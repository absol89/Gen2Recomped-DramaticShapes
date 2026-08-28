local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = assert(file:read("*a"))
  file:close()
  return source
end

local firstPerson = read("lib/FirstPerson.lua")
local camControl = read("lib/CamControl.lua")

assert(not firstPerson:find("love.mousemoved =", 1, true)
  and not firstPerson:find("love.mousepressed =", 1, true)
  and not firstPerson:find("love.mousereleased =", 1, true)
  and not camControl:find("love.mousemoved =", 1, true),
  "camera input still assigns a sandbox-owned LOVE mouse callback")
assert(firstPerson:find('V.mod.hooks:wrap("input.pointer"', 1, true),
  "first-person mouse look is not registered through input.pointer")
assert(camControl:find('V.mod.hooks:wrap("input.pointer"', 1, true),
  "battle-camera mouse input is not registered through input.pointer")
assert(firstPerson:find('ev.phase == "moved"', 1, true)
  and firstPerson:find('ev.source == "mouse"', 1, true),
  "first-person pointer hook does not limit itself to mouse motion")
assert(firstPerson:find('ev.phase == "pressed"', 1, true)
  and firstPerson:find('ev.phase == "released"', 1, true)
  and firstPerson:find('ev.phase == "cancelled"', 1, true),
  "first-person pointer hook does not own the complete mouse-button lifecycle")
assert(camControl:find('ev.phase == "moved"', 1, true)
  and camControl:find('ev.source == "mouse"', 1, true),
  "battle-camera pointer hook does not limit itself to mouse motion")

print("camera pointer-input regression: ok")
