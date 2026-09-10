-- Stable read-only diagnostics provider for external performance monitors.
--
-- Battle Art owns domain-specific counters; the standalone monitor owns
-- capture cadence, aggregation, reporting and UI. Consumers must not depend on
-- this mod's private files or V.require namespace.

local V = ...

local M = {
  API_VERSION = 1,
  SCHEMA_VERSION = 1,
  SOURCE_MOD_ID = "BATTLE_ART_VOXEL_GEN2",
}

local function clock()
  if love and love.timer and love.timer.getTime then return love.timer.getTime() end
  return os.clock()
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return nil end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    local copiedKey = type(key) == "table" and tostring(key) or key
    out[copiedKey] = copy(child, seen)
  end
  return out
end

local function call(module, method, fallback)
  local okModule, value = pcall(V.require, module)
  if not okModule or type(value) ~= "table" or type(value[method]) ~= "function" then
    return fallback
  end
  local ok, result = pcall(value[method])
  if not ok then return fallback end
  return result
end

function M.snapshot(hostVersion)
  return {
    apiVersion = M.API_VERSION,
    schemaVersion = M.SCHEMA_VERSION,
    sourceModId = M.SOURCE_MOD_ID,
    sourceVersion = tostring(hostVersion or "unknown"),
    monotonicSeconds = clock(),
    -- Gen2 2.1.x does not ship the Gen1 LoadTimings/Sapling/CommunityFlora
    -- instrumentation. Keep those optional domains empty and advertise that
    -- fact in capabilities instead of presenting invented zero measurements.
    timings = {},
    cache = {
      available = call("VoxelMeshDisk", "available", false) and true or false,
      precacheAvailable = call("VoxelMeshDisk", "precacheAvailable", false) and true or false,
      readOnly = call("VoxelMeshDisk", "cacheReadOnly", true) and true or false,
      ram = copy(call("VoxelMeshDisk", "ramStats", {})),
      trace = copy(call("CacheTrace", "snapshot", {})),
    },
    mesher = copy(call("ChunkMesher", "stats", {})),
    trees = {},
    shadow = copy(call("ShadowMap", "stats", {})),
    saplings = {},
  }
end

function M.export(hostVersion)
  hostVersion = tostring(hostVersion or "unknown")
  return {
    apiVersion = M.API_VERSION,
    schemaVersion = M.SCHEMA_VERSION,
    sourceModId = M.SOURCE_MOD_ID,
    sourceVersion = hostVersion,
    capabilities = {
      timings = 0,
      cache = 1,
      cacheTrace = 1,
      storage = 1,
      mesher = 1,
      trees = 0,
      shadow = 1,
      saplings = 0,
    },
    snapshot = function() return M.snapshot(hostVersion) end,
    storageSnapshot = function()
      return copy(call("VoxelMeshDisk", "stats", {}))
    end,
  }
end

return M
