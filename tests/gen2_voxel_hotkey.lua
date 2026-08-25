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
local cycleBody = main:sub(cycle, wrapper - 1)
assert(not cycleBody:find('require("src.render.GBCFX").setLevel', 1, true),
  "Silver's voxel key still requires Gen1-only GBCFX")
assert(cycleBody:find('pcall(require, "src.render.GBCFX")', 1, true),
  "optional GBCFX clearing is not protected for Silver")

print("Gen 2 voxel hotkey: ok")
