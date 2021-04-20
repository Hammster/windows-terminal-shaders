// Applies a Hue shift

// Define map for PS input
struct PSInput {
  float4 pos : SV_POSITION;
  float2 uv : TEXCOORD0;
};

// The terminal graphics as a texture
Texture2D shaderTexture : register(t0);
SamplerState samplerState : register(s0);

// Terminal settings such as the resolution of the texture
cbuffer PixelShaderSettings : register(b0) {
  // The number of seconds since the pixel shader was enabled
  float  Time;
  // UI Scale
  float  Scale;
  // Resolution of the shaderTexture
  float2 Resolution;
  // Background color as rgba
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

// All the DEBUG settings are optional
// At a minimum, #define DEBUG 1 will pass debug visualizations
// through, but that can be refined with the additional settings
// #define SHOW_UV and SHOW_POS can be useful for seeing the
// coordinates but this is more valuable when trying to see these
// coordinates when applied to the Windows Terminal, a capability
// disabled by default. SHOW_UV and SHOW_POS are independant of
// DEBUG and effectively replace the shader code being written. This
// can be useful to temporarily disable the shader code with a
// minumum output which renders during development.

// Settings - Debug
#define DEBUG                   0
#define DEBUG_ROTATION          0.25
#define DEBUG_SEGMENTS          1
#define DEBUG_OFFSET            0.425
#define DEBUG_WIDTH             0.15
#define SHOW_UV                 0
#define SHOW_POS                0

#if SHADERed
// Must be inlined to the shader or it breaks single-step debugging
PSInput patchCoordinates(PSInput pin);

struct DebugOut {
  bool show;
  float4 color;
};
DebugOut debug(float4 pos, float2 uv);
#endif

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

float4 main(PSInput pin) : SV_TARGET
{
  // Use pos and uv in the shader the same as we might use
  // Time, Scale, Resolution, and Background. Unlike those,
  // they are local variables in this implementation and should
  // be passed to any functions using them.
  
  float4 pos = pin.pos;
  float2 uv = pin.uv;
  
  #if SHADERed
  // Must be inlined to the shader or it breaks single-step debugging
  // Patches the pin pos and uv
  PSInput patchedPin = patchCoordinates(pin);
  pos = patchedPin.pos;
  uv = patchedPin.uv;

  // Patches in the UV Debug output
  DebugOut debugOut = debug(pos, uv);
  if (debugOut.show) { return debugOut.color; }
  #endif

//-- Shader goes here --//
  float4 color = shaderTexture.Sample(samplerState, uv);
  float3 hsv = rgb2hsv(color.rgb);
  hsv = adjust_hue(hsv, HUE_OFFSET + Time * CHANGE_RATE);

  return float4(hsv2rgb(hsv), color.a);
//-- Shader goes here --//
}

#if SHADERed
#include "SHADERed/PS-DebugPatch.hlsl"
#include "SHADERed/PS-CoordinatesPatch.hlsl"
#endif
