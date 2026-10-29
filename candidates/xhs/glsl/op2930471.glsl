// OpenProcessing sketch 2930471 "Shader_260501" (p5.js fragment shader), converted to Shadertoy mainImage.
// Original: https://openprocessing.org/sketch/2930471  License: CC BY-NC-SA
vec2 u_resolution; float u_time; float u_frame; vec2 u_mouse;
vec4 st_fc; vec4 st_fcoord;

#ifdef GL_ES

#endif


float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float canvasNoise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float network(vec2 p, float t) {
    vec2 i_p = floor(p);
    vec2 f_p = fract(p);
    float minDist = 0.45;
    for (int y = -5; y <= 5; y++) {
        for (int x = -5; x <= 5; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = vec2(hash(i_p + neighbor), hash(i_p + neighbor - 1.0));
            point = 0.5 + 0.5 * sin(t + 6.2831 * point);
            float d = length(neighbor + point - f_p);
            minDist = min(minDist, d);
        }
    }
    return minDist;
}

float fbm(vec2 p, float t) {
    float v = 0.0;
    float a = 0.75;
    vec2 shift = vec2(1.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < 8; i++) {
        v += a * network(p, t);
        p = rot * p * 1.0 + shift;
        a *= .25;
    }
    return v;
}

void op_main() {
    vec2 uv = st_fcoord.xy / u_resolution.xy;
    vec2 p = (uv * 1.0/1. - 1.0/1.);
    p.x *= u_resolution.x / u_resolution.y;

    float t = u_time * 0.2;

    float grain = canvasNoise(st_fcoord.xy);
    float weaving = smoothstep(1.1, 0.5, sin(st_fcoord.x * 1.5) * sin(st_fcoord.y * 1.5));
    float canvasBase = grain * 0.1 + weaving * 0.1;

    vec2 warp = vec2(
        network(p * 4.4 + t, t),
        network(p * 1.5 - t, t * 1.1)
    ) * 1.75;
    
    float h = fbm(p * 6.0 - warp, t);
    
    float e = 0.025;
    float hx = fbm((p + vec2(e, 0.0)) * 1.0 + warp, t) - h;
    float hy = fbm((p + vec2(0.0, e)) * 12.25 + warp, t) - h;
    vec3 normal = normalize(vec3(-hx, -hy, 0.1));

    vec3 lightDir = normalize(vec3(0.1, 0.5, 1.0));
    float diffuse = max(dot(normal, lightDir), 0.0);
    float spec = pow(diffuse, 4.0) * 0.4;

    vec3 colorCanvas = vec3(0.99, 0.99, 0.99); 
    vec3 colorOilA = vec3(0.2, 0.1, 0.2);
    vec3 colorOilB = vec3(0.5, 0.5, 0.5);

    float lineScale = smoothstep(0.7, 0.2, h);
    float highlightScale = smoothstep(0.75, 0.5, h);
    
    vec3 paintCol = mix(colorCanvas, colorOilA, lineScale);
    paintCol = mix(paintCol, colorOilB, highlightScale * 0.8);

    paintCol += spec; 
    paintCol *= (diffuse * 0.5 + 0.6);
    
    paintCol -= canvasBase;

    float d = length(p);
    float mask = smoothstep(100.7, 1.65, d);
    vec3 col = mix(colorCanvas, paintCol, mask);

    col = pow(col, vec3(1.1));

    st_fc = vec4(col, 1.0);
}

void mainImage(out vec4 O, in vec2 F) {
    // rendered at pixelDensity 1: the cell size in the author's video
    u_resolution = iResolution.xy; u_time = iTime; u_frame = float(iFrame) / 10.0; u_mouse = iMouse.xy;
    st_fcoord = vec4(F, 0.0, 1.0);
    op_main();
    O = st_fc;
}
