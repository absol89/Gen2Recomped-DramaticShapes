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

print("render crash wrapper: ok")
