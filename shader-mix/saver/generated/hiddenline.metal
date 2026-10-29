#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL mod() function, which is slightly different than Metal fmod()
template<typename Tx, typename Ty>
inline Tx mod(Tx x, Ty y)
{
    return x - y * floor(x / y);
}

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ST
{
    packed_float3 iResolution;
    float iTime;
    float4 iMouse;
    float4 iDate;
    float iTimeDelta;
    int iFrame;
    float iFrameRate;
    float iSampleRate;
    float3 iChannelResolution[4];
    float4 iChannelTime[4];
};

struct main0_out
{
    float4 st_out [[color(0)]];
};

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float spotlight(thread const float2& p, thread const float2& lightPos, thread const float2& dir, thread const float& coneAngle, thread const float& softness)
{
    float2 L = fast::normalize(p - lightPos);
    float theta = dot(L, fast::normalize(dir));
    float dist = length(p - lightPos);
    float att = 2.0 / (1.0 + ((3.0 * dist) * dist));
    float inner = cos(radians(coneAngle * 0.125));
    float edge = inner - softness;
    float cone = smoothstep(edge, inner, theta);
    return cone * att;
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float3 rgb = fast::clamp(abs(mod(float3(c.x * 6.0) + float3(0.0, 4.0, 2.0), float3(6.0)) - float3(3.0)) - float3(1.0), float3(0.0), float3(1.0));
    return mix(float3(1.0), rgb, float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
void op_main(thread float4& st_fcoord, thread float2& u_resolution, thread float& u_time, thread float4& st_fc)
{
    float2 uv = st_fcoord.xy / u_resolution;
    float2 p = (uv * 1.5) - float2(1.5);
    p.x *= (u_resolution.x / u_resolution.y);
    float2 gp = (p * 0.5) + float2(0.5);
    float2 cell = floor(gp * 64.0);
    float3 col = float3(0.25 + (0.1500000059604644775390625 * sin(u_time * 0.300000011920928955078125)), 0.800000011920928955078125, 0.100000001490116119384765625);
    float globalPulse = 0.5 + (0.25 * sin(u_time * 0.60000002384185791015625));
    float align = smoothstep(0.5, 1.0, sin(u_time * 0.20000000298023223876953125));
    float harmony = 0.5 + (0.5 * sin(u_time * 0.0500000007450580596923828125));
    for (int i = 0; i < 32; i++)
    {
        float fi = float(i);
        float seed = fi * 19.3449993133544921875;
        float gx = mod(fi * 5.0, 64.0);
        float gy = mod(fi * 5.0, 64.0);
        float2 jitter = float2(sin((u_time * 0.300000011920928955078125) + seed), cos((u_time * 0.2700000107288360595703125) + seed)) * 0.100000001490116119384765625;
        float2 lightPos = (float2(gx, gy) + float2(0.5)) / float2(64.0);
        lightPos = (lightPos * 2.0) - float2(1.0);
        lightPos += (jitter * 0.001562500023283064365386962890625);
        lightPos.x *= (u_resolution.x / u_resolution.y);
        float param = seed;
        float angle = (u_time * 0.5) + (hash(param) * 6.28318023681640625);
        float2 dir = float2(cos(angle), sin(angle));
        float param_1 = seed + 18.0;
        float coneAngle = mix(0.5, 0.20000000298023223876953125, hash(param_1));
        float param_2 = seed + 9.0;
        float softness = mix(2.0, 0.5, hash(param_2));
        float2 param_3 = p;
        float2 param_4 = lightPos;
        float2 param_5 = dir;
        float param_6 = coneAngle;
        float param_7 = softness;
        float light = spotlight(param_3, param_4, param_5, param_6, param_7);
        float param_8 = seed + 10.0;
        float hueBase = hash(param_8);
        float param_9 = seed + 20.0;
        float hueSpeed = 0.0500000007450580596923828125 + (0.02500000037252902984619140625 * hash(param_9));
        float hue = fract(mix(hueBase, harmony, 0.25) + ((u_time * hueSpeed) * 0.25));
        float3 param_10 = float3(hue, 0.9900000095367431640625, 1.0);
        float3 lightColor = hsv2rgb(param_10);
        float param_11 = seed + 4.5;
        float flicker = (0.5 + (0.1500000059604644775390625 * sin((u_time * (1.7000000476837158203125 + hash(param_11))) + fi))) + (0.5 * sin((u_time * 3.099999904632568359375) + seed));
        col += ((((lightColor * light) * globalPulse) * flicker) * mix(1.0, 2.150000095367431640625, align));
    }
    float vignette = smoothstep(1.25, 0.75, length(p));
    col -= float3(vignette * 1.25);
    col /= (col + float3(1.0));
    col = powr(col, float3(0.89999997615814208984375));
    st_fc = float4(col, 1.0);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& O, thread const float2& F, thread float4& st_fcoord, thread float2& u_resolution, thread float& u_time, thread float4& st_fc, constant ST& _403, thread float& u_frame, thread float2& u_mouse)
{
    u_resolution = float2(_403.iResolution[0], _403.iResolution[1]) / float2(2.0);
    u_time = _403.iTime;
    u_frame = float(_403.iFrame) / 10.0;
    u_mouse = _403.iMouse.xy;
    float cover = 0.550000011920928955078125 * fast::min(1.0, (1.60000002384185791015625 * _403.iResolution[1u]) / _403.iResolution[0u]);
    st_fcoord = float4((float2(_403.iResolution[0], _403.iResolution[1]) * 0.5) + ((F - (float2(_403.iResolution[0], _403.iResolution[1]) * 0.5)) * cover), 0.0, 1.0);
    op_main(st_fcoord, u_resolution, u_time, st_fc);
    O = st_fc;
}

fragment main0_out main0(constant ST& _403 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _403.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    float4 st_fcoord = {};
    float2 u_resolution = {};
    float u_time = {};
    float4 st_fc = {};
    float u_frame = {};
    float2 u_mouse = {};
    mainImage(param, param_1, st_fcoord, u_resolution, u_time, st_fc, _403, u_frame, u_mouse);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

