-- Elm's exact western healing tray. The original drawing is a horizontal
-- recess with rails, front controls and a small rear display, not a tower.
-- Build after Gen2LabEquipment so its original north-wall context stays valid.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=640}
local rows={{66,67,68,69},{82,83,84,85},{70,71,71,73},{86,87,88,89}}
local function key(x,z)return(z+64)*4096+x+64 end
function M.build(S,map,data,perRow)
 if S.outdoor or S.elmHealingMachine or not(map and map.def and map.def.generation==2 and map.id=='ELMS_LAB' and map.tileset and map.tileset.id=='TilesetLab' and data and data.getPixel)then return 0 end
 if not(map.tileAt and map.warpAtCell and map.isWarpTileCell)then return 0 end
 local w,h=data:getDimensions();if w~=128 or h<48 or(perRow or 16)~=16 then return 0 end
 local cells,sum,index,donors={},0,0,{}
 for rz,row in ipairs(rows)do for rx,t in ipairs(row)do
  local x,z=rx-1,rz+1;local k=key(x,z);local s=S.shapeAt[k]
  if S.skip[k]or(S.doorFold and S.doorFold[k])or S.tileAt[k]~=t or not s or s.class~='console'or not s.authored or s.flat or s.h~=16 then return 0 end
  local ok,actual=pcall(map.tileAt,map,x,z);if not ok or actual~=t then return 0 end
  for _,method in ipairs({'warpAtCell','isWarpTileCell'})do local ok,hit=pcall(map[method],map,math.floor(x/2),math.floor(z/2));if not ok or hit then return 0 end end
  cells[#cells+1]=k
  for py=0,7 do for px=0,7 do
   index=index+1;local ax,ay=t%16*8+px,math.floor(t/16)*8+py
   local ok,r,g,b,a=pcall(data.getPixel,data,ax,ay)
   if not ok or type(r)~='number'or type(g)~='number'or type(b)~='number'or type(a)~='number'or r~=r or g~=g or b~=b or r<0 or r>1 or a~=a or a<.999 then return 0 end
   local level=math.floor(r*3+.5)
   if math.abs(r-level/3)>.01 or math.abs(g-r)>.01 or math.abs(b-r)>.01 then return 0 end
   sum=sum+index*(level+1);donors[level]=donors[level]or G.texelUV(ax,ay,w,h)
  end end
 end end
 if sum~=982361 or not donors[0]or not donors[1]or not donors[2]or not donors[3]then return 0 end
 local out={};local box=G.geometryWriter(out,2048)
 local dark,case,light=donors[0],donors[2],donors[3]
 for _,x in ipairs({2,27})do for _,z in ipairs({3,27})do box(x,0,z,x+3,2,z+3,case)end end
 box(1,2,2,31,7,31,case)
 box(0,7,1,32,8,32,case)
 -- Recessed tray and distinct rails; the cavity stays horizontal.
 box(5,8,9,27,8.3,27,dark)
 box(2,8,9,5,10,27,case);box(27,8,9,30,10,27,case)
 box(3,10,10,4,10.3,26,light);box(28,10,10,29,10.3,26,light)
 box(5,8,26,27,9,28,case)
 -- Rear status housing, complete closed sides/back/top, modest height.
 box(8,8,2,24,14,8,case)
 box(9,9,8,23,13,8.3,dark)
 local function source(x,y)local t=rows[math.floor(y/8)+1][math.floor(x/8)+1];return t%16*8+x%8,math.floor(t/16)*8+y%8 end
 local function art(x0,x1,y0,y1,px,py,pz,top)
  for sy=y0,y1 do local sx=x0
   while sx<=x1 do local n=math.min(x1-sx+1,8-sx%8);local ax,ay=source(sx,sy);local x=px+sx-x0
    local uv={{(ax+.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.05)/h},{(ax+.05)/w,(ay+.05)/h}}
    if top then local z=pz+sy-y0
     out[#out+1]={{x,py,z},{x+n,py,z},{x+n,py,z+1},{x,py,z+1},uv={uv[4],uv[3],uv[2],uv[1]},own=true,shade=.98}
    else local y=py+y1-sy;out[#out+1]={{x,y,pz},{x+n,y,pz},{x+n,y+1,pz},{x,y+1,pz},uv=uv,own=true,shade=1}end
    sx=sx+n
   end
  end
 end
 art(10,21,3,6,10,9,8.32,false)
 art(6,25,10,25,6,8.32,10,true)
 -- Original rounded front control icons become raised horizontal decks.
 box(2,8,28,11,9,31,case);box(21,8,28,30,9,31,case)
 art(3,10,28,30,3,9.02,28,true);art(21,28,28,30,21,9.02,28,true)
 -- Side seams and vents retain the source neutral metal color, no black slab.
 for _,x in ipairs({.98,31})do for z=8,24,4 do box(x,4,z,x+.04,4.5,z+2,donors[1])end end
 if #out>M.MAX_QUADS then return 0 end
 for _,k in ipairs(cells)do S.skip[k]=true;S.ground[k]=16;S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=8}end
 for _,q in ipairs(out)do for i=1,4 do q[i][3]=q[i][3]+16 end;S.objectQuads[#S.objectQuads+1]=q end
 S.elmHealingMachine={models=1,quads=#out,claimedTiles=16,x=0,z=2,bodyHeight=8,trayHeight=10,displayHeight=14}
 return #out
end
return M
