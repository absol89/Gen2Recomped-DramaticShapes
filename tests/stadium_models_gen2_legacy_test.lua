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
  local renderer = { dex=dex, variant=variant, finished=false, context="idle",
    contextCalls={} }
  function renderer:worldMetrics() return { height=52.25, floor=0 } end
  function renderer:setContext(context)
    self.context=context
    self.contextCalls[context]=(self.contextCalls[context] or 0)+1
    self.finished=false
    return true
  end
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

screen.enemy.hp = 0
screen.enemy.shownHP = 20
screen.draining = true
screen.fxHidden = function(_, mon) return mon == screen.enemy end
screen.fxFaintActive = function() return false end
check(StadiumModels.update(screen, 0.1), "faint presentation updates")
placements = StadiumModels.placements({
  player={8,56}, enemy={8,8},
}, 2, {player={canvas=true},enemy={canvas=true}}, screen)
check(created[2].context == "faint" and placements.enemy,
  "lethal hit starts authored faint before displayed HP reaches zero")
screen.draining = nil
check(StadiumModels.update(screen, 0.1), "faint signal hand-off updates")
screen.fxFaintActive = function() return true end
screen.enemy.fainted = true
check(StadiumModels.update(screen, 0.1), "native faint signal updates")
check(created[2].contextCalls.faint == 1,
  "Gen 2 lethal/faint signal hand-off restarts the Stadium faint clip")
check(StadiumModels.covers({enemy={canvas=true}}, "enemy"),
  "fainting Stadium model suppresses native species card")
check(not StadiumModels.covers({enemy={canvas=true,trainer=true}}, "enemy"),
  "Stadium Pokemon ownership never suppresses trainer cards")

screen.animPlaying = true
screen.animName = "TACKLE"
screen.animAttackerIsPlayer = false
check(StadiumModels.update(screen, 0.1), "late move edge updates")
check(created[2].context == "faint",
  "late attack edge cannot overwrite terminal faint context")

created[2].finished = true
check(StadiumModels.update(screen, 0.1), "finished faint updates")
placements = StadiumModels.placements({
  player={8,56}, enemy={8,8},
}, 2, {player={canvas=true},enemy={canvas=true}}, screen)
check(not placements.enemy,
  "finished faint keeps model and shadow placement hidden")

print(("%d checks passed (legacy Gen 2 Stadium model bridge)"):format(checks))
