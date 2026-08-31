local checks = 0
local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL " .. message, 0) end
end

local Mat4 = assert(loadfile("lib/Mat4.lua"))()
local BattleArt = {
  speciesFor = function(mon)
    return mon and ({SPECIES_187="HOPPIP",SPECIES_069="BELLSPROUT"})[mon.species]
      or mon and mon.species
  end,
  isShiny = function() return false end,
}

local created = {}
local function newRenderer(dex, variant)
  local renderer = { dex=dex, variant=variant, finished=false }
  function renderer:worldMetrics() return { height=52.25, floor=0 } end
  function renderer:setContext() return true end
  function renderer:setHandlerRuntime() end
  function renderer:step() end
  function renderer:drawScene() return true end
  function renderer:drawShadowMap() return true end
  function renderer:release() self.released=true end
  created[#created + 1] = renderer
  return renderer
end

local provider = { version="0.10.14", exports = {
  modelsEnabled = function() return true end,
  battleEnabled = function() return true end,
  newRenderer = newRenderer,
  -- 0.10.14 offers both. Embedded voxel scenes deliberately retain the
  -- direct renderer because it draws into the caller's bound color target.
  models = {
    apiVersion = 2,
    newInstance = function()
      error("v2 must not supersede the compatible direct renderer")
    end,
  },
} }
local V = { mod = {
  find = function(id) return id == "STADIUM2_IMPORTER" and provider or nil end,
  log = { warn=function() end },
} }
function V.require(name)
  return assert(({ Mat4=Mat4, BattleArt=BattleArt })[name], name)
end

local StadiumModels = assert(loadfile("lib/StadiumModels.lua"))(V)
local mons = {
  player={species="SPECIES_187", hp=20},
  enemy={species="SPECIES_069", hp=20},
}
local screen = {
  game={data={pokemon={
    SPECIES_187={dex=187,name="HOPPIP"},
    SPECIES_069={dex=69,name="BELLSPROUT"},
  }}},
  player=mons.player,
  enemy=mons.enemy,
}

check(StadiumModels.active(), "0.10.7 direct renderer API is active")
check(StadiumModels.update(screen, 0.1), "unified Gen 2 battle state updates")
check(#created == 2, "both Gen 2 combatants create renderers")
check(created[1].dex == 187 and created[2].dex == 69,
  "activeMon species resolve through screen.game.data")

local placements = StadiumModels.placements({
  player={8,56}, enemy={8,8},
}, 2, {player={canvas=true},enemy={canvas=true}}, screen)
check(placements.player and placements.enemy,
  "legacy models replace both sprite-card slots")

print(("%d checks passed (legacy Gen 2 Stadium model bridge)"):format(checks))
