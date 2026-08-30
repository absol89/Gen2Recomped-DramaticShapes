-- Battle Art environment provider for Stadium 2 Importer's owned scene.
-- Stadium keeps its camera, models and native animation projection; Battle
-- Art replaces only the public background/environment phase.

local V = ...

local UiBackplates = V.require("UiBackplates")
local Images = V.require("BackdropImage")
local Voxel3D = V.require("Voxel3D")
local OverworldBattle = V.require("OverworldBattle")

local StadiumBackground = {}
local installed = false
local hostedBattle
local hostedDrawn = setmetatable({}, { __mode = "k" })
local catcherMesh
local catcherShader
local trainerMesh
local trainerShader
local StadiumRenderer

local function rendererApi()
  if StadiumRenderer == false then return nil end
  if not StadiumRenderer then
    local ok, renderer = pcall(require,
      "mods.STADIUM2_IMPORTER.lib.renderer")
    StadiumRenderer = ok and renderer or false
  end
  return StadiumRenderer or nil
end

local function translate(x, y, z)
  return {
    1, 0, 0, x,
    0, 1, 0, y,
    0, 0, 1, z,
    0, 0, 0, 1,
  }
end

local function scale(x, y, z)
  return { x,0,0,0, 0,y,0,0, 0,0,z,0, 0,0,0,1 }
end

local function rotateY(angle)
  local c, s = math.cos(angle), math.sin(angle)
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

local function trainerAssets(g)
  if trainerMesh == false or trainerShader == false then return nil end
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
  return trainerMesh and trainerShader and true or nil
end

local function drawTrainerCard(sceneCtx, camera, origin, unitsPerTile, side)
  side = side == "player" and "player" or "enemy"
  local g = sceneCtx and sceneCtx.graphics
  local host = sceneCtx and sceneCtx.scene and sceneCtx.scene.host
  local screen = sceneCtx and sceneCtx.scene and sceneCtx.scene.screen
  local renderer = rendererApi()
  local vp = camera and (camera.vp or camera.viewProjection)
  local eye = camera and camera.eye
  if not (g and host and screen and renderer
      and vp and eye and trainerAssets(g)
      and type(OverworldBattle.sideTexture) == "function") then return false end
  local tex = OverworldBattle.sideTexture(screen, side)
  if not (tex and tex.trainer and tex.canvas) then return false end
  local p = host.actorPosition and host:actorPosition(side)
  if not p then return false end
  origin = origin or { 0, 0, 0 }
  local x, y, z = p[1] + origin[1], p[2] + origin[2], p[3] + origin[3]
  local k = (tonumber(unitsPerTile) or 16) / 56
  local w, h = 160 * k, 144 * k
  local defaultAx = side == "player" and 40 or 124
  local defaultAy = side == "player" and 96 or 56
  local ox = -((tonumber(tex.ax) or defaultAx) / 160 - .5) * w
  ox = ox + (tonumber(tex.worldSlide) or 0) * k
  local oy = -((144 - (tonumber(tex.ay) or defaultAy)) / 144) * h
  local yaw = math.atan2(eye[1] - x, eye[3] - z)
  local card = renderer.matMul(translate(ox, oy, 0), scale(w, h, 1))
  local model = renderer.matMul(renderer.matMul(translate(x, y, z),
    rotateY(yaw)), card)
  if trainerMesh.setTexture then
    pcall(trainerMesh.setTexture, trainerMesh, tex.canvas)
  end
  if tex.canvas.setFilter then
    pcall(tex.canvas.setFilter, tex.canvas, "nearest", "nearest")
  end
  g.setShader(trainerShader)
  if g.setMeshCullMode then g.setMeshCullMode("none") end
  if g.setDepthMode then g.setDepthMode("lequal", true) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  g.setColor(1, 1, 1, 1)
  pcall(trainerShader.send, trainerShader, "mvp", "row",
    renderer.matMul(vp, model))
  local ok = pcall(g.draw, trainerMesh)
  g.setShader()
  return ok
end

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

local function shadowCatcherAssets(g)
  if catcherMesh == false or catcherShader == false then return nil end
  if not catcherMesh then
    local format = {
      { "VertexPosition", "float", 3 },
      { "VertexTexCoord", "float", 2 },
    }
    local vertices = {
      { -64, -0.08, -64, 0, 0 }, { 64, -0.08, -64, 1, 0 },
      { 64, -0.08, 64, 1, 1 }, { -64, -0.08, 64, 0, 1 },
    }
    local ok, mesh = pcall(g.newMesh, format, vertices, "fan", "static")
    catcherMesh = ok and mesh or false
  end
  if not catcherShader then
    local ok, shader = pcall(g.newShader, CATCHER_SHADER)
    catcherShader = ok and shader or false
  end
  return catcherMesh and catcherShader and true or nil
end

local function drawShadowCatcher(ctx)
  local g, camera, shadow = ctx and ctx.graphics, ctx and ctx.camera,
    ctx and ctx.shadow
  local vp = camera and (camera.vp or camera.viewProjection)
  if not (g and vp and shadow and shadow.map and shadow.sunVP
      and shadowCatcherAssets(g)) then return false end
  g.setShader(catcherShader)
  if g.setMeshCullMode then g.setMeshCullMode("none") end
  if g.setDepthMode then g.setDepthMode("lequal", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
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
  if g.setDepthMode then g.setDepthMode() end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  return ok
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

local function drawImage(g, image, width, height)
  if not (image and image.getDimensions) then return false end
  local ok, iw, ih = pcall(image.getDimensions, image)
  if not ok then return false end
  local x, y, scale = Voxel3D.coverRect(iw, ih, width, height,
    UiBackplates.backdropOffsetPixels())
  if not scale then return false end
  g.setDepthMode("always", false)
  g.setColor(1, 1, 1, 1)
  g.draw(image, x, y, 0, scale, scale)
  return true
end

function StadiumBackground.draw(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode == "OFF" or mode == "STADIUM2" then return next(ctx) end
  local g, target = ctx and ctx.graphics, ctx and ctx.target
  if not (g and target) then return next(ctx) end
  if mode == "WHITE" then
    g.clear(1, 1, 1, 1, true, true)
    return true
  end
  if mode == "PNG" then
    local image = Images.load("bosses", "arena.png")
    g.clear(0, 0, 0, 1, true, true)
    if drawImage(g, image, target.width, target.height) then return true end
  end
  return next(ctx)
end

local function releaseVoxelHost()
  if not hostedBattle then return end
  OverworldBattle.providerFinish()
  hostedBattle = nil
end

local function bindTarget(g, target)
  if not (g and g.setCanvas and target and target.color) then return true end
  local binding = target.depth
    and { target.color, depthstencil = target.depth }
    or { target.color, depth = true }
  return pcall(g.setCanvas, binding)
end

local function drawCanvas(g, canvas, target)
  if not (canvas and canvas.getDimensions and g and g.draw) then return false end
  local ok, cw, ch = pcall(canvas.getDimensions, canvas)
  if not ok or not (cw and ch and cw > 0 and ch > 0) then return false end
  if not bindTarget(g, target) then return false end
  g.setShader()
  if g.setDepthMode then g.setDepthMode("always", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  g.setColor(1, 1, 1, 1)
  g.draw(canvas, 0, 0, 0, target.width / cw, target.height / ch)
  return true
end

local function drawCircleStage(next, ctx)
  local scale = UiBackplates.stadiumCircleScale()
  if scale <= 0 then return ctx and ctx.marks or next(ctx) end
  if scale >= 1 then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  local stage = host and host.Stage
  local radius = stage and stage.radius
  if type(radius) ~= "function" then return next(ctx) end
  stage.radius = function(actor) return radius(actor) * scale end
  local ok, a, b = pcall(next, ctx)
  stage.radius = radius
  if not ok then error(a, 0) end
  return a, b
end

local function drawHostedActors(sceneCtx, providerCtx)
  local host = sceneCtx and sceneCtx.scene and sceneCtx.scene.host
  local renderer = rendererApi()
  local origin = providerCtx and providerCtx.origin
  if not (host and renderer and origin and providerCtx.vp) then
    return { enemy = false, player = false }
  end
  local worldFromStadium = translate(origin[1], origin[2], origin[3])
  local stadiumFromWorld = translate(-origin[1], -origin[2], -origin[3])
  local shadow = sceneCtx.shadow
  local sunVP = shadow and shadow.sunVP
    and renderer.matMul(shadow.sunVP, stadiumFromWorld) or nil
  local environment = sceneCtx.environment or host.environment or {}
  local base = environment.modelTint or { 1, 1, 1 }
  local drawn = { enemy = false, player = false }
  for _, pass in ipairs({ "opaque", "additive" }) do
    for _, side in ipairs({ "enemy", "player" }) do
      local actor = host.visualActor and host:visualActor(side)
      if actor and actor.renderer and host.modelMatrix then
        local localModel, yaw = host:modelMatrix(side, actor)
        local model = renderer.matMul(worldFromStadium, localModel)
        local ok = actor.renderer:drawScene(pass, model, {
          viewProjection = providerCtx.vp,
          viewMatrix = providerCtx.view,
          normalMatrix = renderer.normalMatrix(yaw, 0, false),
          lightDir = environment.light,
          ambient = environment.ambient,
          diffuse = environment.diffuse,
          modernLighting = false,
          flipWinding = true,
          disableCulling = true,
          tint = { base[1], base[2], base[3], 1 },
          flashAmount = actor.flash and actor.flash > 0 and .5 or 0,
          sunMap = shadow and shadow.map,
          sunVP = sunVP,
          sunDark = shadow and shadow.sunDark,
          sunBias = shadow and shadow.sunBias,
          sunTexel = shadow and shadow.sunTexel,
        })
        if pass == "opaque" then drawn[side] = ok == true end
      end
    end
  end
  hostedDrawn[host] = drawn
  for _, side in ipairs({ "enemy", "player" }) do
    if drawTrainerCard(sceneCtx, {
        vp = providerCtx.vp, eye = providerCtx.eye,
      }, origin, 16, side) then
      drawn[side] = true
    end
  end
  return drawn
end

local function stadiumActorPasses(sceneCtx)
  return {
    draw = function(providerCtx)
      drawHostedActors(sceneCtx, providerCtx)
      return true
    end,
  }
end

-- OFF is a single mixed 3-D scene: Stadium's actors are submitted while the
-- Battle Art voxel depth attachment is live.  The later battler hook reports
-- that ownership back to Stadium so it does not paint the same models again
-- after the voxel canvas has been flattened.
function StadiumBackground.battlers(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode ~= "OFF" and mode ~= "STADIUM2" then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  if not host then return next(ctx) end
  if ctx.battlerPhase == "prepare" then
    hostedDrawn[host] = { enemy = false, player = false }
    if mode == "OFF" then
      return { sides = { enemy = "provider", player = "provider" } }
    end
    local screen = ctx.scene.screen
    local enemyMode = screen and screen.showEnemyTrainer
      and "provider" or "host"
    local playerMode = screen and screen.showPlayerTrainer
      and "provider" or "host"
    if enemyMode == "provider" or playerMode == "provider" then
      return { sides = { enemy = enemyMode, player = playerMode } }
    end
    return next(ctx)
  end
  if ctx.battlerPhase == "draw" then
    if mode == "STADIUM2" then
      local enemy = drawTrainerCard(ctx, ctx.camera, { 0, 0, 0 },
        ctx.world and ctx.world.unitsPerTile, "enemy")
      local player = drawTrainerCard(ctx, ctx.camera, { 0, 0, 0 },
        ctx.world and ctx.world.unitsPerTile, "player")
      return { drawn = { enemy = enemy, player = player } }
    end
    return { drawn = hostedDrawn[host]
      or { enemy = false, player = false } }
  end
  return next(ctx)
end

-- Provider battlers still cast into Stadium's public sun map.  The completed
-- map is then consumed by both the voxel ground and the hosted model pass.
function StadiumBackground.shadow(next, ctx)
  if UiBackplates.arenaFill:get() ~= "OFF" then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  local lightVP = ctx and ctx.shadow and ctx.shadow.viewProjection
  if not (host and lightVP) then return next(ctx) end
  for _, side in ipairs({ "enemy", "player" }) do
    local actor = host.visualActor and host:visualActor(side)
    if actor and actor.renderer and host.modelMatrix then
      local model = host:modelMatrix(side, actor)
      actor.renderer:drawShadowMap(model, lightVP)
    end
  end
  return next(ctx)
end

-- Context arenas change more than the environment mesh: they select Stadium
-- source-space actor slots and an authored field camera before the environment
-- hook runs. OFF must switch the owned scene back to its classic composition
-- during camera selection, otherwise the environment fallback below is the
-- complete decoded field and paints it over the voxel canvas. STADIUM2
-- restores arena composition when a decoded contextual field is available.
function StadiumBackground.camera(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode ~= "OFF" and mode ~= "STADIUM2" then return next(ctx) end
  local host = ctx and ctx.scene and ctx.scene.host
  local target = ctx and ctx.target
  local camera = host and host.Camera
  local wantArena = mode == "STADIUM2" and host and host.arenaRenderer ~= nil
  local wanted = wantArena and "arena" or "classic"
  if host and host.sceneMode ~= wanted and type(host.setSceneMode) == "function" then
    host:setSceneMode(wanted)
  end
  if not (host and target and camera and type(camera.sceneFrame) == "function") then
    return next(ctx)
  end
  return camera.sceneFrame(target.logicalWidth or target.width,
    target.logicalHeight or target.height, {
      arena = wantArena,
      scale = host.arenaScale,
      groundY = host.arenaGroundY,
      actors = host.actors,
    })
end

function StadiumBackground.environment(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode ~= "OFF" then
    releaseVoxelHost()
    -- A contextual Stadium arena is the selected ARENA FILL itself, not a
    -- classic ground circle. STADIUM CIRCLE must never suppress or resize the
    -- decoded field; it applies only when the importer is in classic mode.
    if ctx and ctx.scene and ctx.scene.arena then return next(ctx) end
    local result = drawCircleStage(next, ctx)
    if UiBackplates.stadiumCircleScale() < 1 then drawShadowCatcher(ctx) end
    return result
  end
  local battle = ctx and ctx.scene and ctx.scene.battle
  local g, target = ctx and ctx.graphics, ctx and ctx.target
  if not (battle and g and target) then return drawCircleStage(next, ctx) end
  if hostedBattle ~= battle then
    releaseVoxelHost()
    if not OverworldBattle.providerBegin(battle) then
      return drawCircleStage(next, ctx)
    end
    hostedBattle = battle
  end
  local canvas = OverworldBattle.providerRender(battle,
    stadiumActorPasses(ctx), ctx.camera, ctx.shadow)
  if not drawCanvas(g, canvas, target) then
    releaseVoxelHost()
    return drawCircleStage(next, ctx)
  end
  return drawCircleStage(next, ctx)
end

function StadiumBackground.install()
  if installed then return true end
  local handle = findMod("STADIUM2_IMPORTER")
  local scene = handle and handle.exports and handle.exports.scene
  if not (scene and tonumber(scene.VERSION or scene.apiVersion) == 1
      and type(scene.register) == "function") then return false end
  local okBackground = pcall(scene.register, V.mod, "background",
    StadiumBackground.draw, 100)
  local okEnvironment = pcall(scene.register, V.mod, "environment",
    StadiumBackground.environment, 100)
  local okCamera = pcall(scene.register, V.mod, "camera",
    StadiumBackground.camera, 100)
  local okBattlers = pcall(scene.register, V.mod, "battlers",
    StadiumBackground.battlers, 100)
  local okShadow = pcall(scene.register, V.mod, "shadow",
    StadiumBackground.shadow, 100)
  installed = okBackground and okEnvironment and okCamera
    and okBattlers and okShadow
  if installed and V.mod.events and type(V.mod.events.on) == "function" then
    V.mod.events:on("battle.ended", releaseVoxelHost)
  end
  return installed
end

function StadiumBackground.installed()
  return installed
end

return StadiumBackground
