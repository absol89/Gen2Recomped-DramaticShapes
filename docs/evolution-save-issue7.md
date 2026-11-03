# Post-battle evolution save failure (#7)

Investigated against mod `main` at `5ebe9fb` (2.1.4) and engine source at
`7abe68b1`, with pre-existing engine edits left intact. Issue #7 reports Crystal,
Portuguese and Android. Inspected error screenshots show
`SaveSerializer.lua:41: cannot serialize userdata`, followed by the recursive
serializer and `encode` frames. No player save or extracted assets were used.

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

The Gen 2 installer subscribes to the existing `pokemon.evolved` event, emitted
after extension fields are copied and before party writeback. While an arena
session is active, remove only `sprite`/`picAnim` values that are equal by
reference to fields on a tracked source of `fromSpecies`. Leave different
provider values, all other extension data, and out-of-session evolution alone.
Do not change the source record, battle teardown timing, engine serializer or
save schema. Existing saves need no migration. Installation remains idempotent.

## Lifecycle regression

From the engine root (LuaJIT/5.1 semantics):

```text
luajit dev/BattleArtGen2/tests/gen2_evolution_save.lua
```

Optional `DS_MOD_PATH` selects a baseline mod tree. The same final test was run
against copies of `main`'s `OverworldBattle.lua` and `Gen2BattleAdapter.lua`, then
the changed checkout. The baseline fails at the real pause-menu writer:

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

| Check | Before fix | After fix |
| --- | --- | --- |
| Crystal evolution -> dialogue/fade -> overworld -> pause Save | FAIL, same userdata error | PASS |
| Reload Bayleef and persistent data | Not reached | PASS, Crystal/Silver/Gold |
| Silver/Gold lifecycle save/reload | Not reached after Crystal failure | PASS |
| Original art retained until exit; cleanup once | PASS, Crystal | PASS, all three |
| Interrupted stack cleanup, distinct provider fields, no-session event | Not all reached | PASS, all three |
| Actual GPU battle appearance | Not run | Not run |

Reload assertions include species, nickname, level, HP, experience, happiness,
stat experience, custom persistent data, and world map/cells. Neither transient
field survives on the evolved record or the loaded save.

## Additional validation

Executed each test in a fresh **LuaJIT 2.1.1700008891 Windows x64** state using
the discovered LÖVE runtime's `lua51.dll`, via a scratch Python ctypes launcher
(`run_lua.py <test-path>`). This uses the engine's target Lua semantics; no
standalone `luajit` executable was on PATH. Reproduce with the commands below
using `luajit`, or substitute that launcher for `luajit`.

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

Android/device execution, Portuguese gameplay, actual GPU art, native input,
packaged builds and real-cache tiers remain unverified. No test game process
was launched; no player saves/options, installed mods or persistent environment
settings were changed. Scratch logs and issue images remain outside the mod
repository under the engine's task scratch directory and are not committed.
