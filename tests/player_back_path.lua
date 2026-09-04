-- Regression test for the gen2 player back-pic override.
--
-- History: BATTLE ART's player-pic override originally lived only inside the
-- staged voxel renderer (OverworldBattle.sideTexture / BattleArt.applyTrainers).
-- A normal gen2 2D battle (Crystal, Silver, boy or girl) resolves its player
-- back through the engine's Sprites.playerPic -> "player.sprite" runtime hook,
-- which the mod did not wrap, so the replacement never fired for ordinary
-- gen2 battles. The fix wraps "player.sprite" and, for the in-battle back
-- slot, returns assets/battle/back-static/player.png when the active mode's
-- player row is PNG. This test pins that mode-specific ownership so Kris's
-- default PLAYER ART cannot mask a selected PLAYER ANIM atlas.
local stored = {}
local V = {
  require = function(name)
    if name == "ModSetting" then
      return {
        new = function(key, label, values, labels, defaultIndex)
          local setting = {
            key = key, label = label,
            values = values, labels = labels,
            index = defaultIndex or 1,
          }
          function setting:get()
            local v = stored[key]
            if v ~= nil then return v end
            return self.values[self.index]
          end
          function setting:setIndex(index) self.index = index end
          return setting
        end,
      }
    end
    error("unexpected require: " .. name)
  end,
  data = function() return {} end,
  mod = {
    assets = {
      -- Echo a resolved absolute path so the test can assert the target.
      path = function(_, rel) return "RESOLVED/" .. rel end,
    },
  },
}

local BattleArt = assert(loadfile("lib/BattleArt.lua"))(V)

local PNG_PATH = "RESOLVED/assets/battle/back-static/player.png"

-- Fresh install: both player rows default to gen2 -> engine-owned back.
assert(BattleArt.playerBackPathForOptions() == nil,
  "fresh install should leave the engine player back alone (got a path)")

-- STATIC reads PLAYER ART, independent of PLAYER ANIM.
stored.battleArt = "static"
stored.playerArtSet = "png"
assert(BattleArt.playerBackPathForOptions() == PNG_PATH,
  "PLAYER ART: PNG did not resolve to player.png")
stored.playerArtSet = nil

-- ANIMATED reads PLAYER ANIM, independent of PLAYER ART.
stored.battleArt = "animated"
stored.playerArtSet = "png"
stored.playerAnimatedSet = "gen4"
assert(BattleArt.playerBackPathForOptions() == nil,
  "Kris's default PLAYER ART suppressed the selected animation atlas")
stored.playerAnimatedSet = "png"
assert(BattleArt.playerBackPathForOptions() == PNG_PATH,
  "PLAYER ANIM: PNG did not resolve to player.png")
stored.playerArtSet = nil
stored.playerAnimatedSet = nil

-- STATIC resolves the selected named file, not the generic PNG or ROM.
stored.playerArtSet = "gen2"
stored.battleArt = "static"
assert(BattleArt.playerBackPathForOptions()
  == "RESOLVED/assets/battle/back-static/gen2player.png",
  "STATIC must resolve the selected gen2 player art")
stored.playerArtSet = nil

-- ROM on either row restores the engine portrait.
stored.playerAnimatedSet = "rom"
stored.battleArt = "animated"
assert(BattleArt.playerBackPathForOptions() == nil,
  "ROM player anim should restore the engine portrait")
stored.playerAnimatedSet = nil

-- Only the active row owns the path.
stored.playerArtSet = "gen2"
stored.playerAnimatedSet = "png"
stored.battleArt = "animated"
assert(BattleArt.playerBackPathForOptions() == PNG_PATH,
  "ANIMATED did not honor PLAYER ANIM PNG")
stored.battleArt = "static"
assert(BattleArt.playerBackPathForOptions()
  == "RESOLVED/assets/battle/back-static/gen2player.png",
  "inactive PLAYER ANIM PNG leaked into STATIC mode")
stored.playerArtSet = nil
stored.playerAnimatedSet = nil
stored.battleArt = nil

print("player-back path regression: ok")
