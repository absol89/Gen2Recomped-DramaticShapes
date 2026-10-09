-- Gen2 placement/material adapter for the unchanged BattleArt-Astra BikeDisplay.
-- Geometry provenance: authored Battle Art BikeDisplay.lua helper.
-- The carrier below maps its four measured material slots to verified Gen2
-- sprite texels; it does not pretend the Gen2 drawing is a Gen1 24x16 sprite.
local V=...
local Bike=V.require('BikeDisplay')
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=12000}
local function key(x,z)return(z+64)*4096+x+64 end
local horizontal={{12,13,14,15},{28,29,30,31}}
local longitudinal={{2,3},{43,44},{5,6},{21,22}}
local alternate={{18,19},{43,44},{5,6},{21,22}}
local plans={{0,4,horizontal,325531},{0,6,horizontal,325531},{0,10,horizontal,325531},{0,12,horizontal,325531},{12,12,horizontal,325531},{4,0,longitudinal,299064,true},{8,0,longitudinal,299064,true},{10,0,alternate,300431,true}}
local slots={104,195,316,108}
local function clip(poly,axis,bound,positive)
 local out={};local a=poly[#poly]
 for _,b in ipairs(poly)do
  local da=(a[axis]-bound)*(positive and 1 or -1);local db=(b[axis]-bound)*(positive and 1 or -1)
  if(da>=-1e-8)~=(db>=-1e-8)then local f=(bound-a[axis])/(b[axis]-a[axis]);local p={};for j=1,3 do p[j]=a[j]+f*(b[j]-a[j])end;p[axis]=bound;out[#out+1]=p end
  if db>=-1e-8 then out[#out+1]=b end;a=b
 end
 return out
end
local function emit(out,p,uv,shade)
 local polys={p}
 for _,axis in ipairs({1,3})do
  local lo,hi=math.huge,-math.huge;for _,v in ipairs(p)do lo=math.min(lo,v[axis]);hi=math.max(hi,v[axis])end
  for b=(math.floor(lo/8)+1)*8,hi-1e-8,8 do
   local nexts={};for _,poly in ipairs(polys)do
    local mn,mx=math.huge,-math.huge;for _,v in ipairs(poly)do mn=math.min(mn,v[axis]);mx=math.max(mx,v[axis])end
    if mn<b-1e-8 and mx>b+1e-8 then
     for _,side in ipairs({false,true})do local q=clip(poly,axis,b,side);if #q>=3 then nexts[#nexts+1]=q end end
    else nexts[#nexts+1]=poly end
   end;polys=nexts
  end
 end
 for _,poly in ipairs(polys)do
  if #poly==4 then out[#out+1]={poly[1],poly[2],poly[3],poly[4],own=true,uv=uv,shade=shade}
  else for j=2,#poly-1 do local a,b,c=poly[1],poly[j],poly[j+1];local mid={};for k=1,3 do mid[k]=(b[k]+c[k])/2 end;out[#out+1]={a,b,mid,c,own=true,uv=uv,shade=shade}end end
 end
end
function M.build(S,map,data,perRow)
 if S.outdoor or S.bikeShopFixtures or not(map and map.def and map.def.generation==2 and map.id=='GOLDENROD_BIKE_SHOP' and map.tileset and map.tileset.id=='TilesetChampionsRoom' and map.def.width==4 and map.def.height==4 and data and data.getPixel)then return 0 end
 if not(map.tileAt and map.warpAtCell and map.isWarpTileCell)then return 0 end
 local w,h=data:getDimensions();if w~=128 or h<32 or(perRow or 16)~=16 then return 0 end
 local out,claims,columns,counts={},{},{},{}
 local model -- immutable canonical geometry, generated lazily once per build
 for _,p in ipairs(plans)do
  local valid,cells,donors,index,checksum=true,{},{},0,0
  for rz,row in ipairs(p[3])do for rx,t in ipairs(row)do
   local x,z=p[1]+rx-1,p[2]+rz-1;local k=key(x,z);local s=S.shapeAt[k]
   if S.skip[k]or(S.doorFold and S.doorFold[k])or S.tileAt[k]~=t or not s or s.authored or s.class~='wall'or s.h~=16 or s.flat then valid=false end
   local ok,actual=pcall(map.tileAt,map,x,z);if not ok or actual~=t then valid=false end
   for _,method in ipairs({'warpAtCell','isWarpTileCell'})do local ok,hit=pcall(map[method],map,math.floor(x/2),math.floor(z/2));if not ok or hit then valid=false end end
   cells[#cells+1]=k
   for py=0,7 do for px=0,7 do
    index=index+1;local ax,ay=t%16*8+px,math.floor(t/16)*8+py
    local ok,r,g,b,a=pcall(data.getPixel,data,ax,ay)
    if not ok or type(r)~='number'or type(g)~='number'or type(b)~='number'or type(a)~='number'or r~=r or g~=g or b~=b or r<0 or r>1 or a<.999 or a~=a then valid=false
    else local level=math.floor(r*3+.5)
     if math.abs(r-level/3)>.01 or math.abs(g-r)>.01 or math.abs(b-r)>.01 then valid=false end
     checksum=checksum+index*(level+1)
     if not p[5]or rz>=3 then donors[level+1]=donors[level+1]or{{(ax+.5)/w,(ay+.5)/h},{(ax+.5)/w,(ay+.5)/h},{(ax+.5)/w,(ay+.5)/h},{(ax+.5)/w,(ay+.5)/h}}end
    end
   end end
  end end
  if checksum~=p[4]then valid=false end
  for j=1,4 do if not donors[j]then valid=false end end
  if valid then
   local uv={};for j,k in ipairs(slots)do uv[k]=donors[j]end
   if not model then
    local carrier={W=24,H=16,col={}};for j,k in ipairs(slots)do carrier.col[k]=4-j end
    model=Bike.model(carrier,nil,{bicycle='floor'})
   end
   local first=#out
   for _,q in ipairs(model.surfaces)do local poly={}
    for i=1,4 do local v=q[i];local x,z
     if p[5]then x=20-v[3];z=v[1]+4 else x=v[1]+4;z=v[3]-4 end
     poly[i]={x+p[1]*8,v[2],z+p[2]*8}
    end
    emit(out,poly,uv[q.source],q.shade)
   end
   counts[#counts+1]=#out-first
   for _,k in ipairs(cells)do claims[#claims+1]=k end
   if p[5]then columns[p[1]]=16;columns[p[1]+1]=16 end
  end
 end
 local workshop=0;local signColumns,rackColumns={},{}
 -- Source rack and the separate floor bin previously got merged into walls.
 local fixtures={{0,0,{{37,38,38,39},{54,55,55,58},{34,35,35,36},{50,51,51,52}},902525,'rack'},
  {6,2,{{17,17},{32,32},{40,41},{56,57}},328751,'bin'},
  {14,14,{{40,41},{56,57}},77279,'bin',true}}
 for _,p in ipairs(fixtures)do
  local valid,cells,sum,index,donors=true,{},0,0,{}
  for rz,row in ipairs(p[3])do for rx,t in ipairs(row)do
   local x,z=p[1]+rx-1,p[2]+rz-1;local k=key(x,z);local s=S.shapeAt[k]
   if S.skip[k]or(S.doorFold and S.doorFold[k])or S.tileAt[k]~=t or not s or s.authored or s.class~='wall'or s.h~=16 or s.flat then valid=false end
   local ok,tile=pcall(map.tileAt,map,x,z);if not ok or tile~=t then valid=false end
   for _,method in ipairs({'warpAtCell','isWarpTileCell'})do local ok,hit=pcall(map[method],map,math.floor(x/2),math.floor(z/2));if not ok or hit then valid=false end end
   cells[#cells+1]=k
   for py=0,7 do for px=0,7 do
    index=index+1;local ax,ay=t%16*8+px,math.floor(t/16)*8+py
    local ok,r,g,b,a=pcall(data.getPixel,data,ax,ay)
    if not ok or type(r)~='number'or type(g)~='number'or type(b)~='number'or type(a)~='number'or r~=r or r<0 or r>1 or a~=a or a<.999 then valid=false
    else local l=math.floor(r*3+.5);sum=sum+index*(l+1)
     if math.abs(r-l/3)>.01 or math.abs(g-r)>.01 or math.abs(b-r)>.01 then valid=false end
     if p[5]=='rack'or p[6]or rz>=3 then donors[l]=donors[l]or G.texelUV(ax,ay,w,h)end
    end
   end end
  end end
  if sum~=p[4]or not donors[0]or not donors[2]or not donors[3]then valid=false end
  -- The bin's north sign/skirting context must still be the known pattern.
  if p[5]=='bin'and not p[6]then for dz,row in ipairs({{18,19},{33,33}})do for dx,t in ipairs(row)do
   local k=key(5+dx,dz-1);local s=S.shapeAt[k]
   if S.tileAt[k]~=t or not s or s.class~='wall'or s.authored or s.h~=16 or s.flat or S.skip[k]or(S.doorFold and S.doorFold[k])then valid=false end
   local ok,actual=pcall(map.tileAt,map,5+dx,dz-1);if not ok or actual~=t then valid=false end
   for _,method in ipairs({'warpAtCell','isWarpTileCell'})do local ok,hit=pcall(map[method],map,math.floor((5+dx)/2),0);if not ok or hit then valid=false end end
  end end end
  if valid then
   local localOut={};local box=G.geometryWriter(localOut,2048)
   if p[5]=='rack'then
    for _,x in ipairs({1,28})do for _,z in ipairs({17,28})do box(x,0,z,x+2,3,z+2,donors[2])end end
    box(1,3,17,31,4,31,donors[2]);box(1,4,17,2,15,31,donors[2]);box(30,4,17,31,15,31,donors[2]);box(2,4,17,30,15,18,donors[2])
    box(0,15,16,32,16,32,donors[2])
    for sy=8,31 do for sx=0,31,8 do
     local t=p[3][math.floor(sy/8)+1][math.floor(sx/8)+1];local ax,ay=t%16*8,math.floor(t/16)*8+sy%8
     local y=3+(31-sy)*.5
     localOut[#localOut+1]={{sx,y,31.02},{sx+8,y,31.02},{sx+8,y+.5,31.02},{sx,y+.5,31.02},own=true,shade=1,
      uv={{(ax+.05)/w,(ay+.95)/h},{(ax+7.95)/w,(ay+.95)/h},{(ax+7.95)/w,(ay+.05)/h},{(ax+.05)/w,(ay+.05)/h}}}
    end end
    for x=0,3 do columns[x]=16;rackColumns[x]=16 end
   else
    -- Small open octagonal bin: pale rolled rim, dark cavity, lower body.
    local function point(j,r,y)local a=j*math.pi/4;return{8+r*math.cos(a),y,24+r*math.sin(a)}end
    for j=0,7 do
     emit(localOut,{point(j,5,1),point(j+1,5,1),point(j+1,6,8),point(j,6,8)},donors[2],.8)
     emit(localOut,{point(j,6,8),point(j+1,6,8),point(j+1,4.5,8),point(j,4.5,8)},donors[3],1)
     emit(localOut,{point(j,4.5,8),point(j+1,4.5,8),point(j+1,4,2),point(j,4,2)},donors[0],.8)
    end
    box(4,1,20,12,2,28,donors[0])
    if not p[6]then columns[6]=16;columns[7]=16;signColumns[6]=16;signColumns[7]=16 end
   end
   for _,q in ipairs(localOut)do for i=1,4 do q[i][1]=q[i][1]+p[1]*8;q[i][3]=q[i][3]+p[2]*8-(p[6]and 16 or 0)end;out[#out+1]=q end
   for _,k in ipairs(cells)do claims[#claims+1]=k end;workshop=workshop+1
  end
 end
 if #out==0 or #out>M.MAX_QUADS then return 0 end
 -- Keep sign pixels and wall placement, but prevent unrelated floor/bin rows
 -- joining the sign into a 48-high repeated native wall run.
 for x in pairs(signColumns)do for z=0,1 do local k=key(x,z);local copy={};for field,value in pairs(S.shapeAt[k])do copy[field]=value end;copy.h=16;copy.authored=true;S.shapeAt[k]=copy end end
 for _,k in ipairs(claims)do S.skip[k]=true;S.ground[k]=32;S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}end
 for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
 S.bikeShopFixtures={models=#counts,workshopModels=workshop,quads=#out,perBikeQuads=counts,claimedTiles=#claims,wallColumns=columns,signWallColumns=signColumns,rackWallColumns=rackColumns}
 return #out
end
return M
