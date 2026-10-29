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
float2 warp(thread const float2& p, thread float& u_time)
{
    float t = u_time * 0.300000011920928955078125;
    return p + (float2(sin((p.y * 4.0) + t), cos((p.x * 4.0) - t)) * 0.119999997317790985107421875);
}

static inline __attribute__((always_inline))
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float spotlight(thread const float2& p, thread const float2& lightPos, thread const float2& dir, thread const float& cone, thread const float& soft, thread const float& seed, thread float& u_time)
{
    float2 L = fast::normalize(p - lightPos);
    float dist = length(p - lightPos);
    float theta = dot(L, fast::normalize(dir));
    theta += (0.25 * sin(((dist * 8.0) + u_time) + seed));
    float inner = cos(cone);
    float edge = inner - soft;
    float att = 2.5 / (1.0 + ((3.0 * dist) * dist));
    float beam = smoothstep(edge, inner, theta);
    return beam * att;
}

static inline __attribute__((always_inline))
float3 hsv2rgb(thread const float3& c)
{
    float3 rgb = fast::clamp(abs(mod(float3(c.x * 6.0) + float3(0.0, 4.0, 2.0), float3(6.0)) - float3(3.0)) - float3(1.0), float3(0.0), float3(1.0));
    return mix(float3(1.0), rgb, float3(c.y)) * c.z;
}

static inline __attribute__((always_inline))
float blob(thread const float2& p, thread const float& r, thread const float& life, thread float& u_time)
{
    float d = length(p) - r;
    d += ((0.1500000059604644775390625 * sin((length(p) * 6.0) - (u_time * 1.10000002384185791015625))) * life);
    d += (0.07999999821186065673828125 * sin((p.x * 5.0) + u_time));
    d += (0.119999997317790985107421875 * sin((p.y * 5.0) - u_time));
    return d;
}

static inline __attribute__((always_inline))
void op_main(thread float& u_time, thread float4& st_fcoord, thread float2& u_resolution, thread float4& st_fc)
{
    float2 uv = st_fcoord.xy / u_resolution;
    float2 p = (uv * 2.0) - float2(2.0);
    p.x *= (u_resolution.x / u_resolution.y);
    float2 param = p;
    float2 pw = warp(param, u_time);
    float3 col = float3(0.5, 0.0500000007450580596923828125, 0.07999999821186065673828125);
    float pulse = 0.60000002384185791015625 + (0.4000000059604644775390625 * sin(u_time * 0.60000002384185791015625));
    float harmony = 0.300000011920928955078125 + (0.20000000298023223876953125 * sin(u_time * 0.20000000298023223876953125));
    float life = pulse * (0.60000002384185791015625 + harmony);
    life = fast::clamp(life, 0.0, 1.0);
    for (int i = 0; i < 64; i++)
    {
        float fi = float(i);
        float seed = fi * 17.700000762939453125;
        float2 g = float2(mod(fi * 7.0, 1.0), mod(fi * 11.0, 1.0));
        float2 lightPos = (g + float2(0.5)) / float2(1.0);
        lightPos = (lightPos * 2.0) - float2(1.0);
        lightPos.x *= (u_resolution.x / u_resolution.y);
        float param_1 = seed;
        float ang = (u_time * 0.4000000059604644775390625) + (hash(param_1) * 6.28318023681640625);
        float2 dir = float2(cos(ang), sin(ang));
        float param_2 = seed;
        float param_3 = seed + 3.0;
        float2 param_4 = pw;
        float2 param_5 = lightPos;
        float2 param_6 = dir;
        float param_7 = mix(0.60000002384185791015625, 0.300000011920928955078125, hash(param_2));
        float param_8 = mix(0.300000011920928955078125, 0.100000001490116119384765625, hash(param_3));
        float param_9 = seed;
        float light = spotlight(param_4, param_5, param_6, param_7, param_8, param_9, u_time);
        float param_10 = seed;
        float hue = fract(mix(hash(param_10), harmony, 0.5) + (u_time * 0.0500000007450580596923828125));
        float3 param_11 = float3(hue, 0.949999988079071044921875, 1.0);
        float3 lc = hsv2rgb(param_11);
        float param_12 = seed + 2.0;
        float flicker = 0.60000002384185791015625 + (0.4000000059604644775390625 * sin((u_time * (1.5 + hash(param_12))) + fi));
        col += (((lc * light) * flicker) * pulse);
    }
    float2 param_13 = pw;
    float param_14 = 0.85000002384185791015625;
    float param_15 = life;
    float mask = smoothstep(0.02999999932944774627685546875, -0.02999999932944774627685546875, blob(param_13, param_14, param_15, u_time));
    col /= float3(mask);
    col -= float3(smoothstep(0.20000000298023223876953125, 0.60000002384185791015625, length(pw)) * 0.800000011920928955078125);
    col /= (col + float3(2.0));
    col = powr(col, float3(0.9900000095367431640625));
    st_fc = float4(col, 1.0);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& O, thread const float2& F, thread float& u_time, thread float4& st_fcoord, thread float2& u_resolution, thread float4& st_fc, constant ST& _436, thread float& u_frame, thread float2& u_mouse)
{
    u_resolution = float2(_436.iResolution[0], _436.iResolution[1]) / float2(2.0);
    u_time = _436.iTime;
    u_frame = float(_436.iFrame) / 10.0;
    u_mouse = _436.iMouse.xy;
    float cover = 0.449999988079071044921875 * fast::min(1.0, (1.60000002384185791015625 * _436.iResolution[1u]) / _436.iResolution[0u]);
    st_fcoord = float4((float2(_436.iResolution[0], _436.iResolution[1]) * 0.5) + ((F - (float2(_436.iResolution[0], _436.iResolution[1]) * 0.5)) * cover), 0.0, 1.0);
    op_main(u_time, st_fcoord, u_resolution, st_fc);
    O = st_fc;
}

fragment main0_out main0(constant ST& _436 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _436.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    float u_time = {};
    float4 st_fcoord = {};
    float2 u_resolution = {};
    float4 st_fc = {};
    float u_frame = {};
    float2 u_mouse = {};
    mainImage(param, param_1, u_time, st_fcoord, u_resolution, st_fc, _436, u_frame, u_mouse);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

