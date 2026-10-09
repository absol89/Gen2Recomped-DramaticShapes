-- Render-only ground alias after the exact Radio2F atlas bake succeeded.
-- Source01 also belongs to a partition wall; its atlas pixels stay native.
local V=...
local M={}
local function key(x,z)return(z+64)*4096+x+64 end
function M.build(S,map,data,perRow)
 if S.outdoor or S.radioFloor or not(map and map.def and map.def.generation==2
   and map.id=='RADIO_TOWER_2F' and map.tileset and map.tileset.id=='TilesetRadioTower')then return 0 end
 -- Structures uses raw source pixels and normally runs BEFORE the palette
 -- atlas. Resolve that existing atlas first, or this one-time mesh build
 -- would miss the later successful bake and keep the original pink UVs.
 if not map._gen2RadioFloorReady and V and V.require then
  local ok,atlas=pcall(V.require,'TerrainAtlas')
  if ok and atlas and atlas.forMap then pcall(atlas.forMap,map)end
 end
 if not map._gen2RadioFloorReady then return 0 end
 -- Match Structures' common-ground fallback for claimed props whose floor
 -- is still unresolved. Only alias it when01 is the unique majority.
 local votes={}
 for k,s in pairs(S.shapeAt)do if s.flat and s.class=='ground' then
  local t=S.tileAt[k];if t then votes[t]=(votes[t]or 0)+1 end
 end end
 local commonIsOne=(votes[1]or 0)>0
 for t,n in pairs(votes)do if t~=1 and n>=(votes[1]or 0)then commonIsOne=false end end
 local floors,props,office,partition=0,0,0,0
 for z=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  local k=key(x,z);local s=S.shapeAt[k]
  -- Radio2F's eastern office uses decorative pink/white source floor tiles.
  -- They are useful atlas donors but are not a separate rug in the room:
  -- claim the exact office footprint into the same baked blue floor as the
  -- rest of 2F. Props remain intact and keep only their floor underneath.
  if x>=24 and x<=35 and z>=8 and z<=15
      and not(map.warpAtCell and map:warpAtCell(math.floor(x/2),math.floor(z/2)))
      and ((S.skip[k]and S.ground[k]~=nil)or(s and s.flat and s.class=='ground'))then
   S.skip[k]=true;S.ground[k]=0x42;office=office+1
  elseif S.skip[k] then
   if S.ground[k]==1 or (S.ground[k]==false and commonIsOne)then
    S.ground[k]=0x42;props=props+1
   end
  elseif S.tileAt[k]==1 and s and s.flat and s.class=='ground' and (s.h or 0)==0 then
   S.skip[k]=true;S.ground[k]=0x42;floors=floors+1
  end
 end end
 -- A column of source01 at x22 is walkable office floor misclassified as a
 -- ten-cell wall by the native region detector. In VR it becomes the giant
 -- black slab behind the desks. Remove only the captured, exact column and
 -- restore the same baked floor; no collision, warp or map data is changed.
 for z=6,15 do for _,x in ipairs({22,23})do local k=key(x,z);local s=S.shapeAt[k]
  local expected=x==22 and 1 or(z%2==0 and 0x8A or 0x8B)
  if not S.skip[k]and S.tileAt[k]==expected and map:tileAt(x,z)==expected and s
      and s.class=='wall'and not s.flat and s.h==16
      and not(map.warpAtCell and map:warpAtCell(math.floor(x/2),math.floor(z/2)))then
   S.skip[k]=true;S.ground[k]=0x42
   S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}
   partition=partition+1
  end
 end end
 -- Cover the office carpet plane itself after all furniture claims. Some
 -- legacy low-detail props retain their source floor as shallow geometry,
 -- so metadata aliasing alone cannot hide the pink/white strip. A 0.08px
 -- render-only skin keeps the entire exact office footprint consistent.
 local quads,wallQuads=0,0
 if data and data.getDimensions then local w,h=data:getDimensions()
  if(perRow or 16)==16 and w>=128 and h>=40 then
   local t=0x42;local u=((t%16)*8+5.5)/w;local v=(math.floor(t/16)*8+5.5)/h
   -- Radio2F has several disconnected native carpet strips, including one
   -- beneath the northern stools. Skin the whole walkable room body (leaving
   -- the two top-row warp mats untouched) so no pink checker island survives.
   local zones={{0,35,2,15}}
   for _,zone in ipairs(zones)do for z=zone[3],zone[4]do for x=zone[1],zone[2]do
    if not(map.warpAtCell and map:warpAtCell(math.floor(x/2),math.floor(z/2)))then
     local x0,z0=x*8,z*8
     S.objectQuads[#S.objectQuads+1]={{x0,1.1,z0},{x0+8,1.1,z0},{x0+8,1.1,z0+8},{x0,1.1,z0+8},
      uv={{u,v},{u,v},{u,v},{u,v}},shade=1.22,own=true,roomRole='radio_office_floor'}
     quads=quads+1
    end
   end end end
   -- The south boundary's native lower band is an opaque black backing
   -- behind the stools. Cover only that exact, warp-free wall face with the
   -- light source tone used by the room finish; upper wallpaper is untouched.
   local wu=((t%16)*8+.5)/w;local wv=(math.floor(t/16)*8+.5)/h
   for x=0,35 do local x0=x*8
    S.objectQuads[#S.objectQuads+1]={{x0,0,111.72},{x0+8,0,111.72},{x0+8,16,111.72},{x0,16,111.72},
     uv={{wu,wv},{wu,wv},{wu,wv},{wu,wv}},shade=1,own=true,roomRole='radio_south_wall_finish'}
    wallQuads=wallQuads+1
   end
  end
 end
 S.radioFloor={floorCells=floors,propCells=props,officeCells=office,
  partitionCells=partition,donor=0x42,quads=quads+wallQuads,floorQuads=quads,
  wallFinishQuads=wallQuads,floorZones=1}
 return floors+props+office+partition
end
return M
