-- Exercise the real LÖVE shader/canvas path. Source-string tests cannot tell
-- whether the shadow shader compiled or whether its offset survived blending.
local BattleHud = assert(loadfile("lib/BattleHud.lua"))({})
local g = love.graphics

local function render(preserveOriginal, inkOnly)
  local out = g.newCanvas(16, 16)
  out:setFilter("nearest", "nearest")
  g.setCanvas(out)
  g.clear(0, 0, 0, 0)
  g.setBlendMode("alpha")
  g.setColor(1, 1, 1, 1)
  BattleHud.flipGlyphs(16, 16, function()
    g.setColor(0, 0, 0, 1)
    g.rectangle("fill", 2, 2, 4, 4)
  end, preserveOriginal, true, inkOnly)
  g.setCanvas()
  return out:newImageData()
end

local inverted = render(false)
local r, _, _, a = inverted:getPixel(2, 2)
assert(r > 0.9 and a > 0.9, "inverted HUD ink was not made white")
r, _, _, a = inverted:getPixel(6, 6)
assert(r < 0.1 and a > 0.5,
  "inverted HUD/OFF textbox black shadow did not survive at +1,+1")

local textbox = render(false, true)
r, _, _, a = textbox:getPixel(2, 2)
assert(r > 0.9 and a > 0.9, "OFF/HALF textbox ink-only pass lost its ink")
r, _, _, a = textbox:getPixel(6, 6)
assert(r < 0.1 and a > 0.5,
  "OFF/HALF textbox ink-only pass lost its black shadow")

local color = render(true)
r, _, _, a = color:getPixel(2, 2)
assert(r < 0.1 and a > 0.9, "COLOR HUD did not retain its black ink")
r, _, _, a = color:getPixel(6, 6)
assert(a > 0.2 and r / a > 0.9,
  "COLOR HUD white shadow did not survive at +1,+1")

print("battle UI pixel shadows: ok")
