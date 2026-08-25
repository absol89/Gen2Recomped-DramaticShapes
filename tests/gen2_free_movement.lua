local function read(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local main = read("main.lua")
local move = read("lib/Gen2FreeMove.lua")

assert(main:find('if V.generation() == 2 then', 1, true),
  "Silver does not select its own movement bridge")
assert(main:find('V.require("Gen2FreeMove")', 1, true),
  "Silver free movement is not installed")
assert(move:find('function World:pollInput(input)', 1, true),
  "camera-relative intent does not enter through Gold pollInput")
assert(move:find('function World:stepBody(...)', 1, true),
  "continuous movement does not tick through Gold stepBody")
assert(move:find('FirstPerson.moveWorld(mx, mz)', 1, true),
  "movement intent is not rotated by camera yaw")
assert(move:find('local function driving(world)', 1, true),
  "Silver movement ownership still depends on the Gen-1 game singleton")
assert(move:find('local function moveVector(input)', 1, true),
  "Silver movement does not read the live input passed to pollInput")
assert(move:find('if allowed then return nil end', 1, true),
  "allowed Silver cells still fall through to the blocked fallback")
assert(move:find('landingEvents(world, p)', 1, true),
  "cell crossings do not replay Gold landing events")
assert(move:find('world:tryConnection(dir)', 1, true)
   and move:find('world:tryLedgeJump(dir)', 1, true)
   and move:find('world:tryPushBoulder', 1, true),
  "native special-movement handoffs are incomplete")

print("Gen 2 free movement: ok")
