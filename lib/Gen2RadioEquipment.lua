-- Radio2F's exact90..9F drawing is a six-drawer storage bank, not a wall.
-- Original colored drawer art remains on separate inset fronts and pulls.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=1200}
local function key(x,z)return(z+64)*4096+x+64 end
local function validMap(map)
 return map and map.def and map.def.generation==2 and map.id=='RADIO_TOWER_2F'
  and map.tileset and map.tileset.id=='TilesetRadioTower'
end
local function validRadioMap(map)
 return map and map.def and map.def.generation==2
  and map.tileset and map.tileset.id=='TilesetRadioTower'
end
local function model(w,h)
 local out={};local box=G.geometryWriter(out,4096)
 local function pos(x,y)
  local t=144+math.floor(y/8)*4+math.floor(x/8)
  return t%16*8+x%8,math.floor(t/16)*8+y%8
 end
 local function donor(x,y)local ax,ay=pos(x,y);return G.texelUV(ax,ay,w,h)end
 local function panel(x0,x1,s0,s1,y0,z)
  for sy=s0,s1 do local x=x0;local y=y0+s1-sy
   while x<=x1 do
    local n=math.min(x1-x+1,8-x%8);local ax,ay=pos(x,sy)
    out[#out+1]={{x,y,z},{x+n,y,z},{x+n,y+1,z},{x,y+1,z},own=true,shade=1,
     uv={{(ax+.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.05)/h},{(ax+.05)/w,(ay+.05)/h}}}
    x=x+n
   end
  end
 end
 -- The outer source outline is near-black, not the cabinet's case paint.
 -- Use the actual gray case/base trim for large surfaces; reserve the dark
 -- border for narrow joinery seams so rear/side views remain legible.
 local frame,dark,top=donor(2,27),donor(9,8),donor(2,2)
 -- Four short feet and actual storage depth; no full-height solid cube.
 for _,x in ipairs({2,28})do for _,z in ipairs({18,28})do box(x,0,z,x+2,4,z+2,frame)end end
 box(1,4,17,31,26,18,frame)
 for _,x in ipairs({1,10,20,30})do box(x,4,18,x+1,26,31,frame)end
 for _,y in ipairs({4,14,25})do box(2,y,18,30,y+1,31,frame)end
 box(0,26,16,32,27,32,top)
 -- Closed side panels and restrained rear joints follow the three-column,
 -- two-row cabinet layout. No second set of fake drawers on its back.
 box(.7,6,20,1,24,29,frame)
 box(31,6,20,31.3,24,29,frame)
 local function rear(x0,x1,y0,y1)
  local x=x0
  while x<x1 do local xx=math.min(x1,(math.floor(x/8)+1)*8)
   out[#out+1]={{xx,y0,16.99},{x,y0,16.99},{x,y1,16.99},{xx,y1,16.99},uv=dark,shade=.9,own=true}
   x=xx
  end
 end
 rear(10,10.2,6,24);rear(20,20.2,6,24);rear(2,30,14,14.2)
 -- Each panel uses its own 8x8 source window, with narrow sides closing
 -- the drawer behind it. Tiny pulls follow the source's upper-center marks.
 for c,x in ipairs({2,12,22})do
  for _,level in ipairs({{6,16},{16,6}})do
   local sy,y=level[1],level[2]
   box(x,y,24,x+8,y+8,29.75,donor(x+1,sy+2))
   panel(x,x+7,sy,sy+7,y,29.77)
   box(x+2,y+5,29.8,x+6,y+6,31.2,donor(x+3,sy+1))
  end
 end
 return out
end
local function workstation(w,h)
 local out={};local box=G.geometryWriter(out,640)
 local function donor(tile,x,y)
  return G.texelUV(tile%16*8+x,math.floor(tile/16)*8+y,w,h)
 end
 local frame,case,top,screen=donor(0x9C,2,3),donor(0x90,3,3),donor(0x90,2,2),donor(0x03,4,4)
 -- A long radio workstation: a thin top, three equipment pedestals and
 -- open knee spaces. This keeps the native footprint without the opaque
 -- 16x64 generic wall slab that formerly read as a black box.
 box(0,11,0,16,13,64,top)
 box(1,0,0,15,11,2,frame);box(1,0,62,15,11,64,frame)
 for _,z in ipairs({5,27,49})do
  box(2,0,z,14,10,z+10,case)
  box(13.7,2,z+1,15.2,9,z+9,screen)
  box(3,10,z+1,13,12,z+9,frame)
 end
 box(1,5,2,2,7,62,frame)
 return out
end
function M.build(S,map,data,perRow)
 if S.outdoor or S.radioEquipment or not validMap(map)or not data then return 0 end
 local w,h=data:getDimensions()
 if (perRow or 16)~=16 or w<128 or h<80 then return 0 end
 local cells={}
 for z=0,3 do for x=0,3 do
  local k=key(8+x,8+z);local s=S.shapeAt[k]
  if S.skip[k]or S.tileAt[k]~=144+z*4+x or not s or s.class~='wall'or s.flat or s.h~=16 then return 0 end
  if map.warpAtCell and map:warpAtCell(math.floor((8+x)/2),math.floor((8+z)/2))then return 0 end
  cells[#cells+1]=k
 end end
 local q=model(w,h)
 local western={{0x80,0x81},{0x82,0x83},{0x84,0x85},{0x86,0x87},
  {0x88,0x89},{0x82,0x83},{0x44,0x45},{0x4A,0x4B}}
 local westernCells={};local westernOk=true
 for dz,row in ipairs(western)do for dx,t in ipairs(row)do
  local x,z=dx-1,7+dz;local k=key(x,z);local s=S.shapeAt[k]
  if S.skip[k]or S.tileAt[k]~=t or map:tileAt(x,z)~=t or not s
      or s.class~='wall'or s.flat or s.h~=16
      or(map.warpAtCell and map:warpAtCell(math.floor(x/2),math.floor(z/2)))then westernOk=false end
  westernCells[#westernCells+1]=k
 end end
 local westernQuads=westernOk and workstation(w,h)or{}
 if #q+#westernQuads>M.MAX_QUADS then return 0 end
 for _,k in ipairs(cells)do
  S.skip[k]=true;S.ground[k]=1
  S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}
 end
 for _,v in ipairs(q)do for i=1,4 do v[i][1]=v[i][1]+64;v[i][3]=v[i][3]+64 end S.objectQuads[#S.objectQuads+1]=v end
 if westernOk then
  for _,k in ipairs(westernCells)do
   S.skip[k]=true;S.ground[k]=1
   S.shapeAt[k]={class='building',art='building',authored=true,flat=false,h=0}
  end
  for _,v in ipairs(westernQuads)do for i=1,4 do v[i][3]=v[i][3]+64 end S.objectQuads[#S.objectQuads+1]=v end
 end
 S.radioEquipment={models=westernOk and 2 or 1,quads=#q+#westernQuads,
  claimedTiles=16+(westernOk and 16 or 0),drawers=6,workstations=westernOk and 1 or 0,x=8,z=8}
 return #q+#westernQuads
end
-- Call after native structural runs are built, BEFORE room enclosure styling.
-- Diagnostic capture proves the black upper slabs are off-map rows-2/-1
-- inflating an otherwise16px, two-row wall to32px. Never cap interior runs,
-- doors, actual tall equipment, or a different source pair.
function M.correctWallRuns(S,map)
 if S.outdoor or S.radioWallRuns or not validRadioMap(map)or not S.runs then return 0 end
 local columns={};local changed=0
 local allowed={[17]=16,[3]=19,[4]=20}
 for x=0,map.def.width*4-1 do
  local k0,k1=key(x,0),key(x,1);local a,b=S.shapeAt[k0],S.shapeAt[k1]
  local r=S.runs[k1]
  if not S.skip[k0]and not S.skip[k1]and allowed[S.tileAt[k0]]==S.tileAt[k1]
   and a and b and a.class=='wall'and b.class=='wall'and a.h==16 and b.h==16
   and r and S.runs[k0]==r and r.north==-2 and r.front==1 and r.extent==4
   and r.unit==4 and r.h==32 and r.peak==32 and r.base==0 and r.rise==0
   and not r.door and (r.roofRows or 0)==0 then
   local c={};for field,value in pairs(r)do c[field]=value end
   c.north=0;c.extent=2;c.unit=2;c.h=16;c.peak=16
   -- A native run is shared by its four member cells, including border.
   -- Replace only those known members, never mutate a shared prototype.
   for z=-2,1 do local k=key(x,z);if S.runs[k]==r then S.runs[k]=c end end
   columns[x]=16;changed=changed+1
  end
 end
 S.radioWallRuns={columns=columns,corrected=changed,sourceRows=2,height=16}
 return changed
end
return M
