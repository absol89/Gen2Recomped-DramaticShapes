local root='lib/'
local G=assert(loadfile(root..'Gen2ArchitectureVisuals.lua'))()
local M=assert(loadfile(root..'Gen2DeskVisuals.lua'))({require=function()return G end})
local function k(x,z)return(z+64)*4096+x+64 end
local data={getDimensions=function()return 128,48 end}
local map={def={width=5,height=4},tileset={id='TilesetLab'},warps={sentinel=true}}
local function scene()
 local S={shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
 for x=0,5 do for z=0,1 do local p=k(x,z);S.tileAt[p]=(x==0 and 5 or(x==5 and 7 or 6))+z*16;S.shapeAt[p]={class='table',h=6,authored=true}end end
 return S
end
local S=scene();local n=M.build(S,map,data,16)
assert(n>0 and n<=M.MAX_QUADS and S.deskVisuals.count==1 and map.warps.sentinel)
assert(M.build(S,map,data,16)==0)
for x=0,5 do for z=0,1 do assert(S.skip[k(x,z)] and S.shapeAt[k(x,z)].h==6)end end
for _,q in ipairs(S.objectQuads)do for i,p in ipairs(q)do
 assert(p[1]>=0 and p[1]<=48 and p[2]>=0 and p[2]<=6.025 and p[3]>=0 and p[3]<=16)
 assert(q.uv[i][1]>=0 and q.uv[i][1]<=1 and q.uv[i][2]>=0 and q.uv[i][2]<=1)
end end
S=scene();S.tileAt[k(2,1)]=3;assert(M.build(S,map,data,16)==0 and not next(S.skip))
S=scene();S.shapeAt[k(1,1)].class='bookcase';assert(M.build(S,map,data,16)==0)
S=scene();S.skip[k(1,1)]=true;assert(M.build(S,map,data,16)==0)
S=scene();S.outdoor=true;assert(M.build(S,map,data,16)==0)
assert(M.build(scene(),{def=map.def,tileset={id='TilesetHouse'}},data,16)==0)
print('PASS lab desks: '..n..' quads, exact endcap/repeated desktop, partial guards, height/footprint/UV bounds')
