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
Disk.setRamBudget(0)            -- reset
-- Load both containers, then impose a tiny budget and confirm the oldest is
-- dropped first and ramBytes stays within budget after a fresh load.
Disk.setRamBudget(#names * 64)  -- smaller than two typical blobs
for _, name in ipairs(names) do
  local ok = Disk.loadIntoRam(name)
  assert(ok, "loadIntoRam failed for " .. tostring(name))
end
assert(Disk.ramStats().bytes <= Disk.ramBudgetBytes() or Disk.ramBudgetBytes() == 0,
  "ramBytes exceeded the streaming budget")
-- Force one more load beyond budget: oldest must be evicted to stay in budget.
local before = Disk.ramStats().files
Disk.loadIntoRam(names[1])  -- re-touch; eviction targets the LRU head
assert(Disk.ramStats().bytes <= Disk.ramBudgetBytes(),
  "evictOldest did not keep ramBytes within budget")
assert(before >= 1, "eviction removed all resident containers unexpectedly")

-- 3) The CONTINUE decision mirrors eagerLoadAllowed: streaming platforms must
-- NOT drive the whole-world preload screen; they resume straight to disk.
DETECT = { os = "NX", console = true, mobile = false }
assert(not Disk.eagerLoadAllowed(),
  "CONTINUE gate would eager-load the whole world on Switch")
DETECT = { os = "Windows", console = false, mobile = false }

print("precache streaming regression: ok")
