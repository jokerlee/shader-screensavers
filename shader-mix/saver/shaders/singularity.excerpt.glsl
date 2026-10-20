c = p * mat2(1, 1, d/(.1 + i/dot(b,b))),
v = c * mat2(cos(.5*log(a=dot(c,c)) + iTime*i + vec4(0,33,11,0)))/i,
// ...
for(; i++<9.; w += 1.+sin(v) )
    v += .7* sin(v.yx*i+iTime) / i + .5;
// ...
O = 1. - exp( -exp( c.x * vec4(.6,-.4,-1,0) )
               /  w.xyyx
               / ( 2. + i*i/4. - i )
               / ( .5 + 1. / a )
               / ( .03 + abs( length(p)-.7 ) ) );
