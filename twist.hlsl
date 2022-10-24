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

// License CC0: Apollian with a twist
// Playing around with apollian fractal

#define PI              3.141592654
#define TAU             (2.0*PI)
#define L2(x)           dot(x, x)
#define ROT(a)          mat2(cos(a), sin(a), -sin(a), cos(a))
#define PSIN(x)         (0.5+0.5*sin(x))

vec3 hsv2rgb(vec3 c) {
  const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float apollian(vec4 p, float s) {
  float scale = 1.0;

  for(int i=0; i<7; ++i) {
    p        = -1.0 + 2.0*fract(0.5*p+0.5);

    float r2 = dot(p,p);

    float k  = s/r2;
    p       *= k;
    scale   *= k;
  }

  return abs(p.y)/scale;
}

float weird(vec2 p) {
  float z = 4.0;
  p = mul(ROT(TIME*0.1), p);
  float tm = 0.2*TIME;
  float r = 0.5;
  vec4 off = vec4(r*PSIN(tm*sqrt(3.0)), r*PSIN(tm*sqrt(1.5)), r*PSIN(tm*sqrt(2.0)), 0.0);
  vec4 pp = vec4(p.x, p.y, 0.0, 0.0)+off;
  pp.w = 0.125*(1.0-tanh(length(pp.xyz)));
  pp.yz = mul(ROT(tm), pp.yz);
  pp.xz = mul(ROT(tm*sqrt(0.5)), pp.xz);
  pp /= z;
  float d = apollian(pp, 1.2);
  return d*z;
}

float df(vec2 p) {
  const float zoom = 0.5;
  p /= zoom;
  float d0 = weird(p);
  return d0*zoom;
}

vec3 color(vec2 p) {
  float aa   = 2.0/RESOLUTION.y;
  const float lw = 0.0235;
  const float lh = 1.25;

  const vec3 lp1 = vec3(0.5, lh, 0.5);
  const vec3 lp2 = vec3(-0.5, lh, 0.5);

  float d = df(p);

  float b = -0.125;
  float t = 10.0;

  vec3 ro = vec3(0.0, t, 0.0);
  vec3 pp = vec3(p.x, 0.0, p.y);

  vec3 rd = normalize(pp - ro);

  vec3 ld1 = normalize(lp1 - pp);
  vec3 ld2 = normalize(lp2 - pp);

  float bt = -(t-b)/rd.y;

  vec3 bp   = ro + bt*rd;
  vec3 srd1 = normalize(lp1-bp);
  vec3 srd2 = normalize(lp2-bp);
  float bl21= L2(lp1-bp);
  float bl22= L2(lp2-bp);

  float st1= (0.0-b)/srd1.y;
  float st2= (0.0-b)/srd2.y;
  vec3 sp1 = bp + srd1*st1;
  vec3 sp2 = bp + srd2*st1;

  float bd = df(bp.xz);
  float sd1= df(sp1.xz);
  float sd2= df(sp2.xz);

  vec3 col  = 0.0*unit3;
  const float ss =15.0;

  col       += (1.0-exp(-ss*(max((sd1+0.0*lw), 0.0))))/bl21;
  col       += 0.5*(1.0-exp(-ss*(max((sd2+0.0*lw), 0.0))))/bl22;
  float l   = length(p);
  float hue = fract(0.75*l-0.3*TIME)+0.3+0.15;
  float sat = 0.75*tanh(2.0*l);
  vec3 hsv  = vec3(hue, sat, 1.0);
  vec3 bcol = hsv2rgb(hsv);
  col       *= (1.0-tanh(0.75*l))*0.5;
  col       = mix(col, bcol, smoothstep(-aa, aa, -d));
  col       += 0.5*sqrt(bcol.zxy)*(exp(-(10.0+100.0*tanh(l))*max(d, 0.0)));

  return col;
}

vec3 postProcess(vec3 col, vec2 q)  {
  col = sqrt(col);
  col=col*0.6+0.4*col*col*(3.0-2.0*col);  // contrast
  col=mix(col, unit3*(dot(col, unit3*(0.33))), -0.4);  // saturation
  col*=0.5+0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.7);  // vigneting
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
  vec3 col = color(p);
  col = postProcess(col, q);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);
  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}
