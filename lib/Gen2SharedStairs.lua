-- Shared Crystal stair drawings that are flat in the extracted collision
-- grid. Signatures are exact per tileset and were swept across every map;
-- presentation claims never replace native warp or collision tables.
local V=...
local M={MAX_QUADS=900}
local function key(x,z)return(z+64)*4096+x+64 end
local families={
 TilesetLighthouse={['41:42:57:58']='stair_e',['39:40:55:56']='stair_down_w'},
 TilesetMansion={['10:11:26:27']='stair_e',['8:9:24:25']='stair_down_e'},
 TilesetRadioTower={['12:13:28:29']='stair_e',['14:15:30:31']='stair_down_w'},
 TilesetTower={['12:13:28:29']='stair_e',['14:15:30:31']='stair_down_w'},
 TilesetUnderground={['3:4:19:20']='stair_e'},
}
local function sig(map,x,z)
 return table.concat({map:tileAt(x,z),map:tileAt(x+1,z),
  map:tileAt(x,z+1),map:tileAt(x+1,z+1)},':')
end
local function pin(S,x,z,class)
 for dz=0,1 do for dx=0,1 do local k=key(x+dx,z+dz)
  S.shapeAt[k]={class=class,art='stair',authored=true,flat=false,h=16}
 end end
end
function M.build(S,map,data,perRow)
 if not(S and map and map.def and map.def.generation==2 and map.tileset and data)
  or S.outdoor or S.sharedStairs then return 0 end
 local patterns=families[map.tileset.id];if not patterns then return 0 end
 local up,down=0,0
 for cz=0,map.heightCells-1 do for cx=0,map.widthCells-1 do
  local x,z=cx*2,cz*2;local class=patterns[sig(map,x,z)]
  if class then
   -- Feed Crystal's exact drawings into the proven Gen 1 stair builder.
   -- It produces a full 16px east/west flight, textured risers and treads,
   -- a sealed upper landing, or a genuinely excavated down-stair well.
   pin(S,x,z,class)
   if class:find('down',1,true)then down=down+1 else up=up+1 end
  end
 end end
 if up+down==0 then return 0 end
 S.sharedStairs={quads=0,pinned=up+down,up=up,down=down,map=map.id or map.def.id,
  tileset=map.tileset.id}
 return up+down
end
return M
