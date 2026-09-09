-- A conservative world-space draw/build budget for the voxel neighborhood.
--
-- Connected maps can be hundreds of world pixels away from the player even
-- though the engine keeps them in state.neighbors. Building and submitting
-- every one mattered less while the legacy FFI sink was available; current
-- sandboxed engines deliberately deny FFI, so avoiding work which cannot enter
-- the camera is the important replacement. The current map is never culled.

local V = ...

local ModSetting = V.require("ModSetting")
local RenderDistance = {}

-- Gen 2 movement cells are 16 world pixels; map blocks are 32. MEDIUM covers
-- 32 cells in every direction,
-- comfortably beyond the stock view and the tilted camera; FULL is exact
-- legacy behavior for screenshots or unusually wide survey views.
RenderDistance.setting = ModSetting.new(
  "renderDistance", "R.DIST",
  { 16, 32, 64, false },
  { "SHORT", "MEDIUM", "FAR", "FULL" },
  2)

function RenderDistance.radius()
  local ok, cells = pcall(RenderDistance.setting.get, RenderDistance.setting)
  if not ok or cells == false then return nil end
  cells = tonumber(cells)
  if not cells then return nil end
  return math.max(16, math.min(64, cells)) * 16
end

local function playerPoint(player)
  if not player then return nil end
  local x = tonumber(player.px or player.x)
  local y = tonumber(player.py or player.y)
  local cellX, cellY = tonumber(player.cellX), tonumber(player.cellY)
  if x == nil and cellX ~= nil then x = cellX * 16 end
  if y == nil and cellY ~= nil then y = cellY * 16 end
  if x == nil or y == nil then return nil end
  return x + 8, y + 8
end

function RenderDistance.point(x, y, player)
  local radius = RenderDistance.radius()
  local px, py = playerPoint(player)
  if not radius or not px then return true end
  local dx, dy = (tonumber(x) or 0) - px, (tonumber(y) or 0) - py
  return dx * dx + dy * dy <= radius * radius
end

-- Distance from the player to the nearest point of a connected map's body.
-- A map whose seam is close remains eligible even when its origin is far away.
function RenderDistance.neighbor(nb, player)
  local radius = RenderDistance.radius()
  local px, py = playerPoint(player)
  if not radius or not px or not (nb and nb.map and nb.map.def) then return true end
  local x0, y0 = tonumber(nb.ox) or 0, tonumber(nb.oy) or 0
  local x1 = x0 + (tonumber(nb.map.def.width) or 0) * 32
  local y1 = y0 + (tonumber(nb.map.def.height) or 0) * 32
  local dx = px < x0 and (x0 - px) or (px > x1 and (px - x1) or 0)
  local dy = py < y0 and (y0 - py) or (py > y1 and (py - y1) or 0)
  return dx * dx + dy * dy <= radius * radius
end

-- A render-only view; do not remove connected maps from the engine world.
-- Keep the original neighbors for stable border masks regardless of distance.
function RenderDistance.view(state)
  if state._distanceNeighbors or not RenderDistance.radius() then return state end
  local view = setmetatable({ neighbors = {},
    _distanceNeighbors = state.neighbors or {} }, { __index = state })
  for _, nb in ipairs(state.neighbors or {}) do
    if RenderDistance.neighbor(nb, state.player) then
      view.neighbors[#view.neighbors + 1] = nb
    end
  end
  return view
end

return RenderDistance
