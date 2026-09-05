-- Exercise the actual capture body and both install-time selections without
-- booting the engine. In particular, native Gen2Recomped has no animView.
local file = assert(io.open('lib/OverworldBattle.lua', 'rb'))
local source = file:read('*a'); file:close()
local first = assert(source:find('local innerAnim = nil', 1, true))
local last = assert(source:find('-- The staged fight\'s effects', first, true))
local capture = source:sub(first, last-1)
local selections = {}
for line in source:gmatch('[^\r\n]+') do
  if line:match('^%s*innerAnim = ') then selections[#selections+1]=line end
end
assert(#selections==2)
local function run(selection, native)
  local calls, fallbackCalls, target = 0, 0, nil
  local canvas = {setFilter=function() end}
  local stack = {}
  local battle = {anim={}}
  local state = {}
  if native then
    state.drawAnimLayer=function(self, colorized)
      assert(self==battle and colorized==false and target==canvas)
      calls=calls+1
    end
  else
    battle.battle={}
    battle.animView={drawObjects=function(_, anim, model)
      assert(anim==battle.anim and model==battle.battle and target==canvas)
      fallbackCalls=fallbackCalls+1
    end}
  end
  local g = {
    newCanvas=function() return canvas end,
    getCanvas=function() return target end,
    setCanvas=function(value) target=value end,
    push=function() stack[#stack+1]={target} end,
    pop=function() target=table.remove(stack)[1] end,
    origin=function() end, clear=function() end,
    setBlendMode=function() end, setColor=function() end,
  }
  local env = setmetatable({
    OverworldBattle={}, BattleState=state,
    BattleScene={GB_W=160,GB_H=144}, love={graphics=g},
    BattleVisibility=assert(loadfile('lib/BattleVisibility.lua'))(),
  }, {__index=_G})
  local chunk=assert(loadstring(capture..'\n'..selection..'\nreturn OverworldBattle'))
  setfenv(chunk,env)
  local api=chunk()
  -- The captured function must survive installation of the wrapper itself.
  state.drawAnimLayer=function() error('recursive capture of wrapper') end
  assert(api.animTexture(battle)==canvas)
  assert(calls==(native and 1 or 0) and fallbackCalls==(native and 0 or 1))
  battle.introBalls=true
  assert(api.animTexture(battle)==nil)
  assert(target==nil and #stack==0)
end
for _,selection in ipairs(selections) do run(selection,true); run(selection,false) end
print('native and legacy attack capture regression: ok')
