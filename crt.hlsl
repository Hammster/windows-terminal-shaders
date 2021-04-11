// CRT emulation

// Define map for PS I/O
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

// Options
#define ENABLE_CURVE 1
#define ENABLE_BLOOM 1
#define ENABLE_BLUR 1
#define ENABLE_GRAYSCALE 1
#define ENABLE_REFRESHLINE 1
#define ENABLE_SCANLINES 1
#define ENABLE_TINT 1
#define ENABLE_GRAIN 1
#define DEBUG 0

// Settings - Bloom
#define BLOOM_STRENGTH 0.8
#define BLOOM_OFFSET 0.002	

// Settings - Blur
#define BLUR_MULTIPLIER 1.05
#define BLUR_STRENGTH 0.3
#define BLUR_OFFSET 0.003

// Settings - Grayscale Strategies
#define USE_INTENSITY 0
#define USE_GLEAM 0
#define USE_LUMINANCE 1
#define USE_LUMA 0

// Settings - Tint
#define TINT_COLOR float4(1, 0.7f, 0, 0)

// Settings - Gain
#define GRAIN_INTENSITY 0.02f

// retro.hlsl
#define SCANLINE_FACTOR 0.5f
#define SCALED_SCANLINE_PERIOD Scale
// end - retro.hlsl

// Configures the original behavior for tint
#if ENABLE_TINT && !ENABLE_GRAYSCALE
#undef ENABLE_GRAYSCALE
#undef USE_INTENSITY
#undef USE_GLEAM
#undef USE_LUMINANCE
#undef USE_LUMA
#define ENABLE_GRAYSCALE 1
#define USE_INTENSITY 1
#endif

// If you have Bloom enabled, it doesn't play well
// with the way Gleam and Luma calculate grayscale
// so fall back to Luminance
#if ENABLE_BLOOM && (USE_GLEAM || USE_LUMA)
#undef USE_GLEAM
#undef USE_LUMINANCE
#undef USE_LUMA
#define USE_LUMINANCE 1
#endif

// Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

#define GAMMA 2.2f

static const float4 tint = TINT_COLOR;
static const float4 scanlineTint = float4(0.6f, 0.6f, 0.6f, 0.0f);

float2 transformCurve(float2 uv) {
  // TODO: add control variable for transform intensity
  uv -= 0.5f;				// offcenter screen
  float r = uv.x * uv.x + uv.y * uv.y; 	// get ratio
  uv *= 4.2f + r;				// apply ratio
  uv *= 0.25f;				// zoom
  uv += 0.5f;				// move back to center
  return uv;
}

float permute(float x)
{
  x *= (34 * x + 1);
  return 289 * frac(x * 1 / 289.0f);
}

float rand(inout float state)
{
  state = permute(state);
  return frac(state / 41.0f);
}

// retro.hlsl
float SquareWave(float y)
{
  return 1 - (floor(y / SCALED_SCANLINE_PERIOD) % 2) * SCANLINE_FACTOR;
}

float4 Scanline(float4 color, float2 pos)
{
  float wave = SquareWave(pos.y);

  // TODO:GH#3929 make this configurable.
  // Remove the && false to draw scanlines everywhere.
  if (length(color.rgb) < 0.2 && false)
  {
    return color + wave*0.1;
  }
  else
  {
    return color * wave;
  }
}
// end - retro.hlsl

float4 RefreshLines(float4 c, float2 uv)
{
  float timeOver = fmod(Time / 5, 1);
  float refreshLineColorTint = timeOver - uv.y;
  if(uv.y > timeOver && uv.y - 0.04f < timeOver ) c.rgb += (refreshLineColorTint * 2.0f);
  return c;
}

// http://theinstructionlimit.com/bloom
const float3 luminanceFilter = { 0.2989f, 0.5866f, 0.1145f };
const static float threshold = 0.5f;

float4 HighPass(float4 c, Texture2D input, float2 uv)
{
  float normalizationFactor = 1.f / (1.f - threshold);
  float3 sample = input.Sample(samplerState, uv).rgb;
  float grayLevel = saturate(mul(sample, luminanceFilter));
  float3 desaturated = lerp(sample, grayLevel.xxx, threshold);
  return saturate(float4((desaturated - threshold) * normalizationFactor, 1));
}

float4 Bloom(float4 c, Texture2D input, float2 uv)
{
  float4 bloom = c - input.Sample(
    samplerState,
    uv + float2(-BLOOM_OFFSET, 0) * Scale);
  float4 bloom_mask = bloom * BLOOM_STRENGTH;

  return c + bloom_mask;
}

static const float BlurWeights[9]={0.0,0.092,0.081,0.071,0.061,0.051,0.041,0.031,0.021};

float4 BlurH(float4 c, Texture2D input, float2 uv)
{
  float3 screen =
    input.Sample(samplerState, uv).rgb*0.102;
  for (int i = 1; i < 9; i++) screen +=
    input.Sample(samplerState, uv+float2( i*BLUR_OFFSET,0)).rgb*BlurWeights[i];
  for (int i = 1; i < 9; i++) screen +=
    input.Sample(samplerState, uv+float2(-i*BLUR_OFFSET,0)).rgb*BlurWeights[i];
  return float4(screen*BLUR_MULTIPLIER,1);
}

float4 BlurV(float4 c, Texture2D input, float2 uv)
{
  float3 screen =
    input.Sample(samplerState, uv).rgb*0.102;
  for (int i = 1; i < 9; i++) screen +=
    input.Sample(samplerState, uv+float2(0, i*BLUR_OFFSET)).rgb*BlurWeights[i];
  for (int i = 1; i < 9; i++) screen +=
    input.Sample(samplerState, uv+float2(0,-i*BLUR_OFFSET)).rgb*BlurWeights[i];
  return float4(screen*BLUR_MULTIPLIER,1);
}

float4 Blur(float4 c, Texture2D input, float2 uv)
{
  float4 blur = (BlurH(c, input, uv) + BlurV(c, input, uv))/2 - c;
  float4 blur_mask = blur * BLUR_STRENGTH;
  return c + blur_mask;
}

// // http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
// float3 rgb2hsv(float3 c)
// {
//   float4 K = float4(0.f, -1.f / 3.f, 2.f / 3.f, -1.f);
//   float4 p = c.g < c.b ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
//   float4 q = c.r < p.x ? float4(p.xyw, c.r) : float4(c.r, p.yzx);

//   float d = q.x - min(q.w, q.y);
//   float e = 1e-10;
//   return float3(abs(q.z + (q.w - q.y) / (6.f * d + e)), d / (q.x + e), q.x);
// }

// float3 hsv2rgb(float3 c)
// {
//   float4 K = float4(1.f, 2.f / 3.f, 1.f / 3.f, 3.f);
//   float3 p = abs(frac(c.xxx + K.xyz) * 6.f - K.www);
//   return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
// }

// https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0029740
float3 rgb2intensity(float3 c)
{
  return (c.r + c.g + c.b) / 3.f;
}

float3 gamma(float3 c)
{
  return pow(c, GAMMA);
}

float3 invGamma(float3 c)
{
  return pow(c, 1.f/GAMMA);
}

float3 rgb2gleam(float3 c)
{
  c = invGamma(c);
  c= rgb2intensity(c);
  return gamma(c);
}

float3 rgb2luminance(float3 c)
{
  return 0.2989f * c.r + 0.5866f * c.g + 0.1145f * c.b;
}

float3 rgb2luma(float3 c)
{
  c = invGamma(c);
  c = 0.2126f * c.r + 0.7152f * c.g + 0.0722f * c.b;
  return gamma(c);
}

float4 Grayscale(float4 color)
{
  #if USE_INTENSITY
  color.rgb = rgb2intensity(color.rgb);
  #elif USE_GLEAM
  color.rgb = rgb2gleam(color.rgb);
  #elif USE_LUMINANCE
  color.rgb = rgb2luminance(color.rgb);
  #elif USE_LUMA
  color.rgb = rgb2luma(color.rgb);
  #endif

  return color;
}

float4 main(PSInput pin) : SV_TARGET {
  float2 pos = pin.pos.xy;
  float2 uv = pin.uv;

  #if DEBUG
  if(uv.x < 0.5f) return shaderTexture.Sample(samplerState, uv);
  #endif

  #if ENABLE_CURVE
  uv = transformCurve(uv);

  // TODO: add monitor visuals and make colors static consts
  // Outer Box
  if(uv.x < -0.025f || uv.y < -0.025f) return float4(0.f, 0.f, 0.f, 1.f); 
  if(uv.x > 1.025f  || uv.y > 1.025f)  return float4(0.f, 0.f, 0.f, 1.f); 
  // Bezel
  if(uv.x < -0.015f || uv.y < -0.015f) return float4(0.03f, 0.03f, 0.03f, 1.f);
  if(uv.x > 1.015f  || uv.y > 1.015f)  return float4(0.03f, 0.03f, 0.03f, 1.f);
  // Screen Border
  if(uv.x < 0.000f  || uv.y < 0.000f)  return float4(0.f, 0.f, 0.f, 1.f);
  if(uv.x > 1.000f  || uv.y > 1.000f)  return float4(0.f, 0.f, 0.f, 1.f);
  #endif
  
  // If no options are selected, this will just display as normal
  float4 color = shaderTexture.Sample(samplerState, uv);

  #if ENABLE_BLOOM
  color = Bloom(color, shaderTexture, uv);
  #endif
  
  #if ENABLE_BLUR
  color = Blur(color, shaderTexture, uv);
  #endif
  
  #if ENABLE_GRAYSCALE
  color = Grayscale(color);
  #endif

  // The texture sent by Windows Terminal seems inverted on the
  // y-axis, because this only seems to affect the refresh line
  #if SHADERed
  uv.y = 1.0-uv.y;
  #endif

  #if ENABLE_REFRESHLINE
  color = RefreshLines(color, uv);
  #endif

  #if ENABLE_SCANLINES
  color = Scanline(color, pos);
  #endif

  #if ENABLE_TINT
  color *= tint;
  #endif

  #if ENABLE_GRAIN
  float3 m = float3(uv, Time % 5 / 5) + 1.;
  float state = permute(permute(m.x) + m.y) + m.z;

  float p = 0.95 * rand(state) + 0.025;
  float q = p - 0.5;
  float r2 = q * q;

  float grain = q * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
  color.rgb += GRAIN_INTENSITY * grain;
  #endif

  return color;
}