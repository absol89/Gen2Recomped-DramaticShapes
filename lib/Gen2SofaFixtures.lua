-- Exact Mr Pokemon couch: native23/24/24/25 over57/58/58/59. The wall22
-- behind it is separate architecture, not another16px of couch height.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=1024}
local function key(x,z)return(z+64)*4096+x+64 end
local rows={{0x23,0x24,0x24,0x25},{0x57,0x58,0x58,0x59}}
local plans={
 MR_POKEMONS_HOUSE={tileset='TilesetFacility',width=4,height=4,xy={{4,2}},wall=true},
 SILPH_CO_1F={tileset='TilesetFacility',width=8,height=4,xy={{16,4},{20,4},{16,8}}},
 POWER_PLANT={tileset='TilesetFacility',width=10,height=9,xy={{12,2},{16,2}}},
}
local function model(w,h)
 local out={};local box=G.geometryWriter(out,1024)
 local function donor(x,y)
  local t=rows[math.floor(y/8)+1][math.floor(x/8)+1]
  return G.texelUV(t%16*8+x%8,math.floor(t/16)*8+y%8,w,h)
 end
 local cloth,shadow,feet=donor(6,4),donor(5,6),donor(5,14)
 local backCloth=donor(6,3)
 for _,x in ipairs({2,28})do for _,z in ipairs({3,12})do box(x,0,z,x+2,1.5,z+2,feet)end end
 box(1,1.5,2,31,3.5,15,shadow)
 box(4,3.5,4.5,15.6,5.2,14,cloth)
 box(16.4,3.5,4.5,28,5.2,14,cloth)
 box(2,3,1,30,10,4,shadow)
 box(4,5.5,3.8,15.6,9.5,4.5,backCloth)
 box(16.4,5.5,3.8,28,9.5,4.5,backCloth)
 for _,x in ipairs({0,28})do
  box(x,2,3,x+4,6.5,15,shadow)
  box(x+.4,6.5,3.5,x+3.6,7.3,14.5,cloth)
 end
 return out
end
function M.build(S,map,data,perRow)
 local plan=map and plans[map.id]
 if not(plan and map.def and map.def.generation==2
   and map.def.width==plan.width and map.def.height==plan.height
   and map.tileset and map.tileset.id==plan.tileset and data)
   or S.outdoor or S.sofaFixtures then return 0 end
 if type(map.tileAt)~='function' or type(map.warpAtCell)~='function' or type(map.isWarpTileCell)~='function' then return 0 end
 perRow=perRow or 16;local w,h=data:getDimensions()
 if perRow~=16 or w<128 or h<48 then return 0 end
 local out,claims,wallCells,wallColumns={}, {},{},{}
 for _,pos in ipairs(plan.xy)do
  local x0,z0=pos[1],pos[2];local cells={};local walls={};local valid=true
  if plan.wall then for z=z0-2,z0-1 do for x=x0,x0+3 do
   local k=key(x,z);local s=S.shapeAt[k]
   if S.skip[k]or(S.doorFold and S.doorFold[k])or S.tileAt[k]~=0x22 or map:tileAt(x,z)~=0x22
    or not s or s.authored or s.class~='wall'or s.art~='upright'or s.flat or s.h~=16
    or map:warpAtCell(math.floor(x/2),math.floor(z/2))or map:isWarpTileCell(math.floor(x/2),math.floor(z/2))then valid=false end
   walls[#walls+1]=k
  end end end
  for dz=0,1 do for dx=0,3 do
   local x,z=x0+dx,z0+dz;local k=key(x,z);local s=S.shapeAt[k];local t=rows[dz+1][dx+1]
   if S.skip[k]or(S.doorFold and S.doorFold[k])or S.tileAt[k]~=t or map:tileAt(x,z)~=t
    or not s or s.authored or s.class~='wall'or s.art~='upright'or s.flat or s.h~=16
    or map:warpAtCell(math.floor(x/2),math.floor(z/2))or map:isWarpTileCell(math.floor(x/2),math.floor(z/2))then valid=false end
   cells[#cells+1]={k=k,x=x,z=z}
  end end
  for z=z0+2,z0+3 do for x=x0,x0+3 do
   local k=key(x,z);local s=S.shapeAt[k];local t=(x+z)%2==0 and 1 or 0x26
   if S.tileAt[k]~=t or map:tileAt(x,z)~=t or not s or s.class~='ground'or not s.flat or(s.h or 0)~=0 then valid=false end
  end end
  if valid then
   local q=model(w,h)
   if #out+#q<=M.MAX_QUADS then
    for _,v in ipairs(q)do for i=1,4 do v[i][1]=v[i][1]+x0*8;v[i][3]=v[i][3]+z0*8 end out[#out+1]=v end
    for _,c in ipairs(cells)do claims[#claims+1]=c end
    for _,k in ipairs(walls)do wallCells[#wallCells+1]=k end
    if plan.wall then for x=x0,x0+3 do wallColumns[x]=16 end end
   end
  end
 end
 if #claims==0 then return 0 end
 for _,c in ipairs(claims)do
  S.skip[c.k]=true;S.ground[c.k]=(c.x+c.z)%2==0 and 1 or 0x26
  S.shapeAt[c.k]={class='building',art='building',authored=true,flat=false,h=5.2}
 end
 for _,k in ipairs(wallCells)do local fixed={};for field,value in pairs(S.shapeAt[k])do fixed[field]=value end
  fixed.authored=true;fixed.h=16;S.shapeAt[k]=fixed end
 for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
 S.sofaFixtures={count=#claims/8,quads=#out,claimedTiles=#claims,wallPins=#wallCells,
  wallColumns=wallColumns,height=10}
 return #out
end
return M
