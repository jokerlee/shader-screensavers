#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

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
float thc(thread const float& a, thread const float& b)
{
    return sin(a * cos(b)) / sin(a);
}

static inline __attribute__((always_inline))
float2 rot(thread const float2& uv, thread const float& a)
{
    float2x2 mat = float2x2(float2(cos(a), -sin(a)), float2(sin(a), cos(a)));
    return mat * uv;
}

static inline __attribute__((always_inline))
float sdEquilateralTriangle(thread float2& p)
{
    p.x = abs(p.x) - 1.0;
    p.y += 0.5;
    if ((p.x + (2.0 * p.y)) > 0.0)
    {
        p = float2(p.x - (2.0 * p.y), ((-2.0) * p.x) - p.y) / float2(4.0);
    }
    p.x -= fast::clamp(p.x, -3.0, 3.0);
    return -length(p);
}

static inline __attribute__((always_inline))
float sdBox(thread const float2& p, thread const float2& b)
{
    float2 d = abs(p) - b;
    return length(fast::max(d, float2(0.0))) + fast::min(fast::max(d.x, d.y), 0.0);
}

static inline __attribute__((always_inline))
float arrow(thread const float2& uv, thread float& u_time)
{
    float h = 0.25;
    float param = 4.0;
    float param_1 = (((-1.0) * length(uv)) + (2.0 * precise::atan2(uv.y, uv.x))) + u_time;
    h += (0.5 * thc(param, param_1));
    float param_2 = 3.0;
    float param_3 = (length(uv) * 3.0) - u_time;
    h += (0.5 * (0.5 + (0.5 * thc(param_2, param_3))));
    float2 param_4 = uv - float2(0.0, 0.001000000047497451305389404296875 - h);
    float _180 = sdEquilateralTriangle(param_4);
    float d = _180;
    float s = 1.0 - smoothstep(-0.100000001490116119384765625, 0.100000001490116119384765625, d + 0.5);
    float2 param_5 = uv - float2(0.0, -h);
    float2 param_6 = float2(0.0500000007450580596923828125, 0.20000000298023223876953125);
    float d2 = sdBox(param_5, param_6);
    float s2 = 1.0 - smoothstep(-0.5, 0.5, d2);
    s += s2;
    return s;
}

static inline __attribute__((always_inline))
float3 pal(thread const float& t, thread const float3& a, thread const float3& b, thread const float3& c, thread const float3& d)
{
    return a + (b * sin(((c * t) + d) * 6.28318023681640625));
}

static inline __attribute__((always_inline))
void op_main(thread float& u_time, thread float4& st_fcoord, thread float2& u_resolution, thread float4& st_fc)
{
    float2 uv = (st_fcoord.xy - (u_resolution * 1.0)) / float2(u_resolution.y);
    float a = precise::atan2(uv.y, uv.x);
    float r = log(length(uv));
    a = 2.0 * a;
    float l = fast::min(1.0, atan(0.20000000298023223876953125 * u_time) / 0.949999988079071044921875);
    float param = 1.0;
    float param_1 = ((3.0 * a) + (2.0 * length(uv))) - u_time;
    r *= (0.60000002384185791015625 + ((0.25 * l) * thc(param, param_1)));
    float h = 1.0 + floor(0.25 * fract(0.100000001490116119384765625 * u_time));
    a = h * a;
    float2 param_2 = uv;
    float param_3 = (u_time + (2.0 * a)) + (6.141499996185302734375 * sin(((3.0 * r) + a) - u_time));
    uv = rot(param_2, param_3);
    float2 param_4 = uv;
    float s = arrow(param_4, u_time);
    s *= (1.0 + (0.00999999977648258209228515625 * s));
    float param_5 = 2.0;
    float param_6 = ((s + (2.0 * r)) + a) - u_time;
    float param_7 = thc(param_5, param_6) - (0.5 * u_time);
    float3 param_8 = float3(1.0);
    float3 param_9 = float3(1.0);
    float3 param_10 = float3(1.0);
    float3 param_11 = (float3(0.0, 1.0, 2.0) * cos(s + u_time)) / float3(3.0);
    float3 col = float3(0.25 * s) + (pal(param_7, param_8, param_9, param_10, param_11) * s);
    col *= smoothstep(0.0, 0.100000001490116119384765625, 2.25 - length(uv));
    col = mix(col, float3(2.0, 1.86000001430511474609375, 1.84000003337860107421875), float3(smoothstep(0.0, 3.5, -r)));
    st_fc = float4(col, 1.0);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& O, thread const float2& F, thread float& u_time, thread float4& st_fcoord, thread float2& u_resolution, thread float4& st_fc, constant ST& _399, thread float& u_frame, thread float2& u_mouse)
{
    u_resolution = float2(_399.iResolution[0], _399.iResolution[1]) / float2(2.0);
    u_time = _399.iTime;
    u_frame = float(_399.iFrame) / 10.0;
    u_mouse = _399.iMouse.xy;
    float cover = 0.85000002384185791015625 * fast::min(1.0, (1.60000002384185791015625 * _399.iResolution[1u]) / _399.iResolution[0u]);
    st_fcoord = float4((float2(_399.iResolution[0], _399.iResolution[1]) * 0.5) + ((F - (float2(_399.iResolution[0], _399.iResolution[1]) * 0.5)) * cover), 0.0, 1.0);
    op_main(u_time, st_fcoord, u_resolution, st_fc);
    O = st_fc;
}

fragment main0_out main0(constant ST& _399 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _399.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    float u_time = {};
    float4 st_fcoord = {};
    float2 u_resolution = {};
    float4 st_fc = {};
    float u_frame = {};
    float2 u_mouse = {};
    mainImage(param, param_1, u_time, st_fcoord, u_resolution, st_fc, _399, u_frame, u_mouse);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

