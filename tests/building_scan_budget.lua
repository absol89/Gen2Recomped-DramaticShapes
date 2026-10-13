-- Production Buildings scan must yield between expensive rows, not every 32 rows.
local now = 0
love = {timer = {getTime = function() return now end}}
local B = dofile("lib/BuildBudget.lua")
local templates = {}
for i = 1, 10 do templates[i] = {tiles = {{999 + i}}} end
local profile = {buildings = {TEST = templates}}
local Buildings = assert(loadfile("lib/Buildings.lua"))({
  require = function() return B end,
  data = function() return profile end,
})
local reads = 0
local S = {objectQuads = {}, tileAt = setmetatable({}, {__index = function()
  now = now + .00005; reads = reads + 1; return 0
end})}
local map = {tileset = {id = "TEST"}, def = {width = 20, height = 20}}
local co = coroutine.create(function() Buildings.build(S, map, {}, 16) end)
local worst, resumes = 0, 0
repeat
  local start = now
  B.begin(co, .005)
  local ok, err = coroutine.resume(co)
  B.finish()
  assert(ok, err)
  worst = math.max(worst, now - start); resumes = resumes + 1
until coroutine.status(co) == "dead"
assert(reads == 6400 and #S.objectQuads == 0, "templates must share one map scan")
assert(resumes > 20 and worst < .012, "building row scan exceeded cooperative slice")
print("PASS ten production building templates share one scan, yield within 12ms and retain output")
