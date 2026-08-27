-- The selected PLAYER ANIM atlas owns Crystal's trainer back for either
-- gender. Its first pose is stationary through the opening textbox; playback
-- begins only when SlideTrainerPicOffScreen makes the back offset negative.

local frames = {}
local selected = "gen4"
local offset = 0

local function setting(value)
  return { get = function() return value end }
end

local BattleArt = {
  setting = setting("animated"),
  frontAnimationSetting = setting("gen2"),
  backAnimationSetting = setting("gen2"),
  playerAnimationSetting = { get = function() return selected end },
  displayMode = function() return "color" end,
  ownsSpeciesArt = function() return false end,
  releaseSpeciesOverrides = function() end,
  applyTrainers = function() end,
  playerSide = function() return "back" end,
  prepareData = function()
    local frame = { index = #frames + 1 }
    frames[#frames + 1] = frame
    return frame
  end,
  shareFrameAnchor = function() end,
}

love = {
  image = {
    newImageData = function(width)
      if type(width) == "string" then
        return { getDimensions = function() return 500, 100 end }
      end
      return { paste = function() end }
    end,
  },
}

local definitions = {
  gen4 = { image = "assets/battle/back-animated/gen4player.png",
           autoColumns = 5 },
}
local V = {
  require = function(name)
    assert(name == "BattleArt")
    return BattleArt
  end,
  data = function(name)
    if name == "animated_player_trainers" then return definitions end
    return {}
  end,
  mod = { assets = { path = function(_, path) return path end } },
}

local AnimatedBattleArt = assert(loadfile("lib/AnimatedBattleArt.lua"))(V)
local rom = {}
local battle = {
  showPlayerBack = true,
  demo = false,
  playerBackPic = rom,
  picOffset = function(_, side)
    assert(side == "back")
    return offset
  end,
}

AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == frames[1],
  "selected PLAYER ANIM atlas was absent during the stationary intro")

-- Time alone must not start the walk cycle while the textbox remains open.
for _ = 1, 60 do AnimatedBattleArt.update(battle, 1 / 60) end
assert(battle.playerBackPic == frames[1],
  "player atlas animated before the opening textbox advanced")

offset = -1
AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == frames[2],
  "player atlas did not start when the trainer began sliding left")

offset = -72
AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == frames[5],
  "player atlas did not reach its final authored slide pose")
assert(AnimatedBattleArt.hasPlayerTrainerFrame(battle),
  "active player atlas frame was not reported as renderer-owned")

-- Gender is deliberately not an input: changing only the selected atlas must
-- replace the definition for any Crystal player choice.
selected = "rom"
AnimatedBattleArt.update(battle, 1 / 60)
assert(battle.playerBackPic == rom,
  "ROM selection did not restore the gender-owned engine portrait")

print("player trainer intro animation regression: ok")

-- Gen2Recomp uses different state fields and has no picOffset("back"). Its
-- send-out drops showPlayerTrainer immediately, so the mod retains the atlas
-- for the equivalent 18-frame / 72-pixel exit without consulting gender.
selected = "gen4"
local krisRom = {}
local crystal = {
  showPlayerTrainer = true,
  playerBackImage = krisRom,
  playerBackTrueColor = false,
}
AnimatedBattleArt.update({}, 1 / 60, crystal)
assert(crystal.playerBackImage == frames[1],
  "Crystal intro retained Kris ROM instead of the selected atlas frame")
assert(crystal.playerBackTrueColor == true,
  "Crystal atlas was not marked true-color")

for _ = 1, 60 do AnimatedBattleArt.update({}, 1 / 60, crystal) end
assert(crystal.playerBackImage == frames[1],
  "Crystal player atlas advanced while its intro textbox was still open")

crystal.showPlayerTrainer = false
AnimatedBattleArt.update({}, 1 / 60, crystal)
local leaving, leaveOffset = AnimatedBattleArt.playerTrainerFrame(crystal)
assert(leaving == frames[2] and leaveOffset == -4,
  "Crystal atlas did not begin its Gen1-matched left exit at send-out")
for _ = 2, 17 do AnimatedBattleArt.update({}, 1 / 60, crystal) end
leaving, leaveOffset = AnimatedBattleArt.playerTrainerFrame(crystal)
assert(leaving == frames[5] and leaveOffset == -68,
  "Crystal atlas did not reach its last visible exit pose")
AnimatedBattleArt.update({}, 1 / 60, crystal)
assert(AnimatedBattleArt.playerTrainerFrame(crystal) == nil,
  "Crystal trainer frame remained after completing its exit")
assert(crystal.playerBackImage == krisRom,
  "Crystal trainer animation did not restore the engine-owned image")

print("Crystal player trainer intro animation regression: ok")
