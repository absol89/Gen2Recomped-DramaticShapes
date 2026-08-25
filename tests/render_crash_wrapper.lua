local f = assert(io.open("main.lua", "rb"))
local main = f:read("*a")
f:close()

local wrapper = assert(main:find("local function captureRenderCrash(body)",
                                 1, true))
local draw = assert(main:find("drawWorld = function(ctx)", wrapper, true))
assert(main:find("local ok, result = xpcall(body", wrapper, true) < draw,
  "render crash wrapper does not execute the world renderer")
assert(main:find("return captureRenderCrash(function()", draw, true),
  "world renderer is no longer protected by crash capture")
assert(main:find('pcall(cache.write, cache, "render_crash.txt"',
                 wrapper, true) < draw,
  "render failures are not persisted outside playthrough storage")
assert(main:find('writeWorldProbe("decline_"', draw, true),
  "nil Silver world frames have no one-shot readiness diagnostic")

print("render crash wrapper: ok")
