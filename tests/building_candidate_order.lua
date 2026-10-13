local B = {check = function() end}
local templates = {
  {tiles={{1,2}},claimOnly=true,id="wide"},
  {tiles={{1}},claimOnly=true,id="small"},
}
local M = assert(loadfile("lib/Buildings.lua"))({require=function() return B end,
  data=function() return {buildings={TEST=templates}} end})
local function k(x,y) return (y+64)*4096+x+64 end
local S={objectQuads={},skip={},tileAt={}}
for y=0,3 do for x=0,3 do S.tileAt[k(x,y)]=0 end end
S.tileAt[k(0,0)]=1; S.tileAt[k(1,0)]=2
S.tileAt[k(2,0)]=1; S.tileAt[k(3,0)]=2
S.tileAt[k(3,1)]=1 -- wide placement would exceed body bounds
S.tileAt[k(0,2)]=1; S.tileAt[k(1,2)]=2; S.skip[k(1,2)]=true
local placed={}
M.stamp=function(grid,map,quads,x,y,w,h,t)
  placed[#placed+1]=t.id..":"..x..","..y
  for dy=0,h-1 do for dx=0,w-1 do grid.skip[k(x+dx,y+dy)]=true end end
end
M.build(S,{tileset={id="TEST"},def={width=1,height=1}},{},16)
assert(table.concat(placed,"|")=="wide:0,0|wide:2,0|small:3,1|small:0,2",
  "row order, template priority, claimed cells or edge bounds changed")
assert(S.tileAt[k(0,0)]==1 and S.tileAt[k(1,0)]==2)
print("PASS indexed candidate placement order, first claim, partial claims, bounds and unchanged tile IDs")
