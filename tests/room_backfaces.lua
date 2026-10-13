local M=dofile('lib/RoomBackfaces.lua')
local function quad(a,b,c) return {a,b,c,{0,0,0},oneSided=true} end
local cases={
 {quad({0,1,0},{1,1,0},{1,1,1}),4,{0,-1,0}}, -- ceiling points down
 {quad({0,0,0},{1,0,0},{1,1,0}),5,{0,0,1}}, -- north wall faces room
 {quad({1,0,1},{0,0,1},{0,1,1}),6,{0,0,-1}},
 {quad({0,0,1},{0,0,0},{0,1,0}),1,{1,0,0}},
 {quad({1,0,0},{1,0,1},{1,1,1}),2,{-1,0,0}},
}
for _,case in ipairs(cases) do
 local packed=M.shade(case[1],{.8,.9,1,1.1})
 for i,shade in ipairs({.8,.9,1,1.1}) do
  local side=math.floor(-packed[i]/4)
  assert(side==case[2] and math.abs(-packed[i]-side*4-shade)<1e-6)
 end
 local n=case[3]
 assert(n[1]*n[1]+n[2]*n[2]+n[3]*n[3]==1)
end
local furniture={};local shade={1,1,1,1}
assert(M.shade(furniture,shade)==shade,'two-sided furniture/sprites changed')
assert(M.shade(quad({0,0,0},{0,0,0},{0,0,0}),1)==1,'degenerate fallback')
local outward = quad({0,0,0},{0,0,1},{0,1,1})
assert(math.floor(-M.shade(outward,1,{10,8,10})/4)==1,
  'native exterior wall must face the room instead of outside')
print('PASS inward ceiling/four walls, packed shade round trip and two-sided fallback')
