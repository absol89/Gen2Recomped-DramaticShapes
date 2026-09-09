local f=assert(io.open('lib/BattleScene.lua'));local source=f:read('*a');f:close()
local body=assert(source:match('(function BattleScene.groundY.-)\n%-%- Where a world point'))
local heights={0,4}
local env=setmetatable({BattleScene={},VoxelScene={groundAt=function(_,x) return heights[x] end}},{__index=_G})
local chunk=assert(loadstring(body));setfenv(chunk,env);chunk()
local arena={playerCell={1,0},enemyCell={2,0}}
assert(env.BattleScene.groundY({},arena)==5,'enemy raised terrain must support shared battle floor')
heights={6,0}
assert(env.BattleScene.groundY({},arena)==7,'player raised terrain remains supported')
heights={0,0}
assert(env.BattleScene.groundY({},arena)==1,'flat terrain gets one pixel of clearance')
env.VoxelScene.groundAt=function() error('unavailable') end
assert(env.BattleScene.groundY({},arena)==1,'safe fallback keeps clearance')
print('4 battle ground clearance checks passed')
