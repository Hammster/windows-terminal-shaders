// Allows the unaltered console display to show through in regions
#ifndef DEBUG_ROTATION
#define DEBUG_ROTATION  0.25
#endif
  
#ifndef DEBUG_SEGMENTS
#define DEBUG_SEGMENTS  1
#endif
  
#ifndef DEBUG_OFFSET
#define DEBUG_OFFSET    0.375
#endif
  
#ifndef DEBUG_WIDTH
#define DEBUG_WIDTH     0.25
#endif

DebugOut debug(float4 pos, float2 uv) {
  DebugOut debugOut;
  debugOut.show = false;

  #if SHOW_UV || SHOW_POS
  float4 coordinate_overlay = float4(0);
  #endif
  
  // UV coordinates are mapped from upper left to lower right, (0, 1)
  #if SHOW_UV
  coordinate_overlay += float4(uv.x, uv.y, 0, 1);
  #endif
  
  // Pos coordinates are mapped from upper left to lower right, (0, Resolution)
  #if SHOW_POS
  coordinate_overlay +=  float4(0, pos.x / Resolution.x, pos.y / Resolution.y, 1);
  #endif
  
  #if SHOW_UV && SHOW_POS
  coordinate_overlay *= 0.5;
  #endif
  
  #if SHOW_UV || SHOW_POS
  debugOut.show = true;
  debugOut.color = coordinate_overlay;
  return debugOut;
  #endif  	
		
  #if DEBUG
  float debugCutout = DEBUG_OFFSET + lerp(uv.x, uv.y, DEBUG_ROTATION) * DEBUG_SEGMENTS;
  if (floor(frac(debugCutout) + DEBUG_WIDTH) > 0) {
    debugOut.show = true;
    debugOut.color = shaderTexture.Sample(samplerState, uv);
    return debugOut;
  }
  #endif

  return debugOut;
};
