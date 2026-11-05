# Gen 2 shiny context port

Ported the mon-aware interface selection already present in Gen 1's
`e39a80a`, adapted to Gen 2's portrait methods and separate battle views.
The prior shiny child-folder and separate front/back atlas fixes were already
present; they were not replaced.

Gen 2's engine preserves `mon.shiny=true` for forced/scripted shinies even
when the DVs are ordinary. Battle Art now accepts that explicit true flag,
then falls back to its existing canonical DV check. False/nil flags do not
prevent true shiny DVs from selecting shiny art. Gameplay DVs and saves are
not changed by the mod.

`InterfaceSprites` passes the actual Pokémon to static and animated front
resolvers and includes shininess in its playback cache key. The helpers choose
the shiny collection and its own dimensions/timing. Species-only callers stay
regular; Gen 2 Summary forwards its mon, while Dex preserves its existing
species-only, unseen-entry and native-Unown behavior. Battle art remains on
separate presentation views, retaining the evolution-save fix and canonical
English species routing. MODDED ownership and missing-art fallback remain.

## Automated checks

Windows LuaJIT 2.1.1700008891 through the existing scratch ctypes runner and
compatible LÖVE `lua51.dll`; each suite runs in a fresh Lua state.
From the mod root, equivalent commands are `luajit tests/<name>.lua`.

- `battle_art_defaults`: before FAIL `forced Gen 2 shiny flag was ignored`;
  after PASS. Covers forced/raw/wrapped, ordinary and canonical-DV cases.
- `animated_interface_provider_test`: ported Gen 1 regression; before FAIL
  `shiny interface playback retains the shiny atlas timing`; after 25/25.
  Covers regular/shiny metadata, timing, tight/legacy layouts and fallback.
- `interface_summary_ownership`: PASS, including regular -> shiny -> regular
  on the same species/summary instance without stale playback.
- `interface_scaling_anchor`: 35 checks, including actual Gen 2 menu adapters.
- `interface_sprite_defaults`, `gen2_battle_adapter`, and
  `animated_battle_art_ownership`: PASS.
- Three-edition evolution/save/reload regression and Gen 2 SDK load: PASS.
- `interface_dex_list_static`: existing assertion failure at line 64 on both
  unchanged HEAD and this patch. Its image-preparation code was not modified.

## Live Crystal preview

Two independent portable copies of the previously verified engine 0.4.0
payload use copied Crystal cache/save data. Each loads a production-file copy
of this checkout, including the user's existing 2.1.5 version edits. Optional
regular/shiny Gen 4 Chikorita atlases were copied from the user's local tight
front-art pack into the disposable mods only; no artwork is committed.

Both run at speed 1 with paced engine-driver input and `--no-sync`. The player
is Chikorita level 15; the opponent is an ordinary level-5 Pidgey.

| Case | Explicit shiny flag | DVs | Battle Art result |
| --- | --- | --- | --- |
| Player forced | true | Attack/Defense/Speed/Special 15, HP 15 (not shiny) | shiny Gen 4 Chikorita |
| Player DVs | false at fixture setup | Attack 2, Defense/Speed/Special 10, HP 0 (shiny) | shiny Gen 4 Chikorita |

Both drivers assert the selected front atlas is
`assets/battle/front-animated/gen4/shiny/chikorita.png`, the prepared image is
external, the opponent is not shiny, and the persistent player has no sprite
or animation fields. Actual GPU captures were opened and inspected: both
show the player's brown-leaf shiny sprite. The user approved the previews.

The inspection driver leaves each battle interactive, with F9 opening the
real Gen 2 Summary for that player and F10 closing it. Native keyboard/focus
behavior is left to user inspection; driver captures are not claimed as
native Computer Use evidence. Both previews were left interactive for review;
after user approval, neither preview process was still running.

Evidence remains local in `tmp/gen2-shiny-port-20261105/{forced,dvs}`:
`status.log` records flag/DV detection and exact selected atlas;
`captures/battle-player-shiny.png` records each rendered battle. Scratch driver
is `tmp/issue7-save/shiny-live.lua`. No player progress was written. Android,
Portuguese runtime, Gen 1 gameplay and every optional asset collection were
not exercised by these Windows previews.

After approval, deployed only `BattleArt.lua`, `AnimatedBattleArt.lua` and
`InterfaceSprites.lua` to the existing installed Gen 2 mod. Backed up the
prior installed files in the task scratch directory and verified all three
deployed/source hashes match. Optional artwork stayed in the disposable
profiles. Existing user edits to `main.lua` and `manifest.json` were preserved.
