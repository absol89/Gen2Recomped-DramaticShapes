-- Exact native columns whose measured height includes two synthetic rows
-- outside the map. Preserve every in-map artwork band; discard only proven
-- uniform-black outside samples. Post-volume render metadata correction.
local M={MAX_COLUMNS=512}
local function key(x,z)return(z+64)*4096+x+64 end
local function clone(t)local out={};for k,v in pairs(t)do out[k]=v end;return out end
local function sameRun(a,b)
 if not a or not b then return false end
 for _,k in ipairs({'north','front','h','base','rise','unit','extent','roofRows','fromRepeat','door'})do
  if a[k]~=b[k]then return false end
 end
 return true
end
function M.build(S,map,data,perRow)
 if not(map and map.def and map.def.generation==2 and map.tileset and data and data.getPixel)
    or S.outdoor or S.exactNorthCaps or not S.runs then return 0 end
 if type(map.warpAtCell)~='function' or type(map.isWarpTileCell)~='function' then return 0 end
 perRow=perRow or 16;local w,h=data:getDimensions()
 if perRow~=16 or w<128 then return 0 end
 local report={count=0,columns={},trimmedPixels=0,pixelReads=0}
 local cache={}
 local function blank(t)
  if type(t)~='number' or t<0 or t~=math.floor(t)then return false end
  if cache[t]~=nil then return cache[t]end
  local ax,ay=t%16*8,math.floor(t/16)*8
  if ax+8>w or ay+8>h then return false end
  local first
  for y=0,7 do for x=0,7 do
   local r,g,b,a=data:getPixel(ax+x,ay+y);report.pixelReads=report.pixelReads+1
   if a<.999 or math.min(r,g,b)<0 or math.max(r,g,b)>.1 then cache[t]=false;return false end
   if first and math.max(math.abs(r-first[1]),math.abs(g-first[2]),math.abs(b-first[3]))>1/255 then cache[t]=false;return false end
   first=first or {r,g,b}
  end end
  cache[t]=true;return true
 end
 for x=0,map.def.width*4-1 do
  if report.count<M.MAX_COLUMNS then
   local run=S.runs[key(x,0)]
   -- A valid candidate is exactly two synthetic north rows plus one to six
   -- real map rows.  The run itself supplies the finite pattern length;
   -- every retained row is then re-proved against the map below.
   local n=run and run.front+1 or 0
   local valid=run and run.north==-2 and run.front==n-1 and run.extent==n+2
     and run.unit==n+2 and run.h==(n+2)*8 and run.base==0 and run.rise==0
     and n>=1 and n<=6 and run.roofRows==0 and run.fromRepeat==false and not run.door
   for z=-2,n-1 do
    local k=key(x,z);local s=S.shapeAt[k]
    if not s or s.authored or s.flat or s.art~='upright' or S.skip[k]
      or (S.doorFold and S.doorFold[k]) or not sameRun(run,S.runs[k])
      or s.class~=(z<0 and 'shell' or 'wall') then valid=false end
    if z>=0 then
     if S.tileAt[k]~=map:tileAt(x,z)
       or map:warpAtCell(math.floor(x/2),math.floor(z/2))
       or map:isWarpTileCell(math.floor(x/2),math.floor(z/2)) then valid=false end
    elseif not blank(map:tileAt(x,z))then valid=false end
   end
   if valid then
    -- Never mutate the native shared run object: sibling regions, callers
    -- and diagnostic snapshots can retain references to it.
    local body=clone(run);body.north=0;body.extent=n;body.unit=n;body.h=n*8;body.peak=body.h
    local shell=clone(run);shell.front=-1;shell.extent=2;shell.unit=2;shell.h=16;shell.peak=16
    for z=0,n-1 do S.runs[key(x,z)]=body end
    S.runs[key(x,-2)]=shell;S.runs[key(x,-1)]=shell
    report.columns[x]={height=body.h,frontDepth=n*8,oldHeight=run.h}
    report.count=report.count+1;report.trimmedPixels=report.trimmedPixels+16
   end
  end
 end
 S.exactNorthCaps=report
 return report.count
end
return M
