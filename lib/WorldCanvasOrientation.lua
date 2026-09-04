-- Gold/Silver/Crystal's integrated world compositor draws a pipeline Canvas
-- directly.  On LÖVE 12's affected renderer path that leaves the completed world
-- image upside-down.  Gen 1 goes through Renderer:endFrame instead, which
-- already owns its iOS correction, so this compatibility copy is deliberately
-- generation-gated rather than engine-version-gated.

local V = ...

local PixelCanvas = V.require("PixelCanvas")
local Orientation = {}
local targets = {}

function Orientation.needsFlip(generation)
  if tonumber(generation) ~= 2 then return false end
  -- Runtime first, renderer second. LÖVE 11 Macs must not receive this copy
  -- merely because their renderer/device description mentions Metal.
  local RendererOrientation = V.require("RendererOrientation")
  return RendererOrientation.metalRenderer()
end

local function targetFor(slot, w, h)
  local held = targets[slot]
  if held and held.w == w and held.h == h then return held.canvas end
  local ok, canvas = PixelCanvas.new(w, h)
  if not (ok and canvas) then return nil end
  pcall(canvas.setFilter, canvas, "nearest", "nearest")
  if held and held.canvas and held.canvas.release then
    pcall(held.canvas.release, held.canvas)
  end
  targets[slot] = { canvas = canvas, w = w, h = h }
  return canvas
end

-- Pre-flip only the finished Gen 2 world image.  UI is composed afterward,
-- so menus and touch controls retain their ordinary top-down orientation.
function Orientation.present(canvas, slot, generation)
  if not (canvas and Orientation.needsFlip(generation)) then return canvas end
  local ok, w, h = pcall(canvas.getDimensions, canvas)
  if not (ok and w and h and w > 0 and h > 0) then return canvas end
  local target = targetFor(slot or "world", w, h)
  if not target or target == canvas then return canvas end

  local g = love.graphics
  local prevCanvas = g.getCanvas and g.getCanvas() or nil
  local prevBlend, prevAlpha = g.getBlendMode()
  local drew = pcall(function()
    g.setCanvas(target)
    g.setShader()
    g.setBlendMode("replace", "premultiplied")
    g.setColor(1, 1, 1, 1)
    g.clear(0, 0, 0, 0)
    g.draw(canvas, 0, h, 0, 1, -1)
  end)
  if prevCanvas then g.setCanvas(prevCanvas) else g.setCanvas() end
  g.setShader()
  g.setBlendMode(prevBlend or "alpha", prevAlpha)
  g.setColor(1, 1, 1, 1)
  return drew and target or canvas
end

function Orientation.invalidate()
  for slot, held in pairs(targets) do
    if held.canvas and held.canvas.release then
      pcall(held.canvas.release, held.canvas)
    end
    targets[slot] = nil
  end
end

return Orientation
