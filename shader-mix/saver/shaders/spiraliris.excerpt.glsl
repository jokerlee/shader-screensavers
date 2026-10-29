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
