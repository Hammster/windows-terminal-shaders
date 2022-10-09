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
// --------------------

#define PI          3.141592654
#define TAU         (2.0*PI)
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))

#define TOLERANCE       0.0005
#define MAX_RAY_LENGTH  10.0
#define MAX_RAY_MARCHES 60
#define NORM_OFF        0.005

//float g_mod = 2.5;

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

static const float hoff = 0.;

static const vec3 skyCol     = HSV2RGB(vec3(hoff+0.50, 0.90, 0.25));
static const vec3 skylineCol = HSV2RGB(vec3(hoff+0.70, 0.95, 0.5));
static const vec3 sunCol     = HSV2RGB(vec3(hoff+0.80, 0.90, 0.5));
static const vec3 diffCol1   = HSV2RGB(vec3(hoff+0.75, 0.90, 0.5));
static const vec3 diffCol2   = HSV2RGB(vec3(hoff+0.95, 0.90, 0.5));

static const vec3 sunDir1    = normalize(vec3(0., 0.05, -1.0));

static const float lpf = 5.0;
static const vec3 lightPos1  = lpf*vec3(+1.0, 2.0, 3.0);
static const vec3 lightPos2  = lpf*vec3(-1.0, 2.0, 3.0);

// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
vec3 sRGB(vec3 t) {
  return mix(1.055*pow(t, unit3*(1./2.4)) - 0.055, 12.92*t, step(t, unit3*(0.0031308)));
}

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

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
  //  Found this somewhere on the interwebs
  //  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/distfunctions/
float rayPlane(vec3 ro, vec3 rd, vec4 p) {
  return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float box(vec2 p, vec2 b) {
  vec2 d = abs(p)-b;
  return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

vec3 render0(vec3 ro, vec3 rd) {
  vec3 col = unit3*(0.0);
  float sf = 1.0001-max(dot(sunDir1, rd), 0.0);
  col += skyCol*pow((1.0-abs(rd.y)), 8.0);
  col += (mix(0.0025, 0.125, tanh_approx(.005/sf))/abs(rd.y))*skylineCol;
  sf *= sf;
  col += sunCol*0.00005/sf;

  float tp1  = rayPlane(ro, rd, vec4(vec3(0.0, -1.0, 0.0), 6.0));

  if (tp1 > 0.0) {
    vec3 pos  = ro + tp1*rd;
    vec2 pp = pos.xz;
    float db = box(pp, vec2(5.0, 9.0))-3.0;

    col += unit3*(4.0)*skyCol*rd.y*rd.y*smoothstep(0.25, 0.0, db);
    col += unit3*(0.8)*skyCol*exp(-0.5*max(db, 0.0));
  }

  return clamp(col, 0.0, 10.0);;
}

float df(vec3 p, vec2 dim) {
  vec3 p0 = p;
  p0.xy = mul(ROT(0.2*p0.z-0.1*TIME), p0.xy);
  return -box(p0.xy, dim);
}

vec3 normal(vec3 pos, vec2 dim) {
  vec2  eps = vec2(NORM_OFF,0.0);
  vec3 nor;
  nor.x = df(pos+eps.xyy, dim) - df(pos-eps.xyy, dim);
  nor.y = df(pos+eps.yxy, dim) - df(pos-eps.yxy, dim);
  nor.z = df(pos+eps.yyx, dim) - df(pos-eps.yyx, dim);
  return normalize(nor);
}

float rayMarch(vec3 ro, vec3 rd, float initt, vec2 dim) {
  float t = initt;
  float tol = TOLERANCE;
  for (int i = 0; i < MAX_RAY_MARCHES; ++i) {
    if (t > MAX_RAY_LENGTH) {
      t = MAX_RAY_LENGTH;
      break;
    }
    float d = df(ro + rd*t, dim);
    if (d < TOLERANCE) {
      break;
    }
    t += d;
  }
  return t;
}

vec3 boxCol(vec3 col, vec3 nsp, vec3 ro, vec3 rd, vec3 nnor, vec3 nrcol) {
  float nfre  = 1.0+dot(rd, nnor);
  nfre        *= nfre;

  vec3 nld1   = normalize(lightPos1-nsp);
  vec3 nld2   = normalize(lightPos2-nsp);

  float ndif1 = max(dot(nld1, nnor), 0.0);
  ndif1       *= ndif1;

  float ndif2 = max(dot(nld2, nnor), 0.0);
  ndif2       *= ndif2;

  vec3 scol = unit3*(0.0);
  scol += diffCol1*ndif1;
  scol += diffCol2*ndif2;
  scol += 0.1*(skyCol+skylineCol);
  scol += nrcol*0.75*mix(unit3*(0.25), vec3(0.5, 0.5, 1.0), nfre);

  vec3 pp = nsp-ro;

  col = mix(col, scol, smoothstep(100.0, 20.0, dot(pp, pp)));

  return col;
}

vec3 render1(vec3 ro, vec3 rd) {
  vec3 col = 0.1*sunCol;

  vec2 dim = vec2(mix(1.25, 2.5, 0.5+0.5*sin(TAU*TIME/60.0)), 1.25);

  float nt    = rayMarch(ro, rd, .0, dim);
  if (nt < MAX_RAY_LENGTH) {
    vec3 nsp    = ro + rd*nt;
    vec3 nnor   = normal(nsp, dim);
    vec3 nref   = reflect(rd, nnor);
    float nrt   = rayMarch(nsp, nref, 0.2, dim);
    vec3 nrcol  = render0(nsp, nref);

    if (nrt < MAX_RAY_LENGTH) {
      vec3 nrsp   = nsp + nref*nrt;
      vec3 nrnor  = normal(nrsp, dim);
      vec3 nrref  = reflect(nref, nrnor);
      nrcol = boxCol(nrcol, nrsp, ro, nref, nrnor, render0(nrsp, nrref));
    }

    col = boxCol(col, nsp, ro, rd, nnor, nrcol);
  }

  return col;
}

vec3 effect(vec2 p) {
  const float fov = tan(TAU/(6.-0.6));
  const vec3 up = vec3(0.0, 1.0, 0.0);
  const vec3 ro = vec3(0.0, 0.0, 5.0);
  const vec3 la = vec3(0.0, 0.0, 0.);

  vec3 ww = normalize(la - ro);
  vec3 uu = normalize(cross(up, ww));
  vec3 vv = cross(ww,uu);
  vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

  vec3 col = render1(ro, rd);

  col -= 0.0333*vec3(1.0, 2.0, 2.0);

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

  vec3 col = effect(p);
  col = aces_approx(col);
  col = sRGB(col);

#if defined(WINDOWS_TERMINAL)
  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q+2.0*vec2(-1.0, 1.0)/RESOLUTION.xy);
  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);
#endif

  return vec4(col, 1.0);
}