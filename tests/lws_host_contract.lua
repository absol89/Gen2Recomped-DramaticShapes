-- Run from the mod root: luajit tests/lws_host_contract.lua [other-mod-root]
-- Actual host Voxel3D/Mat4, mocked graphics and sibling services. No LWS code.
-- This guards legacy attachment seams, not rendered weather or Quest stereo.
local root = arg[1] or "."
local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end
local function read(path)
  local f = assert(io.open(root .. "/" .. path, "rb"))
  local text = f:read("*a"); f:close(); return text
end
check(read("main.lua"):find("mod%.exports%.lib%s*=%s*V") ~= nil,
      "source contract: host library export missing")
check(read("manifest.json"):find('"id"%s*:%s*"BATTLE_ART_VOXEL_GEN2"') ~= nil,
      "source contract: Gen2 host identity changed")

local noop = function() end
local bound, shader, depth, writes, cull
local g = {
  setCanvas = function(target) bound = target end,
  setShader = function(value) shader = value end,
  setDepthMode = function(mode, write) depth, writes = mode, write end,
  setMeshCullMode = function(mode) cull = mode end,
  setColor = noop, clear = noop,
  newShader = function() return {send = noop} end,
}
love = {graphics = g}
local Mat4 = assert(loadfile(root .. "/lib/Mat4.lua"))()
local host, expectedEye, expectedRay, paints = nil, nil, nil, 0
local sky = {region = function() return 50 end}
sky.paint = function(w, h, palette, horizon, cell, body, top, axis, ray)
  paints = paints + 1
  check(type(bound) == "table" and bound[1] == host.canvas(),
        "sky seam must have the scene canvas bound")
  check(host.eye == expectedEye and type(host.vp) == "table" and #host.vp == 16,
        "sky seam must expose the current camera before drawing")
  check(ray == expectedRay, "sky seam lost the current camera ray fan")
  check(w == 100 and h == 100 and cell == 1 and palette.bands,
        "sky seam arguments changed")
end
local modules = {
  Mat4 = Mat4, VoxelState = {},
  ShadowMap = {active = function() return false end, texture = noop, res = 64},
  Shadows = {off = function() return true end},
  VoxelGrid = {enabled = function() return false end},
  WorldCurve = {k = function() return 0 end}, Sky = sky,
  DayNight = {body = noop}, GlassMask = {blank = noop},
  PixelCanvas = {new = function()
    return true, {setFilter = noop, release = noop}
  end},
  RendererOrientation = {},
}
host = assert(loadfile(root .. "/lib/Voxel3D.lua"))({require = function(name)
  return assert(modules[name], "unexpected host dependency: " .. name)
end})
check(type(host.beginScene) == "function" and type(host.endScene) == "function",
      "legacy scene entry points missing")
check(host.endScene() == nil, "closing an unopened scene must return nil")

local function camera(x, ray)
  expectedEye, expectedRay = {x, 32, 64}, ray
  host.camera = {eye = expectedEye, focus = {0, 0, 0},
    view = Mat4.identity(), proj = Mat4.identity(), fov = 1, skyRay = ray}
end
local palette = {0, 0, 0, 1, bands = {{0, 0, 0}, {1, 1, 1}}}
-- Two distinct synthetic cameras guard against stale public camera fields.
-- These are ordinary host passes, not an execution of the Quest bridge.
for index = 1, 2 do
  camera(index, {base = {0, 0, -1}, dx = {1, 0, 0}, dy = {0, 1, 0}})
  check(host.beginScene(100, 100, 0, 0, 100, 100, palette), "scene failed")
  check(paints == index, "sky seam must run once per scene")
  local expectedCanvas = host.canvas()
  check(host.endScene() == expectedCanvas, "scene close must return its canvas")
  check(bound == nil and shader == nil and depth == nil and writes == nil
        and cull == "none", "scene close must reset host graphics bindings")
  check(host.endScene() == nil, "a closed scene must not close twice")
end
camera(3, nil)
check(host.beginScene(100, 100, 0, 0, 100, 100, nil), "no-sky scene failed")
check(paints == 2, "no-sky scene must not invoke the sky seam")
check(host.endScene() ~= nil, "no-sky scene must still close")

-- An unavailable shader declines before exposing a sky pass.
local originalShader = host.shader
host.shader = function() return nil end
check(host.beginScene(100, 100, 0, 0, 100, 100, palette) == false,
      "unavailable renderer must decline the scene")
check(paints == 2 and host.endScene() == nil,
      "failed scene must not draw sky or leave a live scene")
host.shader = originalShader
print("LWS legacy host contract: " .. checks .. " checks passed (source/mocked graphics)")
