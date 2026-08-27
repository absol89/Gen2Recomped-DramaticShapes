-- The Gen1Recomp cache backend changes at the 0.1.83/0.1.84 boundary.

package.preload["src.core.Version"] = function()
  return { engine = "0.1.84" }
end
package.preload["src.core.Platform"] = function()
  return { detect = function() return { os = "Windows" } end }
end

local legacyBytes = {}
love.filesystem = {
  getDirectoryItems = function() return {} end,
  getInfo = function(path)
    return legacyBytes[path] and { size = #legacyBytes[path] } or nil
  end,
  read = function(path) return legacyBytes[path] end,
  write = function(path, value) legacyBytes[path] = value; return true end,
  createDirectory = function() return true end,
}

local scopedBytes = {}
local function scopeId(scope)
  return scope and scope.save and scope.save.version or "unscoped"
end
local storage = {}
function storage:list(scope, prefix)
  local out, values = {}, scopedBytes[scopeId(scope)] or {}
  for key in pairs(values) do
    if key:sub(1, #prefix) == prefix then out[#out + 1] = key end
  end
  return out
end
function storage:readBytes(scope, key)
  return (scopedBytes[scopeId(scope)] or {})[key]
end
function storage:writeBytes(scope, key, value)
  local id = scopeId(scope)
  scopedBytes[id] = scopedBytes[id] or {}
  scopedBytes[id][key] = value
  return true
end

local V = { mod = { storage = storage } }
function V.require(name)
  return assert(({ BuildBudget = { check = function() end },
                   StaticGeometry = {} })[name], name)
end

local Disk = assert(loadfile("lib/VoxelMeshDisk.lua"))(V)
local function policy(version, expectedBackend)
  local allowed, backend = Disk.precachePolicy(version, "Windows")
  assert(allowed and backend == expectedBackend,
    ("wrong policy for %s: %s"):format(version, tostring(backend)))
end

policy("0.1.82", "legacy")
policy("0.1.83", "legacy")
policy("0.1.84", "storage")
policy("0.2.20", "storage")
policy("0.7.34", "storage")

Disk._setCompatibilityForTests("0.1.83", "Windows")
assert(Disk.bind({ save = { version = "silver" } }, true),
  "0.1.83 did not bind the legacy filesystem")
assert(Disk.legacy() and Disk.precacheAvailable(),
  "0.1.83 did not expose writable legacy precaching")
assert(Disk.DIRECTORY:match("/silver$"),
  "legacy Silver cache was not version-scoped")

Disk._setCompatibilityForTests("0.1.84", "Windows")
assert(Disk.bind({ save = { version = "gold" } }, true),
  "0.1.84 did not bind mod.storage")
assert(not Disk.legacy() and Disk.precacheAvailable(),
  "0.1.84 did not expose writable byte-storage precaching")
assert(Disk.DIRECTORY:match("/gold$"),
  "modern Gold cache was not version-scoped")

Disk._setCompatibilityForTests(nil)
print("precache storage compatibility regression: ok")
