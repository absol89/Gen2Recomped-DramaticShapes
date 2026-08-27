-- PR #23 plus the Gen2 big-sprite path: registered dimensions affect the
-- sampled frame, card geometry, centre and mesh-cache identity.

package.loaded["src.render.Assets"] = nil
local images = {
  custom = { getDimensions = function() return 68, 70 end },
  shared = { getDimensions = function() return 64, 64 end },
  big = { getDimensions = function() return 32, 32 end },
}
package.preload["src.render.Assets"] = function()
  return {
    image = function(path) return assert(images[path], path) end,
    register = function() end,
  }
end

local fake3d = {
  pushQuad = function(indices, base)
    for _, i in ipairs({ 1, 2, 3, 1, 3, 4 }) do
      indices[#indices + 1] = base + i
    end
  end,
  newMesh = function(verts, indices)
    return { verts = verts, indices = indices }
  end,
}
local V = { require = function(name)
  assert(name == "Voxel3D", name)
  return fake3d
end }
local Billboards = assert(loadfile("lib/SpriteBillboards.lua"))(V)

local custom = { image = "custom", frameWidth = 34, frameHeight = 35 }
local card = assert(Billboards.mesh(custom, 1))
assert(card.verts[2][1] == 34 and card.verts[3][2] == 35,
  "registered dimensions did not size the voxel card")
assert(Billboards.halfWidth(custom) == 17,
  "registered-width card is not centred on its own midpoint")
assert(card.verts[1][5] > 0.49,
  "frameHeight did not advance the sampled frame row")

local a = Billboards.mesh({ image = "shared", frameWidth = 16,
                            frameHeight = 16 }, 0)
local b = Billboards.mesh({ image = "shared", frameWidth = 32,
                            frameHeight = 32 }, 0)
assert(a ~= b, "registered sprite dimensions collided in the mesh cache")
assert(a.verts[2][1] == 16 and b.verts[2][1] == 32)

local big = { id = "SPRITE_BIG_SNORLAX", image = "big", big = true }
assert(Billboards.mesh(big, 0).verts[2][1] == 32
  and Billboards.halfWidth(big) == 16,
  "PR #23 integration regressed Gen2's native 2x2 sprite support")

print("sprite billboard registered-dimension regression: ok")
