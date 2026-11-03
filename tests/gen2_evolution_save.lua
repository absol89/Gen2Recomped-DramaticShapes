-- Run from the engine root: luajit dev/BattleArtGen2/tests/gen2_evolution_save.lua
-- ROM-free lifecycle integration. Real engine screens/evolution/snapshot/save/load
-- and mod staging/adapter; synthetic species, GPU/audio doubles, memory-only FS.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")
local Version = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Events = require("src.mods.Events")
local Hooks = require("src.mods.Hooks")
local SaveData = require("src.core.SaveData")
-- Explicitly isolate every persistence call from portable/player files.
SaveData.persistenceFs = function() return love.filesystem end
SaveData.portableFs = function() return nil end
local Save = require("src.core.gen2.Save")
local Game = require("src.core.Game2")
local BattleState = require("src.ui.gen2.BattleState")
local StartMenu = require("src.ui.gen2.StartMenu")
local Stack = require("src.core.StateStack")
local Mon = require("src.battle.gen2.Mon")
local data = { moves = {}, pokemon = {
  growthRates = { MEDIUM_FAST = { numerator=1, denominator=1, squared=0, linear=0, constant=0 } },
} }
for _, row in ipairs({ {"CHIKORITA",152,45}, {"BAYLEEF",153,60} }) do
  data.pokemon[row[1]] = { name=row[1], index=row[2], growthRate="MEDIUM_FAST",
    types={"GRASS"}, genderRatio=31, levelMoves={}, evolutions={},
    baseStats={ hp=row[3], attack=49, defense=65, speed=45, specialAttack=49, specialDefense=65 } }
end
data.pokemon.CHIKORITA.evolutions = { {method="EVOLVE_LEVEL", level=16, into="BAYLEEF"} }
local modPath = os.getenv("DS_MOD_PATH") or "dev/BattleArtGen2"
local function noop() end
local updates, finishes = 0, 0
local texture = newproxy(true) -- stand-in for a LOVE Image, through the real resolver seam
local animation = { image=texture }
local game
local modules = {
  ModSetting={ new=function(_,_,values) return { get=function() return values[1] end } end },
  BattleArena={ find=function() return {} end },
  BattleCam={ reset=noop, update=noop },
  BattleScene={ render=function() return nil end }, BattleDOF={}, BattleHud={},
  BattlePics={}, BattlePresentation={}, BattleVisibility={}, UiBackplates={},
  BattleArt={ apply=noop, releaseSpeciesOverrides=noop, isExternal=function() return false end },
  AnimatedBattleArt={
    update=function(view)
      updates=updates+1
      view.player.picAnim=animation
    end,
    finish=function() finishes=finishes+1 end,
    ownsFrame=function() return nil end, updateTrainer=noop,
  },
  StadiumModels={release=noop}, Voxel3D={available=function() return true end},
  ChunkMesher={pump=noop}, CamControl={tick=noop},
}
local events = Events.new()
Runtime.install(events, Hooks.new())
local V = { game=function() return game end, mod={events=events} }
function V.require(name)
  if modules[name] then return modules[name] end
  if name == "Gen2BattleAdapter" then
    modules[name] = assert(loadfile(modPath.."/lib/Gen2BattleAdapter.lua"))(V)
    return modules[name]
  end
  error("unexpected module "..name)
end
-- Reproduce the sandbox's Gen2Compat alias used by the production installer.
package.loaded["src.battle.BattleState"] = BattleState
local ow = assert(loadfile(modPath.."/lib/OverworldBattle.lua"))(V)
ow.install()
ow.install()
-- Installation is idempotent, including the evolution subscription.
if events.listeners["pokemon.evolved"] then
  assert(#events.listeners["pokemon.evolved"]==1)
end
ow.setGen2PicResolver(function() return texture end)
events:on("battle.ended", ow.retire)

for _, version in ipairs({"crystal", "silver", "gold"}) do
  Version.set(version)
  assert(Version.engine() == (version=="crystal" and "crystal" or "gs"))
  local save = Save.newGame({trainerId=7})
  save.party = { Mon.new(data,"CHIKORITA",16) }
  local original = save.party[1]
  original.nickname, original.happiness = "LEAF", 123
  original.statExp.hp = 1234
  original.customPersistent = {value="keep me"}
  local stack = setmetatable({}, {__index=Stack}); stack:init()
  game = setmetatable({save=save,options=save.options,data=data,stack=stack,phase="play"}, {__index=Game})
  game.world = {map={id="NEW_BARK_TOWN",def={}},player={cellX=3,cellY=4,facing="up"},
    entities={},ghosts={}}
  game.syncEngine = function() return nil end
  local battle = {party=save.party,player=original,enemy=Mon.new(data,"CHIKORITA",5),
    outcome="win",over=true,clearAllVolatiles=noop}
  local state = setmetatable({game=game,save=save,battle=battle,evolvable={[1]=true},
    phase="resolving",stopAlarm=noop, givePokerus=noop}, {__index=BattleState})
  state.onDone = function() stack:pop() end
  assert(ow.begin(game.world,state)); stack:push(state)
  ow.update(1/60)
  assert(original.sprite==texture and original.picAnim==animation, "art attachment did not run")
  -- The handler must not sanitize another provider's distinct rendering fields.
  local foreign = {species="BAYLEEF",sprite=newproxy(true),picAnim={foreign=true},custom=9}
  local foreignSprite, foreignAnim = foreign.sprite, foreign.picAnim
  Runtime.emit("pokemon.evolved",{mon=foreign,fromSpecies="CHIKORITA"})
  assert(foreign.sprite==foreignSprite and foreign.picAnim==foreignAnim and foreign.custom==9)
  local baseline=finishes
  -- Queue/turn resolution is simulated; run the real post-victory sweep and
  -- entire evolution screen, including dialogue, commit, callback and exit fade.
  state:startEvolutions()
  local observedPostEvolution = false
  for frame=1,4000 do
    local top=stack:top()
    if top==state and state.phase=="fadeout" then state:stepExitFade()
    elseif top and top~=state then top:update(1/60) end
    ow.update(1/60)
    if save.party[1]~=original and stack:top() then
      observedPostEvolution=true
      assert(finishes==baseline,"art retired during evolution/dialogue")
      assert(original.sprite==texture and original.picAnim==animation,
        "source art cleared before battle exit")
    end
    if not stack:top() then break end
  end
  assert(stack:top()==nil and game.phase=="play", "battle did not return to overworld")
  assert(observedPostEvolution,"post-evolution dialogue/fade was not exercised")
  assert(finishes==baseline+1, "battle art teardown did not run exactly once")
  assert(original.sprite==nil and original.picAnim==nil, "original battler was not cleaned")
  local evolved=save.party[1]
  assert(evolved~=original and evolved.species=="BAYLEEF")
  local menu=StartMenu.new(game,{onChoose=function(id) game:pushStartMenuItem(id) end})
  stack:push(menu)
  local index
  for i,item in ipairs(menu.items) do if item.value=="save" then index=i end end
  assert(index,"overworld pause menu has no Save option")
  menu:choose(menu.items[index].value,index)
  local saveMenu=stack:top()
  assert(saveMenu~=menu and saveMenu.writer,"Save menu was not opened")
  print(version..": save.party[1].sprite="..type(evolved.sprite)..", picAnim="..type(evolved.picAnim)
    ..", inherited sprite="..tostring(evolved.sprite==texture))
  -- The real pause-menu writer calls Game2:writeSave -> snapshot -> Save.save.
  -- Run it first so the pre-fix failure is the actual serializer stack trace.
  saveMenu:writeNow()
  assert(saveMenu.saved,"pause-menu save failed")
  assert(evolved.sprite==nil and evolved.picAnim==nil,"transient fields leaked")
  local loaded=assert(Save.load(version))
  local mon=loaded.party[1]
  assert(mon.species=="BAYLEEF" and mon.nickname=="LEAF" and mon.happiness==123)
  assert(mon.statExp.hp==1234 and mon.customPersistent.value=="keep me")
  assert(mon.sprite==nil and mon.picAnim==nil)
  assert(loaded.position.map=="NEW_BARK_TOWN" and loaded.position.x==3 and loaded.position.y==4)
  assert(mon.level==evolved.level and mon.hp==evolved.hp and mon.experience==evolved.experience)
  stack:clear()
  -- No active arena: evolution outside a battle must preserve other owners.
  Runtime.emit("pokemon.evolved",{mon=foreign,fromSpecies="CHIKORITA"})
  assert(foreign.sprite==foreignSprite and foreign.picAnim==foreignAnim)
  -- Interrupted battle/stack clear still uses the existing deferred cleanup.
  battle.player = evolved
  assert(ow.begin(game.world,state)); stack:push(state)
  ow.update(1/60)
  assert(evolved.sprite==texture and evolved.picAnim==animation)
  stack:clear(); ow.update(1/60)
  assert(evolved.sprite==nil and evolved.picAnim==nil)
  print(version..": evolution -> overworld -> pause-menu save -> reload PASS")
end
assert(updates>0,"battle art never updated")
Runtime.reset()
