// ...
    ; p=abs(p/s)
    , d=min(length(p.xy)+3e-4,min(p.z,p.w)+3e-3)
    , p=e*e+3.+3.*cos(13.*dot(o.xy,o.zw)+vec4(2,7,0,4))
    , O+=p.w/(7.*e*e*e*d+d)*exp(-z*z*.5)*p
    , z+=.6*d+1e-3
    )
    for(s=d=1.;++d<7.;s*=e)
      p-=2.*round(p*.5)
    , p*=e=2./dot(p,p)
