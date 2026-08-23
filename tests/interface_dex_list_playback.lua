local interfaceMode = "battle_art"
local replacement, fitted, rom = {}, {}, {}
function fitted:getDimensions() return 56, 56 end

local marks = {}
package.loaded["src.render.PaletteFX"] = {
  markTrueColor = function(...) marks[#marks + 1] = { ... } end,
}

local ListMenu = {}
function ListMenu:update() self.stockUpdates = (self.stockUpdates or 0) + 1 end
function ListMenu:drawGen2Dex()
  local species = self.items[self.index].value
  self.drawn = self.dexPics and self.dexPics[species] or rom
end
package.loaded["src.ui.ListMenu"] = ListMenu

local setting = { get = function() return interfaceMode end }
local BattleArt = {
  setting = { get = function() return "animated" end },
  frontAnimationSetting = { get = function() return "gen4" end },
  displayMode = function() return "color" end,
  fitPreparedFrames = function(frames)
    assert(frames[1] == replacement)
    return { fitted }
  end,
}
local AnimatedBattleArt = {
  interfaceFront = function() return { replacement }, { 100 } end,
}
local V = {
  require = function(name)
    if name == "ModSetting" then
      return { new = function() return setting end }
    elseif name == "BattleArt" then
      return BattleArt
    elseif name == "AnimatedBattleArt" then
      return AnimatedBattleArt
    end
    error(name)
  end,
  mod = { assets = { path = function(_, path) return path end } },
}

local InterfaceSprites = assert(loadfile("lib/InterfaceSprites.lua"))(V)
InterfaceSprites.installDexList()

local species = "SPECIES_TEST"
local menu = {
  items = { { value = species } }, index = 1,
  dexPics = { [species] = rom },
}
ListMenu.drawGen2Dex(menu)
assert(menu.drawn == fitted, "Pokedex list retained its static ROM preview")
assert(menu.dexPics[species] == rom, "Pokedex list ROM cache was not restored")
assert(#marks == 1 and marks[1][1] == 8 and marks[1][2] == 8
  and marks[1][3] == 56 and marks[1][4] == 56,
  "Pokedex list replacement was not marked true-color")

interfaceMode = "off"
ListMenu.drawGen2Dex(menu)
assert(menu.drawn == rom, "Pokedex list did not restore its ROM preview")

print("interface Pokedex list playback regression: ok")
