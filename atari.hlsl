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

#define SPEED       0.75

#define PI          3.141592654
#define PI_2        (0.5*PI)
#define TAU         (2.0*PI)
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))

static const vec3 lightPos = vec3(1.0, 2.0, 2.0);
static const float planeY  = -0.75;

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
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5,size) - size*0.5;
  return c;
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/spherefunctions/spherefunctions.htm
vec2 raySphere(vec3 ro, vec3 rd, vec4 sph) {
  vec3 oc = ro - sph.xyz;
  float b = dot( oc, rd );
  float c = dot( oc, oc ) - sph.w*sph.w;
  float h = b*b - c;
  if (h < 0.0) return unit2*(-1.0);
  h = sqrt(h);
  return vec2(-b - h, -b + h);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float box(vec2 p, vec2 b) {
  vec2 d = abs(p)-b;
  return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float parabola(vec2 pos, float k) {
  pos.x = abs(pos.x);
  float ik = 1.0/k;
  float p = ik*(pos.y - 0.5*ik)/3.0;
  float q = 0.25*ik*ik*pos.x;
  float h = q*q - p*p*p;
  float r = sqrt(abs(h));
  float x = (h>0.0) ?
        pow(q+r,1.0/3.0) - pow(abs(q-r),1.0/3.0)*sign(r-q) :
        2.0*cos(atan2(r,q)/3.0)*sqrt(p);
  return length(pos-vec2(x,k*x*x)) * sign(pos.x-x);
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/smin/smin.htm
float pmin(float a, float b, float k) {
  float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/smin/smin.htm
float pmax(float a, float b, float k) {
  return -pmin(-a, -b, k);
}

vec3 toSpherical(vec3 p) {
  float r   = length(p);
  float t   = acos(p.z/r);
  float ph  = atan2(p.y, p.x);
  return vec3(r, t, ph);
}

float atari(vec2 p) {
  p.x = abs(p.x);
  float db = box(p, vec2(0.36, 0.32));

  float dp0 = -parabola(p-vec2(0.4, -0.235), 4.0);
  float dy0 = p.x-0.115;
  float d0 = mix(dp0, dy0, smoothstep(-0.25, 0.125, p.y)); // Very hacky

  float dp1 = -parabola(p-vec2(0.4, -0.32), 3.0);
  float dy1 = p.x-0.07;
  float d1 = mix(dp1, dy1, smoothstep(-0.39, 0.085, p.y)); // Very hacky

  float d2 = p.x-0.035;
  const float sm = 0.025;
  float d = 1E6;
  d = min(d, max(d0, -d1));;
  d = pmin(d, d2, sm);
  d = pmax(d, db, sm);

  return d;
}

vec3 atari(vec3 col, vec2 p) {
  float aa = 2.0/RESOLUTION.y;
  const float z = 2.0;
  float d = atari(p/z)*z;

  col = mix(col, unit3*(2.0), smoothstep(aa, -aa, d));

  return col;
}

float bouncef(float tt) {
  float tm = sqrt(SPEED)*tt;
  float t = fract(tm)-0.5;
  return 5.0*(0.25 - t*t);
}

float dots(vec2 p, float f, float mf) {
  const vec2 gz = unit2*(PI/100.0);
  vec2  n = mod2(p, gz);
  p.x     /= f;
  float d = length(p)-0.005;

  return d;
}

float grid(vec2 p, float f, float mf) {
  const float steps = 20.0;
  vec2 gz = vec2(PI/(steps*mf), PI/steps);
  vec2  n = mod2(p, gz);
  p.y     *= f;
  float d = min(abs(p.x), abs(p.y))-0.0025;
  return d;
}

vec4 ballDim(float bf) {
  float b = 0.25*bf;
  const float r = 0.5;
  return vec4(vec3(0.0, b+planeY+r, 0.0), r);
}

vec3 skyColor(float bf, vec3 ro, vec3 rd, vec3 nrd) {
  float pi = -(ro.y-(planeY))/rd.y;

  if (pi < 0.0) return unit3*(1.0);

  vec3 pp = ro+rd*pi;
  vec3 npp= ro+nrd*pi;
  vec3 pld = normalize(lightPos-pp);

  float aa = length(npp-pp);

  vec4 ball = ballDim(bf);

  vec2 bi = raySphere(pp, pld, ball);

  const float rr = 20.0;
  float a = SPEED*TIME/(rr);
  vec2 pp2 = pp.xz+rr*vec2(cos(a), sin(a));
  vec2 np2 = mod2(pp2, unit2*(0.5));
  float pd = min(abs(pp2.x), abs(pp2.y))-0.01;

  vec3 col = unit3*(1.0);

  col = mix(col, unit3*(0.5), smoothstep(aa, -aa, pd));

  if (bi.x > 0.0) {
    col *= mix(1.0, 1.0-exp(-bi.x), tanh_approx(2.0*(bi.y-bi.x)));
  }

  col = mix(unit3*(1.0), col, exp(-0.2*max(pi-2.0, 0.0)));

  return col;
}

vec3 color(float bf, vec3 ro, vec3 rd, vec3 nrd) {
  vec4 ball = ballDim(bf);

  vec3 sky = skyColor(bf, ro, rd, nrd);

  vec2 bi = raySphere(ro, rd, ball);
  float st = tanh_approx(10.0*(bi.y-bi.x));
  if (st < 0.0) {
    return sky;
  }

  vec3 sp   = ro + bi.x*rd;
  vec3 nsp  = ro + bi.x*nrd;
  float aa  = length(sp-nsp);

  vec3 sld = normalize(lightPos-sp);
  sp -= ball.xyz;
  vec3 sn   = normalize(sp);
  vec3 sr   = reflect(rd, sn);

  float sfre= 1.0+dot(sn, rd);
  sfre *= sfre;

  sp.yz = mul(ROT(TIME*sqrt(0.5)), sp.yz);
  sp.xy = mul(ROT(TIME*1.234), sp.xy);

  vec3 ssp = toSpherical(sp.zxy);

  vec2 sp2 = ssp.yz;
  float sf  = sin(sp2.x);
  float slf2 = -ceil(log(sf)/log(2.0));
  float smf = pow(2.0, slf2);

  float sdiff = max(dot(sld, sn), 0.0);
  float sspe  = pow(max(dot(sld, sr), 0.0), 0.5);
  float sdd = dots(sp2, sf, smf);
  float sdg = grid(sp2, sf, smf);

  vec3 scol = unit3*(0.0);
  float sdcol = mix(0.05, 0.1, sdiff);
  scol += sdcol;
  scol = mix(scol, unit3*(sdcol*2.0), smoothstep(aa, -aa, sdd));
  scol = mix(scol, unit3*(sdcol*3.0), smoothstep(aa, -aa, sdg));
  scol += sspe*sfre;

  return mix(sky, scol, st);
}

vec3 background(vec2 p) {
  vec3 ro = vec3(0.0, 0, 2.0);
  vec3 la = vec3(0.0 ,0.0, 0.0);

  vec2 np = p + unit2*(2.0/RESOLUTION.y);

  vec3 ww = normalize(la - ro);
  vec3 uu = normalize(cross(vec3(0.0,1.0,0.0), ww));
  vec3 vv = cross(ww,uu);
  float rdd = 2.0;
  vec3 rd = normalize(-p.x*uu + p.y*vv + rdd*ww);
  vec3 nrd= normalize(-np.x*uu + np.y*vv + rdd*ww);

  float bf = bouncef(TIME);
  return color(bf, ro, rd, nrd);
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

  vec3 col = background(p);
  col = atari(col, p);
  col = aces_approx(col);
  col = sRGB(col);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);

  col = mix(col, 0.8*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}



