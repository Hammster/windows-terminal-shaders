// This shader helps to add transparency for vim themes that use xterm colors.

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

// Settings - Debug
#define DEBUG                   0
#define DEBUG_ROTATION          0.25
#define DEBUG_SEGMENTS          1
#define DEBUG_OFFSET            0.425
#define DEBUG_WIDTH             0.15
#define SHOW_UV                 0
#define SHOW_POS                0

// Patches pos and uv coordinates to work for SHADERed or Windows Terminal
// see "SHADERed\GeometryPatch.hlsl" for more details.
PSInput patchGeometry(PSInput pin);

// Used for Debug output only
#if SHADERed
struct DebugOut {
  bool show;
  float4 color;
};
DebugOut debug(float4 pos, float2 uv);
#endif

// Set the color that is supposed to be transparent
static const float3 chromaKey = float3(8.0f / 0xFF, 8.0f / 0xFF, 8.0f / 0xFF);

float4 main(PSInput pin) : SV_TARGET
{
  PSInput patchedPin = patchGeometry(pin);
  // Use Pos and UV in the shader the same as we might use
  // Time, Scale, Resolution, and Background. Unlike those,
  // they are local variables in this implementation and should
  // be passed to any functions using them.
  float4 pos = patchedPin.pos;
  float2 uv = patchedPin.uv;

  // Patches in the debug output in SHADERed
  #if SHADERed
  DebugOut debugOut = debug(pos, uv);
  if (debugOut.show) { return debugOut.color; }
  #endif
  
//-- Shader goes here --//
  float4 color = shaderTexture.Sample(samplerState, uv);
	
  // Filter by chroma key
  if(color.r == chromaKey.r && color.g == chromaKey.g && color.b == chromaKey.b)
  {
    return float4(0.0f, 0.0f, 0.0f, 0.0f);
  }

  return color;
//-- Shader goes here --//
}

// Below is SHADERed patching code to support coordinate transformation
// and debug.
#if SHADERed
#include "SHADERed/GeometryPatch.hlsl"
#include "SHADERed/Debug.hlsl"
#else
// If we aren't in SHADERed, we want to leave the PSInput structure
// unchanged. However, it makes things easier to read if we perform
// a pass through this function anyway. This is an identity function
// used to keep a lot of the #if SHADERed checks outside the shader
// we pass to Windows Terminal.
PSInput patchGeometry(PSInput pin)
{
  return pin;
}
#endif