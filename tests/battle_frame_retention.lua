local function source(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local battle = source("lib/OverworldBattle.lua")
assert(battle:find("if not (shot and shot.canvas) then return end", 1, true),
  "a transient empty battle render can discard the last composed frame")
assert(battle:find("handoffShot = session.shot", 1, true),
  "battle teardown does not retain its last composed frame")
assert(battle:find("function OverworldBattle.handoff()", 1, true),
  "the world pipeline cannot consume the retained battle frame")

local main = source("main.lua")
local empty = assert(main:find("if not canvas then", 1, true))
assert(main:find("return OverworldBattle.handoff()", empty, true),
  "an unready Silver world still falls straight through to native 2D")
assert(main:find("OverworldBattle.worldReady()", empty, true),
  "the battle handoff is not released after the voxel world is ready")

print("battle frame retention: ok")
