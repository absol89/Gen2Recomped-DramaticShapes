-- Exact Crystal electronics drawings reconstructed as cases, recessed panels
-- and supports. No collision/script changes, runtime draws or new textures.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_MAP_QUADS=2048,MAX_FIXTURES=8,MAX_FIXTURE_QUADS=640}
local floor,min=math.floor,math.min
local function key(x,y)return (y+64)*4096+x+64 end
local specs={
 TilesetPlayersRoom={
  {id='bedroom_pc',class='console',kind='pc',rows={{11,12},{27,28},{43,44}}},
  {id='bedroom_tv',class='billboard',kind='tv',rows={{59,60},{75,76},{91,92}}},
  {id='bedroom_stereo_lamp',class='prop',kind='stereo',rows={{66,67},{82,83}}},
 },
 TilesetHouse={
  {id='house_tv',class='console',kind='tv',rows={{6,7},{22,23},{30,31}}},
  {id='house_radio',class='console',kind='radio',rows={{12,13},{28,29},{30,31}}},
 },
}

local function build(spec,data,row,w,h)
 local out={}
 -- Build into a private list and commit only complete, in-budget fixtures.
 local box=G.geometryWriter(out,4096)
 local function pos(px,py)
  local tile=spec.rows[floor(py/8)+1][floor(px/8)+1]
  return (tile%row)*8+px%8,floor(tile/row)*8+py%8
 end
 local function donor(x,y)local ax,ay=pos(x,y);return G.texelUV(ax,ay,w,h)end
 local function uv(x,y,n)
  local ax,ay=pos(x,y)
  return {{(ax+.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.95)/h},
   {(ax+n-.05)/w,(ay+.05)/h},{(ax+.05)/w,(ay+.05)/h}}
 end
 local function face(a,b,c,d,texture,shade)
  out[#out+1]={a,b,c,d,uv=texture,shade=shade or 1,own=true}
 end
 -- Pixel rows retain their exact UVs. Closed reveals connect the recessed
 -- screen/speaker and raised buttons to the surrounding bezel.
 local function panel(x0,x1,s0,s1,base,front,depth)
  local back=front-1.25
  local function at(x,y)
   if x<x0 or x>x1 or y<s0 or y>s1 then return back end
   return front+(depth and depth(x,y) or 0)
  end
  for sy=s0,s1 do
   local x=x0;local yy=base+s1-sy
   while x<=x1 do
    local z=at(x,sy);local n=1
    while x+n<=x1 and floor(x/8)==floor((x+n)/8) and at(x+n,sy)==z do n=n+1 end
    face({x,yy,z},{x+n,yy,z},{x+n,yy+1,z},{x,yy+1,z},uv(x,sy,n))
    x=x+n
   end
   for sx=x0,x1 do
    local z=at(sx,sy);local col=donor(sx,sy)
    local n=at(sx-1,sy)
    if z>n then face({sx,yy,n},{sx,yy,z},{sx,yy+1,z},{sx,yy+1,n},col,.76)end
    n=at(sx+1,sy)
    if z>n then face({sx+1,yy,z},{sx+1,yy,n},{sx+1,yy+1,n},{sx+1,yy+1,z},col,.84)end
    n=at(sx,sy-1)
    if z>n then face({sx,yy+1,n},{sx+1,yy+1,n},{sx+1,yy+1,z},{sx,yy+1,z},col,.95)end
    n=at(sx,sy+1)
    if z>n then face({sx,yy,z},{sx+1,yy,z},{sx+1,yy,n},{sx,yy,n},col,.65)end
   end
  end
 end
 local function desk(z0,z1)
  local tex=donor(3,spec.kind=='pc' and 15 or 13)
  for _,x in ipairs({1,13})do for _,z in ipairs({z0+1,z1-3})do
   box(x,0,z,x+2,5,z+2,tex)
  end end
  box(0,5,z0,16,6,z1,tex)
 end
 local function lid(x0,x1,s0,s1,y,z0)
  for sy=s0,s1 do
   local x=x0
   while x<=x1 do
    local n=min(x1-x+1,8-x%8);local u=uv(x,sy,n);local z=z0+sy-s0
    face({x,y,z},{x+n,y,z},{x+n,y,z+1},{x,y,z+1},{u[4],u[3],u[2],u[1]},.95)
    x=x+n
   end
  end
 end
 -- The case stays within its original 16px width. A shallow dark pocket
 -- and source-colored ribs replace blank end panels without painting a
 -- second screen on the sides. All ribs are real closed, bounded solids.
 local function sideVents(y0,y1,z0,z1,caseColor,dark)
  box(.12,y0,z0,.5,y1,z1,dark)
  box(15.5,y0,z0,15.88,y1,z1,dark)
  for y=y0,y1-.5,2 do
   box(0,y,z0,.5,y+.5,z1,caseColor)
   box(15.5,y,z0,16,y+.5,z1,caseColor)
  end
 end
 if spec.kind=='pc' then
  desk(8,24)
  box(2,6,9,14,17,15.75,donor(3,4))
  lid(2,13,0,3,17.015,9)
  panel(2,13,4,14,6,17,function(x,y)
   if x>=5 and x<=11 and y>=5 and y<=9 then return -.8 end
   if y==11 and x>=8 and x<=10 then return .25 end
   return 0
  end)
  -- Keyboard is a shallow horizontal object in front of the monitor,
  -- with its original key pattern, never a second upright screen.
  box(2,6,18,14,6.5,24,donor(3,18))
  for sy=16,21 do for sx=2,13 do
   local y,z=6.52,18+sy-16;local u=uv(sx,sy,1)
   face({sx,y,z},{sx+1,y,z},{sx+1,y,z+1},{sx,y,z+1},{u[4],u[3],u[2],u[1]},.95)
  end end
 elseif spec.kind=='tv' or spec.kind=='radio' then
  local wood=donor(3,18)
  if spec.kind=='tv' then
   -- The TV cabinet is joinery, not a solid box with the complete lower
   -- sprite stretched to the floor. Four inset feet support a bottom shelf,
   -- two structural sides and a back; the top overhangs that narrower body.
   local frame=donor(0,16)
   for _,x in ipairs({2,12})do for _,z in ipairs({10,17})do
    box(x,0,z,x+2,1.25,z+2,frame)
   end end
   box(1,1.25,9,15,2,20,frame)
   box(1,2,9,2,7,19.5,wood)
   box(14,2,9,15,7,19.5,wood)
   box(2,2,9,14,7,10,wood)
   box(0,7,8,16,8,21,donor(3,17))
   if spec.id=='bedroom_tv' then
    -- The bedroom source has two distinct doors divided at x7/8.
    box(7,2,10,9,7,19.5,frame)
    panel(1,14,17,21,2,19.75,function(x)
     return ((x>=2 and x<=6)or(x>=9 and x<=13)) and -.75 or 0
    end)
   else
    -- Ordinary-house art has one framed storage/media panel. Do not invent
    -- the bedroom's paired doors on this different drawing.
    panel(1,14,17,21,2,19.75,function(x)
     return x>=3 and x<=12 and -.75 or 0
    end)
   end
   -- The patterned source bottom row is background, not cabinet fascia.
   -- Keep a plain wooden sill above the genuinely open foot clearance.
  else
   -- The existing radio cabinet is independent of the TV stand revision.
   box(1,1,9,15,8,18.75,wood)
   for _,x in ipairs({2,12})do for _,z in ipairs({10,17})do box(x,0,z,x+2,1,z+2,wood)end end
   panel(1,14,16,21,2,20)
  end
  local y0=8
  if spec.kind=='tv' then
   local caseColor=donor(2,4)
   box(.5,y0,8,15.5,18,14.75,caseColor)
   -- The original upper casing band becomes a complete stepped crown,
   -- not a truncated screen box with a thin printed strip on its top.
   box(0,18,8,16,18.5,16,caseColor)
   box(1,18.5,9,15,19.5,15,caseColor)
   lid(1,14,0,5,19.515,9)
   sideVents(10,16,10,14,caseColor,donor(0,6))
   panel(0,15,6,15,y0,16,function(x,y)
    if x>=3 and x<=12 and y>=7 and y<=12 then return -.8 end
    if y==14 and x>=11 and x<=12 then return .25 end
    return 0
   end)
  else
   local caseColor=donor(1,7)
   box(.5,y0,9,15.5,16,14.75,caseColor)
   box(0,16,9,16,16.5,16,caseColor)
   box(1,16.5,10,15,17.5,15,donor(3,5))
   lid(1,14,4,7,17.515,10)
   sideVents(9,15,10,14,donor(7,10),donor(0,7))
   panel(0,15,8,15,y0,16,function(x,y)
    if x>=2 and x<=6 and y>=8 and y<=12 then return -.45 end
    if x>=9 and x<=12 and y>=8 and y<=9 then return -.65 end
    if y==12 and (x==8 or x==10 or x==12)then return .3 end
    return 0
   end)
   -- The actual source aerial is at x12..14 above the radio, not a generic
   -- pair of invented TV antennas.
   box(12.5,16,10,13.5,21,11,donor(13,2))
  end
 else
  desk(0,16)
  box(0,6,3,16,13,10.75,donor(1,8))
  panel(0,15,8,14,6,12,function(x,y)
   if x>=2 and x<=5 and y>=9 and y<=12 then return -.45 end
   if x>=9 and x<=11 and y>=9 and y<=10 then return -.65 end
   if y==12 and (x==9 or x==11 or x==13)then return .3 end
   return 0
  end)
  -- Lamp arm follows the diagonal stroke in the upper source band. It is
  -- a stepped solid arm with depth, not a full opaque background rectangle.
  for sy=1,6 do
   local cx=13-2*sy
   for sx=math.max(0,cx),math.min(15,cx+2)do
    box(sx,19-sy,6,sx+1,20-sy,7,donor(sx,sy))
   end
  end
  box(12,12,6,14,19,8,donor(13,1))
 end
 return out
end

function M.build(S,map,data,perRow)
 if not(map and map.def and map.def.generation==2 and map.tileset and data)
    or S.outdoor or S.electronicsVisuals then return 0 end
 local list=specs[map.tileset.id]
 if not list then return 0 end
 local w,h=data:getDimensions();local tw,th=map.def.width*4,map.def.height*4
 local row=perRow or map.tileset.tilesPerRow or 16
 local report={fixtures=0,quads=0,models={}}
 for _,spec in ipairs(list)do
  for z=0,th-#spec.rows do for x=0,tw-2 do
   local cells={};local valid=true
   for r,tiles in ipairs(spec.rows)do for c,tile in ipairs(tiles)do
    local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
    if S.skip[k] or S.tileAt[k]~=tile or not s or not s.authored or s.class~=spec.class
       or (tile%row)*8+8>w or floor(tile/row)*8+8>h then valid=false end
    cells[#cells+1]={x+c-1,z+r-1,k}
   end end
   if valid and report.fixtures<M.MAX_FIXTURES then
    local quads=build(spec,data,row,w,h)
    if #quads<=M.MAX_FIXTURE_QUADS and report.quads+#quads<=M.MAX_MAP_QUADS then
     local ground
     for _,c in ipairs(cells)do
      for _,d in ipairs({{0,1},{1,0},{-1,0}})do
       local k=key(c[1]+d[1],c[2]+d[2]);local s=S.shapeAt[k]
       if s and s.flat and s.class=='ground' then ground=S.tileAt[k];break end
      end
      if ground then break end
     end
     for _,c in ipairs(cells)do
      S.skip[c[3]]=true;S.ground[c[3]]=ground or false
      S.shapeAt[c[3]]={class='building',art='building',authored=true,flat=false,h=6}
     end
     for _,q in ipairs(quads)do
      for i=1,4 do q[i][1]=q[i][1]+x*8;q[i][3]=q[i][3]+z*8 end
      S.objectQuads[#S.objectQuads+1]=q
     end
     report.fixtures=report.fixtures+1;report.quads=report.quads+#quads
     report.models[#report.models+1]={id=spec.id,x=x,z=z,quads=#quads}
    end
   end
  end end
 end
 S.electronicsVisuals=report
 return report.quads
end
return M
