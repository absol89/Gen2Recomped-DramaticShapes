-- Runtime seam test: a held direction must move Silver's player during the
-- wrapped World:pollInput call, while leaving the native grid poll untouched.

local old = {}
local function provide(name, value)
  old[name] = package.loaded[name]
  package.loaded[name] = value
end

local basePolls = 0
local World = {}
function World:pollInput()
  basePolls = basePolls + 1
  self.heldDir = "down"
end
function World:stepBody() end

local Player = {}
function Player:walkPhase() return 0 end

provide("src.world.gen2.World", World)
provide("src.world.gen2.Player", Player)
provide("src.world.gen2.FieldMoves", {
  PLAYER_NORMAL = 0,
  isBiking = function() return false end,
  isSurfing = function() return false end,
})
provide("src.world.gen2.Permissions", {
  stepPermitted = function() return true end,
  currentDirection = function() return nil end,
  doorForcedDirection = function() return nil end,
  isIce = function() return false end,
  surfable = function() return nil end,
})
provide("src.mods.Runtime", {
  wantsHook = function() return false end,
  wants = function() return false end,
})

local driving = true
local FirstPerson = {
  driving = function() return driving end,
  bindGame = function() end,
  moveVector = function(input)
    assert(input.marker == "live", "pollInput did not pass its live input")
    return 0, 1
  end,
  moveWorld = function(x, z) return x, z end,
  pointBody = function() return "down" end,
  releaseBody = function() end,
  lookFlat = function() return 0, 1 end,
}
local Voxel = { level = 6, isFirstPerson = function() return true end }
local V = {
  require = function(name)
    if name == "FirstPerson" then return FirstPerson end
    if name == "VoxelState" then return Voxel end
    error("unexpected sibling " .. tostring(name))
  end,
}

local Controls = assert(loadfile("lib/Gen2FreeMove.lua"))(V)
assert(Controls.install())

local map = { id = "ROUTE_29" }
function map:inBounds(x, y) return x >= 0 and y >= 0 and x < 20 and y < 20 end
function map:isWalkable() return true end
function map:cellCollision() return 0 end

local input = { marker = "live" }
function input:isDown() return false end
local world = setmetatable({
  game = { input = input }, map = map, entities = {}, playerState = 0,
  player = { cellX = 2, cellY = 2, px = 32, py = 32, facing = "down",
             moving = false, animClock = 0, stepFlip = false },
}, { __index = World })
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
assert(basePolls == 0, "native grid poll also ran during the free walk")
assert(world.player.px == 32 and world.player.py == 33,
  "held free-camera input did not move Silver's player by one pixel")
assert(world._battleArtFreeMove == true, "free position was not adopted")

driving = false
world:pollInput(input)
assert(basePolls == 1, "native grid poll was not restored after leaving 1P/3P")
assert(world.player.px == 32 and world.player.py == 32,
  "leaving free movement did not snap cleanly back to the logical cell")

for name, value in pairs(old) do package.loaded[name] = value end
print("Gen 2 free movement runtime: ok")
