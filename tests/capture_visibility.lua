local Visibility = assert(loadfile("lib/BattleVisibility.lua"))()
local enemy = { sprite = {} }
local battle = { enemy = enemy, fxHidden = function() return false end }

assert(Visibility.sideVisible(battle, "enemy"),
  "ordinary enemy lost its billboard")
battle.picFx = { [enemy] = { hidden = true } }
assert(not Visibility.sideVisible(battle, "enemy"),
  "Gen 2's return-to-ball effect kept the enemy billboard")
battle.picFx[enemy].hidden = nil
battle.lockedBall = {}
assert(not Visibility.sideVisible(battle, "enemy"),
  "successful capture reappeared beside its resting ball")
battle.lockedBall = nil
assert(Visibility.sideVisible(battle, "enemy"),
  "breakout did not restore the enemy billboard")

battle.introBalls = true
assert(not Visibility.animationLayerVisible(battle),
  "the intro's engine animation layer can duplicate the ROM monster")
battle.introBalls = nil
assert(Visibility.animationLayerVisible(battle),
  "battle animations stayed hidden after the intro message")

print("capture visibility regression: ok")
