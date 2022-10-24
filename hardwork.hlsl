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

// CC0: Nested transparent sphere4s
//  Reminded by the weekly shader "simple refraction test" by drschizzo (https://www.shadertoy.com/view/flcSW2)
//  that refractions are cool looking decided to tinker a bit with them again.
//  Thought it looked neat so shared.


#define PI              3.141592654
#define TAU             (2.0*PI)

#define TOLERANCE       0.0001
#define MAX_RAY_LENGTH  20.0
#define MAX_RAY_MARCHES 60
#define NORM_OFF        0.001
#define MAX_BOUNCES     5

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

static const vec3 skyCol     = HSV2RGB(vec3(0.6, 0.86, 1.0));
static const vec3 lightPos   = vec3(0.0, 10.0, 0.0);

static const float initt       = 0.1;
static const float refraction  = 0.8;

struct State {
  mat3 _rot;
  vec2 _mat;
  vec3 _beer;
};

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

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float box(vec2 p, vec2 b) {
  vec2 d = abs(p)-b;
  return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/intersectors/intersectors.htm
float rayPlane(vec3 ro, vec3 rd, vec4 p) {
  return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);
}

mat3 rot_z(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat3(
      c,s,0
    ,-s,c,0
    , 0,0,1
    );
}

mat3 rot_y(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat3(
      c,0,s
    , 0,1,0
    ,-s,0,c
    );
}

mat3 rot_x(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat3(
      1, 0,0
    , 0, c,s
    , 0,-s,c
    );
}

float sphere4(vec3 p, float r) {
  p *= p;
  return pow(dot(p, p), 0.25)-r;
}

vec3 skyColor(vec3 ro, vec3 rd) {
  vec3 col = clamp(unit3*(0.0025/abs(rd.y))*skyCol, 0.0, 1.0);

  float tp0  = rayPlane(ro, rd, vec4(vec3(0.0, 1.0, 0.0), 4.0));
  float tp1  = rayPlane(ro, rd, vec4(vec3(0.0, -1.0, 0.0), 6.0));
  float tp = tp1;
  tp = max(tp0,tp1);


  if (tp1 > 0.0) {
    vec3 pos  = ro + tp1*rd;
    vec2 pp = pos.xz;
    float db = box(pp, vec2(6.0, 9.0))-1.0;

    col += unit3*(4.0)*skyCol*rd.y*rd.y*smoothstep(0.25, 0.0, db);
    col += unit3*(0.8)*skyCol*exp(-0.5*max(db, 0.0));
  }

  if (tp0 > 0.0) {
    vec3 pos  = ro + tp0*rd;
    vec2 pp = pos.xz;
    float ds = length(pp) - 0.5;

    col += unit3*(0.25)*skyCol*exp(-.5*max(ds, 0.0));
  }

  return clamp(col, 0.0, 10.0);
}

float df(vec3 p, inout State state) {
  p = mul(state._rot, p);
  vec3 p0 = p;
  p = mul(state._rot, p);
  vec3 p1 = p;
  float d0 = sphere4(p0, 1.0);
  float d1 = sphere4(p1, 1.75);
  d1 = max(d1, -(d0-0.2));

  vec2 mat = vec2(0.05, 0.5);
  vec3 beer = -vec3(2., 1.0, 2.0);

  float d = d0;
  if (d1 < d) {
    mat = vec2(0.99, 0.6);
    d = d1;
    beer = vec3(0.1, 0.2, 0.);
  }

  state._mat = mat;
  state._beer = beer;
  return d;
}

vec3 normal(vec3 pos, inout State state) {
  vec2  eps = vec2(NORM_OFF,0.0);
  vec3 nor;
  nor.x = df(pos+eps.xyy, state) - df(pos-eps.xyy, state);
  nor.y = df(pos+eps.yxy, state) - df(pos-eps.yxy, state);
  nor.z = df(pos+eps.yyx, state) - df(pos-eps.yyx, state);
  return normalize(nor);
}

float rayMarch(vec3 ro, vec3 rd, float dfactor, inout State state, out int ii) {
  float t = 0.0;
  float tol = dfactor*TOLERANCE;
  ii = MAX_RAY_MARCHES;
  for (int i = 0; i < MAX_RAY_MARCHES; ++i) {
    if (t > MAX_RAY_LENGTH) {
      t = MAX_RAY_LENGTH;
      break;
    }
    float d = dfactor*df(ro + rd*t, state);
    if (d < TOLERANCE) {
      ii = i;
      break;
    }
    t += d;
  }
  return t;
}

vec3 render(vec3 ro, vec3 rd) {
  vec3 agg = unit3*(0.0);
  vec3 ragg = unit3*(1.0);

  State state;
  state._rot = mul(rot_x(0.2*TIME),rot_y(0.3*TIME));
  state._mat = unit2;
  state._beer = unit3;

  bool isInside = df(ro, state) < 0.0;

  for (int bounce = 0; bounce < MAX_BOUNCES; ++bounce) {
    float dfactor = isInside ? -1.0 : 1.0;
    float mragg = min(min(ragg.x, ragg.y), ragg.z);
    if (mragg < 0.025) break;
    int iter;
    float st = rayMarch(ro, rd, dfactor, state, iter);
    const float mrm = 1.0/float(MAX_RAY_MARCHES);
    float ii = float(iter)*mrm;
    vec2 mat = state._mat;
    vec3 beer = state._beer;
    if (st >= MAX_RAY_LENGTH) {
      agg += ragg*skyColor(ro, rd);
      break;
    }

    vec3 sp = ro+rd*st;

    vec3 sn = dfactor*normal(sp, state);
    float fre = 1.0+dot(rd, sn);
    fre *= fre;
    fre = mix(0.1, 1.0, fre);

    vec3 ld     = normalize(lightPos - sp);

    float dif   = max(dot(ld, sn), 0.0);
    vec3 ref    = reflect(rd, sn);
    const float irefraction = 1.0/refraction;
    vec3 refr   = refract(rd, sn, !isInside ? refraction : irefraction);
    vec3 rsky   = skyColor(sp, ref);
    const vec3 dcol = HSV2RGB(vec3(0.6, 0.85, 1.0));
    vec3 col = unit3*(0.0);
    col += dcol*dif*dif*(1.0-mat.x);
    col += rsky*mat.y*fre*smoothstep(1.0, 0.9, fre);

    if (isInside) {
      ragg *= exp(-st*beer);
    }
    agg += ragg*col;

    ragg *= mat.x;
    if (refr.x == 0.0 && refr.y == 0.0 && refr.z == 0.0) {
      rd = ref;
    } else {
      isInside = !isInside;
      rd = refr;
    }

    // TODO: if inside should also compute beer factor based on initt
    ro = sp+initt*rd;
  }

  return agg;
}

vec3 effect(vec2 p) {
  vec3 ro = 0.8*vec3(0.0, 2.0, 5.0);
  const vec3 la = vec3(0.0, 0.0, 0.0);
  const vec3 up = vec3(0.0, 1.0, 0.0);

  vec3 ww = normalize(la - ro);
  vec3 uu = normalize(cross(up, ww ));
  vec3 vv = normalize(cross(ww,uu));
  const float fov = tan(TAU/6.);
  vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

  vec3 col = render(ro, rd);

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
  col = effect(p);
  col = aces_approx(col);
  col = sRGB(col);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);

  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}



