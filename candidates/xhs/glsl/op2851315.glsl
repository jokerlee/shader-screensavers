// OpenProcessing sketch 2851315 "GENUARY 2026_0120" (p5.js fragment shader), converted to Shadertoy mainImage.
// Original: https://openprocessing.org/sketch/2851315  License: CC BY-NC-SA
vec2 u_resolution; float u_time; float u_frame; vec2 u_mouse;
vec4 st_fc; vec4 st_fcoord;

#ifdef GL_ES

#endif


// --------------------------------------------------
// Hash
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// --------------------------------------------------
// HSV → RGB
vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(
        abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0,
        0.0, 1.0
    );
    return c.z * mix(vec3(1.0), rgb, c.y);
}

// --------------------------------------------------
// Spotlight
float spotlight(
    vec2 p,
    vec2 lightPos,
    vec2 dir,
    float coneAngle,
    float softness
){
    vec2 L = normalize(p - lightPos);
    float theta = dot(L, normalize(dir));
    float dist = length(p - lightPos);

    float att = 2.0 / (1.0 + 3.0 * dist * dist);

    float inner = cos(radians(coneAngle * 0.125));
    float edge  = inner - softness;

    float cone = smoothstep(edge, inner, theta);
    return cone * att;
}

// --------------------------------------------------
void op_main() {

    // --------------------------------------------------
    // Normalized space
    // --------------------------------------------------
    vec2 uv = st_fcoord.xy / u_resolution.xy;
    vec2 p  = uv * 1.5 - 1.5;
    p.x *= u_resolution.x / u_resolution.y;

    // --------------------------------------------------
    // 16x16 grid space
    // --------------------------------------------------
    const float GRID = 64.0;

    vec2 gp = p * 0.5 + 0.5;          // [-1,1] → [0,1]
    vec2 cell = floor(gp * GRID);     // cell id 0~15

    // --------------------------------------------------
    // Background
    // --------------------------------------------------
    vec3 col = vec3(
        0.25 + 0.15 * sin(u_time * 0.3),
        0.8,
        0.1
    );

    const int NUM_LIGHTS = 32;

    float globalPulse = 0.5 + 0.25 * sin(u_time * 0.6);
    float align       = smoothstep(0.5, 1.0, sin(u_time * 0.2));
    float harmony     = 0.5 + 0.5 * sin(u_time * 0.05);

    // --------------------------------------------------
    // Lights
    // --------------------------------------------------
    for (int i = 0; i < NUM_LIGHTS; i++) {

        float fi   = float(i);
        float seed = fi * 19.345;

        // --------------------------------------------------
        // MAP 16 LIGHTS → 16x16 GRID POSITIONS
        // --------------------------------------------------
        // Each light chooses one grid cell (static but harmonic)
        float gx = mod(fi * 5.0, GRID);
        float gy = mod(fi * 5.0, GRID);

        // subtle drift but locked to grid
        vec2 jitter = 0.1 * vec2(
            sin(u_time * 0.3 + seed),
            cos(u_time * 0.27 + seed)
        );

        // cell center → normalized space
        vec2 lightPos = (vec2(gx, gy) + 0.5) / GRID;
        lightPos = lightPos * 2.0 - 1.0;
        lightPos += jitter * (.1 / GRID);

        lightPos.x *= u_resolution.x / u_resolution.y;

        // --------------------------------------------------
        // DIRECTION: radial, breathing
        // --------------------------------------------------
        float angle = u_time * 0.5 + hash(seed) * 6.28318;
        vec2 dir = vec2(cos(angle), sin(angle));

        // --------------------------------------------------
        // Spotlight shape
        // --------------------------------------------------
        float coneAngle = mix(0.5, 0.2, hash(seed + 18.0));
        float softness  = mix(2., .5, hash(seed + 9.0));

        float light = spotlight(p, lightPos, dir, coneAngle, softness);

        // --------------------------------------------------
        // Color
        // --------------------------------------------------
        float hueBase  = hash(seed + 10.0);
        float hueSpeed = 0.05 + 0.025 * hash(seed + 20.0);

        float hue = fract(
            mix(hueBase, harmony, 0.25) +
            u_time * hueSpeed * 0.25
        );

        vec3 lightColor = hsv2rgb(vec3(hue, 0.99, 1.0));

        // --------------------------------------------------
        // Flicker
        // --------------------------------------------------
        float flicker =
            0.5 +
            0.15 * sin(u_time * (1.7 + hash(seed + 4.5)) + fi) +
            0.5 * sin(u_time * 3.1 + seed);

        // --------------------------------------------------
        // Combine
        // --------------------------------------------------
        col += lightColor
             * light
             * globalPulse
             * flicker
             * mix(1.0, 2.15, align);
    }

    // --------------------------------------------------
    // Vignette
    // --------------------------------------------------
    float vignette = smoothstep(1.25, 0.75, length(p));
    col -= vignette * 1.25;

    // --------------------------------------------------
    // Tone mapping & gamma
    // --------------------------------------------------
    col = col / (col + vec3(1.0));
    col = pow(col, vec3(0.9));

    st_fc = vec4(col, 1.0);
}

void mainImage(out vec4 O, in vec2 F) {
    // p5.js on a Retina display: pixelDensity 2, so gl_FragCoord runs to 2x u_resolution
    u_resolution = iResolution.xy / 2.0; u_time = iTime; u_frame = float(iFrame) / 10.0; u_mouse = iMouse.xy;
    st_fcoord = vec4(F, 0.0, 1.0);
    op_main();
    O = st_fc;
}
