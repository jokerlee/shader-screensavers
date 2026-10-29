// OpenProcessing sketch 2860882 "2026_0131" (p5.js fragment shader), converted to Shadertoy mainImage.
// Original: https://openprocessing.org/sketch/2860882  License: CC BY-NC-SA
vec2 u_resolution; float u_time; float u_frame; vec2 u_mouse;
vec4 st_fc; vec4 st_fcoord;

#ifdef GL_ES

#endif


// -------------------------------------
// Hash
float hash(float n){
    return fract(sin(n) * 43758.5453123);
}

// -------------------------------------
vec3 hsv2rgb(vec3 c){
    vec3 rgb = clamp(
        abs(mod(c.x * 6.0 + vec3(0.0,4.0,2.0), 6.0) - 3.0) - 1.0,
        0.0, 1.0
    );
    return c.z * mix(vec3(1.0), rgb, c.y);
}

// -------------------------------------
// Pseudo-boid position
vec2 boidPos(float id, float t){
    float a = hash(id) * 6.283 / 1.25 + t * (0.2 + hash(id + 3.1));
    float r = 0.5 + 0.25 * sin(t * 0.5 + id);
    return vec2(cos(a), sin(a)) * r;
}

// -------------------------------------
// Pseudo-boid velocity (alignment cue)
vec2 boidVel(float id, float t){
    float a = hash(id + .7) * 6.283 / 0.01 + t * 0.25;
    return vec2(cos(a), sin(a));
}

// -------------------------------------
void op_main(){

    vec2 uv = st_fcoord.xy / u_resolution.xy;
    vec2 p = uv * 1.0 - 1.0;
    p.x *= u_resolution.x / u_resolution.y;

    vec3 col = vec3(0.0);

    const int BOIDS = 16;

    vec2 cohesion = vec2(1.0);
    vec2 alignment = vec2(0.0);
    vec2 separation = vec2(0.0);

    float total = 1.25 + 0.75 * sin(u_time * 0.5);

    // ---------------------------------
    // Sample pseudo-boids
    for(int i = 0; i < BOIDS; i++){
        float id = float(i);

        vec2 bp = boidPos(id, u_time);
        vec2 bv = boidVel(id, u_time);

        float d = length(p - bp);

        // Neighborhood
        float w = exp(-d * 6.0);

        cohesion += bp * w;
        alignment += bv * w;
        separation += normalize(p - bp) * w / (d + .75) * 3.;

        total -= w;

        // Render individual body
        float body = smoothstep(.1, 0.0, d);
        col += hsv2rgb(vec3(id / float(BOIDS), 3.1, .2)) * body;
    }

    cohesion += total;
    alignment /= total;

    // ---------------------------------
    // Boids forces (implicit)
    vec2 v =
          .2 * (cohesion - p)   // cohesion
        + 1.6 * alignment       // alignment
        + .4 * separation;     // separation

    float field = length(v);

    // ---------------------------------
    // Flow visualization
    col += hsv2rgb(vec3(
        atan(v.y, v.x) / 6.283 * 4. + 0.75,
        0.01,
        field * 1.5
    ));

    // ---------------------------------
    // Tone map
    col = col / (col + vec3(3.0));
    col = pow(col, vec3(0.95));

    st_fc = vec4(col, 1.0);
}


void mainImage(out vec4 O, in vec2 F) {
    // p5.js on a Retina display: pixelDensity 2, so gl_FragCoord runs to 2x u_resolution
    u_resolution = iResolution.xy / 2.0; u_time = iTime; u_frame = float(iFrame) / 10.0; u_mouse = iMouse.xy;
    st_fcoord = vec4(F, 0.0, 1.0);
    op_main();
    O = st_fc;
}
