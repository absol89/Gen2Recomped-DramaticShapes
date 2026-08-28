local file = assert(io.open("lib/FreeMove.lua", "rb"))
local source = assert(file:read("*a")); file:close()

assert(source:find("p.moving = true", 1, true),
  "1ST/3RD free movement does not enter the native walking pose")
assert(source:find("p.animClock = (p.animClock or 0) + 1", 1, true),
  "1ST/3RD free movement does not advance the native walk clock")
assert(source:find("p.moving = false", 1, true)
  and source:find("p.animClock = 0", 1, true),
  "free movement does not return the player to an idle pose")
assert(not source:find("p.walkPhase = function", 1, true),
  "the native 2D/partial-voxel walkPhase was overridden")

print("free movement walkcycle regression: ok")
