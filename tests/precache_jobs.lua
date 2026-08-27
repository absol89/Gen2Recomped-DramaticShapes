-- Whole-version generation ignores registry metadata and queues real maps.

local Precache = assert(loadfile("lib/VoxelPrecache.lua"))({
  require = function(name)
    if name == "ChunkMesher" then return {} end
    if name == "VoxelMeshDisk" then return { staticEligible = function() return true end } end
    error("unexpected module " .. tostring(name))
  end,
})

local jobs = Precache.allJobs({ maps = {
  _romInfo = { version = "silver", checksum = 123 },
  ROUTE_1 = {
    id = "ROUTE_1", tileset = "JOHTO", width = 2, height = 2,
    blocks = { 1, 2, 3, 4 }, connections = { east = { map = "ROUTE_2" } },
  },
  ROUTE_2 = {
    id = "ROUTE_2", tileset = "JOHTO", width = 2, height = 2,
    blocks = { 1, 2, 3, 4 }, connections = {},
  },
} })

assert(#jobs == 4, "two connected maps should each have full and body jobs")
for _, job in ipairs(jobs) do
  assert(job.id ~= "_romInfo", "registry metadata was queued as a map")
end
-- The raw Game2 dataset passed by mods.loaded is namespaced; no compatibility
-- proxy has manufactured data.maps yet. Connections likewise use mapId in
-- extracted Gold/Silver/Crystal catalogs.
local gen2Jobs = Precache.allJobs({ gen2Maps = {
  NEW_BARK_TOWN = {
    id = "NEW_BARK_TOWN", tileset = "JOHTO", width = 2, height = 2,
    blocks = { 1, 2, 3, 4 },
    connections = { east = { map = 1, mapId = "ROUTE_29" } },
  },
  ROUTE_29 = {
    id = "ROUTE_29", tileset = "JOHTO", width = 2, height = 2,
    blocks = { 1, 2, 3, 4 }, connections = {},
  },
} })
assert(#gen2Jobs == 4,
  "raw Gen2 catalogs/mapId connections did not enumerate full and body jobs")

print("precache jobs regression: ok")
