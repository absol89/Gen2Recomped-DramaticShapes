-- Camera-relative continuous movement for Gold/Silver's voxel free cameras.
-- Gen2 keeps its World outside the state stack and has different movement
-- seams from Gen1, so lib/FreeMove.lua cannot safely own this generation.

local V = ...
local FirstPerson = V.require("FirstPerson")
local Voxel = V.require("VoxelState")

local Controls = {
  installed = false,
  freeFrames = 0,
  freeCells = 0,
  wallSlides = 0,
  specialHandoffs = 0,
}

Controls.RADIUS = 5.5
Controls.WALK_SPEED = 1.0
local EPS = 0.01
local unpackResults = (table and table.unpack) or unpack

local FieldMoves, Permissions, Runtime
local DIRS = { "down", "right", "up", "left" }
local SCORE = {
  right = function(x, z) return x end,
  left = function(x, z) return -x end,
  down = function(x, z) return z end,
  up = function(x, z) return -z end,
}
local DELTA_DIR = {
  ["1,0"] = "right", ["-1,0"] = "left",
  ["0,1"] = "down", ["0,-1"] = "up",
}

local function direction(x, z, previous)
  if math.abs(x) < 1e-6 and math.abs(z) < 1e-6 then return nil end
  local best, score = nil, -math.huge
  for _, dir in ipairs(DIRS) do
    local s = SCORE[dir](x, z)
    if s > score then best, score = dir, s end
  end
  if previous and SCORE[previous] then
    local old = SCORE[previous](x, z)
    if old > 0 and old >= score - 0.1 then best = previous end
  end
  return best
end

local function safeBusy(world)
  if type(world.busy) ~= "function" then return false end
  local ok, busy = pcall(world.busy, world)
  return ok and busy or false
end

-- Silver's live game is the instance owned by World; src.core.Game is the
-- separate Gen-1 singleton. Read Game2's own pipeline gate here so movement
-- ownership cannot accidentally depend on the wrong state stack.
local function driving(world)
  if not (FirstPerson.engaged() and world and world.game) then return false end
  local game = world.game
  if type(game.pipelineGate) == "function" then
    local ok, top, live = pcall(game.pipelineGate, game)
    return ok and top == world and live == world
  end
  local top = game.stack and game.stack.top and game.stack:top() or nil
  return top == nil and game.world == world
end

-- World:pollInput already hands us the live Gen-2 Input instance. Preserve
-- the original free camera's analog/key priority without reaching sideways
-- into Gen 1's Game.input singleton.
local function moveVector(input)
  local dead = FirstPerson.MOVE_DEAD or 0.25
  local axis = input and input.stickAxis or nil
  if axis then
    local mag = math.sqrt(axis.x * axis.x + axis.y * axis.y)
    if mag > dead then
      local amount = math.min(1, (mag - dead) / (1 - dead))
      return axis.x / mag * amount, -axis.y / mag * amount
    end
  end
  if input and type(input.isDown) == "function" then
    local x = (input:isDown("right") and 1 or 0)
      - (input:isDown("left") and 1 or 0)
    local z = (input:isDown("up") and 1 or 0)
      - (input:isDown("down") and 1 or 0)
    local mag = math.sqrt(x * x + z * z)
    if mag > 0 then return x / mag, z / mag end
  end
  return 0, 0
end

local function collisionOf(world)
  if type(world.playerCollision) ~= "function" then return nil end
  local ok, collision = pcall(world.playerCollision, world)
  return ok and collision or nil
end

local function nativeSpecial(world)
  if not (world and world.player) then return true end
  if FieldMoves.isBiking(world.playerState)
     or FieldMoves.isSurfing(world.playerState) then return true end
  local c = collisionOf(world)
  if c ~= nil then
    if type(Permissions.isIce) == "function" and Permissions.isIce(c) then
      return true
    end
    if type(Permissions.currentDirection) == "function"
       and Permissions.currentDirection(c) then return true end
    if type(Permissions.doorForcedDirection) == "function"
       and Permissions.doorForcedDirection(c) then return true end
  end
  return false
end

local function eligible(world)
  return driving(world) and world and world.map and world.player
    and not nativeSpecial(world)
end

local function tickEligible(world)
  local p = world and world.player
  return eligible(world) and p and not p.moving and not safeBusy(world)
    and not world.mapSetup and not world.moveState and not world.fieldMove
    and not world.fishing and not world.headbutt
end

local function clear(world, snap)
  if not world then return end
  local p = world.player
  if snap and p and not p.moving and world._battleArtFreeMove then
    p.px, p.py = p.cellX * 16, p.cellY * 16
  end
  world._battleArtFreeMove = nil
  world._battleArtFreeX, world._battleArtFreeZ = nil, nil
  world._battleArtFreeMap = nil
  world._battleArtIntentX, world._battleArtIntentZ = nil, nil
  world._battleArtAnimDistance = nil
  world._battleArtVisualMoving = nil
  FirstPerson.releaseBody()
end

local function adopt(world)
  local p = world.player
  world._battleArtFreeX = (tonumber(p.px) or p.cellX * 16) + 8
  world._battleArtFreeZ = (tonumber(p.py) or p.cellY * 16) + 8
  world._battleArtFreeMap = world.map and world.map.id
  world._battleArtFreeMove = true
  world._battleArtVisualMoving = false
  -- The free walk moves px/py directly: Player.moving never sets, so
  -- the class walkPhase answers 0 forever and the billboard glides
  -- frozen. Give this player INSTANCE a phase reading the free walk's
  -- own movement flag; the engine's grid walk is untouched (setting
  -- .moving here crashes Player:update, whose interpolation needs
  -- target cells free move does not keep).
  if not p._battleArtWalkPhase then
    p._battleArtWalkPhase = true
    -- Keep the engine's native walkPhase so the grid (2D / voxel-off /
    -- partial-voxel) overworld still animates its steps. The free walk never
    -- sets Player.moving, so the engine's own phase reads 0 while free-move
    -- is active -- in that case drive the step from the free walk's own
    -- animClock + visual-moving flag instead. Without this fallback the
    -- override would hard-return 0 forever once installed, freezing the
    -- player's walk animation in every non-free-move mode.
    local engineWalkPhase = p.walkPhase
    p.walkPhase = function(self)
      if world._battleArtFreeMove and world._battleArtVisualMoving then
        return ((self.animClock or 0) % 8 >= 4) and 1 or 0
      end
      if engineWalkPhase then return engineWalkPhase(self) end
      return 0
    end
  end
end

local function entityBlocked(world, p, cx, cy)
  if type(world.npcAt) == "function" then
    local ok, npc = pcall(world.npcAt, world, cx, cy)
    if ok and npc and npc ~= p and not npc.passable then return true end
  end
  for _, e in ipairs(world.entities or {}) do
    if e ~= p and not e.passable
       and ((e.cellX == cx and e.cellY == cy)
         or (e.moving and e.targetX == cx and e.targetY == cy)) then
      return true
    end
  end
  return false
end

local function permitted(world, p, cx, cy)
  local dir = DELTA_DIR[tostring(cx - p.cellX) .. "," .. tostring(cy - p.cellY)]
  if not dir or type(Permissions.stepPermitted) ~= "function" then return true end
  local ok, allowed = pcall(Permissions.stepPermitted,
    function(x, y) return world.map:cellCollision(x, y) end,
    p.cellX, p.cellY, dir)
  return not ok or allowed ~= false
end

local function collisionHook(world, p, allowed, reason, cx, cy)
  if not (Runtime and type(Runtime.wantsHook) == "function"
      and Runtime.wantsHook("movement.collision")) then
    return allowed, reason
  end
  local dir = DELTA_DIR[tostring(cx - p.cellX) .. "," .. tostring(cy - p.cellY)]
    or direction(cx - p.cellX, cy - p.cellY)
  local ctx = { map = world.map, mover = p, dir = dir,
    fromX = p.cellX, fromY = p.cellY, toX = cx, toY = cy, reason = reason }
  local ok, result = pcall(Runtime.call, "movement.collision",
    function(v) return v end, allowed, ctx)
  if ok then return result and true or false, ctx.reason end
  return allowed, reason
end

local function blockedCell(world, p, cx, cy)
  if cx == p.cellX and cy == p.cellY then return nil end
  if not world.map:inBounds(cx, cy) then return "bounds" end
  local allowed = world.map:isWalkable(cx, cy) and permitted(world, p, cx, cy)
  local reason = allowed and nil or "tile"
  if allowed and entityBlocked(world, p, cx, cy) then
    allowed, reason = false, "entity"
  end
  allowed, reason = collisionHook(world, p, allowed, reason, cx, cy)
  if allowed then return nil end
  return reason or "tile"
end

local function slideX(world, p, dx)
  if dx == 0 then return nil end
  local r, x, z = Controls.RADIUS, world._battleArtFreeX, world._battleArtFreeZ
  local nx = x + dx
  local edge = dx > 0 and math.floor((nx + r) / 16)
    or math.floor((nx - r) / 16)
  local hit
  for cz = math.floor((z - r + EPS) / 16), math.floor((z + r - EPS) / 16) do
    hit = blockedCell(world, p, edge, cz)
    if hit then break end
  end
  if hit then
    nx = dx > 0 and math.min(nx, edge * 16 - r - EPS)
      or math.max(nx, (edge + 1) * 16 + r + EPS)
  end
  world._battleArtFreeX = nx
  return hit
end

local function slideZ(world, p, dz)
  if dz == 0 then return nil end
  local r, x, z = Controls.RADIUS, world._battleArtFreeX, world._battleArtFreeZ
  local nz = z + dz
  local edge = dz > 0 and math.floor((nz + r) / 16)
    or math.floor((nz - r) / 16)
  local hit
  for cx = math.floor((x - r + EPS) / 16), math.floor((x + r - EPS) / 16) do
    hit = blockedCell(world, p, cx, edge)
    if hit then break end
  end
  if hit then
    nz = dz > 0 and math.min(nz, edge * 16 - r - EPS)
      or math.max(nz, (edge + 1) * 16 + r + EPS)
  end
  world._battleArtFreeZ = nz
  return hit
end

local function landingEvents(world, p)
  if type(world.grassAt) == "function" then
    p.inGrass = world:grassAt(p.cellX, p.cellY)
    p.grassShake = p.inGrass or nil
  end
  if type(world.checkTrainerBattle) == "function"
     and world:checkTrainerBattle() then return true end
  if Runtime and type(Runtime.wants) == "function"
     and Runtime.wants("world.stepped") then
    Runtime.emit("world.stepped", { mapId = world.map.id,
      x = p.cellX, y = p.cellY, tile = world.map:cellCollision(p.cellX, p.cellY),
      tod = world.tod, daytime = world.daytime })
  end
  if type(world.clearWarpCooldownIfLeft) == "function" then
    world:clearWarpCooldownIfLeft()
  end
  if type(world.checkWarpOnArrive) == "function"
     and world:checkWarpOnArrive() then return true end
  if not world.map then return true end
  if type(world.tryCoordScript) == "function" and world:tryCoordScript() then
    return true
  end
  if type(world.countStep) == "function" and world:countStep() then return true end
  if type(world.tryWildEncounter) == "function"
     and world:tryWildEncounter() then return true end
  return false
end

local function forcedHandoff(world, p)
  local c = collisionOf(world)
  if c == nil then return false end
  local forced = (type(Permissions.currentDirection) == "function"
      and Permissions.currentDirection(c))
    or (type(Permissions.doorForcedDirection) == "function"
      and Permissions.doorForcedDirection(c))
  local ice = type(Permissions.isIce) == "function" and Permissions.isIce(c)
  if not (forced or ice) then return false end
  p.px, p.py = p.cellX * 16, p.cellY * 16
  if ice then world.turningDirection = p.facing end
  clear(world, false)
  Controls.specialHandoffs = Controls.specialHandoffs + 1
  return true
end

local function blockedSpecial(world, p, dir, why)
  if not dir then return false end
  p.facing = dir
  if why == "bounds" and type(world.tryConnection) == "function"
     and world:tryConnection(dir) then
    clear(world, false); Controls.specialHandoffs = Controls.specialHandoffs + 1
    return true
  end
  if why == "tile" and type(world.tryLedgeJump) == "function"
     and world:tryLedgeJump(dir) then
    clear(world, false); Controls.specialHandoffs = Controls.specialHandoffs + 1
    return true
  end
  if why == "entity" and type(world.tryPushBoulder) == "function" then
    local d = ({ up={0,-1}, down={0,1}, left={-1,0}, right={1,0} })[dir]
    if d and world:tryPushBoulder(dir, p.cellX + d[1], p.cellY + d[2]) then
      clear(world, false); Controls.specialHandoffs = Controls.specialHandoffs + 1
      return true
    end
  end
  return false
end

local function freeTick(world)
  local p = world.player
  if world._battleArtFreeMap ~= (world.map and world.map.id)
     or world._battleArtFreeX == nil then adopt(world) end
  local wx = tonumber(world._battleArtIntentX) or 0
  local wz = tonumber(world._battleArtIntentZ) or 0
  local mag = math.sqrt(wx * wx + wz * wz)
  if mag > 1 then wx, wz, mag = wx / mag, wz / mag, 1 end
  if mag <= 1e-6 then world._battleArtVisualMoving = false return end

  p.facing = FirstPerson.pointBody(wx, wz)
  p.animClock = (p.animClock or 0) + 1
  local dx, dz = wx * Controls.WALK_SPEED, wz * Controls.WALK_SPEED
  local ox, oz = world._battleArtFreeX, world._battleArtFreeZ
  local hitX, hitZ = slideX(world, p, dx), slideZ(world, p, dz)
  if hitX or hitZ then Controls.wallSlides = Controls.wallSlides + 1 end
  local mx, mz = world._battleArtFreeX - ox, world._battleArtFreeZ - oz
  local moved = math.sqrt(mx * mx + mz * mz)
  world._battleArtVisualMoving = moved > 0.01
  world._battleArtAnimDistance = (world._battleArtAnimDistance or 0) + moved
  while world._battleArtAnimDistance >= 16 do
    world._battleArtAnimDistance = world._battleArtAnimDistance - 16
    p.stepFlip = not p.stepFlip
  end
  p.px, p.py = world._battleArtFreeX - 8, world._battleArtFreeZ - 8
  Controls.freeFrames = Controls.freeFrames + 1

  local cx, cy = math.floor(world._battleArtFreeX / 16),
                       math.floor(world._battleArtFreeZ / 16)
  if cx ~= p.cellX or cy ~= p.cellY then
    p.cellX, p.cellY = cx, cy
    Controls.freeCells = Controls.freeCells + 1
    local held = world.heldDir
    world.heldDir = p.facing
    local taken = landingEvents(world, p)
    world.heldDir = held
    if taken then clear(world, false) return end
    if forcedHandoff(world, p) then return end
  end

  local why, dir
  if hitX and (not hitZ or math.abs(dx) >= math.abs(dz)) then
    why, dir = hitX, dx > 0 and "right" or "left"
  elseif hitZ then
    why, dir = hitZ, dz > 0 and "down" or "up"
  end
  if why and moved < Controls.WALK_SPEED * 0.75 then
    if blockedSpecial(world, p, dir, why) then return end
    p.facing = FirstPerson.pointBody(wx, wz)
  end
end

function Controls.install()
  if Controls.installed then return true end
  local okW, World = pcall(require, "src.world.gen2.World")
  local okF, F = pcall(require, "src.world.gen2.FieldMoves")
  local okP, P = pcall(require, "src.world.gen2.Permissions")
  local okR, R = pcall(require, "src.mods.Runtime")
  if not (okW and okF and okP and okR and type(World) == "table") then
    return false, "Gold/Silver movement dependencies unavailable"
  end
  FieldMoves, Permissions, Runtime = F, P, R
  if type(World.pollInput) ~= "function" or type(World.stepBody) ~= "function" then
    return false, "Gold/Silver movement seams unavailable"
  end
  if World.battleArtTrueDirectionalControlsHook then
    Controls.installed = true
    return true
  end

  local pollInput = World.pollInput
  function World:pollInput(input)
    local out = pollInput(self, input)
    if not driving(self) then
      self._battleArtIntentX, self._battleArtIntentZ = nil, nil
      return out
    end
    local mx, mz = moveVector(input)
    local wx, wz = FirstPerson.moveWorld(mx, mz)
    if eligible(self) then
      self._battleArtIntentX, self._battleArtIntentZ = wx, wz
      self.heldDir = nil
    elseif mx ~= 0 or mz ~= 0 then
      self.heldDir = direction(wx, wz, self.heldDir)
    end
    return out
  end

  local stepBody = World.stepBody
  function World:stepBody(...)
    local out = { stepBody(self, ...) }
    if tickEligible(self) then
      freeTick(self)
    else
      clear(self, self.player and not self.player.moving)
    end
    return unpackResults(out)
  end

  if type(World.interact) == "function" then
    local interact = World.interact
    function World:interact(...)
      if driving(self) and Voxel.isFirstPerson(Voxel.level)
         and self.player and not self.player.moving then
        local sx, sz = FirstPerson.lookFlat()
        local dir = direction(sx, sz)
        if dir then self.player.facing = dir end
      end
      return interact(self, ...)
    end
  end

  World.battleArtTrueDirectionalControlsHook = true
  Controls.installed = true
  return true
end

function Controls.release(world)
  if not world then
    local ok, Game = pcall(require, "src.core.Game")
    world = ok and Game and Game.world or nil
  end
  clear(world, true)
end

return Controls
