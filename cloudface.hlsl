#define WINDOWS_TERMINAL

Texture2D shaderTexture;
SamplerState samplerState;

// --------------------
#if defined(WINDOWS_TERMINAL)
cbuffer PixelShaderSettings {
  float  Time;
  float  Scale;
  float2 Resolution;
  float4 Background;
};

#define TIME        Time
#define RESOLUTION  Resolution
#else
float time;
float2 resolution;

#define TIME        time
#define RESOLUTION  resolution
#endif
// --------------------

// --------------------
// GLSL => HLSL adapters
#define vec2  float2
#define vec3  float3
#define vec4  float4
#define mat2  float2x2
#define mat3  float3x3
#define fract frac
#define mix   lerp

float mod(float x, float y) {
  return x - y * floor(x/y);
}

vec2 mod(vec2 x, vec2 y) {
  return x - y * floor(x/y);
}

static const vec2 unit2 = vec2(1.0, 1.0);
static const vec3 unit3 = vec3(1.0, 1.0, 1.0);
static const vec4 unit4 = vec4(1.0, 1.0, 1.0, 1.0);

// --------------------

// License CC0: Face in the clouds
//  Symmetry around y-axis can often create an illusion of a face
//  or a human body. I was playing around with smeared FBM
//  and added some glowing points to mislead the brain to think it's eyes
//  of a malevolent cloud being

#define PI          3.141592654
#define TAU         (2.0*PI)
#define TTIME       (TIME*TAU)
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))
#define DOT2(x)     dot(x, x)

static const mat2 frot = 2.0*ROT(PI/3.33);

struct State {
  vec2 _vx;
  vec2 _vy;

  vec2 _wx;
  vec2 _wy;
};

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
float sRGB(float t) { return mix(1.055*pow(t, 1./2.4) - 0.055, 12.92*t, step(t, 0.0031308)); }
// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
vec3 sRGB(in vec3 c) { return vec3 (sRGB(c.x), sRGB(c.y), sRGB(c.z)); }

// License: Unknown, author: Matt Taylor (https://github.com/64), found: https://64.github.io/tonemapping/
vec3 aces_approx(vec3 v) {
  v = max(v, 0.0);
  v *= 0.6f;
  float a = 2.51f;
  float b = 0.03f;
  float c = 2.43f;
  float d = 0.59f;
  float e = 0.14f;
  return clamp((v*(a*v+b))/(v*(c*v+d)+e), 0.0f, 1.0f);
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/smin/smin.htm
float pmin(float a, float b, float k) {
  float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}

float vesica(vec2 p, vec2 sz) {
  if (sz.x < sz.y) {
    sz = sz.yx;
  } else {
    p  = p.yx;
  }
  vec2 sz2 = sz*sz;
  float d  = (sz2.x-sz2.y)/(2.0*sz.y);
  float r  = sqrt(sz2.x+d*d);
  float b  = sz.x;
  p = abs(p);
  return ((p.y-b)*d>p.x*b) ? length(p-vec2(0.0,b))
                           : length(p-vec2(-d,0.0))-r;
}

float pabs(float a, float k) {
  return -pmin(a, -a, k);
}

float noise(vec2 p) {
  float a = sin(p.x);
  float b = sin(p.y);
  float c = 0.5 + 0.5*cos(p.x + p.y);
  float d = mix(a, b, c);
  return d;
}

float fbm(vec2 p) {
  float f = 0.0;
  float a = 1.0;
  float s = 0.0;
  float m = 2.0;
  for (int x = 0; x < 4; ++x) {
    f += a*noise(p); p = mul(frot, p);
    m += 0.01;
    s += a;
    a *= 0.5;
  }
  return f/s;
}

vec2 df(vec2 p) {
  vec2 p0 = p;
  p0.x = abs(p0.x);
  p0 -= vec2(0.75, 0.4);
  p0 = mul(ROT(PI/9.0), p0);
  float d0 = vesica(p0, vec2(0.45, 0.2));
  float g0 = length(p0);

  float d = d0;
  float g = g0;

  return vec2(d, g);
}

float warp(vec2 p, inout State state, out vec2 v, out vec2 w) {
  float d = df(p).x-0.1;
  p.x = -pabs(p.x, 0.125);

  v = vec2(fbm(p + state._vx), fbm(p + state._vy));
  w = vec2(fbm(p + 3.0*v + state._wx), fbm(p + 3.0*v + state._wy));

  float h = fbm(p + 2.25*w);

  float aa = 0.2;
  h *= mix(1.0, 0.05, smoothstep(aa, -aa, d));

  return h*smoothstep(2.5, 0.15, abs(p.x+0.5*p.y));
}

vec3 normal(vec2 p, inout State state) {
  vec2 v;
  vec2 w;
  float eps = 2.0/RESOLUTION.y;
  vec2 e = vec2(eps, 0);

  vec3 n;
  n.x = warp(p + e.xy, state, v, w) - warp(p - e.xy, state, v, w);
  n.y = 2.0*e.x;
  n.z = warp(p + e.yx, state, v, w) - warp(p - e.yx, state, v, w);

  return normalize(n);
}

vec3 smear(vec2 p, vec2 q) {
  float aa = 2.0/RESOLUTION.y;

  State state;
//  state._vx = mul(vec2(0.0, 0.0), ROT(TTIME/1000.0));
  state._vx = unit2*0.0;
  state._vy = mul(vec2(3.2, 1.3), ROT(TTIME/900.0));
  state._wx = mul(vec2(1.7, 9.2), ROT(TTIME/800.0));
  state._wy = mul(vec2(8.3, 2.8), ROT(TTIME/700.0));

  vec2 v;
  vec2 w;

  vec2 d2 = df(p);
  float d = abs(d2.x) - 2.0*aa;
  float g = d2.y;
  float h = warp(p, state, v, w);
  vec3 n  = normal(p, state);

  vec3 ld1  = normalize(vec3(0.5, 0.2, 0.4));
  vec3 ld2  = normalize(vec3(-0.5, 0.2, -0.4));
  vec3 lcol1= HSV2RGB(vec3(0.9, 0.333, 1.0));
  vec3 lcol2= HSV2RGB(vec3(0.6, 0.125, 2.0));
  vec3 acol = HSV2RGB(vec3(0.6, 0.0, 0.3));

  float dif1 = pow(max(dot(ld1, n), .0), 1.0);
  float dif2 = pow(max(dot(ld2, n), .0), 2.0);

  const vec3 col11 = HSV2RGB(vec3(0.9, 0.9, 0.5));
  const vec3 col21 = HSV2RGB(vec3(0.4, 0.9, 0.5));
  const vec3 col12 = HSV2RGB(vec3(0.6, 0.9, 1.5));
  const vec3 col22 = HSV2RGB(vec3(0.0, 0.9, 1.5));

  vec3 col1 = mix(col11, col12, q.x);
  vec3 col2 = mix(col21, col22, q.y);

  vec3 col = unit3*(0.0);
  float lv = length(v);
  float lw = length(w);
  col += lv*col1*dif1*lcol1;
  col += lw*col2*dif1*lcol1;
  col += lv*col1*dif2*lcol2;
  col += lw*col2*dif2*lcol2;
  col += lv*col1*acol;
  col += lw*col2*acol;
  col *= smoothstep(0.0, 1., (h*h+0.05+0.75*0.125*(1.0+p.y)));
  col += mix(5.0, 1.0, 0.5+0.5*sin(TTIME/8.0))*HSV2RGB(vec3(0.6, 0.8, 1.0))*exp(-40.0*g);
  col -= vec3(0.1, 0.2, 0.1)*0.25;
  return col;
}

//
// PS_OUTPUT ps_main(in PS_INPUT In)
#if defined(WINDOWS_TERMINAL)
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
#else
float4 ps_main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
#endif
{
  vec2 q = tex;
  vec2 p = -1.0 + 2.0*q;
#if defined(WINDOWS_TERMINAL)
  p.y = -p.y;
#endif
  p.x *= RESOLUTION.x/RESOLUTION.y;

  vec3 col = smear(p, q);
  col = aces_approx(col);
  col = sRGB(col);
  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);
  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);
  return vec4(col, 1.0);
}



