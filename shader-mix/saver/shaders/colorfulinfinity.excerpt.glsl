for (int i=0 ; i++ < ITER;) o.xzyw = abs(o/dot(o,o)- dec);
// ...
for(float i=0.; i<=1.; i+=1./NUM_LAYERS)
{
    float d = fract(i+t); // depth
    float s = mix(5.,.5,d); // scale
    float f = d * smoothstep(1.,.9,d); //fade
    col+= tex(vec3(uv*s,i*4.)).xyz*f;
}
