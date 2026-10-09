package.loaded['src.world.Map']={isOutdoor=function(def)return def.outdoor end}
local shape={flat=true,class='ground'}
local TS={forMap=function()return{}end,at=function(map,_,tile,x,y)
  if map.mixed and x==0 and y==0 then return{flat=false,class='wall'}end
  return shape
end}
local M=assert(loadfile('lib/Gen2IndoorFloors.lua'))(
  {require=function(name)assert(name=='TileShape');return TS end})
local function image()
  local data={pixels={},writes=0,reads=0}
  function data:getDimensions()return 128,64 end
  function data:getPixel(x,y)
    self.reads=self.reads+1
    local p=self.pixels[y*128+x] or {.85,.68,.80,1}
    return unpack(p)
  end
  function data:setPixel(x,y,r,g,b,a)self.writes=self.writes+1;self.pixels[y*128+x]={r,g,b,a}end
  return data
end
local function map(id,tileset,tile)
  return{id=id,def={generation=2,width=1,height=1},tileset={id=tileset,tilesPerRow=16},
    tileAt=function(_,x,y)return(x==3 and y==3)and 2 or tile end}
end
local a=map('PLAYERS_HOUSE_1F','TilesetPlayersHouse',1)
local img=image();local n,painted,style=M.bake(a,img,{[1]=true,[2]=true})
assert(n==1 and painted[1] and not painted[2] and style=='oak' and img.writes==64)
assert(not img.pixels[16],'nonwhitelisted artwork changed')
local copy=image();M.bake(a,copy,{[1]=true})
for k,v in pairs(img.pixels)do for i=1,4 do assert(v[i]==copy.pixels[k][i])end end
local dark=image();dark.pixels[8]={0,0,0,1}
assert(M.bake(a,dark,{[1]=true})==0 and dark.writes==0,'symbol outline overwritten')
local transparent=image();transparent.pixels[8]={.8,.8,.8,0}
assert(M.bake(a,transparent,{[1]=true})==0 and transparent.writes==0)
local mixed=image();assert(M.bake(a,mixed,{[1]=false})==0 and mixed.writes==0)
local mixedMap=map('PLAYERS_HOUSE_1F','TilesetPlayersHouse',1);mixedMap.mixed=true
assert(M.bake(mixedMap,image())==0,'local inventory missed mixed wall use')
local outdoor=map('ROUTE_1','TilesetPlayersHouse',1);outdoor.def.outdoor=true
local out=image();assert(M.bake(outdoor,out,{[1]=true})==0 and out.writes==0 and out.reads==0)
local old=map('GEN1','TilesetHouse',1);old.def.generation=1
assert(M.bake(old,image(),{[1]=true})==0)
local warp=map('CENTER','TilesetPokecenter',0x11);warp.def.warps={{x=0,y=0}}
local wi=image();local wn,_,ws=M.bake(warp,wi,{[0x11]=true})
assert(wn==0 and wi.writes==0 and ws=='center_ceramic','warp reuse or zero-paint style wrong')
local styleSeen={}
for _,id in ipairs({'A','B','C'})do
  local _,_,s=M.bake(map(id,'TilesetHouse',1),image(),{[1]=true});styleSeen[s]=true
end
assert(styleSeen.oak and styleSeen.walnut and styleSeen.pale_planks)
for _,case in ipairs({{'EARLS_POKEMON_ACADEMY','TilesetLab',0x24,'academy_oak'},
  {'ELMS_LAB','TilesetLab',0x10,'laboratory_linoleum'},
  {'CENTER','TilesetPokecenter',0x11,'center_ceramic'},
  {'MART','TilesetMart',0x48,'mart_tile'},
  {'RADIO_TOWER_1F','TilesetRadioTower',1,'office_carpet'},
  {'KURTS_HOUSE','TilesetTraditionalHouse',1,'traditional_timber'}})do
  local im=image();local n,_,s=M.bake(map(case[1],case[2],case[3]),im,{[case[3]]=true})
  assert(n==1 and s==case[4])
  local lo,hi=1,0
  for _,p in pairs(im.pixels)do local l=(p[1]+p[2]+p[3])/3;lo=math.min(lo,l);hi=math.max(hi,l)end
  assert(hi-lo<.09,'floor contrast exceeds subdued palette')
end
for _,case in ipairs({
  {'BATTLE_TOWER_1F',0x01},
  {'BATTLE_TOWER_HALLWAY',0x03},
  {'BATTLE_TOWER_ELEVATOR',0x30},
  {'BATTLE_TOWER_BATTLE_ROOM',0x57},
})do
  local im=image();local n,painted,s=M.bake(map(case[1],'TilesetBattleTowerInside',case[2]),im,{[case[2]]=true})
  assert(n==1 and painted[case[2]] and s=='facility_blue',case[1]..' floor not calmed')
end
local forced=map('BATTLE_TOWER_1F','TilesetBattleTowerInside',0x11)
local forcedImage=image();local fn,fp,fs=M.bake(forced,forcedImage,{[0x11]=false})
assert(fn==1 and fp[0x11] and fs=='facility_blue','exact Battle Tower lobby carpet proof not applied')
local mansion=map('CELADON_MANSION_1F','TilesetMansion',1)
local mansionTileAt=mansion.tileAt
mansion.tileAt=function(self,x,y)if x==2 and y==2 then return 0x11 end;return mansionTileAt(self,x,y)end
local mi=image();assert(M.bake(mansion,mi,{[1]=true,[0x11]=true})==2)
assert(mi.pixels[8][1]~=mi.pixels[8*128+8][1],'distinct Mansion floor zones merged')
-- Exact 16px native House chair, transcribed from the source atlas. The
-- checker background shares colors with enclosed chair highlights.
local chairArt={
  '. . . . . . . . ', ' . . . . . . . .',
  '. . . . . . . . ', ' . . . . . . . .',
  '. . . . . . . . ', ' . . ######. . .',
  '. .#o......o# . ', ' .#...    ...# .',
  '. #..o....o..#. ', ' .#...oooo...# .',
  '. #o........o#. ', ' .##oooooooo## .',
  '. # ######## #. ', ' .#  #oooo#  # .',
  '. #  ######  #. ', ' . ###.o.o###. .',
}
local palette={[' ']={1,1,1,1},['.']={.67,.67,.67,1},
  ['#']={0,0,0,1},o={.33,.33,.33,1}}
local function chairPixel(x,y)
  local tile=(y<8 and 2 or 18)+(x<8 and 0 or 1)
  return (tile%16)*8+x%8,math.floor(tile/16)*8+y%8
end
local chairUses={[1]=true,[2]=true,[3]=true,[18]=true,[19]=true}
local function chairFixture()
  local im=image()
  for y=0,7 do for x=0,7 do
    im.pixels[y*128+8+x]=palette[(x+y)%2==0 and '.' or ' ']
  end end
  for y=0,15 do
    assert(#chairArt[y+1]==16)
    for x=0,15 do
      local ax,ay=chairPixel(x,y)
      im.pixels[ay*128+ax]=palette[chairArt[y+1]:sub(x+1,x+1)]
    end
  end
  local m=map('OLIVINE_TIMS_HOUSE','TilesetHouse',1)
  m.tileAt=function(_,x,y)
    if x<2 and y<2 then return(y==0 and 2 or 18)+x end
    return 1
  end
  return m,im
end
local cm,ci=chairFixture()
local cn,cp=M.bake(cm,ci,chairUses)
assert(cn==5 and cp[2] and cp[3] and cp[18] and cp[19])
local retained,changed=0,0
for y=0,15 do for x=0,15 do
  local ax,ay=chairPixel(x,y);local p=ci.pixels[ay*128+ax]
  local original=palette[chairArt[y+1]:sub(x+1,x+1)]
  -- All outlines, bindings and interior chair pixels are byte-identical;
  -- only the exterior checker field may be reached from the boundary.
  local inside=(y>=6 and y<=11 and x>=3 and x<=12)
    or (y>=12 and y<=14 and x>=5 and x<=10)
  if original==palette['#'] or original==palette.o or inside then
    for c=1,4 do assert(p[c]==original[c],('chair artwork changed %d,%d'):format(x,y))end
    retained=retained+1
  elseif p[1]~=original[1] then changed=changed+1 end
end end
assert(retained>80 and changed>100,'native chair mask did not preserve furniture/remove background')
for _,reason in ipairs({'unmatched','mixed','warp','palette'})do
  local m,im=chairFixture();local uses={}
  for k,v in pairs(chairUses)do uses[k]=v end
  if reason=='unmatched' then
    local prior=m.tileAt;m.tileAt=function(self,x,y)if x==3 and y==3 then return 2 end;return prior(self,x,y)end
  elseif reason=='mixed' then uses[2]=false
  elseif reason=='warp' then m.def.warps={{x=0,y=0}}
  else local ax,ay=chairPixel(0,0);im.pixels[ay*128+ax]={.2,.3,.4,1} end
  local before={}
  for y=0,15 do for x=0,15 do local ax,ay=chairPixel(x,y);before[ay*128+ax]=im.pixels[ay*128+ax]end end
  assert(M.bake(m,im,uses)==1,reason..' must veto all shared chair tiles')
  for k,p in pairs(before)do for c=1,4 do assert(im.pixels[k][c]==p[c],reason..' changed chair')end end
end
print('PASS floor styles, guards, native chair background-only mask, exact retained furniture pixels, all-occurrence veto')
