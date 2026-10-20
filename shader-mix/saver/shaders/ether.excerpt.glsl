float map(vec3 p){
    p.xz*= m(t*0.4);p.xy*= m(t*0.3);
    vec3 q = p*2.+t;
    return length(p+vec3(sin(t*0.7)))*log(length(p)+1.) + sin(q.x+sin(q.z+sin(q.y)))*0.5 - 1.;
}
// ...
    float rz = map(p);
    float f =  clamp((rz - map(p+.1))*0.5, -.1, 1. );
    vec3 l = vec3(0.1,0.3,.4) + vec3(5., 2.5, 3.)*f;
    cl = cl*l + smoothstep(2.5, .0, rz)*.7*l;
