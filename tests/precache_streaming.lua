package.preload["src.core.Version"] = function()
  return { engine = "0.7.34" }
end
local DETECT = { os = "Windows", console = false, mobile = false }
package.preload["src.core.Platform"] = function()
  return { detect = function() return DETECT end }
end

local bytes, storage = {}, {}
function storage:list(_, prefix)
  local out, under = {}, prefix .. "/"
  for key in pairs(bytes) do
    if key:sub(1, #under) == under then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end
function storage:readBytes(_, key) return bytes[key] end
function storage:writeBytes(_, key, value) bytes[key] = value; return true end
function storage:delete(_, key) bytes[key] = nil; return true end

local V = { mod = { storage = storage } }
function V.require(name)
  if name == "BuildBudget" then return { check = function() end } end
  if name == "StaticGeometry" then
    return { source = function(map) return map end, record = function() end }
  end
  if name == "MapAprons" then
    return { cacheTag = function() return "" end }
  end
  error(name)
end
local Disk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)
assert(Disk.bind({ save = { version = "crystal" } }, true))
Disk.beginPrecache()

local map = {
  id = "STREAM_TEST",
  def = { tileset = "T", width = 1, height = 1,
          borderBlock = 0, blocks = { 0 } },
  tileset = { id = "T", image = "t.png", imageWidth = 8, imageHeight = 8,
    tilesPerRow = 1, blocks = { { 0, 0, 0, 0 } }, walkable = { 0 } },
}
local packed = love.data.pack("string", "<ffffff", 1, 2, 3, 0, 0, 1)
local function record() return { n = 1, chunks = { packed } } end
assert(Disk.saveTerrain(map, "full", {}, record(), { n = 0 }))
assert(Disk.saveAux(map, { grass = record(), flowers = { n = 0 }, figures = {} }))
local names = Disk.ramPlan()
assert(#names == 2, "test cache did not persist both map products")

-- OFF is a policy, not a tiny positive budget: it must prevent both the
-- CONTINUE plan and neighbourhood preloads while leaving on-demand reads
-- available through loadTerrain/loadAux.
Disk.beginSession()
Disk.setRamPrecacheEnabled(false)
assert(#Disk.ramPlan() == 0, "RAM PRECACHE OFF still planned eager reads")
assert(not Disk.loadIntoRam(names[1]), "RAM PRECACHE OFF accepted an eager read")
assert(Disk.preload(map, false) == 0,
  "RAM PRECACHE OFF warmed a neighbourhood record")
assert(Disk.loadTerrain(map, "full", {}),
  "RAM PRECACHE OFF disabled ordinary on-demand cache reads")
assert(Disk.ramStats().files == 0,
  "RAM PRECACHE OFF retained a clean on-demand container")
Disk.setRamPrecacheEnabled(true)

-- Capped mobile CONTINUE must begin with the resumed map rather than cache
-- records from alphabetical earlier locations.
bytes[Disk.DIRECTORY .. "/A_FAR/full-terrain"] = "far"
bytes[Disk.DIRECTORY .. "/Z_RESUME/full-terrain"] = "resume"
local prioritized = Disk.ramPlan({ "Z_RESUME", "STREAM_TEST" })
assert(prioritized[1] == Disk.DIRECTORY .. "/Z_RESUME/full-terrain",
  "RAM plan did not prioritize the resumed map")
assert(prioritized[2]:find("/STREAM_TEST/", 1, true),
  "RAM plan did not retain preferred-map order")

DETECT = { os = "Windows", console = false, mobile = false }
assert(Disk.eagerLoadAllowed(), "desktop lost eager cache loading")
for _, platform in ipairs({
  { os = "NX", console = true },
  { os = "Android", mobile = true },
  { os = "iOS", mobile = true },
}) do
  DETECT = platform
  assert(not Disk.eagerLoadAllowed(), platform.os .. " attempted eager preload")
end
assert(Disk.recommendedRamBudget() == 1024 * 1024 * 1024,
  "mobile cache budget did not expand to 1 GB")

Disk.beginSession()
Disk.setRamBudget(0)
Disk.loadIntoRam(names[1]); local one = Disk.ramStats().bytes
Disk.dropRam()
Disk.loadIntoRam(names[2]); one = math.max(one, Disk.ramStats().bytes)
Disk.dropRam()
Disk.setRamBudget(one)
assert(Disk.loadTerrain(map, "full", {}), "runtime terrain stream failed")
assert(Disk.loadAux(map), "runtime decoration stream failed")
assert(Disk.ramStats().bytes <= one and Disk.ramStats().files == 1,
  "runtime reads bypassed the one-container LRU budget")

-- Unsaved runtime misses remain protected until explicit CACHE -> SAVE.
Disk.dropRam()
Disk.setRamBudget(1)
assert(Disk.saveTerrain(map, "full", {}, record(), { n = 0 }))
assert(Disk.ramStats().dirty == 1 and Disk.ramStats().files == 1,
  "LRU discarded an unsaved runtime cache miss")
assert(Disk.saveRamToDisk())
assert(Disk.ramStats().dirty == 0)

print("precache streaming regression: ok")
