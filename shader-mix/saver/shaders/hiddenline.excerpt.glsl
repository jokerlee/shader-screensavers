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
