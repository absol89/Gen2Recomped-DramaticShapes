-- Original native-material upper finishes. This replaces, never layers over,
-- the finite Lab12 enclosure. Original wall art, props and door levels stay.
local V=...
local Geometry=V.require('Gen2ArchitectureVisuals')
local Styles=V.require('Gen2InteriorStyles')
local BlankShell=V.require('Gen2BlankShell')
local StairSideFinish=V.require('Gen2StairSideFinish')
local WallArt=V.require('Gen2WallArt')
local RoomPaper=V.require('Gen2RoomPaper')
local ExitDoors=V.require('Gen2ExitDoors')
local M={MAX_QUADS=2200,CEILING_HEIGHT=40}
local floor,ceil,min,max=math.floor,math.ceil,math.min,math.max
local function key(x,z)return (z+64)*4096+x+64 end

-- A complete authored fixture may pin its former backing volume before run
-- detection. Accept only its exact native wall contract, never arbitrary
-- authored furniture or a map-wide height hint.
function M.fixtureWallColumns(S,map)
  local columns={}
  if not(map and map.def and map.def.generation==2 and map.id=='MR_POKEMONS_HOUSE'
      and map.tileset and map.tileset.id=='TilesetFacility' and S.sofaFixtures
      and type(S.sofaFixtures.wallColumns)=='table' and type(map.tileAt)=='function'
      and type(map.warpAtCell)=='function' and type(map.isWarpTileCell)=='function')then return columns end
  for x=4,11 do
    local pinned=x<=7
    if not pinned or S.sofaFixtures.wallColumns[x]==16 then
      local valid=true
      for z=0,1 do
        local k=key(x,z);local s=S.shapeAt[k];local r=S.runs and S.runs[k]
        if S.tileAt[k]~=0x22 or map:tileAt(x,z)~=0x22 or not s or s.class~='wall'
            or s.art~='upright' or s.h~=16 or s.authored~=pinned or s.flat
            or(S.skip and S.skip[k])or(S.doorFold and S.doorFold[k])
            or(not pinned and not r)
            or(r and(r.h~=16 or r.front~=1 or r.base~=0 or r.rise~=0 or r.door))
            or map:warpAtCell(floor(x/2),0)or map:isWarpTileCell(floor(x/2),0)then valid=false;break end
      end
      if valid then columns[x]={height=16,frontDepth=16}end
    end
  end
  return columns
end

function M.bikeBackdropColumns(S,map)
  local out={}
  if not(map and map.def and map.def.generation==2 and map.id=='GOLDENROD_BIKE_SHOP'
      and map.def.width==4 and map.def.height==4 and map.tileset and map.tileset.id=='TilesetChampionsRoom'
      and S.bikeShopFixtures and type(S.bikeShopFixtures.wallColumns)=='table'
      and type(map.tileAt)=='function'and type(map.warpAtCell)=='function'and type(map.isWarpTileCell)=='function')then return out end
  local plans={{4,{{2,3},{43,44},{5,6},{21,22}}},{8,{{2,3},{43,44},{5,6},{21,22}}},
    {10,{{18,19},{43,44},{5,6},{21,22}}},
    {0,{{37,38,38,39},{54,55,55,58},{34,35,35,36},{50,51,51,52}}}}
  for _,plan in ipairs(plans)do
    local anchor,rows=plan[1],plan[2]
    local valid=true
    for z=0,3 do for dx=0,#rows[1]-1 do
      local x=anchor+dx;local k=key(x,z);local s=S.shapeAt[k]
      if S.bikeShopFixtures.wallColumns[x]~=16 or S.tileAt[k]~=rows[z+1][dx+1]
          or(anchor==0 and not(S.bikeShopFixtures.rackWallColumns and S.bikeShopFixtures.rackWallColumns[x]==16))
          or map:tileAt(x,z)~=rows[z+1][dx+1]or not s or s.class~='building'
          or s.art~='building'or s.h~=0 or not s.authored or s.flat or not(S.skip and S.skip[k])
          or(S.runs and S.runs[k])or(S.doorFold and S.doorFold[k])
          or map:warpAtCell(floor(x/2),floor(z/2))or map:isWarpTileCell(floor(x/2),floor(z/2))then valid=false end
    end end
    if valid then for dx=0,#rows[1]-1 do out[anchor+dx]=true end end
  end
  return out
end

function M.bikeSignWallColumns(S,map)
  local out={}
  local meta=S.bikeShopFixtures and S.bikeShopFixtures.signWallColumns
  if not(map and map.def and map.id=='GOLDENROD_BIKE_SHOP'and map.def.generation==2
      and map.tileset and map.tileset.id=='TilesetChampionsRoom'and type(meta)=='table'
      and type(map.tileAt)=='function'and type(map.warpAtCell)=='function'and type(map.isWarpTileCell)=='function')then return out end
  local rows={{18,19},{33,33}};local valid=true
  for z=0,1 do for dx=0,1 do local x=6+dx;local k=key(x,z);local s=S.shapeAt[k];local r=S.runs and S.runs[k]
    if meta[x]~=16 or S.tileAt[k]~=rows[z+1][dx+1]or map:tileAt(x,z)~=rows[z+1][dx+1]
        or not s or s.class~='wall'or s.art~='upright'or s.h~=16 or not s.authored or s.flat
        or(S.skip and S.skip[k])or(S.doorFold and S.doorFold[k])
        or(r and(r.h~=16 or r.front~=1 or r.base~=0 or r.rise~=0 or r.door))
        or map:warpAtCell(3,0)or map:isWarpTileCell(3,0)then valid=false end
  end end
  if valid then out[6]={height=16,frontDepth=16};out[7]={height=16,frontDepth=16}end
  return out
end

function M.bikeWestGaps(S,map,data)
  local out={}
  if not(map and map.def and map.id=='GOLDENROD_BIKE_SHOP'and map.def.generation==2
      and map.def.width==4 and map.def.height==4 and map.tileset and map.tileset.id=='TilesetChampionsRoom'
      and S.bikeShopFixtures and type(map.tileAt)=='function'and type(map.warpAtCell)=='function'
      and type(map.isWarpTileCell)=='function'and data and data.getPixel and data.getDimensions)then return out end
  if map.def.connections and next(map.def.connections)then return out end
  local w,h=data:getDimensions();if w~=128 or h<16 then return out end
  -- The actual native map outside sample is tile10, not synthetic S.tile01.
  -- Its entire black/opaque graphic must still be void, never altered art.
  for y=8,15 do for x=0,7 do local r,g,b,a=data:getPixel(x,y)
    if r~=0 or g~=0 or b~=0 or a~=1 then return out end
  end end
  local function gap(x,z,ix,iz,source)
    local k=key(x,z);local ik=key(ix,iz);local s=S.shapeAt[k];local inside=S.shapeAt[ik]
    if s and s.class=='shell'and s.art=='upright'and not s.authored and not s.flat and s.h==32
        and S.tileAt[k]==1 and S.skip and S.skip[k]and not(S.runs and S.runs[k])
        and not(S.doorFold and (S.doorFold[k]or S.doorFold[ik]))and map:tileAt(x,z)==0x10
        and inside and inside.class=='ground'and inside.flat and inside.h==0
        and S.tileAt[ik]==source and map:tileAt(ix,iz)==source
        and not map:warpAtCell(floor(ix/2),floor(iz/2))
        and not map:isWarpTileCell(floor(ix/2),floor(iz/2))then return true end
  end
  for _,z in ipairs({8,14})do out[z]=gap(-1,z,0,z,0x20)or nil end
  local south,east={},{}
  -- Paired exit columns4..7 are never considered, even if a host changes
  -- their warp predicate. Native ground/skirting art stays entirely intact.
  for _,x in ipairs({0,1,2,3,8,9,10,11,12,13})do south[x]=gap(x,16,x,15,0x20)or nil end
  for _,z in ipairs({2,4,6,10})do east[z]=gap(16,z,15,z,(z==2 or z==10)and 0x11 or 0x20)or nil end
  local lintel=true
  for x=4,7 do local k=key(x,16);local s=S.shapeAt[k];local inside=S.shapeAt[key(x,15)]
    if not s or s.class~='shell'or s.art~='upright'or s.authored or s.flat or s.h~=32
        or S.tileAt[k]~=1 or not(S.skip and S.skip[k])or(S.runs and S.runs[k])
        or(S.doorFold and S.doorFold[k])or map:tileAt(x,16)~=0x10
        or not inside or inside.class~='ground'or not inside.flat or inside.h~=0
        or S.tileAt[key(x,15)]~=0x14 or map:tileAt(x,15)~=0x14
        or not map:warpAtCell(floor(x/2),7)or not map:isWarpTileCell(floor(x/2),7)then lintel=false end
  end
  return out,south,east,lintel
end

-- A host may run the art claim before native trim generation. Retain its
-- wall-column evidence: applying again to already claimed cells loses it.
function M.wallArtForBuild(S,map,data,perRow)
  if type(S.gen2MountedWallArt)~='table' then
    S.gen2MountedWallArt=WallArt.apply(S,map,data,perRow or 16)
  end
  return S.gen2MountedWallArt
end

local function palette(S,data,perRow,w,h)
  local votes={}
  for k,s in pairs(S.shapeAt)do
    local tile=S.tileAt[k]
    if (s.class=='shell' or s.class=='wall') and type(tile)=='number'
        and tile>=0 and (tile%perRow)*8+8<=w and floor(tile/perRow)*8+8<=h then
      votes[tile]=(votes[tile]or 0)+1
    end
  end
  local best,count,pale,dark=nil,0,nil,nil
  for tile,n in pairs(votes)do
    local ox,oy=(tile%perRow)*8,floor(tile/perRow)*8
    local light,accent,high,distance=nil,nil,-1,math.huge
    for z=0,7 do for x=0,7 do
      local r,g,b,a=data:getPixel(ox+x,oy+z)
      local l=(r+g+b)/3
      if a>.5 then
        if l>high then light={ox+x,oy+z};high=l end
        local d=math.abs(l-.42)
        if d<distance then accent={ox+x,oy+z};distance=d end
      end
    end end
    if light and high>=.25 and (n>count or(n==count and tile<(best or tile+1)))then
      best,count,pale,dark=tile,n,light,accent
    end
  end
  if not pale then return end
  return Geometry.texelUV(pale[1],pale[2],w,h),Geometry.texelUV(dark[1],dark[2],w,h),best
end

-- Residential finishes should read as paper/plaster, not inherit saturated
-- furniture or accent-wall colors. Reuse opaque atlas texels; no new texture.
local function warmPalette(data,w,h)
  local target={.94,.89,.78}
  local best,score=nil,math.huge
  -- Finite build-time scan even if a host presents an oversized atlas.
  for pixel=0,min(w*h,65536)-1 do
    local x,y=pixel%w,floor(pixel/w)
    local r,g,b,a=data:getPixel(x,y)
    if a>=.999 and r>=g and g>=b and r-b<.32 then
      local distance=(r-target[1])^2+(g-target[2])^2+(b-target[3])^2
      if r>.83 and distance<score then
        score=distance;best={x,y}
      end
    end
  end
  if best then
    -- Gen2 remaps mid-grey source texels to palette-specific accent colors.
    -- Reuse the paper's light texel for trim with existing face shading;
    -- choosing a grey texel here would turn the trim saturated blue again.
    local paper=Geometry.texelUV(best[1],best[2],w,h)
    return paper,paper
  end
end

-- Ceilings in saturated tilesets must not inherit foliage, carpet or Elite
-- accent colors. Pick the lightest low-chroma opaque atlas texel, keeping
-- all material sourced from the active game's own tileset.
local function neutralPalette(data,w,h)
  local best,score=nil,math.huge
  for pixel=0,min(w*h,65536)-1 do
    local x,y=pixel%w,floor(pixel/w)
    local r,g,b,a=data:getPixel(x,y)
    local hi,lo=max(r,g,b),min(r,g,b)
    if a>=.999 and hi-lo<=.12 and hi>=.58 then
      local target=.82
      local distance=(r-target)^2+(g-target)^2+(b-target)^2
      if distance<score then score=distance;best={x,y} end
    end
  end
  if best then return Geometry.texelUV(best[1],best[2],w,h) end
end

local function tileLight(data,perRow,w,h,tile)
  local ox,oy=(tile%perRow)*8,floor(tile/perRow)*8
  if ox+8>w or oy+8>h then return nil end
  local best,light=nil,-1
  for y=0,7 do for x=0,7 do local r,g,b,a=data:getPixel(ox+x,oy+y)
    local l=(r+g+b)/3;if a>.5 and l>light then best,light={ox+x,oy+y},l end
  end end
  if best then return Geometry.texelUV(best[1],best[2],w,h) end
end

function M.build(S,map,data,perRow)
  if S.roomVisuals or S.outdoor or not data or not map.tileset then return 0 end
  local style=Styles.resolve(map.id or map.def.id,map.tileset.id)
  if not style then return 0 end
  local tw,th=map.def.width*4,map.def.height*4
  local boundary
  local function reject(reason)
    S.roomVisuals={quads=0,style=style.id,reason=reason,boundary=boundary};return 0
  end
  if tw<4 or th<4 or tw~=floor(tw) or th~=floor(th) or tw*th>16384 then
    return reject('room exceeds finite ceiling budget')
  end
  -- Large ship/facility maps cannot afford one ceiling quad per 8px tile.
  -- Ceiling faces use a single source texel, so finite 32px panels preserve
  -- material color without stretching artwork and keep the 2200-quad cap.
  local ceilingStep=tw*th>1600 and 4 or 1
  local ceilingCount=ceil(tw/ceilingStep)*ceil(th/ceilingStep)
  local w,h=data:getDimensions()
  local paper=RoomPaper.prove(map,data)
  local centerPaper=paper and paper.style=='center_ivory_coral'
  local playerPaper=paper and paper.style=='player_warm_paper'
  local bikeFinish=map.id=='GOLDENROD_BIKE_SHOP'and map.def.generation==2
      and map.tileset.id=='TilesetChampionsRoom'and S.bikeShopFixtures~=nil
  local plaster,accent,fieldTile=palette(S,data,perRow or 16,w,h)
  local nativeDado=not paper and style.wallpaper=='native_dado'
  if paper then
    fieldTile=paper.tile
    local ox,oy=(fieldTile%(perRow or 16))*8,floor(fieldTile/(perRow or 16))*8
    plaster=Geometry.texelUV(ox+7,oy+7,w,h)
    accent=Geometry.texelUV(ox+7,oy+6,w,h)
    style.wallpaper=centerPaper and 'center_warm' or 'pixelpaper'
  elseif plaster and style.id:find('house',1,true) then
    local paper,trim=warmPalette(data,w,h)
    if paper then plaster,accent=paper,trim end
  end
  if not plaster then return reject('native wall material unavailable') end
  local ceilingMaterial=plaster
  if style.id=='elite' then
    plaster=tileLight(data,perRow or 16,w,h,0x27)or plaster
    ceilingMaterial=plaster
  elseif style.id=='industrial' then
    ceilingMaterial=neutralPalette(data,w,h)or plaster
    plaster=ceilingMaterial
  end
  local wallArt=M.wallArtForBuild(S,map,data,perRow)
  -- Gatehouses are compact single-storey rooms.  The generic forty-pixel
  -- institutional shell made them cavernous and stretched their ceiling
  -- drawing into long beams.
  local height=style.id=='gate' and 32 or M.CEILING_HEIGHT
  -- Native domestic north walls occupy two map rows: their visible face is
  -- at z=16, not the synthetic shell at z=0. Extend the proven complete row
  -- at its own plane/height or perspective makes equal stripes look unequal.
  local northFront
  local propTops={}
  local mountedColumns={}
  local labColumns=S.labEquipmentVisuals and S.labEquipmentVisuals.wallColumns
  local exactCaps=S.exactNorthCaps and S.exactNorthCaps.columns
  local capColumns={}
  if type(exactCaps)=='table' then
    for x,c in pairs(exactCaps)do
      if type(x)=='number' and x==floor(x) and x>=0 and x<tw and type(c)=='table'
          and type(c.height)=='number' and c.height>0 and c.height<=height and c.height%8==0
          and type(c.frontDepth)=='number' and c.frontDepth>=8 and c.frontDepth<=th*8
          and c.frontDepth%8==0 then
        local k=key(x,c.frontDepth/8-1);local r=S.runs and S.runs[k];local s=S.shapeAt[k]
        if r and r.h==c.height and (r.front+1)*8==c.frontDepth and r.base==0 and r.rise==0
            and not r.door and s and s.class=='wall' and not(S.skip and S.skip[k])
            and not(S.doorFold and S.doorFold[k])then capColumns[x]=c end
      end
    end
  end
  local fixtureColumns=M.fixtureWallColumns(S,map)
  for x,c in pairs(fixtureColumns)do capColumns[x]=c end
  for x,c in pairs(M.bikeSignWallColumns(S,map))do capColumns[x]=c end
  local bikeBackdrops=M.bikeBackdropColumns(S,map)
  local bikeWest,bikeSouth,bikeEast,bikeLintel=M.bikeWestGaps(S,map,data)
  bikeSouth,bikeEast=bikeSouth or{},bikeEast or{}
  local playerColumns={}
  local playerPropColumns={}
  local playerPropTiles=playerPaper and ((map.id or map.def.id)=='PLAYERS_HOUSE_1F'
    and {[0x0A]=true,[0x0B]=true,[0x25]=true,[0x35]=true,[0x06]=true,[0x07]=true}
    or {[0x0B]=true,[0x0C]=true,[0x3B]=true,[0x3C]=true,[0x15]=true,[0x16]=true})
  if playerPaper then
    -- The raw atlas and every map occurrence have already passed RoomPaper's
    -- wall-only proof. HomeFixtures pins these plain panels as authored16;
    -- that render-only pin must not push the upper finish back to z=0.
    for x=0,tw-1 do
      local k=key(x,1);local s=S.shapeAt[k];local r=S.runs and S.runs[k]
      if S.tileAt[k]==paper.tile and map:tileAt(x,1)==paper.tile and s
          and s.class=='wall' and s.art=='upright' and not s.flat and s.h==16
          and not(S.skip and S.skip[k]) and not(S.doorFold and S.doorFold[k])
          and(not r or(r.front==1 and r.base==0 and r.rise==0 and r.h==16 and not r.door))then
        playerColumns[x]=true
      end
    end
  end
  if paper or(wallArt.wallColumns and next(wallArt.wallColumns)) or labColumns then
    local proven=true
    for x=0,tw-1 do
      local k=key(x,1);local s=S.shapeAt[k];local r=S.runs and S.runs[k]
      local provenLab=type(labColumns)=='table' and labColumns[x]==16 and s and s.h==16
      local wall=s and s.class=='wall' and (not s.authored or provenLab) and r and r.front==1
          and r.base==0 and r.rise==0 and not r.door and r.h>=16 and r.h<=32
          and not(S.skip and S.skip[k])
      -- Claimed props can exceed their classification height. Measure their
      -- existing quads conservatively rather than treating s.h as a mesh bound.
      local prop=s and s.class=='building' and s.authored and S.skip and S.skip[k]
          and not r and type(s.h)=='number' and s.h>=0 and s.h<=32
      if not(wall or prop or playerColumns[x])or(S.doorFold and S.doorFold[k])then proven=false end
      if prop then
        local top=s.h
        local house=S.houseWallFixtures and S.houseWallFixtures.wallColumns
        local marker=wallArt.wallColumns and wallArt.wallColumns[x]
        if marker==nil and type(house)=='table'then marker=house[x]end
        local backing=marker==16 and s.h==16
        mountedColumns[x]=backing or nil
        if backing then top=16 else for _,q in ipairs(S.objectQuads)do
          local x0,x1,z0,z1,y1=math.huge,-math.huge,math.huge,-math.huge,-math.huge
          for i=1,4 do local p=q[i]
            x0=min(x0,p[1]);x1=max(x1,p[1]);z0=min(z0,p[3]);z1=max(z1,p[3]);y1=max(y1,p[2])
          end
          if x1>x*8 and x0<(x+1)*8 and z0<=16.1 and z1>=0 then top=max(top,y1+.05)end
        end end
        if top>height then proven=false
        else
          propTops[x]=top
          -- Complete fixture claims are already authored/skipped above. Only
          -- these observed native north-row motifs can extend player paper;
          -- stair/warp/unknown columns never acquire a replacement front.
          if playerPropTiles and playerPropTiles[S.tileAt[k]]
              and S.tileAt[k]==map:tileAt(x,1) and not(S.doorFold and S.doorFold[k])
              and not map:warpAtCell(floor(x/2),0) and not map:isWarpTileCell(floor(x/2),0)then
            playerPropColumns[x]=true
          end
        end
      end
    end
    if proven then northFront=16 end
  end
  local sides,segments,backings={},{},{}
  local stairSides,stairSideStats=StairSideFinish.collect(S,map,data,perRow or 16)
  local stairNorthX=stairSideStats.faces==3 and
    ((map.id=='PLAYERS_HOUSE_1F'and 18)or(map.id=='PLAYERS_HOUSE_2F'and 14))
  boundary={expected=2*(tw+th),actual=0,missingShape=0,wrongClass=0,
    invalidHeight=0,bySide={},heights={},samples={}}
  local function side(x,z,orientation)
    local k=key(x,z);local s=S.shapeAt[k];local run=S.runs and S.runs[k]
    -- The real native run.h includes base already: never add it twice.
    local top=run and run.h or(s and s.h)
    local sideStats=boundary.bySide[orientation]
    if not sideStats then sideStats={expected=0,actual=0};boundary.bySide[orientation]=sideStats end
    sideStats.expected=sideStats.expected+1
    -- A tall existing wall already closes this edge; only shorter walls need
    -- upper infill. Completeness must not confuse tall walls with holes.
    if s and s.class=='shell' and type(top)=='number' and top>0 and top<math.huge then
      sideStats.actual=sideStats.actual+1;boundary.actual=boundary.actual+1
      local topKey=tostring(top);boundary.heights[topKey]=(boundary.heights[topKey]or 0)+1
      local entry={x=x,z=z,orientation=orientation,y=top}
      -- Exact Bike side/exit walls: proved native lower finishes already sit
      -- .025px inward. Use that SAME plane for generated upper/gap finishes,
      -- otherwise changes in native run height expose dotted vertical joins.
      -- Only generated infill moves; source volumes, props and art stay put.
      if orientation~='north'and bikeFinish then entry.depth=.025 end
      if orientation=='north' and bikeBackdrops[x]then
        -- Bikes stay below15.3: upper wall can align with the adjacent16px
        -- native wall without cutting a wheel. Lower backdrop remains at0.
        entry.depth=16;top=16;entry.y=16
      elseif orientation=='west'and bikeWest[z]then
        top=0;entry.y=0
      elseif(orientation=='south'and bikeSouth[x])or(orientation=='east'and bikeEast[z])then
        top=0;entry.y=0
      elseif orientation=='north' and capColumns[x] then
        local c=capColumns[x];local rearTop=top
        entry.depth=c.frontDepth+(playerPaper and .025 or 0);top=c.height;entry.y=top
        if top>rearTop then backings[#backings+1]={x=x,z=z,orientation=orientation,y=rearTop,top=height}end
      elseif orientation=='north' and stairNorthX and x>=stairNorthX and x<stairNorthX+2 then
        -- Native stair art occupies the lower 16px; keep its warp opening.
        -- The upper wallpaper must meet the other north panels at z=16,
        -- not recede to the black border shell at z=0.
        entry.depth=16+.025;top=16;entry.y=16
      elseif orientation=='north' and (northFront or playerColumns[x] or playerPropColumns[x]) then
        local k=key(x,1);local r=S.runs[k]
        local rearTop=top
        entry.depth=(northFront or 16)+(playerPaper and .025 or 0)
        top=r and r.h or((mountedColumns[x] or playerColumns[x]) and 16 or max(top,propTops[x]));entry.y=top
        -- Continue rear closure to ceiling: stopping at propTop leaves an
        -- oblique sightline through the 16px step between the two planes.
        if top>rearTop then backings[#backings+1]={x=x,z=z,orientation=orientation,y=rearTop,top=height}end
      end
      sides[#sides+1]=entry
      for y=top,height-.000001,8 do segments[#segments+1]={side=entry,y=y,top=min(y+8,height)} end
    else
      if not s then boundary.missingShape=boundary.missingShape+1
      elseif s.class~='shell' then boundary.wrongClass=boundary.wrongClass+1
      else boundary.invalidHeight=boundary.invalidHeight+1 end
      if #boundary.samples<8 then boundary.samples[#boundary.samples+1]={
        x=x,z=z,class=s and s.class or 'missing',height=top,run=run~=nil} end
    end
  end
  for x=0,tw-1 do side(x,-1,'north');side(x,th,'south') end
  for z=0,th-1 do side(-1,z,'west');side(tw,z,'east') end
  if #sides~=2*(tw+th) then return reject('native room shell incomplete') end
  local lower,blankStats=BlankShell.collect(S,map,data,perRow or 16,height)
  for i=#lower,1,-1 do
    if lower[i].orientation=='north'and bikeBackdrops[lower[i].x]then table.remove(lower,i)end
  end
  local bikeReturns=0
  for x in pairs(bikeBackdrops)do
    lower[#lower+1]={x=x,z=-1,orientation='north',depth=0,y=0,top=16}
    bikeReturns=bikeReturns+2
  end
  for _,record in ipairs(stairSides)do lower[#lower+1]=record end
  if stairNorthX then for x=stairNorthX,stairNorthX+1 do
    -- Close the black rear shell behind the steps / stairwell. This is a
    -- vertical finish only: the floor cutout and native warp stay untouched.
    lower[#lower+1]={x=x,z=-1,orientation='north',y=0,top=16}
  end end
  if playerPaper then
    -- Same phase, UV density and .9 shade as the upper finish. Native lower
    -- AO made the wallpaper look like a separate upholstered dado. Cover
    -- only proved blank panel fronts, leaving native volume/collision intact.
    for x in pairs(playerColumns)do
      lower[#lower+1]={x=x,z=1,orientation='north',depth=16,y=0,top=16}
    end
  end
  local exits,exitReason=ExitDoors.collect(map)
  for i=#exits,1,-1 do
    local exit=exits[i];local existing=false
    for tx=exit.x0/8,exit.x1/8-1 do for tz=th-2,th do
      local k=key(tx,tz);local r=S.runs and S.runs[k]
      if(S.doorFold and S.doorFold[k])or(r and r.door)then existing=true end
    end end
    if existing then table.remove(exits,i)end
  end
  -- Packaged Gen2DoorStyles.WIDTH/HEIGHT are32/30, confirmed against cache67.
  -- Fill only the two pixels above that real paired exit, never its opening.
  if bikeLintel and #exits==1 then local e=exits[1]
    if e.x0==32 and e.x1==64 and e.z==128 and e.destMap=='GOLDENROD_CITY'and e.destWarp==2 then
      for x=4,7 do lower[#lower+1]={x=x,z=16,orientation='south',y=30,top=32}end
    end
  end
  local upperCount=0
  local function finishCost(y,top)
    if centerPaper then return 3 end
    if paper then return ceil(top/8)-floor(y/8) end
    if not nativeDado or y>=24 then return bikeFinish and y<6 and top>6 and 2 or 1 end
    return ceil(min(top,24)/8)-floor(y/8)+(top>24 and 1 or 0)
  end
  for _,s in ipairs(sides)do if s.y<height then upperCount=upperCount+finishCost(s.y,height) end end
  for _,s in ipairs(backings)do upperCount=upperCount+finishCost(s.y,s.top)end
  -- Solid-texel base faces need no vertical subdivisions. Keep the horizontal
  -- 8px lattice for native curvature, reserve every blank finish before trim.
  local lowerCount=0
  for _,s in ipairs(lower)do lowerCount=lowerCount+finishCost(s.y,s.top) end
  local stairHeaderCount=stairNorthX and 1 or 0
  local baseCost=ceilingCount+upperCount+lowerCount+#exits*16+bikeReturns+stairHeaderCount
  if baseCost>M.MAX_QUADS then return reject('room enclosure exceeds finite budget') end
  local out=S.objectQuads;local before=#out
  local phaseLimit=M.MAX_QUADS
  local function quad(a,b,c,d,uv,shade,role)
    if #out-before>=phaseLimit then return false end
    out[#out+1]={a,b,c,d,uv=uv,shade=shade,own=true,roomRole=role}
    return true
  end
  local function down(x0,z0,x1,z1,y,uv,shade,role)
    return quad({x0,y,z0},{x1,y,z0},{x1,y,z1},{x0,y,z1},uv,shade,role)
  end
  if stairNorthX then
    -- The upper front is at z16.025, the lower stair backing at z.025.
    -- Join those planes under the header so the 16px setback has a closed
    -- underside when seen from the room or while looking up the stairs.
    down(stairNorthX*8,0,(stairNorthX+2)*8,16.025,16,
      plaster,.9,'stair_header_return')
  end
  local function wallPoint(s,u,y,inset)
    if s.orientation=='north' then return{s.x*8+u,y,(s.depth or 0)+inset}
    elseif s.orientation=='south' then return{(s.x+1)*8-u,y,th*8-(s.depth or 0)-inset}
    elseif s.orientation=='west' then return{(s.depth or 0)+inset,y,(s.z+1)*8-u}
    else return{tw*8-(s.depth or 0)-inset,y,s.z*8+u} end
  end
  local wallCoverage={}
  local function cover(s,y0,y1,inset)
    if not bikeFinish or y1<=y0 then return end
    local orientation=s.orientation
    local index=(orientation=='north'or orientation=='south')and s.x or s.z
    local bucket=wallCoverage[orientation]or{};wallCoverage[orientation]=bucket
    local spans=bucket[index]or{};bucket[index]=spans
    local p=wallPoint(s,0,0,inset)
    spans[#spans+1]={y0,y1,(orientation=='west'or orientation=='east')and p[1]or p[3]}
  end
  for _,s in ipairs(sides)do cover(s,s.y,height,0)end
  for _,s in ipairs(lower)do cover(s,s.y,s.top,.025)end
  local function adjoining(s,index,y0,y1,plane)
    local bucket=wallCoverage[s.orientation];local spans=bucket and bucket[index]
    if not spans then return false end
    local cursor=y0
    for _=1,#spans do
      local nextY=cursor
      for _,b in ipairs(spans)do
        -- The only tolerated normal offset is the existing .025px lower
        -- face overlay, not recessed architecture or a different wall plane.
        if math.abs(b[3]-plane)<=.025001 and b[1]<=cursor+.000001 then nextY=max(nextY,b[2])end
      end
      cursor=nextY;if cursor>=y1-.000001 then return true end
    end
    return false
  end
  local function wallRect(s,u0,y0,u1,y1,uv,shade,inset,role)
    if bikeFinish and u0==0 and u1==8 and(role=='upper_wall'or role=='lower_blank_wall')then
      -- Float triangles with unequal vertical endpoints form T-junctions.
      -- A .02px tangent overlap prevents subpixel cracks without moving the
      -- wall in depth. Only expand INTO another generated finish covering
      -- this whole band: room corners, door openings and source art stay out.
      local vertical=s.orientation=='west'or s.orientation=='east'
      local index=vertical and s.z or s.x
      local direction=(s.orientation=='north'or s.orientation=='east')and 1 or -1
      local p=wallPoint(s,0,0,inset);local plane=vertical and p[1]or p[3]
      if adjoining(s,index-direction,y0,y1,plane)then u0=-.02 end
      if adjoining(s,index+direction,y0,y1,plane)then u1=8.02 end
    end
    return quad(wallPoint(s,u0,y0,inset),wallPoint(s,u1,y0,inset),
      wallPoint(s,u1,y1,inset),wallPoint(s,u0,y1,inset),uv,shade,role)
  end
  local function finishWall(s,y,top,inset,role)
    if centerPaper then
      local ox=(fieldTile%(perRow or 16))*8
      local coral=Geometry.texelUV(ox,0,w,h)
      local red=Geometry.texelUV(ox+6,7,w,h)
      if y<16 then wallRect(s,0,y,8,min(top,16),coral,.94,inset,role) end
      if y<17 and top>16 then wallRect(s,0,max(y,16),8,min(top,17),red,.94,inset,role) end
      if top>17 then wallRect(s,0,max(y,17),8,top,plaster,.96,inset,role) end
      return
    end
    if paper or (nativeDado and y<24) then
      -- Match ChunkMesher.uvRect: half-texel insets compress eight world
      -- pixels into seven texture pixels and shift stripes at the native join.
      local ox,oy=(fieldTile%(perRow or 16))*8,floor(fieldTile/(perRow or 16))*8
      local stop=paper and top or min(top,24)
      local yy=y
      while yy<stop do
        local baseY=floor(yy/8)*8
        local endY=min(baseY+8,stop)
        local insetUV=min(.02,(endY-yy)/4)
        local u0,u1=(ox+.02)/w,(ox+7.98)/w
        local v0=(oy+8-(endY-baseY)+insetUV)/h
        local v1=(oy+8-(yy-baseY)-insetUV)/h
        wallRect(s,0,yy,8,endY,{{u0,v1},{u1,v1},{u1,v0},{u0,v0}},.9,inset,role)
        yy=endY
      end
      y=stop
    end
    -- Native ChunkMesher.groundShades falls off at y6. A floor-to-ceiling
    -- solid quad stretches that 6px contact shadow over48px by interpolation.
    -- Keep this exact shop's new closures consistent with adjacent walls.
    if bikeFinish and y<6 and top>6 then
      wallRect(s,0,y,8,6,plaster,.9,inset,role);y=6
    end
    if y<top then wallRect(s,0,y,8,top,plaster,.9,inset,role) end
  end
  -- A closed base is reserved first; decoration cannot consume its budget.
  for z=0,th-1,ceilingStep do for x=0,tw-1,ceilingStep do
    local pattern=style.ceiling;local uv,shade=ceilingMaterial,.93
    if pattern=='planks' or pattern=='traditional' then
      uv=plaster;shade=((floor(x/2)+floor(z/8))%2==0) and .81 or .88
    elseif pattern=='coffer' then shade=(floor(x/4)+floor(z/4))%2==0 and .93 or .85
    elseif pattern=='johto_coffer' then shade=.84
    elseif pattern=='johto_beams' then shade=.87
    elseif pattern=='lab_panels' then shade=(x%4==0 or z%4==0) and .84 or .98
    elseif pattern=='clinical' then shade=(floor(x/2)+floor(z/2))%2==0 and .98 or .93
    elseif pattern=='shop_tiles' then shade=(floor(x/3)+floor(z/3))%2==0 and .93 or .85
    elseif pattern=='industrial' then shade=x%4<2 and .84 or .94
    elseif pattern=='gate_panels' then shade=(x+z)%2==0 and .94 or .89
    elseif pattern=='stone' then shade=(floor(x/2)+z)%2==0 and .76 or .88 end
    down(x*8,z*8,min(tw,x+ceilingStep)*8,min(th,z+ceilingStep)*8,height,uv,shade,'ceiling')
  end end
  for _,s in ipairs(sides)do if s.y<height then
    finishWall(s,s.y,height,0,'upper_wall')
  end end
  for _,s in ipairs(backings)do finishWall(s,s.y,s.top,0,'rear_prop_closure')end
  for _,s in ipairs(lower)do
    finishWall(s,s.y,s.top,.025,'lower_blank_wall')
    for y=s.y,s.top-.000001,8 do
      segments[#segments+1]={side=s,y=y,top=min(y+8,s.top)}
    end
  end
  for x in pairs(bikeBackdrops)do
    down(x*8,.025,(x+1)*8,8,16,plaster,.9,'bike_alcove_return')
    down(x*8,8,(x+1)*8,16,16,plaster,.9,'bike_alcove_return')
  end
  local baseQuads=#out-before

  -- Render-only doors: never alter warps, collision or input. Existing south
  -- edge triggers fire before the player reaches this decorative wall plane.
  local doorBefore=#out
  for _,exit in ipairs(exits)do
    local x0,x1,z=exit.x0,exit.x1,exit.z-.12
    local function face(a,b,c,d,uv,shade,depth)
      local zz=z-(depth or 0)
      quad({c,b,zz},{a,b,zz},{a,d,zz},{c,d,zz},uv,shade,'exit_door')
    end
    local domestic=style.id:find('house',1,true)or style.id=='traditional'
    local panel=domestic and accent or plaster
    face(x0,0,x1,30,accent,.40)
    face(x0+2,1,x1-2,28,panel,.85,.06)
    face(x0,0,x0+2,30,accent,.66,.3)
    face(x1-2,0,x1,30,accent,.66,.3)
    face(x0,28,x1,30,accent,.8,.3)
    local middle=(x0+x1)/2
    face(middle-.35,1,middle+.35,28,accent,.4,.12)
    for _,range in ipairs({{x0+4,middle-2},{middle+2,x1-4}})do
      face(range[1],5,range[2],12,panel,.63,.1)
      face(range[1],16,range[2],25,domestic and panel or plaster,domestic and .70 or 1,.1)
    end
    face(middle-2.2,13,middle-1.1,15,plaster,1,.3)
    face(middle+1.1,13,middle+2.2,15,plaster,1,.3)
    -- Original blank-shell policy protects a tile beside each warp. Finish
    -- only exactly black native border art there, never arbitrary decoration.
    for _,tx in ipairs({x0/8-1,x1/8})do
      local k=key(tx,th);local shape=S.shapeAt[k]
      local run=S.runs and S.runs[k]
      local ok,tile=false,nil
      if map.tileAt then ok,tile=pcall(map.tileAt,map,tx,th)end
      local blank=ok and type(tile)=='number' and tile>=0 and tile==floor(tile)
        and shape and shape.class=='shell' and not shape.authored
        and not(S.skip and S.skip[k])and not(S.doorFold and S.doorFold[k])
        and run and not run.door and(run.rise or 0)==0 and run.h>=16
        and type(run.front)=='number' and type(run.north)=='number'
      local ox,oy=blank and(tile%(perRow or 16))*8 or 0,blank and floor(tile/(perRow or 16))*8 or 0
      blank=blank and ox+8<=w and oy+8<=h
      if blank then for yy=0,7 do for xx=0,7 do
        local r,g,b,a=data:getPixel(ox+xx,oy+yy)
        if a<.999 or max(r,g,b)>.1 then blank=false end
      end end end
      -- North-facing native volume folds each band from the run's own map
      -- row. The border tile alone cannot prove these two visible bands blank.
      if blank then for band=0,1 do
        local row=min(run.front,run.north+max(0,band-floor((run.base or 0)/8)))
        local valid,src=pcall(map.tileAt,map,tx,row)
        if not valid or type(src)~='number' or src<0 or src~=floor(src)then blank=false;break end
        local sx,sy=(src%(perRow or 16))*8,floor(src/(perRow or 16))*8
        if sx+8>w or sy+8>h then blank=false;break end
        for yy=0,7 do for xx=0,7 do local r,g,b,a=data:getPixel(sx+xx,sy+yy)
          if a<.999 or max(r,g,b)>.1 then blank=false end
        end end
      end end
      if blank then
        local uv=plaster
        if paper then
          local ax,ay=(fieldTile%(perRow or 16))*8,floor(fieldTile/(perRow or 16))*8
          local u0,u1,v0,v1=(ax+.02)/w,(ax+7.98)/w,(ay+.02)/h,(ay+7.98)/h
          uv={{u0,v1},{u1,v1},{u1,v0},{u0,v0}}
        end
        face(tx*8,0,tx*8+8,8,uv,.9)
        face(tx*8,8,tx*8+8,16,uv,.9)
      end
    end
  end
  local doorQuads=#out-doorBefore

  -- Surface-lit fixtures use only native palette texels, not new light/shader
  -- sources. They live at the ceiling and cannot intrude into doorway height.
  local function light(cx,cz,kind)
    local y=height-(kind=='lantern' and 4 or 1.4)
    local remaining=M.MAX_QUADS-(#out-before)
    if remaining<24 then return end
    local lightUV=plaster
    if kind=='johto_lantern' or kind=='johto_panel' then
      local rx,rz=kind=='johto_lantern' and 4.5 or 6,3.5
      local bottom=height-2.2
      down(cx-rx,cz-rz,cx+rx,cz+rz,bottom,accent,.40,'light')
      quad({cx+rx,bottom,cz-rz},{cx-rx,bottom,cz-rz},{cx-rx,height-.15,cz-rz},{cx+rx,height-.15,cz-rz},accent,.48,'light')
      quad({cx-rx,bottom,cz+rz},{cx+rx,bottom,cz+rz},{cx+rx,height-.15,cz+rz},{cx-rx,height-.15,cz+rz},accent,.48,'light')
      quad({cx-rx,bottom,cz-rz},{cx-rx,bottom,cz+rz},{cx-rx,height-.15,cz+rz},{cx-rx,height-.15,cz-rz},accent,.43,'light')
      quad({cx+rx,bottom,cz+rz},{cx+rx,bottom,cz-rz},{cx+rx,height-.15,cz-rz},{cx+rx,height-.15,cz+rz},accent,.43,'light')
      down(cx-rx+.7,cz-rz+.7,cx+rx-.7,cz+rz-.7,bottom-.06,lightUV,1,'light')
      if kind=='johto_lantern' then
        down(cx-.22,cz-rz+.7,cx+.22,cz+rz-.7,bottom-.1,accent,.45,'light')
      else
        down(cx-rx+.7,cz-.2,cx+rx-.7,cz+.2,bottom-.1,accent,.45,'light')
      end
    elseif kind=='round' or kind=='lantern' then
      local r,a=kind=='lantern' and 3 or 4,kind=='lantern' and 1.4 or 1.8
      local p={{-r,-a},{-a,-r},{a,-r},{r,-a},{r,a},{a,r},{-a,r},{-r,a}}
      local function vertex(i,yy)return{cx+p[i][1],yy,cz+p[i][2]}end
      for _,q in ipairs({{1,2,3,4},{1,4,5,8},{8,5,6,7}})do
        quad(vertex(q[1],y),vertex(q[2],y),vertex(q[3],y),vertex(q[4],y),lightUV,1,'light')
      end
      for i=1,8 do local j=i%8+1
        quad(vertex(j,y),vertex(i,y),vertex(i,height-.1),vertex(j,height-.1),accent,.86,'light')
      end
    elseif kind=='fluorescent' then
      for x=cx-8,cx,8 do down(x,cz-1.5,x+8,cz+1.5,y,lightUV,1,'light') end
      for x=cx-8,cx,8 do
        quad({x+8,y,cz-1.5},{x,y,cz-1.5},{x,height-.1,cz-1.5},{x+8,height-.1,cz-1.5},accent,.8,'light')
        quad({x,y,cz+1.5},{x+8,y,cz+1.5},{x+8,height-.1,cz+1.5},{x,height-.1,cz+1.5},accent,.8,'light')
      end
    elseif kind=='domestic' then
      down(cx-3.5,cz-3.5,cx+3.5,cz+3.5,y,accent,.78,'light')
      down(cx-2.7,cz-2.7,cx+2.7,cz+2.7,y-.04,lightUV,1,'light')
    end
  end
  local lightBefore=#out
  if style.lights~='none' then
    if tw>=24 then light(tw*8/3,th*4,style.lights);light(tw*16/3,th*4,style.lights)
    else light(tw*4,th*4,style.lights) end
  end
  local lightQuads=#out-lightBefore

  -- Partition optional budget so every wall and ceiling has a fair sampling
  -- rather than exhausting all detail on the first scanned edge.
  local remaining=M.MAX_QUADS-(#out-before)
  local wallBudget=floor(remaining*.45)
  local every=max(1,ceil(#segments/max(1,wallBudget)))
  local wallpaperBefore=#out
  phaseLimit=min(M.MAX_QUADS,#out-before+wallBudget)
  for i,seg in ipairs(segments)do if (i-1)%every==0 then
    local s,y0,y1=seg.side,seg.y,seg.top
    local motif=style.wallpaper;local middle=(y0+y1)/2
    if motif=='pixelpaper' then
      if y1==height then
        wallRect(s,0,height-1,8,height,accent,.9,.06,'wallpaper')
        wallRect(s,0,height-1.4,8,height-1,plaster,.98,.07,'wallpaper')
      end
    elseif motif=='native_dado' then
      if y0<=24 and y1>24 then
        wallRect(s,0,24,8,min(25,y1),accent,.57,.12,'wallpaper')
        if y1>25 then wallRect(s,0,25,8,min(25.4,y1),plaster,.95,.125,'wallpaper') end
      end
      if y1==height then wallRect(s,0,height-1.2,8,height,accent,.67,.06,'wallpaper') end
    elseif motif=='pinstripe' then
      wallRect(s,3.65,y0,4.15,y1,accent,.7,.035,'wallpaper')
    elseif motif=='diamond' and y1-y0>=4 then
      quad(wallPoint(s,2,middle,.035),wallPoint(s,4,middle-1.7,.035),
        wallPoint(s,6,middle,.035),wallPoint(s,4,middle+1.7,.035),accent,.85,'wallpaper')
    elseif motif=='wainscot' then
      wallRect(s,0,y0,8,min(y0+.7,y1),accent,.83,.035,'wallpaper')
    elseif motif=='lab_band' then
      wallRect(s,0,max(y0,middle-.6),8,min(y1,middle+.6),accent,.88,.035,'wallpaper')
      if y1-y0>=4 then wallRect(s,6.4,y0,7,y1,accent,.8,.04,'wallpaper') end
    elseif motif=='clinical_band' then
      wallRect(s,0,max(y0,middle-.35),8,min(y1,middle+.35),accent,.9,.035,'wallpaper')
    elseif motif=='shop_band' then
      wallRect(s,0,max(y0,y1-.7),8,y1,accent,.79,.035,'wallpaper')
    elseif motif=='timber' then
      wallRect(s,0,y0,1,y1,accent,.73,.035,'wallpaper')
    elseif motif=='stone' then
      wallRect(s,0,y0,8,min(y0+.4,y1),accent,.71,.035,'wallpaper')
    end
  end end
  local wallpaperQuads=#out-wallpaperBefore
  local detailBefore=#out
  phaseLimit=M.MAX_QUADS
  local available=M.MAX_QUADS-(#out-before)
  local step=max(1,ceil(tw*th/max(1,available)))
  for z=0,th-1 do for x=0,tw-1 do if(z*tw+x)%step==0 then
    local p=style.ceiling;local xx,zz=x*8,z*8;local y=height-.07
    if p=='johto_coffer' then
      if x%6==0 then down(xx+.2,zz,xx+1.7,zz+8,height-1,accent,.58,'ceiling_detail') end
      if z%4==0 then down(xx,zz+.2,xx+8,zz+1.3,height-1,accent,.64,'ceiling_detail') end
    elseif p=='johto_beams' then
      if x%5==1 then down(xx+2.4,zz,xx+4.2,zz+8,height-1.3,accent,.57,'ceiling_detail') end
      if z%4==0 then down(xx,zz+.15,xx+8,zz+.4,y,accent,.82,'ceiling_detail') end
    elseif p=='plaster_beams' and x%4==1 then
      down(xx+3,zz,xx+4.4,zz+8,height-1.6,accent,.83,'ceiling_detail')
    elseif p=='coffer' then
      if x%4==0 then down(xx+.2,zz,xx+1,zz+8,height-.65,accent,.88,'ceiling_detail') end
      if z%4==0 then down(xx,zz+.2,xx+8,zz+1,height-.65,accent,.88,'ceiling_detail') end
    elseif p=='planks' then
      down(xx+.1,zz,xx+.45,zz+8,y,accent,.65,'ceiling_detail')
    elseif p=='traditional' then
      if x%4==1 then down(xx+2.8,zz,xx+4.8,zz+8,height-1.7,accent,.76,'ceiling_detail') end
      if z%4==1 then down(xx,zz+2.8,xx+8,zz+4.8,height-1.7,accent,.76,'ceiling_detail') end
    elseif p=='lab_panels' then
      if x%4==0 then down(xx+.1,zz,xx+.65,zz+8,y,accent,.85,'ceiling_detail') end
      if z%(style.id=='elm_lab' and 3 or 4)==0 then down(xx,zz+.1,xx+8,zz+.65,y,accent,.85,'ceiling_detail') end
    elseif p=='clinical' and (x%2==0 or z%2==0) then
      down(xx,zz+.1,xx+8,zz+.45,y,accent,.94,'ceiling_detail')
    elseif p=='shop_tiles' and x%3==0 then
      down(xx+.1,zz,xx+.7,zz+8,y,accent,.84,'ceiling_detail')
    elseif p=='industrial' and x%4==1 then
      down(xx+1,zz,xx+2,zz+8,height-1.2,accent,.73,'ceiling_detail')
    elseif p=='gate_panels' then
      -- One inset per native tile, deliberately separated on all sides;
      -- no full-room bars masquerading as roof/ceiling panels.
      down(xx+.7,zz+.7,xx+7.3,zz+7.3,height-.32,accent,.84,'ceiling_detail')
    elseif p=='stone' and z%2==0 then
      down(xx,zz+.1,xx+8,zz+.5,y,accent,.7,'ceiling_detail')
    end
  end end end
  local n=#out-before
  S.roomVisuals={quads=n,ceiling=height,style=style.id,ceilingPattern=style.ceiling,
    exitDoors=#exits,doorQuads=doorQuads,exitReason=exitReason,
    wallpaper=style.wallpaper,paperStyle=paper and paper.style,lights=style.lights,wallSegments=#segments,wallArt=wallArt,
    baseQuads=baseQuads,blankShell=blankStats,lowerFinishQuads=#lower,
    wallpaperQuads=wallpaperQuads,lightQuads=lightQuads,
    ceilingDetailQuads=#out-detailBefore,ceilingStride=ceilingStep,
    wallpaperStride=every,detailStride=step,boundary=boundary,
    stairSideFinish=stairSideStats,stairHeaderQuads=stairHeaderCount}
  return n
end
return M
