# Windows Terminal Shaders

Shaders for the new Windows Terminal

## How to use

- Checkout the repository
- Set the value for `experimental.pixelShaderPath` in your terminal setting to the desired shader
- **optional:** Add keybindings for turning the shader on/off and focusmode

### Example Setting

> Please add the lines you need to your own config, this example config only show the values that you need to add.

```jsonc
{
  "profiles": {
    "defaults": {
      // Add your desired shader
      "experimental.pixelShaderPath": "C:\\gitrepos\\windows-terminal-shaders\\crt.hlsl"
    },
  },
  "keybindings": [
    // It's recommended to add those two toggles for ease of use
    {
      "command": "toggleFocusMode",
      "keys": "shift+f11"
    },
    {
      "command": "toggleShaderEffects",
      "keys": "shift+f10"
    }
  ]
}
```

## [CRT](./crt.hlsl)

### Preview
|![crt1](.github/crt-1.png)|![crt1](.github/crt-2.png)|![crt1](.github/crt-3.png)|
|---|---|---|
|Default|Green Monochrome|Ember Monochrome|

### Settings
```c++
#define GRAIN_INTENSITY 0.02
#define TINT_COLOR float4(1, 0.7f, 0, 0)
#define ENABLE_SCANLINES 1
#define ENABLE_REFRESHLINE 1
#define ENABLE_NOISE 1
#define ENABLE_CURVE 1
#define ENABLE_TINT 0
#define DEBUG 0
```

## [Transparent](./transparent.hlsl)

Turn a specific color into transparent for use with `useAcrylic` and `acrylicOpacity` when xterm colors are enabled, like in vim themes.

### Preview
|![transparent not show](.github/transparent-1.png)|![transparent applie](.github/transparent-2.png)|
|---|---|
|xterm colors without shader|xterm colors with shader|

### Settings

Set the color value for the chromaKey used for transparency `float3(8.0f / 0xFF, 8.0f / 0xFF, 8.0f / 0xFF)` is the same as `rgb(8, 8, 8)` 

```c++
static const float3 chromaKey = float3(8.0f / 0xFF, 8.0f / 0xFF, 8.0f / 0xFF);
```

## [Hue Shift](./hueshift.hlsl)

Changes the hue of screen colors. This can apply a color correction similar to the tint knob of old TVs or it can be set to cycle the colors smoothly over time.

### Preview
|![hueshift not applied](.github/hueshift-1.png)|![hueshift applied](.github/hueshift-2.gif)|
|---|---|
|vintage colors without shader|vintage colors with shader|

### Settings

`HUE_OFFSET`  [0.0, 1.0)f : Adjust the hue to a specific offset.  
`CHANGE_RATE` [0.0, 1.0)f : Changes the hue over time. For small values like 0.01f, this will cause a slow change over time and probably won't be very disruptive.
`TOLERANCE`   [0.0, 1.0)f : Saturation% setpoint. All saturation levels greater or equal than this will be affected by the hue adjustments. This allows you to fix some of the grayscale colors such as those offten used by on-screen text.

```c++
#define HUE_OFFSET 0.0f
#define CHANGE_RATE 0.01f
#define TOLERANCE 0.266f
```
