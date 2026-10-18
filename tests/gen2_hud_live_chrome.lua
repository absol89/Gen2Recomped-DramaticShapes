-- Real host Chrome text entry points, with recorded glyph/palette output.
-- Run from mod root with DS_ENGINE_ROOT pointing at the engine checkout.
local root = assert(os.getenv('DS_ENGINE_ROOT'))
package.path = root .. '/?.lua;' .. package.path
local draws, color, shader = {}, {1,1,1,1}, nil
love = {graphics={
  setColor=function(r,g,b,a) color={r,g,b,a or 1} end,
  getColor=function()return unpack(color)end,
  getShader=function()return shader end,
  setShader=function(s)shader=s end,
  rectangle=function()end, draw=function()end,
}}
local Font={TTF_BASE=1000}
function Font.encode(text)
  local out={};for i=1,#text do out[i]=text:byte(i)end;return out
end
function Font.advanceOf(code)return code==73 and 4 or 8 end
function Font.drawCode(code,x,y)
  draws[#draws+1]={code=code,x=x,y=y,ink=shader and shader[4][1]/255 or color[1],alpha=color[4]}
end
package.loaded['src.render.Font']=Font
package.loaded['src.render.GbcPalette']={available=function()return true end,
  resolve=function(p)return p end,remap=function(p)return p end,
  useRaw=function(p)shader=p end,use=function(p)shader=p end}
local Chrome=require('src.ui.gen2.Chrome')
local original=Chrome.printThrough
local originalRight=Chrome.printRightThrough
local hudColors
local hud={drawTile=function(_,_,_,_,_,_,pal)hudColors=pal end}
local nativeTile=hud.drawTile
local fail=false
local Battle={pic=function()end,drawPic=function()end,drawSceneBody=function()end}
function Battle:drawWidescreen()
  Chrome.printThrough('AI',1,1,Chrome.DEFAULT_BOX_PALETTE) -- enemy
  Chrome.printRightThrough('AI',18,10,Chrome.DEFAULT_BOX_PALETTE) -- player
  Chrome.printThrough('AI',2,14,Chrome.DEFAULT_BOX_PALETTE) -- message/menu
  self.hud:drawTile('hpBar',0,0,10,9,{{255,255,255},{200,200,0},{0,255,0},{0,0,0}})
  if fail then error('draw failure')end
end
package.loaded['src.battle.BattleState']=Battle
local inverted=true
local modules={BattleArt={isExternal=function()return false end},BattlePics={},
  UiBackplates={arenaWhite=function()return false end,
    hudUsesColor=function()return not inverted end,
    hudUsesColorShadow=function()return not inverted end,
    textboxMode=function()return 'OFF'end,textboxFillStyle=function()end}}
local Adapter=assert(loadfile('lib/Gen2BattleAdapter.lua'))({require=function(n)return assert(modules[n],n)end})
local shot={canvas={getDimensions=function()return 160,144 end}}
Adapter.install({shot=function()return shot end,setGen2PicResolver=function()end})
local state=setmetatable({hud=hud},{__index=Battle})
for _,value in ipairs({true,false})do
  inverted=value;draws={};state:drawWidescreen(160,144)
  assert(#draws==12,'each text glyph needs shadow and foreground')
  for i=1,#draws,2 do
    local a,b=draws[i],draws[i+1]
    assert(a.x==b.x+1 and a.y==b.y+1,'shadow offset')
    assert(b.ink==(inverted and 1 or 0),'foreground ink')
    assert(a.ink==(inverted and 0 or 1),'shadow ink')
    assert(a.alpha==(inverted and 1 or .5),'shadow opacity')
  end
  assert(draws[6].x==18*8-12,'right aligned proportional font width')
  assert(hudColors[4][1]==(inverted and 255 or 0),'HUD tile ink')
  assert(hudColors[3][2]==255 and hudColors[3][1]==0,'HP fill color preserved')
  assert(Chrome.printThrough==original and Chrome.printRightThrough==originalRight)
  assert(hud.drawTile==nativeTile,'HUD method restored')
end
fail=true
assert(not pcall(state.drawWidescreen,state,160,144))
assert(Chrome.printThrough==original and Chrome.printRightThrough==originalRight)
assert(hud.drawTile==nativeTile,'error cleanup')
print('PASS real Chrome: enemy/player/message ink, shadow, alignment, HP color, cleanup')
