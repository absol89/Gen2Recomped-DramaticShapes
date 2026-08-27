-- Renderer-specific texture orientation at the point an Image is sampled
-- inside a Canvas.  This is separate from presenting the completed world
-- Canvas: Metal needs both corrections at different boundaries.

local Orientation = {}

function Orientation.metalRenderer()
  if not (love and love.graphics and love.graphics.getRendererInfo) then
    return false
  end
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
