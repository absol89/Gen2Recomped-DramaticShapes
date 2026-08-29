local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local main = source("main.lua")
local ramSetting = assert(main:find(
  '"ramPrecacheMb", "RAM PRECACHE MB"', 1, true))
local ramSettingEnd = assert(main:find("local PipelineCanvas", ramSetting, true))
local ramDefinition = main:sub(ramSetting, ramSettingEnd - 1)
assert(ramDefinition:find(
  '{ 256, 512, 1024, 1536, 2048, 2560, 3172, 0 }', 1, true),
  "RAM PRECACHE MB choices do not include the requested budgets")
assert(ramDefinition:find(
  '{ "256", "512", "1024", "1536", "2048", "2560", "3172", "FULL" }',
  1, true), "RAM PRECACHE MB labels do not expose FULL")
assert(ramDefinition:find("\n  3)", 1, true),
  "RAM PRECACHE MB does not default to 1024")
assert(main:find("{ RamPrecacheSetting,", 1, true),
  "RAM PRECACHE MB is not part of the shared settings surface")
local ramEntry = assert(main:find("{ RamPrecacheSetting,", 1, true))
local ramEntryEnd = assert(main:find("{ VoxelGrid.setting,", ramEntry, true))
assert(main:sub(ramEntry, ramEntryEnd - 1):find("full = true", 1, true),
  "RAM PRECACHE MB disappears under VOXEL FULL")
assert(main:find("applyRamPrecacheBudget()", 1, true),
  "RAM PRECACHE MB is not applied to cache loading")
assert(main:find("VoxelCacheRamScreen.new(game, resume, priorityMaps)", 1, true),
  "CONTINUE does not expose the RAM loading screen")
assert(main:find("VoxelPrecache.startupMapIds(game.data, game.save)", 1, true),
  "CONTINUE does not prioritize the saved map for the RAM cache")
assert(main:find("applyRamPrecacheBudget()", ramEntryEnd, true),
  "new-game cache setup does not use RAM PRECACHE MB")
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
local frontFlip = assert(main:find("{ BattleArt.frontFlipSetting,", 1, true))
local spriteLight = assert(main:find("{ UiBackplates.spriteLight,", frontFlip, true))
assert(main:sub(frontFlip, spriteLight - 1):find(
  'BattleArt.playerSide() == "front"', 1, true),
  "FLIP FRONT SPRITE remains visible for selected back sprites")
local rowsRefresh = assert(main:find(
  "local hadPlayerSide = BattleArt.playerSide()", 1, true))
assert(main:find("BattleArt.playerSide() ~= hadPlayerSide", rowsRefresh, true),
  "switching PLAYER does not refresh its conditional option rows")

local worldFill = assert(main:find("{ WorldUnderlay.setting,", 1, true))
local nextSetting = assert(main:find("{ DayNight.setting,", worldFill, true))
assert(main:sub(worldFill, nextSetting - 1):find("managerOnly = true", 1, true),
  "WORLD FILL is not restricted to the mod-specific options page")
assert(main:find("local offered = not entry.managerOnly", 1, true),
  "the in-game options menu does not honor manager-only settings")
assert(main:find('key = VOXEL_OPTION_KEY, type = "choice", label = "VOXEL"',
  1, true), "the mod manager has no VOXEL quality selector")
assert(main:find('table.insert(extra, 1, {', 1, true),
  "the Gen 2 VOXEL row is not placed ahead of secondary mod settings")
assert(main:find('row.id == "zoom"', 1, true),
  "Gen 2 mod rows are not anchored before the options screen's CANCEL row")
assert(main:find('setVoxelOption(g, target)', 1, true),
  "the touch VOXEL row does not step the complete bidirectional ladder")
assert(main:find('"CACHE SAVED\\n%d FILE%s\\nRAM %s\\n%d IN RAM"', 1, true),
  "CACHE SAVE does not report the selected-unit RAM size")
assert(main:find('"CACHE ALREADY SAVED\\nRAM %s"', 1, true),
  "CACHE ALREADY SAVED does not report the RAM size")

local presentation = assert(main:find(
  "local function applyPresentationDefaults", 1, true))
local rowsHook = assert(main:find(
  'mod.hooks:wrap("ui.options.rows"', presentation, true))
local preset = main:sub(presentation, rowsHook - 1)
assert(preset:find('opts.colors = "redpp"', 1, true),
  "COLORS does not start at ADVANCED")
assert(preset:find('opts.uiLayout = "centered"', 1, true),
  "UI LAYOUT does not start CENTERED")
for _, event in ipairs({ "save.loaded", "save.created" }) do
  local handler = assert(main:find(
    'mod.events:on("' .. event .. '"', 1, true))
  local handlerEnd = assert(main:find("end)", handler, true))
  assert(main:sub(handler, handlerEnd):find(
    "applyPresentationDefaults()", 1, true),
    event .. " does not apply the presentation defaults")
end

print("options surface regression: ok")
