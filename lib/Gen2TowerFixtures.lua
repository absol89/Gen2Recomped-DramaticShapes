-- Authored round timber and shrine figures for Crystal's shared Tower set.
-- Render-only exact-pattern claims: native collision, scripts and warps remain
-- the authority.  The old generic paths made the rails rectangular slabs and
-- extruded each statue's floor-coloured 2x4 drawing as a solid box.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=18000}
local floor,cos,sin,pi=math.floor,math.cos,math.sin,math.pi
local function key(x,z)return(z+64)*4096+x+64 end

local function material(data,tile,row,w,h,target)
 local ox,oy=(tile%row)*8,floor(tile/row)*8
 local best,delta=nil,math.huge
 for py=0,7 do for px=0,7 do
  local r,g,b,a=data:getPixel(ox+px,oy+py)
  if a>.5 then
   local l=.2126*r+.7152*g+.0722*b
   local d=math.abs(l-target)
   if d<delta then delta=d;best={ox+px,oy+py}end
  end
 end end
 if best then return G.texelUV(best[1],best[2],w,h)end
end

local function addFace(out,limit,role,a,b,c,d,uv,shade)
 if #out>=limit then return false end
 out[#out+1]={a,b,c,d,uv=uv,shade=shade,own=true,roomRole=role}
 return true
end

-- An eight-sided prism. Long pieces split only their side bands on the
-- eight-voxel world lattice; the cut faces remain single visible log ends.
local function prism(out,limit,role,axis,a0,a1,c0,c1,r,side,cap)
 local function p(a,u,v)
  if axis=='x'then return{a,c0+u,c1+v}
  elseif axis=='y'then return{c0+u,a,c1+v}
  else return{c0+u,c1+v,a}end
 end
 local cuts={a0};local a=(floor(a0/8)+1)*8
 while a<a1 do cuts[#cuts+1]=a;a=a+8 end
 cuts[#cuts+1]=a1
 for n=1,#cuts-1 do
  for i=0,7 do
   local t0=2*pi*i/8 local t1=2*pi*(i+1)/8
   local u0,v0=cos(t0)*r,sin(t0)*r
   local u1,v1=cos(t1)*r,sin(t1)*r
   addFace(out,limit,role,p(cuts[n],u0,v0),p(cuts[n+1],u0,v0),
    p(cuts[n+1],u1,v1),p(cuts[n],u1,v1),side,.74+.18*(i%3)/2)
  end
 end
 local centre0,centre1=p(a0,0,0),p(a1,0,0)
 for i=0,7 do
  local t0=2*pi*i/8 local t1=2*pi*(i+1)/8
  local u0,v0=cos(t0)*r,sin(t0)*r
  local u1,v1=cos(t1)*r,sin(t1)*r
  addFace(out,limit,role,centre0,p(a0,u1,v1),p(a0,u0,v0),centre0,cap,.66)
  addFace(out,limit,role,centre1,p(a1,u0,v0),p(a1,u1,v1),centre1,cap,.93)
 end
end

local function frustum(out,limit,role,x,z,y0,y1,r0,r1,uv)
 for i=0,7 do
  local a=2*pi*i/8 local b=2*pi*(i+1)/8
  addFace(out,limit,role,
   {x+cos(a)*r0,y0,z+sin(a)*r0},{x+cos(b)*r0,y0,z+sin(b)*r0},
   {x+cos(b)*r1,y1,z+sin(b)*r1},{x+cos(a)*r1,y1,z+sin(a)*r1},uv,.72+.2*(i%3)/2)
 end
end

local function cap(out,limit,role,x,z,y,r,uv,up)
 local centre={x,y,z}
 for i=0,7 do
  local a=2*pi*i/8 local b=2*pi*(i+1)/8
  local p0={x+cos(a)*r,y,z+sin(a)*r};local p1={x+cos(b)*r,y,z+sin(b)*r}
  if up then addFace(out,limit,role,centre,p0,p1,centre,uv,1)
  else addFace(out,limit,role,centre,p1,p0,centre,uv,.58)end
 end
end

local function claim(S,cells,ground)
 local shape={class='building',art='building',authored=true,flat=false,h=0}
 for _,c in ipairs(cells)do local k=key(c[1],c[2])
  S.skip[k]=true;S.ground[k]=ground or 0x02;S.shapeAt[k]=shape
 end
end

local function exact(map,x,z,rows)
 for rz,row in ipairs(rows)do for rx,t in ipairs(row)do
  if map:tileAt(x+rx-1,z+rz-1)~=t then return false end
 end end
 return true
end

local function boxes(out,limit,role)
 local raw={};local box,count=G.geometryWriter(raw,limit)
 return function(... )box(...)end,function()
  for _,q in ipairs(raw)do q.roomRole=role;out[#out+1]=q end
  return count()
 end
end

local function leaf(out,limit,role,x,y,z,dx,uv)
 local z0,z1=z-1.25,z+1.25
 local a={x,y,z0};local b={x+dx*.52,y+3.0,z0};local c={x+dx,y+1.4,z0};local d={x+dx*.55,y-1.8,z0}
 local aa={a[1],a[2],z1};local bb={b[1],b[2],z1};local cc={c[1],c[2],z1};local dd={d[1],d[2],z1}
 addFace(out,limit,role,a,b,c,d,uv,.94);addFace(out,limit,role,dd,cc,bb,aa,uv,.70)
 addFace(out,limit,role,a,aa,bb,b,uv,.78);addFace(out,limit,role,b,bb,cc,c,uv,.86)
 addFace(out,limit,role,c,cc,dd,d,uv,.75);addFace(out,limit,role,d,dd,aa,a,uv,.68)
end

local function bellsprout(out,limit,x,z,mat)
 local role='tower_bellsprout_statue';local cx,cz=x*8+8,z*8+8
 local box,flush=boxes(out,limit-#out,role)
 box(cx-6,0,cz-6,cx+6,1.5,cz+6,mat.mid)
 box(cx-5,1.5,cz-5,cx+5,3.5,cz+5,mat.light)
 box(cx-3.7,3.5,cz-3.7,cx+3.7,6,cz+3.7,mat.mid)
 flush()
 prism(out,limit,role,'y',6,18,cx,cz,1.45,mat.mid,mat.dark)
 leaf(out,limit,role,cx-1.0,13.2,cz,-6.2,mat.light)
 leaf(out,limit,role,cx+1.0,12.6,cz,6.2,mat.mid)
 -- Bell-shaped head: a genuinely round, tapered volume readable from every
 -- side, with a recessed south-facing mouth instead of a second flat card.
 frustum(out,limit,role,cx,cz,17,20,2.5,5.0,mat.mid)
 frustum(out,limit,role,cx,cz,20,25,5.0,6.3,mat.light)
 frustum(out,limit,role,cx,cz,25,29,6.3,3.2,mat.mid)
 cap(out,limit,role,cx,cz,29,3.2,mat.light,true)
 -- Mouth rim and dark well on the room-facing (south) side.
 local box2,flush2=boxes(out,limit-#out,role)
 box2(cx-3.5,20.2,cz+5.35,cx+3.5,24.4,cz+6.15,mat.dark)
 box2(cx-2.3,21.0,cz+6.1,cx+2.3,23.6,cz+6.35,mat.black)
 flush2()
end

local function urn(out,limit,x,z,mat)
 local role='tower_urn_statue';local cx,cz=x*8+8,z*8+8
 local box,flush=boxes(out,limit-#out,role)
 box(cx-6,0,cz-6,cx+6,1.5,cz+6,mat.mid)
 box(cx-5,1.5,cz-5,cx+5,3.5,cz+5,mat.light)
 box(cx-3.8,3.5,cz-3.8,cx+3.8,5.2,cz+3.8,mat.mid)
 flush()
 frustum(out,limit,role,cx,cz,5.2,8,3.0,5.1,mat.dark)
 frustum(out,limit,role,cx,cz,8,15,5.1,4.2,mat.mid)
 frustum(out,limit,role,cx,cz,15,17,4.2,5.6,mat.light)
 frustum(out,limit,role,cx,cz,17,19,5.6,3.7,mat.mid)
 cap(out,limit,role,cx,cz,19,3.7,mat.light,true)
 prism(out,limit,role,'y',19,21,cx,cz,1.2,mat.mid,mat.light)
end

local function buildRailX(S,map,out,limit,x,z,x1,mat)
 local role='tower_round_log';local a=x*8 local b=(x1+1)*8 local cz=z*8+8
 prism(out,limit,role,'x',a,b,5.0,cz,1.25,mat.mid,mat.light)
 prism(out,limit,role,'x',a,b,12.3,cz,1.45,mat.light,mat.mid)
 for px=a+1.8,b-1.8,8 do prism(out,limit,role,'y',1.0,15.5,px,cz,1.35,mat.mid,mat.light)end
 local cells={};for zz=z,z+1 do for xx=x,x1 do cells[#cells+1]={xx,zz}end end
 claim(S,cells,0x02)
 return #cells
end

local function buildRailZ(S,map,out,limit,x,z,z1,mat)
 local role='tower_round_log';local a=z*8 local b=(z1+1)*8 local cx=x*8+8
 prism(out,limit,role,'z',a,b,cx,5.0,1.25,mat.mid,mat.light)
 prism(out,limit,role,'z',a,b,cx,12.3,1.45,mat.light,mat.mid)
 for pz=a+1.8,b-1.8,8 do prism(out,limit,role,'y',1.0,15.5,cx,pz,1.35,mat.mid,mat.light)end
 local cells={};for zz=z,z1 do for xx=x,x+1 do cells[#cells+1]={xx,zz}end end
 claim(S,cells,0x02)
 return #cells
end

function M.build(S,map,data,perRow)
 if not(S and map and map.def and map.def.generation==2 and data and not S.outdoor)
    or S.towerFixtures then return 0 end
 local ts=map.tileset and map.tileset.id
 if ts~='TilesetTower'and map.def.tileset~='TILESET_TOWER'then return 0 end
 local row=perRow or 16;local w,h=data:getDimensions();local out=S.objectQuads
 local start=#out
 local limit=start+M.MAX_QUADS
 local logMat={mid=material(data,0x11,row,w,h,.43),light=material(data,0x21,row,w,h,.72)}
 local statMat={dark=material(data,0x4B,row,w,h,.25),mid=material(data,0x4A,row,w,h,.46),
  light=material(data,0x5A,row,w,h,.72),black=material(data,0x4A,row,w,h,.03)}
 if not(logMat.mid and logMat.light and statMat.dark and statMat.mid and statMat.light and statMat.black)then return 0 end
 local tw,th=map.def.width*4,map.def.height*4;local logs,statues,urns,claimed=0,0,0,0
 local used={}
 -- Face-on rails: exact $11/$21 two-row drawing, extended only across a
 -- contiguous source run.  This also handles the long perimeter timbers.
 for z=0,th-2 do local x=0 while x<tw do
  if not used[key(x,z)]and map:tileAt(x,z)==0x11 and map:tileAt(x,z+1)==0x21 then
   local x1=x;while x1+1<tw and map:tileAt(x1+1,z)==0x11 and map:tileAt(x1+1,z+1)==0x21 do x1=x1+1 end
   if x1>=x then
    claimed=claimed+buildRailX(S,map,out,limit,x,z,x1,logMat);logs=logs+1
    for xx=x,x1 do used[key(xx,z)]=true;used[key(xx,z+1)]=true end
   end
   x=x1+1
  else x=x+1 end
 end end
 -- End-on rails are exact adjacent $41/$31 pairs; $40/$20 is their corner.
 for x=0,tw-2 do local z=0 while z<th do
  local a,b=map:tileAt(x,z),map:tileAt(x+1,z)
  if not used[key(x,z)]and((a==0x41 and b==0x31)or(a==0x40 and b==0x20))then
   local z1=z
   while z1+1<th do local c,d=map:tileAt(x,z1+1),map:tileAt(x+1,z1+1)
    if used[key(x,z1+1)]or not((c==0x41 and d==0x31)or(c==0x40 and d==0x20))then break end
    z1=z1+1
   end
   claimed=claimed+buildRailZ(S,map,out,limit,x,z,z1,logMat);logs=logs+1
   for zz=z,z1 do used[key(x,zz)]=true;used[key(x+1,zz)]=true end
   z=z1+1
  else z=z+1 end
 end end
 local bellA={{0x4A,0x4B},{0x5A,0x5B},{0x4C,0x5C},{0x36,0x37}}
 local bellB={{0x42,0x43},{0x5A,0x5B},{0x4C,0x5C},{0x36,0x37}}
 local urnGrid={{0x22,0x23},{0x32,0x33},{0x12,0x13},{0x36,0x37}}
 for z=0,th-4 do for x=0,tw-2 do
  local kind=nil
  if exact(map,x,z,bellA)or exact(map,x,z,bellB)then kind='bell'
  elseif exact(map,x,z,urnGrid)then kind='urn'end
  if kind then
   local cells={};local free=true
   for dz=0,3 do for dx=0,1 do local k=key(x+dx,z+dz);if used[k]then free=false end;cells[#cells+1]={x+dx,z+dz}end end
   if free then
    if kind=='bell'then bellsprout(out,limit,x,z,statMat);statues=statues+1
    else urns=urns+1;urn(out,limit,x,z,statMat)end
    claim(S,cells,0x02);claimed=claimed+#cells
    for _,c in ipairs(cells)do used[key(c[1],c[2])]=true end
   end
  end
 end end
 local added=#out-start
 S.towerFixtures={quads=added,logs=logs,statues=statues,urns=urns,claimedTiles=claimed}
 return added
end

return M
