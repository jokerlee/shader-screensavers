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
