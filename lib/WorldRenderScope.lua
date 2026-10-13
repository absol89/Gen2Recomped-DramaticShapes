-- World-only feature scope. Shared renderer modules retain battle behavior.
local Scope = {}
local active = false
function Scope.active() return active end
function Scope.run(enabled, fn, ...)
  local previous = active
  active = enabled == true
  local ok, result = pcall(fn, ...)
  active = previous
  if not ok then error(result, 0) end
  return result
end
return Scope
