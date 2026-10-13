-- Native atlas proves these two Radio2F fixtures are potted foliage, not
-- studio glass. Exact pattern only; distinct western long fixture untouched.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=5600,MAX_FIXTURE_QUADS=700,MAX_FIXTURES=24}
local layouts={
 {{128,129},{130,131},{68,69},{74,75}},
 -- The three large green panels on Radio Tower1F are the tileset's second
 -- complete planter drawing. They are foliage, not ceiling-high walls.
 {{0x46,0x47},{0x48,0x49},{0x44,0x45},{0x4A,0x4B}},
}
local function key(x,z)return(z+64)*4096+x+64 end
local function model(rows,w,h)
 local out={};local box=G.geometryWriter(out,4096)
 local function donor(x,y)
  local t=rows[math.floor(y/8)+1][math.floor(x/8)+1]
  return G.texelUV(t%16*8+x%8,math.floor(t/16)*8+y%8,w,h)
 end
 local light,dark=donor(4,3),donor(7,18)
 local pot,rim=donor(4,24),donor(7,27)
 box(4,0,20,12,5,28,pot)
 box(3,5,19,13,6,29,rim)
 box(4,6,20,12,6.05,28,donor(8,23))
 box(7,6,23,9,10,25,pot)
 -- Two overlapping lobes follow the source's stacked foliage. Emit only
 -- exterior 2px voxel faces; no interior caps, meshes or per-frame caches.
 local function occupied(x,y,z)
  if x<0 or x>7 or y<0 or y>7 or z<0 or z>7 then return false end
  local px,pz=x*2+1-8,z*2+1-8;local py=y*2+1
  return (px*px+pz*pz)/49+(py-5)^2/36<=1
      or (px*px+pz*pz)/36+(py-11)^2/25<=1
 end
 local function face(a,b,c,d,u,shade)out[#out+1]={a,b,c,d,uv=u,shade=shade,own=true}end
 for y=0,7 do for z=0,7 do for x=0,7 do if occupied(x,y,z)then
  local a,b,c=x*2,8+y*2,16+z*2
  local u=(y>=5 or (x+2*y+z)%5==0)and light or dark
  if not occupied(x,y+1,z)then face({a,b+2,c},{a+2,b+2,c},{a+2,b+2,c+2},{a,b+2,c+2},light,1)end
  if not occupied(x,y-1,z)then face({a,b,c+2},{a+2,b,c+2},{a+2,b,c},{a,b,c},dark,.7)end
  if not occupied(x,y,z+1)then face({a,b,c+2},{a+2,b,c+2},{a+2,b+2,c+2},{a,b+2,c+2},u,.92)end
  if not occupied(x,y,z-1)then face({a+2,b,c},{a,b,c},{a,b+2,c},{a+2,b+2,c},u,.83)end
  if not occupied(x-1,y,z)then face({a,b,c},{a,b,c+2},{a,b+2,c+2},{a,b+2,c},u,.85)end
  if not occupied(x+1,y,z)then face({a+2,b,c+2},{a+2,b,c},{a+2,b+2,c},{a+2,b+2,c+2},u,.88)end
 end end end end
 return out
end
function M.build(S,map,data,perRow)
 if S.outdoor or S.radioFixtures or not(map and map.def and map.def.generation==2
  and map.tileset and map.tileset.id=='TilesetRadioTower'and data)then return 0 end
 local w,h=data:getDimensions()
 if (perRow or 16)~=16 or w<128 or h<72 then return 0 end
 local report={models=0,quads=0,claimedTiles=0,fixtures={}}
 local tw,th=map.def.width*4,map.def.height*4
 for _,rows in ipairs(layouts)do for z=0,th-4 do for x=0,tw-2 do
  local cells={};local ok=true
  for r,tiles in ipairs(rows)do for c,t in ipairs(tiles)do
   local xx,zz=x+c-1,z+r-1;local k=key(xx,zz);local s=S.shapeAt[k]
   if S.skip[k]or S.tileAt[k]~=t or map:tileAt(xx,zz)~=t
    or not s or s.class~='wall'or s.flat or s.h~=16 then ok=false end
   if map.warpAtCell and map:warpAtCell(math.floor(xx/2),math.floor(zz/2))then ok=false end
   cells[#cells+1]=k
  end end
  if ok and report.models<M.MAX_FIXTURES then
   local q=model(rows,w,h)
   if #q<=M.MAX_FIXTURE_QUADS and report.quads+#q<=M.MAX_QUADS then
    for _,k in ipairs(cells)do
     S.skip[k]=true;S.ground[k]=1 -- RadioFloor aliases this to baked42 afterward.
     S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}
    end
    for _,v in ipairs(q)do for i=1,4 do v[i][1]=v[i][1]+x*8;v[i][3]=v[i][3]+z*8 end S.objectQuads[#S.objectQuads+1]=v end
    report.models=report.models+1;report.quads=report.quads+#q;report.claimedTiles=report.claimedTiles+#cells
    report.fixtures[#report.fixtures+1]={id='potted_foliage',x=x,z=z,quads=#q}
   end
  end
 end end end
 S.radioFixtures=report
 return report.quads
end
return M
