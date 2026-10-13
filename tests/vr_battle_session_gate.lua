-- Execute production battle setting gates without graphics/runtime dependencies.
local active, enabled = false, true
local settings = { ModSetting = { new = function(_, _, values)
  return { value = values[1], get = function(self) return self.value end }
end } }
local V = { require = function(name)
  if name == "VR" then return {
    enabled = function() return enabled end, active = function() return active end,
  } end
  return settings[name] or {}
end }
local f = assert(io.open("lib/OverworldBattle.lua")); local source = f:read("*a"); f:close()
-- Keep the real imports and setting methods; omit installation and render code.
local stop = assert(source:find("-- Whether a pic is", 1, true))
local M = assert(loadstring(source:sub(1, stop - 1) .. "\nreturn OverworldBattle"))(V)
M.setting.value = false
assert(not M.enabled(), "stored VR ON must not force staged battles without a session")
M.setting.value = true; M.backSetting.value = true
assert(M.backPinned(), "inactive VR must retain desktop back sprites")
active = true
assert(M.enabled() and not M.backPinned(), "live headset must force world battlers")
active = false; enabled = false; M.setting.value = false
assert(not M.enabled(), "desktop OFF fallback")
print("PASS VR enabled/inactive, active, stopped and desktop battle settings")
