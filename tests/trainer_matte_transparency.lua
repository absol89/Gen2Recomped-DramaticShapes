local pixels = {}
local W, H = 5, 5
local unpackValues = table.unpack or unpack
for y = 0, H - 1 do
  for x = 0, W - 1 do pixels[y * W + x] = { 1, 1, 1, 1 } end
end
-- A dark ring encloses a painted white shirt pixel. The outside paper must
-- clear, but the identical white inside the silhouette must survive.
for x = 1, 3 do
  pixels[1 * W + x] = { 0, 0, 0, 1 }
  pixels[3 * W + x] = { 0, 0, 0, 1 }
end
pixels[2 * W + 1] = { 0, 0, 0, 1 }
pixels[2 * W + 3] = { 0, 0, 0, 1 }
-- Extracted indexed portraits can already contain some alpha even though the
-- rest of their outside shade-0 paper remains opaque.
pixels[0] = { 1, 1, 1, 0 }

local data = {
  getDimensions = function() return W, H end,
  getPixel = function(_, x, y) return unpackValues(pixels[y * W + x]) end,
  setPixel = function(_, x, y, r, g, b, a)
    pixels[y * W + x] = { r, g, b, a }
  end,
}
local made
local canvas = {
  newImageData = function() return data end,
  release = function() end,
}
love = { graphics = {
  getCanvas = function() return nil end,
  getBlendMode = function() return "alpha", "alphamultiply" end,
  getColor = function() return 1, 1, 1, 1 end,
  newCanvas = function() return canvas end,
  setCanvas = function() end,
  clear = function() end,
  setBlendMode = function() end,
  setColor = function() end,
  draw = function() end,
  newImage = function(out)
    made = out
    return { setFilter = function() end }
  end,
} }

local BattlePics = assert(loadfile("lib/BattlePics.lua"))({})
local image = { getDimensions = function() return W, H end }
local out = BattlePics.outsideTransparent(image)
assert(out ~= image and made, "opaque trainer matte was not rebuilt")
local _, _, _, outside = made:getPixel(4, 0)
local r, g, b, inside = made:getPixel(2, 2)
assert(outside == 0, "trainer's outside white remained opaque")
assert(inside == 1 and r == 1 and g == 1 and b == 1,
  "trainer's enclosed painted white was made transparent")
assert(BattlePics.outsideTransparent(image) == out,
  "trainer matte result was not cached")

print("trainer matte transparency regression: ok")
