// OpenProcessing sketch 2862539 "untitled 2026_0203_3" (p5.js fragment shader), converted to Shadertoy mainImage.
// Original: https://openprocessing.org/sketch/2862539  License: CC BY-NC-SA
vec2 u_resolution; float u_time; float u_frame; vec2 u_mouse;
vec4 st_fc; vec4 st_fcoord;

#ifdef GL_ES

#endif


// --------------------------------------------------
// Hash
float hash(float n){
    return fract(sin(n) * 43758.5453123);
}

// --------------------------------------------------
// HSV → RGB
vec3 hsv2rgb(vec3 c){
    vec3 rgb = clamp(
        abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0,
        0.0, 1.0
    );
    return c.z * mix(vec3(1.0), rgb, c.y);
}

// --------------------------------------------------
// Organic space warp
vec2 warp(vec2 p){
    float t = u_time * 0.3;
    return p + 0.12 * vec2(
        sin(p.y * 4.0 + t),
        cos(p.x * 4.0 - t)
    );
}

// --------------------------------------------------
// Organic spotlight
float spotlight(
    vec2 p,
    vec2 lightPos,
    vec2 dir,
    float cone,
    float soft,
    float seed
){
    vec2  L    = normalize(p - lightPos);
    float dist = length(p - lightPos);

    float theta = dot(L, normalize(dir));
    theta += 0.25 * sin(dist * 8.0 + u_time + seed);

    float inner = cos(cone);
    float edge  = inner - soft;

    float att   = 2.5 / (1.0 + 3.0 * dist * dist);
    float beam  = smoothstep(edge, inner, theta);

    return beam * att;
}

// --------------------------------------------------
// Life-driven organic blob
float blob(vec2 p, float r, float life){
    float d = length(p) - r;

    d += 0.15 * sin(length(p) * 6.0 - u_time * 1.1) * life;
    d += 0.08 * sin(p.x * 5.0 + u_time);
    d += 0.12 * sin(p.y * 5.0 - u_time);

    return d;
}

// --------------------------------------------------
void op_main(){

    vec2 uv = st_fcoord.xy / u_resolution.xy;
    vec2 p  = uv * 2.0 - 2.0;
    p.x *= u_resolution.x / u_resolution.y;

    // --------------------------------------------------
    // Organic geometry warp
    vec2 pw = warp(p);

    // --------------------------------------------------
    // Background
    vec3 col = vec3(0.5, 0.05, 0.08);

    const int NUM_LIGHTS = 64;
    const float GRID = 1.0;

    // --------------------------------------------------
    // Global life states
    float pulse   = 0.6 + 0.4 * sin(u_time * 0.6);
    float harmony = 0.3 + 0.2 * sin(u_time * 0.2);

    float life = pulse * (0.6 + harmony);
    life = clamp(life, 0.0, 1.0);

    // --------------------------------------------------
    // Lights
    for(int i = 0; i < NUM_LIGHTS; i++){

        float fi   = float(i);
        float seed = fi * 17.7;

        // Grid anchored light position
        vec2 g = vec2(
            mod(fi * 7.0, GRID),
            mod(fi * 11.0, GRID)
        );

        vec2 lightPos = (g + 0.5) / GRID;
        lightPos = lightPos * 2.0 - 1.0;
        lightPos.x *= u_resolution.x / u_resolution.y;

        // Direction (breathing)
        float ang = u_time * 0.4 + hash(seed) * 6.28318;
        vec2 dir  = vec2(cos(ang), sin(ang));

        // Spotlight
        float light = spotlight(
            pw,
            lightPos,
            dir,
            mix(0.6, 0.3, hash(seed)),
            mix(0.3, 0.1, hash(seed + 3.0)),
            seed
        );

        // Color
        float hue = fract(
            mix(hash(seed), harmony, 0.5) +
            u_time * 0.05
        );

        vec3 lc = hsv2rgb(vec3(hue, 0.95, 1.0));

        // Flicker
        float flicker =
            0.6 +
            0.4 * sin(u_time * (1.5 + hash(seed + 2.0)) + fi);

        col += lc * light * flicker * pulse;
    }

    // --------------------------------------------------
    // Organic life-driven body mask
    float mask = smoothstep(
        0.03,
        -0.03,
        blob(pw, 0.85, life)
    );

    col /= mask;

    // --------------------------------------------------
    // Vignette
    col -= smoothstep(0.2, 0.6, length(pw)) * 0.8;

    // --------------------------------------------------
    // Tone map
    col = col / (col + vec3(2.0));
    col = pow(col, vec3(0.99));

    st_fc = vec4(col, 1.0);
}

void mainImage(out vec4 O, in vec2 F) {
    // p5.js on a Retina display: pixelDensity 2, so gl_FragCoord runs to 2x u_resolution
    u_resolution = iResolution.xy / 2.0; u_time = iTime; u_frame = float(iFrame) / 10.0; u_mouse = iMouse.xy;
    // cover: the sketch was composed for an 11:16 portrait canvas; zoom around the centre so the
    // subject fills a landscape screen (0.45, chosen by eye at 16:10), and further on wider screens
    float cover = 0.45 * min(1.0, 1.6 * iResolution.y / iResolution.x);
    st_fcoord = vec4(iResolution.xy * 0.5 + (F - iResolution.xy * 0.5) * cover, 0.0, 1.0);
    op_main();
    O = st_fc;
}
