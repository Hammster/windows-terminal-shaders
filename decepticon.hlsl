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

// License CC0: The Decepticons
//  Felt like creating a distance field for the decepticons logo
//  The distance field isn't perfect but the result came out kind of nice anyway

#define ROT(a)          mat2(cos(a), sin(a), -sin(a), cos(a))
#define PI              3.141592654
#define TAU             (2.0*PI)
#define TTIME           (TAU*TIME)
#define PSIN(x)         (0.5+0.5*sin(x))
#define L2(x)           dot(x, x)

// https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl
vec3 hsv2rgb(vec3 c) {
  const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float tanh_approx(float x) {
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// https://iquilezles.org/articles/smin
float pmin(float a, float b, float k) {
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

float pmax(float a, float b, float k) {
  return -pmin(-a, -b, k);
}

float pabs(float a, float k) {
  return pmax(a, -a, k);
}

// https://iquilezles.org/articles/distfunctions2d
float isosceles(vec2 p, vec2 q) {
    p.x = abs(p.x);
    vec2 a = p - q*clamp( dot(p,q)/dot(q,q), 0.0, 1.0 );
    vec2 b = p - q*vec2( clamp( p.x/q.x, 0.0, 1.0 ), 1.0 );
    float s = -sign( q.y );
    vec2 d = min( vec2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                  vec2( dot(b,b), s*(p.y-q.y)  ));
    return -sqrt(d.x)*sign(d.y);
}

float plane(vec2 p, vec3 plane) {
  return dot(p, plane.xy) + plane.z;
}

vec2 refl(vec2 p, vec2 n) {
  p -= n*min(0.0, dot(p, n))*2.0;
  return p;
}

vec2 irefl(vec2 p, vec2 n) {
  p -= n*max(0.0, dot(p, n))*2.0;
  return p;
}

vec2 decepticon(vec2 p) {
  p.x = abs(p.x);

  vec2 p0 = p;
  p0 -= vec2(0.77, -0.68);
  p0 = irefl(p0, normalize(vec2(1.0, 1.275)));
  float d0 = plane(p0, vec3(normalize(vec2(-1., 2.375)), 0.0));

  vec2 p1 = p;
  p1 -= vec2(0.8, 0.68);
  p1 = irefl(p1, normalize(vec2(1.4, 1.0)));
  float d1 = plane(p1, vec3(normalize(vec2(-1., 2.9)), 0.0));


  vec2 p2 = p;
  p2 -= vec2(0.7, 0.085);
  p2 = mul(ROT(2.11), p2);
  float d2 = isosceles(p2, vec2(0.125, 0.65));

  vec2 p3 = p;
  float d3 = plane(p3, vec3(normalize(vec2(-1.29, 1.0)), 0.635));
  d3 = abs(d3)- 0.029;

  vec2 p4 = p;
  p4 -= vec2(0.225, 0.115);
  p4 = refl(p4, normalize(vec2(1.0, 1.72)));
  float d4 = plane(p4, vec3(normalize(vec2(-5.0, 1.0)), 0.0));
  float d4_ = d4;
  d4 = abs(d4)- 0.025;

  vec2 p5 = p;
  p5 -= vec2(0.0, 0.0395);
  float d5 = plane(p5, vec3(normalize(vec2(-1.0, 2.8)), 0.0));
  d5 = abs(d5) - 0.025;
  d5 = max(d5, d4_);

  vec2 p6 = p;
  p6 -= vec2(0.0, 0.196);
  float d6 = plane(p6, vec3(normalize(vec2(-1.0, 2.8)), 0.0));
  d6 = abs(d6) - 0.025;
  d6 = max(d6, d4_);

  vec2 p7 = p;
  p7 -= vec2(0.61, 0.0);
  float d7 = plane(p7, vec3(normalize(vec2(-3.7, 1.0)), 0.0));
  d5 = max(d5, -d7);
  d6 = max(d6, -d7);

  vec2 p8 = p;
  p8 -= vec2(0.085, 0.585);
  p8 = irefl(p8, normalize(vec2(2.075, 1.0)));
  float d8 = -plane(p8, vec3(normalize(vec2(0.0, 1.0)), 0.0));

  vec2 p9 = p;
  p9 -= vec2(0.00, 0.155);
  float d9 = isosceles(p9, vec2(0.085, 0.29));

  float d = -d0;
  d = max(d, d1);
  d = min(d, -d4_);
  d = max(d, -d2);
  d = max(d, -d3);
  d = max(d, -d4);
  d = max(d, -d5);
  d = max(d, -d6);
  d = max(d, -d8);
  d = max(d, -d9);
  return vec2(d0, d);
}

float df(vec2 p) {
  const float z = 0.9;
  vec2 d0 = decepticon(p/z);
  return -d0.y*z;
}

float hf(vec2 p) {
  float d = df(p);
  float height = 0.5*(smoothstep(-0.05, 0.01, d));
  return pmax(height, 0.5, 0.125);
}

float height(vec2 p) {
  return tanh_approx(hf(p));
}

vec3 normal(vec2 p) {
  vec2 eps = vec2(4.0/RESOLUTION.y, 0.0);

  vec3 n;

  n.x = height(p - eps.xy) - height(p + eps.xy);
  n.y = 2.0*eps.x;
  n.z = height(p - eps.yx) - height(p + eps.yx);

  return normalize(n);
}

vec3 postProcess(vec3 col, vec2 q)  {
  col=sqrt(clamp(col,0.0,1.0));
  col=col*0.6+0.4*col*col*(3.0-2.0*col);  // contrast
  col=mix(col, unit3*(dot(col, unit3*(0.33))), -0.4);  // saturation
  col*=0.5+0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.7);  // vigneting
  return col;
}

vec3 effect(vec2 p, vec2 q) {
  const vec3 up  = vec3(0.0, 1.0, 0.0);
  const vec3 lp1 = 1.0*vec3(1.0, 1.25, 1.0);
  const vec3 lp2 = 1.0*vec3(-1.0, 2.5, 1.0);

  float aa = 2.0/RESOLUTION.y;

  float hh = PSIN(sqrt(0.5)*TTIME/60.0);
  float l  = length(p);

  float d  = df(p);
  float h  = height(p);
  vec3  n  = normal(p);

  vec3 ro = vec3(0.0, mix(1.0, 10.0, PSIN(TTIME/30.0)), 0.0);
  vec3 pp = vec3(p.x, 0.0, p.y);

  vec3 po = vec3(p.x, h, p.y);
  vec3 rd = normalize(po - ro);

  // Lots of random choices below from an old shader of mine
  vec3 ld1 = normalize(lp1 - po);
  vec3 ld2 = normalize(lp2 - po);

  vec3 hsv = vec3(hh+mix(0.6, 0.9, PSIN(TIME*0.1-10.0*l+(p.x+p.y))), tanh_approx(h*h*1.0), tanh_approx(1.0*h+.1));
  hsv.yz = clamp(hsv.yz, 0.0, 1.0);
  vec3 baseCol1 = hsv2rgb(hsv);
  vec3 baseCol2 = sqrt(baseCol1.zyx);
  vec3 matCol   = 1.0-baseCol1*baseCol2;

  float diff1 = max(dot(n, ld1), 0.0);
  float diff2 = max(dot(n, ld2), 0.0);

  vec3  ref   = reflect(rd, n);
  float ref1  = max(dot(ref, ld1), 0.0);
  float ref2  = max(dot(ref, ld2), 0.0);

  baseCol1 *= mix(0.0, 4.0, 1.0/L2(lp1 - po));
  baseCol2 *= mix(0.0, 3.0, 1.0/L2(lp2 - po));

  vec3 col = unit3*(0.0);
  const float basePow = 1.25;
  col += 1.00*matCol*baseCol1*mix(0.1, 1.0, pow(diff1, 4.0))*0.5;
  col += 0.50*matCol*baseCol2*mix(0.1, 1.0, pow(diff2, 2.0))*0.5;
  col = pow(col, unit3*(1.25));
  col += 4.0*baseCol1*pow(ref1, 20.0);
  col += 2.0*baseCol2*pow(ref2, 10.0);

  float gd = d;
  const float glow_lw = 0.025;
  gd = abs(gd)-glow_lw*2.0;
  gd = abs(gd)-glow_lw;
  vec3 glowCol = unit3*(1.0);
  glowCol = mix(baseCol1, glowCol, max(dot(ld1, up), 0.0));
  glowCol = mix(baseCol2, glowCol, max(dot(ld2, up), 0.0));
  vec3 finalGlowCol = glowCol*exp(-20.0*max(gd, 0.0));
  finalGlowCol = mix(finalGlowCol, glowCol, smoothstep(-aa, aa, -d+glow_lw));

  float tuneOut = sqrt(q.x+(1.0-q.y))*0.85;
  col = clamp(col, 0.0, 1.0);
  col = mix(col, unit3*(0.0), smoothstep(-aa, aa, -d));

  col -= 0.5*0.125*tuneOut*finalGlowCol;

  col += vec3(0.125*0.75*((1.0-q.x)+q.y), 0.0, 0.0)*length(p);
  p.x = abs(p.x);
  col += smoothstep(10.0, 29.0, TIME)*vec3(mix(0.125, 0.5, PSIN(TTIME/10.0)), 0.0, 0.0)*exp(-9.0*(length(p-vec2(0.25, -0.15))));

  vec3 dcol = mix(unit3*(0.0), unit3*(0.5), smoothstep(-aa, aa, d));
  col = mix(dcol, col, smoothstep(5.0, 10.0, TIME));

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

  vec3 col = unit3*(0.0);
  col = effect(p, q);
  col = postProcess(col, q);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);

  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}



