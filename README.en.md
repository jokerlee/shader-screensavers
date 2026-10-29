**English** | [中文](README.md)

# Shader screen savers

Thirteen Shadertoy and OpenProcessing shaders ported to Metal and combined into one macOS screen saver, **Shader Mix**.
It plays them in random order with transitions, and shows the current shader's title, author,
licence and key lines of code in the bottom-left corner.

> **Private repository, personal use only.** Most shaders are CC BY-NC-SA (attribution,
> non-commercial), and the Balatro shader has no licence at all. Do not make this repository
> public or distribute the built screen saver.

## Features

- **Random playlist**: all thirteen shaders are on by default, 20 seconds each, never the same one twice in a row; each display picks its own order.
- **Four transitions** (about 2 seconds, picked at random): cross-fade, noise dissolve with a glowing seam, a circle opening from the centre, and a clock wipe.
- **Code overlay**: a large title, a line with author / link / licence, and a verbatim excerpt of the shader's key lines (`// ...` marks omissions).
  - The text area is fixed to the bottom-left corner and sized for the longest excerpt at start-up, so the title and the first code line never move when shaders switch.
  - The text is composited on the GPU at native resolution.
  - The ink is always light; its dark outline and halo follow the brightness of the picture behind it, smoothed over time so it never flickers.
  - On a transition the old code fades out first, then the new code fades in.
- **Performance**: shaders render at up to 1920×1080 per screen, at 30 fps. On an M4 Pro a single shader takes 1–9 ms of GPU per frame, about 9–11 ms during a transition.
- **Checked ports**: every shader was compared pixel by pixel with the original rendered in a browser (WebGL); see `shader-mix/reference/`.

## Transitions

These animations were rendered offline with the screen saver's own transition shader, with the code overlay off; the tool is `shader-mix/saver/tools/transition_demo/`.

<table>
<tr>
<td width="50%"><img src="docs/screenshots/transition-fade.webp" alt="cross-fade"><br>Cross-fade <code>fade</code></td>
<td width="50%"><img src="docs/screenshots/transition-dissolve.webp" alt="noise dissolve"><br>Noise dissolve <code>dissolve</code></td>
</tr>
<tr>
<td width="50%"><img src="docs/screenshots/transition-radial.webp" alt="radial"><br>Radial <code>radial</code></td>
<td width="50%"><img src="docs/screenshots/transition-clock.webp" alt="clock wipe"><br>Clock wipe <code>clock</code></td>
</tr>
</table>

## Omarchy

`omarchy/` holds a port of Shader Mix to Omarchy (Arch + Hyprland): the same shaders, transitions and code overlay, replacing Omarchy's own screensaver. Install with `cd omarchy && ./install.sh`; see [omarchy/README.md](omarchy/README.md) (Chinese).

## Install

**A normal install needs neither Xcode nor any other developer tools.** A prebuilt universal bundle
(Apple Silicon + Intel, ad-hoc signed) is published under
[Releases](https://github.com/jokerlee/shader-screensavers/releases).

```bash
gh auth login                                   # private repository: log in with an account that has access (jokerlee)
gh repo clone jokerlee/shader-screensavers
cd shader-screensavers
./install.sh
```

`install.sh`:

1. Checks that the Mac runs macOS 13 or later.
2. Downloads `ShaderMix.zip` from the latest release with `gh release download`.
3. Backs up any previous version to `~/Library/Screen Savers/ShaderMix.saver.backup` and installs into `~/Library/Screen Savers/`.
4. Removes the quarantine attribute and restarts the screen saver process.
5. Opens System Settings → Screen Saver, where you pick **Shader Mix** under Other.

| Usage | What it does |
|---|---|
| `./install.sh` | download the latest release and install it (default) |
| `./install.sh --zip <path>` | install a `ShaderMix.zip` you already have (a downloaded release asset, or the output of `package.sh`) |
| `./install.sh --build` | build from source and install; needs only the Command Line Tools: `xcode-select --install` |
| `./install.sh --no-open` | do not open System Settings afterwards (combinable with the other options) |
| `./install.sh --uninstall` | move the installed screen saver to the Trash |

Building from source:

- No Xcode and no offline Metal compiler are needed: the shaders ship as Metal source and are compiled by the GPU driver when the screen saver loads.
- The GLSL → Metal translators glslang and spirv-cross are optional. If installed (`brew install glslang spirv-cross`) the GLSL is translated again; otherwise the pre-translated files in `shader-mix/saver/generated/` are used.
- To publish a release: `./shader-mix/saver/package.sh` writes `dist/ShaderMix.zip` (not versioned); upload it as a release asset.

## Settings (`shader-mix/saver/configure.sh`)

`./shader-mix/saver/configure.sh <key> <value>` changes the default in `Info.plist`, rebuilds from source, installs, and restarts the screen saver process (needs the Command Line Tools). Run it without arguments to see the current values and the available shaders.

| Key | Default | Meaning |
|---|---|---|
| `shaders` | all thirteen | shaders to play, comma-separated; keys are listed with each shader below |
| `segmentSeconds` | 20 | how long each shader plays (seconds) |
| `transitionSeconds` | 2 | transition length (seconds) |
| `transitions` | `fade,dissolve,radial,clock` | transitions to pick from at random (all by default) |
| `startTimeJitter` | 30 | each segment starts at a random point in the first 30 seconds of the shader's timeline |
| `framesPerSecond` | 30 | frame rate cap |
| `renderScale` | 1.0 | shader pixels per point; the text is always native resolution |
| `maxRenderPixels` | 2073600 | per-screen cap on shader pixels (1920×1080) |
| `showCode` | true | show the code overlay |
| `codeOpacity` | 0.9 | text opacity |
| `codeHalo` | 0.85 | strength of the dark outline/halo behind the text (stronger over bright areas) |
| `codeScale` | 1.0 | text size multiplier (code is about 1/80 of the screen height, the title about 2.7x that) |
| `logStats` | false | log frame rate and GPU time to the system log every 10 seconds and per transition |

Examples:

```bash
./shader-mix/saver/configure.sh segmentSeconds 30
./shader-mix/saver/configure.sh shaders flowingwires,singularity,balatroswirl
./shader-mix/saver/configure.sh transitions dissolve,radial
./shader-mix/saver/configure.sh showCode false
```

## Shaders

The screenshots show the full screen on a MacBook (1728×1117 points). The code in the corner is sharp at native resolution but too small to read once scaled down, so each shader below also lists the same code as text.

### Flowing Wires

![Flowing Wires](docs/screenshots/flowingwires.jpg)

- Author: kishimisu
- Original: https://www.shadertoy.com/view/DsBczR
- Licence: CC BY-NC-SA 4.0
- Settings key: `flowingwires`

A 3D truchet of tori, ray-marched in 28 steps, with neon lines flowing along the wires. The original packs its logic into a macro full of comma expressions, which was rewritten by hand as a function with the same math and evaluation order.

```glsl
#define r(a) mat2(cos(a + vec4(0,33,11,0)))
// ...
for (O *= i, F += F - R.xy; i++ < 28.;          // raymarch for 28 iterations
    p = t * normalize(vec3(F*r(t*.1), R.y)),    // ray position
    p.zx *= r(T/4.), p.zy *= r(T/3.), p.x += T, // camera movement
    t += min(min(s( p = fract(p) - .5 ),        // distance to torus + color (x3)
                 s( vec3(-p.y, p.zx)  )),
                 s( -p.zxy            ))
);
```

### Starship

![Starship](docs/screenshots/starship.jpg)

- Author: Xor (@XorDev)
- Original: https://www.shadertoy.com/view/l3cfW4
- Licence: not stated, so Shadertoy's default CC BY-NC-SA 3.0
- Settings key: `starship`

Fifty glowing debris particles with long trails, inspired by the debris of SpaceX's seventh Starship test. It samples one of Shadertoy's built-in noise textures, which is bundled with the screen saver.

```glsl
for(float t=iTime, T=.1*t+p.y, i; i++<50.;
    S += (cos(W=sin(i)*C)+1.)
    * exp(sin(i+i*T))
    / length(max(p,
        p / vec2(2,texture(iChannel0, p/exp(W.x)+vec2(i,t)/8.)*40.))
    ) / 1e4)
    p+=.02*cos(i*(C.xz+8.+i)+T+T);
// ...
O = tanh(p.x*--C+S*S);
```

### fractal pyramid

![fractal pyramid](docs/screenshots/fractalpyramid.jpg)

- Author: bradjamesgrant
- Original: https://www.shadertoy.com/view/tsXBzS
- Licence: not stated, so CC BY-NC-SA 3.0
- Settings key: `fractalpyramid`

A distance field folded and rotated eight times, ray-marched with accumulated glow: a spinning neon pyramid of fragments.

```glsl
float map(vec3 p){
    for( int i = 0; i<8; ++i){
        float t = iTime*0.2;
        p.xz =rotate(p.xz,t);
        p.xy =rotate(p.xy,t*1.89);
        p.xz = abs(p.xz);
        p.xz-=.5;
    }
    return dot(sign(p),p)/5.;
}
// ...
col+=palette(length(p)*.1)/(400.*(d));
```

### Simplicity

![Simplicity](docs/screenshots/simplicity.jpg)

- Author: JoshP
- Original: https://www.shadertoy.com/view/lslGWr
- Licence: not stated, so CC BY-NC-SA 3.0
- Settings key: `simplicity`

Kali's abs(p)/dot(p,p) fractal formula iterated 32 times, accumulating brightness from how much each step changes; it looks like nebula clouds.

```glsl
for (int i = 0; i < 32; ++i) {
    float mag = dot(p, p);
    p = abs(p) / mag + vec3(-.5, -.4, -1.5);
    float w = exp(-float(i) / 7.);
    accum += w * exp(-strength * pow(abs(mag - prev), 2.3));
    tw += w;
    prev = mag;
}
// ...
fragColor = mix(.4, 1., v) * vec4(1.8 * t * t * t, 1.4 * t * t, t, 1.0);
```

### Singularity

![Singularity](docs/screenshots/singularity.jpg)

- Author: Xor (@XorDev)
- Original: https://www.shadertoy.com/view/3csSWB
- Licence: not stated, so CC BY-NC-SA 3.0
- Settings key: `singularity`

Coordinates are put in perspective, spun into a spiral and layered with waves, giving a whirling black hole with an accretion disk. The original is 381 characters.

```glsl
c = p * mat2(1, 1, d/(.1 + i/dot(b,b))),
v = c * mat2(cos(.5*log(a=dot(c,c)) + iTime*i + vec4(0,33,11,0)))/i,
// ...
for(; i++<9.; w += 1.+sin(v) )
    v += .7* sin(v.yx*i+iTime) / i + .5;
// ...
O = 1. - exp( -exp( c.x * vec4(.6,-.4,-1,0) )
               /  w.xyyx
               / ( 2. + i*i/4. - i )
               / ( .5 + 1. / a )
               / ( .03 + abs( length(p)-.7 ) ) );
```

### Ether

![Ether](docs/screenshots/ether.jpg)

- Author: nimitz
- Original: https://www.shadertoy.com/view/MsjSW3
- Licence: CC BY-NC-SA 3.0
- Settings key: `ether`

A volumetric ray march of only six steps through a distance field perturbed by nested sines: a glowing, drifting fluid.

```glsl
float map(vec3 p){
    p.xz*= m(t*0.4);p.xy*= m(t*0.3);
    vec3 q = p*2.+t;
    return length(p+vec3(sin(t*0.7)))*log(length(p)+1.) + sin(q.x+sin(q.z+sin(q.y)))*0.5 - 1.;
}
// ...
    float rz = map(p);
    float f =  clamp((rz - map(p+.1))*0.5, -.1, 1. );
    vec3 l = vec3(0.1,0.3,.4) + vec3(5., 2.5, 3.)*f;
    cl = cl*l + smoothstep(2.5, .0, rz)*.7*l;
```

### Path to the colorful infinity

![Path to the colorful infinity](docs/screenshots/colorfulinfinity.jpg)

- Author: Benoit Marini (benoitM)
- Original: https://www.shadertoy.com/view/WtjyzR
- Licence: CC BY-NC-SA 3.0
- Settings key: `colorfulinfinity`

A 4D point is repeatedly inverted in the unit sphere, shifted and folded (a Kaliset fractal); 17 slices zoom in on a loop, making an endless tunnel. o/dot(o,o) is written as o*(1./dot(o,o)): the same picture, about 8x faster.

```glsl
for (int i=0 ; i++ < ITER;) o.xzyw = abs(o/dot(o,o)- dec);
// ...
for(float i=0.; i<=1.; i+=1./NUM_LAYERS)
{
    float d = fract(i+t); // depth
    float s = mix(5.,.5,d); // scale
    float f = d * smoothstep(1.,.9,d); //fade
    col+= tex(vec3(uv*s,i*4.)).xyz*f;
}
```

### Balatro background

![Balatro background](docs/screenshots/balatroswirl.jpg)

- Author: LocalThunk (the game), ported by xxidbr9
- Original: https://www.shadertoy.com/view/XXtBRr · https://github.com/xxidbr9/balatro-effect-recreate · https://www.playbalatro.com
- Licence: **no licence: personal use only, not for distribution**
- Settings key: `balatroswirl`

The background of the game Balatro: pixelated, swirled in polar coordinates, distorted by five rounds of sin/cos into a paint-like flow, then mixed between three colours.

```glsl
float new_pixel_angle = atan(uv.y, uv.x) + speed
    - SPIN_EASE*20.*(SPIN_AMOUNT*uv_len + (1. - SPIN_AMOUNT));
// ...
for (int i=0; i < 5; i++) {
    uv2 += sin(max(uv.x, uv.y)) + uv;
    uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),
                    sin(uv2.x - 0.113*speed));
    uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
}
float paint_res = min(2., max(0., length(uv)*(0.035)*contrast_mod));
```

The last five are the originals behind MasterYeeeee's breakdown videos on Xiaohongshu. Four are SamuelYAN's p5.js fragment shaders on OpenProcessing, converted to Shadertoy's mainImage: coordinates follow p5.js at pixelDensity 2 (Retina); the sketches are composed for an 11:16 portrait canvas, so they are zoomed around the centre to fill a landscape screen (factor set by eye at 16:10, more on wider screens). Each was checked pixel by pixel against the original code rendered in a browser.

### Shader_240422-4

![Shader_240422-4](docs/screenshots/spiraliris.jpg)

- Author: SamuelYAN (@samuelyan)
- Original: https://openprocessing.org/sketch/2247937
- Licence: CC BY-NC-SA
- Settings key: `spiraliris`

Liquid iridescence flung out of a logarithmic spiral: log-polar coordinates twisted and rotated into liquid-metal colour bands.

```glsl
vec2 uv = (gl_FragCoord.xy-1.0*u_resolution.xy)/u_resolution.y;
float a = atan(uv.y, uv.x);
float r = log(length(uv));
a = 2. *a;
// ...
uv = rot(uv, u_time +  2. * a + 6.1415 * sin(3. * r + a - u_time));
float s = arrow(uv);
// ...
col *= smoothstep(0.,0.1,2.25-length(uv));
col = mix(col, vec3(1, .93, .92)*2., smoothstep(0., 3.5, -r));
```
### untitled 2026_0203_3

![untitled 2026_0203_3](docs/screenshots/membrane.jpg)

- Author: SamuelYAN (@samuelyan)
- Original: https://openprocessing.org/sketch/2862539
- Licence: CC BY-NC-SA
- Settings key: `membrane`

Light dancing inside a cell membrane: 64 spotlights turning in a warped space, held by a membrane mask that breathes with a "life" state.

```glsl
vec2 pw = warp(p);
// ...
float ang = u_time * 0.4 + hash(seed) * 6.28318;
vec2 dir  = vec2(cos(ang), sin(ang));
// ...
col += lc * light * flicker * pulse;
// ...
float mask = smoothstep( 0.03, -0.03, blob(pw, 0.85, life) );
col /= mask;
col -= smoothstep(0.2, 0.6, length(pw)) * 0.8;
```
### 2026_0131

![2026_0131](docs/screenshots/motes.jpg)

- Author: SamuelYAN (@samuelyan)
- Original: https://openprocessing.org/sketch/2860882
- Licence: CC BY-NC-SA
- Settings key: `motes`

Sixteen motes attracting each other: cohesion, alignment and separation of 16 pseudo-boids form a field drawn as glowing, merging outlines. Its colour sibling GENUARY 2026_0131 (openprocessing.org/sketch/2860834) is not included.

```glsl
for(int i = 0; i < BOIDS; i++){
    // ...
    float w = exp(-d * 6.0);
    cohesion += bp * w;
    alignment += bv * w;
    separation += normalize(p - bp) * w / (d + .75) * 3.;
    // ...
}
vec2 v =
      .2 * (cohesion - p)   // cohesion
    + 1.6 * alignment       // alignment
    + .4 * separation;     // separation
```
### GENUARY 2026_0120

![GENUARY 2026_0120](docs/screenshots/hiddenline.jpg)

- Author: SamuelYAN (@samuelyan)
- Original: https://openprocessing.org/sketch/2851315
- Licence: CC BY-NC-SA
- Settings key: `hiddenline`

The hidden line: 32 spotlights locked to the grid diagonal flicker and breathe under a vignette, forming a soft glowing sphere.

```glsl
for (int i = 0; i < NUM_LIGHTS; i++) {
    // ...
    vec2 lightPos = (vec2(gx, gy) + 0.5) / GRID;
    lightPos = lightPos * 2.0 - 1.0;
    // ...
    float light = spotlight(p, lightPos, dir, coneAngle, softness);
    // ...
}
float vignette = smoothstep(1.25, 0.75, length(p));
col -= vignette * 1.25;
```
### Yet Another 4D Apollonian

![Yet Another 4D Apollonian](docs/screenshots/apollonian4d.jpg)

- Author: mrange
- Original: https://www.shadertoy.com/view/N3VXz1
- Licence: CC0
- Settings key: `apollonian4d`

The four-dimensional riddle: a 4D Apollonian fractal rotated in three planes and projected, ray-marched with accumulated glow.

```glsl
// ...
    ; p=abs(p/s)
    , d=min(length(p.xy)+3e-4,min(p.z,p.w)+3e-3)
    , p=e*e+3.+3.*cos(13.*dot(o.xy,o.zw)+vec4(2,7,0,4))
    , O+=p.w/(7.*e*e*e*d+d)*exp(-z*z*.5)*p
    , z+=.6*d+1e-3
    )
    for(s=d=1.;++d<7.;s*=e)
      p-=2.*round(p*.5)
    , p*=e=2./dot(p,p)
```

## Layout

| Path | Contents |
|---|---|
| `install.sh` | one-step install and uninstall |
| `shader-mix/saver/` | screen saver source: `ShaderMixView.swift`, `Info.plist`, `build.sh`, `package.sh`, `configure.sh`, `README.md` |
| `shader-mix/saver/shaders/` | each shader's GLSL (`<key>.glsl`), the excerpt shown on screen (`<key>.excerpt.glsl`), `manifest.json` (titles, authors, licences) |
| `shader-mix/saver/generated/` | pre-translated Metal shaders, used when glslang and spirv-cross are not installed |
| `shader-mix/saver/tools/` | `gen_metal.py` (GLSL → Metal), `make_sources.py` (sources from the Shadertoy JSON), `transition_demo/` (renders the transition animations) |
| `shader-mix/reference/` | the originals rendered in a browser, used to check the ports |
| `common/CodeText.swift` | the code overlay: text mask layout and GPU shading |
| `candidates/` | the original Shadertoy JSON of the 24 shaders considered, measured GPU cost, an overview image and the measuring tools; `candidates/xhs/` holds the Xiaohongshu-sourced candidates (OpenProcessing source, converted GLSL, browser reference renders) |
| `docs/screenshots/` | screenshots and transition animations for the READMEs |

## Credits and licences

Every shader belongs to its author; this repository is a port for personal study and use:

- The works by kishimisu, Xor, bradjamesgrant, JoshP, nimitz, Benoit Marini and mrange come from Shadertoy; SamuelYAN's come from OpenProcessing.
  - They are CC BY-NC-SA 3.0 or 4.0; where the author states nothing, Shadertoy's default CC BY-NC-SA 3.0 applies.
  - That means attribution, no commercial use, and derivatives under the same licence.
- The Balatro background shader is by LocalThunk, from the game Balatro, ported by xxidbr9.
  - It has no open licence; it is here for personal use only and must not be published or distributed.
- SamuelYAN's four OpenProcessing sketches are CC BY-NC-SA; mrange's Yet Another 4D Apollonian is CC0.
- The noise texture used by Starship is one of Shadertoy's built-in textures.
- Authors and licences of the other shaders in `candidates/src` are listed in `candidates/README.md`.
- The ports, the screen saver framework and the tools are for personal use only.
