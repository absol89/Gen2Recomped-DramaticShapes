# Battle Art Gen2 performance provider API

`BATTLE_ART_VOXEL_GEN2` exposes a read-only performance producer at
`mod.exports.performance`. Capture cadence, aggregation, report generation and UI
belong in the standalone performance-monitor mod.

Current API/schema version: `1`.

The descriptor contains `apiVersion`, `schemaVersion`, `sourceModId`,
`sourceVersion`, `capabilities`, `snapshot()` and `storageSnapshot()`.

`snapshot()` is intended for regular sampling and does not enumerate persistent
storage. Gen2 2.1.x currently exposes:

- cache availability/read-only flags and RAM cache state;
- a bounded structured cache-event trace with monotonic sequence/counters;
- ChunkMesher resident/settled/stale-map counts and pending queue pressure;
- shadow target resolution, session allocations and active state.

The Gen1-specific `LoadTimings`, `CommunityFlora` tree cache and `SaplingEdits`
domains do not exist in this Gen2 codebase, so their capability values are `0`
and their snapshot sections are empty rather than fabricated measurements.

Persistent cache inventory can invoke `storage.list`, so it is deliberately
separate behind `storageSnapshot()` and should only be called after or outside a
hot capture window.

All returned tables are detached copies. Consumers should require
`apiVersion == 1` and inspect `capabilities` before relying on optional domains.
