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
float4 effect(thread const float2& screenSize, thread const float2& screen_coords, constant ST& _107)
{
    float pixel_size = length(screenSize) / 745.0;
    float2 uv = (((floor(screen_coords * (1.0 / pixel_size)) * pixel_size) - (screenSize * 0.5)) / float2(length(screenSize))) - float2(0.0);
    float uv_len = length(uv);
    float speed = 301.79998779296875;
    float new_pixel_angle = (precise::atan2(uv.y, uv.x) + speed) - (20.0 * ((0.25 * uv_len) + 0.75));
    float2 mid = (screenSize / float2(length(screenSize))) / float2(2.0);
    uv = float2((uv_len * cos(new_pixel_angle)) + mid.x, (uv_len * sin(new_pixel_angle)) + mid.y) - mid;
    uv *= 30.0;
    speed = _107.iTime * 7.0;
    float2 uv2 = float2(uv.x + uv.y);
    for (int i = 0; i < 5; i++)
    {
        uv2 += (float2(sin(fast::max(uv.x, uv.y))) + uv);
        uv += (float2(cos((5.112331390380859375 + (0.352999985218048095703125 * uv2.y)) + (speed * 0.13112099468708038330078125)), sin(uv2.x - (0.112999998033046722412109375 * speed))) * 0.5);
        uv -= float2((1.0 * cos(uv.x + uv.y)) - (1.0 * sin((uv.x * 0.711000025272369384765625) - uv.y)));
    }
    float contrast_mod = 2.2000000476837158203125;
    float paint_res = fast::min(2.0, fast::max(0.0, (length(uv) * 0.0350000001490116119384765625) * contrast_mod));
    float c1p = fast::max(0.0, 1.0 - (contrast_mod * abs(1.0 - paint_res)));
    float c2p = fast::max(0.0, 1.0 - (contrast_mod * abs(paint_res)));
    float c3p = 1.0 - fast::min(1.0, c1p + c2p);
    float light = (0.20000000298023223876953125 * fast::max((c1p * 5.0) - 4.0, 0.0)) + (0.4000000059604644775390625 * fast::max((c2p * 5.0) - 4.0, 0.0));
    return (float4(0.074657142162322998046875, 0.0228857137262821197509765625, 0.019799999892711639404296875, 0.085714288055896759033203125) + ((((float4(0.870999991893768310546875, 0.2669999897480010986328125, 0.231000006198883056640625, 1.0) * c1p) + (float4(0.0, 0.4199999868869781494140625, 0.70599997043609619140625, 1.0) * c2p)) + float4(float3(0.086000002920627593994140625, 0.1369999945163726806640625, 0.14499999582767486572265625) * c3p, c3p * 1.0)) * 0.914285719394683837890625)) + float4(light);
}

static inline __attribute__((always_inline))
void mainImage(thread float4& fragColor, thread const float2& fragCoord, constant ST& _107)
{
    float2 param = float2(_107.iResolution[0], _107.iResolution[1]);
    float2 param_1 = fragCoord;
    fragColor = effect(param, param_1, _107);
}

fragment main0_out main0(constant ST& _107 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    main0_out out = {};
    float4 c = float4(0.0);
    float2 param_1 = float2(gl_FragCoord.x, _107.iResolution[1u] - gl_FragCoord.y);
    float4 param = {};
    mainImage(param, param_1, _107);
    c = param;
    out.st_out = float4(c.xyz, 1.0);
    return out;
}

