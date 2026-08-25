local calls = { arena = 0, paper = 0, clear = 0, pic = 0 }

local nativeRectangle
local graphics = { color = { 1, 1, 1, 1 } }
function graphics.setColor(r, g, b, a) graphics.color = { r, g, b, a } end
function graphics.getColor() return unpack(graphics.color) end
function graphics.draw() calls.arena = calls.arena + 1 end
function graphics.rectangle() calls.paper = calls.paper + 1 end
nativeRectangle = graphics.rectangle
_G.love = _G.love or {}
_G.love.graphics = graphics

local Chrome = {
  clear = function() calls.clear = calls.clear + 1 end,
}
package.preload["src.ui.gen2.Chrome"] = function() return Chrome end

local BattleState = {
  pic = function() return "native-image", false, "native-path" end,
  drawPic = function() calls.pic = calls.pic + 1 end,
  drawSceneBody = function() end,
}
function BattleState:drawWidescreen(w, h)
  if self.fail then error("native failure") end
  graphics.setColor(1, 1, 1, 1)
  graphics.rectangle("fill", 0, 0, w, h)
  Chrome.clear()
  self:drawPic()
  return "native-result"
end
package.preload["src.battle.BattleState"] = function() return BattleState end

local BattleArt = {
  isExternal = function(value) return value == "external-image" end,
}
local V = {
  require = function(name)
    assert(name == "BattleArt")
    return BattleArt
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
assert(calls.arena == 0 and calls.paper == 1 and calls.clear == 1
  and calls.pic == 1, "unstaged battle no longer falls through unchanged")

shot = { canvas = { getDimensions = function() return 320, 288 end } }
assert(state:drawWidescreen(320, 288) == "native-result")
assert(calls.arena == 1, "staged arena was not drawn")
assert(calls.paper == 1 and calls.clear == 1 and calls.pic == 1,
  "opaque paper or native pictures survived staged composition")

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
