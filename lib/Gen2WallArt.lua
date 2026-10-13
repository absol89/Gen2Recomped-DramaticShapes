-- Correct only verified north-wall art grids (house picture/window and the
-- Earl's Academy chalkboard). Native
-- volume detection includes the two synthetic border rows in their height;
-- the extra 16px folds black outside-map pixels above the picture/window.
-- Keep shell runs, tile art, collision and furnishings unchanged.
local M={MAX_COLUMNS=256,MAX_MOUNTED_QUADS=24}
local floor=math.floor
local function key(x,z)return(z+64)*4096+x+64 end
local houseGrids={{{45,46},{61,62}},{{36,74},{52,44}}}
local academyGrids={{{45,46,46,46,46,47},{61,62,62,62,62,63}}}
local function finite(n)return type(n)=='number'and n==n and n>-math.huge and n<math.huge end
local function expected(r)
 return type(r)=='table'and r.north==-2 and r.front==1 and r.h==32
  and r.peak==32 and r.base==0 and r.rise==0 and r.extent==4
  and r.unit==4 and r.roofRows==0 and r.fromRepeat==false and r.door==false
end
function M.apply(S,map,data,perRow)
 local stats={correctedGrids=0,correctedCells=0,pixelReads=0,mountedGrids=0,mountedQuads=0,wallColumns={}}
 if not(S and map and map.def and map.tileset and data)or S.outdoor
  or not(S.shapeAt and S.tileAt and S.runs)
  or type(map.tileAt)~='function'or type(map.warpAtCell)~='function'
  or type(map.isWarpTileCell)~='function'or type(data.getPixel)~='function'
  or type(data.getDimensions)~='function'then return stats end
 local grids=map.tileset.id=='TilesetHouse'and houseGrids
  or(map.tileset.id=='TilesetLab'and(map.id or map.def.id)=='EARLS_POKEMON_ACADEMY'and academyGrids)
 if not grids or(map.def.connections and next(map.def.connections))then return stats end
 local tw,th=map.def.width,map.def.height
 if not finite(tw)or not finite(th)then return stats end
 tw,th=tw*4,th*4
 if tw<2 or th<2 or tw>M.MAX_COLUMNS or tw~=floor(tw)or th~=floor(th)then return stats end
 perRow=perRow or 16
 if not finite(perRow)or perRow<1 or perRow~=floor(perRow)then return stats end
 local ok,w,h=pcall(data.getDimensions,data)
 if not ok or not finite(w)or not finite(h)then return stats end
 local blanks={}
 local function black(tile)
  if not finite(tile)or tile<0 or tile~=floor(tile)then return false end
  if blanks[tile]~=nil then return blanks[tile]end
  local ox,oy=tile%perRow*8,floor(tile/perRow)*8
  if ox+8>w or oy+8>h then return false end
  local rr,gg,bb
  for y=0,7 do for x=0,7 do
   local valid,r,g,b,a=pcall(data.getPixel,data,ox+x,oy+y)
   stats.pixelReads=stats.pixelReads+1
   if not valid or not finite(r)or not finite(g)or not finite(b)or not finite(a)
    or a<.999 or r<0 or g<0 or b<0 or math.max(r,g,b)>.1
    or(rr and math.max(math.abs(r-rr),math.abs(g-gg),math.abs(b-bb))>1/255)then
    blanks[tile]=false;return false
   end
   if rr==nil then rr,gg,bb=r,g,b end
  end end
  blanks[tile]=true;return true
 end
 local function protected(x,z)
  local k=key(x,z);local r=S.runs[k]
  if(S.doorFold and S.doorFold[k])or(r and r.door)then return true end
  local cx,cy=floor(x/2),floor(z/2)
  for _,method in ipairs({'warpAtCell','isWarpTileCell'})do
   local called,hit=pcall(map[method],map,cx,cy)
   if not called or hit then return true end
  end
  for _,list in ipairs({map.def.warps or{},map.warps or{}})do
   for _,warp in ipairs(list)do if warp.x==cx and warp.y==cy then return true end end
  end
  return false
 end
 local function match(x,grid)
  local width=#grid[1]
  if x+width>tw then return end
  for xx=math.max(0,x-1),math.min(tw-1,x+width)do
   for z=0,2 do if protected(xx,z)then return end end
  end
  local runs={}
  for c=0,width-1 do
   local run=S.runs[key(x+c,0)]
   if not expected(run)then return end
   for z=-2,1 do
    local k=key(x+c,z);local s=S.shapeAt[k]
    if not s or s.authored or s.flat or s.art~='upright'
     or s.class~=(z<0 and'shell'or'wall')or S.runs[k]~=run
     or(S.skip and S.skip[k])or(S.doorFold and S.doorFold[k])then return end
    local called,tile=pcall(map.tileAt,map,x+c,z)
    if not called then return end
    if z<0 then if not black(tile)then return end
    elseif s.h~=16 or S.tileAt[k]~=grid[z+1][c+1]or tile~=grid[z+1][c+1]then return end
   end
   runs[c+1]=run
  end
  return runs
 end
 local function mountedAcademy(x,grid)
  if grids~=academyGrids or map.def.generation~=2 or type(S.objectQuads)~='table'
   or type(S.skip)~='table'or type(S.ground)~='table'or stats.mountedGrids>0 then return end
  -- The actual neighbouring undecorated lab wall uses tile52. Its material
  -- is sampled only after placement/class proof, never from the black border.
  local donor=false
  for _,xx in ipairs({x-1,x+#grid[1]})do for z=0,1 do
   local k=key(xx,z);local s=S.shapeAt[k]
   local valid,tile=pcall(map.tileAt,map,xx,z)
   if xx>=0 and xx<tw and valid and tile==52 and S.tileAt[k]==52
    and s and s.class=='wall'and s.art=='upright'and not s.flat
    and not s.authored and not S.skip[k]and not protected(xx,z)then donor=true end
  end end
  if not donor then return end
  local ox,oy=52%perRow*8,floor(52/perRow)*8
  if ox+8>w or oy+8>h then return end
  local brightness=-1
  for yy=0,7 do for xx=0,7 do
   local valid,r,g,b,a=pcall(data.getPixel,data,ox+xx,oy+yy)
   if not valid or not finite(r)or not finite(g)or not finite(b)or not finite(a)or a<.999 then return end
   local light=(r+g+b)/3
   if light>brightness then brightness=light end
  end end
  if brightness<.25 then return end
  -- Use a real nearby floor source, not the old green board art and not the
  -- early-build false sentinel (ground synthesis has already run by now).
  local votes={};local floorTile,best=nil,0
  local artTiles={[52]=true}
  for _,row in ipairs(grid)do for _,tile in ipairs(row)do artTiles[tile]=true end end
  for zz=2,math.min(5,th-1)do for xx=x,x+#grid[1]-1 do
   local k=key(xx,zz);local s=S.shapeAt[k];local tile=S.tileAt[k]
   local valid,source=pcall(map.tileAt,map,xx,zz)
   if s and s.class=='ground'and s.art=='flat'and s.flat==true and s.h==0
    and not S.skip[k]and not S.runs[k]and not protected(xx,zz)
    and valid and finite(tile)and tile==floor(tile)and tile>=0 and source==tile and not artTiles[tile]then
    votes[tile]=(votes[tile]or 0)+1
    if votes[tile]>best or(votes[tile]==best and tile<(floorTile or math.huge))then floorTile,best=tile,votes[tile]end
   end
  end end
  if not floorTile then return end
  local fx,fy=floorTile%perRow*8,floor(floorTile/perRow)*8
  if fx+8>w or fy+8>h then return end
  local floorLight=0
  for yy=0,7 do for xx=0,7 do
   local valid,r,g,b,a=pcall(data.getPixel,data,fx+xx,fy+yy)
   if not valid or not finite(r)or not finite(g)or not finite(b)or not finite(a)
    or r<0 or g<0 or b<0 or math.max(r,g,b)>1 or a<.999 or a>1 then return end
   floorLight=math.max(floorLight,r,g,b)
  end end
  if floorLight<.25 then return end
  local backing={{(ox+.02)/w,(oy+7.98)/h},{(ox+7.98)/w,(oy+7.98)/h},
   {(ox+7.98)/w,(oy+.02)/h},{(ox+.02)/w,(oy+.02)/h}};local out={}
  for c=0,#grid[1]-1 do for r=0,1 do
   local xx,yy=(x+c)*8,r*8
   out[#out+1]={{xx,yy,16},{xx+8,yy,16},{xx+8,yy+8,16},{xx,yy+8,16},
    uv=backing,shade=1,own=true,oneSided=true,roomRole='wall_art_backing'}
  end end
  for r,row in ipairs(grid)do for c,tile in ipairs(row)do
   local ax,ay=tile%perRow*8,floor(tile/perRow)*8
   if ax+8>w or ay+8>h then return end
   local xx,yy=(x+c-1)*8,18+(2-r)*8
   out[#out+1]={{xx,yy,16.15},{xx+8,yy,16.15},{xx+8,yy+8,16.15},{xx,yy+8,16.15},
    uv={{(ax+.025)/w,(ay+7.975)/h},{(ax+7.975)/w,(ay+7.975)/h},
     {(ax+7.975)/w,(ay+.025)/h},{(ax+.025)/w,(ay+.025)/h}},
    shade=1,own=true,oneSided=true,roomRole='mounted_chalkboard'}
  end end
  if #out>M.MAX_MOUNTED_QUADS then return end
  return out,floorTile
 end
 for x=0,tw-2 do
  for _,grid in ipairs(grids)do
   local runs=match(x,grid)
   if runs then
    local mounted,floorTile=mountedAcademy(x,grid)
    for c=0,#runs-1 do
     local clone={};for k,v in pairs(runs[c+1])do clone[k]=v end
     clone.north=0;clone.h=16;clone.peak=16;clone.extent=2;clone.unit=2
     for z=0,1 do S.runs[key(x+c,z)]=clone end
    end
    if mounted then
     for c=0,#runs-1 do
      stats.wallColumns[x+c]=16
      for z=0,1 do
       local k=key(x+c,z)
       S.skip[k]=true
       S.runs[k]=nil
       S.ground[k]=floorTile
       S.shapeAt[k]={class='building',art='building',h=16,authored=true,flat=false}
      end
     end
     for _,q in ipairs(mounted)do S.objectQuads[#S.objectQuads+1]=q end
     stats.mountedGrids=stats.mountedGrids+1;stats.mountedQuads=stats.mountedQuads+#mounted
    end
    stats.correctedGrids=stats.correctedGrids+1
    stats.correctedCells=stats.correctedCells+#runs*2
   end
  end
 end
 return stats
end
return M
