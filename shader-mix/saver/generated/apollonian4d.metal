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
void mainImage(thread float4& o, thread const float2& C, constant ST& _25)
{
    float2 r = float2(_25.iResolution[0], _25.iResolution[1]);
    float4 _46 = cos(float4(_25.iTime / 27.0) + float4(0.0, 11.0, 33.0, 0.0));
    float2x2 R = float2x2(float2(_46.xy), float2(_46.zw));
    float4 p = {};
    float z = {};
    float i = {};
    float s = {};
    float d = {};
    float e = {};
    float4 O = {};
    for (;;)
    {
        float2 _67 = r * 0.5;
        float2 _68 = C - _67;
        float _72 = _68.x;
        float3 _74 = float3(_72, _68.y, r.y);
        float3 _75 = fast::normalize(_74);
        float3 _76 = _75 * z;
        float _78 = _76.x;
        float4 _81 = float4(_78, _76.yz, 0.60000002384185791015625);
        p = _81;
        float _84 = p.z;
        float _85 = _84 - 1.0;
        p.z = _85;
        float4 _87 = p;
        float2 _89 = _87.xw * R;
        float _92 = _89.x;
        p.x = _92;
        float _95 = _89.y;
        p.w = _95;
        float4 _97 = p;
        float2 _99 = _97.wy * R;
        float _101 = _99.x;
        p.w = _101;
        float _103 = _99.y;
        p.y = _103;
        float4 _105 = p;
        float2 _107 = _105.zw * R;
        float _109 = _107.x;
        p.z = _109;
        float _111 = _107.y;
        p.w = _111;
        float4 _112 = p;
        o = _112;
        float _114 = i;
        float _115 = _114 + 1.0;
        i = _115;
        if (_115 < 77.0)
        {
            d = 1.0;
            s = 1.0;
            for (;;)
            {
                float _126 = d;
                float _127 = _126 + 1.0;
                d = _127;
                if (_127 < 7.0)
                {
                    p -= (round(p * 0.5) * 2.0);
                    float _141 = 2.0 / dot(p, p);
                    e = _141;
                    p *= _141;
                    s *= e;
                    continue;
                }
                else
                {
                    break;
                }
            }
            p = abs(p / float4(s));
            d = fast::min(length(p.xy) + 0.0003000000142492353916168212890625, fast::min(p.z, p.w) + 0.0030000000260770320892333984375);
            p = float4((e * e) + 3.0) + (cos(float4(13.0 * dot(o.xy, o.zw)) + float4(2.0, 7.0, 0.0, 4.0)) * 3.0);
            O += (p * ((p.w / (((((7.0 * e) * e) * e) * d) + d)) * exp(((-z) * z) * 0.5)));
            z += ((0.60000002384185791015625 * d) + 0.001000000047497451305389404296875);
            continue;
        }
        else
        {
            break;
        }
    }
    o = precise::tanh((O / float4(20000.0)) - (float4(2.0, 3.0, 1.0, 0.0) * (length((C / r) - float2(0.5)) / 5.0))) / float4(0.89999997615814208984375);
}

fragment main0_out main0(constant ST& _25 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _25.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _25);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

