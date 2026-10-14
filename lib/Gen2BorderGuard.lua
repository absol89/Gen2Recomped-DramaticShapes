-- Compatibility for hosts retaining released border bakes during a dissolve.
-- Keep this at the draw boundary: existing engine builds need no update.
local V = ...
local Guard = {}

local function drawable(image)
  return image and image.getDimensions and pcall(image.getDimensions, image)
end

local function reset(owner)
  if not owner then return end
  owner.borderLast, owner.borderFrom = nil, nil
  owner.borderKey, owner.borderFade = nil, nil
  owner.borderTicks = 0
end

function Guard.install()
  if V.generation() ~= 2 then return false end
  local ok, Border = pcall(require, "src.world.gen2.BorderFill")
  if not (ok and type(Border) == "table" and type(Border.draw) == "function") then
    return false -- Other engine lineages may not have this renderer.
  end
  if Border.battleArtReleasedBorderGuard then return true end
  local draw = Border.draw
  Border.draw = function(owner, image, ...)
    if not drawable(image) then
      reset(owner)
      return false -- Optional border scenery can be invisible until rebuilt.
    end
    if owner and ((owner.borderLast and not drawable(owner.borderLast))
        or (owner.borderFrom and not drawable(owner.borderFrom))) then
      reset(owner) -- Start opaque rather than fading from a missing texture.
    end
    return draw(owner, image, ...)
  end
  Border.battleArtReleasedBorderGuard = true
  return true
end

return Guard
