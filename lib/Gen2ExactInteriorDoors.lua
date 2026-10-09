-- Exact render-only doorway for the east exit in Wise Trio's Room.
-- The two east-boundary warps remain untouched; this only covers the native
-- black opening with a shallow, source-palette double door and frame.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=240}
local function integer(n)return type(n)=='number'and n==math.floor(n)end
local function exactMap(map)
 if not(map and map.def and map.def.generation==2 and map.id=='WISE_TRIOS_ROOM'
   and map.def.width==4 and map.def.height==4 and map.def.environment=='INDOOR'
   and map.tileset and map.tileset.id=='TilesetTraditionalHouse')then return false end
 local w=map.def.warps
 if type(w)~='table'or #w~=3 then return false end
 local found={}
 for i=1,3 do local a=w[i]
  if type(a)~='table'or not integer(a.x)or not integer(a.y)then return false end
  found[a.x..':'..a.y..':'..tostring(a.destMap)..':'..tostring(a.destWarp)]=true
 end
 return found['7:4:ECRUTEAK_CITY:4']and found['7:5:ECRUTEAK_CITY:5']
   and found['1:4:ECRUTEAK_TIN_TOWER_ENTRANCE:5']
end
function M.build(S,map,data,perRow)
 if S.outdoor or S.exactInteriorDoors or not exactMap(map)or not data then return 0 end
 local w,h=data:getDimensions();if(perRow or 16)~=16 or w<128 or h<64 then return 0 end
 local function uv(tile,x,y)
  return G.texelUV((tile%16)*8+x,math.floor(tile/16)*8+y,w,h)
 end
 local dark,wood,light,metal=uv(0x40,6,5),uv(0x41,3,3),uv(0x11,4,3),uv(0x36,3,3)
 local out={};local box=G.geometryWriter(out,M.MAX_QUADS)
 -- Interior plane is x128; keep every new face shallow and inside the room.
 box(125.7,0,64,127.7,32,66,dark)
 box(125.7,0,94,127.7,32,96,dark)
 box(125.7,30,66,127.7,32,94,dark)
 -- Flush side returns cover the native void around the paired warp instead
 -- of leaving black slivers beside an otherwise finished door frame.
 box(125.9,0,56,127.8,30,64,light)
 box(125.9,0,96,127.8,30,104,light)
 box(125.9,1.5,66,127.4,30,79.7,wood)
 box(125.9,1.5,80.3,127.4,30,94,wood)
 -- Raised rails and inset panels make both leaves read as doors off-axis.
 for _,z in ipairs({67.2,80.8})do
  box(125.35,4,z,125.85,13,z+11.5,dark)
  box(125.35,18,z,125.85,27,z+11.5,dark)
  box(125.15,5,z+1,125.32,12,z+10.5,light)
  box(125.15,19,z+1,125.32,26,z+10.5,light)
 end
 box(124.6,14.5,78.2,125.8,16.5,79.4,metal)
 box(124.6,14.5,80.6,125.8,16.5,81.8,metal)
 box(125.6,0,65.5,127.8,2,94.5,dark)
 if #out>M.MAX_QUADS then return 0 end
 for _,q in ipairs(out)do q.roomRole='exact_exit_door';S.objectQuads[#S.objectQuads+1]=q end
 S.exactInteriorDoors={models=1,quads=#out,orientation='east',x=128,z0=64,z1=96,
  destination='ECRUTEAK_CITY',warpsPreserved=3,sideReturns=2}
 return #out
end
return M
