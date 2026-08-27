-- Regression test for the gen2 player back-pic override.
--
-- History: BATTLE ART's player-pic override originally lived only inside the
-- staged voxel renderer (OverworldBattle.sideTexture / BattleArt.applyTrainers).
-- A normal gen2 2D battle (Crystal, Silver, boy or girl) resolves its player
-- back through the engine's Sprites.playerPic -> "player.sprite" runtime hook,
-- which the mod did not wrap, so the replacement never fired for ordinary
-- gen2 battles. The fix wraps "player.sprite" and, for the in-battle back
-- slot, returns assets/battle/back-static/player.png when EITHER player row is
-- PNG. This test pins the option->path decision (playerBackPathForOptions),
-- which the wrap and the staged renderer both consult, so a future port keeps
-- the same gender-neutral, master-mode-independent contract.
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

-- PLAYER ART: PNG wins, independent of PLAYER ANIM.
stored.playerArtSet = "png"
assert(BattleArt.playerBackPathForOptions() == PNG_PATH,
  "PLAYER ART: PNG did not resolve to player.png")
stored.playerArtSet = nil

-- PLAYER ANIM: PNG wins, independent of PLAYER ART.
stored.playerAnimatedSet = "png"
assert(BattleArt.playerBackPathForOptions() == PNG_PATH,
  "PLAYER ANIM: PNG did not resolve to player.png")
stored.playerAnimatedSet = nil

-- A named generation (gen2) on either row -> engine back, not player.png.
stored.playerArtSet = "gen2"
assert(BattleArt.playerBackPathForOptions() == nil,
  "gen2 player art should not be rewritten to player.png")
stored.playerArtSet = nil

-- ROM on either row restores the engine portrait.
stored.playerAnimatedSet = "rom"
assert(BattleArt.playerBackPathForOptions() == nil,
  "ROM player anim should restore the engine portrait")
stored.playerAnimatedSet = nil

-- Either row PNG -> PNG, even if the other is a generation (boy+png mix).
stored.playerArtSet = "gen2"
stored.playerAnimatedSet = "png"
assert(BattleArt.playerBackPathForOptions() == PNG_PATH,
  "PNG on one row must win even when the other is a generation")
stored.playerArtSet = nil
stored.playerAnimatedSet = nil

print("player-back path regression: ok")
