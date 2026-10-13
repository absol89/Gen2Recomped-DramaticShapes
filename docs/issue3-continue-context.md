# Issue #3: Continue callback context (2026-10-13)

Release: **2.1.3**. Report: [issue #3](https://github.com/absol89/Gen2Recomped-DramaticShapes/issues/3).

The issue's October failures report `main.lua:1350: attempt to index local
'menu' (a nil value)`. The mod turns the native `{value="continue"}` row
into an injected `onSelect` callback. Its native-action closure calls
`menu:choose("continue")`, assuming every host supplies a second argument.
Argument-free callback hosts violate that assumption. That is a Lua callback
compatibility defect, not evidence of GPU failure or out-of-memory.

The current Gen2 mod dispatcher normally supplies `(game, menu)`, whereas the
shared Gen1 Menu calls `item.onSelect()` and Gen2 StartMenu supplies only game.
The logged historical engine/host combination is not available for device
reproduction, so this review does not identify which menu host the reporter
actually ran. The production callback is nevertheless reproducibly unsafe with
the argument-free call shape, giving the exact nil-menu error.

Continue and New Game wrappers now use the explicit owner when supplied, or
capture the current stack screen when called without one. Capture happens
before a cache loader can cover the menu. Delayed completion uses that captured
owner, retaining the native Continue confirmation rather than bypassing it.

Steam Deck is classified as Linux desktop by the current engine, so the mod
uses eager preload. iOS is mobile and uses streaming with the selected soft RAM
budget. Both paths eventually invoke the same native-action closure and thus
can reach this missing-context defect. Neither path proves an iOS crash occurred.
Separately, desktop eager preload currently clears the selected soft RAM budget;
the default setting is 3072 MiB and dirty cache records may exceed soft budgets.
That remains a memory-pressure concern, distinct from this nil-menu exception.

The August `Unknown event: mesh` entry in the issue belongs to engine 0.1.82
and predates the October nil-menu reports. No producer of a custom `mesh` event
or matching handler was found in the inspected current main/core/render/mod
paths. It is a separate historical symptom; no fix for it is claimed.

Validation:

- `tests/title_continue_callback_context.lua` executes the production mod hook
  and dispatcher with mocks. The old PR5 main.lua reproduces the exact nil-menu
  failure; the updated main passes explicit/no-argument hosts, eager/mobile,
  precache OFF, ready cache, deferred loader and original callback cases.
- The engine's MainMenu translation regression passes through embedded LuaJIT
  2.1. Engine resource monitoring and clipboard changes are separate engine
  work; installing this mod does not supply those features.
- Native LOVE storage compatibility, streaming and cache lifecycle tests pass
  after combining PR5 with the preserved changes. SDK load and 138-file LuaJIT
  syntax scan pass; whitespace checks pass.
- Previous performance regressions and PR5 synthetic geometry tests pass; the
  isolated old PR5 render-distance test still has its documented missing
  CacheTrace mock. The updated local test supplies that dependency and passes.

A native Continue probe did not produce usable driver logs or captures and is
not counted as a gameplay or visual pass. Physical iOS/Steam Deck qualification
remains outstanding. No player saves or options were changed during testing.

Run the focused regression from this mod's root:

```text
luajit tests/title_continue_callback_context.lua
```
