-- Exact Crystal till artwork separated into counter, drawer, keypad and head.
-- Mesh-build only: no input, interaction, collision or per-frame changes.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_FIXTURE_QUADS=320,MAX_MAP_QUADS=1280,MAX_FIXTURES=4}
local floor,min=math.floor,math.min
local function key(x,z)return (z+64)*4096+x+64 end
local rows={{32,33},{48,49}}
local function model(row,w,h)
 local out={};local box=G.geometryWriter(out,2048)
 local function pos(x,y)
  local t=rows[floor(y/8)+1][floor(x/8)+1]
  return t%row*8+x%8,floor(t/row)*8+y%8
 end
 local function donor(x,y)local ax,ay=pos(x,y);return G.texelUV(ax,ay,w,h)end
 local function uv(x,y,n)
  local ax,ay=pos(x,y)
  return {{(ax+.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.95)/h},
   {(ax+n-.05)/w,(ay+.05)/h},{(ax+.05)/w,(ay+.05)/h}}
 end
 local function face(a,b,c,d,u,shade)out[#out+1]={a,b,c,d,uv=u,shade=shade or 1,own=true}end
 local function front(x0,x1,s0,s1,y0,z)
  for sy=s0,s1 do local x=x0;local y=y0+s1-sy
   while x<=x1 do local n=min(x1-x+1,8-x%8)
    face({x,y,z},{x+n,y,z},{x+n,y+1,z},{x,y+1,z},uv(x,sy,n))
    x=x+n
   end
  end
 end
 local cream,grey,dark=donor(3,0),donor(4,1),donor(4,0)
 -- The original counter remains eight pixels high. Its clean neighboring
 -- tiles replace only the machine's ink, retaining the two counter edges.
 box(0,0,0,16,8,16,donor(1,0))
 for z=0,8,8 do for x=0,8,8 do
  local t=x==0 and 62 or 63;local ax,ay=t%row*8,floor(t/row)*8
  local u={{(ax+.05)/w,(ay+.05)/h},{(ax+7.95)/w,(ay+.05)/h},
   {(ax+7.95)/w,(ay+7.95)/h},{(ax+.05)/w,(ay+7.95)/h}}
  face({x,8.015,z},{x+8,8.015,z},{x+8,8.015,z+8},{x,8.015,z+8},u,.98)
 end end
 -- Low closed drawer, horizontal original key deck, and separate printer
 -- tower. No entire 16px source rectangle is stretched onto an upright face.
 box(3,8.03,3,13,11,14,grey)
 front(3,12,13,15,8.03,14.02)
 box(3,11,6,9,12,13,cream)
 for sy=7,12 do
  local u=uv(3,sy,5);local z=7+sy-7
  face({3,12.015,z},{8,12.015,z},{8,12.015,z+1},{3,12.015,z+1},{u[4],u[3],u[2],u[1]},.97)
 end
 -- Rear display with a closed hood and original display pixels, facing
 -- the same direction as the source drawer. Its top has physical depth.
 box(3,12,3,9,18,5.8,grey)
 front(3,8,0,5,12,5.82)
 box(3,18,3,9,18.5,6,cream)
 box(9,11,3,13,15,10,grey)
 front(9,12,5,8,11,10.02)
 box(10,15,4,13,15.4,7,dark)
 -- The source upper-right curl becomes a short stepped paper strip. Only
 -- its white donor is used: surrounding counter pixels are not extruded.
 box(10.5,15.4,5,12.5,18,5.6,cream)
 box(10.5,18,5,12.5,18.6,7,cream)
 return out
end
function M.build(S,map,data,perRow)
 if not(map and map.def and map.def.generation==2 and map.tileset and map.tileset.id=='TilesetMart'and data)
  or S.outdoor or S.martEquipmentVisuals then return 0 end
 local w,h=data:getDimensions();local row=perRow or 16
 if row~=16 or w<128 or h<40 then return 0 end
 local report={fixtures=0,quads=0,models={}}
 for z=1,map.def.height*4-3 do for x=0,map.def.width*4-2 do
  local ok=true;local cells={}
  for dz=0,1 do for dx=0,1 do
   local k=key(x+dx,z+dz);local s=S.shapeAt[k]
   if S.skip[k]or S.tileAt[k]~=rows[dz+1][dx+1]or not s or not s.authored or s.class~='counter'or s.h~=8 then ok=false end
   cells[#cells+1]=k
  end end
  -- Exact clean counter context protects this tiny, shared atlas vocabulary.
  for _,zz in ipairs({z-1,z+2})do for dx=0,1 do
   local k=key(x+dx,zz);local s=S.shapeAt[k]
   if S.tileAt[k]~=62+dx or not s or s.class~='counter'or s.h~=8 then ok=false end
  end end
  if ok and report.fixtures<M.MAX_FIXTURES then
   local q=model(row,w,h)
   if #q<=M.MAX_FIXTURE_QUADS and report.quads+#q<=M.MAX_MAP_QUADS then
    for _,k in ipairs(cells)do S.skip[k]=true;S.ground[k]=72;S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=8}end
    for _,v in ipairs(q)do for i=1,4 do v[i][1]=v[i][1]+x*8;v[i][3]=v[i][3]+z*8 end S.objectQuads[#S.objectQuads+1]=v end
    report.fixtures=report.fixtures+1;report.quads=report.quads+#q
    report.models[#report.models+1]={id='mart_register',x=x,z=z,quads=#q}
   end
  end
 end end
 S.martEquipmentVisuals=report
 return report.quads
end
return M
