local draws, made = {}, 0
local major = 12
local renderer = { "Metal", "3.1", "Apple", "Apple GPU" }
local current
love = {
  getVersion = function() return major, 0, 0 end,
  graphics = {
    getRendererInfo = function() return unpack(renderer) end,
    getCanvas = function() return current end,
    setCanvas = function(c) current = c end,
    getBlendMode = function() return "alpha", "alphamultiply" end,
    setBlendMode = function() end,
    setShader = function() end,
    setColor = function() end,
    clear = function() end,
    draw = function(...)
      draws[#draws + 1] = { ... }
    end,
  },
}

setmetatable(love, { __index = function(_, key)
  if key == "system" then error("love.system is blocked for mods") end
end })

local function canvas(w, h)
  return {
    getDimensions = function() return w, h end,
    setFilter = function() end,
    release = function() end,
  }
end

local V = {
  require = function(name)
    if name == "RendererOrientation" then
      return assert(loadfile("lib/RendererOrientation.lua"))()
    end
    assert(name == "PixelCanvas")
    return { new = function(w, h)
      made = made + 1
      return true, canvas(w, h)
    end }
  end,
}

local Orientation = assert(loadfile("lib/WorldCanvasOrientation.lua"))(V)
assert(Orientation.needsFlip(2), "Gen 2 iOS/Metal frame was not detected")
assert(not Orientation.needsFlip(1), "Gen 1 would be double-flipped")

local source = canvas(320, 640)
local out = Orientation.present(source, "world", 2)
assert(out ~= source and made == 1, "Gen 2 iOS frame was not copied")
local d = draws[#draws]
assert(d[1] == source and d[2] == 0 and d[3] == 640
       and d[5] == 1 and d[6] == -1,
  "compatibility copy did not invert the Canvas exactly once")

assert(Orientation.present(source, "world", 1) == source,
  "Gen 1 did not receive its original Canvas")
renderer = { "OpenGL ES", "3.0", "Qualcomm", "Adreno" }
assert(not Orientation.needsFlip(2), "Android was mistaken for Metal/iOS")
renderer = { "Metal", "3.1", "Apple", "Apple GPU" }
major = 11
assert(not Orientation.needsFlip(2), "LÖVE 11 Metal was incorrectly flipped")
local count = #draws
assert(Orientation.present(source, "world", 2) == source,
  "LÖVE 11 Mac world must pass through without a canvas flip")
assert(#draws == count, "LÖVE 11 must not draw a correction copy")

print("world canvas orientation regression: ok")
