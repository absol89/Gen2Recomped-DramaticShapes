-- Optional Stadium 2 model adapter for Battle Art's staged voxel arena.
-- Battle Art retains the camera, terrain, HUD, animation projection and
-- battle lifecycle; the optional importer owns only its model instances.

local V = ...

local Mat4 = V.require("Mat4")
local BattleArt = V.require("BattleArt")

local StadiumModels = {}

local providerHandle, providerExports, models
local actors = { player = {}, enemy = {} }
local warned = {}
local reported = {}
local report

-- Importer 0.10.14's expanded desktop shader uses the manual
-- `void effect()/love_PixelColor` output path. It compiles on the packaged
-- Gen2Recomped runtime, so drawScene reports success, but produces no color
-- when drawing into Battle Art's externally-bound color+depth target. Its
-- separate shadow shader still works, which presents as two model shadows
-- under two ordinary Battle Art cards. Use the older, portable effect return
-- contract at this boundary. The renderer continues to own all meshes,
-- textures, animation, material selection, depth modes and draw ordering.
local COMPAT_COLOR_SHADER = [[
varying vec3 stadiumNormal;
#ifdef VERTEX
uniform mat4 mvp;
uniform mat3 normalMatrix;
attribute vec3 VertexNormal;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  stadiumNormal = normalize(normalMatrix * VertexNormal);
  return mvp * vertex_position;
}
#endif
#ifdef PIXEL
uniform vec4 primitiveColor;
uniform vec4 environmentColor;
uniform float environmentMix;
uniform vec4 sceneTint;
uniform float flashAmount;
uniform float alphaCutoff;
uniform float lightingEnabled;
uniform float effectIntensityMode;
vec4 effect(vec4 color, Image texture, vec2 texture_coords,
            vec2 screen_coords) {
  vec4 texel = Texel(texture, texture_coords);
  if (effectIntensityMode > 0.5) {
    float intensity = texel.r;
    float alpha = intensity * primitiveColor.a * color.a * sceneTint.a;
    if (alpha <= alphaCutoff) discard;
    vec3 gas = mix(environmentColor.rgb, primitiveColor.rgb, intensity);
    return vec4(gas * color.rgb * sceneTint.rgb, alpha);
  }
  texel *= color * primitiveColor;
  if (texel.a <= alphaCutoff) discard;
  vec3 n = normalize(stadiumNormal);
  float shade = clamp(0.7725 + n.x * 0.06 + n.y * 0.225
                      + n.z * 0.11, 0.30, 1.0);
  vec3 base = mix(texel.rgb, texel.rgb * environmentColor.rgb,
                  environmentMix);
  vec3 lit = mix(base, base * shade, lightingEnabled) * sceneTint.rgb;
  lit = mix(lit, vec3(1.0), flashAmount);
  return vec4(lit, texel.a
    * mix(1.0, environmentColor.a, environmentMix) * sceneTint.a);
}
#endif
]]

local function installCompatColorShader(renderer)
  if not (renderer and love and love.graphics
      and type(love.graphics.newShader) == "function") then return false end
  local ok, shader = pcall(love.graphics.newShader, COMPAT_COLOR_SHADER)
  if not (ok and shader) then
    report("compat-shader", "compile-failed " .. tostring(shader))
    return false
  end
  local previous = renderer.shader
  renderer.shader = shader
  renderer.shaderTier = "battle-art-compat"
  if previous and previous ~= shader and previous.release then
    pcall(previous.release, previous)
  end
  report("compat-shader", "installed")
  return true
end

-- Logger output is buffered by the packaged Gen2Recomped launcher and may not
-- reach log.txt until the launcher itself exits. Keep this tiny, de-duplicated
-- report beside the save instead so a ROM close is enough to diagnose the
-- compatibility boundary. It contains no save data, only API/model state.
report = function(key, message)
  message = tostring(message)
  if reported[key] == message then return end
  reported[key] = message
  local fs = love and love.filesystem
  if not (fs and fs.append) then return end
  pcall(fs.append, "battle_art_stadium2_bridge.txt",
    ("%s %s\n"):format(tostring(key), message))
end

do
  local fs = love and love.filesystem
  if fs and fs.write then
    pcall(fs.write, "battle_art_stadium2_bridge.txt",
      "Battle Art 2.0.7 standalone Stadium 2 bridge\n")
  end
end

local function warnOnce(key, message)
  if warned[key] then return end
  warned[key] = true
  local log = V.mod and V.mod.log
  if log and log.warn then pcall(log.warn, log, "%s", tostring(message)) end
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

-- The importer's exported Renderer has every operation Battle Art needs to
-- draw into the open voxel color/depth target. 0.10.7 exposes only this path;
-- 0.10.14 also exposes an owned-instance API, but its graphics-state scope can
-- successfully submit a shadow pass while leaving this host's already-bound
-- color/depth target untouched by the color pass. Keep the direct renderer as
-- the preferred embedded-scene boundary on every version that exports it,
-- with the v2 instance API as a fallback for importers that remove it later.
local function legacyInstance(renderer)
  local instance = { renderer = renderer }

  function instance:release()
    if self.renderer and self.renderer.release then
      pcall(self.renderer.release, self.renderer)
    end
    self.renderer = nil
  end

  function instance:metrics()
    if not (self.renderer and self.renderer.worldMetrics) then return nil end
    return self.renderer:worldMetrics()
  end

  function instance:playContext(name, loop)
    if not (self.renderer and self.renderer.setContext) then return false end
    local ok = self.renderer:setContext(name, loop and true or false)
    if not ok and name == "attack" then
      ok = self.renderer:setContext("attack_default", loop and true or false)
    end
    return ok and true or false
  end

  function instance:playMove(move, loop)
    return self.renderer and self.renderer.setMove
      and self.renderer:setMove(move, loop and true or false) or false
  end

  function instance:update(dt, runtime)
    if not self.renderer then return nil, "released" end
    if self.renderer.setHandlerRuntime then
      runtime = runtime or {}
      -- Match importer 0.10.7's BattleActor exactly. Handler evaluation is
      -- deferred into step(), after the pose clock advances; evaluating it
      -- immediately against a stale pose leaves callback objects frozen and
      -- can expose the yellow dynamic primitives between the two battlers.
      runtime.frame = self.renderer.frame
      runtime.textureFrame = self.renderer.frame
      self.renderer:setHandlerRuntime(runtime, true)
    end
    self.renderer:step(dt)
    return true
  end

  function instance:isFinished()
    return self.renderer and self.renderer.finished == true or false
  end

  function instance:draw(options)
    if not self.renderer then return false, "released" end
    options = options or {}
    local camera, light, shadow = options.camera or {}, options.light or {},
      options.shadow or {}
    return self.renderer:drawScene(options.pass, options.modelMatrix, {
      viewProjection = camera.viewProjection,
      viewMatrix = camera.view,
      lightDir = light.direction,
      ambient = light.ambient,
      diffuse = light.diffuse,
      tint = options.tint,
      flashAmount = options.flashAmount,
      sunMap = shadow.map,
      sunVP = shadow.viewProjection,
      sunDark = shadow.darkness,
      sunBias = shadow.bias,
      sunTexel = shadow.texel,
      flipWinding = options.flipWinding,
      disableCulling = options.disableCulling,
    })
  end

  function instance:drawShadow(options)
    if not self.renderer then return false, "released" end
    options = options or {}
    return self.renderer:drawShadowMap(options.modelMatrix,
      options.lightViewProjection)
  end

  return instance
end

local function versionAtLeast(value, major, minor, patch)
  local a, b, c = tostring(value or ""):match("^v?(%d+)%.(%d+)%.(%d+)")
  if not a then return nil end
  a, b, c = tonumber(a), tonumber(b), tonumber(c)
  if a ~= major then return a > major end
  if b ~= minor then return b > minor end
  return c >= patch
end

local function legacyApi(exports, version)
  if not (type(exports) == "table" and type(exports.newRenderer) == "function") then
    return nil
  end
  -- f94bb66 changed the color shader output contract; v0.10.11 was the
  -- first release carrying it. Model API v2 did not arrive until v0.10.14,
  -- so using that namespace as the gate misses three affected releases.
  local affected = versionAtLeast(version, 0, 10, 11)
  if affected == nil then
    affected = type(exports.models) == "table"
      and (tonumber(exports.models.apiVersion) or 0) >= 2
  end
  return {
    apiVersion = 1,
    newInstance = function(dex, variant, options)
      local renderer, err = exports.newRenderer(dex, variant, options)
      if not renderer then return nil, err end
      if affected then installCompatColorShader(renderer) end
      return legacyInstance(renderer)
    end,
  }
end

local function connect()
  if models and type(models.newInstance) == "function" then
    return models, providerExports
  end
  local handle = findMod("STADIUM2_IMPORTER")
  local exports = handle and handle.exports or nil
  local candidate = legacyApi(exports, handle and handle.version)
  local route = candidate and "direct-renderer" or nil
  if not candidate then
    candidate = type(exports) == "table" and exports.models or nil
    if type(candidate) ~= "table" or (tonumber(candidate.apiVersion) or 0) < 2
        or type(candidate.newInstance) ~= "function" then
      candidate = nil
    else
      route = "models-v2"
    end
  end
  if not candidate then
    report("connect", ("missing handle=%s exports=%s newRenderer=%s")
      :format(tostring(handle ~= nil), tostring(type(exports)),
              tostring(type(exports and exports.newRenderer))))
    return nil
  end
  providerHandle, providerExports, models = handle, exports, candidate
  report("connect", ("ok importer=%s api=%s route=%s")
    :format(tostring(handle and handle.version),
            tostring(candidate.apiVersion), tostring(route)))
  return models, providerExports
end

function StadiumModels.installed()
  return connect() ~= nil
end

local function exportEnabled(exports, name)
  local fn = exports and exports[name]
  if type(fn) ~= "function" then return nil end
  local ok, enabled = pcall(fn)
  if not ok then ok, enabled = pcall(fn, exports) end
  if ok then return enabled end
  return nil
end

function StadiumModels.active()
  local api, exports = connect()
  if not api then return false end
  -- The importer toggles are the single source of truth for Pokemon art in a
  -- staged voxel battle. Both ON selects its scene-neutral model instances;
  -- either OFF releases them and leaves Battle Art's sprite cards in place.
  local modelOn = exportEnabled(exports, "modelsEnabled")
  local battleOn = exportEnabled(exports, "battleEnabled")
  report("toggles", ("models=%s battles=%s")
    :format(tostring(modelOn), tostring(battleOn)))
  if modelOn ~= true then return false end
  if battleOn ~= true then return false end
  return true
end

local function releaseActor(actor)
  if actor.instance and type(actor.instance.release) == "function" then
    pcall(actor.instance.release, actor.instance)
  end
  for key in pairs(actor) do actor[key] = nil end
end

local function failActor(actor)
  local battler, dex, variant = actor.battler, actor.dex, actor.variant
  releaseActor(actor)
  actor.failedBattler, actor.failedDex, actor.failedVariant =
    battler, dex, variant
end

function StadiumModels.release()
  releaseActor(actors.player)
  releaseActor(actors.enemy)
  StadiumModels.animWasPlaying = false
end

local function battleData(battle)
  if type(battle) ~= "table" then return nil end
  if type(battle.data) == "table" then return battle.data end
  if type(battle.game) == "table" and type(battle.game.data) == "table" then
    return battle.game.data
  end
  if type(battle.battle) == "table" then
    return battleData(battle.battle)
  end
  return nil
end

-- RBY's rules battle exposes `battle.player` / `battle.enemy`. The unified
-- Gen 2 presentation keeps the actually shown party members on
-- BattleState:activeMon instead. Accept both shapes at this leaf boundary so
-- the Stadium renderer is not coupled to either engine context.
local function battlerFor(battle, side)
  if type(battle) ~= "table" then return nil end
  if type(battle.activeMon) == "function" then
    local ok, mon = pcall(battle.activeMon, battle, side)
    if ok and mon then return mon end
  end
  if battle[side] then return battle[side] end
  if type(battle.battle) == "table" then
    return battlerFor(battle.battle, side)
  end
  return nil
end

local function dexFor(battle, battler)
  local species = BattleArt.speciesFor(battler)
  if type(species) == "number" then
    local dex = math.floor(species)
    return dex >= 1 and dex <= 251 and dex or nil
  end
  local data = battleData(battle)
  local pokemon = data and data.pokemon
  -- BattleArt.speciesFor deliberately canonicalizes Gen2Recomp's generated
  -- key `SPECIES_158` to the art name `TOTODILE`. The generated data table is
  -- still keyed by the former, however. Resolve the raw battle species first,
  -- then the art alias, then named definitions (needed for Transform targets
  -- recorded by name). This runs only when a side changes, not per draw.
  local raw = battler and (battler.__battleArtTransformed
    or (battler.mon and battler.mon.species) or battler.species) or nil
  local rawNumber = type(raw) == "string"
    and tonumber(raw:match("^SPECIES_0*(%d+)$")) or nil
  if rawNumber then
    rawNumber = math.floor(rawNumber)
    if rawNumber >= 1 and rawNumber <= 251 then return rawNumber end
  end
  local def = type(pokemon) == "table"
    and (pokemon[raw] or pokemon[species]) or nil
  if not def and type(pokemon) == "table" and type(species) == "string" then
    for _, candidate in pairs(pokemon) do
      if type(candidate) == "table" and candidate.name == species then
        def = candidate
        break
      end
    end
  end
  local dex = def and tonumber(def.dex or def.index)
  dex = dex and math.floor(dex) or nil
  return dex and dex >= 1 and dex <= 251 and dex or nil
end

local function safeCall(object, name, ...)
  local fn = object and object[name]
  if type(fn) ~= "function" then return nil end
  local ok, value, extra = pcall(fn, object, ...)
  if not ok then return nil, value end
  return value, extra
end

local function playIdle(actor)
  if not actor.instance then return false end
  local ok = safeCall(actor.instance, "playContext", "idle", true)
  actor.context = ok and "idle" or actor.context
  return ok and true or false
end

local function playContext(actor, context, loop)
  if not actor.instance then return false end
  local ok = safeCall(actor.instance, "playContext", context, loop)
  if not ok and context == "attack" then
    ok = safeCall(actor.instance, "playContext", "attack_default", loop)
  end
  if not ok and context ~= "idle" then return playIdle(actor) end
  if ok then actor.context = context end
  return ok and true or false
end

local function syncSide(battle, side)
  local actor = actors[side]
  local battler = battlerFor(battle, side)
  local dex = dexFor(battle, battler)
  local variant = BattleArt.isShiny(battler) and "shiny" or "normal"
  report("source-" .. side, ("battle=%s battler=%s species=%s dex=%s variant=%s")
    :format(tostring(type(battle)), tostring(battler ~= nil),
            tostring(BattleArt.speciesFor(battler)), tostring(dex), variant))
  if actor.instance and actor.battler == battler and actor.dex == dex
      and actor.variant == variant then return actor end
  if actor.failedBattler == battler and actor.failedDex == dex
      and actor.failedVariant == variant then return actor end

  releaseActor(actor)
  actor.battler, actor.dex, actor.variant = battler, dex, variant
  if not (battler and dex) then return actor end

  local api = connect()
  if not api then return actor end
  local called, instance, err = pcall(api.newInstance, dex, variant, {
    textureFilter = "nearest",
    anisotropy = 4,
    flipY = false,
    anchorTravel = true,
  })
  if not called then err, instance = instance, nil end
  if type(instance) ~= "table" then
    actor.failedBattler, actor.failedDex, actor.failedVariant =
      battler, dex, variant
    warnOnce(("load:%s:%d:%s"):format(side, dex, variant),
      ("Stadium 2 %s model %03d (%s) unavailable: %s; using Battle Art")
        :format(side, dex, variant, tostring(err)))
    report("renderer-" .. side, ("failed dex=%03d variant=%s error=%s")
      :format(dex, variant, tostring(err)))
    return actor
  end

  actor.instance = instance
  actor.callbackFrame = side == "enemy" and 4 or 0
  actor.context = "idle"
  actor.lastGrow, actor.lastFainted, actor.lastPicKind = false, false, nil
  playIdle(actor)
  report("renderer-" .. side, ("ready dex=%03d variant=%s")
    :format(dex, variant))
  return actor
end

function StadiumModels.sync(battle)
  if not StadiumModels.active() then
    StadiumModels.release()
    return false
  end
  syncSide(battle, "player")
  syncSide(battle, "enemy")
  return true
end

local function updatePresentation(battle, side, actor)
  if not actor.instance then return end
  local battler = battlerFor(battle, side)
  local rules = type(battle) == "table" and battle.battle or battle
  local grow = battler and safeCall(rules, "growInScale", battler) or nil
  if grow and not actor.lastGrow then playContext(actor, "entrance", false) end
  actor.lastGrow = grow and true or false

  local fainted = battler and battler.fainted and true or false
  local faintFx = battler and safeCall(rules, "fxFaintActive", battler) or false
  if (faintFx or fainted) and not actor.lastFainted then
    playContext(actor, "faint", false)
  end
  actor.lastFainted = fainted or faintFx or false

  local picFx = battler and rules and rules.picFx and rules.picFx[battler] or nil
  local kind = picFx and picFx.kind or nil
  if kind == "blink" and actor.lastPicKind ~= "blink" then actor.flash = 0.12 end
  actor.lastPicKind = kind
end

function StadiumModels.update(battle, dt)
  if not StadiumModels.sync(battle) then return false end

  for _, side in ipairs({ "player", "enemy" }) do
    updatePresentation(battle, side, actors[side])
  end

  local playing = battle and battle.animPlaying and true or false
  if playing and not StadiumModels.animWasPlaying then
    local data = battleData(battle)
    local def = data and data.moves and data.moves[battle.animName]
    local side = battle.animAttackerIsPlayer and "player" or "enemy"
    local actor = actors[side]
    local move = def and tonumber(def.index or def.number)
    local ok = actor.instance and move
      and safeCall(actor.instance, "playMove", move, false)
    if actor.instance and not ok then playContext(actor, "attack", false) end
    if ok then actor.context = "attack" end
  end
  StadiumModels.animWasPlaying = playing

  dt = math.max(0, tonumber(dt) or 0)
  for _, side in ipairs({ "player", "enemy" }) do
    local actor = actors[side]
    if actor.instance then
      actor.flash = math.max(0, (actor.flash or 0) - dt)
      actor.callbackFrame = (actor.callbackFrame or 0) + dt * 30
      local updated, err = safeCall(actor.instance, "update", dt, {
        callbackFrame = math.floor(actor.callbackFrame),
        species = actor.dex,
      })
      if updated == nil and err then
        warnOnce("update:" .. side,
          ("Stadium 2 %s model update failed: %s; using Battle Art")
            :format(side, tostring(err)))
        failActor(actor)
      elseif safeCall(actor.instance, "isFinished")
          and actor.context ~= "idle" and actor.context ~= "faint" then
        playIdle(actor)
      end
    end
  end
  return true
end

local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 then return math.atan(y / x) + (y >= 0 and math.pi or -math.pi) end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

local function modelMatrix(arena, groundY, battle, side, actor)
  local point = arena and arena[side]
  local target = arena and arena[side == "player" and "enemy" or "player"]
  if not (point and target and actor.instance) then return nil end
  local metrics = safeCall(actor.instance, "metrics")
  if not (metrics and tonumber(metrics.height) and metrics.height > 0) then
    return nil
  end

  local worldHeight = math.max(5, math.min(18,
    14 * math.sqrt(metrics.height / 52.25)))
  local battler = battlerFor(battle, side)
  local rules = type(battle) == "table" and battle.battle or battle
  local grow = battler and safeCall(rules, "growInScale", battler) or 1
  grow = tonumber(grow) or 1
  local k = worldHeight / metrics.height * math.max(0, math.min(1, grow))
  local floor = tonumber(metrics.floor) or 0
  local hover = math.min(math.max(floor, 0), metrics.height * 0.5)
  local yaw = atan2(target[1] - point[1], target[2] - point[2])
  return Mat4.mul(Mat4.translate(point[1], groundY, point[2]),
    Mat4.mul(Mat4.rotateY(yaw),
      Mat4.mul(Mat4.scale(k, k, k), Mat4.translate(0, -(floor - hover), 0))))
end

-- Return only sides that can replace a Pokemon card this frame. Trainer
-- portraits and host-hidden sides remain on Battle Art's established path.
function StadiumModels.placements(arena, groundY, textures, battle)
  if not StadiumModels.sync(battle) then return {} end
  local out = {}
  for _, side in ipairs({ "enemy", "player" }) do
    local texture = textures and textures[side]
    local actor = actors[side]
    if texture and not texture.trainer and actor.instance then
      local matrix = modelMatrix(arena, groundY, battle, side, actor)
      if matrix then
        out[side] = { side = side, actor = actor, instance = actor.instance,
                      modelMatrix = matrix }
      end
    end
  end
  report("placements", ("player=%s enemy=%s textures=%s/%s")
    :format(tostring(out.player ~= nil), tostring(out.enemy ~= nil),
            tostring(textures and textures.player ~= nil),
            tostring(textures and textures.enemy ~= nil)))
  return out
end

function StadiumModels.draw(placement, context, pass)
  if not (placement and placement.instance and context) then return false end
  local actor = placement.actor
  local tint = context.tint or { 1, 1, 1 }
  local shadow
  if context.shadowMap and context.shadowVP then
    shadow = {
      map = context.shadowMap,
      viewProjection = context.shadowVP,
      darkness = context.shadowDark,
      bias = context.shadowBias,
      texel = context.shadowTexel,
    }
  end
  local called, ok, err = pcall(placement.instance.draw, placement.instance, {
    pass = pass,
    modelMatrix = placement.modelMatrix,
    camera = { view = context.view, viewProjection = context.viewProjection },
    light = context.light,
    shadow = shadow,
    tint = { tint[1] or 1, tint[2] or 1, tint[3] or 1, tint[4] or 1 },
    flashAmount = (context.flashing or (actor.flash or 0) > 0) and 0.5 or 0,
    flipWinding = true,
    disableCulling = true,
    skipHandlers = pass == "additive",
  })
  if not called then err, ok = ok, false end
  if not ok then
    warnOnce("draw:" .. placement.side,
      ("Stadium 2 %s model draw failed: %s; using Battle Art")
        :format(placement.side, tostring(err)))
    failActor(actor)
    report("draw-" .. tostring(placement.side) .. "-" .. tostring(pass),
      ("failed pass=%s error=%s"):format(tostring(pass), tostring(err)))
  else
    report("draw-" .. tostring(placement.side) .. "-" .. tostring(pass),
      ("ok pass=%s"):format(tostring(pass)))
  end
  return ok and true or false
end

-- Battle Art's caster matrix already maps depth to [0,1]; the Stadium API
-- accepts ordinary GL clip z, so undo that conversion at the boundary.
local FROM_UNIT_Z = { 1,0,0,0, 0,1,0,0, 0,0,2,-1, 0,0,0,1 }

function StadiumModels.drawShadow(placement, lightClipVP)
  if not (placement and placement.instance and lightClipVP) then return false end
  local called, ok, err = pcall(placement.instance.drawShadow,
    placement.instance, {
      modelMatrix = placement.modelMatrix,
      lightViewProjection = Mat4.mul(FROM_UNIT_Z, lightClipVP),
    })
  if not called then err, ok = ok, false end
  if not ok then
    warnOnce("shadow:" .. placement.side,
      ("Stadium 2 %s model shadow failed: %s; using card shadow")
        :format(placement.side, tostring(err)))
  end
  return ok and true or false
end

function StadiumModels.uses(placements, side)
  return type(placements) == "table" and placements[side] ~= nil
end

function StadiumModels.status()
  return {
    apiVersion = 1,
    installed = StadiumModels.installed(),
    active = StadiumModels.active(),
    providerId = providerHandle and "STADIUM2_IMPORTER" or nil,
    sides = {
      player = actors.player.instance and true or false,
      enemy = actors.enemy.instance and true or false,
    },
  }
end

return StadiumModels
