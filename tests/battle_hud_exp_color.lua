local dark, bright = { 1 }, { 2 }
local PaletteFX = {
  pal = function(_, name)
    if name == "EXPBAR" then return { {}, bright, dark, {} } end
    return dark
  end,
}

package.loaded["src.render.PaletteFX"] = PaletteFX
local BattleHud = assert(loadfile("lib/BattleHud.lua"))({})
local original = PaletteFX.pal

BattleHud.withBrightExpBar(function()
  local colors = PaletteFX.pal({}, "EXPBAR")
  assert(colors[3] == bright, "detached HUD kept the dark EXP-bar color")
  assert(colors[2] == bright, "bright EXP-bar color was replaced")
  assert(PaletteFX.pal({}, "GREENBAR") == dark,
    "EXP-bar compatibility changed another palette")
end)

assert(PaletteFX.pal == original, "palette lookup was not restored")
local ok = pcall(BattleHud.withBrightExpBar, function() error("expected") end)
assert(not ok and PaletteFX.pal == original,
  "palette lookup was not restored after a draw error")

print("battle HUD EXP-color regression: ok")
