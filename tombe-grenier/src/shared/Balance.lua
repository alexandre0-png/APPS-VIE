--[[
  Balance : difficulté distincte en solo et en duo. Les valeurs de Config.Balance s'appliquent par-dessus
  le niveau Config.Difficulty : vitesse de poursuite et ouïe du monstre (facteurs), durées de recherche,
  délai d'attaque surprise, vies par joueur, délai des indices. apply() part toujours des valeurs de base
  (mémorisées au premier appel) : l'appeler deux fois ne cumule rien.
]]
local Balance = {}

local base = nil

-- Calcul pur : valeurs du monstre et vies pour un mode, à partir des valeurs de base
function Balance.compute(baseMonster, baseLives, balance, mode)
	local b = balance[mode] or balance.solo
	return {
		ChaseSpeed = baseMonster.ChaseSpeed * b.chase,
		HearRange = baseMonster.HearRange * b.hear,
		LoseTargetTime = b.loseTarget,
		SearchTime = b.search,
		SurpriseGap = b.surpriseGap,
		lives = b.lives,
		hintDelay = b.hintDelay,
	}
end

-- Applique le mode à Config (partie en cours) ; renvoie les valeurs calculées
function Balance.apply(Config, mode)
	if not base then
		base = {
			ChaseSpeed = Config.Monster.ChaseSpeed,
			HearRange = Config.Monster.HearRange,
			Lives = Config.Player.Lives,
			HintDelay = Config.Quests.HintDelay,
		}
	end
	local v = Balance.compute(base, base.Lives, Config.Balance, mode)
	Config.Monster.ChaseSpeed = v.ChaseSpeed
	Config.Monster.HearRange = v.HearRange
	Config.Monster.LoseTargetTime = v.LoseTargetTime
	Config.Monster.SearchTime = v.SearchTime
	Config.Monster.SurpriseGap = v.SurpriseGap
	Config.Player.Lives = v.lives
	Config.Quests.HintDelay = v.hintDelay
	return v
end

return Balance
