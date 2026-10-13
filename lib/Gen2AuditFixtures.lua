-- Exact room-specific fixtures found by the 208-map visual audit. These
-- replace only render claims; map collision, events, warps and ROM data stay
-- untouched. Each plan is guarded by its complete native source footprint.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=3600}
local floor=math.floor
local function key(x,z)return(z+64)*4096+x+64 end
local function tex(data,perRow,w,h,tile,px,py)
 return G.texelUV((tile%perRow)*8+(px or 4),floor(tile/perRow)*8+(py or 4),w,h)
end
local function claim(S,cells,ground)
 for _,c in ipairs(cells)do local k=key(c[1],c[2]);S.skip[k]=true;S.ground[k]=ground
  S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}
 end
end
local function add(out,q,ox,oz)
 for _,face in ipairs(q)do for i=1,4 do face[i][1]=face[i][1]+ox;face[i][3]=face[i][3]+oz end;out[#out+1]=face end
end
local function soulFixture(data,perRow,w,h,right)
 local out={};local box=G.geometryWriter(out,128)
 local wood=tex(data,perRow,w,h,0x37,3,4);local dark=tex(data,perRow,w,h,right,5,5)
 for _,x in ipairs({1,13})do for _,z in ipairs({3,12})do box(x,0,z,x+2,4,z+2,wood)end end
 box(.5,4,2,15.5,6,15,wood);box(2,6,3,14,14,6,dark)
 box(1.5,13.5,2.5,14.5,15,6.5,wood)
 return out
end
local function wiseFixture(data,perRow,w,h)
 local out={};local box=G.geometryWriter(out,96);local wood=tex(data,perRow,w,h,0x40,4,4);local dark=tex(data,perRow,w,h,0x41,4,4)
 for _,x in ipairs({1,5})do for _,z in ipairs({2,13})do box(x,0,z,x+2,5,z+2,wood)end end
 box(.5,5,1,7.5,8,15,wood);box(1.2,6,14.7,6.8,7.3,15.4,dark)
 return out
end
local function trainerTable(S,data,perRow,w,h,x,z,rw,rh)
 local out={};local box=G.geometryWriter(out,512);local first=S.tileAt[key(x,z)]
 local wood=tex(data,perRow,w,h,first,4,4);local dark=tex(data,perRow,w,h,first,1,6)
 local width,depth=rw*8,rh*8
 for _,xx in ipairs({2,width-5})do for _,zz in ipairs({2,depth-5})do box(xx,0,zz,xx+3,7,zz+3,wood)end end
 box(1,6,1,width-1,8,depth-1,wood)
 box(1,4,1,width-1,6,3,dark);box(1,4,depth-3,width-1,6,depth-1,dark)
 box(1,4,3,3,6,depth-3,dark);box(width-3,4,3,width-1,6,depth-3,dark)
 -- Preserve every source tile as horizontal top art; no stretched texture.
 for dz=0,rh-1 do for dx=0,rw-1 do local tile=S.tileAt[key(x+dx,z+dz)]
  local ax,ay=(tile%perRow)*8,floor(tile/perRow)*8
  out[#out+1]={{dx*8,8.02,dz*8},{dx*8+8,8.02,dz*8},{dx*8+8,8.02,dz*8+8},{dx*8,8.02,dz*8+8},
   uv={{(ax+.03)/w,(ay+.03)/h},{(ax+7.97)/w,(ay+.03)/h},{(ax+7.97)/w,(ay+7.97)/h},{(ax+.03)/w,(ay+7.97)/h}},shade=.98,own=true}
 end end
 return out
end
local function exactRect(S,map,x,z,rw,rh,corners)
 local cells={}
 if S.tileAt[key(x,z)]~=corners[1]or S.tileAt[key(x+rw-1,z)]~=corners[2]
   or S.tileAt[key(x,z+rh-1)]~=corners[3]or S.tileAt[key(x+rw-1,z+rh-1)]~=corners[4]then return end
 for dz=0,rh-1 do for dx=0,rw-1 do local xx,zz=x+dx,z+dz;local k=key(xx,zz);local s=S.shapeAt[k]
  if S.skip[k]or not s or s.flat or (s.class~='wall'and s.class~='counter'and s.class~='table')
    or map:warpAtCell(floor(xx/2),floor(zz/2))then return end
  cells[#cells+1]={xx,zz}
 end end
 return cells
end
function M.build(S,map,data,perRow)
 if S.outdoor or S.auditFixtures or not(map and map.def and map.def.generation==2 and data)then return 0 end
 perRow=perRow or 16;local w,h=data:getDimensions();local out={};local report={models=0,quads=0,claims=0,kinds={}}
 if map.id=='SOUL_HOUSE'and map.tileset.id=='TilesetHouse'then
  for _,z in ipairs({4,8,12})do for _,x in ipairs({0,2,4,6,12,14,16,18})do
   local right=S.tileAt[key(x+1,z+1)];local cells={};local ok=S.tileAt[key(x,z)]==0x37 and S.tileAt[key(x+1,z)]==0x28 and S.tileAt[key(x,z+1)]==0x38 and(right==0x3F or right==0x4E)
   for dz=0,1 do for dx=0,1 do local k=key(x+dx,z+dz);local s=S.shapeAt[k];if S.skip[k]or not s or s.flat or s.class~='wall'then ok=false end;cells[#cells+1]={x+dx,z+dz}end end
   if ok then local q=soulFixture(data,perRow,w,h,right);if #out+#q<=M.MAX_QUADS then claim(S,cells,1);add(out,q,x*8,z*8);report.models=report.models+1;report.claims=report.claims+4;report.kinds.memorial=(report.kinds.memorial or 0)+1 end end
  end end
 elseif map.id=='WISE_TRIOS_ROOM'and map.tileset.id=='TilesetTraditionalHouse'then
  local positions={};for x=0,7 do positions[#positions+1]={x,4};positions[#positions+1]={x,12}end
  for _,p in ipairs({{6,6},{7,6},{6,10},{7,10}})do positions[#positions+1]=p end
  for _,p in ipairs(positions)do local x,z=p[1],p[2];local cells={{x,z},{x,z+1}};local a,b=S.shapeAt[key(x,z)],S.shapeAt[key(x,z+1)]
   if S.tileAt[key(x,z)]==0x40 and S.tileAt[key(x,z+1)]==0x41 and a and b and not a.flat and not b.flat and not S.skip[key(x,z)]and not S.skip[key(x,z+1)]then
    local q=wiseFixture(data,perRow,w,h);if #out+#q<=M.MAX_QUADS then claim(S,cells,0x50);add(out,q,x*8,z*8);report.models=report.models+1;report.claims=report.claims+2;report.kinds.storage=(report.kinds.storage or 0)+1 end
   end
  end
 elseif ({ECRUTEAK_ITEMFINDER_HOUSE=true,ECRUTEAK_LUGIA_SPEECH_HOUSE=true,
     VIOLET_NICKNAME_SPEECH_HOUSE=true})[map.id]and map.tileset.id=='TilesetTraditionalHouse'then
  local cells=exactRect(S,map,6,6,4,4,{0x23,0x24,0x33,0x34})
  if cells then local q=trainerTable(S,data,perRow,w,h,6,6,4,4)
   if #q<=M.MAX_QUADS then claim(S,cells,1);add(out,q,6*8,6*8);report.models=1;report.claims=#cells;report.kinds.traditional_table=1 end
  end
 elseif map.id=='TRAINER_HOUSE_1F'and map.tileset.id=='TilesetHouse'then
  for _,p in ipairs({{6,8,8,8,{0x26,0x29,0x3C,0x3B}},{14,18,4,4,{0x26,0x29,0x3C,0x3B}}})do
   local cells=exactRect(S,map,p[1],p[2],p[3],p[4],p[5]);if cells then local q=trainerTable(S,data,perRow,w,h,p[1],p[2],p[3],p[4])
    if #out+#q<=M.MAX_QUADS then claim(S,cells,1);add(out,q,p[1]*8,p[2]*8);report.models=report.models+1;report.claims=report.claims+#cells;report.kinds.table=(report.kinds.table or 0)+1 end
   end
  end
 end
 for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
 report.quads=#out;S.auditFixtures=report;return #out
end
return M
