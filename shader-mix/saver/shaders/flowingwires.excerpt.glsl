#define r(a) mat2(cos(a + vec4(0,33,11,0)))
// ...
for (O *= i, F += F - R.xy; i++ < 28.;          // raymarch for 28 iterations
    p = t * normalize(vec3(F*r(t*.1), R.y)),    // ray position
    p.zx *= r(T/4.), p.zy *= r(T/3.), p.x += T, // camera movement
    t += min(min(s( p = fract(p) - .5 ),        // distance to torus + color (x3)
                 s( vec3(-p.y, p.zx)  )),
                 s( -p.zxy            ))
);
