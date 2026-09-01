local settings = {}
local V = {
  require = function(name)
    if name == "ModSetting" then
      return { new = function(key, label, values, labels)
        local setting = { key = key, label = label,
                          values = values, labels = labels, index = 1 }
        function setting:get() return self.values[self.index] end
        function setting:setIndex(index) self.index = index end
        settings[key] = setting
        return setting
      end }
    end
    error(name)
  end,
}

local UiBackplates = assert(loadfile("lib/UiBackplates.lua"))(V)
assert(settings.hudColor.values[1] == "INVERTED",
  "HUD COLOR does not default to INVERTED")
assert(table.concat(settings.arenaFill.values, ",") == "OFF,WHITE,PNG,STADIUM2",
  "ARENA FILL exposes choices outside this release")
settings.arenaFill:setIndex(4)
assert(UiBackplates.arenaStadium2() and not UiBackplates.arenaArt(),
  "STADIUM2 is not isolated from flat illustrated arena handling")
settings.arenaFill:setIndex(1)
assert(not UiBackplates.arenaStadium2() and not UiBackplates.arenaArt(),
  "ARENA FILL: OFF no longer retains the voxel battlefield")
assert(table.concat(settings.stadiumCircle.values, ",") == "ON,OFF,HALF"
    and UiBackplates.stadiumCircleScale() == 1,
  "STADIUM CIRCLE does not expose the full/two-size platform control")
settings.stadiumCircle:setIndex(3)
assert(math.abs(UiBackplates.stadiumCircleScale() - 2 / 3) < 1e-9,
  "STADIUM CIRCLE: HALF is not two-thirds size")
settings.stadiumCircle:setIndex(2)
assert(UiBackplates.stadiumCircleScale() == 0,
  "STADIUM CIRCLE: OFF still requests visible platform geometry")
assert(settings.backdropOffset.values[1] == 100,
  "BG Y-OFFSET does not default to 100 PX")
assert(settings.bossBg.values[1] == "OFF",
  "BOSS BG does not default to OFF")
assert(settings.textboxFill.values[1] == "HALF",
  "TEXTBOX FILL does not default to HALF")
assert(UiBackplates.textboxUsesFrost(),
  "TEXTBOX FILL: HALF no longer owns its single glass backplate")
assert(UiBackplates.HALF_CHROME_INSET == 2
    and UiBackplates.HALF_FRAME_OUTSET == 1
    and UiBackplates.HALF_INSET == 1,
  "TEXTBOX FILL: HALF is not one logical pixel outside visible chrome")
do
  local x, y, w, h = UiBackplates.halfRect(0, 0, 160, 48, 1)
  assert(x == 1 and y == 2 and w == 158 and h == 47,
    "HALF plate is not horizontally inset and vertically tuned")
end
assert(UiBackplates.HALF_Y_OFFSET == -2,
  "TEXTBOX FILL: HALF does not preserve the two-pixel bottom margin")
settings.textboxFill:setIndex(3)
assert(not UiBackplates.textboxUsesFrost(),
  "TEXTBOX FILL: BLACK still stacks glass below opaque paper")
settings.textboxFill:setIndex(4)
assert(not UiBackplates.textboxUsesFrost(),
  "TEXTBOX FILL: OFF still requests frosted glass")

local VoxelState = assert(loadfile("lib/VoxelState.lua"))()
local freshOptions = {}
assert(VoxelState.seedOptions(freshOptions)
    and freshOptions.pipelines.voxel == VoxelState.FULL_LEVEL,
  "a fresh Gen 2 save does not default VOXEL to FULL")
local explicitOff = { pipelines = { voxel = 0 } }
assert(not VoxelState.seedOptions(explicitOff)
    and explicitOff.pipelines.voxel == 0,
  "an explicit VOXEL: OFF choice is overwritten")

local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local main = source("main.lua")
for _, setting in ipairs({ "hudColor", "arenaFill", "stadiumCircle", "backdropOffset",
                           "textboxFill" }) do
  assert(main:find("{ UiBackplates." .. setting .. ",", 1, true),
    setting .. " is missing from the in-game options schema")
end
local boss = assert(main:find("{ UiBackplates.bossBg,", 1, true))
local textbox = assert(main:find("{ UiBackplates.textboxFill,", boss, true))
assert(main:sub(boss, textbox - 1):find("managerOnly = true", 1, true),
  "BOSS BG is not restricted to the mod-specific options page")
assert(not main:find("{ BattleArt.backPlacementSetting,", 1, true),
  "dead BACK PLACEMENT is exposed in the options schema")
assert(main:find('moduleName = "src.core.gen2.Unown"', 1, true)
    and main:find('moduleName = "src.ui.gen2.BattleAnimView"', 1, true),
  "Stadium 2 Importer 0.10.7 engine-module aliases are missing")

local scene = source("lib/BattleScene.lua")
assert(scene:find("Voxel3D.backdrop(artImage", 1, true),
  "PNG arena selection is not connected to the battle scene")
assert(scene:find("externalModelShadow", 1, true)
    and scene:find("drawActorPass", 1, true),
  "Stadium-hosted voxel scenes do not accept model shadows and actors")
local stadium = source("lib/StadiumBackground.lua")
assert(stadium:find('scene.register, V.mod, phase, callback, 100', 1, true)
    and stadium:find("OverworldBattle.providerRender", 1, true)
    and stadium:find("drawTrainer", 1, true)
    and stadium:find("drawShadowCatcher", 1, true),
  "Stadium scene-provider integration is incomplete")
assert(stadium:find('trainerShowing(screen, "player")', 1, true)
    and stadium:find("pokemonReady(sceneCtx.scene.screen, side)", 1, true),
  "player trainer exit does not retain exclusive world-slot ownership")
assert(stadium:find('if not (host and host.arenaRenderer) then return "OFF" end',
    1, true),
  "unavailable STADIUM2 arenas do not fall back to the voxel OFF path")
assert(stadium:find("local function installLegacy(handle)", 1, true)
    and stadium:find("exports and exports.presentation", 1, true)
    and stadium:find("legacyProviderRender", 1, true),
  "Stadium 2 Importer 0.10.7 compatibility path is missing")
assert(stadium:find("Scene.surfaceDimensions(g, width, height)", 1, true),
  "legacy Stadium clock can still pass a nil surface into Battle Art")
assert(stadium:find("providerRender(scene.battle, actors,", 1, true)
    and stadium:find("nil, shadow, scene.screen)", 1, true),
  "legacy OFF mode does not use Battle Art's steerable voxel camera")
local stadiumModels = source("lib/StadiumModels.lua")
assert(stadiumModels:find("battle.activeMon", 1, true)
    and stadiumModels:find("battle.game.data", 1, true),
  "legacy Stadium models cannot resolve unified Gen 2 combatants")
local voxel3d = source("lib/Voxel3D.lua")
assert(voxel3d:find("modelSunlight(vModelSun)", 1, true),
  "voxel terrain does not receive the Stadium model shadow map")
local overworld = source("lib/OverworldBattle.lua")
local mesher = source("lib/ChunkMesher.lua")
local meshDisk = source("lib/VoxelMeshDisk.lua")
assert(overworld:find("not UiBackplates.hudUsesColor()", 1, true),
  "HUD COLOR is not connected to staged HUD rendering")
assert(overworld:find("UiBackplates.textboxMode()", 1, true),
  "TEXTBOX FILL is not connected to battle text rendering")
assert(mesher:find("local function flushConnection(tx, ty)", 1, true)
    and mesher:find("local function crowds(tx, ty, h)", 1, true)
    and mesher:find("local n = crowds(tx, ty - 1, h)", 1, true)
    and mesher:find("local se = crowds(tx + 1, ty + 1, h)", 1, true),
  "connected edges still AO-shade against their hidden border ring")
assert(meshDisk:find("Disk.CACHE_REVISION = 7", 1, true)
    and meshDisk:find("MapAprons.cacheTag(map)", 1, true),
  "the connection-AO vertex change did not invalidate persistent meshes")
local voxelScene = source("lib/VoxelScene.lua")
assert(voxelScene:find("VoxelScene.silhouetteSetting = ModSetting.new", 1, true)
    and voxelScene:find("VoxelScene.GHOST_RADIUS_CELLS = 15", 1, true)
    and voxelScene:find("for _, p in ipairs(posed) do", 1, true)
    and main:find("{ VoxelScene.silhouetteSetting,", 1, true),
  "the all-character silhouette option is not completely integrated")
local shadows = source("lib/Shadows.lua")
local shadowMap = source("lib/ShadowMap.lua")
assert(shadows:find('ModSetting.new("shadowQuality", "SHADOWS"', 1, true)
    and shadowMap:find("if Shadows.off() then return false end", 1, true)
    and voxel3d:find("external and not Shadows.off()", 1, true)
    and voxelScene:find("if Shadows.enabled() and not Voxel3D.shadowsActive()",
                        1, true)
    and main:find("{ Shadows.setting,", 1, true),
  "the global shadow toggle is not completely integrated")
assert(overworld:find("UiBackplates.HALF_Y_OFFSET", 1, true),
  "active Gen 2 HALF frame and panel offset is missing")
assert(overworld:find("local function uiPresentation", 1, true)
    and overworld:find("if Renderer.uiFill then", 1, true)
    and overworld:find("shot.ph / uih", 1, true)
    and overworld:find("ui = uiPresentation(shot)", 1, true)
    and overworld:find("connectedHalfPanels(textPanelRects, ui.scale)", 1, true),
  "snapped HALF plate does not use the engine's final UI presentation")
assert(overworld:find("connectedHalfPanels", 1, true)
    and overworld:find("local seam = lower.panel%[2%]")
    and overworld:find("panels = connectedHalfPanels", 1, true),
  "connected HALF boxes are not built from one gap-free outer silhouette")
local frostChecks = 0
for _ in overworld:gmatch("UiBackplates%.textboxUsesFrost%(%)") do
  frostChecks = frostChecks + 1
end
assert(frostChecks == 2,
  "TEXTBOX FILL does not govern both snapped and fallback frosted panels")
assert(overworld:find("providerBegin", 1, true)
    and overworld:find("providerRender", 1, true),
  "provider-hosted battle boundary is missing")
assert(overworld:find("session.apiHosted and session.providerShot", 1, true),
  "provider-hosted voxel shots cannot open the battle camera input gate")
assert(overworld:find("g.overworld or g.world", 1, true),
  "Gen2Recomped's world owner cannot seed the voxel battle arena")

local art = source("lib/BattleArt.lua")
assert(art:find('"enemyTrainerImage"', 1, true)
    and art:find('"enemyTrainerTrueColor"', 1, true)
    and art:find("battle.enemyTrainerClass", 1, true),
  "native Gen 2 opponent trainer art surface is not supported")
local animated = source("lib/AnimatedBattleArt.lua")
assert(animated:find("AnimatedBattleArt.finish(battle, trainerBattle)", 1, true),
  "native Gen 2 trainer animation state is not restored on mode changes")

local aux = source("lib/BattleAuxUi.lua")
assert(aux:find("self.tx, self.ty = 0", 1, true)
    and aux:find("g.translate(-72, 0)", 1, true)
    and aux:find("UiBackplates.textboxFillStyle()", 1, true),
  "battle prompts/stats are not attached and styled")

local gen2 = source("lib/Gen2BattleAdapter.lua")
assert(gen2:find('require, "src.ui.gen2.BattleState"', 1, true)
    and gen2:find("getActiveBattleScene", 1, true),
  "native Gen 2 battle scene discovery is missing")
assert(gen2:find("Hud.modalLayer", 1, true)
    and gen2:find("height - 52 * s", 1, true)
    and gen2:find("local inset = 2 * s", 1, true),
  "Gen 2 prompts/stats are not captured into the safe widescreen slot")
assert(gen2:find("current", 1, true)
    and gen2:find("subtract(paper)", 1, true)
    and gen2:find("UiBackplates.halfRect", 1, true),
  "Gen 2 HALF box overlap protection is missing")
assert(not gen2:find("fillRect(g,", 1, true),
  "Gen 2 compatibility compositor still doubles captured box backplates")
assert(gen2:find("self.animView.drawObjects", 1, true),
  "native Gen 2 attack objects are not composited over the model anchors")
assert(gen2:find("local function composite(scene, screen", 1, true)
    and gen2:find("lowerY - 96*s", 1, true),
  "version-neutral prompt/stats compositor is missing")

print("battle UI options regression: ok")
