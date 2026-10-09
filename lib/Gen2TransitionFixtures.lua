-- Exact remaining domestic stair drawings that were still flat after the
-- authored cave/radio/mansion/facility/ship stair families. Render-only:
-- warp and collision tables are never replaced.
local V=...
local M={MAX_QUADS=160}
local function key(x,z)return(z+64)*4096+x+64 end
local specs={
 PLAYERS_HOUSE_1F={x=9,z=0,tiles={0x4C,0x4D,0x5C,0x5D},up=true,dest='PLAYERS_HOUSE_2F'},
 REDS_HOUSE_1F={x=7,z=0,tiles={0x4C,0x4D,0x5C,0x5D},up=true,dest='REDS_HOUSE_2F'},
 COPYCATS_HOUSE_1F={x=2,z=0,tiles={0x4C,0x4D,0x5C,0x5D},up=true,dest='COPYCATS_HOUSE_2F'},
 PLAYERS_HOUSE_2F={x=7,z=0,tiles={0x40,0x41,0x50,0x51},up=false,dest='PLAYERS_HOUSE_1F'},
 REDS_HOUSE_2F={x=7,z=0,tiles={0x4E,0x4F,0x5E,0x5F},up=false,dest='REDS_HOUSE_1F'},
 COPYCATS_HOUSE_2F={x=3,z=0,tiles={0x4E,0x4F,0x5E,0x5F},up=false,dest='COPYCATS_HOUSE_1F'},
 TRAINER_HOUSE_1F={x=8,z=2,tiles={0x4C,0x4D,0x5C,0x5D},up=false,dest='TRAINER_HOUSE_B1F'},
 TRAINER_HOUSE_B1F={x=9,z=4,tiles={0x10,0x11,0x20,0x21},up=true,dest='TRAINER_HOUSE_1F'},
}
local function hasWarp(map,spec)
 for _,warp in ipairs(map.def.warps or{})do
  if warp.x==spec.x and warp.y==spec.z and warp.destMap==spec.dest then return true end
 end
 return false
end
function M.build(S,map,data,perRow)
 if not(S and map and map.def and map.def.generation==2 and data and not S.outdoor)
    or S.transitionFixtures then return 0 end
 local id=map.id or map.def.id;local spec=specs[id]
 if not spec or not hasWarp(map,spec)then return 0 end
 local x,z=spec.x*2,spec.z*2
 local actual={map:tileAt(x,z),map:tileAt(x+1,z),map:tileAt(x,z+1),map:tileAt(x+1,z+1)}
 for i=1,4 do if actual[i]~=spec.tiles[i]then return 0 end end
 local class=spec.up and'stair_e'or'stair_down_w'
 for dz=0,1 do for dx=0,1 do local k=key(x+dx,z+dz)
  S.shapeAt[k]={class=class,art='stair',authored=true,flat=false,h=16}
 end end
 S.transitionFixtures={quads=0,pinned=1,id=id,x=x,z=z,
  direction=spec.up and'up_e'or'down_w'}
 return 1
end
return M
