# Desktop cache diagnostics

Windows/Linux/macOS builds automatically write `battleart-gen2-cache.log` in
LOVE's save directory. The console prints its absolute path when tracing starts.
Android/iOS emit no trace. Rebuild/install the mod, start Silver, load the save,
then travel between Violet and Ecruteak and back. Copy the log before restarting
the game: each session starts a new log. At 4 MiB it rotates to
`battleart-gen2-cache.previous.log`; include that file if present.

Events include elapsed runtime timestamps and map IDs:

- `live-set`: current map and eligible connected maps.
- `evict-gpu` / `evict-runtime`: runtime resources removed; disk records retained.
- `refresh` / `invalidate`: block edit, regrowth, asset reset, cache purge, or
  unspecified invalidation, with affected map and generation cancellation.
- `queue` / `job-start` / `job-done` / `job-failed`: full/body mesh jobs.
- `ram-hit` / `disk-hit` / `disk-miss`: record source/path.
- `reject-fingerprint`: the specific fingerprint difference, beyond revision.
- `cache-ineligible`, `cache-rejected-session`, `reject-corrupt`: rejection causes.
- `upload-cached`: cached geometry uploaded to GPU, not a terrain rebuild.
- `build-terrain` / `build-aux`: actual live geometry generation.

Logging does not change cache revision, eligibility, eviction, or build policy.
It logs events rather than each frame; file I/O still has some diagnostic cost.
The runtime invalidation preceding an upload is not itself proof of a disk
cache failure. Follow that map's cache-source and build/upload events.

Headless trace gating/failure-isolation tests and native LOVE cache lifecycle
tests pass. City-to-city gameplay diagnosis awaits the captured desktop log.
