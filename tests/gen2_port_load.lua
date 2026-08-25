package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local previous = GameVersion.get()
GameVersion.set("silver")

local path = os.getenv("DS_MOD_PATH") or "mods/BATTLE_ART_VOXEL_GEN2"
local run = T.sdk.loadMod(path, {
  data = T.fixtures.load(),
  generation = 2,
  root = os.getenv("DS_ENGINE_ROOT") or ".",
})
GameVersion.set(previous)

assert(#run.errors == 0,
  "Silver mod load failed: " .. table.concat(run.errors, "; "))
assert(run.mod and run.mod.manifest.id == "BATTLE_ART_VOXEL_GEN2",
  "Silver loader did not retain the Battle Art mod")
local pipelines = run.data.render_pipelines
assert(pipelines and pipelines.voxel and pipelines.voxel.drawWorld,
  "Silver loader did not receive the voxel world pipeline")
assert(pipelines._owners.voxel == "BATTLE_ART_VOXEL_GEN2",
  "Silver voxel pipeline lost its owning mod")
local exported = run.loader.exports.BATTLE_ART_VOXEL_GEN2
assert(exported and exported.lib and exported.lib.require,
  "Silver port did not publish its shared module boundary")
assert(exported.lib.require("Gen2BattleAdapter"),
  "Silver battle adapter could not be loaded")
assert(exported.lib.require("Gen2WorldAdapter"),
  "Silver world adapter could not be loaded")

run.release()
print("Gen 2 port load regression: ok")
