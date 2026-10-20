// Flowing Wires by @kishimisu (2023) - https://www.shadertoy.com/view/DsBczR
// CC BY-NC-SA 4.0. Hand port of the original for SPIR-V/Metal: the s(p) macro with comma
// expressions and uninitialised locals is rewritten as a function with explicit state.
// Same math, same evaluation order (the three s() calls see p in left-to-right order).

#define r(a) mat2(cos(a + vec4(0,33,11,0)))

float s(vec3 q, inout vec4 O, float t, float T) {
    q.xy += .5;
    float d = length(vec2(length(q.xy) - .5, q.z)) - .01;
    q.yx *= r(round((atan(q.y, q.x) - T) * 3.8) / 3.8 + T);
    q.x -= .5;
    O += (sin(t + T) * .1 + .1) * (1. + cos(t + T * .5 + vec4(0, 1, 2, 0)))
         / (.5 + pow(length(q) * 50., 1.3));
    return d;
}

void mainImage(out vec4 O, vec2 F) {
    vec3 p, R = iResolution;
    float t = 0., T = iTime;
    O = vec4(0);
    F += F - R.xy;
    for (float i = 0.; i++ < 28.;) {
        p = t * normalize(vec3(F * r(t * .1), R.y));
        p.zx *= r(T / 4.); p.zy *= r(T / 3.); p.x += T;
        p = fract(p) - .5;
        float d1 = s(p, O, t, T);
        float d2 = s(vec3(-p.y, p.zx), O, t, T);
        float d3 = s(-p.zxy, O, t, T);
        t += min(min(d1, d2), d3);
    }
}
