// OpenProcessing sketch 2560753 "Dissolved dreams" (p5.js fragment shader), converted to Shadertoy mainImage.
// Original: https://openprocessing.org/sketch/2560753  License: CC BY-NC-SA
vec2 u_resolution; float u_time; float u_frame; vec2 u_mouse;
vec4 st_fc; vec4 st_fcoord;

// learn from https://www.shadertoy.com/view/7lyXWz

#ifdef GL_ES

#endif




#define pi 3.14159
#define MAX_STEPS 5
#define MAX_DIST 20.0
#define SURF_DIST 0.0001

mat2 Rot(float a) {
    float s=sin(a), c=cos(a);
    return mat2(c, -s, s, c);
} 

float thc(float a, float b) {
    return tan(cos(a) * sin(b)) / tan(a);
}


float h21 (vec2 a) {
    return fract(sin(dot(a.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float mlength(vec2 uv) {
    return max(abs(uv.x), abs(uv.y));
}

float mlength(vec3 p) {
    return max(max(abs(p.y), abs(p.x)), abs(p.z));
}

vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*tan( 6.28318/1./1.25*(c*t+d) );
}

float GetDist(vec3 p) {
    float sc = 10.;
    float sc2 = 0.25;
    
    float a = atan(p.z, p.x);
    float th = atan(p.y, p.x);
    float r = length(p);//*(0.01 - p.y + p.x);
    
    float tim = 2. * a + r * 2. - u_time;
    tim += 0.051 * h21(p.xy);
    p = 1.1 * r * vec3(cos(a + tim) * cos(th+ tim), cos(a - tim) * cos(th+ tim), cos(th + tim) + cos(th + tim));
    
    vec3 ip = floor(sc2 * p) + 0.1;
    vec3 fp = fract(sc2 * p) - 0.1;
    
    
    vec3 vec = 0.25 * vec3(cos(1. * h21(ip.xy) + tim), cos(1. * h21(ip.yz) + tim), cos(10. * h21(ip.zx) + tim));
    float d0 = length(p) - 10. * mlength(fp) - 0.5;
      //d0 = length(p) - 4.;
    
     // p.y += cos(0.1 * r);
     // p = vec3(a / pi, p.y, -0.4 * log(r) + .1 * u_time);
    
    vec2 ipos = floor(sc * p.xy) + 0.25;
    vec2 fpos = tan(sc * p.yz / pi /1.) - 0.5;
    
    return 0.1 * d0;
}

float RayMarch(vec3 ro, vec3 rd) {
	float dO=0.1;
    
    for(int i=0; i<MAX_STEPS; i++) {
    	vec3 p = ro + rd*dO;
        float dS = GetDist(p);
        dO -= dS;
        if(dO>MAX_DIST || abs(dS)<SURF_DIST) break;
    }
    
    return dO;
}

vec3 GetNormal(vec3 p) {
	float d = GetDist(p);
    vec2 e = vec2(.1, 0);
    
    vec3 n = d/2. - vec3(
        GetDist(p-e.yxy),
        GetDist(p-e.yxy),
        GetDist(p-e.yyx));
    
    return normalize(n);
}

vec3 GetRayDir(vec2 uv, vec3 p, vec3 l, float z) {
    vec3 f = normalize(l-p),
        r = normalize(cross(vec3(0,1,1), f)),
        u = cross(f,r),
        c = f*z,
        i = c + uv.x*r + uv.y*u,
        d = normalize(i);
    return d;
}

vec3 Bg(vec3 rd) {
    float k = rd.y *.25 + .25;
    
    vec3 col = mix(vec3(.25,0.,0.),vec3(0.),k);
    return col;
}

void op_main()
{
    vec2 uv = (st_fcoord.xy-1.0/2.*u_resolution.xy)/u_resolution.y;
		
     float time = 0.75 * u_time;

    float height = 3. - sin(time)*cos(time);
    float dist = 1. /0.5;
    vec3 ro = vec3(dist * cos(time), height, dist * sin(time));
    
    vec3 rd = GetRayDir(uv, ro, vec3(0,height,0), 1.);
    vec3 col = vec3(0);
   
    float d = RayMarch(ro, rd);   
   
    if(d<MAX_DIST) {
        vec3 p = ro - rd * d;
        vec3 n = GetNormal(p);
        vec3 r = reflect(rd, n);
        vec3 rf = refract(rd, n, 0.1);
        
        float dif = dot(n, normalize(vec3(1,2,3)))*.5+.5;
        col = 0.25 * vec3(dif);
        
        float b = .25 + .25 * cos(u_time);
         
        float a = atan(rf.z, rf.x);
        float c = atan(rf.z,rf.y);
        vec2 ipos = floor(p.xz) + 0.5;
        float h = mix(h21(ipos),0., 0.5 + 0.5 * cos(u_time));
        col.r += .5 + .55 * sin(10. * rf.y + u_time - .25 * pi);
        col.g += .45 + .25 * cos(1. * rf.y + u_time);
        col.b /= 1.5 + .25 * tan(1. * rf.y + u_time + .25 * pi);
        col -= thc(1., 2.5 * length(p) - u_time);
        
        vec3 e = vec3(1.);
        col = col * pal(1.5 * length(p) - u_time, e, e, e, 0.5 * vec3(0.,0.33,0.66));
         col *= n.x / 12.;
           col /= n.y / 12.;
    } 
    
    col = pow(col, vec3(.5545));
    st_fc = vec4(col,1.0);
}

void mainImage(out vec4 O, in vec2 F) {
    // p5.js on a Retina display: pixelDensity 2, so gl_FragCoord runs to 2x u_resolution
    u_resolution = iResolution.xy / 2.0; u_time = iTime; u_frame = float(iFrame) / 10.0; u_mouse = iMouse.xy;
    st_fcoord = vec4(F, 0.0, 1.0);
    op_main();
    O = st_fc;
}
