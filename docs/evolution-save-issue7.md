# Post-battle evolution save failure (#7)

Investigated against mod `main` at `5ebe9fb` (2.1.4) and engine source at
`7abe68b1`, with pre-existing engine edits left intact. Issue #7 reports Crystal,
Portuguese and Android. Inspected error screenshots show
`SaveSerializer.lua:41: cannot serialize userdata`, followed by the recursive
serializer and `encode` frames. The initial headless investigation used no
player save or extracted assets. The subsequent live validation used copies
of the user's Crystal import and edited save, with isolated persistence.

## Confirmed cause

`OverworldBattle.gen2ArtBattle` obtains the actual active Pokémon from
`BattleState:activeMon`, attaches `sprite`, and tracks that table in
`session.gen2Mons`. Art playback also uses `picAnim` on that record.

After victory dialogue/experience processing, `BattleState:startEvolutions`
pushes `Gen2EvolutionAnim`. `Evolution.apply` constructs a **new** record and
copies fields outside `Evolution.MON_FIELDS`, preserving future/mod data.
That includes the old record's texture and animation references.
`EvolutionAnim:commit` replaces the party slot with the new record. The battle's
active/shown Pokémon can still be the original record.

After evolution dialogue and exit fade, `completeBattle` emits `battle.ended`
and exits via its callback. The mod retires its arena and the next update
finishes it when the stack returns to free roam. Cleanup clears the tracked
original, but cannot clear the separate evolved copy. This is an ownership leak,
not a need to tear the arena down sooner.

The pause menu opens `Gen2SaveMenu` through `Game2:pushStartMenuItem("save")`.
Its writer calls `Game2:writeSave` -> `snapshotSave` -> Gen 2 `Save.save` ->
`SaveSerializer.encode`. The snapshot returns `self.save`, including the evolved
party record. In the regression, `save.party[1].sprite` is the exact same userdata
returned by the mod's picture resolver; `save.party[1].picAnim` is also copied
by identity and contains that userdata. Serialization raises before writing
backup/staged/progress bytes. It does not return a successful write.

## Fix

The first fix (`c22cd11`) removed inherited references at `pokemon.evolved`.
The requested follow-up replaces that cleanup workaround with separate
battle-lifetime presentation records, held by `session.gen2Views` and keyed by
the original Pokémon. Art managers write `sprite` and `picAnim` only on these
views; gameplay fields are read through to the source without copying them.
The native Gen 2 picture/animation adapter and the staged capture's reassertion
read the same view. Nothing is added to a persistent Pokémon.

Each view resolves `artSpecies` from the source definition's National Dex
number (`dex`, or Gen 2 `index`) through `battle_species_dex_386`. The canonical
English key, not a localized name or nickname, selects artwork. Existing stable
species strings and numeric `SPECIES_152` aliases remain supported. This pointer
is presentation-only; there is no reason to add another field to old saves.
Native picture resolution still receives the original Pokémon, retaining Unown
form, shiny and provider context. Front/back art settings remain in their
existing resolvers.

Views refresh when the source species changes (including Transform-style
changes). Teardown releases art ownership for every cached view, including
switched-out Pokémon, then discards the session. The evolved party record has
no rendering fields to inherit, so the evolution event scrubber is removed.
Battle teardown timing, engine serializer, save schema and persistent extension
data are unchanged. Existing saves need no migration.

## Lifecycle regression

From the engine root (LuaJIT/5.1 semantics):

```text
luajit dev/BattleArtGen2/tests/gen2_evolution_save.lua
```

Optional `DS_MOD_PATH` selects a baseline mod tree. The original regression at
`c22cd11` was run unchanged against copies of `main`'s `OverworldBattle.lua` and
`Gen2BattleAdapter.lua`, then the initial fix. The baseline fails at the real
pause-menu writer:

```text
crystal: save.party[1].sprite=userdata, picAnim=table, inherited sprite=true
SaveSerializer.lua:41: cannot serialize userdata
SaveSerializer.lua:52: in function 'encode'
core/gen2/Save.lua:971: in function 'save'
core/Game2.lua:1035: in function 'writer'
ui/gen2/SaveMenu.lua:171: in function 'writeNow'
```

The harness uses real `Mon`, `BattleState` evolution/exit methods,
`EvolutionAnim` (including its dialogue/timers), `Evolution`, `StateStack`,
`StartMenu`, `Game2` save/menu methods, `SaveMenu`, `Save`, `SaveSerializer`,
`Runtime`/event buses, and mod staging/Gen 2 adapter installation. It simulates
the completed winning turn/level flag, world geometry and GPU/audio providers.
An opaque Lua userdata stands in for the picture resolver's Image; the real
mod code attaches it. All persistence is explicitly redirected to the engine's
memory filesystem. This is a headless lifecycle integration, not a complete
interactive battle or visual rendering reproduction.

The rewritten regression additionally asserts that source Pokémon never gain
rendering fields, snapshots serialize while art is active, adapter consumers
resolve the separate view, capture reasserts ownership on that view, and the
view cache is gone after exit. Canonical-art tests cover numeric Dex IDs,
localized display names, English asset slugs and named species aliases.

| Check | Before fix | After fix |
| --- | --- | --- |
| Crystal evolution -> dialogue/fade -> overworld -> pause Save | FAIL, same userdata error | PASS |
| Reload Bayleef and persistent data | Not reached | PASS, Crystal/Silver/Gold |
| Silver/Gold lifecycle save/reload | Not reached after Crystal failure | PASS |
| Original art retained until exit; cleanup once | PASS, Crystal | PASS, all three |
| Interrupted stack cleanup, distinct provider fields, no-session event | Not all reached | PASS, all three |
| Actual GPU battle appearance | Not run | Crystal ROM-art fallback inspected in live engine 0.4.0 |

Reload assertions include species, nickname, level, HP, experience, happiness,
stat experience, custom persistent data, and world map/cells. Neither transient
field survives on the evolved record or the loaded save.

## Additional validation

Executed each test in a fresh **LuaJIT 2.1.1700008891 Windows x64** state using
the discovered LÖVE runtime's `lua51.dll`, via a scratch Python ctypes launcher
(`run_lua.py <test-path>`). This uses the engine's target Lua semantics; no
standalone `luajit` executable was on PATH. Reproduce with the commands below
using `luajit`, or substitute that launcher for `luajit`.

After the presentation rewrite, reran the three-edition lifecycle, SDK load,
Gen 2 save (209) and mod save/serializer (132) suites. Mod adapter, canonical
art defaults, animated ownership, layer order, effect facing and interface
summary ownership pass. The source-order checks now reference the presentation
view rather than a live-mon sprite. A concurrent Windows SDK invocation failed
directory discovery; its standalone rerun passed.

Engine-root tests (each `luajit <path>`), exit 0:

- `tests/gen2_save_test.lua`: 209 checks, no failures.
- `tests/gen2_battle_test.lua`: 819 checks, no failures.
- `tests/gen2_evolution_test.lua`: 97/97.
- `tests/gen2_battle_end_test.lua`: 32/32.
- `tests/gen2_battle_exit_fade_test.lua`: 83/83.
- `tests/engine/gen2_evolution_stat_exp.lua`: 28/28.
- `tests/engine/gen2_evolution_cry_order_bug2033.lua`: 16/16.
- `tests/engine/gen2_save_order_bug2053.lua`: 18/18.
- `tests/engine/gen2_save_menu_translation_test.lua`: 72/72.
- `tests/engine/gen2_save_import.lua`: 409/409; personal-save audit skipped.
- `tests/engine/gen2_save_import_options.lua`: 48/48. Initial Windows `tmpnam`
  drive-root permission failure; rerun with a scratch wrapper routing only
  `os.tmpname` into the disposable task directory. No engine test changes.
- `tests/engine/gen2_save_no_cache.lua`: 16/16; all three real-cache checks skipped.
- `tests/mod_save_tests.lua`: 132/132, including serializer grammar and recovery.
- `tests/engine/save_lua_import_tests.lua`: 328/328.

SDK load: `DS_MOD_PATH=dev/BattleArtGen2 DS_ENGINE_ROOT=.` then
`luajit dev/BattleArtGen2/tests/gen2_port_load.lua`: PASS. An initial absolute
path invocation did not match the SDK alias; the relative-path run passed.

Mod-root tests (each `luajit tests/<name>.lua`), exit 0:

- `gen2_battle_adapter`
- `animated_battle_art_ownership`
- `battle_layer_order`
- `battle_effect_facing`

`battle_frame_retention` fails line 18's existing source-string assertion on
both untouched `main` and the patch (exit 1); baseline was rechecked, not waived
from historical notes. `tests/engine/save_file_io_tests.lua` exits 0 but skips
because generated Gen 1 content is absent. `git diff --check` passes.

## Live Crystal validation after the rewrite

The user's installed launcher is a fused 0.2.41 executable whose updater selects
`gen1recomp-0.4.0.love`. Extracted that exact 0.4.0 payload into an isolated
portable test directory and ran it with the discovered compatible Windows
LÖVE runtime. This validates the updated engine payload, not a claim that the
older fused bootstrap itself was modified.

Deployed only production mod files to the user-requested AppData Gen 2 mod
folder, which did not previously exist. The disposable app's mod junction
points to that exact installed folder. The driver asserted Crystal/Crystal
lineage, export ID `BATTLE_ART_VOXEL_GEN2`, version 2.1.4, the new `gen2ArtMon`
API, and a portable persistence root inside the task directory. Deployed/source
Lua hashes matched. The user's existing running game was left alone.

The copied save was on ROUTE_30, player cell (7,50), facing right, at night.
The user had edited Chikorita to level 15; the driver changed only the copied
fixture to EXP 2525, ten below level 16's Crystal growth threshold of 2535,
and refreshed stats/HP. Camera: voxel 35 degrees; default art settings.

Launched the engine with `--game=crystal --no-sync`, process-local
`POKEPORT_VERSION=crystal`, speed 1, paced driver, and a separate identity.
Scratch driver: `tmp/issue7-rewrite-live/repro.lua`.

The fixture calls the real world's `startBattle` with a level-3 Sentret,
then drives real game A-button input through battle commands/dialogue,
experience, the full evolution animation and battle exit. It does not fake a
win, call `Evolution.apply` directly, or teleport during the battle. After
returning to normal free roam, it opens START, selects SAVE, confirms through
the real save UI, then loads with `Save.load` and `continueGame`.

Two complete live runs passed. Chikorita became level-16 Bayleef at EXP 2549.
The runtime reported `ART_VIEW CHIKORITA userdata DATA nil nil`. Save/load
assertions verified species, level, EXP, HP and absence of rendering fields.
The second run captured and visually inspected:

- `captures/refined/02-battle-art.png`: Chikorita and Sentret on the staged map.
- `captures/refined/03-evolution.png`: actual Chikorita evolution silhouette.
- `captures/refined/05-pause-save.png`: SAVE selected after the overworld return.
- `captures/refined/08-bayleef-party.png`: reloaded BAYLEEF, level 16, 48/48 HP.

All paths above are inside `tmp/issue7-rewrite-live`; status.log records the
roots, mod, fixture, captures and final PASS. These private artifacts are not
committed. This clean mod checkout has no optional species PNG packs, so the
live battle validates the ROM-art fallback. Canonical English external-image
routing is covered by headless lookup/adapter tests, not claimed as a live
custom-atlas pass.

Both disposable game processes auto-quit on successful driver completion.
The original and edited user saves were backed up in scratch; the actual
edited main slot's hash remained identical afterward. No main progress or
options were overwritten. The requested Gen 2 mod deployment remains installed.

Windows Computer Use found the exact user Crystal window, but its screenshot
capture timed out twice, so no native UI inputs were issued. Live input was
injected by the engine driver with releases; GPU captures came from actual
rendered frames and were opened for inspection. Android, Portuguese gameplay,
native keyboard/focus behavior, optional custom atlas packs, and the fused
bootstrap path remain unverified.
