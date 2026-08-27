-- Immutable geometry source for persistent voxel meshes.
--
-- Runtime Map objects deliberately share their definitions with Game.data.
-- Cut, card-key doors and scripts therefore mutate def.blocks in place, while
-- overworld mods append transient NPC/Pokemon records to def.objects.  Neither
-- kind of session state belongs in a persistent static-mesh key.
--
-- Capture the final modded registries once, after `mods.loaded`, before a save
-- can enter the overworld.  Disk meshes are generated from these private map
-- objects.  A live map may reuse them only while every geometry-bearing field
-- still equals the snapshot; a genuinely edited map is meshed in RAM and never
-- overwrites the static record.

local V = ...

local StaticGeometry = {}

local snapshot, maps = nil, {}
local ledger, ledgerLoaded = {}, false

-- The exclusion ledger is diagnostic. Preserve it on legacy engines, while
-- allowing current sandboxed engines (where love.filesystem raises on access)
-- to keep the same information in memory for the session.
local legacyFilesystem
pcall(function() legacyFilesystem = love and love.filesystem end)

StaticGeometry.EXCLUSION_FILE =
  "mod-derived/BATTLE_ART_VOXEL_FORK/static-cache-exclusions.tsv"

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do
    out[clone(k, seen)] = clone(v, seen)
  end
  return out
end

local function sameList(a, b)
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
  for i = 1, #a do
    local av, bv = a[i], b[i]
    if type(av) == "table" or type(bv) == "table" then
      if not sameList(av, bv) then return false end
    elseif av ~= bv then
      return false
    end
  end
  return true
end

local function sameScalarList(a, b)
  a, b = a or {}, b or {}
  return sameList(a, b)
end

local function clean(value)
  local cleaned = tostring(value or "-"):gsub("[\t\r\n]", " ")
  return cleaned
end

local function loadLedger()
  if ledgerLoaded then return end
  ledgerLoaded = true
  local fs = legacyFilesystem
  if not (fs and fs.read) then return end
  local ok, text = pcall(fs.read, StaticGeometry.EXCLUSION_FILE)
  if not ok or type(text) ~= "string" then return end
  for line in text:gmatch("[^\r\n]+") do
    if line:sub(1, 1) ~= "#" and line ~= "map\tkind\tasset\tdetail" then
      ledger[line] = true
    end
  end
end

local function writeLedger()
  local fs = legacyFilesystem
  if not (fs and fs.write and fs.createDirectory) then return false end
  local rows = {}
  for line in pairs(ledger) do rows[#rows + 1] = line end
  table.sort(rows)
  local text = table.concat({
    "# BATTLE ART VOXEL FORK static-cache exclusion ledger",
    "# Rows are live components deliberately refused by persistent precaching.",
    "# Canonical terrain remains cacheable; this is not a permanent map blacklist.",
    "map\tkind\tasset\tdetail",
    table.concat(rows, "\n"),
    "",
  }, "\n")
  local ok = pcall(function()
    assert(fs.createDirectory("mod-derived/BATTLE_ART_VOXEL_FORK"))
    assert(fs.write(StaticGeometry.EXCLUSION_FILE, text))
  end)
  return ok
end

local function record(mapId, kind, asset, detail)
  loadLedger()
  local line = table.concat({ clean(mapId), clean(kind), clean(asset),
                              clean(detail) }, "\t")
  if ledger[line] then return false end
  ledger[line] = true
  writeLedger()
  return true
end

function StaticGeometry.record(mapId, kind, asset, detail)
  return record(mapId, kind, asset, detail)
end

local function geometryDifferences(map)
  local out = {}
  if not (snapshot and map and map.id and map.def and map.tileset) then
    out[#out + 1] = { "map.unavailable", "-", "missing snapshot or live map" }
    return out
  end
  local def = snapshot.maps[map.id]
  local tileset = def and snapshot.tilesets[def.tileset]
  if not def then
    out[#out + 1] = { "map.unregistered", map.id, "added after mods.loaded" }
    return out
  end
  if not tileset then
    out[#out + 1] = { "tileset.unregistered", def.tileset,
                      "missing from immutable snapshot" }
    return out
  end
  local liveDef, liveTs = map.def, map.tileset
  if liveDef.tileset ~= def.tileset or liveDef.width ~= def.width
     or liveDef.height ~= def.height or liveDef.borderBlock ~= def.borderBlock
     or liveDef.outdoor ~= def.outdoor then
    out[#out + 1] = { "map.layout", map.id,
                      "tileset/size/border/outdoor changed at runtime" }
  end
  if not sameList(liveDef.blocks, def.blocks) then
    out[#out + 1] = { "map.blocks", map.id,
                      "Cut, door, script, or runtime block patch" }
  end
  if liveTs.id ~= tileset.id or liveTs.image ~= tileset.image
     or liveTs.imageWidth ~= tileset.imageWidth
     or liveTs.imageHeight ~= tileset.imageHeight
     or liveTs.tilesPerRow ~= tileset.tilesPerRow
     or liveTs.trueColor ~= tileset.trueColor then
    out[#out + 1] = { "tileset.art", liveDef.tileset,
                      "image or atlas layout changed at runtime" }
  end
  if not sameList(liveTs.blocks, tileset.blocks) then
    out[#out + 1] = { "tileset.blocks", liveDef.tileset,
                      "tile composition changed at runtime" }
  end
  if liveTs.grassTile ~= tileset.grassTile
     or not sameScalarList(liveTs.walkable, tileset.walkable)
     or not sameScalarList(liveTs.doorTiles, tileset.doorTiles)
     or not sameScalarList(liveTs.waterTiles, tileset.waterTiles)
     or not sameScalarList(liveTs.shoreTiles, tileset.shoreTiles) then
    out[#out + 1] = { "tileset.rules", liveDef.tileset,
                      "geometry-bearing collision/material rules changed" }
  end
  return out
end

function StaticGeometry.report(map)
  if not map then return {} end
  local differences = geometryDifferences(map)
  for _, row in ipairs(differences) do
    record(map.id, row[1], row[2], row[3])
  end
  -- Runtime objects are never a mismatch because billboards are not part of
  -- static geometry. Record their asset keys anyway so a playtest can prove
  -- which Pokemon/NPC mod content was explicitly kept out of precaching.
  for _, obj in ipairs((map.def and map.def.objects) or {}) do
    if obj.runtime then
      record(map.id, "runtime.object",
             obj.sprite or obj.image or obj.species or obj.name,
             "owner=" .. clean(obj.owner))
    end
  end
  return differences
end

function StaticGeometry.capture(data)
  if snapshot or not (data and data.maps and data.tilesets) then return false end
  snapshot = { maps = clone(data.maps), tilesets = clone(data.tilesets) }
  maps = {}
  return true
end

function StaticGeometry.available()
  return snapshot ~= nil
end

function StaticGeometry.data()
  return snapshot
end

-- A renderer-free Map is sufficient for Structures/ChunkMesher: those paths
-- query blocks, collision properties and tileset art, never TileRenderer state.
function StaticGeometry.map(id)
  if not snapshot then return nil end
  if maps[id] then return maps[id] end
  local def = snapshot.maps[id]
  local tileset = def and snapshot.tilesets[def.tileset]
  if not (def and tileset) then return nil end
  local Map = require("src.world.Map")
  local map = Map.new(def, tileset)
  maps[id] = map
  return map
end

-- Keep this list intentionally narrower than the whole registry. Objects,
-- warps, signs, connections, palette animation and other gameplay/presentation
-- data do not alter emitted vertices. Everything Structures does read is here.
function StaticGeometry.matches(map)
  return #geometryDifferences(map) == 0
end

-- The private snapshot map is itself the canonical source. Runtime maps return
-- it only when eligible, which lets Disk.fingerprint ignore NPC/object churn.
function StaticGeometry.source(map)
  local canonical = map and StaticGeometry.map(map.id) or nil
  if map == canonical then return canonical end
  StaticGeometry.report(map)
  if StaticGeometry.matches(map) then return canonical end
  return nil
end

return StaticGeometry
