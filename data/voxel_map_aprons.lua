-- Render-only maps which occupy holes in Gen 2's gameplay connection graph.
--
-- A connector is authored once, then placed relative to every real map that
-- touches it. It never enters the engine's map registry: there is no collision,
-- encounter, warp or transition state here, only Battle Art voxel terrain.

return {
  -- Limit a map's ordinary border material independently of the authored
  -- connector extents below. Real body/neighbor tiles always win first.
  borderScopes = {
    -- Keep only the southwest coastal apron: three blocks west of the city
    -- and three blocks south beneath its western ten blocks.
    CHERRYGROVE_CITY = { bx0 = -3, by0 = 0, bx1 = 9, by1 = 11 },
  },

  connectors = {
    CHERRYGROVE_NORTHEAST_FOREST = {
      width = 15,
      height = 36,
      block = 0x05, -- TILESET_JOHTO's solid tree wall on green ground
      -- Block $05's fourth tile row is its pale foot/ledge. At this artificial
      -- map edge that reads as a misauthored horizontal path, so continue the
      -- foliage from its third row through the connector's final tile row.
      southEdgeSourceRow = 2, -- zero-based row inside the 4x4 block
      connections = {
        -- The same 15x36 rectangle in each real map's 32px block
        -- coordinates. Its south edge is unchanged at Cherrygrove/Route 29;
        -- the north extension now starts beside Route 31's east edge.
        CHERRYGROVE_CITY = { bx = 15, by = -36 },
        ROUTE_29         = { bx = -5, by = -36 },
        ROUTE_30         = { bx = 10, by = -9 },
        ROUTE_31         = { bx = 20, by = 0 },
        ROUTE_46         = { bx = -15, by = -18 },
      },
    },

    -- Route 29 is a body-only neighbour while Cherrygrove is the render root,
    -- so its ordinary three-block tree ring would otherwise disappear. Keep
    -- that southern strip as shared authored terrain without filling beneath
    -- Cherrygrove's eastern half.
    ROUTE_29_SOUTH_FOREST = {
      width = 30,
      height = 3,
      block = 0x05,
      connections = {
        CHERRYGROVE_CITY = { bx = 20, by = 9 },
        ROUTE_29         = { bx = 0, by = 9 },
        ROUTE_30         = { bx = 15, by = 36 },
        ROUTE_31         = { bx = 25, by = 45 },
        ROUTE_46         = { bx = -10, by = 27 },
      },
    },
  },
}
