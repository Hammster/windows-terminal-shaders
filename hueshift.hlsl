// This shader applies a hue shift.

Texture2D shaderTexture;
SamplerState samplerState;

struct PSInput {
  float4 pos    : SV_POSITION;
  float2 uv     : TEXCOORD;
};

cbuffer PixelShaderSettings {
	float  Time;
	float  Scale;
	float2 Resolution;
	float4 Background;
};

// Set the CHANGE_RATE to 0.0f and fix the hue to a specific value with HUE_OFFSET
// if you don't want the colors to shift over time but you want the colors to
// be adjusted.
#define HUE_OFFSET 0.0f
// As close to 1/6 as possible with float. For standard term color definitions
// with 6 non-gray scale "primary" colors, this will cycle through the colors
// once a second at each intensity before repeating.
// #define CHANGE_RATE 0.16666667163372039794921875f
#define CHANGE_RATE 0.01f
// Use a tool like https://www.rapidtables.com/convert/color/rgb-to-hsv.html
// to find the saturation of the color you want to be the set point if the color
// isn't changing. The tolerance changes values >= this number, so if you see
// the saturation for #AD7FA8 is 26.6%, 0.266f will be the saturation level from
// which all saturations are compared. #AE9A06 for instance has a saturation of
// 96.1% so it will meet this threshold.
#define TOLERANCE 0.266f

// http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
float3 rgb2hsv(float3 c)
{
    float4 K = float4(0.f, -1.f / 3.f, 2.f / 3.f, -1.f);
    float4 p = c.g < c.b ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
    float4 q = c.r < p.x ? float4(p.xyw, c.r) : float4(c.r, p.yzx);

    float d = q.x - min(q.w, q.y);
    float e = 1e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.f * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c)
{
    float4 K = float4(1.f, 2.f / 3.f, 1.f / 3.f, 3.f);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.f - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float3 adjust_hue(float3 HSV, float offset)
{
	if (HSV.y >= TOLERANCE) { HSV.x = fmod(HSV.x + offset, 1); }
	return HSV;
}

float4 main(PSInput input) : SV_TARGET
{
 	float4 color = shaderTexture.Sample(samplerState, input.uv);
	float3 hsv = rgb2hsv(color.rgb);
	hsv = adjust_hue(hsv, HUE_OFFSET + Time * CHANGE_RATE);

    return float4(hsv2rgb(hsv), color.a);
}
