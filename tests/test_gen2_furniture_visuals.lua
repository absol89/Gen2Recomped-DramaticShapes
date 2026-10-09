local root='lib/'
local G=assert(loadfile(root..'Gen2ArchitectureVisuals.lua'))()
local M=assert(loadfile(root..'Gen2FurnitureVisuals.lua'))({require=function(n)assert(n=='Gen2ArchitectureVisuals');return G end})
local function key(x,z)return (z+64)*4096+x+64 end
local data={getDimensions=function()return 128,128 end,getPixel=function()return .5,.4,.3,1 end}
local function scene(class,w,h,authored)
  local S={outdoor=false,shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
  for z=0,7 do for x=0,7 do
    local k=key(x,z)
    S.shapeAt[k]={flat=true,class='ground',h=0};S.tileAt[k]=0
    if x>=1 and x<=w and z>=1 and z<=h then
      S.shapeAt[k]={flat=false,class=class,h=6,authored=authored};S.tileAt[k]=16+x
    end
  end end
  return S
end
local map={def={width=2,height=2},collision={keep=true},warps={keep=true}}
for _,class in ipairs({'table','bed'}) do
  local S=scene(class,2,2,true)
  local n=M.build(S,map,data,16)
  assert(n>0 and n<=M.MAX_MAP_QUADS and S.furnitureVisuals.fixtures==1)
  assert(S.skip[key(1,1)] and S.shapeAt[key(1,1)].class=='building')
  assert(not S.skip[key(0,0)] and S.shapeAt[key(0,0)].flat)
  assert(map.collision.keep and map.warps.keep)
  assert(M.build(S,map,data,16)==0)
  local hasArt=false
  for _,q in ipairs(S.objectQuads) do
    assert(#q==4 and q.own)
    if q.uv[1][1]~=q.uv[2][1] then hasArt=true end
    local xmin,xmax,zmin,zmax=math.huge,-math.huge,math.huge,-math.huge
    for _,p in ipairs(q)do
      xmin=math.min(xmin,p[1]);xmax=math.max(xmax,p[1]);zmin=math.min(zmin,p[3]);zmax=math.max(zmax,p[3])
    end
    assert(xmax-xmin<=8.001 and zmax-zmin<=8.001)
  end
  assert(hasArt,'native tabletop artwork missing')
end
local irregular=scene('table',2,2,true)
irregular.shapeAt[key(2,2)]={flat=true,class='ground',h=0}
assert(M.build(irregular,map,data,16)==0 and not next(irregular.skip))
assert(M.build(scene('table',2,2,false),map,data,16)==0)
assert(M.build(scene('console',2,2,true),map,data,16)==0)
assert(M.build(scene('stool',2,2,true),map,data,16)==0,'unidentified stools must retain native shape')
local outside=scene('table',2,2,true);outside.outdoor=true
assert(M.build(outside,map,data,16)==0)
for _,device in ipairs({{class='console',tiles={{11,12},{27,28},{43,44}}},
    {class='billboard',tiles={{59,60},{75,76},{91,92}}}}) do
  local S=scene('none',0,0,true)
  for r=1,3 do for c=1,2 do
    local k=key(c,r)
    S.shapeAt[k]={class=device.class,h=16,authored=true};S.tileAt[k]=device.tiles[r][c]
  end end
  local pcMap={def={width=2,height=2},tileset={id='TilesetPlayersRoom'}}
  assert(M.build(S,pcMap,data,16)>0 and S.furnitureVisuals.fixtures==1)
  assert(S.skip[key(1,1)] and S.skip[key(2,3)] and not S.skip[key(3,3)])
  local hasFace,hasShelf=false,false
  for _,q in ipairs(S.objectQuads) do
    if q.uv[1][1]~=q.uv[2][1] then
      if q[1][3]==q[3][3] then hasFace=true end
      if q[1][2]==q[3][2] then hasShelf=true end
    end
  end
  assert(hasFace and hasShelf,'upright display and horizontal controls required')
end
-- Two adjacent exact Crystal stools remain TWO round seats with open support
-- zones; they must not become a merged bench or full-cell textured boxes.
local seats=scene('none',0,0,true)
for _,origin in ipairs({1,3})do
  local ids={{2,3},{18,19}}
  for r=1,2 do for c=1,2 do
    local k=key(origin+c-1,r)
    seats.shapeAt[k]={class='stool',h=5,authored=true};seats.tileAt[k]=ids[r][c]
  end end
end
local stoolMap={def={width=2,height=2},tileset={id='TilesetPlayersHouse'}}
assert(M.build(seats,stoolMap,data,16)>0 and seats.furnitureVisuals.sourceStools==2)
assert(seats.furnitureVisuals.fixtures==2 and #seats.objectQuads<=M.MAX_MAP_QUADS)
local footprint={};local bottomContacts={}
for _,q in ipairs(seats.objectQuads)do
  -- Every face uses a material texel, never an entire chair drawing.
  for i=2,4 do assert(q.uv[i][1]==q.uv[1][1] and q.uv[i][2]==q.uv[1][2])end
  local xmin,xmax,zmin,zmax=math.huge,-math.huge,math.huge,-math.huge
  local ymin,ymax=math.huge,-math.huge
  for _,p in ipairs(q)do
    xmin=math.min(xmin,p[1]);xmax=math.max(xmax,p[1]);zmin=math.min(zmin,p[3]);zmax=math.max(zmax,p[3])
    ymin=math.min(ymin,p[2]);ymax=math.max(ymax,p[2])
  end
  assert(xmax-xmin<=8 and zmax-zmin<=8)
  if ymin==5 and ymax==5 then
    for x=xmin,xmax-1 do for z=zmin,zmax-1 do footprint[x..':'..z]=true end end
  end
  if ymin==0 and ymax==0 then
    for x=xmin,xmax-1 do for z=zmin,zmax-1 do bottomContacts[x..':'..z]=true end end
  end
end
assert(footprint['15:15'] and not footprint['8:8'] and not footprint['10:10'], 'seat needs curved perimeter and trimmed corners')
assert(bottomContacts['12:12'] and not bottomContacts['15:15'], 'separate feet with open centre required')
local seatPixels,footPixels=0,0
for _ in pairs(footprint)do seatPixels=seatPixels+1 end
for _ in pairs(bottomContacts)do footPixels=footPixels+1 end
assert(seatPixels<2*16*16 and footPixels==2*4*2*2)
-- Real extracted PlayersHouse1F table and2F bed tile grids. Their claimed
-- bands contain top-facing artwork only; the southern legs/shadow row is a
-- separate floor row and must never be folded into the top surface.
for _,native in ipairs({
  {class='table',height=6,rows={{0x23,0x22,0x22,0x24},{0x25,0x15,0x15,0x35},
    {0x25,0x15,0x15,0x35},{0x33,0x32,0x32,0x34}},shadow={0x1C,0x40,0x40,0x1D}},
  {class='bed',height=7,rows={{0x10,0x11,0x11,0x12},{0x20,0x21,0x21,0x22}},
    shadow={0x30,0x31,0x31,0x32}},
})do
  local S=scene('none',0,0,true)
  for r,row in ipairs(native.rows)do for c,tile in ipairs(row)do
    local k=key(c,r)
    S.shapeAt[k]={class=native.class,h=native.height,authored=true};S.tileAt[k]=tile
  end end
  for c,tile in ipairs(native.shadow)do S.tileAt[key(c,#native.rows+1)]=tile end
  assert(M.build(S,map,data,16)>0 and S.furnitureVisuals.fixtures==1)
  local surfaceCount=0
  for _,q in ipairs(S.objectQuads)do
    if q[1][2]==native.height+.015 and q[1][2]==q[3][2] then
      surfaceCount=surfaceCount+1
      local tx,tz=q[1][1]/8,q[1][3]/8
      local expected=native.rows[tz][tx]
      assert(math.floor(q.uv[1][1]*128/8)==expected%16)
      assert(math.floor(q.uv[1][2]*128/8)==math.floor(expected/16))
    end
  end
  assert(surfaceCount==#native.rows*4)
  for c=1,4 do assert(not S.skip[key(c,#native.rows+1)],'shadow/floor must remain unclaimed')end
end
print('PASS Gen2 furniture: authored rectangular claims only, original art, topology limits, native fallback, collision/doorway preservation')
