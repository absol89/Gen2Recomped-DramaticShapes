local settings = {}
local V = {
  require = function(name)
    assert(name == "ModSetting")
    return {
      new = function(key, label, values, labels, defaultIndex)
        local setting = { key = key, label = label, values = values,
                          labels = labels, index = defaultIndex or 1 }
        function setting:get() return self.values[self.index] end
        function setting:setIndex(index) self.index = index end
        function setting:indexForValue(value)
          for i, candidate in ipairs(self.values) do
            if candidate == value then return i end
          end
          return self.index
        end
        settings[key] = setting
        return setting
      end,
    }
  end,
  data = function() return {} end,
  mod = { id = "BATTLE_ART_VOXEL_GEN2" },
}

local BattleArt = assert(loadfile("lib/BattleArt.lua"))(V)
local function game(gender, stored)
  return {
    save = {
      player = { gender = gender },
      options = { modOptions = {
        BATTLE_ART_VOXEL_GEN2 = stored or {},
      } },
    },
  }
end

BattleArt.seedPlayerDefaults(game("female"))
assert(settings.playerArtSet:get() == "png"
  and settings.playerAnimatedSet:get() == "png",
  "Crystal girl did not default both player rows to PNG")

settings.playerArtSet.index, settings.playerAnimatedSet.index = 3, 3
BattleArt.seedPlayerDefaults(game("male"))
assert(settings.playerArtSet:get() == "gen2"
  and settings.playerAnimatedSet:get() == "gen2",
  "Silver/Crystal boy did not default both player rows to Gen 2")

settings.playerArtSet.index, settings.playerAnimatedSet.index = 5, 5
BattleArt.seedPlayerDefaults(game("female", {
  playerArtSet = "gen4", playerAnimatedSet = "gen4",
}))
assert(settings.playerArtSet:get() == "gen4"
  and settings.playerAnimatedSet:get() == "gen4",
  "explicit player selections were overwritten by gender defaults")

settings.playerArtSet.index, settings.playerAnimatedSet.index = 3, 3
BattleArt.seedPlayerDefaults({ save = {
  player = {}, options = { modOptions = { BATTLE_ART_VOXEL_GEN2 = {} } },
} })
assert(settings.playerArtSet:get() == "gen2"
  and settings.playerAnimatedSet:get() == "gen2",
  "unknown pre-selection gender was prematurely persisted as another default")

print("player gender defaults regression: ok")
