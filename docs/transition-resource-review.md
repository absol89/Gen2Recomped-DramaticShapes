# Area transitions and inactive VR review (2026-10-13)

Update: PR #5 has since been merged and pulled into this checkout at `4a29c76`.
The engine now includes latest dev through `7abe68b1`. Local performance and
user edits were reapplied. See `issue3-continue-context.md` for the subsequent
menu-context investigation and updated validation. The baseline records below
describe the earlier separate-candidate testing.

Baseline: engine `dev` with existing local edits; mod `main` at `59e11d4`.
Installed source junction resolves to this checkout. Existing guide/survey
edits were preserved. PR #5 head `74fdfec` was extracted to an isolated scratch
directory for review; it was not installed or merged.

The battle setting gates now consult `VR.active()` instead of the stored
`VR.enabled()` setting. An enabled setting without a running headset respects
desktop 3D-BTL and BACK SPRITES choices; active VR still forces world battlers.
This is a setting regression fix, not proof that every black battle in issue
#4 has this cause. The production gate regression and Gen2 battle adapter pass
with mocked dependencies; GPU battle appearance remains unverified.

Transition inspection found cooperative build slices of 12 ms foreground,
5 ms idle and 30 ms covered. Uploads are sliced into 65,536 vertices (roughly
1.5 MiB). These are cooperative deadlines, not preemptive guarantees. Precaching
still needs lazy GPU uploads. `VoxelMeshDisk.eagerLoadAllowed()` permits Linux
classified as desktop to preload compressed cache without a cap; Steam Deck
pressure is a hypothesis requiring actual device logs, not a reproduced OOM.
Dirty compressed containers may exceed the soft RAM budget to preserve data.
No cache or device policy was changed speculatively.

Perf's per-segment histories are now capped at its frame-ring size and only 64
segments remain resident; failed filesystem writes no longer report success.
The legacy voxel_bench driver has Gen1 export/controller assumptions and was
not used as Gen2 transition evidence. The engine's opt-in resource monitor
and crash-screen clipboard action are documented in `docs/resource-monitor.md`
in the engine repository. Texture readings are partial resource observations.

PR #5: all 13 added `test_*.lua` files and Park boundary, LWS host, world adapter
and static-ground-anchor tests passed using embedded LuaJIT 2.1. The
render-distance test fails on both local base and PR head because its extracted
function mock omits CacheTrace. PR remains draft: its documented Silver/Crystal
GPU, sprite-offset, atlas/cache and optional stereo acceptance is outstanding.
Android/iOS, Steam Deck and headset qualification remain outstanding. The
subsequent native source runs below supersede the initial no-runtime limitation.

Evidence: engine `tmp/review-tests.log` and `tmp/run_review_tests.py`.
No player saves/options were changed. No commits, deployment, issue comments or
release changes were made.

## Native transition probe

Fetched engine `origin/dev` at `e50c396e` and extracted it into
`tmp/transition-probe/source`; the working engine checkout at `b5460206` has
three local commits and 539 upstream commits of divergence, so it was preserved.
Reused the installed package's existing LOVE executable prefix and runtime DLLs
in a disposable runtime directory. The package's embedded engine is 0.2.41;
these runs used the extracted latest source, not that embedded engine.
Copied Silver/Crystal completed caches and the staged 2.1.2 mod into the test
source. Used identity `transition-budget-probe-20261013` and a portable scratch
source root. Only this mod was installed; no imported sprite companions.

The driver ranked city neighborhoods and used fresh world fixtures at
CELADON_CITY (39,10), facing right. It held/released real right input to cross
to ROUTE_7, then left to return. Normal FIT zoom, VOXEL 35, tiltshift OFF,
R.DIST FULL, speed 1 and no-sync. Silver and Crystal both completed outbound
and return crossings; native rendered before/after/return captures were opened
and inspected. No manual native keyboard/focus test was performed.

Baseline used four neighbors in Celadon and six on Route 7. All 149 baseline
build pumps incorrectly used the covered budget; max pump was 141.05 ms. The
coverage fix changed that count to zero. Coarse Buildings loops now check each
row/part instead of sampling every 32 coarse iterations. An index shared by
all templates replaces repeated full-map placement scans, retaining row-major
order, template priority and claim/bounds checks. The ten-template regression
reduces tile lookups from 64,000 to 6,400, with unchanged unmatched output.

Source version `0.0.0-dev` was also classified as an ancient legacy engine by
the mod's cache selector. It now selects byte storage, still guarded by a
write/read round-trip. The final native runs assert `cacheBound=true`.
Native LOVE cache storage, streaming and lifecycle tests all exited zero.
Those runs used a fresh derived cache, not the reporter's complete precache.

Final FIT cold-build runs still show substantial spikes: Silver max pump
71.21 ms, work-frame worst 117.62 ms; Crystal max pump 134.16 ms, work-frame
worst 138.10 ms. Backend/path and profiler settings changed from the first
baseline, so these are diagnostics, not a controlled FPS speedup claim. The
FrameProfiler separates update/draw/present and attaches map/neighbor/queue
context; the engine resource log captures partial memory peaks. Both runs
retained terrain and completed return crossings.

The Silver wide-zoom probe (1 world pixel per display pixel, R.DIST FULL)
reached 17 actual neighbors. It exceeded the probe-only 768 MiB Lua heap cap
while ten builds remained queued, and intentionally exited with a driver error.
The profiler observed a 175.2 ms work-frame spike (147.5 ms in draw). This cap
is a test stop condition, not a measured Android/iOS process limit. GC heap
peaks do not prove a leak or include all native/GPU allocations. No OS crash
or mobile OOM was reproduced. FULL still needs further memory/allocation work;
existing SHORT/MEDIUM distance settings offer a narrower diagnostic comparison.

Evidence directories under engine `tmp/transition-probe`: `silver-baseline`,
`silver-fixed-diagnostic`, `silver-final`, `crystal-final`, `silver-wide`.
Read `measurements.log`, `pump-spikes.log`, `perf.json`, `resource-monitor.log`,
and stdout/stderr as available. The wide probe abort is expected, not a pass.
All disposable game processes returned or exited on the guard; the installed
package and staging directory were not modified. Test shell environments were
scoped to each command. Scratch private caches remain untracked for review.

## Repeat the probe

`tests/gen2_transition_budget_probe.lua` requires a current source engine with
`src.core.FrameProfiler`, a disposable identity whose name starts with
`transition-budget-probe`, completed edition caches and this enabled mod.
Prepare copies and verify actual persistence roots first; it refuses the normal
player identity. Set POKEPORT_VERSION to Silver or Crystal, POKEPORT_DRIVER to
its absolute path, POKEPORT_DRIVER_PACED=1, POKEPORT_SPEED=1,
POKEPORT_BOOT_CINEMA=0, POKEPORT_GAME_PROF=all, POKEPORT_GC_PROBE=1,
and PROBE_DIR to an existing absolute writable evidence directory. Launch with
`--game=silver --no-sync` (or Crystal). PROBE_ZOOM=wide and
PROBE_LUA_BUDGET_MB=768 enable the guarded wide stress run. The optional
PROBE_RESOURCE_MODULE points to the engine ResourceMonitor.lua if the selected
source snapshot does not include it. No gameplay save is written. Do not set
PROBE_SAVE_CACHE=1 outside a disposable profile; it explicitly saves derived
cache records for a subsequent warm-cache comparison.
