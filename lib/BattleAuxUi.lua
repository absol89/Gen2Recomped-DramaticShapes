-- Battle-owned screens pushed above BattleState do not pass through
-- BattleState:drawTextArea. Keep those prompts/stat windows attached to the
-- lower textbox and apply the same paper mode without changing their input or
-- lifecycle. The compact/native layout remains untouched outside a staged
-- battle.

local V = ...

local UiBackplates = V.require("UiBackplates")
local BattleHud = V.require("BattleHud")
local OverworldBattle = V.require("OverworldBattle")

local BattleAuxUi = {}

local function active()
  if OverworldBattle.battle and OverworldBattle.battle() then return true end
  local find = V.mod and V.mod.find
  if type(find) ~= "function" then return false end
  local ok, handle = pcall(find, "STADIUM2_IMPORTER")
  if not ok or not handle then ok, handle = pcall(find, V.mod, "STADIUM2_IMPORTER") end
  local current = handle and handle.exports and handle.exports.getActiveBattleScene
  if type(current) ~= "function" then return false end
  local found, scene = pcall(current)
  if not found then found, scene = pcall(current, handle.exports) end
  return found and scene ~= nil
end

local function styled(draw)
  local mode = UiBackplates.textboxMode()
  if mode == "WHITE" then return draw() end
  local style = UiBackplates.textboxFillStyle()
  local g = love.graphics
  local rectangle = g.rectangle
  local filled = {}
  local function uncovered(rect)
    local pieces = { rect }
    for _, old in ipairs(filled) do
      local nextPieces = {}
      for _, p in ipairs(pieces) do
        local x1, y1 = math.max(p[1], old[1]), math.max(p[2], old[2])
        local x2 = math.min(p[1] + p[3], old[1] + old[3])
        local y2 = math.min(p[2] + p[4], old[2] + old[4])
        if x1 >= x2 or y1 >= y2 then
          nextPieces[#nextPieces + 1] = p
        else
          if p[2] < y1 then
            nextPieces[#nextPieces + 1] = { p[1], p[2], p[3], y1 - p[2] }
          end
          if y2 < p[2] + p[4] then
            nextPieces[#nextPieces + 1] = {
              p[1], y2, p[3], p[2] + p[4] - y2 }
          end
          if p[1] < x1 then
            nextPieces[#nextPieces + 1] = { p[1], y1, x1 - p[1], y2 - y1 }
          end
          if x2 < p[1] + p[3] then
            nextPieces[#nextPieces + 1] = {
              x2, y1, p[1] + p[3] - x2, y2 - y1 }
          end
        end
      end
      pieces = nextPieces
    end
    return pieces
  end
  g.rectangle = function(kind, x, y, w, h, ...)
    if kind ~= "fill" then return rectangle(kind, x, y, w, h, ...) end
    if style then
      local old = { g.getColor() }
      g.setColor(style[1], style[2], style[3], style[4])
      local parts = mode == "HALF" and uncovered({ x, y, w, h })
        or { { x, y, w, h } }
      for _, p in ipairs(parts) do
        rectangle(kind, p[1], p[2], p[3], p[4], ...)
        if mode == "HALF" then filled[#filled + 1] = p end
      end
      g.setColor(old[1], old[2], old[3], old[4])
    end
    -- OFF deliberately emits no paper. HALF/BLACK emitted their replacement.
  end
  local ok, err = pcall(function()
    BattleHud.flipGlyphs(160, 144, draw, false, true, true)
  end)
  g.rectangle = rectangle
  if not ok then error(err, 0) end
end

function BattleAuxUi.install()
  local ChoiceBox = require("src.ui.ChoiceBox")
  if not ChoiceBox.battleArtAuxUi then
    local native = ChoiceBox.draw
    function ChoiceBox:draw()
      if not active() or self.anchor then return native(self) end
      local tx, ty = self.tx, self.ty
      -- The left/type-pane slot immediately above the 48px lower textbox.
      -- Keeping the existing width/height preserves translated/custom labels.
      self.tx, self.ty = 0, math.max(0, 12 - self.th)
      local ok, err = pcall(styled, function() native(self) end)
      self.tx, self.ty = tx, ty
      if not ok then error(err, 0) end
    end
    ChoiceBox.battleArtAuxUi = true
  end

  local BattleState = require("src.battle.BattleState")
  local StatBox = BattleState.StatBox
  if StatBox and not StatBox.battleArtAuxUi then
    local native = StatBox.draw
    function StatBox:draw()
      if not active() then return native(self) end
      -- Native box is (9,2)-(20,12). Translate it to (0,2)-(11,12): its
      -- bottom touches the dialogue box at y=96 and its left edge aligns.
      local g = love.graphics
      styled(function()
        g.push()
        g.translate(-72, 0)
        local ok, err = pcall(native, self)
        g.pop()
        if not ok then error(err, 0) end
      end)
    end
    StatBox.battleArtAuxUi = true
  end

  local MoveLearnMenu = require("src.ui.MoveLearnMenu")
  if MoveLearnMenu and not MoveLearnMenu.battleArtAuxUi then
    local native = MoveLearnMenu.draw
    function MoveLearnMenu:draw()
      if not active() then return native(self) end
      return styled(function() native(self) end)
    end
    MoveLearnMenu.battleArtAuxUi = true
  end
  return true
end

return BattleAuxUi
