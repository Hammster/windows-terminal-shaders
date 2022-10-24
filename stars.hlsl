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

// License CC0: Another star tunnel
//  Inspired by: https://www.shadertoy.com/view/MdlXWr
#define SPEED           0.666
#define FASTATAN

#define PI              3.141592654
#define PI_2            (0.5*PI)
#define TAU             (2.0*PI)
#define ROT(a)          mat2(cos(a), sin(a), -sin(a), cos(a))

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

// License: Unknown, author: Unknown, found: don't remember
float hash(float co) {
  co += 123.4;
  return fract(sin(co*12.9898) * 13758.5453);
}

// License: MIT, author: Pascal Gilcher, found: https://www.shadertoy.com/view/flSXRV
float atan_approx(float y, float x) {
  float cosatan2 = x / (abs(x) + abs(y));
  float t = PI_2 - cosatan2 * PI_2;
  return y < 0.0 ? -t : t;
}

vec3 alphaBlend(vec3 back, vec4 front) {
  return mix(back, front.xyz, front.w);
}

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
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

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5,size) - size*0.5;
  return c;
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/spherefunctions/spherefunctions.htm
vec2 rayCylinder(vec3 ro, vec3 rd, vec3 cb, vec3 ca, float cr) {
    vec3  oc = ro - cb;
    float card = dot(ca,rd);
    float caoc = dot(ca,oc);
    float a = 1.0 - card*card;
    float b = dot( oc, rd) - caoc*card;
    float c = dot( oc, oc) - caoc*caoc - cr*cr;
    float h = b*b - a*c;
    if( h<0.0 ) return -1.0*unit2; //no intersection
    h = sqrt(h);
    return vec2(-b-h,-b+h)/a;
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/index.htm
vec3 postProcess(vec3 col, vec2 q) {
  col = clamp(col, 0.0, 1.0);
  col = sqrt(col);
  col = col*0.6+0.4*col*col*(3.0-2.0*col);
  col = mix(col, unit3*(dot(col, 0.33*unit3)), -0.4);
  col *=0.5+0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.7);
  return col;
}

vec3 skyColor(vec3 ro, vec3 rd) {
  const vec3 l = normalize(vec3(0.0, 0.0, 1));
  const vec3 baseCol = vec3(0.5, 0.66, 1.0);
  return baseCol*pow(max(dot(l, normalize(rd*vec3(1.0, 0.33, 1.0))), 0.0), 250.0);
}

vec3 color(vec3 ww, vec3 uu, vec3 vv, vec3 ro, vec2 p) {
  float lp = length(p);
  vec2 np = p + 1.0/RESOLUTION.xy;
  float rdd = (2.0+0.5*tanh_approx(lp));  // Playing around with rdd can give interesting distortions
  vec3 rd = normalize(-p.x*uu + p.y*vv + rdd*ww);

  vec3 skyCol = skyColor(ro, rd);

  float aa = TIME*0.125;
  rd.yx = mul(ROT(aa), rd.yx);
  float a = ATAN(rd.y, rd.x);

  vec3 col = skyCol;
  const float mm = 5.0;
  for(float i = 0.0; i < mm; ++i) {
    float ma = a;
    float ii = i/(mm-1.0);
    float sz = 31.0+i*64.0;
    float slices = TAU/sz;
    float na = mod1(ma, slices);

    float hh = hash(na+113.0*i);
    float h1 = hh;
    float h2 = fract(hh*113.0);
    float h3 = fract(hh*127.0);

    float tr = mix(0.25, 2.0, h1);
    vec2 tc = rayCylinder(ro, rd, ro, vec3(0.0, 0.0, 1.0), tr);
    vec3 tcp = ro + tc.y*rd;
    vec2 tcp2 = vec2(tcp.z+h2*2.0, ATAN(tcp.y, tcp.x));

    float sx = mix(0.75, 1.5, h3);
    vec2 tnp2 = mod2(tcp2, vec2(sx, slices));
    tcp2.y *= tr*PI;
    float h4 = hash(tnp2.x+hh);
    float h5 = fract(113.0*h4);
    tcp2.x += 0.4*sx*h4;
    float d = length(tcp2)-0.001;

    float si = exp(-(100.0+1.4*sz)*max(d, 0.0));

    vec3 hsv = vec3(-0.0-0.4*h4, mix(0.4, 0.00, ii), 1.0);
    vec3 bcol = hsv2rgb(hsv)*3.0;
    vec4 scol = vec4(bcol*sqrt(si), sqrt(si)*exp(-0.05*tc.y*tc.y));

    col = alphaBlend(col, scol);
  }

  return col;
}

vec3 effect(vec2 p) {
  float tm  = TIME*SPEED;
  vec3 ro   = vec3(0.0, 0, tm);
  vec3 dro  = normalize(vec3(0.20, 0.2, 1.0));
  dro.xz = mul(ROT(0.2*sin(0.05*tm)), dro.xz);
  dro.yz = mul(ROT(0.2*sin(0.05*tm*sqrt(0.5))), dro.yz);
  vec3 up = vec3(0.0,1.0,0.0);

  vec3 ww = normalize(dro);
  vec3 uu = normalize(cross(up, ww));
  vec3 vv = (cross(ww, uu));

  vec3 col = color(ww, uu, vv, ro, p);
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
  col = postProcess(col, q);

  vec4 fg = shaderTexture.Sample(samplerState, q);
  vec4 sh = shaderTexture.Sample(samplerState, q-2.0*unit2/RESOLUTION.xy);

  col = mix(col, 0.0*unit3, sh.w);
  col = mix(col, fg.xyz, fg.w);

  return vec4(col, 1.0);
}



