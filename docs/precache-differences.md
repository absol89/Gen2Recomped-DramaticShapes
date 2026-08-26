# Precache implementation differences

## Purpose

Both maintained branches need a persistent voxel mesh precacher, but they should
not receive the same implementation wholesale:

- `codex/battle-art-voxel-gen2` is closest to the older Gen 1 renderer path. Port
  the proven cache boundary from `dev/DramaticShapeVoxelMod`, adapting only the
  cache-related changes to this branch's current files.
- `port/gen1recomp-GSC` has Gen 2 map loading, tileset profiles, roof composition,
  and newer engine/storage expectations. Use `dev/potato_voxel` as the reference
  for lifecycle, resume, mobile behavior, and diagnostics, but preserve
  BattleArtGen2's current renderer and add a narrow persistent-geometry boundary.

The common goal is to build CPU geometry ahead of play, persist it safely, and
reconstruct GPU meshes on demand. Prebuilding must not retain GPU meshes for the
whole game or stall startup with an unbounded scan.

## Baseline comparison

| Area | `codex/battle-art-voxel-gen2` | `port/gen1recomp-GSC` |
| --- | --- | --- |
| Best reference | `dev/DramaticShapeVoxelMod` | `dev/potato_voxel` plus the DramaticShape serialization seam |
| Engine baseline | `>=0.1.37` | `>=0.2.20` |
| Game path | Shared/pre-port renderer path | Gold and Silver Gen 2 path |
| Current mesher | Directly creates GPU meshes | Same `ChunkMesher` API as the codex branch |
| Map preparation | Existing map/tileset data | `Gen2WorldAdapter.prepareMap` and composed Gen 2 atlases |
| Storage approach | Preserve compatibility with the branch's supported engine backends | Prefer scoped `mod.storage`; no new legacy filesystem dependency |
| Mobile policy | Cooperative main-thread build is sufficient initially | Cooperative serial build is required; worker geometry is opt-in only after profiling |
| UI entry points | Title `PRECACHE`; start-menu `CACHE` | Touch-accessible options rows before `VOXEL GRID`, plus readiness/status actions |

Neither target branch currently contains the reference cache modules or a raw
geometry serialization seam. Their `ChunkMesher` implementations are currently
the same, so the low-level record format can share tests, but Gen 1 and Gen 2
cache namespaces must remain distinct.

## Shared cache contract

Implement these rules on both branches before adding branch-specific UI:

1. **Persist CPU geometry, not GPU objects.** Extend the meshing sink so a job can
   return vertex/index streams and auxiliary geometry as plain Lua data. Add a
   single reconstruction function that validates a record and creates runtime
   meshes.
2. **Keep the cache optional.** A missing, stale, corrupt, or unwritable cache is
   a miss, never a reason gameplay cannot render. Fall back to the existing
   synchronous/queued meshing path and journal the failure for diagnostics.
3. **Use stable identities.** A key must include game generation, game/version,
   mod cache family/revision, map identity, BODY/FULL slot, connection mask,
   geometry settings, tileset/profile inputs, and void-fill rules. It must not
   include userdata addresses, live image identity, palette, or transient camera
   state.
4. **Separate runtime and disk eviction.** Normal map transitions may evict RAM
   meshes without deleting persistent records. Explicit wipe/invalidation owns
   disk deletion.
5. **Write atomically and resume safely.** Write a record to a temporary key/file,
   verify its header, counts, bounds, checksum, and identity, then publish it.
   Track completion in a manifest so cancellation or a crash can resume without
   treating a partial record as valid.
6. **Bound each frame.** Enumerating maps, loading maps, meshing, encoding, and
   storage writes must be incremental. Current and visible gameplay work must
   preempt speculative and whole-game prebuild work.
7. **Bound memory.** Hold only the active record and a small queue of completed
   records. Whole-game precaching must not instantiate or retain all GPU meshes.
8. **Version formats independently.** Use distinct cache families such as
   `gen1-v1` and `gen2-v1`, even though the mod ID is shared. A format bump or
   geometry change invalidates only its own family.

Suggested shared modules (names may be adjusted to existing conventions):

- `lib/VoxelMeshRecord.lua`: record validation, encode/decode, and GPU rebuild.
- `lib/VoxelMeshDisk.lua`: keys, manifest, atomic persistence, lookup, wipe, and
  failure journal.
- `lib/VoxelPrecache.lua`: job enumeration, priorities, cancellation, progress,
  and resume state.

Keep branch-specific map preparation and UI outside those modules.

## Plan for `codex/battle-art-voxel-gen2`

### 1. Port the serialization seam surgically

Use DramaticShape's `VoxelMeshDisk.lua`, `StaticGeometry.lua`, and cache-related
`ChunkMesher.lua` changes as the source of truth, but do not replace the target
files wholesale. The reference renderer has accumulated unrelated changes.

Changes:

- Add raw sink output and `meshFromRaw`/auxiliary reconstruction to
  `lib/ChunkMesher.lua`.
- Check the disk cache before running a BODY or FULL job; save a validated raw
  record after successful geometry generation.
- Add the cache-facing queue API needed by the screens and scheduler:
  `jobPending`, `takeJobFailure`, `jobPriority`, and `slotKnown`.
- Replace the boolean urgent flag internally with explicit current, visible, and
  speculative priorities while retaining a compatibility path for existing
  callers.
- Add runtime-only eviction/invalidation operations without changing persistent
  storage unless explicitly requested.

### 2. Establish canonical static geometry

Port the purpose of DramaticShape's `StaticGeometry.lua`:

- Capture the final modded `data.maps` and `data.tilesets` after other mods have
  loaded.
- Produce immutable canonical map inputs for precache jobs.
- Compare geometry-bearing fields and reject persistent writes for maps mutated
  at runtime. Transient runtime maps may still be meshed and held in RAM.
- Fingerprint only fields that can change emitted geometry.

This prevents a cached static map from being reused for a scripted or dynamically
modified map with the same name.

### 3. Port the proven scheduler and job set

Adapt DramaticShape's `VoxelPrecache.lua`:

- Generate one FULL job for every canonical map.
- Generate BODY jobs only for maps participating in connections; these are the
  maps whose bodies may be needed as neighboring void-ring content.
- Compute connection masks with
  `OverworldController.computeNeighbors(map, 2)`.
- Predictively enqueue warp and connection destinations during normal gameplay.
- Deduplicate jobs by stable identity and allow gameplay priorities to preempt
  background work.

### 4. Integrate storage and lifecycle

- Bind storage only after the mod/game context is ready.
- Preserve DramaticShape's compatibility behavior for the older engine baseline,
  including a safe RAM-only fallback when persistent storage is unavailable.
- Initialize a session on new game and preload only relevant known records on
  continue/restore. Do not eagerly materialize the complete cache as GPU meshes.
- Pump predictive precaching from the always-running update path, with a strict
  per-frame budget.

### 5. Add the existing menu model

Port the DramaticShape user flow:

- Add `PRECACHE` before `EXIT` on the title menu. Its screen can build, resume,
  cancel, and report progress/failures for the whole-game cache.
- Add `CACHE` before `SAVE` on the start menu for status plus explicit save/drop
  actions.
- Preserve the branch's input/navigation conventions and verify both keyboard
  and controller operation.

Expected new/adapted files:

- `lib/VoxelPrecache.lua`
- `lib/VoxelPrecacheScreen.lua`
- `lib/VoxelMeshDisk.lua`
- `lib/VoxelCacheRamScreen.lua`
- `lib/StaticGeometry.lua`
- cache-specific edits to `lib/ChunkMesher.lua` and `main.lua`

### 6. Codex-branch validation

- Unit-test canonical-map eligibility, fingerprints, connection masks, candidate
  deduplication, and the optimized FULL/BODY job set.
- Round-trip every raw geometry stream and reject invalid counts, indices,
  checksums, identities, and truncated payloads.
- Test both supported storage paths plus unavailable/read-only storage fallback.
- Verify title/start menu ordering and continue/new-game/restore lifecycle hooks.
- Confirm a warm connection or warp avoids regeneration and that runtime
  eviction leaves the disk record intact.

## Plan for `port/gen1recomp-GSC`

### 1. Preserve the Gen 2 renderer and define its cache boundary

Do not transplant PotatoVoxel's `ChunkMesher`, `MeshRuntime`, or queue stack.
Those modules use a different indexed-stream and worker architecture. Instead:

- Add the same narrow raw-record/reconstruction seam described in the shared
  contract to BattleArtGen2's current `lib/ChunkMesher.lua`.
- Keep `Structures`, `TerrainAtlas`, battle rendering, and live queue semantics
  intact.
- Use a Gen 2-specific cache family/revision so records can never collide with
  the codex branch.

This gives the branch persistent geometry without making the precacher a renderer
rewrite.

### 2. Build a canonical Gen 2 map source

This is the largest branch-specific difference. A prebuild job must load a map
through the Gen 2 loader/facade and prepare it with
`Gen2WorldAdapter.prepareMap`, or an offline equivalent, before geometry is
generated. The canonical source must:

- enumerate all Gold/Silver maps deterministically;
- normalize tileset names exactly as the runtime does;
- attach the correct Gen 2 tileset/profile and renderer data;
- account for roof-composed atlas inputs used by the live world;
- snapshot only stable geometry-bearing map, block, collision, tileset, and
  profile inputs.

Do not fingerprint the composed image userdata or current palette. Geometry
records should remain valid across palette/day/night changes; `TerrainAtlas`
continues to supply runtime color and texture state. If an auxiliary mesh truly
depends on decoded atlas pixels, initially build that auxiliary data on the main
thread from a stable pixel snapshot rather than serializing image identity.

Add a Gen 2 counterpart to `StaticGeometry` (or a generation-aware implementation)
that detects runtime map mutation before permitting a persistent write.

### 3. Adapt PotatoVoxel's prebuild lifecycle

Use `CachePrebuild.lua`, `MeshCache.lua`, and `CacheFeature.lua` as behavioral
references rather than copy sources:

- bootstrap only after `game.ready` and storage binding;
- scan/validate the manifest incrementally across updates;
- automatically resume an incomplete cache with a visible status and cancel
  control;
- prioritize current-map warmup, then connection/warp candidates, then the
  deterministic whole-game queue;
- prime the first/current BODY record without waiting for the entire cache;
- retain progress, cancellation, failure, resume, and corruption diagnostics;
- expose cache readiness without gating ordinary rendering on success.

Start with the same optimized job policy as the codex branch—FULL for every map,
BODY only where connections require it—unless Gen 2 route testing demonstrates a
runtime body lookup not represented by map connections. PotatoVoxel currently
builds both slots for every map; that is simpler but costs more time and storage.

### 4. Use modern scoped storage

- Store manifests and records through the engine's scoped `mod.storage` API.
- Do not add the legacy `love.filesystem` compatibility layer from the older
  reference unless a supported Gen 2 platform proves it necessary.
- Include game (`gold`/`silver` where their data differs), engine/mod cache
  revision, geometry settings, tileset profiles, and void-fill behavior in the
  identity.
- Verify and atomically publish each record; wipe only this branch's cache
  namespace.

### 5. Ship a cooperative mobile-safe implementation first

PotatoVoxel's profiling found CPU geometry workers slower on Android/iOS. The
first port implementation should therefore:

- use incremental serial geometry on all platforms;
- keep map loading and storage on the main thread;
- cap geometry/storage work per frame and yield between chunks/maps;
- guarantee that current/visible gameplay jobs preempt prebuild work.

Treat compute workers as a later optimization. Add them only after geometry can
run as a pure CPU function over an immutable snapshot, the manifest requests the
`compute` permission, threaded output passes byte-for-byte/index-range parity
tests, and desktop profiling shows a useful win. A dedicated decode worker may be
evaluated separately because decompression and geometry generation have different
mobile costs.

### 6. Add touch-accessible settings UI

The branch already needs all important voxel controls reachable without the `3`
key. Add cache controls to the same options surface, before `VOXEL GRID`:

- `PREBUILD CACHE`: start/resume/cancel and display percentage/current map;
- `CACHE STATUS`: ready/incomplete/failed, record counts, size, and last error;
- `WIPE CACHE`: explicit confirmation, scoped to `gen2-v1` records.

If a post-continue readiness prompt is retained from PotatoVoxel, it should offer
`BUILD NOW` and a continue-without-cache path. It must not trap a player when
storage is unavailable.

Expected new/adapted files:

- shared record/disk/precache modules listed above;
- a Gen 2 canonical-map/snapshot module;
- a compact cache options/status screen;
- cache-specific edits to `lib/ChunkMesher.lua`, `lib/Gen2WorldAdapter.lua` (only
  if a reusable offline preparation entry point is needed), and `main.lua`.

### 7. Port-branch validation

- Enumerate and prebuild every Gold and Silver map through the Gen 2 loader.
- Compare precached and live-generated BODY/FULL streams, including index bounds,
  vertex counts, structures, grass/flower/figure auxiliaries, and void rings.
- Exercise roof/no-roof maps, every tileset profile, connections in all
  directions, warps, caves/interiors, and palette/day-night changes.
- Verify that palette changes reuse geometry while selecting the correct runtime
  atlas.
- Test cancellation, restart/resume, corrupt/truncated records, a stale cache
  revision, unwritable storage, and a failed single map without poisoning the
  manifest.
- Test Android/iOS policy without a geometry worker and verify every cache action
  is reachable by touch/controller through options.
- Measure boot time, worst prebuild frame time, first route/warp transition, peak
  RAM, persistent size, and warm-cache hit rate.

## What should not be copied

- Do not overwrite either target's complete `ChunkMesher.lua`, `main.lua`,
  `Structures.lua`, `TerrainAtlas.lua`, or scene code from a reference checkout.
- Do not copy PotatoVoxel's complete worker/mesh runtime into the port branch as
  the first implementation; it would turn cache work into a renderer migration.
- Do not cache GPU meshes, palette-specific textures, LÖVE userdata, or live atlas
  identities.
- Do not block gameplay on whole-cache readiness or perform an all-map build in a
  single update.
- Do not share persistent keys between Gen 1 and Gen 2 merely because the mod ID
  is the same.

## Acceptance criteria

The precacher is ready on a branch when:

- a cold build can be cancelled and resumed after restart without accepting
  partial records;
- corrupt, stale, missing, or unwritable cache data falls back to normal meshing;
- current gameplay work always preempts prebuild work;
- warm BODY/FULL requests reconstruct the same geometry as live meshing;
- boot and menu entry never perform an unbounded synchronous map scan;
- peak memory stays bounded independently of the number of maps;
- cache/status/wipe controls are reachable on the branch's supported inputs;
- automated tests cover identity, round-trip, invalidation, persistence, and
  lifecycle, followed by route/warp smoke tests on the actual engine.

## Recommended implementation sequence

Keep the branches reviewable with small commits:

1. Shared raw geometry record, validation, and round-trip tests.
2. Storage identity, manifest, atomic writes, corruption handling, and tests.
3. Canonical static-map source (branch-specific).
4. Incremental scheduler, priorities, cancellation, and resume.
5. Runtime cache lookup/save integration in `ChunkMesher`.
6. Predictive connection/warp warmup.
7. Branch-specific UI and lifecycle integration.
8. Real-engine route/warp profiling and tuning.
9. Optional desktop compute/decode workers only if profiling justifies them.

Implement and validate the record contract on `codex/` first because its
DramaticShape reference is closest. Then reuse the tested format concepts—not its
cache namespace or canonical-map logic—while building the Gen 2 adapter on
`port/`.
