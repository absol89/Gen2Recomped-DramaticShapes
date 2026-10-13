-- Cached presentation geometry. Call only for recognized tree/grass/flower
-- artwork; map collision, tree cutting, and encounter ownership stay native.
-- Texture coordinates point into the existing atlas, preserving time-of-day
-- palettes and flower animation. No images, meshes, or per-frame work live here.
local Nature = {}
local cache = setmetatable({}, { __mode = "k" })
local treeCache = setmetatable({}, { __mode = "k" })
local brownCache = setmetatable({}, { __mode = "k" })

-- A small authored family, selected per biome instead of manufacturing unique
-- geometry per placement.  All forms stay inside the native tree footprint and
-- reuse its atlas rows; only the silhouette and trunk proportions change.
local broadMaps = {
  NATIONAL_PARK=true, NATIONAL_PARK_BUG_CONTEST=true,
}
local evergreenMaps = {
  LAKE_OF_RAGE=true, ROUTE_43=true, ROUTE_44=true,
  ROUTE_45=true, ROUTE_46=true, SILVER_CAVE_OUTSIDE=true,
}
local clippedMaps = { GOLDENROD_CITY=true }

local function mapId(map)
  return map and (map.id or map.def and map.def.id)
end

function Nature.treeArchetype(map)
  local id,tsid=mapId(map),map and map.tileset and map.tileset.id
  if clippedMaps[id] then return "urban" end
  if broadMaps[id] then return "broad" end
  if evergreenMaps[id] then return "evergreen" end
  if tsid=="TilesetPark" or tsid=="TilesetKanto" then return "broad" end
  if tsid=="TilesetForest" then return "evergreen" end
  return "native"
end

-- Gen2's Kanto profile predates the tree_crown metadata: its two forest
-- drawings are cylinder-pinned alongside other, collision-inferred round
-- objects. Match the complete art cell, never the generic cylinder class.
local canonicalTrees = {
  TilesetKanto = { ["42:43:58:59"]=true, ["64:65:80:81"]=true },
  TilesetJohtoModern = { ["30:31:62:63"]=true },
  TilesetForest = { ["38:39:54:55"]=true },
  TilesetPark = { ["38:39:54:55"]=true },
}
local forestTiles = { [0x0C]=true,[0x0D]=true,[0x0E]=true,[0x0F]=true,
  [0x1C]=true,[0x1D]=true,[0x1E]=true,[0x1F]=true,
  [0x2C]=true,[0x2D]=true,[0x2E]=true,[0x2F]=true,
  [0x3C]=true,[0x3D]=true,[0x3E]=true,[0x3F]=true }
function Nature.treeCell(map,S,cx,cy)
  local tsid = map and map.tileset and map.tileset.id
  if not tsid or not S or not S.tileAt then return false end
  local ids, allForest = {}, tsid=="TilesetForest" or tsid=="TilesetPark"
  for dy=0,1 do for dx=0,1 do
    local id=S.tileAt[(cy*2+dy+64)*4096+cx*2+dx+64]
    if type(id)~="number" then return false end
    ids[#ids+1]=id
    allForest=allForest and forestTiles[id] or false
  end end
  local known=canonicalTrees[tsid]
  return allForest or (known and known[table.concat(ids,":")]) or false
end

local function bounds(quads)
  local b = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
  for _, q in ipairs(quads) do
    for i = 1, 4 do
      for a = 1, 3 do
        b[a], b[a + 3] = math.min(b[a], q[i][a]), math.max(b[a + 3], q[i][a])
      end
    end
  end
  return b
end

-- A single texel supplies a material rather than stretching the entire tree's
-- silhouette over every side. Candidates are from surfaces the native builder
-- already emitted, never the transparent/background portions of its atlas.
local function material(data, source, target, low, high)
  local w, h = data:getDimensions()
  local best, score
  for _, q in ipairs(source) do
    local y = (q[1][2] + q[2][2] + q[3][2] + q[4][2]) / 4
    if y >= low and y <= high and q.uv then
      local u, v = 0, 0
      for i = 1, 4 do u, v = u + q.uv[i][1] / 4, v + q.uv[i][2] / 4 end
      local x, z = math.floor(u * w), math.floor(v * h)
      if x >= 0 and x < w and z >= 0 and z < h then
        local r, g, b, a = data:getPixel(x, z)
        local light = (r + g + b) / 3
        if a > 0.5 and light > 0.10 and light < 0.94 then
          local d = math.abs(light - target)
          if not score or d < score then
            best, score = { (x + 0.5) / w, (z + 0.5) / h }, d
          end
        end
      end
    end
  end
  return best
end

-- Gen 2's source sheet is four-shade art: the brown is not present until the
-- tile's assigned GBC palette is baked by TerrainAtlas. Resolve candidate
-- texels through that exact palette table first, then fall back to scanning a
-- true-colour sheet (mods and the focused harness use those). The returned UV
-- still points into the native atlas, so this adds no texture or draw call.
local function brownMaterial(map,data)
  local set=map and map._battleArtGen2BgSet
  local slots=map and map.tileset and map.tileset.tilePalettes
  local cacheKey=(map and tostring(map.id) or "?").."|"..tostring(set or false)
  local perData=brownCache[data]
  if not perData then perData={};brownCache[data]=perData end
  local cached=perData[cacheKey]
  if cached~=nil then return cached or nil end
  local w,h=data:getDimensions()
  local best,score
  local GbcPalette
  if set and slots then
    local ok,module=pcall(require,"src.render.GbcPalette")
    if ok then GbcPalette=module end
  end
  local limit=w*h
  for pixel=0,limit-1 do
    local x,y=pixel%w,math.floor(pixel/w)
    local r,g,b,a=data:getPixel(x,y)
    local rr,gg,bb=r,g,b
    if GbcPalette then
      local tile=math.floor(x/8)+math.floor(y/8)*(map.tileset.tilesPerRow or 16)
      local palette=set[slots[tile+1] or 1]
      if palette then
        local shade=r>.83 and 1 or r>.5 and 2 or r>.17 and 3 or 4
        local col=GbcPalette.color(palette,shade)
        if col then
          rr,gg,bb=col[1],col[2],col[3]
          -- GbcPalette is byte-valued in the Gen 2 runtime; a few harnesses
          -- and ports expose the same contract normalized. Accept both.
          if math.max(rr,gg,bb)>1 then rr,gg,bb=rr/255,gg/255,bb/255 end
        end
      end
    end
    if a>.99 and rr>.12 and rr<.96 and gg>.05 and gg<.86 and bb<.50
        and rr>gg*1.02 and gg>bb*1.02 then
      -- Choose an ochre donor rather than a mid-brown one. The nighttime
      -- world tint brings this down to readable bark instead of near-black.
      local d=(rr-.68)^2+(gg-.43)^2+(bb-.16)^2
      if not score or d<score then
        score=d;best={(x+.5)/w,(y+.5)/h,rgb={rr,gg,bb}}
      end
    end
  end
  perData[cacheKey]=best or false
  return best
end

local function face(out, a, b, c, d, uv, shade)
  out[#out + 1] = { a, b, c, d, uv = { uv, uv, uv, uv }, shade = shade }
end

local function box(out, x0, y0, z0, x1, y1, z1, uv)
  face(out,{x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1},uv,1)
  face(out,{x1,y0,z0},{x0,y0,z0},{x0,y1,z0},{x1,y1,z0},uv,0.72)
  face(out,{x0,y0,z0},{x0,y0,z1},{x0,y1,z1},{x0,y1,z0},uv,0.78)
  face(out,{x1,y0,z1},{x1,y0,z0},{x1,y1,z0},{x1,y1,z1},uv,0.88)
  face(out,{x0,y1,z1},{x1,y1,z1},{x1,y1,z0},{x0,y1,z0},uv,0.95)
end

-- A tapered rectangular beam between two points in the horizontal plane.
-- Used sparingly for authored-looking boughs and roots; six quads are far
-- cheaper than voxelizing a new sprite volume and preserve a blocky GBC form.
local function beam(out,x0,y0,z0,x1,y1,z1,w0,w1,uv)
  local dx,dz=x1-x0,z1-z0
  local len=math.sqrt(dx*dx+dz*dz)
  if len<.001 then return end
  local nx,nz=-dz/len,dx/len
  local v0,v1=w0*.72,w1*.72
  local s1={x0+nx*w0,y0-v0,z0+nz*w0}
  local s2={x0-nx*w0,y0-v0,z0-nz*w0}
  local s3={x0-nx*w0,y0+v0,z0-nz*w0}
  local s4={x0+nx*w0,y0+v0,z0+nz*w0}
  local e1={x1+nx*w1,y1-v1,z1+nz*w1}
  local e2={x1-nx*w1,y1-v1,z1-nz*w1}
  local e3={x1-nx*w1,y1+v1,z1-nz*w1}
  local e4={x1+nx*w1,y1+v1,z1+nz*w1}
  face(out,s1,e1,e4,s4,uv,1)
  face(out,e2,s2,s3,e3,uv,.72)
  face(out,s4,e4,e3,s3,uv,.95)
  face(out,s2,e2,e1,s1,uv,.68)
  face(out,s2,s1,s4,s3,uv,.80)
  face(out,e1,e2,e3,e4,uv,.88)
end

local function remember(source, result)
  -- A simpler source object must never become more expensive in this pass.
  if #result > #source then return source end
  cache[source] = result
  result.gen2Nature = true
  return result
end

local function rememberedTree(source, archetype)
  local forms=treeCache[source]
  return forms and forms[archetype]
end

local function rememberTree(source, result, archetype)
  if #result > #source then result=source end
  local forms=treeCache[source]
  if not forms then forms={};treeCache[source]=forms end
  forms[archetype]=result
  if result~=source then result.gen2Nature=true end
  return result
end

-- Native front rows are often emitted as one quad per texel. For the park
-- trunk's side views, merge only horizontally adjacent fragments whose UVs
-- also meet in the original atlas. This keeps every fork/root pixel and its
-- stepped silhouette, but does not multiply tiny faces across 275 trees.
local function mergeRowParts(parts,w,h)
  local sorted={}
  for i,q in ipairs(parts)do sorted[i]=q end
  table.sort(sorted,function(a,b)return a[1][1]<b[1][1] end)
  local merged={}
  local function near(a,b,scale)return math.abs(a-b)*scale<.11 end
  for _,q in ipairs(sorted)do
    local last=merged[#merged]
    local join=last and last.uv and q.uv
      and math.abs(last[2][1]-q[1][1])<.001
      and math.abs(last[1][2]-q[1][2])<.001
      and math.abs((last.shade or 1)-(q.shade or 1))<.001
      and near(last.uv[2][1],q.uv[1][1],w)
      and near(last.uv[3][1],q.uv[4][1],w)
      and near(last.uv[2][2],q.uv[1][2],h)
      and near(last.uv[3][2],q.uv[4][2],h)
    if join then
      last[2],last[3]=q[2],q[3]
      last.uv[2],last.uv[3]=q.uv[2],q.uv[3]
    else
      merged[#merged+1]={{q[1][1],q[1][2],q[1][3]},
        {q[2][1],q[2][2],q[2][3]},
        {q[3][1],q[3][2],q[3][3]},
        {q[4][1],q[4][2],q[4][3]},
        uv={{q.uv[1][1],q.uv[1][2]},{q.uv[2][1],q.uv[2][2]},
          {q.uv[3][1],q.uv[3][2]},{q.uv[4][1],q.uv[4][2]}},
        shade=q.shade}
    end
  end
  return merged
end

-- The original FRONT is the model: each pixel row keeps its own width and
-- artwork. Repeat that elevation on four sides of a stepped square hull.
-- The native round hull's bulbous side silhouette and bright stretched side
-- ledges are deliberately not retained. No crop atlas or substitute crown.
function Nature.tree(map, data, source)
  local archetype=Nature.treeArchetype(map)
  local parkNative=archetype=="broad" and
    (mapId(map)=="NATIONAL_PARK" or mapId(map)=="NATIONAL_PARK_BUG_CONTEST")
  -- Lake deliberately keeps the shorter exposed trunk while Silver/route
  -- conifers lift their foliage clear of uneven corridor ground. They share
  -- an archetype but not an elevation template, so do not alias their cache.
  local cacheForm=parkNative and "broad_park_native"
    or archetype=="evergreen"
    and (mapId(map)=="LAKE_OF_RAGE" and "evergreen_lake" or "evergreen_raised")
    or archetype
  local cached=rememberedTree(source,cacheForm)
  if cached then return cached end
  if not data or #source < 16 then return source end
  local w,h=data:getDimensions()
  local b = bounds(source)
  local h = b[5] - b[2]
  if h < 8 or b[4] <= b[1] or b[6] <= b[3] then return source end
  local byY,rows={},{}
  for _,q in ipairs(source) do
    if q.uv and q[1][3]==q[2][3] and q[2][3]==q[3][3] then
      local x0,x1=math.min(q[1][1],q[2][1]),math.max(q[1][1],q[2][1])
      local y0,y1=math.min(q[1][2],q[3][2]),math.max(q[1][2],q[3][2])
      if x1>x0 and y1>y0 then
        if q[2][1]>q[1][1] and y0>=b[2]+2 then
          local row=byY[y0]
          if not row then row={y0=y0,y1=y1,x0=x0,x1=x1,parts={}};byY[y0]=row;rows[#rows+1]=row end
          row.x0=math.min(row.x0,x0);row.x1=math.max(row.x1,x1)
          row.parts[#row.parts+1]=q
        end
      end
    end
  end
  if #rows==0 then return source end
  table.sort(rows,function(a,b)return a.y0<b.y0 end)
  local cx,cz=(b[1]+b[4])/2,(b[3]+b[6])/2
  local nativeBark=material(data,source,0.22,b[2],b[2]+h*.25)
    or material(data,source,0.22,b[2],b[5])
  if not nativeBark then return source end
  -- Park's fork and roots already carry their own brown pixels. Sampling a
  -- generic brown elsewhere in the atlas and building a new trunk on top of
  -- that artwork changed its character and spent unnecessary geometry.
  local bark=parkNative and nativeBark or brownMaterial(map,data) or nativeBark
  local barkDark=not parkNative and
    (material(data,source,0.18,b[2],b[2]+h*.48) or nativeBark)
  -- Crown caps must sample the crown, never the bark donor. The latter made
  -- tier tops brown and turned their shallow undersides into long dark slabs
  -- behind a tree row. A mid-light texel from the upper art keeps the cap in
  -- the native leaf palette while retaining the stepped silhouette.
  local foliage=material(data,source,0.55,b[2]+h*.35,b[5]) or nativeBark
  local foliageDark=material(data,source,0.30,b[2]+h*.35,b[5]) or foliage
  local out,facades={},0
  local radiusLimit=math.min(b[4]-b[1],b[6]-b[3])/2
  -- Park's fork/root drawing is the authored trunk. Keep its exact row art
  -- on every face of the voxel hull; no substitute post or cartoon roots.
  local broadCrownY=b[2]+h*.48
  local evergreenLift=mapId(map)=="LAKE_OF_RAGE" and math.min(1.5,h*.06)
    or math.min(2.5,h*.10)
  local canopyLift=archetype=="broad" and 0
    or archetype=="evergreen" and evergreenLift
    or archetype=="urban" and math.min(2,h*.08) or 0
  local function formY(y)
    if canopyLift==0 then return y end
    return b[2]+canopyLift+(y-b[2])*(h-canopyLift)/h
  end
  for index,row in ipairs(rows)do
    row.r=math.min((row.x1-row.x0)/2,radiusLimit)
    local t=math.max(0,math.min(1,((row.y0+row.y1)*.5-b[2])/h))
    if archetype=="broad" then
      -- A park/city shade tree: a full middle crown with gently tucked top
      -- and underside, like the rounded National Park reference.
      row.r=math.min(radiusLimit,row.r*(.96+.12*math.sin(math.pi*t)))
    elseif archetype=="evergreen" then
      -- A compact conifer.  The overall taper supplies the triangle while a
      -- shallow three-row cadence breaks the outline into readable tiers.
      local tier=(index-1)%3==2 and .88 or 1
      row.r=row.r*(1-.30*t)*tier
    elseif archetype=="urban" then
      -- Goldenrod's clipped border trees: dense, controlled and a little
      -- narrower than the rural crown, without becoming a flat hedge wall.
      row.r=math.min(radiusLimit*.84,math.max(row.r*.90,radiusLimit*.68))
    end
    row.y0,row.y1=formY(row.y0),formY(row.y1)
    local center=(row.x0+row.x1)/2
    local scale=row.r/((row.x1-row.x0)/2)
    local sideParts=parkNative and row.y1<=broadCrownY
      and mergeRowParts(row.parts,w,h) or row.parts
    for turn=0,3 do
      for _,q in ipairs((turn==1 or turn==3) and sideParts or row.parts)do
        -- The darkest GBC green is not true black. A small lift preserves its
        -- branch/needle pattern under night tint instead of crushing it.
        local tone=archetype=="evergreen" and 1.04 or archetype=="urban" and .84 or 1
        local keep=not (archetype=="broad" and not parkNative
          and row.y1<=broadCrownY and (turn==1 or turn==3))
        if keep then
          -- Crown and original trunk art retain the native row silhouette
          -- from all four directions, including oblique approaches.
          local copy={uv=q.uv,shade=(q.shade or 1)*tone,gen2Facade=turn,
            gen2TreeArchetype=archetype}
          local rounded=parkNative and row.y0>=broadCrownY
          local corner=rounded and math.min(1.8,row.r*.13) or 0
          if rounded and q.uv then
            copy.uv={}
            for i=1,4 do
              local u,v=q.uv[i][1],q.uv[i][2]
              if math.abs(q[i][1]-row.x0)<.01 then u=u+.85/w end
              if math.abs(q[i][1]-row.x1)<.01 then u=u-.85/w end
              copy.uv[i]={u,v}
            end
          end
          if parkNative and row.y1<=broadCrownY then
            copy.gen2Trunk=true;copy.gen2NativeTrunkArt=true
          end
          for i=1,4 do
            local x,z=(q[i][1]-center)*scale,row.r
            if corner>0 then x=math.max(-row.r+corner,math.min(row.r-corner,x)) end
            for n=1,turn do x,z=z,-x end
            copy[i]={cx+x,formY(q[i][2]),cz+z}
          end
          out[#out+1]=copy;facades=facades+1
        end
      end
    end
    if parkNative and row.y0>=broadCrownY then
      local r,c=row.r,math.min(1.8,row.r*.13)
      for sx=-1,1,2 do for sz=-1,1,2 do
        local a={cx+sx*(r-c),row.y0,cz+sz*r}
        local b={cx+sx*r,row.y0,cz+sz*(r-c)}
        local d={cx+sx*(r-c),row.y1,cz+sz*r}
        local e={cx+sx*r,row.y1,cz+sz*(r-c)}
        face(out,a,b,e,d,foliage,.94)
        local mid=row.parts[math.floor(#row.parts/2)+1]
        if mid and mid.uv then
          out[#out].uv={{mid.uv[1][1],mid.uv[1][2]},
                        {mid.uv[2][1],mid.uv[2][2]},
                        {mid.uv[3][1],mid.uv[3][2]},
                        {mid.uv[4][1],mid.uv[4][2]}}
        end
        out[#out].gen2ParkCorner=true
      end end
    end
  end
  local function plate(x0,z0,x1,z1,y,up)
    if x1<=x0 or z1<=z0 then return end
    local a,b0,c,d={cx+x0,y,cz+z1},{cx+x1,y,cz+z1},{cx+x1,y,cz+z0},{cx+x0,y,cz+z0}
    if not up then a,b0,c,d=d,c,b0,a end
    face(out,a,b0,c,d,foliage,up and .84 or .62)
  end
  local function ring(outer,inner,y,up)
    if outer<=inner then return end
    if archetype~="native" then
      -- The authored biome forms are opaque crowns. One full tier plate is
      -- cheaper and visually denser than four donut strips at every radius
      -- change; the native form keeps its exact stepped cut faces.
      plate(-outer,-outer,outer,outer,y,up)
      return
    end
    if inner<=0 then plate(-outer,-outer,outer,outer,y,up);return end
    plate(-outer,-outer,outer,-inner,y,up)
    plate(-outer,inner,outer,outer,y,up)
    plate(-outer,-inner,-inner,inner,y,up)
    plate(inner,-inner,outer,inner,y,up)
  end
  local ringStart=1
  if archetype=="broad" then
    for i,row in ipairs(rows)do if row.y1>=broadCrownY then ringStart=i;break end end
  end
  ring(rows[ringStart].r,0,rows[ringStart].y0,false)
  for i=ringStart,#rows do
    local row=rows[i]
    local nextRow=rows[i+1]
    if not nextRow or nextRow.y0~=row.y1 then
      ring(row.r,0,row.y1,true)
      if nextRow then ring(nextRow.r,0,nextRow.y0,false) end
    elseif row.r>nextRow.r then ring(row.r,nextRow.r,row.y1,true)
    elseif nextRow.r>row.r then ring(nextRow.r,row.r,row.y1,false) end
  end
  local half=math.min(archetype=="broad" and 2.1 or archetype=="urban" and 1.25 or 1.5,
    rows[1].r*.5)
  local trunkStart=#out+1
  if archetype=="broad" and not parkNative then
    -- Preserve the established non-Park broad-tree model. This revision is
    -- deliberately scoped to National Park and its Bug Contest map.
    local coreHalf=math.min(2.05,radiusLimit*.25)
    local forkY=b[2]+h*.34
    box(out,cx-coreHalf,b[2]+.15,cz-coreHalf,
      cx+coreHalf,forkY+.55,cz+coreHalf,bark)
    local branchReach=math.min(4.0,radiusLimit*.40)
    local branchY=math.min(b[5]-.4,broadCrownY+math.min(1.7,h*.06))
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
      beam(out,cx,forkY,cz,cx+d[1]*branchReach,branchY,
        cz+d[2]*branchReach,coreHalf*.72,.72,bark)
    end
    local rootReach=math.min(4.3,radiusLimit*.44)
    local rootY=b[2]+math.min(.78,h*.035)
    for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}})do
      beam(out,cx,rootY,cz,cx+d[1]*rootReach,b[2]+.22,
        cz+d[2]*rootReach,coreHalf*.50,.52,bark)
    end
    local groove=math.min(.34,coreHalf*.17)
    local gy0,gy1=b[2]+h*.10,forkY-.28
    face(out,{cx-groove,gy0,cz+coreHalf+.01},{cx+groove,gy0,cz+coreHalf+.01},
      {cx+groove,gy1,cz+coreHalf+.01},{cx-groove,gy1,cz+coreHalf+.01},barkDark,.72)
    face(out,{cx+groove,gy0,cz-coreHalf-.01},{cx-groove,gy0,cz-coreHalf-.01},
      {cx-groove,gy1,cz-coreHalf-.01},{cx+groove,gy1,cz-coreHalf-.01},barkDark,.72)
    face(out,{cx-coreHalf-.01,gy0,cz-groove},{cx-coreHalf-.01,gy0,cz+groove},
      {cx-coreHalf-.01,gy1,cz+groove},{cx-coreHalf-.01,gy1,cz-groove},barkDark,.72)
    face(out,{cx+coreHalf+.01,gy0,cz+groove},{cx+coreHalf+.01,gy0,cz-groove},
      {cx+coreHalf+.01,gy1,cz-groove},{cx+coreHalf+.01,gy1,cz+groove},barkDark,.72)
    local knotY=b[2]+h*.24
    local kw,kh=coreHalf*.42,math.min(.62,h*.025)
    face(out,{cx-kw,knotY-kh,cz+coreHalf+.02},{cx+kw,knotY-kh,cz+coreHalf+.02},
      {cx+kw,knotY+kh,cz+coreHalf+.02},{cx-kw,knotY+kh,cz+coreHalf+.02},barkDark,.62)
    face(out,{cx+kw,knotY-kh,cz-coreHalf-.02},{cx-kw,knotY-kh,cz-coreHalf-.02},
      {cx-kw,knotY+kh,cz-coreHalf-.02},{cx+kw,knotY+kh,cz-coreHalf-.02},barkDark,.62)
    face(out,{cx-coreHalf-.02,knotY-kh,cz-kw},{cx-coreHalf-.02,knotY-kh,cz+kw},
      {cx-coreHalf-.02,knotY+kh,cz+kw},{cx-coreHalf-.02,knotY+kh,cz-kw},barkDark,.62)
    face(out,{cx+coreHalf+.02,knotY-kh,cz+kw},{cx+coreHalf+.02,knotY-kh,cz-kw},
      {cx+coreHalf+.02,knotY+kh,cz-kw},{cx+coreHalf+.02,knotY+kh,cz+kw},barkDark,.62)
  elseif archetype~="broad" then
    box(out,cx-half,b[2],cz-half,cx+half,rows[1].y0+.02,cz+half,bark)
  end
  local brown=bark~=nativeBark
  for i=trunkStart,#out do
    out[i].shade=(out[i].shade or 1)*(brown and .88 or .22)
    out[i].gen2Trunk=true
    out[i].gen2BrownTrunk=brown or nil
  end
  out.gen2NatureFourSides=facades
  out.gen2NatureTrunk=parkNative or trunkStart<=#out
  out.gen2NatureArchetype=archetype
  out.gen2NatureCanopyLift=canopyLift
  out.gen2NatureBrownTrunk=brown or false
  out.gen2NatureBarkUV={bark[1],bark[2]}
  out.gen2NatureBarkRGB=bark.rgb or false
  return rememberTree(source,out,cacheForm)
end

-- Three tapered, closed blades per 8px source tile (15 quads), deliberately
-- separated into clumps so the grass field has depth from every direction.
function Nature.grass(map, data, tileId, source)
  if cache[source] then return cache[source] end
  if not data or #source < 15 then return source end
  local b = bounds(source)
  local uv = material(data, source, 0.44, b[2], b[5])
  if not uv then return source end
  local out = {}
  local h = math.max(2, math.min(7, b[5]))
  local seeds = {{1.8,2.0,0.80},{5.8,3.1,1.0},{3.4,6.1,0.68}}
  for _, seed in ipairs(seeds) do
    local x, z, height = seed[1],seed[2],h*seed[3]
    local lean = (tileId % 3 - 1) * 0.4
    local a,b0,c,d = {x-0.7,0,z-0.45},{x+0.7,0,z-0.45},{x+0.7,0,z+0.45},{x-0.7,0,z+0.45}
    local tipA, tipB = {x+lean-0.12,height,z+0.2},{x+lean+0.12,height,z+0.2}
    face(out,d,c,tipB,tipA,uv,1)
    face(out,b0,a,tipA,tipB,uv,0.76)
    face(out,a,d,tipA,tipA,uv,0.82)
    face(out,c,b0,tipB,tipB,uv,0.90)
    face(out,a,b0,c,d,uv,0.7)
  end
  return remember(source,out)
end

-- Two crossed flower clumps using the entire native masked tile. Each plane
-- has its reverse face because scene culling can be enabled. The existing
-- TerrainAtlas animation changes these same UVs without rebuilding geometry.
function Nature.flower(map, data, tileId, source)
  if cache[source] then return cache[source] end
  if #source < 8 then return source end
  local ts = map.tileset
  -- TerrainAtlas alpha-keys only frame-animated flower slots. Static flower
  -- tiles keep opaque backgrounds and must retain the native cut geometry.
  local ok, specs = pcall(function()
    return require("src.render.TileRenderer").defaultAnimatedTiles(ts)
  end)
  local masked = false
  if ok and type(specs)=="table" then
    for _, spec in ipairs(specs) do
      if spec.kind=="frames" and spec.tile==tileId then masked=true; break end
    end
  end
  if not masked then return source end
  local perRow = ts.tilesPerRow or 16
  local w, h = ts.imageWidth or perRow*8, ts.imageHeight
  if data then w,h = data:getDimensions() end
  if not h then return source end
  local x,y = tileId % perRow * 8, math.floor(tileId/perRow)*8
  local uv = {{(x+0.02)/w,(y+7.98)/h},{(x+7.98)/w,(y+7.98)/h},
              {(x+7.98)/w,(y+0.02)/h},{(x+0.02)/w,(y+0.02)/h}}
  local out = {}
  local function panel(x0,z0,x1,z1,height)
    local q = {{x0,0,z0},{x1,0,z1},{x1,height,z1},{x0,height,z0},uv=uv,shade=1}
    out[#out+1]=q
    out[#out+1]={q[2],q[1],q[4],q[3],uv={uv[2],uv[1],uv[4],uv[3]},shade=0.88}
  end
  panel(0.3,1.0,4.8,4.3,5.5)
  panel(0.8,4.6,4.3,0.7,5.5)
  panel(3.0,3.5,7.7,6.8,6.5)
  panel(3.2,7.4,7.4,3.0,6.5)
  return remember(source,out)
end

function Nature.invalidate()
  cache = setmetatable({}, { __mode = "k" })
  treeCache = setmetatable({}, { __mode = "k" })
  brownCache = setmetatable({}, { __mode = "k" })
end

return Nature
