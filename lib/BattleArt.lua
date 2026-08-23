-- Minimal Battle Art species/shiny facade for the Gen 2 fork.
--
-- StadiumModels only needs two facts about a battler: which species to load
-- a model for, and whether it wears the shiny variant. Both are answered
-- from the engine's own battle records -- the same shapes the Gen 1 mod
-- read -- so no artwork or transform bookkeeping is required here.
--
-- Species: a Transform mid-fight wins (the battler's own transformed mark),
-- otherwise the monster record's species. A string species name resolves
-- through the battle's pokemon table to its dex number, because the Stadium
-- 2 importer indexes models by national dex (1..251 -- both regions).
--
-- Shiny: Gen 2's DV predicate. A battler without readable DVs simply is not
-- shiny; nothing here guesses.

local BattleArt = {}

local function monsterOf(battler)
  local mon = battler and (battler.mon or battler)
  return type(mon) == "table" and mon or nil
end

function BattleArt.isShiny(battler)
  local mon = monsterOf(battler)
  local dvs = mon and mon.dvs
  if type(dvs) ~= "table" then return false end
  local attack = tonumber(dvs.attack)
  local defense = tonumber(dvs.defense)
  local speed = tonumber(dvs.speed)
  local special = tonumber(dvs.special or dvs.specialAttack)
  if not (attack and defense and speed and special) then return false end
  -- The engine's own Gen 2 shiny test over the five-bit DV values.
  return attack % 32 == 10
     and defense % 32 == 10
     and speed % 32 == 10
     and special % 4 == 2
end

function BattleArt.speciesFor(battler)
  local mon = monsterOf(battler)
  return (battler and battler.__battleArtTransformed)
    or (mon and mon.species) or nil
end

return BattleArt
