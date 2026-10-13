local now = 0
love = { timer = {getTime = function() return now end}, filesystem = {
  getInfo = function() return {} end,
  createDirectory = function() return true end,
  write = function() return nil, "disk full" end,
} }
local P = dofile("lib/Perf.lua")
P.RING = 8; P.setSegment("map:ROUTE_29")
for i = 1, 100 do now = i / 60; P.frame() end
assert(#P.frames == 8 and #P.segments[1].frames == 8)
for i = 1, 100 do P.setSegment("map:" .. i) end
assert(#P.segments == 64 and P.segments["map:1"] == nil)
local oldPrint = print; print = function() end
assert(not P.write("test"), "failed write must not report success")
print = oldPrint
print("PASS bounded frame/segment history and report write failure")
