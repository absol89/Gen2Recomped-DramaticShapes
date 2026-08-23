local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local overworld = source("lib/OverworldBattle.lua")
local sideTexture = assert(overworld:find("function OverworldBattle.sideTexture", 1, true))
local apply = assert(overworld:find("pcall(BattleArt.apply, battle)", sideTexture, true))
local reassert = assert(overworld:find("pcall(AnimatedBattleArt.reassert, battle[side])", apply, true))
local pics = assert(overworld:find("innerPics(battle, 0, 0, 0)", reassert, true))
assert(apply < reassert and reassert < pics,
  "animated ownership is not reclaimed after Battle Art and before capture")
local capture = assert(overworld:find("OverworldBattle.animTexture", 1, true))
local render = assert(overworld:find("BattleScene.render", capture, true))
local hud = assert(overworld:find("OverworldBattle.snapHUDs", render, true))
assert(capture < render and render < hud,
  "animation capture, world render, and HUD composite are out of order")
local hudEnd = assert(overworld:find("function OverworldBattle.drawHudPanels", hud, true))
local snappedHud = overworld:sub(hud, hudEnd - 1)
assert(snappedHud:find("BattleHud.verdict(readable, shot, true)", 1, true),
  "snapped HUD contrast no longer measures the exposed HUD regions")
assert(snappedHud:find("for _, rect in pairs(panels) do BattleHud.panel", 1, true),
  "snapped text-box panels are not isolated from exposed HUD regions")
assert(overworld:find("if shot.animInWorld then return end", 1, true),
  "the duplicate UI animation layer is not suppressed")

local stagedPics = assert(overworld:find("stagedPics = BattleState.drawPicsLayer", 1, true))
local pinPics = assert(overworld:find("self.drawPicsLayer = stagedPics", 1, true))
local uiDraw = assert(overworld:find(
  "pcall(withoutBackgroundFill, self, innerDraw)", pinPics, true))
local restorePics = assert(overworld:find(
  "self.drawPicsLayer = instancePics", uiDraw, true))
assert(stagedPics > restorePics and pinPics < uiDraw and uiDraw < restorePics,
  "staged draws do not transactionally defeat per-state picture overrides")

local scene = source("lib/BattleScene.lua")
local effect = assert(scene:find("BattleScene.fxCard", 1, true))
local effectDraw = assert(scene:find("BattleBillboard.PULL + 6", effect, true))
local finish = assert(scene:find("Voxel3D.endScene", effectDraw, true))
assert(effect < effectDraw and effectDraw < finish,
  "the animation plane is not part of the world scene")

print("battle layer-order regression: ok")
