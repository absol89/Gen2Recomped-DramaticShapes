local root='lib/'
local G=assert(loadfile(root..'Gen2ArchitectureVisuals.lua'))()
local M=assert(loadfile(root..'Gen2HomeFixtures.lua'))({require=function()return G end})
local function key(x,z)return(z+64)*4096+x+64 end
local data={getDimensions=function()return 128,48 end}
local map={def={width=5,height=4},tileset={id='TilesetPlayersHouse'},warps={untouched=true}}
local function scene()
  local S={outdoor=false,shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
  for z=0,15 do for x=0,19 do
    S.shapeAt[key(x,z)]={class='ground',flat=true};S.tileAt[key(x,z)]=1
  end end
  for _,p in ipairs({{x=0,z=2,rows={{80,81},{82,83}}},
      {x=2,z=2,rows={{67,69},{24,25}}},
      {x=4,z=1,rows={{10,11},{26,27},{42,43}}},
      {x=8,z=1,rows={{6,7},{22,23},{8,9}},classes={'wall','console','console'}},
      {x=10,z=2,rows={{14,15},{58,59}},classes={'wall','bookcase'}}})do
    for r,row in ipairs(p.rows)do for c,t in ipairs(row)do
      local k=key(p.x+c-1,p.z+r-1)
      S.tileAt[k]=t;S.shapeAt[k]={class=p.classes and p.classes[r] or 'bookcase',h=32,authored=true}
    end end
  end
  S.tileAt[key(8,0)]=0x11;S.shapeAt[key(8,0)]={class='wall',art='upright',h=16,authored=false}
  S.tileAt[key(7,7)]=0x11 -- A floor tile sharing the number is never promoted.
  return S
end
local S=scene()
local n=M.build(S,map,data,16)
assert(n>0 and n<=M.MAX_QUADS and map.warps.untouched)
for _,kind in ipairs({'cooker','sink','refrigerator','television','drawers'})do assert(S.homeFixtures.counts[kind]==1,kind)end
assert(M.build(S,map,data,16)==0)
assert(S.shapeAt[key(0,2)].h==8 and S.shapeAt[key(2,2)].h==8 and S.shapeAt[key(4,1)].h==22)
assert(not S.skip[key(0,1)] and not S.skip[key(6,3)],'wall/window/floor outside fixture was claimed')
assert(S.homeFixtures.wallPanels==1 and S.shapeAt[key(8,0)].authored and S.shapeAt[key(8,0)].h==16)
assert(S.shapeAt[key(7,7)].class=='ground' and not S.skip[key(7,7)])
assert(S.skip[key(8,1)] and S.skip[key(8,3)],'TV cap and base must be claimed together')
local minTop,maxTop=math.huge,-math.huge
local fridgeSides,fridgeHandles=0,0
for _,q in ipairs(S.objectQuads)do
  local lx,hx,lz,hz=math.huge,-math.huge,math.huge,-math.huge
  for i,p in ipairs(q)do
    lx=math.min(lx,p[1]);hx=math.max(hx,p[1]);lz=math.min(lz,p[3]);hz=math.max(hz,p[3])
    assert(p[1]>=0 and p[1]<=96 and p[2]>=0 and p[2]<=22.5)
    assert(q.uv[i][1]>=0 and q.uv[i][1]<=1 and q.uv[i][2]>=0 and q.uv[i][2]<=1)
  end
  assert(hx-lx<=8.001 and hz-lz<=8.001,'worldcurve split exceeded')
  if lx>=32.9 and hx<=48.1 and lz>=18 and hz<=33 then
    if lx==hx and (math.abs(lx-48.08)<.001 or math.abs(lx-33.04)<.001)then fridgeSides=fridgeSides+1 end
    if lz>=32.79 and hz>32.89 then fridgeHandles=fridgeHandles+1 end
  end
  -- Counter-top polygons must not bridge across the sink's hollow opening.
  if q[1][2]>8 and q[1][2]<8.1 and q[1][2]==q[3][2]
      and lx>=16 and hx<=32 then
    assert(hx<=19 or lx>=29 or hz<=21 or lz>=29,'sink opening covered by top art')
  end
end
assert(fridgeSides>=6,'refrigerator side seams/vents missing')
assert(fridgeHandles>=2,'refrigerator raised handles missing')
local S=scene();S.tileAt[key(0,2)]=0
M.build(S,map,data,16)
assert(not S.homeFixtures.counts.cooker and not S.skip[key(0,2)],'partial tile pattern claimed')
local S=scene();S.shapeAt[key(4,1)].class='ground'
M.build(S,map,data,16)
assert(not S.homeFixtures.counts.refrigerator,'nonmatching class claimed')
local S=scene();S.shapeAt[key(8,1)].class='ground'
M.build(S,map,data,16)
assert(not S.homeFixtures.counts.television and not S.skip[key(8,2)],'partial TV class match claimed')
local other={def=map.def,tileset={id='TilesetHouse'}}
assert(M.build(scene(),other,data,16)==0)
print('PASS exact PlayersHouse5 fixtures: '..n..' quads, mixed TV cap/base,16px wall pin, hollow sink, native outside claims preserved')
