-- Conservative visual markers for proven paired south-boundary building exits.
-- Gen2 warp coordinates are16px cells; map dimensions are32px blocks.
-- No collision edits, engine requires or per-frame work. Interior destinations
-- (including boundary stairs), caves and unpaired exits are left unchanged.
local M={MAX_WARPS=128,MAX_DOORS=8,MAX_DIMENSION=256}
local floor=math.floor
local function integer(n)return type(n)=='number'and n==n and n>=0 and n<math.huge and n==floor(n)end
local function outside(id)
 return type(id)=='string'and #id>0 and #id<=128
  and(id:match('^[A-Z0-9_]+_TOWN$')or id:match('^[A-Z0-9_]+_CITY$')or id:match('^ROUTE_%d+$'))
end
function M.collect(map)
 local function reject(reason)return{},reason end
 if type(map)~='table'or type(map.def)~='table'then return reject('map definition unavailable')end
 local d=map.def
 if d.environment~='INDOOR'or d.outdoor==true then return reject('unproven indoor environment')end
 if d.connections and(type(d.connections)~='table'or next(d.connections))then return reject('connected map excluded')end
 if not integer(d.width)or not integer(d.height)or d.width<1 or d.height<1
  or d.width>M.MAX_DIMENSION or d.height>M.MAX_DIMENSION then return reject('invalid map bounds')end
 local warps=d.warps
 if type(warps)~='table'then return reject('warp metadata unavailable')end
 -- Inspect the table shape, not only #/ipairs: sparse or keyed records fail
 -- closed rather than silently overlooking duplicates or malformed entries.
 local count=0
 for k in pairs(warps)do
  count=count+1
  if count>M.MAX_WARPS or not integer(k)or k<1 or k>M.MAX_WARPS then return reject('warp list malformed or over budget')end
 end
 if count~=#warps then return reject('sparse warp list')end
 local width,height=d.width*2,d.height*2
 local seen,candidates={},{}
 for i=1,count do
  local w=warps[i]
  if type(w)~='table'or not integer(w.x)or not integer(w.y)
   or w.x>=width or w.y>=height then return reject('invalid warp coordinates')end
  local key=w.y*width+w.x
  if seen[key]then return reject('duplicate warp coordinates')end
  seen[key]=true
  if w.y==height-1 and outside(w.destMap)and integer(w.destWarp)and w.destWarp>=1 then
   candidates[#candidates+1]={x=w.x,destMap=w.destMap,destWarp=w.destWarp}
  end
 end
 table.sort(candidates,function(a,b)return a.x<b.x end)
 local doors={};local i=1
 while i<=#candidates do
  local first=i;local last=i
  while last<#candidates and candidates[last+1].x==candidates[last].x+1 do last=last+1 end
  -- Exactly two cells make one measured opening. A long carpet run is not
  -- guessed into multiple doors, even when alternating destinations match.
  if last-first+1==2 then
   local a,b=candidates[first],candidates[last]
   if a.destMap==b.destMap and a.destWarp==b.destWarp then
    if #doors>=M.MAX_DOORS then return reject('door count exceeds budget')end
    doors[#doors+1]={x0=a.x*16,x1=(b.x+1)*16,z=d.height*32,
     destMap=a.destMap,destWarp=a.destWarp}
   end
  end
  i=last+1
 end
 return doors,#doors>0 and 'paired south exits proven'or'no supported paired south exits'
end
return M
