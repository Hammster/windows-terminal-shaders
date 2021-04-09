// A pixel shader is a program that given a texture coordinate (UV) produces a color.
// For Windows Terminal UV is an x,y tuple that ranges from 0,0 (top left) to 1,1 (bottom right).
// For SHADERed Position is an x,y tuple that ranges from 0,0 (bottom left) to with,height (top right).
struct PSInput {
  float4 Position : SV_POSITION;
  float2 UV : TEXCOORD0;
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

// Settings
#define GRAIN_INTENSITY 0.02f
#define TINT_COLOR float4(1, 0.7f, 0, 0)
#define ENABLE_SCANLINES 0
#define ENABLE_REFRESHLINE 0
#define ENABLE_GRAIN 0
#define ENABLE_CURVE 1
#define ENABLE_BLUR 0
#define ENABLE_BLOOM 0
#define ENABLE_TINT 0
#define ENABLE_GRAYSCALE 0
#define USE_INTENSITY 0
#define USE_GLEAM 0
#define USE_LUMINANCE 1
#define USE_LUMA 0
#define DEBUG 0

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

// retro.hlsl
#define SCANLINE_FACTOR 0.5f
#define SCALED_SCANLINE_PERIOD u_scale
#define SCALED_GAUSSIAN_SIGMA (2.f * u_scale)
#define GAUSSIAN_SIGMA 0.8f

static const float M_PI = 3.14159265f;

// Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

#define GAMMA 2.2f

static const float4 tint = TINT_COLOR;
static const float4 scanlineTint = float4(0.6f, 0.6f, 0.6f, 0.0f);

// In SHADERed, we need to provide the scale
// Other uniform variables seem to be provided
#if SHADERed
static float u_time = Time;
static float u_scale = 1.f/Resolution.y;
static float2 u_resolution = Resolution;
static float4 u_background = Background;
float2 normalize_y(float2 texcoord) {
	return float2(texcoord.x, 1.f - texcoord.y);
}
float4 normalize_y(float4 pos) {
	return float4(pos.x, 1.f - pos.y, pos.zw);
}
#else
static float u_time = Time;
static float u_scale = Scale;
static float2 u_resolution = Resolution;
static float4 u_background = Background;
float2 normalize_y(float2 texcoord) {
	return texcoord;
}
float4 normalize_y(float4 pos) {
	return pos;
}
#endif

static float2 uv;
static float4 pos;

float4 Curve(float4 xy)
{
	// TODO: add control variable for transform intensity
	xy -= 0.5f;				// offcenter screen
	float r = xy.x * xy.x + xy.y * xy.y; 	// get ratio
	xy *= 4.2f + r;				// apply ratio
	xy *= 0.25f;				// zoom
	xy += 0.5f;				// move back to center

	// TODO: add monitor visuals and make colors static consts
	// Outter Box
	if(xy.x < -0.025f || xy.y < -0.025f) return float4(0.f); 
	if(xy.x > 1.025f  || xy.y > 1.025f)  return float4(0.f); 
	// Bazel
	if(xy.x < -0.015f || xy.y < -0.015f) return float4(0.03f, 0.03f, 0.03f, 0.f);
	if(xy.x > 1.015f  || xy.y > 1.015f)  return float4(0.03f, 0.03f, 0.03f, 0.f);
	// Screen Border
	if(xy.x < 0.000f  || xy.y < 0.000f)  return float4(0.f);
	if(xy.x > 1.000f  || xy.y > 1.000f)  return float4(0.f);
	
	return xy;
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
float Gaussian2D(float x, float y, float sigma)
{
    return 1/(sigma*sqrt(2*M_PI)) * exp(-0.5*(x*x + y*y)/sigma/sigma);
}

float4 Blur(Texture2D input, float2 tex_coord, float sigma)
{
    uint width, height;
    shaderTexture.GetDimensions(width, height);

    float texelWidth = 1.0f/width;
    float texelHeight = 1.0f/height;

    float4 color = { 0, 0, 0, 0 };

    int sampleCount = 13;

    for (int x = 0; x < sampleCount; x++)
    {
        float2 samplePos = { 0, 0 };

        samplePos.x = tex_coord.x + (x - sampleCount/2) * texelWidth;
        for (int y = 0; y < sampleCount; y++)
        {
            samplePos.y = tex_coord.y + (y - sampleCount/2) * texelHeight;
            if (samplePos.x <= 0 || samplePos.y <= 0 || samplePos.x >= width || samplePos.y >= height) continue;

            color += input.Sample(samplerState, samplePos) * Gaussian2D((x - sampleCount/2), (y - sampleCount/2), sigma);
        }
    }

    return color;
}

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

float4 RefreshLines(float4 c, float2 pos)
{
	float timeOver = fmod(u_time / 5, 1);
	float refreshLineColorTint = timeOver - pos.y;
	if(pos.y > timeOver && pos.y - 0.04f < timeOver ) c.rgb += (refreshLineColorTint * 2.0f);
	return c;
}

// http://theinstructionlimit.com/bloom
const float3 luminanceFilter = { 0.2989f, 0.5866f, 0.1145f };
const float3 lumaFilter = { 0.2126f, 0.7152f, 0.0722f };
const static float threshold = 0.5f;

float4 HighPass(float4 c)
{
	float normalizationFactor = 1.f / (1.f - threshold);
	float3 sample = shaderTexture.Sample(samplerState, normalize_y(uv)).rgb;
	//float3 sample = shaderTexture.Sample(samplerState, uv).rgb;
	float grayLevel = saturate(mul(sample, luminanceFilter));
	float3 desaturated = lerp(sample, grayLevel.xxx, threshold);
	return saturate(float4((desaturated - threshold) * normalizationFactor, 1));
}

float4 Bloom(float4 c)
{
	float4 bright = HighPass(c);
	return bright;
}

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

//float3 rgb2luminance(float3 c)
//{
//	float3 sample = shaderTexture.Sample(samplerState, normal_texcoord(uv)).rgb;
//	return saturate(mul(sample, luminanceFilter)).xxx;
//}

//float3 rgb2luma(float3 c)
//{
//	c = gamma(c);
//	return saturate(mul(c, lumaFilter)).xxx;
//}

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

float4 ConvertToGrayscale(float4 color)
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

float4 main(PSInput pin) : SV_TARGET
{
	// SHADERed Position doesn't match what is expected and
	// needs to be adjusted for the resolution.
	// SHADERed doesn't seem to provide a UV TEXCOORD, so
	// we need to figure that out from the SV_POSITION and
	// invert the y axis so that it is in the range [0.f, 1.f].
	#if SHADERed
	pos = pin.Position / float4(u_resolution, 1.f, 1.f);
	uv = pin.Position.xy / float2(u_resolution);
	#else
	pos = pin.Position;
	uv = pin.UV;
	#endif

	float2 xy = uv.xy;
	
	#if ENABLE_CURVE
	xy = Curve(pos).xy;
	#endif
	
	float4 color = shaderTexture.Sample(samplerState, xy);

	#if DEBUG
	if(xy.x < 0.5f) return color;
	#endif

	#if ENABLE_BLUR
	float blurFactor = 0.9f;
	float invBlurFactor = 1.f / blurFactor;
	color *= blurFactor;
	color *= Blur(shaderTexture, normalize_y(xy), SCALED_GAUSSIAN_SIGMA) * invBlurFactor;
	//color *= Blur(shaderTexture, normalize_y(xy), GAUSSIAN_SIGMA) * invBlurFactor;
	#endif
	
	#if ENABLE_BLOOM
	color = Bloom(color);
	#endif
	
	#if ENABLE_GRAYSCALE
	color = ConvertToGrayscale(color);
	#endif

	#if ENABLE_REFRESHLINE
	color = RefreshLines(color, pos.xy);
	#endif

	#if ENABLE_SCANLINES
	color = Scanline(color, pos.xy);
	#endif

	#if ENABLE_TINT
	color *= tint;
	#endif

	#if ENABLE_GRAIN
	float3 m = float3(xy, Time % 5 / 5) + 1.;
	float state = permute(permute(m.x) + m.y) + m.z;

	float p = 0.95 * rand(state) + 0.025;
	float q = p - 0.5;
	float r2 = q * q;

	float grain = q * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
	color.rgb += GRAIN_INTENSITY * grain;
	#endif

	return color;
}