-- Actual Gen 2 scene transforms/pass orchestration with a mocked GPU.
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "dev/BattleArtGen2"
local mat = assert(loadfile(root .. "/lib/Mat4.lua"))()
local count, ended, draws = 0, 0, 0
local readable, allocation, enabled = true, true, true
local captured
local water = { CAST_RAISE = 6, CAST_ALPHA = .5,
  enabled = function() return enabled end,
  begin = function(ctx) captured = ctx; return true end,
  draw = function() draws = draws + 1 end, finish = function() end }
local vox = { depthReadable = function() return readable end,
  beginCast = function() count = count + 1; return allocation and "cast" or nil end,
  endCast = function() ended = ended + 1 end,
  beginWater = function() return "mirror", "depth" end,
  endWater = function() end, size = function() return 320, 288 end,
  draw = function() end }
local modules = { Mat4 = mat, Voxel3D = vox, Water = water,
  ModSetting = { new = function() return {} end },
  VoxelState = { angle = math.pi / 2 },
  FirstPerson = { cardBlend = function() return 0 end },
  TileShape = { heights = function() return {water = -2} end },
  VoxelGrid = { enabled = function() return false end } }
local scene = assert(loadfile(root .. "/lib/VoxelScene.lua"))({
  require = function(name) return modules[name] or {} end,
})
local visited = {}
local function find(fn, wanted)
  if type(fn) ~= "function" or visited[fn] then return end
  visited[fn] = true
  for i = 1, 100 do
    local name, value = debug.getupvalue(fn, i)
    if not name then break end
    if name == wanted then return value end
    if type(value) == "function" then
      local found = find(value, wanted)
      if found then return found end
    end
  end
end
local billboard
for _, fn in pairs(scene) do billboard = billboard or find(fn, "billboardMatrix") end
assert(billboard, "test needs production billboard transform")
local function point(m, x, y, z)
  return {m[1]*x+m[2]*y+m[3]*z+m[4], m[5]*x+m[6]*y+m[7]*z+m[8],
    m[9]*x+m[10]*y+m[11]*z+m[12]}
end
for _, half in ipairs({8, 16}) do
  local plain = billboard(20, 30, 3, false, half)
  local reflected
  scene.drawWater({{"mesh", "atlas"}}, function()
    reflected = billboard(20, 30, 3, false, half)
  end)
  T.same(point(plain, half, 0, 0), {20+half, 3, 30+half}, "native feet retain width-dependent pivot")
  T.same(point(reflected, half, 0, 0), {20+half, -1, 30+half}, "reflected feet keep Gen 2 width and mirror height")
  T.same(point(reflected, half, 10, 0), {20+half, -11, 30+half}, "reflection flips full-height card without shrinking")
  T.same(billboard(20,30,3,false,half), plain, "normal pose restored after reflection")
  T.eq(captured.cast, "cast", "water samples the produced reflection")
end
local normal = billboard(0,0,0,false,16)
scene.drawWater({{"mesh", "atlas"}}, function() error("sprite failure") end)
T.eq(captured.cast, nil, "failed cast is not composited partially")
T.same(billboard(0,0,0,false,16), normal, "throw does not leave reflected transforms active")
T.eq(ended, 3, "successful allocations close even if character drawing fails")
local prior = count
readable = false
scene.drawWater({{"mesh", "atlas"}}, function() error("must not draw") end)
T.eq(count, prior, "unreadable depth skips cast allocation")
readable, enabled = true, false
scene.drawWater({{"mesh", "atlas"}}, function() error("must not draw") end)
T.eq(count, prior, "water OFF skips cast allocation")
enabled = true
scene.drawWater({}, function() error("must not draw") end)
T.eq(count, prior, "no visible water skips cast allocation")
allocation = false
scene.drawWater({{"mesh", "atlas"}}, function() error("must not draw") end)
T.eq(captured.cast, nil, "allocation failure leaves ordinary water available")
T.eq(ended, 3, "failed allocation has no cast to close")
T.finish("Gen 2 water reflection")
