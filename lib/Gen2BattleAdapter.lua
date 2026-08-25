-- Gold/Silver battle presentation for Gen1Recomp.
--
-- Gen 2 owns a window-sized battle surface.  Keep its state, HUD, menus and
-- animation layers authoritative, but replace the opaque paper background and
-- native monster pictures while a staged arena is ready.

local V = ...
local BattleArt = V.require("BattleArt")

local Adapter = {}
local MARKER = "battleArtGen2WidescreenAdapter"
local NATIVE_PIC = "battleArtGen2NativePic"

local unpackValues = table.unpack or unpack

local function pack(...)
  return { n = select("#", ...), ... }
end

local function isWhite(r, g, b, a)
  return r >= 0.999 and g >= 0.999 and b >= 0.999 and a >= 0.999
end

local function isScreenFlash(mode, x, y, w, h, r, g, b, a)
  return mode == "fill" and x == 0 and y == 0 and w == 160 and h == 144
    and r >= 0.999 and g >= 0.999 and b >= 0.999 and a > 0 and a < 1
end

local function drawArena(canvas, width, height)
  local cw, ch = canvas:getDimensions()
  if not (cw and ch and cw > 0 and ch > 0) then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, 0, 0, 0, width / cw, height / ch)
  return true
end

local function withoutOpaqueBattlePaper(state, width, height, body)
  local g = love.graphics
  local Chrome = require("src.ui.gen2.Chrome")
  local nativeClear = Chrome.clear
  local nativeRectangle = g.rectangle
  local instancePic = rawget(state, "drawPic")

  Chrome.clear = function() end
  state.drawPic = function() end
  g.rectangle = function(mode, x, y, w, h, ...)
    if mode == "fill" and x == 0 and y == 0 and w == width and h == height then
      local r, gr, b, a = g.getColor()
      if isWhite(r, gr, b, a) then return end
    end
    local r, gr, b, a = g.getColor()
    if isScreenFlash(mode, x, y, w, h, r, gr, b, a) then return end
    return nativeRectangle(mode, x, y, w, h, ...)
  end

  local results = pack(pcall(body))
  g.rectangle = nativeRectangle
  state.drawPic = instancePic
  Chrome.clear = nativeClear

  if not results[1] then error(results[2], 0) end
  return unpackValues(results, 2, results.n)
end

function Adapter.install(OverworldBattle)
  local BattleState = require("src.battle.BattleState")
  if BattleState[MARKER] then return true end
  if type(BattleState.drawWidescreen) ~= "function"
      or type(BattleState.drawSceneBody) ~= "function"
      or type(BattleState.drawPic) ~= "function" then
    return false
  end

  local nativePic = BattleState.pic
  local nativeWidescreen = BattleState.drawWidescreen
  BattleState[NATIVE_PIC] = nativePic
  OverworldBattle.setGen2PicResolver(nativePic)

  -- Gen 2 resolves art from the species definition at draw time.  Battle Art
  -- stores an already-selected external image on the transient battler view.
  function BattleState:pic(mon, back)
    local image, trueColor, path = nativePic(self, mon, back)
    if mon and BattleArt.isExternal(mon.sprite) then
      return mon.sprite, true, path
    end
    return image, trueColor, path
  end

  function BattleState:drawWidescreen(width, height)
    local shot = OverworldBattle.shot()
    if not (shot and shot.canvas and love and love.graphics) then
      return nativeWidescreen(self, width, height)
    end

    local drawn = drawArena(shot.canvas, width, height)
    if not drawn then return nativeWidescreen(self, width, height) end
    return withoutOpaqueBattlePaper(self, width, height, function()
      return nativeWidescreen(self, width, height)
    end)
  end

  BattleState[MARKER] = true
  return true
end

return Adapter
