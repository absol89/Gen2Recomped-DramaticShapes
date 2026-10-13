-- Execute the production title hook and menu dispatcher across callback hosts.
-- Optional arg[1] selects an older main.lua to reproduce issue #3.
local f = assert(io.open(arg and arg[1] or "main.lua"))
local source = f:read("*a"); f:close()
local start = assert(source:find("-- Gen 1's title Menu executes", 1, true))
local stop = assert(source:find("-- Runtime misses stay in RAM", start, true))
local hook, eager, preload, ready = nil, true, true, true
local choice, sessions, created = nil, 0, 0
local MainMenu = {choose = function(self, value) choice = value; self.phase = "confirm" end}
local current
local game = {data = {}, save = {}, stack = {
  top = function() return current end,
  push = function(_, screen) current = screen end,
}}
local env = setmetatable({
  require = function(name) assert(name == "src.ui.gen2.MainMenu"); return MainMenu end,
  mod = {hooks = {wrap = function(_, name, callback)
    assert(name == "ui.title_menu.items"); hook = callback
  end}},
  VoxelMeshDisk = {
    bind = function() end, available = function() return true end,
    beginSession = function() sessions = sessions + 1 end,
    eagerLoadAllowed = function() return eager end, setRamBudget = function() end,
    ramPlan = function() return {"saved-area"} end,
    ramReady = function() return ready end,
    precacheAvailable = function() return false end,
  },
  applyRamPrecacheBudget = function() return preload end,
  VoxelPrecache = {startupMapIds = function() return {"NEW_BARK_TOWN"} end},
  VoxelCacheRamScreen = {new = function(_, resume) return {onReady = resume} end},
}, {__index = _G})
local chunk = assert(loadstring(source:sub(start, stop - 1)))
setfenv(chunk, env); chunk()
local function rows()
  choice = nil
  local items = hook(function(_, list) return list end, game, {
    {label = "CONTINUE", value = "continue"},
    {label = "NEW GAME", value = "new"},
  })
  local menu = setmetatable({game=game,list={items=items,index=1}}, {__index=MainMenu})
  current = menu
  return items, menu
end
for _,desktop in ipairs({true,false}) do
  eager = desktop
  for _,load in ipairs({true,false}) do
    preload = load; ready = true
    local items, menu = rows()
    items[1].onSelect() -- argument-free hosts: the original failure
    assert(choice == "continue" and menu.phase == "confirm")
    items, menu = rows(); menu:choose(nil) -- actual Gen2 dispatcher supplies owner
    assert(choice == "continue" and menu.phase == "confirm")
  end
  preload = true; ready = false
  local items, menu = rows()
  items[1].onSelect()
  local loader = current
  assert(loader ~= menu and choice == nil)
  -- Resume while an unrelated screen is still on top: capture must retain owner.
  loader.onReady()
  assert(choice == "continue" and menu.phase == "confirm")
end
preload = false; ready = true
local items = hook(function(_, list) return list end, game, {
  {label="CONTINUE",onSelect=function() created=created+1 end},
})
items[1].onSelect()
assert(created == 1 and sessions > 0, "existing zero-argument callbacks must remain valid")
print("PASS Continue callback context: no-argument/Gen2 hosts, eager/mobile, OFF/warm/deferred and original callbacks")
