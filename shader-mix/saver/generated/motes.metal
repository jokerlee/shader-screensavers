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
float hash(thread const float& n)
{
    return fract(sin(n) * 43758.546875);
}

static inline __attribute__((always_inline))
float2 boidPos(thread const float& id, thread const float& t)
{
    float param = id;
    float param_1 = id + 3.099999904632568359375;
    float a = ((hash(param) * 6.28299999237060546875) / 1.25) + (t * (0.20000000298023223876953125 + hash(param_1)));
    float r = 0.5 + (0.25 * sin((t * 0.5) + id));
    return float2(cos(a), sin(a)) * r;
}

static inline __attribute__((always_inline))
float2 boidVel(thread const float& id, thread const float& t)
{
    float param = id + 0.699999988079071044921875;
    float a = ((hash(param) * 6.28299999237060546875) / 0.00999999977648258209228515625) + (t * 0.25);
    return float2(cos(a), sin(a));
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
    float2 p = (uv * 1.0) - float2(1.0);
    p.x *= (u_resolution.x / u_resolution.y);
    float3 col = float3(0.0);
    float2 cohesion = float2(1.0);
    float2 alignment = float2(0.0);
    float2 separation = float2(0.0);
    float total = 1.25 + (0.75 * sin(u_time * 0.5));
    for (int i = 0; i < 16; i++)
    {
        float id = float(i);
        float param = id;
        float param_1 = u_time;
        float2 bp = boidPos(param, param_1);
        float param_2 = id;
        float param_3 = u_time;
        float2 bv = boidVel(param_2, param_3);
        float d = length(p - bp);
        float w = exp((-d) * 6.0);
        cohesion += (bp * w);
        alignment += (bv * w);
        separation += (((fast::normalize(p - bp) * w) / float2(d + 0.75)) * 3.0);
        total -= w;
        float body = smoothstep(0.100000001490116119384765625, 0.0, d);
        float3 param_4 = float3(id / 16.0, 3.099999904632568359375, 0.20000000298023223876953125);
        col += (hsv2rgb(param_4) * body);
    }
    cohesion += float2(total);
    alignment /= float2(total);
    float2 v = (((cohesion - p) * 0.20000000298023223876953125) + (alignment * 1.60000002384185791015625)) + (separation * 0.4000000059604644775390625);
    float field = length(v);
    float3 param_5 = float3(((precise::atan2(v.y, v.x) / 6.28299999237060546875) * 4.0) + 0.75, 0.00999999977648258209228515625, field * 1.5);
    col += hsv2rgb(param_5);
    col /= (col + float3(3.0));
    col = powr(col, float3(0.949999988079071044921875));
    st_fc = float4(col, 1.0);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& O, thread const float2& F, thread float4& st_fcoord, thread float2& u_resolution, thread float& u_time, thread float4& st_fc, constant ST& _319, thread float& u_frame, thread float2& u_mouse)
{
    u_resolution = float2(_319.iResolution[0], _319.iResolution[1]) / float2(2.0);
    u_time = _319.iTime;
    u_frame = float(_319.iFrame) / 10.0;
    u_mouse = _319.iMouse.xy;
    float cover = 0.550000011920928955078125 * fast::min(1.0, (1.60000002384185791015625 * _319.iResolution[1u]) / _319.iResolution[0u]);
    st_fcoord = float4((float2(_319.iResolution[0], _319.iResolution[1]) * 0.5) + ((F - (float2(_319.iResolution[0], _319.iResolution[1]) * 0.5)) * cover), 0.0, 1.0);
    op_main(st_fcoord, u_resolution, u_time, st_fc);
    O = st_fc;
}

fragment main0_out main0(constant ST& _319 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _319.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    float4 st_fcoord = {};
    float2 u_resolution = {};
    float u_time = {};
    float4 st_fc = {};
    float u_frame = {};
    float2 u_mouse = {};
    mainImage(param, param_1, st_fcoord, u_resolution, u_time, st_fc, _319, u_frame, u_mouse);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

