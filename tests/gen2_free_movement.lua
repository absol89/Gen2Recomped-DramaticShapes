local function read(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local main = read("main.lua")
local move = read("lib/Gen2FreeMove.lua")
local first = read("lib/FirstPerson.lua")

assert(main:find('if V.generation() == 2 then', 1, true),
  "Silver does not select its own movement bridge")
assert(main:find('V.require("Gen2FreeMove")', 1, true),
  "Silver free movement is not installed")
assert(move:find('function World:pollInput(input)', 1, true),
  "camera-relative intent does not enter through Gold pollInput")
assert(move:find('freeTick(self)', 1, true),
  "continuous movement does not run at Gold's pollInput choke point")
assert(not move:find('function World:stepBody(...)', 1, true),
  "Silver free movement is still split across the post-update body hook")
assert(move:find('FirstPerson.moveWorld(mx, mz)', 1, true),
  "movement intent is not rotated by camera yaw")
assert(move:find('FirstPerson.bindGame(self.game)', 1, true),
  "Silver's World does not lend the live Game2 instance to the camera")
assert(move:find('FirstPerson.moveVector(input)', 1, true),
  "Silver movement does not read the input passed to World:pollInput")
assert(first:find('Game = require("src.core.Game2")', 1, true),
  "Silver camera handlers are still installed on the Gen-1 game singleton")
assert(first:find('local Game = currentGame()', 1, true),
  "camera ownership does not consult Silver's bound live game")
assert(move:find('landingEvents(world, p)', 1, true),
  "cell crossings do not replay Gold landing events")
assert(move:find('world:tryConnection(dir)', 1, true)
   and move:find('world:tryLedgeJump(dir)', 1, true)
   and move:find('world:tryPushBoulder', 1, true),
  "native special-movement handoffs are incomplete")

print("Gen 2 free movement: ok")
