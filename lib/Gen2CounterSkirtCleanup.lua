-- The PlayersHouse kitchen divider's drawn front skirt shares wall tile11.
-- Its tabletop already has a complete3D replacement; the skirt must not
-- survive as a second16px wallpaper cube. Render state only, never collision.
local M={}
local function key(x,z)return(z+64)*4096+x+64 end
function M.build(S,map)
 if S.outdoor or S.counterSkirtCleanup or not(map and map.def and map.def.generation==2
  and map.id=='PLAYERS_HOUSE_1F' and map.tileset and map.tileset.id=='TilesetPlayersHouse'
  and type(map.tileAt)=='function' and type(map.cellCollision)=='function'
  and type(map.warpAtCell)=='function' and type(map.isWarpTileCell)=='function')then return 0 end
 -- Exact native block0x16 at block(1,1): left plain floor, right tabletop
 -- end25/35,33/34, then the two-row wood-panel face11/11.
 local grid={{1,1,0x25,0x35},{1,1,0x33,0x34},{1,1,0x11,0x11},{1,1,0x11,0x11}}
 for r,row in ipairs(grid)do for c,t in ipairs(row)do
  local x,z=c+3,r+3;local k=key(x,z);local s=S.shapeAt[k]
  if S.tileAt[k]~=t or map:tileAt(x,z)~=t or not s
   or (S.doorFold and S.doorFold[k])then return 0 end
  if c<=2 then
   if S.skip[k] or s.class~='ground' or not s.flat or (s.h or 0)~=0 then return 0 end
  elseif r<=2 then
   if not S.skip[k] or s.class~='building' or not s.authored or s.h~=6 then return 0 end
  else
   if S.skip[k] or s.class~='wall' or s.art~='upright' or s.flat or not s.authored or s.h~=16 then return 0 end
  end
 end end
 -- The blocked native right cells are preserved; a cleared/warped/remapped
 -- block is not the source counter footprint this correction was proven on.
 for z=2,3 do
  if map:cellCollision(2,z)~=0 or map:cellCollision(3,z)~=7
   or map:warpAtCell(3,z) or map:isWarpTileCell(3,z)then return 0 end
 end
 for z=6,7 do for x=6,7 do local k=key(x,z)
  S.skip[k]=true;S.ground[k]=1
  S.shapeAt[k]={class='ground',art='flat',h=0,flat=true,authored=true}
 end end
 S.counterSkirtCleanup={tiles=4,x=6,z=6,sourceBlock=0x16}
 return 4
end
return M
