-- Native Gen 2 widescreen presentation boundary. Stadium supplies the live
-- world scene; Battle Art captures and styles Gold/Silver's own HUD, menus,
-- prompts and animation objects exactly once.

local V = ...
local UiBackplates = V.require("UiBackplates")
local BattleHud = V.require("BattleHud")
local BattleArt = V.require("BattleArt")
local StadiumBackground = V.require("StadiumBackground")
local OverworldBattle = V.require("OverworldBattle")

local Adapter = {}
local MARKER = "battleArtGen2WidescreenAdapter"

local function sameBattle(a, b)
  if a == nil or b == nil then return a == b end
  if a == b then return true end
  local aa = type(a) == "table" and a.battle or nil
  local bb = type(b) == "table" and b.battle or nil
  return aa == b or bb == a or (aa ~= nil and aa == bb)
end

local function stadiumScene(state)
  local mode = UiBackplates.arenaFill:get()
  if mode ~= "OFF" and mode ~= "STADIUM2"
      and not (StadiumBackground.legacyInstalled
        and StadiumBackground.legacyInstalled()) then return nil end
  local find = V.mod and V.mod.find
  if type(find) ~= "function" then return nil end
  local ok, handle = pcall(find, "STADIUM2_IMPORTER")
  if not ok or not handle then ok, handle = pcall(find, V.mod, "STADIUM2_IMPORTER") end
  local current = handle and handle.exports and handle.exports.getActiveBattleScene
  if type(current) ~= "function" then
    return StadiumBackground.legacyScene
      and StadiumBackground.legacyScene(state) or nil
  end
  local found, scene = pcall(current)
  if not found then found, scene = pcall(current, handle.exports) end
  if not (found and scene and not scene.defect) then return nil end
  if scene.screen and scene.screen ~= state then return nil end
  -- The unified Gen 2 screen and its rules battle are two views of the same
  -- fight. Importer 0.10.7 may key its scene to either one depending on which
  -- battle.started compatibility event it observed; accept both identities.
  if scene.battle and not sameBattle(scene.battle, state) then return nil end
  return scene
end

local function drawArena(picture, width, height)
  if not (picture and picture.getDimensions and love and love.graphics) then
    return false
  end
  local ok, w, h = pcall(picture.getDimensions, picture)
  if not ok or not (w and h and w > 0 and h > 0) then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(picture, 0, 0, 0, width / w, height / h)
  return true
end

-- Replace only Chrome box paper. The box/border/text remain native; nested
-- HALF boxes share one coverage list per capture so their overlap never turns
-- into the darker broken band seen between TYPE and the move selector.
local function withStyledPaper(fn)
  local mode = UiBackplates.textboxMode()
  if mode == "WHITE" then return fn() end
  local Chrome = require("src.ui.gen2.Chrome")
  local g = love.graphics
  local nativeBox, nativeRectangle = Chrome.paletteBox, g.rectangle
  local drawing, boxes, fills = nil, {}, {}

  local function contains(box, x, y, w, h)
    return x >= box.x and y >= box.y
      and x + w <= box.x + box.w and y + h <= box.y + box.h
  end

  local function subtract(rect)
    local pieces = { rect }
    for _, old in ipairs(fills) do
      local nextPieces = {}
      for _, p in ipairs(pieces) do
        local x1, y1 = math.max(p.x, old.x), math.max(p.y, old.y)
        local x2 = math.min(p.x + p.w, old.x + old.w)
        local y2 = math.min(p.y + p.h, old.y + old.h)
        if x1 >= x2 or y1 >= y2 then
          nextPieces[#nextPieces + 1] = p
        else
          if p.y < y1 then nextPieces[#nextPieces + 1] =
            { x=p.x, y=p.y, w=p.w, h=y1-p.y } end
          if y2 < p.y+p.h then nextPieces[#nextPieces + 1] =
            { x=p.x, y=y2, w=p.w, h=p.y+p.h-y2 } end
          if p.x < x1 then nextPieces[#nextPieces + 1] =
            { x=p.x, y=y1, w=x1-p.x, h=y2-y1 } end
          if x2 < p.x+p.w then nextPieces[#nextPieces + 1] =
            { x=x2, y=y1, w=p.x+p.w-x2, h=y2-y1 } end
        end
      end
      pieces = nextPieces
    end
    return pieces
  end

  Chrome.paletteBox = function(tx, ty, tw, th, palette)
    local box = { x=tx*8, y=ty*8, w=tw*8, h=th*8 }
    boxes[#boxes + 1], drawing = box, box
    local ok, a, b = pcall(nativeBox, tx, ty, tw, th, palette)
    drawing = nil
    if not ok then error(a, 0) end
    return a, b
  end

  g.rectangle = function(kind, x, y, w, h, ...)
    if kind ~= "fill" then return nativeRectangle(kind, x, y, w, h, ...) end
    if drawing and x == drawing.x and y == drawing.y
        and w == drawing.w and h == drawing.h then
      local style = UiBackplates.textboxFillStyle()
      if style then
        local old = { g.getColor() }
        g.setColor(style[1], style[2], style[3], style[4])
        local paper = drawing
        if mode == "HALF" then
          local x, y, w, h = UiBackplates.halfRect(
            drawing.x, drawing.y, drawing.w, drawing.h, 1)
          paper = { x=x, y=y, w=w, h=h }
        end
        local parts = mode == "HALF" and subtract(paper) or { paper }
        for _, p in ipairs(parts) do
          nativeRectangle("fill", p.x, p.y, p.w, p.h, ...)
          if mode == "HALF" then fills[#fills + 1] = p end
        end
        g.setColor(old[1], old[2], old[3], old[4])
      end
      return
    end
    if mode ~= "WHITE" then
      for _, box in ipairs(boxes) do
        if contains(box, x, y, w, h) then return end
      end
    end
    return nativeRectangle(kind, x, y, w, h, ...)
  end

  local ok, a, b = pcall(fn)
  Chrome.paletteBox, g.rectangle = nativeBox, nativeRectangle
  if not ok then error(a, 0) end
  return a, b
end

local HUD_RECT = {
  enemy={8,0,80,32}, player={72,56,80,40},
}

-- Version-neutral final placement. 0.10.7 already exposes layer/hudLayer/
-- modalLayer, but its Hud.composite predates bottom anchoring, connected move
-- panes, complete stats capture and the safe Yes/No slot. Compose those
-- stable 160x144 source rectangles here so both importer API generations use
-- exactly the same Battle Art layout.
local function composite(scene, screen, layer, hudLayer, modalLayer)
  if not (scene and layer and scene.hudBox) then return false end
  local g, box = love.graphics, scene.hudBox
  local s = box.scale
  local width, height = scene.width, scene.height
  if not (s and width and height) then return false end
  local inset = 2 * s
  local lowerY = box.ly + 96 * s
  -- The native lower box is 48 logical pixels high. Keep four pixels below
  -- it in widescreen: the prior two-pixel margin put the captured frame two
  -- pixels below the HALF frost plate, exposing the translucent slab outside
  -- the white chrome. TYPE/move panes and auxiliary prompts derive from this
  -- same anchor and remain attached when it moves.
  if width >= height then lowerY = math.max(0, height - 52 * s) end
  local er, pr = HUD_RECT.enemy, HUD_RECT.player
  local enemyX, enemyY = inset, inset
  local playerX = width - pr[3] * s - inset
  local playerY = box.ly + pr[2] * s
  local enemyLive = screen.showEnemyHud and not screen.showEnemyTrainer
  local playerLive = screen.showPlayerHud and not screen.showPlayerTrainer
    and not screen.tutorial

  g.setShader()
  g.setColor(1, 1, 1, 1)
  if enemyLive and hudLayer then
    local q = g.newQuad(er[1], er[2], er[3], er[4], 160, 144)
    g.draw(hudLayer, q, enemyX, enemyY, 0, s, s)
  end
  if playerLive and hudLayer then
    local q = g.newQuad(pr[1], pr[2], pr[3], pr[4], 160, 144)
    g.draw(hudLayer, q, playerX, playerY, 0, s, s)
  end

  if screen.phase == "moves" then
    local y = lowerY - 32 * s
    local q = g.newQuad(0, 64, 160, 80, 160, 144)
    g.draw(modalLayer or layer, q, box.lx, y, 0, s, s)
  else
    local q = g.newQuad(0, 96, 160, 48, 160, 144)
    g.draw(layer, q, box.lx, lowerY, 0, s, s)
  end

  local asking = screen.phase=="ask-nickname"
    or screen.phase=="ask-forget" or screen.phase=="stop-learning"
    or screen.phase=="ask-shift" or screen.phase=="ask-next-mon"
  if asking and (screen.messageTimer or 0) <= 0 then
    local left = (screen.phase=="ask-shift" or screen.phase=="ask-next-mon")
      and 8 or 112
    local x, y = box.lx, math.max(inset, lowerY - 40*s)
    local q = g.newQuad(left, 56, 48, 40, 160, 144)
    g.draw(modalLayer or layer, q, x, y, 0, s, s)
  end

  if screen.phase == "stats-box" and screen.statsBoxMon then
    local x, y = box.lx, math.max(inset, lowerY - 96*s)
    local q = g.newQuad(72, 0, 88, 96, 160, 144)
    g.draw(modalLayer or layer, q, x, y, 0, s, s)
  end
  g.setColor(1, 1, 1, 1)
  return true
end

function Adapter.install()
  local ok, BattleState = pcall(require, "src.ui.gen2.BattleState")
  if not ok or not BattleState then return ok end
  if type(BattleState.drawWidescreen) ~= "function" then return false end
  local nativePic = BattleState.pic
  if type(nativePic) == "function" and not BattleState.battleArtGen2PicAdapter then
    function BattleState:pic(mon, back)
      local image, trueColor, path = nativePic(self, mon, back)
      if mon and BattleArt.isExternal(mon.sprite) then
        return mon.sprite, true, path
      end
      return image, trueColor, path
    end
    BattleState.battleArtGen2PicAdapter = true
  end
  local nativeFrontAnim = BattleState.frontAnimFrame
  if type(nativeFrontAnim) == "function"
      and not BattleState.battleArtGen2FrontAnimAdapter then
    function BattleState:frontAnimFrame(mon)
      if mon and BattleArt.isExternal(mon.sprite) then return nil end
      return nativeFrontAnim(self, mon)
    end
    BattleState.battleArtGen2FrontAnimAdapter = true
  end
  local nativeWide = BattleState.drawWidescreen
  if nativeWide == Adapter._wideWrapper then return true end

  local function wideWrapper(self, width, height)
    if self.stadium2ImporterBattleArtUiPass then
      return nativeWide(self, width, height)
    end
    local scene = stadiumScene(self)
    if scene then
      -- Importer 0.10.7 normally performs these assignments in its own
      -- drawWidescreen wrapper. Battle Art is the outer compositor now, so
      -- keep the legacy scene attached to the live unified BattleState and
      -- refresh its two model actors before reading the rendered canvas.
      local newlyAttached = scene.screen ~= self
      scene.screen = self
      if type(scene.sync) == "function" then pcall(scene.sync, scene) end
      if type(scene.render) == "function"
          and (newlyAttached or not scene.readyFrame or scene.width ~= width
            or scene.height ~= height) then
        pcall(scene.render, scene, width, height)
      end
    end
    local picture = scene and (scene.presentCanvas or scene.canvas)
    if not (scene and drawArena(picture, width, height)) then
      return nativeWide(self, width, height)
    end

    local okHud, Hud = pcall(require,
      "mods.STADIUM2_IMPORTER.lib.battle_hud")
    if not (okHud and Hud and Hud.layer and Hud.hudLayer and Hud.composite) then
      return nativeWide(self, width, height)
    end

    -- Successful catch scripts may retain their terminal OBJ pose for one
    -- presentation frame after BattleState has cleared self.anim. Mirror the
    -- importer's native compositor so that Pokeballs and other authored OBJs
    -- are not lost at that boundary.
    local nativeAnim = self.anim
    local anim = nativeAnim or self.stadium2ImporterRetainedAnim
    self.anim = nil
    -- Unified Gen2Recomped owns animations through animPlayer/drawAnimLayer,
    -- not the removed BattleAnimView object API used by importer 0.10.7.
    -- Keep that complete layer out of the split HUD captures and paint it once
    -- over the final scene below, where Stadium Battle FX has replaced the
    -- engine AnimPlayer and can emit its authored particles.
    local nativeDrawAnim = rawget(self, "drawAnimLayer")
    self.drawAnimLayer = function() end
    self.stadium2ImporterBattleArtUiPass = true
    local okDraw, result = pcall(function()
      scene.crystalMovePane = self.phase == "moves"
      local function styledScene()
        return withStyledPaper(function()
          BattleHud.flipGlyphs(160, 144,
            function() self:drawScene() end, false, true, true)
        end)
      end
      local layer = Hud.layer(styledScene,
        { preservePaper=true, crystalMovePane=scene.crystalMovePane })
      local hudLayer = Hud.hudLayer(function()
        local preserve = UiBackplates.hudUsesColor()
        BattleHud.flipGlyphs(160, 144,
          function() self:drawHud() end, preserve, true)
      end)
      local modalLayer
      if Hud.modalLayer then
        modalLayer = Hud.modalLayer(function()
          local had = rawget(self, "drawHud")
          self.drawHud = function() end
          local modalOk, modalErr = pcall(styledScene)
          self.drawHud = had
          if not modalOk then error(modalErr, 0) end
        end, { preservePaper=true, crystalMovePane=scene.crystalMovePane })
      end
      scene.statusHudOwned = true
      scene.bottomUiVisible = true
      local composed = composite(scene, self, layer, hudLayer, modalLayer)
      if anim and self.animView and scene.uiAnchors and scene.hudBox then
        local box, g = scene.hudBox, love.graphics
        g.push()
        g.translate(box.lx, box.ly)
        g.scale(box.scale, box.scale)
        local drawOk, drawErr = pcall(self.animView.drawObjects,
          self.animView, anim, self.battle)
        g.pop()
        if not drawOk then error(drawErr, 0) end
      end
      if self.animPlayer and scene.hudBox then
        local box, g = scene.hudBox, love.graphics
        local hadShot = rawget(self, "dramaticShapeShot")
        if not hadShot then
          self.dramaticShapeShot = OverworldBattle.stageShot()
            or OverworldBattle.shot()
        end
        g.push()
        g.translate(box.lx, box.ly)
        g.scale(box.scale, box.scale)
        local drawOk, drawErr = pcall(BattleState.drawAnimLayer, self, true)
        g.pop()
        self.dramaticShapeShot = hadShot
        if not drawOk then error(drawErr, 0) end
      end
      return composed
    end)
    self.stadium2ImporterBattleArtUiPass = nil
    self.drawAnimLayer = nativeDrawAnim
    self.anim = nativeAnim
    if not okDraw then error(result, 0) end
    return result
  end

  Adapter._wideWrapper = wideWrapper
  BattleState.drawWidescreen = wideWrapper

  BattleState[MARKER] = true
  return true
end

return Adapter
