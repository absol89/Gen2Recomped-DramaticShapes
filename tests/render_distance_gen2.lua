local value=32
local R=assert(loadfile('lib/RenderDistance.lua'))({require=function(name)
  assert(name=='ModSetting')
  return {new=function(key,label,values,labels,default)
    assert(key=='renderDistance' and default==2 and values[4]==false)
    return {get=function() return value end}
  end}
end})
local player={px=0,py=0}
local near={map={id='near',def={width=8,height=8}},ox=128,oy=0}
local far={map={id='far',def={width=8,height=8}},ox=900,oy=0}
local state={map={id='current'},player=player,neighbors={near,far}}
assert(R.radius()==512)
assert(R.point(520,8,player) and not R.point(521,8,player))
local view=R.view(state)
assert(#view.neighbors==1 and view.neighbors[1]==near)
assert(#state.neighbors==2 and view.map==state.map)
assert(view._distanceNeighbors==state.neighbors and R.view(view)==view)
-- A long map's origin can be far away while its connected edge is near.
assert(R.neighbor({map={def={width=40,height=4}},ox=-1300,oy=0},player))
value=64;assert(#R.view(state).neighbors==2)
value=false;assert(R.view(state)==state and R.point(99999,99999,player))
value=16;assert(R.radius()==256)
assert(R.point(264,8,{cellX=0,cellY=0}))

-- Exercise the production prefetch function with Gen 2 map objects.
local f=assert(io.open('lib/VoxelScene.lua'));local source=f:read('*a');f:close()
local body=assert(source:match('(function VoxelScene.prefetch.-)\n%-%- Capture every entity'))
local requests,live,masks={},nil,nil
local env=setmetatable({VoxelScene={},RenderDistance=R,
  V={require=function() return {} end},Gen2WorldAdapter={prepareWorld=function() end},
  TerrainAtlas={setLive=function() end},ChunkMesher={
    setLive=function(set) live=set end,
    request=function(map,_,border) requests[#requests+1]=map.id;if border then masks=border end end,
    pair=function(map) return map.id..'-mesh',map.id..'-water' end,
  }},{__index=_G})
local chunk=assert(loadstring(body));setfenv(chunk,env);chunk()
value=32
local terrain,meshes,water,waters=env.VoxelScene.prefetch(state)
assert(terrain=='current-mesh' and water=='current-water')
assert(#requests==2 and requests[2]=='near' and not live.far)
assert(meshes[1]=='near-mesh' and waters[1]=='near-water' and #meshes==1)
assert(#masks==2,'border masks must retain all connected map footprints')
value=false;requests={};env.VoxelScene.prefetch(state)
assert(#requests==3 and live.far,'FULL must restore neighbor requests live')
print('Gen 2 render distance boundaries, world isolation, prefetch and FULL restoration: ok')
