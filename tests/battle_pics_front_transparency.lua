local BattlePics = assert(loadfile("lib/BattlePics.lua"))({})
local pixels = {
  { 1, 1, 1, 1 },
  { 0.2, 1, 0.1, 1 },
  { 0, 0, 0, 1 },
  { 1, 1, 1, 0 },
}
local data = {
  mapPixel = function(_, fn)
    for i, pixel in ipairs(pixels) do
      pixels[i] = { fn(i - 1, 0, unpack(pixel)) }
    end
  end,
}

assert(BattlePics.keyWhiteData(data), "opaque ROM white was not detected")
assert(pixels[1][4] == 0, "opaque ROM white was not keyed transparent")
assert(pixels[2][2] == 1 and pixels[2][4] == 1,
  "colored sprite ink was changed")
assert(pixels[3][4] == 1, "black sprite ink was changed")
assert(pixels[4][4] == 0, "existing transparency was changed")

print("battle-pics front transparency regression: ok")
