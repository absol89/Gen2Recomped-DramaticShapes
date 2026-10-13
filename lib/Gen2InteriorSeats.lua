-- Exact, source-verified seats missed by the native flat-ground profile.
-- Claims affect rendering only; logical map tiles, collisions and NPCs stay.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=2048}
local function key(x,z)return(z+64)*4096+x+64 end
local plans={
 MR_POKEMONS_HOUSE={tileset='TilesetFacility',width=4,height=4,tiles={{14,15},{30,31}},
  xy={{6,8},{6,10}},ax=112,ay=0,sum=96968,kind='chair'},
 SILPH_CO_1F={tileset='TilesetFacility',width=8,height=4,tiles={{14,15},{30,31}},
  xy={{0,2},{4,2},{22,8},{26,8},{22,14},{26,14}},ax=112,ay=0,sum=96968,kind='chair'},
 POWER_PLANT={tileset='TilesetFacility',width=10,height=9,tiles={{14,15},{30,31}},
  xy={{6,4},{10,4},{6,10},{10,10},{18,28},{18,30}},ax=112,ay=0,sum=96968,kind='chair'},
 TEAM_ROCKET_BASE_B3F={tileset='TilesetFacility',width=15,height=9,tiles={{14,15},{30,31}},
  xy={{22,4},{26,4},{22,10},{26,10},{18,24},{22,24},{18,30},{22,30}},ax=112,ay=0,sum=96968,kind='chair'},
 RADIO_TOWER_1F={tileset='TilesetRadioTower',width=9,height=4,tiles={{44,45},{60,61}},
  xy={{12,12},{16,12},{20,12},{24,12}},ax=96,ay=16,sum=94618,kind='stool'},
 RADIO_TOWER_2F={tileset='TilesetRadioTower',width=9,height=4,tiles={{44,45},{60,61}},
  xy={{8,12},{12,12}},ax=96,ay=16,sum=94618,kind='stool'},
 RADIO_TOWER_3F={tileset='TilesetRadioTower',width=9,height=4,tiles={{44,45},{60,61}},
  xy={{6,8},{14,8},{4,14},{12,14},{20,14}},ax=96,ay=16,sum=94618,kind='stool'},
 RADIO_TOWER_4F={tileset='TilesetRadioTower',width=9,height=4,tiles={{44,45},{60,61}},
  xy={{10,8},{2,12},{14,12}},ax=96,ay=16,sum=94618,kind='stool'},
 RADIO_TOWER_5F={tileset='TilesetRadioTower',width=9,height=4,tiles={{44,45},{60,61}},
  xy={{2,8},{8,12}},ax=96,ay=16,sum=94618,kind='stool'},
 LAV_RADIO_TOWER_1F={tileset='TilesetRadioTower',width=10,height=4,tiles={{44,45},{60,61}},
  xy={{12,12}},ax=96,ay=16,sum=94618,kind='stool'},
}
local function radioTable(S,map,data,w,h)
 local rows={{141,142},{80,81}};local cells={};local sum=0
 for dz=0,1 do for dx=0,1 do
  local x,z=10+dx,12+dz;local k=key(x,z);local s=S.shapeAt[k];local t=rows[dz+1][dx+1]
  if S.tileAt[k]~=t or map:tileAt(x,z)~=t or not s or s.class~='wall' or s.flat or s.h~=16
   or s.authored or S.skip[k] or (S.doorFold and S.doorFold[k])
   or map:warpAtCell(5,6) or map:isWarpTileCell(5,6)then return end
  cells[#cells+1]={k=k,x=x,z=z,height=6}
 end end
 local function pos(x,y)local t=rows[math.floor(y/8)+1][math.floor(x/8)+1];return t%16*8+x%8,math.floor(t/16)*8+y%8 end
 for y=0,15 do for x=0,15 do
  local ax,ay=pos(x,y);local ok,r,g,b,a=pcall(data.getPixel,data,ax,ay)
  if not ok or type(r)~='number' or type(g)~='number' or type(b)~='number' or type(a)~='number'
   or r~=r or g~=g or b~=b or a~=a or r<0 or r>1 or a<.999 then return end
  local l=math.floor(r*3+.5)
  if math.abs(r-l/3)>.01 or math.abs(g-r)>.01 or math.abs(b-r)>.01 then return end
  sum=sum+(y*16+x+1)*(l+1)
 end end
 if sum~=88980 then return end
 local function uv(x,y)local ax,ay=pos(x,y);return G.texelUV(ax,ay,w,h)end
 local top,edge,leg=uv(8,3),uv(2,8),uv(7,14)
 local q={};local box=G.geometryWriter(q,192)
 box(87,1,103,89,5.3,105,leg)
 box(83,0,103,93,1,105,leg);box(87,0,99,89,1,109,leg)
 for j=0,15 do
  local a,b=j*math.pi/8,(j+1)*math.pi/8
  local ax,az=88+7*math.cos(a),104+7*math.sin(a)
  local bx,bz=88+7*math.cos(b),104+7*math.sin(b)
  q[#q+1]={{88,6,104},{ax,6,az},{bx,6,bz},{88,6,104},own=true,uv=top,shade=1}
  q[#q+1]={{ax,5.1,az},{bx,5.1,bz},{bx,6,bz},{ax,6,az},own=true,uv=edge,shade=.86}
 end
 return q,cells
end
function M.build(S,map,data,perRow)
 local p=map and plans[map.id]
 if not p or S.outdoor or S.interiorSeatCleanup or not map.def or map.def.generation~=2
  or map.def.width~=p.width or map.def.height~=p.height or not map.tileset or map.tileset.id~=p.tileset
  or type(map.tileAt)~='function' or type(map.warpAtCell)~='function' or type(map.isWarpTileCell)~='function'
  or not data or not data.getDimensions or not data.getPixel or (perRow or 16)~=16 then return 0 end
 local w,h=data:getDimensions();if w~=128 or h<p.ay+16 then return 0 end
 local sum=0
 for y=0,15 do for x=0,15 do
  local ok,r,g,b,a=pcall(data.getPixel,data,p.ax+x,p.ay+y)
  if not ok or type(r)~='number' or type(g)~='number' or type(b)~='number' or type(a)~='number'
   or r~=r or g~=g or b~=b or a~=a or r<0 or r>1 or a<.999 then return 0 end
  local l=math.floor(r*3+.5)
  if math.abs(r-l/3)>.01 or math.abs(g-r)>.01 or math.abs(b-r)>.01 then return 0 end
  sum=sum+(y*16+x+1)*(l+1)
 end end
 if sum~=p.sum then return 0 end
 local function uv(x,y)return G.texelUV(p.ax+x,p.ay+y,w,h)end
 local out,claims,count={}, {},0
 for _,pos in ipairs(p.xy)do
  local valid=true;local cells={};local xx,zz=pos[1],pos[2]
  for dz=0,1 do for dx=0,1 do
   local x,z=xx+dx,zz+dz;local k=key(x,z);local s=S.shapeAt[k]
   local ok,t=pcall(map.tileAt,map,x,z)
   if not ok or t~=p.tiles[dz+1][dx+1] or S.tileAt[k]~=t or not s or s.class~='ground'
    or not s.flat or s.h~=0 or s.authored or S.skip[k] or (S.doorFold and S.doorFold[k])then valid=false end
   for _,method in ipairs({'warpAtCell','isWarpTileCell'})do
    local good,warp=pcall(map[method],map,math.floor(x/2),math.floor(z/2));if not good or warp then valid=false end
   end
   cells[#cells+1]={k=k,x=x,z=z}
  end end
  if valid then
   local q={};local box=G.geometryWriter(q,192);local x,z=xx*8,zz*8
   if p.kind=='chair'then
    -- Square cushion and narrow northern back, unlike the source's projected
    -- front/legs. Keep the open space below the seat and four physical legs.
    local wood,cushion,edge=uv(6,10),uv(6,5),uv(3,8)
    for _,dx in ipairs({3,11.5})do for _,dz in ipairs({3.5,11.5})do box(x+dx,0,z+dz,x+dx+1.5,4.2,z+dz+1.5,wood)end end
    box(x+2.5,3.8,z+3,x+13.5,5,z+13.5,edge)
    box(x+3,5,z+4,x+13,5.6,z+13,cushion)
    box(x+2.5,5,z+2.5,x+4,9,z+4,wood);box(x+12,5,z+2.5,x+13.5,9,z+4,wood)
    box(x+4,6.5,z+2.5,x+12,8.8,z+3.8,cushion)
   else
    local cushion,edge,metal=uv(6,5),uv(5,8),uv(5,11)
    box(x+7,1,z+7,x+9,4.7,z+9,metal)
    box(x+3,0,z+7,x+13,1,z+9,metal);box(x+7,0,z+3,x+9,1,z+13,metal)
    for j=0,15 do
     local a,b=j*math.pi/8,(j+1)*math.pi/8
     local ax,az=x+8+5.8*math.cos(a),z+8+5.8*math.sin(a)
     local bx,bz=x+8+5.8*math.cos(b),z+8+5.8*math.sin(b)
     q[#q+1]={{x+8,5.6,z+8},{ax,5.6,az},{bx,5.6,bz},{x+8,5.6,z+8},own=true,uv=cushion,shade=1}
     q[#q+1]={{ax,4.5,az},{bx,4.5,bz},{bx,5.6,bz},{ax,5.6,az},own=true,uv=edge,shade=.88}
    end
   end
   if #out+#q<=M.MAX_QUADS then
    for _,v in ipairs(q)do out[#out+1]=v end
    for _,v in ipairs(cells)do claims[#claims+1]=v end
    count=count+1
   end
  end
 end
 local tables=0
 if p.kind=='stool' and h>=72 then
  local q,cells=radioTable(S,map,data,w,h)
  if q and #out+#q<=M.MAX_QUADS then
   for _,v in ipairs(q)do out[#out+1]=v end
   for _,v in ipairs(cells)do claims[#claims+1]=v end
   count=count+1;tables=1
  end
 end
 if count==0 then return 0 end
 for _,v in ipairs(claims)do
  S.skip[v.k]=true
  S.ground[v.k]=p.kind=='chair' and ((v.x+v.z)%2==0 and 1 or 0x26) or 1
  S.shapeAt[v.k]={class='building',art='building',authored=true,flat=false,h=v.height or (p.kind=='chair' and 9 or 5.6)}
 end
 for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
 S.interiorSeatCleanup={models=count,quads=#out,claimedTiles=#claims,kind=p.kind,tables=tables,seats=count-tables}
 return #out
end
return M
