# Optional Lightweight Weather & Skies integration

Lightweight Weather & Skies (LWS) is a separate companion. This host does not
bundle its source, effects, art, audio, or private lab packages. The compatibility
seams below already exist in Battle Art Gen2; documenting and testing them does
not add weather rendering or introduce a required dependency.

The legacy integration discovers `BATTLE_ART_VOXEL_GEN2` and reads
`exports.lib.require`. It obtains `Voxel3D`, `Sky`, and `DayNight` through that
namespace. `Voxel3D.beginScene` binds the scene canvas and updates `eye` and `vp`
before calling `Sky.paint`. Sky wrappers must preserve all arguments, including
the optional camera ray fan, and the original return value. `Voxel3D.endScene`
returns the rendered canvas once, resets the host's shader/depth/canvas bindings,
and returns nil when no scene is active. It does not restore arbitrary caller
graphics state; companions must restore any extra state they change, including
on errors.

LWS currently supplies its own legacy attachment logic and effect helpers in
memory. Its Gen2 Quest path attaches sky work at `Sky.paint` and late work before
the current eye closes. A stereo bridge can temporarily replace `endScene`, so a
wrapper captured only at mod load is not proof of integration with both eyes.
The Quest bridge remains a separate dependency for standalone Quest operation.
This host does not advertise the newer `voxel_companion` atmosphere-effects
packet API merely because these legacy seams are present.

## Regression coverage

From the mod root, run:

```text
luajit tests/lws_host_contract.lua
```

An optional first argument selects a different host root, allowing the same test
to run against the unmodified baseline. The test uses the actual `Voxel3D` and
`Mat4` modules with mocked graphics and sibling services. It checks source-level
library export/identity, camera and canvas availability at the sky seam, camera
ray forwarding for two synthetic cameras, once-per-scene sky invocation, scene
close/reset behavior, omission of sky work when no sky is supplied, and the
unavailable-shader fallback. It does not load LWS, the engine, or a Quest bridge.

Passing this test is source/mocked evidence only. It does not verify weather
appearance, cloud or precipitation depth, clocks/options, companion failure
recovery, stereo rendering, performance, or any device. Live acceptance requires
separate Silver and Crystal checks with the exact engine, host, LWS, and bridge
versions recorded: companion absent/present/disabled; outdoor and indoor entry;
flat and voxel modes; menus and battle transitions; and, on Quest, both eyes and
graphics-state recovery. No such live validation is claimed by this test.

Puddles and god rays are outside this integration scope. Companion source and
asset permissions remain with their authors; this documentation grants no right
to redistribute them and does not turn private lab artifacts into public builds.
