-- Source-authored masonry for the flanks of recognized Gen2 buildings.
-- The original voxel emitter supplies the closed shell, UVs and curve-safe
-- merging. This changes occupancy, not a second layer pasted over a wall.
local M={}
local floor=math.floor

-- The Center's front is intentionally brick, but extending that elevation
-- texture down both flanks turns a nearby side wall into one enormous brick
-- billboard.  Keep the native occupancy/closure and replace only exposed
-- wall-side texels with the facade's dominant painted wall shade.
local function cleanCenterFlanks(model,sp,pr,t)
 if not(t and t.id=='johto_pokecenter')or model.gen2CleanCenterFlanks
  or not(model and model.at and sp and pr)then return model end
 local wallH=pr.ground-t.roofRows
 local counts,donors={},{ }
 for sy=t.roofRows,pr.ground-1 do for sx=0,sp.W-1 do
  local i=sy*sp.W+sx
  if sp.inside[i]and sp.col[i]~=3 then
   local shade=sp.col[i];counts[shade]=(counts[shade]or 0)+1
   donors[shade]=donors[shade]or i
  end
 end end
 local best
 for shade,n in pairs(counts)do
  if not best or n>best.n then best={shade=shade,n=n}end
 end
 local plaster=best and donors[best.shade]
 if not plaster then return model end
 local sides={}
 for y=2,wallH-3 do
  local left,right
  for x=0,sp.W-1 do if model.at(x,y,math.floor(pr.D/2))~=nil then
   left=left or x;right=x
  end end
  if left and right-left>=8 then sides[y]={left,right}end
 end
 local old=model.at;local wrapped={};for k,v in pairs(model)do wrapped[k]=v end
 wrapped.at=function(x,y,z)
  local value=old(x,y,z);if value==nil then return nil end
  local side=sides[y]
  if side and z>=2 and z<pr.D-2 and (x==side[1]or x==side[2])then
   return plaster
  end
  return value
 end
 wrapped.gen2CleanCenterFlanks={template=t.id,texel=plaster,rows=sides}
 return wrapped
end

local function eligible(t)
 local id=t and t.id or ''
 -- Pokemon Centers keep their brick identity on the front elevation, but
 -- the side is a clean structural plane.  Reusing the facade brick course
 -- here produced literal projecting bricks around the whole flank.
 if id=='johto_pokecenter' then return false end
 local family=id:match('^johto_(.+)') or id:match('^kanto_(.+)') or id:match('^modern_(.+)')
 return family and (family:match('^house') or family:match('^block') or
  family:match('^mart') or family:match('^pokecenter') or family:match('^center') or
  family:match('^office') or family:match('^civic') or family:match('^gym'))
  and not(t.parts or t.desk or t.claimOnly or t.topRows)
  and (t.roofRows or 0)>=8
end

-- Brick artwork has broad painted faces separated by fine pale joints.
-- Requiring repeated complete tiles, no dark frame, and full mortar rows
-- excludes windows, doors, signs, sparse plaster speckles and timber lattice.
local function masonry(sp,sx,sy)
 local white,paint,black,rows=0,0,0,0
 for y=0,7 do
  local pale=0
  for x=0,7 do
   local i=(sy+y)*sp.W+sx+x
   if not sp.inside[i] then return false end
   local c=sp.col[i]
   if c==0 then white=white+1;pale=pale+1
   elseif c==3 then black=black+1 else paint=paint+1 end
  end
  if pale==8 then rows=rows+1 end
 end
 return paint>=32 and white>=8 and black<=2 and rows>=1 and rows<=3
end

function M.wrapModel(model,sp,pr,t)
 model=cleanCenterFlanks(model,sp,pr,t)
 if not eligible(t) or sp.W<24 or pr.D<16 or sp.H>96 then return model end
 local bands={}
 for sy=math.ceil(t.roofRows/8)*8,pr.ground-8,8 do
  local repeated={}
  for sx=8,sp.W-16,8 do
   local i=sy*sp.W+sx
   local k=tostring(sp.ax[i])..':'..tostring(sp.ay[i])
   local hit=repeated[k]
   if hit then hit.n=hit.n+1 else repeated[k]={x=sx,y=sy,n=1}end
  end
  local best
  for _,candidate in pairs(repeated)do
   if candidate.n>=2 and masonry(sp,candidate.x,candidate.y)
      and (not best or candidate.n>best.n or
       (candidate.n==best.n and candidate.x<best.x))then best=candidate end
  end
  if best then
   best.texels={}
   for py=0,7 do for px=0,7 do
    local i=(sy+py)*sp.W+best.x+px
    best.texels[sp.col[i]]=best.texels[sp.col[i]] or i
   end end
   bands[sy]=best
  end
 end
 if not next(bands)then return model end
 local rows={}
 for y=2,pr.ground-t.roofRows-3 do
  local sy=pr.ground-1-y
  local source=bands[floor(sy/8)*8]
  if source then
   local left,right
   for x=0,sp.W-1 do
    if model.at(x,y,floor(pr.D/2))~=nil then left=left or x;right=x end
   end
   if left and right-left>=8 then rows[y]={left=left,right=right,source=source,sy=sy}end
  end
 end
 if not next(rows)then return model end
 local wrapped={}
 for k,v in pairs(model)do wrapped[k]=v end
 local original=model.at
 wrapped.at=function(x,y,z)
  local old=original(x,y,z)
  if old==nil then return nil end
  local row=rows[y]
  if not row or z<2 or z>=pr.D-2 then return old end
  local side=(x==row.left or x==row.right)
  local backing=(x==row.left+1 or x==row.right-1)
  if not(side or backing)then return old end
  -- A side-wall brick is two world voxels per source pixel: readable courses
  -- at headset distance, and fewer joints than a one-voxel micro-brick wall.
  local sx=row.source.x+(floor(z/2)%8)
  local sy=row.source.y+(floor(row.sy/2)%8)
  local i=sy*sp.W+sx
  -- A pale mortar pixel retreats one voxel; the neighboring backing
  -- remains filled, so the native emitter closes the joint and its reveals.
  if side and sp.col[i]==0 then return nil end
  -- Identical source shades share a texel within this exact tile. That
  -- permits the native emitter to merge long brick faces instead of
  -- retaining a separate surface for every visually identical pixel.
  return row.source.texels[sp.col[i]] or i
 end
 wrapped.gen2Masonry={template=t.id,rows=rows,bands=bands}
 return wrapped
end
return M
