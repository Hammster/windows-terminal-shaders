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
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))
#define PI          3.141592654
#define TAU         (2.0*PI)

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

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

// License: Unknown, author: Martijn Steinrucken, found: https://www.youtube.com/watch?v=VmrIDyYiJBA
vec2 hextile(inout vec2 p) {
  // See Art of Code: Hexagonal Tiling Explained!
  // https://www.youtube.com/watch?v=VmrIDyYiJBA
  const vec2 sz       = vec2(1.0, sqrt(3.0));
  const vec2 hsz      = 0.5*sz;

  vec2 p1 = mod(p, sz)-hsz;
  vec2 p2 = mod(p - hsz, sz)-hsz;
  vec2 p3 = dot(p1, p1) < dot(p2, p2) ? p1 : p2;
  vec2 n = ((p3 - p + hsz)/sz);
  p = p3;

  n -= (0.5);
  // Rounding to make hextile 0,0 well behaved
  return round(n*2.0)*0.5;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float hexagon(vec2 p, float r) {
  const vec3 k = vec3(-0.866025404,0.5,0.577350269);
  p = abs(p);
  p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
  p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
  return length(p)*sign(p.y);
}

float shape(vec2 p) {
  return hexagon(p.yx, 0.4)-0.075;
}

float cellHeight(float h) {
  return 0.05*2.0*(-h);
}

vec3 cell(vec2 p, float h) {
  float hd = shape(p);

  const float he = 0.0075*2.0;
  float aa = he;
  float hh = -he*smoothstep(aa, -aa, hd);

  return vec3(hd, hh, cellHeight(h));
}

float height(vec2 p, float h) {
  return cell(p, h).y;
}

vec3 normal(vec2 p, float h) {
  vec2 e = vec2(4.0/RESOLUTION.y, 0);

  vec3 n;
  n.x = height(p + e.xy, h) - height(p - e.xy, h);
  n.y = height(p + e.yx, h) - height(p - e.yx, h);
  n.z = 2.0*e.x;

  return normalize(n);
}

vec3 planeColor(vec3 ro, vec3 rd, vec3 lp, vec3 pp, vec3 pnor, vec3 bcol, vec3 pcol) {
  vec3  ld = normalize(lp-pp);
  float dif  = pow(max(dot(ld, pnor), 0.0), 1.0);
  vec3 col = pcol;
  col = mix(bcol, col, dif);
  return col;
}

static const mat2 rots[6] = {
    ROT(0.0*TAU/6.0)
  , ROT(1.0*TAU/6.0)
  , ROT(2.0*TAU/6.0)
  , ROT(3.0*TAU/6.0)
  , ROT(4.0*TAU/6.0)
  , ROT(5.0*TAU/6.0)
};

static const vec2 off = vec2(1.0, 0.0);

static const vec2 offs[6] = {
    mul(rots[0], off)
  , mul(rots[1], off)
  , mul(rots[2], off)
  , mul(rots[3], off)
  , mul(rots[4], off)
  , mul(rots[5], off)
  };

float cutSlice(vec2 p, vec2 off) {
  // A bit like this but unbounded
  // https://www.shadertoy.com/view/MlycD3
  p.x = abs(p.x);
  off.x *= 0.5;

  vec2 nn = normalize(vec2(off));
  vec2 n  = vec2(nn.y, -nn.x);

  float d0 = length(p-off);
  float d1 = -(p.y-off.y);
  float d2 = dot(n, p);

  bool b = p.x > off.x && (dot(nn, p)-dot(nn, off)) < 0.0;

  return b ? d0 : max(d1, d2);
}

float hexSlice(vec2 p, int n) {
  n = 6-n;
  n = n%6;
  p = mul(rots[n], p);
  p = p.yx;
  const vec2 dim  = vec2((0.5)*2.0/sqrt(3.0), (0.5));
  return cutSlice(p, dim);
}

vec3 backdrop(vec2 p, vec2 q) {
  const float z = 0.327;
  float aa = 2.0/(z*RESOLUTION.y);

  p.yx = p;

  vec3 lp = vec3(3.0, 0.0, 1.0);

  p -= vec2(0.195, 0.);
  p /= z;

  float toff = 0.2*TIME;
  p.x += toff;
  lp.x += toff;

  vec2 hp  = p;
  vec2 hn  = hextile(hp);
  float hh = hash(hn);
  vec3 c   = cell(hp, hh);
  float cd = c.x;
  float ch = c.z;

  vec3 fpp = vec3(p, ch);
  vec3 bpp = vec3(p, 0.0);

  vec3 ro = vec3(0.0, 0.0, 1.0);
  vec3 rd = normalize(fpp-ro);

  vec3  bnor = vec3(0.0, 0.0, 1.0);
  vec3  bdif = lp-bpp;
  float bl2  = dot(bdif, bdif);

  vec3  fnor = normal(hp, hh);
  vec3  fld  = normalize(lp-fpp);

  float sf = 0.0;

  for (int i = 0; i < 6; ++i) {
    vec2  ioff= offs[i];
    vec2  ip  = p+ioff;
    vec2  ihn = hextile(ip);
    float ihh = hash(ihn);
    float ich = cellHeight(ihh);
    float iii = (ich-ch)/fld.z;
    vec3  ipp = vec3(hp, ch)+iii*fld;

    float hsd = hexSlice(ipp.xy, i);
    if (ich > ch) {
      sf += exp(-20.0*tanh_approx(1.0/(10.0*iii))*max(hsd+0., 0.0));
    }
  }

  const float sat = 0.23;
  const vec3 bcol0 = HSV2RGB(vec3(240.0/36.0, sat, 0.14));
  const vec3 bcol1 = HSV2RGB(vec3(240.0/36.0, sat, 0.19));
  vec3 bpcol = planeColor(ro, rd, lp, bpp, bnor, unit3*(0.0), bcol0);
  vec3 fpcol = planeColor(ro, rd, lp, fpp, fnor, bpcol, bcol1);

  vec3 col = bpcol;
  col = mix(col, fpcol, smoothstep(aa, -aa, cd));
  col *= 1.0-tanh_approx(sf);

  float fo = exp(-0.025*max(bl2-0., 0.0));
  col *= fo;
  col = mix(bpcol, col, fo);

  return col;
}

vec3 effect(vec2 p, vec2 q) {
  float aa = 2.0/RESOLUTION.y;

  float dh = hexagon(p, 0.6);
  float odh = abs(dh+0.016) - 0.08;

  vec3 col = backdrop(p, q);

  vec3 bcol = hsv2rgb(vec3(0.6, mix(0.95, 0.8, p.x+p.y),0.5));
  col = mix(col, bcol, 0.4*smoothstep(aa, -aa, odh));

  const vec3 gcol0 = HSV2RGB(vec3(0.6, 0.95, 0.005));
  const vec3 gcol1 = HSV2RGB(vec3(0.65, 0.85, 0.005));
  col += gcol0/(abs(odh));
//  col += gcol1/(abs(odh)+0.05*p.y*p.y);
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

  vec3 col = effect(p, q);
  col = aces_approx(col);
  col = sRGB(col);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);

  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}



