-- Bounded session diagnostics. Structured counters are platform-neutral;
-- the text log remains desktop-only. Never affects cache decisions.
local Trace = {}
local started, bytes = false, 0
local path = "battleart-gen2-cache.log"
local sequence, counts, recent = 0, {}, {}
local MAX_RECENT = 64

local function record(event, map, detail)
  sequence = sequence + 1
  event = tostring(event or "unknown")
  counts[event] = (counts[event] or 0) + 1
  recent[#recent + 1] = {
    sequence = sequence,
    event = event,
    map = tostring(map or "*"),
    detail = tostring(detail or ""):sub(1, 512),
    at = love and love.timer and love.timer.getTime and love.timer.getTime() or 0,
  }
  if #recent > MAX_RECENT then table.remove(recent, 1) end
end

function Trace.enabled()
  if not (love and love.system and love.system.getOS) then return false end
  local ok, os = pcall(love.system.getOS)
  return ok and (os == "Windows" or os == "Linux" or os == "OS X")
end
function Trace.log(event, map, detail)
  pcall(record, event, map, detail)
  if not Trace.enabled() then return end
  pcall(function()
    local fs = love.filesystem
    if not started then
      started = true
      if fs and fs.write then fs.write(path, "BattleArtGen2 cache trace: new session\n") end
      print("[BAV2 cache] log: " .. ((fs and fs.getSaveDirectory and fs.getSaveDirectory()) or "") .. "/" .. path)
    end
    local now = love.timer and love.timer.getTime and love.timer.getTime() or 0
    local line = string.format("[BAV2 cache %.3f] %s map=%s %s\n", now,
      tostring(event), tostring(map or "*"), tostring(detail or ""))
    print(line:sub(1,-2))
    if fs and fs.append then
      if bytes + #line > 4 * 1024 * 1024 then
        if fs.read and fs.write then
          local old = fs.read(path)
          if old then fs.write("battleart-gen2-cache.previous.log", old) end
          fs.write(path, "Trace continued after rotation\n")
        end
        bytes = 0
      end
      fs.append(path, line)
      bytes = bytes + #line
    end
  end)
end

function Trace.snapshot()
  local copiedCounts = {}
  for event, count in pairs(counts) do copiedCounts[event] = count end
  local copiedRecent = {}
  for i, row in ipairs(recent) do
    copiedRecent[i] = {
      sequence = row.sequence, event = row.event, map = row.map,
      detail = row.detail, at = row.at,
    }
  end
  return { sequence = sequence, capacity = MAX_RECENT,
           counts = copiedCounts, recent = copiedRecent }
end

return Trace
