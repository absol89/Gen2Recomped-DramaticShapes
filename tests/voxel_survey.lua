-- Driver: Gen 2 voxel-accuracy survey of one map.
--
-- Uses the passed Game2/world, asserts Silver or Crystal, loads an explicit
-- Gen 2 map as a geometry fixture, and captures every spot flat plus each
-- requested voxel camera label. Direct setMap is NOT a real transition test.
--
--   POKEPORT_DRIVER=dev/BattleArtGen2/tests/voxel_survey.lua
--
-- knobs (env):
--   REPRO_VERSION  silver or crystal; required and asserted against GameVersion
--   SURVEY_MAP     Gen 2 map id (default CHERRYGROVE_CITY)
--   SURVEY_SPOTS   "x,y[,facing][@label]; ..." (default centre of map)
--                  cell coordinates, facing up/down/left/right
--   SURVEY_LEVELS  comma list of valid voxel levels OR current labels
--                  (default "2,3,4" = 15/35/50 degrees)
--   SHOT_DIR       absolute writable output directory; must be fresh
--   POKEPORT_SPEED optional integer; keep at 1 for timing-sensitive work
--
-- Levels are set through Pipelines.setLevel and mirrored into game.options so
-- the mod's option restore logic sees the same in-memory value as the renderer.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")
  local Version = require("src.core.GameVersion")

  local SPEED = math.max(1, math.floor(tonumber(os.getenv("POKEPORT_SPEED")) or 1))
  local function wait(frames) U.wait(frames * SPEED) end

  local wanted = assert(os.getenv("REPRO_VERSION"),
    "Set REPRO_VERSION to silver or crystal")
  assert(wanted == "silver" or wanted == "crystal",
    "REPRO_VERSION must be silver or crystal")
  assert(Version.generation() == 2 and Version.get() == wanted,
    "Wrong Gen 2 edition: expected " .. wanted .. ", got " .. Version.get())
  assert(Version.engine() == (wanted == "crystal" and "crystal" or "gs"),
    "Wrong Gen 2 engine lineage")

  local exports = game.mods and game.mods.exports
  assert(exports and exports.BATTLE_ART_VOXEL_GEN2,
    "BATTLE_ART_VOXEL_GEN2 is not loaded")
  local world = assert(game.world, "Gen 2 world is unavailable")
  assert(game.phase == "play" and not game.stack:top(),
    "Survey requires free-roam Game2 state (not a menu/cinema)")

  local DIR = assert(os.getenv("SHOT_DIR"),
    "Set SHOT_DIR to an absolute writable directory")
  assert(DIR:match("^[A-Za-z]:[\\/]") or DIR:match("^/"),
    "SHOT_DIR must be an absolute path")
  local mapId = os.getenv("SURVEY_MAP") or "CHERRYGROVE_CITY"
  local mapDef = world.maps and world.maps[mapId]
  assert(mapDef, "unknown map in selected Gen 2 version: " .. tostring(mapId))
  assert(mapDef.width and mapDef.height and mapDef.width > 0 and mapDef.height > 0,
    "map has invalid dimensions: " .. tostring(mapId))

  local spots = {}
  local spec = os.getenv("SURVEY_SPOTS")
  if spec and spec ~= "" then
    for entry in spec:gmatch("[^;]+") do
      local body, label = entry:match("^%s*(.-)%s*@%s*(%S+)%s*$")
      body = body or entry
      local x, y, facing = body:match("^%s*(%d+)%s*,%s*(%d+)%s*,?%s*(%a*)")
      assert(x, "bad SURVEY_SPOTS entry: " .. entry)
      facing = (facing ~= "" and facing) or "up"
      assert(facing == "up" or facing == "down" or facing == "left" or facing == "right",
        "bad facing in SURVEY_SPOTS entry: " .. entry)
      spots[#spots + 1] = {
        x = tonumber(x), y = tonumber(y), facing = facing,
        label = label or (x .. "x" .. y),
      }
    end
  else
    spots[1] = {
      x = math.floor(mapDef.width * 2 / 2),
      y = math.floor(mapDef.height * 2 / 2),
      facing = "up", label = "centre",
    }
  end
  assert(#spots > 0, "SURVEY_SPOTS produced no positions")

  local levels = {}
  for token in (os.getenv("SURVEY_LEVELS") or "2,3,4"):gmatch("[^,]+") do
    local raw = token:gsub("^%s+", ""):gsub("%s+$", "")
    local level = tonumber(raw)
    if not level then
      for candidate = 0, Pipelines.maxLevel("voxel") do
        if Pipelines.levelLabel("voxel", candidate) == raw then
          level = candidate
          break
        end
      end
    end
    assert(level and level >= 0 and level <= Pipelines.maxLevel("voxel"),
      "invalid SURVEY_LEVELS entry: " .. raw)
    levels[#levels + 1] = level
  end
  assert(#levels > 0, "SURVEY_LEVELS must contain at least one valid level")

  local maxX, maxY = mapDef.width * 2 - 1, mapDef.height * 2 - 1
  for _, s in ipairs(spots) do
    assert(s.x >= 0 and s.x <= maxX and s.y >= 0 and s.y <= maxY,
      ("spot %s,%s is outside %s cell bounds 0..%s,0..%s"):format(
        s.x, s.y, mapId, maxX, maxY))
  end

  local function setLevel(id, level)
    game.options.pipelines = game.options.pipelines or {}
    game.options.pipelines[id] = level
    assert(Pipelines.setLevel(id, level) == level,
      "failed to set pipeline " .. id .. " to " .. tostring(level))
  end

  local function shot(name)
    local path = ("%s/%s_%s.png"):format(DIR, mapId, name)
    local existing = io.open(path, "rb")
    if existing then
      existing:close()
      error("capture already exists; use a fresh SHOT_DIR: " .. path)
    end
    game.capturePath = path
    for _ = 1, 120 do
      wait(1) -- capture is requested during an actual Game2 draw frame
      local f = io.open(path, "rb")
      if f then
        local size = f:seek("end") or 0
        f:close()
        if size > 0 then
          print("[survey] capture ready " .. path)
          return path
        end
      end
    end
    game.capturePath = nil
    error("capture did not reach disk within 120 driver frames: " .. path)
  end

  setLevel("tiltshift", 0)

  for _, s in ipairs(spots) do
    -- Direct relocation is deliberately a geometry fixture. It does not claim
    -- to exercise a door/connection/fall/scripted arrival transition.
    assert(world:setMap(mapId, s.x, s.y, s.facing),
      world.status or "failed to position survey spot")
    wait(20)
    assert(world.map.id == mapId, "fixture moved away from requested map")
    assert(world.player.cellX == s.x and world.player.cellY == s.y,
      "fixture did not reach requested cell")

    setLevel("voxel", 0)
    wait(25)
    shot(s.label .. "_flat")

    for _, level in ipairs(levels) do
      setLevel("voxel", level)
      wait(25) -- outlast the 0.25s camera tween; readiness remains draw-driven
      shot(("%s_v%s"):format(s.label, Pipelines.levelLabel("voxel", level)))
    end
  end

  setLevel("voxel", 0)
  setLevel("tiltshift", 0)
  wait(5)
  print(("[survey] done: edition=%s engine=%s map=%s spots=%d"):format(
    wanted, Version.engine(), mapId, #spots))
end
