-- Adapted from upstream's shadow rate limit. Only moving-cast changes wait;
-- changes to the light/camera/terrain and invalidated shadow maps draw now.
local Cadence = {}
function Cadence.new()
  local last, age = nil, 0
  return {
    due = function(key, interval, valid)
      age = age + 1
      return not interval or interval <= 1 or not valid
        or key ~= last or age >= interval
    end,
    committed = function(key) last, age = key, 0 end,
  }
end
return Cadence
