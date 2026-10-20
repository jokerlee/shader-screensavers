for(float t=iTime, T=.1*t+p.y, i; i++<50.;
    S += (cos(W=sin(i)*C)+1.)
    * exp(sin(i+i*T))
    / length(max(p,
        p / vec2(2,texture(iChannel0, p/exp(W.x)+vec2(i,t)/8.)*40.))
    ) / 1e4)
    p+=.02*cos(i*(C.xz+8.+i)+T+T);
// ...
O = tanh(p.x*--C+S*S);
