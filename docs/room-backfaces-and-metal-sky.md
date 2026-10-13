# Room cutaways and Metal sky alignment

Room shells were emitted with inward-facing geometry but rendered in the
same two-sided pass as mirrored sprites. The new marker encodes a shell
normal in the existing six-float vertex format. The scene shader discards
fragments when the camera lies behind that normal, including their depth
writes. Ceiling fronts face down, wall fronts face into the room. Native
perimeter columns use the room center to face inward rather than drawing an
exterior wall skin. Furniture and sprites retain their two-sided rendering.

The marker survives packed cache vertices. Cache revision 24 rejects older
records so they rebuild through the normal cache path. No gameplay, collision,
door warp, authored floor or exterior building geometry is changed. Natural
Cave/DarkCave/IcePath profiles do not receive room ceilings; authored rooms
using those tilesets remain governed by their existing exact style rules.

Gen2 world presentation reverses the finished scene on LÖVE 12 Metal. The sky
is a 2D shader rectangle inside that 3D target, so its screen coordinates must
use the same raw canvas orientation. Otherwise the final flip moves its ray
elevations opposite the terrain, and discarded sky pixels expose the pale
clear color. The sky now receives an optional raw-canvas Y correction from
Voxel3D. Cameras already carrying the Metal battle Y correction are excluded.
Desktop/VR cameras retain their prior path. The flat gradient fallback uses
the same correction and restores its added transform if drawing fails.

Validation (2026-10-13):

- Inspected the supplied mobile recording and three screenshots.
- Headless inward-normal/packed-shade, fallback-ceiling, LWS host, world
  adapter, render-distance and 13 synthetic visual suites passed. Gen2 water
  reflection passed 18 checks. Library LuaJIT syntax checks passed.
- The Silver SDK load passed using explicit fixture paths and a read-only
  directory probe. The stock Windows test adapter's rename-to-self directory
  probe did not discover this checkout; that run is not counted as passing.
- Native Windows LÖVE/OpenGL shader fixture rendered ceiling fronts from
  inside and discarded backs from outside. Sky pixels matched the desktop
  result after a simulated Metal-style canvas reversal; the fixture also
  reproduces the old pale-haze region when that correction is omitted.
- Native Crystal captures of Cherrygrove Mart, Cianwood Gym and Union Cave 1F
  were inspected. Room ceilings no longer obscure the view. Union Cave retained
  its rock geometry with no room ceiling. These are fresh geometry fixtures,
  not tests of native door transitions or a restored player save.
- Physical iOS/Metal and headset qualification remain outstanding; OpenGL
  simulation is not device evidence. No version tag, package build, deployment
  or push was performed. Player saves/options were left untouched.

Run `luajit tests/room_backfaces.lua` from the mod checkout for pure logic.
For the GPU fixture, set DS_MOD_PATH to that checkout and SHOT_DIR to an
existing writable output directory, then launch a compatible LÖVE runtime
with `tests/gpu_room_sky` as its source. It uses synthetic geometry/palette,
writes `gpu.log` and PNGs to SHOT_DIR, and returns a failing exit code on a
pixel mismatch. It does not boot gameplay or load player data.
