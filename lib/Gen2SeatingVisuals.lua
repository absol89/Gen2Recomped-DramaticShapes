-- Exact House round stools and Earl's verified 4x4 classroom bank:
-- two-place desk and two north-facing chairs. No collision/map mutations.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=2400}
local function key(x,z)return(z+64)*4096+x+64 end
local grid={{0x2A,0x2B,0x2B,0x2C},{0x3A,0x3B,0x3B,0x3C},
 {0x40,0x41,0x40,0x41},{0x50,0x51,0x50,0x51}}
local function houseStools(S,map,data,perRow)
 local w,h=data:getDimensions();if perRow~=16 or w<128 or h<16 then return 0 end
 local total,count=0,0
 local function donor(t,x,y)return G.texelUV(t%16*8+x,math.floor(t/16)*8+y,w,h)end
 -- Source02(7,7) is the cream highlight inside the seat; its pink
 -- upholstery is02(5,7). Do not stretch that highlight over the whole lid.
 local cushion,edge,wood=donor(2,5,7),donor(0x12,4,2),donor(0x12,6,5)
 local highlight=donor(2,7,7)
 for z=0,map.def.height*4-2 do for x=0,map.def.width*4-2 do
  local valid=true
  for r=0,1 do for c=0,1 do
   local k=key(x+c,z+r);local s=S.shapeAt[k]
   if S.skip[k] or S.tileAt[k]~=2+c+r*16 or not s or s.class~='ground' or not s.flat then valid=false end
  end end
  if valid then
   local out={};local box=G.geometryWriter(out,192);local xx,zz=x*8,z*8
   for _,dx in ipairs({4.4,10.2})do for _,dz in ipairs({6.4,12.2})do
    box(xx+dx,0,zz+dz,xx+dx+1.4,4,zz+dz+1.4,wood)
   end end
   local cx,cz=xx+8,zz+10
   for i=0,11 do
    local a,b=i*math.pi/6,(i+1)*math.pi/6
    local ax,az=cx+5.8*math.cos(a),cz+5.8*math.sin(a)
    local bx,bz=cx+5.8*math.cos(b),cz+5.8*math.sin(b)
    out[#out+1]={{cx,5,cz},{ax,5,az},{bx,5,bz},{cx,5,cz},uv=cushion,shade=1,own=true}
    out[#out+1]={{ax,3.8,az},{bx,3.8,bz},{bx,5,bz},{ax,5,az},uv=edge,shade=.88,own=true}
   end
   out[#out+1]={{cx-2,5.015,cz-2},{cx-.2,5.015,cz-2},
    {cx-.2,5.015,cz+1},{cx-2,5.015,cz+1},uv=highlight,shade=.98,own=true}
   if total+#out<=M.MAX_QUADS then
    for r=0,1 do for c=0,1 do local k=key(x+c,z+r)
     S.skip[k]=true;S.ground[k]=0x01;S.shapeAt[k]={class='building',art='building',h=5,authored=true,flat=false}
    end end
    for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
    total=total+#out;count=count+1
   end
  end
 end end
 S.seatingVisuals={quads=total,count=count,stools=count,chairs=0};return total
end
function M.build(S,map,data,perRow)
 if S.outdoor or S.seatingVisuals or not data or not map.tileset then return 0 end
 perRow=perRow or 16
 if map.tileset.id=='TilesetHouse' then return houseStools(S,map,data,perRow)end
 if map.tileset.id~='TilesetLab' or map.id~='EARLS_POKEMON_ACADEMY' then return 0 end
 local w,h=data:getDimensions()
 if perRow~=16 or w<128 or h<48 then return 0 end
 local total,count=0,0
 local function donor(t,x,y)return G.texelUV(t%16*8+x,math.floor(t/16)*8+y,w,h)end
 local desktop,edge=donor(0x2A,3,3),donor(0x2A,3,7)
 local timber,cushion=donor(0x50,5,3),donor(0x40,5,5)
 for z=0,map.def.height*4-4 do for x=0,map.def.width*4-4 do
  local valid=true
  for r=0,3 do for c=0,3 do
   local k=key(x+c,z+r);local s=S.shapeAt[k]
   local class=r<2 and 'wall' or 'ground'
   if S.skip[k] or S.tileAt[k]~=grid[r+1][c+1] or not s or s.class~=class then valid=false end
  end end
  if valid then
   local out={};local box=G.geometryWriter(out,512);local xx,zz=x*8,z*8
   -- The common ground pass draws native floor24 beneath these claims;
   -- do not add a coplanar decorative floor mesh.
   -- A shallow writing slab, apron, and four legs, not a 16px wall.
   box(xx+.5,6,zz+1,xx+31.5,7,zz+12,desktop)
   box(xx+1,4.8,zz+10.8,xx+31,6,zz+12,edge)
   for _,dx in ipairs({1,29.5})do for _,dz in ipairs({2,10})do
    box(xx+dx,0,zz+dz,xx+dx+1.5,6,zz+dz+1.5,timber)
   end end
   for _,offset in ipairs({0,16})do
    local cx=xx+offset
    box(cx+3,4,zz+19,cx+13,5,zz+28,cushion)
    for _,dx in ipairs({3.2,11.4})do for _,dz in ipairs({19.5,26})do
     box(cx+dx,0,zz+dz,cx+dx+1.3,4,zz+dz+1.3,timber)
    end end
    -- The source's south-side slats are an upright backrest with open
    -- daylight beneath its rails. It faces the teaching wall to the north.
    for _,dx in ipairs({3,11.5})do box(cx+dx,4,zz+27,cx+dx+1.5,10,zz+28.5,timber)end
    box(cx+4.5,8,zz+27,cx+11.5,10,zz+28.5,cushion)
    box(cx+4.5,6,zz+27,cx+11.5,6.8,zz+28.5,timber)
   end
   if total+#out<=M.MAX_QUADS then
    for r=0,3 do for c=0,3 do local k=key(x+c,z+r)
     S.skip[k]=true;S.ground[k]=0x24
     S.shapeAt[k]={class='building',art='building',h=r<2 and 7 or 10,authored=true,flat=false}
    end end
    for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
    total=total+#out;count=count+1
   end
  end
 end end
 S.seatingVisuals={quads=total,count=count,chairs=count*2,stools=0};return total
end
return M
