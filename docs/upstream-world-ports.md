# Upstream world rendering ports, 2026-10-14

Target: this repository's **main**, for Gen1Recomp / G1R Deluxe's Gold,
Silver and Crystal runtime. The separate `g2r7/stadium2-cleanup` branch is
owned by the Gen2Recomped engine integration. It was inspected, not modified.

Reviewed sources:

- UNDERdecoded upstream `726782f223cac76b4e78cdadb24fa6ac78edaef0`, including
  [the optimization commit 4a114b3](https://github.com/UNDERdecoded/Gen2Recomped-DramaticShapes/commit/4a114b3).
- [g2r7/stadium2-cleanup](https://github.com/absol89/Gen2Recomped-DramaticShapes/tree/g2r7/stadium2-cleanup)
  at `9c5983971ad9ffd3d38ac247892bee7829d92b9f`.
- Local Gen1Recomp engine `7abe68b1`; native fixtures used the disposable
  engine snapshot `e50c396e` with the current mod sources.

## Feature decisions

| Feature | Main adaptation |
| --- | --- |
| Whole-mesh camera and shadow culling | Ported. Bounds are measured while emitting corners and stored with terrain/water cache records. Upstream's fixed bounds were surveyed on Hoenn and are not assumed to cover this port's authored rooms and props. |
| Performance tiers | Ported through the optional `src.core.Performance.tier` service. Unknown/unavailable service means uncapped. Saved options are never rewritten. |
| Moving-cast shadow rate | Balanced redraws at most every third stale frame when only poses change. Camera, sun, terrain, quality, invalidation and an intervening battle shadow pass force an immediate redraw. Failed allocations retry. |
| Generic decals without depth writes | Existing `beginShadows` already has this behavior. Upstream's additional callers are its Gen 3 ripple/effect paths; no unused API or Emerald effects were added. |
| Full-scene planar water mirror | Deferred: it adds a second scene render and substantially more GPU cost. Main already has its own cast-reflection integration. |
| Emerald structures, terrain seams, frame anchors | Not transplanted into Gen 2. Preserve this port's authored geometry and variable-size sprite contracts. |
| Upstream cache/scheduler replacement | Not transplanted. Preserve packed-byte sandbox support, streaming budgets, Cut spans, transition job cancellation and Gen 2 precaching. |
| Battle camera, Battle Art, Stadium and HUD changes | No ports. Their owning files are unchanged by this series. |

The new scope is active only inside flat-screen `VoxelScene.render`.
Shared renderer methods remain uncapped and exempt from culling outside that scope,
including the separate battle arena. VR world passes can contain battle cards,
so they also retain their previous behavior. Scope restoration runs on errors.
World AA gets an explicit world argument at its existing pipeline call site;
battle AA calls retain the default behavior.

Balanced caps shadow resolution at 1024, water at SKY and AA at 2X. Low disables
the shadow-map pass (existing decal fallback), reflective water and AA. High
retains the selected settings. Culling skips camera tests under world curvature;
the flat light-space pass can still cull. Unknown mesh bounds always draw.

Mesh cache revision **25** adds bounds after the existing terrain, water and
Cut-span records. Older records rebuild through normal fingerprint rejection.
Culling reduces draw submissions; it does not reduce live neighbor mesh memory
or eliminate cold transition builds. Corner-bound measurement adds build work;
this series does not claim a measured cold-build speedup.

## iOS canvas ownership

| Runtime path | Correction |
| --- | --- |
| Gen1Recomp/G1R Deluxe Gen 2 | `src/world/gen2/World.lua` directly draws the pipeline result. Keep main's LÖVE 12+ affected-renderer check and one mod presentation flip. |
| Gen1Recomp Gen 1 | `src/render/Renderer.lua` owns the world-override flip. Main's compatibility helper declines generation 1. |
| Gen2Recomped integration branch | Its helper declares the engine correction present from 0.7.6 and only pre-flips older iOS builds. This is that branch's contract, not a cross-engine version rule. |

Do not copy the 0.7.6 threshold into main: engine versions are unrelated, and
source builds use `0.0.0-dev`. The g2r7 helper also queries `love.system`, which
is blocked in main's current mod sandbox. Main uses renderer information.

Retain the existing raw-sky alignment fix: the 2D sky must agree with the raw
3D canvas before its final presentation reversal. A camera already supplying
`metalFlipY` is excluded. The final world-copy helper now saves/restores all
graphics state, including its canvas, shader, transform and clipping, on both
success and failure. UI and touch controls remain outside the world copy.

The side engine was not run, and no physical iOS device was available. Its
0.7.6 claim is evidence from branch source, not independent device validation.
No engine-name guessing or universal version cutoff was added.

## Validation

- Native LÖVE regressions passed: `mesh_bounds`, `world_quality`,
  `shadow_cadence`, `world_canvas_orientation`, `renderer_orientation`,
  `canvas_state_gpu`, `lws_host_contract`, `precache_streaming`,
  `precache_lifecycle`, `cut_cached_mesh`, `transition_job_retention`.
- Native GPU room-facing and sky-ray tests passed. The sky test simulates a
  Metal-style canvas reversal on Windows; it is not an iOS driver test.
- Battle layer order, voxel-grid ownership, Stadium circle depth, VR session
  gating, Gen 2 battle adapter and mobile renderer syntax checks passed.
- Room/geometry regressions and the 18-check Gen 2 water-reflection suite passed
  under LuaJIT through Lupa. SDK loading passed with the documented read-only
  directory probe workaround for the Windows harness.
- `battle_frame_retention.lua` fails its literal source-text assertion at line
  18 on both the result and pre-port `ca970b6`. It expects a direct return where
  the current pipeline routes the handoff canvas through presentation. The
  battle implementation was not changed to satisfy this stale assertion.
- A disposable Crystal source fixture completed at Celadon (20,10),
  Cherrygrove Mart (3,5) and Union Cave 1F (2,2), voxel 35, tilt-shift off,
  High/Balanced/Low, speed 1, no sync. Inspected Celadon's three tiers, Mart's
  High/Low and Cave's Low captures. Celadon logged 60 culled draw calls in the
  sampled High window and 32 in Balanced; these are submission counts, not FPS
  or a controlled performance comparison. The fixture used direct relocation,
  not a real door/route transition, and cold unbound cache generation.
- Evidence is under the engine workspace's `tmp/upstream-port-tests/`.
  Processes auto-quit with exit 0; only the disposable profile/source copy was
  used. Player saves, installed mod, package and the side-engine branch were
  not changed. No release ZIP, tag or push was performed.

Standalone tests run from the mod root. Native tests need a LÖVE host that
executes the selected file in `love.load`; `canvas_state_gpu` needs a graphics
context. Use the existing `tests/gpu_room_sky` host for `room_sky_gpu`.
