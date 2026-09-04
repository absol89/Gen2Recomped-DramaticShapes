-- Compatibility corrections require both LÖVE 12+ and the affected renderer.
-- A Metal renderer/device string alone does not imply LÖVE 12 canvas behavior.

local Orientation = {}

function Orientation.metalRenderer()
  if not (love and love.getVersion) then return false end
  local versionOK, major = pcall(love.getVersion)
  if not versionOK or type(major) ~= "number" or major < 12 then
    return false
  end
  if not (love and love.graphics and love.graphics.getRendererInfo) then
    return false
  end
  -- Do not inspect love.system: the engine's mod sandbox blocks that API.
  local ok, name, version, vendor, device =
    pcall(love.graphics.getRendererInfo)
  if not ok then return false end
  local info = table.concat({ tostring(name), tostring(version),
                              tostring(vendor), tostring(device) }, " "):lower()
  return info:find("metal", 1, true) ~= nil
      or (info:find("apple", 1, true) ~= nil
          and info:find("opengl es", 1, true) ~= nil)
end

function Orientation.backdropTransform(iw, ih, x, y, scale, metal)
  if metal then return x, y + ih * scale, scale, -scale end
  return x, y, scale, scale
end

return Orientation
