-- Remove only verified flat support/shadow pixels of successfully replaced
-- furniture. S is render metadata: source maps, collision and atlases remain
-- unchanged. Run after furniture builders, before common-ground resolution.
local M={MAX_TILES=128}
local function key(x,y)return(y+64)*4096+x+64 end
local function claimed(S,x,y,rows)
 for r,row in ipairs(rows)do for c,t in ipairs(row)do
  local k=key(x+c-1,y+r-1);local s=S.shapeAt[k]
  if not S.skip[k] or S.tileAt[k]~=t or not s or s.class~='building' or not s.authored then return false end
 end end
 return true
end
local function flat(S,x,y,t)
 local k=key(x,y);local s=S.shapeAt[k]
 return not S.skip[k] and S.tileAt[k]==t and s and s.flat and s.class=='ground' and (s.h or 0)==0
end
local function warp(map,x,y)
 local cx,cy=math.floor(x/2),math.floor(y/2)
 if type(map.warpAtCell)=='function' and map:warpAtCell(cx,cy)then return true end
 for _,w in ipairs(map.def.warps or {})do if w.x==cx and w.y==cy then return true end end
 return type(map.warpAt)=='table' and map.warpAt[cy*map.def.width*2+cx] or false
end
local function pinGround(S,x,y,rows,t)
 for r,row in ipairs(rows)do for c in ipairs(row)do S.ground[key(x+c-1,y+r-1)]=t end end
end
function M.build(S,map)
 if not(map and map.def and map.def.generation==2 and map.tileset)or S.outdoor or S.furnitureFloorCleanup then return 0 end
 local report={tiles=0,groups=0,modelGroundPins=0}
 local function strip(x,y,tiles,floorTile)
  if report.tiles+#tiles>M.MAX_TILES then return false end
  for c,t in ipairs(tiles)do
   if not flat(S,x+c-1,y,t) or not flat(S,x+c-1,y+1,floorTile) or warp(map,x+c-1,y) then return false end
  end
  for c in ipairs(tiles)do local k=key(x+c-1,y)
   S.skip[k]=true;S.ground[k]=floorTile
  end
  report.tiles=report.tiles+#tiles;report.groups=report.groups+1
  return true
 end
 if map.id=='PLAYERS_HOUSE_2F' and map.tileset.id=='TilesetPlayersRoom' then
  local models=S.electronicsVisuals and S.electronicsVisuals.models
  local pcRows={{0x0B,0x0C},{0x1B,0x1C},{0x2B,0x2C}}
  local stereoRows={{0x42,0x43},{0x52,0x53}}
  for _,pc in ipairs(models or {})do if pc.id=='bedroom_pc' then
   for _,stereo in ipairs(models)do
    if stereo.id=='bedroom_stereo_lamp' and stereo.x==pc.x+2 and stereo.z==pc.z+1
      and claimed(S,pc.x,pc.z,pcRows) and claimed(S,stereo.x,stereo.z,stereoRows)
      and strip(pc.x,pc.z+3,{0x30,0x31,0x31,0x32},0x01) then
     -- Electronics' nearest-ground vote can pick this very shadow strip.
     -- Correct its under-model donor as part of the same verified context.
     pinGround(S,pc.x,pc.z,pcRows,0x01)
     pinGround(S,stereo.x,stereo.z,stereoRows,0x01)
     report.modelGroundPins=report.modelGroundPins+10
    end
   end
  end end
 elseif map.id=='ELMS_LAB' and map.tileset.id=='TilesetLab'
     and S.deskVisuals and (S.deskVisuals.count or 0)>0 then
  for y=0,map.def.height*4-4 do for x=0,map.def.width*4-3 do
   if S.tileAt[key(x,y)]==5 and S.tileAt[key(x,y+1)]==0x15 then
    local n=1
    while n<7 and S.tileAt[key(x+n,y)]==6 and S.tileAt[key(x+n,y+1)]==0x16 do n=n+1 end
    if n>=2 and S.tileAt[key(x+n,y)]==7 and S.tileAt[key(x+n,y+1)]==0x17 then
     local rows,shadows={{},{}},{}
     for c=0,n do
      rows[1][c+1]=c==0 and 5 or(c==n and 7 or 6)
      rows[2][c+1]=rows[1][c+1]+16
      shadows[c+1]=c==0 and 0x25 or(c==n and 0x27 or 0x26)
     end
     if claimed(S,x,y,rows) and strip(x,y+2,shadows,0x10)then
      pinGround(S,x,y,rows,0x10);report.modelGroundPins=report.modelGroundPins+(n+1)*2
     end
    end
   end
  end end
 end
 S.furnitureFloorCleanup=report
 return report.tiles
end
return M
