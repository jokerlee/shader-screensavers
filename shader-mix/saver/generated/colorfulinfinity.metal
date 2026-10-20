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
float4 tex(thread const float3& p, constant ST& _31)
{
    float t = _31.iTime + 78.0;
    float4 o = float4(p, 3.0 * sin(t * 0.100000001490116119384765625));
    float4 dec = float4(1.0, 0.89999997615814208984375, 0.100000001490116119384765625, 0.1500000059604644775390625) + float4(0.0599999986588954925537109375 * cos(t * 0.100000001490116119384765625), 0.0, 0.0, 0.14000000059604644775390625 * cos(t * 0.23000000417232513427734375));
    int i = 0;
    for (;;)
    {
        int _77 = i;
        int _78 = _77 + 1;
        i = _78;
        if (_77 < 23)
        {
            float4 _90 = abs((o * (1.0 / dot(o, o))) - dec);
            o = float4(_90.x, _90.z, _90.y, _90.w);
            continue;
        }
        else
        {
            break;
        }
    }
    return o;
}

static inline __attribute__((always_inline))
void mainImage(thread float4& fragColor, thread const float2& fragCoord, constant ST& _31)
{
    float2 uv = (fragCoord - (float2(_31.iResolution[0], _31.iResolution[1]) * 0.5)) / float2(_31.iResolution[1u]);
    float3 col = float3(0.0);
    float t = _31.iTime * 0.300000011920928955078125;
    for (float i = 0.0; i <= 1.0; i += 0.0625)
    {
        float d = fract(i + t);
        float s = mix(5.0, 0.5, d);
        float f = d * smoothstep(1.0, 0.89999997615814208984375, d);
        float3 param = float3(uv * s, i * 4.0);
        col += (tex(param, _31).xyz * f);
    }
    col /= float3(16.0);
    col *= float3(2.0, 1.0, 2.0);
    col = powr(col, float3(0.5));
    fragColor = float4(col, 0.0);
}

fragment main0_out main0(constant ST& _31 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _31.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _31);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

