-- Static margins must not become world-space levitation; animated margins survive.
local f=assert(io.open("lib/OverworldBattle.lua"));local source=f:read("*a");f:close()
local body=assert(source:match("(function OverworldBattle.gen2EnemyAnchorY.-)\nfunction OverworldBattle.sideTexture"))
local mode="static"
local image={getDimensions=function() return 80,80 end}
local env=setmetatable({OverworldBattle={},BattleArt={
  setting={get=function() return mode end},
  isExternal=function(img) return img==image end,
  metrics=function() return {padBottom=12} end,
}},{__index=_G})
local chunk=assert(loadstring(body));setfenv(chunk,env);chunk()
local B=env.OverworldBattle
assert(B.gen2StaticPadding(image,1)==12)
assert(B.gen2EnemyAnchorY(image,B.gen2StaticPadding(image,1))==68)
assert(96-B.gen2StaticPadding(image,2)==72,"scaled player padding")
local rom={getDimensions=function() return 40,40 end}
assert(B.gen2StaticPadding(rom,1)==0,"ROM identity must remain engine-owned")
assert(B.gen2EnemyAnchorY(rom)==56)
mode="animated"
assert(B.gen2StaticPadding(image,1)==0,"animation clearance must survive")
assert(B.gen2EnemyAnchorY(image)==80,"oversized animation anchor")
mode="rom";assert(B.gen2StaticPadding(image,1)==0)
print("Gen2 static ground anchors and animated/ROM preservation: ok")
