-- Real selectors and trainer managers, with image decoding replaced by source
-- labels. Every selection starts a fresh Gen 2 battle, as the options UI does.
local modules, stored = {}, {}
local V = { mod = {
  options = { get = function(_, key) return stored[key] end },
  assets = { path = function(_, path) return path end },
} }
function V.data(name)
  if name == "animated_player_trainers" then
    return assert(loadfile("data/animated_player_trainers.lua"))()
  end
  return {}
end
function V.require(name)
  if not modules[name] then modules[name] = assert(loadfile("lib/" .. name .. ".lua"))(V) end
  return modules[name]
end
love = { image = { newImageData = function(source)
  if type(source) == "string" then
    return { source = source, getDimensions = function() return 320, 64 end }
  end
  return { paste = function(self, sheet, dx, dy, x)
    self.source, self.cell = sheet.source, x
  end }
end } }
local Art = V.require("BattleArt")
Art.prepareData = function(data) return { source = data.source, cell = data.cell } end
Art.shareFrameAnchor = function() end
local Anim = V.require("AnimatedBattleArt")
local function choose(setting, value) setting:sync(value) end
local function battle()
  return { showPlayerTrainer = true, playerBackImage = { source = "engine" },
           playerBackTrueColor = false }
end
for _, staged in ipairs({ false, true }) do
  local function tick(b)
    if staged then
      Anim.update({}, 1 / 60, b)
      -- The staged consumer reapplies static art before capturing the card.
      Art.applyTrainers(b)
    else Anim.updateTrainer(b) end
  end
  for _, mode in ipairs({ "animated", "static" }) do
    choose(Art.setting, mode)
    -- The inactive row deliberately disagrees with the selected row.
    for _, generation in ipairs({ "gen5", "gen1", "gen2", "gen3", "gen4" }) do
      choose(Art.playerArtSetting, mode == "static" and generation or "gen5")
      choose(Art.playerAnimationSetting, mode == "animated" and generation or "gen5")
      local b = battle()
      tick(b)
      local folder = mode == "animated" and "back-animated" or "back-static"
      assert(b.playerBackImage.source == "assets/battle/" .. folder .. "/" .. generation .. "player.png",
        mode .. " did not select " .. generation)
      assert(b.playerBackTrueColor == true)
      Anim.finish({}, b)
      assert(Anim.playerTrainerFrame(b) == nil)
    end
  end
end
choose(Art.setting, "animated")
choose(Art.playerAnimationSetting, "png")
local png = battle()
local original = png.playerBackImage
Anim.updateTrainer(png)
assert(png.playerBackImage.source == "assets/battle/back-static/player.png")
assert(Anim.hasPlayerTrainerFrame(png), "Gen 2 PNG was not managed on its real image field")
Anim.finish({}, png)
assert(png.playerBackImage == original and png.playerBackTrueColor == false)

-- Cleanup must address the separate trainer state, not the species facade.
choose(Art.playerAnimationSetting, "gen5")
local old = battle()
Anim.update({}, 1 / 60, old)
choose(Art.setting, "static")
Anim.update({}, 1 / 60, old)
assert(Anim.playerTrainerFrame(old) == nil, "separate trainer state survived cleanup")

choose(Art.setting, "rom")
choose(Art.playerArtSetting, "gen5")
assert(Art.playerBackPathForOptions() == nil, "ROM mode leaked a static selection")
local rom = battle()
Anim.updateTrainer(rom)
assert(rom.playerBackImage.source == "engine")
print("player trainer selection across fresh flat/staged battles: ok")

-- Exercise the actual no-arena tick, not just the trainer helper directly.
local top = battle()
top.drawPic, top.drawSceneBody = function() end, function() end
local worldV = {
  game = function() return { stack = { top = function() return top end } } end,
  require = function(name)
    if name == "AnimatedBattleArt" then return Anim end
    if name == "BattleArt" then return Art end
    if name == "ModSetting" then return V.require(name) end
    return {}
  end,
}
local World = assert(loadfile("lib/OverworldBattle.lua"))(worldV)
choose(Art.setting, "animated")
choose(Art.playerAnimationSetting, "gen2")
World.update(1 / 60)
assert(top.playerBackImage.source == "assets/battle/back-animated/gen2player.png",
  "ordinary battle tick never applied PLAYER ANIM")
choose(Art.setting, "static")
choose(Art.playerArtSetting, "gen3")
top = battle()
top.drawPic, top.drawSceneBody = function() end, function() end
World.update(1 / 60)
assert(top.playerBackImage.source == "assets/battle/back-static/gen3player.png",
  "next ordinary battle did not apply PLAYER ART")
print("ordinary battle tick dispatch: ok")
