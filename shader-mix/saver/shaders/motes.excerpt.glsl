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
