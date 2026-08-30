local calls = { arena = 0, paper = 0, clear = 0, pic = 0, wide = 0,
                objects = 0 }

local nativeRectangle
local graphics = { color = { 1, 1, 1, 1 } }
function graphics.setColor(r, g, b, a) graphics.color = { r, g, b, a } end
function graphics.getColor() return unpack(graphics.color) end
function graphics.draw() calls.arena = calls.arena + 1 end
function graphics.rectangle() calls.paper = calls.paper + 1 end
function graphics.push() end
function graphics.pop() end
function graphics.translate() end
function graphics.scale() end
nativeRectangle = graphics.rectangle
_G.love = _G.love or {}
_G.love.graphics = graphics

local Chrome = {
  clear = function() calls.clear = calls.clear + 1 end,
}
package.preload["src.ui.gen2.Chrome"] = function() return Chrome end
package.preload["src.render.Font"] = function()
  return { drawCode = function() end }
end

local BattleState = {
  pic = function() return "native-image", false, "native-path" end,
  drawPic = function() calls.pic = calls.pic + 1 end,
  drawSceneBody = function() end,
  drawScene = function() end,
  drawHud = function() end,
}
function BattleState:drawWidescreen(w, h)
  if self.fail then error("native failure") end
  graphics.setColor(1, 1, 1, 1)
  graphics.rectangle("fill", 0, 0, w, h)
  graphics.setColor(1, 1, 1, 0.85)
  graphics.rectangle("fill", 0, 0, 160, 144)
  Chrome.clear()
  self:drawPic()
  return "native-result"
end
package.preload["src.battle.BattleState"] = function() return BattleState end
package.preload["mods.STADIUM2_IMPORTER.lib.battle_hud"] = function()
  return {
    layer = function(draw, options)
      assert(options and options.preservePaper==true,
        "Battle Art textbox paper was removed before HALF styling")
      assert(options.crystalMovePane==true,
        "Gen 2 move TYPE/PP pane was not retained by the wide capture")
      draw(); return "ui-layer"
    end,
    hudLayer = function(draw) draw(); return "hud-layer" end,
    modalLayer = function(draw, options)
      assert(options and options.preservePaper==true)
      draw(); return "aux-layer"
    end,
    composite = function(_, _, layer, hudLayer, auxiliaryLayer, options)
      assert(layer=="ui-layer" and hudLayer=="hud-layer")
      assert(auxiliaryLayer=="aux-layer",
        "wide auxiliary windows did not receive a HUD-free capture")
      assert(options and options.decorate==false,
        "Battle Art wide UI unexpectedly enabled Stadium decoration")
      assert(options.bottomToScreen==true,
        "Battle Art lower UI was not anchored for landscape")
      assert(options.edgeInset==2,
        "Battle Art wide UI lost its two-pixel logical edge inset")
      calls.wide=calls.wide+1
      return "wide-result"
    end,
  }
end

local BattleArt = {
  isExternal = function(value) return value == "external-image" end,
}
local BattlePics = {
  shade0Transparent = function(image) return image end,
}
local UiBackplates = {
  arenaWhite = function() return false end,
  hudUsesColor = function() return false end,
  hudUsesColorShadow = function() return false end,
  textboxMode = function() return "OFF" end,
  textboxFillStyle = function() return nil end,
  arenaStadium2 = function() return true end,
}
local stadiumScene = nil
local V = {
  mod = {
    find = function(id)
      if id ~= "STADIUM2_IMPORTER" then return nil end
      return { exports = {
        getActiveBattleScene = function() return stadiumScene end,
      } }
    end,
  },
  require = function(name)
    if name == "BattleArt" then return BattleArt end
    if name == "BattlePics" then return BattlePics end
    if name == "UiBackplates" then return UiBackplates end
    error("unexpected module " .. tostring(name))
  end,
}

local Adapter = assert(loadfile("lib/Gen2BattleAdapter.lua"))(V)
local shot = nil
local nativeResolver = nil
local OverworldBattle = {
  shot = function() return shot end,
  setGen2PicResolver = function(value) nativeResolver = value end,
}

assert(Adapter.install(OverworldBattle), "Gen 2 battle adapter did not install")
assert(nativeResolver ~= nil, "native Gen 2 picture resolver was not retained")

local state = setmetatable({}, { __index = BattleState })
assert(state:drawWidescreen(320, 288) == "native-result")
assert(calls.arena == 0 and calls.paper == 2 and calls.clear == 1
  and calls.pic == 1, "unstaged battle no longer falls through unchanged")

shot = { canvas = { getDimensions = function() return 320, 288 end } }
assert(state:drawWidescreen(320, 288) == "native-result")
assert(calls.arena == 1, "staged arena was not drawn")
assert(calls.paper == 2 and calls.clear == 1 and calls.pic == 1,
  "opaque paper, screen flash, or native pictures survived staged composition")

stadiumScene = { battle = state.battle, screen = state,
  uiAnchors = { player = {26,96}, enemy = {124,56} },
  hudBox = { lx = 0, ly = 0, scale = 2 },
  presentCanvas = { getDimensions = function() return 320, 288 end } }
state.phase = "moves"
state.anim = {}
state.animView = { drawObjects = function() calls.objects = calls.objects + 1 end }
assert(state:drawWidescreen(320, 288) == "wide-result")
assert(calls.arena == 2,
  "active Stadium 2 field was not used as Battle Art's arena pass")
assert(calls.paper == 2 and calls.clear == 1 and calls.pic == 1
    and calls.wide == 1 and calls.objects == 1,
  "Battle Art did not retain complete UI ownership over the Stadium field")
assert(state.stadium2ImporterBattleArtUiPass == nil,
  "temporary Stadium UI bypass leaked after composition")
stadiumScene = nil
state.phase = nil
state.anim = nil

local image, trueColor, path = state:pic({ sprite = "external-image" }, false)
assert(image == "external-image" and trueColor == true and path == "native-path",
  "external Battle Art did not retain the native Gen 2 asset identity")

state.fail = true
local ok = pcall(state.drawWidescreen, state, 320, 288)
assert(not ok, "native compositor failure was swallowed")
assert(graphics.rectangle == nativeRectangle and Chrome.clear ~= nil
  and rawget(state, "drawPic") == nil,
  "temporary Gen 2 drawing overrides leaked after an error")

print("Gen 2 battle adapter regression: ok")
