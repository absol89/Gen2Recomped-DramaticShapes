-- Decorative geometry for the Gen2-authored architecture. Called only while
-- constructing a mesh: no draw hooks, assets, persistent caches or collision edits.
-- Keep the original conservative per-building ceiling.  Sprout's landmark
-- tiers fit by using half as many cross-roof ribs, not by buying more quads.
local M = { MODEL_QUAD_LIMIT = 192, ROOM_QUAD_LIMIT = 768 }
local floor, min, max = math.floor, math.min, math.max
local function key(x, z) return (z + 64) * 4096 + x + 64 end

local function writer(out, limit)
  local count = 0
  local function face(a,b,c,d,uv,shade)
    if count >= limit then return false end
    out[#out+1] = {a,b,c,d,uv=uv,shade=shade,own=true}
    count = count + 1
    return true
  end
  local function box(x0,y0,z0,x1,y1,z1,uv)
    -- Split on the world's eight-voxel lattice so world curvature never tears
    -- a long decorative beam away from the existing building beneath it.
    local x=x0
    while x < x1 do
      local xx=min(x1,(floor(x/8)+1)*8)
      local z=z0
      while z < z1 do
        local zz=min(z1,(floor(z/8)+1)*8)
        if count+6 > limit then return end
        face({x,y1,z},{xx,y1,z},{xx,y1,zz},{x,y1,zz},uv,1)
        face({x,y0,zz},{xx,y0,zz},{xx,y0,z},{x,y0,z},uv,.56)
        face({x,y0,zz},{xx,y0,zz},{xx,y1,zz},{x,y1,zz},uv,.88)
        face({xx,y0,z},{x,y0,z},{x,y1,z},{xx,y1,z},uv,.68)
        face({x,y0,z},{x,y0,zz},{x,y1,zz},{x,y1,z},uv,.76)
        face({xx,y0,zz},{xx,y0,z},{xx,y1,z},{xx,y1,zz},uv,.82)
        z=zz
      end
      x=xx
    end
  end
  return box,function() return count end
end

local function texelUV(x,y,w,h)
  local p={(x+.5)/w,(y+.5)/h}
  return {p,p,p,p}
end

local function modelMaterial(sp,pr,w,h)
  -- A middle shade from this exact sprite retains roofs/furniture palettes.
  local i=pr.shadeTexel and (pr.shadeTexel[2] or pr.shadeTexel[1])
  if i and sp.ax[i] and sp.ay[i] then return texelUV(sp.ax[i],sp.ay[i],w,h) end
end

function M.decorateModel(quads,t,sp,pr,atlasW,atlasH)
  if not t or t.claimOnly or not sp or not pr or #quads==0 then return 0 end
  local uv=modelMaterial(sp,pr,atlasW,atlasH)
  if not uv then return 0 end
  local box,count=writer(quads,M.MODEL_QUAD_LIMIT)
  local width,depth=sp.W,pr.D
  local pagoda=t.id and t.id:match('^johto_pagoda')
  if pagoda and (t.roofRows or 0)>0 and width>=32 and depth>=16 and pr.top then
    -- A darker texel from this exact tower supplies the relief.  The prior
    -- pass laid one coplanar quad on the roof: it z-fought into the native
    -- surface and vanished at gameplay distance.  These shallow ribs rise
    -- above the measured slope and expose a top plus both side faces, while
    -- still stopping before the next eight-pixel bay.  They therefore read
    -- as individual roof panels rather than two uninterrupted rails.
    local dark=pr.shadeTexel and (pr.shadeTexel[3] or pr.shadeTexel[2] or pr.shadeTexel[1])
    local detailUV=dark and sp.ax[dark] and texelUV(sp.ax[dark],sp.ay[dark],atlasW,atlasH) or uv
    local made=0
    local sourceWall=max(0,(pr.ground or sp.H)-(t.roofRows or 0))
    local sproutStretch=(t.id=='johto_pagoda_crystal' and sourceWall==48)and 12 or 0
    local tallLandmark=(t.id:match('^johto_pagoda_tall') and sourceWall>=96)and true or false
    local tierLandmark=sproutStretch>0 or tallLandmark
    local visualWall=tallLandmark and sourceWall+floor(sourceWall/16)*8
      or sourceWall+sproutStretch
    local roofShift=visualWall-sourceWall
    local function detail(a,b,c,d,shade,tag,extraTag)
      if made>=M.MODEL_QUAD_LIMIT then return false end
      local q={a,b,c,d,uv=detailUV,shade=shade,own=true}
      q[tag]=true;if extraTag then q[extraTag]=true end
      quads[#quads+1]=q;made=made+1;return true
    end
    local ribStep=tierLandmark and 16 or 8
    for x=8,width-9,ribStep do
      local y=(pr.ytop-pr.top[x])+roofShift+.18
      for z=1,depth-2,8 do
        local z1=min(depth-1,z+6.5)
        if not detail({x-.34,y+.62,z},{x+.34,y+.62,z},{x+.34,y+.62,z1},{x-.34,y+.62,z1},.92,'gen2RoofPanel')then break end
        detail({x-.34,y,z1},{x-.34,y,z},{x-.34,y+.62,z},{x-.34,y+.62,z1},.68,'gen2RoofPanel')
        detail({x+.34,y,z},{x+.34,y,z1},{x+.34,y+.62,z1},{x+.34,y+.62,z},.82,'gen2RoofPanel')
      end
    end
    -- The facade already paints each tier, but a painted stripe does not
    -- continue around a voxel tower.  Wrap a shallow, segmented eave around
    -- the front and both flanks at every authored sixteen-pixel storey.  The
    -- strips sit outside the native shell, preserve doors/collision, and are
    -- cut on the world lattice so curvature cannot tear them into long bars.
    local wall=visualWall
    local storeyStep=tallLandmark and 24 or tierLandmark and 20 or 16
    for y=storeyStep,wall-1,storeyStep do
      local bandTier=floor(y/storeyStep)-1
      local inset=tierLandmark and (tallLandmark and floor(bandTier/2)or bandTier)*4 or 0
      local projection=tierLandmark and 3.1 or .34
      for x=inset,width-inset-1,8 do
        local x1=min(width-inset,x+7.35)
        local a,b,c,d
        if tierLandmark then
          a={x,y+1.05,depth-.16};b={x1,y+1.05,depth-.16}
          c={x1,y-.82,depth+projection};d={x,y-.82,depth+projection}
        else
          local z=depth+projection
          a={x,y-.55,z};b={x1,y-.55,z};c={x1,y+.55,z};d={x,y+.55,z}
        end
        if not detail(a,b,c,d,.78,'gen2StoreyBand',tierLandmark and 'gen2TierRoof' or nil)then break end
      end
      for z=0,depth-1,8 do
        local z1=min(depth,z+7.35)
        local left=inset-projection;local right=width-inset+projection
        local la,lb,lc,ld,ra,rb,rc,rd
        if tierLandmark then
          la={inset+.16,y+1.05,z};lb={inset+.16,y+1.05,z1};lc={left,y-.82,z1};ld={left,y-.82,z}
          ra={width-inset-.16,y+1.05,z1};rb={width-inset-.16,y+1.05,z};rc={right,y-.82,z};rd={right,y-.82,z1}
        else
          la={left,y-.55,z};lb={left,y-.55,z1};lc={left,y+.55,z1};ld={left,y+.55,z}
          ra={right,y-.55,z1};rb={right,y-.55,z};rc={right,y+.55,z};rd={right,y+.55,z1}
        end
        if not detail(la,lb,lc,ld,.72,'gen2StoreyBand',tierLandmark and 'gen2TierRoof' or nil)then break end
        detail(ra,rb,rc,rd,.82,'gen2StoreyBand',tierLandmark and 'gen2TierRoof' or nil)
      end
    end
    local total=made+count()
    quads.architectureDetailQuads=total
    return total
  elseif (t.roofRows or 0)>0 and width>=16 and depth>=8 and not t.topRows then
    -- A raised ridge only belongs on an authored pitched silhouette; flat
    -- department-store/industrial roofs retain their existing silhouette.
    local mid=floor(width/2)
    local top=pr.top
    if top and top[mid] and top[1] and top[width-2]
        and top[mid]+2 < max(top[1],top[width-2]) then
      local y=pr.ytop-top[mid]+1
      box(mid-.8,y-.1,0,mid+.8,y+.9,depth,uv)
    end
    -- The little universal corner posts/foundation caps added geometry to
    -- every pitched building without helping its authored silhouette.  The
    -- roof ridge above is retained; those generic supports are omitted.
  elseif t.desk then
    -- The desk's own fascia identifies its usable edge. In particular, never
    -- put trim at the bounding box of a monitor standing on that desk.
    local d=t.desk
    if d.fascia and d.base then
      local x0=d.x and d.x[1] or 0
      local x1=d.x and d.x[2]+1 or width
      local y=(d.base[2]-d.base[1]+1)+(d.fascia[2]-d.fascia[1]+1)
      local z=(d.z or 0)+(d.depthPx or (d.depth and d.depth*8) or depth)
      if y>0 then box(x0,y-.35,z-.25,x1,y+.25,z+.3,uv) end
    end
  end
  local n=count()
  quads.architectureDetailQuads=n
  return n
end

local function tileMaterial(data,tile,perRow,w,h)
  if not data or type(tile)~="number" or tile<0 then return end
  local ox,oy=(tile%perRow)*8,floor(tile/perRow)*8
  if ox+8>w or oy+8>h then return end
  local best,dist=nil,math.huge
  -- Choose a midtone from the object's own authored tile, avoiding black
  -- outlines and white voids when a real material color is available.
  for y=1,6 do for x=1,6 do
    local r,g,b,a=data:getPixel(ox+x,oy+y)
    if a>.5 then
      local l=.2126*r+.7152*g+.0722*b
      local delta=math.abs(l-.48)
      if delta<dist then dist=delta;best={ox+x,oy+y} end
    end
  end end
  if best then return texelUV(best[1],best[2],w,h) end
end

function M.decorateRoom(S,map,data,perRow)
  if S.outdoor or not data or S.architectureDetailQuads then return 0 end
  local w,h=data:getDimensions()
  local materials={}
  local box,count=writer(S.objectQuads,M.ROOM_QUAD_LIMIT)
  for z=0,map.def.height*4-1 do
    for x=0,map.def.width*4-1 do
      local k=key(x,z)
      local s=S.shapeAt[k]
      if s and not S.skip[k] and not s.flat and (s.h or 0)>=4 then
        local furniture=s.class=="counter" or s.class=="table" or s.class=="desk"
        local wall=s.class=="wall" or s.class=="shell"
        local nextShape=S.shapeAt[key(x,z+1)]
        -- Only the room-facing edge: no floating bands within joined solids,
        -- no geometry across a door, and no new furniture classification.
        if (furniture or wall) and nextShape and nextShape.flat then
          local tile=S.tileAt[k]
          local uv=materials[tile]
          if uv==nil and tile~=nil then
            uv=tileMaterial(data,tile,perRow or 16,w,h) or false
            materials[tile]=uv
          end
          if uv then
            local run=S.runs and S.runs[k]
            local y=run and run.h or s.h
            local xx,zz=x*8,(z+1)*8
            if wall then
              box(xx,.25,zz-.15,xx+8,1.1,zz+.2,uv)
              if y>=12 then box(xx,y*.42,zz-.15,xx+8,y*.42+.7,zz+.2,uv) end
            else
              box(xx,y-.6,zz-.2,xx+8,y+.15,zz+.3,uv)
            end
          end
        end
      end
      if count()>=M.ROOM_QUAD_LIMIT-6 then break end
    end
    if count()>=M.ROOM_QUAD_LIMIT-6 then break end
  end
  S.architectureDetailQuads=count()
  return count()
end

-- Shared by the finite furniture builder; these allocate no retained state.
M.geometryWriter=writer
M.texelUV=texelUV
return M
