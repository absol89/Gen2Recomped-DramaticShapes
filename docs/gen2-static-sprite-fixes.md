# Gen2 staged static sprites (2026-09-10)

The staged player trainer capture now reconstructs keyed shade-zero paper inside indexed ROM backs after removing the outside matte. Authored images and true-color portraits bypass reconstruction, preserving gen2player.png transparency. The original engine trainer image is restored after capture, including its existing error path.

STATIC Battle Art Pokemon now subtract measured transparent bottom padding from their capture anchor, on both player and enemy sides, using the native picture scale. This fixes a static illustration hanging above its world ground line because its image canvas extends below its painted feet. Animated atlas margins/motion, ROM images and substitutes retain their existing anchoring. Oversized enemy images still use Gen2's top-pinned image baseline.

Validation: LuaJIT 2.1 through Lupa; gen2_static_ground_anchor, trainer_matte_transparency (including keyed ROM shirt restoration), authored_sprite_transparency, player_trainer_selection, player_trainer_intro_animation, capture_visibility and battle_ground_clearance pass. Lua syntax and git diff whitespace checks pass. These are mocked/headless regressions; actual ROM/PNG intro captures, static Ekans on both sides, live setting transitions, and attack resize/faint behavior still need in-game visual confirmation. No source PNGs changed.
