local function source(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local interface = source("lib/InterfaceSprites.lua")
assert(not interface:find("installDexList", 1, true),
  "Pokedex list still installs animated Battle Art")
assert(not interface:find("drawGen2Dex", 1, true),
  "Pokedex list ROM preview is still wrapped")
assert(interface:find("InterfaceSprites.installDex()", 1, true),
  "selected Pokedex entry page lost its animated playback")
assert(interface:find("function InterfaceSprites.installDex()", 1, true),
  "selected Pokedex entry animation implementation was removed")

print("interface Pokedex static-list regression: ok")
