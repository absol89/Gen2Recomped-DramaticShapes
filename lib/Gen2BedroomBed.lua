-- The live decorated bedroom adds this bed although the static generated map
-- omits it. Exact source03/04,13/14,23/24,33/34 at(0,8), not a wall/door.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=360}
local rows={{3,4},{19,20},{35,36},{51,52}}
local function key(x,z)return(z+64)*4096+x+64 end
function M.build(S,map,data,perRow)
 if S.outdoor or S.bedroomBed or not(map and map.def and map.def.generation==2
  and map.id=='PLAYERS_HOUSE_2F'and map.tileset and map.tileset.id=='TilesetPlayersRoom'
  and map.def.width==4 and map.def.height==3 and data and data.getPixel)then return 0 end
 if type(map.tileAt)~='function'or type(map.warpAtCell)~='function'or type(map.isWarpTileCell)~='function'then return 0 end
 local w,h=data:getDimensions()
 if (perRow or 16)~=16 or w<128 or h<32 then return 0 end
 local cells={}
 for z,row in ipairs(rows)do for x,t in ipairs(row)do
  local k=key(x-1,z+7);local s=S.shapeAt[k]
  if S.skip[k]or(S.doorFold and S.doorFold[k])or S.tileAt[k]~=t or not s or s.authored or s.class~='wall'or s.flat or s.h~=16 then return 0 end
  local ok,actual=pcall(map.tileAt,map,x-1,z+7)
  if not ok or actual~=t then return 0 end
  local cx,cz=math.floor((x-1)/2),math.floor((z+7)/2)
  for _,method in ipairs({'warpAtCell','isWarpTileCell'})do
   local called,hit=pcall(map[method],map,cx,cz);if not called or hit then return 0 end
  end
  cells[#cells+1]=k
  for py=0,7 do for px=0,7 do
   local ok,r,g,b,a=pcall(data.getPixel,data,t%16*8+px,math.floor(t/16)*8+py)
   if not ok or type(a)~='number'or a~=a or a<.999 then return 0 end
  end end
 end end
 local function pos(x,y)local t=rows[math.floor(y/8)+1][math.floor(x/8)+1];return t%16*8+x%8,math.floor(t/16)*8+y%8 end
 -- Distinct source case trim, dark seam and white bedding, not an arbitrary
 -- same-ID opaque sprite. Structures supplies the original grayscale pixels.
 for _,p in ipairs({{5,2,.6,.75},{5,3,0,.1},{5,10,.9,1}})do
  local x,y=pos(p[1],p[2]);local ok,r,g,b=pcall(data.getPixel,data,x,y)
  if not ok or type(r)~='number'or type(g)~='number'or type(b)~='number'then return 0 end
  local l=(r+g+b)/3;if l~=l or l<p[3]or l>p[4]then return 0 end
 end
 local out={};local box=G.geometryWriter(out,2048)
 local function donor(x,y)local ax,ay=pos(x,y);return G.texelUV(ax,ay,w,h)end
 local case,bedding=donor(5,2),donor(5,10)
 for _,x in ipairs({1,12})do for _,z in ipairs({1,28})do box(x,0,z,x+2,2,z+2,case)end end
 box(0,2,0,16,3,32,case)
 box(2,3,3,14,5,29,bedding)
 box(0,3,0,16,8,2,case)
 box(0,3,30,16,6,32,case)
 -- The original blanket and pillow stay on a horizontal mattress, with
 -- sprite head/foot bands excluded from its deck rather than stretched.
 for sy=6,23 do
  local z0=3+(sy-6)*26/18;local z1=3+(sy-5)*26/18
  local x=2
  while x<=13 do local n=math.min(14-x,8-x%8);local ax,ay=pos(x,sy)
   out[#out+1]={{x,5.025,z0},{x+n,5.025,z0},{x+n,5.025,z1},{x,5.025,z1},own=true,shade=.98,
    uv={{(ax+.05)/w,(ay+.05)/h},{(ax+n-.05)/w,(ay+.05)/h},{(ax+n-.05)/w,(ay+.95)/h},{(ax+.05)/w,(ay+.95)/h}}}
   x=x+n
  end
 end
 if #out>M.MAX_QUADS then return 0 end
 for _,k in ipairs(cells)do S.skip[k]=true;S.ground[k]=1;S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}end
 for _,q in ipairs(out)do for i=1,4 do q[i][3]=q[i][3]+64 end S.objectQuads[#S.objectQuads+1]=q end
 S.bedroomBed={models=1,quads=#out,claimedTiles=8,x=0,z=8,bedHeight=5,headboardHeight=8}
 return #out
end
return M
