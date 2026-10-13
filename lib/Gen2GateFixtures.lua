-- Exact shared Gen 2 route-gate furniture and north exit finish.  Gate maps
-- reuse the same source banks; the old generic wall extrusion turned them
-- into ceiling-high green slabs.  Rendering only: ROM tiles, warps, NPCs and
-- collision remain untouched.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=1800}
local floor,min=math.floor,math.min
local function key(x,z)return(z+64)*4096+x+64 end
local leftRows={{0x08,0x09},{0x0E,0x0F},{0x20,0x21},{0x18,0x19},
 {0x18,0x19},{0x18,0x19},{0x18,0x19},{0x24,0x25}}
local rightRows={{0x08,0x09},{0x18,0x19},{0x18,0x19},{0x18,0x19},
 {0x18,0x19},{0x18,0x19},{0x18,0x19},{0x24,0x25}}

local function exact(S,map,x,z,rows)
 local cells={}
 for dz,row in ipairs(rows)do for dx,t in ipairs(row)do
  local xx,zz=x+dx-1,z+dz-1;local k=key(xx,zz);local s=S.shapeAt[k]
  if S.skip[k]or S.tileAt[k]~=t or map:tileAt(xx,zz)~=t or not s or s.flat
    or map:warpAtCell(floor(xx/2),floor(zz/2))then return end
  cells[#cells+1]={k=k,x=xx,z=zz,t=t}
 end end
 return cells
end

local function counter(data,w,h,perRow,rows,eastFacing)
 local out={};local box=G.geometryWriter(out,720)
 local function uv(tile,px,py)return G.texelUV(tile%perRow*8+(px or 4),floor(tile/perRow)*8+(py or 4),w,h)end
 local body,edge,dark=uv(0x18,4,4),uv(0x24,4,5),uv(0x19,6,5)
 for _,z in ipairs({3,59})do for _,x in ipairs({2,12})do box(x,0,z,x+2,6,z+2,body)end end
 box(1,5.6,1,15,7.2,63,edge)
 local faceX=eastFacing and 15.05 or .95
 for z=4,60,8 do
  if eastFacing then box(13.8,1.2,z,15.2,5.7,min(62,z+6),body)
  else box(.8,1.2,z,2.2,5.7,min(62,z+6),body)end
  local x0=eastFacing and 13.55 or 2.2
  local x1=eastFacing and 13.9 or 2.55
  box(x0,3.1,z+2,x1,3.55,z+4,dark)
 end
 -- Preserve each native tile as a small horizontal top panel rather than
 -- stretching one texel over the entire sixty-four-pixel counter.
 for dz,row in ipairs(rows)do for dx,t in ipairs(row)do
  local ax,ay=t%perRow*8,floor(t/perRow)*8;local x0=(dx-1)*8;local z0=(dz-1)*8
  out[#out+1]={{x0+.35,7.23,z0+.35},{x0+7.65,7.23,z0+.35},
   {x0+7.65,7.23,z0+7.65},{x0+.35,7.23,z0+7.65},
   uv={{(ax+.05)/w,(ay+.05)/h},{(ax+7.95)/w,(ay+.05)/h},
       {(ax+7.95)/w,(ay+7.95)/h},{(ax+.05)/w,(ay+7.95)/h}},shade=.98,own=true}
 end end
 out.gateFacing=eastFacing and'east'or'west';out.gateFront=faceX
 return out
end

local function northDoor(S,map,data,w,h,perRow)
 local tiles={{0x02,0x03,0x02,0x03},{0x12,0x13,0x12,0x13}}
 for dz,row in ipairs(tiles)do for dx,t in ipairs(row)do
  local x,z=7+dx,dz-1;local k=key(x,z);local s=S.shapeAt[k]
  if S.tileAt[k]~=t or map:tileAt(x,z)~=t or not s or s.flat then return{}end
 end end
 local pair={}
 for _,warp in ipairs(map.def.warps or{})do
  if warp.y==0 and(warp.x==4 or warp.x==5)then pair[warp.x]=warp end
 end
 if not(pair[4]and pair[5]and pair[4].destMap==pair[5].destMap)then return{}end
 local function uv(t,px,py)return G.texelUV(t%perRow*8+(px or 4),floor(t/perRow)*8+(py or 4),w,h)end
 local out={};local box=G.geometryWriter(out,120);local trim=uv(0x12,2,4);local panel=uv(0x02,5,4)
 local x0,x1,z=64,96,16.08
 box(x0,0,z,x0+1.5,30,z+1.5,trim);box(x1-1.5,0,z,x1,30,z+1.5,trim)
 box(x0,28.5,z,x1,30,z+1.5,trim);box(79.25,0,z,80.75,28.5,z+1.2,trim)
 out[#out+1]={{x0+1.5,0,z+1.52},{79.25,0,z+1.52},{79.25,28.5,z+1.52},{x0+1.5,28.5,z+1.52},uv=panel,shade=.94,own=true,roomRole='gate_north_door'}
 out[#out+1]={{80.75,0,z+1.52},{x1-1.5,0,z+1.52},{x1-1.5,28.5,z+1.52},{80.75,28.5,z+1.52},uv=panel,shade=.9,own=true,roomRole='gate_north_door'}
 return out
end

function M.build(S,map,data,perRow)
 if S.outdoor or S.gateFixtures or not(map and map.def and map.def.generation==2
  and map.def.environment=='GATE'and map.tileset and map.tileset.id=='TilesetGate'
  and data and type(map.tileAt)=='function'and type(map.warpAtCell)=='function')then return 0 end
 perRow=perRow or 16;local w,h=data:getDimensions();if perRow~=16 or w<128 or h<48 then return 0 end
 local plans={{2,4,leftRows,true},{16,4,rightRows,false}}
 local out,claims,models={}, {},0
 for _,p in ipairs(plans)do local cells=exact(S,map,p[1],p[2],p[3])
  if cells then local q=counter(data,w,h,perRow,p[3],p[4])
   if #out+#q<=M.MAX_QUADS then
    for _,f in ipairs(q)do for i=1,4 do f[i][1]=f[i][1]+p[1]*8;f[i][3]=f[i][3]+p[2]*8 end;out[#out+1]=f end
    for _,c in ipairs(cells)do claims[#claims+1]=c end;models=models+1
   end
  end
 end
 local door=northDoor(S,map,data,w,h,perRow)
 if #out+#door<=M.MAX_QUADS then for _,q in ipairs(door)do out[#out+1]=q end else door={}end
 if models==0 and #door==0 then return 0 end
 for _,c in ipairs(claims)do S.skip[c.k]=true;S.ground[c.k]=0x01
  S.shapeAt[c.k]={class='building',art='building',authored=true,flat=false,h=7.23}end
 for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
 S.gateFixtures={models=models,claims=#claims,quads=#out,northDoor=#door>0 and 1 or 0,
  sharedPattern=true}
 return #out
end
return M
