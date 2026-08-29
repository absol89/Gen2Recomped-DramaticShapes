local stored = {}
local V = {
  require = function(name)
    assert(name == "ModSetting")
    return { new = function(key, label, values, labels, defaultIndex)
      local setting = { key = key, label = label, values = values,
                        labels = labels, index = defaultIndex or 1 }
      function setting:get() return stored[key] or self.values[self.index] end
      function setting:setIndex(index) self.index = index end
      return setting
    end }
  end,
  data = function() return {} end,
  mod = { assets = { path = function(_, rel) return "RESOLVED/" .. rel end } },
}
local BattleArt = assert(loadfile("lib/BattleArt.lua"))(V)
local PNG = "RESOLVED/assets/battle/back-static/player.png"
local GEN4 = "RESOLVED/assets/battle/back-static/gen4player.png"

stored.battleArt = "animated"
stored.playerArtSet = "png"       -- Kris's static default must not win here.
stored.playerAnimatedSet = "gen4"
assert(BattleArt.playerBackPathForOptions() == nil,
  "inactive Kris PLAYER ART masked the selected animation atlas")
stored.playerAnimatedSet = "png"
assert(BattleArt.playerBackPathForOptions() == PNG,
  "ANIMATED mode did not honor PLAYER ANIM PNG")
stored.playerAnimatedSet = "rom"
assert(BattleArt.playerBackPathForOptions() == nil,
  "ANIMATED ROM did not restore the engine player picture")

stored.battleArt = "static"
stored.playerArtSet = "png"
stored.playerAnimatedSet = "gen4"
assert(BattleArt.playerBackPathForOptions() == PNG,
  "STATIC mode did not honor PLAYER ART PNG")
stored.playerArtSet = "gen4"
stored.playerAnimatedSet = "png"
assert(BattleArt.playerBackPathForOptions() == GEN4,
  "STATIC mode did not map named PLAYER ART to its back-static PNG")
stored.playerArtSet = "rom"
assert(BattleArt.playerBackPathForOptions() == nil,
  "STATIC PLAYER ART: ROM did not restore the engine player picture")

print("player back path regression: ok")
