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

// License CC0 - Complex atanh - darkmode edition
// More work tinkering based on mlas shader Complex atanh - https://www.shadertoy.com/view/tsBXRW
#define DARKMODE
#define FASTATAN
#define SPEED     0.5

#define PI          3.141592654
#define PI_2        (0.5*PI)
#define TAU         (2.0*PI)
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))

#if defined(FASTATAN)
#define ATAN atan_approx
#else
#define ATAN atan2
#endif

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5,size) - size*0.5;
  return c;
}

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
  //  Found this somewhere on the interwebs
  //  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// License: MIT, author: Pascal Gilcher, found: https://www.shadertoy.com/view/flSXRV
float atan_approx(float y, float x) {
  float cosatan2 = x / (abs(x) + abs(y));
  float t = PI_2 - cosatan2 * PI_2;
  return y < 0.0 ? -t : t;
}

// Complex trig functions found at: Complex Atanh - https://www.shadertoy.com/view/tsBXRW
//  A very cool shader
vec2 cmul(vec2 z, vec2 w) {
  return vec2 (z.x*w.x-z.y*w.y, z.x*w.y+z.y*w.x);
}

vec2 cinv(vec2 z) {
  float t = dot(z,z);
  return vec2(z.x,-z.y)/t;
}

vec2 cdiv(vec2 z, vec2 w) {
  return cmul(z,cinv(w));
}

vec2 clog(vec2 z) {
  float r = length(z);
  return vec2(log(r),ATAN(z.y,z.x));
}

// Inverse hyperbolic tangent
vec2 catanh(vec2 z) {
  return 0.5*clog(cdiv(vec2(1,0)+z,vec2(1,0)-z));
}

// My own attempt at an ctanh
vec2 cexp(vec2 z) {
  float r = exp(z.x);
  return r*vec2(cos(z.y), sin(z.y));
}

vec2 ctanh(vec2 z) {
  z = cexp(2.0*z);
  return cdiv(vec2(1,0)-z,vec2(1,0)+z);
}

float circle8(vec2 p, float r) {
  p *= p;
  p *= p;
  return pow(dot(p, p),1.0/8.0)-r;
}

vec2 transform(vec2 z, out float aa, out vec2 hscale) {
  float A = 9.0;
  float B = 2.0;

  vec2 rot = vec2(A, B);
  float a = TIME*SPEED;
  z *= 2.0;
  z = catanh(-0.5*z+0.5*vec2(sin(a*0.234*sqrt(0.5)), sin(a*0.234)))+catanh(mul(ROT(0.1234*a), z));
  z /= PI;

  aa = fwidth(z.x);
  aa *= length(rot);
  z = cmul(rot,z);
  z.x += 0.5*a;

  hscale = 1.0/rot.yx;
  return z;
}

vec3 effect(vec3 col, vec2 op) {
  op = mul(ROT(0.05*TIME*SPEED), op);

  float aaa = 2.0/RESOLUTION.y;
  float aa;
  vec2 hscale;
  vec2 p = transform(op, aa, hscale);

  vec2 n = round(p);
  p -= n; // Neat!

  float d = circle8(p, 0.45);

  vec2 pf = p;
  float sf = sign(pf.x*pf.y);
  pf = abs(pf);
  float df = sf*min(pf.x, pf.y);
  float flip = smoothstep(aa, -aa, df);

#if defined(DARKMODE)
  col = 0.0*unit3;
  float fo = tanh_approx(0.333*aaa/(aa*hscale.x*hscale.y));
  vec3 rgb = hsv2rgb(vec3(fract(0.65+0.2*sin(0.5*TIME*SPEED+0.25*flip+PI*dot(n, hscale))), mix(0.0, 0.75, fo), mix(1.0, 0.05, fo*fo)));
#else
  col = vec3(1.0);
  float fo = tanh_approx(0.125*aaa/(aa*hscale.x*hscale.y));
  vec3 rgb = hsv2rgb(vec3(fract(0.05*TIME*SPEED+0.125*flip+0.5*dot(hscale, n)), mix(0.0, 0.75, fo), mix(1.0, 0.85, fo*fo)));
#endif

  rgb = mix(rgb, smoothstep(0.5, 1.0, rgb), flip);
  col = mix(col, rgb, smoothstep(aa, -aa, d));

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

  vec3 col = unit3;
  col = effect(col, p);
  col = clamp(col, 0.0, 1.0);
  col = sqrt(col);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);

  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}
