// Windows Terminal observes DirectX 10 Coordinates
//   https://docs.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-coordinates

// SHADERed has an inverted y-axis coordinate compared with
// what Windows Terminal uses. This patch inverts SHADERed's
// coordinate geometry so that it matches Windows Terminal.

PSInput patchCoordinates(PSInput pin)
{
  PSInput output;
  output.pos = float4(pin.pos.x, Resolution.y - pin.pos.y, pin.pos.z, pin.pos.w);
  output.uv = float2(pin.uv.x, 1.0 - pin.uv.y);
  return output;
}
