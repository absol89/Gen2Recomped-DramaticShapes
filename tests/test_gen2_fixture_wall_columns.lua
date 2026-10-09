local root='./'
local Rooms=assert(loadfile(root..'lib/Gen2RoomVisuals.lua'))({require=function()return{}end})
local function key(x,z)return(z+64)*4096+x+64 end
local function scene()
 local S={shapeAt={},tileAt={},runs={},skip={},doorFold={},sofaFixtures={wallColumns={}}}
 for x=4,11 do if x<=7 then S.sofaFixtures.wallColumns[x]=16 end
  for z=0,1 do local k=key(x,z);S.tileAt[k]=0x22
   S.shapeAt[k]={class='wall',art='upright',h=16,authored=x<=7,flat=false}
   if x>=8 then S.runs[k]={h=16,front=1,base=0,rise=0,door=false}end
  end
 end
 local map={id='MR_POKEMONS_HOUSE',def={generation=2},tileset={id='TilesetFacility'},
  tileAt=function(_,x,z)return x>=4 and x<=11 and z>=0 and z<=1 and 0x22 or 0 end,
  warpAtCell=function()end,isWarpTileCell=function()return false end}
 return S,map
end
local S,map=scene();local c=Rooms.fixtureWallColumns(S,map)
local n=0;for x,v in pairs(c)do assert(x>=4 and x<=11 and v.height==16 and v.frontDepth==16);n=n+1 end
assert(n==8)
for _,mode in ipairs({'absent','wrongmap','wrongtileset','generation','source','shape','art','height',
 'authored','skip','door','warp','rise','runheight','front','metadata','outside'})do
 local S,map=scene();local k=key(4,1)
 if mode=='absent'then S.sofaFixtures=nil
 elseif mode=='wrongmap'then map.id='BIKE_SHOP'
 elseif mode=='wrongtileset'then map.tileset.id='TilesetHouse'
 elseif mode=='generation'then map.def.generation=1
 elseif mode=='source'then map.tileAt=function()return 0x23 end
 elseif mode=='shape'then S.shapeAt[k].class='building'
 elseif mode=='art'then S.shapeAt[k].art='flat'
 elseif mode=='height'then S.shapeAt[k].h=32
 elseif mode=='authored'then S.shapeAt[k].authored=false
 elseif mode=='skip'then S.skip[k]=true
 elseif mode=='door'then S.doorFold[k]=true
 elseif mode=='warp'then map.warpAtCell=function()return{}end
 elseif mode=='metadata'then S.sofaFixtures.wallColumns[4]=32
 elseif mode=='outside'then S.sofaFixtures.wallColumns[99]=16
 else S.runs[k]={h=16,front=1,base=0,rise=0,door=false}
  if mode=='rise'then S.runs[k].rise=8
  elseif mode=='runheight'then S.runs[k].h=32 else S.runs[k].front=3 end
 end
 local cols=Rooms.fixtureWallColumns(S,map)
 if mode=='outside'then assert(not cols[99])else assert(not cols[4],mode)end
end
assert(S.shapeAt[key(4,1)].h==16 and not next(S.skip),'collector changed native structures')
print('PASS fixture wall columns: exact sofa4+adjacent4columns/16pxplane; metadata,source,art,warp,run protection; read-only')
local function bikeScene(workshop)
 local S={shapeAt={},tileAt={},runs={},skip={},doorFold={},ground={},objectQuads={},bikeShopFixtures={wallColumns={}}}
 local source={}
 for _,a in ipairs({4,8,10})do
  local rows={{2,3},{43,44},{5,6},{21,22}};if a==10 then rows[1]={18,19}end
  for z=0,3 do for dx=0,1 do local x=a+dx;local k=key(x,z)
   S.tileAt[k]=rows[z+1][dx+1];source[k]=S.tileAt[k];S.skip[k]=true;S.ground[k]=32
   S.shapeAt[k]={class='building',art='building',authored=true,h=0,flat=false};S.bikeShopFixtures.wallColumns[x]=16
  end end
 end
 if workshop then
  S.bikeShopFixtures.rackWallColumns={};S.bikeShopFixtures.signWallColumns={}
  local rows={{37,38,38,39},{54,55,55,58},{34,35,35,36},{50,51,51,52}}
  for z=0,3 do for x=0,3 do local k=key(x,z)
   S.tileAt[k]=rows[z+1][x+1];source[k]=S.tileAt[k];S.skip[k]=true
   S.shapeAt[k]={class='building',art='building',authored=true,h=0,flat=false}
   S.bikeShopFixtures.wallColumns[x]=16;S.bikeShopFixtures.rackWallColumns[x]=16
  end end
  for z=0,1 do for x=6,7 do local k=key(x,z)
   S.tileAt[k]=z==0 and (x==6 and 18 or 19)or 33;source[k]=S.tileAt[k]
   S.shapeAt[k]={class='wall',art='upright',authored=true,h=16,flat=false}
   S.bikeShopFixtures.wallColumns[x]=16;S.bikeShopFixtures.signWallColumns[x]=16
  end end
 end
 local map={id='GOLDENROD_BIKE_SHOP',def={generation=2,width=4,height=4},tileset={id='TilesetChampionsRoom'},
  tileAt=function(_,x,z)return source[key(x,z)]or 0 end,warpAtCell=function()end,isWarpTileCell=function()return false end}
 return S,map
end
for _,mode in ipairs({'valid','missingClaim','art','run','warp','source','map'})do
 local S,map=bikeScene();local k=key(4,3)
 if mode=='missingClaim'then S.skip[k]=nil
 elseif mode=='art'then S.shapeAt[k].art='upright'
 elseif mode=='run'then S.runs[k]={h=48}
 elseif mode=='warp'then map.warpAtCell=function()return{}end
 elseif mode=='source'then map.tileAt=function()return 0 end
 elseif mode=='map'then map.id='OTHER_ROOM'end
 local c=Rooms.bikeBackdropColumns(S,map)
 assert(not c[6]and not c[7],'sign columns claimed')
 if mode=='valid'then local n=0;for _ in pairs(c)do n=n+1 end;assert(n==6)
 else assert(not c[4]and not c[5],mode)end
end
local deps={Gen2ArchitectureVisuals=dofile(root..'lib/Gen2ArchitectureVisuals.lua'),
 Gen2InteriorStyles={resolve=function()return{id='shop',ceiling='clinical',wallpaper='clinical_band',lights='none'}end},
 Gen2BlankShell={collect=function()return{{x=-1,z=9,orientation='west',y=0,top=16}},{}end},
 Gen2StairSideFinish={collect=function()return{},{}end},
 Gen2RoomPaper={prove=function()end},Gen2WallArt={apply=function()return{wallColumns={}}end},
 Gen2ExitDoors={collect=function(map)return map.testExits or{}end}}
local Build=assert(loadfile(root..'lib/Gen2RoomVisuals.lua'))({require=function(n)return assert(deps[n],n)end})
local S,map=bikeScene(true)
assert(Rooms.bikeSignWallColumns(S,map)[6]and Rooms.bikeSignWallColumns(S,map)[7])
local saved=S.shapeAt[key(6,0)].h;S.shapeAt[key(6,0)].h=32
assert(not next(Rooms.bikeSignWallColumns(S,map)));S.shapeAt[key(6,0)].h=saved
local function shell(x,z)local k=key(x,z);S.shapeAt[k]={class='shell',h=16};S.tileAt[k]=0;S.runs[k]={h=16}end
for x=0,15 do shell(x,-1);shell(x,16)end;for z=0,15 do shell(-1,z);shell(16,z)end
local originalTile=map.tileAt
map.tileAt=function(self,x,z)
 if x==-1 or x==16 or z==16 then return 0x10
 elseif z==15 and x>=0 and x<=13 then return x>=4 and x<=7 and 0x14 or 0x20
 elseif x==15 and(z==2 or z==4 or z==6 or z==10)then return(z==2 or z==10)and 0x11 or 0x20
 elseif x==0 and(z==8 or z==14)then return 0x20 end
 return originalTile(self,x,z)
end
for x=0,13 do local k=key(x,16)
 S.shapeAt[k]={class='shell',art='upright',h=32,authored=false,flat=false};S.skip[k]=true;S.runs[k]=nil;S.tileAt[k]=1
 S.shapeAt[key(x,15)]={class='ground',flat=true,h=0};S.tileAt[key(x,15)]=x>=4 and x<=7 and 0x14 or 0x20
end
for _,z in ipairs({2,4,6,10})do local k=key(16,z)
 S.shapeAt[k]={class='shell',art='upright',h=32,authored=false,flat=false};S.skip[k]=true;S.runs[k]=nil;S.tileAt[k]=1
 S.shapeAt[key(15,z)]={class='ground',flat=true,h=0};S.tileAt[key(15,z)]=(z==2 or z==10)and 0x11 or 0x20
end
map.warpAtCell=function(_,x,z)return z==7 and(x==2 or x==3)and{}or nil end
map.isWarpTileCell=function(_,x,z)return z==7 and(x==2 or x==3)end
for _,z in ipairs({8,14})do
 local k=key(-1,z);S.shapeAt[k]={class='shell',art='upright',h=32,authored=false,flat=false};S.skip[k]=true;S.runs[k]=nil;S.tileAt[k]=1
 S.shapeAt[key(0,z)]={class='ground',flat=true,h=0};S.tileAt[key(0,z)]=0x20
end
local pixels={getDimensions=function()return 128,128 end,getPixel=function(_,x,y)
 if x<8 and y>=8 and y<16 then return 0,0,0,1 end;return .7,.7,.7,1 end}
assert(Rooms.bikeWestGaps(S,map,pixels)[8]and Rooms.bikeWestGaps(S,map,pixels)[14])
local _,south,east=Rooms.bikeWestGaps(S,map,pixels)
local _,_,_,lintel=Rooms.bikeWestGaps(S,map,pixels);assert(lintel)
local warpAt=map.warpAtCell;map.warpAtCell=function()end
local _,_,_,noLintel=Rooms.bikeWestGaps(S,map,pixels);assert(not noLintel);map.warpAtCell=warpAt
for x=4,7 do assert(not south[x],'door columns covered')end
for _,x in ipairs({0,1,2,3,8,9,10,11,12,13})do assert(south[x])end
for _,z in ipairs({2,4,6,10})do assert(east[z])end
S.tileAt[key(15,2)]=0x12;local _,_,badEast=Rooms.bikeWestGaps(S,map,pixels);assert(not badEast[2]);S.tileAt[key(15,2)]=0x11
assert(not next(Rooms.bikeWestGaps(S,map,{getDimensions=pixels.getDimensions,getPixel=function()return .1,0,0,1 end})))
map.testExits={{x0=32,x1=64,z=128,destMap='GOLDENROD_CITY',destWarp=2}}
local n=Build.build(S,map,pixels,16)
assert(n>0 and n<=2200)
local front,lower,west={},{},{};local returns=0;local southFaces,eastFaces,lintelFaces=0,0,0
local overlaps=0
for _,q in ipairs(S.objectQuads)do
 if q.roomRole=='upper_wall'or q.roomRole=='lower_blank_wall' then
  assert(not(q[1][2]<6 and q[3][2]>6),'floor contact AO stretched across upper wall')
  if q[1][1]==q[2][1]and q[1][1]<1 then
   assert(q[1][1]==.025,'Bike west upper/lower faces use staggered planes')
  end
  if q[1][1]==q[2][1]and q[1][1]>127 then assert(q[1][1]==127.975,'east planes staggered')end
  if q[1][3]==q[2][3]and q[1][3]>127 then assert(q[1][3]==127.975,'south planes staggered')end
  local dx,dz=math.abs(q[1][1]-q[2][1]),math.abs(q[1][3]-q[2][3])
  assert(math.max(dx,dz)<=8.040001,'tangent overlap exceeds bounded .02 per edge')
  if math.max(dx,dz)>8.001 then overlaps=overlaps+1 end
  for _,p in ipairs(q)do assert(p[1]>=0 and p[1]<=128 and p[3]>=0 and p[3]<=128,'overlap left room bounds')end
  if q[1][3]>=127.9 and q[2][3]>=127.9 and q[1][2]<30 then
   local lo,hi=math.min(q[1][1],q[2][1]),math.max(q[1][1],q[2][1])
   assert(hi<=32 or lo>=64,'tangent overlap intrudes into real doorway')
  end
 end
 if q.roomRole=='upper_wall'and q[1][3]==16 and q[2][3]==16 then
  local x=math.floor((q[1][1]+q[2][1])/16);assert(x>=0 and x<=11)
   front[x]=true;assert(q[1][2]==16 and q[3][2]==40,'bike upperwall clips model or leaves gap')
 elseif q.roomRole=='lower_blank_wall'and q[1][3]==.025 then
  lower[math.floor((q[1][1]+q[2][1])/16)]=true;assert(q[1][2]>=0 and q[3][2]<=16)
 elseif q.roomRole=='upper_wall'and q[1][1]==.025 and q[2][1]==.025 then
  local z=math.floor((q[1][3]+q[2][3])/16)
   if z==8 or z==14 then west[z]=true;assert(q[1][2]>=0 and q[3][2]<=40)end
 elseif q.roomRole=='upper_wall'and q[1][3]==127.975 and q[2][3]==127.975 and q[1][2]==0 then
  southFaces=southFaces+1;local x=math.floor((q[1][1]+q[2][1])/16);assert(not(x>=4 and x<=7))
 elseif q.roomRole=='upper_wall'and q[1][1]==127.975 and q[2][1]==127.975 and q[1][2]==0 then eastFaces=eastFaces+1
 elseif q.roomRole=='lower_blank_wall'and q[1][3]==127.975 then
  local x=math.floor((q[1][1]+q[2][1])/16);assert(x>=4 and x<=7 and q[1][2]==30 and q[3][2]==32)
  lintelFaces=lintelFaces+1
 elseif q.roomRole=='bike_alcove_return'then
  returns=returns+1;for _,p in ipairs(q)do assert(p[2]==16 and p[3]>=.025 and p[3]<=16)end
 end
end
local count=0;for _ in pairs(front)do count=count+1 end;assert(count==12)
for x in pairs(front)do if x~=6 and x~=7 then assert(lower[x])else assert(not lower[x],'source sign overpainted')end end
assert(west[8]and west[14]and returns==20)
assert(southFaces==10 and eastFaces==4 and S.tileAt[key(15,2)]==0x11 and S.tileAt[key(15,10)]==0x11)
assert(lintelFaces==4 and S.roomVisuals.exitDoors==1,'paired exit lintel not exactly closed above30')
assert(overlaps>0,'raster seam overlap was not applied')
print('PASS exact bike backdrop:12flush upper columns,20safe returns,2west/10south/4east voidclosures,retainedsign/skirting/doors; '..n..' bounded roomquads')
