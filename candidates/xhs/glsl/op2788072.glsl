// OpenProcessing sketch 2788072 "Shader_251111" (p5.js fragment shader), converted to Shadertoy mainImage.
// Original: https://openprocessing.org/sketch/2788072  License: CC BY-NC-SA
vec2 u_resolution; float u_time; float u_frame; vec2 u_mouse;
vec4 st_fc; vec4 st_fcoord;

#ifdef GL_ES

#endif


float hash(float n) { return fract(sin(n) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float n = i.x + i.y*57.0;
    return mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
               mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y);
}

// fbm for fluid flow
float fbm(vec2 p) {
    float f = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        f += a * noise(p);
        p *= 2.02;
        a *= 0.5;
    }
    return f;
}

vec2 flowField(vec2 p, float t) {
    float n = fbm(p * 1.2 + t * 0.2);
    float a = n * 6.2831;
    return vec2(cos(a), sin(a));
}

vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0,
                     0.0, 1.0);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

float dustDensity(vec2 pos, float time) {
    float d = fbm(pos * 1.5 + time * 0.1);
    return d * 0.25 + 0.25;
}

float spotlightFluid(vec2 uv, vec2 lightPos, vec2 dir, float coneAngle, float softness, float time)
{
    vec2 toPix = uv - lightPos;

    // 🔸 flow field warp
    vec2 flow = flowField(uv * 1.5 + time * 0.2, time);
    toPix += flow * 0.25;

    float dist = length(toPix);
    vec2 L = normalize(toPix);

    // direction noise warp
    float theta = dot(L, normalize(dir));
    theta += 0.2 * (fbm(L * 3.0 + time * 0.3) - 0.5);

    // cone softness
    float inner = cos(radians(coneAngle * 0.125));
    float edge = inner - softness;
    float cone = smoothstep(edge, inner, theta);

    // volumetric dust
    float vol = 0.0;
    for (int i = 0; i < 8; i++) {
        float t = float(i) / 8.0;
        vec2 samplePos = lightPos + L * (t * dist);
        float density = dustDensity(samplePos * 1.5, time);
        vol += (1.0 - exp(-density * 2.0)) * (1.0 - t);
    }
    vol /= 8.0;

    float att = 1.2 / (1.0 + 1.8 * dist * dist);
    return cone * att * (0.5 + vol);
}

void op_main() {
    vec2 uv = st_fcoord.xy / u_resolution.xy;
    vec2 p = (uv - 0.5) * vec2(u_resolution.x / u_resolution.y, 1.0);

    vec3 col = vec3(0.0);
    const int NUM_LIGHTS = 12;

    for (int i = 0; i < NUM_LIGHTS; i++) {
        float fi = float(i);
        float seed = fi * 2.0;

        vec2 base = vec2(cos(fi * 0.8), sin(fi * 1.1)) * 0.6;
        vec2 lightPos = base + 0.2 * flowField(base * 1.2 + u_time * 0.3, u_time);

        float baseAngle = hash(seed + 4.0) * 6.2831;
        vec2 dir = flowField(lightPos + u_time * 0.1, u_time + baseAngle);

        float coneAngle = mix(60.0, 140.0, hash(seed + 8.0));
        float softness = 0.5 + 0.5 * hash(seed + 9.0);

        float light = spotlightFluid(p, lightPos, dir, coneAngle, softness, u_time);
        float hue = fract(hash(seed + 1.0) + 0.2 * sin(u_time * 0.3 + fi));
        vec3 lightColor = hsv2rgb(vec3(hue, 0.8, 1.0));

        col += lightColor * light;
    }

    // Tone mapping + gamma
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
