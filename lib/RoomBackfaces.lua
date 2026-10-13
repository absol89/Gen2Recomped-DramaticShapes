-- Encode inward room-shell normals in the existing shade float. Packed cache
-- vertices retain the marker without changing the six-float vertex format.
local M = {}
function M.shade(q, shades, roomCenter)
  if not q.oneSided then return shades end
  local a,b,c=q[1],q[2],q[3]
  local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3]
  local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
  local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
  local ax,ay,az=math.abs(nx),math.abs(ny),math.abs(nz)
  if math.max(ax,ay,az)<1e-8 then return shades end
  local direction
  if roomCenter then
    if ax>=ay and ax>=az then nx=roomCenter[1]-a[1]
    elseif ay>=az then ny=roomCenter[2]-a[2]
    else nz=roomCenter[3]-a[3] end
  end
  if ax>=ay and ax>=az then direction=nx>0 and 1 or 2
  elseif ay>=az then direction=ny>0 and 3 or 4
  else direction=nz>0 and 5 or 6 end
  local function encode(s) return -(direction*4+s) end
  if type(shades)=='table' then
    return {encode(shades[1]),encode(shades[2]),encode(shades[3]),encode(shades[4])}
  end
  return encode(shades)
end
return M
