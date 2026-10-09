local path = arg[1] or "lib/Gen2NatureVisuals.lua"
local Nature = assert(loadfile(path))()
local data = {}
function data:getDimensions() return 128,128 end
function data:getPixel(x,y) return 0.5,0.7,0.3,1 end
local map = {tileset={tilesPerRow=16,imageWidth=128,imageHeight=128}}
local function source(n)
  local out={}
  for i=1,n do
    out[i]={{-8,0,-8},{8,0,-8},{8,32,8},{-8,32,8},
      uv={{0.1,0.1},{0.12,0.1},{0.12,0.12},{0.1,0.12}},shade=1}
  end
  return out
end
local function validate(quads,x0,x1,y0,y1,z0,z1)
  for _,q in ipairs(quads) do
    assert(#q==4 and (q.uv and #q.uv==4 or q.u and q.v))
    for i=1,4 do
      local p=q[i]
      assert(p[1]>=x0 and p[1]<=x1,"x bounds")
      assert(p[2]>=y0 and p[2]<=y1,"y bounds")
      assert(p[3]>=z0 and p[3]<=z1,"z bounds")
      assert((q.uv and q.uv[i][1] or q.u)>0 and (q.uv and q.uv[i][1] or q.u)<1,"u atlas")
      assert((q.uv and q.uv[i][2] or q.v)>0 and (q.uv and q.uv[i][2] or q.v)<1,"v atlas")
    end
  end
end
local original={}
local function radiusAt(y)return y<8 and 4+math.floor(y/2) or 16-y end
for y=0,15 do
  local radius=radiusAt(y)
  local v0,v1=(40-y+.05)/128,(41-y-.05)/128
  local uv={{.1,v1},{.22,v1},{.22,v0},{.1,v0}}
  original[#original+1]={{-radius,y,8},{radius,y,8},{radius,y+1,8},{-radius,y+1,8},uv=uv,shade=1}
  original[#original+1]={{radius,y,-8},{-radius,y,-8},{-radius,y+1,-8},{radius,y+1,-8},uv={uv[2],uv[1],uv[4],uv[3]},shade=.72}
  original[#original+1]={{-radius,y,-8},{-radius,y,8},{-radius,y+1,8},{-radius,y+1,-8},u=.12,v=v0,shade=.8}
  original[#original+1]={{radius,y,8},{radius,y,-8},{radius,y+1,-8},{radius,y+1,8},u=.12,v=v0,shade=.8}
end
-- Native-style voxel caps close every change in the source front's width.
-- This is a rectangular stepped hull with the original too-wide side profile,
-- not a fixture that assumes the four-side reconstruction already exists.
for y=0,16 do
  local below=y>0 and radiusAt(y-1) or 0
  local above=y<16 and radiusAt(y) or 0
  local outer,inner=math.max(below,above),math.min(below,above)
  for x=-outer,outer-1 do
    if x< -inner or x>=inner then
      for z=-8,7 do
        local a,b,c,d={x,y,z+1},{x+1,y,z+1},{x+1,y,z},{x,y,z}
        if above>below then a,b,c,d=d,c,b,a end
        original[#original+1]={a,b,c,d,u=.12,v=.2,shade=.75}
      end
    end
  end
end
local originalCount=#original
local budgetLimited={}
for i=1,64 do budgetLimited[i]=original[i] end
assert(Nature.tree(map,data,budgetLimited)==budgetLimited,"quad-budget guard rejects too-simple source without inflation")
local tree=Nature.tree(map,data,original)
assert(tree~=original and #tree<=#original)
assert(tree.gen2NatureFourSides==56 and tree.gen2NatureTrunk,"four original facades and small trunk")
validate(tree,-8,8,0,16,-8,8)
assert(Nature.tree(map,data,original)==tree,"cached template identity")
assert(original[1][1][1]==-4 and #original==originalCount and original[3].uv==nil,"source unmodified")
local function normal(q)
  local a,b,c=q[1],q[2],q[3]
  local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
  return uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
end
for y=2,15 do
  local i=(y-2)*4+1
  local src=(y*4)+1
  for k=1,4 do for a=1,2 do
    assert(tree[i][k][a]==original[src][k][a],"native front elevation retained exactly")
  end end
  for k=1,4 do
    assert(tree[i].uv[k][1]==original[src].uv[k][1] and tree[i].uv[k][2]==original[src].uv[k][2],"native front art retained")
  end
  assert(tree[i+2].uv[1][1]~=tree[i+2].uv[2][1],"side carries full original row, not solid edge texel")
  assert(tree[i+3].uv[1][1]~=tree[i+3].uv[2][1],"opposite side carries original row")
  for k=1,4 do
    assert(math.abs(tree[i+2].uv[k][1]-tree[i].uv[k][1])<1e-9,"west image corners match front artwork")
    assert(math.abs(tree[i+3].uv[k][1]-tree[i].uv[k][1])<1e-9,"east image corners match front artwork")
    assert(math.abs(tree[i+2].uv[k][2]-tree[i].uv[k][2])<1e-9,"side rows use original image height")
    for turn=1,3 do
      local x,z=tree[i][k][1],tree[i][k][3]
      for n=1,turn do x,z=z,-x end
      assert(tree[i+turn][k][1]==x and tree[i+turn][k][3]==z,"four crown profiles are actual90-degree copies")
    end
  end
  local nx,ny,nz=normal(tree[i+3]);assert(nx<0,"side winding preserved")
end
for _,q in ipairs(tree)do if q.gen2Trunk then assert(q.shade<=.22,"fallback trunk must visibly darken native green texel") end end
local simple=source(8)
assert(Nature.tree(map,data,simple)==simple,"small object not inflated")
assert(Nature.tree(map,nil,original)==tree,"cache survives omitted pixel source")
local empty={}
assert(Nature.tree(map,data,empty)==empty,"headless empty fallback")
local grassSource=source(100)
local grass=Nature.grass(map,data,12,grassSource)
assert(#grass==15 and grass~=grassSource)
validate(grass,0,8,0,7,0,8)
local flowerSource=source(80)
package.preload["src.render.TileRenderer"]=function()
  return {defaultAnimatedTiles=function() return {{kind="frames",tile=3}} end}
end
local flowers=Nature.flower(map,data,3,flowerSource)
assert(#flowers==8 and flowers~=flowerSource)
local staticFlowerSource=source(80)
assert(Nature.flower(map,data,4,staticFlowerSource)==staticFlowerSource,"opaque static flower keeps native silhouette")
validate(flowers,0,8,0,7,0,8)
for i=1,8,2 do
  local ax,ay,az=normal(flowers[i])
  local bx,by,bz=normal(flowers[i+1])
  assert(ax*bx+ay*by+az*bz<0,"flower opposite faces")
end
Nature.invalidate()
assert(Nature.tree(map,data,original)~=tree,"full invalidation rebuilds")
Nature.invalidate()
local brownData={getDimensions=data.getDimensions,getPixel=function(_,x,y)
  if x==3 and y==3 then return .46,.29,.14,1 end
  return .5,.7,.3,1
end}
local brownTree=Nature.tree(map,brownData,original)
local brownTrunks=0
for _,q in ipairs(brownTree)do if q.gen2Trunk then
  brownTrunks=brownTrunks+1
  assert(q.gen2BrownTrunk and q.shade>=.59 and q.shade<=.89,
    'warm native atlas donor makes a visibly shaded brown trunk')
  assert(math.abs(q.uv[1][1]-3.5/128)<1e-9 and math.abs(q.uv[1][2]-3.5/128)<1e-9)
end end
assert(brownTrunks==5,'five visible brown trunk faces')
Nature.invalidate()
package.preload['src.render.GbcPalette']=function()
  return {color=function(_,shade)
    if shade==3 then return {.70,.43,.15,1} end
    return {.20,.58,.14,1}
  end}
end
local indexedData={getDimensions=data.getDimensions,getPixel=function()
  return .40,.70,.20,1 -- raw grayscale class 3; colour arrives from GBC palette
end}
local indexedMap={id='LAKE_OF_RAGE',_battleArtGen2BgSet={{}},tileset={
  id='TilesetJohto',tilesPerRow=16,imageWidth=128,imageHeight=128,tilePalettes={}}}
for i=1,256 do indexedMap.tileset.tilePalettes[i]=1 end
local indexedTree=Nature.tree(indexedMap,indexedData,original)
assert(indexedTree.gen2NatureBrownTrunk,'palette-baked brown donor is found from grayscale source')
assert(indexedTree.gen2NatureBarkRGB and indexedTree.gen2NatureBarkRGB[1]>.6
  and indexedTree.gen2NatureBarkRGB[2]>.3,'diagnostic records resolved GBC bark colour')
local function treeMap(id,tsid)
  return {id=id,tileset={id=tsid or 'TilesetJohto',tilesPerRow=16,imageWidth=128,imageHeight=128}}
end
local parkTree=Nature.tree(treeMap('NATIONAL_PARK','TilesetPark'),brownData,original)
local lakeTree=Nature.tree(treeMap('LAKE_OF_RAGE'),brownData,original)
local cityTree=Nature.tree(treeMap('GOLDENROD_CITY','TilesetJohtoModern'),brownData,original)
assert(parkTree.gen2NatureArchetype=='broad' and lakeTree.gen2NatureArchetype=='evergreen'
  and cityTree.gen2NatureArchetype=='urban','reference maps choose distinct tree families')
assert(parkTree.gen2NatureCanopyLift==0 and lakeTree.gen2NatureCanopyLift>0,
  'park art stays at native ground elevation while evergreen exposes a short trunk')
assert(parkTree~=lakeTree and lakeTree~=cityTree and parkTree~=cityTree,
  'template cache is partitioned by archetype')
assert(#parkTree<=#original and #lakeTree<=#original and #cityTree<=#original,
  'every biome tree remains inside the native quad budget')
local parkRoots,evergreenRows,urbanRows=0,0,0
local cornerPanels=0
local parkSides={}
for _,q in ipairs(parkTree)do if q.gen2ParkCorner then cornerPanels=cornerPanels+1 end end
assert(cornerPanels>0 and cornerPanels<80,'Park-only canopy corners have bounded leaf panels')
for _,q in ipairs(parkTree)do if q.gen2Trunk then
  parkRoots=parkRoots+1
  assert(q.gen2NativeTrunkArt and q.gen2Facade~=nil,
    'park trunk must use the original sprite, not added brown geometry')
  parkSides[q.gen2Facade]=(parkSides[q.gen2Facade] or 0)+1
end end
for _,q in ipairs(lakeTree)do if q.gen2TreeArchetype=='evergreen' then evergreenRows=evergreenRows+1 end end
for _,q in ipairs(cityTree)do if q.gen2TreeArchetype=='urban' then urbanRows=urbanRows+1 end end
assert(parkRoots>0 and parkTree.gen2NatureTrunk and not parkTree.gen2NatureBrownTrunk,
  'broad tree preserves its own fork and roots without a replacement trunk')
for side=0,3 do assert(parkSides[side]==parkRoots/4,
  'native trunk/root artwork must wrap all four sides equally')end
local otherBroad=Nature.tree(treeMap('PALLET_TOWN','TilesetKanto'),brownData,original)
local otherBroadTrunk=0
for _,q in ipairs(otherBroad)do if q.gen2Trunk then otherBroadTrunk=otherBroadTrunk+1 end end
assert(otherBroadTrunk==61 and otherBroad.gen2NatureBrownTrunk,
  'Park trunk change must not alter other broad-tree maps')
assert(evergreenRows>0 and urbanRows>0,'evergreen and clipped crown faces tagged')
assert(Nature.treeArchetype(treeMap('SILVER_CAVE_OUTSIDE'))=='evergreen')
local silverTree=Nature.tree(treeMap('SILVER_CAVE_OUTSIDE'),brownData,original)
assert(silverTree.gen2NatureCanopyLift>lakeTree.gen2NatureCanopyLift,
  'Silver corridor foliage clears the ground while Lake keeps its shorter trunk')
assert(Nature.treeArchetype(treeMap('AZALEA_TOWN','TilesetJohtoModern'))=='native',
  'modern tileset alone does not clip non-Goldenrod trees')
local function cell(ids)
  local S={tileAt={}}
  for dy=0,1 do for dx=0,1 do S.tileAt[(dy+64)*4096+dx+64]=ids[dy*2+dx+1] end end
  return S
end
local kanto={tileset={id="TilesetKanto"}}
assert(Nature.treeCell(kanto,cell({42,43,58,59}),0,0),"Kanto pale crown")
assert(Nature.treeCell(kanto,cell({64,65,80,81}),0,0),"Kanto dark crown")
assert(not Nature.treeCell(kanto,cell({72,73,88,89}),0,0),"boulder excluded")
assert(not Nature.treeCell(kanto,cell({45,46,61,62}),0,0),"cut tree preserved")
assert(not Nature.treeCell({tileset={id="TilesetCave"}},cell({64,65,80,81}),0,0),"other tileset excluded")
local modern={tileset={id="TilesetJohtoModern"}}
assert(Nature.treeCell(modern,cell({30,31,62,63}),0,0),"Goldenrod complete clipped-tree drawing")
assert(not Nature.treeCell(modern,cell({30,31,46,47}),0,0),"Modern non-tree lower course excluded")
assert(Nature.treeCell({tileset={id="TilesetForest"}},cell({14,15,30,31}),0,0),"partial forest canopy")
assert(not Nature.treeCell({tileset={id="TilesetForest"}},cell({14,5,30,31}),0,0),"mixed ground excluded")
print("PASS nature geometry: bounded counts, footprint, palette UV, winding, cache and fallbacks")
