local Trees = assert(loadfile("lib/TreeOverrides.lua"))()
for _, id in ipairs({ "ROUTE_32", "ROUTE32" }) do
  local changed = 0
  for y = 0, 89 do
    for x = 0, 19 do
      local scale = Trees.scale({ id = id }, x, y)
      if scale ~= 1 then
        changed = changed + 1
        assert((x == 6 or x == 7) and y == 67 and scale == 0.5)
      end
    end
  end
  assert(changed == 2)
end
assert(Trees.scale({ id = "ROUTE_31" }, 6, 67) == 1)
local quad = { {0, 0, 0}, {16, 0, 0}, {16, 32, 16}, {0, 32, 16},
               u = 0.25, v = 0.5, shade = 0.8 }
local out = Trees.scaleQuads({ quad }, 0.5)[1]
assert(out[1][2] == 0 and out[3][2] == 16)
assert(out[3][1] == 16 and out[3][3] == 16)
assert(out.u == quad.u and out.v == quad.v and out.shade == quad.shade)
assert(quad[3][2] == 32, "shared tall-tree template was mutated")
print("Route 32: exactly two trees shortened to 16px; footprint/art unchanged")
