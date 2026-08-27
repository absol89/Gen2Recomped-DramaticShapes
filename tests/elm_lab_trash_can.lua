-- Elm's authored $09 pin must survive the Gen2 engine-id normalization and
-- reach the round-hull classifier used by Structures.buildCylinders.

local profile = assert(loadfile("data/voxel_heights.lua"))({})
local V = {
  data = function(name)
    assert(name == "voxel_heights", name)
    return profile
  end,
}
local TileShape = assert(loadfile("lib/TileShape.lua"))(V)
local shapes = TileShape.forMap({ tileset = {
  id = "TilesetLab", imageWidth = 128, imageHeight = 48,
  walkable = {}, waterTiles = {},
} })
local can = assert(shapes[0x09], "TilesetLab $09 has no resolved shape")
assert(can.authored and can.class == "can" and can.art == "cylinder",
  "Elm's trash can did not reach the authored round-hull path")
assert(can.h == profile.tilesets.TilesetLab.can_height,
  "Elm's can classifier and hull height disagree")

print("Elm lab trash-can classifier regression: ok")
