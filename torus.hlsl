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

#define PERIOD      30.0

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/intersectors
float rayTorus(vec3 ro, vec3 rd, vec2 tor) {
  float po = 1.0;

  float Ra2 = tor.x*tor.x;
  float ra2 = tor.y*tor.y;

  float m = dot(ro,ro);
  float n = dot(ro,rd);

  // bounding sphere
  {
    float h = n*n - m + (tor.x+tor.y)*(tor.x+tor.y);
    if(h<0.0) return -1.0;
    //float t = -n-sqrt(h); // could use this to compute intersections from ro+t*rd
  }

  // find quartic equation
  float k = (m - ra2 - Ra2)/2.0;
  float k3 = n;
  float k2 = n*n + Ra2*rd.z*rd.z + k;
  float k1 = k*n + Ra2*ro.z*rd.z;
  float k0 = k*k + Ra2*ro.z*ro.z - Ra2*ra2;

  #ifndef TORUS_REDUCE_PRECISION
  // prevent |c1| from being too close to zero
  if(abs(k3*(k3*k3 - k2) + k1) < 0.01)
  {
    po = -1.0;
    float tmp=k1; k1=k3; k3=tmp;
    k0 = 1.0/k0;
    k1 = k1*k0;
    k2 = k2*k0;
    k3 = k3*k0;
  }
  #endif

  float c2 = 2.0*k2 - 3.0*k3*k3;
  float c1 = k3*(k3*k3 - k2) + k1;
  float c0 = k3*(k3*(-3.0*k3*k3 + 4.0*k2) - 8.0*k1) + 4.0*k0;


  c2 /= 3.0;
  c1 *= 2.0;
  c0 /= 3.0;

  float Q = c2*c2 + c0;
  float R = 3.0*c0*c2 - c2*c2*c2 - c1*c1;

  float h = R*R - Q*Q*Q;
  float z = 0.0;
  if(h < 0.0) {
    // 4 intersections
    float sQ = sqrt(Q);
    z = 2.0*sQ*cos(acos(R/(sQ*Q)) / 3.0);
  } else {
    // 2 intersections
    float sQ = pow(sqrt(h) + abs(R), 1.0/3.0);
    z = sign(R)*abs(sQ + Q/sQ);
  }
  z = c2 - z;

  float d1 = z   - 3.0*c2;
  float d2 = z*z - 3.0*c0;
  if(abs(d1) < 1.0e-4) {
    if(d2 < 0.0) return -1.0;
    d2 = sqrt(d2);
  } else {
    if(d1 < 0.0) return -1.0;
    d1 = sqrt(d1/2.0);
    d2 = c1/d1;
  }

  //----------------------------------

  float result = 1e20;

  h = d1*d1 - z + d2;
  if(h > 0.0) {
    h = sqrt(h);
    float t1 = -d1 - h - k3; t1 = (po<0.0)?2.0/t1:t1;
    float t2 = -d1 + h - k3; t2 = (po<0.0)?2.0/t2:t2;
    if(t1 > 0.0) result=t1;
    if(t2 > 0.0) result=min(result,t2);
  }

  h = d1*d1 - z - d2;
  if(h > 0.0) {
    h = sqrt(h);
    float t1 = d1 - h - k3;  t1 = (po<0.0)?2.0/t1:t1;
    float t2 = d1 + h - k3;  t2 = (po<0.0)?2.0/t2:t2;
    if(t1 > 0.0) result=min(result,t1);
    if(t2 > 0.0) result=min(result,t2);
  }

  return result;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/intersectors
vec3 torusNormal(vec3 pos, vec2 tor) {
  return normalize(pos*(dot(pos,pos)- tor.y*tor.y - tor.x*tor.x*vec3(1.0,1.0,-1.0)));
}

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
  //  Found this somewhere on the interwebs
  //  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
float mod1(inout float p, float size) {
  float halfsize = size*0.5;
  float c = floor((p + halfsize)/size);
  p = mod(p + halfsize, size) - halfsize;
  return c;
}

// License: Unknown, author: Unknown, found: don't remember
float hash(float co) {
  return fract(sin(co*12.9898) * 13758.5453);
}

vec3 effect(vec2 p, float ntime, float ptime) {
  float h0 = hash(ntime + 1.5);
  float rn = mod(ntime, 3.0);
  const float rdd = 2.0;
  const vec3 ro0 = vec3(0.0, 0.75, -0.2);
  const vec3 ro1 = vec3(0.0, 0.75, 0.2);
  const vec3 ro2 = vec3(0.0, 0.5, -0.38);
  vec3 ro  = ro0;
  if (rn == 1.0) {
    ro = ro1;
  } else if (rn == 2.0) {
    ro = ro2;
  }

  const vec3 la  = vec3(0.0, 0.0, 0.2);
  const vec3 up  = normalize(vec3(0.3, 0.0, 1.0));
  vec3 lp1 = ro;
  const mat2 rotxy = ROT(0.85);
  const mat2 rotxz = ROT(-0.5);
  lp1.xy = mul(rotxy, lp1.xy);
  lp1.xz = mul(rotxz, lp1.xz);

  vec3 ww = normalize(la - ro);
  vec3 uu = normalize(cross(up, ww));
  vec3 vv = (cross(ww,uu));
  vec3 rd = normalize(p.x*uu + p.y*vv + rdd*ww);

  const vec2 tor = 0.55*vec2(1.0, 0.75);
  float td    = rayTorus(ro, rd, tor);
  vec3  tpos  = ro + rd*td;
  vec3  tnor  = -torusNormal(tpos, tor);
  vec3  tref  = reflect(rd, tnor);

  vec3  ldif1 = lp1 - tpos;
  float ldd1  = dot(ldif1, ldif1);
  float ldl1  = sqrt(ldd1);
  vec3  ld1   = normalize(ldif1);
  vec3  sro   = tpos+0.05*tnor;
  float sd    = rayTorus(sro, ld1, tor);
  vec3  spos  = sro+ld1*sd;
  vec3  snor  = -torusNormal(spos, tor);

  float dif1  = max(dot(tnor, ld1), 0.0);
  float spe1  = pow(max(dot(tref, ld1), 0.0), 10.0);
  float r     = length(tpos.xy);

  float a     = atan2(tpos.y, tpos.x);
  float tw    = 1.0*PI*tpos.z/(r+0.5*abs(tpos.z));
  float aa    = ptime*TAU/45.0;
  a -= tw+aa;

  float n = floor(mix(1.0, 7.0, h0));
  float pg = a;
  float ng = mod1(pg, TAU/n);
  float dg = max(abs(pg)-0.01, 0.001);

  vec3 gcol = hsv2rgb(vec3(fract(0.1*ptime+0.125*ng*tpos.y), 0.75, 1.0-0.5));
  const vec3 lcol = HSV2RGB(vec3(0.55, 0.9, 0.75));

  float fre = 1.0+dot(rd, tnor);
  fre *= fre;

  vec3 col = 0.0*unit3;

  vec3 mat = 0.125*lcol*dif1+4.0*sqrt(lcol)*spe1*fre;
  if (td > -1.0) {
    col += mat;
  }

  float shade = mix(1.0, 0.1, pow(abs(dot(ld1, snor)), 3.0*tanh_approx(sd)));
  if (sd < ldl1) {
    col *= shade;
  }

  vec3 glow = 0.0125*gcol/(dg)*smoothstep(1.0, 0.8, fre);
  if (td > -1.0) {
    col += glow;
  }

  return col;
}

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

  float ptime = mod(TIME, PERIOD);
  float ntime = floor(TIME/PERIOD);
  vec3 col = effect(p, ntime, ptime);
  col = aces_approx(col);
  col *= smoothstep(0.0, 2.0, ptime);
  col *= smoothstep(PERIOD, PERIOD-2.0, ptime);
  col = sRGB(col);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);
  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}