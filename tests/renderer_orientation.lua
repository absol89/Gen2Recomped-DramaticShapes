local renderer = { "Metal", "3.1", "Apple", "Apple GPU" }
love = { graphics = {
  getRendererInfo = function() return unpack(renderer) end,
} }

local Orientation = assert(loadfile("lib/RendererOrientation.lua"))()
assert(Orientation.metalRenderer(), "Metal renderer was not detected")

local x, y, sx, sy = Orientation.backdropTransform(
  800, 600, -20, -30, 2, true)
assert(x == -20 and y == 1170 and sx == 2 and sy == -2,
  "Metal backdrop did not flip around the complete image height")

x, y, sx, sy = Orientation.backdropTransform(800, 600, -20, -30, 2, false)
assert(x == -20 and y == -30 and sx == 2 and sy == 2,
  "non-Metal backdrop transform changed")

renderer = { "OpenGL ES", "3.0", "Qualcomm", "Adreno" }
assert(not Orientation.metalRenderer(), "Android GLES was mistaken for Metal")
renderer = { "OpenGL ES", "3.0", "Apple", "A-series" }
assert(Orientation.metalRenderer(), "Apple GLES compatibility path was missed")

print("renderer orientation regression: ok")
