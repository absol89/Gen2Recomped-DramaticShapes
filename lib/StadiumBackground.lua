-- Public Stadium 2 scene bridge. Stadium owns battle lifetime, camera and
-- actor animation; Battle Art owns the selected background and UI treatment.
-- OFF is a single shared-depth voxel scene, while STADIUM2 uses the decoded
-- contextual arena. Missing/incompatible importer APIs always fall through.

local V = ...

local UiBackplates = V.require("UiBackplates")
local Images = V.require("BackdropImage")
local Voxel3D = V.require("Voxel3D")
local OverworldBattle = V.require("OverworldBattle")
local BattleArt = V.require("BattleArt")
local AnimatedBattleArt = V.require("AnimatedBattleArt")

local StadiumBackground = {}
local unpack = table.unpack or unpack
local installed, hostedBattle, trainerScreen = false, nil, nil
local legacy = { installed=false, current=nil, eventsInstalled=false }
local hostedDrawn = setmetatable({}, { __mode = "k" })
local hostedReported = setmetatable({}, { __mode = "k" })
local renderer, trainerMesh, trainerShader, catcherMesh, catcherShader

local function findMod(id)
  local find = V.mod and V.mod.find
  if type(find) ~= "function" then return nil end
  local ok, handle = pcall(find, id)
  if ok and handle then return handle end
  ok, handle = pcall(find, V.mod, id)
  return ok and handle or nil
end

local function rendererApi()
  if renderer == false then return nil end
  if renderer == nil then
    local ok, api = pcall(require, "mods.STADIUM2_IMPORTER.lib.renderer")
    renderer = ok and api or false
  end
  return renderer or nil
end

local function translate(x, y, z)
  return { 1,0,0,x, 0,1,0,y, 0,0,1,z, 0,0,0,1 }
end

local function scale(x, y, z)
  return { x,0,0,0, 0,y,0,0, 0,0,z,0, 0,0,0,1 }
end

local function rotateY(a)
  local c, s = math.cos(a), math.sin(a)
  return { c,0,s,0, 0,1,0,0, -s,0,c,0, 0,0,0,1 }
end

local TRAINER_SHADER = [[
#ifdef VERTEX
uniform mat4 mvp;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  return mvp * vertex_position;
}
#endif
#ifdef PIXEL
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  vec4 pixel = Texel(tex, tc) * color;
  if (pixel.a < 0.01) discard;
  return pixel;
}
#endif
]]

local CATCHER_SHADER = [[
varying vec3 vSun;
#ifdef VERTEX
uniform mat4 mvp;
uniform mat4 sunVP;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  vSun = (sunVP * vertex_position).xyz;
  return mvp * vertex_position;
}
#endif
#ifdef PIXEL
uniform Image sunMap;
uniform float sunDark;
uniform float sunBias;
uniform vec2 sunTexel;
float depthAt(vec2 uv) {
  vec4 c = Texel(sunMap, uv);
  return c.r + c.g / 255.0;
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  if (vSun.x < 0.0 || vSun.x > 1.0 || vSun.y < 0.0 || vSun.y > 1.0
      || vSun.z > 1.0) discard;
  float z = vSun.z - sunBias;
  float lit = step(z, depthAt(vSun.xy + sunTexel * vec2(-1.5, -0.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2( 0.5, -1.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2( 1.5,  0.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2(-0.5,  1.5)));
  float alpha = sunDark * (1.0 - lit * 0.25);
  if (alpha <= 0.005) discard;
  return vec4(0.015, 0.018, 0.025, alpha);
}
#endif
]]

local function trainerAssets(g)
  if trainerMesh == false or trainerShader == false then return false end
  if not trainerMesh then
    local format = {
      { "VertexPosition", "float", 3 },
      { "VertexTexCoord", "float", 2 },
    }
    local vertices = {
      { -.5,0,0, 0,1 }, { .5,0,0, 1,1 },
      { .5,1,0, 1,0 }, { -.5,1,0, 0,0 },
    }
    local ok, mesh = pcall(g.newMesh, format, vertices, "fan", "static")
    trainerMesh = ok and mesh or false
  end
  if not trainerShader then
    local ok, shader = pcall(g.newShader, TRAINER_SHADER)
    trainerShader = ok and shader or false
  end
  return trainerMesh and trainerShader and true or false
end

local function drawShadowCatcher(ctx)
  local g, camera, shadow = ctx and ctx.graphics, ctx and ctx.camera,
    ctx and ctx.shadow
  local vp = camera and (camera.vp or camera.viewProjection)
  if not (g and vp and shadow and shadow.map and shadow.sunVP) then return false end
  if catcherMesh == false or catcherShader == false then return false end
  if not catcherMesh then
    local format = {
      { "VertexPosition", "float", 3 },
      { "VertexTexCoord", "float", 2 },
    }
    local vertices = {
      { -64,-0.08,-64,0,0 }, { 64,-0.08,-64,1,0 },
      { 64,-0.08,64,1,1 }, { -64,-0.08,64,0,1 },
    }
    local ok, mesh = pcall(g.newMesh, format, vertices, "fan", "static")
    catcherMesh = ok and mesh or false
  end
  if not catcherShader then
    local ok, shader = pcall(g.newShader, CATCHER_SHADER)
    catcherShader = ok and shader or false
  end
  if not (catcherMesh and catcherShader) then return false end
  g.setShader(catcherShader)
  if g.setMeshCullMode then g.setMeshCullMode("none") end
  if g.setDepthMode then g.setDepthMode("lequal", false) end
  g.setBlendMode("alpha", "alphamultiply")
  g.setColor(1, 1, 1, 1)
  pcall(catcherShader.send, catcherShader, "mvp", "row", vp)
  pcall(catcherShader.send, catcherShader, "sunVP", "row", shadow.sunVP)
  pcall(catcherShader.send, catcherShader, "sunMap", shadow.map)
  pcall(catcherShader.send, catcherShader, "sunDark",
    tonumber(shadow.sunDark) or 0.55)
  pcall(catcherShader.send, catcherShader, "sunBias",
    tonumber(shadow.sunBias) or 0.003)
  pcall(catcherShader.send, catcherShader, "sunTexel",
    shadow.sunTexel or { 1 / 1024, 1 / 1024 })
  local ok = pcall(g.draw, catcherMesh)
  g.setShader()
  g.setColor(1, 1, 1, 1)
  return ok
end

local function drawTrainer(ctx, camera, origin, unitsPerTile, side,
                           worldFromStadium, worldScale)
  local g = ctx and ctx.graphics
  local host = ctx and ctx.scene and ctx.scene.host
  local screen = ctx and ctx.scene and ctx.scene.screen
  local api = rendererApi()
  local vp, eye = camera and (camera.vp or camera.viewProjection),
                  camera and camera.eye
  if not (g and host and screen and api and vp and eye and trainerAssets(g)) then
    return false
  end
  local tex = OverworldBattle.gen2TrainerTexture(screen, side)
    or OverworldBattle.sideTexture(screen, side)
  if not (tex and tex.trainer and tex.canvas) then return false end
  local p = host.actorPosition and host:actorPosition(side)
  local stage = host.Stage
  p = p or (stage and stage.positions and stage.positions[side])
  if not p then return false end
  origin = origin or { 0, 0, 0 }
  local x, y, z
  if worldFromStadium then
    local m = worldFromStadium
    x = m[1]*p[1] + m[2]*p[2] + m[3]*p[3] + m[4]
    y = m[5]*p[1] + m[6]*p[2] + m[7]*p[3] + m[8]
    z = m[9]*p[1] + m[10]*p[2] + m[11]*p[3] + m[12]
  else
    x, y, z = p[1] + origin[1], p[2] + origin[2], p[3] + origin[3]
  end
  local k = (tonumber(unitsPerTile) or 16)
    * (tonumber(worldScale) or 1) / 56
  local w, h = 160 * k, 144 * k
  local defaultAx = side == "player" and 40 or 124
  local defaultAy = side == "player" and 96 or 56
  local ox = -((tonumber(tex.ax) or defaultAx) / 160 - .5) * w
             + (tonumber(tex.worldSlide) or 0) * k
  local oy = -((144 - (tonumber(tex.ay) or defaultAy)) / 144) * h
  local yaw = math.atan2(eye[1] - x, eye[3] - z)
  local card = api.matMul(translate(ox, oy, 0), scale(w, h, 1))
  local model = api.matMul(api.matMul(translate(x, y, z), rotateY(yaw)), card)
  trainerMesh:setTexture(tex.canvas)
  tex.canvas:setFilter("nearest", "nearest")
  g.setShader(trainerShader)
  if g.setMeshCullMode then g.setMeshCullMode("none") end
  if g.setDepthMode then g.setDepthMode("lequal", true) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  g.setColor(1, 1, 1, 1)
  pcall(trainerShader.send, trainerShader, "mvp", "row", api.matMul(vp, model))
  local ok = pcall(g.draw, trainerMesh)
  g.setShader()
  return ok
end

local function trainerShowing(screen, side)
  if not screen then return false end
  if side == "enemy" then return screen.showEnemyTrainer and true or false end
  -- Importer 0.10.7 names this flag showPlayerTrainer; the unified
  -- Gen2Recomped BattleState retains Gen 1's showPlayerBack name.
  if screen.showPlayerTrainer or screen.showPlayerBack then return true end
  local frame = AnimatedBattleArt.playerTrainerFrame(screen)
  return frame ~= nil
end

local function pokemonReady(screen, side)
  if not screen then return false end
  if trainerShowing(screen, side) then return false end
  -- Unified Gen2Recomped exposes these send-out gates directly on BattleState.
  -- The party member already exists while its Pokeball animation is pending,
  -- but neither a Stadium model nor a fallback card should pre-empt it.
  if side == "player" and screen.sendingOut then return false end
  if side == "enemy" and screen.enemySendingOut then return false end
  -- 0.10.7 drops showEnemyTrainer just before the send event is armed. The
  -- mon already exists in battle data during that gap, but has not entered.
  if side == "enemy" and screen.battle and screen.battle.trainer
      and not screen.battle.wild and not screen.showEnemyHud then
    local sending = screen.afterSendOut
      and screen.afterSendOut.side == "enemy"
    if not sending then return false end
  end
  return true
end

local function hostedCovers(sceneCtx, side)
  local scene = sceneCtx and sceneCtx.scene
  local host, screen = scene and scene.host, scene and scene.screen
  if not (host and screen) then return false end
  -- Trainer art belongs to Battle Art's existing billboard capture. It is a
  -- world-space, depth-tested card and follows the unified intro/end states;
  -- the old importer's trainer seam targets a different screen structure.
  if trainerShowing(screen, side) then return false end
  -- An intentionally hidden Pokemon must not resurrect through fallback art.
  if not pokemonReady(screen, side) then return true end
  local prior = hostedDrawn[host]
  return prior and prior[side] == true or false
end

local function releaseHost()
  if hostedBattle then OverworldBattle.providerFinish() end
  if trainerScreen then
    pcall(AnimatedBattleArt.finish, trainerScreen.battle, trainerScreen)
  end
  hostedBattle = nil
  trainerScreen = nil
end

-- STADIUM2 is an authored contextual-arena choice, not an alias for the
-- importer's classic circle. If this encounter has no decoded arena, honor
-- the option contract by taking the same voxel provider path as OFF.
local function effectiveMode(ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode == "STADIUM2" then
    local host = ctx and ctx.scene and ctx.scene.host
    if not (host and host.arenaRenderer) then return "OFF" end
  end
  return mode
end

local function drawCircleStage(next, ctx)
  local amount = UiBackplates.stadiumCircleScale()
  if amount <= 0 then return ctx and ctx.marks end
  if amount >= 1 then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  local stage = host and host.Stage
  local radius = stage and stage.radius
  if type(radius) ~= "function" then return next(ctx) end
  stage.radius = function(actor) return radius(actor) * amount end
  local ok, a, b = pcall(next, ctx)
  stage.radius = radius
  if not ok then error(a, 0) end
  return a, b
end

local function bindTarget(g, target)
  if not (g and target and target.color) then return false end
  local binding = target.depth
    and { target.color, depthstencil = target.depth }
    or { target.color, depth = true }
  return pcall(g.setCanvas, binding)
end

local function drawCanvas(g, canvas, target)
  if not (canvas and canvas.getDimensions and bindTarget(g, target)) then
    return false
  end
  local ok, cw, ch = pcall(canvas.getDimensions, canvas)
  if not ok or not (cw and ch and cw > 0 and ch > 0) then return false end
  g.setShader()
  if g.setDepthMode then g.setDepthMode("always", false) end
  g.setBlendMode("alpha", "alphamultiply")
  g.setColor(1, 1, 1, 1)
  g.draw(canvas, 0, 0, 0, target.width / cw, target.height / ch)
  return true
end

local function drawHostedActors(sceneCtx, providerCtx)
  local host = sceneCtx and sceneCtx.scene and sceneCtx.scene.host
  local api = rendererApi()
  local origin = providerCtx and providerCtx.origin
  if not (host and api and origin and providerCtx.vp) then
    return { enemy = false, player = false }
  end
  -- Stadium's classic stage is authored on local Z, player at +24 and enemy
  -- at -24. Battle Art can stage a fight on any two walkable map cells, so a
  -- translation alone leaves models beside (or behind) their voxel slots.
  -- Build the similarity transform which maps those two authored marks onto
  -- the live arena marks. Models then occupy the same world coordinates and
  -- the same open depth target as the voxel terrain.
  local arena = OverworldBattle.arena and OverworldBattle.arena() or nil
  local player, enemy = arena and arena.player, arena and arena.enemy
  local worldFromStadium, stadiumFromWorld, worldScale
  if player and enemy then
    local dx, dz = player[1] - enemy[1], player[2] - enemy[2]
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance > 1e-6 then
      local k = distance / 48
      worldScale = k
      local fx, fz = dx / distance, dz / distance
      local rx, rz = fz, -fx
      worldFromStadium = {
        rx*k, 0, fx*k, origin[1],
        0, k, 0, origin[2],
        rz*k, 0, fz*k, origin[3],
        0, 0, 0, 1,
      }
      local ik = 1 / k
      stadiumFromWorld = {
        rx*ik, 0, rz*ik, -(rx*origin[1] + rz*origin[3])*ik,
        0, ik, 0, -origin[2]*ik,
        fx*ik, 0, fz*ik, -(fx*origin[1] + fz*origin[3])*ik,
        0, 0, 0, 1,
      }
    end
  end
  worldFromStadium = worldFromStadium
    or translate(origin[1], origin[2], origin[3])
  stadiumFromWorld = stadiumFromWorld
    or translate(-origin[1], -origin[2], -origin[3])
  local shadow = sceneCtx.shadow
  local sunVP = shadow and shadow.sunVP
    and api.matMul(shadow.sunVP, stadiumFromWorld) or nil
  local env = sceneCtx.environment or host.environment or {}
  local base = env.modelTint or { 1, 1, 1 }
  local drawn = { enemy = false, player = false }
  local report = hostedReported[host]
  if not report then report = {}; hostedReported[host] = report end
  for _, pass in ipairs({ "opaque", "additive" }) do
    for _, side in ipairs({ "enemy", "player" }) do
      -- A retained player-trainer exit frame still owns the world slot after
      -- showPlayerTrainer falls. Do not reveal the Pokemon underneath it; the
      -- host gets ownership back only after the trainer has slid away.
      local ready = pokemonReady(sceneCtx.scene.screen, side)
      local actor, actorState
      if ready and host.visualActor then
        local okActor, value, state = pcall(host.visualActor, host, side,
          sceneCtx.scene.screen)
        if okActor then actor, actorState = value, state
        elseif not report[side] then
          report[side] = true
          V.mod.log:warn("hosted Stadium %s actor failed: %s", side,
            tostring(value))
        end
      end
      if actor and actor.renderer and host.modelMatrix then
        local callOk, ok, drawErr = pcall(function()
          local localModel, yaw = host:modelMatrix(side, actor)
          local model = api.matMul(worldFromStadium, localModel)
          return actor.renderer:drawScene(pass, model, {
            viewProjection = providerCtx.vp, viewMatrix = providerCtx.view,
            normalMatrix = api.normalMatrix(yaw, 0, false),
            lightDir = env.light, ambient = env.ambient, diffuse = env.diffuse,
            modernLighting = false, flipWinding = true, disableCulling = true,
            tint = { base[1], base[2], base[3], 1 },
            flashAmount = actor.flash and actor.flash > 0 and .5 or 0,
            sunMap = shadow and shadow.map, sunVP = sunVP,
            sunDark = shadow and shadow.sunDark,
            sunBias = shadow and shadow.sunBias,
            sunTexel = shadow and shadow.sunTexel,
          })
        end)
        if not callOk then ok, drawErr = false, ok end
        if pass == "opaque" then drawn[side] = ok == true end
        if ok ~= true and not report[side] then
          report[side] = true
          V.mod.log:warn("hosted Stadium %s model draw failed: %s", side,
            tostring(drawErr))
        end
      elseif pass == "opaque" and ready and not report[side] then
        report[side] = true
        V.mod.log:warn("hosted Stadium %s model unavailable (state=%s)",
          side, tostring(actorState or "missing"))
      end
    end
  end
  hostedDrawn[host] = drawn
  return drawn
end

function StadiumBackground.background(next, ctx)
  local mode = effectiveMode(ctx)
  if mode == "OFF" or mode == "STADIUM2" then return next(ctx) end
  local g, target = ctx and ctx.graphics, ctx and ctx.target
  if not (g and target) then return next(ctx) end
  if mode == "WHITE" then
    g.clear(1, 1, 1, 1, true, true)
    return true
  end
  if mode == "PNG" then
    local image = Images.load("bosses", "arena.png")
    if image and image.getDimensions then
      local iw, ih = image:getDimensions()
      local x, y, k = Voxel3D.coverRect(iw, ih, target.width, target.height,
        UiBackplates.backdropOffsetPixels())
      if k then
        g.clear(0, 0, 0, 1, true, true)
        g.setDepthMode("always", false)
        g.setColor(1, 1, 1, 1)
        g.draw(image, x, y, 0, k, k)
        return true
      end
    end
  end
  return next(ctx)
end

function StadiumBackground.camera(next, ctx)
  local mode = effectiveMode(ctx)
  if mode ~= "OFF" and mode ~= "STADIUM2" then return next(ctx) end
  local host, target = ctx and ctx.scene and ctx.scene.host, ctx and ctx.target
  local screen = ctx and ctx.scene and ctx.scene.screen
  if screen then
    trainerScreen = screen
    pcall(AnimatedBattleArt.update, screen.battle, 0, screen)
    -- Static PLAYER ART is also stored on Gen 2's presentation state rather
    -- than on the logical battle. Animated mode applies this internally;
    -- static mode needs the same native surface claimed after old animation
    -- state has been restored.
    if BattleArt.setting:get() ~= "animated" then
      pcall(BattleArt.applyTrainers, screen)
    end
  end
  local camera = host and host.Camera
  local wantArena = mode == "STADIUM2"
  local wanted = wantArena and "arena" or "classic"
  if host and host.sceneMode ~= wanted and host.setSceneMode then
    host:setSceneMode(wanted)
  end
  if not (host and target and camera and camera.sceneFrame) then return next(ctx) end
  return camera.sceneFrame(target.logicalWidth or target.width,
    target.logicalHeight or target.height, {
      arena = wantArena, scale = host.arenaScale,
      groundY = host.arenaGroundY, actors = host.actors,
    })
end

function StadiumBackground.environment(next, ctx)
  local mode = effectiveMode(ctx)
  if mode ~= "OFF" then
    local battle = ctx and ctx.scene and ctx.scene.battle
    if mode == "STADIUM2" and battle then
      -- The importer draws the authored arena itself, but still claim the
      -- existing Battle Art session so its update loop does not build a
      -- second invisible standalone voxel frame every tick.
      if hostedBattle ~= battle then
        releaseHost()
        if OverworldBattle.providerBegin(battle) then hostedBattle = battle end
      end
    else
      releaseHost()
    end
    -- A decoded contextual arena is the selected fill, not a resizable
    -- classic circle. The circle row applies only to classic Stadium stages.
    if ctx and ctx.scene and ctx.scene.arena then return next(ctx) end
    local result = drawCircleStage(next, ctx)
    if UiBackplates.stadiumCircleScale() < 1 then drawShadowCatcher(ctx) end
    return result
  end
  local battle = ctx and ctx.scene and ctx.scene.battle
  local g, target = ctx and ctx.graphics, ctx and ctx.target
  if not (battle and g and target) then return drawCircleStage(next, ctx) end
  if hostedBattle ~= battle then
    releaseHost()
    if not OverworldBattle.providerBegin(battle) then
      return drawCircleStage(next, ctx)
    end
    hostedBattle = battle
  end
  local actors = {
    covers = function(side) return hostedCovers(ctx, side) end,
    draw = function(providerCtx)
      drawHostedActors(ctx, providerCtx)
      return true
    end,
  }
  local canvas = OverworldBattle.providerRender(battle, actors,
    ctx.camera, ctx.shadow)
  if not drawCanvas(g, canvas, target) then
    releaseHost()
    return drawCircleStage(next, ctx)
  end
  return drawCircleStage(next, ctx)
end

function StadiumBackground.battlers(next, ctx)
  local mode = effectiveMode(ctx)
  if mode ~= "OFF" and mode ~= "STADIUM2" then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  if not host then return next(ctx) end
  if ctx.battlerPhase == "prepare" then
    hostedDrawn[host] = { enemy = false, player = false }
    if mode == "OFF" then
      return { sides = { enemy = "provider", player = "provider" } }
    end
    local screen = ctx.scene.screen
    return { sides = {
      enemy = trainerShowing(screen, "enemy") and "provider" or "host",
      player = trainerShowing(screen, "player") and "provider" or "host",
    } }
  end
  if ctx.battlerPhase == "draw" then
    if mode == "OFF" then
      return { drawn = hostedDrawn[host]
        or { enemy = false, player = false } }
    end
    local units = ctx.world and ctx.world.unitsPerTile
    return { drawn = {
      enemy = drawTrainer(ctx, ctx.camera, { 0, 0, 0 }, units, "enemy"),
      player = drawTrainer(ctx, ctx.camera, { 0, 0, 0 }, units, "player"),
    } }
  end
  return next(ctx)
end

function StadiumBackground.shadow(next, ctx)
  if effectiveMode(ctx) ~= "OFF" then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  local lightVP = ctx and ctx.shadow and ctx.shadow.viewProjection
  if host and lightVP then
    for _, side in ipairs({ "enemy", "player" }) do
      local actor = host.visualActor and host:visualActor(side)
      if actor and actor.renderer and host.modelMatrix then
        actor.renderer:drawShadowMap(host:modelMatrix(side, actor), lightVP)
      end
    end
  end
  return next(ctx)
end

local function updateLegacyTrainerArt(screen)
  if not screen then return end
  trainerScreen = screen
  pcall(AnimatedBattleArt.update, screen.battle, 0, screen)
  if BattleArt.setting:get() ~= "animated" then
    pcall(BattleArt.applyTrainers, screen)
  end
end

local function legacyFrame(scene, width, height)
  local Camera, Shadow, Sky = legacy.Camera, legacy.Shadow, legacy.Sky
  if not (scene and Camera and Shadow and Sky) then return nil end
  scene.environment = Sky.resolve(
    scene.environmentGame and scene:environmentGame() or nil)
  local frame = Camera.frame(width, height)
  local env = scene.environment or {}
  local lightVP = Shadow.begin(env.light, env.shadowStrength)
  if lightVP then
    for _, side in ipairs({ "enemy", "player" }) do
      local actor = pokemonReady(scene.screen, side)
        and scene.visualActor and scene:visualActor(side) or nil
      if actor and actor.renderer and scene.modelMatrix then
        actor.renderer:drawShadowMap(scene:modelMatrix(side, actor), lightVP)
      end
    end
  end
  local shadow = lightVP and Shadow.finish() or nil
  return frame, shadow
end

local function legacyProviderRender(scene, width, height)
  updateLegacyTrainerArt(scene and scene.screen)
  local frame, shadow = legacyFrame(scene, width, height)
  if not frame then return false end
  if hostedBattle ~= scene.battle then
    releaseHost()
    if not OverworldBattle.providerBegin(scene.battle) then return false end
    hostedBattle = scene.battle
  end
  local sceneCtx = {
    graphics = love.graphics,
    shadow = shadow,
    environment = scene.environment,
    scene = { host=scene, screen=scene.screen, battle=scene.battle },
  }
  -- Importer 0.10.7's Gen2 scene is retained for lifecycle/HUD compatibility,
  -- but its pre-unification actor ownership is not used in a voxel arena.
  -- BattleScene's StadiumModels adapter owns the same exported renderers
  -- directly, which guarantees they share Battle Art's camera and depth target.
  local actors = nil
  -- OFF is Battle Art's voxel battlefield, so its own steerable BattleCam
  -- must build the view. The old importer camera remains the owner only for
  -- ARENA FILL: STADIUM2. Its sun map is camera-independent and can still be
  -- shared with the models here.
  local canvas, shot = OverworldBattle.providerRender(scene.battle, actors,
    nil, shadow, scene.screen)
  if not (canvas and shot) then return false end
  scene.width, scene.height = width, height
  scene.presentCanvas = canvas
  scene.hudBox = {
    lx=shot.lx, ly=shot.ly, scale=shot.scale, pw=shot.pw, ph=shot.ph,
  }
  scene.uiAnchors = { player=shot.player, enemy=shot.enemy }
  scene.readyFrame, scene.defect = true, nil
  return true
end

local function drawLegacyTrainers(scene, width, height)
  if not (scene and scene.canvas and love and love.graphics) then return end
  updateLegacyTrainerArt(scene.screen)
  local Camera = legacy.Camera
  local frame = Camera and Camera.frame(width, height)
  if not frame then return end
  local g = love.graphics
  local previous = g.getCanvas and { g.getCanvas() } or nil
  local target = scene.depth
    and { scene.canvas, depthstencil=scene.depth } or scene.canvas
  local ok = pcall(function()
    g.setCanvas(target)
    local ctx = {
      graphics=g, camera=frame, environment=scene.environment,
      scene={host=scene,screen=scene.screen,battle=scene.battle},
    }
    for _, side in ipairs({ "enemy", "player" }) do
      drawTrainer(ctx, frame, { 0, 0, 0 }, 16, side)
    end
  end)
  if previous and #previous > 0 then pcall(g.setCanvas, unpack(previous))
  else pcall(g.setCanvas) end
  if not ok then return end
  local _, _, pixelWidth, pixelHeight = legacy.Scene.surfaceDimensions(
    g, width, height)
  scene.presentCanvas = legacy.AA.resolve(scene.canvas,
    pixelWidth, pixelHeight)
  if legacy.Hud and legacy.Hud.build then
    pcall(legacy.Hud.build, scene.presentCanvas)
  end
end

local function installLegacy(handle)
  if legacy.installed then installed = true; return true end
  local exports = handle and handle.exports
  if not (exports and exports.presentation) then return false end
  local okGen2, Gen2 = pcall(require,
    "mods.STADIUM2_IMPORTER.lib.gen2_battle")
  local okCamera, Camera = pcall(require,
    "mods.STADIUM2_IMPORTER.lib.battle_camera")
  local okShadow, Shadow = pcall(require,
    "mods.STADIUM2_IMPORTER.lib.battle_shadow")
  local okSky, Sky = pcall(require,
    "mods.STADIUM2_IMPORTER.lib.battle_sky")
  local okHud, Hud = pcall(require,
    "mods.STADIUM2_IMPORTER.lib.battle_hud")
  local okAA, AA = pcall(require,
    "mods.STADIUM2_IMPORTER.lib.battle_aa")
  local Scene = okGen2 and Gen2 and Gen2.Scene
  if not (Scene and okCamera and okShadow and okSky and okHud and okAA) then
    return false
  end
  legacy.Gen2, legacy.Scene, legacy.Camera = Gen2, Scene, Camera
  legacy.Shadow, legacy.Sky, legacy.Hud, legacy.AA = Shadow, Sky, Hud, AA

  local nativeNew, nativeRelease = Scene.new, Scene.release
  local nativeShownMon = Scene.shownMon
  local nativeRender, nativeVisualState = Scene.render, Scene.visualState
  function Scene.new(...)
    local value = nativeNew(...)
    legacy.current = value
    return value
  end
  function Scene:release(...)
    if legacy.current == self then legacy.current = nil end
    if hostedBattle == self.battle then releaseHost() end
    return nativeRelease(self, ...)
  end
  if type(nativeShownMon) == "function" then
    function Scene:shownMon(side)
      local mon = nativeShownMon(self, side)
      -- Unified BattleState sides are Battlers ({ mon = <Gen2 record> });
      -- importer 0.10.7 predates that wrapper and its dex/shiny loader expects
      -- the raw record. The older native Gen2 screen already returns it raw.
      return type(mon) == "table" and type(mon.mon) == "table" and mon.mon
        or mon
    end
  end
  function Scene:visualState(side, screen)
    screen = screen or self.screen
    if trainerShowing(screen, side) then return "trainer" end
    if not pokemonReady(screen, side) then return "empty" end
    return nativeVisualState(self, side, screen)
  end
  function Scene:render(width, height)
    legacy.current = self
    -- Importer 0.10.7 advances its scene from the always-on battle clock
    -- before drawWidescreen supplies an explicit surface size. Its native
    -- renderer resolves that omission internally, but the Battle Art provider
    -- path needs the resolved dimensions before it builds the shared camera.
    -- Normalize both paths here so Camera.frame never receives a nil height.
    if not (tonumber(width) and tonumber(height)) then
      local g = love and love.graphics
      local resolvedW, resolvedH = Scene.surfaceDimensions(g, width, height)
      width, height = resolvedW, resolvedH
    end
    local mode = UiBackplates.arenaFill:get()
    if mode ~= "STADIUM2" and legacyProviderRender(self, width, height) then
      return true
    end
    if hostedBattle == self.battle then releaseHost() end
    local result = nativeRender(self, width, height)
    if result then drawLegacyTrainers(self, width, height) end
    return result
  end

  local Stage = Scene.Stage
  if Stage and not Stage.battleArtLegacyCircle then
    local nativeRadius, nativeDraw = Stage.radius, Stage.draw
    function Stage.radius(actor)
      local radius = nativeRadius(actor)
      if UiBackplates.arenaFill:get() == "STADIUM2" then
        radius = radius * UiBackplates.stadiumCircleScale()
      end
      return radius
    end
    function Stage.draw(g, width, height, frame, actors, shadow, environment)
      local marks, err = nativeDraw(g, width, height, frame, actors,
        shadow, environment)
      if UiBackplates.arenaFill:get() == "STADIUM2"
          and UiBackplates.stadiumCircleScale() < 1 then
        drawShadowCatcher({graphics=g,camera=frame,shadow=shadow})
      end
      return marks, err
    end
    Stage.battleArtLegacyCircle = true
  end

  legacy.installed, installed = true, true
  -- Importer 0.10.7 installs against the pre-unification Gen 2 screen seam.
  -- Gen2Recomped now emits the same battle.started event with the underlying
  -- Gen 2 battle owner, but the compatibility screen wrapper can reach its
  -- first voxel draw without the importer's listener having made a session.
  -- Explicitly request that same public Gen2 provider here. ensure() samples
  -- MODELS, BATTLES and cache availability itself, so this cannot turn models
  -- on behind the user's settings; it only guarantees that an enabled provider
  -- has a scene for Battle Art to host.
  if not legacy.eventsInstalled and V.mod.events and V.mod.events.on then
    V.mod.events:on("battle.started", function(payload)
      local battle = payload and payload.battle
      -- A unified presentation BattleState wraps the actual Gen2 rules battle
      -- in .battle. Importer 0.10.7's active(screen) contract specifically
      -- compares its session with screen.battle, so always key its scene to
      -- that underlying owner when one is present.
      if type(battle) == "table" and type(battle.battle) == "table" then
        battle = battle.battle
      end
      local ok, active = pcall(Gen2.ensure, battle)
      if not (ok and active) then
        local statusOk, status = pcall(Gen2.status)
        local reason = statusOk and status and status.defect or nil
        V.mod.log:warn("Stadium 2 Gen2 scene unavailable: %s",
          tostring(reason or (ok and "disabled/not ready" or active)))
      end
    end)
    legacy.eventsInstalled = true
  end
  return true
end

function StadiumBackground.legacyScene(screen)
  local scene = legacy.current
  if not (legacy.installed and scene and not scene.defect) then
    return nil
  end
  -- Let the Battle Art compositor perform the first attachment. The importer
  -- can create its scene from battle.started before its old drawWidescreen
  -- wrapper sees the unified screen, leaving scene.screen nil on frame one.
  if screen and scene.screen and scene.screen ~= screen then return nil end
  if screen and scene.battle and scene.battle ~= screen
      and scene.battle ~= screen.battle then return nil end
  return scene
end

function StadiumBackground.legacyInstalled()
  return legacy.installed
end

function StadiumBackground.install()
  if installed then return true end
  local handle = findMod("STADIUM2_IMPORTER")
  local scene = handle and handle.exports and handle.exports.scene
  if not (scene and tonumber(scene.VERSION or scene.apiVersion) == 1
      and type(scene.register) == "function") then
    return installLegacy(handle)
  end
  local ok = true
  for phase, callback in pairs({
      background = StadiumBackground.background,
      environment = StadiumBackground.environment,
      camera = StadiumBackground.camera,
      battlers = StadiumBackground.battlers,
      shadow = StadiumBackground.shadow,
    }) do
    ok = pcall(scene.register, V.mod, phase, callback, 100) and ok
  end
  installed = ok
  if installed and V.mod.events and V.mod.events.on then
    V.mod.events:on("battle.ended", releaseHost)
  end
  return installed
end

function StadiumBackground.installed()
  return installed
end

return StadiumBackground
