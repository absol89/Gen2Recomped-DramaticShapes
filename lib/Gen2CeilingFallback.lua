-- Exact ceiling-only fallback for three Gen 2 rooms whose native perimeter
-- intentionally has open/invisible wall segments. Gen2RoomVisuals correctly
-- refuses to invent walls for those gaps; this closes only the overhead void.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local Map=require('src.world.Map')
local M={MAX_QUADS=1024,HEIGHT=48}
local exact={CIANWOOD_GYM=true,ECRUTEAK_GYM=true,ECRUTEAK_TIN_TOWER_ENTRANCE=true}
local floor,ceil,min,max=math.floor,math.ceil,math.min,math.max

local function material(data,w,h)
 local best,bestScore
 for y=0,h-1 do for x=0,w-1 do
  local r,g,b,a=data:getPixel(x,y);local hi,lo=max(r,g,b),min(r,g,b);local light=(r+g+b)/3
  if a>=.999 and light>=.42 and hi-lo<=.22 then
   local score=math.abs(light-.78)+(hi-lo)*.7
   if not bestScore or score<bestScore then best,bestScore={x,y},score end
  end
 end end
 if not best then return nil end
 return G.texelUV(best[1],best[2],w,h)
end

function M.build(S,map,data)
 if S.outdoor or S.ceilingFallback or not(map and map.def and map.def.generation==2)
    or Map.isOutdoor(map.def) or not exact[tostring(map.id or map.def.id or '')]
    or not data or not data.getPixel then return 0 end
 local rejected=S.roomVisuals and S.roomVisuals.reason
 if rejected~='native room shell incomplete'and rejected~='native wall material unavailable'then return 0 end
 local tw,th=map.def.width*4,map.def.height*4
 if tw<4 or th<4 or tw~=floor(tw)or th~=floor(th)or tw*th>16384 then return 0 end
 local w,h=data:getDimensions();local uv=material(data,w,h);if not uv then return 0 end
 local step=tw*th>1600 and 4 or 2;local ceilingCount=ceil(tw/step)*ceil(th/step)
 local cellW,cellH=map.def.width*2,map.def.height*2;local warps={}
 for _,warp in ipairs(map.def.warps or{})do if type(warp.x)=='number'and type(warp.y)=='number'then warps[warp.y*cellW+warp.x]=true end end
 local function blocked(cx,cy)return warps[cy*cellW+cx]end
 local wallCount=0
 for x=0,tw-1,2 do
  if not blocked(floor(x/2),0)then wallCount=wallCount+1 end
  if not blocked(floor(x/2),cellH-1)then wallCount=wallCount+1 end
 end
 for z=0,th-1,2 do
  if not blocked(0,floor(z/2))then wallCount=wallCount+1 end
  if not blocked(cellW-1,floor(z/2))then wallCount=wallCount+1 end
 end
 local count=ceilingCount+wallCount;if count>M.MAX_QUADS then return 0 end
 for z=0,th-1,step do for x=0,tw-1,step do
  local x1,z1=min(tw,x+step)*8,min(th,z+step)*8
  S.objectQuads[#S.objectQuads+1]={{x*8,M.HEIGHT,z*8},{x1,M.HEIGHT,z*8},{x1,M.HEIGHT,z1},{x*8,M.HEIGHT,z1},uv=uv,shade=.91+((x/step+z/step)%2)*.03,own=true,oneSided=true,roomRole='ceiling_fallback'}
 end end
 local function wall(a,b,c,d)S.objectQuads[#S.objectQuads+1]={a,b,c,d,uv=uv,shade=.88,own=true,oneSided=true,roomRole='wall_fallback'}end
 for x=0,tw-1,2 do local x0,x1=x*8,min(tw,x+2)*8;local cx=floor(x/2)
  if not blocked(cx,0)then wall({x0,16,0},{x1,16,0},{x1,M.HEIGHT,0},{x0,M.HEIGHT,0})end
  if not blocked(cx,cellH-1)then local z=th*8;wall({x1,16,z},{x0,16,z},{x0,M.HEIGHT,z},{x1,M.HEIGHT,z})end
 end
 for z=0,th-1,2 do local z0,z1=z*8,min(th,z+2)*8;local cy=floor(z/2)
  if not blocked(0,cy)then wall({0,16,z1},{0,16,z0},{0,M.HEIGHT,z0},{0,M.HEIGHT,z1})end
  if not blocked(cellW-1,cy)then local x=tw*8;wall({x,16,z0},{x,16,z1},{x,M.HEIGHT,z1},{x,M.HEIGHT,z0})end
 end
 S.ceilingFallback={quads=count,ceilingQuads=ceilingCount,wallQuads=wallCount,height=M.HEIGHT,stride=step,reason=rejected}
 S.roomVisuals.ceiling=M.HEIGHT;S.roomVisuals.ceilingFallback=true
 return count
end
return M
