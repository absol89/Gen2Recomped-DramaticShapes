-- Gen 2 edits the flat block buffer in World:replaceBlock, not Map:setBlock.
-- Capture the old id before that write; the public event only has the new id.
local V = ...
local M = {}

function M.install(mesher, events)
  local pending = {}
  local function refresh(map, bx, by, before)
    if map and map.id and before ~= nil and map:blockAt(bx, by) ~= before then
      mesher.refresh(map.id, bx, by, map, before)
    end
  end
  events:on("world.block_replaced", function(payload)
    local id = payload and (payload.mapId or (payload.map and payload.map.id))
    -- The wrapped call handles its own notification after the engine returns.
    -- Unwrapped/older event producers retain the conservative in-place rebuild.
    if id and not pending[id] then mesher.refresh(id) end
  end)

  local Map = require("src.world.Map") -- Gen2Compat aliases the live Gen 2 class.
  local originalSet = Map.setBlock
  Map.setBlock = function(self, bx, by, block)
    local before = self:blockAt(bx, by)
    local result = originalSet(self, bx, by, block)
    if not pending[self.id] then refresh(self, bx, by, before) end
    return result
  end

  if V.generation() ~= 2 then return end
  local World = require("src.world.gen2.World")
  local originalReplace = World.replaceBlock
  World.replaceBlock = function(self, index, block, ...)
    local map = self.map
    local width = map and map.width
    local valid = map and map.id and type(width) == "number" and width > 0
      and type(index) == "number" and index == math.floor(index)
      and index > 0 and map.def and map.def.blocks
      and map.def.blocks[index] ~= nil
    if not valid then return originalReplace(self, index, block, ...) end
    local bx, by = (index - 1) % width, math.floor((index - 1) / width)
    local before = map:blockAt(bx, by)
    pending[map.id] = (pending[map.id] or 0) + 1
    local ok, result = pcall(originalReplace, self, index, block, ...)
    pending[map.id] = pending[map.id] > 1 and pending[map.id] - 1 or nil
    refresh(map, bx, by, before)
    if not ok then error(result, 0) end
    return result
  end
end

return M
