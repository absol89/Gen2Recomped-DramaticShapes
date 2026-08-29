-- Streaming vs eager-load platform profile for the voxel mesh cache.
--
-- History: a released build eager-loaded the WHOLE compressed cache into RAM
-- on CONTINUE (VoxelCacheRamScreen over Disk.ramPlan/loadIntoRam), which
-- decompressed to ~2.7 GiB of vertices and crashed a 4 GiB Nintendo Switch.
-- The fix keeps the cache on disk and streams per-map on demand; the eager
-- whole-world preload (and any RAM-resident container budget) only applies on
-- desktop-class builds. Consoles/mobiles/handhelds stream and evict the
-- oldest compressed container under a RAM budget so long sessions cannot OOM.
-- This test pins that contract for a future port.

package.preload["src.core.Version"] = function()
  return { engine = "0.7.34" }
end

-- detect() is overridden per-case below; this default is desktop.
local DETECT = { os = "Windows", console = false, mobile = false }
package.preload["src.core.Platform"] = function()
  return { detect = function() return DETECT end }
end

local bytes = {}
local storage = {}
function storage:list(scope, prefix)
  local out = {}
  local under = prefix .. "/"
  for key in pairs(bytes) do
    if key == prefix or key:sub(1, #under) == under then out[#out + 1] = key end
  end
  table.sort(out)
  return out
end
function storage:readBytes(_, key)
  local value = bytes[key]
  if value == nil then return nil, "not_found" end
  return value
end
function storage:writeBytes(_, key, value)
  bytes[key] = value
  return true
end
function storage:delete(_, key)
  if bytes[key] == nil then return false, "not_found" end
  bytes[key] = nil
  return true
end

local StaticGeometry = { source = function(map) return map end, record = function() end }
local V = { mod = { storage = storage } }
function V.require(name)
  if name == "BuildBudget" then return { check = function() end } end
  if name == "StaticGeometry" then return StaticGeometry end
  error("unexpected module " .. tostring(name))
end

local Disk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)

assert(Disk.sizeText(256 * 1024 * 1024) == "256.0 MB",
  "RAM size formatter did not use MB")
assert(Disk.sizeText(1024 * 1024 * 1024) == "1.00 GB",
  "RAM size formatter did not use GB")
do
  -- Gen1Recomp 0.2.25 can omit the Lua GC global. The cache cleanup API must
  -- remain a no-op in that sandbox rather than raising a nil-call error.
  local savedGc = collectgarbage
  collectgarbage = nil
  local ok = pcall(Disk.collectGarbage)
  collectgarbage = savedGc
  assert(ok, "cache cleanup is not safe without collectgarbage")
end

-- Seed a small cache so loadIntoRam has something to hold.
assert(Disk.bind({ save = { version = "gold" } }, true))
Disk.beginPrecache()
Disk.DIRECTORY = Disk.DIRECTORY -- noop to keep lint calm
local map = {
  id = "TEST_MAP",
  def = { tileset = "T", width = 1, height = 1, borderBlock = 0, blocks = { 0 } },
  tileset = { id = "T", image = "t.png", imageWidth = 8, imageHeight = 8,
              tilesPerRow = 1, blocks = { { 0, 0, 0, 0 } }, walkable = { 0 } },
}
local packed = love.data.pack("string", "<ffffff", 1, 2, 3, 0, 0, 1)
local function record() return { n = 1, chunks = { packed } } end
local function aux() return { grass = record(), flowers = { n = 0 }, figures = {} } end
assert(Disk.saveTerrain(map, "full", {}, record(), { n = 0 }))
assert(Disk.saveAux(map, aux()))
local names = Disk.ramPlan()
assert(#names == 2, "seeded cache did not persist two products")

-- A capped mobile CONTINUE budget must spend its first bytes on the map being
-- resumed, not alphabetical records from elsewhere in the world.
bytes[Disk.DIRECTORY .. "/A_FAR/full-terrain"] = "far"
bytes[Disk.DIRECTORY .. "/Z_RESUME/full-terrain"] = "resume"
local prioritized = Disk.ramPlan({ "Z_RESUME", "TEST_MAP" })
assert(prioritized[1] == Disk.DIRECTORY .. "/Z_RESUME/full-terrain",
  "RAM plan did not prioritize the resumed map ahead of alphabetical cache files")
assert(prioritized[2]:find("/TEST_MAP/", 1, true),
  "RAM plan did not retain the caller's preferred-map order")

-- 1) eagerLoadAllowed: desktop yes, console/mobile no.
DETECT = { os = "Windows", console = false, mobile = false }
assert(Disk.eagerLoadAllowed(), "desktop should allow eager whole-world load")
DETECT = { os = "NX", console = true, mobile = false }
assert(not Disk.eagerLoadAllowed(), "Switch (console) must stream, not eager-load")
DETECT = { os = "Android", console = false, mobile = true }
assert(not Disk.eagerLoadAllowed(), "Android (mobile) must stream, not eager-load")
DETECT = { os = "UWP", console = true, mobile = false }
assert(not Disk.eagerLoadAllowed(), "Xbox/UWP (console) must stream, not eager-load")
DETECT = { os = "Windows", console = false, mobile = false }

-- 2) LRU eviction under a RAM budget on streaming platforms.
Disk.beginSession()
Disk.setRamBudget(0)
Disk.loadIntoRam(names[1])
local firstBytes = Disk.ramStats().bytes
Disk.dropRam()
Disk.loadIntoRam(names[2])
local secondBytes = Disk.ramStats().bytes
Disk.dropRam()
local oneContainerBudget = math.max(firstBytes, secondBytes)
Disk.setRamBudget(oneContainerBudget)
-- Both products fit individually but not together. The LRU must retain the
-- newest one rather than emptying the cache because of an arbitrary budget.
for _, name in ipairs(names) do
  local ok = Disk.loadIntoRam(name)
  assert(ok, "loadIntoRam failed for " .. tostring(name))
end
assert(Disk.ramStats().bytes <= Disk.ramBudgetBytes() or Disk.ramBudgetBytes() == 0,
  "ramBytes exceeded the streaming budget")
assert(Disk.ramStats().files == 1,
  "LRU did not retain exactly the newest one-container working set")

-- Normal gameplay uses loadTerrain/loadAux, not loadIntoRam. Those reads must
-- participate in the same bounded LRU or Switch memory would still grow for
-- every map visited even though the title-screen eager load was removed.
Disk.dropRam()
assert(Disk.loadTerrain(map, "full", {}), "runtime terrain stream failed")
assert(Disk.loadAux(map), "runtime aux stream failed")
assert(Disk.ramStats().bytes <= oneContainerBudget,
  "runtime disk reads bypassed the streaming RAM budget")
assert(Disk.ramStats().files == 1,
  "runtime LRU did not evict the older clean container")

-- Runtime-generated misses are deliberately dirty until CACHE -> SAVE. A soft
-- memory cap may evict clean disk-backed blobs, but never silently lose these
-- unsaved records.
Disk.dropRam()
Disk.setRamBudget(1)
assert(Disk.saveTerrain(map, "full", {}, record(), { n = 0 }))
local dirtyStats = Disk.ramStats()
assert(dirtyStats.dirty == 1 and dirtyStats.files == 1,
  "streaming eviction discarded an unsaved runtime cache miss")
assert(dirtyStats.bytes > Disk.ramBudgetBytes(),
  "dirty cache unexpectedly obeyed the soft budget by losing data")
assert(Disk.saveRamToDisk(), "CACHE -> SAVE could not persist protected dirty data")
assert(Disk.ramStats().dirty == 0, "saved runtime cache remained dirty")

-- 3) The CONTINUE decision mirrors eagerLoadAllowed: streaming platforms must
-- NOT drive the whole-world preload screen; they resume straight to disk.
DETECT = { os = "NX", console = true, mobile = false }
assert(not Disk.eagerLoadAllowed(),
  "CONTINUE gate would eager-load the whole world on Switch")
DETECT = { os = "Windows", console = false, mobile = false }

print("precache streaming regression: ok")
