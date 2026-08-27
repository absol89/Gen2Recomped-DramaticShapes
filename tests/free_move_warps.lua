-- Free movement preserves Gen2's directional-carpet check before collision.

package.preload["src.core.Game"] = function()
  return { data = { field = { warpCarpets = {} } } }
end

local FreeMove = assert(loadfile("lib/FreeMove.lua"))({
  require = function(name)
    if name == "FirstPerson" then return { releaseBody = function() end } end
    error("unexpected module " .. tostring(name))
  end,
})

local calls = {}
local state = {
  player = { cellX = 4, cellY = 7 },
  checkGen2Whirlpool = function() calls[#calls + 1] = "whirlpool" return false end,
  checkGen2CarpetExit = function(_, dir)
    calls[#calls + 1] = "carpet:" .. dir
    return true
  end,
  checkEdgeExit = function() error("carpet must outrank edge exit") end,
  checkLedgeHop = function() error("carpet must outrank ledges") end,
  checkBoulderPush = function() error("carpet must outrank boulders") end,
}

assert(FreeMove._pushSpecials(state, "left", "tile"))
assert(state.player.facing == "left")
assert(table.concat(calls, ",") == "whirlpool,carpet:left")
print("free movement warp regression: ok")
