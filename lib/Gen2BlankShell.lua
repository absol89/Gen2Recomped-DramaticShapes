-- Read-only proof of blank, already-rendered inward synthetic shell bands.
-- Native reference: ChunkMesher.runGeometry heightAt/sideQuad/band folding.
-- Crucially a volume samples map:tileAt, NOT Structures' synthetic S.tileAt.
local M={MAX_BOUNDARY_TILES=4096,MAX_BANDS=8192}
local floor,ceil,min,max=math.floor,math.ceil,math.min,math.max
local function key(x,z)return(z+64)*4096+x+64 end
local function number(v)return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function heightAt(S,x,z)
  local k=key(x,z)
  if S.skip and S.skip[k] then return 0 end
  local run=S.runs and S.runs[k]
  local s=S.shapeAt[k]
  local h=run and run.h or(s and s.h)or 0
  -- For ledges s.h is an upper bound on native per-cell shapeHeight (0/h).
  -- Using it can omit a band, never paint a hidden/not-emitted lower band.
  if not number(h) then return nil end
  return h
end
local function pixelsBlank(data,tile,perRow,w,h,vTop,vBot)
  if not number(tile)or tile<0 or tile~=floor(tile)then return nil end
  local ox,oy=(tile%perRow)*8,floor(tile/perRow)*8
  if ox<0 or oy<0 or ox+8>w or oy+8>h or vTop<0 or vBot>8 or vTop>=vBot then return nil end
  -- Sample every texel touched by the cropped native UV, not one representative
  -- color: even a single colored/transparent authored pixel protects the band.
  local reads=0
  local firstR,firstG,firstB
  for y=max(0,floor(vTop)),min(7,ceil(vBot)-1)do for x=0,7 do
    local ok,r,g,b,a=pcall(data.getPixel,data,ox+x,oy+y)
    reads=reads+1
    if not ok or not number(r)or not number(g)or not number(b)or not number(a)then return nil,reads end
    if a<.999 or r<0 or g<0 or b<0 or max(r,g,b)>.1 then return false,reads end
    if firstR then
      if max(math.abs(r-firstR),math.abs(g-firstG),math.abs(b-firstB))>1/255 then return false,reads end
    else firstR,firstG,firstB=r,g,b end
  end end
  return true,reads
end

function M.collect(S,map,data,perRow,ceiling)
  local stats={edges=0,eligible=0,protected=0,protectedBands=0,unknown=0,
    blankBands=0,artBands=0,faces=0,pixelReads=0,sampleCacheHits=0}
  local out={}
  local function reject(reason)stats.reason=reason;return{},stats end
  if not(S and S.shapeAt and S.tileAt and map and map.def and data and data.getPixel)
      or S.outdoor then return reject('missing indoor shell evidence')end
  if type(map.warpAtCell)~='function'or type(map.isWarpTileCell)~='function'then
    return reject('warp predicate evidence unavailable')end
  if not number(map.def.width)or not number(map.def.height)then return reject('map dimensions unavailable')end
  local tw,th=map.def.width*4,map.def.height*4
  perRow=perRow or(map.tileset and map.tileset.tilesPerRow)or 16
  ceiling=ceiling or 48
  if not number(tw)or not number(th)or tw<1 or th<1 or tw~=floor(tw)or th~=floor(th)
      or 2*(tw+th)>M.MAX_BOUNDARY_TILES or not number(perRow)or perRow<1
      or perRow~=floor(perRow)or not number(ceiling)or ceiling<=0 or ceiling>1024 then
    return reject('invalid or unbounded shell dimensions')
  end
  if map.def.connections and next(map.def.connections)then
    return reject('connected-map masking not proven')
  end
  local ok,w,h=pcall(data.getDimensions,data)
  if not ok or not number(w)or not number(h)then return reject('pixel dimensions unavailable')end
  local inspected=0
  local blankCache={}
  local function blankAt(tile,vTop,vBot)
    if not number(tile)or vTop<0 or vBot>8 or vTop>=vBot then return nil end
    local id=tostring(tile)..':'..floor(vTop)..':'..ceil(vBot)
    local cached=blankCache[id]
    if cached~=nil then stats.sampleCacheHits=stats.sampleCacheHits+1
      if cached=='unknown'then return nil end;return cached end
    local blank,reads=pixelsBlank(data,tile,perRow,w,h,vTop,vBot)
    stats.pixelReads=stats.pixelReads+(reads or 0)
    blankCache[id]=blank==nil and 'unknown'or blank
    return blank
  end
  local function doorAt(tx,tz)
    if tx<0 or tz<0 or tx>=tw or tz>=th then return false end
    local k=key(tx,tz);local run=S.runs and S.runs[k]
    -- Adjacent claimed furniture is not a doorway: native heightAt(skip)=0
    -- already draws this shell behind it, and the prop still depth-occludes it.
    if(S.doorFold and S.doorFold[k])or(run and run.door)then return true end
    local cx,cy=floor(tx/2),floor(tz/2)
    for _,method in ipairs({'warpAtCell','isWarpTileCell'})do
      if type(map[method])=='function'then
        local called,hit=pcall(map[method],map,cx,cy)
        if not called or hit then return true end
      end
    end
    for _,warp in ipairs(map.def.warps or map.warps or{})do
      if warp.x==cx and warp.y==cy then return true end
    end
    return false
  end
  local function edge(tx,tz,d,orientation,dx,dz)
    stats.edges=stats.edges+1
    local k=key(tx,tz);local s=S.shapeAt[k];local run=S.runs and S.runs[k]
    if not s or s.class~='shell' or s.authored or(S.skip and S.skip[k])
        or(S.doorFold and S.doorFold[k])or(run and run.door)then
      stats.protected=stats.protected+1;return
    end
    local ax,az=tx+dx,tz+dz
    local neighborShape=S.shapeAt[key(ax,az)]
    local neighborRun=S.runs and S.runs[key(ax,az)]
    if not run or(run.rise and run.rise~=0)
        or(neighborRun and neighborRun.rise and neighborRun.rise~=0)
        or(neighborShape and neighborShape.class=='ledge')then
      stats.unknown=stats.unknown+1;return
    end
    -- A warp cell spans two 8px columns. Sampling one adjacent tile to either
    -- side protects the full warp strip plus one tile of doorway margin.
    for offset=-1,1 do
      local px,pz=ax,az
      if dx==0 then px=px+offset else pz=pz+offset end
      if doorAt(px,pz)then stats.protected=stats.protected+1;return end
    end
    local top=heightAt(S,tx,tz);local neighbor=heightAt(S,ax,az)
    if not top or not neighbor or neighbor<0 or top<=neighbor or top<=0 then stats.unknown=stats.unknown+1;return end
    if run and(not number(run.front)or not number(run.north)
        or(run.base~=nil and not number(run.base)))then stats.unknown=stats.unknown+1;return end
    stats.eligible=stats.eligible+1
    local last
    for band=floor(neighbor/8),ceil(min(top,ceiling)/8)-1 do
      local y0=max(neighbor,band*8);local y1=min(top,ceiling,band*8+8)
      if y1>y0 then
        inspected=inspected+1
        if inspected>M.MAX_BANDS then return false end
        local src,sourceOutside
        if run then
          local bb=max(0,band-floor((run.base or 0)/8))
          local row=d==6 and min(run.front,run.north+bb)or max(run.north,run.front-bb)
          local called,tile=pcall(map.tileAt,map,tx,row)
          src=called and tile or nil
          sourceOutside=tx<0 or tx>=tw or row<0 or row>=th
        end
        -- A uniform dark authored tile is still artwork. Only prove a void
        -- border fallback when the ACTUAL mesher sample is outside the body.
        local blank=sourceOutside and blankAt(src,band*8+8-y1,band*8+8-y0)
        if blank then
          stats.blankBands=stats.blankBands+1
          if last and math.abs(last.top-y0)<.000001 then last.top=y1
          else last={x=tx,z=tz,orientation=orientation,y=y0,top=y1};out[#out+1]=last end
        else
          last=nil
          if not sourceOutside then stats.protectedBands=stats.protectedBands+1
          elseif blank==nil then stats.unknown=stats.unknown+1 else stats.artBands=stats.artBands+1 end
        end
      end
    end
    return true
  end
  for x=0,tw-1 do
    if edge(x,-1,5,'north',0,1)==false or edge(x,th,6,'south',0,-1)==false then
      return reject('shell band budget exceeded')end
  end
  for z=0,th-1 do
    if edge(-1,z,1,'west',1,0)==false or edge(tw,z,2,'east',-1,0)==false then
      return reject('shell band budget exceeded')end
  end
  stats.faces=#out
  return out,stats
end
return M
