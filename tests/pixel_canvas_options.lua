local runtimeLove = love
local got = nil
love = { graphics = { newCanvas = function(w, h, opts)
  got = { w = w, h = h, opts = opts }
  return { marker = true }
end } }

local PixelCanvas = assert(loadfile("lib/PixelCanvas.lua"))({})
local source = { format = "depth24", readable = true, msaa = 2 }
local ok, canvas = PixelCanvas.new(320, 180, source)
assert(ok and canvas.marker, "canvas creation failed")
assert(got.w == 320 and got.h == 180, "dimensions changed")
assert(got.opts.dpiscale == 1, "DPI was not pinned")
assert(got.opts.format == "depth24" and got.opts.readable == true
       and got.opts.msaa == 2, "caller options were not preserved")
assert(source.dpiscale == nil, "caller options were mutated")

love = runtimeLove
print("pixel canvas option/DPI contract: ok")
