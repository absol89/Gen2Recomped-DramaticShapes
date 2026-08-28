local frames = {}
local selected = "bulma_front"
local offset = 0
local function setting(value) return { get = function() return value end } end
local BattleArt = {
  setting = setting("animated"),
  frontAnimationSetting = setting("gen2"),
  backAnimationSetting = setting("gen2"),
  playerAnimationSetting = { get = function() return selected end },
  displayMode = function() return "color" end,
  releaseSpeciesOverrides = function() end,
  applyTrainers = function() end,
  playerSide = function() return "back" end,
  ownsSpeciesArt = function() return false end,
  prepareData = function()
    local frame = { index = #frames + 1 }
    frames[#frames + 1] = frame
    return frame
  end,
  shareFrameAnchor = function() end,
}
love = { image = { newImageData = function(width)
  if type(width) == "string" then
    return { getDimensions = function() return 500, 100 end }
  end
  return { paste = function() end }
end } }
local V = {
  require = function(name) assert(name == "BattleArt"); return BattleArt end,
  data = function(name)
    if name == "animated_player_trainers" then
      return { bulma_front = {
        image = "assets/battle/back-animated/bulmafrontplayer.png",
        autoColumns = 5,
      } }
    end
    return {}
  end,
  mod = { assets = { path = function(_, path) return path end } },
}
local AnimatedBattleArt = assert(loadfile("lib/AnimatedBattleArt.lua"))(V)
local rom = {}
local battle = {
  showPlayerBack = true, demo = false, playerBackPic = rom,
  picOffset = function(_, side) assert(side == "back"); return offset end,
}

AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == frames[1],
  "selected player atlas did not replace the ROM intro immediately")
for _ = 1, 60 do AnimatedBattleArt.update(battle, 1 / 60) end
assert(battle.playerBackPic == frames[1],
  "player atlas advanced before the intro textbox was dismissed")
offset = -1
AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == frames[2],
  "player atlas did not animate when its leftward exit began")
offset = -72
AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == frames[5],
  "player atlas did not reach its final exit pose")

print("player trainer intro animation regression: ok")
