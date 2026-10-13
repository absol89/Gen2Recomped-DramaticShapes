return function(game)
  local dir = assert(os.getenv("PROBE_DIR"))
  local version = assert(os.getenv("POKEPORT_VERSION"))
  local GV = require("src.core.GameVersion")
  assert(GV.get() == version and GV.generation() == 2)
  assert(love.filesystem.getIdentity():match("^transition%-budget%-probe"),
    "Use a disposable transition-budget-probe identity")
  local output = assert(io.open(dir .. "/measurements.log", "w"))
  local function log(s) output:write(s .. "\n"); output:flush(); print(s) end
  log("saveDir=" .. love.filesystem.getSaveDirectory())
  log("source=" .. love.filesystem.getSource() .. " version=" .. version)
  local handle = assert(game.mods.exports.BATTLE_ART_VOXEL_GEN2, "mod not loaded")
  local V = handle.lib
  local M, B = V.require("ChunkMesher"), V.require("BuildBudget")
  local A, R = V.require("Gen2WorldAdapter"), V.require("RenderDistance")
  local world = assert(game.world)
  local Disk = V.require("VoxelMeshDisk")
  log("cacheBound="..tostring(Disk.bind(game, false)))
  Disk.beginSession()
  local clock = love.timer.getTime
  local pumpMax, overruns, pumps, coveredPumps = 0, 0, 0, 0
  local budget
  local currentCo
  local spikeLog = assert(io.open(dir .. "/pump-spikes.log", "w"))
  local begin = B.begin
  B.begin = function(co, seconds)
    if budget == nil then budget = seconds end
    currentCo = co
    return begin(co, seconds)
  end
  local pump = M.pump
  M.pump = function(covered)
    budget = nil
    local start = clock()
    local result = pump(covered)
    local elapsed = clock() - start
    if budget then
      pumps = pumps + 1
      if covered then coveredPumps = coveredPumps + 1 end
      pumpMax = math.max(pumpMax, elapsed * 1000)
      if elapsed > budget + .001 then
        overruns = overruns + 1
        spikeLog:write(("map=%s pending=%d budget=%.2fms elapsed=%.2fms\n")
          :format(world.map.id,M.pending(),budget*1000,elapsed*1000))
        spikeLog:write(debug.traceback(currentCo) .. "\n"); spikeLog:flush()
      end
    end
    return result
  end
  local Perf = V.require("Perf"); Perf.enabled = true
  local profiler = require("src.core.FrameProfiler")
  profiler.context = function()
    return world.map.id .. " neighbors=" .. #(world.neighbors or {}) .. " pending=" .. M.pending()
  end
  profiler.out = function(text) log(text) end
  local flagOK, flagError = love.filesystem.write("resource-monitor.flag", "enabled")
  log("monitorFlag="..tostring(flagOK).." error="..tostring(flagError).." info="..tostring(love.filesystem.getInfo("resource-monitor.flag")))
  local monitorPath = os.getenv("PROBE_RESOURCE_MODULE")
  local okMonitor, monitor = pcall(function()
    if monitorPath then return dofile(monitorPath) end
    return require("src.debug.ResourceMonitor")
  end)
  if not okMonitor then monitor = {frame=function() end,flush=function() end} end
  local draw = love.draw
  love.draw = function()
    draw(); Perf.frame(); Perf.drawStats(); monitor.frame(game)
  end
  local function wait(n) for _ = 1,n do coroutine.yield() end end
  local P = require("src.render.Pipelines")
  local camera
  for i=0,P.maxLevel("voxel") do if P.levelLabel("voxel",i)=="35" then camera=i end end
  assert(camera)
  game.options.pipelines = game.options.pipelines or {}
  game.options.pipelines.voxel = camera; game.options.pipelines.tiltshift = 0
  P.setLevel("voxel",camera); P.setLevel("tiltshift",0)
  if os.getenv("PROBE_ZOOM") == "wide" then
    local Zoom = require("src.render.Zoom")
    Zoom.offset = 1 - world:fitScale()
    log("stressZoomScale="..tostring(world:zoomScale()))
  end
  -- Compare the worst supported neighborhood rather than hiding it with distance.
  R.setting:sync(false)
  local World = require("src.world.gen2.World")
  local Map = require("src.world.gen2.Map")
  local ranked = {}
  for id,def in pairs(world.maps) do
    if id:find("CITY") or id:find("TOWN") then
      local neighbors = World.computeNeighbors(world.maps,id,2,1024,768)
      ranked[#ranked+1] = {id=id,n=#neighbors}
    end
  end
  table.sort(ranked,function(a,b) if a.n==b.n then return a.id<b.id end return a.n>b.n end)
  for i=1,math.min(12,#ranked) do log("rank " .. ranked[i].id .. " neighbors=" .. ranked[i].n) end
  local directions={north="up",south="down",west="left",east="right"}
  local root, direction, x, y, destination
  for _,candidate in ipairs(ranked) do
    local def=world.maps[candidate.id]
    assert(world:setMap(candidate.id,math.floor(def.width),math.floor(def.height),"down"))
    for _,key in ipairs({"east","west","north","south"}) do
      local dirKey=directions[key]
      local conn=world.map:connection(key)
      if conn and conn.mapId and world.maps[conn.mapId] then
        local dest=world:connectionMap(conn.mapId)
        local width,height=world.map.widthCells,world.map.heightCells
        for i=0,(key=="north" or key=="south") and width-1 or height-1 do
          local cx=(key=="west" and 0 or key=="east" and width-1 or i)
          local cy=(key=="north" and 0 or key=="south" and height-1 or i)
          local dx,dy=Map.connectionLanding(world.maps[conn.mapId],conn,dirKey,cx,cy)
          if world.map:isWalkable(cx,cy) and dx and dest:isWalkable(dx,dy) then
            root,direction,x,y,destination=candidate.id,dirKey,cx,cy,conn.mapId
            break
          end
        end
      end
      if root then break end
    end
    if root then break end
  end
  assert(root,"no walkable city connection found")
  assert(world:setMap(root,x,y,direction))
  log("fixture "..root.." cell="..x..","..y.." facing="..direction.." destination="..destination)
  local function sample(label)
    A.prepareWorld(world)
    local view=R.view(world)
    local stats=love.graphics.getStats()
    log(("%s map=%s neighbors=%d rendered=%d pending=%d texture=%d lua=%.0f pumps=%d covered=%d maxPumpMs=%.2f budgetOverruns=%d")
      :format(label,world.map.id,#world.neighbors,#view.neighbors,M.pending(),stats.texturememory or 0,
        collectgarbage("count")*1024,pumps,coveredPumps,pumpMax,overruns))
  end
  local function settle(label)
    for i=1,900 do
      wait(1)
      local cap = tonumber(os.getenv("PROBE_LUA_BUDGET_MB"))
      if cap and collectgarbage("count") > cap * 1024 then
        sample("PROBE_BUDGET_EXCEEDED:"..label)
        monitor.flush(); profiler.finish(); output:flush(); spikeLog:close()
        local text=love.filesystem.read("resource-monitor.log")
        if text then local f=assert(io.open(dir.."/resource-monitor.log","w"));f:write(text);f:close() end
        error("probe-only Lua heap budget exceeded "..cap.." MiB; stopping disposable run")
      end
      if i%120==0 then sample(label.."-building") end
      if i>120 and M.pending()==0 then break end
    end
    sample(label)
    game.capturePath=dir.."/"..label..".png"; wait(3)
  end
  settle("before-crossing")
  Perf.setSegment("connection:"..root.."->"..destination)
  -- A real held direction invokes the engine movement/connection path.
  for _=1,120 do
    game.input.state[direction]=true
    table.insert(game.input.pressQueue,direction)
    wait(1)
    if world.map.id~=root then break end
  end
  game.input.state[direction]=false
  assert(world.map.id==destination,"native movement did not cross connection; stack="..tostring(game.stack:top()))
  settle("after-crossing")
  local opposite={up="down",down="up",left="right",right="left"}
  local back=opposite[direction]
  for _=1,120 do
    game.input.state[back]=true; table.insert(game.input.pressQueue,back); wait(1)
    if world.map.id==root then break end
  end
  game.input.state[back]=false
  assert(world.map.id==root,"return crossing failed")
  settle("returned")
  monitor.flush()
  local text=love.filesystem.read("resource-monitor.log")
  if text then local f=assert(io.open(dir.."/resource-monitor.log","w")); f:write(text); f:close() end
  local f=assert(io.open(dir.."/perf.json","w")); f:write(Perf.toJson({version=version})); f:close()
  log("DONE real outbound/return connections; fresh fixture, no save write")
  if os.getenv("PROBE_SAVE_CACHE") == "1" then
    local saved, err = Disk.saveRamToDisk()
    log("scratch-cache-save="..tostring(saved).." error="..tostring(err))
  end
  profiler.finish()
  spikeLog:close()
  output:close()
end
