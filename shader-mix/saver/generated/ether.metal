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
float2x2 m(thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static inline __attribute__((always_inline))
float map(thread float3& p, constant ST& _53)
{
    float param = _53.iTime * 0.4000000059604644775390625;
    float3 _62 = p;
    float2 _64 = _62.xz * m(param);
    p.x = _64.x;
    p.z = _64.y;
    float param_1 = _53.iTime * 0.300000011920928955078125;
    float3 _77 = p;
    float2 _79 = _77.xy * m(param_1);
    p.x = _79.x;
    p.y = _79.y;
    float3 q = (p * 2.0) + float3(_53.iTime);
    return ((length(p + float3(sin(_53.iTime * 0.699999988079071044921875))) * log(length(p) + 1.0)) + (sin(q.x + sin(q.z + sin(q.y))) * 0.5)) - 1.0;
}

static inline __attribute__((always_inline))
void mainImage(thread float4& fragColor, thread const float2& fragCoord, constant ST& _53)
{
    float2 p = (fragCoord / float2(_53.iResolution[1u])) - float2(0.89999997615814208984375, 0.5);
    float3 cl = float3(0.0);
    float d = 2.5;
    for (int i = 0; i <= 5; i++)
    {
        float3 p_1 = float3(0.0, 0.0, 5.0) + (fast::normalize(float3(p, -1.0)) * d);
        float3 param = p_1;
        float _164 = map(param, _53);
        float rz = _164;
        float3 param_1 = p_1 + float3(0.100000001490116119384765625);
        float _172 = map(param_1, _53);
        float f = fast::clamp((rz - _172) * 0.5, -0.100000001490116119384765625, 1.0);
        float3 l = float3(0.100000001490116119384765625, 0.300000011920928955078125, 0.4000000059604644775390625) + (float3(5.0, 2.5, 3.0) * f);
        cl = (cl * l) + (l * (smoothstep(2.5, 0.0, rz) * 0.699999988079071044921875));
        d += fast::min(rz, 1.0);
    }
    fragColor = float4(cl, 1.0);
}

fragment main0_out main0(constant ST& _53 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _53.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _53);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

