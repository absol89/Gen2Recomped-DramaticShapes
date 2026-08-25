local f = assert(io.open("main.lua", "rb"))
local main = f:read("*a")
f:close()

local cycle = assert(main:find("local function cycleVoxel(game)", 1, true))
local wrapper = assert(main:find("Game.battleArtVoxelGen2Hotkey", cycle, true))

assert(main:find("game:pipelineGate()", cycle, true) < wrapper,
  "the voxel ladder does not use Silver's free-roam pipeline gate")
assert(main:find("game.options or (game.save", cycle, true) < wrapper,
  "the voxel ladder does not persist to Silver's scoped options")
assert(main:find('if key == "3" and cycleVoxel(self)', wrapper, true),
  "Silver's native TILT key still consumes 3 before the voxel ladder")

print("Gen 2 voxel hotkey: ok")
