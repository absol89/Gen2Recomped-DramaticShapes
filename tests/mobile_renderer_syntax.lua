for _, path in ipairs({
  "main.lua",
  "lib/PipelineCanvas.lua",
  "lib/PixelCanvas.lua",
  "lib/RendererOrientation.lua",
  "lib/WorldCanvasOrientation.lua",
  "lib/Voxel3D.lua",
  "lib/ShadowMap.lua",
}) do
  local chunk, err = loadfile(path)
  assert(chunk, path .. ": " .. tostring(err))
end

local shadow = assert(io.open("lib/ShadowMap.lua", "rb")):read("*a")
assert(shadow:find("vDepth = c.z;", 1, true),
  "shadow writer did not retain normalized clip depth")
assert(shadow:find("vSign = probeVSign()", 1, true),
  "shadow-map storage orientation is not calibrated")
assert(not shadow:find('love.system.getOS() == "iOS"', 1, true),
  "iOS shadow maps are still disabled")

print("mobile renderer syntax and shadow contract: ok")
