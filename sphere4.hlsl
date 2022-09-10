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
#define mat3  float3x3
#define fract frac
#define mix   lerp
vec2 mod(vec2 x, vec2 y) {
  return x - y * floor(x/y);
}

static const vec2 unit2 = vec2(1.0, 1.0);
static const vec3 unit3 = vec3(1.0, 1.0, 1.0);
// --------------------

#define PI      3.141592654
#define TAU     (2.0*PI)

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
static const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

static const vec3 gcol = HSV2RGB(vec3(0.4, 0.6, 1.0));
static const float fov = tan(TAU/6.0);
static const float speed = 0.3;

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

float3x3 rot_z(float a) {
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

float circle(vec2 p, float r) {
  return length(p) - r;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/distfunctions2d
float box(vec2 p, vec2 b) {
  vec2 d = abs(p)-b;
  return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/smin
float pmin(float a, float b, float k) {
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

// http://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5, size) - size*0.5;
  return c;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/intersectors
float rayPlane(vec3 ro, vec3 rd, vec4 p) {
  return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/intersectors
float raySphere4(vec3 ro, vec3 rd, float ra) {
  float r2 = ra*ra;
  vec3 d2 = rd*rd; vec3 d3 = d2*rd;
  vec3 o2 = ro*ro; vec3 o3 = o2*ro;
  float ka = 1.0/dot(d2,d2);
  float k3 = ka* dot(ro,d3);
  float k2 = ka* dot(o2,d2);
  float k1 = ka* dot(o3,rd);
  float k0 = ka*(dot(o2,o2) - r2*r2);
  float c2 = k2 - k3*k3;
  float c1 = k1 + 2.0*k3*k3*k3 - 3.0*k3*k2;
  float c0 = k0 - 3.0*k3*k3*k3*k3 + 6.0*k3*k3*k2 - 4.0*k3*k1;
  float p = c2*c2 + c0/3.0;
  float q = c2*c2*c2 - c2*c0 + c1*c1;
  float h = q*q - p*p*p;
  if( h<0.0 ) return -1.0; //no intersection
  float sh = sqrt(h);
  float s = sign(q+sh)*pow(abs(q+sh),1.0/3.0); // cuberoot
  float t = sign(q-sh)*pow(abs(q-sh),1.0/3.0); // cuberoot
  vec2  w = vec2( s+t,s-t );
  vec2  v = vec2( w.x+c2*4.0, w.y*sqrt(3.0) )*0.5;
  float r = length(v);
  return -abs(v.y)/sqrt(r+v.x) - c1/r - k3;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/articles/intersectors
vec3 normalSphere4(in vec3 pos) {
  return normalize(pos*pos*pos);
}

float blobs(vec2 p) {
  // Generates a grid of dots
  vec2 bp = p;
  vec2 bn = mod2(bp, 3.0*unit2);

  vec2 dp = p;
  vec2 dn = mod2(dp, 0.25*unit2);
  float ddots = length(dp);

  // Blobs
  float dblobs = 1E6;
  for (int i = 0; i < 5; ++i) {
    float dd = circle(bp-1.0*vec2(sin(TIME+float(i)), sin(float(i*i)+TIME*sqrt(0.5))), 0.1);
    dblobs = pmin(dblobs, dd, 0.35);
  }

  float d = 1E6;
  d = min(d, ddots);
  // Smooth min between blobs and dots makes it look somewhat amoeba like
  d = pmin(d, dblobs, 0.35);
  return d;
}

vec3 skyColor(vec3 ro, vec3 rd) {
  vec3 col = clamp(0.00125/abs(rd.y)*gcol, 0.0, 10.0)*unit3;

  float tp0  = rayPlane(ro, rd, vec4(vec3(0.0, 1.0, 0.0), 4.0));
  float tp1  = rayPlane(ro, rd, vec4(vec3(0.0, -1.0, 0.0), 6.0));

  float tp = tp1;
  tp = max(tp0,tp1);
  if (tp > 0.0) {
    vec3 pos  = ro + tp*rd;
    vec3 tpos = pos+vec3(0.0, 0.0, 2.0*TIME*speed);
    const float fz = 0.25;
    const float bz = 1.0/fz;
    vec2 bpos = tpos.xz/bz;
    float db = blobs(bpos)*bz;
    db = abs(db);
    vec2 pp = tpos.xz*fz;
    float m = 0.5+0.25*(sin(3.0*pp.x+TIME*2.1)+sin(3.3*pp.y+TIME*2.0));
    m *= m;
    m *= m;
    pp = fract(pp+0.5)-0.5;
    float dp = pmin(abs(pp.x), abs(pp.y), 0.125);
    dp = min(dp, db);
    vec3 hsv = vec3(0.4+mix(0.15,0.0, m), tanh_approx(mix(50.0, 10.0, m)*dp), 1.0);
    vec3 pcol = 1.5*hsv2rgb(hsv)*exp(-mix(30.0, 10.0, m)*dp);

    float f = 1.0-tanh_approx(0.1*length(pos.xz));
    col = mix(col, pcol , f);
  }


  if (tp1 > 0.0) {
    vec3 pos  = ro + tp1*rd;
    vec2 pp = pos.xz;
    float db = box(pp, vec2(6.0, 9.0))-1.0;

    col += 2.0*unit3*gcol*rd.y*smoothstep(0.25, 0.0, db);
    col += 0.8*unit3*gcol*exp(-0.5*max(db, 0.0));
  }


  return col;
}

vec3 color(vec3 ro, vec3 rd) {
  vec3 skyCol = skyColor(ro, rd);
  mat3 rot = rot_x(speed*0.25*TIME);
  rot = mul(rot,rot_y(speed*0.33*TIME));
  rot = mul(rot,rot_z(speed*0.45*TIME));
  mat3 irot = transpose(rot);

  vec3 bro = mul(rot, ro);
  vec3 brd = mul(rot, rd);

  float bi = raySphere4(bro, brd, 3.0);

  if (bi > -1.0) {

    vec3 bp = bro + bi*brd;
    vec3 bn = normalSphere4(bp);
    vec3 p = mul(irot, bp);
    vec3 n = mul(irot, bn);
    vec3 r = reflect(rd, n);
    float bf = 1.0+dot(rd,n);
    float fre = bf;
    fre *= fre;
    vec3 rsky = skyColor(p, r);
    vec3 col = mix(0.125, 1.0, fre)*rsky;
    float rdif = dot(-rd, n);
    rdif *= rdif;
    col += 0.25*mix(0.0125, 0.05, rdif)*unit3;
    return mix(skyCol, col, smoothstep(1.0, 0.85, bf));
  }

  return skyCol;
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

  const vec3 ro = vec3(0.0, 3.0, 7.0);
  const vec3 la = vec3(0.0, 0.0, 0.0);
  const vec3 up = vec3(0.0, 1.0, 0.0);

  vec3 ww = normalize(la - ro);
  vec3 uu = normalize(cross(up, ww));
  vec3 vv = cross(ww,uu);
  vec3 rd = normalize(-p.x*uu + p.y*vv + fov*ww);

  vec3 col = color(ro, rd);
  col = sqrt(col); // Cheap "sRGB"

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);
  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}