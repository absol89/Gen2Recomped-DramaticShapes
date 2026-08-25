-- Silver movement regression: exercise the installed pollInput/stepBody seam
-- close enough to a cell edge that the allowed-cell verdict must be honored.

local saved = {}
local function provide(name, value)
  saved[name] = package.loaded[name]
  package.loaded[name] = value
end

local World = {}
function World:pollInput() end
function World:stepBody() end

provide("src.world.gen2.World", World)
provide("src.world.gen2.FieldMoves", {
  isBiking = function() return false end,
  isSurfing = function() return false end,
})
provide("src.world.gen2.Permissions", {
  stepPermitted = function() return true end,
  currentDirection = function() return nil end,
  doorForcedDirection = function() return nil end,
  isIce = function() return false end,
})
provide("src.mods.Runtime", {
  wantsHook = function() return false end,
  wants = function() return false end,
})

local FirstPerson = {
  MOVE_DEAD = 0.25,
  engaged = function() return true end,
  moveWorld = function(x, z) return x, z end,
  pointBody = function() return "right" end,
  releaseBody = function() end,
  lookFlat = function() return 1, 0 end,
}
local Voxel = { level = 6, isFirstPerson = function() return true end }
local V = { require = function(name)
  if name == "FirstPerson" then return FirstPerson end
  if name == "VoxelState" then return Voxel end
  error("unexpected sibling: " .. tostring(name))
end }

local Controls = assert(loadfile("lib/Gen2FreeMove.lua"))(V)
assert(Controls.install())

local map = { id = "ROUTE_30" }
function map:inBounds() return true end
function map:isWalkable() return true end
function map:cellCollision() return 0 end

local input = { stickAxis = { x = 0, y = 0 } }
function input:isDown(key) return key == "right" end
local world = setmetatable({
  map = map, entities = {}, neighbors = {},
  game = { pipelineGate = function(self) return self.world, self.world end },
  player = { cellX = 2, cellY = 2, px = 34.4, py = 32,
    moving = false, facing = "right", animClock = 0, stepFlip = false },
}, { __index = World })
world.game.world = world
function world:busy() return false end
function world:playerCollision() return 0 end
function world:grassAt() return false end
function world:checkTrainerBattle() return false end
function world:clearWarpCooldownIfLeft() end
function world:checkWarpOnArrive() return false end
function world:tryCoordScript() return false end
function world:countStep() return false end
function world:tryWildEncounter() return false end

world:pollInput(input)
world:stepBody()
assert(world.player.px > 34.5,
  "a valid neighboring cell was still clamped as blocked")

for name, value in pairs(saved) do package.loaded[name] = value end
print("Gen 2 free movement runtime: ok")
