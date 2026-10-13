local Mat = assert(loadfile('lib/Mat4.lua'))()
local B = assert(loadfile('lib/MeshBounds.lua'))({require=function(n) assert(n=='Mat4');return Mat end})
local Scope = assert(loadfile('lib/WorldRenderScope.lua'))()
local mesh = {}
B.set(mesh, {-.2,-.2,-.2,.2,.2,.2})
assert(not B.hidden(mesh,Mat.identity()))
for axis=1,3 do for _,sign in ipairs({-1,1})do
 local t={0,0,0};t[axis]=sign*2
 assert(B.hidden(mesh,Mat.identity(),Mat.translate(unpack(t))))
end end
assert(not B.hidden({},Mat.identity()),'unknown meshes must draw')
B.set(mesh, {-2,-2,-2,2,2,2})
assert(not B.hidden(mesh,Mat.identity()),'straddling boxes must draw')
assert(not Scope.active())
Scope.run(true,function()
 assert(Scope.active())
 Scope.run(false,function()assert(not Scope.active())end)
 assert(Scope.active())
end)
local ok=pcall(function()Scope.run(true,function()error('fixture')end)end)
assert(not ok and not Scope.active(),'error leaked world policy into battle')

-- Exercise production draw dispatch, including the battle and curve bypasses.
local f=assert(io.open('lib/Voxel3D.lua'));local s=f:read('*a');f:close()
local body=assert(s:match('(function Voxel3D.draw.-)\n%-%- Project a world point'))
local draws=0
local env=setmetatable({Voxel3D={vp=Mat.identity(),curveK=0},active=true,
 activeShader={send=function()end},WorldRenderScope=Scope,MeshBounds=B,
 IDENTITY=Mat.identity(),love={graphics={draw=function()draws=draws+1 end}}},{__index=_G})
local fn=assert(loadstring(body));setfenv(fn,env);fn()
B.set(mesh,{2,2,2,3,3,3})
Scope.run(true,function()env.Voxel3D.draw(mesh)end);assert(draws==0)
env.Voxel3D.draw(mesh);assert(draws==1,'battle draw was culled')
env.Voxel3D.curveK=.001
Scope.run(true,function()env.Voxel3D.draw(mesh)end);assert(draws==2,'curved mesh wrongly culled')
print('PASS mesh bounds: six planes, translation, unknown/straddling, scope cleanup, battle/curve bypass')
