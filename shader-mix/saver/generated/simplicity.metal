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
float field(thread float3& p, constant ST& _34)
{
    float strength = 7.0 + (0.02999999932944774627685546875 * log(9.9999999747524270787835121154785e-07 + fract(sin(_34.iTime) * 4373.10986328125)));
    float accum = 0.0;
    float prev = 0.0;
    float tw = 0.0;
    for (int i = 0; i < 32; i++)
    {
        float mag = dot(p, p);
        p = (abs(p) / float3(mag)) + float3(-0.5, -0.4000000059604644775390625, -1.5);
        float w = exp((-float(i)) / 7.0);
        accum += (w * exp((-strength) * powr(abs(mag - prev), 2.2999999523162841796875)));
        tw += w;
        prev = mag;
    }
    return fast::max(0.0, ((5.0 * accum) / tw) - 0.699999988079071044921875);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& fragColor, thread const float2& fragCoord, constant ST& _34)
{
    float2 uv = ((fragCoord * 2.0) / float2(_34.iResolution[0], _34.iResolution[1])) - float2(1.0);
    float2 uvs = (uv * float2(_34.iResolution[0], _34.iResolution[1])) / float2(fast::max(_34.iResolution[0u], _34.iResolution[1u]));
    float3 p = float3(uvs / float2(4.0), 0.0) + float3(1.0, -1.2999999523162841796875, 0.0);
    p += (float3(sin(_34.iTime / 16.0), sin(_34.iTime / 12.0), sin(_34.iTime / 128.0)) * 0.20000000298023223876953125);
    float3 param = p;
    float _174 = field(param, _34);
    float t = _174;
    float v = (1.0 - exp((abs(uv.x) - 1.0) * 6.0)) * (1.0 - exp((abs(uv.y) - 1.0) * 6.0));
    fragColor = float4(((1.7999999523162841796875 * t) * t) * t, (1.39999997615814208984375 * t) * t, t, 1.0) * mix(0.4000000059604644775390625, 1.0, v);
}

fragment main0_out main0(constant ST& _34 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _34.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _34);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

