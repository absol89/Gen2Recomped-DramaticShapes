-- Gold/Silver map preparation for Gen1Recomp's shared drawWorld pipeline.

local V = ...
local Assets = require("src.render.Assets")

local Adapter = {}
local pixelsByAtlas = setmetatable({}, { __mode = "k" })

local function active()
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  return ok and GameVersion and type(GameVersion.generation) == "function"
    and tonumber(GameVersion.generation()) == 2
end

-- Gen1Recomp's generated Gen-2 cache names tilesets with ROM constants such
-- as TILESET_JOHTO. Dramatic Shapes' authored geometry predates that cache
-- vocabulary and is keyed as TilesetJohto. Only normalize the presentation
-- id consumed by the voxel modules; map.def.tileset remains the engine key.
local function profileTilesetId(raw)
  if type(raw) ~= "string" or raw:sub(1, 8) ~= "TILESET_" then return raw end
  local out = { "Tileset" }
  for word in raw:sub(9):gmatch("[^_]+") do
    local lower = word:lower()
    out[#out + 1] = lower:sub(1, 1):upper() .. lower:sub(2)
  end
  return table.concat(out)
end

Adapter.profileTilesetId = profileTilesetId

local function paletteSet(world, map)
  local ok, Palettes = pcall(require, "src.world.gen2.Palettes")
  if not (ok and Palettes and Palettes.bgSet and world.palettes
      and map and map.def) then return nil end
  local daytime = world.daytime or world.tod or "DAY"
  local colors = Palettes.bgSet(world.palettes, map.def, daytime)
  if colors and daytime == "DARK" and Palettes.withCaveFlicker then
    colors = Palettes.withCaveFlicker(colors, world.flickerPhase or 1)
  end
  return colors
end

-- World:atlasFor keys its composed image by the engine tileset and, for the
-- two Johto outdoor sheets, the map group's roof.  Keep the same identity in
-- plain data: userdata tostring values change every process and therefore
-- cannot participate in a persistent-cache contract.
local ROOF_TILESETS = {
  TILESET_JOHTO = true,
  TILESET_JOHTO_MODERN = true,
}

local function atlasProfile(world, map)
  local def = map and map.def or {}
  local engineId = def.tileset
  local roofName
  if ROOF_TILESETS[engineId] then
    roofName = world and world.roofs and world.roofs.mapGroupRoofs
      and world.roofs.mapGroupRoofs[def.group]
  end
  return tostring(engineId or "-") .. (roofName and ("|" .. roofName) or "")
end

Adapter.atlasProfile = atlasProfile

-- The title menu has no live overworld yet, but whole-game precaching must use
-- exactly the same atlas composer as gameplay.  This deliberately constructs
-- only the fields World:atlasFor reads; World:load would start gameplay and
-- mutate considerably more engine state.
function Adapter.staticWorld(game, data)
  if not (active() and type(data) == "table") then return nil end
  local ok, World = pcall(require, "src.world.gen2.World")
  if not (ok and World and type(World.atlasFor) == "function") then return nil end
  local tilesets = data.gen2Tilesets or data.tilesets
  if type(tilesets) ~= "table" then return nil end
  return {
    game = game,
    tilesets = tilesets,
    roofs = data.gen2Roofs or data.roofs,
    palettes = data.gen2Palettes or data.palettes,
    daytime = "DAY",
    flickerPhase = 1,
    atlasCache = {},
    atlasFor = World.atlasFor,
  }
end

function Adapter.prepareMap(world, map)
  if not (active() and world and map and map.def
      and type(world.atlasFor) == "function") then return map end
  local ok, atlas, tileset = pcall(world.atlasFor, world, map.def)
  if not (ok and atlas) then return map end
  map.tileset = tileset or map.tileset
  if map.tileset then
    local engineId = map.def.tileset or map.tileset.id
    local profileId = profileTilesetId(engineId)
    if profileId then
      map.tileset._battleArtEngineTilesetId =
        map.tileset._battleArtEngineTilesetId or map.tileset.id or engineId
      map.tileset.id = profileId
    end
  end
  map.renderer = map.renderer or {}
  map.renderer.data = (world.game and world.game.data) or map.renderer.data
  map.renderer.image = atlas
  map._battleArtGen2BgSet = paletteSet(world, map)
  map._battleArtGen2AtlasKey = tostring(atlas)
  map._battleArtGen2AtlasProfile = atlasProfile(world, map)
  return map
end

function Adapter.prepareWorld(world)
  if not (active() and world and world.maps and world.tilesets) then
    return world
  end
  Adapter.prepareMap(world, world.map)
  local ok, Map = pcall(require, "src.world.gen2.Map")
  if not (ok and Map and type(Map.new) == "function") then return world end
  for _, neighbor in ipairs(world.neighbors or {}) do
    if not neighbor.map then
      local def = world.maps[neighbor.id]
      local tileset = def and world.tilesets[def.tileset]
      if def and tileset then neighbor.map = Map.new(def, tileset) end
    end
    Adapter.prepareMap(world, neighbor.map)
  end
  return world
end

-- World:atlasFor includes live roof overlays that are absent from the raw
-- tileset PNG.  Read that composed atlas once so terrain recolouring keeps
-- those map-specific pixels.
function Adapter.sourcePixels(map)
  if not (active() and map and map.renderer and map.renderer.image
      and love and love.graphics and love.graphics.newCanvas) then
    return nil
  end
  local atlas = map.renderer.image
  if pixelsByAtlas[atlas] ~= nil then return pixelsByAtlas[atlas] or nil end

  local g = love.graphics
  local pushed = false
  local canvas = nil
  local ok, data = pcall(function()
    local w, h = atlas:getDimensions()
    canvas = g.newCanvas(w, h, { dpiscale = 1 })
    g.push("all")
    pushed = true
    g.origin()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("replace", "premultiplied")
    g.setColor(1, 1, 1, 1)
    g.draw(atlas, 0, 0)
    local out = canvas:newImageData()
    g.pop()
    pushed = false
    return out
  end)
  if pushed then pcall(g.pop) end
  if canvas and canvas.release then pcall(canvas.release, canvas) end
  pixelsByAtlas[atlas] = ok and data or false
  return ok and data or nil
end

function Adapter.invalidate()
  for _, data in pairs(pixelsByAtlas) do
    if data and data ~= false and data.release then pcall(data.release, data) end
  end
  pixelsByAtlas = setmetatable({}, { __mode = "k" })
end

if Assets.register then Assets.register(Adapter.invalidate) end

return Adapter
