-- Contextual floor finishes baked into the existing per-map8px atlas.
-- The whitelist is from inspected Crystal floor art, not collision alone:
-- walkable stools, furniture shadows, mats and tatami borders are excluded.
local V=...
local Map=require('src.world.Map')
local TileShape=V.require('TileShape')
local M={}
local floor,min,max=math.floor,math.min,math.max
local whitelist={
  TilesetHouse={[0x01]=true},TilesetPlayersHouse={[0x01]=true},
  TilesetPlayersRoom={[0x01]=true},TilesetLab={[0x10]=true,[0x24]=true},
  TilesetPokecenter={[0x11]=true},TilesetMart={[0x01]=true,[0x48]=true},
  TilesetFacility={[0x01]=true,[0x26]=true},
  TilesetRadioTower={[0x01]=true},TilesetTraditionalHouse={[0x01]=true},
  TilesetMansion={[0x01]=true,[0x11]=true},
}
local styles={
  oak={kind='wood',rgb={.56,.43,.29}},walnut={kind='wood',rgb={.40,.31,.24}},
  pale_planks={kind='wood',rgb={.66,.58,.45}},academy_oak={kind='wood',rgb={.60,.47,.32}},
  laboratory_linoleum={kind='linoleum',rgb={.58,.63,.62}},
  center_ceramic={kind='tile',rgb={.68,.70,.65}},
  mart_tile={kind='tile',rgb={.51,.58,.59}},
  office_carpet={kind='carpet',rgb={.39,.44,.50}},
  office_carpet_light={kind='carpet',rgb={.45,.49,.54}},
  traditional_timber={kind='wood',rgb={.51,.41,.29}},
  industrial_concrete={kind='linoleum',rgb={.36,.42,.45}},
  facility_blue={kind='linoleum',rgb={.43,.49,.54}},
  ship_oak={kind='wood',rgb={.48,.37,.27}},
  elite_stone={kind='tile',rgb={.29,.31,.34}},
}
local mapFloors={
 POWER_PLANT={allow={[0x01]=true,[0x26]=true},style='industrial_concrete'},
 SILPH_CO_1F={allow={[0x01]=true,[0x26]=true},style='facility_blue'},
 TRAINER_HOUSE_B1F={allow={[0x01]=true,[0x26]=true},style='facility_blue'},
 TEAM_ROCKET_BASE_B3F={allow={[0x01]=true,[0x26]=true},style='industrial_concrete'},
 FAST_SHIP_1F={allow={[0x04]=true},style='ship_oak'},
  FAST_SHIP_B1F={allow={[0x2E]=true,[0x2F]=true},style='industrial_concrete'},
 BRUNOS_ROOM={allow={[0x51]=true,[0x52]=true},style='elite_stone'},
 WILLS_ROOM={allow={[0x51]=true,[0x52]=true},style='elite_stone'},
 -- 0x11 is the authored lobby carpet. The legacy classifier reports it as
 -- a shallow platform even though every occurrence is walkable ground, so
 -- this exact-map proof may replace it while the palette/warp guards remain.
 BATTLE_TOWER_1F={allow={[0x01]=true,[0x11]=true},force={[0x11]=true},style='facility_blue'},
 -- 0x11 is also the authored hallway carpet.  Its collision sampling is
 -- mixed by the door threshold, so the exact-map rule must override that
 -- shared-use classification just as the lobby does.
 BATTLE_TOWER_HALLWAY={allow={[0x01]=true,[0x02]=true,[0x03]=true,[0x11]=true},allowWarp={[0x11]=true},force={[0x11]=true},style='facility_blue'},
 BATTLE_TOWER_ELEVATOR={allow={[0x30]=true,[0x4E]=true,[0x5C]=true,[0x5E]=true},style='facility_blue'},
  BATTLE_TOWER_BATTLE_ROOM={allow={
   [0x21]=true,[0x22]=true,[0x23]=true,[0x24]=true,[0x25]=true,
   [0x30]=true,[0x31]=true,[0x32]=true,[0x33]=true,[0x34]=true,
   [0x46]=true,[0x47]=true,[0x56]=true,[0x57]=true,
  },style='facility_blue'},
 GOLDENROD_POKECENTER_1F={allow={[0x11]=true},allowWarp={[0x11]=true},style='center_ceramic'},
 -- These two rooms use tile 0x01 for nearly the entire carpet, including a
 -- doorway cell.  Exact map scoping makes it safe to replace despite the
 -- mixed collision/warp classification.
 LAV_RADIO_TOWER_1F={allow={[0x01]=true,[0x42]=true,[0x43]=true},allowWarp={[0x01]=true},force={[0x01]=true},style='office_carpet'},
 RADIO_TOWER_5F={allow={[0x01]=true,[0x42]=true,[0x43]=true},allowWarp={[0x01]=true},force={[0x01]=true},style='office_carpet'},
 FAST_SHIP_CABINS_NNW_NNE_NE={allow={[0x0D]=true,[0x1D]=true},style='ship_oak'},
 FAST_SHIP_CABINS_SE_SSE_CAPTAINS_CABIN={allow={[0x0D]=true,[0x1D]=true},style='ship_oak'},
 FAST_SHIP_CABINS_SW_SSW_NW={allow={[0x0D]=true,[0x1D]=true},style='ship_oak'},
}
local function hash(text)
  local n=0;for i=1,#text do n=(n*31+text:byte(i))%65521 end;return n
end
local function styleFor(map)
  local id=tostring(map.id or map.def.id or '')
  if mapFloors[id]then return mapFloors[id].style end
  local t=map.tileset.id
  if t=='TilesetPlayersRoom' then return 'pale_planks' end
  if t=='TilesetPlayersHouse' then return 'oak' end
  if t=='TilesetHouse' then return ({'oak','walnut','pale_planks'})[hash(id)%3+1] end
  if t=='TilesetLab' then return id=='EARLS_POKEMON_ACADEMY' and 'academy_oak' or 'laboratory_linoleum' end
  if t=='TilesetFacility' then return 'facility_blue' end
  if t=='TilesetPokecenter' then return 'center_ceramic' end
  if t=='TilesetMart' then return 'mart_tile' end
  if t=='TilesetRadioTower' then return 'office_carpet' end
  if t=='TilesetMansion' then return 'office_carpet' end
  if t=='TilesetTraditionalHouse' then return 'traditional_timber' end
end
local function finish(style,x,y,seed)
  local grain=((x*13+y*7+seed)%11-5)*.0015
  local delta=grain
  if style.kind=='wood' then
    local plank=floor(y/4)
    delta=delta+(plank==0 and .009 or -.009)
    if y%4==0 then delta=delta-.028 end
    if x==(plank==0 and 0 or 4) and y%4~=0 then delta=delta-.017 end
    if (x+seed+plank*3)%7==0 then delta=delta-.004 end
  elseif style.kind=='tile' then
    if x==0 or y==0 then delta=-.026 end
    if x==1 or y==1 then delta=delta+.006 end
  elseif style.kind=='linoleum' then
    delta=grain*.7
    if y==0 then delta=delta-.009 end
  else
    delta=((x+y)%2==0 and .003 or -.003)+grain*.4
  end
  return max(0,min(1,style.rgb[1]+delta)),max(0,min(1,style.rgb[2]+delta)),max(0,min(1,style.rgb[3]+delta))
end

local chairTiles={[0x02]=true,[0x03]=true,[0x12]=true,[0x13]=true}
-- Native Radio brick-floor drawings, checked by exact color relationships
-- after palette bake. Never replace a new graphic that reused these IDs.
local radioPatterns={
 [0x42]={'____#__.','....#_..','....#_..','########','__._.___','........','........','########'},
 [0x43]={'_.______','........','........','########','____#___','....#...','....#...','########'},
}
local function radioFingerprint(image,tile,w,h,perRow)
 local ox,oy=tile%perRow*8,floor(tile/perRow)*8
 if ox+8>w or oy+8>h then return false end
 local colors={}
 for y=0,7 do for x=0,7 do
  local c={image:getPixel(ox+x,oy+y)};local tag=radioPatterns[tile][y+1]:sub(x+1,x+1)
  if c[4]<.99 then return false end
  local old=colors[tag]
  if old then for i=1,4 do if math.abs(c[i]-old[i])>.000001 then return false end end
  else colors[tag]=c end
 end end
 for a,ca in pairs(colors)do for b,cb in pairs(colors)do
  if a~=b and math.abs(ca[1]-cb[1])+math.abs(ca[2]-cb[2])+math.abs(ca[3]-cb[3])<.01 then return false end
 end end
 return true
end
local function chairBackground(map,image,uses,blocked,originalFloor,style,seed,perRow,w,h)
  local totals,covered={},{}
  local tw,th=map.def.width*4,map.def.height*4
  for y=0,th-1 do for x=0,tw-1 do
    local t=map:tileAt(x,y)
    if chairTiles[t]then totals[t]=(totals[t] or 0)+1 end
    if t==0x02 and x+1<tw and y+1<th and map:tileAt(x+1,y)==0x03
        and map:tileAt(x,y+1)==0x12 and map:tileAt(x+1,y+1)==0x13 then
      for id in pairs(chairTiles)do covered[id]=(covered[id] or 0)+1 end
    end
  end end
  for t in pairs(chairTiles)do
    if not totals[t] or totals[t]~=covered[t] or uses[t]~=true or blocked[t]
        or (t%perRow)*8+8>w or floor(t/perRow)*8+8>h then return nil end
  end
  local pixels={}
  local function atlas(x,y)
    local t=(y<8 and 0x02 or 0x12)+(x<8 and 0 or 1)
    return(t%perRow)*8+x%8,floor(t/perRow)*8+y%8
  end
  for y=0,15 do for x=0,15 do
    local ax,ay=atlas(x,y);pixels[y*16+x]={image:getPixel(ax,ay)}
  end end
  local function sameFloor(x,y)
    local a,b=pixels[y*16+x],originalFloor[(y%8)*8+x%8+1]
    for c=1,4 do if math.abs(a[c]-b[c])>.000001 then return false end end
    return true
  end
  -- These five rows are verified unobstructed floor in the native House
  -- chair drawing. A changed palette or different sprite is ambiguous.
  for y=0,4 do for x=0,15 do if not sameFloor(x,y)then return nil end end end
  local seen,queue={},{}
  local function add(x,y)
    if x<0 or x>15 or y<0 or y>15 then return end
    local k=y*16+x
    if not seen[k] and sameFloor(x,y)then seen[k]=true;queue[#queue+1]={x,y}end
  end
  for i=0,15 do add(i,0);add(i,15);add(0,i);add(15,i)end
  local at=1
  while at<=#queue do
    local p=queue[at];at=at+1
    add(p[1]-1,p[2]);add(p[1]+1,p[2]);add(p[1],p[2]-1);add(p[1],p[2]+1)
  end
  local changed={}
  for _,p in ipairs(queue)do
    local x,y=p[1],p[2];local ax,ay=atlas(x,y)
    local r,g,b=finish(style,x%8,y%8,seed)
    image:setPixel(ax,ay,r,g,b,1)
    changed[(y<8 and 0x02 or 0x12)+(x<8 and 0 or 1)]=true
  end
  return changed
end

-- uses may be the caller's tile->exclusively-flat-ground inventory. If omitted
-- the identical inventory is computed locally. A mixed-use ID is never baked.
-- Returns changed tile count, changed IDs, style name. No assets or meshes.
function M.bake(map,image,uses)
  local painted={}
  if map then map._gen2RadioFloorReady=nil end
  if not(map and map.def and map.tileset and image and map.def.generation==2)
      or Map.isOutdoor(map.def) then return 0,painted,nil end
  local scoped=mapFloors[tostring(map.id or map.def.id or '')]
  local allow=scoped and scoped.allow or whitelist[map.tileset.id]
  if not allow then return 0,painted,nil end
  local styleName=styleFor(map);local style=styles[styleName]
  local shapes=not uses and TileShape.forMap(map)
  uses=uses or {}
  local blocked={};local present={};local warpCells={}
  local cellWidth=map.def.width*2
  for _,warp in ipairs(map.def.warps or {})do
    if type(warp.x)=='number' and type(warp.y)=='number' then warpCells[warp.y*cellWidth+warp.x]=true end
  end
  for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
    local tile=map:tileAt(x,y)
    if tile~=nil then
      present[tile]=true
      if shapes then
        local s=TileShape.at(map,shapes,tile,x,y)
        local eligible=s and s.flat and s.class=='ground'
        if not eligible then uses[tile]=false elseif uses[tile]==nil then uses[tile]=true end
      end
      if allow[tile] or (map.tileset.id=='TilesetHouse' and chairTiles[tile])
          or (map.tileset.id=='TilesetRadioTower' and radioPatterns[tile]) then
        local cx,cy=floor(x/2),floor(y/2)
        local k=cy*cellWidth+cx
        if warpCells[k] or (type(map.warpAt)=='table' and map.warpAt[k])
            or (type(map.warpAtCell)=='function' and map:warpAtCell(cx,cy)) then blocked[tile]=true end
      end
    end
  end end
  local w,h=image:getDimensions();local perRow=map.tileset.tilesPerRow or 16
  local seed=hash(tostring(map.id or map.def.id or ''))
  local count=0;local originalFloor
  if map.tileset.id=='TilesetRadioTower'
      and perRow==16 and uses[0x42]==true and uses[0x43]==true
      and not blocked[0x42] and not blocked[0x43] and not blocked[1]
      and radioFingerprint(image,0x42,w,h,perRow) and radioFingerprint(image,0x43,w,h,perRow)then
    for _,tile in ipairs({0x42,0x43})do
      local ox,oy=tile%16*8,floor(tile/16)*8
      for y=0,7 do for x=0,7 do
        local r,g,b=finish(styles.office_carpet,x,y,seed)
        image:setPixel(ox+x,oy+y,r,g,b,1)
      end end
      painted[tile]=true;count=count+1
    end
    map._gen2RadioFloorReady=true
  end
  for tile in pairs(allow)do
    local warpSafe=scoped and scoped.allowWarp and scoped.allowWarp[tile]
    if present[tile] and (uses[tile]==true or (scoped and scoped.force and scoped.force[tile]))
        and (not blocked[tile] or warpSafe) then
      local ox,oy=(tile%perRow)*8,floor(tile/perRow)*8
      if ox+8<=w and oy+8<=h then
        -- Exact IDs can still be replaced by another mod. Preserve transparent
        -- or black-outlined symbolic art instead of assuming it is plain floor.
        local plain=true;local snapshot={}
        for y=0,7 do for x=0,7 do
          local r,g,b,a=image:getPixel(ox+x,oy+y)
          snapshot[y*8+x+1]={r,g,b,a}
          if a<.99 or (r+g+b)/3<.12 then plain=false end
        end end
        if plain then
          if map.tileset.id=='TilesetHouse' and tile==1 then originalFloor=snapshot end
          local tileStyle=(map.tileset.id=='TilesetMansion' and tile==0x11)
            and styles.office_carpet_light or style
          for y=0,7 do for x=0,7 do
            local r,g,b=finish(tileStyle,x,y,seed)
            image:setPixel(ox+x,oy+y,r,g,b,1)
          end end
          painted[tile]=true;count=count+1
        end
      end
    end
  end
  if originalFloor and painted[1]then
    local backgrounds=chairBackground(map,image,uses,blocked,originalFloor,style,seed,perRow,w,h)
    for tile in pairs(backgrounds or {})do painted[tile]=true;count=count+1 end
  end
  return count,painted,styleName
end
return M
