-- The cast's PLANAR reflection: each card reflected in the water plane and
-- flipped, drawn into a canvas of its own, composited by the water shader at
-- each fragment's own screen position.
--
-- Why not a mirrored CAMERA, which is the obvious way: a character is a
-- billboard that leans back to face the camera, so a mirrored camera catches
-- it leaning away and lands a foreshortened sliver in the water. Correct for
-- the flat quad it really is, useless as a reflection of the person it is
-- pretending to be. A billboard is a fake that works from one side only, so
-- reflecting it has to be faked too: reflect the POSITION, keep the card
-- facing the camera, flip it about its own feet.
--
-- What is pinned here is the arithmetic and the wiring, which are the parts
-- a screenshot cannot check. The LOOK is not testable in this harness.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = os.getenv("DS_MOD_PATH") or "dev/BattleArtGen2"

local loaded = {}
local V = {
  mod = {
    id = "BATTLE_ART_VOXEL_GEN2",
    options = { get = function() return nil end },
  },
  -- the SHIPPED heights, not the fallbacks: the water plane this reflection
  -- is taken in is whatever data/voxel_heights.lua actually says
  data = function(name)
    return assert(loadfile(root .. "/data/" .. name .. ".lua"))()
  end,
}

local fakes = {
  Sky = {
    ramp = function() return { "ramp" }, 4 end,
    discRadius = function() return 4 end,
    discShades = function() return { { 255, 255, 255 } } end,
    GLOW_REACH = 0.5, MOON_CRATERS = {},
  },
  DayNight = {
    body = function() return nil end,
    glow = function() return 0, nil end,
  },
  ShadowMap = {
    active = function() return nil end,
    texture = function() return nil end,
    uvVP = nil, bias = 0.001, res = 1024,
  },
  Voxel3D = {
    FACE_SHADE = { 0.9, 0.8, 1.0, 1.0, 0.85, 0.95 },
    SHADOW_ALPHA = 0.5, tint = { 1, 1, 1 },
  },
  TerrainAtlas = { _animFrame = function() return 0 end },
}

function V.require(name)
  if fakes[name] then return fakes[name] end
  if loaded[name] then return loaded[name] end
  local chunk = assert(loadfile(root .. "/lib/" .. name .. ".lua"))
  local module = chunk(V)
  loaded[name] = module
  return module
end

-- ------- the reflected card
--
-- A card is a billboard leaning back to face the camera, so a mirrored
-- CAMERA catches it leaning away and lands a foreshortened sliver in the
-- water. The position is reflected instead and the card kept facing the
-- camera, then flipped about its own feet.

local Mat4 = V.require("Mat4")
local Water = V.require("Water")

local function apply(m, x, y, z)
  return m[1] * x + m[2] * y + m[3] * z + m[4],
         m[5] * x + m[6] * y + m[7] * z + m[8],
         m[9] * x + m[10] * y + m[11] * z + m[12]
end

-- the flip a reflected card carries: local y negated, so the mesh hangs from
-- its anchor instead of standing on it, and its texture comes with it
local flip = Mat4.scale(1, -1, 1)
local _, fy = apply(flip, 0, 5, 0)
T.eq(fy, -5, "the card flip negates local height")
local fx, _, fz = apply(flip, 3, 5, -4)
T.eq(fx, 3, "and leaves x alone")
T.eq(fz, -4, "and z")

-- the whole reflected transform, as billboardMatrix composes it
local PLANE = -2
local function reflected(px, py, y)
  return Mat4.mul(
    Mat4.billboard(px, py, 2 * PLANE - y + Water.CAST_RAISE, 0, 0, false),
    flip)
end

-- feet: the mesh stands on its own y = 0, so that vertex lands on the anchor
local _, feet = apply(reflected(0, 0, 6), 0, 0, 0)
T.eq(feet, 2 * PLANE - 6 + Water.CAST_RAISE,
  "the reflected feet sit at the mirrored height, lifted by the raise")

-- and the body hangs DOWN from there rather than standing up
local _, head = apply(reflected(0, 0, 6), 0, 10, 0)
T.check(head < feet, "the card hangs downward, so it reads upside down")
T.eq(head, 2 * PLANE - 6 + Water.CAST_RAISE - 10,
  "by exactly its own height")

-- a character standing ON the plane is its own reflection's anchor, which is
-- what keeps the waterline agreeing
local _, onPlane = apply(reflected(0, 0, PLANE), 0, 0, 0)
T.eq(onPlane, PLANE + Water.CAST_RAISE,
  "a card standing on the plane is anchored on it, plus the raise")

-- the flip must not shrink the card: a reflection is the same size as the
-- thing it reflects, which is the whole reason the camera is not mirrored
local upright = Mat4.billboard(0, 0, 0, 0, 0, false)
local _, uy = apply(upright, 0, 10, 0)
local _, ry = apply(reflected(0, 0, 0), 0, 10, 0)
T.eq(math.abs(uy - 0), math.abs(ry - (2 * PLANE + Water.CAST_RAISE)),
  "the reflected card is the same height as the upright one")

-- ------- surfing, where the player stands ON the water
--
-- The case that cannot be reached without Surf, so it is pinned here
-- instead. The numbers were measured in a real run rather than assumed:
-- groundAt returns 0 on a water cell, the surf bob spans -1..0, and the
-- water plane is -2, so the card's feet are at 0 and the player floats two
-- pixels over the surface they are sitting on.
--
-- Water is a recessed class and groundAt returns `s.h > 0 and s.h or 0`, so
-- a recessed class does not lower what stands on it. That float is where
-- the gap comes from.

local TileShape = V.require("TileShape")
local plane = TileShape.heights().water

T.check(plane < 0, "water is recessed below the ground it is cut into")
-- and it is the number the card section above reflected in, so the two
-- halves of this file cannot drift apart if the shipped heights change
T.eq(plane, PLANE, "the shipped water height is the plane the cards use")

local FLOAT = 0 - plane
T.eq(FLOAT, 2, "a surfing player floats two pixels over the surface")

-- A TRUE mirror doubles that float into open water between the two, which
-- is correct and looks wrong. CAST_RAISE is what closes it.
local function anchorFor(lift, raise)
  return 2 * plane - (0 + lift) + raise
end

T.eq(anchorFor(0, 0), plane - FLOAT,
  "an unraised reflection hangs a full float below the surface")
T.eq(0 - anchorFor(0, 0), 2 * FLOAT,
  "so the clear water between feet and reflection is twice the float")

-- the raise walks it back up, one world pixel at a time
T.eq(anchorFor(0, 2), plane, "raised by the float, it hangs from the waterline")
T.eq(anchorFor(0, 2 * FLOAT), 0,
  "raised by twice the float, it is joined at the character's own feet")
T.check(Water.CAST_RAISE >= 2 * FLOAT,
  "the shipped raise closes the geometric gap for a surfing player")

-- Past that it compensates for the sprite's own bottom padding, which the
-- card knows nothing about: whatever empty space the art carries under
-- itself shows once upright and once flipped. That is why the shipped value
-- is a measured number rather than a derived one.

-- the bob still mirrors, whatever the raise is: a mirror moves the other
-- way, so the pair open and close rather than sliding together
T.check(anchorFor(2, Water.CAST_RAISE) < anchorFor(0, Water.CAST_RAISE),
  "bobbing up drives the reflection down")
T.eq(anchorFor(0, Water.CAST_RAISE) - anchorFor(2, Water.CAST_RAISE), 2,
  "by exactly the bob, so the pair open and close at twice its rate")

-- and it still hangs downward from wherever the bob leaves it
local _, bobbedFeet = apply(reflected(0, 0, 1), 0, 0, 0)
local _, bobbedHead = apply(reflected(0, 0, 1), 0, 10, 0)
T.check(bobbedHead < bobbedFeet, "upside down at every point of the bob")

-- ------- the shader

local full = Water._source(false)

-- composited AFTER the fresnel mix, not into the reflection before it:
-- fresnel is smallest looked straight down at, which is the camera this
-- feature exists for
local mixAt = full:find("vec3 rgb = mix(base, refl", 1, true)
local castAt = full:find("if (castOn > 0.5)", 1, true)
T.check(mixAt ~= nil, "the fresnel mix is still there")
T.check(castAt ~= nil, "the cast is composited")
T.check(castAt > mixAt, "and it lands AFTER the fresnel mix, not inside it")

T.check(full:find("sc / love_ScreenSize.xy + n.xz * castWobble", 1, true) ~= nil,
  "read at the fragment's own screen place, dragged by the wave normal")
T.check(full:find("person.a * castAlpha", 1, true) ~= nil,
  "the canvas's alpha decides where there is anything to composite")

-- ------- the uniforms reach the shader

local sent = {}
local fakeShader = { send = function(_, name, ...) sent[name] = { ... } end }
Water.shader = function() return fakeShader end

love.graphics = love.graphics or {}
love.graphics.setShader = love.graphics.setShader or function() end
love.graphics.setColor = love.graphics.setColor or function() end

local function begin(castTex)
  sent = {}
  return Water.begin({
    vp = {}, eye = { 0, 8, 0 }, curve = { 0, 0, 0 },
    screen = { 320, 288 }, cell = 1, fov = 1,
    reflect = { "reflect" }, depth = { "depth" }, cast = castTex,
    lookFlat = { 0, 0, -1 }, descent = 0.4,
  }, false)
end

T.check(begin({ "cast" }), "the pass starts")
T.eq(sent.castOn[1], 1, "castOn is set when there is a cast canvas")
T.eq(sent.castAlpha[1], Water.CAST_ALPHA,
  "the strength is the constant, not a copy kept in step by hand")
T.eq(sent.castWobble[1], Water.CAST_WOBBLE, "and so is the wobble")
T.same(sent.castTex[1], { "cast" }, "the canvas itself is bound")

-- and with no cast canvas the sampler is STILL bound: an unbound sampler is
-- a driver-dependent crash, not a fallback
T.check(begin(nil), "the pass still starts without a cast canvas")
T.eq(sent.castOn[1], 0, "castOn is clear when there is no cast canvas")
T.check(sent.castTex ~= nil,
  "but the sampler is bound anyway, so the draw cannot fault on it")

-- ------- the canvas is owned, not leaked

local vox = io.open(root .. "/lib/Voxel3D.lua")
local voxSrc = vox:read("*a")
vox:close()
T.check(voxSrc:find('{ "canvas", "depth", "mirror", "cast" }', 1, true) ~= nil,
  "releaseSlot frees the cast canvas with the rest of the slot")
T.check(voxSrc:find("function Voxel3D.beginCast", 1, true) ~= nil,
  "the pass has an opening")
T.check(voxSrc:find("function Voxel3D.endCast", 1, true) ~= nil,
  "and a close that puts the camera back")

T.finish("water cast reflection")
