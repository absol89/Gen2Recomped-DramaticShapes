local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local main = source("main.lua")
local backSprites = assert(main:find("{ OverworldBattle.backSetting,", 1, true))
local battleArt = assert(main:find("{ BattleArt.setting,", backSprites, true))
assert(main:sub(backSprites, battleArt - 1):find("managerOnly = true", 1, true),
  "BACK SPRITES is not restricted to the mod-specific options page")
local battle = source("lib/OverworldBattle.lua")
local backDefault = assert(battle:find(
  "OverworldBattle.backSetting = ModSetting.new", 1, true))
local backEnd = assert(battle:find("function OverworldBattle.backPinned", backDefault, true))
assert(battle:sub(backDefault, backEnd - 1):find(
  '{ false, true }, { "OFF", "ON" }', 1, true),
  "BACK SPRITES does not default to OFF")
local trainerArt = assert(main:find("{ BattleArt.trainerSetting,", 1, true))
local playerArt = assert(main:find("{ BattleArt.playerArtSetting,", trainerArt, true))
assert(main:sub(trainerArt, playerArt - 1):find("managerOnly = true", 1, true),
  "TRAINER ART is not restricted to the mod-specific options page")
local playerAnim = assert(main:find("{ BattleArt.playerAnimationSetting,", 1, true))
local frontAnim = assert(main:find("{ BattleArt.frontAnimationSetting,", 1, true))
assert(playerAnim < frontAnim,
  "PLAYER ANIM is not exposed beside the animated Battle Art rows")

local worldFill = assert(main:find("{ WorldUnderlay.setting,", 1, true))
local nextSetting = assert(main:find("{ DayNight.setting,", worldFill, true))
assert(main:sub(worldFill, nextSetting - 1):find("managerOnly = true", 1, true),
  "WORLD FILL is not restricted to the mod-specific options page")
assert(main:find("local offered = not entry.managerOnly", 1, true),
  "the in-game options menu does not honor manager-only settings")

print("options surface regression: ok")
