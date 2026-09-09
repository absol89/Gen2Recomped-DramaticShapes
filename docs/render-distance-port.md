# Gen 2 render distance

R.DIST is available in the shared settings surface, including VOXEL FULL.
SHORT/MEDIUM/FAR use radii of 16/32/64 movement cells (256/512/1024 world pixels).
MEDIUM is the default. FULL disables distance filtering.

The Gen 1 radius and nearest-map-edge calculations are compatible with Gen 2:
movement cells are 16 pixels and map blocks are 32 pixels. Gen 2 integration
uses a render-only view of connected maps, shared by prefetch and every scene
pass, preserving mesh/water array indexing. Original connection masks remain
stable as distance changes. Engine neighbor lists are never modified.

The current map remains fully rendered. Characters use point distance after
pose collection so animation timers advance normally; the player is retained.
Connected-map figures are filtered with their map. This does not implement
per-tile culling within the current map or change gameplay/simulation distance.
BattleScene's separate arena renderer is unchanged.

Validation: render_distance_gen2.lua passes radius/edge boundaries, cell fallback,
engine-world isolation, production prefetch selection, stable border masks,
mesh/water alignment, and live FULL restoration. Gen 2 water reflection passes
18 checks. Lua syntax and git whitespace checks pass. In-game camera/seam
visuals and device performance are not yet measured.

These changes are local follow-up work after the published 2.1.1 tag.
