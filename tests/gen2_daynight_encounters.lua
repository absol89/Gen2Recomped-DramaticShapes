-- Mod root, DS_ENGINE_ROOT set. Real clock, hook, World and encounter lookup.
local root=assert(os.getenv('DS_ENGINE_ROOT'))
package.path=root..'/?.lua;'..package.path
love=require('tests.love_stub')
local Clock=require('src.core.gen2.Clock')
local Palettes=require('src.world.gen2.Palettes')
local Encounter=require('src.battle.gen2.Encounter')
local World=require('src.world.gen2.World')
local Runtime=require('src.mods.Runtime')
local Hooks=require('src.mods.Hooks')
local hooks=Hooks.new()
Runtime.install(nil,hooks,{})
local game={save={rtc={startMinute=12*60}}}
local V={mod={},generation=function()return 2 end,game=function()return game end}
local modules={}
V.require=function(name)
 if not modules[name]then modules[name]=assert(loadfile('lib/'..name..'.lua'))(V)end
 return modules[name]
end
local DayNight=V.require('DayNight')
-- Execute the shipped hook registration, not a copy of its callback.
local f=assert(io.open('main.lua'));local source=f:read('*a');f:close()
local registration=assert(source:match('(mod.hooks:wrap%("world%.tod".-\nend%))'))
local install=assert(loadstring('return function(mod,DayNight) '..registration..' end'))()
install({hooks=hooks},DayNight)
local world=setmetatable({game=game,weekday=function()return 1 end},{__index=World})
local date=os.date
os.date=function(format,...)
 if format=='%H'then return '12' end
 if format=='%M'then return '00' end
 if format=='*t'then return {hour=12,min=0,sec=0}end
 return date(format,...)
end -- PC noon, Pokegear midnight
assert(Clock.hour(game.save)==0)
DayNight.setting:sync('sync')
assert(DayNight.hours()==0 and world:timeOfDay(0)=='NITE','SYNC must read Pokegear offset')
local function slots(species)
 local out={};for i=1,7 do out[i]={species=species,level=5}end;return out
end
local tables={grass={TEST={slots={MORN=slots('MORNING_MON'),DAY=slots('DAY_MON'),NITE=slots('NIGHT_MON')},
 rates={MORN=11,DAY=22,NITE=33}}}}
for mode,expected in pairs({dawn='MORN',day='DAY',dusk='NITE',night='NITE'})do
 DayNight.setting:sync(mode)
 local period=world:timeOfDay(12)
 assert(period==expected,mode..' returned '..period)
 assert(Encounter.grassSlot(tables,'TEST',period,function()return 0 end).species
  ==tables.grass.TEST.slots[expected][1].species)
 assert(Encounter.grassRate(tables,'TEST',period)==tables.grass.TEST.rates[expected])
end
-- Every minute, including both sides of each host boundary and midnight.
for minute=0,1439 do
 local expected=Palettes.clockDaytime(minute/60)
 game.save.rtc.startMinute=(minute-720)%1440
 DayNight.setting:sync('sync')
 assert(world:timeOfDay(minute/60)==expected,'SYNC minute '..minute)
 DayNight.setting:sync('cycle')
 DayNight.clock=((minute/60-6)%24)*DayNight.CYCLE/24
 assert(world:timeOfDay(12)==expected,'CYCLE minute '..minute)
end
assert(game.save.rtc.startMinute==(1439-720)%1440,'clock offset mutated')
local fish={fishGroups={TEST={old={{chance=256,
 day={species='DAY_FISH',level=5},nite={species='NIGHT_FISH',level=5}}}}}}
DayNight.setting:sync('night')
assert(Encounter.fish(fish,'TEST','old',world:timeOfDay(12),function()return 0 end).species=='NIGHT_FISH')
DayNight.setting:sync('day')
assert(Encounter.fish(fish,'TEST','old',world:timeOfDay(0),function()return 0 end).species=='DAY_FISH')
-- Legacy Gen 1 vocabulary remains unchanged for consumers outside Gen 2.
V.generation=function()return 1 end
DayNight.setting:sync('night');assert(DayNight.tod()=='NIGHT')
assert(DayNight.hours()==12)
os.date=date
print('PASS Gen2 DAYTIME: Pokegear offset, all pins, 1440 SYNC/CYCLE minutes, encounter slots/rates')
