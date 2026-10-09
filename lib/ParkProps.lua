-- Source-matched Park furniture, claimed before generic upright detection.
local M={}
local function K(x,z)return(z+64)*4096+x+64 end
function M.build(S,map,data,perRow)
 if not(map.tileset and map.tileset.id=='TilesetPark')then return end
 local tw,th=map.def.width*4,map.def.height*4
 local aw,ah=data:getDimensions();perRow=perRow or 16
 local stats={benches=0,signs=0,bins=0,flowerbeds=0,flowers=0,quads=0}
 local start=#S.objectQuads
 local function tile(x,z)return S.tileAt[K(x,z)]end
 local function uv(t,px,py)
  return {(t%perRow*8+px)/aw,(math.floor(t/perRow)*8+py)/ah}
 end
 local function quad(p,t,rect,shade)
  local r=rect or{.5,.5,.5,.5}
  p.uv={uv(t,r[1],r[4]),uv(t,r[3],r[4]),uv(t,r[3],r[2]),uv(t,r[1],r[2])}
  p.shade=shade or 1;S.objectQuads[#S.objectQuads+1]=p
 end
 local inks={}
 for _,t in ipairs({7,8,9,10,0x17})do for py=0,7 do for px=0,7 do
  local r=data:getPixel(t%perRow*8+px,math.floor(t/perRow)*8+py)
  local s=r>.83 and 0 or r>.50 and 1 or r>.17 and 2 or 3
  if not inks[s]then inks[s]={t,{px+.5,py+.5,px+.5,py+.5}}end
 end end end
 local function box(x0,z0,x1,z1,y0,y1,shade)
  local a=inks[shade]or inks[1]or{7,{.5,.5,.5,.5}}
  quad({{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},{x0,y1,z0}},a[1],a[2],1)
  quad({{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1}},a[1],a[2],.9)
  quad({{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0}},a[1],a[2],.8)
  quad({{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0}},a[1],a[2],.8)
  quad({{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1}},a[1],a[2],.9)
 end
 local function parkBin(x,z)
  local X,Z=x*8+8,z*8+8
  local top=tile(x,z)
  local bottom=tile(x,z+1)
  local function binInk(t,target)
   local best,score
   for py=0,7 do for px=0,7 do
    local r=data:getPixel(t%perRow*8+px,math.floor(t/perRow)*8+py)
    local d=math.abs(r-target)
    if not score or d<score then best={t,{px+.5,py+.5,px+.5,py+.5}};score=d end
   end end
   return best
  end
  local gray=binInk(top,.66)
  local lip=binInk(top,.33)
  local dark=binInk(bottom,0)
  -- Eight broad facets make a short, tapered, hollow litter bin. The dark
  -- opening is recessed below the lip rather than covered by a gray lid.
 local outer={}
  for i=0,7 do
   local a=(i+.5)*math.pi/4
   outer[i+1]={math.cos(a),math.sin(a)}
  end
  for i=1,8 do
   local j=i%8+1
   local a,b=outer[i],outer[j]
   local ax,az,bx,bz=X+a[1]*5.0,Z+a[2]*5.0,X+b[1]*5.0,Z+b[2]*5.0
   local atx,atz,btx,btz=X+a[1]*6.0,Z+a[2]*6.0,X+b[1]*6.0,Z+b[2]*6.0
   quad({{ax,0,az},{bx,0,bz},{btx,10,btz},{atx,10,atz}},gray[1],gray[2],i%2==0 and .8 or .95)
   local ai,azi,bi,bzi=X+a[1]*3.7,Z+a[2]*3.7,X+b[1]*3.7,Z+b[2]*3.7
   quad({{atx,10,atz},{btx,10,btz},{bi,10,bzi},{ai,10,azi}},lip[1],lip[2],1)
   quad({{ai,10,azi},{bi,10,bzi},{bi,6,bzi},{ai,6,azi}},dark[1],dark[2],.48)
  end
  quad({{X-3.7,6,Z+3.7},{X+3.7,6,Z+3.7},{X+3.7,6,Z-3.7},{X-3.7,6,Z-3.7}},dark[1],dark[2],.28)
  stats.bins=stats.bins+1
 end
 local function claim(x,z,w,d,kind)
  S.parkActorOffsets=S.parkActorOffsets or{}
  for zz=z,z+d-1 do for xx=x,x+w-1 do
   local k=K(xx,zz)
   S.skip[k]=true;S.runs[k]=nil
   S.shapeAt[k]={class='park_prop',authored=true,h=0,base=0,flat=false}
   S.ground[k]=kind=='bed'and 1 or ((xx+zz)%2==0 and 0 or (zz%2==0 and 0x16 or 6))
   -- Native NPCs occupy the back row of the 2D bench drawing. Keep their
   -- event cells, but put the upright card just in front of the 3D seat.
   if kind=='bench'and zz<z+2 then S.parkActorOffsets[k]=14 end
  end end
 end
 local function flower(X,Z,t)
  -- Preserve the native eight-pixel silhouette. The white/checkered field
  -- is background, not petals. Midtone pixels enclosed by the dark outline
  -- belong to the bloom; do not extrude the surrounding checker pattern.
  local tones,levels={},{}
  for py=0,7 do for px=0,7 do
   local r=data:getPixel(t%perRow*8+px,math.floor(t/perRow)*8+py)
   tones[py*8+px]=r
  end end
  local function dark(x,y)return x>=0 and x<8 and y>=0 and y<8 and tones[y*8+x]<.5 end
  for py=0,7 do for px=0,7 do
   local r=tones[py*8+px];local n=0
   for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do if dark(px+d[1],py+d[2])then n=n+1 end end
   levels[py*8+px]=(r<.5 and 3.25)or(r<.83 and n>=2 and 4)or 2.04
  end end
  local function height(x,y)return x>=0 and x<8 and y>=0 and y<8 and levels[y*8+x]or 2.04 end
  for py=0,7 do
   local px=0
   while px<8 do
    local h=height(px,py);local r=tones[py*8+px];local finish=px+1
    while finish<8 and height(finish,py)==h and tones[py*8+finish]==r do finish=finish+1 end
    if h>2.04 then
     local ink={px+.5,py+.5,px+.5,py+.5}
     quad({{X+px,h,Z+py+1},{X+finish,h,Z+py+1},{X+finish,h,Z+py},{X+px,h,Z+py}},t,ink,1)
    end
    px=finish
   end
  end
  for py=0,7 do for px=0,7 do
   local h=height(px,py);local ink={px+.5,py+.5,px+.5,py+.5}
   if h>2.04 then
    local a,b=X+px,Z+py
    local low=height(px,py+1);if low<h then quad({{a,low,b+1},{a+1,low,b+1},{a+1,h,b+1},{a,h,b+1}},t,ink,.85)end
    low=height(px,py-1);if low<h then quad({{a+1,low,b},{a,low,b},{a,h,b},{a+1,h,b}},t,ink,.8)end
    low=height(px-1,py);if low<h then quad({{a,low,b},{a,low,b+1},{a,h,b+1},{a,h,b}},t,ink,.8)end
    low=height(px+1,py);if low<h then quad({{a+1,low,b+1},{a+1,low,b},{a+1,h,b},{a+1,h,b+1}},t,ink,.85)end
   end
  end end
  stats.flowers=stats.flowers+1
 end
 local function benchAt(x,z)
  local rows={{7,8,9,10},{0x17,0x18,0x19,0x1A},{0x27,0x28,0x29,0x2A}}
  for dz,row in ipairs(rows)do for dx,t in ipairs(row)do
   if tile(x+dx-1,z+dz-1)~=t or S.skip[K(x+dx-1,z+dz-1)]then return false end
  end end
  return true
 end
 for z=0,th-3 do for x=0,tw-4 do
  if benchAt(x,z)then
   local n=1;while benchAt(x+n*4,z)do n=n+1 end
   claim(x,z,n*4,3,'bench')
   local X,Z,W=x*8,z*8,n*32
   -- Open underside, separate slats, no roof/wedge or added decor beams.
   for _,lx in ipairs({3,W-5})do
    for _,lz in ipairs({6,18})do box(X+lx,Z+lz,X+lx+2,Z+lz+2,0,6,2)end
    box(X+lx,Z+5,X+lx+2,Z+7,6,17,2)
   end
   for j=0,2 do box(X+1,Z+7+j*4,X+W-1,Z+10+j*4,5,6.5,1)end
   for j=0,2 do
    box(X+1,Z+5,X+W-1,Z+7,8+j*3,10+j*3,1)
    box(X+1,Z+4.8,X+W-1,Z+5,8+j*3,8.6+j*3,0)
   end
   stats.benches=stats.benches+1
  end
 end end
 for z=0,th-2 do for x=0,tw-2 do
  if tile(x,z)==0x45 and tile(x+1,z)==0x46 and tile(x,z+1)==0x55 and tile(x+1,z+1)==0x56 then
   claim(x,z,2,2,'sign')
   local X,Z=x*8,z*8+8
   for _,dx in ipairs({3,11})do box(X+dx,Z-.6,X+dx+2,Z+.6,0,6,2)end
   box(X,Z-.8,X+16,Z+.8,4,16,2)
   -- Native two-row sign face, cropping only the floor below its frame.
   for dz=0,1 do for dx=0,1 do
    local t=tile(x+dx,z+dz);local h=dz==0 and 8 or 4
    local y1=16-dz*8;local y0=y1-h
    quad({{X+dx*8,y0,Z+.82},{X+(dx+1)*8,y0,Z+.82},{X+(dx+1)*8,y1,Z+.82},{X+dx*8,y1,Z+.82}},t,{.05,.05,7.95,h-.05},.95)
    quad({{X+(dx+1)*8,y0,Z-.82},{X+dx*8,y0,Z-.82},{X+dx*8,y1,Z-.82},{X+(dx+1)*8,y1,Z-.82}},tile(x+1-dx,z+dz),{.05,.05,7.95,h-.05},.85)
   end end
   stats.signs=stats.signs+1
  end
 end end
 -- The Park has two native 2x2 bin drawings. Match complete art only;
 -- incomplete wall/ground tiles elsewhere should never become bins.
 for z=0,th-2 do for x=0,tw-2 do
  local a,b,c,d=tile(x,z),tile(x+1,z),tile(x,z+1),tile(x+1,z+1)
  if (a==0x5A and b==0x5B and c==0x13 and d==0x82)
     or (a==0x4C and b==0x4D and c==0x5C and d==0x5D)then
   claim(x,z,2,2,'bin');parkBin(x,z)
  end
 end end
 -- Detect the whole original framed bed, not isolated flower-colour pixels.
 for z=0,th-4 do for x=0,tw-3 do
  if tile(x,z)==0x37 then
   local w=1;while tile(x+w,z)==0x38 do w=w+1 end;w=w+1
   local valid=w>=3 and tile(x+w-1,z)==0x39 and tile(x,z+3)==0x57 and tile(x+w-1,z+3)==0x59
   for dx=1,w-2 do valid=valid and tile(x+dx,z+3)==0x58 end
   for dz=1,2 do
    valid=valid and tile(x,z+dz)==0x47 and tile(x+w-1,z+dz)==0x49
    for dx=1,w-2 do local t=tile(x+dx,z+dz);valid=valid and(t==3 or t==1)end
   end
   if valid then
    claim(x,z,w,4,'bed')
    box(x*8,z*8,(x+w)*8,(z+4)*8,0,2,2)
    -- A low, substantial frame around the existing soil. It stands about
    -- two units above the flowers' base, below the six-unit pond edge.
    local X,Z,W=x*8,z*8,w*8
    local function rim(x0,z0,x1,z1,t)
     local ink={2.5,3.5,2.5,3.5}
     quad({{x0,4.3,z1},{x1,4.3,z1},{x1,4.3,z0},{x0,4.3,z0}},t,ink,1)
     quad({{x0,2.02,z1},{x1,2.02,z1},{x1,4.3,z1},{x0,4.3,z1}},t,ink,.86)
     quad({{x1,2.02,z0},{x0,2.02,z0},{x0,4.3,z0},{x1,4.3,z0}},t,ink,.78)
     quad({{x0,2.02,z0},{x0,2.02,z1},{x0,4.3,z1},{x0,4.3,z0}},t,ink,.8)
     quad({{x1,2.02,z1},{x1,2.02,z0},{x1,4.3,z0},{x1,4.3,z1}},t,ink,.88)
    end
    rim(X,Z,X+W,Z+2.4,0x38)
    rim(X,Z+29.6,X+W,Z+32,0x58)
    rim(X,Z+2.4,X+2.4,Z+29.6,0x47)
    rim(X+W-2.4,Z+2.4,X+W,Z+29.6,0x49)
    -- Keep the native frame, with low source-pixel flowers over green soil.
    for dz=0,3 do for dx=0,w-1 do
     local X,Z=(x+dx)*8,(z+dz)*8
     local t=tile(x+dx,z+dz)
     quad({{X,2.02,Z+8},{X+8,2.02,Z+8},{X+8,2.02,Z},{X,2.02,Z}},t==3 and 1 or t,{.05,.05,7.95,7.95},1)
     if t==3 then flower(X,Z,t)end
    end end
    stats.flowerbeds=stats.flowerbeds+1
   end
  end
 end end
 stats.quads=#S.objectQuads-start;S.parkProps=stats
end
return M
