-- Material finish baked into the existing Gen2 atlas, with no extra textures
-- or render passes. Only exclusively flat ground tiles are eligible.
local V=...
local TileShape=V.require('TileShape')
local IndoorFloors=V.require('Gen2IndoorFloors')
local M={}
function M.bake(map,image)
 if not(map and map.def and map.tileset and map.def.generation==2)then return 0 end
 local shapes=TileShape.forMap(map)
 local uses={}
 for y=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
  local tile=map:tileAt(x,y)
  if tile~=nil then
   local s=TileShape.at(map,shapes,tile,x,y)
   local allowed=s and s.flat and s.class=='ground'
   if not allowed then uses[tile]=false elseif uses[tile]==nil then uses[tile]=true end
  end
 end end
 local floorCount,painted,style=IndoorFloors.bake(map,image,uses)
 if style then
  map._gen2IndoorFloors={style=style,tiles=floorCount}
  -- A recognized interior receives only the explicitly verified floor
  -- replacement. Mats, rugs and any vetoed/shared tiles keep their pixels.
  return floorCount
 end
 map._gen2IndoorFloors=nil
 local w,h=image:getDimensions();local row=map.tileset.tilesPerRow or 16
 local count=0
 for tile,eligible in pairs(uses)do if eligible then
  local ox,oy=(tile%row)*8,math.floor(tile/row)*8
  if ox+8<=w and oy+8<=h then
   local pixels={};local avg={0,0,0};local lo,hi=1,0
   for y=0,7 do for x=0,7 do
    local r,g,b,a=image:getPixel(ox+x,oy+y)
    pixels[#pixels+1]={r,g,b,a}
    avg[1]=avg[1]+r/64;avg[2]=avg[2]+g/64;avg[3]=avg[3]+b/64
    local l=(r+g+b)/3;lo=math.min(lo,l);hi=math.max(hi,l)
   end end
   -- High-contrast symbols/door mats and black void artwork keep their art.
   if lo>.12 and hi-lo<.62 then
    local grass=avg[2]>avg[1]*1.12 and avg[2]>avg[3]*1.15
    -- Grass artwork stays byte-for-byte native; its redesign is deferred.
    if not grass then
    for y=0,7 do for x=0,7 do
     local p=pixels[y*8+x+1]
     local grain=((x*13+y*7+tile*3)%11-5)*.004
     -- Restrained finish for non-grass paths and floor patterns only.
     local blend=.035
     for c=1,3 do p[c]=math.max(0,math.min(1,p[c]*(1-blend)+avg[c]*blend+grain))end
     image:setPixel(ox+x,oy+y,p[1],p[2],p[3],p[4])
    end end
    count=count+1
    end
   end
  end
 end end
 return count
end
return M
