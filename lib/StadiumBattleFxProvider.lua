-- Optional StadiumBattleFX Battle Presentation API v1 arena provider.
-- StadiumBattleFX owns the independently selected models/effects while Battle
-- Art supplies its staged voxel world and open depth pass.

local V = ...
local OverworldBattle = V.require("OverworldBattle")
local UiBackplates = V.require("UiBackplates")

local Provider = { registered = false, fallback = nil }

local function available(context)
  -- STADIUM2 deliberately returns ownership to StadiumBattleFX's built-in
  -- arena. Every other Battle Art fill, especially OFF's voxel map, uses this
  -- provider and keeps the independently selected Stadium model source.
  return UiBackplates.arenaFill:get() ~= "STADIUM2"
    and OverworldBattle.providerAvailable(context and context.battle)
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

function Provider:arena(context)
  if not available(context) then
    return self.fallback
  end
  return OverworldBattle.arena()
end

function Provider:begin(context)
  return OverworldBattle.providerBegin(context and context.battle)
    or self.fallback
end

function Provider:render(context, arena, drawActors)
  local canvas = OverworldBattle.providerRender(
    context and context.battle, drawActors)
  return canvas or self.fallback
end

function Provider:finish()
  OverworldBattle.providerFinish()
end

function Provider.register()
  if Provider.registered then return true end
  local handle = findMod("STADIUM_BATTLE_FX")
  local api = handle and handle.exports and handle.exports.battles
  if not (api and tonumber(api.version) == 1
      and type(api.registerComponent) == "function") then return false end
  Provider.fallback = api.FALLBACK
  local ok, id = pcall(api.registerComponent, api, V.mod.id, "arena",
    "voxel-map", {
      label = "BATTLE ART VOXEL MAP",
      description = "Battle Art's staged voxel-map arena with the selected "
        .. "StadiumBattleFX Pokemon model provider.",
      provider = Provider,
      available = available,
    })
  if not ok then
    if V.mod.log and V.mod.log.warn then
      V.mod.log:warn("StadiumBattleFX arena registration failed: %s",
        tostring(id))
    end
    return false
  end
  Provider.registered, Provider.id = true, id
  return true
end

return Provider
