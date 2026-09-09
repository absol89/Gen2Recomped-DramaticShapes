-- Run from the engine root. Exercise the engine's real Gen 2 write method.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "dev/BattleArtGen2"
local Map = require("src.world.gen2.Map")
local World = require("src.world.gen2.World")
local Runtime = require("src.mods.Runtime")
package.loaded["src.world.Map"] = Map
local handlers, calls = {}, {}
local events = { on = function(_, name, fn) handlers[name] = fn end }
Runtime.wants = function(name) return handlers[name] ~= nil end
Runtime.emit = function(name, payload) if handlers[name] then handlers[name](payload) end end
local original = World.replaceBlock
local M = assert(loadfile(root .. "/lib/BlockMeshRefresh.lua"))({
  generation = function() return 2 end,
})
M.install({ refresh = function(...) calls[#calls + 1] = {...} end }, events)
local oldTiles, newTiles = {}, {}
for i = 1, 16 do oldTiles[i], newTiles[i] = 1, 1 end
newTiles[1] = 2
local blocks = {0, 0, 0, 0}
local map = setmetatable({ id = "ROUTE_30", width = 2, height = 2,
  blocks = blocks, def = { width = 2, height = 2, blocks = blocks },
  tileset = { blocks = { oldTiles, newTiles } } }, {__index = Map})
local images = 0
local world = setmetatable({map = map, blockEdits = {},
  refreshMapImages = function() images = images + 1 end}, {__index = World})
T.check(world:replaceBlock(4, 1), "real World edit returns success")
T.eq(images, 1, "engine image refresh still runs")
T.eq(blocks[4], 1, "engine block buffer changes")
T.eq(world.blockEdits.ROUTE_30[4], 0, "engine retains regrowth undo")
T.eq(#calls, 1, "event and wrapper do not refresh twice")
T.same(calls[1], {"ROUTE_30", 1, 1, map, 0}, "Gen 2 flat index resolves to block coordinates and old id")
world:replaceBlock(4, 1)
T.eq(#calls, 1, "same-value write does not stale meshes")
T.check(not world:replaceBlock(99, 1), "invalid index retains engine result")
T.eq(#calls, 1, "invalid index does not refresh")
map:setBlock(1, 1, 0)
T.eq(#calls, 2, "direct map writes/regrowth also refresh")
T.same(calls[2], {"ROUTE_30", 1, 1, map, 1}, "direct write captures its own old id")
map:setBlock(1, 1, 0)
map:setBlock(99, 99, 1)
T.eq(#calls, 2, "same-value and out-of-range direct writes stay inert")
handlers["world.block_replaced"]({mapId = "OTHER"})
T.same(calls[3], {"OTHER"}, "older event-only producers rebuild without erasing unknown props")
world.refreshMapImages = function() error("image failure") end
T.check(not pcall(world.replaceBlock, world, 4, 1), "engine exceptions remain visible")
T.eq(#calls, 4, "partially applied engine edit still refreshes its mesh")
handlers["world.block_replaced"]({mapId = "ROUTE_30"})
T.eq(#calls, 5, "exception clears event suppression")
World.replaceBlock = original
T.finish("Gen 2 block mesh refresh")
