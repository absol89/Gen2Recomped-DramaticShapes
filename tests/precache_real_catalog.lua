local path = assert(os.getenv("GEN2_MAPS_PATH"), "GEN2_MAPS_PATH missing")
local maps = assert(loadfile(path))()
local Precache = assert(loadfile("lib/VoxelPrecache.lua"))({
  require = function(name)
    if name == "ChunkMesher" then return {} end
    if name == "VoxelMeshDisk" then
      return { staticEligible = function() return true end }
    end
    error("unexpected module " .. tostring(name))
  end,
})

local jobs = Precache.allJobs({ gen2Maps = maps })
local full, body = 0, 0
for _, job in ipairs(jobs) do
  if job.bodyOnly then body = body + 1 else full = full + 1 end
end
assert(full > 100, "real Gen2 catalog unexpectedly produced no map jobs")
assert(body > 0, "real Gen2 mapId connections produced no body jobs")
print(("real Gen2 precache catalog: %d maps, %d body jobs"):format(full, body))
