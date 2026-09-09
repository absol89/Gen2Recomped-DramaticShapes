-- Run with the LOVE data/image headless runner from the mod root.
local f=assert(io.open('lib/OverworldBattle.lua'));local source=f:read('*a');f:close()
local body=assert(source:match('(function OverworldBattle.gen2EnemyAnchorY.-)\nfunction OverworldBattle.sideTexture'))
local env=setmetatable({OverworldBattle={}},{__index=_G})
local chunk=assert(loadstring(body));setfenv(chunk,env);chunk()
local defs=assert(loadfile('data/animated_battle_sprites_gen4.lua'))()
for _, species in ipairs({'PIDGEOTTO','EKANS'}) do
  local def=defs[species].front
  local file=assert(io.open(def.image,'rb'));local bytes=file:read('*a');file:close()
  local sheet=love.image.newImageData(love.filesystem.newFileData(bytes,'atlas.png'))
  local w,h=def.width,def.height
  if sheet:getWidth()==def.legacyLayout.width*def.columns then w,h=def.legacyLayout.width,def.legacyLayout.height end
  local anchor=env.OverworldBattle.gen2EnemyAnchorY({getDimensions=function() return w,h end})
  local restGap
  for i=0,def.frames-1 do
    local bottom=-1
    for y=0,h-1 do for x=0,w-1 do
      local _,_,_,a=sheet:getPixel(i%def.columns*w+x,math.floor(i/def.columns)*h+y)
      if a>0.001 then bottom=math.max(bottom,y) end
    end end
    -- Same placement as real Silver drawPic; one atlas coordinate system.
    local paintedBottom=math.max(0,56-h)+bottom+1
    assert(paintedBottom<=anchor,species..' frame sinks through ground')
    if i==def.frames-1 then restGap=anchor-paintedBottom end
  end
  assert(restGap>0,species..' authored resting clearance lost')
  print(species..': all frames above floor; resting gap '..restGap..' atlas pixels')
end
assert(env.OverworldBattle.gen2EnemyAnchorY({getDimensions=function() return 40,40 end})==56)
