# Branch notes: `g2r7/stadium2-cleanup`

This branch targets the older Gen2Recomp v0.7.x data contract while porting
selected Battle Art changes from `port/gen1recomp-GSC`.

## Gen 2 map ID compatibility

The live v0.7.35 map extractor and the newer port branch spell route IDs
differently:

| Location | Gen2Recomp v0.7.x | Newer/port data |
| --- | --- | --- |
| Route 29 | `ROUTE29` | `ROUTE_29` |
| Route 30 | `ROUTE30` | `ROUTE_30` |
| Route 31 | `ROUTE31` | `ROUTE_31` |
| Route 46 | `ROUTE46` | `ROUTE_46` |

Multiword city IDs such as `CHERRYGROVE_CITY` remain underscored in both.

- Keep render-only authored data in the newer underscored form.
- Normalize runtime `map.id` values at the authored-data boundary in
  `lib/MapAprons.lua`; do not rename engine map definitions, connections,
  saves, or gameplay IDs.
- Cover both ID forms in regression tests whenever authored terrain is added
  to one of these routes.
- Use the canonical form in mesh fingerprints. Bump
  `VoxelMeshDisk.CACHE_REVISION` whenever ID compatibility changes which
  geometry a map emits.
- Verify IDs against the installed engine's generated data under
  `%APPDATA%/Gen2Recomp/<game>/data/generated/maps.lua`, not a newer source
  tree's map constants.

## Relevant connection graph

The v0.7.35 generated map data connects Route 30 north to `ROUTE31` (offset
-10) and south to `CHERRYGROVE_CITY` (offset -5). Route 31 connects south to
`ROUTE30` (offset +10) and west to `VIOLET_CITY` (offset -9). Route 29 connects
north to `ROUTE46` (offset +10) and west to `CHERRYGROVE_CITY`; Route 46
connects south to `ROUTE29` (offset -10).

The large northeast Cherrygrove forest is render-only authored geometry, not
a gameplay map. It therefore must be placed relative to every render root
that can see it rather than added as a synthetic engine neighbour. Closed
authored forest volumes must also survive `ChunkMesher`'s real-neighbour body
masks: those rectangles overlap the synthetic forest from Routes 29, 30, and
31 even though no real map body owns the visible terrain there. Do not extend
that exception to authored water or the ordinary border ring.
