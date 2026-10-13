-- Finite Gen 2 interior finish plans. Shared tilesets such as Facility,
-- GameCorner, IcePath and Cave serve unrelated maps, so ambiguous sets are
-- admitted by exact map id rather than by tileset-wide guesses.
local M={}
local plans={
 house={'plaster_beams','pinstripe','domestic'},
 house_coffer={'johto_coffer','pinstripe','johto_lantern'},
 house_planks={'johto_beams','pinstripe','johto_panel'},
 elm_lab={'lab_panels','lab_band','fluorescent'},
 lab={'lab_panels','clinical_band','fluorescent'},
 center={'clinical','clinical_band','round'},
 mart={'shop_tiles','shop_band','fluorescent'},
 traditional={'traditional','timber','lantern'},
 station={'industrial','wainscot','fluorescent'},
 institutional={'clinical','wainscot','fluorescent'},
 tower={'traditional','timber','lantern'},
 casino={'coffer','wainscot','round'},
 ship={'planks','wainscot','round'},
 elite={'coffer','stone','round'},
 industrial={'industrial','clinical_band','fluorescent'},
}
local function normalized(value)
 return tostring(value or''):upper():gsub('^TILESET_?',''):gsub('_','')
end
local function houseStyle(id)
 local name=id:gsub('_%d+F$',''):gsub('_B%d+F$','');local h=0
 for i=1,#name do h=(h*31+name:byte(i))%65521 end
 return({'house','house_coffer','house_planks'})[h%3+1]
end
local scoped={
 MR_POKEMONS_HOUSE={'FACILITY','domestic'},
 RUINS_OF_ALPH_RESEARCH_CENTER={'FACILITY','lab'},
 POWER_PLANT={'FACILITY','industrial'},
 SILPH_CO_1F={'FACILITY','institutional'},
 TRAINER_HOUSE_B1F={'FACILITY','institutional'},
 GOLDENROD_BIKE_SHOP={'CHAMPIONSROOM','mart'},
 CELADON_MANSION_1F={'MANSION','domestic'},CELADON_MANSION_2F={'MANSION','domestic'},
 CELADON_MANSION_3F={'MANSION','domestic'},
 OLIVINE_CAFE={'GAMECORNER','traditional'},CELADON_CAFE={'GAMECORNER','traditional'},
 CELADON_GAME_CORNER={'GAMECORNER','casino'},CELADON_GAME_CORNER_PRIZE_ROOM={'GAMECORNER','casino'},
 GOLDENROD_GAME_CORNER={'GAMECORNER','casino'},SAFARI_ZONE_MAIN_OFFICE={'GAMECORNER','institutional'},
 BATTLE_TOWER_1F={'BATTLETOWERINSIDE','institutional'},
 BATTLE_TOWER_BATTLE_ROOM={'BATTLETOWERINSIDE','institutional'},
 BATTLE_TOWER_ELEVATOR={'BATTLETOWERINSIDE','institutional'},
 BATTLE_TOWER_HALLWAY={'BATTLETOWERINSIDE','institutional'},
 BRUNOS_ROOM={'ELITEFOURROOM','elite'},WILLS_ROOM={'ELITEFOURROOM','elite'},
 KARENS_ROOM={'ELITEFOURROOM','elite'},KOGAS_ROOM={'ELITEFOURROOM','elite'},
 LANCES_ROOM={'CHAMPIONSROOM','elite'},
 FAST_SHIP_1F={'LIGHTHOUSE','ship'},FAST_SHIP_B1F={'LIGHTHOUSE','ship'},
 HALL_OF_FAME={'ICEPATH','elite'},SEAFOAM_GYM={'CAVE','elite'},
 POKECOM_CENTER_ADMIN_OFFICE_MOBILE={'POKECOMCENTER','institutional'},
 OLIVINE_PORT_PASSAGE={'UNDERGROUND','station'},VERMILION_PORT_PASSAGE={'UNDERGROUND','station'},
}
function M.resolve(mapId,tilesetId)
 local id=tostring(mapId or''):upper();local ts=normalized(tilesetId);local kind
 if id:match('_ROOF$')or id=='SAFARI_ZONE_BETA'then return nil end
 local exact=scoped[id]
 if exact then
  if ts~=exact[1]then return nil end
  kind=exact[2]=='domestic'and houseStyle(id)or exact[2]
 elseif ts=='FOREST'or ts=='CAVE'or ts=='DARKCAVE'or ts=='ICEPATH'or ts=='JOHTO'or ts=='KANTO'then
  return nil
 elseif id=='ELMS_LAB'then kind='elm_lab'
 elseif id=='DRAGON_SHRINE'or id=='EARLS_POKEMON_ACADEMY'then kind='traditional'
 elseif id:find('GYM',1,true)or id=='FIGHTING_DOJO'then kind='institutional'
 elseif ts=='TRADITIONALHOUSE'or id=='DANCE_THEATER'then kind='traditional'
 elseif ts=='PLAYERSHOUSE'or ts=='PLAYERSROOM'then kind='house'
 elseif ts=='HOUSE'then kind=houseStyle(id)
 elseif ts=='LAB'then kind='lab'
 elseif ts=='POKECENTER'then kind='center'
 elseif ts=='MART'then kind='mart'
 elseif ts=='TRAINSTATION'then kind='station'
 elseif ts=='TOWER'and not id:find('BURNED_TOWER',1,true)then kind='tower'
 elseif ts=='GATE'or ts=='RADIOTOWER'or ts=='PORT'or ts=='LIGHTHOUSE'then kind='institutional'
 else return nil end
 local p=plans[kind]
 return{id=kind,ceiling=p[1],wallpaper=p[2],lights=p[3]}
end
return M
