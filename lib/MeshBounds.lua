-- Adapted from UNDERdecoded 4a114b3: conservative whole-mesh culling.
-- Bounds come from emitted vertices and survive the disk cache; no engine IDs.
-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Mat4 = V.require("Mat4")

local MeshBounds = {}

-- WEAK KEYS. A mesh released by the cache (setLive evicting a far map, a
-- slot swapped for a rebuilt one) must not be kept alive by its own
-- bounding box, and a box for a dead mesh must not accumulate over a
-- cross-region walk.
local boxes = setmetatable({}, { __mode = "k" })

function MeshBounds.set(mesh, box)
  if mesh and box then
    -- Slack covers float32 serialization and clip-plane rounding.
    boxes[mesh] = {box[1] - .01, box[2] - .01, box[3] - .01,
                  box[4] + .01, box[5] + .01, box[6] + .01}
  end
end

function MeshBounds.get(mesh)
  return mesh and boxes[mesh] or nil
end

-- Is this mesh's box entirely outside `vp`'s clip volume?
--
-- The standard conservative test: the box is hidden only when all eight
-- corners fall outside the SAME clip plane. A box that straddles two planes
-- without being inside is reported visible, which costs a draw and can
-- never cost a pixel.
--
-- No bitwise operators: LOVE ships LuaJIT 5.1 and `&` is a parse error
-- there, whatever a newer standalone build accepts.
function MeshBounds.hidden(mesh, vp, model)
  if not (mesh and vp) then return false end
  local b = boxes[mesh]
  if not b then return false end
  local m = model and Mat4.mul(vp, model) or vp
  local m1, m2, m3, m4 = m[1], m[2], m[3], m[4]
  local m5, m6, m7, m8 = m[5], m[6], m[7], m[8]
  local m9, m10, m11, m12 = m[9], m[10], m[11], m[12]
  local m13, m14, m15, m16 = m[13], m[14], m[15], m[16]
  local oL, oR, oB, oT, oN, oF = true, true, true, true, true, true
  for i = 0, 7 do
    local x = (i % 2 == 0) and b[1] or b[4]
    local y = (i >= 2 and i <= 3) or i >= 6
    y = y and b[5] or b[2]
    local z = (i < 4) and b[3] or b[6]
    local cx = m1 * x + m2 * y + m3 * z + m4
    local cy = m5 * x + m6 * y + m7 * z + m8
    local cz = m9 * x + m10 * y + m11 * z + m12
    local cw = m13 * x + m14 * y + m15 * z + m16
    if not (cx < -cw) then oL = false end
    if not (cx > cw) then oR = false end
    if not (cy < -cw) then oB = false end
    if not (cy > cw) then oT = false end
    if not (cz < -cw) then oN = false end
    if not (cz > cw) then oF = false end
    if not (oL or oR or oB or oT or oN or oF) then return false end
  end
  return oL or oR or oB or oT or oN or oF
end

return MeshBounds
