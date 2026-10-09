-- Exact north-wall picture/window panels. Source art is mounted at eye
-- level instead of extruded from the floor. Gameplay tiles stay untouched.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=256}
local patterns={{{0x2D,0x2E},{0x3D,0x3E}},{{0x24,0x4A},{0x34,0x2C}}}
local function key(x,z)return(z+64)*4096+x+64 end
function M.build(S,map,data,perRow)
 if S.outdoor or S.houseWallFixtures or not(map and map.def and map.def.generation==2
   and map.tileset and map.tileset.id=='TilesetHouse' and data)then return 0 end
 perRow=perRow or 16
 local w,h=data:getDimensions();if perRow~=16 or w<128 or h<40 then return 0 end
 local motifs,total=0,0
 local wallColumns={}
 local function tex(tile,px,py)return G.texelUV(tile%16*8+px,math.floor(tile/16)*8+py,w,h)end
 local function uv(tile)
  local x,y=tile%16*8,math.floor(tile/16)*8
  return{{(x+.025)/w,(y+7.975)/h},{(x+7.975)/w,(y+7.975)/h},
   {(x+7.975)/w,(y+.025)/h},{(x+.025)/w,(y+.025)/h}}
 end
 for _,rows in ipairs(patterns)do for x=0,map.def.width*4-2 do
  local targets={};local valid=true
  for r,row in ipairs(rows)do for c,t in ipairs(row)do
   local k=key(x+c-1,r-1);local s=S.shapeAt[k]
   if S.skip[k] or S.tileAt[k]~=t or not s or s.authored or s.flat
      or s.class~='wall' or s.art~='upright' then valid=false end
   targets[#targets+1]=k
  end end
  -- A real adjacent undecorated wall is required for the restored backing.
  local wall=false
  for _,xx in ipairs({x-1,x+2})do for z=0,1 do
   local k=key(xx,z);local s=S.shapeAt[k]
   if S.tileAt[k]==0 and s and s.class=='wall' and not s.flat and not S.skip[k]then wall=true end
  end end
  if valid and wall then
   local out={};local xx=x*8
   -- Only the lower native wall band is replaced here. The room owner keeps
   -- its upper wallpaper/ceiling, at the same z=16 plane. Tile0 is a WALL
   -- donor, intentionally not used to color furniture or the mounted frame.
   for c=0,1 do for r=0,1 do
    local a,b=xx+c*8,r*8
    out[#out+1]={{a,b,16},{a+8,b,16},{a+8,b+8,16},{a,b+8,16},uv=uv(0),shade=.9,own=true}
   end end
   local box=G.geometryWriter(out,96)
   local frame=tex(rows[1][1],1,1)
   local window=rows[1][1]==0x24
   if window then
    -- Keep the original pixel drawing behind a genuinely deeper casing.
    -- Nothing is cut into the room wall: wallColumns still describes16px.
    local casing=tex(rows[2][1],3,6)
    box(xx,17.6,16.05,xx+16,18.4,19.25,casing)
    box(xx,33.6,16.05,xx+16,34.4,18,casing)
    box(xx,18.4,16.05,xx+.65,33.6,18,casing)
    box(xx+15.35,18.4,16.05,xx+16,33.6,18,casing)
    local function patch(sx,sy,width,depth,shade,component)
     local tile=rows[math.floor(sy/8)+1][math.floor(sx/8)+1]
     local ax,ay=tile%16*8+sx%8,math.floor(tile/16)*8+sy%8
     local bottom=33-sy
     local q={{xx+sx,bottom,depth},{xx+sx+width,bottom,depth},
       {xx+sx+width,bottom+1,depth},{xx+sx,bottom+1,depth},
       uv={{(ax+.025)/w,(ay+.975)/h},{(ax+width-.025)/w,(ay+.975)/h},
           {(ax+width-.025)/w,(ay+.025)/h},{(ax+.025)/w,(ay+.025)/h}},
       shade=shade,own=true,houseWindow=component}
     out[#out+1]=q
    end
    for r,row in ipairs(rows)do for c,t in ipairs(row)do
     local a,b=xx+(c-1)*8,18+(2-r)*8
     out[#out+1]={{a,b,16.325},{a+8,b,16.325},{a+8,b+8,16.325},{a,b+8,16.325},
       uv=uv(t),shade=.96,own=true,houseWindow='glass'}
    end end
    -- The exact native curtains taper inward row-by-row. Retain those
    -- source pixels and silhouette; small closed folds provide depth.
    local widths={4,4,4,3,3,2,3,3,4,4,3,2}
    for sy=0,11 do for side=0,1 do
     local width=widths[sy+1];local sx=side==0 and 0 or 16-width
     local z=17.45+(sy%3)*.06;local y=33-sy
     patch(sx,sy,width,z,.95,'curtain')
     local inner=xx+(side==0 and width or sx)
     local tint=tex(rows[math.floor(sy/8)+1][side+1],side==0 and width-1 or 8-width,sy%8)
     out[#out+1]={{inner,y,16.35},{inner,y,z},{inner,y+1,z},{inner,y+1,16.35},uv=tint,shade=.78,own=true,houseWindow='fold'}
     for _,cy in ipairs({y,y+1})do
      out[#out+1]={{xx+sx,cy,16.35},{xx+sx+width,cy,16.35},
        {xx+sx+width,cy,z},{xx+sx,cy,z},uv=tint,shade=.88,own=true,houseWindow='fold'}
     end
    end end
    -- Soften only native bright reflection pixels inside the panes.
    -- Frames/curtains and the separate picture never sample this path.
    if data.getPixel then for sy=1,8 do for _,sx in ipairs({4,5,6,9,10,11})do
     local tile=rows[math.floor(sy/8)+1][math.floor(sx/8)+1]
     local r,g,b,a=data:getPixel(tile%16*8+sx%8,math.floor(tile/16)*8+sy%8)
     if a>.99 and math.min(r,g,b)>.9 then patch(sx,sy,1,16.35,.74,'reflection')end
    end end end
   else
   box(xx,17.6,16.05,xx+16,18,16.8,frame)
   box(xx,34,16.05,xx+16,34.4,16.8,frame)
   box(xx,18,16.05,xx+.4,34,16.8,frame)
   box(xx+15.6,18,16.05,xx+16,34,16.8,frame)
   for r,row in ipairs(rows)do for c,t in ipairs(row)do
    local a,b=xx+(c-1)*8,18+(2-r)*8
    out[#out+1]={{a,b,16.825},{a+8,b,16.825},{a+8,b+8,16.825},{a,b+8,16.825},uv=uv(t),shade=1,own=true}
   end end
   end
   if total+#out<=M.MAX_QUADS then
    -- Explicit room-finish contract: this is shallow hanging art, not a
    -- cabinet requiring a recessed wall behind its full model height.
    wallColumns[x]=16;wallColumns[x+1]=16
    for _,k in ipairs(targets)do
     -- h describes the restored lower wall, not the elevated hanging art;
     -- the upper room finish must start at16, not leave a34px hole.
     S.shapeAt[k]={class='building',art='building',h=16,authored=true,flat=false}
     S.skip[k]=true;S.ground[k]=1
    end
    for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
    total=total+#out;motifs=motifs+1
   end
  end
 end end
 S.houseWallFixtures={motifs=motifs,claimedCells=motifs*4,quads=total,artBottom=18,artTop=34,wallColumns=wallColumns}
 return motifs
end
return M
