-- Crystal Pokemon Center equipment: exact source grids, independent volumes,
-- original atlas palettes. Built once with terrain; no gameplay/draw hooks.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_MAP_QUADS=4096,MAX_FIXTURE_QUADS=1200,MAX_FIXTURES=12}
local floor,min=math.floor,math.min
local function key(x,z)return (z+64)*4096+x+64 end
local specs={
 {id='healing_machine',class='bookcase',rows={{28,29,30,31},{44,45,46,47},{60,61,61,63},{76,77,78,79}}},
 {id='center_pc',class='bookcase',rows={{32,33},{48,49},{64,65}}},
 {id='medical_cabinet',class='bookcase',rows={{4,5},{20,21},{10,11},{26,27}}},
 -- Only the actual dispenser pixels are claimed. Wall/floor to the left
 -- of the narrow stem is context, never part of this object.
 {id='water_dispenser',class='bookcase',rows={{false,15},{false,15},{3,37},{19,53},{70,71}}},
 {id='counter_ball',class='counter',rows={{12},{36}}},
 {id='waiting_bench',class='table',rows={{72,73},{88,89}}},
}

local function model(spec,perRow,w,h)
 local out={}
 local box=G.geometryWriter(out,8192)
 local function pos(x,y)
  local tile=spec.rows[floor(y/8)+1][floor(x/8)+1]
  assert(tile,'source donor in unclaimed context')
  return (tile%perRow)*8+x%8,floor(tile/perRow)*8+y%8
 end
 local function donor(x,y)local ax,ay=pos(x,y);return G.texelUV(ax,ay,w,h)end
 local function uv(x,y,n)
  local ax,ay=pos(x,y)
  return {{(ax+.05)/w,(ay+.95)/h},{(ax+n-.05)/w,(ay+.95)/h},
   {(ax+n-.05)/w,(ay+.05)/h},{(ax+.05)/w,(ay+.05)/h}}
 end
 local function face(a,b,c,d,texture,shade)
  out[#out+1]={a,b,c,d,uv=texture,shade=shade or 1,own=true}
 end
 local function panel(x0,x1,s0,s1,base,front,depth)
  local function at(x,y)
   if x<x0 or x>x1 or y<s0 or y>s1 then return front-1.25 end
   return front+(depth and depth(x,y)or 0)
  end
  for sy=s0,s1 do
   local y=base+s1-sy;local x=x0
   while x<=x1 do
    local z=at(x,sy);local n=1
    while x+n<=x1 and floor(x/8)==floor((x+n)/8)and at(x+n,sy)==z do n=n+1 end
    face({x,y,z},{x+n,y,z},{x+n,y+1,z},{x,y+1,z},uv(x,sy,n))
    x=x+n
   end
   for xx=x0,x1 do
    local z=at(xx,sy);local t=donor(xx,sy);local n=at(xx-1,sy)
    if z>n then face({xx,y,n},{xx,y,z},{xx,y+1,z},{xx,y+1,n},t,.76)end
    n=at(xx+1,sy)
    if z>n then face({xx+1,y,z},{xx+1,y,n},{xx+1,y+1,n},{xx+1,y+1,z},t,.84)end
    n=at(xx,sy-1)
    if z>n then face({xx,y+1,n},{xx+1,y+1,n},{xx+1,y+1,z},{xx,y+1,z},t,.95)end
    n=at(xx,sy+1)
    if z>n then face({xx,y,z},{xx+1,y,z},{xx+1,y,n},{xx,y,n},t,.65)end
   end
  end
 end
 local function surface(x0,x1,s0,s1,y,z0)
  for sy=s0,s1 do
   local x=x0
   while x<=x1 do
    local n=min(x1-x+1,8-x%8);local u=uv(x,sy,n);local z=z0+sy-s0
    face({x,y,z},{x+n,y,z},{x+n,y,z+1},{x,y,z+1},{u[4],u[3],u[2],u[1]},.96)
    x=x+n
   end
  end
 end
 if spec.id=='healing_machine'then
  -- A deep treatment bay with raised cheeks and a separate rear control
  -- head replaces the old full-height bookcase extrusion of this drawing.
  local enamel=donor(2,16);local dark=donor(12,16)
  box(1,2,17,31,10,31,enamel)
  box(1,10,17,5,12,32,enamel);box(27,10,17,31,12,32,enamel)
  box(5,10,17,27,12,20,enamel)
  box(5,10,29,27,12,32,enamel)
  box(5,9.5,20,27,10,29,dark)
  surface(5,26,17,25,10.02,20)
  -- Lower the control head three pixels; preserve its artwork proportions
  -- and the treatment surface/counter datum instead of scaling the object.
  -- The source pixel at (10,2) is the console's outline black. Using it as
  -- a box material turned every off-axis case face into a featureless black
  -- slab. Keep outline black on the detailed front panel only; the case and
  -- its sides use the machine's own mid-grey enamel.
  box(1,12,17,31,22,20.75,enamel)
  panel(1,30,0,9,12,22,function(x,y)
   if ((x>=3 and x<=8)or(x>=23 and x<=28))and y>=3 and y<=7 then return -.75 end
   if x>=11 and x<=20 and y>=2 and y<=5 then return -.5 end
   return 0
  end)
  panel(1,30,28,31,0,32)
 elseif spec.id=='center_pc'then
  local body=donor(1,4)
  -- Terminal pedestal, sloped-use keyboard shelf and a separate CRT hood.
  box(3,0,10,13,10,20,donor(4,18))
  panel(3,12,18,23,0,21)
  box(1,10,9,15,11,23,body)
  box(1,11,9,15,22,14.75,body)
  surface(1,14,0,2,22.015,9)
  panel(1,14,3,13,11,16,function(x,y)
   if x>=3 and x<=12 and y>=5 and y<=9 then return -.8 end
   return 0
  end)
  surface(1,14,14,17,11.02,18)
 elseif spec.id=='medical_cabinet'then
  -- (2,18) is another outline-black pixel. It made the cabinet beside the
  -- nurse look like a wall-sized black box whenever its side was visible.
  local body=donor(4,26)
  box(1,1,17,15,24,29.75,body)
  surface(1,14,0,1,24.015,18)
  panel(1,14,8,31,0,31,function(x,y)
   if x>=3 and x<=12 and y>=9 and y<=14 then return -.7 end
   if x>=11 and x<=12 and y>=18 and y<=25 then return .3 end
   return 0
  end)
 elseif spec.id=='water_dispenser'then
  -- Compact reservoir above a real base. Repeated 0F stem artwork is a
  -- short neck, not two extra 16px wall columns above the counter.
  local body=donor(1,34)
  -- Keep it visibly subordinate to the healing station: the older 14x23
  -- volume read as a giant blue tank from the lobby camera.
  box(3,0,27,13,7,37.5,body)
  panel(3,12,32,39,0,38)
  local cx,cz,r=8,32,4.5
  for i=0,11 do
   local a,b=i*math.pi/6,(i+1)*math.pi/6
   local x0,z0=cx+r*math.cos(a),cz+r*math.sin(a)
   local x1,z1=cx+r*math.cos(b),cz+r*math.sin(b)
   -- Keep the reservoir's actual blue/lavender shades, not its white
   -- background. Four source-owned bands retain the glass/water reading.
   local blue=donor(4,21);local pale=donor(3,27);local rim=donor(2,18)
   local bands={{7,8.5,blue},{8.5,13.5,i==2 and pale or blue},{13.5,15,pale},{15,16,rim}}
   for _,band in ipairs(bands)do
    face({x0,band[1],z0},{x1,band[1],z1},{x1,band[2],z1},{x0,band[2],z0},band[3],.9)
   end
   face({cx,16,cz},{x0,16,z0},{x1,16,z1},{cx,16,cz},rim,.97)
  end
  box(6,16,30,10,19,34,donor(12,3))
  -- Original dark dispensing recess and source-colored tap, facing lobby.
  box(5,8,36.8,11,12.5,38.5,donor(7,23))
  box(7,9,38.5,9,11,39.5,donor(6,18))
 elseif spec.id=='waiting_bench'then
  -- The waiting-room seat used to inherit the generic table extrusion: its
  -- outline pixel became a solid black block behind each visitor. Separate
  -- legs, cushion, arms and a raised back make the original 16px drawing a
  -- real two-person bench while keeping its exact source palette/footprint.
  local cushion=donor(5,2);local edge=donor(2,10);local trim=donor(2,1)
  for _,x in ipairs({2,12.5})do for _,z in ipairs({4,11.5})do
   box(x,0,z,x+1.5,4.2,z+1.5,edge)
  end end
  box(1.5,4,3,14.5,5.3,13.5,edge)
  box(2,5.3,3.5,14,6.1,12.8,cushion)
  box(1,5,3,3,9.2,13.5,trim);box(13,5,3,15,9.2,13.5,trim)
  box(2,6,12,4,14,14.5,edge);box(12,6,12,14,14,14.5,edge)
  box(3,7.2,12.2,13,13.5,14.2,cushion)
 elseif spec.id=='counter_ball'then
  box(0,0,0,8,8,16,donor(1,10))
  for z=0,8,8 do
   face({0,8.015,z},{8,8.015,z},{8,8.015,z+8},{0,8.015,z+8},donor(0,2),.96)
  end
  -- Its white counter background remains flat; the ball graphic itself
  -- becomes a low-poly volume over the existing eight-pixel counter height.
  local cx,cy,cz,r=4,10.7,8,2.7
  for lat=0,5 do for lon=0,11 do
   local function point(a,b)
    local p=-math.pi/2+a*math.pi/6;local t=b*math.pi/6
    return {cx+r*math.cos(p)*math.cos(t),cy+r*math.sin(p),cz+r*math.cos(p)*math.sin(t)}
   end
   local sy
   if lat==2 or lat==3 then sy=4 elseif lat<2 then sy=6 else sy=3 end
   face(point(lat,lon),point(lat,lon+1),point(lat+1,lon+1),point(lat+1,lon),donor(4,sy),.96)
  end end
 end
 return out
end

function M.build(S,map,data,perRow)
 if not(map and map.def and map.def.generation==2 and map.tileset and
  map.tileset.id=='TilesetPokecenter' and data)or S.outdoor or S.centerEquipmentVisuals then return 0 end
 local w,h=data:getDimensions();local row=perRow or 16
 local tw,th=map.def.width*4,map.def.height*4
 local report={fixtures=0,quads=0,models={},cornerFinish=0}
 for _,spec in ipairs(specs)do
  local bw,bh=#spec.rows[1],#spec.rows
  for z=0,th-bh do for x=0,tw-bw do
   local cells={};local valid=true
   for dy,tiles in ipairs(spec.rows)do for dx,tile in ipairs(tiles)do
    if tile then
     local k=key(x+dx-1,z+dy-1);local s=S.shapeAt[k]
     if S.skip[k] or S.tileAt[k]~=tile or not s or not s.authored or s.class~=spec.class
       or floor(tile/row)*8+8>h or(tile%row)*8+8>w then valid=false end
     cells[#cells+1]={x+dx-1,z+dy-1,k}
    end
   end end
   if valid and report.fixtures<M.MAX_FIXTURES then
    local quads=model(spec,row,w,h)
    if #quads<=M.MAX_FIXTURE_QUADS and report.quads+#quads<=M.MAX_MAP_QUADS then
     for _,c in ipairs(cells)do
      S.skip[c[3]]=true;S.ground[c[3]]=17
      S.shapeAt[c[3]]={class='building',art='building',authored=true,flat=false,
       h=spec.id=='counter_ball'and 8 or spec.id=='waiting_bench'and 14 or 0}
     end
     for _,q in ipairs(quads)do
      for i=1,4 do q[i][1]=q[i][1]+x*8;q[i][3]=q[i][3]+z*8 end
      S.objectQuads[#S.objectQuads+1]=q
     end
     report.fixtures=report.fixtures+1;report.quads=report.quads+#quads
     report.models[#report.models+1]={id=spec.id,x=x,z=z,quads=#quads}
    end
   end
  end end
 end
 -- The southeast join is viewed almost edge-on from the lobby. Two native
 -- shell volumes meet there and their outline-black end caps can win the
 -- depth test over the otherwise complete wallpaper, producing the remaining
 -- black rectangle beside the exit. Seal only this proven standard-Center
 -- corner with a shallow L-shaped finish, inset toward the room so it cannot
 -- z-fight. No map tile, interaction, warp or collision is changed.
 local d=map.def
 if report.fixtures==11 and d.width==5 and d.height==4 and d.environment=='INDOOR'and type(map.tileAt)=='function'
    and map:tileAt(18,15)==0x11 and map:tileAt(19,15)==0x11 then
  local coral=G.texelUV((2%row)*8,0,w,h);local red=G.texelUV((2%row)*8+6,7,w,h)
  local south=d.height*4*8-.2
  -- This shell's east run ends at front=17, so its visible inner plane is
  -- x=144 rather than the synthetic boundary at x=160.
  local east=(d.width*4-2)*8-.2
  local function southFace(x0,y0,x1,y1,material)
   S.objectQuads[#S.objectQuads+1]={{x1,y0,south},{x0,y0,south},{x0,y1,south},{x1,y1,south},
    uv=material,shade=.94,own=true,roomRole='center_corner_finish'}
  end
  local function eastFace(z0,y0,z1,y1,material)
   S.objectQuads[#S.objectQuads+1]={{east,y0,z1},{east,y0,z0},{east,y1,z0},{east,y1,z1},
    uv=material,shade=.94,own=true,roomRole='center_corner_finish'}
  end
  -- Right of the paired exit is a continuous undecorated wall behind the
  -- waiting benches. Finish the full span, not just the geometric corner.
  -- The paired exit occupies x5..9. Finish both undecorated spans on the
  -- exact same plane, including the west shell's four-cell render apron.
  -- That apron is what the south-looking camera sees to the right of the
  -- door; leaving it unclad exposes the native black void/end face.
  for x=-4,4 do southFace(x*8,0,(x+1)*8,16,coral);southFace(x*8,16,(x+1)*8,17,red)end
  for x=10,19 do southFace(x*8,0,(x+1)*8,16,coral);southFace(x*8,16,(x+1)*8,17,red)end
  -- Begin immediately south of the PC footprint (z1..3); the rest of the
  -- east wall is undecorated and needs the same flush lower finish.
  for z=5,16 do eastFace(z*8,0,(z+1)*8,16,coral);eastFace(z*8,16,(z+1)*8,17,red)end
  -- Close the north-facing end of that recessed run as well; this is the
  -- face seen as a black rectangle when looking south toward the exit.
  -- The captured east shell run reports front=17: its exposed south end is
  -- therefore at z=136, one cell beyond the nominal room boundary. Clad that
  -- actual end cap; the earlier z=80 guess left the black face untouched.
  local cap=17*8-.2
  local function capFace(x0,y0,x1,y1,material)
   S.objectQuads[#S.objectQuads+1]={{x1,y0,cap},{x0,y0,cap},{x0,y1,cap},{x1,y1,cap},
    uv=material,shade=.94,own=true,roomRole='center_corner_finish'}
  end
  for x=18,19 do capFace(x*8,0,(x+1)*8,16,coral);capFace(x*8,16,(x+1)*8,17,red)end
  report.cornerFinish=66;report.quads=report.quads+66
 end
 S.centerEquipmentVisuals=report
 return report.quads
end
return M
