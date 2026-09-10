local writes,prints=0,0
local osName='Android'
love={system={getOS=function() return osName end},timer={getTime=function() return 1 end},
 filesystem={write=function() writes=writes+1 end,append=function() writes=writes+1 end,
 getSaveDirectory=function() return 'save' end}}
local oldPrint=print
print=function() prints=prints+1 end
local trace=assert(loadfile('lib/CacheTrace.lua'))()
trace.log('test','VIOLET_CITY','ignored')
assert(writes==0 and prints==0,'mobile must not log')
local mobile=trace.snapshot()
assert(mobile.sequence==1 and mobile.counts.test==1,
       'structured counters must work without desktop file logging')
osName='Windows';trace.log('queue','VIOLET_CITY','full')
assert(writes==2 and prints==2,'desktop starts session and records event')
trace.log('disk-hit','ECRUTEAK_CITY','body')
assert(writes==3,'append without resetting session')
love.filesystem.append=function() error('disk full') end
assert(pcall(trace.log,'test','MAP','failure'),'logging must fail open')
local snapshot=trace.snapshot()
assert(snapshot.sequence==4 and snapshot.capacity==64,
       'structured trace sequence/capacity')
assert(snapshot.counts.test==2 and snapshot.counts.queue==1
       and snapshot.counts['disk-hit']==1,
       'structured trace counts cache events')
print=oldPrint
print('Desktop cache trace gating, append and failure isolation: ok')
