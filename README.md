# Windows Terminal Shaders

Shaders for the new Windows Terminal

## How to use

- Checkout the repository
- Set the value for `experimental.pixelShaderPath` in your terminal setting to the desired shader
- **optional:** Add keybindings for turning the shader on/off and focusmode

### Example Setting

```json
  // ...
	"profiles": {
		"defaults": {
      // Add
			"experimental.pixelShaderPath": "C:\\gitrepos\\windows-terminal-shaders\\crt.hlsl"
		},
  }
  	"keybindings": [
		// ... It's recommended to add those two toggles for ease of use
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