-- Exact Lab trash-can drawing. The inherited table pin misclassified this
-- four-tile prop; Elm's bg-event at cell(9,3) identifies it as the trash can.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=384}
local function key(x,z)return(z+64)*4096+x+64 end
local rows={{0x0E,0x0F},{0x1E,0x1F}}
function M.build(S,map,data,perRow)
 if S.outdoor or S.smallProps or not data or not data.getPixel or not map.tileset or map.tileset.id~='TilesetLab' then return 0 end
 local w,h=data:getDimensions();perRow=perRow or 16
 local tones={}
 for _,row in ipairs(rows)do for _,t in ipairs(row)do
  local ax,ay=t%perRow*8,math.floor(t/perRow)*8
  if ax+8>w or ay+8>h then return 0 end
  for yy=0,7 do for xx=0,7 do
   local r,g,b,a=data:getPixel(ax+xx,ay+yy)
   if a>.5 then tones[#tones+1]={l=(r+g+b)/3,x=ax+xx,y=ay+yy}end
  end end
 end end
 if #tones==0 then return 0 end
 table.sort(tones,function(a,b)return a.l<b.l end)
 local function tone(frac)
  local p=tones[math.max(1,math.floor(#tones*frac))]
  return G.texelUV(p.x,p.y,w,h)
 end
 local dark,metal,edge,paper=tone(.05),tone(.65),tone(.85),tone(1)
 local total,count=0,0
 for z=0,map.def.height*4-2 do for x=0,map.def.width*4-2 do
  local cells={};local valid=true
  for r,row in ipairs(rows)do for c,t in ipairs(row)do
   local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
   if S.skip[k] or S.tileAt[k]~=t or not s or not s.authored or s.class~='table' or s.h~=6 then valid=false end
   cells[#cells+1]=k
  end end
  if valid then
   local out={};local cx,cz=x*8+8,z*8+8
   local function at(a,r,y)return {cx+math.cos(a)*r,y,cz+math.sin(a)*r}end
   local function face(a,b,c,d,uv,shade)out[#out+1]={a,b,c,d,uv=uv,shade=shade,own=true}end
   for i=0,11 do
    local a,b=i*math.pi/6,(i+1)*math.pi/6
    -- Tapered twelve-sided shell, thick rim, recessed inner wall and floor.
    face(at(a,4.3,0),at(b,4.3,0),at(b,5.5,9),at(a,5.5,9),metal,.75+.15*math.sin((a+b)/2))
    face(at(a,5.5,9),at(b,5.5,9),at(b,4.4,9),at(a,4.4,9),edge,.96)
    face(at(b,3.3,2),at(a,3.3,2),at(a,4.4,9),at(b,4.4,9),dark,.74)
    face({cx,2,cz},at(a,3.3,2),at(b,3.3,2),{cx,2,cz},dark,.65)
   end
   -- A small pale scrap lies inside, below the rim, using the source's
   -- own light texel. It does not close the opening like the old flat art.
   local box=G.geometryWriter(out,64)
   box(cx-1.8,2.05,cz-1,cx+1.2,2.35,cz+.7,paper)
   box(cx-.8,2.35,cz-.6,cx+.5,2.9,cz+.4,paper)
   if total+#out<=M.MAX_QUADS then
    for _,k in ipairs(cells)do S.shapeAt[k]={class='building',art='building',h=9,authored=true,flat=false};S.skip[k]=true;S.ground[k]=false end
    for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
    total=total+#out;count=count+1
   end
  end
 end end
 S.smallProps={trashCans=count,quads=total};return total
end
return M
