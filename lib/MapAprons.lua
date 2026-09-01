-- Small, explicit extensions to a map's voxel border ring.
--
-- A Gen 2 connection owns only its overlap strip. The rectangular corner
-- between two connections is still filled from the current map's border
-- block, and Cherrygrove deliberately declares WATER there. In 2D that is a
-- harmless screen-edge fill; under a tilted camera it becomes a conspicuous
-- square lake. This module lets the voxel presentation author a different
-- metatile in selected off-body blocks without modifying gameplay map data.

local V = ...

local authored = V.data("voxel_map_aprons")
local MapAprons = {}
local patchCache = {}

function MapAprons.genericBorderAllowed(map, tx, ty)
  local scope = map and authored.borderScopes
    and authored.borderScopes[map.id]
  if not scope then return true end
  local bx, by = math.floor(tx / 4), math.floor(ty / 4)
  return bx >= scope.bx0 and bx <= scope.bx1
     and by >= scope.by0 and by <= scope.by1
end

local function patchesFor(map)
  local mapId = map and map.id
  if not mapId then return nil end
  if patchCache[mapId] ~= nil then return patchCache[mapId] or nil end
  local patches = {}
  for _, connector in pairs(authored.connectors or {}) do
    local at = connector.connections and connector.connections[mapId]
    if at then
      patches[#patches + 1] = {
        bx0 = at.bx,
        by0 = at.by,
        bx1 = at.bx + connector.width - 1,
        by1 = at.by + connector.height - 1,
        block = connector.block,
        southEdgeSourceRow = connector.southEdgeSourceRow,
      }
    end
  end
  patchCache[mapId] = #patches > 0 and patches or false
  return patchCache[mapId] or nil
end

function MapAprons.blockAt(map, bx, by)
  local patches = patchesFor(map)
  if not patches then return nil end
  for _, patch in ipairs(patches) do
    if bx >= patch.bx0 and bx <= patch.bx1
       and by >= patch.by0 and by <= patch.by1 then
      return patch.block
    end
  end
  return nil
end

function MapAprons.containsTile(map, tx, ty)
  local bx, by = math.floor(tx / 4), math.floor(ty / 4)
  for _, patch in ipairs(patchesFor(map) or {}) do
    if bx >= patch.bx0 and bx <= patch.bx1
       and by >= patch.by0 and by <= patch.by1 then
      return true
    end
  end
  return false
end

-- Inclusive tile bounds of every authored apron for this map. The ordinary
-- terrain ring is intentionally small; callers enlarge it only when a patch
-- explicitly reaches farther, keeping the global memory/build optimization.
function MapAprons.tileBounds(map)
  local patches = patchesFor(map)
  if not patches then return nil end
  local x0, y0, x1, y1
  for _, patch in ipairs(patches) do
    local px0, py0 = patch.bx0 * 4, patch.by0 * 4
    local px1, py1 = (patch.bx1 + 1) * 4 - 1, (patch.by1 + 1) * 4 - 1
    x0, y0 = math.min(x0 or px0, px0), math.min(y0 or py0, py0)
    x1, y1 = math.max(x1 or px1, px1), math.max(y1 or py1, py1)
  end
  return x0, y0, x1, y1
end

function MapAprons.tileAt(map, tx, ty)
  local bx, by = math.floor(tx / 4), math.floor(ty / 4)
  local patch
  for _, candidate in ipairs(patchesFor(map) or {}) do
    if bx >= candidate.bx0 and bx <= candidate.bx1
       and by >= candidate.by0 and by <= candidate.by1 then
      patch = candidate
      break
    end
  end
  if not patch then return nil end
  local block = map.tileset and map.tileset.blocks
    and map.tileset.blocks[patch.block + 1]
  if not block then return nil end
  local row = ty % 4
  if patch.southEdgeSourceRow ~= nil
     and by == patch.by1 and row == 3 then
    row = patch.southEdgeSourceRow
  end
  return block[row * 4 + (tx % 4) + 1]
end

return MapAprons
