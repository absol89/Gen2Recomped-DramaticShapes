-- Exact Crystal Pokemon Center link-floor reconstruction and the shared
-- first/second-floor stair pair. These are presentation claims only: native
-- warp tables, collision and interaction ownership remain untouched.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=1100}
local floor=math.floor
local function key(x,z)return(z+64)*4096+x+64 end

local beta={
 CERULEAN_POKECENTER_2F_BETA=true,LAVENDER_POKECENTER_2F_BETA=true,
 VERMILION_POKECENTER_2F_BETA=true,PEWTER_POKECENTER_2F_BETA=true,
 CINNABAR_POKECENTER_2F_BETA=true,VIRIDIAN_POKECENTER_2F_BETA=true,
 SAFFRON_POKECENTER_2F_BETA=true,FUCHSIA_POKECENTER_2F_BETA=true,
 CELADON_POKECENTER_2F_BETA=true,ROUTE_10_POKECENTER_2F_BETA=true,
}

local function tileUV(tile,px,py,row,w,h)
 return G.texelUV((tile%row)*8+(px or 4),floor(tile/row)*8+(py or 4),w,h)
end

local function exactUpper(map)
 local id=map.id or map.def.id
 if id~='POKECENTER_2F'and not beta[id]then return false end
 if map.def.width~=8 or map.def.height~=4 then return false end
 -- Widely separated samples prove the one shared Crystal link-floor layout.
 local proof={{0,0,0x02},{6,0,0x16},{10,0,0x22},{16,0,0x26},
  {26,0,0x1F},{4,3,0x20},{12,3,0x03},{20,3,0x03},
  {0,4,0x34},{24,5,0x46},{30,7,0x46},{12,12,0x48},
  {20,13,0x58},{0,14,0x42},{1,15,0x53}}
 for _,p in ipairs(proof)do if map:tileAt(p[1],p[2])~=p[3]then return false end end
 return true
end

local function claim(S,x,z,ground)
 local k=key(x,z)
 S.skip[k]=true;S.ground[k]=ground or 0x11
 S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}
end

local function role(out,from,name)
 for i=from,#out do out[i].roomRole=name end
end

local function buildStair(S,map,data,row,w,h,x,z,up)
 local a,b,c,d=map:tileAt(x,z),map:tileAt(x+1,z),map:tileAt(x,z+1),map:tileAt(x+1,z+1)
 local first=a==0x44 and b==0x45 and c==0x54 and d==0x55
 local second=a==0x42 and b==0x43 and c==0x52 and d==0x53
 if not(first or second)then return 0 end
 local class=up and'stair_e'or'stair_down_w'
 for dz=0,1 do for dx=0,1 do
  S.shapeAt[key(x+dx,z+dz)]={class=class,art='stair',authored=true,
   flat=false,h=16}
 end end
 -- Structures.buildStairs runs later and applies the shared Gen 1-quality
 -- full-height flight / excavated well to these exact Crystal cells.
 return 0
end

function M.build(S,map,data,perRow)
 if not(S and map and map.def and map.def.generation==2 and map.tileset
    and map.tileset.id=='TilesetPokecenter'and data and not S.outdoor)
    or S.centerUpperFixtures then return 0 end
 local row=perRow or 16;local w,h=data:getDimensions();local id=map.id or map.def.id
 local out=S.objectQuads;local total=0

 if exactUpper(map)then
  -- Remove only the upper eight rows' non-floor native projections. Their
  -- 2D dividers/screens were previously interpreted as ceiling-high walls.
  local claimed=0
  for z=0,7 do for x=0,31 do local k=key(x,z);local s=S.shapeAt[k]
   if s and not s.flat then claim(S,x,z);claimed=claimed+1 end
  end end

  local start=#out+1;local box,count=G.geometryWriter(out,M.MAX_QUADS)
  local body=tileUV(0x36,4,4,row,w,h)
  local trim=tileUV(0x02,3,3,row,w,h)
  local screen=tileUV(0x28,4,4,row,w,h)
  local light=tileUV(0x01,4,4,row,w,h)
  local accent=tileUV(0x34,4,4,row,w,h)
  for bay=0,3 do
   local x0=bay*64
   -- Compact portal frame: the 16px center aisle stays open to the native
   -- north-edge warp while side terminals read as equipment, not chimneys.
   box(x0+21,0,5,x0+24,24,18,body)
   box(x0+40,0,5,x0+43,24,18,body)
   box(x0+21,21,5,x0+43,24,18,trim)
   box(x0+3,0,24,x0+20,7,39,body)
   box(x0+44,0,24,x0+61,7,39,body)
   box(x0+6,7,19,x0+18,19,23,trim)
   box(x0+46,7,19,x0+58,19,23,trim)
   box(x0+8,9,18.4,x0+16,17,19,screen)
   box(x0+48,9,18.4,x0+56,17,19,screen)
   box(x0+4,7,23,x0+20,8,39,light)
   box(x0+44,7,23,x0+60,8,39,light)
   box(x0+29,0,20,x0+35,4,27,accent)
  end
  role(out,start,'center_link_booth')
  total=total+count()

  -- The two repeated 3-seat drawings in the open lobby become low benches.
  local benchStart=#out+1;local bBox,bCount=G.geometryWriter(out,160)
  for _,x0 in ipairs({96,160})do
   for _,lx in ipairs({3,21,39})do
    bBox(x0+lx,0,100,x0+lx+3,4,109,body)
   end
   bBox(x0+1,4,98,x0+47,6,112,accent)
   bBox(x0+1,6,108,x0+47,15,112,screen)
  end
  role(out,benchStart,'center_link_seating');total=total+bCount()
  for z=12,13 do for x=12,17 do claim(S,x,z)end;for x=20,25 do claim(S,x,z)end end

  total=total+buildStair(S,map,data,row,w,h,0,14,false)
  S.centerUpperFixtures={quads=total,claimed=claimed,booths=4,benches=2,
   stair='down',stairPinned=1,layout=id}
  return total
 end

 -- Every ordinary 1F Center uses this exact south-west upstairs flight.
 if map.def.width>=5 and map.def.height>=4 and type(map.tileAt)=='function'
    and map:tileAt(0,map.def.height*4-2)==0x44
    and map:tileAt(1,map.def.height*4-2)==0x45
    and map:tileAt(0,map.def.height*4-1)==0x54
    and map:tileAt(1,map.def.height*4-1)==0x55 then
  local z=map.def.height*4-2
  total=buildStair(S,map,data,row,w,h,0,z,true)
  S.centerUpperFixtures={quads=total,claimed=4,booths=0,benches=0,
   stair='up',stairPinned=1,layout=id}
  return 1
 end
 return 0
end

return M
