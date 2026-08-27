local runtimeLove = love
love = { graphics = { getPixelDimensions = function() return 1080, 2268 end } }

local V = {}
local PipelineCanvas = assert(loadfile("lib/PipelineCanvas.lua"))(V)
local ctx = { width = 411, height = 864 }

local w, h = PipelineCanvas.sceneSize(ctx, 1)
assert(w == 1080 and h == 2268,
  "Gen 1 did not return framebuffer-pixel canvas dimensions")

w, h = PipelineCanvas.sceneSize(ctx, 2)
assert(w == 411 and h == 864,
  "Gen 2 did not preserve direct-compositor LOVE-unit dimensions")

love.graphics.getPixelDimensions = function() error("must not query", 0) end
w, h = PipelineCanvas.sceneSize(ctx, 2)
assert(w == 411 and h == 864,
  "Gen 2 consulted framebuffer dimensions")

love = runtimeLove
print("pipeline canvas compositor contract: ok")
