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

#define SPEED           0.05

#define PI              3.141592654
#define TAU             (2.0*PI)
#define PI_2            (0.5*PI)
#define ROT(a)          mat2(cos(a), sin(a), -sin(a), cos(a))
#define PSIN(x)         (0.5+0.5*sin(x))
#define LESS(a,b,c)     mix(a,b,step(0.,c))
#define SABS(x,k)       LESS((.5/(k))*(x)*(x)+(k)*.5,abs(x),abs(x)-(k))
#define L2(x)           dot(x, x)

float hash(float co) {
  return fract(sin(co*12.9898) * 13758.5453);
}

// License: MIT, author: Pascal Gilcher, found: https://www.shadertoy.com/view/flSXRV
float atan_approx(float y, float x) {
  float cosatan2 = x / (abs(x) + abs(y));
  float t = PI_2 - cosatan2 * PI_2;
  return y < 0.0 ? -t : t;
}

vec2 toPolar(vec2 p) {
  return vec2(length(p), atan_approx(p.y, p.x));
}

vec2 toRect(vec2 p) {
  return vec2(p.x*cos(p.y), p.x*sin(p.y));
}

float modMirror1(inout float p, float size) {
  float halfsize = size*0.5;
  float c = floor((p + halfsize)/size);
  p = mod(p + halfsize,size) - halfsize;
  p *= mod(c, 2.0)*2.0 - 1.0;
  return c;
}

float smoothKaleidoscope(inout vec2 p, float sm, float rep) {
  vec2 hp = p;

  vec2 hpp = toPolar(hp);
  float rn = modMirror1(hpp.y, TAU/rep);

  float sa = PI/rep - SABS(PI/rep - abs(hpp.y), sm);
  hpp.y = sign(hpp.y)*(sa);

  hp = toRect(hpp);

  p = hp;

  return rn;
}

vec4 alphaBlend(vec4 back, vec4 front) {
  float w = front.w + back.w*(1.0-front.w);
  vec3 xyz = (front.xyz*front.w + back.xyz*back.w*(1.0-front.w))/w;
  return w > 0.0 ? vec4(xyz, w) : unit4*(0.0);
}

vec3 alphaBlend(vec3 back, vec4 front) {
  return mix(back, front.xyz, front.w);
}

float tanh_approx(float x) {
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

float pmin(float a, float b, float k) {
  float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0);

  return mix(b, a, h) - k*h*(1.0-h);
}

vec3 hsv2rgb(vec3 c) {
  const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float apollian(vec4 p, float s) {
  float scale = 1.0;

  for(int i=0; i<7; ++i) {
    p = -1.0 + 2.0*fract(0.5*p+0.5);

    float r2 = dot(p,p);

    float k  = s/r2;
    p       *= k;
    scale   *= k;
  }

  return abs(p.y)/scale;
}

vec2 mod2_1(inout vec2 p) {
  vec2 c = floor(p + 0.5);
  p = fract(p + 0.5) - 0.5;
  return c;
}

float hex(vec2 p, float r) {
  const vec3 k = vec3(-sqrt(3.0)/2.0,1.0/2.0,sqrt(3.0)/3.0);
  p = p.yx;
  p = abs(p);
  p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
  p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
  return length(p)*sign(p.y);
}

float circle(vec2 p, float r) {
  return length(p) - r;
}

// -----------------------------------------------------------------------------
// PATH
// -----------------------------------------------------------------------------

// The path function
vec3 offset(float z) {
  float a = z;
  vec2 p = -0.10*(vec2(cos(a), sin(a*sqrt(2.0))) + vec2(cos(a*sqrt(0.75)), sin(a*sqrt(0.5))));
  return vec3(p, z);
}

// The derivate of the path function
//  Used to generate where we are looking
vec3 doffset(float z) {
  float eps = 0.1;
  return 0.5*(offset(z + eps) - offset(z - eps))/eps;
}

// The second derivate of the path function
//  Used to generate tilt
vec3 ddoffset(float z) {
  float eps = 0.1;
  return 0.125*(doffset(z + eps) - doffset(z - eps))/eps;
}

// -----------------------------------------------------------------------------
// PLANE MARCHER
// -----------------------------------------------------------------------------

float weird(vec2 p, float h) {
  float z = 4.0;
  float tm = SPEED*TIME+h*10.0;
  mat2 a = ROT(tm*0.5);
  mat2 b = mul(a, a);
  mat2 c = ROT(tm*sqrt(0.5));
  p = mul(a, p);
  float r = 0.5;
  vec4 off = vec4(r*PSIN(tm*sqrt(3.0)), r*PSIN(tm*sqrt(1.5)), r*PSIN(tm*sqrt(2.0)), 0.0);
  vec4 pp = vec4(p.x, p.y, 0.0, 0.0)+off;
  pp.w = 0.125*(1.0-tanh_approx(length(pp.xyz)));
  pp.yz = mul(b, pp.yz);
  pp.xz = mul(c, pp.xz);
  pp /= z;
  float d = apollian(pp, 0.8+h);
  return d*z;
}

float circles(vec2 p) {
  vec2 pp = toPolar(p);
  const float ss = 0.25;
  pp.x = fract(pp.x*ss)/ss;
  p = toRect(pp);
  float d = circle(p, 1.0);
  return d;
}

vec2 df(vec2 p, float h) {
  vec2 wp = p;
  float rep = 10.0;
  float ss = 0.05*6.0/rep;
  float n = smoothKaleidoscope(wp, ss, rep);

  float d0 = weird(wp, h);
  float d1 = hex(p, 0.25)-0.1;
  float d2 = circles(p);
  const float lw = 0.0125;
  d2 = abs(d2)-lw;
  float d  = pmin(pmin(d0, d2, 0.1), abs(d1)-lw, 0.05);
  return vec2(d, d1+lw);
}

vec4 plane(vec3 ro, vec3 rd, vec3 pp, vec3 off, float aa, float n) {
  float h = hash(n);
  float s = 0.25*mix(0.5, 0.25, h);
  float dd= length(pp-ro);

  const vec3 nor  = vec3(0.0, 0.0, 1.0);
  const vec3 loff = vec3(0.25*0.5, 0.125*0.5, -0.125);
  vec3 lp1  = ro + loff;
  vec3 lp2  = ro + loff*vec3(-1.0, 1.0, 1.0);
  vec3 ld1  = normalize(pp - lp1);
  vec3 ld2  = normalize(pp - lp2);
  float lpw1= 0.2/L2(pp - lp1);
  float lpw2= 0.2/L2(pp - lp2);
  vec3 ref  = reflect(rd, nor);
  float ref1= pow(max(dot(nor, ld1), 0.0), 20.0);
  float ref2= pow(max(dot(nor, ld2), 0.0), 20.0);
  vec3  col1= vec3(0.75, 0.5, 1.0);
  vec3  col2= vec3(1.0, 0.5, 0.75);

  vec3 hn;
  vec2 p = (pp-off*vec3(1.0, 1.0, 0.0)).xy;
  p = mul(ROT(TAU*h), p);
  vec2 d2 = df(p/s, h)*s;

  float ha = smoothstep(-aa, aa, d2.y);
  float d = d2.x;
  vec4 col = unit4*(0.0);

  float l   = length(10.0*p);
  float ddf = 1.0/((1.0+2.0*dd));
  float hue = fract(0.75*l-SPEED*TIME)+0.3+0.15;
  float sat = 0.75*tanh_approx(2.0*l)*ddf;
  float vue = sqrt(ddf);
  vec3 hsv  = vec3(hue, sat, vue);
  vec3 bcol = hsv2rgb(hsv);
  col.xyz   = mix(col.xyz, bcol, smoothstep(-aa, aa, -d));
  float glow = (exp(-(10.0+100.0*tanh_approx(l))*10.0*max(d, 0.0)*ddf));
  col.xyz   += 0.5*sqrt(bcol.zxy)*glow;
  col.w     = ha*mix(0.75, 1.0, ha*glow);
  col.xyz   += 0.125*col.w*(col1*ref1+col2*ref2);

  return col;
}

vec3 skyColor(vec3 ro, vec3 rd) {
  float ld = max(dot(rd, vec3(0.0, 0.0, 1.0)), 0.0);
  return 1.25*vec3(1.0, 0.75, 0.85)*(tanh_approx(3.0*pow(ld, 100.0)));
}

vec3 color(vec3 ww, vec3 uu, vec3 vv, vec3 ro, vec2 p) {

  float lp = length(p);
  vec2 np = p + 1.0/RESOLUTION.xy;
  const float rdd = tan(TAU/5.0);
  vec3 rd = normalize(-p.x*uu + p.y*vv + rdd*ww);
  vec3 nrd = normalize(-np.x*uu + np.y*vv + rdd*ww);

  const float planeDist = 1.0-0.75;
  const int furthest = 8;
  const int fadeFrom = max(furthest-3, 0);
  const float fadeDist = planeDist*float(furthest - fadeFrom);
  float nz = floor(ro.z / planeDist);

  vec3 skyCol = skyColor(ro, rd);

  // Steps from nearest to furthest plane and accumulates the color

  vec4 acol = unit4*(0.0);
  const float cutOff = 0.95;
  bool cutOut = false;

  for (int i = 1; i <= furthest; ++i) {
    float pz = planeDist*nz + planeDist*float(i);

    float pd = (pz - ro.z)/rd.z;

    if (pd > 0.0 && acol.w < cutOff) {
      vec3 pp = ro + rd*pd;
      vec3 npp = ro + nrd*pd;

      float aa = 3.0*length(pp - npp);

      vec3 off = offset(pp.z);

      vec4 pcol = plane(ro, rd, pp, off, aa, nz+float(i));

      float nz = pp.z-ro.z;
      float fadeIn = exp(-2.5*max((nz - planeDist*float(fadeFrom))/fadeDist, 0.0));
      float fadeOut = smoothstep(0.0, planeDist*0.1, nz);
      pcol.xyz = mix(skyCol, pcol.xyz, (fadeIn));
      pcol.w *= fadeOut;

      pcol = clamp(pcol, 0.0, 1.0);

      acol = alphaBlend(pcol, acol);
    } else {
      cutOut = true;
      break;
    }

  }

  vec3 col = alphaBlend(skyCol, acol);
// To debug cutouts due to transparency
//  col += cutOut ? vec3(1.0, -1.0, 0.0) : vec3(0.0);
  return col;
}

// Classic post processing
vec3 postProcess(vec3 col, vec2 q) {
  col -= 0.5*vec3(0.1, 0.2, 0.);
  col = clamp(col, 0.0, 1.0);
  col = sqrt(col);
  col = col*0.6+0.4*col*col*(3.0-2.0*col);
  col = mix(col, unit3*(dot(col, unit3*(0.33))), -0.4);
  col *=0.5+0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.7);
  return col;
}

vec3 effect(vec2 p, vec2 q) {
  float tm  = SPEED*TIME*2.0;
  vec3 ro   = offset(tm);
  vec3 dro  = doffset(tm);
  vec3 ddro = ddoffset(tm);

  vec3 ww = normalize(dro);
  vec3 uu = normalize(cross(normalize(vec3(0.0,1.0,0.0)+ddro), ww));
  vec3 vv = (cross(ww, uu));

  vec3 col = color(ww, uu, vv, ro, p);
  col = postProcess(col, q);
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

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);
  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}
