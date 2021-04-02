// Data provided by Windows Terminal
Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
	float  Time;
	float  Scale;
	float2 Resolution;
	float4 Background;
};

// Settings
#define GRAIN_INTENSITY 0.02
#define TINT_COLOR float4(1, 0.7f, 0, 0)
#define ENABLE_SCANLINES 1
#define ENABLE_REFRESHLINE 1
#define ENABLE_GRAIN 1
#define ENABLE_CURVE 1
#define ENABLE_TINT 1
#define ENABLE_BLUR 1
#define DEBUG 0

// retro.hlsl
#define SCANLINE_FACTOR 0.5
#define SCALED_SCANLINE_PERIOD Scale
#define SCALED_GAUSSIAN_SIGMA (2.0*Scale)

static const float M_PI = 3.14159265f;

// Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

static const float4 tint = TINT_COLOR;
static const float4 scanlineTint = float4(0.6f, 0.6f, 0.6f, 0.0f);

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

float4 Scanline(float4 color, float4 pos)
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

float4 mainImage(float4 pos, float2 tex) : TARGET
{
	float2 xy = tex.xy;
	
	#if ENABLE_CURVE
	// TODO: add control variable for transform intensity
	xy -= 0.5f;				// offcenter screen
	float r = xy.x * xy.x + xy.y * xy.y; 	// get ratio
	xy *= 4.2f + r;				// apply ratio
	xy *= 0.25f;				// zoom
	xy += 0.5f;				// move back to center

	// TODO: add monitor visuals and make colors static consts
	// Outter Box
	if(xy.x < -0.025f || xy.y < -0.025f) return float4(0, 0, 0, 0); 
	if(xy.x > 1.025f  || xy.y > 1.025f)  return float4(0, 0, 0, 0); 
	// Bazel
	if(xy.x < -0.015f || xy.y < -0.015f) return float4(0.03f, 0.03f, 0.03f, 0.0f);
	if(xy.x > 1.015f  || xy.y > 1.015f)  return float4(0.03f, 0.03f, 0.03f, 0.0f);
	// Screen Border
	if(xy.x < 0.001f  || xy.y < 0.001f)  return float4(0.0f, 0.0f, 0.0f, 0.0f);
	if(xy.x > 0.999f  || xy.y > 0.999f)  return float4(0.0f, 0.0f, 0.0f, 0.0f);
	#endif
	
	#if ENABLE_BLUR
	Texture2D input = shaderTexture;
	float4 color = shaderTexture.Sample(samplerState, xy) * 0.9;
	color += Blur(input, xy, SCALED_GAUSSIAN_SIGMA) * 0.1;
	#else
	float4 color = shaderTexture.Sample(samplerState, xy);
	#endif

	#if DEBUG
	if(xy.x < 0.5f) return color;
	#endif

	#if ENABLE_REFRESHLINE
	float timeOver = fmod(Time / 5, 1);
	float refreshLineColorTint = timeOver - xy.y;
	if(xy.y > timeOver && xy.y - 0.03f < timeOver ) color.rgb += (refreshLineColorTint * 2.0f);
	#endif

	// #if ENABLE_SCANLINES
	// // TODO: fixing the precision issue so that scanlines are always 1px
	// if(floor(xy.y * 1000) % 2) color *= scanlineTint;
	// #endif

	#if ENABLE_SCANLINES
	color = Scanline(color, pos);
	#endif

	#if ENABLE_TINT
	float grayscale = (color.r + color.g + color.b) / 3.f;
	color = float4(grayscale, grayscale, grayscale, 0);
	color *= tint;
	#endif

	#if ENABLE_GRAIN
	float3 m = float3(tex, Time % 5 / 5) + 1.;
	float state = permute(permute(m.x) + m.y) + m.z;

	float p = 0.95 * rand(state) + 0.025;
	float q = p - 0.5;
	float r2 = q * q;

	float grain = q * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
	color.rgb += GRAIN_INTENSITY * grain;
	#endif

	return color;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
	float4 color = mainImage(pos, tex);

	return color;
}