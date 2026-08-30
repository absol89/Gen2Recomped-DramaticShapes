local settings = {}
local V = {
  require = function(name)
    if name == "ModSetting" then
      return { new = function(key, label, values, labels, defaultIndex)
        local setting = { key = key, label = label,
                          values = values, labels = labels,
                          index = defaultIndex or 1 }
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
assert(not UiBackplates.hudUsesColor(),
  "HUD COLOR: INVERTED does not request white HUD ink")
assert(not UiBackplates.hudUsesColorShadow(),
  "HUD COLOR: INVERTED does not request its dark shadow")
settings.hudColor:setIndex(2)
assert(UiBackplates.hudUsesColor(),
  "HUD COLOR: COLOR does not request black HUD ink")
assert(UiBackplates.hudUsesColorShadow(),
  "HUD COLOR: COLOR does not request its bright shadow")
settings.hudColor:setIndex(1)
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
assert(settings.textboxFill:get() == "HALF",
  "TEXTBOX FILL does not default to HALF")
settings.textboxFill:setIndex(4)
assert(not UiBackplates.textboxUsesFrost(),
  "TEXTBOX FILL: OFF still requests frosted glass")
settings.textboxFill:setIndex(2)
local half = UiBackplates.textboxFillStyle()
assert(half and half[4] == 0.30,
  "TEXTBOX FILL: HALF does not expose its translucent fill")
settings.textboxFill:setIndex(3)
local black = UiBackplates.textboxFillStyle()
assert(black and black[1] == 0 and black[4] == 1,
  "TEXTBOX FILL: BLACK does not expose an opaque black fill")
settings.textboxFill:setIndex(1)
local white = UiBackplates.textboxFillStyle()
assert(white and white[1] == 1 and white[4] == 1,
  "TEXTBOX FILL: WHITE does not expose an opaque white fill")

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

local scene = source("lib/BattleScene.lua")
assert(scene:find("Voxel3D.backdrop(artImage", 1, true),
  "PNG arena selection is not connected to the battle scene")
assert(scene:find("externalModelShadow", 1, true)
    and scene:find("drawActorPass", 1, true),
  "Stadium-hosted voxel scenes do not accept model shadows and actors")
local stadiumBackground = source("lib/StadiumBackground.lua")
assert(stadiumBackground:find('scene.register, V.mod, "camera"', 1, true)
    and stadiumBackground:find('scene.register, V.mod, "environment"', 1, true)
    and stadiumBackground:find("OverworldBattle.providerRender", 1, true)
    and stadiumBackground:find("ctx.scene.arena then return next(ctx)", 1, true)
    and stadiumBackground:find("drawShadowCatcher", 1, true),
  "Stadium environment provider is missing its voxel/shadow integration")
local voxel3d = source("lib/Voxel3D.lua")
assert(voxel3d:find("modelSunlight(vModelSun)", 1, true),
  "voxel terrain does not receive the Stadium model shadow map")
local overworld = source("lib/OverworldBattle.lua")
assert(overworld:find("not UiBackplates.hudUsesColor()", 1, true),
  "HUD COLOR is not connected to staged HUD rendering")
assert(overworld:find("UiBackplates.textboxMode()", 1, true),
  "TEXTBOX FILL is not connected to battle text rendering")
local frostChecks = 0
for _ in overworld:gmatch("UiBackplates%.textboxUsesFrost%(%)") do
  frostChecks = frostChecks + 1
end
assert(frostChecks == 2,
  "TEXTBOX FILL does not govern both snapped and fallback frosted panels")
local gen2 = source("lib/Gen2BattleAdapter.lua")
assert(gen2:find("UiBackplates.textboxMode()", 1, true),
  "Gen2 staged battles do not read the Gen2 TEXTBOX FILL setting")
assert(gen2:find("drawingStyledBox", 1, true),
  "Gen2 staged battles do not replace Chrome box paper in its draw transform")
assert(gen2:find("styledBoxes", 1, true),
  "Gen2 staged battles do not track Chrome textbox bounds")
assert(gen2:find("installChromeUiStyle", 1, true),
  "Gen2 staged battles do not install Chrome UI styling")
assert(gen2:find("UiBackplates.hudUsesColor()", 1, true),
  "Gen2 Chrome UI does not read HUD COLOR")
assert(gen2:find("drawShadowWithOpacity(drawShadow, finishShadow", 1, true),
  "Gen2 Chrome UI does not apply the HUD glyph drop shadow")
assert(gen2:find("fresh shadow/main closures", 1, true),
  "Gen2 Chrome does not isolate the shadow palette from each main glyph")
assert(gen2:find('return mode ~= "WHITE" and mode ~= "BLACK"',
  1, true),
  "Gen2 Chrome does not suppress the drop shadow in opaque textbox fill modes")
assert(gen2:find('if mode == "WHITE" then return { 0, 0, 0 }, mode end',
  1, true),
  "Gen2 WHITE textbox text does not override HUD ink to black")
assert(gen2:find('if mode == "HALF" then return { 255, 255, 255 }, mode end',
  1, true),
  "Gen2 HALF textbox text does not override HUD ink to white")
assert(gen2:find('if mode == "HALF" then return { 0, 0, 0 } end', 1, true),
  "Gen2 HALF textbox shadow is not dark")
assert(gen2:find("local BRIGHT_SHADOW_ALPHA = 0.50", 1, true),
  "Gen2 COLOR HUD shadow opacity is not reduced")
assert(gen2:find("local halfFillRects = {}", 1, true),
  "Gen2 HALF textbox fills can compound in overlapping boxes")
assert(gen2:find("currentHalfFillRects", 1, true)
    and gen2:find("halfFillCanvas", 1, true),
  "Gen2 HALF fill de-duplication leaks between wide UI capture canvases")
assert(gen2:find('if textboxMode == "WHITE" then', 1, true),
  "Gen2 WHITE textbox frame does not override HUD ink to black")
assert(gen2:find("Chrome.paletteBox", 1, true),
  "Gen2 Chrome UI box borders do not receive the HUD color")

print("battle UI options regression: ok")
