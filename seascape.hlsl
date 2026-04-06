// Original (https://www.shadertoy.com/view/Ms2SD1):
// "fully-procedural sea surface computing. without textures."
/*
 * "Seascape" by Alexander Alekseev aka TDM - 2014
 * License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
 * Contact: tdmaav@gmail.com
 */
// HLSL port by https://github.com/Schleicher-Thomas

#define NUM_STEPS 32
#define PI 3.141592
#define EPSILON 1e-3
#define EPSILON_NRM (0.1 / Resolution.x)

// sea
#define ITER_GEOMETRY 3
#define ITER_FRAGMENT 5
#define SEA_HEIGHT 0.6
#define SEA_CHOPPY 4.0
#define SEA_SPEED 0.8
#define SEA_FREQ 0.16
#define SEA_BASE float3(0.0, 0.09, 0.18)
#define SEA_WATER_COLOR float3(0.8, 0.9, 0.6) * 0.6
#define SEA_TIME (1.0 + Time * SEA_SPEED)

Texture2D inputTexture : register(t0);
SamplerState samplerState : register(s0);

static float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);

cbuffer PixelShaderSettings
{
	float Time;
	float MouseX;
	float2 Resolution;
};

// math
float3x3 fromEuler(float3 ang)
{
	float2 a1 = float2(sin(ang.x), cos(ang.x));
	float2 a2 = float2(sin(ang.y), cos(ang.y));
	float2 a3 = float2(sin(ang.z), cos(ang.z));
	
	float3x3 m;
	m[0] = float3(a1.y * a3.y + a1.x * a2.x * a3.x, a1.y * a2.x * a3.x + a3.y * a1.x, -a2.y * a3.x);
	m[1] = float3(-a2.y * a1.x, a1.y * a2.y, a2.x);
	m[2] = float3(a3.y * a1.x * a2.x + a1.y * a3.x, a1.x * a3.x - a1.y * a3.y * a2.x, a2.y * a3.y);
	
	return m;
}

float hash(float2 p)
{
	float h = dot(p, float2(127.1, 311.7));
	return frac(sin(h) * 43758.5453123);
}

float noise(float2 p)
{
	float2 i = floor(p);
	float2 f = frac(p);
	float2 u = f * f * (3.0 - 2.0 * f);
	
	return -1.0 + 2.0 * lerp(
		lerp(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), u.x),
		lerp(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), u.x),
		u.y);
}

// lighting
float diffuse(float3 n, float3 l, float p)
{
	return pow(dot(n, l) * 0.4 + 0.6, p);
}

float specular(float3 n, float3 l, float3 e, float s)
{
	float nrm = (s + 8.0) / (PI * 8.0);
	return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
}

// sky
float3 getSkyColor(float3 e)
{
	e.y = (max(e.y, 0.0) * 0.8 + 0.2) * 0.8;
	return float3(pow(1.0 - e.y, 2.0), 1.0 - e.y, 0.6 + (1.0 - e.y) * 0.4) * 1.1;
}

// sea
float sea_octave(float2 uv, float choppy)
{
	uv += noise(uv);
	float2 wv = 1.0 - abs(sin(uv));
	float2 swv = abs(cos(uv));
	wv = lerp(wv, swv, wv);
	return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}

float map(float3 p)
{
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	float2 uv = p.xz;
	uv.x *= 0.75;
	
	float d, h = 0.0;
	for (int i = 0; i < ITER_GEOMETRY; i++)
	{
		d = sea_octave((uv + SEA_TIME) * freq, choppy);
		d += sea_octave((uv - SEA_TIME) * freq, choppy);
		h += d * amp;
		uv = mul(octave_m, uv);
		freq *= 1.9;
		amp *= 0.22;
		choppy = lerp(choppy, 1.0, 0.2);
	}
	return p.y - h;
}

float map_detailed(float3 p)
{
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	float2 uv = p.xz;
	uv.x *= 0.75;
	
	float d, h = 0.0;
	for (int i = 0; i < ITER_FRAGMENT; i++)
	{
		d = sea_octave((uv + SEA_TIME) * freq, choppy);
		d += sea_octave((uv - SEA_TIME) * freq, choppy);
		h += d * amp;
		uv = mul(octave_m, uv);
		freq *= 1.9;
		amp *= 0.22;
		choppy = lerp(choppy, 1.0, 0.2);
	}
	return p.y - h;
}

float3 getSeaColor(float3 p, float3 n, float3 l, float3 eye, float3 dist)
{
	float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
	fresnel = min(fresnel * fresnel * fresnel, 0.5);
	
	float3 reflected = getSkyColor(reflect(eye, n));
	float3 refracted = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12;
	
	float3 color = lerp(refracted, reflected, fresnel);
	
	float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
	color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;
	
	color += specular(n, l, eye, 600.0 * rsqrt(dot(dist, dist)));
	
	return color;
}

// tracing
float3 getNormal(float3 p, float eps) {
	float3 n;
	n.y = map_detailed(p);
	n.x = map_detailed(float3(p.x + eps, p.y, p.z)) - n.y;
	n.z = map_detailed(float3(p.x, p.y, p.z + eps)) - n.y;
	n.y = eps;
	return normalize(n);
}

float heightMapTracing(float3 ori, float3 dir, out float3 p) {
	float tm = 0.0;
	float tx = 1000.0;
	float hx = map(ori + dir * tx);
	
	if (hx > 0.0) {
		p = ori + dir * tx;
		return tx;
	}
	
	float hm = map(ori);
	for (int i = 0; i < NUM_STEPS; i++) {
		float tmid = lerp(tm, tx, hm / (hm - hx));
		p = ori + dir * tmid;
		float hmid = map(p);
		
		if (hmid < 0.0) {
			tx = tmid;
			hx = hmid;
		}
		else {
			tm = tmid;
			hm = hmid;
		}
		
		if (abs(hmid) < EPSILON) break;
	}
	return lerp(tm, tx, hm / (hm - hx));
}

float3 getPixel(float2 coord, float time) {
	float2 uv = coord / Resolution.xy;
	uv = uv * 2.0 - 1.0;
	uv.x *= Resolution.x / Resolution.y;

	// ray
	float3 ang = float3(sin(time * 3.0) * 0.1, sin(time) * 0.2 + 0.3, time);
	float3 ori = float3(0.0, 3.5, time * 5.0);
	float3 dir = normalize(float3(uv.xy, -2.0));
	dir.z += length(uv) * 0.14;
	dir = normalize(dir);
	dir = mul(float3x3(
		fromEuler(ang)[0],
		fromEuler(ang)[1],
		fromEuler(ang)[2]
	), dir);

	// tracing
	float3 p;
	heightMapTracing(ori, dir, p);
	float3 dist = p - ori;
	float3 n = getNormal(p, dot(dist, dist) * EPSILON_NRM);
	float3 light = normalize(float3(0.0, 1.0, 0.8));

	// color
	return lerp(
		getSkyColor(dir),
		getSeaColor(p, n, light, dir, dist),
		pow(smoothstep(0.0, -0.02, dir.y), 0.2));
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET {
	float2 fragCoord = pos.xy;
	fragCoord.y = Resolution.y - fragCoord.y;  // Flip Y coordinate
	float time = Time * 0.3 + MouseX * 0.01;

	// preserve text
	float4 original = inputTexture.Sample(samplerState, tex);
	// text pixels have alpha = 1
	if (original.a > 0.9) {
		return original;
	}

	float3 color = getPixel(fragCoord, time);

	// post
	float3 shaderColor = pow(color, float3(0.65, 0.65, 0.65));
	float shaderAlpha = 0.7;
	float3 finalColor = lerp(original.rgb, shaderColor, shaderAlpha);
	return float4(finalColor, 1.0);
}
