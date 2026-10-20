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
void mainImage(thread float4& O, thread const float2& F, constant ST& _28)
{
    float i = 0.20000000298023223876953125;
    float2 r = float2(_28.iResolution[0], _28.iResolution[1]);
    float2 p = (((F + F) - r) / float2(r.y)) / float2(0.699999988079071044921875);
    float2 d = float2(-1.0, 1.0);
    float2 b = p - (d * i);
    float2 c = p * float2x2(float2(1.0), float2(d / float2(0.100000001490116119384765625 + (i / dot(b, b)))));
    float _84 = dot(c, c);
    float a = _84;
    float4 _99 = cos(float4((0.5 * log(_84)) + (_28.iTime * i)) + float4(0.0, 33.0, 11.0, 0.0));
    float2 v = (c * float2x2(float2(_99.xy), float2(_99.zw))) / float2(i);
    float2 w = {};
    for (;;)
    {
        float _116 = i;
        float _117 = _116 + 1.0;
        i = _117;
        if (_116 < 9.0)
        {
            v += (((sin((v.yx * i) + float2(_28.iTime)) * 0.699999988079071044921875) / float2(i)) + float2(0.5));
            w += (float2(1.0) + sin(v));
            continue;
        }
        else
        {
            break;
        }
    }
    i = length((sin(v / float2(0.300000011920928955078125)) * 0.4000000059604644775390625) + (c * (float2(3.0) + d)));
    O = float4(1.0) - exp(((((-exp(float4(0.60000002384185791015625, -0.4000000059604644775390625, -1.0, 0.0) * c.x)) / w.xyyx) / float4((2.0 + ((i * i) / 4.0)) - i)) / float4(0.5 + (1.0 / a))) / float4(0.02999999932944774627685546875 + abs(length(p) - 0.699999988079071044921875)));
}

fragment main0_out main0(constant ST& _28 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _28.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _28);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

