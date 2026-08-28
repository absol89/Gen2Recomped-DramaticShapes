local checks = 0
local function eq(actual, expected, message)
  checks = checks + 1
  if math.abs(actual - expected) > 0.000001 then
    error(("FAIL %s: expected %s, got %s")
      :format(message, tostring(expected), tostring(actual)), 0)
  end
end

local made = {}
local invalidator
package.loaded["src.render.Assets"] = {
  image = function()
    return { getDimensions = function() return 64, 96 end }
  end,
  register = function(fn) invalidator = fn end,
}

local voxel = {
  pushQuad = function(indices)
    for _, index in ipairs({ 1, 2, 3, 1, 3, 4 }) do
      indices[#indices + 1] = index
    end
  end,
  newMesh = function(verts, indices)
    local mesh = { verts = verts, indices = indices }
    made[#made + 1] = mesh
    return mesh
  end,
}
local V = { require = function(name)
  assert(name == "Voxel3D", name)
  return voxel
end }

local Billboards = assert(loadfile("lib/SpriteBillboards.lua"))(V)

local sized = Billboards.mesh({
  image = "large-sheet.png", frameWidth = 32, frameHeight = 32,
}, 1)
eq(sized.verts[1][1], -8, "a 32px card starts left of its tile")
eq(sized.verts[2][1], 24, "a 32px card retains its full width")
eq(sized.verts[1][2], 0, "the default bottom anchor remains grounded")
eq(sized.verts[3][2], 32, "the card retains its full height")
eq(sized.verts[1][5], (64 - 0.05) / 96,
  "frame one samples the second vertical frame")

local anchored = Billboards.mesh({
  image = "large-sheet.png", frameWidth = 32, frameHeight = 32,
  anchorX = 12, anchorY = 24,
}, 1)
eq(anchored.verts[1][1], -4, "custom anchorX matches the 2D renderer")
eq(anchored.verts[2][1], 28, "custom anchorX retains the full width")
eq(anchored.verts[1][2], -8, "custom anchorY positions the frame bottom")
eq(anchored.verts[3][2], 24, "custom anchorY positions the frame top")
eq(#made, 2, "anchor metadata separates cached cards")

eq(Billboards.mesh({
  image = "large-sheet.png", frameWidth = 32, frameHeight = 32,
  anchorX = 12, anchorY = 24,
}, 1) == anchored and 1 or 0, 1, "identical definitions reuse their mesh")
eq(#made, 2, "a cache hit does not rebuild the mesh")

assert(invalidator, "FAIL billboard cache invalidator was not registered")
invalidator()
Billboards.mesh({
  image = "large-sheet.png", frameWidth = 32, frameHeight = 32,
  anchorX = 12, anchorY = 24,
}, 1)
eq(#made, 3, "asset invalidation rebuilds custom-sized cards")

print(("%d checks passed (oversized sprite billboards)"):format(checks))
