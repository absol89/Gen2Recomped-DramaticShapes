-- Cherrygrove's northeast connection gap is a voxel-only forest apron.
-- It must not replace the city's real water or leak onto another map.

local data = assert(loadfile("data/voxel_map_aprons.lua"))({})
local V = {
  data = function(name)
    assert(name == "voxel_map_aprons", name)
    return data
  end,
}
local MapAprons = assert(loadfile("lib/MapAprons.lua"))(V)

local structuresFile = assert(io.open("lib/Structures.lua", "rb"))
local structuresSource = assert(structuresFile:read("*a"))
structuresFile:close()
assert(loadstring(structuresSource, "@lib/Structures.lua"),
  "Structures no longer compiles with the map-apron integration")
assert(structuresSource:find("MapAprons.tileAt(map, tx, ty)", 1, true),
  "Structures stopped consulting authored map aprons")
assert(structuresSource:find("tx < ringX0 or tx > ringX1", 1, true),
  "a distant apron can stretch Cherrygrove's generic water fill again")
assert(structuresSource:find("MapAprons.genericBorderAllowed(map, tx, ty)",
                             1, true),
  "Structures stopped applying Cherrygrove's rectangular water scope")
assert(structuresSource:find("not MapAprons.containsTile(map, cx * 2, cy * 2)",
                             1, true),
  "authored forests can be rounded into camera-dependent edge gaps again")

local blocks = {}
for id = 0, 5 do
  blocks[id + 1] = {}
  for i = 1, 16 do blocks[id + 1][i] = id * 16 + i - 1 end
end
local cherry = { id = "CHERRYGROVE_CITY", tileset = { blocks = blocks } }
local route29 = { id = "ROUTE_29", tileset = { blocks = blocks } }
local route30 = { id = "ROUTE_30", tileset = { blocks = blocks } }
local route31 = { id = "ROUTE_31", tileset = { blocks = blocks } }
local route46 = { id = "ROUTE_46", tileset = { blocks = blocks } }

assert(MapAprons.genericBorderAllowed(cherry, -12, 0),
  "Cherrygrove lost the west edge of its yellow water rectangle")
assert(MapAprons.genericBorderAllowed(cherry, 39, 47),
  "Cherrygrove lost the southeast corner of its yellow water rectangle")
assert(not MapAprons.genericBorderAllowed(cherry, -1, -1),
  "Cherrygrove still allows the crossed-out northwest water")
assert(not MapAprons.genericBorderAllowed(cherry, 40, 36),
  "Cherrygrove still allows the crossed-out southeast water")
assert(MapAprons.genericBorderAllowed(route29, 999, -999),
  "Cherrygrove's water scope leaked onto an unrelated map")
assert(MapAprons.containsTile(cherry, 15 * 4, -1),
  "the Pokecenter forest backdrop is not marked as authored terrain")
assert(not MapAprons.containsTile(cherry, 14 * 4, -1),
  "the authored-forest marker leaked west of the Pokecenter backdrop")

local connector = assert(data.connectors.CHERRYGROVE_NORTHEAST_FOREST)
assert(connector.width == 15 and connector.height == 36
    and connector.block == 0x05 and connector.southEdgeSourceRow == 2,
  "shared forest connector is not one 15x36 tree map")
local route29South = assert(data.connectors.ROUTE_29_SOUTH_FOREST)
assert(route29South.width == 30 and route29South.height == 3
    and route29South.block == 0x05,
  "Route 29's shared southern forest is not a 30x3 tree strip")

for by = -36, -1 do
  for bx = 15, 29 do
    assert(MapAprons.blockAt(cherry, bx, by) == 0x05,
      ("missing tree apron at block %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(cherry, 14, -1) == nil,
  "forest connector crossed west into Route 30")
assert(MapAprons.blockAt(cherry, 30, -1) == nil,
  "forest connector extended beyond its east edge")
assert(MapAprons.blockAt(cherry, 15, 0) == nil,
  "tree apron replaced in-bounds Cherrygrove water")

for by = -36, -1 do
  for bx = -5, 9 do
    assert(MapAprons.blockAt(route29, bx, by) == 0x05,
      ("missing reciprocal Route 29 apron at block %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(route29, 10, -1) == nil,
  "forest connector extended past its Route 29 east edge")
assert(MapAprons.blockAt(route29, -5, 0) == nil,
  "Route 29 apron extended south into Cherrygrove's real body")

-- Negative tile coordinates must retain normal 4x4 metatile alignment.
assert(MapAprons.tileAt(cherry, 60, -12) == 0x50,
  "apron north-west tile did not come from Johto block $05")
assert(MapAprons.tileAt(cherry, 79, -1) == 0x5b,
  "apron south edge did not continue its foliage row")
assert(MapAprons.tileAt(cherry, 119, -1) == 0x5b,
  "Cherrygrove east-ring edge did not continue its foliage row")
assert(MapAprons.tileAt(cherry, 119, -5) == 0x5f,
  "the south-edge rule leaked into an interior tree block")
assert(MapAprons.tileAt(route29, -20, -60) == 0x50,
  "Route 29 apron north-west tile lost negative metatile alignment")
assert(MapAprons.tileAt(route29, 39, -1) == 0x5b,
  "Route 29 apron south edge did not continue its foliage row")

for by = -9, 26 do
  for bx = 10, 24 do
    assert(MapAprons.blockAt(route30, bx, by) == 0x05,
      ("missing reciprocal Route 30 apron at block %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(route30, 9, 24) == nil,
  "Route 30 apron replaced the route's east body edge")
assert(MapAprons.blockAt(route30, 10, 27) == nil,
  "Route 30 apron extended south into the connected map bodies")
local x0, y0, x1, y1 = MapAprons.tileBounds(route30)
assert(x0 == 40 and y0 == -36 and x1 == 179 and y1 == 155,
  "Route 30's explicit mesh extent does not cover both shared forests")

-- Composing Route 30 -> Route 31 and Route 29 -> Route 46 connection
-- offsets must still place this one connector on the same world rectangle.
for by = 0, 35 do
  for bx = 20, 34 do
    assert(MapAprons.blockAt(route31, bx, by) == 0x05,
      ("missing reciprocal Route 31 apron at block %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(route31, 19, 0) == nil,
  "Route 31 apron extended west of the shared forest")
assert(MapAprons.blockAt(route31, 20, 36) == nil,
  "Route 31 apron extended south of the shared forest")

for by = -18, 17 do
  for bx = -15, -1 do
    assert(MapAprons.blockAt(route46, bx, by) == 0x05,
      ("missing reciprocal Route 46 apron at block %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(route46, -16, -18) == nil,
  "Route 46 apron extended west of the shared forest")
assert(MapAprons.blockAt(route46, 0, 3) == nil,
  "Route 46 apron replaced the route's real body")

for by = 9, 11 do
  for bx = 0, 29 do
    assert(MapAprons.blockAt(route29, bx, by) == 0x05,
      ("missing Route 29 south forest at block %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(route29, 0, 8) == nil,
  "Route 29 south forest replaced the real map body")
assert(MapAprons.blockAt(route29, 30, 9) == nil,
  "Route 29 south forest extended beyond the route's east edge")
for by = 9, 11 do
  for bx = 20, 49 do
    assert(MapAprons.blockAt(cherry, bx, by) == 0x05,
      ("Cherrygrove view lost Route 29 south forest at %d,%d"):format(bx, by))
  end
end
assert(MapAprons.blockAt(cherry, 19, 9) == nil,
  "Route 29 south forest filled beneath Cherrygrove")

local mesherFile = assert(io.open("lib/ChunkMesher.lua", "rb"))
local mesherSource = assert(mesherFile:read("*a"))
mesherFile:close()
assert(loadstring(mesherSource, "@lib/ChunkMesher.lua"),
  "ChunkMesher no longer compiles with variable apron extents")
assert(mesherSource:find("MapAprons.tileBounds(map)", 1, true),
  "ChunkMesher stopped extending FULL meshes to authored apron bounds")
assert(mesherSource:find("and maskedOpen(tx * 8, ty * 8", 1, true),
  "masked neighbour terrain can suppress exposed apron faces again")
assert(mesherSource:find("local authoredVolume = MapAprons.containsTile", 1,
                         true),
  "authored forest perimeters no longer force their exposed vertical faces")

print("Cherrygrove voxel tree-apron regression: ok")
