local function read(path)
  local f = assert(io.open(path, "rb"))
  local text = f:read("*a")
  f:close()
  return text
end

local first = read("lib/FirstPerson.lua")
local third = read("lib/ThirdPerson.lua")

assert(first:find('if Game.world and Game.world.map then', 1, true),
  "free-camera ownership does not recognize Silver's world")
assert(first:find('local gateTop, world = Game:pipelineGate()', 1, true),
  "Silver free-camera input does not use its supported pipeline gate")
assert(first:find('local world = Game.world or Game.overworld', 1, true),
  "camera entry facing is still Gen1-only")
assert(first:find('local wantCapture = engagedNow and FirstPerson.onTop()', 1, true),
  "relative mouse capture is not tied to live Silver free roam")
assert(third:find('return Game.world or Game.overworld', 1, true),
  "third-person boom collision is still Gen1-only")

print("Gen 2 free camera: ok")
