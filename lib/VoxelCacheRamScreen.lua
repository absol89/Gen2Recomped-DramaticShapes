-- Opaque CONTINUE gate which copies compressed persistent voxel containers to
-- RAM before gameplay. Disk files remain authoritative; this table removes
-- traversal-time filesystem reads without keeping decompressed/GPU copies of
-- the entire world resident.

local V = ...

local Font = require("src.render.Font")
local Disk = V.require("VoxelMeshDisk")
local Screen = {}
Screen.__index = Screen
Screen.isOpaque = true

local function sizeText(bytes)
  return Disk.sizeText(bytes)
end

local function put(text, row)
  Font.draw(tostring(text or ""), 8, row * 8)
end

function Screen.new(game, onReady)
  Disk.beginSession()
  local names, total = Disk.ramPlan()
  return setmetatable({
    game = game,
    onReady = onReady,
    names = names,
    total = total,
    index = 1,
    loaded = 0,
    failed = 0,
    titleUiBox = { 0, 0, 19, 17 },
  }, Screen)
end

function Screen:finish()
  local callback = self.onReady
  self.onReady = nil
  self.game.stack:pop()
  if callback then callback() end
end

function Screen:update()
  -- Read at least one file per frame, then small records up to an 8 MB slice.
  -- A large route is intentionally one loading-screen frame rather than a
  -- traversal hitch later.
  local slice, processed = 0, 0
  local budget = type(Disk.ramBudgetBytes) == "function"
    and Disk.ramBudgetBytes() or 0
  local function atBudget()
    return budget > 0 and Disk.ramStats().bytes >= budget
  end
  while self.names[self.index] and not atBudget()
      and (processed == 0 or slice < 8 * 1024 * 1024) do
    local ok, bytes = Disk.loadIntoRam(self.names[self.index])
    if ok then self.loaded = self.loaded + bytes else self.failed = self.failed + 1 end
    self.index = self.index + 1
    slice, processed = slice + bytes, processed + 1
  end
  -- On mobile, stop at the bounded compressed-RAM budget instead of reading a
  -- multi-gigabyte world only to evict most of it. VoxelScene/Precache then
  -- warm the current map and warp-neighbours in priority order after resume.
  if not self.names[self.index] or atBudget() then
    collectgarbage("collect")
    self:finish()
  end
end

function Screen:draw()
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  Font.drawBox(0, 0, 20, 18)
  love.graphics.setColor(0, 0, 0, 1)
  put("LOADING VOXELS", 2)
  put(("FILE %d/%d"):format(math.min(self.index - 1, #self.names),
                              #self.names), 5)
  local stats = Disk.ramStats()
  put(("RAM %s"):format(sizeText(stats.bytes)), 7)
  put(("READ %s"):format(sizeText(self.loaded)), 8)
  put(("TOTAL %s"):format(sizeText(self.total)), 9)
  if self.failed > 0 then put(("DISK FALLBACK %d"):format(self.failed), 11) end
  put("PLEASE WAIT", 14)
end

return Screen
