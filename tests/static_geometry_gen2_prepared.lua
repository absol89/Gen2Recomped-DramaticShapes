-- A title precache map and a live Gen2 map use different GPU atlas objects,
-- but must resolve to the same immutable prepared geometry and disk key.

love = love or {}
package.preload["src.render.Assets"] = function()
  return { register = function() end }
end
package.preload["src.core.GameVersion"] = function()
  return { generation = function() return 2 end }
end
package.preload["src.world.gen2.Palettes"] = function() return {} end
package.preload["src.world.gen2.World"] = function()
  return {
    atlasFor = function(self, def)
      return { owner = self }, self.tilesets[def.tileset]
    end,
  }
end
package.preload["src.world.Map"] = function()
  return {
    new = function(def, tileset)
      return { id = def.id, def = def, tileset = tileset }
    end,
  }
end

local Adapter = assert(loadfile("lib/Gen2WorldAdapter.lua"))({})
local modules = { Gen2WorldAdapter = Adapter }
local V = { require = function(name) return assert(modules[name], name) end }
local StaticGeometry = assert(loadfile("lib/StaticGeometry.lua"))(V)

local def = {
  id = "CHERRYGROVE_CITY", group = "GROUP_CHERRYGROVE",
  tileset = "TILESET_JOHTO", width = 1, height = 1,
  borderBlock = 0, outdoor = true, blocks = { 1 },
}
local rawTileset = {
  id = "TILESET_JOHTO", image = "johto.png",
  imageWidth = 128, imageHeight = 48, tilesPerRow = 16,
  blocks = { { 0, 1, 2, 3 } }, walkable = {}, doorTiles = {},
  waterTiles = {}, shoreTiles = {},
}
local roofs = {
  mapGroupRoofs = { GROUP_CHERRYGROVE = "ROOF_CHERRYGROVE" },
  roofs = {},
}
local data = {
  gen2Maps = { CHERRYGROVE_CITY = def },
  gen2Tilesets = { TILESET_JOHTO = rawTileset },
  gen2Roofs = roofs,
}

assert(StaticGeometry.capture(data))
assert(StaticGeometry.configure({ data = data }))
local canonical = assert(StaticGeometry.map("CHERRYGROVE_CITY"))
assert(canonical.tileset.id == "TilesetJohto")
assert(canonical._battleArtGen2AtlasProfile
  == "TILESET_JOHTO|ROOF_CHERRYGROVE")

local liveTileset = {}
for key, value in pairs(rawTileset) do liveTileset[key] = value end
local live = { id = def.id, def = def, tileset = liveTileset }
local liveWorld = {
  game = { data = data }, tilesets = { TILESET_JOHTO = liveTileset },
  roofs = roofs, atlasCache = {},
  atlasFor = require("src.world.gen2.World").atlasFor,
}
Adapter.prepareMap(liveWorld, live)

assert(live.renderer.image ~= canonical.renderer.image,
  "fixture did not create distinct runtime atlas objects")
assert(StaticGeometry.source(live) == canonical,
  "prepared gameplay map could not reuse title-precache geometry")

print("static geometry prepared Gen2 reuse regression: ok")
