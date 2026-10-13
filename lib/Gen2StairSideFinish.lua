-- Pure proof collector: finish the already solid EAST shell beside the
-- player's floor-stair warps. Never cover the stair floor or north.
local M={}
local floor,max=math.floor,math.max
local function key(x,z)return(z+64)*4096+x+64 end
local specs={
 PLAYERS_HOUSE_1F={width=5,height=4,tileset='TilesetPlayersHouse',warpX=9,dest='PLAYERS_HOUSE_2F',destWarp=1,
  stairX=18,sideX=20,tiles={0x4C,0x4D,0x5C,0x5D},class='stair_e'},
 PLAYERS_HOUSE_2F={width=4,height=3,tileset='TilesetPlayersRoom',warpX=7,dest='PLAYERS_HOUSE_1F',destWarp=3,
  stairX=14,sideX=16,tiles={0x40,0x41,0x50,0x51},class='stair_down_w'},
}
function M.collect(S,map,data,perRow)
 local stats={faces=0,pixelReads=0};local function reject(why)stats.reason=why;return{},stats end
 local spec=map and specs[map.id or(map.def and map.def.id)]
 if not(S and map and map.def and map.def.generation==2 and spec
  and map.tileset and map.tileset.id==spec.tileset
  and map.def.width==spec.width and map.def.height==spec.height)
  or S.outdoor or not(data and data.getDimensions and data.getPixel)then return reject('different room')end
 if map.def.connections and next(map.def.connections)then return reject('connected room')end
 if type(map.tileAt)~='function'or type(map.warpAtCell)~='function'or type(map.isWarpTileCell)~='function'
  or not(S.shapeAt and S.tileAt and S.runs)then return reject('missing native proof')end
 local matched=false
 for _,warp in ipairs(map.def.warps or{})do
  if warp.x==spec.warpX and warp.y==0 and warp.destMap==spec.dest
    and warp.destWarp==spec.destWarp then matched=true end
 end
 local ok,warp=pcall(map.warpAtCell,map,spec.warpX,0)
 local okCollision,warpCollision=pcall(map.isWarpTileCell,map,spec.warpX,0)
 if not matched or not ok or not warp or not okCollision or not warpCollision then return reject('missing stair warp')end
 for z=0,1 do for dx=0,1 do
  local k=key(spec.stairX+dx,z);local s=S.shapeAt[k]
  local t=spec.tiles[z*2+dx+1]
  if S.tileAt[k]~=t or not s or s.class~=spec.class or not s.authored
    or s.flat or s.h~=16 or not(S.skip and S.skip[k])then return reject('stair changed')end
 end end
 local w,h=data:getDimensions();local row=perRow or 16
 if row~=16 or w<8 or h<8 then return reject('invalid atlas')end
 local out={};local sampled={}
 for z=0,2 do
  local k=key(spec.sideX,z);local s,r=S.shapeAt[k],S.runs[k]
  local inside=S.shapeAt[key(spec.sideX-1,z)]
  if not s or s.class~='shell'or s.authored or(S.skip and S.skip[k])
   or(S.doorFold and S.doorFold[k])or not r or r.door or r.rise~=0 or r.base~=0
   or r.h~=16 or r.north~=-2 or r.front~=spec.height*4+1 or r.unit~=2
   or r.extent~=spec.width*4
   or not inside or (z<2 and (inside.class~=spec.class or not inside.authored
     or inside.h~=16) or z==2 and (inside.class~='ground'or not inside.flat
     or inside.h~=0))then return reject('shell changed')end
  -- ChunkMesher east/west folding samples front-band, NOT syntheticS.tileAt.
  for band=0,1 do
   local called,t=pcall(map.tileAt,map,spec.sideX,r.front-band)
   if not called or type(t)~='number'or t<0 or t~=floor(t)then return reject('unknown sample')end
   if not sampled[t]then
    local ax,ay=t%row*8,floor(t/row)*8
    if ax+8>w or ay+8>h then return reject('sample outside atlas')end
    for yy=0,7 do for xx=0,7 do
     local valid,red,green,blue,alpha=pcall(data.getPixel,data,ax+xx,ay+yy)
     stats.pixelReads=stats.pixelReads+1
     if not valid or type(alpha)~='number'or type(red)~='number'or type(green)~='number'or type(blue)~='number'
      or alpha~=alpha or alpha<.999 or red~=red or green~=green or blue~=blue
      or red<0 or green<0 or blue<0 or max(red,green,blue)>.1 then return reject('authored border art')end
    end end
    sampled[t]=true
   end
  end
  out[#out+1]={x=spec.sideX,z=z,orientation='east',y=0,top=16}
 end
 stats.faces=#out;stats.reason='blank existing sidewall beside floor stairs'
 return out,stats
end
return M
