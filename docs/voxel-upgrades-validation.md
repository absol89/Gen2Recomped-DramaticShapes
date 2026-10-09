# Gen 2 voxel upgrade candidate

This is a source-only visual port onto target base
`59e11d4a968603ca8a3c786bb5e37d80332f2b74`. The authored visual source was
selected from the pre-DS301 r145 lab snapshot (archive SHA-256
`64b875649b8c048d9b83012dca5c1eb678a081d10f10eeff32ed3fe4f3822c26`).
The archive itself, game data, imported art and binaries are not included.
The host manifest identity and release version are unchanged.

## Scope

- Building and traditional roof presentation, Park entrance matching and
  Crystal tower profile corrections.
- Interior furniture, electronics, lab equipment, stairs, room finishes,
  doors and exact wall closures, selected by map/art signatures.
- Native-atlas tree/flower presentation, native grass preservation, and
  map-specific floor/wall atlas finishes.
- National Park benches, signs, flower beds, edge-aligned perimeter hoops,
  raised pond border profiles and open pond center. `Gen2ParkBoundary` is
  the structural-only extraction; it does not install a ground material pack.
- Cached prop ground/visual offsets and geometry cache revision 23.
- Documentation and tests for existing optional LWS host seams; see
  [LWS compatibility](lws-compatibility.md). Weather rendering remains owned
  by the separate companion.

Excluded: DS301-derived ports, horizon extensions, new cave/waterfall behavior,
Legendary ground imports, private companion assets/source, Quest controls,
watch/tablet/belt features, and the HGSS-specific seated sprite relief.
No gameplay, encounter, collision or map-event changes are intended.

## Source and synthetic verification (2026-10-09)

Run from this mod's root with LuaJIT:

```text
luajit tests/gen2_park_boundary.lua
luajit tests/lws_host_contract.lua
luajit tests/gen2_world_adapter.lua
luajit tests/gen2_static_ground_anchor.lua
```

These pass, along with all 13 `tests/test_*.lua` files introduced by this
candidate: architecture, ceiling fallback, desks, exact interior doors,
fixture wall columns, furniture, home fixtures, indoor floors, small props,
native grass, nature, Park props and sign backs. Tests use synthetic fixtures
and mocked services, not imported ROM data or a real GPU. The Park boundary
test covers both Park map IDs. LWS tests do not load the companion.

`tests/render_distance_gen2.lua` currently fails with a missing `CacheTrace`
global in its extracted-function mock. This was reproduced on the unchanged
target base as well as this candidate; it is not counted as a passing test.

## Remaining acceptance gates

This candidate is not visually accepted or device-qualified. Prior lab views
do not prove the new upstream combination works. Before merging, review
Silver and Crystal separately, recording engine/mod versions, options,
map/cell/facing and before/after views:

- Park perimeter corners, entrance doors, pond border and center, all bench
  and sign sides, flower beds, and NPC/prop overlap from multiple angles.
- Player house both floors/stairs, Elm's lab, marts/centers, Radio Tower,
  Goldenrod Underground/warehouse, Rocket base, Ecruteak and tower exteriors.
- Native sprites and optional imported sprites; local/connected-map actors,
  jump lift and event positions. Prop producer tests do not yet execute the
  full local/ghost `VoxelScene` pose consumers.
- Flat/voxel transitions, entering/leaving maps, palette/time changes,
  animated water, cache rebuild/reuse and memory behavior.
- Optional LWS absent/present/disabled, menus/battles, and stereo/state
  restoration if a compatible Quest bridge is used.

Additional boundary-test gaps: rejected partial fountain patterns and
deep snapshots of unrelated render-grid tables. No FPS, headset, live weather
or complete world-wide regression claim is made by this source review.
