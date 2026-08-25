local registered = nil
package.preload["src.render.Assets"] = function()
  return { register = function(callback) registered = callback end }
end
package.preload["src.core.GameVersion"] = function()
  return { generation = function() return 2 end }
end
package.preload["src.world.gen2.Palettes"] = function()
  return {
    bgSet = function(_, def, daytime)
      return { marker = def.id .. ":" .. daytime }
    end,
    withCaveFlicker = function(colors, phase)
      colors.flicker = phase
      return colors
    end,
  }
end

local made = 0
package.preload["src.world.gen2.Map"] = function()
  return {
    new = function(def, tileset)
      made = made + 1
      return { id = def.id, def = def, tileset = tileset }
    end,
  }
end

local Adapter = assert(loadfile("lib/Gen2WorldAdapter.lua"))({})
local atlas = { getDimensions = function() return 128, 48 end }
local maps = {
  HOME = { id = "HOME", tileset = "JOHTO" },
  NEXT = { id = "NEXT", tileset = "JOHTO" },
}
local tilesets = { JOHTO = { id = "JOHTO", image = "johto.png" } }
local world = {
  maps = maps,
  tilesets = tilesets,
  palettes = {},
  daytime = "DARK",
  flickerPhase = 3,
  map = { id = "HOME", def = maps.HOME, tileset = tilesets.JOHTO },
  neighbors = { { id = "NEXT", ox = 32, oy = 0 } },
  atlasFor = function(_, def)
    assert(def == maps.HOME or def == maps.NEXT)
    return atlas, tilesets.JOHTO
  end,
}

assert(Adapter.prepareWorld(world) == world)
assert(world.map.renderer.image == atlas,
  "current Gold map did not receive its runtime atlas")
assert(world.map._battleArtGen2BgSet.marker == "HOME:DARK"
  and world.map._battleArtGen2BgSet.flicker == 3,
  "current Gold palette did not retain time and cave flicker")
assert(made == 1 and world.neighbors[1].map.id == "NEXT",
  "lightweight Gold neighbor was not materialized")
assert(world.neighbors[1].map.renderer.image == atlas,
  "materialized Gold neighbor did not receive its runtime atlas")
assert(world.map._battleArtGen2AtlasKey == tostring(atlas),
  "map-specific runtime atlas identity was not retained")
assert(type(registered) == "function", "atlas invalidation was not registered")

print("Gen 2 world adapter regression: ok")
