local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local overworld = source("lib/OverworldBattle.lua")
local sideTexture = assert(overworld:find("function OverworldBattle.sideTexture", 1, true))
local sideTextureEnd = assert(overworld:find(
  "function OverworldBattle.flashing", sideTexture, true))
assert(overworld:sub(sideTexture, sideTextureEnd - 1):find(
  "not BattleArt.mirrorsPlayerSprite()", 1, true),
  "player capture does not respect front-versus-back mirror policy")
local picHook = assert(overworld:find("function BattleState:picImage", 1, true))
local externalBypass = assert(overworld:find(
  "BattleArt.isExternal(img)", picHook, true))
local frontRomBypass = assert(overworld:find(
  "OverworldBattle.isFrontPokemonPic(self, img)", externalBypass, true))
local romBackFill = assert(overworld:find("BattlePics.filled", frontRomBypass, true))
local pinnedBack = assert(overworld:find(
  "OverworldBattle.pinnedPic(self, img)", romBackFill, true))
assert(externalBypass < frontRomBypass and frontRomBypass < romBackFill,
  "front ROM transparency is not preserved before back ROM reconstruction")
assert(romBackFill < pinnedBack,
  "ROM back reconstruction no longer retains its pinned-slot behavior")
local apply = assert(overworld:find("pcall(BattleArt.apply,", sideTexture, true))
local reassert = assert(overworld:find("pcall(AnimatedBattleArt.reassert, mon)", apply, true))
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
assert(snappedHud:find("not UiBackplates.hudUsesColor()", 1, true),
  "snapped HUD no longer honors the selected HUD color")
assert(snappedHud:find("for _, rect in pairs(panels) do BattleHud.panel", 1, true),
  "snapped text-box panels are not isolated from exposed HUD regions")
assert(overworld:find("if shot.animInWorld then return end", 1, true),
  "the duplicate UI animation layer is not suppressed")

local gen2Install = assert(overworld:find(
  'V.require("Gen2BattleAdapter").install', 1, true))
local gen2AnimCapture = assert(overworld:find(
  "innerAnim = drawGen2AnimObjects", 1, true))
assert(gen2AnimCapture < gen2Install,
  "Gen 2 returns from installation before enabling attack-object capture")
local objectDraw = assert(overworld:find(
  "view:drawObjects(battle.anim, battle.battle)", 1, true))
local backgroundDraw = overworld:find("view:present", objectDraw, true)
assert(not backgroundDraw or backgroundDraw > gen2Install,
  "Gen 2 world attack capture includes the opaque animation background")

local gen2 = source("lib/Gen2BattleAdapter.lua")
assert(gen2:find("withoutOpaqueBattlePaper", 1, true),
  "Gen 2 staged battles no longer suppress the opaque native backdrop")
assert(gen2:find("state.drawPic = function() end", 1, true),
  "Gen 2 staged battles no longer suppress duplicate native pictures")
assert(not gen2:find("state.battle and state.battle.over", 1, true),
  "Gen 2 outcome frames revive native screen-space battle pictures")
assert(overworld:find("not battle.enemyTrainerTrueColor", sideTexture, true)
    and overworld:find("not battle.playerBackTrueColor", sideTexture, true),
  "authored true-colour trainers are routed through inferred matte keying")
assert(gen2:find("isScreenFlash", 1, true),
  "Gen 2 staged battles no longer remove the opaque-paper flash")
assert(gen2:find("function BattleState:frontAnimFrame", 1, true)
    and gen2:find("BattleArt.isExternal(mon.sprite)", 1, true),
  "Gen 2 native front animation is not suppressed for selected Battle Art")
assert(gen2:find("UiBackplates.textboxMode()", 1, true),
  "Gen 2 staged textbox fill is not routed through Battle Art")
local keyedHud = assert(gen2:find("BattlePics.shade0Transparent", 1, true))
assert(gen2:find('"hpBar", "expBar", "enemyBorder", "playerBorder"', 1, true),
  "Gen 2 staged HUD sheets are not all routed through paper keying")
assert(gen2:find("hud.images[path] = image", keyedHud, true),
  "Gen 2 staged HUD image swaps are not restored after the draw")
assert(overworld:find("battle.picHidden[side]", sideTexture, true),
  "Gen 2 fainted pictures remain eligible for a world billboard")
assert(overworld:find("battle.faintSlide = nil", sideTexture, true),
  "Gen 2 fainting pictures are still cropped instead of lowered in-world")

local stagedPics = assert(overworld:find("stagedPics = BattleState.drawPicsLayer", 1, true))
local pinPics = assert(overworld:find("self.drawPicsLayer = stagedPics", 1, true))
local uiDraw = assert(overworld:find(
  "pcall(withoutBackgroundFill, self, innerDraw)", pinPics, true))
local restorePics = assert(overworld:find(
  "self.drawPicsLayer = instancePics", uiDraw, true))
assert(stagedPics > restorePics and pinPics < uiDraw and uiDraw < restorePics,
  "staged draws do not transactionally defeat per-state picture overrides")

local scene = source("lib/BattleScene.lua")
assert(scene:find("groundY %- %(tex.sink or 0%)", 1),
  "Gen 2 faint progress does not lower the world billboard")
local effect = assert(scene:find("BattleScene.fxCard", 1, true))
local effectDraw = assert(scene:find("BattleBillboard.PULL + 6", effect, true))
local finish = assert(scene:find("Voxel3D.endScene", effectDraw, true))
assert(effect < effectDraw and effectDraw < finish,
  "the animation plane is not part of the world scene")

print("battle layer-order regression: ok")
