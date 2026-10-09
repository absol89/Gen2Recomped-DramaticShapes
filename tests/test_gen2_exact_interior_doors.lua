local root='./'
local G=dofile(root..'lib/Gen2ArchitectureVisuals.lua')
local M=assert(loadfile(root..'lib/Gen2ExactInteriorDoors.lua'))({
 require=function(name)assert(name=='Gen2ArchitectureVisuals');return G end})
local function scene()
 local map={id='WISE_TRIOS_ROOM',def={generation=2,width=4,height=4,environment='INDOOR',warps={
  {x=7,y=4,destMap='ECRUTEAK_CITY',destWarp=4},
  {x=7,y=5,destMap='ECRUTEAK_CITY',destWarp=5},
  {x=1,y=4,destMap='ECRUTEAK_TIN_TOWER_ENTRANCE',destWarp=5}}},
  tileset={id='TilesetTraditionalHouse'}}
 return {outdoor=false,objectQuads={}},map,{getDimensions=function()return 128,128 end}
end
local S,map,data=scene();local warps=map.def.warps;local n=M.build(S,map,data,16)
assert(n>0 and n<=M.MAX_QUADS and n==#S.objectQuads)
assert(S.exactInteriorDoors.orientation=='east'and S.exactInteriorDoors.warpsPreserved==3)
assert(map.def.warps==warps and #map.def.warps==3)
local panel,knob=false,false
for _,q in ipairs(S.objectQuads)do
 local xmin,xmax,ymin,ymax,zmin,zmax=math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
 for i=1,4 do local p=q[i];xmin=math.min(xmin,p[1]);xmax=math.max(xmax,p[1]);ymin=math.min(ymin,p[2]);ymax=math.max(ymax,p[2]);zmin=math.min(zmin,p[3]);zmax=math.max(zmax,p[3]) end
 assert(xmin>=124.5 and xmax<=128 and ymin>=0 and ymax<=32 and zmin>=56 and zmax<=104)
 assert(q.roomRole=='exact_exit_door')
 panel=panel or(ymin>=5 and ymax<=26 and xmin<125.4)
 knob=knob or(xmin<125 and ymin>=14 and ymax<=17)
end
assert(panel and knob and S.exactInteriorDoors.sideReturns==2 and M.build(S,map,data,16)==0)
for _,bad in ipairs({'map','tileset','generation','width','warps','destination','atlas','outdoor'})do
 local s,m,d=scene()
 if bad=='map'then m.id='WISE_TRIOS_ROOM_2'
 elseif bad=='tileset'then m.tileset.id='TilesetHouse'
 elseif bad=='generation'then m.def.generation=1
 elseif bad=='width'then m.def.width=5
 elseif bad=='warps'then table.remove(m.def.warps)
 elseif bad=='destination'then m.def.warps[1].destMap='ROUTE_1'
 elseif bad=='atlas'then d={getDimensions=function()return 64,64 end}
 else s.outdoor=true end
 assert(M.build(s,m,d,16)==0 and #s.objectQuads==0,bad)
end
print('PASS exact Wise Trio east double door, source palette, bounded geometry, preserved warps, fail-closed guards')
