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

-- The ROM can also key shade-zero pixels inside the trainer's shirt.
-- After outside matte removal, restore that indexed paper without making
-- the surrounding arena opaque. Keep one surviving shade-zero highlight.
data:setPixel(2, 1, 1, 1, 1, 1)
data:setPixel(2, 2, 1, 1, 1, 0)
local filled = BattlePics.filled(image, true)
assert(filled ~= image, "ROM trainer's keyed shirt was not restored")
local r, g, b, a = data:getPixel(2, 2)
assert(a == 1 and r == 1 and g == 1 and b == 1,
  "ROM trainer shirt must use surviving shade-zero paper")
local _, _, _, outside = data:getPixel(4, 0)
assert(outside == 0, "ROM reconstruction filled the outside background")
print("ROM trainer keyed paper restoration: ok")
