// SHADERed / Windows Terminal mapping

// Define map for VS I/O
struct VSInput {
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

struct VSOutput {
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
};

VSOutput main(VSInput input)
{
  // We'll adjust the coordinates in the Pixel (Fragment) Shader
  // Textures used must be VFliped
  VSOutput output;
  output.pos = float4(input.pos.xy, 0, 1);
  output.uv = input.uv;

  return output;
}