-- Gold/Silver battle presentation for Gen1Recomp.
--
-- Gen 2 owns a window-sized battle surface.  Keep its state, HUD, menus and
-- animation layers authoritative, but replace the opaque paper background and
-- native monster pictures while a staged arena is ready.

local V = ...
local BattleArt = V.require("BattleArt")
local BattlePics = V.require("BattlePics")
local UiBackplates = V.require("UiBackplates")
local Font = require("src.render.Font")

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

local function copyPalette(palette)
  local copy = {}
  for index, color in ipairs(palette or {}) do
    if type(color) == "table" then
      copy[index] = { color[1], color[2], color[3] }
    else
      copy[index] = color
    end
  end
  return copy
end

local function installChromeUiStyle(Chrome, textboxModeAt)
  local native = {
    paletteGlyphs = Chrome.paletteGlyphs,
    paletteBox = Chrome.paletteBox,
    print = Chrome.print,
    printRight = Chrome.printRight,
    cursorThrough = Chrome.cursorThrough,
  }

  -- The Gen2 Chrome renderer normally owns a black-on-white palette.  That
  -- bypasses the Gen1 HUD compositor, so apply the same HUD COLOR choice to
  -- Chrome's glyphs directly while this staged battle is being drawn.
  -- INVERTED is white ink with a dark one-pixel shadow; COLOR is black ink
  -- with a bright shadow.  Arena WHITE already supplies a clean black-on-
  -- white presentation and intentionally keeps the shadow disabled.
  local shadowEnabled = not UiBackplates.arenaWhite()
  local colorHud = UiBackplates.hudUsesColor()
  local brightShadow = UiBackplates.hudUsesColorShadow()
  local textboxMode = UiBackplates.textboxMode()
  local ink = colorHud and { 0, 0, 0 } or { 255, 255, 255 }
  local shadow = brightShadow and { 255, 255, 255 } or { 0, 0, 0 }
  local BRIGHT_SHADOW_ALPHA = 0.50

  local function styledPalette(palette, color)
    local styled = copyPalette(palette or Chrome.DEFAULT_BOX_PALETTE)
    styled[4] = { color[1], color[2], color[3] }
    return styled
  end

  if not shadowEnabled then
    return function() end
  end

  -- Opaque textbox paper supplies its own contrast. Keep the HUD shadow on
  -- the upper battle information, but do not add it to WHITE or BLACK text
  -- inside Gen2's lower six-row message/menu area.
  local function textboxInkAt(x, y)
    local mode = textboxModeAt and textboxModeAt(x, y)
    if mode == "WHITE" then return { 0, 0, 0 }, mode end
    if mode == "BLACK" then return { 255, 255, 255 }, mode end
    if mode == "HALF" then return { 255, 255, 255 }, mode end
    return ink, mode
  end

  local function shadowInkAt(x, y)
    local mode = textboxModeAt and textboxModeAt(x, y)
    if mode == "HALF" then return { 0, 0, 0 } end
    return shadow
  end

  local function shadowOpacityAt(x, y)
    local mode = textboxModeAt and textboxModeAt(x, y)
    if brightShadow and mode ~= "HALF" then return BRIGHT_SHADOW_ALPHA end
    return 1
  end

  local function drawShadowWithOpacity(drawGlyph, finish, code, x, y, alpha)
    if alpha >= 1 then
      drawGlyph(code, x, y)
      finish()
      return
    end
    -- Chrome's palette glyph helper sets its own draw colour, including the
    -- alpha channel. Clamp it for this pass so COLOR's white shadow blends
    -- into the world instead of landing as an opaque white duplicate.
    local nativeSetColor = love.graphics.setColor
    love.graphics.setColor = function(r, g, b, a, ...)
      if type(r) == "table" then
        return nativeSetColor({ r[1], r[2], r[3], (r[4] or 1) * alpha },
          g, ...)
      end
      return nativeSetColor(r, g, b, (a or 1) * alpha, ...)
    end
    local results = pack(pcall(function()
      drawGlyph(code, x, y)
      finish()
    end))
    love.graphics.setColor = nativeSetColor
    if not results[1] then error(results[2], 0) end
  end

  local function shadowsAt(x, y)
    local _, mode = textboxInkAt(x, y)
    return mode ~= "WHITE" and mode ~= "BLACK"
  end

  Chrome.paletteGlyphs = function(palette, invert, raw)
    -- printThrough needs only palette colour 0 before it calls drawGlyph;
    -- choose the normal ink here, then select the opaque textbox ink for
    -- each positioned glyph below.
    local mainPal = native.paletteGlyphs(styledPalette(palette, ink),
      invert, raw)

    if mainPal then
      return mainPal, function(code, x, y)
        if shadowsAt(x, y) then
          -- Chrome's native draw closures cache their shader state. Give this
          -- glyph fresh shadow/main closures so one pass cannot leak its
          -- palette or plain black tint into later letters.
          local _, drawShadow, finishShadow =
            native.paletteGlyphs(styledPalette(palette, shadowInkAt(x, y)),
              invert, raw)
          drawShadowWithOpacity(drawShadow, finishShadow, code, x + 1, y + 1,
            shadowOpacityAt(x, y))
        end
        local mainInk = textboxInkAt(x, y)
        local _, drawMain, finishMain =
          native.paletteGlyphs(styledPalette(palette, mainInk), invert, raw)
        drawMain(code, x, y)
        finishMain()
      end, function() end
    end

    -- Driverless/fallback rendering has no GbcPalette shader, but returning a
    -- synthetic palette keeps Chrome.printThrough on this same path so the
    -- setting still works on a renderer without shader support.
    local fallback = styledPalette(palette, ink)
    return fallback, function(code, x, y)
      local old = { love.graphics.getColor() }
      if shadowsAt(x, y) then
        local shadowInk = shadowInkAt(x, y)
        love.graphics.setColor(shadowInk[1] / 255, shadowInk[2] / 255,
          shadowInk[3] / 255, shadowOpacityAt(x, y))
        Font.drawCode(code, x + 1, y + 1)
      end
      local mainInk = textboxInkAt(x, y)
      love.graphics.setColor(mainInk[1] / 255, mainInk[2] / 255,
        mainInk[3] / 255, 1)
      Font.drawCode(code, x, y)
      love.graphics.setColor(old[1], old[2], old[3], old[4])
    end, function() end
  end

  -- Box borders and cursors are also Chrome glyphs.  Style their ink so an
  -- inverted HUD does not leave black controls among otherwise white text.
  Chrome.paletteBox = function(tx, ty, tw, th, palette)
    local boxInk = ink
    if textboxMode == "WHITE" then
      boxInk = { 0, 0, 0 }
    elseif textboxMode == "BLACK" or textboxMode == "HALF" then
      boxInk = { 255, 255, 255 }
    end
    return native.paletteBox(tx, ty, tw, th, styledPalette(palette, boxInk))
  end

  Chrome.print = function(text, tx, ty)
    return Chrome.printThrough(text, tx, ty, Chrome.DEFAULT_BOX_PALETTE)
  end

  Chrome.printRight = function(text, txEnd, ty)
    return Chrome.printRightThrough(text, txEnd, ty,
      Chrome.DEFAULT_BOX_PALETTE)
  end

  Chrome.cursorThrough = function(tx, ty, palette, invert, hollow, raw)
    local pal, drawGlyph, finish = Chrome.paletteGlyphs(
      styledPalette(palette, ink), invert, raw)
    local paper = pal[1] or { 255, 255, 255 }
    love.graphics.setColor(paper[1] / 255, paper[2] / 255,
      paper[3] / 255, 1)
    love.graphics.rectangle("fill", tx * 8, ty * 8, 8, 8)
    drawGlyph(hollow and Chrome.CURSOR_HOLLOW or Chrome.CURSOR,
      tx * 8, ty * 8)
    finish()
  end

  return function()
    Chrome.paletteGlyphs = native.paletteGlyphs
    Chrome.paletteBox = native.paletteBox
    Chrome.print = native.print
    Chrome.printRight = native.printRight
    Chrome.cursorThrough = native.cursorThrough
  end
end

local function withoutOpaqueBattlePaper(state, width, height, body)
  local g = love.graphics
  local Chrome = require("src.ui.gen2.Chrome")
  local nativeClear = Chrome.clear
  local nativeRectangle = g.rectangle
  local instancePic = rawget(state, "drawPic")
  local hudImages = {}
  local textboxMode = UiBackplates.textboxMode()
  local textboxStyle = UiBackplates.textboxFillStyle()
  local styledBoxes = {}
  local drawingStyledBox = nil
  local halfFillRects = {}

  local function contains(box, x, y, w, h)
    return x >= box.x and y >= box.y
      and x + w <= box.x + box.w and y + h <= box.y + box.h
  end

  local function textboxModeAt(x, y)
    for _, box in ipairs(styledBoxes) do
      if x >= box.x and x < box.x + box.w
          and y >= box.y and y < box.y + box.h then
        return textboxMode
      end
    end
    return nil
  end

  -- Add only the portions of a new HALF panel which have not already been
  -- tinted. Nested Chrome boxes (the move list and its info panel) otherwise
  -- alpha-blend over each other and turn darker than the surrounding message
  -- box.
  local function uncovered(rect)
    local pieces = { rect }
    for _, cover in ipairs(halfFillRects) do
      local nextPieces = {}
      for _, piece in ipairs(pieces) do
        local left = math.max(piece.x, cover.x)
        local top = math.max(piece.y, cover.y)
        local right = math.min(piece.x + piece.w, cover.x + cover.w)
        local bottom = math.min(piece.y + piece.h, cover.y + cover.h)
        if left >= right or top >= bottom then
          nextPieces[#nextPieces + 1] = piece
        else
          if piece.y < top then
            nextPieces[#nextPieces + 1] = {
              x = piece.x, y = piece.y, w = piece.w, h = top - piece.y }
          end
          if bottom < piece.y + piece.h then
            nextPieces[#nextPieces + 1] = {
              x = piece.x, y = bottom, w = piece.w,
              h = piece.y + piece.h - bottom }
          end
          if piece.x < left then
            nextPieces[#nextPieces + 1] = {
              x = piece.x, y = top, w = left - piece.x, h = bottom - top }
          end
          if right < piece.x + piece.w then
            nextPieces[#nextPieces + 1] = {
              x = right, y = top, w = piece.x + piece.w - right,
              h = bottom - top }
          end
        end
      end
      pieces = nextPieces
    end
    return pieces
  end

  local restoreChromeUiStyle = installChromeUiStyle(Chrome, textboxModeAt)

  -- A palette flash (BATTLE_BG_EFFECT_FLASH_*) makes the engine re-bake the
  -- panel under a remapped BGP and blit it back as one opaque near-white
  -- sheet over the arena; its own fillBackground() also paints a plain white
  -- full-screen rect whose color may no longer read as exact white once the
  -- remap tint is applied. While a flash is live, suppress EVERY fullscreen
  -- fill together with the paper: HUD ink and boxes are never fullscreen
  -- fills, so they survive.
  local flashActive = false
  do
    local bg = state.anim and state.anim.bg
    if bg and bg.bgp ~= nil then
      local okPal, Pal = pcall(require, "src.ui.gen2.GbcPalette")
      if okPal and Pal and Pal.BGP_IDENTITY and bg.bgp ~= Pal.BGP_IDENTITY then
        flashActive = true
      end
    end
  end

  Chrome.clear = function() end
  -- Every live picture is already captured onto a world billboard, including
  -- the beaten trainer that returns for the victory text. Keep the native
  -- panel's picture calls suppressed for the entire staged presentation or
  -- both that trainer and the player's standing mon are drawn a second time
  -- in screen space as soon as battle.over is latched.
  state.drawPic = function() end

  -- BattleHud's four indexed sheets carry opaque shade-0 paper inside every
  -- HP/EXP cell and frame tile. Swap in cached keyed copies for this staged
  -- draw only. The ball sprites themselves already have OBJ transparency; the
  -- party-counter's white trailing square is its $5c corner from expBar, so it
  -- is covered here without touching the ball art.
  local hud = state.hud
  if hud and type(hud.image) == "function" and type(hud.images) == "table" then
    for _, key in ipairs({ "hpBar", "expBar", "enemyBorder", "playerBorder" }) do
      local path = hud.gfx and hud.gfx[key]
      local image = path and hud:image(key) or nil
      if path and image then
        hudImages[path] = hud.images[path]
        hud.images[path] = BattlePics.shade0Transparent(image)
      end
    end
  end
  -- BattleAnimView's fillBackground() paints its white sheet in GB space
  -- (160x144) under the panel transform, so it never matches a window-size
  -- test even though it lands over the whole arena. Treat an exact
  -- GB-frame white fill as paper too.
  local GB_W, GB_H = 160, 144
  g.rectangle = function(mode, x, y, w, h, ...)
    local r, gr, b, a = g.getColor()
    local coversFrame = mode == "fill" and ((w >= width * 0.9
                          and h >= height * 0.9)
                         or (w == GB_W and h == GB_H
                             and x <= 0 and y <= 0))
    if coversFrame then
      if isWhite(r, gr, b, a) or flashActive then return end
    end
    if isScreenFlash(mode, x, y, w, h, r, gr, b, a) then return end
    -- Font.drawBox paints its paper after Chrome has established the battle
    -- panel transform. Replace that exact fill in-place; the old eager draw
    -- ran in window coordinates, which left BLACK/OFF misaligned on screen.
    if mode == "fill" and drawingStyledBox
        and x == drawingStyledBox.x and y == drawingStyledBox.y
        and w == drawingStyledBox.w and h == drawingStyledBox.h then
      if textboxStyle then
        local oldColor = { g.getColor() }
        local oldShader = g.getShader()
        g.setShader()
        g.setColor(textboxStyle[1], textboxStyle[2], textboxStyle[3],
          textboxStyle[4])
        local parts = textboxMode == "HALF" and uncovered(drawingStyledBox)
          or { drawingStyledBox }
        for _, part in ipairs(parts) do
          nativeRectangle("fill", part.x, part.y, part.w, part.h, ...)
          if textboxMode == "HALF" then halfFillRects[#halfFillRects + 1] = part end
        end
        g.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
        g.setShader(oldShader)
      end
      return
    end
    -- Chrome prints a paper cell behind each line and cursor. Once a box has
    -- been filled with the selected style, suppress those smaller native
    -- whites so they do not punch holes through BLACK/HALF/OFF.
    if mode == "fill" and textboxMode ~= "WHITE" then
      for _, box in ipairs(styledBoxes) do
        if contains(box, x, y, w, h) then return end
      end
    end
    -- HUD panel paper: Font.drawBox paints the HP/EXP panels' white
    -- interior before its border glyphs. Over the arena those slabs are
    -- exactly the white the user wants gone; the text box lower on the
    -- screen keeps its paper. HUD panels live above GB row 12.
    if mode == "fill" and isWhite(r, gr, b, a)
        and h < 64 and (y + h) <= 96 then
      return
    end
    -- The command menu's cursor cell paints the same paper beside the
    -- arrow; over the arena it reads as a floating white square. Drop it
    -- with the rest of the upper-frame whites.
    if mode == "fill" and isWhite(r, gr, b, a)
        and y >= 96 and x >= 88 and w <= 48 and h <= 48 then
      return
    end
    return nativeRectangle(mode, x, y, w, h, ...)
  end

  -- Track each Chrome battle box. Its paper is handled by the rectangle shim
  -- above, and the same bounds tell the glyph adapter when opaque text needs
  -- no contrast shadow.
  local trackedPaletteBox = Chrome.paletteBox
  Chrome.paletteBox = function(tx, ty, tw, th, palette)
    local box = { x = tx * 8, y = ty * 8, w = tw * 8, h = th * 8 }
    styledBoxes[#styledBoxes + 1] = box
    local previous = drawingStyledBox
    drawingStyledBox = box
    local results = pack(pcall(trackedPaletteBox, tx, ty, tw, th, palette))
    drawingStyledBox = previous
    if not results[1] then error(results[2], 0) end
    return unpackValues(results, 2, results.n)
  end

  local results = pack(pcall(body))
  g.rectangle = nativeRectangle
  state.drawPic = instancePic
  if hud and hud.images then
    for path, image in pairs(hudImages) do hud.images[path] = image end
  end
  Chrome.clear = nativeClear
  Chrome.paletteBox = trackedPaletteBox
  restoreChromeUiStyle()

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

  -- Crystal's native front animation is a second image provider. When Battle
  -- Art has installed a selected custom frame, allowing the native frame
  -- through paints the greyscale animation over the chosen colored sprite.
  local nativeFrontAnim = BattleState.frontAnimFrame
  if type(nativeFrontAnim) == "function" then
    function BattleState:frontAnimFrame(mon)
      if mon and BattleArt.isExternal(mon.sprite) then return nil end
      return nativeFrontAnim(self, mon)
    end
  end

  function BattleState:drawWidescreen(width, height)
    local shot = OverworldBattle.shot()
    if not (shot and shot.canvas and love and love.graphics) then
      return nativeWidescreen(self, width, height)
    end

    local drawn = drawArena(shot.canvas, width, height)
    if not drawn then return nativeWidescreen(self, width, height) end

    -- While a move animation runs, the flat game repaints its whole panel
    -- through BattleAnimView: bake the 160x144 screen under a remapped BGP
    -- and blit it back as one opaque sheet. Over the arena that reads as a
    -- white panel with HUD on it -- the attack never reaches the world.
    -- The staged renderer composites the move IN WORLD instead (the anim
    -- layer rides the mon cards through OverworldBattle.animTexture), so
    -- here the animation view is set aside and the native draw runs its
    -- plain panel path: HUD, text box, nothing else.
    local anim = self.anim
    if anim ~= nil then self.anim = nil end
    local ok, result = pcall(function()
      return withoutOpaqueBattlePaper(self, width, height, function()
        return nativeWidescreen(self, width, height)
      end)
    end)
    self.anim = anim
    if not ok then error(result, 0) end
    return result
  end

  BattleState[MARKER] = true
  return true
end

return Adapter
