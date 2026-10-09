local M=assert(loadfile('lib/Gen2ArchitectureVisuals.lua'))()
local function key(x,z) return (z+64)*4096+x+64 end
local function check(q,start)
  for i=start or 1,#q do
    local v=q[i]
    assert(#v==4 and #v.uv==4 and v.shade>0 and v.shade<=1)
    local loX,hiX,loZ,hiZ=math.huge,-math.huge,math.huge,-math.huge
    for _,p in ipairs(v) do
      for _,n in ipairs(p) do assert(n==n and math.abs(n)<10000) end
      loX=math.min(loX,p[1]);hiX=math.max(hiX,p[1])
      loZ=math.min(loZ,p[3]);hiZ=math.max(hiZ,p[3])
    end
    assert(hiX-loX<=8.001 and hiZ-loZ<=8.001,'world curve span exceeded')
  end
end
local sp={W=32,H=48,ax={[5]=3},ay={[5]=4}}
local top={};for x=0,31 do top[x]=math.abs(x-16) end
local pr={top=top,ytop=36,D=32,ground=48,shadeTexel={[2]=5}}
local q={{original=true}}
local n=M.decorateModel(q,{roofRows=32,slab=4},sp,pr,128,128)
assert(n>0 and n<=M.MODEL_QUAD_LIMIT and #q==n+1 and q[1].original)
check(q,2)
for i=2,#q do for _,p in ipairs(q[i])do
 assert(p[1]>14 and p[1]<18,'generic building corner support returned')
end end
local pagoda={{original=true}}
local pagodaPr={};for k,v in pairs(pr)do pagodaPr[k]=v end;pagodaPr.ground=80;pagodaPr.ytop=68
local pn=M.decorateModel(pagoda,{id='johto_pagoda_crystal',roofRows=32,slab=4},sp,pagodaPr,128,128)
local panels,bands,tiers=0,0,0
for i=2,#pagoda do
 if pagoda[i].gen2RoofPanel then panels=panels+1 end
 if pagoda[i].gen2StoreyBand then bands=bands+1 end
 if pagoda[i].gen2TierRoof then tiers=tiers+1 end
end
assert(pn>0 and pn<=M.MODEL_QUAD_LIMIT and panels>0 and bands>0 and tiers==bands,'pagoda landmark relief missing')
assert(pagoda.architectureDetailQuads==pn)
check(pagoda,2)
local furniture={{original=true}}
assert(M.decorateModel(furniture,{roofRows=0,desk={fascia={20,21},base={22,23},x={4,27},z=4,depthPx=12}},sp,pr,128,128)>0)
check(furniture,2)
local unchanged={{original=true}}
assert(M.decorateModel(unchanged,{claimOnly=true},sp,pr,128,128)==0 and #unchanged==1)
local data={getDimensions=function()return 128,128 end,getPixel=function()return .3,.5,.6,1 end}
local S={outdoor=false,shapeAt={},skip={},tileAt={},runs={},objectQuads={}}
local map={def={width=50,height=50}}
for x=0,199 do
  S.shapeAt[key(x,0)]={class='wall',h=16}
  S.shapeAt[key(x,1)]={flat=true}
  S.tileAt[key(x,0)]=3
end
local before=S.shapeAt[key(0,0)]
local room=M.decorateRoom(S,map,data,16)
assert(room>0 and room<=M.ROOM_QUAD_LIMIT)
assert(S.shapeAt[key(0,0)]==before and not next(S.skip),'collision/claims changed')
assert(M.decorateRoom(S,map,data,16)==0 and #S.objectQuads==room,'duplicate build')
check(S.objectQuads)
local outdoor={outdoor=true,objectQuads={}}
assert(M.decorateRoom(outdoor,map,data,16)==0)
-- A doorway never gets a new trim bar across it.
local door={outdoor=false,shapeAt={[key(0,0)]={flat=true}},tileAt={},skip={},objectQuads={}}
assert(M.decorateRoom(door,{def={width=1,height=1}},data,16)==0)
print('PASS Gen2 architecture: bounded real quads, curvature spans, source preservation, room/door guards')
