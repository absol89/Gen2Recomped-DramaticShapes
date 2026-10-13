-- Gen2 furniture shapes from authored tile classes, replacing only render
-- claims. ROM collision, warps, interactive objects and save data are untouched.
local V=...
local Geometry=V.require('Gen2ArchitectureVisuals')
local M={MAX_MAP_QUADS=1536,MAX_FIXTURES=48}
local floor,min,max=math.floor,math.min,math.max
local function key(x,z) return (z+64)*4096+x+64 end
local eligible={table=true,bed=true}

-- The original dining-table drawing includes a separate flat south shadow.
-- Remove that drawing only alongside its exact successfully rebuilt table.
local function diningShadow(S,map,bounds,data,perRow,w,h)
  if map.id~='PLAYERS_HOUSE_1F' or not map.tileset
      or map.tileset.id~='TilesetPlayersHouse' then return end
  local x,z,x1,z1=unpack(bounds)
  if x1-x~=3 or z1-z~=3 then return end
  local rows={{0x23,0x22,0x22,0x24},{0x25,0x15,0x15,0x35},
    {0x25,0x15,0x15,0x35},{0x33,0x32,0x32,0x34}}
  local warps=map.def.warps or {}
  if #warps>128 or next(map.def.connections or {})then return end
  local function safe(xx,zz)
    local k=key(xx,zz)
    if S.skip[k] or(S.doorFold and S.doorFold[k])then return false end
    for _,warp in ipairs(warps)do
      if type(warp.x)~='number'or type(warp.y)~='number'then return false end
      if floor(xx/2)==warp.x and floor(zz/2)==warp.y then return false end
    end
    return true
  end
  for r=1,4 do for c=1,4 do
    local xx,zz=x+c-1,z+r-1;local k=key(xx,zz);local s=S.shapeAt[k]
    if not safe(xx,zz)or S.tileAt[k]~=rows[r][c] or not s
        or s.class~='table'or not s.authored or s.h~=6 then return end
  end end
  local function ground(xx,zz,tile)
    local k=key(xx,zz);local s=S.shapeAt[k]
    return safe(xx,zz)and S.tileAt[k]==tile and s and s.class=='ground'
      and s.flat and s.h==0 and not(S.runs and S.runs[k])
  end
  if not ground(x,z-1,1)then return end
  local ox,oy=(1%perRow)*8,floor(1/perRow)*8
  if ox+8>w or oy+8>h then return end
  for yy=0,7 do for xx=0,7 do
    local r,g,b,a=data:getPixel(ox+xx,oy+yy)
    if type(a)~='number'or a<.999 or a>1 then return end
    for _,v in ipairs({r,g,b})do
      if type(v)~='number'or v~=v or v<0 or v>1 then return end
    end
  end end
  local strip={0x1C,0x40,0x40,0x1D};local keys={}
  for c=1,4 do
    if not ground(x+c-1,z1+1,strip[c])then return end
    keys[c]=key(x+c-1,z1+1)
  end
  return keys
end

local function uv(tile,perRow,w,h,x0,y0,x1,y1)
  local x,y=(tile%perRow)*8,floor(tile/perRow)*8
  local a,b,c,d=(x+(x0 or .05))/w,(y+(y0 or .05))/h,
    (x+(x1 or 7.95))/w,(y+(y1 or 7.95))/h
  return {{a,b},{c,b},{c,d},{a,d}}
end

local function material(data,tile,perRow,w,h)
  local x,y=(tile%perRow)*8,floor(tile/perRow)*8
  local chosen,dist=nil,math.huge
  for yy=1,6 do for xx=1,6 do
    local r,g,b,a=data:getPixel(x+xx,y+yy)
    local delta=math.abs((r+g+b)/3-.38)
    if a>.5 and delta<dist then chosen={x+xx,y+yy};dist=delta end
  end end
  if chosen then return Geometry.texelUV(chosen[1],chosen[2],w,h) end
end

local function top(out,x,y,z,texture)
  out[#out+1]={{x,y,z},{x+8,y,z},{x+8,y,z+8},{x,y,z+8},uv=texture,shade=.95,own=true}
end

local function claim(S,cells,height)
  local paint=nil
  for _,c in ipairs(cells) do
    for _,d in ipairs({{0,1},{1,0},{-1,0},{0,-1}}) do
      local k=key(c[1]+d[1],c[2]+d[2]);local s=S.shapeAt[k]
      if s and s.flat and s.class~='void' then paint=S.tileAt[k];break end
    end
    if paint then break end
  end
  local shape={class='building',art='building',h=height,authored=true,flat=false}
  for _,c in ipairs(cells) do
    local k=key(c[1],c[2])
    S.shapeAt[k]=shape;S.skip[k]=true;S.ground[k]=paint or false
  end
end

-- Crystal PlayersHouse's 02/03 over12/13 is a round upholstered stool:
-- source rows2..9 are its elliptical seat,11..13 its legs, with FLOOR in
-- the four corners. Never paste that entire drawing onto a square tabletop.
-- Like Astra's authored furniture parts, the seat and four supports occupy
-- separate volumes and take only material texels from their own source bands.
local function roundStool(S,x,z,data,perRow,w,h)
  local ids={{0x02,0x03},{0x12,0x13}};local cells={}
  for r=1,2 do for c=1,2 do
    local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
    if S.skip[k] or S.tileAt[k]~=ids[r][c] or not s or not s.authored
        or s.class~='stool' or s.h~=5 then return end
    cells[#cells+1]={x+c-1,z+r-1}
  end end
  local function donor(px,py)
    local tile=ids[floor(py/8)+1][floor(px/8)+1]
    return Geometry.texelUV((tile%perRow)*8+px%8,floor(tile/perRow)*8+py%8,w,h)
  end
  local materials={donor(4,4),donor(7,5),donor(4,11)}
  local function at(xx,y,zz)
    if xx<0 or xx>15 or zz<0 or zz>15 or y<0 or y>4 then return end
    if y==4 then
      local d=(xx-7.5)^2+(zz-7.5)^2
      if d<=36 then return d<=16 and 2 or 1 end
    elseif ((xx>=4 and xx<=5) or (xx>=10 and xx<=11))
        and ((zz>=4 and zz<=5) or (zz>=10 and zz<=11)) then return 3 end
  end
  local out={};local mx,mz=x*8,z*8
  local function face(a,b,c,d,t,shade)
    for _,p in ipairs({a,b,c,d})do p[1]=p[1]+mx;p[3]=p[3]+mz end
    out[#out+1]={a,b,c,d,uv=materials[t],shade=shade,own=true}
  end
  -- Merge constant-material exposed runs, split on the native tile lattice.
  for y=0,4 do for zz=0,15 do for _,dir in ipairs({-1,1})do
    local xx=0
    while xx<16 do
      local t=at(xx,y,zz)
      if t and not at(xx,y+dir,zz) then
        local n=1;while xx+n<16 and floor(xx/8)==floor((xx+n)/8)
          and at(xx+n,y,zz)==t and not at(xx+n,y+dir,zz) do n=n+1 end
        local yy=y+(dir==1 and 1 or 0)
        if dir==1 then face({xx,yy,zz},{xx+n,yy,zz},{xx+n,yy,zz+1},{xx,yy,zz+1},t,.96)
        else face({xx,yy,zz+1},{xx+n,yy,zz+1},{xx+n,yy,zz},{xx,yy,zz},t,.6) end
        xx=xx+n
      else xx=xx+1 end
    end
  end end end
  for y=0,4 do for zz=0,15 do for _,dir in ipairs({-1,1})do
    local xx=0
    while xx<16 do
      local t=at(xx,y,zz)
      if t and not at(xx,y,zz+dir) then
        local n=1;while xx+n<16 and floor(xx/8)==floor((xx+n)/8)
          and at(xx+n,y,zz)==t and not at(xx+n,y,zz+dir) do n=n+1 end
        local zf=zz+(dir==1 and 1 or 0)
        if dir==1 then face({xx,y,zf},{xx+n,y,zf},{xx+n,y+1,zf},{xx,y+1,zf},t,.94)
        else face({xx+n,y,zf},{xx,y,zf},{xx,y+1,zf},{xx+n,y+1,zf},t,.73) end
        xx=xx+n
      else xx=xx+1 end
    end
  end end end
  for y=0,4 do for xx=0,15 do for _,dir in ipairs({-1,1})do
    local zz=0
    while zz<16 do
      local t=at(xx,y,zz)
      if t and not at(xx+dir,y,zz) then
        local n=1;while zz+n<16 and floor(zz/8)==floor((zz+n)/8)
          and at(xx,y,zz+n)==t and not at(xx+dir,y,zz+n) do n=n+1 end
        local xf=xx+(dir==1 and 1 or 0)
        if dir==1 then face({xf,y,zz+n},{xf,y,zz},{xf,y+1,zz},{xf,y+1,zz+n},t,.83)
        else face({xf,y,zz},{xf,y,zz+n},{xf,y+1,zz+n},{xf,y+1,zz},t,.77) end
        zz=zz+n
      else zz=zz+1 end
    end
  end end end
  return out,cells
end

local function fixture(S,cells,class,bounds,data,perRow,w,h)
  local x0,z0,x1,z1=bounds[1]*8,bounds[2]*8,(bounds[3]+1)*8,(bounds[4]+1)*8
  local first=key(cells[1][1],cells[1][2])
  local height=S.shapeAt[first].h or (class=='bed' and 7 or 6)
  if height<3 or height>16 then return end
  local tex=material(data,S.tileAt[first],perRow,w,h)
  if not tex then return end
  local out={};local box=Geometry.geometryWriter(out,512)
  local inset=class=='stool' and 1.5 or .7
  -- Legs and inset aprons replace the solid floor-to-lid extrusion with a
  -- visible under-table cavity, while keeping its authored top elevation.
  local leg=class=='stool' and 1.4 or 1.7
  for _,x in ipairs({x0+inset,x1-inset-leg}) do
    for _,z in ipairs({z0+inset,z1-inset-leg}) do
      box(x,0,z,x+leg,height-1,z+leg,tex)
    end
  end
  if class=='bed' then
    box(x0+.5,2,z0+.5,x1-.5,height-1,z1-.5,tex)
    -- Low timber headboard/footboard, kept within the exact claimed tiles.
    box(x0+.2,1,z0+.5,x0+1.2,height+3,z1-.5,tex)
    box(x1-1.2,1,z0+.5,x1-.2,height+1,z1-.5,tex)
  else
    box(x0+.7,max(1,height-2.2),z0+.7,x1-.7,height-.9,z0+1.6,tex)
    box(x0+.7,max(1,height-2.2),z1-1.6,x1-.7,height-.9,z1-.7,tex)
    box(x0+.7,max(1,height-2.2),z0+1.6,x0+1.6,height-.9,z1-1.6,tex)
    box(x1-1.6,max(1,height-2.2),z0+1.6,x1-.7,height-.9,z1-1.6,tex)
  end
  box(x0,height-1,z0,x1,height,z1,tex)
  for _,c in ipairs(cells) do
    top(out,c[1]*8,height+.015,c[2]*8,uv(S.tileAt[key(c[1],c[2])],perRow,w,h))
  end
  return out,height
end

-- These are complete tile grids from the Crystal PlayersRoom authored
-- profile, not a collision-code guess shared across unrelated tilesets.
local electronics={
  {class='console',rows={{0x0B,0x0C},{0x1B,0x1C},{0x2B,0x2C}},tv=false},
  {class='billboard',rows={{0x3B,0x3C},{0x4B,0x4C},{0x5B,0x5C}},tv=true},
}
local function electronic(S,x,z,spec,data,perRow,w,h)
  local cells={}
  for r=1,3 do for c=1,2 do
    local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
    if S.skip[k] or S.tileAt[k]~=spec.rows[r][c] or not s
        or not s.authored or s.class~=spec.class then return end
    cells[#cells+1]={x+c-1,z+r-1}
  end end
  local tex=material(data,spec.rows[1][1],perRow,w,h)
  if not tex then return end
  local out={};local box=Geometry.geometryWriter(out,384)
  local xx,zz=x*8,z*8
  -- A desk on four legs with actual air underneath, plus a deep CRT case.
  for _,dx in ipairs({1,13}) do for _,dz in ipairs({9,21}) do
    box(xx+dx,0,zz+dz,xx+dx+2,5,zz+dz+2,tex)
  end end
  box(xx,5,zz+8,xx+16,6,zz+24,tex)
  local screenBottom=spec.tv and 10 or 6
  if spec.tv then box(xx+5,6,zz+11,xx+11,10,zz+15,tex) end
  box(xx,screenBottom,zz+8,xx+16,screenBottom+16,zz+16,tex)
  -- Keep the upper two authored rows upright on the screen enclosure;
  -- keyboard/controls become a horizontal shelf rather than a second screen.
  for r=1,2 do for c=1,2 do
    local px=xx+(c-1)*8;local yy=screenBottom+(2-r)*8
    local t=uv(spec.rows[r][c],perRow,w,h)
    out[#out+1]={{px,yy,zz+16.015},{px+8,yy,zz+16.015},
      {px+8,yy+8,zz+16.015},{px,yy+8,zz+16.015},
      uv={t[4],t[3],t[2],t[1]},shade=1,own=true}
  end end
  for c=1,2 do
    top(out,xx+(c-1)*8,6.015,zz+16,uv(spec.rows[3][c],perRow,w,h))
  end
  return out,cells
end

function M.build(S,map,data,perRow)
  if S.outdoor or not data or S.furnitureVisuals then return 0 end
  perRow=perRow or 16
  local w,h=data:getDimensions()
  local seen,oversized={},{};local added,fixtures=0,0
  local tw,th=map.def.width*4,map.def.height*4
  local sourceStools=0
  if map.tileset and map.tileset.id=='TilesetPlayersHouse' then
    for z=0,th-2 do for x=0,tw-2 do
      if fixtures<M.MAX_FIXTURES and added<M.MAX_MAP_QUADS-256 then
        local out,cells=roundStool(S,x,z,data,perRow,w,h)
        if out and added+#out<=M.MAX_MAP_QUADS then
          claim(S,cells,5)
          for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
          added=added+#out;fixtures=fixtures+1;sourceStools=sourceStools+1
        end
      end
    end end
  end
  if map.tileset and map.tileset.id=='TilesetPlayersRoom' then
    for z=0,th-3 do for x=0,tw-2 do
      for _,spec in ipairs(electronics) do
        if fixtures<M.MAX_FIXTURES and added<M.MAX_MAP_QUADS-384 then
          local out,cells=electronic(S,x,z,spec,data,perRow,w,h)
          if out and added+#out<=M.MAX_MAP_QUADS then
            claim(S,cells,6)
            for _,q in ipairs(out) do S.objectQuads[#S.objectQuads+1]=q end
            fixtures=fixtures+1;added=added+#out
          end
        end
      end
    end end
  end
  for z=0,th-1 do for x=0,tw-1 do
    local k=key(x,z);local s=S.shapeAt[k]
    if s and eligible[s.class] and not oversized[s.class] and s.authored and not S.skip[k] and not seen[k] then
      local cells={{x,z}};seen[k]=true
      local at=1;local loX,hiX,loZ,hiZ=x,x,z,z
      while at<=#cells and #cells<=64 do
        local c=cells[at];at=at+1
        for _,d in ipairs({{0,1},{1,0},{-1,0},{0,-1}}) do
          local xx,zz=c[1]+d[1],c[2]+d[2];local kk=key(xx,zz)
          local ns=S.shapeAt[kk]
          if xx>=0 and xx<tw and zz>=0 and zz<th and not seen[kk] and not S.skip[kk]
              and ns and ns.authored and ns.class==s.class and ns.h==s.h then
            seen[kk]=true;cells[#cells+1]={xx,zz}
            loX=min(loX,xx);hiX=max(hiX,xx);loZ=min(loZ,zz);hiZ=max(hiZ,zz)
          end
        end
      end
      if #cells>64 then oversized[s.class]=true end
      -- Irregular kitchen counters and any large/ambiguous connected groups
      -- retain the native model. Only completely filled rectangles qualify.
      if #cells<=16 and #cells==(hiX-loX+1)*(hiZ-loZ+1)
          and hiX>loX and hiZ>loZ and hiX-loX<=7 and hiZ-loZ<=7
          and (s.class~='stool' or (#cells==4 and hiX-loX==1 and hiZ-loZ==1))
          and (s.class~='bed' or #cells<=8) then
        local valid=true
        for _,c in ipairs(cells) do
          local tile=S.tileAt[key(c[1],c[2])]
          if type(tile)~='number' or tile<0 or floor(tile/perRow)*8+8>h then valid=false end
        end
        if valid then
          local out,height=fixture(S,cells,s.class,{loX,loZ,hiX,hiZ},data,perRow,w,h)
          if out and added+#out<=M.MAX_MAP_QUADS then
            local shadow=diningShadow(S,map,{loX,loZ,hiX,hiZ},data,perRow,w,h)
            claim(S,cells,height)
            if shadow then for _,k in ipairs(shadow)do
              S.skip[k]=true;S.ground[k]=1
            end end
            for _,q in ipairs(out) do S.objectQuads[#S.objectQuads+1]=q end
            fixtures=fixtures+1;added=added+#out
          end
        end
      end
    end
    if fixtures>=M.MAX_FIXTURES or added>=M.MAX_MAP_QUADS-256 then break end
  end
  if fixtures>=M.MAX_FIXTURES or added>=M.MAX_MAP_QUADS-256 then break end
  end
  S.furnitureVisuals={fixtures=fixtures,quads=added,sourceStools=sourceStools}
  return added
end
return M
