-- Crystal's laboratory work desks. Exact endcaps and repeated middle tiles
-- distinguish these from bookshelves that share the same top corner IDs.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=768}
local floor=math.floor
local function key(x,z)return(z+64)*4096+x+64 end
function M.build(S,map,data,perRow)
 if S.outdoor or S.deskVisuals or not data or not map.tileset or map.tileset.id~='TilesetLab' then return 0 end
 perRow=perRow or 16
 local w,h=data:getDimensions();local total,count,teacherCount=0,0,0
 local function valid(x,z,t)
  local k=key(x,z);local s=S.shapeAt[k]
  return not S.skip[k] and S.tileAt[k]==t and s and s.authored and s.class=='table' and s.h==6
 end
 local function donor(t,x,y)return G.texelUV(t%perRow*8+x,floor(t/perRow)*8+y,w,h)end
 -- Academy's small teacher cabinet uses the closed 13/14 cupboard front,
 -- not the long laboratory bench's 15/16/17 skirt. The native fallback
 -- treated this lower band as a wall and attached it to the room shell.
 if map.id=='EARLS_POKEMON_ACADEMY' and perRow==16 and w>=128 and h>=48 then
  for z=0,map.def.height*4-2 do for x=0,map.def.width*4-2 do
   local a,b=S.shapeAt[key(x,z+1)],S.shapeAt[key(x+1,z+1)]
   if valid(x,z,5) and valid(x+1,z,7) and not S.skip[key(x,z+1)] and not S.skip[key(x+1,z+1)]
     and S.tileAt[key(x,z+1)]==0x13 and S.tileAt[key(x+1,z+1)]==0x14
     and a and b and a.class=='wall' and b.class=='wall' then
    local out={};local box=G.geometryWriter(out,256);local xx,zz=x*8,z*8
    local wood,dark=donor(5,4,4),donor(0x13,1,1)
    for _,dx in ipairs({1,13})do for _,dz in ipairs({3,11})do box(xx+dx,0,zz+dz,xx+dx+2,2,zz+dz+2,dark)end end
    box(xx+.8,1.6,zz+2.8,xx+15.2,7,zz+13.2,wood)
    box(xx,7,zz+2,xx+16,8,zz+14,wood)
    for _,dx in ipairs({1.3,8.2})do
     box(xx+dx,2,zz+13.2,xx+dx+6.5,6.5,zz+13.6,wood)
    end
    box(xx+7.7,2,zz+13.6,xx+8.1,6.5,zz+13.8,dark)
    for _,dx in ipairs({6.4,8.8})do box(xx+dx,4.2,zz+13.6,xx+dx+.6,4.8,zz+14,dark)end
    -- The source top band only: no door art stretched across the desktop.
    for c=0,1 do local t=c==0 and 5 or 7;local ax=t*8
     for r=0,1 do local pz=zz+2+r*6;local sy=r*4
      out[#out+1]={{xx+c*8,8.025,pz},{xx+c*8+8,8.025,pz},{xx+c*8+8,8.025,pz+6},{xx+c*8,8.025,pz+6},
       uv={{(ax+.025)/w,(sy+.025)/h},{(ax+7.975)/w,(sy+.025)/h},
        {(ax+7.975)/w,(sy+3.975)/h},{(ax+.025)/w,(sy+3.975)/h}},shade=1,own=true}
     end
    end
    if total+#out<=M.MAX_QUADS then
     for r=0,1 do for c=0,1 do local k=key(x+c,z+r)
      S.skip[k]=true;S.ground[k]=0x24;S.shapeAt[k]={class='building',art='building',h=8,authored=true,flat=false}
     end end
     for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
     total=total+#out;count=count+1;teacherCount=teacherCount+1
    end
   end
  end end
 end
 for z=0,map.def.height*4-2 do for x=0,map.def.width*4-3 do
  if valid(x,z,0x05) and valid(x,z+1,0x15) then
   local n=1
   while n<7 and valid(x+n,z,0x06) and valid(x+n,z+1,0x16)do n=n+1 end
   if n>=2 and valid(x+n,z,0x07) and valid(x+n,z+1,0x17) and floor(0x17/perRow)*8+8<=h then
    local out={};local box=G.geometryWriter(out,384)
    local xx,zz=x*8,z*8;local width=(n+1)*8
    local timber=donor(0x05,3,3);local dark=donor(0x15,0,7);local light=donor(0x06,4,3)
    -- A drawer pedestal on the left and two separate right legs leave
    -- actual knee space, not a solid extrusion below the desktop.
    box(xx+.8,0,zz+1,xx+9,5,zz+15,timber)
    for _,y in ipairs({.5,2.7})do
     box(xx+1.2,y,zz+14.8,xx+8.5,y+1.8,zz+15.3,timber)
     box(xx+3.5,y+.65,zz+15.3,xx+6.2,y+.95,zz+15.6,dark)
    end
    for _,dz in ipairs({1,13.5})do box(xx+width-2.5,0,zz+dz,xx+width-1,5,zz+dz+1.5,timber)end
    box(xx+9,3.6,zz+1,xx+width-2.5,4.5,zz+2,timber)
    box(xx,5,zz,xx+width,6,zz+16,light)
    -- Keep only the source's desktop on the horizontal plane. Its dark
    -- bottom trim belongs on the apron, not stretched across the lid.
    for c=0,n do
     local t=c==0 and 0x05 or(c==n and 0x07 or 0x06)
     for r=0,1 do
      local tt=t+r*perRow;local ax=tt%perRow*8;local ay=floor(tt/perRow)*8
      local sy=r==0 and 8 or 5;local za=zz+r*8;local zb=r==0 and zz+8 or zz+16
      out[#out+1]={{xx+c*8,6.025,za},{xx+(c+1)*8,6.025,za},{xx+(c+1)*8,6.025,zb},{xx+c*8,6.025,zb},
       uv={{(ax+.025)/w,(ay+.025)/h},{(ax+7.975)/w,(ay+.025)/h},{(ax+7.975)/w,(ay+sy-.025)/h},{(ax+.025)/w,(ay+sy-.025)/h}},shade=.97,own=true}
     end
    end
    if total+#out<=M.MAX_QUADS then
     local shape={class='building',art='building',h=6,authored=true,flat=false}
     for c=0,n do for r=0,1 do local k=key(x+c,z+r);S.shapeAt[k]=shape;S.skip[k]=true;S.ground[k]=false end end
     for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
     total=total+#out;count=count+1
    end
   end
  end
 end end
 S.deskVisuals={quads=total,count=count,teacherCabinets=teacherCount};return total
end
return M
