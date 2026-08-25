local f = assert(io.open("main.lua", "rb"))
local main = f:read("*a")
f:close()

local helper = assert(main:find("local function gen2PipelineOptions(game)",
                                1, true))
local update = assert(main:find("update = function(dt, level)", helper, true))
local ready = assert(main:find('mod.events:on("game.ready"', update, true))

assert(main:find("game and (game.options", helper, true) < update,
  "Silver does not read its generation-scoped options table first")
assert(main:find("opts.pipelines.voxel == nil", helper, true) < update,
  "a missing Silver voxel setting is not distinguished from explicit OFF")
assert(main:find("opts.pipelines.voxel = GEN2_DEFAULT_VOXEL", helper, true)
       < update,
  "the Silver voxel default is not seeded into its own options block")
assert(main:find("gen2PipelineOptions(Game)", update, true) < ready,
  "the update-side restore bypasses Silver's scoped option migration")
assert(main:find("gen2PipelineOptions(game)", ready, true),
  "game.ready bypasses Silver's scoped option migration")

print("Gen 2 voxel option scope: ok")
