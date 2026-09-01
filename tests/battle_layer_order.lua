local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local overworld = source("lib/OverworldBattle.lua")
local main = source("main.lua")
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
local apply = assert(overworld:find("pcall(BattleArt.apply, battle)", sideTexture, true))
local reassert = assert(overworld:find("pcall(AnimatedBattleArt.reassert, battle[side])", apply, true))
local pics = assert(overworld:find("innerPics(battle, 0, 0, 0)", reassert, true))
assert(apply < reassert and reassert < pics,
  "animated ownership is not reclaimed after Battle Art and before capture")
local capture = assert(overworld:find("OverworldBattle.animTexture", 1, true))
assert(main:find("installLegacyAlias(payload and payload.loader", 1, true),
  "mods.loaded must publish the StadiumBattleFX discovery alias from its loader")
assert(main:find("StadiumBattleFxProvider:update(dt)", 1, true),
  "the external Stadium model owner is not advanced on Battle Art's tick")
assert(overworld:find('require, "src.ui.gen2.BattleTransition"', 1, true)
    and overworld:find("if voxel then return false end", 1, true),
  "voxel encounter flashes can still palette-remap the shaded world")
assert(not main:find("if OverworldBattle.preBattle() then return nil end", 1, true)
    and overworld:find("dramaticShapeVoxelWideFadeHook", 1, true)
    and overworld:find("if voxel then", 1, true)
    and overworld:find('require, "src.render.BattleTransition"', 1, true)
    and overworld:find("dramaticShapeVoxelRenderFadeHook", 1, true)
    and overworld:find("session.preBattle = false", 1, true),
  "entry transitions can expose transformed voxel meshes or a clear-color frame")
assert(main:find("OverworldBattle.entryTransitionActive()", 1, true)
    and overworld:find("function OverworldBattle.entryTransitionActive", 1, true),
  "voxel geometry can leak into the palette-authored encounter transition")
local stadiumBackground = source("lib/StadiumBackground.lua")
local stadiumModels = source("lib/StadiumModels.lua")
assert(stadiumBackground:find("ensureRendererCompatibility(actor.renderer", 1, true)
    and stadiumBackground:find("local hostedReady = scene and scene.host and scene.screen", 1, true)
    and stadiumModels:find("function StadiumModels.ensureRendererCompatibility", 1, true)
    and stadiumModels:find("renderer%-contract%-", 1),
  "scene API actors bypass the >=0.10.11 portable color contract or diagnostics")
assert(stadiumModels:find("battle.showPlayerBack", 1, true)
    and stadiumModels:find('safeCall(battle, "fxFaintActive"', 1, true)
    and stadiumModels:find("battler.shownHP", 1, true),
  "Stadium model visibility/shadows or faint timing bypass Gen 2 presentation state")
local hostedProvider = source("lib/StadiumBattleFxProvider.lua")
assert(hostedProvider:find("function Provider:update(dt)", 1, true)
    and hostedProvider:find("handle.exports.modelProvider", 1, true),
  "hosted Stadium models cannot advance queued faint animations")
local render = assert(overworld:find("BattleScene.render", capture, true))
local hud = assert(overworld:find("OverworldBattle.snapHUDs", render, true))
assert(capture < render and render < hud,
  "animation capture, world render, and HUD composite are out of order")
local provider = assert(overworld:find("function OverworldBattle.providerRender", 1, true))
local providerEnd = assert(overworld:find(
  "function OverworldBattle.providerFinish", provider, true))
local hosted = overworld:sub(provider, providerEnd - 1)
local hostedDof = assert(hosted:find("BattleDOF.apply", 1, true))
local hostedHud = assert(hosted:find("OverworldBattle.snapHUDs", hostedDof, true))
assert(hostedDof < hostedHud and hosted:find("session.snapped =", hostedHud, true),
  "StadiumBattleFX-hosted frames do not snap and own the edge HUDs")
local hudEnd = assert(overworld:find("function OverworldBattle.drawHudPanels", hud, true))
local snappedHud = overworld:sub(hud, hudEnd - 1)
assert(snappedHud:find("not UiBackplates.hudUsesColor()", 1, true),
  "snapped HUD no longer honors the selected HUD color")
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
assert(scene:find("side = side", 1, true)
    and scene:find("trainer = tex.trainer == true", 1, true),
  "world cards do not retain the side/trainer metadata needed for ownership")
assert(scene:find("hostedActors and not card.trainer", 1, true),
  "hosted Stadium actors do not replace Pokemon cards while preserving trainers")
assert(scene:find("if tex.trainer then oy = oy + 2 * k end", 1, true),
  "trainer battle cards are not lifted to place visible feet on the ground")
local effect = assert(scene:find("BattleScene.fxCard", 1, true))
local effectDraw = assert(scene:find("BattleBillboard.PULL + 6", effect, true))
local finish = assert(scene:find("Voxel3D.endScene", effectDraw, true))
assert(effect < effectDraw and effectDraw < finish,
  "the animation plane is not part of the world scene")

print("battle layer-order regression: ok")
