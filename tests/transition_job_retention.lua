-- Run production setLive: keep completed history, cancel obsolete queued work.
local f = assert(io.open("lib/ChunkMesher.lua")); local source = f:read("*a"); f:close()
local body = assert(source:match("(function ChunkMesher.setLive.-)\n%-%-"))
local released, invalidated = {}, {}
local oldJob = { id = "OLD_NEIGHBOR", slot = "body" }
local currentJob = { id = "CITY", slot = "full" }
local jobs = {oldJob, currentJob}
local index = { ["OLD_NEIGHBOR:body"] = oldJob, ["CITY:full"] = currentJob }
local cache = {OLD_NEIGHBOR = {}, CITY = {}, FAR = {}}
local env = setmetatable({
  ChunkMesher = {}, cache = cache, jobs = jobs, jobIndex = index,
  prevLive = {OLD_NEIGHBOR = true}, gen = {},
  CacheTrace = {log = function() end},
  Structures = {invalidate = function(id) invalidated[id] = true end},
  releaseEntry = function(c) released[c] = true end,
  jobKey = function(id, slot) return id .. ":" .. slot end,
}, {__index = _G})
local chunk = assert(loadstring(body)); setfenv(chunk, env); chunk()
env.ChunkMesher.setLive({CITY = true})
assert(cache.OLD_NEIGHBOR and cache.CITY and not cache.FAR)
assert(not invalidated.OLD_NEIGHBOR and invalidated.FAR)
assert(#jobs == 1 and jobs[1] == currentJob and not index["OLD_NEIGHBOR:body"])
env.ChunkMesher.setLive({NEXT_ROUTE = true})
assert(cache.CITY and not cache.OLD_NEIGHBOR and #jobs == 0)
print("PASS transition retains finished previous meshes and cancels invisible queued neighbors")
