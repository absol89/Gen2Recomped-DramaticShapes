-- Crystal station geometry, derived from the train-station atlas signatures.
-- The Magnet Train uses a guideway, not a sleeper railway. Road crossings
-- must be authored against verified road art separately; none is invented here.
local Rail = {}
local stations = { GOLDENROD_MAGNET_TRAIN_STATION=true, SAFFRON_MAGNET_TRAIN_STATION=true }
local function key(x,y) return (y+64)*4096+x+64 end

function Rail.apply(S,map)
  local d,t=map and map.def,map and map.tileset
  if not (d and t and stations[map.id or d.id] and
      (d.tileset=='TILESET_TRAIN_STATION' or t.id=='TilesetTrainStation')) then return end
  if S._gen2StationVisuals then return S._gen2StationVisuals end
  local w,h=d.width*4,d.height*4
  local perRow=t.tilesPerRow or 16
  local aw,ah=t.imageWidth or perRow*8,t.imageHeight or 128
  local stats={guidewaySpans=0,barrierBays=0,platformEdges=0,quads=0}
  local first=#S.objectQuads
  local function tile(x,y)
    if x<0 or y<0 or x>=w or y>=h then return nil end
    return map:tileAt(x,y)
  end
  local function color(id,px,py)
    return {((id%perRow)*8+px+.5)/aw,(math.floor(id/perRow)*8+py+.5)/ah}
  end
  local metal=color(51,3,1)
  local dark=color(49,3,3)
  local mid=color(62,3,3)
  local function quad(a,b,c,d,uv,shade)
    S.objectQuads[#S.objectQuads+1]={a,b,c,d,u=uv[1],v=uv[2],shade=shade}
  end
  local function box(x0,y0,z0,x1,y1,z1,uv)
    -- Native world curvature and mesh-span culling operate at tile scale.
    -- Split visible faces on that lattice; never add internal box faces.
    local xa=x0
    while xa<x1 do
      local xb=math.min(x1,(math.floor(xa/8)+1)*8)
      local za=z0
      while za<z1 do
        local zb=math.min(z1,(math.floor(za/8)+1)*8)
        quad({xa,y1,za},{xb,y1,za},{xb,y1,zb},{xa,y1,zb},uv,1)
        za=zb
      end
      quad({xa,y0,z1},{xb,y0,z1},{xb,y1,z1},{xa,y1,z1},uv,.86)
      quad({xb,y0,z0},{xa,y0,z0},{xa,y1,z0},{xb,y1,z0},uv,.78)
      xa=xb
    end
    local za=z0
    while za<z1 do
      local zb=math.min(z1,(math.floor(za/8)+1)*8)
      quad({x0,y0,za},{x0,y0,zb},{x0,y1,zb},{x0,y1,za},uv,.72)
      quad({x1,y0,zb},{x1,y0,za},{x1,y1,za},{x1,y1,zb},uv,.90)
      za=zb
    end
  end
  local function claim(x,y,ground)
    local k=key(x,y)
    S.skip[k]=true
    S.ground[k]=ground
    -- Claimed cells must also bypass Structures' later region flood and
    -- profile passes, which inspect shapeAt rather than skip.
    S.shapeAt[k]={art='ground',class='ground',h=0,authored=true}
  end
  -- Exposed guideway is exactly two rows of tile17. The train's own artwork
  -- interrupts those rows and remains untouched, including boarding doors.
  for y=0,h-2 do
    local x=0
    while x<w do
      if tile(x,y)==17 and tile(x,y+1)==17 and tile(x,y-1)~=17 then
        local a=x
        repeat x=x+1 until tile(x,y)~=17 or tile(x,y+1)~=17
        local x0,x1,z=a*8,x*8,y*8
        box(x0,0,z+1,x1,1,z+15,dark)
        box(x0,1,z+3,x1,2.5,z+4.5,metal)
        box(x0,1,z+11.5,x1,2.5,z+13,metal)
        for tx=a,x-1 do claim(tx,y,49);claim(tx,y+1,49) end
        stats.guidewaySpans=stats.guidewaySpans+1
      else x=x+1 end
    end
  end
  -- Recognize fence only as its complete two-tile vertical signature. Each
  -- open bay gets narrow posts and two rails, never a solid walkway wall.
  for y=0,h-2 do
    for x=0,w-1 do
      if tile(x,y)==8 and tile(x,y+1)==24 then
        local px,pz=x*8,(y+2)*8-3
        box(px+1,0,pz,px+3,14,pz+2,mid)
        box(px,10,pz,px+8,12,pz+2,metal)
        box(px,3,pz,px+8,5,pz+2,mid)
        claim(x,y,62);claim(x,y+1,62)
        stats.barrierBays=stats.barrierBays+1
      end
    end
  end
  -- The platform edge is the atlas's grey/white50/51 pair. A shallow curb
  -- adds depth without raising the walkable deck or altering movement.
  for y=0,h-1 do
    local x=0
    while x<w do
      if tile(x,y)==51 and (tile(x,y-1)==50 or tile(x,y-1)==62) then
        local a=x
        repeat x=x+1 until tile(x,y)~=51 or (tile(x,y-1)~=50 and tile(x,y-1)~=62)
        box(a*8,.05,y*8,x*8,.7,y*8+1,metal)
        stats.platformEdges=stats.platformEdges+1
      else x=x+1 end
    end
  end
  stats.quads=#S.objectQuads-first
  S._gen2StationVisuals=stats
  return stats
end
return Rail
