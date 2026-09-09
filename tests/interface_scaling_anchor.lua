-- Production fitter and Summary/Dex adapters with synthetic opaque pixels.
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function data(w,h)
  local d={w=w,h=h,p={}}
  function d:getDimensions() return self.w,self.h end
  function d:getWidth() return self.w end
  function d:getHeight() return self.h end
  function d:getPixel(x,y) return 1,0,0,self.p[y*self.w+x] or 0 end
  function d:setPixel(x,y,r,g,b,a) self.p[y*self.w+x]=a end
  function d:setFilter() end
  return d
end
local file=assert(io.open('lib/BattleArt.lua'))
local source=file:read('*a');file:close()
local body=assert(source:match('(function BattleArt.fitPreparedFrames.-)\n%-%- Animated transforms'))
local env=setmetatable({BattleArt={},metrics={},preparedData={},external={},
  fittedFrameSets={},love={image={newImageData=data},graphics={newImage=function(d) return d end}}},{__index=_G})
local chunk=assert(loadstring(body));setfenv(chunk,env);chunk()
local function pose(y,h,w)
  w=w or 20
  local d=data(120,120)
  for py=y,y+h-1 do for x=20,19+w do d:setPixel(x,py,1,0,0,1) end end
  env.metrics[d]={x0=20,x1=19+w,y0=y,y1=y+h-1}
  env.preparedData[d]=d
  return d
end
local frames={pose(20,20),pose(10,30)}
local sets={SMALL=frames, MEDIUM={pose(20,40)}, LARGE={pose(20,70,80)}}
local mode,interfaceMode,flip='fit','battle_art',true
local function setting(get) return {get=get} end
local battle=env.BattleArt
battle.metrics=function(image) return env.metrics[image] end
battle.setting=setting(function() return 'animated' end)
battle.frontAnimationSetting=setting(function() return 'gen4' end)
battle.displayMode=function() return 'color' end
battle.flipsPlayerFront=function() return flip end
local rom=data(56,56)
local draw,mark,throws
love={graphics={draw=function(image,x,y,rotation,sx)
  draw={image=image,x=x,y=y,sx=sx}
end}}
local P={markTrueColor=function(x,y,w,h) mark={x=x,y=y,w=w,h=h} end}
package.loaded['src.render.PaletteFX']=P
local Summary={}
function Summary.new(_,mon) return setmetatable({mon=mon,sprite=rom},{__index=Summary}) end
function Summary:update() end
function Summary:draw()
  local w,h=self.sprite:getDimensions()
  local y=math.max(0,56-h)
  love.graphics.draw(self.sprite,8+w,y,0,-1,1)
  P.markTrueColor(8,y,w,h)
  if throws then error('draw failed') end
end
local Dex={}
function Dex.new(_,def) return setmetatable({def=def,sprite=rom},{__index=Dex}) end
function Dex:update() end
function Dex:draw()
  local w,h=self.sprite:getDimensions()
  local x=8+math.floor((8-w/8)/2)*8
  love.graphics.draw(self.sprite,x+w,64-h,0,-1,1)
  P.markTrueColor(x,64-h,w,h)
  if throws then error('draw failed') end
end
package.loaded['src.ui.SummaryMenu']=Summary
package.loaded['src.ui.DexEntryMenu']=Dex
local V={require=function(name)
  if name=='BattleArt' then return battle end
  if name=='AnimatedBattleArt' then return {interfaceFront=function(species) return sets[species],{100,100} end} end
  if name=='ModSetting' then return {new=function(key)
    return setting(function() return key=='interfaceScaling' and mode or interfaceMode end)
  end} end
  error(name)
end}
local Interface=assert(loadfile('lib/InterfaceSprites.lua'))(V)
Interface.installSummary();Interface.installDex()
local summary=Summary.new({}, {species='SMALL'})
summary:draw()
check(env.metrics[draw.image].y1+draw.y==55,'FIT bottom alignment retained')
mode='full';summary:draw()
local firstImage=draw.image
check(draw.y+env.metrics[draw.image].y0==36,'20px first pose starts at row 36')
check(draw.y+env.metrics[draw.image].y1==55,'20px first pose ends at row 55')
check(mark.y==draw.y and mark.x==draw.x-draw.image.w,'true-color rect follows mirrored sprite')
local origin=draw.y
summary:update(.11);summary:draw()
check(draw.y==origin,'later taller pose keeps first-frame offset')
check(draw.y+env.metrics[draw.image].y0==26,'authored 10px upward movement preserved')
local secondImage=draw.image
mode='fit';summary:draw()
check(draw.image~=firstImage and draw.image~=secondImage,'FIT uses its separate fitted cache')
check(env.metrics[draw.image].y0==26,'mode switch retains second animation frame')
mode='full';summary:draw()
check(draw.image==secondImage,'switching back retains native frame and playback')
flip=false;summary:draw()
check(draw.sx==1 and draw.x==mark.x,'authored orientation works with FULL offset')
local medium=Summary.new({}, {species='MEDIUM'});medium:draw()
check(draw.y+env.metrics[draw.image].y0==16,'40px pose starts at row 16')
local large=Summary.new({}, {species='LARGE'});large:draw()
check(draw.y+env.metrics[draw.image].y0==0,'oversized first pose starts at screen top')
check(draw.image.w==80 and draw.image.h==70,'FULL preserves oversized dimensions')
local pixels=0
for _,alpha in pairs(draw.image.p) do if alpha>0 then pixels=pixels+1 end end
check(pixels==80*70,'FULL preserves every visible pixel')
check(draw.x==0 and mark.x==0,'oversized summary keeps left edge visible')
local dex=Dex.new({}, {id='SMALL'});dex:draw()
check(draw.y+env.metrics[draw.image].y0==26,'Dex centers first pose in 72px portrait')
check(mark.y==draw.y,'Dex true-color rect follows its new origin')
local dexOrigin=draw.y
dex:update(.11);dex:draw()
check(draw.y==dexOrigin,'Dex preserves animation movement')
local originalDraw,originalMark=love.graphics.draw,P.markTrueColor
throws=true
check(not pcall(summary.draw,summary),'Summary propagates draw exception')
check(love.graphics.draw==originalDraw and P.markTrueColor==originalMark,'Summary restores wrappers on exception')
check(not pcall(dex.draw,dex),'Dex propagates draw exception')
check(love.graphics.draw==originalDraw and P.markTrueColor==originalMark,'Dex restores wrappers on exception')
throws=false;interfaceMode='off';summary:draw()
check(draw.image==rom and draw.y==0,'OFF restores unmodified ROM image and origin')
print(checks..' interface scaling/first-pose anchor checks passed')

-- Load the REAL Gen 2 menu classes: Gen 1 stand-ins cannot catch wrong hooks.
package.path='../../?.lua;../../?/init.lua;'..package.path
local G=love.graphics
local depth=0
G.push=function() depth=depth+1 end
G.pop=function() depth=depth-1 end
G.setColor=function() end
G.setShader=function() end
G.rectangle=function() end
G.newQuad=function() return {} end
G.getDimensions=function() return 160,144 end
G.getShader=function() return nil end
G.newShader=function() error('no GPU') end
love.filesystem={getInfo=function() return nil end}
local S2=require('src.ui.gen2.SummaryMenu')
local D2=require('src.ui.gen2.PokedexMenu')
Interface.installGen2()
interfaceMode='battle_art';mode='full'
local s2=setmetatable({mon={species='SMALL'},pokemon={SMALL={spriteFront='rom'}}},{__index=S2})
s2:drawPic()
check(draw.y+env.metrics[draw.image].y0==36,'real Silver Summary replaces portrait and bottom-aligns small first pose')
check(mark.x==draw.x and mark.y==draw.y,'Gen 2 true-color coordinates match portrait')
local d2=setmetatable({pokemon=s2.pokemon},{__index=D2})
d2:drawPic({species='SMALL',seen=true},1,1,true)
check(draw.y+env.metrics[draw.image].y0==26,'real Silver Dex replaces portrait at its tile origin')
s2.mon.species='LARGE';s2.pokemon.LARGE={spriteFront='large'}
s2:drawPic()
check(draw.y+env.metrics[draw.image].y0==0,'real Silver Summary top-aligns large first pose')
d2:drawPic({species='LARGE',seen=true},1,1,true)
check(draw.y+env.metrics[draw.image].y0==1,'oversize 70px Dex pose centers at -7 relative to portrait')
sets.PIDGEOTTO={pose(6,78,69)}
d2.pokemon.PIDGEOTTO={spriteFront='pidgeotto'}
d2:drawPic({species='PIDGEOTTO',seen=true},1,1,true)
check(draw.y+env.metrics[draw.image].y0==-3,'78px Pidgeotto pose centers at -11 relative to portrait')
local nativeCalls=0
s2.picFor=function() return rom end
s2.picAnimFrame=function() return nil end
s2.drawPicBlock=function(_,image) check(image==rom,'ROM image restored');nativeCalls=nativeCalls+1 end
interfaceMode='off';s2:drawPic()
check(nativeCalls==1,'Gen 2 OFF delegates to native portrait')
interfaceMode='battle_art'
d2.questionMark=function() nativeCalls=nativeCalls+1;return rom end
d2:drawPic({species='SMALL',seen=false},1,1,true)
check(nativeCalls==2 and draw.image==rom,'unseen Dex retains question mark')
check(depth==0,'Gen 2 drawing restores graphics state')
print(checks..' total interface checks passed, including real Gen 2 menus')
