-- Authored National Park hoop boundaries and open pond repair.
-- Adapted from the accepted Gen 2 lab's structural fixes only; no imported
-- paving, vegetation, lighting kit or settings dependency. Map data is untouched.
local M = {}
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local function key(x,z) return (z+64)*4096+x+64 end
local materialCache = setmetatable({}, { __mode = "k" })
local TARGETS = {
  body={.58,.58,.54}, light={.78,.78,.69}, shadow={.38,.39,.36},
  dark={.25,.27,.23}, moss={.28,.39,.19}, turf={.25,.43,.20},
  leaf={.17,.48,.13}, petal={.93,.49,.69}, glass={.98,.79,.35},
  wood={.48,.29,.12}, woodEnd={.59,.39,.20}, stone={.63,.62,.57},
  iron={.12,.13,.16},
}

local function paletteReader(map)
  local set = map and map._battleArtGen2BgSet
  local slots = map and map.tileset and map.tileset.tilePalettes
  local perRow = map and map.tileset and (map.tileset.tilesPerRow or 16) or 16
  local GbcPalette
  if set and slots then
    local ok, module = pcall(require, "src.render.GbcPalette")
    if ok then GbcPalette = module end
  end
  return function(x,y,r,g,b)
    if GbcPalette then
      local tile=floor(x/8)+floor(y/8)*perRow
      local pal=set[slots[tile+1] or 1]
      if pal then
        local shade=r>.83 and 1 or r>.50 and 2 or r>.17 and 3 or 4
        local col=GbcPalette.color(pal,shade)
        if col then
          r,g,b=col[1],col[2],col[3]
          if max(r,g,b)>1 then r,g,b=r/255,g/255,b/255 end
        end
      end
    end
    return r,g,b
  end
end

local function materials(map,data)
  local id=tostring(map and map.id or "?").."|"..
    tostring(map and map._battleArtGen2AtlasProfile or "-")
  local byMap=materialCache[data]
  if not byMap then byMap={};materialCache[data]=byMap end
  if byMap[id] then return byMap[id] end
  local w,h=data:getDimensions();local read=paletteReader(map)
  local best,score={},{ }
  for y=0,h-1 do for x=0,w-1 do
    local r,g,b,a=data:getPixel(x,y)
    if a>.5 then
      local rr,gg,bb=read(x,y,r,g,b)
      local l=.2126*rr+.7152*gg+.0722*bb
      if l>.035 and l<.985 then
        for role,t in pairs(TARGETS) do
          local d=(rr-t[1])^2+(gg-t[2])^2+(bb-t[3])^2
          if not score[role] or d<score[role] then
            score[role]=d;best[role]={(x+.5)/w,(y+.5)/h}
          end
        end
      end
    end
  end end
  -- Every current Gen 2 sheet has candidates. These fallbacks make a future
  -- monochrome/modded sheet fail open to one valid atlas texel, not bad UVs.
  local fallback=best.body or {(0.5)/w,(0.5)/h}
  for role in pairs(TARGETS) do best[role]=best[role] or fallback end
  byMap[id]=best
  return best
end

local function isPark(map)
  return map.id=="NATIONAL_PARK" or map.id=="NATIONAL_PARK_BUG_CONTEST"
end
-- The native Park border is a repeated 2x2 drawing ($23/$24 over
-- $33/$34).  Generic voxelization reads its pale negative space as body and
-- turns the rail into tall opaque panels; splitting the four tiles into
-- standees leaves only disconnected orange/white wedges.  Build the cheap
-- geometry the drawing actually describes: one low open hoop per 16px bay.
-- Each bay is deliberately separated from its neighbours and uses a small
-- three-step crown, matching the reference's individual squared arches
-- instead of visually merging into one continuous fence. No curves,
-- cylinders or unique meshes are required on Quest.
local function parkHoops(S,map,emit)
  if not isPark(map) then return 0 end
  local tw,th=map.def.width*4,map.def.height*4
  local built=0
  local function tile(x,z) return S.tileAt[key(x,z)] end
  local function box(x0,z0,x1,z1,y0,y1,role,tone)
    tone=tone or 1
    emit({{x0,y1,z0},{x1,y1,z0},{x1,y1,z1},{x0,y1,z1}},role,tone*1.08)
    emit({{x0,y0,z0},{x1,y0,z0},{x1,y1,z0},{x0,y1,z0}},role,tone*.86)
    emit({{x1,y0,z1},{x0,y0,z1},{x0,y1,z1},{x1,y1,z1}},role,tone*.92)
    emit({{x0,y0,z1},{x0,y0,z0},{x0,y1,z0},{x0,y1,z1}},role,tone*.78)
    emit({{x1,y0,z0},{x1,y0,z1},{x1,y1,z1},{x1,y1,z0}},role,tone)
  end
  local function inlay(x0,x1,y0,y1,z,back,role,tone)
    local p=back
      and {{x1,y0,z},{x0,y0,z},{x0,y1,z},{x1,y1,z}}
       or {{x0,y0,z},{x1,y0,z},{x1,y1,z},{x0,y1,z}}
    emit(p,role or "light",tone or 1.04)
  end
  local function inlayZ(z0,z1,y0,y1,x,back,role,tone)
    local p=back
      and {{x,y0,z0},{x,y0,z1},{x,y1,z1},{x,y1,z0}}
       or {{x,y0,z1},{x,y0,z0},{x,y1,z0},{x,y1,z1}}
    emit(p,role or "light",tone or 1.04)
  end
  local function claim(x0,z0,w,d)
    for dz=0,d-1 do for dx=0,w-1 do
      local k=key(x0+dx,z0+dz);S.skip[k]=true;S.ground[k]=0x01
    end end
  end
  local function hoopZ(z0,xc,h)
    -- A closed, individual pixel hoop: strong air gap, dark outer frame,
    -- orange inner loop and a cream glint.  The taller stepped crown keeps
    -- the source's arch silhouette from collapsing into a flat fence rail.
    box(xc-1.0,z0+2.4,xc+1.0,z0+4.3,h+.15,h+7.0,"iron",.82)
    box(xc-1.0,z0+11.7,xc+1.0,z0+13.6,h+.15,h+7.0,"iron",.82)
    box(xc-1.0,z0+2.4,xc+1.0,z0+13.6,h+.15,h+1.3,"iron",.84)
    box(xc-1.0,z0+2.4,xc+1.0,z0+13.6,h+6.2,h+7.5,"iron",.88)
    box(xc-1.0,z0+3.6,xc+1.0,z0+12.4,h+7.5,h+8.8,"iron",.91)
    box(xc-1.0,z0+4.8,xc+1.0,z0+11.2,h+8.8,h+10.2,"iron",.94)
    for _,back in ipairs({false,true}) do
      local faceX=xc+(back and 1.01 or-1.01)
      inlayZ(z0+2.9,z0+3.75,h+.65,h+6.15,faceX,back,"wood",1.08)
      inlayZ(z0+12.25,z0+13.1,h+.65,h+6.15,faceX,back,"wood",1.08)
      inlayZ(z0+3.15,z0+12.85,h+.48,h+1.02,faceX,back,"wood",1.08)
      inlayZ(z0+3.15,z0+12.85,h+6.55,h+7.18,faceX,back,"wood",1.08)
      inlayZ(z0+3.8,z0+4.25,h+1.25,h+5.85,faceX,back,"light",1.04)
      inlayZ(z0+11.75,z0+12.2,h+1.25,h+5.85,faceX,back,"light",1.04)
      inlayZ(z0+4.35,z0+11.65,h+7.7,h+8.18,faceX,back,"light",1.06)
    end
  end
  local function hoopX(x0,zc,h)
    box(x0+2.4,zc-1.0,x0+4.3,zc+1.0,h+.15,h+7.0,"iron",.82)
    box(x0+11.7,zc-1.0,x0+13.6,zc+1.0,h+.15,h+7.0,"iron",.82)
    box(x0+2.4,zc-1.0,x0+13.6,zc+1.0,h+.15,h+1.3,"iron",.84)
    box(x0+2.4,zc-1.0,x0+13.6,zc+1.0,h+6.2,h+7.5,"iron",.88)
    box(x0+3.6,zc-1.0,x0+12.4,zc+1.0,h+7.5,h+8.8,"iron",.91)
    box(x0+4.8,zc-1.0,x0+11.2,zc+1.0,h+8.8,h+10.2,"iron",.94)
    for _,back in ipairs({false,true}) do
      local faceZ=zc+(back and 1.01 or-1.01)
      inlay(x0+2.9,x0+3.75,h+.65,h+6.15,faceZ,back,"wood",1.08)
      inlay(x0+12.25,x0+13.1,h+.65,h+6.15,faceZ,back,"wood",1.08)
      inlay(x0+3.15,x0+12.85,h+.48,h+1.02,faceZ,back,"wood",1.08)
      inlay(x0+3.15,x0+12.85,h+6.55,h+7.18,faceZ,back,"wood",1.08)
      inlay(x0+3.8,x0+4.25,h+1.25,h+5.85,faceZ,back,"light",1.04)
      inlay(x0+11.75,x0+12.2,h+1.25,h+5.85,faceZ,back,"light",1.04)
      inlay(x0+4.35,x0+11.65,h+7.7,h+8.18,faceZ,back,"light",1.06)
    end
  end
  for z=0,th-2 do for x=0,tw-2 do
    local north=tile(x,z)==0x23 and tile(x+1,z)==0x24
      and tile(x,z+1)==0x33 and tile(x+1,z+1)==0x34
    local south=tile(x,z)==0x25 and tile(x+1,z)==0x26
      and tile(x,z+1)==0x35 and tile(x+1,z+1)==0x36
    if north or south then
      local x0,z0=x*8,z*8
      local h=(S.shapeAt[key(x,z)] and S.shapeAt[key(x,z)].h) or 0
      -- The source drawing occupies two map rows but depicts HEIGHT, not
      -- depth.  Stand the rail on the path-facing (south) edge; at the cell
      -- centre its legs sit behind the Park's tall grass and only the pale
      -- crown survives, which reads as another little A-shaped roof.
      local zc=z0+(south and 1.3 or 14.7)
      -- Replace the four source-art cells with ordinary Park floor.  The
      -- correction is render-only; collision and map data stay untouched.
      claim(x,z,2,2)
      hoopX(x0,zc,h)
      built=built+1
    end
  end end
  -- The stepped east/west edges use the same rail seen end-on: a 2x4-tile
  -- strip ($1B/$43/$53/$2B beside four $05 tiles), mirrored on the opposite
  -- side.  Boxed independently, each strip was the orange/white A-shaped
  -- object reported in the background.  Replace it with two rotated hoops.
  for z=0,th-4 do for x=0,tw-2 do
    local left=tile(x,z)==0x1B and tile(x+1,z)==0x05
      and tile(x,z+1)==0x43 and tile(x+1,z+1)==0x05
      and tile(x+1,z+2)==0x05 and tile(x+1,z+3)==0x05
      and ((tile(x,z+2)==0x53 and tile(x,z+3)==0x2B)
        or (tile(x,z+2)==0x43 and tile(x,z+3)==0x53))
    local right=tile(x,z)==0x05 and tile(x+1,z)==0x1B
      and tile(x,z+1)==0x05 and tile(x+1,z+1)==0x43
      and tile(x,z+2)==0x05 and tile(x,z+3)==0x05
      and ((tile(x+1,z+2)==0x53 and tile(x+1,z+3)==0x2B)
        or (tile(x+1,z+2)==0x43 and tile(x+1,z+3)==0x53))
    if left or right then
      local h=(S.shapeAt[key(x,z)] and S.shapeAt[key(x,z)].h) or 0
      local xc=x*8+(left and 14.7 or 1.3)
      claim(x,z,2,4)
      hoopZ(z*8,xc,h);hoopZ(z*8+16,xc,h)
      built=built+2
    end
  end end
  -- Short corner returns end after $53 without a fourth $2B row.
  -- Only claim unhandled pairs, so the full strips above never duplicate.
  for z=0,th-2 do for x=0,tw-2 do
    local left=tile(x,z)==0x43 and tile(x,z+1)==0x53
      and tile(x+1,z)==5 and tile(x+1,z+1)==5 and not S.skip[key(x,z)]
    local right=tile(x+1,z)==0x43 and tile(x+1,z+1)==0x53
      and tile(x,z)==5 and tile(x,z+1)==5 and not S.skip[key(x+1,z)]
    if left or right then
      local h=(S.shapeAt[key(x,z)] and S.shapeAt[key(x,z)].h) or 0
      claim(x,z,2,2)
      if z>0 and tile(x+(left and 0 or 1),z-1)==0x1B then claim(x,z-1,2,1) end
      hoopZ(z*8,x*8+(left and 14.7 or 1.3),h)
      built=built+1
    end
  end end
  -- The single $2B return/end tile is not part of either 2x2 hoop
  -- drawing. It still depicts railing, including the staggered corners.
  -- Fit a narrow individual hoop to its one-tile footprint.
  for z=0,th-1 do for x=0,tw-1 do
    if (tile(x,z)==0x2B or tile(x,z)==0x05) and not S.skip[key(x,z)] then
      local function path(dx,dz)
        local t=tile(x+dx,z+dz)
        return t==0 or t==6 or t==0x16
      end
      local west,east,north,south=path(-1,0),path(1,0),path(0,-1),path(0,1)
      -- A corner cap can be diagonally behind a rail. It is not another
      -- freestanding hoop: only the exposed pavement edge receives one.
      local exposed=west or east or north or south
      local side=west or east
      local x0,z0=x*8,z*8
      local original=emit
      emit=function(p,role,tone)
        for _,v in ipairs(p)do
          if side then v[3]=z0+(v[3]-z0)*.5
          else v[1]=x0+(v[1]-x0)*.5 end
        end
        original(p,role,tone)
      end
      local h=(S.shapeAt[key(x,z)] and S.shapeAt[key(x,z)].h) or 0
      if exposed then
        if side then hoopZ(z0,x0+(west and 1.3 or 6.7),h)
        else hoopX(x0,z0+(north and 1.3 or 6.7),h)end
      end
      emit=original
      claim(x,z,1,1);if exposed then built=built+1 end
    end
  end end
  return built
end

-- Crystal's Park pond contains a 2x2 fountain drawing ($80/$81 over
-- $90/$91), surrounded by eight $5F backing cells. In the native map those
-- pixels depict a fountain, but the 3D wall extrusion makes an opaque blue
-- box. A cheap static spray still looked like wires around that box in the
-- desktop test. Until a convincing model exists, show the open authored pond
-- instead. These are render-grid substitutions only: map/collision stay put.
local function parkOpenPond(S,map)
  if not isPark(map) then return 0 end
  local tw,th=map.def.width*4,map.def.height*4
  local function tile(x,z) return S.tileAt[key(x,z)] end
  for z=1,th-3 do for x=1,tw-3 do
    if tile(x,z)==0x80 and tile(x+1,z)==0x81
        and tile(x,z+1)==0x90 and tile(x+1,z+1)==0x91
        and tile(x-1,z)==0x5F and tile(x+2,z)==0x5F then
      local water=S.shapeAt[key(x-2,z)]
      if not water or water.class~="water" then return 0 end
      local cleared=0
      for dz=-1,2 do for dx=-1,2 do
        local source=tile(x+dx,z+dz)
        if source==0x5F or source==0x80 or source==0x81
            or source==0x90 or source==0x91 then
          local k=key(x+dx,z+dz)
          S.shapeAt[k]=water
          S.tileAt[k]=0x14
          -- Height runs are resolved before this adapter. They override the
          -- changed shape in ChunkMesher unless cleared too.
          S.runs[k]=nil
          S.skip[k]=nil
          S.ground[k]=nil
          cleared=cleared+1
        end
      end end
      return cleared
    end
  end end
  return 0
end

function M.build(S,map,data)
  if not S.outdoor or not data or not isPark(map) then return 0 end
  local swatches=materials(map,data)
  local function emit(poly,role,tone)
    local uv=swatches[role] or swatches.body
    S.objectQuads[#S.objectQuads+1]={poly[1],poly[2],poly[3],poly[4] or poly[3],
      uv={uv,uv,uv,uv},shade=tone or 1,own=true}
  end
  local hoops=parkHoops(S,map,emit)
  local pond=parkOpenPond(S,map)
  S.parkBoundary={hoops=hoops,pondCenter=pond}
  return hoops+pond
end
function M.invalidate()
  materialCache=setmetatable({}, {__mode="k"})
end
return M
