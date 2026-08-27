love = love or {}

local made
package.preload["src.world.Map"] = function()
  return { new = function(def, tileset)
    made = { def = def, tileset = tileset, id = def.id }
    return made
  end }
end

local StaticGeometry = assert(loadfile("lib/StaticGeometry.lua"))({})
local maps = {
  ROUTE_29 = { id = "ROUTE_29", tileset = "JOHTO",
    width = 1, height = 1, blocks = { 1 } },
}
local tilesets = {
  JOHTO = { id = "JOHTO", blocks = { { 0, 0, 0, 0 } } },
}

assert(StaticGeometry.capture({ gen2Maps = maps, gen2Tilesets = tilesets }),
  "mods.loaded raw Gen2 catalogs were rejected")
assert(StaticGeometry.data().maps.ROUTE_29,
  "Gen2 map catalog was not normalized for the precacher")
assert(StaticGeometry.data().tilesets.JOHTO,
  "Gen2 tileset catalog was not normalized for the precacher")
assert(StaticGeometry.data().maps ~= maps,
  "static geometry retained the mutable runtime catalog")
local map = StaticGeometry.map("ROUTE_29")
assert(map and map.id == "ROUTE_29" and made.tileset.id == "JOHTO",
  "normalized Gen2 map could not be constructed")

print("static geometry Gen2 catalog regression: ok")
