local file = assert(io.open("lib/FreeMove.lua", "rb"))
local source = assert(file:read("*a")); file:close()

assert(not source:find("p.moving = true", 1, true)
  and not source:find("p.moving = false", 1, true),
  "free movement writes Player.moving and can enter native grid interpolation")
assert(source:find("p.animClock = (p.animClock or 0) + 1", 1, true),
  "1ST/3RD free movement does not advance the native walk clock")
assert(source:find("p.walkPhase = function", 1, true)
  and source:find("if engineWalkPhase then return engineWalkPhase(self) end", 1, true),
  "free movement does not provide a safe visual phase with an overhead fallback")
assert(source:find("visualMoving = false", 1, true),
  "free movement does not return the player to an idle pose")

print("free movement walkcycle regression: ok")
