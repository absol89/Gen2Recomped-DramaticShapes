local V = ...

local PixelCanvas = {}

-- Every canvas which can be attached to, copied from, or sampled alongside
-- the scene canvas must use one DPI rule. Preserve format/readability options
-- and pin the family to one physical texel per requested pixel, as Battle Art
-- 1.9.8 does for high-density Android/iOS targets.
function PixelCanvas.new(w, h, options)
  local opts = {}
  for key, value in pairs(options or {}) do opts[key] = value end
  opts.dpiscale = 1
  return pcall(love.graphics.newCanvas, w, h, opts)
end

return PixelCanvas
