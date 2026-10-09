local P=assert(loadfile('lib/ParkProps.lua'))()
local function K(x,z)return(z+64)*4096+x+64 end
local data={getDimensions=function()return 128,128 end,getPixel=function(_,x,y)local v=({1,.66,.33,0})[x%4+1];return v,v,v,1 end}
local map={tileset={id='TilesetPark'},def={width=8,height=8}}
local function grid()
 local s={tileAt={},shapeAt={},skip={},ground={},runs={},objectQuads={}}
 for z=0,31 do for x=0,31 do local k=K(x,z);s.tileAt[k]=0;s.shapeAt[k]={class='wall',h=16}end end
 return s
end
local function rows(s,x,z,rs)
 for dz,row in ipairs(rs)do for dx,t in ipairs(row)do s.tileAt[K(x+dx-1,z+dz-1)]=t end end
end
local s=grid()
rows(s,2,2,{{7,8,9,10,7,8,9,10},{0x17,0x18,0x19,0x1A,0x17,0x18,0x19,0x1A},{0x27,0x28,0x29,0x2A,0x27,0x28,0x29,0x2A}})
rows(s,14,2,{{0x45,0x46},{0x55,0x56}})
rows(s,2,12,{{0x37,0x38,0x38,0x39},{0x47,3,1,0x49},{0x47,1,3,0x49},{0x57,0x58,0x58,0x59}})
rows(s,10,20,{{0x5A,0x5B},{0x13,0x82}})
rows(s,18,20,{{0x4C,0x4D},{0x5C,0x5D}})
P.build(s,map,data,16)
assert(s.parkProps.benches==1 and s.parkProps.signs==1 and s.parkProps.flowerbeds==1 and s.parkProps.bins==2)
assert(s.shapeAt[K(2,2)].authored and not s.shapeAt[K(2,2)].art)
assert(s.skip[K(9,4)] and s.skip[K(15,3)] and s.skip[K(5,15)])
assert(not s.skip[K(10,2)],'adjacent paving untouched')
assert(s.parkActorOffsets[K(2,3)]==14,'bench actor card clears the seat')
assert(s.parkActorOffsets[K(2,4)]==nil and s.parkActorOffsets[K(14,2)]==nil,'no offset on front paving or signs')
for _,q in ipairs(s.objectQuads)do
 assert(#q==4 and #q.uv==4)
 for i,v in ipairs(q)do
  assert(v[2]>=0 and v[2]<=17,'prop height bounded')
  if v[3]>=96 and v[3]<=128 then assert(v[2]<=5.5,'flowers have shallow relief, not tall walls')end
  assert(q.uv[i][1]>0 and q.uv[i][1]<1 and q.uv[i][2]>0 and q.uv[i][2]<1)
 end
end
assert(s.parkProps.flowers==2,'both source flower tiles receive relief')
assert(s.skip[K(10,20)] and s.skip[K(11,21)] and s.skip[K(18,20)] and s.skip[K(19,21)],'whole bin footprints claimed')
local raisedRim=false
for _,q in ipairs(s.objectQuads)do for _,v in ipairs(q)do
 if v[2]==4.3 then raisedRim=true end
end end
assert(raisedRim,'flowerbed frame must rise above soil')
assert(#s.objectQuads<600,'bounded geometry for three props')
local other=grid();P.build(other,{tileset={id='TilesetJohto'},def=map.def},data,16)
assert(#other.objectQuads==0 and not other.parkProps,'other maps untouched')
local broken=grid();rows(broken,2,2,{{0x45,0x46},{0x55,0}});P.build(broken,map,data,16)
assert(broken.parkProps.signs==0,'incomplete sprite not guessed')
print('PASS Park source matching, separate bench parts, thin sign, low bed, scope and quad budget',#s.objectQuads)
