-- Standalone producer-contract regression for performance-monitor integration.
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

love = { timer = { getTime = function() return 12.5 end } }

local storageCalls = 0
local modules = {
  VoxelMeshDisk = {
    available = function() return true end,
    precacheAvailable = function() return true end,
    cacheReadOnly = function() return false end,
    stats = function()
      storageCalls = storageCalls + 1
      return { bytes = 456, files = 7, maps = 3 }
    end,
    ramStats = function() return { enabled = true, bytes = 99, files = 4, dirty = 1 } end,
  },
  CacheTrace = { snapshot = function()
    return { sequence = 5, counts = { ['disk-hit'] = 3 }, recent = {
      { sequence = 5, event = 'disk-hit', map = 'ECRUTEAK_CITY', detail = 'body' },
    } }
  end },
  ChunkMesher = { stats = function()
    return { pending = 2, unconsumedFailures = 1,
             queue = { current = 1, speculative = 1 } }
  end },
  ShadowMap = { stats = function() return { allocations = 2, size = 1536, active = true } end },
}

local V = { require = function(name) return assert(modules[name], name) end }
local P = assert(loadfile('lib/PerformanceExport.lua'))(V)
local api = P.export('2.1.2')

check(api.apiVersion == 1 and api.schemaVersion == 1, 'versioned provider contract')
check(api.sourceModId == 'BATTLE_ART_VOXEL_GEN2' and api.sourceVersion == '2.1.2',
      'provider identifies Gen2 producer')
check(api.capabilities.cacheTrace == 1 and api.capabilities.mesher == 1
      and api.capabilities.shadow == 1, 'provider advertises supported diagnostics')
check(api.capabilities.timings == 0 and api.capabilities.trees == 0
      and api.capabilities.saplings == 0, 'unsupported optional domains are explicit')

local s = api.snapshot()
check(s.monotonicSeconds == 12.5, 'snapshot timestamps at source')
check(s.cache.available and s.cache.precacheAvailable and not s.cache.readOnly,
      'cache capabilities are exported')
check(s.cache.ram.dirty == 1 and s.cache.trace.counts['disk-hit'] == 3,
      'RAM and structured cache telemetry are exported')
check(s.mesher.pending == 2 and s.mesher.unconsumedFailures == 1,
      'mesher queue/failure pressure is exported')
check(s.shadow.size == 1536 and s.shadow.allocations == 2,
      'shadow allocation state is exported')
check(next(s.timings) == nil and next(s.trees) == nil and next(s.saplings) == nil,
      'unsupported optional sections stay empty')
check(storageCalls == 0, 'hot snapshot never enumerates persistent storage')
check(api.storageSnapshot().files == 7 and storageCalls == 1,
      'persistent storage inventory is explicit and low-cadence')

s.cache.trace.counts['disk-hit'] = 999
s.mesher.queue.current = 999
local fresh = api.snapshot()
check(fresh.cache.trace.counts['disk-hit'] == 3, 'cache trace is detached')
check(fresh.mesher.queue.current == 1, 'mesher state is detached')

print(checks .. ' checks passed (Gen2 performance export API)')
