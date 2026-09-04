-- Presentation-only tree heights, in map-local 16px cells. Route 32's two
-- trees northwest of the Pokemon Center obstruct the staged battle camera.
local TreeOverrides = {}

function TreeOverrides.scale(map, cx, footCY)
  local id = map and map.id
  if (id == "ROUTE_32" or id == "ROUTE32")
      and (cx == 6 or cx == 7) and footCY == 67 then
    return 0.5 -- 32px canopy -> the surrounding short trees' 16px height
  end
  return 1
end

function TreeOverrides.scaleQuads(quads, scale)
  if scale == 1 then return quads end
  local result = {}
  for i, quad in ipairs(quads) do
    local copy = {}
    for key, value in pairs(quad) do copy[key] = value end
    for j = 1, 4 do
      local vertex = {}
      for key, value in pairs(quad[j]) do vertex[key] = value end
      vertex[2] = vertex[2] * scale
      copy[j] = vertex
    end
    result[i] = copy
  end
  return result
end

return TreeOverrides
