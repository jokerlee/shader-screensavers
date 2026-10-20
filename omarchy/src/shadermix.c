// ShaderMix for Omarchy: a fullscreen Wayland port of the macOS Shader Mix screen saver
// (../shader-mix/saver/ShaderMixView.swift). Plays the same Shadertoy shaders in random order
// with the same four transitions and the same bottom-left code overlay.
//
// Frame structure (as on macOS): the current (and, during a transition, the next) shader renders
// into an offscreen target capped at maxRenderPixels; a tiny pass keeps a time-smoothed,
// low-resolution copy of the picture; the final pass at native resolution upscales the shader
// output, applies the transition and draws the code text from a pre-rendered mipmapped mask,
// whose dark outline and halo follow that smoothed copy.
//
// Personal use only; every shader belongs to its author (see ../shader-mix/saver/README.md).

#include <SDL3/SDL.h>
#include <GLES3/gl3.h>
#include <ft2build.h>
#include FT_FREETYPE_H

#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAX_SHADERS 64
#define MAX_CHANNELS 4

// ------------------------------------------------------------------ options

static struct {
  const char *dir;
  const char *only;
  double segment, transition, jitter;
  int fps;
  double maxPixels;
  float codeOpacity, codeHalo, codeScale;
  int showCode;
  int transitions[4], nTransitions;
  int windowed;
  const char *shot;
  double shotAt;
  int shotW, shotH;
  float shotScale;
  int shotMode;
  unsigned seed;
  int stats;
} opt = {
  .segment = 20, .transition = 2, .jitter = 30, .fps = 30, .maxPixels = 1920.0 * 1080.0,
  .codeOpacity = 0.9f, .codeHalo = 0.85f, .codeScale = 1, .showCode = 1,
  .transitions = {0, 1, 2, 3}, .nTransitions = 4,
  .shotW = 1920, .shotH = 1080, .shotScale = 1, .shotMode = -1,
};

static const char *transitionNames[] = {"fade", "dissolve", "radial", "clock"};

// ------------------------------------------------------------------ helpers

static char *readFile(const char *path, size_t *len) {
  FILE *f = fopen(path, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *buf = malloc(n + 1);
  if (fread(buf, 1, n, f) != (size_t)n) { free(buf); fclose(f); return NULL; }
  buf[n] = 0;
  fclose(f);
  if (len) *len = n;
  return buf;
}

static unsigned rngState;
static double frand(void) {   // [0, 1)
  rngState = rngState * 1664525u + 1013904223u;
  return (rngState >> 8) / 16777216.0;
}

// ---------------------------------------------------------------- GL helpers

static GLuint compile(GLenum type, const char *src, const char *name) {
  GLuint s = glCreateShader(type);
  glShaderSource(s, 1, &src, NULL);
  glCompileShader(s);
  GLint ok;
  glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
  if (!ok) {
    char log[8192];
    glGetShaderInfoLog(s, sizeof log, NULL, log);
    fprintf(stderr, "shadermix: %s failed to compile:\n%s\n", name, log);
    glDeleteShader(s);
    return 0;
  }
  return s;
}

static const char *vertSrc =
  "#version 300 es\n"
  "const vec2 P[3] = vec2[3](vec2(-1.,-1.), vec2(3.,-1.), vec2(-1.,3.));\n"
  "void main(){ gl_Position = vec4(P[gl_VertexID], 0., 1.); }\n";

static GLuint linkProgram(const char *frag, const char *name) {
  GLuint vs = compile(GL_VERTEX_SHADER, vertSrc, "vertex");
  GLuint fs = compile(GL_FRAGMENT_SHADER, frag, name);
  if (!vs || !fs) return 0;
  GLuint p = glCreateProgram();
  glAttachShader(p, vs);
  glAttachShader(p, fs);
  glLinkProgram(p);
  glDeleteShader(vs);
  glDeleteShader(fs);
  GLint ok;
  glGetProgramiv(p, GL_LINK_STATUS, &ok);
  if (!ok) {
    char log[4096];
    glGetProgramInfoLog(p, sizeof log, NULL, log);
    fprintf(stderr, "shadermix: %s failed to link:\n%s\n", name, log);
    glDeleteProgram(p);
    return 0;
  }
  return p;
}

typedef struct {
  GLuint fbo, tex;
  int w, h;
} Target;

static int targetResize(Target *t, int w, int h, GLenum format) {
  if (t->fbo && t->w == w && t->h == h) return 0;
  if (!t->fbo) { glGenFramebuffers(1, &t->fbo); glGenTextures(1, &t->tex); }
  t->w = w; t->h = h;
  glBindTexture(GL_TEXTURE_2D, t->tex);
  glTexStorage2D(GL_TEXTURE_2D, 1, format, w, h);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glBindFramebuffer(GL_FRAMEBUFFER, t->fbo);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, t->tex, 0);
  return 1;
}

static void targetFree(Target *t) {
  if (!t->fbo) return;
  glDeleteFramebuffers(1, &t->fbo);
  glDeleteTextures(1, &t->tex);
  memset(t, 0, sizeof *t);
}

// Shadertoy channel textures as binary PPM (install.sh converts the repo's JPG once):
// vertically flipped, linear, mipmapped, repeat.
static GLuint loadTexture(const char *path, float res[3]) {
  size_t len;
  char *buf = readFile(path, &len);
  if (!buf) { fprintf(stderr, "shadermix: missing texture %s\n", path); return 0; }
  int w, h, maxv, off = 0;
  if (sscanf(buf, "P6 %d %d %d%n", &w, &h, &maxv, &off) != 3 || maxv != 255 ||
      (size_t)(off + 1 + (size_t)w * h * 3) > len) {
    fprintf(stderr, "shadermix: %s is not a binary PPM\n", path);
    free(buf);
    return 0;
  }
  const unsigned char *src = (const unsigned char *)buf + off + 1;
  unsigned char *pix = malloc((size_t)w * h * 3);
  for (int y = 0; y < h; y++)
    memcpy(pix + (size_t)(h - 1 - y) * w * 3, src + (size_t)y * w * 3, (size_t)w * 3);
  GLuint t;
  glGenTextures(1, &t);
  glBindTexture(GL_TEXTURE_2D, t);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB8, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, pix);
  glGenerateMipmap(GL_TEXTURE_2D);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  free(pix);
  free(buf);
  res[0] = w; res[1] = h; res[2] = 1;
  return t;
}

// ------------------------------------------------------------------ shaders

typedef struct {
  char key[64], title[128], author[128], link[128], license[64];
  char channel[MAX_CHANNELS][128];
  char *excerpt;
  GLuint prog;
  GLint uRes, uTime, uDelta, uFrame, uMouse, uDate, uRate, uSampleRate, uChRes, uCh[MAX_CHANNELS];
  GLuint tex[MAX_CHANNELS];
  float texRes[MAX_CHANNELS][3];
  GLuint mask;          // code overlay coverage (R8, mipmapped), top row first
  int maskW, maskH;
  float maskTopPad;
} Shader;

static Shader shaders[MAX_SHADERS];
static int nShaders;
static GLuint blankTex;

static const char *shadertoyHeader =
  "#version 300 es\n"
  "precision highp float;\nprecision highp int;\nprecision highp sampler2D;\n"
  "uniform vec3 iResolution;\nuniform float iTime;\nuniform float iTimeDelta;\n"
  "uniform int iFrame;\nuniform vec4 iMouse;\nuniform vec4 iDate;\nuniform float iFrameRate;\n"
  "uniform float iSampleRate;\nuniform float iChannelTime[4];\nuniform vec3 iChannelResolution[4];\n"
  "uniform sampler2D iChannel0;\nuniform sampler2D iChannel1;\n"
  "uniform sampler2D iChannel2;\nuniform sampler2D iChannel3;\n"
  "out vec4 shadermixOut;\n"
  "#line 1\n";

static const char *shadertoyFooter =
  "\nvoid main(){ vec4 c = vec4(0.0); mainImage(c, gl_FragCoord.xy);"
  " shadermixOut = vec4(c.rgb, 1.0); }\n";

static int buildShader(Shader *s) {
  char path[1024];
  snprintf(path, sizeof path, "%s/shaders/%s.glsl", opt.dir, s->key);
  char *body = readFile(path, NULL);
  if (!body) { fprintf(stderr, "shadermix: missing %s\n", path); return 0; }
  size_t n = strlen(shadertoyHeader) + strlen(body) + strlen(shadertoyFooter) + 1;
  char *src = malloc(n);
  snprintf(src, n, "%s%s%s", shadertoyHeader, body, shadertoyFooter);
  free(body);
  s->prog = linkProgram(src, s->key);
  free(src);
  if (!s->prog) return 0;

  s->uRes = glGetUniformLocation(s->prog, "iResolution");
  s->uTime = glGetUniformLocation(s->prog, "iTime");
  s->uDelta = glGetUniformLocation(s->prog, "iTimeDelta");
  s->uFrame = glGetUniformLocation(s->prog, "iFrame");
  s->uMouse = glGetUniformLocation(s->prog, "iMouse");
  s->uDate = glGetUniformLocation(s->prog, "iDate");
  s->uRate = glGetUniformLocation(s->prog, "iFrameRate");
  s->uSampleRate = glGetUniformLocation(s->prog, "iSampleRate");
  s->uChRes = glGetUniformLocation(s->prog, "iChannelResolution");
  for (int i = 0; i < MAX_CHANNELS; i++) {
    char name[16];
    snprintf(name, sizeof name, "iChannel%d", i);
    s->uCh[i] = glGetUniformLocation(s->prog, name);
    s->tex[i] = blankTex;
    s->texRes[i][0] = s->texRes[i][1] = s->texRes[i][2] = 1;
    if (s->channel[i][0]) {
      snprintf(path, sizeof path, "%s/textures/%s", opt.dir, s->channel[i]);
      GLuint t = loadTexture(path, s->texRes[i]);
      if (t) s->tex[i] = t;
    }
  }

  snprintf(path, sizeof path, "%s/shaders/%s.excerpt.glsl", opt.dir, s->key);
  s->excerpt = readFile(path, NULL);
  if (!s->excerpt) s->excerpt = strdup("");
  return 1;
}

// playlist.tsv (written by install.sh from manifest.json):
//   key <TAB> title <TAB> author <TAB> link <TAB> license [<TAB> iChannel0 [<TAB> iChannel1 ...]]
static void loadPlaylist(void) {
  char path[1024];
  snprintf(path, sizeof path, "%s/playlist.tsv", opt.dir);
  char *buf = readFile(path, NULL);
  if (!buf) { fprintf(stderr, "shadermix: cannot read %s\n", path); exit(1); }
  for (char *line = strtok(buf, "\n"); line && nShaders < MAX_SHADERS; line = strtok(NULL, "\n")) {
    if (!*line || *line == '#') continue;
    char *field[5 + MAX_CHANNELS] = {0};
    int nf = 0;
    for (char *p = line; nf < 5 + MAX_CHANNELS;) {
      field[nf++] = p;
      char *tab = strchr(p, '\t');
      if (!tab) break;
      *tab = 0;
      p = tab + 1;
    }
    if (nf < 5) continue;
    if (opt.only) {
      char want[512];
      snprintf(want, sizeof want, ",%s,", opt.only);
      char key[80];
      snprintf(key, sizeof key, ",%s,", field[0]);
      if (!strstr(want, key)) continue;
    }
    Shader *s = &shaders[nShaders];
    memset(s, 0, sizeof *s);
    snprintf(s->key, sizeof s->key, "%s", field[0]);
    snprintf(s->title, sizeof s->title, "%s", field[1]);
    snprintf(s->author, sizeof s->author, "%s", field[2]);
    snprintf(s->link, sizeof s->link, "%s", field[3]);
    snprintf(s->license, sizeof s->license, "%s", field[4]);
    for (int i = 5; i < nf; i++) snprintf(s->channel[i - 5], sizeof s->channel[0], "%s", field[i]);
    if (buildShader(s)) nShaders++;
  }
  free(buf);
  if (!nShaders) { fprintf(stderr, "shadermix: no usable shaders\n"); exit(1); }
}

// ------------------------------------------------------------------ code text
//
// Same layout as common/CodeText.swift: a bold title at 2.7x the code size, a
// "by author · link · license" line at 0.95x (75% white), a blank line, then the excerpt in
// monospace. Line height 1.08. One font size and one text area per screen, sized for the
// longest excerpt, anchored bottom-left with the title at its top.

static FT_Library ft;
static FT_Face faceTitle, faceBody, faceMono;

static FT_Face openFace(const char *pattern) {
  char cmd[256], file[1024] = {0};
  snprintf(cmd, sizeof cmd, "fc-match -f '%%{file}' '%s'", pattern);
  FILE *p = popen(cmd, "r");
  if (p) { if (!fgets(file, sizeof file, p)) file[0] = 0; pclose(p); }
  FT_Face f = NULL;
  if (!file[0] || FT_New_Face(ft, file, 0, &f)) {
    fprintf(stderr, "shadermix: font '%s' not found\n", pattern);
    return NULL;
  }
  return f;
}

static unsigned nextCodepoint(const char **s) {
  const unsigned char *p = (const unsigned char *)*s;
  unsigned c = *p++;
  int extra = c >= 0xF0 ? 3 : c >= 0xE0 ? 2 : c >= 0xC0 ? 1 : 0;
  if (extra) c &= 0x3F >> extra;
  while (extra-- && (*p & 0xC0) == 0x80) c = (c << 6) | (*p++ & 0x3F);
  *s = (const char *)p;
  return c;
}

typedef struct { FT_Face face; float px; unsigned char level; const char *text; float kern; } Line;

// Measure (buf == NULL) or draw a line; returns its advance width in pixels.
static float runLine(const Line *l, unsigned char *buf, int bw, int bh, float x, float baseline) {
  FT_Set_Pixel_Sizes(l->face, 0, (FT_UInt)(l->px + 0.5f));
  const char *s = l->text;
  float pen = x;
  while (*s) {
    unsigned c = nextCodepoint(&s);
    if (c == '\t') c = ' ';
    if (c == '\r') continue;
    if (FT_Load_Char(l->face, c, buf ? FT_LOAD_RENDER : FT_LOAD_DEFAULT)) continue;
    FT_GlyphSlot g = l->face->glyph;
    if (buf) {
      int ox = (int)lroundf(pen) + g->bitmap_left, oy = (int)lroundf(baseline) - g->bitmap_top;
      for (unsigned r = 0; r < g->bitmap.rows; r++) {
        int y = oy + r;
        if (y < 0 || y >= bh) continue;
        for (unsigned col = 0; col < g->bitmap.width; col++) {
          int xx = ox + col;
          if (xx < 0 || xx >= bw) continue;
          int v = g->bitmap.buffer[r * g->bitmap.pitch + col] * l->level / 255;
          if (v > buf[y * bw + xx]) buf[y * bw + xx] = v;
        }
      }
    }
    pen += (g->advance.x / 64.0f) + l->kern;
  }
  return pen - x;
}

// Lines for one shader at code size `size` (pixels); returns count. Strings point into `store`.
static int buildLines(const Shader *s, float size, Line *lines, int max, char *store, size_t storeLen) {
  int n = 0;
  snprintf(store, storeLen, "by %s \xc2\xb7 %s \xc2\xb7 %s", s->author, s->link, s->license);
  size_t used = strlen(store) + 1;
  lines[n++] = (Line){faceTitle, size * 2.7f, 255, s->title, -size * 0.03f};
  lines[n++] = (Line){faceBody, size * 0.95f, 191, store, 0};
  lines[n++] = (Line){faceBody, size * 0.95f, 0, "", 0};
  // excerpt, trimmed of leading/trailing blank lines
  const char *ex = s->excerpt;
  while (*ex == '\n' || *ex == '\r' || *ex == ' ' || *ex == '\t') {
    const char *nl = strchr(ex, '\n');
    const char *q = ex;
    while (*q == ' ' || *q == '\t' || *q == '\r') q++;
    if (*q != '\n' || !nl) break;
    ex = nl + 1;
  }
  char *copy = store + used;
  snprintf(copy, storeLen - used, "%s", ex);
  for (char *e = copy + strlen(copy); e > copy && (e[-1] == '\n' || e[-1] == ' ' || e[-1] == '\r' || e[-1] == '\t');) *--e = 0;
  for (char *p = copy; *p && n < max;) {
    char *nl = strchr(p, '\n');
    if (nl) *nl = 0;
    lines[n++] = (Line){faceMono, size, 255, p, 0};
    if (!nl) break;
    p = nl + 1;
  }
  return n;
}

// natural line height of the face at the size last set for this line
static float lineHeight(const Line *l) { return l->face->size->metrics.height / 64.0f; }

static void measureText(const Shader *s, float size, float *w, float *h) {
  static char store[65536];
  Line lines[128];
  int n = buildLines(s, size, lines, 128, store, sizeof store);
  *w = 0; *h = 0;
  for (int i = 0; i < n; i++) {
    float lw = runLine(&lines[i], NULL, 0, 0, 0, 0);
    if (lw > *w) *w = lw;
    float lh = lineHeight(&lines[i]) * (i == 0 ? 1.0f : 1.08f);
    if (i == 0) lh += size * 0.15f;
    *h += lh;
  }
}

static struct {
  int viewW, viewH;
  float size;     // code font size, pixels
  float areaTop;  // pixels from the top of the view
  float left;
} layout;

static void computeLayout(int viewW, int viewH, float scale) {
  float ptsW = viewW / scale, ptsH = viewH / scale;
  float margin = ptsH * 0.035f;
  float base = fmaxf(9, fminf(26, ptsH * 0.0125f * opt.codeScale));
  float maxW = 1, maxH = 1;
  for (int i = 0; i < nShaders; i++) {
    float w, h;
    measureText(&shaders[i], base * scale, &w, &h);
    w /= scale; h /= scale;
    if (w > maxW) maxW = w;
    if (h > maxH) maxH = h;
  }
  float fit = fminf(1, fminf(ptsW * 0.66f / maxW, ptsH * 0.4f / maxH));
  float size = fit < 1 ? fmaxf(7, floorf(base * fit * 0.98f)) : base;
  float areaH = maxH * size / base;
  layout.viewW = viewW;
  layout.viewH = viewH;
  layout.size = size * scale;
  layout.areaTop = (ptsH - margin - areaH) * scale;
  layout.left = margin * scale;
}

static void buildMask(Shader *s) {
  static char store[65536];
  Line lines[128];
  float size = layout.size;
  int n = buildLines(s, size, lines, 128, store, sizeof store);
  float w, h;
  measureText(s, size, &w, &h);
  float pad = size * 0.8f;   // room for the halo
  int bw = (int)ceilf(w + pad * 2), bh = (int)ceilf(h + pad * 2);
  unsigned char *buf = calloc((size_t)bw * bh, 1);
  float y = pad;
  for (int i = 0; i < n; i++) {
    float lh = lineHeight(&lines[i]);
    FT_Set_Pixel_Sizes(lines[i].face, 0, (FT_UInt)(lines[i].px + 0.5f));
    float asc = lines[i].face->size->metrics.ascender / 64.0f;
    runLine(&lines[i], buf, bw, bh, pad, y + asc);
    y += lh * (i == 0 ? 1.0f : 1.08f) + (i == 0 ? size * 0.15f : 0);
  }
  if (!s->mask) glGenTextures(1, &s->mask);
  glBindTexture(GL_TEXTURE_2D, s->mask);
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, bw, bh, 0, GL_RED, GL_UNSIGNED_BYTE, buf);
  glGenerateMipmap(GL_TEXTURE_2D);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  s->maskW = bw;
  s->maskH = bh;
  s->maskTopPad = pad;
  free(buf);
}

// ---------------------------------------------------------------- composite

// Ported from compositeSource in ShaderMixView.swift and codeTextMSL in CodeText.swift.
// GL's gl_FragCoord is bottom-left based; it is flipped so all positions are top-left based.
static const char *compositeSrc =
  "#version 300 es\n"
  "precision highp float;\n"
  "uniform sampler2D uA, uB, uBackdrop, uText;\n"
  "uniform vec2 uViewSize;\n"   // pixels of the pass being drawn
  "uniform float uProgress;\n"  // 0 = only A, >0 transition towards B
  "uniform int uMode;\n"        // 0 fade, 1 dissolve, 2 radial, 3 clock
  "uniform float uSeed;\n"
  "uniform float uTextAlpha;\n"
  "uniform float uHalo;\n"
  "uniform vec4 uTextRect;\n"   // x, y (top-left origin), width, height in view pixels
  "uniform int uPass;\n"        // 0 backdrop, 1 composite
  "out vec4 o;\n"
  "float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\n"
  "float vnoise(vec2 p) {\n"
  "  vec2 i = floor(p), f = fract(p);\n"
  "  vec2 u = f * f * (3.0 - 2.0 * f);\n"
  "  return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + 1.0), u.x), u.y);\n"
  "}\n"
  "vec3 shadeCodeText(vec3 col, vec2 pixel, vec3 bg) {\n"
  "  if (uTextAlpha <= 0.0) return col;\n"
  "  vec2 tuv = (pixel - uTextRect.xy) / uTextRect.zw;\n"
  "  if (any(lessThan(tuv, vec2(0.0))) || any(greaterThan(tuv, vec2(1.0)))) return col;\n"
  "  float glyph = textureLod(uText, tuv, 0.0).r;\n"
  "  float edge = clamp(textureLod(uText, tuv, 1.0).r * 3.0, 0.0, 1.0);\n"
  "  float glow = clamp(textureLod(uText, tuv, 2.5).r * 4.0, 0.0, 1.0);\n"
  "  float lum = dot(min(bg, 1.0), vec3(0.2126, 0.7152, 0.0722));\n"
  "  float bright = smoothstep(0.15, 0.65, lum);\n"
  "  vec3 comp = 1.0 - min(bg, 1.0);\n"
  "  comp /= max(max(comp.r, comp.g), max(comp.b, 1e-3));\n"
  "  vec3 ink = mix(vec3(1.0), comp, 0.12 * (1.0 - bright));\n"
  "  float shade = max(edge * mix(0.35, 0.9, bright), glow * mix(0.3, 0.75, bright)) * uHalo;\n"
  "  col = mix(col, col * 0.08, shade * uTextAlpha);\n"
  "  return mix(col, ink, glyph * uTextAlpha);\n"
  "}\n"
  "float sweep(float field, float p, float w) { return smoothstep(field - w, field + w, p * (1.0 + 2.0 * w) - w); }\n"
  "float transitionWeight(vec2 uv, out float glow) {\n"
  "  glow = 0.0;\n"
  "  float p = uProgress;\n"
  "  if (p <= 0.0) return 0.0;\n"
  "  float aspect = uViewSize.x / uViewSize.y;\n"
  "  vec2 c = (uv - 0.5) * vec2(aspect, 1.0);\n"
  "  float m;\n"
  "  if (uMode == 1) {\n"
  "    vec2 q = c * 5.0 + uSeed * 17.0;\n"
  "    float n = 0.55 * vnoise(q) + 0.3 * vnoise(q * 2.1) + 0.15 * vnoise(q * 4.3);\n"
  "    m = sweep(n, p, 0.06);\n"
  "    glow = m * (1.0 - m) * 4.0;\n"
  "  } else if (uMode == 2) {\n"
  "    float maxR = length(vec2(aspect, 1.0)) * 0.5;\n"
  "    m = sweep(length(c) / maxR, p, 0.08);\n"
  "    glow = m * (1.0 - m) * 2.0;\n"
  "  } else if (uMode == 3) {\n"
  "    float ang = fract(atan(c.x, c.y) / 6.2831853 + 1.0);\n"
  "    m = sweep(ang, p, 0.04);\n"
  "    glow = m * (1.0 - m) * 2.0;\n"
  "  } else {\n"
  "    m = smoothstep(0.0, 1.0, p);\n"
  "  }\n"
  "  return m;\n"
  "}\n"
  // Targets are rendered by GL bottom-up, so flip v when sampling with top-left uv.
  "vec3 scene(vec2 uv) {\n"
  "  vec2 tuv = vec2(uv.x, 1.0 - uv.y);\n"
  "  vec3 ca = texture(uA, tuv).rgb;\n"
  "  if (uProgress <= 0.0) return ca;\n"
  "  float glow;\n"
  "  float m = transitionWeight(uv, glow);\n"
  "  vec3 cb = texture(uB, tuv).rgb;\n"
  "  return mix(ca, cb, m) + glow * 0.35 * (cb + 0.15);\n"
  "}\n"
  "void main() {\n"
  "  vec2 pos = vec2(gl_FragCoord.x, uViewSize.y - gl_FragCoord.y);\n"
  "  if (uPass == 0) {\n"
  "    vec3 sum = vec3(0.0);\n"
  "    for (int j = 0; j < 4; j++)\n"
  "      for (int i = 0; i < 4; i++)\n"
  "        sum += scene((pos + (vec2(i, j) + 0.5) / 4.0 - 0.5) / uViewSize);\n"
  "    o = vec4(sum / 16.0, 1.0);\n"
  "    return;\n"
  "  }\n"
  "  vec2 uv = pos / uViewSize;\n"
  "  vec3 col = scene(uv);\n"
  "  col = shadeCodeText(col, pos, texture(uBackdrop, vec2(uv.x, 1.0 - uv.y)).rgb);\n"
  "  o = vec4(col, 1.0);\n"
  "}\n";

static GLuint compProg;
static GLint cViewSize, cProgress, cMode, cSeed, cTextAlpha, cHalo, cTextRect, cPass;

// ------------------------------------------------------------------ playback

typedef struct {
  Shader *shader;
  double start;       // seconds on our clock when the segment started
  double timeOffset;  // iTime at segment start
} Playing;

static Playing current, next;
static int hasNext;
static double firstShown, transitionStart;
static int transitionMode;
static float transitionSeed;

static Playing play(Shader *s, double now) {
  return (Playing){s, now, frand() * opt.jitter};
}

static void advance(double now) {
  if (!current.shader) {
    current = play(&shaders[(int)(frand() * nShaders)], now);
    firstShown = now;
    return;
  }
  if (hasNext) {
    if (now - transitionStart >= opt.transition) {
      current = (Playing){next.shader, transitionStart, next.timeOffset};
      hasNext = 0;
    }
    return;
  }
  if (now - current.start < opt.segment || nShaders < 2) return;
  int pick = (int)(frand() * (nShaders - 1));
  if (&shaders[pick] >= current.shader) pick++;
  next = play(&shaders[pick], now);
  hasNext = 1;
  transitionStart = now;
  transitionMode = opt.shotMode >= 0 ? opt.shotMode : opt.transitions[(int)(frand() * opt.nTransitions)];
  transitionSeed = (float)frand();
}

static void encode(const Playing *p, Target *t, double now) {
  Shader *s = p->shader;
  glBindFramebuffer(GL_FRAMEBUFFER, t->fbo);
  glViewport(0, 0, t->w, t->h);
  glUseProgram(s->prog);
  float iTime = (float)(now - p->start + p->timeOffset);
  glUniform3f(s->uRes, t->w, t->h, 1.0f);
  glUniform1f(s->uTime, iTime);
  glUniform1f(s->uDelta, 1.0f / opt.fps);
  glUniform1i(s->uFrame, (int)(iTime * opt.fps));
  glUniform4f(s->uMouse, 0, 0, 0, 0);
  glUniform1f(s->uRate, (float)opt.fps);
  glUniform1f(s->uSampleRate, 44100);
  time_t wall = time(NULL);
  struct tm tm;
  localtime_r(&wall, &tm);
  glUniform4f(s->uDate, tm.tm_year + 1900, tm.tm_mon, tm.tm_mday, tm.tm_hour * 3600 + tm.tm_min * 60 + tm.tm_sec);
  for (int i = 0; i < MAX_CHANNELS; i++) {
    glActiveTexture(GL_TEXTURE0 + i);
    glBindTexture(GL_TEXTURE_2D, s->tex[i]);
    glUniform1i(s->uCh[i], i);
  }
  glUniform3fv(s->uChRes, MAX_CHANNELS, &s->texRes[0][0]);
  glDrawArrays(GL_TRIANGLES, 0, 3);
}

static void sceneSize(int viewW, int viewH, float scale, int *w, int *h) {
  // renderScale 1 = one pixel per point, capped at maxPixels
  double fw = viewW / scale, fh = viewH / scale, px = fw * fh;
  if (px > opt.maxPixels) { double r = sqrt(opt.maxPixels / px); fw *= r; fh *= r; }
  *w = fw < 1 ? 1 : (int)lround(fw);
  *h = fh < 1 ? 1 : (int)lround(fh);
}

static Target targets[2], backdrop;
static int backdropFresh = 1;

static void drawFrame(double now, GLuint outFbo, int viewW, int viewH, float scale) {
  advance(now);
  int sw, sh;
  sceneSize(viewW, viewH, scale, &sw, &sh);
  targetResize(&targets[0], sw, sh, GL_RGBA8);
  targetResize(&targets[1], sw, sh, GL_RGBA8);
  if (targetResize(&backdrop, sw / 16 > 0 ? sw / 16 : 1, sh / 16 > 0 ? sh / 16 : 1, GL_RGBA8)) backdropFresh = 1;
  if (opt.showCode && (layout.viewW != viewW || layout.viewH != viewH)) {
    computeLayout(viewW, viewH, scale);
    for (int i = 0; i < nShaders; i++) buildMask(&shaders[i]);
  }

  float progress = 0;
  encode(&current, &targets[0], now);
  if (hasNext) {
    encode(&next, &targets[1], now);
    progress = (float)fmin(fmax((now - transitionStart) / opt.transition, 0.0001), 1);
  }

  // text: fades in over one transition time at start-up; during a transition the old text
  // fades out in the first half and the new text fades in during the second half
  Shader *maskShader = current.shader;
  float fade;
  if (hasNext) {
    float p = (float)((now - transitionStart) / opt.transition);
    if (p < 0.5f) fade = fmaxf(0, 1 - 2 * p);
    else { maskShader = next.shader; fade = fminf(1, 2 * p - 1); }
  } else {
    fade = (float)fmin(1, (now - firstShown) / opt.transition);
  }
  float textAlpha = opt.showCode ? fade * opt.codeOpacity : 0;
  float rect[4] = {0, 0, 1, 1};
  if (opt.showCode) {
    rect[0] = layout.left - maskShader->maskTopPad;
    rect[1] = layout.areaTop - maskShader->maskTopPad;
    rect[2] = maskShader->maskW;
    rect[3] = maskShader->maskH;
  }

  glUseProgram(compProg);
  glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, targets[0].tex);
  glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_2D, targets[1].tex);
  glActiveTexture(GL_TEXTURE2); glBindTexture(GL_TEXTURE_2D, backdrop.tex);
  glActiveTexture(GL_TEXTURE3); glBindTexture(GL_TEXTURE_2D, opt.showCode ? maskShader->mask : blankTex);
  glUniform1f(cProgress, progress);
  glUniform1i(cMode, transitionMode);
  glUniform1f(cSeed, transitionSeed);
  glUniform1f(cTextAlpha, textAlpha);
  glUniform1f(cHalo, opt.codeHalo);
  glUniform4fv(cTextRect, 1, rect);

  // low-resolution, time-smoothed copy of the picture for the text colour
  // (exponential moving average via constant blend alpha)
  glBindFramebuffer(GL_FRAMEBUFFER, backdrop.fbo);
  glViewport(0, 0, backdrop.w, backdrop.h);
  glUniform1i(cPass, 0);
  glUniform2f(cViewSize, backdrop.w, backdrop.h);
  glEnable(GL_BLEND);
  glBlendColor(0, 0, 0, backdropFresh ? 1.0f : 0.12f);
  glBlendFuncSeparate(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA, GL_ONE, GL_ZERO);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  glDisable(GL_BLEND);
  backdropFresh = 0;

  glBindFramebuffer(GL_FRAMEBUFFER, outFbo);
  glViewport(0, 0, viewW, viewH);
  glUniform1i(cPass, 1);
  glUniform2f(cViewSize, viewW, viewH);
  glDrawArrays(GL_TRIANGLES, 0, 3);
}

// ---------------------------------------------------------------------- main

static volatile sig_atomic_t quitSignal;
static void onSignal(int sig) { (void)sig; quitSignal = 1; }

static void writePPM(const char *path, int w, int h) {
  unsigned char *pix = malloc((size_t)w * h * 4);
  glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, pix);
  FILE *f = fopen(path, "wb");
  if (!f) { perror(path); free(pix); return; }
  fprintf(f, "P6\n%d %d\n255\n", w, h);
  for (int y = h - 1; y >= 0; y--)
    for (int x = 0; x < w; x++) fwrite(pix + ((size_t)y * w + x) * 4, 1, 3, f);
  fclose(f);
  free(pix);
}

// One window per monitor; dismissing any of them closes all (like Omarchy's own screensaver).
static void dismissAll(void) {
  if (system("pkill -f '[o]rg.omarchy.screensaver' >/dev/null 2>&1")) {}
}

static int screensaverFocused(void) {
  FILE *p = popen("hyprctl activewindow -j 2>/dev/null", "r");
  if (!p) return 1;
  char buf[16384];
  size_t n = fread(buf, 1, sizeof buf - 1, p);
  buf[n] = 0;
  pclose(p);
  return strstr(buf, "\"class\": \"org.omarchy.screensaver\"") != NULL;
}

static void usage(void) {
  fprintf(stderr,
    "usage: shadermix [options]\n"
    "  --dir DIR            data directory with playlist.tsv, shaders/, textures/\n"
    "  --shaders a,b,...    keys to play (default: all in playlist.tsv)\n"
    "  --segment SEC        seconds per shader (20)\n"
    "  --transition SEC     transition length (2)\n"
    "  --transitions LIST   subset of fade,dissolve,radial,clock\n"
    "  --jitter SEC         random iTime offset per segment in [0, SEC) (30)\n"
    "  --fps N              frame rate cap (30)\n"
    "  --max-pixels N       shader render size cap per screen (2073600 = 1920x1080)\n"
    "  --no-code            hide the code overlay\n"
    "  --code-scale X       text size multiplier (1)\n"
    "  --windowed           normal window, Esc quits, input does not dismiss\n"
    "  --stats              print fps every 10 s\n"
    "  --class ID           Wayland app id (org.omarchy.screensaver)\n"
    "  --seed N             random seed\n"
    "offline: --shot FILE.ppm --at SEC [--size WxH] [--scale S] [--mode NAME]\n"
    "  renders the timeline at SEC (first segment change at --segment) and exits\n");
  exit(2);
}

int main(int argc, char **argv) {
  const char *appId = "org.omarchy.screensaver";
  opt.seed = (unsigned)time(NULL) ^ ((unsigned)getpid() << 16);
  for (int i = 1; i < argc; i++) {
    const char *a = argv[i];
    int hasV = i + 1 < argc;
    if (!strcmp(a, "--dir") && hasV) opt.dir = argv[++i];
    else if (!strcmp(a, "--shaders") && hasV) opt.only = argv[++i];
    else if (!strcmp(a, "--segment") && hasV) opt.segment = fmax(3, atof(argv[++i]));
    else if (!strcmp(a, "--transition") && hasV) opt.transition = fmin(20, fmax(0.1, atof(argv[++i])));
    else if (!strcmp(a, "--jitter") && hasV) opt.jitter = fmax(0, atof(argv[++i]));
    else if (!strcmp(a, "--fps") && hasV) opt.fps = atoi(argv[++i]);
    else if (!strcmp(a, "--max-pixels") && hasV) opt.maxPixels = fmax(64 * 64, atof(argv[++i]));
    else if (!strcmp(a, "--no-code")) opt.showCode = 0;
    else if (!strcmp(a, "--code-scale") && hasV) opt.codeScale = fminf(3, fmaxf(0.3f, atof(argv[++i])));
    else if (!strcmp(a, "--windowed")) opt.windowed = 1;
    else if (!strcmp(a, "--stats")) opt.stats = 1;
    else if (!strcmp(a, "--class") && hasV) appId = argv[++i];
    else if (!strcmp(a, "--seed") && hasV) opt.seed = strtoul(argv[++i], NULL, 10);
    else if (!strcmp(a, "--shot") && hasV) opt.shot = argv[++i];
    else if (!strcmp(a, "--at") && hasV) opt.shotAt = atof(argv[++i]);
    else if (!strcmp(a, "--size") && hasV) sscanf(argv[++i], "%dx%d", &opt.shotW, &opt.shotH);
    else if (!strcmp(a, "--scale") && hasV) opt.shotScale = atof(argv[++i]);
    else if ((!strcmp(a, "--mode") || !strcmp(a, "--transitions")) && hasV) {
      int isMode = !strcmp(a, "--mode");
      char *list = strdup(argv[++i]);
      opt.nTransitions = 0;
      for (char *t = strtok(list, ","); t; t = strtok(NULL, ","))
        for (int m = 0; m < 4; m++)
          if (!strcmp(t, transitionNames[m]) && opt.nTransitions < 4) opt.transitions[opt.nTransitions++] = m;
      if (!opt.nTransitions) opt.transitions[opt.nTransitions++] = 0;
      if (isMode) opt.shotMode = opt.transitions[0];
      free(list);
    }
    else usage();
  }
  if (opt.fps < 1) opt.fps = 1;
  if (opt.fps > 120) opt.fps = 120;
  if (!opt.dir) {
    static char def[1024];
    const char *data = getenv("XDG_DATA_HOME");
    if (data && *data) snprintf(def, sizeof def, "%s/shadermix", data);
    else snprintf(def, sizeof def, "%s/.local/share/shadermix", getenv("HOME"));
    opt.dir = def;
  }
  rngState = opt.seed;

  signal(SIGTERM, onSignal);
  signal(SIGINT, onSignal);
  signal(SIGHUP, onSignal);

  // Shadertoy (WebGL) and Metal zero-initialise locals; several of these shaders rely on it
  // (Starship, Singularity). Mesa reads this driconf option from the environment.
  setenv("glsl_zero_init", "true", 0);

  SDL_SetHint(SDL_HINT_APP_ID, appId);
  if (!SDL_Init(SDL_INIT_VIDEO)) { fprintf(stderr, "shadermix: %s\n", SDL_GetError()); return 1; }
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0);

  SDL_WindowFlags flags = SDL_WINDOW_OPENGL | SDL_WINDOW_HIGH_PIXEL_DENSITY;
  if (opt.shot) flags |= SDL_WINDOW_HIDDEN;
  else if (opt.windowed) flags |= SDL_WINDOW_RESIZABLE;
  else flags |= SDL_WINDOW_FULLSCREEN;
  SDL_Window *win = SDL_CreateWindow("Shader Mix", 1280, 800, flags);
  if (!win) { fprintf(stderr, "shadermix: %s\n", SDL_GetError()); return 1; }
  SDL_GLContext ctx = SDL_GL_CreateContext(win);
  if (!ctx) { fprintf(stderr, "shadermix: %s\n", SDL_GetError()); return 1; }
  SDL_GL_MakeCurrent(win, ctx);
  SDL_GL_SetSwapInterval(1);
  if (!opt.windowed && !opt.shot) SDL_HideCursor();

  // black first, so nothing flashes while the shaders compile
  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT);
  if (!opt.shot) SDL_GL_SwapWindow(win);

  GLuint vao;
  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);
  unsigned char black[4] = {0, 0, 0, 0};
  glGenTextures(1, &blankTex);
  glBindTexture(GL_TEXTURE_2D, blankTex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, black);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

  compProg = linkProgram(compositeSrc, "composite");
  if (!compProg) return 1;
  glUseProgram(compProg);
  glUniform1i(glGetUniformLocation(compProg, "uA"), 0);
  glUniform1i(glGetUniformLocation(compProg, "uB"), 1);
  glUniform1i(glGetUniformLocation(compProg, "uBackdrop"), 2);
  glUniform1i(glGetUniformLocation(compProg, "uText"), 3);
  cViewSize = glGetUniformLocation(compProg, "uViewSize");
  cProgress = glGetUniformLocation(compProg, "uProgress");
  cMode = glGetUniformLocation(compProg, "uMode");
  cSeed = glGetUniformLocation(compProg, "uSeed");
  cTextAlpha = glGetUniformLocation(compProg, "uTextAlpha");
  cHalo = glGetUniformLocation(compProg, "uHalo");
  cTextRect = glGetUniformLocation(compProg, "uTextRect");
  cPass = glGetUniformLocation(compProg, "uPass");

  FT_Init_FreeType(&ft);
  faceTitle = openFace("sans-serif:bold");
  faceBody = openFace("sans-serif:medium");
  faceMono = openFace("monospace");
  if (!faceTitle || !faceBody || !faceMono) return 1;

  loadPlaylist();

  if (opt.shot) {
    // Replay the timeline on a fixed clock up to --at, then save the last frame.
    Target out = {0};
    targetResize(&out, opt.shotW, opt.shotH, GL_RGBA8);
    for (double t = 0; t < opt.shotAt; t += 0.05) advance(t);
    drawFrame(opt.shotAt, out.fbo, opt.shotW, opt.shotH, opt.shotScale);
    glBindFramebuffer(GL_FRAMEBUFFER, out.fbo);
    writePPM(opt.shot, opt.shotW, opt.shotH);
    return 0;
  }

  const Uint64 frameNs = 1000000000ull / opt.fps;
  Uint64 start = SDL_GetTicksNS(), nextFrame = start, statSince = start;
  int statFrames = 0;
  double mouseTravel = 0, focusCheckAt = -1;
  int running = 1;

  while (running && !quitSignal) {
    double now = (SDL_GetTicksNS() - start) / 1e9;
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      switch (e.type) {
      case SDL_EVENT_QUIT:
      case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
        running = 0;
        break;
      case SDL_EVENT_KEY_DOWN:
        if (opt.windowed) { if (e.key.key == SDLK_ESCAPE) running = 0; break; }
        running = 0;
        dismissAll();
        break;
      case SDL_EVENT_MOUSE_BUTTON_DOWN:
      case SDL_EVENT_MOUSE_WHEEL:
        if (opt.windowed) break;
        running = 0;
        dismissAll();
        break;
      case SDL_EVENT_MOUSE_MOTION:
        // the window maps under a resting pointer: ignore the first second and tiny jitter
        if (opt.windowed || now < 1.0) break;
        mouseTravel += fabs(e.motion.xrel) + fabs(e.motion.yrel);
        if (mouseTravel > 12) { running = 0; dismissAll(); }
        break;
      case SDL_EVENT_WINDOW_FOCUS_LOST:
        if (!opt.windowed) focusCheckAt = now + 0.5;
        break;
      case SDL_EVENT_WINDOW_FOCUS_GAINED:
        focusCheckAt = -1;
        break;
      }
    }
    if (!running) break;
    // Focus moving to another screensaver window (multi-monitor) is fine; focus going to
    // anything else (e.g. the lock screen) ends the screensaver, as with Omarchy's own.
    if (focusCheckAt >= 0 && now >= focusCheckAt && now > 3.0) {
      focusCheckAt = -1;
      if (!screensaverFocused()) break;
    }

    int viewW, viewH;
    SDL_GetWindowSizeInPixels(win, &viewW, &viewH);
    if (viewW <= 0 || viewH <= 0) { SDL_Delay(50); continue; }
    float scale = SDL_GetWindowPixelDensity(win);
    if (scale <= 0) scale = 1;

    drawFrame(now, 0, viewW, viewH, scale);
    SDL_GL_SwapWindow(win);

    if (opt.stats && ++statFrames && SDL_GetTicksNS() - statSince >= 10000000000ull) {
      int sw, sh;
      sceneSize(viewW, viewH, scale, &sw, &sh);
      fprintf(stderr, "shadermix: scene %dx%d @ %.1f fps (now: %s)\n", sw, sh,
              statFrames / ((SDL_GetTicksNS() - statSince) / 1e9), current.shader->key);
      statFrames = 0;
      statSince = SDL_GetTicksNS();
    }

    nextFrame += frameNs;
    Uint64 t = SDL_GetTicksNS();
    if (nextFrame > t) SDL_DelayNS(nextFrame - t);
    else nextFrame = t;
  }

  targetFree(&targets[0]);
  targetFree(&targets[1]);
  targetFree(&backdrop);
  SDL_GL_DestroyContext(ctx);
  SDL_DestroyWindow(win);
  SDL_Quit();
  return 0;
}
