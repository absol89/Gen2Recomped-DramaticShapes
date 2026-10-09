local root='lib/'
local G=assert(loadfile(root..'Gen2ArchitectureVisuals.lua'))()
local M=assert(loadfile(root..'Gen2SmallProps.lua'))({require=function()return G end})
local function k(x,z)return(z+64)*4096+x+64 end
local rows={{14,15},{30,31}}
local function fixture()
 local S={shapeAt={},tileAt={},skip={},ground={},objectQuads={}}
 for r,row in ipairs(rows)do for c,t in ipairs(row)do local p=k(c-1,r-1);S.tileAt[p]=t;S.shapeAt[p]={class='table',h=6,authored=true}end end
 return S
end
local map={tileset={id='TilesetLab'},def={width=2,height=2},warps={safe=true}}
local data={getDimensions=function()return 128,128 end,getPixel=function(_,x,y)local c=(x%4)/3;return c,c,c,1 end}
local S=fixture();local n=M.build(S,map,data,16)
assert(n>0 and n<=M.MAX_QUADS and S.smallProps.trashCans==1 and map.warps.safe)
assert(M.build(S,map,data,16)==0)
for r,row in ipairs(rows)do for c,t in ipairs(row)do assert(S.skip[k(c-1,r-1)] and S.tileAt[k(c-1,r-1)]==t)end end
for _,q in ipairs(S.objectQuads)do
 local top=true
 for i,p in ipairs(q)do
  assert(p[1]>=2.5 and p[1]<=13.5 and p[3]>=2.5 and p[3]<=13.5 and p[2]>=0 and p[2]<=9)
  assert(q.uv[i][1]>=0 and q.uv[i][1]<=1 and q.uv[i][2]>=0 and q.uv[i][2]<=1)
  if p[2]~=9 then top=false end
 end
 if top then for _,p in ipairs(q)do assert((p[1]-8)^2+(p[3]-8)^2>19,'rim closes hollow mouth')end end
end
S=fixture();S.tileAt[k(1,1)]=0;assert(M.build(S,map,data,16)==0 and not next(S.skip))
S=fixture();S.shapeAt[k(0,0)].class='ground';assert(M.build(S,map,data,16)==0)
S=fixture();S.skip[k(1,0)]=true;assert(M.build(S,map,data,16)==0)
S=fixture();S.outdoor=true;assert(M.build(S,map,data,16)==0)
assert(M.build(fixture(),{tileset={id='TilesetHouse'},def=map.def},data,16)==0)
print('PASS exact Lab bin '..n..' quads: hollow mouth, source palette, footprint, claims, collision identity and fallback guards')
