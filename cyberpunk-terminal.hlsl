// Cyberpunk 2077 inspired neon display shader for Windows Terminal.
// Original implementation; no game assets are used.

struct PSInput
{
    float4 pos : SV_POSITION;
    float2 uv  : TEXCOORD0;
};

Texture2D shaderTexture : register(t0);
SamplerState samplerState : register(s0);

cbuffer PixelShaderSettings : register(b0)
{
    float Time;
    float Scale;
    float2 Resolution;
    float4 Background;
};

// -----------------------------------------------------------------------------
// User settings
// -----------------------------------------------------------------------------

// 1 = use the built-in lower-intensity daily-use preset.
#define CYBERPUNK_SUBTLE_PRESET  0

#define ENABLE_NEON_GLOW         1
#define ENABLE_RGB_SPLIT         1
#define ENABLE_GLITCHES          1
#define ENABLE_SCANLINES         1
#define ENABLE_SCAN_SWEEP        1
#define ENABLE_NEON_FLICKER      1
#define ENABLE_NOISE             1
#define ENABLE_VIGNETTE          0

// Main palette accents from the official Cyberpunk 2077 UI style guide.
#define CYBERPUNK_RED            float3(0.969, 0.314, 0.286) // #F75049
#define CYBERPUNK_CYAN           float3(0.369, 0.965, 1.000) // #5EF6FF

// Thin display rows instead of a heavy CRT raster.
#define SCANLINE_PERIOD_PIXELS   3.0
// Scanner sweep shape, as a fraction of the screen height.
#define SWEEP_TRAIL_HEIGHT       0.08
#define SWEEP_EDGE_HEIGHT        0.004
// Glitch bands are re-rolled at this rate while a burst is active.
#define GLITCH_FRAME_RATE        20.0
#define GLITCH_MIN_BAND_PIXELS   3.0
#define GLITCH_MAX_BAND_PIXELS   26.0
#define VIGNETTE_STRENGTH        0.35

#if CYBERPUNK_SUBTLE_PRESET
#define GLOW_RADIUS_PIXELS       2.0
#define GLOW_STRENGTH            0.25
#define GLOW_ALPHA_STRENGTH      0.10
#define RGB_SPLIT_PIXELS         0.35
#define SCANLINE_STRENGTH        0.05
#define SWEEP_INTERVAL           15.0
#define SWEEP_STRENGTH           0.05
#define FLICKER_STRENGTH         0.10
#define NOISE_STRENGTH           0.004
#define GLITCH_INTERVAL          20.0
#define GLITCH_CHANCE            0.35
#define GLITCH_DURATION          0.12
#define GLITCH_SHIFT_PIXELS      6.0
#define GLITCH_RGB_SPLIT_PIXELS  1.5
#define GLITCH_BAND_DENSITY      0.15
#define GLITCH_TINT_STRENGTH     0.35
#define GLITCH_BAR_STRENGTH      0.015
#else
#define GLOW_RADIUS_PIXELS       2.5
#define GLOW_STRENGTH            0.45
#define GLOW_ALPHA_STRENGTH      0.20
#define RGB_SPLIT_PIXELS         0.75
#define SCANLINE_STRENGTH        0.10
// Seconds between scanner passes.
#define SWEEP_INTERVAL           9.0
#define SWEEP_STRENGTH           0.10
#define FLICKER_STRENGTH         0.20
#define NOISE_STRENGTH           0.010
// One possible glitch burst per interval, in seconds.
#define GLITCH_INTERVAL          7.0
#define GLITCH_CHANCE            0.55
#define GLITCH_DURATION          0.22
// Glitch offsets are measured in screen pixels.
#define GLITCH_SHIFT_PIXELS      14.0
#define GLITCH_RGB_SPLIT_PIXELS  3.5
#define GLITCH_BAND_DENSITY      0.28
#define GLITCH_TINT_STRENGTH     0.55
#define GLITCH_BAR_STRENGTH      0.035
#endif

static const float PI = 3.14159265359;

float hash12(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float luminance(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

// Returns 1 during a short glitch burst and 0 otherwise.
float glitchBurst()
{
#if ENABLE_GLITCHES
    float eventId = floor(Time / GLITCH_INTERVAL);
    float eventTime = Time - eventId * GLITCH_INTERVAL;
    float eventStart = hash12(float2(eventId, 13.0)) *
        (GLITCH_INTERVAL - GLITCH_DURATION);
    float eventEnabled = step(1.0 - GLITCH_CHANCE,
        hash12(float2(eventId, 29.0)));
    return eventEnabled * step(eventStart, eventTime) *
        step(eventTime, eventStart + GLITCH_DURATION);
#else
    return 0.0;
#endif
}

// x = horizontal UV offset, y = band mask, z = random accent selector.
// Bands use the physical pixel height so they look the same at every size.
float3 glitchBand(float2 uv, float burst)
{
#if ENABLE_GLITCHES
    float uiScale = max(Scale, 1.0);
    float frame = floor(Time * GLITCH_FRAME_RATE);
    float bandHeight = lerp(GLITCH_MIN_BAND_PIXELS, GLITCH_MAX_BAND_PIXELS,
        hash12(float2(frame, 3.0))) * uiScale;
    float band = floor(uv.y * Resolution.y / bandHeight);
    float mask = burst * step(1.0 - GLITCH_BAND_DENSITY,
        hash12(float2(band, frame)));
    float shift = (hash12(float2(band, frame + 41.0)) * 2.0 - 1.0) *
        GLITCH_SHIFT_PIXELS * uiScale / max(Resolution.x, 1.0);
    return float3(shift * mask, mask, hash12(float2(band, frame + 97.0)));
#else
    return float3(0.0, 0.0, 0.0);
#endif
}

float4 sampleRgbSplit(float2 uv, float splitPixels)
{
    float4 center = shaderTexture.Sample(samplerState, uv);
#if ENABLE_RGB_SPLIT || ENABLE_GLITCHES
    float2 offset = float2(splitPixels / max(Resolution.x, 1.0), 0.0);
    float4 redSample = shaderTexture.Sample(samplerState, saturate(uv + offset));
    float4 blueSample = shaderTexture.Sample(samplerState, saturate(uv - offset));
    center.r = redSample.r;
    center.b = blueSample.b;
    // Keep the separated fringes visible over the transparent background.
    center.a = max(center.a, max(redSample.a, blueSample.a));
#endif
    return center;
}

float4 sampleNeonGlow(float2 uv, float3 center)
{
#if ENABLE_NEON_GLOW
    float2 radius = GLOW_RADIUS_PIXELS * max(Scale, 1.0) /
        max(Resolution, float2(1.0, 1.0));
    float4 glow = 0.0;

    // A tight inner ring and a wider, weaker ring approximate a neon tube halo.
    [unroll]
    for (int i = 0; i < 8; i++)
    {
        float angle = i * (PI / 4.0);
        float2 direction = float2(cos(angle), sin(angle));
        glow += shaderTexture.Sample(samplerState,
            saturate(uv + direction * radius));
        glow += shaderTexture.Sample(samplerState,
            saturate(uv + direction * radius * 2.5)) * 0.6;
    }
    glow /= 8.0 * 1.6;

    float3 halo = max(glow.rgb - center * 0.35, 0.0) * GLOW_STRENGTH;
    return float4(halo, glow.a * GLOW_ALPHA_STRENGTH);
#else
    return float4(0.0, 0.0, 0.0, 0.0);
#endif
}

// Neon tubes buzz and occasionally stutter. Only the glow is affected so the
// glyphs themselves stay steady.
float neonFlicker()
{
#if ENABLE_NEON_FLICKER
    float buzz = 0.5 + 0.25 * sin(Time * 57.0) + 0.25 * sin(Time * 23.0);
    float stutter = step(0.97, hash12(float2(floor(Time * 18.0), 5.0)));
    return saturate(1.0 - FLICKER_STRENGTH * buzz - stutter * FLICKER_STRENGTH * 2.0);
#else
    return 1.0;
#endif
}

float scanlineMask(float2 pixelPosition)
{
#if ENABLE_SCANLINES
    float uiScale = max(Scale, 1.0);
    float row = 0.5 + 0.5 * cos(2.0 * PI * pixelPosition.y /
        (SCANLINE_PERIOD_PIXELS * uiScale));
    return 1.0 - SCANLINE_STRENGTH * row;
#else
    return 1.0;
#endif
}

// A thin scanner line travels down the screen with a short fading trail.
float scanSweep(float2 uv)
{
#if ENABLE_SCAN_SWEEP
    // Start above and finish below the screen so the line fully enters and exits.
    float position = frac(Time / SWEEP_INTERVAL) * 1.4 - 0.2;
    float distanceToLine = uv.y - position;
    float trail = smoothstep(-SWEEP_TRAIL_HEIGHT, 0.0, distanceToLine) *
        step(distanceToLine, 0.0);
    float edge = 1.0 - smoothstep(0.0, SWEEP_EDGE_HEIGHT, abs(distanceToLine));
    return saturate(trail * 0.5 + edge) * SWEEP_STRENGTH;
#else
    return 0.0;
#endif
}

float vignette(float2 uv)
{
#if ENABLE_VIGNETTE
    float2 centered = uv * 2.0 - 1.0;
    return 1.0 - VIGNETTE_STRENGTH * smoothstep(0.4, 1.4, dot(centered, centered));
#else
    return 1.0;
#endif
}

float4 main(PSInput input) : SV_TARGET
{
    float2 screenUv = input.uv;
    float uiScale = max(Scale, 1.0);

    float burst = glitchBurst();
    float3 glitch = glitchBand(screenUv, burst);
    float2 uv = saturate(screenUv + float2(glitch.x, 0.0));

    float splitPixels = glitch.y * GLITCH_RGB_SPLIT_PIXELS;
#if ENABLE_RGB_SPLIT
    splitPixels += RGB_SPLIT_PIXELS;
#endif

    float4 source = sampleRgbSplit(uv, splitPixels * uiScale);
    float4 glow = sampleNeonGlow(uv, source.rgb) * neonFlicker();

    float3 color = source.rgb + glow.rgb;
    float alpha = max(source.a, glow.a);

#if ENABLE_GLITCHES
    // Corrupted bands repaint their glyphs in red or the cooling cyan highlight.
    float3 accent = glitch.z < 0.5 ? CYBERPUNK_CYAN : CYBERPUNK_RED;
    float peak = max(color.r, max(color.g, color.b));
    color = lerp(color, accent * peak, glitch.y * GLITCH_TINT_STRENGTH);
    color += accent * glitch.y * GLITCH_BAR_STRENGTH;
    alpha = max(alpha, glitch.y * GLITCH_BAR_STRENGTH);
#endif

    color *= scanlineMask(input.pos.xy);

    float sweep = scanSweep(screenUv);
    color += CYBERPUNK_CYAN * sweep;
    alpha = max(alpha, sweep);

#if ENABLE_NOISE
    float noise = hash12(floor(input.pos.xy / uiScale) + floor(Time * 24.0) * 17.0);
    color += (noise - 0.5) * NOISE_STRENGTH;
#endif

    color *= vignette(screenUv);

    return float4(saturate(color), alpha);
}
