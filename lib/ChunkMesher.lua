-- Voxel world mode: turn a map's tile layer into one static 3D mesh.
--
-- The scene description comes from Structures.lua, which -- 3dSen-style --
-- detects each connected drawn thing on the map and picks its model:
--
--   flat      ground / water / void: a single quad.
--   top art   ledges, roofs (profile-authored): a box with the art on its
--             TOP face; partial side bands crop the art (a 6px ledge face
--             is the bottom of the lip drawing).
--   volume    walls, buildings, tree lines: each column rises to the
--             structure's REAL drawn height (Structures measures it,
--             repeat-aware and region-consistent -- a 6-row house is 48px,
--             a 40-row border forest is rows of 16px trees). The south
--             face folds the full artwork upright, 8px band by band, band
--             k sampling the map row k tiles north; the top wears the
--             structure's top rows.
--   object    small props with a silhouette (plants, signs, lone trees):
--             per-pixel voxel prisms prebuilt by Structures, standing on
--             synthesized ground -- this mesher just emits their quads.
--             Round trees arrive as STAMPS (a shared hull template plus a
--             cell offset) and expand here, straight into the vertex
--             stream, so no map retains per-cell copies of its forests.
--
-- Side faces are never stretched: all sides are 8px bands with the art
-- tiled per band and cropped at partial bands.
--
-- Texturing samples the TILESET ATLAS, not a rendered copy of the map. The
-- atlas is 128x48; a map-space canvas covering the biggest routes would be
-- ~5 MB each with up to five live at once (connected maps), which is real
-- memory on the mobile targets. Sampling the atlas costs 24 KB, and costs
-- nothing in fidelity because TerrainAtlas hands back the same atlas
-- TileRenderer draws with -- including the fully recolored one RED++
-- bakes -- so terrain color comes through untouched.
--
-- BUILDS ARE ASYNCHRONOUS. A frame never blocks on meshing: VoxelScene
-- requests what it wants to draw, request() queues a build job, and
-- pump() -- called once a frame from the pipeline's update -- advances
-- the queue inside a few-millisecond budget (BuildBudget suspends the
-- job's coroutine mid-loop when the slice is spent). Until a mesh lands
-- the scene simply draws without it: the engine's flat path while the
-- current map has nothing, the body-only variant while the full one (the
-- border ring) is still cooking, neighbours popping in as they finish.
-- The synchronous get() remains for probes and tests.
--
-- Meshes are cached per map id and EVICTED down to the live set (current
-- map + connected neighbours) whenever that set changes -- setLive()
-- releases far maps' GPU meshes and their Structures analysis, which is
-- what used to grow the heap by gigabytes over a cross-region trek.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Structures = V.require("Structures")
local TileShape = V.require("TileShape")
local Voxel3D = V.require("Voxel3D")
local Budget = V.require("BuildBudget")
local MeshDisk = V.require("VoxelMeshDisk")

-- Persistent geometry cache. Optional on purpose: a build without the module
-- (or one whose option is off) simply meshes every time, exactly as before.
local DiskCache = nil
do
  local okCache, cacheMod = pcall(V.require, "VoxelDiskCache")
  if okCache and type(cacheMod) == "table" and type(cacheMod.load) == "function" then
    DiskCache = cacheMod
  end
end

local ffi = nil
do
  local ok, mod = pcall(require, "ffi")
  if ok then ffi = mod end
end

local ChunkMesher = {}

-- The optional whole-map prebake writes raw vertex bytes. The ordinary live
-- renderer can use the packed sink on Android, but that sink intentionally has
-- no raw-file writer; do not advertise prebake support unless this exact path
-- is present.
local function rawDiskCacheAvailable()
  return DiskCache
    and type(DiskCache.enabled) == "function"
    and DiskCache.enabled()
    and ffi
    and love and love.filesystem and type(love.filesystem.newFile) == "function"
    and love.data and type(love.data.newByteData) == "function"
    and love.graphics and type(love.graphics.newMesh) == "function"
end

-- Anything geometry depends on that neither the map body nor the editor's
-- tile pins nor the companion config describes. Bumping it invalidates every
-- entry at once; it is the escape hatch for a rules change this file makes.
function ChunkMesher.setCacheRulesTag(tag)
  if DiskCache and type(DiskCache.setRulesTag) == "function" then
    DiskCache.setRulesTag(tag)
  end
end

function ChunkMesher.cacheStatus()
  if DiskCache and type(DiskCache.status) == "function" then
    local status = DiskCache.status()
    status.prebake = rawDiskCacheAvailable() == true
    return status
  end
  return { enabled = false, prebake = false, unavailable = true }
end

function ChunkMesher.clearCache()
  if DiskCache and type(DiskCache.clear) == "function" then
    return DiskCache.clear()
  end
  return false
end

-- Ring of border blocks meshed around the body, matching the width
-- TileRenderer draws so the two modes end at the same place.
local RING = 3

-- A sliver of a texel, to keep a quad's sampling inside its own tile.
-- Without any inset the perspective rasteriser lands on a NEIGHBOURING
-- tile's texel along the shared edge and stitches bright seams across the
-- whole map.
--
-- It has to be a sliver and not, as it first was, half a texel. A tile is
-- 8 texels of art across 8 world pixels -- one texel per pixel exactly --
-- and insetting the uv by half a texel at each end squeezes that art into
-- a 7-texel sample range while the quad still covers 8 world pixels. The
-- art then advances 7/8 of a texel per pixel: boundaries drift off the
-- pixel grid, one art pixel gets sampled twice and another never at all.
-- Nothing showed it until the voxel wireframe drew the grid those pixels
-- were supposed to be sitting on. Interpolation error is nowhere near a
-- fiftieth of a texel, so this is as safe against bleed and costs 0.25% of
-- a pixel of drift across a whole tile.
local INSET = 0.02

-- The south face of a volume is the artwork itself, so it draws at full
-- brightness; its top face darkens a touch so the plateau behind a
-- standing drawing reads as depth rather than repeating the same art at
-- the same energy.
local VOLUME_TOP_SHADE = 0.85

local cache = {}     -- map id -> { full = mesh|false, body = ..., grass = ... }
local gen = {}       -- map id -> generation, bumped by invalidate/evict

-- Horizontal neighbours: tile step, face direction id (see Voxel3D).
local SIDES = {
  { 1, 0, 1 },    -- +X east
  { -1, 0, 2 },   -- -X west
  { 0, 1, 5 },    -- +Z south
  { 0, -1, 6 },   -- -Z north
}

local function keyOf(tx, ty)
  return (ty + 64) * 4096 + (tx + 64)
end

-- ------------------------------------------------------------ vertex sinks

-- A sink accepts quads (4 corners, 4 uv pairs, flat or per-corner shade)
-- and finishes into a drawable mesh. The TABLE sink reproduces the
-- historical pure-Lua output -- geometry() returns its arrays for the
-- headless suite. The FFI sink packs the same six floats per vertex
-- straight into one growing native buffer, unindexed (v1 v2 v3 v1 v3 v4),
-- skipping ~a million short-lived Lua tables per route and LOVE's slow
-- table-by-table vertex upload.

local function newTableSink()
  local verts, indices, quads = {}, {}, 0
  return {
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      for i = 1, 4 do
        local cc, t = c[i], uv[i]
        verts[#verts + 1] = { cc[1], cc[2], cc[3], t[1], t[2],
                              flat and shade or shade[i] }
      end
      Voxel3D.pushQuad(indices, quads)
      quads = quads + 1
    end,
    results = function()
      return verts, indices, quads
    end,
    -- Vertices as the GPU would see them: the table sink is INDEXED, so its
    -- drawn vertex count is three per triangle, not #verts. Only the FFI
    -- sink's unindexed stream can be persisted; this exists so a caller can
    -- ask either sink the same question.
    vertexCount = function()
      return quads * 6
    end,
    finish = function()
      return Voxel3D.newMesh(verts, indices)
    end,
  }
end

local TRI_ORDER = { 1, 2, 3, 1, 3, 4 }

-- Sandboxed Gen2Recomp builds do not expose FFI to mods. LOVE's binary packer
-- produces the same tightly packed six-float stream without allocating a Lua
-- table for every vertex, and the chunks are also the persistent-cache source.
local PACKED_VERTEX = "<" .. string.rep("f", 6 * 6)
local PACKED_VERTEX_BYTES = 6 * 4
local PACKED_QUADS_PER_CHUNK = 4096

local function newPackedSink()
  local chunks, parts, values = {}, {}, {}
  local quads, n = 0, 0

  local function flush()
    if #parts == 0 then return end
    chunks[#chunks + 1] = table.concat(parts)
    parts = {}
  end

  return {
    push = function(c, uv, shade)
      local flat = type(shade) ~= "table"
      local at = 1
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local cc, t = c[i], uv[i]
        values[at], values[at + 1], values[at + 2] = cc[1], cc[2], cc[3]
        values[at + 3], values[at + 4] = t[1], t[2]
        values[at + 5] = flat and shade or shade[i]
        at = at + 6
      end
      parts[#parts + 1] = love.data.pack(
        "string", PACKED_VERTEX, unpack(values, 1, 36))
      quads, n = quads + 1, n + 6
      if quads % PACKED_QUADS_PER_CHUNK == 0 then flush() end
    end,
    finish = function()
      if n == 0 then return nil end
      flush()
      local ok, mesh = pcall(function()
        local result = love.graphics.newMesh(Voxel3D.FORMAT, n,
                                             "triangles", "static")
        local first = 1
        for _, chunk in ipairs(chunks) do
          local data = love.data.newByteData(chunk)
          result:setVertices(data, first)
          first = first + math.floor(#chunk / PACKED_VERTEX_BYTES)
          data:release()
          Budget.check()
        end
        return result
      end)
      chunks, parts = {}, {}
      return ok and mesh or nil
    end,
    raw = function()
      flush()
      return { chunks = chunks, n = n }
    end,
  }
end

local function newFfiSink()
  local cap = 4096 * 6
  local buf = ffi.new("float[?]", cap * 6)
  local n = 0
  local sink
  sink = {
    push = function(c, uv, shade)
      if n + 6 > cap then
        local grown = ffi.new("float[?]", cap * 2 * 6)
        ffi.copy(grown, buf, n * 6 * 4)
        buf, cap = grown, cap * 2
      end
      local flat = type(shade) ~= "table"
      local base = n * 6
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local cc, t = c[i], uv[i]
        buf[base] = cc[1]
        buf[base + 1] = cc[2]
        buf[base + 2] = cc[3]
        buf[base + 3] = t[1]
        buf[base + 4] = t[2]
        buf[base + 5] = flat and shade or shade[i]
        base = base + 6
      end
      n = n + 6
    end,
    vertexCount = function()
      return n
    end,
    -- Spill the raw six-float stream straight to disk, in the same slices
    -- the GPU upload uses and with a budget tick between them, so baking a
    -- whole region never stalls a frame. Writing from here rather than from
    -- the cache module keeps every cdata pointer inside this file.
    -- Called by the cache as `sink:writeRaw(path)`, so the sink itself
    -- arrives first; a plain `sink.writeRaw(path)` works too. Getting this
    -- wrong is silent -- the path becomes a table and the write lands
    -- nowhere -- so it is checked rather than assumed.
    writeRaw = function(a, b)
      local path = b
      if path == nil and type(a) == "string" then path = a end
      if type(path) ~= "string" then return false, "writeRaw needs a path" end
      if not (love and love.filesystem and love.filesystem.newFile
              and love.data and love.data.newByteData) then
        return false, "no filesystem"
      end
      local okFile, file = pcall(love.filesystem.newFile, path)
      if not okFile or not file then
        return false, "could not create " .. tostring(path)
      end
      local okOpen, opened = pcall(file.open, file, "w")
      if not okOpen or opened == false then
        pcall(file.close, file)
        return false, "could not open " .. tostring(path)
      end
      local okWrite, err = pcall(function()
        local CHUNK = 65536
        local i = 0
        while i < n do
          local count = math.min(CHUNK, n - i)
          local bytes = count * 6 * 4
          local data = love.data.newByteData(bytes)
          ffi.copy(data:getFFIPointer(), buf + i * 6, bytes)
          local wrote = file:write(data:getString())
          if data.release then pcall(data.release, data) end
          if wrote == false then error("short write") end
          i = i + count
          Budget.check()
        end
      end)
      pcall(file.close, file)
      if not okWrite then
        pcall(love.filesystem.remove, path)
        return false, tostring(err)
      end
      return true
    end,
    finish = function()
      if n == 0 then return nil end
      -- upload in slices with budget ticks between: a route-sized mesh
      -- is ~10-20MB and one atomic setVertices was the last remaining
      -- frame spike. The mesh is not cached (so never drawn) until the
      -- whole upload lands, and LuaJIT yields fine across pcall.
      local ok, mesh = pcall(function()
        local m = love.graphics.newMesh(Voxel3D.FORMAT, n,
                                        "triangles", "static")
        local CHUNK = 65536              -- vertices per slice (~1.5MB)
        local i = 0
        while i < n do
          local count = math.min(CHUNK, n - i)
          local bytes = count * 6 * 4
          local data = love.data.newByteData(bytes)
          ffi.copy(data:getFFIPointer(), buf + i * 6, bytes)
          m:setVertices(data, i + 1)
          data:release()
          i = i + count
          Budget.check()
        end
        return m
      end)
      return ok and mesh or nil
    end,
    raw = function()
      return { ptr = buf, n = n }
    end,
  }
  return sink
end

local function newSink()
  if rawDiskCacheAvailable() then
    return newFfiSink()
  end
  if MeshDisk.available() and MeshDisk.legacy() and ffi
     and love and love.data and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newFfiSink()
  end
  if MeshDisk.available() and love and love.data and love.data.pack
     and love.data.newByteData and love.graphics and love.graphics.newMesh then
    return newPackedSink()
  end
  if ffi and love and love.data and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newFfiSink()
  end
  if love and love.data and love.data.pack and love.data.newByteData
     and love.graphics and love.graphics.newMesh then
    return newPackedSink()
  end
  return newTableSink()
end

-- Reconstruct one cached CPU stream into a session-local GPU Mesh. Decoded
-- strings are released as soon as LOVE has copied them into the mesh.
local function meshFromRaw(record)
  if not (record and record.n and record.n > 0) then return nil end
  if record.ptr and ffi then
    local ok, mesh = pcall(function()
      local result = love.graphics.newMesh(Voxel3D.FORMAT, record.n,
                                           "triangles", "static")
      local first = 0
      while first < record.n do
        local count = math.min(65536, record.n - first)
        local byteCount = count * PACKED_VERTEX_BYTES
        local data = love.data.newByteData(byteCount)
        ffi.copy(data:getFFIPointer(),
          ffi.cast("const uint8_t*", record.ptr)
            + first * PACKED_VERTEX_BYTES, byteCount)
        result:setVertices(data, first + 1)
        data:release()
        first = first + count
        Budget.check()
      end
      return result
    end)
    return ok and mesh or nil
  end
  if not record.chunks then return nil end
  local ok, mesh = pcall(function()
    local result = love.graphics.newMesh(Voxel3D.FORMAT, record.n,
                                         "triangles", "static")
    local first, carry = 1, ""
    for _, chunk in ipairs(record.chunks) do
      local bytes = carry .. chunk
      local usable = math.floor(#bytes / PACKED_VERTEX_BYTES)
                     * PACKED_VERTEX_BYTES
      carry = bytes:sub(usable + 1)
      if usable > 0 then
        local data = love.data.newByteData(bytes:sub(1, usable))
        result:setVertices(data, first)
        first = first + usable / PACKED_VERTEX_BYTES
        data:release()
      end
      Budget.check()
    end
    if #carry ~= 0 or first ~= record.n + 1 then
      error("invalid packed voxel vertex stream", 0)
    end
    return result
  end)
  record.chunks = nil
  return ok and mesh or nil
end

-- -------------------------------------------------------------- geometry

-- Emit the raw geometry for `map` into `sink`. `bodyOnly` skips the
-- border ring -- the shape the 2D path's drawMapOnly has always had: a
-- neighbour map contributes its body, and only the CURRENT map supplies
-- the ring around the view.
--
-- `masks` (full variant only) lists rectangles, in this map's world
-- pixels, where connected neighbour BODIES sit: ring geometry inside them
-- is suppressed. The 2D renderer never needed this because it painted
-- neighbour bodies OVER the ring; with a depth buffer the ring's standing
-- trees would rise straight through the neighbour's flat ground -- cross
-- into Route 1 and a wall of border trees sprouts over Pallet.
--
-- Kept free of any GPU call so it can be exercised headless -- the
-- geometry is the part with the interesting invariants, and a suite that
-- needed a real GL context to check them would never run in CI.
-- `waterSink`, when given, takes the WATER SURFACE quads instead of the
-- main sink -- the one class in this world that is drawn as its own pass
-- (see Water: a mirror cannot be drawn until what it reflects exists).
-- Nothing else moves: the quads are the same quads, emitted by the same
-- corner and uv arithmetic at the same recessed height, and the shoreline
-- faces around them still belong to the GROUND that exposes them.
--
-- Omitted, water stays in the terrain mesh exactly as it always did, which
-- is what the headless geometry() below and the sun's own pass both want.
local function runGeometry(map, bodyOnly, masks, sink, waterSink)
  local push = sink.push
  local waterPush = waterSink and waterSink.push or nil
  local tileset = map.tileset
  local S = Structures.forMap(map)
  local def = map.def
  local tw, th = def.width * 4, def.height * 4         -- map size in tiles
  local perRow = tileset.tilesPerRow or 16
  local atlasW = tileset.imageWidth or (perRow * 8)
  local atlasH = tileset.imageHeight or 48

  -- ------------------------------------------------------------- ledge lips
  --
  -- A hop-down ledge is a LIP, not a kerb.  TileShape resolves the class per
  -- CELL (its HOP_LIP rule), but the drop is only DRAWN across the 8px tile
  -- row the rim occupies -- the rest of the cell is the turf above it.  Read
  -- at cell granularity the whole square rose, so a ledge line came out as a
  -- kerb of grass with a rim printed on its side.
  --
  -- Which half rises is the ROM's own answer: DoPlayerMovement.TryJump keys
  -- the hop off classes $A0-$AF, and the class sits on the cell you jump
  -- FROM, so the neighbour holding it names the side the lip faces.
  local LEDGE_HOP = {
    { -1, 0, { [0xA0] = true, [0xA4] = true }, "right" },
    { 1, 0, { [0xA1] = true, [0xA5] = true }, "left" },
    { 0, -1, { [0xA3] = true, [0xA4] = true, [0xA5] = true }, "down" },
  }

  local ledgeDropCache = {}
  local function ledgeDrop(cx, cy)
    local k = keyOf(cx, cy)
    local hit = ledgeDropCache[k]
    if hit then return hit end
    local d = "down"
    if map.cellTile then
      for _, r in ipairs(LEDGE_HOP) do
        local ok, class = pcall(map.cellTile, map, cx + r[1], cy + r[2])
        if ok and class and r[3][class] then d = r[4]; break end
      end
    end
    ledgeDropCache[k] = d
    return d
  end

  -- s.h for the tile the rim is drawn on, 0 for the rest of its cell
  local function shapeHeight(tx, ty, s)
    if s.class ~= "ledge" then return s.h end
    local d = ledgeDrop(math.floor(tx / 2), math.floor(ty / 2))
    local onDrop
    if d == "up" then onDrop = ty % 2 == 0
    elseif d == "right" then onDrop = tx % 2 == 1
    elseif d == "left" then onDrop = tx % 2 == 0
    else onDrop = ty % 2 == 1 end
    return onDrop and s.h or 0
  end

  local function heightAt(tx, ty)
    local k = keyOf(tx, ty)
    if S.skip[k] then return 0 end
    local run = S.runs[k]
    if run then return run.h end
    local s = S.shapeAt[k]
    return s and shapeHeight(tx, ty, s) or 0
  end

  -- Structures analyses the map's border ring as real raised geometry. That
  -- is correct at a closed map edge, but a connected neighbour suppresses
  -- the ring and draws its own body flush across the seam. AO must therefore
  -- ignore the phantom ring there. Face exposure continues to use heightAt:
  -- this exception describes occlusion only and cannot open geometry holes.
  -- A coordinate outside both axes remains a real corner of the border ring.
  local conn = def.connections
  local cN = (conn and conn.north) ~= nil
  local cS = (conn and conn.south) ~= nil
  local cE = (conn and conn.east) ~= nil
  local cW = (conn and conn.west) ~= nil
  local anyConn = cN or cS or cE or cW
  local function flushConnection(tx, ty)
    if not anyConn then return false end
    if ty >= 0 and ty < th then
      if tx >= tw then return cE end
      if tx < 0 then return cW end
    end
    if tx >= 0 and tx < tw then
      if ty >= th then return cS end
      if ty < 0 then return cN end
    end
    return false
  end

  local function crowds(tx, ty, h)
    if flushConnection(tx, ty) then return false end
    return heightAt(tx, ty) > h
  end

  -- one atlas-rect UV, optionally cropped to art rows [vTop, vBot] of 8
  local function uvRect(tile, vTop, vBot)
    local ax = (tile % perRow) * 8
    local ay = math.floor(tile / perRow) * 8
    local vi = math.min(INSET, (vBot - vTop) / 4)
    return (ax + INSET) / atlasW, (ax + 8 - INSET) / atlasW,
           (ay + vTop + vi) / atlasH, (ay + vBot - vi) / atlasH
  end

  -- ------------------------------------------------------ ambient occlusion
  --
  -- Ambient light is what reaches a surface from the sky at large, so it is
  -- blocked by how much geometry crowds a point rather than by where the
  -- sun happens to be -- which makes it the exact complement of the shadow
  -- pass, and the reason both are worth having. The shadow map draws the
  -- long directional shadow a building throws; this draws the dark seam in
  -- every corner the sky cannot see into, at every scale finer than a
  -- shadow map texel.
  --
  -- Baked per vertex, the classic voxel way: each corner counts the
  -- neighbours that crowd it and steps down once per neighbour, and the
  -- rasteriser interpolates the steps into a smooth falloff. Costs exactly
  -- nothing at draw time, and it is resolution-independent -- a screen
  -- space pass would blur across the pixel grid this whole mode is built
  -- to keep crisp.
  --
  -- (What was here before was a one-directional contact shadow keyed to a
  -- sun in the northwest: two neighbours, one corner, top faces only.)

  -- Intensity. Both terms below are DARKENING amounts rather than
  -- multipliers, so this one number scales the whole effect: 1.0 is the
  -- barely-there first cut, and everything is expressed against it.
  local AO_STRENGTH = 2.4
  local AO_STEP = 0.09 * AO_STRENGTH      -- per crowding neighbour, max 3
  local AO_EDGE = 1 - 0.14 * AO_STRENGTH  -- creases / corners on a face
  local AO_GROUND = 0.12 * AO_STRENGTH    -- a prop's contact with the floor
  local AO_RISE = 6                       -- px over which the floor lets go
  local AO_FLOOR = 0.25                   -- never let a vertex reach black

  -- Both sinks copy a per-corner shade straight out into the vertex stream
  -- and keep no reference, so these two scratch rows are reused for every
  -- quad on the map rather than allocating a table per face -- a route
  -- builds a few hundred thousand of them.
  local aoTop = { 0, 0, 0, 0 }
  local aoSide = { 0, 0, 0, 0 }

  -- A top face's four corners, each occluded by the three cells that touch
  -- it: two edge neighbours and the diagonal between them.
  local function aoShades(tx, ty, h, shade)
    local n = crowds(tx, ty - 1, h)
    local s = crowds(tx, ty + 1, h)
    local e = crowds(tx + 1, ty, h)
    local w = crowds(tx - 1, ty, h)
    local nw = crowds(tx - 1, ty - 1, h)
    local ne = crowds(tx + 1, ty - 1, h)
    local sw = crowds(tx - 1, ty + 1, h)
    local se = crowds(tx + 1, ty + 1, h)
    if not (n or s or e or w or nw or ne or sw or se) then return shade end
    local function corner(a, b, d)
      local k = 0
      if a then k = k + 1 end
      if b then k = k + 1 end
      -- a diagonal wedged behind both of its edges adds nothing: the
      -- corner is already as enclosed as it can get, and counting it
      -- again is what turns an ordinary inside corner black
      if d and not (a and b) then k = k + 1 end
      -- floored, so cranking AO_STRENGTH deepens the seams instead of
      -- punching holes of pure black through the world
      return shade * math.max(AO_FLOOR, 1 - AO_STEP * k)
    end
    -- corners in topQuad order: NW, NE, SE, SW
    aoTop[1], aoTop[2] = corner(n, w, nw), corner(n, e, ne)
    aoTop[3], aoTop[4] = corner(s, e, se), corner(s, w, sw)
    return aoTop
  end

  -- The same idea on an upright face, where the crowding is of two kinds:
  -- the CREASE it rises out of (the band sitting on the ground, or on
  -- whatever lower neighbour exposed the face) and the INSIDE CORNERS
  -- where the columns flanking it stand proud of the band. `hl`/`hr` are
  -- those flanking heights in FACE order -- left then right as seen from
  -- outside, per LATERAL below -- so the shades line up with sideQuad's
  -- corners without the caller thinking about compass directions.
  local LATERAL = {
    [1] = { 0, 1, 0, -1 },    -- east face:  left south, right north
    [2] = { 0, -1, 0, 1 },    -- west face:  left north, right south
    [5] = { -1, 0, 1, 0 },    -- south face: left west,  right east
    [6] = { 1, 0, -1, 0 },    -- north face: left east,  right west
  }
  -- Ground contact for the prebuilt prop quads -- the per-pixel plants,
  -- signs and lone trees, and the round-tree stamps. Those arrive from
  -- Structures already finished, so the neighbour counting above has no
  -- columns to count. What it CAN say is that the ground plane itself
  -- blocks half the sky, so the closer a voxel sits to it the less ambient
  -- light reaches it -- which is what plants a prop on the floor instead
  -- of leaving it looking pasted over the top.
  local aoProp = { 0, 0, 0, 0 }
  local function groundShades(c, shade)
    if type(shade) == "table" then return shade end
    local y1, y2, y3, y4 = c[1][2], c[2][2], c[3][2], c[4][2]
    if math.min(y1, y2, y3, y4) >= AO_RISE then return shade end
    for i = 1, 4 do
      local t = c[i][2] / AO_RISE
      aoProp[i] = shade * (t >= 1 and 1 or (1 - AO_GROUND * (1 - t)))
    end
    return aoProp
  end

  local AO_CORNER = math.max(AO_FLOOR, AO_EDGE * AO_EDGE)  -- crease AND flank
  local function sideShades(hl, hr, y0, y1, crease, shade)
    if not (crease or hl > y0 or hr > y0) then return shade end
    -- corners run bottom-left, bottom-right, top-right, top-left
    local base = crease and AO_EDGE or 1
    aoSide[1] = shade * (hl > y0 and (crease and AO_CORNER or AO_EDGE) or base)
    aoSide[2] = shade * (hr > y0 and (crease and AO_CORNER or AO_EDGE) or base)
    aoSide[3] = shade * (hr > y1 and AO_EDGE or 1)
    aoSide[4] = shade * (hl > y1 and AO_EDGE or 1)
    return aoSide
  end

  -- `to` routes the quad somewhere other than the main sink -- the water
  -- surface is the only caller that ever does (see runGeometry's header).
  local function topQuad(x0, z0, h, tile, shade, to)
    local u0, u1, v0, v1 = uvRect(tile, 0, 8)
    ;(to or push)({ { x0, h, z0 }, { x0 + 8, h, z0 },
                    { x0 + 8, h, z0 + 8 }, { x0, h, z0 + 8 } },
                  { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } },
                  aoShades(x0 / 8, z0 / 8, h, shade))
  end

  -- vertical quad for face direction `d` of the tile column at (x0, z0),
  -- spanning heights [y0, y1] and showing art rows [vTop, vBot] of `tile`.
  -- Corners run bottom-left, bottom-right, top-right, top-left as seen
  -- from outside; u follows +X on the north/south faces so a door or sign
  -- never draws mirrored.
  local function sideQuad(d, x0, z0, y0, y1, tile, vTop, vBot, shade)
    local x1, z1 = x0 + 8, z0 + 8
    local c
    if d == 5 then                                       -- south, at z1
      c = { { x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 } }
    elseif d == 6 then                                   -- north, at z0
      c = { { x1, y0, z0 }, { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 } }
    elseif d == 1 then                                   -- east, at x1
      c = { { x1, y0, z1 }, { x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 } }
    else                                                 -- west, at x0
      c = { { x0, y0, z0 }, { x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 } }
    end
    local u0, u1, v0, v1 = uvRect(tile, vTop, vBot)
    push(c, { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, shade)
  end

  local r = bodyOnly and 0 or RING * 4

  -- true when the (ring) position lies under a connected neighbour's body
  local function masked(px0, pz0, px1, pz1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if px1 > mk[1] and px0 < mk[3] and pz1 > mk[2] and pz0 < mk[4] then
        return true
      end
    end
    return false
  end

  -- The inclusive variant for OBJECT quads: a quad TOUCHING a neighbour
  -- body counts as under it. The old test took the quad's center with
  -- strict bounds, and a quad whose center sat exactly on the body's
  -- edge line escaped the mask -- stringing stray pixel fragments of
  -- otherwise-dropped border trees along every map seam.
  local function maskedClosed(px0, pz0, px1, pz1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if px1 >= mk[1] and px0 <= mk[3] and pz1 >= mk[2] and pz0 <= mk[4] then
        return true
      end
    end
    return false
  end

  for ty = -r, th + r - 1 do
    for tx = -r, tw + r - 1 do
      Budget.tick()
      local k = keyOf(tx, ty)
      local s, tile = S.shapeAt[k], S.tileAt[k]
      local inBody = tx >= 0 and ty >= 0 and tx < tw and ty < th
      if not inBody and masked(tx * 8, ty * 8, tx * 8 + 8, ty * 8 + 8) then
        s = nil
      end

      -- Under the TREES fill the border wall is MODELLED or it is not there
      -- (see Structures' hullRingOnly): a ring cell nothing claimed would
      -- be a flat-topped box standing beside carved trunks, which reads as
      -- a painted-on plateau rather than forest. Structures already stops
      -- the ring at the carve distance; this catches the odd cell inside it
      -- that the 2x2 grouping could not take -- a canopy whose partners
      -- fall outside the shortened ring is left unclaimed, and one strip of
      -- boxes along an edge is the whole artefact this avoids.
      if not inBody and S.hideBareRing and not S.skip[k] then
        s = nil
      end

      if s and S.skip[k] then
        -- an object stands here; paint its synthesized ground and let the
        -- prebuilt prism quads (appended below) carry the art
        local g = S.ground[k]
        if g then
          -- ...at the DATUM the object stands on, not at zero.  A building
          -- claim carries the height its ground vote found (Buildings.stamp),
          -- so a house on a terrace paints its floor on the terrace instead
          -- of on the world datum sixteen pixels below it.
          local gy = s.base or 0
          topQuad(tx * 8, ty * 8, gy, g, 1)
          -- the claimed tile is still ground at height 0, and water next
          -- door still recesses below it: without the same below-ground
          -- side bands ordinary ground emits, the two-pixel shoreline
          -- face is a slit into the sky behind the mesh -- which is
          -- exactly what a building plot or a sign standing at the
          -- waterline showed. Same bands, cut from the synthesized
          -- ground's own art
          for _, side in ipairs(SIDES) do
            local nh = heightAt(tx + side[1], ty + side[2])
            if nh < gy then
              local d = side[3]
              local lat = LATERAL[d]
              local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
              local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
              for band = math.floor(nh / 8), math.ceil(gy / 8) - 1 do
                local y0 = math.max(nh, band * 8)
                local y1 = math.min(gy, band * 8 + 8)
                if y1 > y0 then
                  sideQuad(d, tx * 8, ty * 8, y0, y1, g,
                           (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                           sideShades(hl, hr, y0, y1, y0 <= nh,
                                      Voxel3D.FACE_SHADE[d]))
                end
              end
            end
          end
        end
      elseif s and s.sub and s.sub.res and s.sub.h then
        -- ------------------------------------------------ SUB-TILE HEIGHTS
        --
        -- A tile's height is normally ONE number: `topQuad` plants all four
        -- corners of the 8px square at it and the side faces span from the
        -- neighbour up to it. That is the whole contract everything below
        -- assumes, which is why finer heights could not simply be a smaller
        -- number -- they need their own emitter.
        --
        -- This is it: the tile is divided into `res` x `res` sub-columns
        -- (res 2 = 4px squares, 4 = 2px, 8 = 1px) and each is emitted as its
        -- own little box. Sides are drawn only where the neighbouring
        -- sub-column is LOWER, exactly as the tile-sized path does, so the
        -- inside of a flat patch costs nothing and only the steps between
        -- levels produce faces.
        --
        -- GATED ON A FIELD THAT IS NIL EVERYWHERE. A tile with no `sub` takes
        -- the original branch below, unchanged, so nothing that renders today
        -- can render differently because this exists.
        --
        -- THE COST IS REAL AND IT IS THE READER'S TO SPEND. At res 8 one tile
        -- is up to 64 boxes; a whole map of them would be a hundred times the
        -- geometry. It is a sparse override on the few tiles that need
        -- sculpting, and the editor writes it nowhere else.
        local res = math.max(1, math.min(8, math.floor(s.sub.res)))
        local step = 8 / res
        local hs = s.sub.h
        local base = run and run.h or shapeHeight(tx, ty, s)
        local x0, z0 = tx * 8, ty * 8
        local tile = S.tileAt[k]

        local function subH(i, j)
          if i < 0 or j < 0 or i >= res or j >= res then return nil end
          local v = hs[j * res + i + 1]
          return tonumber(v) or base
        end

        -- The art under one sub-square, so a sculpted tile keeps its drawing
        -- instead of repeating the whole tile per box.
        local function subUV(i, j)
          local ax = (tile % perRow) * 8
          local ay = math.floor(tile / perRow) * 8
          local u0 = (ax + i * step) / atlasW
          local u1 = (ax + (i + 1) * step) / atlasW
          local v0 = (ay + j * step) / atlasH
          local v1 = (ay + (j + 1) * step) / atlasH
          return u0, u1, v0, v1
        end

        for j = 0, res - 1 do
          for i = 0, res - 1 do
            local hh = subH(i, j) or base
            local sx, sz = x0 + i * step, z0 + j * step
            local u0, u1, v0, v1 = subUV(i, j)
            -- top
            push({ { sx, hh, sz }, { sx + step, hh, sz },
                   { sx + step, hh, sz + step }, { sx, hh, sz + step } },
                 { { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v1 } },
                 aoShades(tx, ty, hh, 1))
            -- sides, only where the neighbour is lower. Off the tile's own
            -- edge the neighbour is the NEXT TILE's height, so a sculpted
            -- tile still closes against the flat ground beside it rather
            -- than leaving a slot you can see through.
            for _, side in ipairs(SIDES) do
              local ni, nj = i + side[1], j + side[2]
              local nh = subH(ni, nj)
              if nh == nil then
                nh = heightAt(tx + side[1], ty + side[2])
              end
              if nh < hh then
                local d = side[3]
                local x1, z1 = sx + step, sz + step
                local c
                if d == 5 then
                  c = { { sx, nh, z1 }, { x1, nh, z1 }, { x1, hh, z1 }, { sx, hh, z1 } }
                elseif d == 6 then
                  c = { { x1, nh, sz }, { sx, nh, sz }, { sx, hh, sz }, { x1, hh, sz } }
                elseif d == 1 then
                  c = { { x1, nh, z1 }, { x1, nh, sz }, { x1, hh, sz }, { x1, hh, z1 } }
                else
                  c = { { sx, nh, sz }, { sx, nh, z1 }, { sx, hh, z1 }, { sx, hh, sz } }
                end
                push(c, { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } },
                     Voxel3D.FACE_SHADE[d] or 1)
              end
            end
          end
        end

      elseif s then
        local run = S.runs[k]
        local h = run and run.h or shapeHeight(tx, ty, s)
        local x0, z0 = tx * 8, ty * 8

        -- top face. A roofed volume gets a GABLE segment: the roof rises
        -- from the facade top at the south eave to a ridge across the
        -- footprint's middle, then falls back to the facade at the north
        -- edge -- so the far side sits LOW. (The first cut was a shed
        -- plane rising all the way north, which turns a building into a
        -- ramp.) The south slope wears the structure's roof rows (ridge
        -- art at the ridge, eaves art at the eave); the back slope
        -- mirrors them. Exposed east/west flanks hip: their outer edge
        -- drops toward the eave, rounding the drawn corner tiles into 45
        -- degree corners. Flat-topped volumes wear their top rows;
        -- everything else its own art.
        if run and run.rise > 0 then
          local mid = run.extent / 2
          local function gableH(d)     -- d = rows north of the south eave
            local t = d <= mid and d / mid or (run.extent - d) / (run.extent - mid)
            return run.h + run.rise * math.max(0, math.min(1, t))
          end
          local d0 = run.front - ty                -- rows from the south edge
          local hS = gableH(d0)
          local hN = gableH(d0 + 1)
          -- art by proximity to the ridge, mirrored over the back
          local rel = 1 - math.abs(d0 + 0.5 - mid) / math.max(mid, 0.5)
          local idx = math.min(run.roofRows - 1,
                               math.floor((1 - rel) * run.roofRows))
          local roofTile = map:tileAt(tx, run.north + idx)
          local swY, seY, neY, nwY = hS, hS, hN, hN
          if heightAt(tx - 1, ty) < run.h then     -- west flank: hip
            swY = math.max(run.h, hS - 8)
            nwY = math.max(run.h, hN - 8)
          end
          if heightAt(tx + 1, ty) < run.h then     -- east flank: hip
            seY = math.max(run.h, hS - 8)
            neY = math.max(run.h, hN - 8)
          end
          local u0, u1, v0, v1 = uvRect(roofTile, 0, 8)
          push({ { x0, swY, z0 + 8 }, { x0 + 8, seY, z0 + 8 },
                 { x0 + 8, neY, z0 }, { x0, nwY, z0 } },
               { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, 0.95)
        elseif run then
          local m = math.min(2, run.extent)
          local topTile = map:tileAt(tx, run.north + ((ty - run.north) % m))
          topQuad(x0, z0, h, topTile, VOLUME_TOP_SHADE)
        else
          local topTile = tile
          if s.art == "upright" and s.authored then
            -- Top art for a pinned box.  A furniture drawing is top-view
            -- rows over floor(h/8) face-on rows the fold stands upright;
            -- a face row's top would repeat its front art lying flat, so
            -- it wears the nearest row above the face block instead --
            -- the drawn tabletop (and whatever sits on it) stays on top,
            -- and a fully-folded structure (wall, desk) tops with its
            -- northmost row.
            local north, front = ty, ty
            while ty - north < 6 do
              local bs = S.shapeAt[keyOf(tx, north - 1)]
              if bs and bs.authored and bs.class == s.class then
                north = north - 1
              else
                break
              end
            end
            while front - ty < 6 do
              local bs = S.shapeAt[keyOf(tx, front + 1)]
              if bs and bs.authored and bs.class == s.class then
                front = front + 1
              else
                break
              end
            end
            local row = math.min(ty, front - math.floor(h / 8))
            if row < north then
              -- the whole run folded onto the face: top with the drawn
              -- row just above it when that row is furniture too (a
              -- bookcase wearing its shelf-top trim), else with the
              -- run's own top row
              local above = S.shapeAt[keyOf(tx, north - 1)]
              row = (above and above.authored and above.art == "upright")
                    and (north - 1) or north
            end
            topTile = S.tileAt[keyOf(tx, row)]
          end
          -- water's surface, and only water's: the recessed sheet itself,
          -- never the ground's shoreline bands around it. A cell an object
          -- stands on took the branch above and paints synthesized GROUND,
          -- which is right -- a sign at the waterline stands on a plot, not
          -- on the pond.
          topQuad(x0, z0, h, topTile,
                  s.art == "upright" and VOLUME_TOP_SHADE or 1,
                  (s.class == "water") and waterPush or nil)
        end

        -- sides: 8px bands wherever the neighbour is lower. Band k spans
        -- heights [8k, 8k+8) and shows one full tile of art; a partial
        -- band crops the art rows to match, so nothing ever stretches.
        for _, side in ipairs(SIDES) do
          local nh = heightAt(tx + side[1], ty + side[2])
          if nh < h then
            local d = side[3]
            -- the columns flanking this face, for the inside-corner term:
            -- fixed for the whole face, so they are read once rather than
            -- once per 8px band
            local lat = LATERAL[d]
            local hl = lat and heightAt(tx + lat[1], ty + lat[2]) or 0
            local hr = lat and heightAt(tx + lat[3], ty + lat[4]) or 0
            for band = math.floor(nh / 8), math.ceil(h / 8) - 1 do
              local y0 = math.max(nh, band * 8)
              local y1 = math.min(h, band * 8 + 8)
              if y1 > y0 then
                local src, shade = tile, Voxel3D.FACE_SHADE[d]
                if run then
                  -- fold the structure's artwork up this face: band k
                  -- samples the map row k tiles north of the structure's
                  -- front, clamped to its extent. The south face is the
                  -- drawing itself (full brightness); the other sides wear
                  -- the same rows darkened, so a building's flank matches
                  -- its face instead of smearing one tile
                  -- band is an ABSOLUTE 8px course, so a run standing on a
                  -- terrace starts at band 2 rather than band 0 -- and
                  -- sampling row north+2 for its first visible course would
                  -- slide the whole drawing two rows up the face.  Count
                  -- courses from the run's own datum instead.
                  local bb = band - math.floor((run.base or 0) / 8)
                  if bb < 0 then bb = 0 end
                  if d == 6 then
                    src = map:tileAt(tx, math.min(run.front,
                                                  run.north + bb))
                  else
                    src = map:tileAt(tx, math.max(run.north,
                                                  run.front - bb))
                  end
                  if d == 5 then shade = 1 end
                elseif s.art == "upright" then
                  -- profile-authored upright (a pinned wall or furniture
                  -- box): fold the drawing up the face, band 0 the
                  -- structure's southmost same-class row and higher bands
                  -- the rows north of it, repeating past the top.  The
                  -- south face is the drawing itself (full brightness);
                  -- flanks and back wear the same front stack darkened, so
                  -- a desk's side matches its face instead of smearing a
                  -- different jumble per row.
                  if d == 5 then shade = 1 end
                  local front = ty
                  while front < ty + 6 do
                    local fs2 = S.shapeAt[keyOf(tx, front + 1)]
                    if fs2 and fs2.authored and fs2.class == s.class then
                      front = front + 1
                    else
                      break
                    end
                  end
                  local fk = keyOf(tx, front - band)
                  local fs = S.shapeAt[fk]
                  if fs and fs.authored and fs.class == s.class then
                    src = S.tileAt[fk]
                  end
                end
                sideQuad(d, x0, z0, y0, y1, src,
                         (band * 8 + 8) - y1, (band * 8 + 8) - y0,
                         sideShades(hl, hr, y0, y1, y0 <= nh, shade))
              end
            end
          end
        end
      end
    end
  end

  -- Prebuilt quads from Structures (per-pixel voxel props, lathed
  -- columns) plus the round-tree stamps expanded in place. Keep rules,
  -- by the quad's own extent:
  --   body-only   the quad must overlap the OPEN body interval -- a
  --               neighbour's ring props must not march past its edge
  --               into this map, and a quad lying exactly ON the edge
  --               plane would z-fight the map that owns that plane.
  --   full        anything overlapping the body stays whole (props that
  --               straddle the edge no longer shed their outer half);
  --               pure ring quads drop when they touch a neighbour body
  --               (maskedClosed), which is what strings of seam pixels
  --               were: fragments of dropped border trees whose centers
  --               sat exactly on the boundary line.
  local bw, bh = tw * 8, th * 8
  local function keepQuad(x0, z0, x1, z1)
    local overBody = x1 > 0 and x0 < bw and z1 > 0 and z0 < bh
    if bodyOnly then return overBody end
    return overBody or not maskedClosed(x0, z0, x1, z1)
  end

  -- A face lying EXACTLY on a body boundary plane is ambiguous to the
  -- rect tests above: a body structure's outward facade (a Saffron row
  -- house whose front row is the map's last row, its south wall on the
  -- shared plane with Route 6) and the inward face of a ring scrap
  -- occupy the same degenerate rect, and the strict overBody plus the
  -- closed mask dropped BOTH -- which is why those facades were missing.
  -- The winding tells them apart: a face pointing AWAY from the body
  -- belongs to this map's own edge-row structure and nothing in the
  -- neighbour will ever draw that plane, so it stays; a face pointing
  -- INTO the body is the scrap the mask rules exist to kill, and falls
  -- through to them.
  local function outwardOnEdge(q, x0, z0, x1, z1)
    if z0 == z1 and (z0 == 0 or z0 == bh) and x1 > 0 and x0 < bw then
      local nz = (q[2][1] - q[1][1]) * (q[3][2] - q[1][2])
                 - (q[2][2] - q[1][2]) * (q[3][1] - q[1][1])
      return (z0 == bh and nz > 0) or (z0 == 0 and nz < 0)
    end
    if x0 == x1 and (x0 == 0 or x0 == bw) and z1 > 0 and z0 < bh then
      local nx = (q[2][2] - q[1][2]) * (q[3][3] - q[1][3])
                 - (q[2][3] - q[1][3]) * (q[3][2] - q[1][2])
      return (x0 == bw and nx > 0) or (x0 == 0 and nx < 0)
    end
    return false
  end

  local scUV = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }
  local function quadUV(q)
    if q.uv then return q.uv end
    for i = 1, 4 do
      scUV[i][1], scUV[i][2] = q.u, q.v
    end
    return scUV
  end

  for _, q in ipairs(S.objectQuads) do
    Budget.tick()
    local x0 = math.min(q[1][1], q[2][1], q[3][1], q[4][1])
    local x1 = math.max(q[1][1], q[2][1], q[3][1], q[4][1])
    local z0 = math.min(q[1][3], q[2][3], q[3][3], q[4][3])
    local z1 = math.max(q[1][3], q[2][3], q[3][3], q[4][3])
    -- q.own: a body-anchored structure's own quad (a building placed by
    -- Buildings.build, whose scan never leaves the body). Exempt from
    -- the edge keep-rules entirely: its eave legitimately overhangs the
    -- boundary plane into the neighbour's airspace, and no variant of
    -- the neighbour will ever draw that geometry
    if q.own or outwardOnEdge(q, x0, z0, x1, z1)
       or keepQuad(x0, z0, x1, z1) then
      push({ q[1], q[2], q[3], q[4] }, quadUV(q), groundShades(q, q.shade))
    end
  end

  -- true when the rect sits entirely inside one neighbour-body rect
  local function containedInMask(x0, z0, x1, z1)
    if not masks then return false end
    for _, mk in ipairs(masks) do
      if x0 >= mk[1] and x1 <= mk[3] and z0 >= mk[2] and z1 <= mk[4] then
        return true
      end
    end
    return false
  end

  -- round-tree stamps: the shared hull template translated per cell,
  -- through reusable scratch corners so expansion allocates nothing.
  -- A hull spans at most its own footprint -- one 16px cell unless the
  -- stamp carries a wider radius (the 2x2-cell canopy groups) -- so one
  -- rect test usually answers for the whole stamp: strictly interior
  -- stamps keep every quad, ring stamps buried under a neighbour body
  -- (or, body-only, ring stamps full stop) skip without touching their
  -- quads. Only stamps crossing a boundary walk quad by quad.
  local sc = { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
  for _, st in ipairs(S.roundStamps or {}) do
    local mx, mz = st.mx, st.mz
    local sr = st.r or 8
    local sx0, sz0, sx1, sz1 = mx - sr, mz - sr, mx + sr, mz + sr
    local interior = sx0 > 0 and sx1 < bw and sz0 > 0 and sz1 < bh
    local overBody = sx1 > 0 and sx0 < bw and sz1 > 0 and sz0 < bh
    local keepAll, skipAll
    if bodyOnly then
      keepAll = interior
      skipAll = not overBody
    else
      keepAll = interior or not maskedClosed(sx0, sz0, sx1, sz1)
      skipAll = not overBody and containedInMask(sx0, sz0, sx1, sz1)
    end
    if not skipAll then
      for _, q in ipairs(st.quads) do
        Budget.tick()
        for i = 1, 4 do
          local c, s2 = q[i], sc[i]
          s2[1] = c[1] + mx
          s2[2] = c[2]
          s2[3] = c[3] + mz
        end
        local ok = keepAll
        if not ok then
          local x0 = math.min(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local x1 = math.max(sc[1][1], sc[2][1], sc[3][1], sc[4][1])
          local z0 = math.min(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          local z1 = math.max(sc[1][3], sc[2][3], sc[3][3], sc[4][3])
          ok = keepQuad(x0, z0, x1, z1)
        end
        if ok then
          push(sc, quadUV(q), groundShades(sc, q.shade))
        end
      end
    end
  end
end

-- The raw geometry for `map`: (vertex list, triangle index list, quad
-- count). Synchronous and GPU-free -- the headless suite and the probes
-- exercise the invariants through this.
--
-- `split` lifts the water surface out, as it is lifted out for the
-- reflective pass, and appends that sink's own three values -- so the suite
-- can check the same separation the GPU path relies on without a GPU.
-- Without it the water is in the first list, which is what every existing
-- caller reads.
function ChunkMesher.geometry(map, bodyOnly, masks, split)
  local sink = newTableSink()
  local waterSink = split and newTableSink() or nil
  runGeometry(map, bodyOnly, masks, sink, waterSink)
  if not waterSink then return sink.results() end
  local v, i, n = sink.results()
  local wv, wi, wn = waterSink.results()
  return v, i, n, wv, wi, wn
end

-- Build the mesh for `map` synchronously. Returns nil when there is
-- nothing to draw or meshes are unavailable (headless).
--
-- `split` asks for the water surface as a SECOND mesh, returned after the
-- terrain one -- the shape the reflective pass needs (see Water). Without
-- it the water is inside the terrain mesh, which is the historical
-- contract and what every other caller still wants.
function ChunkMesher.build(map, bodyOnly, masks, split)
  local sink = newSink()
  local waterSink = split and newSink() or nil
  runGeometry(map, bodyOnly, masks, sink, waterSink)
  return sink.finish(), waterSink and waterSink.finish() or nil
end

-- ---------------------------------------------------------------- prebake

-- Mesh `map` STRAIGHT TO DISK and throw the geometry away.
--
-- The difference from build() is that nothing is uploaded: no GPU mesh is
-- created, nothing enters the in-memory cache, and no slot is swapped. That
-- is what makes it safe to run over the whole map list -- baking two hundred
-- maps into VRAM would be a very expensive way to run out of it.
--
-- Returns true when an entry was written, false plus a reason otherwise.
-- "cached" is not a failure: it is the answer for a map already baked under
-- the current rules, which is what makes a second prebake pass cheap.
function ChunkMesher.bake(map, slot, masks)
  slot = slot or "body"
  if not DiskCache then return false, "no disk cache" end
  if type(DiskCache.enabled) == "function" and not DiskCache.enabled() then
    return false, "disabled"
  end
  if type(DiskCache.has) == "function" then
    local okHas, hit = pcall(DiskCache.has, map, slot, masks)
    if okHas and hit then return false, "cached" end
  end
  local sink = newSink()
  if type(sink.writeRaw) ~= "function" then
    return false, "no ffi sink"          -- the table sink cannot be persisted
  end
  local waterSink = newSink()
  local okGeom, err = pcall(runGeometry, map, slot == "body", masks, sink, waterSink)
  if not okGeom then return false, tostring(err) end
  local okStore, stored = pcall(DiskCache.store, map, slot, masks, sink, waterSink)
  if not okStore then return false, tostring(stored) end
  return stored and true or false, stored and nil or "store declined"
end

local function quadsMesh(quads)
  if #quads == 0 then return nil end
  local verts, indices, n = {}, {}, 0
  for _, q in ipairs(quads) do
    for i = 1, 4 do
      local c = q[i]
      local uv = q.uv and q.uv[i] or { q.u, q.v }
      verts[#verts + 1] = { c[1], c[2], c[3], uv[1], uv[2], q.shade }
    end
    Voxel3D.pushQuad(indices, n)
    n = n + 1
  end
  return Voxel3D.newMesh(verts, indices)
end

-- Flatten auxiliary quads into the same unindexed CPU stream as terrain so
-- grass, flowers and authored figures participate in the persistent record.
local function rawQuads(quads)
  local n = #(quads or {}) * 6
  if n == 0 then return { n = 0 } end
  if MeshDisk.legacy() and ffi then
    local buf, at = ffi.new("float[?]", n * 6), 0
    for _, q in ipairs(quads) do
      for k = 1, 6 do
        local i = TRI_ORDER[k]
        local c = q[i]
        local uv = q.uv and q.uv[i] or { q.u, q.v }
        buf[at], buf[at + 1], buf[at + 2] = c[1], c[2], c[3]
        buf[at + 3], buf[at + 4], buf[at + 5] = uv[1], uv[2], q.shade
        at = at + 6
      end
      Budget.tick()
    end
    return { ptr = buf, n = n }
  end
  local chunks, parts, values = {}, {}, {}
  for _, q in ipairs(quads) do
    local at = 1
    for k = 1, 6 do
      local i = TRI_ORDER[k]
      local c = q[i]
      local uv = q.uv and q.uv[i] or { q.u, q.v }
      values[at], values[at + 1], values[at + 2] = c[1], c[2], c[3]
      values[at + 3], values[at + 4], values[at + 5] = uv[1], uv[2], q.shade
      at = at + 6
    end
    parts[#parts + 1] = love.data.pack(
      "string", PACKED_VERTEX, unpack(values, 1, 36))
    if #parts == PACKED_QUADS_PER_CHUNK then
      chunks[#chunks + 1], parts = table.concat(parts), {}
    end
    Budget.tick()
  end
  if #parts > 0 then chunks[#chunks + 1] = table.concat(parts) end
  return { chunks = chunks, n = n }
end

local function buildRawAux(map)
  local structures = Structures.forMap(map)
  local aux = {
    grass = rawQuads(structures.grassQuads),
    flowers = rawQuads(structures.flowerQuads),
    figures = {},
  }
  for _, figure in ipairs(structures.figures or {}) do
    local raw = rawQuads(figure.quads)
    if raw.n > 0 then
      local width = 0
      for _, q in ipairs(figure.quads) do
        for i = 1, 4 do
          local x = q[i] and q[i][1]
          if x and x > width then width = x end
        end
      end
      raw.wx, raw.wz, raw.y, raw.w = figure.wx, figure.wz, figure.y, width
      aux.figures[#aux.figures + 1] = raw
    end
  end
  return aux
end

local function meshesFromRawAux(aux)
  local figures = {}
  for _, raw in ipairs(aux.figures or {}) do
    local mesh = meshFromRaw(raw)
    if mesh then
      figures[#figures + 1] = {
        mesh = mesh, wx = raw.wx, wz = raw.wz, y = raw.y, w = raw.w,
      }
    end
  end
  return meshFromRaw(aux.grass), meshFromRaw(aux.flowers), figures
end

-- The tall-grass rows as their own mesh: VoxelScene draws it AFTER the
-- characters so the southern row of a grass cell still overdraws a
-- walker's feet (characters stamp over terrain, Gen 1 style, so ordinary
-- terrain could never do this).
local function buildGrassMesh(map)
  return quadsMesh(Structures.forMap(map).grassQuads)
end

-- The flower billboards as their own mesh, for the same reason as the
-- grass one: it draws AFTER the characters WITH the same camera-ward
-- pull, so a flower south of a walker occludes their feet and one north
-- of them hides behind them. Baked into the terrain mesh they lost that
-- depth fight against the pulled character card whenever the player
-- stood among flowers. Unlike grass this mesh still CASTS shadows (the
-- sun pass draws it): a handful of flowers per meadow, not thousands of
-- tufts.
local function buildFlowerMesh(map)
  return quadsMesh(Structures.forMap(map).flowerQuads)
end

-- Authored FIGURES (a person drawn into furniture) as one mesh each, in
-- the card's own local space -- because each one is placed by its own
-- matrix at draw time, leaned back by the camera pitch exactly like a
-- character card (VoxelScene). A figure baked into the terrain mesh could
-- not lean, and a shared mesh could not carry per-figure placement.
--
-- A list, not a mesh: `{ mesh, wx, wz, y, w }` per figure. Maps have one
-- or none, so the loop that draws them is shorter than the terrain's.
-- `w` is the card's own width in its local space (its quads start at
-- x = 0), measured here because the first-person pass yaws a card about
-- its middle -- a card yawed about its left edge swings off its seat.
local function buildFigureMeshes(map)
  local out = {}
  for _, f in ipairs(Structures.forMap(map).figures or {}) do
    local mesh = quadsMesh(f.quads)
    if mesh then
      local w = 0
      for _, q in ipairs(f.quads) do
        for c = 1, 4 do
          local x = q[c] and q[c][1]
          if x and x > w then w = x end
        end
      end
      out[#out + 1] = { mesh = mesh, wx = f.wx, wz = f.wz, y = f.y, w = w }
    end
  end
  return out
end

-- Figure lists hold their meshes one level down, so the generic slot
-- release cannot reach them.
local function releaseFigures(list)
  for _, f in ipairs(type(list) == "table" and list or {}) do
    if f.mesh and f.mesh.release then pcall(f.mesh.release, f.mesh) end
  end
end

-- Replace a cached slot, releasing whatever mesh it held.
local function swapSlot(c, slot, mesh)
  local old = c[slot]
  if old and old ~= mesh and old.release then pcall(old.release, old) end
  c[slot] = mesh
end

-- ------------------------------------------------------------- the cache

local function entry(id)
  local c = cache[id]
  if not c then
    c = {}
    cache[id] = c
  end
  return c
end

-- The water surface that came out of a terrain slot's own build. Kept
-- beside it rather than in a slot of its own because the two are ONE
-- answer: a full mesh drawn beside a body build's water would draw the
-- ring's ponds twice and miss the body's own.
local function waterSlot(slot)
  return slot .. "Water"
end

local function releaseEntry(c)
  for _, slot in ipairs({ "full", "body", "fullWater", "bodyWater",
                          "grass", "flowers" }) do
    local mesh = c[slot]
    if mesh and mesh.release then pcall(mesh.release, mesh) end
    c[slot] = nil
  end
  releaseFigures(c.figures)
  c.figures = nil
  c.stale = nil
end

-- ---------------------------------------------------------- async builds

local jobs = {}       -- FIFO of pending jobs
local jobIndex = {}   -- "id:slot" -> job
local jobFailures = {} -- settled errors consumed by precache diagnostics

local clock = (love and love.timer and love.timer.getTime) or os.clock

local function jobKey(id, slot)
  return id .. ":" .. slot
end

local function finishJob(job, ok, err)
  local key = jobKey(job.id, job.slot)
  jobIndex[key] = nil
  for i, j in ipairs(jobs) do
    if j == job then
      table.remove(jobs, i)
      break
    end
  end
  if not ok then
    -- name the reason: in a real session a lost build is a black map
    print("[warn] voxel mesh build failed for " .. tostring(job.id)
          .. ": " .. tostring(err))
    if (gen[job.id] or 0) == job.gen then
      entry(job.id)[job.slot] = false
    end
    jobFailures[key] = tostring(err or "unknown mesh build error")
  else
    jobFailures[key] = nil
  end
end

-- A build only lands if the map's generation still matches the one the
-- job was queued under -- invalidate/evict bump it to cancel in-flight
-- work whose inputs went stale.
-- Terrain off the disk cache, or nil for "not cached, build it".
--
-- Both persisted slots go through here. BODY is the interesting one for a
-- walk across the world: it is what every neighbouring map contributes, its
-- key does not depend on where the player is standing, and it is what the
-- prebake writes for the whole map list in one pass.
local function loadCachedTerrain(job)
  if not DiskCache then return nil end
  local okLoad, hit, terrain, water =
    pcall(DiskCache.load, job.map, job.slot, job.masks)
  if not okLoad or not hit then return nil end
  return terrain or false, water or false
end

local function storeTerrain(job, sink, waterSink)
  if not DiskCache then return end
  pcall(DiskCache.store, job.map, job.slot, job.masks, sink, waterSink)
end

local function runJob(job)
  local map = job.map
  local c = entry(job.id)
  local function current()
    return (gen[job.id] or 0) == job.gen
  end

  -- Terrain BEFORE the auxiliary meshes when it comes off disk: the cached
  -- vertex stream is the whole reason a town can appear the moment you walk
  -- into it, and grass/flowers/figures are cheap enough to land a frame or
  -- two later. On a miss the original order stands.
  local cachedTerrain, cachedWater
  if not (c.stale and c.stale[job.slot]) then
    cachedTerrain, cachedWater = loadCachedTerrain(job)
  end
  if cachedTerrain ~= nil then
    if (gen[job.id] or 0) ~= job.gen then
      if cachedTerrain and cachedTerrain.release then
        pcall(cachedTerrain.release, cachedTerrain)
      end
      if cachedWater and cachedWater.release then
        pcall(cachedWater.release, cachedWater)
      end
      return
    end
    swapSlot(c, job.slot, cachedTerrain)
    swapSlot(c, waterSlot(job.slot), cachedWater)
  end

  if c.grass == nil or c.flowers == nil or c.figures == nil
     or (c.stale and c.stale.aux) then
    local grass, flowers, figures
    if MeshDisk.available() then
      local aux = MeshDisk.loadAux(map)
      if not aux then
        aux = buildRawAux(map)
        if not current() then return end
        local saved, saveErr = MeshDisk.saveAux(map, aux)
        if not saved then
          print("[warn] voxel aux cache write failed for " .. tostring(job.id)
                .. ": " .. tostring(saveErr))
        end
        if not current() then return end
      end
      grass, flowers, figures = meshesFromRawAux(aux)
    else
      local okG, builtGrass = pcall(buildGrassMesh, map)
      local okF, builtFlowers = pcall(buildFlowerMesh, map)
      local okX, builtFigures = pcall(buildFigureMeshes, map)
      grass = (okG and builtGrass) or false
      flowers = (okF and builtFlowers) or false
      figures = (okX and builtFigures) or false
    end
    if not current() then
      if grass and grass.release then pcall(grass.release, grass) end
      if flowers and flowers.release then pcall(flowers.release, flowers) end
      releaseFigures(figures)
      return
    end
    swapSlot(c, "grass", grass or false)
    swapSlot(c, "flowers", flowers or false)
    releaseFigures(c.figures)
    c.figures = figures or false
    if c.stale then c.stale.aux = nil end
  end
  if cachedTerrain == nil then
    local mesh, water
    local cached = MeshDisk.loadTerrain(map, job.slot, job.masks)
    if cached then
      mesh = meshFromRaw(cached.terrain)
      water = meshFromRaw(cached.water)
    else
      local sink, waterSink = newSink(), newSink()
      runGeometry(map, job.slot == "body", job.masks, sink, waterSink)
      if not current() then return end
      -- Persist to both optional cache layers before finish(): the sinks still
      -- own the raw stream, so no GPU upload is needed for either write.
      storeTerrain(job, sink, waterSink)
      local terrainRaw = sink.raw and sink.raw() or nil
      local waterRaw = waterSink.raw and waterSink.raw() or nil
      if terrainRaw and waterRaw then
        local saved, saveErr = MeshDisk.saveTerrain(
          map, job.slot, job.masks, terrainRaw, waterRaw)
        if not saved then
          print("[warn] voxel terrain cache write failed for "
                .. tostring(job.id) .. " " .. tostring(job.slot)
                .. ": " .. tostring(saveErr))
        end
      end
      mesh, water = sink.finish(), waterSink.finish()
    end
    if not current() then
      if mesh and mesh.release then pcall(mesh.release, mesh) end
      if water and water.release then pcall(water.release, water) end
      return
    end
    swapSlot(c, job.slot, mesh or false)
    swapSlot(c, waterSlot(job.slot), water or false)
  end
  if c.stale then
    c.stale[job.slot] = nil
    if not (c.stale.full or c.stale.body or c.stale.aux) then
      c.stale = nil
    end
  end
end

-- Queue a build unless the slot is already cached or queued. Returns the
-- cached mesh when there is one (false-cached misses return nil).
-- Current-map work has priority 2, visible neighbours priority 1, and
-- speculative warp jobs priority 0. A slot refresh() marked
-- stale queues its rebuild AND keeps handing back the old mesh, so a
-- one-block edit never drops the scene to the flat 2D path while the
-- replacement cooks.
local function priorityValue(priority)
  if priority == true or priority == "current" then return 2 end
  if priority == "visible" then return 1 end
  if type(priority) == "number" then
    return math.max(0, math.min(1.99, priority))
  end
  return 0
end

function ChunkMesher.request(map, bodyOnly, masks, priority)
  local slot = bodyOnly and "body" or "full"
  local c = cache[map.id]
  local stale = c and c.stale and (c.stale[slot] or c.stale.aux)
  if c and c[slot] ~= nil and not stale then return c[slot] or nil end
  local key = jobKey(map.id, slot)
  local job = jobIndex[key]
  local requested = priorityValue(priority)
  if not job then
    jobFailures[key] = nil
    job = { id = map.id, map = map, slot = slot, masks = masks,
            priority = requested, gen = gen[map.id] or 0 }
    jobIndex[key] = job
    jobs[#jobs + 1] = job
  elseif requested > (job.priority or 0) then
    job.priority = requested
  end
  return (c and c[slot]) or nil
end

function ChunkMesher.pending()
  return #jobs
end

function ChunkMesher.jobPending(mapId, bodyOnly)
  return jobIndex[jobKey(mapId, bodyOnly and "body" or "full")] ~= nil
end

function ChunkMesher.takeJobFailure(mapId, bodyOnly)
  local key = jobKey(mapId, bodyOnly and "body" or "full")
  local err = jobFailures[key]
  jobFailures[key] = nil
  return err
end

function ChunkMesher.jobPriority(mapId, bodyOnly)
  local job = jobIndex[jobKey(mapId, bodyOnly and "body" or "full")]
  return job and (job.priority or 0) or nil
end

function ChunkMesher.slotKnown(map, bodyOnly)
  local c = map and cache[map.id]
  return c ~= nil and c[bodyOnly and "body" or "full"] ~= nil
end

-- Advance queued builds inside a per-frame time budget. Urgent jobs (the
-- current map) come first and get the larger slice -- the first voxel
-- frame after a toggle is worth more milliseconds than a neighbour
-- popping in one frame later. `covered` says the world pass is hidden
-- this frame (a warp's fade, a menu): nothing visible can hitch, so the
-- slice opens up and a door fade swallows most of a destination build.
local FOREGROUND_SLICE = 0.012
local IDLE_SLICE = 0.005
local COVERED_SLICE = 0.030

local function nextJob()
  local pick = jobs[1]
  for i = 2, #jobs do
    local candidate = jobs[i]
    if (candidate.priority or 0) > (pick.priority or 0) then pick = candidate end
  end
  return pick
end

-- The fixed slices above are a CEILING, not a target. On a machine with room
-- to spare they are never reached; on a machine already missing its frame,
-- spending a flat 12 ms on top of an already-full frame is what turns a busy
-- frame into a dropped one. So measure what the rest of the frame costs and
-- hand meshing a share of what is actually left, with a floor so builds still
-- finish on a machine with no headroom at all.
local FRAME_TARGET = 1 / 60
local SHARE = 0.75
local MIN_SLICE = 0.0015

ChunkMesher.frameTarget = FRAME_TARGET

-- Hosts that run at something other than 60 (a 30 Hz handheld mode, a 120 Hz
-- panel) can move the target the headroom is measured against.
function ChunkMesher.setFrameTarget(seconds)
  seconds = tonumber(seconds)
  if seconds and seconds > 0 then
    ChunkMesher.frameTarget = seconds
  end
end

local lastSpend = 0    -- seconds this module burned last pump
local avgOther = nil   -- smoothed seconds the REST of the frame costs

local function sliceFor(urgent, covered)
  -- A covered frame draws no world, so there is nothing to hitch and the
  -- adaptive measurement does not apply: take the whole fade.
  if covered then return COVERED_SLICE end
  local cap = urgent and URGENT_SLICE or IDLE_SLICE
  local dt = (love and love.timer and love.timer.getDelta
              and love.timer.getDelta()) or ChunkMesher.frameTarget
  local other = math.max(0, dt - lastSpend)
  avgOther = avgOther and (avgOther * 0.8 + other * 0.2) or other
  local headroom = ChunkMesher.frameTarget - avgOther
  return math.max(MIN_SLICE, math.min(cap, headroom * SHARE))
end

-- Seconds the last pump actually spent; for probes and overlays.
function ChunkMesher.lastSlice() return lastSpend end

function ChunkMesher.pump(covered)
  if #jobs == 0 then lastSpend = 0 return end
  local pick = nextJob()
  local started = clock()
  local slice = sliceFor((pick.priority or 0) > 0, covered)
  local deadline = started + slice
  while pick do
    if not pick.co then
      pick.co = coroutine.create(runJob)
    end
    Budget.begin(pick.co, deadline - clock())
    local ok, err = coroutine.resume(pick.co, pick)
    Budget.finish()
    if not ok then
      finishJob(pick, false, err)
    elseif coroutine.status(pick.co) == "dead" then
      finishJob(pick, true)
    else
      lastSpend = clock() - started
      return   -- slice spent mid-build; resume next frame
    end
    if clock() >= deadline or #jobs == 0 then
      lastSpend = clock() - started
      return
    end
    pick = nextJob()
  end
  lastSpend = clock() - started
end

-- Meshes for `map`, built SYNCHRONOUSLY on first use -- the historical
-- contract, kept for probes and any direct caller. `false` is cached for
-- a map whose mesh could not be built so a headless run does not retry
-- every frame. `masks` (the full variant's neighbour-body rects) is
-- static per map id -- a map's connections never change -- so it caches
-- like everything else.
function ChunkMesher.get(map, bodyOnly, masks)
  local slot = bodyOnly and "body" or "full"
  local c = entry(map.id)
  if c.grass == nil or c.flowers == nil or (c.stale and c.stale.aux) then
    local okG, grass = pcall(buildGrassMesh, map)
    local okF, flowers = pcall(buildFlowerMesh, map)
    swapSlot(c, "grass", (okG and grass) or false)
    swapSlot(c, "flowers", (okF and flowers) or false)
    if c.stale then c.stale.aux = nil end
  end
  if c[slot] == nil or (c.stale and c.stale[slot]) then
    local ok, mesh, water = pcall(ChunkMesher.build, map, bodyOnly, masks,
                                  true)
    if not ok then
      print("[warn] voxel mesh build failed for " .. tostring(map.id)
            .. ": " .. tostring(mesh))
    end
    swapSlot(c, slot, (ok and mesh) or false)
    swapSlot(c, waterSlot(slot), (ok and water) or false)
    if c.stale then
      c.stale[slot] = nil
      if not (c.stale.full or c.stale.body or c.stale.aux) then
        c.stale = nil
      end
    end
    local key = jobKey(map.id, slot)
    local job = jobIndex[key]
    if job then finishJob(job, true) end
  end
  return c[slot] or nil
end

-- The cached mesh, or nil -- never builds. The async path's read side.
function ChunkMesher.peek(map, bodyOnly)
  local c = cache[map.id]
  local mesh = c and c[bodyOnly and "body" or "full"]
  return mesh or nil
end

-- A slot's terrain mesh AND the water surface lifted out of it, as one
-- answer. Never builds, like peek.
--
-- Both or neither, always from the SAME slot: the water was cut out of that
-- exact geometry, so pairing a full mesh with a body build's water would
-- draw the border ring's ponds twice and leave the body's as holes. Callers
-- that fall back from one variant to the other fall back through this, so
-- there is nowhere for the two to be chosen separately.
function ChunkMesher.pair(map, bodyOnly)
  local c = cache[map.id]
  if not c then return nil, nil end
  local slot = bodyOnly and "body" or "full"
  return c[slot] or nil, c[waterSlot(slot)] or nil
end

function ChunkMesher.grass(map)
  local c = cache[map.id]
  return c and c.grass or nil
end

function ChunkMesher.flowers(map)
  local c = cache[map.id]
  return c and c.flowers or nil
end

-- Authored figures as `{ mesh, wx, wz, y, w }` records -- each placed by
-- its own leaning matrix at draw time, so they cannot share one mesh.
function ChunkMesher.figures(map)
  local c = cache[map.id]
  local list = c and c.figures
  return (type(list) == "table") and list or nil
end

-- Rebuild a map's meshes IN PLACE: the stale meshes keep drawing while
-- replacements cook, and each slot swaps as its build lands. This is
-- the block-edit path (a cut tree, a door stamp) -- invalidate() drops
-- the mesh outright, and until the async rebuild landed the scene fell
-- to the flat 2D path, a whole-world blink for a one-block edit.
function ChunkMesher.refresh(mapId)
  if not mapId then return ChunkMesher.invalidate() end
  local c = cache[mapId]
  -- nothing drawable cached: the plain drop costs nothing visible
  if not (c and (c.full or c.body)) then
    return ChunkMesher.invalidate(mapId)
  end
  Structures.invalidate(mapId)
  gen[mapId] = (gen[mapId] or 0) + 1
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if job.id == mapId then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
  -- false-cached slots count as stale too: a retry after a failed build
  -- is exactly a rebuild
  c.stale = { aux = true,
              full = (c.full ~= nil) or nil,
              body = (c.body ~= nil) or nil }
end

-- Evict everything outside `live` (a set of map ids): far maps' meshes
-- are released -- GPU buffer and LOVE's CPU copy both -- and their
-- Structures analysis dropped. The live set is the current map plus its
-- rendered neighbours, so memory stays bounded by what is on or near the
-- screen instead of growing with every area ever visited.
--
-- The PREVIOUS live set is retained too: warping into a building
-- collapses the set to one small interior, and evicting the town at the
-- door means rebuilding the whole neighbourhood on the way out -- a
-- flat-world flash after every house. One set of history makes the
-- round trip free while staying bounded at two neighbourhoods.
local prevLive = {}

function ChunkMesher.setLive(live)
  for id, c in pairs(cache) do
    if not live[id] and not prevLive[id] then
      releaseEntry(c)
      cache[id] = nil
      gen[id] = (gen[id] or 0) + 1
      Structures.invalidate(id)
    end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if not live[job.id] and not prevLive[job.id] then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
  prevLive = live
end

-- Release session GPU meshes and Structures analysis without touching the
-- version-scoped disk records. Whole-world generation uses this between maps
-- so precaching does not retain a GPU copy of the complete game.
function ChunkMesher.evictRuntime(mapId)
  local function evict(id)
    local c = cache[id]
    if c then releaseEntry(c) end
    cache[id] = nil
    gen[id] = (gen[id] or 0) + 1
    Structures.invalidate(id)
  end
  if mapId then
    evict(mapId)
  else
    local ids = {}
    for id in pairs(cache) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do evict(id) end
    prevLive = {}
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if mapId == nil or job.id == mapId then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

-- Drop one map's mesh (Cut swapped a block) or all of them (hot reload).
-- Structures' analysis is derived from the same block layer, so it drops
-- in the same breath; in-flight builds of the map are cancelled through
-- the generation counter.
function ChunkMesher.invalidate(mapId)
  Structures.invalidate(mapId)
  if mapId then
    local c = cache[mapId]
    if c then releaseEntry(c) end
    cache[mapId] = nil
    gen[mapId] = (gen[mapId] or 0) + 1
  else
    for _, c in pairs(cache) do releaseEntry(c) end
    cache = {}
    for id in pairs(gen) do gen[id] = gen[id] + 1 end
  end
  for i = #jobs, 1, -1 do
    local job = jobs[i]
    if mapId == nil or job.id == mapId then
      jobIndex[jobKey(job.id, job.slot)] = nil
      table.remove(jobs, i)
    end
  end
end

Assets.register(function() ChunkMesher.invalidate() end)

-- Explicit CACHE / DROP: discard runtime meshes and delete this game
-- version's persistent CPU records. Missing/read-only storage fails open.
function ChunkMesher.purgeCache()
  ChunkMesher.invalidate()
  if MeshDisk and MeshDisk.purge then pcall(MeshDisk.purge) end
end

return ChunkMesher
