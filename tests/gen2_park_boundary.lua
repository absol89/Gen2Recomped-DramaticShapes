-- Source geometry only, synthetic atlas and map; no ROM or GPU required.
local M=assert(loadfile('lib/Gen2ParkBoundary.lua'))()
local function K(x,z)return (z+64)*4096+x+64 end
local ground={class='ground',flat=true,h=0}
local map={id='NATIONAL_PARK',def={width=2,height=2},tileset={tilesPerRow=16}}
local data={getDimensions=function()return 128,128 end,
 getPixel=function(_,x,y)return .2+x/256,.25+y/256,.2,1 end}
local function grid()
 local s={outdoor=true,shapeAt={},tileAt={},skip={},ground={},runs={},objectQuads={}}
 for z=0,7 do for x=0,7 do s.shapeAt[K(x,z)]=ground;s.tileAt[K(x,z)]=0 end end
 return s
end
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local function finite(v)return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
for _,id in ipairs({'NATIONAL_PARK','NATIONAL_PARK_BUG_CONTEST'})do
 map.id=id
 for _,rows in ipairs({
  {{0x23,0x24},{0x33,0x34}},{{0x25,0x26},{0x35,0x36}},
  {{0x43,5},{0x53,5}},{{5,0x43},{5,0x53}},
  {{0x1B,5},{0x43,5},{0x53,5},{0x2B,5}},
  {{0x1B,5},{0x43,5},{0x43,5},{0x53,5}},
  {{5,0x1B},{5,0x43},{5,0x43},{5,0x53}},
 })do
  local s=grid()
  for z,row in ipairs(rows)do for x,t in ipairs(row)do s.tileAt[K(x-1,z-1)]=t end end
  M.build(s,map,data)
  check(s.parkBoundary.hoops==(#rows==2 and 1 or 2),'rail variant count')
  for z,row in ipairs(rows)do for x in ipairs(row)do check(s.skip[K(x-1,z-1)],'unclaimed rail tile')end end
  for _,q in ipairs(s.objectQuads)do
   for _,p in ipairs(q)do check(finite(p[1]) and finite(p[2]) and finite(p[3]),'nonfinite geometry')end
   for _,uv in ipairs(q.uv)do check(uv[1]>0 and uv[1]<1 and uv[2]>0 and uv[2]<1,'atlas UV bounds')end
  end
 end
 for _,t in ipairs({0x2B,0x05})do
  local s=grid();s.tileAt[K(2,2)]=t;M.build(s,map,data)
  check(s.parkBoundary.hoops==1,'corner omitted')
  for _,q in ipairs(s.objectQuads)do for _,p in ipairs(q)do
   check(p[1]>=16 and p[1]<=24 and p[3]>=16 and p[3]<=24,'corner outside edge footprint')
  end end
 end
 local hidden=grid();for k in pairs(hidden.tileAt)do hidden.tileAt[k]=1 end
 hidden.tileAt[K(2,2)]=0x2B;M.build(hidden,map,data)
 check(hidden.parkBoundary.hoops==0,'invented freestanding diagonal hoop')
 local s=grid();local water={class='water',flat=true,h=-2}
 s.shapeAt[K(1,3)]=water
 for z=2,5 do for x=2,5 do s.tileAt[K(x,z)]=0x5F;s.runs[K(x,z)]={h=16}end end
 s.tileAt[K(3,3)]=0x80;s.tileAt[K(4,3)]=0x81
 s.tileAt[K(3,4)]=0x90;s.tileAt[K(4,4)]=0x91
 M.build(s,map,data);check(s.parkBoundary.pondCenter==16,'pond center not cleared')
 for z=2,5 do for x=2,5 do local k=K(x,z)
  check(s.shapeAt[k]==water and s.tileAt[k]==0x14 and not s.runs[k],'submerged solid remains')
 end end
end
map.id='OTHER';local s=grid();check(M.build(s,map,data)==0 and #s.objectQuads==0,'unrelated map changed')
map.id='NATIONAL_PARK';s.outdoor=false;check(M.build(s,map,data)==0,'indoor modified')
M.invalidate();print('PASS Gen2 Park boundary '..checks..' checks')
