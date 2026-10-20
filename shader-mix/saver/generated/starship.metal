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
void mainImage(thread float4& O, thread const float2& I, constant ST& _25, texture2d<float> iChannel0, sampler iChannel0Smplr)
{
    float2 r = float2(_25.iResolution[0], _25.iResolution[1]);
    float2 p = ((((I + I) - r) / float2(r.y)) * float2x2(float2(3.0, 4.0), float2(4.0, -3.0))) / float2(100.0);
    float4 C = float4(1.0, 2.0, 3.0, 0.0);
    float t = _25.iTime;
    float T = (0.100000001490116119384765625 * t) + p.y;
    float i = {};
    float4 S = {};
    float4 W = {};
    for (;;)
    {
        float _77 = i;
        float _78 = _77 + 1.0;
        i = _78;
        if (_77 < 50.0)
        {
            p += (cos(((((C.xz + float2(8.0)) + float2(i)) * i) + float2(T)) + float2(T)) * 0.0199999995529651641845703125);
            float4 _108 = C * sin(i);
            W = _108;
            S += ((((cos(_108) + float4(1.0)) * exp(sin(i + (i * T)))) / float4(length(fast::max(p, p / float2(2.0, (iChannel0.sample(iChannel0Smplr, ((p / float2(exp(W.x))) + (float2(i, t) / float2(8.0)))) * 40.0).x))))) / float4(10000.0));
            continue;
        }
        else
        {
            break;
        }
    }
    float4 _157 = C;
    float4 _159 = _157 - float4(1.0);
    C = _159;
    O = precise::tanh((_159 * p.x) + (S * S));
}

fragment main0_out main0(constant ST& _25 [[buffer(0)]], texture2d<float> iChannel0 [[texture(0)]], sampler iChannel0Smplr [[sampler(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _25.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _25, iChannel0, iChannel0Smplr);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

