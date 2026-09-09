-- Exercise the real decoder against every regular and shiny Gen 4 definition.
local checks = 0
local function image(w,h)
  return {width=w,height=h,getDimensions=function() return w,h end,
    paste=function(self,_,dx,dy,x,y,cw,ch) self.rect={x,y,cw,ch} end}
end
love={image={newImageData=image}}
for _,suffix in ipairs({'','_shiny'}) do
  local definitions=assert(loadfile('data/animated_battle_sprites_gen4'..suffix..'.lua'))()
  local battle={speciesAlias=function(s) return s end,
    prepareData=function(cell) return cell end}
  local animated=assert(loadfile('lib/AnimatedBattleArt.lua'))({
    require=function() return battle end,
    data=function(name) return name=='animated_battle_sprites_gen4' and definitions or {} end,
    mod={assets={path=function(_,p) return p end}},
  })
  for species,row in pairs(definitions) do
    local def=row.front
    assert(def.legacyLayout, species..' missing original dimensions')
    for _,layout in ipairs({def,def.legacyLayout}) do
      local w,h=layout.width*def.columns,layout.height*math.ceil(def.frames/def.columns)
      local source={newImageData=function() return image(w,h) end}
      local frames,durations=animated.interfaceFront(species,'gen4','color',source)
      assert(frames and #frames==def.frames,species..' frame count/layout')
      assert(durations==def.durations,species..' timing changed')
      local last=frames[#frames]
      assert(last.width==layout.width and last.height==layout.height,species..' cell dimensions')
      assert(last.rect[1]==((def.frames-1)%def.columns)*layout.width
        and last.rect[2]==math.floor((def.frames-1)/def.columns)*layout.height,
        species..' final frame boundary')
      checks=checks+4
    end
    local bad={newImageData=function() return image(1,1) end}
    assert(animated.interfaceFront(species,'gen4','color',bad)==nil,
      species..' malformed atlas should retain the fallback')
    checks=checks+1
  end
end
print(checks..' Gen 4 tight/legacy metadata decoder checks passed')
