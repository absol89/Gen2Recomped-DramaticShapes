-- Real bookshelves matched from Crystal's complete source drawings. The
-- generic bookcase class also means appliances and must never select these.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_MAP_QUADS=2400,MAX_MODELS=24}
local floor,min=math.floor,math.min
local layouts={
  TilesetPlayersRoom={{{5,6},{21,22},{37,38},{53,54}}},
  TilesetLab={{{5,7},{3,4},{3,4},{19,20}},{{5,7},{3,4},{3,4},{53,54}}},
  TilesetHouse={{{50,51},{14,15},{14,15},{30,31}},
    {{50,51},{48,49},{14,15},{60,59}}},
  TilesetRadioTower={{{48,49},{26,27},{26,27},{10,11}}},
  -- Department-store display shelving. These complete four-row motifs are
  -- product/book racks; the shared Mart tileset's other bookcase-class art
  -- includes counters and machines and remains deliberately untouched.
  TilesetMart={{{0x22,0x23},{0x32,0x33},{0x24,0x25},{0x34,0x35}},
    {{0x26,0x27},{0x36,0x37},{0x28,0x29},{0x38,0x39}}},
}
local function key(x,z)return(z+64)*4096+x+64 end
local function model(rows,x,z,data,perRow,w,h,allBooks,openFeet,mart)
  local out={}
  -- Emit only exterior cuboid surfaces; lattice subdivision must not create
  -- internal caps. Omit faces sealed by another panel or the supporting shelf.
  local function box(x0,y0,z0,x1,y1,z1,tex,omit)
    omit=omit or {}
    local function q(a,b,c,d,shade)
      out[#out+1]={a,b,c,d,uv=tex,shade=shade,own=true}
    end
    local x=x0
    while x<x1 do
      local xx=min(x1,(floor(x/8)+1)*8)
      if not omit.front then q({x,y0,z1},{xx,y0,z1},{xx,y1,z1},{x,y1,z1},.88)end
      if not omit.back then q({xx,y0,z0},{x,y0,z0},{x,y1,z0},{xx,y1,z0},.68)end
      if not omit.top or not omit.bottom then
        local z=z0
        while z<z1 do
          local zz=min(z1,(floor(z/8)+1)*8)
          if not omit.top then q({x,y1,z},{xx,y1,z},{xx,y1,zz},{x,y1,zz},1)end
          if not omit.bottom then q({x,y0,zz},{xx,y0,zz},{xx,y0,z},{x,y0,z},.56)end
          z=zz
        end
      end
      x=xx
    end
    local z=z0
    while z<z1 do
      local zz=min(z1,(floor(z/8)+1)*8)
      if not omit.left then q({x0,y0,z},{x0,y0,zz},{x0,y1,zz},{x0,y1,z},.76)end
      if not omit.right then q({x1,y0,zz},{x1,y0,z},{x1,y1,z},{x1,y1,zz},.82)end
      z=zz
    end
  end
  local mx,front=x*8,(z+4)*8;local back=front-10
  local function source(sx,sy)
    local tile=rows[floor(sy/8)+1][floor(sx/8)+1]
    return (tile%perRow)*8+sx%8,floor(tile/perRow)*8+sy%8
  end
  local function sample(sx,sy)
    local u,v=source(sx,sy);return G.texelUV(u,v,w,h)
  end
  local wood,dark=sample(1,15),sample(2,9)
  local base=openFeet and 5 or 0
  box(mx,base,back,mx+1,24,front,wood,{top=true,bottom=true})
  box(mx+15,base,back,mx+16,24,front,wood,{top=true,bottom=true})
  box(mx+1,base,back,mx+15,24,back+.7,dark,{left=true,right=true,top=true,bottom=true})
  for _,y in ipairs(openFeet and {5,8,16,23} or {0,8,16,23})do
    box(mx+1,y,back+.7,mx+15,y+1,front,wood,
      {left=true,right=true,back=true,top=y==23,bottom=y==0 or (y==8 and not allBooks)})
  end
  local function art(sx0,sy0,sx1,sy1,px,py,pz)
    local sy=sy0
    while sy<sy1 do
      local ey=min(sy1,(floor(sy/8)+1)*8)
      local sx=sx0
      while sx<sx1 do
        local ex=min(sx1,(floor(sx/8)+1)*8)
        local u,v=source(sx,sy)
        local left,right=px+sx-sx0,px+ex-sx0
        local top,bottom=py-(sy-sy0),py-(ey-sy0)
        out[#out+1]={{left,bottom,pz},{right,bottom,pz},{right,top,pz},{left,top,pz},
          uv={{(u+.03)/w,(v+ey-sy-.03)/h},{(u+ex-sx-.03)/w,(v+ey-sy-.03)/h},
            {(u+ex-sx-.03)/w,(v+.03)/h},{(u+.03)/w,(v+.03)/h}},shade=.96,own=true}
        sx=ex
      end
      sy=ey
    end
  end
  local bookCount=0
  for _,band in ipairs(allBooks and {8,16,24} or {8,16})do
    local base=24-band+1
    -- Binding outlines are vertical dark runs. Gaps between them retain the
    -- original book widths; their spine pixels become actual recessed faces.
    local breaks={2}
    for sx=3,12 do
      local ink=0
      for sy=band+2,band+5 do
        local u,v=source(sx,sy);local r,g,b,a=data:getPixel(u,v)
        if a>.5 and (r+g+b)/3<.23 then ink=ink+1 end
      end
      if ink>=3 then breaks[#breaks+1]=sx end
    end
    breaks[#breaks+1]=13
    for i=1,#breaks-1 do
      local a,b=breaks[i]+1,breaks[i+1]
      if b>a then
        local bh=4+((a+band)%2)*.5
        local depth=5+(a%2)*.4
        local mat=sample(a,band+3)
        box(mx+a,base,back+1,mx+b-.12,base+bh,back+1+depth,mat,{bottom=true,back=true})
        art(a,band+2,b,band+6,mx+a,base+4,back+1+depth+.02)
        bookCount=bookCount+1
      end
    end
  end
  if openFeet then
    -- House3C/3B is a shaped plinth with floor between its feet, not a
    -- third book row or cupboard face. Preserve that actual open silhouette.
    for _,dx in ipairs({0,14})do for _,dz in ipairs({back,front-2})do
      box(mx+dx,0,dz,mx+dx+2,5,dz+2,wood,{top=true})
    end end
    box(mx+1,6,front-1,mx+15,8,front,wood,{left=true,right=true,back=true,top=true})
  elseif not allBooks then
    -- Native lower cupboard/closed-storage artwork remains a front face,
    -- below the shelves, rather than being printed across the cabinet lid.
    box(mx+1,1,back+.7,mx+15,8,front-1,wood,{left=true,right=true,back=true,top=true,bottom=true})
    -- Bottom source pixels depict the sprite's patterned background, not
    -- cupboard joinery. Let the plain wooden base show below the door art.
    art(1,24,15,30,mx+1,8,front-.98)
  end
  -- Only the original top band's pixels cover the horizontal lid.
  for c=1,2 do
    local tile=rows[1][c];local u,v=(tile%perRow)*8,floor(tile/perRow)*8
    for part=0,1 do
      local z0,z1=back+part*5,back+(part+1)*5
      local v0,v1=v+part*4,v+(part+1)*4
      out[#out+1]={{mx+(c-1)*8,24.015,z0},{mx+c*8,24.015,z0},
        {mx+c*8,24.015,z1},{mx+(c-1)*8,24.015,z1},
        uv={{(u+.03)/w,(v0+.03)/h},{(u+7.97)/w,(v0+.03)/h},
          {(u+7.97)/w,(v1-.03)/h},{(u+.03)/w,(v1-.03)/h}},shade=.95,own=true}
    end
  end
  if mart then
    -- Store racks are commonly seen end-on. Add source-colored edge rails
    -- and shelf-height ribs so their sides read as framed displays instead
    -- of the bland solid rectangles the native volume produced.
    for _,xx in ipairs({mx-.18,mx+15.82})do
      for _,yy in ipairs({7.5,15.5})do box(xx,yy,back+1,xx+.36,yy+1,front-1,dark)end
      box(xx,3,back+1,xx+.36,22,back+2,wood)
      box(xx,3,front-2,xx+.36,22,front-1,wood)
    end
  end
  return out,bookCount
end

function M.build(S,map,data,perRow)
  if S.outdoor or S.shelfVisuals or not data or not map.tileset then return 0 end
  local list=layouts[map.tileset.id]
  if not list then return 0 end
  perRow=perRow or 16
  local w,h=data:getDimensions();local added,models,books=0,0,0
  for _,rows in ipairs(list)do
    for z=0,map.def.height*4-4 do for x=0,map.def.width*4-2 do
      local cells={};local matches=true
      for r,row in ipairs(rows)do for c,t in ipairs(row)do
        local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
        -- Native Lab profile calls the shared05/07 cap tiles "table".
        -- Accept that only in row1 of the complete verified Lab shelf,
        -- never as a generic table-to-bookshelf classification.
        local labCap=map.tileset.id=='TilesetLab' and r==1 and s and s.class=='table'
        if S.skip[k] or S.tileAt[k]~=t or not s or s.flat
            or (s.class~='wall' and s.class~='bookcase' and not labCap)
            or floor(t/perRow)*8+8>h then matches=false end
        cells[#cells+1]=k
      end end
      if matches and models<M.MAX_MODELS then
        -- Lab35/36 is a third row of books (Academy), whereas13/14 is
        -- closed storage (Elm). Preserve that exact source-art distinction.
        local thirdBooks=map.tileset.id=='TilesetRadioTower'
          or (map.tileset.id=='TilesetLab' and rows[4][1]==0x35 and rows[4][2]==0x36)
        local openFeet=map.tileset.id=='TilesetHouse' and rows[2][1]==0x30
          and rows[2][2]==0x31 and rows[4][1]==0x3C and rows[4][2]==0x3B
        local out,n=model(rows,x,z,data,perRow,w,h,thirdBooks,openFeet,map.tileset.id=='TilesetMart')
        if n>0 and added+#out<=M.MAX_MAP_QUADS then
          local shape={class='building',art='building',h=24,authored=true,flat=false}
          for _,k in ipairs(cells)do S.shapeAt[k]=shape;S.skip[k]=true;S.ground[k]=false end
          for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
          models=models+1;added=added+#out;books=books+n
        end
      end
    end end
  end
  S.shelfVisuals={models=models,books=books,quads=added}
  return added
end
return M
