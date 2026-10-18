# Gen 2 staged battle HUD inversion

The host's current Chrome.printThrough and printRightThrough batch glyphs
through a private drawThrough helper. They no longer call the public
paletteGlyphs helper that Battle Art intercepted. As a result the adapter
was active in the correct staged battle, but text bypassed its ink/shadow
policy while box borders still received styling.

Gen2BattleAdapter now temporarily owns both text entry points as well as
paletteGlyphs. It uses the host's font encoding and advances, retains paper
handling, and restores all replaced functions after the staged draw, including
errors. The live HUD instance's tile palettes also receive the selected ink;
the HP/EXP fill entries remain untouched. This applies inside the existing
Battle Art composition scope, including the Stadium UI composition branch;
ordinary unstaged battles retain the native renderer.

Validation (2026-10-19):

- User confirmed HUD COLOR's colored mode and textbox fills were tested and
  working. Font appearance supplied by BATTLE386 remains outside this fix.
- tests/gen2_hud_live_chrome.lua loads the actual host Chrome module. It fails
  against the previous adapter, and passes with this change: enemy/player/
  message text, opposing drop shadows, proportional right alignment, HP fill
  preservation, and restoration after success/error.
- Existing gen2_battle_adapter, battle_hud_bar_colors and hud_paper_transparency
  regressions pass under LuaJIT 2.1.
- Native Windows LÖVE staged Crystal battle captures inspected: Celadon City
  fresh fixture at (20,10), Cyndaquil versus Metapod, INVERTED and COLOR menus
  and the move pane, TEXTBOX FILL OFF. No player save was loaded or saved.
- Gold/Silver live rendering, Stadium provider live rendering, and physical
  mobile targets were not tested in this check. Crystal uses the same native
  Gen 2 Chrome/BattleState implementation, but is not a Gold gameplay test.

The neighboring BattleArtGen2-codex folder is an existing clean Git worktree
on codex/battle-art-voxel-gen2, last committed in August 2026. It was not
modified or removed as part of this fix.
