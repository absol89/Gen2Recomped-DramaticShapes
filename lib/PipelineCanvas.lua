-- Host-compositor sizing contract for render-pipeline world canvases.
--
-- Gen 1's Renderer:endFrame expects a framebuffer-sized worldOverride and
-- scales it back to LOVE units by 1/dpi. Gold/Silver/Crystal's Gen 2 World
-- draws the returned canvas directly at scale 1, so it must remain LOVE-unit
-- sized. Mixing those contracts is the Android DPI-factor crop which looks
-- like an extremely zoomed camera.

local V = ...
local PipelineCanvas = {}

function PipelineCanvas.sceneSize(ctx, generation)
  ctx = ctx or {}
  generation = tonumber(generation) or 1
  if generation == 2 then
    return ctx.width, ctx.height
  end
  if love and love.graphics and love.graphics.getPixelDimensions then
    local ok, pw, ph = pcall(love.graphics.getPixelDimensions)
    if ok and pw and ph and pw > 0 and ph > 0 then return pw, ph end
  end
  return ctx.width, ctx.height
end

return PipelineCanvas
