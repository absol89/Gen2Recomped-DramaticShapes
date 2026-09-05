-- Run from the mod root with Lua 5.1/LuaJIT.
local circleScale, active, stageCalls, fallbackCalls = 1, false, 0, 0
local origin = { 120, 8, 240 }
local vp = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 }
local function mul(a, b)
  local out = {}
  for r=0,3 do for c=0,3 do
    local n=0
    for k=0,3 do n=n+a[r*4+k+1]*b[k*4+c+1] end
    out[r*4+c+1]=n
  end end
  return out
end
package.loaded['mods.STADIUM2_IMPORTER.lib.renderer'] = { matMul=mul }
local radius = function() return 24 end
local stage = { radius=radius, sink=.06 }
local marks = { player={x=10,y=20}, enemy={x=30,y=40} }
local failStage = false
stage.draw = function(g, w, h, frame)
  assert(active, 'circle drawn after voxel depth attachment was resolved')
  assert(w==320 and h==288,
    'supersampled render dimensions leaked into logical attack anchors')
  assert(frame.vp[4]==120 and frame.vp[8]==8 and frame.vp[12]==240,
    'stage camera does not translate Stadium coordinates into voxel world')
  assert(stage.radius()==24*circleScale)
  assert(stage.sink<0, 'circle is buried below the voxel floor')
  stageCalls=stageCalls+1
  if failStage then error('stage failure') end
  return marks
end
local pushes = 0
local g = {
  push=function() pushes=pushes+1 end,
  pop=function() pushes=pushes-1 end,
  setCanvas=function() assert(not active) end,
  setShader=function() end, setDepthMode=function() end,
  setBlendMode=function() end, setColor=function() end,
  draw=function() assert(not active) end,
}
local canvas = { getDimensions=function() return 320,288 end }
local providerFails = false
local overworld = {
  providerBegin=function() return true end,
  providerFinish=function() end,
  providerRender=function(_, passes)
    if providerFails then return nil end
    active=true
    local ok, err=pcall(passes.draw, {vp=vp, origin=origin})
    active=false
    if not ok then error(err) end
    return canvas
  end,
}
local modules = {
  UiBackplates={ arenaFill={get=function() return 'OFF' end},
    stadiumCircleScale=function() return circleScale end },
  OverworldBattle=overworld, Voxel3D={}, BackdropImage={},
}
local api=assert(loadfile('lib/StadiumBackground.lua'))({
  require=function(name) return assert(modules[name]) end,
})
local ctx={ graphics=g, target={color={},width=1280,height=1152,
    logicalWidth=320,logicalHeight=288},
  camera={vp=vp}, marks=marks,
  scene={battle={},host={Stage=stage,actors={}}} }
local function fallback() fallbackCalls=fallbackCalls+1; return marks end
for _, value in ipairs({1, 2/3, 0}) do
  circleScale=value
  local before=stageCalls
  assert(api.environment(fallback,ctx)==marks)
  assert(stageCalls==before+(value>0 and 1 or 0))
  assert(fallbackCalls==0, 'stage redrawn on the flattened color canvas')
  assert(stage.radius==radius and stage.sink==.06 and pushes==0)
end
circleScale=2/3
failStage=true
assert(not pcall(api.environment,fallback,ctx))
assert(stage.radius==radius and stage.sink==.06 and pushes==0,
  'failed circle draw leaks graphics or shared stage state')
providerFails=true
assert(api.environment(fallback,ctx)==marks and fallbackCalls==1)
print('stadium circle depth regression: ok')
