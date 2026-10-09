-- Elm's exact rear instrument bench, not a generic console replacement.
-- Source 0A..0D/1A..1D contains a CRT, controls and equipment housing;
-- the south25/26/26/27 strip is its drawn support. Render metadata only.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=768}
local function key(x,z)return(z+64)*4096+x+64 end
local rows={{0x0A,0x0B,0x0C,0x0D},{0x1A,0x1B,0x1C,0x1D},{0x25,0x26,0x26,0x27}}
local function model(data,perRow)
 local w,h=data:getDimensions();local out={};local box=G.geometryWriter(out,2048)
 local function source(x,y)
  local t=rows[math.floor(y/8)+1][math.floor(x/8)+1]
  return t%perRow*8+x%8,math.floor(t/perRow)*8+y%8
 end
 local function donor(x,y)local ax,ay=source(x,y);return G.texelUV(ax,ay,w,h)end
 local function face(a,b,c,d,u,shade)out[#out+1]={a,b,c,d,uv=u,shade=shade or 1,own=true}end
 local function art(x0,x1,y0,y1,px,py,pz,horizontal)
  for sy=y0,y1 do
   local sx=x0
   while sx<=x1 do
    local n=math.min(x1-sx+1,8-sx%8);local ax,ay=source(sx,sy)
    local uv={{(ax+.025)/w,(ay+.975)/h},{(ax+n-.025)/w,(ay+.975)/h},
      {(ax+n-.025)/w,(ay+.025)/h},{(ax+.025)/w,(ay+.025)/h}}
    local x=px+sx-x0
    if horizontal then
     local z=pz+sy-y0
     face({x,py,z},{x+n,py,z},{x+n,py,z+1},{x,py,z+1},{uv[4],uv[3],uv[2],uv[1]},.98)
    else
     local y=py+y1-sy
     face({x,y,pz},{x+n,y,pz},{x+n,y+1,pz},{x,y+1,pz},uv,.97)
    end
    sx=sx+n
   end
  end
 end
 local body,dark,bench=donor(3,3),donor(4,4),donor(3,17)
 -- Three independent stations; the old uninterrupted slab visually fused
 -- the CRT, controller, and equipment enclosure into one gray mass.
 for _,span in ipairs({{1,13},{14.4,21},{22.4,31}})do
  for _,x in ipairs({span[1],span[2]-2})do
   for _,z in ipairs({9,19})do box(x,0,z,x+2,5,z+2,bench)end
  end
  box(span[1],5,8,span[2],6,21,body)
  box(span[1],4.3,20.8,span[2],5.5,22,bench)
 end
 -- Left CRT: deep closed hood, inset native screen, separate keyboard.
 box(3,6,10,13,7,19,body)
 box(3,10,10,13,18,15.2,body)
 box(4,7,11,12,10,14,body)
 box(4,11,15.2,12,17,15.7,dark)
 art(4,11,4,9,4,11,15.72,false)
 art(3,12,11,14,3,7.025,16,true)
 -- Narrow central controller and distinct right-hand equipment enclosure.
 box(14,6,10,21,17,16.5,body)
 art(14,20,3,10,14,9,16.52,false)
 box(14,6,16.5,21,8.5,20,body)
 art(14,20,11,14,14,8.525,16,true)
 box(22,6,10,31,17,18,body)
 box(23,9,18,30,14,18.4,dark)
 art(22,30,3,13,22,6,18.42,false)
 return out
end
local function foreground(S,map,data,perRow,budget)
 local pattern={{0x10,0x10,0x85,0x86},{0x81,0x82,0x83,0x84},
   {0x91,0x92,0x93,0x94},{0xA1,0xA2,0xA3,0xA4}}
 local w,h=data:getDimensions();if h<88 then return 0 end
 local cells={}
 for r,row in ipairs(pattern)do for c,t in ipairs(row)do
  local k=key(c+3,r+7);local s=S.shapeAt[k]
  local expected=r<3 and 'ground' or 'wall'
  if S.skip[k] or S.tileAt[k]~=t or not s or s.class~=expected
    or (r<3 and (not s.flat or (s.h or 0)~=0)) then return 0 end
  -- Elm stands on the northern row during the opening cutscene. Only the
  -- blocked southern row is furniture, regardless of its painted floor art.
  if r>=3 then cells[#cells+1]=k end
 end end
 for _,warp in ipairs(map.def.warps or {})do
  if warp.x>=2 and warp.x<=3 and warp.y>=4 and warp.y<=5 then return 0 end
 end
 local out={};local box=G.geometryWriter(out,2048)
 local function source(x,y)
  local tile=pattern[math.floor(y/8)+1][math.floor(x/8)+1]
  return tile%16*8+x%8,math.floor(tile/16)*8+y%8
 end
 local function donor(x,y)local a,b=source(x,y);return G.texelUV(a,b,w,h)end
 local function face(a,b,c,d,uv,shade)out[#out+1]={a,b,c,d,uv=uv,shade=shade or 1,own=true}end
 local function art(x0,x1,y0,y1,px,py,pz,top)
  for y=y0,y1 do local x=x0
   while x<=x1 do
    local n=math.min(x1-x+1,8-x%8);local a,b=source(x,y);local xx=px+x-x0
    local u={{(a+.025)/w,(b+.975)/h},{(a+n-.025)/w,(b+.975)/h},
      {(a+n-.025)/w,(b+.025)/h},{(a+.025)/w,(b+.025)/h}}
    if top then local z=pz+y-y0
     face({xx,py,z},{xx+n,py,z},{xx+n,py,z+1},{xx,py,z+1},{u[4],u[3],u[2],u[1]},.98)
    else local yy=py+y1-y
     face({xx,yy,pz},{xx+n,yy,pz},{xx+n,yy+1,pz},{xx,yy+1,pz},u,.97)
    end
    x=x+n
   end
  end
 end
 local enamel,dark,shade=donor(2,16),donor(0,27),donor(23,11)
 -- Two distinct desks entirely on the non-walkable southern map cells.
 -- Nothing may rise through Elm's cutscene tile immediately to the north.
 for _,span in ipairs({{1,14.5},{17.5,31}})do
  for _,x in ipairs({span[1],span[2]-2})do
   for _,z in ipairs({18,28})do box(x,0,z,x+2,2,z+3,shade)end
  end
  box(span[1],2,18,span[2],7,31,enamel)
  box(span[1],7,17,span[2],8,31,enamel)
 end
 box(2,2,31,13.8,6,31.3,shade);box(18.2,2,31,30,6,31.3,shade)
 -- Left source circular instrument becomes a recessed ring, not a giant
 -- vertical silver door. Use its own face inside the horizontal recess.
 local cx,cz=8.5,24;local outer,inner=5.2,3.8
 for i=0,11 do
  local a,b=i*math.pi/6,(i+1)*math.pi/6
  local ax,az=cx+outer*math.cos(a),cz+outer*math.sin(a)
  local bx,bz=cx+outer*math.cos(b),cz+outer*math.sin(b)
  local ix,iz=cx+inner*math.cos(a),cz+inner*math.sin(a)
  local jx,jz=cx+inner*math.cos(b),cz+inner*math.sin(b)
  face({ax,9,az},{bx,9,bz},{jx,9,jz},{ix,9,iz},shade,.97)
  face({ax,8,az},{bx,8,bz},{bx,9,bz},{ax,9,az},enamel,.85)
  face({ix,8.1,iz},{ix,9,iz},{jx,9,jz},{jx,8.1,jz},dark,.75)
 end
 art(6,11,16,20,6,8.12,21.5,true)
 -- Keyboard and CRT face north toward Elm, not into the rear wall.
 box(19,8,18,29,9,23,enamel)
 art(19,28,16,20,19,9.025,18,true)
 box(23,8,25,28,11,28,shade)
 box(18,11,23,30,19,29,enamel)
 box(19,12,22.5,29,18,23,dark)
 local first=#out+1
 art(19,28,4,9,19,12,22.48,false)
 for i=first,#out do
  local q=out[i];q[1],q[2]=q[2],q[1];q[3],q[4]=q[4],q[3]
  q.uv[1],q.uv[2]=q.uv[2],q.uv[1];q.uv[3],q.uv[4]=q.uv[4],q.uv[3]
 end
 if #out>budget then return 0 end
 for _,k in ipairs(cells)do
  S.skip[k]=true;S.ground[k]=0x10
  S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=8}
 end
 for _,q in ipairs(out)do
  for i=1,4 do q[i][1]=q[i][1]+32;q[i][3]=q[i][3]+64 end
  S.objectQuads[#S.objectQuads+1]=q
 end
 return #out
end
function M.build(S,map,data,perRow)
 if not(map and map.def and map.def.generation==2 and (map.id=='ELMS_LAB'or map.id=='OAKS_LAB')
   and map.tileset and map.tileset.id=='TilesetLab' and data)
   or S.outdoor or S.labEquipmentVisuals then return 0 end
 perRow=perRow or 16
 local w,h=data:getDimensions();if perRow~=16 or w<128 or h<24 then return 0 end
 -- Exact source context, including wall and plain floor around the bench.
 local x,z=map.id=='OAKS_LAB'and 0 or 4,2;local cells,wallCells={},{}
 for r,row in ipairs(rows)do for c,t in ipairs(row)do
  local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
  local correct=r<3 and s and s.class=='console' and s.authored and not s.flat
    or r==3 and s and s.class=='ground' and s.flat and (s.h or 0)==0
  if S.skip[k] or S.tileAt[k]~=t or not correct then return 0 end
  cells[#cells+1]=k
 end end
 for c=0,3 do
  local fk=key(x+c,z+3);local fs=S.shapeAt[fk]
  if S.tileAt[fk]~=0x10 or not fs or not fs.flat or fs.class~='ground' then return 0 end
  for r=0,1 do
   local k=key(x+c,r);local s=S.shapeAt[k]
   if S.skip[k] or S.tileAt[k]~=(r==0 and 1 or 0x11) or not s
     or s.flat or s.class~='wall' or s.art~='upright' then return 0 end
   wallCells[#wallCells+1]=k
  end
 end
 -- The adjacent western machine bank shares four more plain wall columns;
 -- the two-column native window is immediately east. These six excluded
 -- columns otherwise keep their32px generic backs while the bench is fixed.
 -- Verify their complete source context before pinning any additional wall.
 local west={{0x42,0x43,0x44,0x45},{0x52,0x53,0x54,0x55},
   {0x46,0x47,0x47,0x49},{0x56,0x57,0x58,0x59}}
 local extra={}
 local context=map.id=='ELMS_LAB'
 for r,row in ipairs(west)do for c,t in ipairs(row)do
  local k=key(c-1,r+1);local s=S.shapeAt[k]
  if S.tileAt[k]~=t or not s or s.class~='console' or not s.authored then context=false end
 end end
 for c=0,9 do if c<4 or c>=8 then for r=0,1 do
  local k=key(c,r);local s=S.shapeAt[k]
  local t=c<4 and (r==0 and 1 or 0x11) or (0x20+c-8+r*16)
  if S.skip[k] or S.tileAt[k]~=t or not s or s.flat or s.class~='wall' or s.art~='upright' then context=false end
  extra[#extra+1]=k
 end end end
 -- The apparent little blue "chest" is the adjoining half of the same
 -- source window (22/23 over 32/33), misclassified as a console in 3D.
 for c=10,11 do for r=0,1 do
  local k=key(c,r);local s=S.shapeAt[k]
  if S.skip[k] or S.tileAt[k]~=(0x20+c-8+r*16)
    or not s or s.class~='console' or not s.authored then context=false end
 end end
 if context then for _,k in ipairs(extra)do wallCells[#wallCells+1]=k end end
 for _,warp in ipairs(map.def.warps or {})do
  local westCell=math.floor(x/2)
  if warp.x>=westCell and warp.x<=westCell+1 and warp.y>=0 and warp.y<=2 then return 0 end
 end
 local quads=model(data,perRow)
 local windowStart=#quads+1
 if context then
  -- The native four-column north-wall window must remain a window. The
  -- right half was treated as floor equipment and extruded as a blue chest.
  -- Replace both halves with one wall-depth slab and flush source-art panes.
  local box=G.geometryWriter(quads,2048)
  box(32,0,-16,64,16,0,G.texelUV(43,3,w,h))
  for r=0,1 do for c=0,3 do
   local t=0x20+c+r*16
   local ax,ay=t%perRow*8,math.floor(t/perRow)*8
   local u={{(ax+.025)/w,(ay+7.975)/h},{(ax+7.975)/w,(ay+7.975)/h},
     {(ax+7.975)/w,(ay+.025)/h},{(ax+.025)/w,(ay+.025)/h}}
   local xx=32+c*8;local yy=8-r*8
   quads[#quads+1]={{xx,yy,.02},{xx+8,yy,.02},
     {xx+8,yy+8,.02},{xx,yy+8,.02},uv=u,shade=1,own=true}
  end end
 end
 if #quads>M.MAX_QUADS then return 0 end
 for _,k in ipairs(cells)do
  S.skip[k]=true;S.ground[k]=0x10
  S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=6}
 end
 -- Pin only the native wall immediately behind this exact instrument
 -- assembly. Unauthored columns otherwise absorb adjacent machine extent
 -- into a high black side/backing. Tile art stays unchanged at native16px.
 for _,k in ipairs(wallCells)do
  local fixed={};for name,v in pairs(S.shapeAt[k])do fixed[name]=v end
  fixed.h=16;fixed.authored=true;S.shapeAt[k]=fixed
 end
 if context then for r=0,1 do for c=8,9 do
  local k=key(c,r);S.skip[k]=true;S.ground[k]=0x10
 end end end
 if context then for r=0,1 do for c=10,11 do
  local k=key(c,r);S.skip[k]=true;S.ground[k]=0x10
  S.shapeAt[k]={class='wall',art='upright',authored=true,flat=false,h=16}
 end end end
 for _,q in ipairs(quads)do
  for i=1,4 do q[i][1]=q[i][1]+x*8;q[i][3]=q[i][3]+z*8 end
  S.objectQuads[#S.objectQuads+1]=q
 end
 -- Room-finish contract: these are native north walls, not tall furniture.
 -- The upper finish should start at16 even if the external shell's old
 -- column vote still reports32. This avoids exposed black backing caps.
 local wallColumns={}
 for c=x,x+3 do wallColumns[c]=16 end
 if context then for c=0,11 do wallColumns[c]=16 end end
 local frontQuads=map.id=='ELMS_LAB'and foreground(S,map,data,perRow,M.MAX_QUADS-#quads)or 0
 S.labEquipmentVisuals={quads=#quads+frontQuads,fixtures=frontQuads>0 and 2 or 1,wallPins=#wallCells,
   supportTiles=4,x=x,z=z,wallColumns=wallColumns,rearQuads=#quads,foregroundQuads=frontQuads,
   foregroundClaims=frontQuads>0 and 8 or 0,windowQuads=#quads-windowStart+1}
 return #quads+frontQuads
end
return M
