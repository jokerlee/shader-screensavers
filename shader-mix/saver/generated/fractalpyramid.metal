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
float2 rotate(thread const float2& p, thread const float& a)
{
    float c = cos(a);
    float s = sin(a);
    return p * float2x2(float2(c, s), float2(-s, c));
}

static inline __attribute__((always_inline))
float map(thread float3& p, constant ST& _88)
{
    for (int i = 0; i < 8; i++)
    {
        float t = _88.iTime * 0.20000000298023223876953125;
        float2 param = p.xz;
        float param_1 = t;
        float2 _99 = rotate(param, param_1);
        p.x = _99.x;
        p.z = _99.y;
        float2 param_2 = p.xy;
        float param_3 = t * 1.88999998569488525390625;
        float2 _113 = rotate(param_2, param_3);
        p.x = _113.x;
        p.y = _113.y;
        float3 _119 = p;
        float2 _121 = abs(_119.xz);
        p.x = _121.x;
        p.z = _121.y;
        float3 _127 = p;
        float2 _130 = _127.xz - float2(0.5);
        p.x = _130.x;
        p.z = _130.y;
    }
    return dot(sign(p), p) / 5.0;
}

static inline __attribute__((always_inline))
float3 palette(thread const float& d)
{
    return mix(float3(0.20000000298023223876953125, 0.699999988079071044921875, 0.89999997615814208984375), float3(1.0, 0.0, 1.0), float3(d));
}

static inline __attribute__((always_inline))
float4 rm(thread const float3& ro, thread const float3& rd, constant ST& _88)
{
    float t = 0.0;
    float3 col = float3(0.0);
    float d = {};
    for (float i = 0.0; i < 64.0; i += 1.0)
    {
        float3 p = ro + (rd * t);
        float3 param = p;
        float _166 = map(param, _88);
        d = _166 * 0.5;
        if (d < 0.0199999995529651641845703125)
        {
            break;
        }
        if (d > 100.0)
        {
            break;
        }
        float param_1 = length(p) * 0.100000001490116119384765625;
        col += (palette(param_1) / float3(400.0 * d));
        t += d;
    }
    return float4(col, 1.0 / (d * 100.0));
}

static inline __attribute__((always_inline))
void mainImage(thread float4& fragColor, thread const float2& fragCoord, constant ST& _88)
{
    float2 uv = (fragCoord - (float2(_88.iResolution[0], _88.iResolution[1]) / float2(2.0))) / float2(_88.iResolution[0u]);
    float3 ro = float3(0.0, 0.0, -50.0);
    float2 param = ro.xz;
    float param_1 = _88.iTime;
    float2 _231 = rotate(param, param_1);
    ro.x = _231.x;
    ro.z = _231.y;
    float3 cf = fast::normalize(-ro);
    float3 cs = fast::normalize(cross(cf, float3(0.0, 1.0, 0.0)));
    float3 cu = fast::normalize(cross(cf, cs));
    float3 uuv = ((ro + (cf * 3.0)) + (cs * uv.x)) + (cu * uv.y);
    float3 rd = fast::normalize(uuv - ro);
    float3 param_2 = ro;
    float3 param_3 = rd;
    float4 col = rm(param_2, param_3, _88);
    fragColor = col;
}

fragment main0_out main0(constant ST& _88 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _88.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _88);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

