local root='./'
local f=assert(io.open(root..'lib/Structures.lua','r'))
local source=f:read('*a');f:close()
assert(not source:find('tpl = Nature.grass',1,true),'replacement grass still enabled')
local shape={flat=true,class='ground'}
package.loaded['src.world.Map']={isOutdoor=function(def)return def.testOutdoor end}
local shapes={forMap=function()return{}end,at=function()return shape end}
local floors=assert(loadfile(root..'lib/Gen2IndoorFloors.lua'))({require=function()return shapes end})
local M=assert(loadfile(root..'lib/Gen2SurfaceMaterials.lua'))({require=function(name)
 if name=='Gen2IndoorFloors' then return floors end
 return shapes
end})
local writes=0
local data={getDimensions=function()return 8,8 end,getPixel=function(_,x,y)return .2,.5+((x+y)%2)*.1,.2,1 end,setPixel=function()writes=writes+1 end}
local map={def={generation=2,width=1,height=1,testOutdoor=true},tileset={id='TilesetHouse',tilesPerRow=1},tileAt=function()return 0 end}
assert(M.bake(map,data)==0 and writes==0,'native grass texels modified')
print('PASS native grass template active and green ground pixels untouched')
