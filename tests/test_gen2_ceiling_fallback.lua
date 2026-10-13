package.loaded['src.world.Map']={isOutdoor=function(def)return def.outdoor end}
local Geometry={texelUV=function(x,y,w,h)return{{x/w,y/h},{x/w,y/h},{x/w,y/h},{x/w,y/h}}end}
local M=assert(loadfile('lib/Gen2CeilingFallback.lua'))({
 require=function(name)assert(name=='Gen2ArchitectureVisuals');return Geometry end})
local data={}
function data:getDimensions()return 16,16 end
function data:getPixel(x,y)return .76,.72,.66,1 end
local function scene(id,reason)
 return{outdoor=false,objectQuads={},roomVisuals={quads=0,reason=reason}},
  {id=id,def={id=id,generation=2,width=5,height=4},tileset={id='TilesetTower'}}
end
for _,id in ipairs({'CIANWOOD_GYM','ECRUTEAK_GYM','ECRUTEAK_TIN_TOWER_ENTRANCE'})do
 local S,map=scene(id,id=='ECRUTEAK_TIN_TOWER_ENTRANCE'and'native wall material unavailable'or'native room shell incomplete')
 local n=M.build(S,map,data)
 assert(n==116 and #S.objectQuads==116 and S.ceilingFallback.height==48 and S.ceilingFallback.wallQuads==36 and S.roomVisuals.ceilingFallback)
 local ceilings,walls=0,0
 for _,q in ipairs(S.objectQuads)do assert(q.oneSided,'room fallback must be inward-only'); if q.roomRole=='ceiling_fallback'then ceilings=ceilings+1;assert(q[1][2]==48 and q[3][2]==48)
  elseif q.roomRole=='wall_fallback'then walls=walls+1;assert(q[1][2]==16 and q[3][2]==48)else error('unknown fallback role')end end
 assert(ceilings==80 and walls==36)
end
for _,case in ipairs({{'PEWTER_GYM','native room shell incomplete'},{'CIANWOOD_GYM','other'}})do
 local S,map=scene(case[1],case[2]);assert(M.build(S,map,data)==0 and #S.objectQuads==0)
end
local S,map=scene('CIANWOOD_GYM','native room shell incomplete');map.def.outdoor=true
assert(M.build(S,map,data)==0)
local S,map=scene('CIANWOOD_GYM','native room shell incomplete')
map.def.warps={{x=4,y=0},{x=4,y=7}}
assert(M.build(S,map,data)==114 and S.ceilingFallback.wallQuads==34)
assert(#map.def.warps==2 and map.def.warps[1].x==4)
print('PASS exact ceiling-only fallbacks: 3 rooms, finite quads, rejection and outdoor guards')
