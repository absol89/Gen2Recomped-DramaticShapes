-- Version-scoped persistent/RAM lifecycle without constructing GPU meshes.

package.preload["src.core.Version"] = function()
  return { engine = "0.7.34" }
end
package.preload["src.core.Platform"] = function()
  return { detect = function() return { os = "Windows" } end }
end

local bytes = {}
local storage = {}
function storage:list(_, prefix)
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

local StaticGeometry = {
  source = function(map) return map end,
  record = function() end,
}
local V = { mod = { storage = storage } }
function V.require(name)
  if name == "BuildBudget" then
    return { check = function() end }
  elseif name == "StaticGeometry" then
    return StaticGeometry
  elseif name == "MapAprons" then
    return { cacheTag = function() return "" end }
  end
  error("unexpected module " .. tostring(name))
end

local Disk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)
local map = {
  id = "TEST_MAP",
  def = {
    tileset = "TEST_TILESET", width = 1, height = 1,
    borderBlock = 0, blocks = { 0 },
  },
  tileset = {
    id = "TEST_TILESET", image = "test.png",
    imageWidth = 8, imageHeight = 8, tilesPerRow = 1,
    blocks = { { 0, 0, 0, 0 } }, walkable = { 0 },
  },
}

local packed = love.data.pack("string", "<ffffff", 1, 2, 3, 0, 0, 1)
local function record() return { n = 1, chunks = { packed } } end
local function aux()
  return { grass = record(), flowers = { n = 0 }, figures = {} }
end

-- Title PRECACHE writes directly to the version namespace.
assert(Disk.bind({ save = { version = "gold" } }, true))
assert(Disk.DIRECTORY:match("/gold$"), "Gold cache is not version-scoped")
Disk.beginPrecache()
assert(Disk.saveTerrain(map, "full", {}, record(), { n = 0 }))
assert(Disk.saveAux(map, aux()))
local goldKeys = storage:list(nil, Disk.DIRECTORY)
assert(#goldKeys == 2, "title precache did not persist both products")

-- Silver cannot enumerate or reuse Gold records.
assert(Disk.bind({ save = { version = "silver" } }, true))
assert(Disk.DIRECTORY:match("/silver$"), "Silver cache is not version-scoped")
assert(#storage:list(nil, Disk.DIRECTORY) == 0,
  "Silver saw records from the Gold namespace")
Disk.beginPrecache()
assert(Disk.saveTerrain(map, "full", {}, record(), { n = 0 }))
local silverKey = storage:list(nil, Disk.DIRECTORY)[1]
assert(silverKey and bytes[silverKey], "Silver record was not persisted")

-- CONTINUE copies compressed containers to RAM and performs no generation.
assert(Disk.bind({ save = { version = "gold" } }, false))
Disk.beginSession()
local names = Disk.ramPlan()
assert(#names == 2 and not Disk.ramReady(names),
  "CONTINUE plan did not describe the persisted Gold cache")
for _, name in ipairs(names) do assert(Disk.loadIntoRam(name)) end
assert(Disk.ramReady(names), "CONTINUE did not finish the RAM preload")
local loaded = Disk.loadTerrain(map, "full", {})
assert(loaded and loaded.terrain and loaded.terrain.n == 1,
  "RAM-preloaded terrain did not decode")

-- Gameplay replacements remain dirty until explicit CACHE / SAVE.
assert(Disk.saveTerrain(map, "body", nil, record(), { n = 0 }))
assert(Disk.ramStats().dirty == 1,
  "runtime cache miss wrote through instead of remaining dirty")
local ok, saved, failed = Disk.saveRamToDisk()
assert(ok and saved == 1 and failed == 0 and Disk.ramStats().dirty == 0,
  "CACHE SAVE did not commit exactly the dirty RAM record")

-- A shell-side Gold/Silver switch cannot retain compressed or dirty RAM from
-- the previously bound version.
assert(Disk.bind({ save = { version = "silver" } }, false))
assert(Disk.ramStats().files == 0,
  "version switch retained the previous version's RAM cache")
assert(Disk.bind({ save = { version = "gold" } }, false))
Disk.beginSession()

-- DROP deletes only the active game version and clears its RAM mirror.
local removed = Disk.purge()
assert(removed >= 3 and #storage:list(nil, Disk.DIRECTORY) == 0,
  "DROP did not remove the Gold version cache")
assert(bytes[silverKey] ~= nil, "Gold DROP removed the Silver cache")
assert(Disk.ramStats().files == 0, "DROP retained compressed RAM records")

print("precache lifecycle regression: ok")
