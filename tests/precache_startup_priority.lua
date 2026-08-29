-- Capped mobile CONTINUE must spend its first cache bytes on the saved map,
-- not alphabetical records elsewhere in the Gen2 world.

local V = {}
function V.require(name)
  if name == "ChunkMesher" then return {} end
  if name == "VoxelMeshDisk" then return { staticEligible = function() return true end } end
  error("unexpected module " .. tostring(name))
end

local Precache = assert(loadfile("lib/VoxelPrecache.lua"))(V)
local data = {
  gen2Maps = {
    CAVE = { connections = {} },
    ROUTE_NORTH = { connections = {} },
    ROUTE_SOUTH = { connections = {} },
    TOWN = { connections = {
      north = { mapId = "ROUTE_NORTH" },
      south = { mapId = "ROUTE_SOUTH" },
    } },
  },
}
local ids = Precache.startupMapIds(data, {
  player = { map = "TOWN" }, lastOutdoor = { id = "CAVE" },
})
assert(table.concat(ids, ",") == "TOWN,ROUTE_NORTH,ROUTE_SOUTH,CAVE",
  "startup map priority did not retain saved map, neighbours, and last outdoor")

print("precache_startup_priority: ok")
