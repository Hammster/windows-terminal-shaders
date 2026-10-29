// Flat Fallout / Pip-Boy inspired CRT shader for Windows Terminal.
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

// 0 = preserve palette colors, 1 = apply Fallout phosphor color grading.
#define FALLOUT_COLOR_MODE       0
// Dark palette variant. The dedicated light shader sets this to 1.
#define FALLOUT_LIGHT_MODE       0
// 1 = use the built-in lower-intensity daily-use preset.
#define FALLOUT_SUBTLE_PRESET    0

#define ENABLE_CURVATURE         0
#define ENABLE_GLOW              1
#define ENABLE_SCANLINES         1
#define ENABLE_NOISE             1
#define ENABLE_GLITCHES          0
#define ENABLE_VIGNETTE          0
#define ENABLE_CHROMATIC_ABERRATION 1
#define ENABLE_GLASS_REFRACTION     1
#define ENABLE_COLOR_BLEED          1
#define ENABLE_EDGE_DEFOCUS         1
#define ENABLE_PHOSPHOR_MASK        1
#define ENABLE_HALATION             1
#define ENABLE_CONVERGENCE_DRIFT    1
#define ENABLE_GLASS_GLARE          1
#define ENABLE_VERTICAL_SYNC_SLIP   1

#define PHOSPHOR_COLOR            float3(0.07, 1.00, 0.15)
#define CURVATURE_AMOUNT          0.035

// Pull the terminal texture away from the dark CRT rim so edge text stays readable.
#define CONTENT_INSET             float2(0.0, 0.0)

// Strong, wide oval vignette like an old recessed terminal screen.
#define VIGNETTE_STRENGTH         0.82
#define VIGNETTE_INNER_RADIUS     0.35
#define VIGNETTE_OUTER_RADIUS     1.30
#define VIGNETTE_HORIZONTAL_SCALE 0.75
#define VIGNETTE_EDGE_SOFTNESS    0.025
#if FALLOUT_SUBTLE_PRESET
#define GLOW_STRENGTH              0.20
#define SCANLINE_STRENGTH          0.14
#define NOISE_STRENGTH             0.006
#define BLACK_LEVEL                0.012
#define BRIGHTNESS                 1.12
#define COLOR_SATURATION           1.18
#define GLITCH_STRENGTH            0.006
#define GLITCH_DISPLACEMENT        0.0015
#define CHROMATIC_OFFSET_PIXELS    0.45
#define REFRACTION_STRENGTH_PIXELS 0.30
#define COLOR_BLEED_PIXELS         0.80
#define COLOR_BLEED_STRENGTH       0.15
#define EDGE_DEFOCUS_PIXELS        0.60
#define EDGE_DEFOCUS_STRENGTH      0.12
#define PHOSPHOR_MASK_STRENGTH     0.08
#define HALATION_RADIUS_PIXELS     2.50
#define HALATION_STRENGTH          0.20
#define HALATION_ALPHA_STRENGTH    0.10
#define CONVERGENCE_DRIFT_PIXELS   0.20
#define GLASS_GLARE_STRENGTH       0.030
#define VERTICAL_SYNC_INTERVAL     42.0
#define VERTICAL_SYNC_CHANCE       0.12
#define VERTICAL_SYNC_SLIP_PIXELS  1.00
#else
#define GLOW_STRENGTH              0.38
#define SCANLINE_STRENGTH          0.26
#define NOISE_STRENGTH             0.014
#define BLACK_LEVEL                0.016
#define BRIGHTNESS                 1.22
#define COLOR_SATURATION           1.35
// Increase for more frequent horizontal signal tears. Recommended: 0.0-0.08.
#define GLITCH_STRENGTH            0.012
#define GLITCH_DISPLACEMENT        0.004
// Glass optics. Values are measured in screen pixels.
#define CHROMATIC_OFFSET_PIXELS    1.25
#define REFRACTION_STRENGTH_PIXELS 0.80
#define COLOR_BLEED_PIXELS         1.75
#define COLOR_BLEED_STRENGTH       0.30
#define EDGE_DEFOCUS_PIXELS        1.25
#define EDGE_DEFOCUS_STRENGTH      0.28
#define PHOSPHOR_MASK_STRENGTH     0.18
#define HALATION_RADIUS_PIXELS     4.50
#define HALATION_STRENGTH          0.42
#define HALATION_ALPHA_STRENGTH    0.20
#define CONVERGENCE_DRIFT_PIXELS   0.65
#define GLASS_GLARE_STRENGTH       0.070
#define VERTICAL_SYNC_INTERVAL     28.0
#define VERTICAL_SYNC_CHANCE       0.28
#define VERTICAL_SYNC_SLIP_PIXELS  2.50
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

float2 curveScreen(float2 uv)
{
    float2 p = uv * 2.0 - 1.0;
    float2 bend = float2(p.y * p.y, p.x * p.x);
    p *= 1.0 + CURVATURE_AMOUNT * bend;
    return p * 0.5 + 0.5;
}

float2 fitContentInsideScreen(float2 uv)
{
    float2 visibleArea = 1.0 - CONTENT_INSET * 2.0;
    return (uv - CONTENT_INSET) / visibleArea;
}

float screenVignette(float2 uv)
{
    float2 centered = uv * 2.0 - 1.0;
    centered.x *= VIGNETTE_HORIZONTAL_SCALE;

    float radius = dot(centered, centered);
    float oval = 1.0 - VIGNETTE_STRENGTH * smoothstep(
        VIGNETTE_INNER_RADIUS, VIGNETTE_OUTER_RADIUS, radius);

    // Fade the extreme rim to black without making the whole image blurry.
    float2 distanceToEdge = min(uv, 1.0 - uv);
    float rim = smoothstep(0.0, VIGNETTE_EDGE_SOFTNESS,
        min(distanceToEdge.x, distanceToEdge.y));

    return saturate(oval * rim);
}

float rollingRefresh(float2 uv)
{
    float beam = frac(Time * 0.085);
    float distanceToBeam = abs(uv.y - beam);
    distanceToBeam = min(distanceToBeam, 1.0 - distanceToBeam);
    return 1.0 + 0.055 * (1.0 - smoothstep(0.0, 0.075, distanceToBeam));
}

float2 addSignalInstability(float2 uv)
{
#if ENABLE_GLITCHES
    float band = floor(uv.y * 120.0);
    float timeBlock = floor(Time * 5.0);
    float randomBand = hash12(float2(band, timeBlock));
    float active = step(1.0 - GLITCH_STRENGTH, randomBand);
    float displacement = (hash12(float2(timeBlock, band + 17.0)) - 0.5) *
        GLITCH_DISPLACEMENT;
    uv.x += displacement * active;

    // Very small continuous analog drift keeps the image from looking digital.
    uv.x += sin(uv.y * 22.0 + Time * 1.7) * 0.00035;
#endif
    return uv;
}

float2 addGlassRefraction(float2 uv, float2 glassUv)
{
#if ENABLE_GLASS_REFRACTION
    float2 pixel = 1.0 / max(Resolution, float2(1.0, 1.0));
    float2 wave;
    wave.x = sin(glassUv.y * PI * 13.0 + Time * 0.11);
    wave.x += 0.5 * sin(glassUv.y * PI * 31.0 - Time * 0.07);
    wave.y = 0.65 * sin(glassUv.x * PI * 11.0 - Time * 0.09);
    uv += wave * pixel * REFRACTION_STRENGTH_PIXELS;
#endif
    return uv;
}

float2 addVerticalSyncSlip(float2 uv)
{
#if ENABLE_VERTICAL_SYNC_SLIP
    float eventId = floor(Time / VERTICAL_SYNC_INTERVAL);
    float eventPhase = frac(Time / VERTICAL_SYNC_INTERVAL);
    float eventEnabled = step(1.0 - VERTICAL_SYNC_CHANCE,
        hash12(float2(eventId, 47.0)));
    float pulse = 1.0 - smoothstep(0.0, 0.006, abs(eventPhase - 0.5));
    float direction = hash12(float2(eventId, 83.0)) * 2.0 - 1.0;
    uv.y += eventEnabled * pulse * direction *
        VERTICAL_SYNC_SLIP_PIXELS / max(Resolution.y, 1.0);
#endif
    return uv;
}

float edgeOpticsAmount(float2 glassUv)
{
    float2 centered = glassUv * 2.0 - 1.0;
    return smoothstep(0.30, 1.15, length(centered));
}

float4 sampleOpticalSource(float2 uv, float2 glassUv, float lightTheme)
{
    float2 pixel = 1.0 / max(Resolution, float2(1.0, 1.0));
    float edgeAmount = edgeOpticsAmount(glassUv);
    float4 center = shaderTexture.Sample(samplerState, uv);
    float4 result = center;

#if ENABLE_CHROMATIC_ABERRATION || ENABLE_CONVERGENCE_DRIFT
    float2 channelOffset = float2(0.0, 0.0);
#if ENABLE_CHROMATIC_ABERRATION
    float2 radial = glassUv * 2.0 - 1.0;
    float2 radialDirection = normalize(radial + float2(0.0001, -0.0001));
    channelOffset += radialDirection * pixel *
        CHROMATIC_OFFSET_PIXELS * edgeAmount;
#endif
#if ENABLE_CONVERGENCE_DRIFT
    float2 convergenceDirection = float2(
        sin(Time * 0.23), cos(Time * 0.19));
    channelOffset += convergenceDirection * pixel * CONVERGENCE_DRIFT_PIXELS;
#endif
    float4 redSample = shaderTexture.Sample(samplerState,
        clamp(uv + channelOffset, float2(0.0, 0.0), float2(1.0, 1.0)));
    float4 blueSample = shaderTexture.Sample(samplerState,
        clamp(uv - channelOffset, float2(0.0, 0.0), float2(1.0, 1.0)));
    result.r = redSample.r;
    result.b = blueSample.b;
#endif

#if ENABLE_COLOR_BLEED
    float2 bleedOffset = float2(COLOR_BLEED_PIXELS * pixel.x, 0.0);
    float4 bleedLeft = shaderTexture.Sample(samplerState,
        clamp(uv - bleedOffset, float2(0.0, 0.0), float2(1.0, 1.0)));
    float4 bleedRight = shaderTexture.Sample(samplerState,
        clamp(uv + bleedOffset, float2(0.0, 0.0), float2(1.0, 1.0)));
    float4 horizontalBleed = (bleedLeft + bleedRight) * 0.5;
    // Bright phosphor blooms on dark screens; dark ink spreads on light ones.
    float3 bleedTarget = lerp(max(result.rgb, horizontalBleed.rgb),
        min(result.rgb, horizontalBleed.rgb), lightTheme);
    result.rgb = lerp(result.rgb, bleedTarget, COLOR_BLEED_STRENGTH);
    result.a = max(result.a, horizontalBleed.a * COLOR_BLEED_STRENGTH);
#endif

#if ENABLE_EDGE_DEFOCUS
    float2 focusOffset = pixel * EDGE_DEFOCUS_PIXELS;
    float4 softEdges = 0.0;
    softEdges += shaderTexture.Sample(samplerState, clamp(
        uv + float2(focusOffset.x, 0.0), float2(0.0, 0.0), float2(1.0, 1.0)));
    softEdges += shaderTexture.Sample(samplerState, clamp(
        uv - float2(focusOffset.x, 0.0), float2(0.0, 0.0), float2(1.0, 1.0)));
    softEdges += shaderTexture.Sample(samplerState, clamp(
        uv + float2(0.0, focusOffset.y), float2(0.0, 0.0), float2(1.0, 1.0)));
    softEdges += shaderTexture.Sample(samplerState, clamp(
        uv - float2(0.0, focusOffset.y), float2(0.0, 0.0), float2(1.0, 1.0)));
    softEdges *= 0.25;
    result = lerp(result, softEdges, EDGE_DEFOCUS_STRENGTH * edgeAmount);
#endif

    return result;
}

float4 sampleHalation(float2 uv, float4 center)
{
#if ENABLE_HALATION
    float2 pixel = 1.0 / max(Resolution, float2(1.0, 1.0));
    float2 radius = pixel * HALATION_RADIUS_PIXELS;
    float4 halo = 0.0;
    halo += shaderTexture.Sample(samplerState, clamp(
        uv + float2(radius.x, 0.0), float2(0.0, 0.0), float2(1.0, 1.0)));
    halo += shaderTexture.Sample(samplerState, clamp(
        uv - float2(radius.x, 0.0), float2(0.0, 0.0), float2(1.0, 1.0)));
    halo += shaderTexture.Sample(samplerState, clamp(
        uv + float2(0.0, radius.y), float2(0.0, 0.0), float2(1.0, 1.0)));
    halo += shaderTexture.Sample(samplerState, clamp(
        uv - float2(0.0, radius.y), float2(0.0, 0.0), float2(1.0, 1.0)));
    halo *= 0.25;

    float haloMask = smoothstep(0.06, 0.75, luminance(halo.rgb));
    float3 haloColor = max(halo.rgb - center.rgb * 0.35, 0.0) *
        HALATION_STRENGTH * haloMask;
    float haloAlpha = halo.a * HALATION_ALPHA_STRENGTH * haloMask;
    return float4(haloColor, haloAlpha);
#else
    return float4(0.0, 0.0, 0.0, 0.0);
#endif
}

float3 applyPhosphorMask(float3 color, float2 pixelPosition)
{
#if ENABLE_PHOSPHOR_MASK
    float uiScale = max(Scale, 1.0);
    float column = fmod(floor(pixelPosition.x / uiScale), 3.0);
    float dim = 1.0 - PHOSPHOR_MASK_STRENGTH;
    float3 mask = column < 1.0 ? float3(1.0, dim, dim) :
        (column < 2.0 ? float3(dim, 1.0, dim) : float3(dim, dim, 1.0));
    return color * mask;
#else
    return color;
#endif
}

float3 applyGlassGlare(float3 color, float2 glassUv, float contentAlpha)
{
#if ENABLE_GLASS_GLARE
    float2 glarePosition = glassUv - float2(0.28, 0.12);
    float diagonal = abs(glarePosition.y + glarePosition.x * 0.22);
    float band = 1.0 - smoothstep(0.02, 0.16, diagonal);
    float upperFade = 1.0 - smoothstep(0.05, 0.58, glassUv.y);
    float glare = band * upperFade * GLASS_GLARE_STRENGTH * contentAlpha;
    color += float3(0.72, 1.0, 0.78) * glare;
#endif
    return color;
}

float3 sampleGlow(float2 uv, float3 center)
{
#if ENABLE_GLOW
    float2 texel = 1.0 / max(Resolution, float2(1.0, 1.0));
    float3 glow = 0.0;

    glow += shaderTexture.Sample(samplerState, uv + float2( 2.0,  0.0) * texel).rgb;
    glow += shaderTexture.Sample(samplerState, uv + float2(-2.0,  0.0) * texel).rgb;
    glow += shaderTexture.Sample(samplerState, uv + float2( 0.0,  2.0) * texel).rgb;
    glow += shaderTexture.Sample(samplerState, uv + float2( 0.0, -2.0) * texel).rgb;
    glow += shaderTexture.Sample(samplerState, uv + float2( 1.5,  1.5) * texel).rgb;
    glow += shaderTexture.Sample(samplerState, uv + float2(-1.5, -1.5) * texel).rgb;
    glow *= 1.0 / 6.0;

    return max(glow - center * 0.32, 0.0) * GLOW_STRENGTH;
#else
    return 0.0;
#endif
}

float scanlineMask(float2 pixelPosition)
{
#if ENABLE_SCANLINES
    float uiScale = max(Scale, 1.0);
    float raster = 0.5 + 0.5 * cos(PI * pixelPosition.y / uiScale);
    float fineLines = 1.0 - SCANLINE_STRENGTH * raster;

    // Subtle vertical phosphor lattice. It is intentionally mild for text clarity.
    float lattice = 0.965 + 0.035 * sin(PI * pixelPosition.x / uiScale);
    return fineLines * lattice;
#else
    return 1.0;
#endif
}

float4 main(PSInput input) : SV_TARGET
{
    float2 glassUv = input.uv;
    float2 uv = glassUv;
    float lightTheme = FALLOUT_LIGHT_MODE;

#if ENABLE_CURVATURE
    uv = curveScreen(uv);
#endif

    // Shrink the source image into the safe area while the vignette remains
    // attached to the outer glass coordinates.
    uv = fitContentInsideScreen(uv);

    // Black rounded CRT corners. Avoid sampling outside the terminal texture.
    if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0)
    {
#if FALLOUT_COLOR_MODE
        return float4(0.0, BLACK_LEVEL * 0.35, 0.0, 1.0);
#else
        return float4(BLACK_LEVEL * 0.2, BLACK_LEVEL * 0.2, BLACK_LEVEL * 0.2, 1.0);
#endif
    }

    uv = addSignalInstability(uv);
    uv = addGlassRefraction(uv, glassUv);
    uv = addVerticalSyncSlip(uv);
    uv = clamp(uv, float2(0.0, 0.0), float2(1.0, 1.0));

    float4 source = sampleOpticalSource(uv, glassUv, lightTheme);
    float3 glowSource = sampleGlow(uv, source.rgb);
    float4 halation = sampleHalation(uv, source);
    glowSource *= 1.0 - lightTheme;
    halation *= 1.0 - lightTheme;
    glowSource += halation.rgb;
    source.a = max(source.a, halation.a);
    float sourceEnergy = max(luminance(source.rgb), max(source.r, source.b) * 0.62);
    float glowEnergy = luminance(glowSource);
    sourceEnergy = pow(saturate(sourceEnergy), 0.82) + glowEnergy;
    float3 phosphorColor = PHOSPHOR_COLOR * sourceEnergy;
    float3 color;

#if FALLOUT_COLOR_MODE
    float3 preservedColor = (source.rgb + glowSource) * float3(0.94, 1.04, 0.96);
    // Neutral foreground colors become green phosphor, while saturated ANSI
    // colors retain their Fallout palette hue.
    float maximumChannel = max(source.r, max(source.g, source.b));
    float minimumChannel = min(source.r, min(source.g, source.b));
    float saturation = (maximumChannel - minimumChannel) / max(maximumChannel, 0.001);
    float preserveAnsiColor = smoothstep(0.12, 0.32, saturation);
    float visibleForeground = smoothstep(0.075, 0.18, maximumChannel);
    float phosphorizeAmount = (1.0 - preserveAnsiColor) * visibleForeground;
    color = lerp(preservedColor, phosphorColor, phosphorizeAmount);
#else
    color = source.rgb + glowSource;
#endif

    // Additive phosphor bloom is appropriate for a dark CRT, but it washes out
    // dark glyphs on a light screen. Preserve the sampled ink colors instead.
    color = lerp(color, source.rgb, lightTheme);

#if FALLOUT_COLOR_MODE
    float colorLuminance = luminance(color);
    color = lerp(float3(colorLuminance, colorLuminance, colorLuminance),
        color, COLOR_SATURATION);
#endif

    color *= lerp(BRIGHTNESS, 1.0, lightTheme);

    // A dim powered-on phosphor floor makes scanlines visible in black areas.
#if FALLOUT_COLOR_MODE
    color += BLACK_LEVEL * PHOSPHOR_COLOR * (1.0 - lightTheme);
#else
    color += BLACK_LEVEL * float3(0.65, 0.65, 0.65) * (1.0 - lightTheme);
#endif

    float scanlines = scanlineMask(input.pos.xy);
    color *= lerp(scanlines, lerp(1.0, scanlines, 0.22), lightTheme);
    float3 phosphorMasked = applyPhosphorMask(color, input.pos.xy);
    color = lerp(phosphorMasked, lerp(color, phosphorMasked, 0.18), lightTheme);
    float refresh = rollingRefresh(glassUv);
    color *= lerp(refresh, lerp(1.0, refresh, 0.20), lightTheme);

    // Irregular power flicker, restrained so text remains comfortable to read.
    float flicker = 0.988 + 0.012 * sin(Time * 41.0);
    flicker += (hash12(float2(floor(Time * 24.0), 7.0)) - 0.5) * 0.012;
    color *= lerp(flicker, lerp(1.0, flicker, 0.20), lightTheme);

#if ENABLE_NOISE
    float noise = hash12(floor(glassUv * Resolution) + floor(Time * 30.0));
#if FALLOUT_COLOR_MODE
    color += PHOSPHOR_COLOR * (noise - 0.5) * NOISE_STRENGTH *
        lerp(1.0, 0.30, lightTheme);
#else
    color += (noise - 0.5) * NOISE_STRENGTH * lerp(1.0, 0.30, lightTheme);
#endif
#endif

    float3 colorBeforeGlare = color;
    color = applyGlassGlare(color, glassUv, source.a);
    color = lerp(color, colorBeforeGlare, lightTheme);

#if ENABLE_VIGNETTE
    float vignette = screenVignette(glassUv);
    color *= lerp(vignette, lerp(1.0, vignette, 0.25), lightTheme);
#endif

    return float4(saturate(color), source.a);
}
