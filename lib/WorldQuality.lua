-- Adapted from UNDERdecoded 4a114b3 Tier.lua. Optional host service;
-- no version thresholds, platform guesses, or writes to saved settings.
local V = ...
local Scope = V.require('WorldRenderScope')
local Quality = {}
local tried, performance
local CAPS = {
  high = {},
  balanced = {shadowRes = 1024, water = 1, aa = 2},
  low = {shadows = false, water = 0, aa = 0},
}
function Quality.name(world)
  if not world and not Scope.active() then return 'high' end
  if not tried then
    tried = true
    local ok, service = pcall(require, 'src.core.Performance')
    if ok and type(service) == 'table' then performance = service end
  end
  local name = performance and performance.tier
  return CAPS[name] and name or 'high'
end
function Quality.caps(world) return CAPS[Quality.name(world)] end
function Quality.clamp(key, value, world)
  local cap = Quality.caps(world)[key]
  return type(cap) == 'number' and math.min(value, cap) or value
end
return Quality
