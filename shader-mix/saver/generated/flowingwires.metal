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
float s(thread float3& q, thread float4& O, thread const float& t, thread const float& T)
{
    float3 _27 = q;
    float2 _30 = _27.xy + float2(0.5);
    q.x = _30.x;
    q.y = _30.y;
    float d = length(float2(length(q.xy) - 0.5, q.z)) - 0.00999999977648258209228515625;
    float _51 = q.y;
    float _53 = q.x;
    float4 _69 = cos(float4((round((precise::atan2(_51, _53) - T) * 3.7999999523162841796875) / 3.7999999523162841796875) + T) + float4(0.0, 33.0, 11.0, 0.0));
    float3 _79 = q;
    float2 _81 = _79.yx * float2x2(float2(_69.xy), float2(_69.zw));
    q.y = _81.x;
    q.x = _81.y;
    q.x -= 0.5;
    O += (((float4(1.0) + cos(float4(t + (T * 0.5)) + float4(0.0, 1.0, 2.0, 0.0))) * ((sin(t + T) * 0.100000001490116119384765625) + 0.100000001490116119384765625)) / float4(0.5 + powr(length(q) * 50.0, 1.2999999523162841796875)));
    return d;
}

static inline __attribute__((always_inline))
void mainImage(thread float4& O, thread float2& F, constant ST& _130)
{
    float3 R = float3(_130.iResolution);
    float t = 0.0;
    float T = _130.iTime;
    O = float4(0.0);
    F += (F - R.xy);
    float i = 0.0;
    for (;;)
    {
        float _154 = i;
        float _155 = _154 + 1.0;
        i = _155;
        if (_154 < 28.0)
        {
            float4 _166 = cos(float4(t * 0.100000001490116119384765625) + float4(0.0, 33.0, 11.0, 0.0));
            float3 p = fast::normalize(float3(F * float2x2(float2(_166.xy), float2(_166.zw)), R.y)) * t;
            float4 _187 = cos(float4(T / 4.0) + float4(0.0, 33.0, 11.0, 0.0));
            float3 _195 = p;
            float2 _197 = _195.zx * float2x2(float2(_187.xy), float2(_187.zw));
            p.z = _197.x;
            p.x = _197.y;
            float4 _207 = cos(float4(T / 3.0) + float4(0.0, 33.0, 11.0, 0.0));
            float3 _215 = p;
            float2 _217 = _215.zy * float2x2(float2(_207.xy), float2(_207.zw));
            p.z = _217.x;
            p.y = _217.y;
            p.x += T;
            p = fract(p) - float3(0.5);
            float3 param = p;
            float4 param_1 = O;
            float param_2 = t;
            float param_3 = T;
            float _240 = s(param, param_1, param_2, param_3);
            O = param_1;
            float d1 = _240;
            float3 param_4 = float3(-p.y, p.zx);
            float4 param_5 = O;
            float param_6 = t;
            float param_7 = T;
            float _258 = s(param_4, param_5, param_6, param_7);
            O = param_5;
            float d2 = _258;
            float3 param_8 = -p.zxy;
            float4 param_9 = O;
            float param_10 = t;
            float param_11 = T;
            float _271 = s(param_8, param_9, param_10, param_11);
            O = param_9;
            float d3 = _271;
            t += fast::min(fast::min(d1, d2), d3);
            continue;
        }
        else
        {
            break;
        }
    }
}

fragment main0_out main0(constant ST& _130 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _130.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _130);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

