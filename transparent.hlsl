// This shader helps to add transparency for vim themes that use xterm colors.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
	float  Time;
	float  Scale;
	float2 Resolution;
	float4 Background;
};

// Set the color that is supposed to be transparent
static const float3 chromaKey = float3(8.0f / 0xFF, 8.0f / 0xFF, 8.0f / 0xFF);

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
	float4 color = shaderTexture.Sample(samplerState, tex);
	
	// Filter by chroma key
	if(color.x == chromaKey.x && color.y == chromaKey.y && color.z == chromaKey.z)
	{
		return float4(0.0f, 0.0f, 0.0f, 0.0f);
	}

	return color;
}
