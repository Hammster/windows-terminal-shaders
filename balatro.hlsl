// Original by localthunk (https://www.playbalatro.com)
// Edit by xxidbr9 (https://www.shadertoy.com/view/XXtBRr)
// Ported to HLSL by Hammster (https://github.com/Hammster/windows-terminal-shaders)

struct PSInput {
  float4 pos : SV_POSITION;
  float2 uv : TEXCOORD0;
};

Texture2D shaderTexture : register(t0);
SamplerState samplerState : register(s0);

cbuffer PixelShaderSettings : register(b0) {
  float  Time;
  float  Scale;
  float2 Resolution;
  float4 Background;
};

// Configuration (modify these values to change the effect)
#define SPIN_ROTATION -2.0
#define SPIN_SPEED 7.0
#define OFFSET float2(0.0)
#define COLOUR_1 float4(0.871, 0.267, 0.231, 1.0)
#define COLOUR_2 float4(0.0, 0.42, 0.706, 1.0)
#define COLOUR_3 float4(0.086, 0.137, 0.145, 1.0)
#define CONTRAST 3.5
#define LIGTHING 0.4
#define SPIN_AMOUNT 0.25
#define PIXEL_FILTER 745.0
#define SPIN_EASE 1.0
#define PI 3.14159265359
#define IS_ROTATE false

float4 effect(float4 screenSize, float2 screen_coords) {
    float pixel_size = length(screenSize.xy) / PIXEL_FILTER;
    float2 uv = (floor(screen_coords.xy*(1./pixel_size))*pixel_size - 0.5*screenSize.xy)/length(screenSize.xy); // - OFFSET
    float uv_len = length(uv);
    
    float speed = (SPIN_ROTATION*SPIN_EASE*0.2);
    if(IS_ROTATE){
       speed = Time * speed;
    }
    speed += 302.2;
    float new_pixel_angle = atan2(uv.y, uv.x) + speed - SPIN_EASE*20.*(1.*SPIN_AMOUNT*uv_len + (1. - 1.*SPIN_AMOUNT));
    float2 mid = (screenSize.xy/length(screenSize.xy))/2.;
    uv = (float2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);
    
    uv *= 30.;
    speed = Time*(SPIN_SPEED);
    float2 uv2 = float2(uv.x, uv.y);
    
    for(int i=0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv  += 0.5*float2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121),sin(uv2.x - 0.113*speed));
        uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
    }
    
    float contrast_mod = (0.25*CONTRAST + 0.5*SPIN_AMOUNT + 1.2);
    float paint_res = min(2., max(0.,length(uv)*(0.035)*contrast_mod));
    float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
    float c2p = max(0.,1. - contrast_mod*abs(paint_res));
    float c3p = 1. - min(1., c1p + c2p);
    float light = (LIGTHING - 0.2)*max(c1p*5. - 4., 0.) + LIGTHING*max(c2p*5. - 4., 0.);
    return (0.3/CONTRAST)*COLOUR_1 + (1. - 0.3/CONTRAST)*(COLOUR_1*c1p + COLOUR_2*c2p + float4(c3p*COLOUR_3.rgb, c3p*COLOUR_1.a)) + light;
}


float4 main(PSInput pin) : SV_TARGET {
    float4 pos = pin.pos;
    float2 uv = pin.uv;

    float4 bg = effect(pos, uv * pos.xy);
    float4 fg = shaderTexture.Sample(samplerState, uv);

    return (bg / 3.0) + fg;
}