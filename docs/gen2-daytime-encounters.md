# DAYTIME and Gen 2 encounters

The mod previously returned Gen 1 presentation names (`MORNING`, `NIGHT`,
`EVENING`) through world.tod. Gen 2 grass slots and rates accept `MORN`,
`DAY`, `NITE` (and `DARK`); unknown keys fall back to DAY. Time-dependent
fishing also recognizes NITE/DARK, not NIGHT. This could remove morning/night
species from the effective encounter table even with a visibly dark sky.

SYNC additionally read os.date directly, ignoring the save's RTC offset.
Pokegear uses src.core.gen2.Clock, so its displayed nighttime could disagree
with the mod's period. Gen 2 now uses that same Clock.minutes(save) for SYNC.

The dial is converted to a 24-hour time and classified by the host's
Palettes.clockDaytime. In the tested engine, boundaries are 04:00 MORN,
10:00 DAY and 18:00 NITE. DAWN pins 06:00 (MORN), DAY noon, DUSK 18:00
(NITE), NIGHT midnight. CYCLE follows the same boundaries. Smooth sky tint
blends do not define encounter categories. Legacy Gen 1 naming is preserved.

This uses the existing world.tod hook. It affects encounter slots/rates,
time-dependent fishing and script TIMEOFDAY. It does not rewrite the save
RTC, weekdays, or hour-specific NPC schedules. Pokegear remains the underlying
RTC display when the mod pins or cycles a period; SYNC follows that display.
Map-pinned cave/indoor palette lighting remains separate from encounter time.

Validation, 2026-10-19:

- New regression loads the production hook, DayNight, Clock, World and
  Encounter. Checks all pins, all 1,440 minutes for SYNC and CYCLE, a saved
  offset putting Pokegear at midnight while the host is at noon, grass slots
  and rates, timed fishing, and unchanged Gen 1 behavior. Previous DayNight
  fails the saved-offset check; fixed version passes.
- Existing engine pinned-palette encounter regression: 6/6 checks passed.
- Running native Windows LÖVE with the mod in disposable Silver and Crystal
  profiles: verified world.tod and script period for each pin, SYNC/Pokegear
  midnight agreement, and deterministic selection from actual imported grass
  tables. Hoothoot (Route 29), Ledyba (Route 30 morning), and Gastly (Sprout
  Tower 2F night) are reachable again. Both runs exited 0; no player save writes.
- Local imported-table audit: morning/day slots differ on 27 Silver maps and
  17 Crystal maps; night/day differ on 57 and 84 respectively (species or
  level differences, not counts of unique missing species).
- No random walking encounter survey, Gold live test, or mobile test was
  performed. Existing saves need no migration; returning to normal world
  updates allows the host's regular time-of-day polling to refresh the period.
