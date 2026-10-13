local P=assert(loadfile('lib/ParkProps.lua'))()
local function K(x,z)return(z+64)*4096+x+64 end
local s={tileAt={},shapeAt={},skip={},ground={},runs={},objectQuads={}}
for dz,row in ipairs({{0x45,0x46},{0x55,0x56}})do for dx,t in ipairs(row)do s.tileAt[K(dx+1,dz+1)]=t end end
local data={getDimensions=function()return 128,128 end,getPixel=function()return .66,.66,.66,1 end}
P.build(s,{tileset={id='TilesetPark'},def={width=4,height=4}},data,16)
assert(s.parkProps.signs==1)
local fronts,backs=0,0
for _,q in ipairs(s.objectQuads)do
 if math.abs(q[1][3]-23.18)<.001 then
  backs=backs+1
  local tileColumn=math.floor(q.uv[1][1]*16)
  assert(tileColumn==(q[1][1]==24 and 6 or 5),'back face halves swapped')
 elseif math.abs(q[1][3]-24.82)<.001 then
  fronts=fronts+1
  local tileColumn=math.floor(q.uv[1][1]*16)
  assert(tileColumn==(q[1][1]==16 and 5 or 6),'front face changed')
 end
end
assert(fronts==4 and backs==4,'both rows of both faces checked')
print('PASS sign front unchanged; back tile halves correctly ordered on both rows')
