// Inspired by the KodeLife default shader

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
  uv = -1.0 + 2.0 * uv;
  float4 color = float4(
    abs(sin(cos(Time + 3.0 * uv.y) * 2.0 * uv.x + Time)),
    abs(cos(sin(Time + 2.0 * uv.x) * 3.0 * uv.y + Time)),
    cos(Time) * 0.5 + 0.5,
    1.0f);
return color;
//-- Shader goes here --//
}

#if SHADERed
#include "SHADERed/PS-DebugPatch.hlsl"
#include "SHADERed/PS-CoordinatesPatch.hlsl"
#endif