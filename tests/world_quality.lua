local performance = {tier='balanced'}
package.loaded['src.core.Performance'] = performance
local Scope = assert(loadfile('lib/WorldRenderScope.lua'))()
local values={aa=4,water='full',shadowQuality='high'}
local modules={WorldRenderScope=Scope,ModSetting={new=function(key)
 return {get=function()return values[key]end}
end}}
local V={require=function(n)return modules[n] or {}end}
modules.WorldQuality=assert(loadfile('lib/WorldQuality.lua'))(V)
local Q=modules.WorldQuality
local AA=assert(loadfile('lib/AntiAlias.lua'))(V)
local Water=assert(loadfile('lib/Water.lua'))(V)
modules.Shadows={off=function()return false end}
modules.Mat4=assert(loadfile('lib/Mat4.lua'))()
local Shadow=assert(loadfile('lib/ShadowMap.lua'))(V)
assert(AA.samples()==4 and Water.level()==2,'battle settings were capped')
assert(AA.samples(true)==2,'explicit world AA did not use balanced tier')
Scope.run(true,function()
 assert(Q.name()=='balanced' and AA.samples()==2 and Water.level()==1)
 assert(Q.clamp('shadowRes',4096)==1024)
 values.aa=0;values.water='off'
 assert(AA.samples()==0 and Water.level()==0,'caps raised user settings')
 values.aa=4;values.water='full';performance.tier='low'
 assert(AA.samples()==0 and Water.level()==0 and not Shadow.available() and not Shadow.active())
 performance.tier='high'
 assert(AA.samples()==4 and Water.level()==2 and Q.clamp('shadowRes',4096)==4096)
 performance.tier='unknown'
 assert(Q.name()=='high')
end)
assert(values.aa==4 and values.water=='full','stored options changed')
performance.tier='low'
assert(AA.samples()==4 and Water.level()==2,'world tier leaked into battle')
package.loaded['src.core.Performance']=nil
package.preload['src.core.Performance']=function()error('unavailable host service')end
local missing=assert(loadfile('lib/WorldQuality.lua'))(V)
Scope.run(true,function()assert(missing.name()=='high')end)
print('PASS world quality: live caps, saved choices, absent host service and battle isolation')
