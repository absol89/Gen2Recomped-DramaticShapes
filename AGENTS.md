# Battle Art Gen 2: contributor and game-testing guide

## Purpose and first steps

This is the Gold/Silver/Crystal Battle Art port. Reproduce against the actual
Gen 2 runtime and this checkout. The Gen 1 guide in the sibling
`DramaticShapeVoxelMod` repository is background, not an executable recipe for
this repository: loading, world state, scripts, UI, and render adapters differ.

1. Read this guide, `README.md`, `CHANGELOG.md`, and the relevant `docs/` notes.
   Start with `docs/2.1.1-port-validation.md`, `docs/render-distance-port.md`,
   and `docs/cache-tracing.md`. `docs/precache-differences.md` is an obsolete
   implementation plan from the earlier porting work; do not use its proposed
   modules, branch model, or implementation sequence as the current design.
   For current cache behavior, read `lib/VoxelMeshDisk.lua`,
   `lib/VoxelPrecache.lua`, `lib/VoxelPrecacheScreen.lua`, and the cache tests.
2. Inspect the current branch, Git status, manifest, and affected files. Preserve
   user edits. This checkout was on `main` during the 2026-09-15 audit; do not
   inherit Gen 1's Legendary-Additions branch instruction or switch blindly.
3. Record the game version, copied save or fresh fixture, map, object cell,
   viewing cell, facing, time, options, companions, trigger, and expected result.
4. Reproduce, make a focused change, repeat the same scene, and inspect related
   scenes. A passing headless test is not proof of correct GPU rendering.

## Ownership and scope

- Build on this port's adapters and rendering architecture. Do not transplant
  Gen 1 scenes or entire cache/renderer modules just because filenames match.
- Preserve native gameplay, collision, encounter rules, scripts, map events,
  warps, stats, inventory, party data, and clock behavior. Geometry fixes should
  change presentation. Experimental 1ST/3RD movement must still use Gen 2's
  collision, step, landing, warp, and event machinery.
- Keep Stadium and character importers separate. Use exported provider APIs;
  retain the native/2D fallback when a provider is disabled, absent, or fails.
  Do not copy companions' private assets/runtimes or bypass their ownership.
- Keep engine UI, HUD, animation, scene lifecycle, and input ownership intact.
  Restore canvas, shader, blend, transform, and depth state after drawing and
  on errors. A silent flat fallback may hide a rendering failure.
- Preserve current authored terrain, forests, water boundaries, interiors, roof
  composition, sprite anchoring, and approved presentation outside the defect.
- Read current manifest compatibility and version rather than copying historical
  README release claims. Do not bump versions, publish, or change mod identity
  as an incidental fix. Keep third-party binary licenses with their files.
- Do not commit ROMs, extracted game data, imported packs, user artwork, derived
  caches, or test screenshots. Respect `.gitignore` and packaging exclusions.

## Paths, identity, and preflight

| Path | Role |
| --- | --- |
| `D:\gen1recomp` | Engine source root; source launch working directory. |
| `D:\gen1recomp\dev\BattleArtGen2` | Authoritative mod checkout and separate Git repository. |
| `D:\gen1recomp\mods\BATTLE_ART_VOXEL_GEN2_PORT` | Engine-facing junction to this checkout as audited on 2026-09-15. Verify each session. |
| `D:\games\gen1recompwin64` | User-named packaged install; absent in the earlier 2026-09-15 audit. Verify existence, executable, and capabilities before use. |
| `D:\gen1recomp\tmp\battle-art-gen2\<case>\<version>\<run>` | Suggested scratch driver/log/image directory. |

The manifest ID is **BATTLE_ART_VOXEL_GEN2**, without `_PORT`. The installed
folder is not the ID. `DRAMATIC_SHAPE` and `BATTLE_ART_VOXEL_FORK` are not this
mod's export key. The audited manifest targets `gen2` and lists its conflicts.

```powershell
$engineRoot = 'D:\gen1recomp'
$modRoot = Join-Path $engineRoot 'dev\BattleArtGen2'
$packageRoot = 'D:\games\gen1recompwin64'
git -C $modRoot status --short
git -C $modRoot branch --show-current
Get-Content (Join-Path $modRoot 'manifest.json')
Get-Item (Join-Path $engineRoot 'mods\BATTLE_ART_VOXEL_GEN2_PORT') |
    Select-Object FullName, LinkType, Target
Get-Command love, lovec, luajit, python -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $packageRoot) {
    Get-ChildItem -LiteralPath $packageRoot -Force
}
```

Confirm this ID is enabled for the selected game in Mod Manager and retained
without loader errors. Inspect actual loaded exports/diagnostics. A package may
load an older installed or save-directory shadow copy. Editing this checkout
only affects a runtime that resolves to it or has received a deliberate test
deployment. Do not replace an existing install or junction blindly.

## Gen 1 versus Gen 2: the runtime map

Paths in this table are relative to the engine root unless prefixed `lib/`.

| Concern | Gen 1 habit to avoid | Gen 2 owner / correct approach |
| --- | --- | --- |
| Game service | Treat `src.core.Game` as the live singleton in an external driver | `main.lua` creates `src.core.Game2.new()`; use the driver's passed `game`. |
| World | Push `src.world.OverworldController` onto the state stack | `game.world` is `src.world.gen2.World`; normal free roam has an EMPTY screen stack and `game.phase == "play"`. |
| Teleport | Call `tests/drivers/util.lua`'s `U.teleport` | Use live `world:setMap` for a geometry fixture or `world:warpToMapId` for Gen 2 map-setup effects. |
| Current coordinates | Read `game.save.player.map/x/y` or stack top as the overworld | Read `game.world.map.id` and `world.player.cellX/cellY/facing`; the saved map is `save.player.map`. Do not substitute `save.position` for the current Gen 2 save schema. |
| Continue/save | Use Gen 1 restore methods or manually assign a raw table | `src.core.gen2.Save` and `Game2:continueGame`; this applies migrations, mod save adoption, options, and rebuilds the world. |
| UI screens | Assume Gen 1 menu/state constructors | `src.ui.gen2.*`, screen registry, and Game2 compositor; screen-stack top can be a menu/dialog/battle, not the world. |
| Battle | Patch only Gen 1 BattleState draw paths | `src.ui.gen2.BattleState`, `src.battle.gen2.*`, and `lib/Gen2BattleAdapter.lua`. |
| Options | Write Gen 1 root pipeline preferences | `game.options`; persisted Gen 2 options use the shared `options.lua` nested `gold` block. |
| Dev UI | Backtick `warp` console and F5 reload | These Gen 1 developer features are not implemented by Game2; use a driver and restart. |
| Time | Assume a visual DAY setting fixes all timed gameplay | Gen 2 RTC/weekday, world palette time, and Battle Art DAYTIME must be recorded separately. |

Sandboxed mod imports can receive facades/aliases from `src/mods/Gen2Compat.lua`.
This is why a Gen 1-looking import inside the mod can work on Gen 2. A raw
external `POKEPORT_DRIVER` uses ordinary engine `require`; do not assume it gets
the same facade. Consult compatibility coverage before adding wrappers: a
wrapper on an inactive Gen 1 method can load successfully and never execute.
Use `V.require` within this mod and its existing live-game boundary.

### Rendering and scene plumbing to inspect

- `World:drawPipeline` supplies the world pass; Game2 composes the final frame
  and UI. `lib/VoxelScene.lua` prepares the Gen 2 world through
  `lib/Gen2WorldAdapter.lua` before rendering/prefetching.
- The world adapter normalizes presentation IDs such as `TILESET_JOHTO` to
  `TilesetJohto`, while retaining the engine key in `map.def.tileset`. It prepares
  connected maps and uses `World:atlasFor` for map-group roof overlays. Raw
  tileset PNGs alone can omit the roof actually shown in the game.
- Graphics tiles and collision bytes are different data. Both generations have
  4x4 8px graphics tiles per block; do not use a Gen 2 collision byte as a tile ID.
  Movement cells are 16px and blocks 32px. Prefer live `widthCells/heightCells`
  and validated engine map IDs; screen coordinates in a tilted view are not cells.
- `Gen2BattleAdapter`, `OverworldBattle`, `BattleScene`, and `StadiumBackground`
  coordinate the staged arena with native Gen 2 battle UI. Preserve the active
  Stadium scene's models/camera/HUD when it owns the battle, and the fallback
  when it declines. Arena and overworld rendering are separate paths.
- Gen 2 character cards can have variable widths and `half`/lean/facing anchors.
  Reflection and sprite changes must preserve these, including error cleanup.
- Summary and Dex have their own Gen 2 portrait methods. Check FIT and FULL,
  first-visible-pose anchors, animation motion, native unseen entries, Unown
  forms, and oversized sprites. Gen 1 alignment is not a Gen 2 requirement.
- Dynamic Cut edits go through `World:replaceBlock(index, blockId)`, bypassing
  `Map:setBlock`. `lib/BlockMeshRefresh.lua` handles the previous block and
  duplicate notifications. Re-entry restores blocks; immutable precache data
  must not be replaced with a transient cut map.

## Silver and Crystal are separate test targets

| Setting | Silver | Crystal |
| --- | --- | --- |
| Launch | `--game=silver` | `--game=crystal` |
| Scripted selection | `POKEPORT_VERSION=silver` | `POKEPORT_VERSION=crystal` |
| Runtime assertion | `GameVersion.get() == "silver"`, `engine() == "gs"` | `GameVersion.get() == "crystal"`, `engine() == "crystal"` |
| Imported cache namespace | `silver/` | `crystal/` |
| Default progress without registered slots | `save_silver.lua` | `save_crystal.lua` |
| Boot/story | Gold/Silver engine with Silver-selected data | Crystal intro, gender selection and Crystal-specific script/data behavior |

Both use Game2, but Crystal is not merely Silver with a different title. Its
map attributes, story scenes, collision rules, gender/character graphics, UI,
and features can differ. A Silver pass is not a Crystal pass. Some engine files
and diagnostics still say `gold` while implementing all Gen 2 games; inspect
version branches and `GameVersion.engine()` rather than inferring from names.
The audited engine labels Crystal as Beta; report the actual build used.

### Import, slots, persistence, and clock

- Import the user's existing Silver and Crystal ROMs into the runtime being
  tested. Each must be ready separately; do not substitute Gold's cache or copy
  extracted tables between editions. Let the normal importer/version overlay
  select the data. Do not download ROMs.
- `--game=...` skips the launcher, not necessarily the title/Continue flow. Use
  equals syntax with LÖVE. `--slot=N` selects a slot in the normal launch path.
- Scripted launch prioritizes `POKEPORT_VERSION`, then the requested game, then
  Red. Set version explicitly and assert it. The driver branch bypasses the
  normal launch-slot path: adding `--slot=2` is not enough to restore that slot.
- Game2 skips cinema and starts a fresh world skeleton under `POKEPORT_DRIVER`
  unless `POKEPORT_BOOT_CINEMA=1`. This is not Continue. Use the cinema flag to
  test copyright, Game Freak, edition intro, title/menu, Oak, naming/clock, and
  Crystal gender selection. Start from `tests/drivers/crystal_boot_smoke.lua`
  or `gold_boot_smoke.lua`, inspecting their assertions and output variables.
- Identify the actual persistence root before testing. `portable.txt` routes
  persistence beside the game/source; otherwise LÖVE normally uses
  `%APPDATA%\LOVE\pokemon-love2d`. A diagnostic driver can print
  `love.filesystem.getSaveDirectory()` and
  `require("src.core.SaveData").portableBaseDir()`.
- `POKEPORT_IDENTITY` changes the LÖVE identity, not portable mode. A fresh
  identity can lack imported caches and enabled mods. Verify isolation before
  claiming it. Registered slots use `saves/<version>/<slot>.lua`; inspect the
  active slot, not just flat legacy filenames. Slots/selection can persist.
- Back up the selected save, options, and slot metadata before stateful testing;
  prefer a disposable test profile/install with a copied known save. Use
  `--no-sync` in normal local test launches. Never save a teleported fixture
  over player progress. **F1 writes a save; F2 loads the active save** in Game2.
- Gen 2 display options are shared through the nested `gold` block, including
  Silver/Crystal. Changing Silver's options can affect the Crystal comparison.
  The mod seeds FULL only when the voxel preference is missing and respects
  explicit OFF. Compare/reset relevant options deliberately, not the whole file.
- For time-dependent bugs, record RTC hour, minute, weekday, `world.tod`,
  `world.daytime`, and Battle Art DAYTIME mode. On a disposable fixture,
  `src.core.gen2.Clock.setTime(save, hour, minute)` and `setWeekday(save, day)`
  set offsets; they do not freeze time. Inspect Clock's weekday convention.
  Host time continues advancing. DAYTIME is presentation; it is not proof that
  NPC schedules, encounters, phone calls, or weekday scripts have the same state.
  FULL forces the mod's DAYTIME to SYNC. Do not change the OS clock for a test.

### Explicitly loading a known Gen 2 slot in a driver

Prefer normal Continue plus Computer Use when checking the loading UI itself.
For automated state restoration, this is the current API sequence; replace the
slot ID with one verified in the disposable profile, and use it BEFORE capturing
`game.world` (Continue replaces that object):

```lua
local Version = require("src.core.GameVersion")
local Slots = require("src.core.SaveData")
local Save2 = require("src.core.gen2.Save")
local version = Version.get()
Slots.setActiveSlot(version, assert(os.getenv("REPRO_SLOT_ID")))
local loaded = assert(Save2.load(version), "Known Gen 2 save did not load")
assert(loaded.version == version, "Wrong save version")
game:continueGame(loaded)
local world = assert(game.world)
```

Do not pass nil to Continue: its fallback starts a new game. Do not treat a
saved `position` assignment as equivalent to a load. Preserve map scenes,
events, script memory, party, and Crystal state through the native save path.

## Source-run recipe: automate setup, then inspect with Computer Use

Use a discovered compatible LÖVE runtime with working directory
`D:\gen1recomp`, passing the engine directory. `lovec.exe` is convenient for
logs. The mod directory is not a standalone LÖVE application.

Create a scratch `repro-gen2.lua` from the template below. It validates the
generation, actual mod ID, world, map, and live location. The default Cherrygrove
view is a candidate framing position, not a verified bug coordinate. Replace it
with the reported map/cell and verify bounds, walkability, camera, and scripts.
Use the optional save-loading sequence above for progression-dependent bugs.

```lua
return function(game)
  local U = dofile("tests/drivers/util.lua") -- wait/shot/input helpers ONLY
  local Version = require("src.core.GameVersion")
  local P = require("src.render.Pipelines")
  local wanted = assert(os.getenv("REPRO_VERSION"))
  assert(wanted == "silver" or wanted == "crystal", "Select Silver or Crystal")
  assert(Version.get() == wanted and Version.generation() == 2, "Wrong game")
  assert(Version.engine() == (wanted == "crystal" and "crystal" or "gs"))
  local exports = game.mods and game.mods.exports
  assert(exports and exports.BATTLE_ART_VOXEL_GEN2, "Gen 2 Battle Art not loaded")
  local world = assert(game.world, "No world: cinema or failed boot?")
  assert(game.phase == "play" and not game.stack:top(), "Not in free roam")
  local mapId = os.getenv("REPRO_MAP") or "CHERRYGROVE_CITY"
  local x = tonumber(os.getenv("REPRO_X")) or 15
  local y = tonumber(os.getenv("REPRO_Y")) or 10
  local facing = os.getenv("REPRO_FACING") or "up"
  assert(world.maps[mapId], "Unknown map in selected version")
  assert(world:setMap(mapId, x, y, facing), world.status)
  -- Direct setMap is a fixture, not a test of a door/warp/fade sequence.
  local dir = assert(os.getenv("SHOT_DIR"))
  local speed = math.max(1, math.floor(tonumber(os.getenv("POKEPORT_SPEED")) or 1))
  local function settle() U.wait(120 * speed) end
  local function setLevel(id, level)
    -- Keep in-memory options aligned so the mod's restore probe respects OFF.
    game.options.pipelines = game.options.pipelines or {}
    game.options.pipelines[id] = level
    P.setLevel(id, level)
  end
  local function shot(label)
    assert(world.map.id == mapId, "Scene moved to another map")
    assert(game.phase == "play" and not game.stack:top(), "UI obscures fixture")
    U.log(wanted, Version.engine(), world.map.id, world.player.cellX,
      world.player.cellY, world.player.facing, world.tod, world.daytime)
    assert(U.shot(game, dir .. "/" .. wanted .. "_" .. label .. ".png"))
  end
  setLevel("tiltshift", 0)
  setLevel("voxel", 0)
  settle()
  shot("flat")
  local angle
  for level = 0, P.maxLevel("voxel") do
    if P.levelLabel("voxel", level) == "35" then angle = level end
  end
  assert(angle, "Inspect current voxel level labels")
  setLevel("voxel", angle)
  settle()
  shot("v35")
  U.log("READY_FOR_INSPECTION", P.levelLabel("voxel", P.level("voxel")))
  while true do U.wait(60) end -- keep window running for real UI input
end
```

This fixture does not suppress NPCs, scene scripts, encounters, or force time.
If scripts move the player or open a dialog, inspect that state and choose a
suitable copied save/approach point. Do not globally disable scripts to make a
reproduction pass. Record any intentional fixture flags separately. In-memory
option changes are not a guarantee that other initialization/hooks never write
options; protect the test profile and restore settings afterward.

PowerShell launch (use a dedicated shell and a new run directory):

```powershell
$engineRoot = 'D:\gen1recomp'
$testVersion = 'silver' # repeat with crystal in a fresh run
$runDir = Join-Path $engineRoot "tmp\battle-art-gen2\cherrygrove\$testVersion\before-01"
$loveExe = 'C:\REPLACE_WITH_DISCOVERED_LOVE_DIRECTORY\lovec.exe'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
# Save the template as $runDir\repro-gen2.lua before launching.
if (-not (Test-Path -LiteralPath $loveExe)) { throw 'Locate LÖVE first' }
$env:POKEPORT_VERSION = $testVersion
$env:REPRO_VERSION = $testVersion
$env:POKEPORT_BOOT_CINEMA = '0'
$env:POKEPORT_SPEED = '1'
$env:POKEPORT_DRIVER = Join-Path $runDir 'repro-gen2.lua'
$env:SHOT_DIR = $runDir.Replace('\', '/')
$gameProcess = Start-Process -FilePath $loveExe -WorkingDirectory $engineRoot `
    -ArgumentList @($engineRoot, "--game=$testVersion", '--no-sync') `
    -RedirectStandardOutput (Join-Path $runDir 'stdout.log') `
    -RedirectStandardError (Join-Path $runDir 'stderr.log') -PassThru
$gameProcess.Id
```

Inspect/clear inherited autopilot, import, arena, and unrelated launch variables
before running. Create the screenshot directory in PowerShell: U.shot's Unix
mkdir fallback is not a Windows setup recipe. Keep speed 1 for timing/input
reproduction. Fixed waits only allow rendering; inspect the loading veil and
wait longer if needed. Verify screenshots exist, are current, and contain the
intended frame. A capture log line alone is not evidence.

The visible window is intentional for inspection. Driver return means automatic
exit; errors log `driver error:` and exit 1. This template deliberately stays
alive. Close only the test instance, then restore environment/options or close
the dedicated shell. Do not launch duplicates while caches are building.

### Do not run the inherited survey unchanged

`tests/voxel_survey.lua` and `tools/voxel-survey.md` retain Gen 1 assumptions:

- `U.teleport` imports the Gen 1 overworld controller.
- Default `REDS_HOUSE_2F` is not a verified Gen 2 starting map.
- DAYTIME lookup uses `exports.DRAMATIC_SHAPE`, not this mod's ID.
- Old comments map levels 1/2/3 to 15/35/50; current FULL shifts these to 2/3/4.
  Always resolve labels from Pipelines/`lib/VoxelState.lua`.
- Flat capture happens only for the first spot, and capture writes are not checked.

Use the Gen 2 template or adapt a scratch survey deliberately. For a batch,
iterate validated positions, capture flat and each relevant angle at EVERY
position, and return only after the last capture has flushed. Many inherited
`*_shots.lua` files also require inspection before use; a filename is not proof
of Gen 2 compatibility.

## Teleport versus real scene reproduction

- `world:setMap(id, x, y, facing)` loads a direct fixture and can still affect
  map state/callbacks. It does not test the full transition setup sequence.
- `world:warpToMapId(...)` runs Gen 2 `MAPSETUP.WARP`. Wait for completion and
  inspect `world.mapSetup`, live coordinates, stack, and input readiness.
- For a door, connection, stairs, hole, Fly, Dig, or scripted entry bug, start
  nearby and perform the actual action. Warping directly to the destination
  cannot prove the original trigger/fade/arrival script works.
- Scene indices, event flags, temporary map flags, VM state, scheduled objects,
  and party progress can determine what happens on arrival. Read
  `src/world/gen2/World.lua`, `src/script/gen2/Vm.lua`, and the active map data.
  Do not replace Silver's scene state with Crystal's numeric assumptions.

Useful source examples (read prerequisites and mutation/output behavior first):

| Driver | What it teaches |
| --- | --- |
| `tests/drivers/gold_warp_scene.lua` | New Bark -> Elm's Lab door, fade, sound, held-input release, and arrival scene. Contains explicit fixture scene edits. |
| `tests/drivers/crystal_mansion_roof_bug1964.lua` | Gen 2 warp setup, live coordinates, normal movement, and a Crystal-specific railing assertion. |
| `tests/drivers/crystal_boot_smoke.lua` | Crystal engine identity and its real boot-screen sequence. Needs cinema enabled. |
| `tests/drivers/crystal_f2_save_and_vars.lua` | Crystal script variables and real save/reload; writes data, so use a disposable profile. |

## Computer Use and packaged Windows runs

Use the installed Windows Computer Use skill; read its current SKILL.md,
guidance, API, and confirmation rules. In a `node_repl` session exposing
`@oai/sky`, initialize:

```javascript
if (!globalThis.sky) {
  const { sky } = await import("@oai/sky");
  globalThis.sky = sky;
}
```

In a separate call, discover the actual windows:

```javascript
globalThis.windows = await sky.list_windows();
nodeRepl.write(JSON.stringify(windows, null, 2));
```

Select exactly one returned game window by observed app/executable and title,
and store the returned object as `globalThis.gameWindow`. Never guess IDs or
choose the first vague match. Observe and inspect the screenshot:

```javascript
globalThis.state = await sky.get_window_state({ window: gameWindow });
globalThis.gameWindow = state.window;
```

After inspecting, take ONE action and refresh immediately, for example:

```javascript
await sky.press_key({ window: gameWindow, key: "Left" });
globalThis.state = await sky.get_window_state({ window: gameWindow });
globalThis.gameWindow = state.window;
```

Screenshots display automatically. Repeat observe/action; do not reuse stale
coordinates, screenshot IDs, or indexes after state/focus changes. LÖVE can have
little accessibility text. Inspect the actual frame, not an assumed menu layout.
Default engine controls: arrows/WASD move; Z/Return/Space is A; X/Backspace is B;
Escape/keypad Enter is Start; Tab is Select. Physical A is left. Check bindings
and mod overrides. SELECT can have a registered-item or voxel role depending
on current state and hooks. Number 3 is likewise context/mod-dependent.

In Gen 2, `--developer` can expose `mod.developer` but does not add Gen 1's
backtick console or F5 reload. Do not send `warp ...` to an imagined console.
Avoid F1 unless intentionally testing save writes in a disposable profile.
Restart the process for final before/after comparisons.

For `D:\games\gen1recompwin64`:

1. Verify the directory and discover the executable/archive. Distinguish a fused
   game EXE from LÖVE plus a `.love` archive; do not invent an executable name.
2. Verify engine version, this installed mod, correct game import, save root,
   and companions. An older package may lack current source driver support.
3. Launch the discovered fused executable with `--game=silver --slot=N --no-sync`
   (or Crystal), using its working directory. For standalone LÖVE, pass the
   discovered game archive/directory first. Use actual slot selection and Continue.
4. For automatic relocation, verify package driver support and required helper
   availability, or use the source runtime with a test copy of the needed save.
   Package support is conditional; there is no Gen 1 console fallback on Gen 2.
5. Inspect title/Continue/gameplay through Computer Use, then execute the bug's
   actual trigger and collect evidence. Do not silently substitute source-engine
   results for a requested packaged-build test.

A browser-only CUA tool does not imply native Windows game control. Discover the
Windows runtime/tools before declaring them unavailable. If blocked, still
prepare the fixture and run available checks; report that live interaction was
not performed. Inspected driver captures verify appearance, not keyboard/focus
behavior. Never claim a visual pass without seeing the image/window.

## Caches and acceptance matrix

- The persistent voxel cache supports **Gold, Silver, and Crystal**. Preserve
  version-specific geometry identities: cache results from one selected game
  version must never be reused by another. `VoxelMeshDisk.bind()` derives the
  storage namespace from the selected save/game version, so Crystal is a first-
  class cache target rather than a Silver-only or Gold/Silver-only exception.
  Inspect current `StaticGeometry`, `VoxelPrecache`, and `VoxelMeshDisk`
  implementation for the authoritative namespace and lifecycle behavior.
- `VoxelPrecache.startupMapIds(data, save)` reads the saved map from
  `save.player.map` and may add `save.lastOutdoor.id` for indoor recovery. The
  live overworld location is a different concern: use `world.map.id` and
  `world.player.cellX/cellY/facing`. Do not document or implement startup
  precaching against a nonexistent `save.position` field.
- Canonical Gen 2 maps need the same adapter/roof preparation as live maps.
  Runtime palette changes should not be mistaken for changed geometry. Keep
  immutable canonical records separate from transient Cut/Whirlpool/regrowth.
- PRECACHE, Continue, GPU upload, lazy rebuild, CACHE SAVE, and CACHE DROP are
  distinct operations. Do not infer a rebuild from a runtime invalidation alone.
  Do not delete caches as the first diagnosis or trigger DROP incidentally.
- Desktop tracing writes `battleart-gen2-cache.log` in LÖVE's save directory;
  the console reports its path. Copy evidence before restart; include the
  rotated `.previous.log` if present. Follow a map's disk/RAM hit, rejection,
  upload, and build events. See `docs/cache-tracing.md`.
- R.DIST SHORT/MEDIUM/FAR/FULL affects connected-map rendering and characters,
  not simulation distance; the current map remains rendered. Inspect seams,
  reflections, and neighbor ordering at relevant distances. See the port note.

For each fix, select relevant cases rather than claiming the entire game passed:

| Area | Minimum useful comparison |
| --- | --- |
| Common terrain | Silver AND Crystal, flat/OFF and affected angles, adjacent map and another shared tileset location. |
| Roof/atlas | Relevant map-group roof, nearby roof variant, day/night colors, cold/warm load. |
| Cherrygrove forest apron | Northeast forest/Route 29-30-31 context, real water boundary, several views; no collision changes. See `data/voxel_map_aprons.lua` and `tests/cherrygrove_apron.lua`. |
| Dynamic blocks | Before Cut, immediate removal, budgeted rebuild, leave/re-enter regrowth, neighbors retained, warm-cache repeat. |
| Battle | Entry, idle, move/effect, capture/faint, exit and world restoration; staged/native/provider-on/off as relevant. |
| Interface sprites | Summary/Dex, FIT/FULL, small/oversized/animated art, Crystal gender and Unown/native fallback as relevant. |
| Timed/scripted scene | Copied known state, RTC/weekday, actual trigger, arrival callback, input release, return transition. |
| Free cameras | 1ST/3RD movement, collision and landing triggers, then return to an orbit camera. |

These are test targets, not claims of current bugs or verified viewpoints.

## Headless tests: working directories differ

Some tests load engine modules; others open this mod's `lib/` directly. Inspect
the test header before running. Do not run every test from one assumed root.

Engine-root SDK smoke (the audited test explicitly selects SILVER):

```powershell
Set-Location 'D:\gen1recomp'
$env:DS_MOD_PATH = 'dev/BattleArtGen2'
$env:DS_ENGINE_ROOT = 'D:\gen1recomp'
luajit dev/BattleArtGen2/tests/gen2_port_load.lua
```

Mod-root examples:

```powershell
Set-Location 'D:\gen1recomp\dev\BattleArtGen2'
luajit tests/gen2_world_adapter.lua
luajit tests/gen2_voxel_option_scope.lua
luajit tests/cherrygrove_apron.lua
git diff --check
```

Use discovered LuaJIT/LÖVE runtimes. Lua 5.4 parsing does not prove LuaJIT 5.1
compatibility. Inspect `gen2_battle_adapter`, `gen2_block_mesh_refresh`,
`gen2_water_reflection`, `gen2_free_movement_runtime`, `render_distance_gen2`,
`interface_scaling_anchor`, and native Gen 2 cache suites for relevant changes.
Some cache tests need LÖVE's data module/mock graphics. Do not use Gen 1 budget
or storage tests as proof of Gen 2 policies. Historical failures in the port
validation note must be rechecked against the starting revision; do not silently
waive a new failure or report historical counts as a current run.

## Troubleshooting and evidence handoff

| Symptom | Inspect next |
| --- | --- |
| Red/Gold instead of target | Inherited POKEPORT_VERSION, launch selection, GameVersion.get/engine. |
| Importer remains | Selected edition is not ready in this runtime's cache root. |
| No world | Boot phase/error, cinema flag, import readiness; do not push Gen 1 state. |
| Wrong save/location | Active Gen 2 slot, Save2.load, Continue, save.position versus live world coordinates. |
| Flat instead of voxel | Correct mod ID/path, generation-scoped options, loader/render errors and world_probe diagnostics. |
| Wrong roof/colors | Adapter preparation, map-group roof atlas, active edition and time/palette. |
| OFF restores itself | Keep fixture's in-memory game.options.pipelines consistent with runtime level. |
| Unexpected dialog/movement | Scene index, flags, party, VM, scheduled objects, mapSetup and screen stack. |
| Missing screenshots | Create output directory, allow draw frames, verify actual files and images. |
| Stale terrain | Version/cache fingerprint, dynamic block invalidation, canonical versus live map, cold/warm restart. |
| Native UI unavailable | Discover Windows tools/target window; state the exact blocker and completed alternative checks. |

Use this completion record:

```text
Case / expected result:
Engine executable/revision / mod revision and local edits / resolved installed path:
Version AND engine lineage / import / copied save or skeleton / active slot:
Map / object cell / viewing cells / live facing / actual trigger:
RTC hour, minute, weekday / world time / DAYTIME / camera and other options:
Companions and scene owner / cold or warm cache / render distance:
Driver + launch command / Computer Use actions:
Before/after images inspected / visual findings:
Tests run and results / Silver versus Crystal coverage / neighbor/fallback checks:
Not verified / exact blockers / remaining risk:
Cleanup: test instance closed, environment/options restored, player save protected:
```

Record new implementation evidence in the appropriate `docs/` note and changelog
when in scope. Label results as static inspection, mocked/headless test, native
rendered capture inspected, or live Computer Use gameplay. Windows is not Android
or Mali/GLES evidence. This guide was checked against local source on 2026-09-15;
its templates and candidate viewpoints were not live-tested during documentation.
