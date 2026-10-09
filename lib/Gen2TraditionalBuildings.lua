-- Six exact native Ecruteak templates. Native emitter owns closure/UVs.
-- No map, collision, placement, draw call or per-frame state changes.
local M={}
local floor,min,max=math.floor,math.min,math.max
local allowed={johto_ecruteak_house=true,johto_ecruteak_house_crystal=true,
 johto_ecruteak_hall=true,johto_ecruteak_hall_crystal=true,
 johto_ecruteak_wall=true,johto_ecruteak_wall_crystal=true}
local pagodas={johto_pagoda=true,johto_pagoda_crystal=true,
 johto_pagoda_tall=true,johto_pagoda_tall_crystal=true,
 johto_pagoda_burned_crystal=true}

local function pagodaModel(model,sp,pr,t)
 if not(t and pagodas[t.id]) or model.gen2Pagoda or t.parts or t.claimOnly
  or t.roofRows~=32 or not(sp and pr and model.at) or sp.W~=64 or pr.D<24 then return model end
 local wallH=pr.ground-t.roofRows
 if wallH<16 then return model end
 local storeys=math.max(1,math.floor((wallH+8)/16))
 local tallLandmark=t.id:match('^johto_pagoda_tall')and storeys>=7
 -- Sprout Tower contains three interior maps, but the source compresses all
 -- three exterior tiers into sixteen pixels apiece.  Give each tier four
 -- more vertical voxels so the entrance level reads as a complete storey
 -- instead of an awning beneath two upper boxes.  The mapping only repeats
 -- authored source rows; no new colors, windows, footprint or collision.
 local stretch=tallLandmark and 8
  or (t.id=='johto_pagoda_crystal' and storeys==3 and wallH==48)and 4 or 0
 local visualWallH=wallH+storeys*stretch
 -- The approach camera sits below the near eave, so a token eight-voxel mast
 -- disappears behind the roof.  The landmark references use a deliberately
 -- tall pagoda finial; sixteen voxels keeps it visible from ground level.
 local finialHeight=stretch>0 and 16 or 0
 -- The source repeats one sixteen-pixel storey per tier.  The front already
 -- shows those eaves; the old extrusion ignored them on the flanks and made
 -- every tower one uninterrupted wall.  Recess only the side wall between
 -- each authored eave, leaving the source facade, roof, foundation and
 -- footprint unchanged.
 local sides={}
 for y=1,wallH-1 do
  local left,right
  for x=0,sp.W-1 do if model.at(x,y,math.floor(pr.D/2))~=nil then left=left or x;right=x end end
  if left and right and right-left>8 then sides[y]={left,right} end
 end
 local old=model.at
 local finialValue
 if finialHeight>0 then
  for y=model.ytop,wallH,-1 do for z=0,pr.D do for x=0,sp.W-1 do
   finialValue=old(x,y,z)or finialValue
  end end end
 end
 local wrapped={};for k,v in pairs(model)do wrapped[k]=v end
 local roofTop=model.ytop+storeys*stretch
 wrapped.ytop=roofTop+finialHeight
 wrapped.at=function(x,y,z)
  if finialHeight>0 and y>roofTop then
   local fy=y-roofTop;local cx,cz=math.floor(sp.W/2),math.floor(pr.D/2)
   if fy==1 then return (math.abs(x-cx)<=3 and math.abs(z-cz)<=3)and finialValue or nil end
   if fy==2 then return (math.abs(x-cx)<=2 and math.abs(z-cz)<=2)and finialValue or nil end
   if fy<=12 then return (math.abs(x-cx)<=1 and math.abs(z-cz)<=1)and finialValue or nil end
   return (x==cx and z==cz)and finialValue or nil
  end
  local sy=y
  local visualTier
  if stretch>0 then
   if y<visualWallH then
    visualTier=math.floor(y/(16+stretch));local within=y%(16+stretch)
    sy=visualTier*16+math.min(15,math.floor(within*16/(16+stretch)))
   else sy=y-storeys*stretch end
  end
  local value=old(x,sy,z);if value==nil then return nil end
  -- The Violet horizon landmark establishes Sprout Tower as a stepped
  -- three-tier pagoda, not a single-width office block.  Preserve the broad
  -- authored eave at the foot of every tier, then inset the occupied wall by
  -- two voxels per ascending floor.  Native voxel closure supplies the newly
  -- exposed side faces; placement and collision keep the original footprint.
  if visualTier and visualTier>0 and (sy%16)>=3 then
   local inset=(tallLandmark and math.floor(visualTier/2)or visualTier)*4
   if x<inset or x>=sp.W-inset then return nil end
  end
  local side=sides[sy]
  if not side or z<=2 or z>=pr.D-1 then return value end
  local phase=sy%16
  -- Three-pixel eaves remain proud. Between them the side steps inward two
  -- pixels, enough for each floor to read separately in VR without opening
  -- a hole through the closed native shell.
  if phase>=3 and phase<=13 and (x==side[1]or x==side[2])then return nil end
  if phase>=5 and phase<=11 and (x==side[1]+1 or x==side[2]-1)then return nil end
  return value
 end
 wrapped.gen2Pagoda={template=t.id,storeys=storeys,tallLandmark=tallLandmark or false,
  sourceWallH=wallH,wallH=visualWallH,
  storeyHeight=16+stretch,finialHeight=finialHeight}
 return wrapped
end
function M.wrapModel(model,sp,pr,t)
 local pagoda=pagodaModel(model,sp,pr,t)
 if pagoda~=model then return pagoda end
 if not(t and allowed[t.id]) or model.gen2Traditional or t.parts or t.topRows or t.claimOnly
  or t.roofRows~=32 or t.slab~=4 or not(sp and pr and model.at)
  or sp.H~=48 or (sp.W~=64 and sp.W~=96) or pr.D~=48
  or not pr.top or not pr.shadeTexel or not pr.interior then return model end
 local wallH=pr.ground-t.roofRows
 if wallH<8 or wallH>16 then return model end
 -- Choose real painted texels from the authored facade, never roof outline
 -- black. Restrict to its left side panel so a central door is not a donor.
 local donor={}
 for y=32,sp.H-1 do for x=0,15 do local i=y*sp.W+x
  if sp.inside[i] and sp.col[i]~=3 then donor[sp.col[i]]=donor[sp.col[i]]or i end
 end end
 local wood=donor[2] or donor[1]
 local plaster=donor[1] or donor[0] or donor[2]
 if not wood or not plaster then return model end
 local lift={}
 for z=model.zmin,model.zmax do
  local d=min(z,pr.D-1-z)
  -- Low, slightly swept eaves; broad ridge. Ends and front extension stay
  -- exactly where native placement put them. Maximum rise is ten pixels.
  local f=max(0,min(1,(d-2)/(pr.D/2-3)))
  lift[z]=floor(10*(f^.82)+.5)
 end
 local sides={}
 for y=3,wallH-3 do
  local left,right
  for x=0,sp.W-1 do if model.at(x,y,24)~=nil then left=left or x;right=x end end
  if left and right-left>=16 then sides[y]={left,right}end
 end
 local wrapped={};for k,v in pairs(model)do wrapped[k]=v end
 wrapped.ytop=model.ytop+10
 local old=model.at
 wrapped.at=function(x,y,z)
  if x<0 or x>=sp.W or y<0 or y>wrapped.ytop or z<model.zmin or z>model.zmax then return nil end
  local offset=lift[z]or 0
  local roofTop=pr.ytop-pr.top[x]
  if pr.top[x]<32 and offset>0 and y>roofTop-t.slab then
   local newTop=roofTop+offset
   if y>newTop then return nil end
   if y>newTop-t.slab then return old(x,y-offset,z)end
   -- Solid triangular end/gable infill closes the raised roof, and the
   -- native hidden-face pass culls everything except the visible ends.
   return wood
  end
  local value=old(x,y,z)
  if value==nil then return nil end
  local side=sides[y]
  if side and z>=3 and z<pr.D-3 then
   local outer=x==side[1] or x==side[2]
   local inner=x==side[1]+1 or x==side[2]-1
   if outer or inner then
    local post=(z%12)<2 or y==3 or y==wallH-3
    if outer and not post then
     local backing=x==side[1] and x+1 or x-1
     if old(backing,y,z)~=nil then return nil end
     return value -- never perforate a one-voxel authored edge
    end
    return post and wood or plaster
   end
  end
  return value
 end
 wrapped.gen2Traditional={template=t.id,rise=10,lift=lift,wallH=wallH,sideRows=sides}
 return wrapped
end
return M
