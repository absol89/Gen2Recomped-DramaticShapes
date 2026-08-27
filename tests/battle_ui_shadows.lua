local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local hud = source("lib/BattleHud.lua")
assert(hud:find("BattleHud._shadowSource = SHADOW", 1, true),
  "battle HUD no longer exposes its drop-shadow shader contract")
assert(hud:find("love.graphics.draw(layer, 1, 1)", 1, true),
  "battle ink shadow is not offset by one logical pixel")
assert(hud:find("preserveOriginal and COLOR_SHADOW_ALPHA or SHADOW_ALPHA", 1, true),
  "COLOR and INVERTED HUD modes no longer have distinct shadow weights")
assert(hud:find("BattleHud.flipGlyphs(w, h, fn, not dark, true)", 1, true),
  "detached battle HUD does not request its drop shadow")

local overworld = source("lib/OverworldBattle.lua")
assert(overworld:find('mode == "OFF" or mode == "HALF"', 1, true),
  "textbox drop shadow is not restricted to OFF and HALF")
assert(overworld:find("end, false, dropShadow)", 1, true),
  "textbox ink does not pass the selected drop-shadow state")
assert(overworld:find("end, color, true)", 1, true),
  "in-frame battle HUD does not request COLOR/INVERTED shadow styling")

print("battle UI drop-shadow regression: ok")
