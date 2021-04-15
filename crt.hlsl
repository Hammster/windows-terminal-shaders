// CRT emulation

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

// Shader Options
#define ENABLE_CURVE            1
#define ENABLE_BLOOM            1
#define ENABLE_BLUR             1
#define ENABLE_GRAYSCALE        1
#define ENABLE_REFRESHLINE      1
#define ENABLE_SCANLINES        1
#define ENABLE_TINT             1
#define ENABLE_GRAIN            1
#define ENABLE_BLACKLEVEL       1

// Settings - Bloom
#define BLOOM_OFFSET            0.0015
#define BLOOM_STRENGTH          0.8

// Settings - Blur
#define BLUR_MULTIPLIER         1.05
#define BLUR_STRENGTH           0.3
#define BLUR_OFFSET             0.003

// Settings - Grayscale
#define GRAYSCALE_INTENSITY     0
#define GRAYSCALE_GLEAM         0
#define GRAYSCALE_LUMINANCE     1
#define GRAYSCALE_LUMA          0

// Settings - Blacklevel
#define BLACKLEVEL_FLOOR        TINT_COLOR / 40

// Settings - Tint
// Colors variations from https://superuser.com/a/1206781
#define TINT_COLOR              TINT_AMBER

#define TINT_AMBER              float3(1.0, 0.7, 0.0) // P3 phosphor
#define TINT_LIGHT_AMBER        float3(1.0, 0.8, 0.0)
#define TINT_GREEN_1            float3(0.2, 1.0, 0.0)
#define TINT_APPLE_II           float3(0.2, 1.0, 0.2) // P1 phosphor
#define TINT_GREEN_2            float3(0.0, 1.0, 0.2)
#define TINT_APPLE_IIc          float3(0.4, 1.0, 0.4) // P24 phpsphor
#define TINT_GREEN_3            float3(0.0, 1.0, 0.4)

// Settings - Gain
#define GRAIN_INTENSITY         0.02

// Configures the original behavior for tint
#if ENABLE_TINT && !ENABLE_GRAYSCALE
#undef ENABLE_GRAYSCALE
#undef GRAYSCALE_INTENSITY
#undef GRAYSCALE_GLEAM
#undef GRAYSCALE_LUMINANCE
#undef GRAYSCALE_LUMA
#define ENABLE_GRAYSCALE 1
#define GRAYSCALE_INTENSITY 1
#endif

// If you have Bloom enabled, it doesn't play well
// with the way Gleam and Luma calculate grayscale
// so fall back to Luminance
#if ENABLE_BLOOM && (GRAYSCALE_GLEAM || GRAYSCALE_LUMA)
#undef GRAYSCALE_INTENSITY
#undef GRAYSCALE_GLEAM
#undef GRAYSCALE_LUMINANCE
#undef GRAYSCALE_LUMA
#define GRAYSCALE_LUMINANCE 1
#endif

// Provide a reasonable Blacklevel even if Tint isn't enabled
#if ENABLE_BLACKLEVEL && !ENABLE_TINT
#undef BLACKLEVEL_FLOOR
#define BLACKLEVEL_FLOOR float3(0.1, 0.1, 0.1)
#endif

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
//#define DEBUG_ROTATION          0.25
//#define DEBUG_SEGMENTS          1
//#define DEBUG_OFFSET            0.425
//#define DEBUG_WIDTH             0.15
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

#if ENABLE_CURVE
float2 transformCurve(float2 uv) {
  // TODO: add control variable for transform intensity
  uv -= 0.5;				// offcenter screen
  float r = uv.x * uv.x + uv.y * uv.y; 	// get ratio
  uv *= 4.2 + r;				// apply ratio
  uv *= 0.25;				// zoom
  uv += 0.5;				// move back to center
  return uv;
}
#endif

#if ENABLE_BLOOM
float4 bloom(float4 c, float2 uv)
{
  float4 bloom = c - shaderTexture.Sample(samplerState, uv + float2(-BLOOM_OFFSET, 0) * Scale);
  float4 bloom_mask = bloom * BLOOM_STRENGTH;
  //return bloom_mask;
  return c + bloom_mask;
}
#endif

#if ENABLE_BLUR
static const float blurWeights[9]={0.0, 0.092, 0.081, 0.071, 0.061, 0.051, 0.041, 0.031, 0.021};

float4 blurH(float4 c, float2 uv)
{
  float3 screen =
    shaderTexture.Sample(samplerState, uv).rgb * 0.102;
  for (int i = 1; i < 9; i++) screen +=
    shaderTexture.Sample(samplerState, uv + float2( i * BLUR_OFFSET, 0)).rgb * blurWeights[i];
  for (int i = 1; i < 9; i++) screen +=
    shaderTexture.Sample(samplerState, uv + float2(-i * BLUR_OFFSET, 0)).rgb * blurWeights[i];
  return float4(screen * BLUR_MULTIPLIER, 1);
}

float4 blurV(float4 c, float2 uv)
{
  float3 screen =
    shaderTexture.Sample(samplerState, uv).rgb * 0.102;
  for (int i = 1; i < 9; i++) screen +=
    shaderTexture.Sample(samplerState, uv + float2(0,  i * BLUR_OFFSET)).rgb * blurWeights[i];
  for (int i = 1; i < 9; i++) screen +=
    shaderTexture.Sample(samplerState, uv + float2(0, -i * BLUR_OFFSET)).rgb * blurWeights[i];
  return float4(screen * BLUR_MULTIPLIER, 1);
}

float4 blur(float4 c, float2 uv)
{
  float4 blur = (blurH(c, uv) + blurV(c, uv)) / 2 - c;
  float4 blur_mask = blur * BLUR_STRENGTH;
  //return blur_mask;
  return c + blur_mask;
}
#endif

#if ENABLE_GRAYSCALE
// https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0029740
float3 rgb2intensity(float3 c)
{
  return (c.r + c.g + c.b) / 3.0;
}

#define GAMMA 2.2
float3 gamma(float3 c)
{
  return pow(c, GAMMA);
}

float3 invGamma(float3 c)
{
  return pow(c, 1.0 / GAMMA);
}

float3 rgb2gleam(float3 c)
{
  c = invGamma(c);
  c= rgb2intensity(c);
  return gamma(c);
}

float3 rgb2luminance(float3 c)
{
  return 0.2989 * c.r + 0.5866 * c.g + 0.1145 * c.b;
}

float3 rgb2luma(float3 c)
{
  c = invGamma(c);
  c = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  return gamma(c);
}

float4 grayscale(float4 color)
{
  #if GRAYSCALE_INTENSITY
  color.rgb = rgb2intensity(color.rgb);
  #elif GRAYSCALE_GLEAM
  color.rgb = rgb2gleam(color.rgb);
  #elif GRAYSCALE_LUMINANCE
  color.rgb = rgb2luminance(color.rgb);
  #elif GRAYSCALE_LUMA
  color.rgb = rgb2luma(color.rgb);
  #else // Error, strategy not defined
  color.rgb = float3(1.0, 0.0, 1.0) - color.rgb;
  #endif

  return color;
}
#endif

#if ENABLE_BLACKLEVEL
float4 blacklevel(float4 color)
{
	color.rgb -= BLACKLEVEL_FLOOR;
	color.rgb = saturate(color.rgb);
	color.rgb += BLACKLEVEL_FLOOR;
	return color;
}
#endif

#if ENABLE_REFRESHLINE
float4 refreshLines(float4 c, float2 uv)
{
  float timeOver = fmod(Time / 5, 1);
  float refreshLineColorTint = timeOver - uv.y;
  if(uv.y > timeOver && uv.y - 0.04 < timeOver ) c.rgb += (refreshLineColorTint * 2.0);
  return c;
}
#endif

#if ENABLE_SCANLINES
// retro.hlsl
#define SCANLINE_FACTOR 0.5
#define SCALED_SCANLINE_PERIOD Scale

float squareWave(float y)
{
  return 1 - (floor(y / SCALED_SCANLINE_PERIOD) % 2) * SCANLINE_FACTOR;
}

float4 scanlines(float4 color, float2 pos)
{
  float wave = squareWave(pos.y);

  // TODO:GH#3929 make this configurable.
  // Remove the && false to draw scanlines everywhere.
  if (length(color.rgb) < 0.2 && false)
  {
    return color + wave * 0.1;
  }
  else
  {
    return color * wave;
  }
}
// end - retro.hlsl
#endif

#if ENABLE_TINT
float4 tint(float4 color)
{
	color.rgb *= TINT_COLOR;
	return color;
}
#endif

#if ENABLE_GRAIN
// Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

float permute(float x)
{
  x *= (34 * x + 1);
  return 289 * frac(x * 1 / 289.0);
}

float rand(inout float state)
{
  state = permute(state);
  return frac(state / 41.0);
}

float4 grain(float4 color, float2 uv)
{
  float3 m = float3(uv, Time % 5 / 5) + 1.0;
  float state = permute(permute(m.x) + m.y) + m.z;
  
  float p = 0.95 * rand(state) + 0.025;
  float q = p - 0.5;
  float r2 = q * q;
  
  float grain = q * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
  color.rgb += GRAIN_INTENSITY * grain;

  return color;
}
#endif

float4 main(PSInput pin) : SV_TARGET {
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
  #if ENABLE_CURVE
  uv = transformCurve(uv);

  // TODO: add monitor visuals and make colors static consts
  // Outer Box
  if(uv.x < -0.025 || uv.y < -0.025) return float4(0.00, 0.00, 0.00, 1.0); 
  if(uv.x >  1.025 || uv.y >  1.025) return float4(0.00, 0.00, 0.00, 1.0); 
  // Bezel
  if(uv.x < -0.015 || uv.y < -0.015) return float4(0.03, 0.03, 0.03, 1.0);
  if(uv.x >  1.015 || uv.y >  1.015) return float4(0.03, 0.03, 0.03, 1.0);
  // Screen Border
  if(uv.x <  0.000 || uv.y <  0.000) return float4(0.00, 0.00, 0.00, 1.0);
  if(uv.x >  1.000 || uv.y >  1.000) return float4(0.00, 0.00, 0.00, 1.0);
  #endif
  
  // If no options are selected, this will just display as normal
  float4 color = shaderTexture.Sample(samplerState, uv).rgba;
  
  #if ENABLE_BLOOM
  color = bloom(color, uv);
  #endif
  
  #if ENABLE_BLUR
  color = blur(color, uv);
  #endif
  
  #if ENABLE_GRAYSCALE
  color = grayscale(color);
  #endif
  
  #if ENABLE_BLACKLEVEL
  color = blacklevel(color);
  #endif
  
  #if ENABLE_REFRESHLINE
  color = refreshLines(color, uv);
  #endif
  
  #if ENABLE_SCANLINES
  color = scanlines(color, pos);
  #endif
  
  #if ENABLE_TINT
  color = tint(color);
  #endif
  
  #if ENABLE_GRAIN
  color = grain(color, uv);
  #endif
  
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