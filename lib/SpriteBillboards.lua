-- Voxel world mode: characters as flat forward-facing sprite billboards.
--
-- Gen2 patch: SPRITE_BIG_SNORLAX / SPRITE_BIG_LAPRAS (and any def.big sheet)
-- are 32x32 over a 2x2 cell footprint.  The stock card was hard-coded 16x16
-- and only sampled the top-left face tile — that is why DramaticShapes showed
-- a quarter of Snorlax.  Big sheets get a 32x32 card; 16-wide mirrored strips
-- get a dual-quad card that mirrors the left half in UV space.

local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local SpriteBillboards = {}

local meshes = {}

local function isBigDef(def)
  if not def then return false end
  if def.big then return true end
  local id = def.id or ""
  return id == "SPRITE_BIG_SNORLAX"
    or id == "SPRITE_BIG_LAPRAS"
    or id == "SPRITE_BIG_DOLL"
end

-- Standard 16x16 walker frame (Gen1 / normal Gen2 NPCs).
local function buildCard16(img, frame)
  local iw, ih = img:getDimensions()
  local fy = frame * 16
  if fy + 16 > ih then fy = 0 end
  local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
  local verts = {
    { 0, 0, 0, u0, v1, 1 }, { 16, 0, 0, u1, v1, 1 },
    { 16, 16, 0, u1, v0, 1 }, { 0, 16, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

-- Full 32x32 body (extractor already mirrored the left half into the sheet).
local function buildCard32(img)
  local iw, ih = img:getDimensions()
  local u0, u1 = 0.02 / iw, (math.min(32, iw) - 0.02) / iw
  local v0, v1 = 0.05 / ih, (math.min(32, ih) - 0.05) / ih
  local verts = {
    { 0, 0, 0, u0, v1, 1 }, { 32, 0, 0, u1, v1, 1 },
    { 32, 32, 0, u1, v0, 1 }, { 0, 32, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

-- 16x32 left-half strip: two side-by-side quads, right one mirrors U.
local function buildCardMirrored16x32(img)
  local iw, ih = img:getDimensions()
  local h = math.min(32, ih)
  local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
  local v0, v1 = 0.05 / ih, (h - 0.05) / ih
  -- left half
  local verts = {
    { 0, 0, 0, u0, v1, 1 }, { 16, 0, 0, u1, v1, 1 },
    { 16, h, 0, u1, v0, 1 }, { 0, h, 0, u0, v0, 1 },
    -- right half = mirror of left (u1→u0)
    { 16, 0, 0, u1, v1, 1 }, { 32, 0, 0, u0, v1, 1 },
    { 32, h, 0, u0, v0, 1 }, { 16, h, 0, u1, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  Voxel3D.pushQuad(indices, 4)
  return Voxel3D.newMesh(verts, indices)
end

local function buildCard(def, frame)
  local ok, img = pcall(Assets.image, def.image)
  if not (ok and img) then return nil end
  local iw, ih = img:getDimensions()

  if isBigDef(def) or iw >= 32 then
    if iw >= 32 and ih >= 32 then
      return buildCard32(img)
    end
    -- Still a 16-wide FacingBigDollSymmetric strip
    return buildCardMirrored16x32(img)
  end

  return buildCard16(img, frame or 0)
end

function SpriteBillboards.mesh(def, frame)
  local big = isBigDef(def)
  local key = def.image .. "#" .. (big and "big" or tostring(frame))
  if meshes[key] == nil then
    local ok, m = pcall(buildCard, def, frame)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

SpriteBillboards.shadowQuad = SpriteBillboards.mesh

function SpriteBillboards.invalidate()
  meshes = {}
end

-- World-space half-width used by VoxelScene to centre the card on the
-- footprint (8 for 16px walkers, 16 for 32px big dolls).
function SpriteBillboards.halfWidth(def)
  if isBigDef(def) then return 16 end
  return 8
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
