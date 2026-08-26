local unpackValues = table.unpack or unpack
local pixels = {
  { 1, 1, 1, 1 },       -- shade-0 paper outside a tile
  { 2 / 3, 2 / 3, 2 / 3, 1 }, -- coloured HP/EXP fill source
  { 0, 0, 0, 1 },       -- frame/label ink
  { 1, 1, 1, 1 },       -- enclosed shade-0 paper inside an empty cell
}
local data = {
  getDimensions = function() return 4, 1 end,
  getPixel = function(_, x) return unpackValues(pixels[x + 1]) end,
  setPixel = function(_, x, _, r, g, b, a)
    pixels[x + 1] = { r, g, b, a }
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
local image = { getDimensions = function() return 4, 1 end }
local out = BattlePics.shade0Transparent(image)
assert(out ~= image and made, "HUD sheet with shade-0 paper was not rebuilt")
local _, _, _, outside = made:getPixel(0, 0)
local fr, _, _, fill = made:getPixel(1, 0)
local ir, _, _, ink = made:getPixel(2, 0)
local _, _, _, enclosed = made:getPixel(3, 0)
assert(outside == 0 and enclosed == 0,
  "HUD shade-0 paper remained opaque outside or inside a bar cell")
assert(fill == 1 and math.abs(fr - 2 / 3) < 0.001,
  "HUD coloured fill shade was made transparent or recoloured")
assert(ink == 1 and ir == 0, "HUD black frame/label ink was made transparent")
assert(BattlePics.shade0Transparent(image) == out,
  "HUD paper-keyed sheet was not cached")

print("HUD paper transparency regression: ok")
