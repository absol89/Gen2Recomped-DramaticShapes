-- Original eight-pixel domestic wallpapers; no imported art or extra GPU
-- resources. A donor is replaced only after its raw art identity and every
-- map use prove it is an undecorated wall. Bake targets the PRIVATE atlas copy.
-- Native donor audit: TilesetHouse has no Buildings templates; furniture
-- material donors use their own nonzero tiles. Reaudit if host models change.
-- Player floors use wall-only 0x11/0x02; kitchen/electronics/shelf patterns
-- use separate source cells. Exact map+tileset gates prohibit global repaint.
local V=...
local TileShape=V and V.require and V.require('TileShape')
local M={MAX_MAP_TILES=4096}
local floor=math.floor
local playerPlanks={'21111110','21111110','21121110','21121110','21111110','21112110','21112110','21111110'}
local styles={
 OLIVINE_TIMS_HOUSE={style='warm_linen',colors={{237,222,188},{208,185,146},{250,238,209},{130,95,63}},
  rows={'00000000','00000000','00000000','00000000','10001000','00000000','00000000','00000000'}},
 PLAYERS_NEIGHBORS_HOUSE={style='sage_floret',colors={{183,202,163},{105,135,83},{220,235,183},{137,98,62}},
  rows={'00000000','00020000','00212000','00010000','00110000','00000000','00000000','00000000'}},
 BLUES_HOUSE={style='buttercream_ticking',colors={{242,220,160},{170,139,83},{255,230,170},{134,95,59}},
  rows={'00100100','00100100','00100100','00100100','00100100','00100100','00100100','00100100'}},
 CHERRYGROVE_EVOLUTION_SPEECH_HOUSE={style='peach_sprig',colors={{235,185,151},{158,100,69},{255,218,180},{125,84,51}},
  rows={'00000000','00010000','00121000','00010000','00011000','00000000','00000000','00000000'}},
}
local function finite(n)return type(n)=='number'and n==n and n>-math.huge and n<math.huge end
function M.resolve(map)
 if not(map and map.def and map.tileset)then return end
 local center=map.tileset.id=='TilesetPokecenter' and map.def.generation==2
 local id=map.id or map.def.id
 local player=map.def.generation==2 and ((id=='PLAYERS_HOUSE_1F' and map.tileset.id=='TilesetPlayersHouse')
  or (id=='PLAYERS_HOUSE_2F' and map.tileset.id=='TilesetPlayersRoom'))
 local s
 if center then
  s={style='center_ivory_coral',colors={{223,156,142},{172,58,57},{255,244,219},{210,137,124}},
   rows={'00000000','00000000','00000000','00000000','00000000','00000000','00000000','00000000'}}
 elseif player then
  -- Both floors share a warm hometown paper, including their native lower
  -- walls. Sparse rose stitching gives the player's own house personality
  -- without becoming a loud repeated motif at room scale.
  s={style='player_warm_paper',colors={{242,218,180},{205,142,126},{255,238,204},{142,105,72}},
   rows={'00000000','00000000','00000000','00100000','00010000','00000000','00000000','00000000'}}
 elseif map.tileset.id=='TilesetHouse' then s=styles[id] end
 if not s then return end
 local colors={}
 for i,c in ipairs(s.colors)do colors[i]={c[1]/255,c[2]/255,c[3]/255,1}end
 return{tile=player and (id=='PLAYERS_HOUSE_1F' and 0x11 or 0x02) or (center and 2 or 0),
  fingerprint=player and playerPlanks or nil,style=s.style,colors=colors,rows={unpack(s.rows)},
  wall={0,0},ceiling={7,7},wood={7,6},trim={6,7}}
end
function M.prove(map,source,shapes)
 local descriptor=M.resolve(map)
 if not descriptor then return nil,'unsupported room'end
 if not(source and type(source.getPixel)=='function'and type(source.getDimensions)=='function'
  and TileShape and type(TileShape.at)=='function'and type(TileShape.forMap)=='function'
  and type(map.tileAt)=='function'and type(map.warpAtCell)=='function'
  and type(map.isWarpTileCell)=='function')then return nil,'missing evidence'end
 if map.def.connections and next(map.def.connections)then return nil,'connected room'end
 local tw,th=map.def.width,map.def.height
 if not finite(tw)or not finite(th)then return nil,'invalid bounds'end
 tw,th=tw*4,th*4
 if tw<1 or th<1 or tw~=floor(tw)or th~=floor(th)or tw*th>M.MAX_MAP_TILES then return nil,'unbounded room'end
 local ok,w,h=pcall(source.getDimensions,source)
 if not ok or not finite(w)or not finite(h)or w<8 or h<8 or w%8~=0 or h%8~=0 then return nil,'invalid source'end
 local ox,oy=(descriptor.tile%(w/8))*8,floor(descriptor.tile/(w/8))*8
 if oy+8>h then return nil,'invalid source'end
 -- Exact observed grayscale stripes or player plank fingerprint. A single
 -- art/alpha modification protects the tile.
 for y=0,7 do for x=0,7 do
  local expected=descriptor.tile==2 and (y%2==0 and 1/3 or 0) or (y%4==0 and 2/3 or 1/3)
  if descriptor.fingerprint then expected=tonumber(descriptor.fingerprint[y+1]:sub(x+1,x+1))/3 end
  local valid,r,g,b,a=pcall(source.getPixel,source,ox+x,oy+y)
  if not valid or not finite(r)or not finite(g)or not finite(b)or not finite(a)
   or math.abs(r-expected)>.00001 or math.abs(g-expected)>.00001
   or math.abs(b-expected)>.00001 or math.abs(a-1)>.00001 then return nil,'source art protected'end
 end end
 if not shapes then
  local valid,result=pcall(TileShape.forMap,map)
  if not valid or type(result)~='table'then return nil,'shape evidence unavailable'end
  shapes=result
 end
 local uses=0
 for z=0,th-1 do for x=0,tw-1 do
  local valid,tile=pcall(map.tileAt,map,x,z)
  if not valid or not finite(tile)then return nil,'tile evidence unavailable'end
  if tile==descriptor.tile then
   uses=uses+1
   local classified,s=pcall(TileShape.at,map,shapes,tile,x,z)
   if not classified or type(s)~='table'or s.class~='wall'or s.art~='upright'
    or s.authored~=false or s.flat~=false or s.h~=16 then return nil,'shared or authored tile'end
   local cx,cy=floor(x/2),floor(z/2)
   for _,method in ipairs({'warpAtCell','isWarpTileCell'})do
    local called,hit=pcall(map[method],map,cx,cy)
    if not called or hit then return nil,'door or unknown warp'end
   end
   for _,list in ipairs({map.def.warps or{},map.warps or{}})do
    for _,warp in ipairs(list)do if warp.x==cx and warp.y==cy then return nil,'door record'end end
   end
   if map.doorTiles then
    if type(map.cellTile)~='function'then return nil,'door evidence unavailable'end
    local called,cell=pcall(map.cellTile,map,cx,cy)
    if not called or map.doorTiles[cell]then return nil,'door art'end
   end
  end
 end end
 if uses==0 then return nil,'wall tile absent'end
 descriptor.uses=uses
 return descriptor
end
function M.bake(map,image,source,shapes)
 if image==source or not(image and type(image.setPixel)=='function'and type(image.getDimensions)=='function')then
  return nil,'private output required'
 end
 local d,reason=M.prove(map,source,shapes)
 if not d then return nil,reason end
 local ok,w,h=pcall(image.getDimensions,image)
 local valid,sw,sh=pcall(source.getDimensions,source)
 if not ok or not valid or w~=sw or h~=sh then return nil,'atlas bounds mismatch'end
 local ox,oy=(d.tile%(w/8))*8,floor(d.tile/(w/8))*8
 for y=0,7 do for x=0,7 do
  local color=tonumber(d.rows[y+1]:sub(x+1,x+1))+1
  if x==0 and y==0 then color=1
  elseif x==7 and y==7 then color=3
  elseif x==7 and y==6 then color=4
  elseif x==6 and y==7 then color=2 end
  local c=d.colors[color];image:setPixel(ox+x,oy+y,c[1],c[2],c[3],1)
 end end
 return d
end
return M
