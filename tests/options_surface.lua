local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local main = source("main.lua")
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
