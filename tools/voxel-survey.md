# Voxel accuracy survey

A repeatable Gen 2 procedure -- runnable by an agent or a human -- for finding
map objects the Battle Art voxel renderer turns into the wrong shape (a bed
extruded to wall height, a table merged into the wall, stairs lying flat)
and for fixing them so each object gets the 3D shape it depicts.

The loop is: **survey → diagnose → pin → re-survey → spot-check**.

## 1. Survey a location

`tests/voxel_survey.lua` is a Gen 2 survey. It receives the live `Game2`
instance, asserts the selected Silver or Crystal edition and the
`BATTLE_ART_VOXEL_GEN2` export, then uses `game.world:setMap()` for a geometry
fixture. It does not use Gen 1 `U.teleport`, and direct relocation does not test
a real transition.

Use a fresh scratch directory and select the edition explicitly:

```powershell
$env:POKEPORT_DRIVER = "dev/BattleArtGen2/tests/voxel_survey.lua"
$env:REPRO_VERSION = "silver"     # repeat separately with crystal
$env:SHOT_DIR = "<absolute writable scratch dir>"
$env:SURVEY_MAP = "CHERRYGROVE_CITY"
$env:SURVEY_SPOTS = "15,10,up@centre; 14,10,left@nearby"
$env:SURVEY_LEVELS = "2,3,4"
$env:POKEPORT_SPEED = "1"
& lovec.exe .
```

`CHERRYGROVE_CITY` is the explicit validated example map in the current Gen 2
data. Spot coordinates are zero-based movement cells and are checked against
the selected map's live block dimensions. Replace the example spots with the
reported object/viewing positions after checking the actual map and walkability.
For progression-dependent bugs, restore a copied known save/slot through the
native Gen 2 save path before the survey; this geometry driver itself is not a
Continue/save test.

### Camera labels and captures

The current voxel ladder is defined by `lib/VoxelState.lua` and exposed through
`src/render/Pipelines.lua`: `0=OFF`, `1=FULL`, `2=15`, `3=35`, `4=50`, followed by
experimental 75/1ST/3RD rungs. The driver accepts numeric levels or exact current
labels, then validates the result against `Pipelines.maxLevel`. Never infer the
meaning of an old numeric level from historical comments.

For EVERY spot the driver captures `_flat` first, then every requested voxel
level. It mirrors levels into `game.options.pipelines` as well as the live
pipeline so generation-scoped option restore logic sees consistent in-memory
state. It waits for actual draw frames and polls the requested output path for up
to 120 driver frames, requiring a non-empty file and rejecting an existing path.
This proves the capture reached disk; it does not prove that a human or native
Computer Use inspected the image.

The driver does not disable scenes, encounters, NPCs, or scripts and does not
force RTC/daytime. If normal Gen 2 scene machinery changes the state, choose a
better fixture/save/approach rather than suppressing native gameplay.

For the shared stateful sequence, follow the engine's [shared reproduction workflow](../../AGENTS.md#shared-reproduction-workflow):
**edition -> runtime/lineage -> persistence root -> copied save/known slot or
fresh fixture -> live state -> approach position -> real trigger -> native
observation -> captured evidence -> cleanup**. This survey covers only the fixture
and capture portions.

## 2. Diagnose against the flat shot

The `_flat` shot is the authority for what each object IS. Compare every
voxel shot against it and record, per object: cells, what it looks like,
what it should look like. The recurring failure modes:

| symptom | cause | fix class |
| --- | --- | --- |
| furniture as a wall-height box | detector defaults solid tiles to `wall` | `bed` / `table` / `desk` |
| furniture towering 3-6 blocks | flood-fill merged it into the wall region, region consensus adopted the tall height | pin it; pinned tiles leave the region |
| walkable art lying flat (stairs, mats) | walkable cells resolve to `ground` | `stair_*`, or leave (mats ARE flat) |
| prop as a solid box wrapped in its art | background flood could not reach around it | `billboard` (forced per-pixel prop) |
| top-down drawing standing upright | art depicts a surface, class folds it | any `top`-art class (`bed`, `ledge`) |
| a house as a cube wearing its own elevation | one drawing packs roof, facade and slopes, and the volume path folds all three upright | a `buildings` template (see below) |

To identify tiles: the map's `blocks` list in `data/generated/maps.lua`
indexes `tileset.blocks` (0-based; each block is 4x4 tile ids over 2x2
cells), and the atlas is the tileset's `image` PNG, 16 tiles per row.
Zoom it with a grid to read ids:

```python
from PIL import Image, ImageDraw
im = Image.open("assets/generated/tilesets/<atlas>.png").convert("RGB")
z = 8; big = im.resize((im.width*z, im.height*z), Image.NEAREST)
d = ImageDraw.Draw(big)
for t in range(im.width//8 * im.height//8):
    x, y = (t % 16)*8*z, (t//16)*8*z
    d.rectangle([x, y, x+8*z-1, y+8*z-1], outline=(255,0,0))
    d.text((x+3, y+2), str(t), fill=(255,0,255))
big.save("<scratch>/atlas_ids.png")
```

## 3. Pin shapes in the profile

The Gen 2 profile in `data/voxel_heights.lua` maps tile ids to shape classes per
tileset id; the classes below are the current Battle Art taxonomy:

- `bed` (h7, art on top) -- anything drawn from above that lies low.
  Also the fallback for a drawing that depicts furniture WITH someone on
  it: a standee would shred it (see the shade note below) and an upright
  fold duplicates them onto the box's top and front, but a slab draws the
  whole thing exactly once.
- `counter` (h8) -- a service counter: half a cell, one 8px band, so the
  drawn front panel stands up and the counter top stays on top. Shorter
  than `table` on purpose; a 12px counter reads as a wall stub.
- `table` (h12) / `desk` (h24) -- boxes; the south face folds the drawing
  upright, flanks wear the front stack darkened, and the top keeps the
  drawn surface (a meal drawn on the tabletop stays on the tabletop).
- `billboard` (10px) / `prop` (5px) / `stool` (5px) / `cutout` (1px) --
  standing per-pixel cutouts: TVs, plants, monitors, stools, vases.
  Segmented by the art's BLACK OUTLINE: background is the shades
  touching the cluster's edge, flooded in from around it; the outline
  and everything it encloses survives, paint whites included -- so a
  white vase cuts cleanly out of a grey tabletop. Solid pixels then
  split into connected components, each standing on its own feet in the
  row it is drawn in (two stacked stools stay two stools; nothing
  floats), and a prop drawn directly above a pinned box stands ON that
  box (the monitor on its desk, the vase on the table). Touching
  drawings that must stay separate objects go in different pools.
  `stool` additionally seats characters: standing on its walkable cell
  lifts them to its 8px class height.
  **Check the drawing has a floor margin before reaching for these.**
  The background is read off the shades touching the cluster's rim, so a
  drawing that runs edge to edge sees its own body colours flood: the
  Pokemon Center bench loses 307 of its 420 interior pixels that way and
  comes out a bare outline. Histogram the rim against the interior first
  -- if all three non-black shades appear on the rim, no standee pool
  will work and the object wants a box or a slab instead.
- `relief` (h3) -- a prop drawn from above (a game console on the
  floor): the drawing stays flat and only the pixels inside its outline
  extrude, art on the top face.
- `bookcase` (h32) -- a free-standing shelf drawn tall, not deep: each
  rank collapses onto a one-cell-deep box at its full drawn height,
  back rows become hidden floor, and a trim row above that cannot be
  pinned (shared with other furniture) is adopted as the cap. Pin the
  book rows and base; leave the shared trim unpinned.
- `stair_e` / `stair_w` -- a rising flight of four steps climbing toward
  the named side, for stairs leading UP.
- `stair_down_e` / `stair_down_w` -- a sunken stairwell descending toward
  the named side, for stairs leading DOWN. Read the drawn railing to pick
  the side: its high end is where the player enters at floor level.
- `wall` -- pin the wall band (and its windows) when de-merging furniture
  would otherwise leave the auto-detected wall patchy.

A whole building is not a tile pin. Its drawing packs several 3D facings
at once -- roof from above, facade face-on, ends as diagonal silhouettes --
and no single class covers that, so buildings go in the profile's
`buildings` list instead, as a BAND TABLE over the drawing's rows
(`mods/DRAMATIC_SHAPE/lib/Buildings.lua`; the pipeline is
`mods/DRAMATIC_SHAPE/assets/docs/buidling_to_voxel/sprite_to_voxel_methodology.md`).
A template is matched by its exact tile grid, which
`assets/docs/buildings/` catalogues per building along
with every map that places it, so one entry covers all of them. Author only what needs a human to read the drawing -- which rows are
roof, how the roof's depth maps onto them, the slab, the eave, an awning
band -- because the silhouette, the taper rate (the slope), the eave
height and every window are measured off the pixels.

Verify a new template against `tools/building_voxels.py`,
which builds the same model offline and renders isometric previews: the
voxel and shell counts it prints must match the runtime's (the mod's
`Buildings.stats()`), and it asserts the intent -- symmetric profile,
constant taper rate, nothing poking through the roof, every wall column
covered.

Heights live in the same file; a cell is 16x16 px, a "block" of height
is 8. The voxelization must be pixel perfect: every standee and relief
voxel carries exactly its source texel, and a segmentation that eats or
keeps the wrong pixels (a cut-off monitor, a slab of tabletop in the
cutout) is a bug -- fix the pin set or the segmentation, don't accept it.

## 4. Re-survey and compare

Re-run step 1 into a fresh `SHOT_DIR` and put before/after side by side.
Check every object at every pitch, not just the one you fixed -- pins
change region shapes, so neighbours can shift.

## 5. Spot-check the blast radius

- Every map sharing the tileset id inherits the pins (grep
  `tileset = "<id>"` in `data/generated/maps.lua`) -- survey at least one.
- A change to the shared analysis (anything in `lib/Structures.lua`
  rather than the data file) affects every map of that kind; survey one
  unrelated busy interior (e.g. `OAKS_LAB`) to prove nothing regressed.
- `luajit tests/dramatic_shape_test.lua` for the headless
  invariants.

## Gameplay is out of bounds

Shape pins are purely presentational. Collision, warps and triggers read
the same data they always did -- a stairwell cell is still the walkable
warp cell it was when it was flat. If a fix seems to need a collision
change, it is the wrong fix.
