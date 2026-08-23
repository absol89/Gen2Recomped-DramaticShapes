local BattleVisibility = {}

local function picHidden(battle, battler)
  local pf = battle.picFx and battle.picFx[battler]
  return pf and pf.hidden or false
end

function BattleVisibility.sideVisible(battle, side)
  if side == "enemy" then
    if battle.showEnemyTrainer and battle.trainerPic then return true end
    return (battle.enemy and battle.enemy.sprite and not battle.enemyHidden
            and not battle.enemySendingOut and not battle.lockedBall
            and not picHidden(battle, battle.enemy)
            and not battle:fxHidden(battle.enemy)) and true or false
  end
  if battle.showPlayerBack and battle.playerBackPic then return true end
  local hide = battle.safari or battle.demo
  return (battle.player and battle.player.sprite and not hide
          and not battle.sendingOut and not picHidden(battle, battle.player)
          and not battle:fxHidden(battle.player)) and true or false
end

return BattleVisibility
