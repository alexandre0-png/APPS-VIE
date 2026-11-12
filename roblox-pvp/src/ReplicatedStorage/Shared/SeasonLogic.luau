--!strict
-- Saison : points gagnés au combat, paliers et récompenses (logique pure).
local SeasonLogic = {}

export type SeasonState = { Id: number, Points: number, Claimed: { [string]: boolean } }

-- Nombre de paliers atteints (0..tiers).
function SeasonLogic.Tier(points: number, tierPoints: number, tiers: number): number
	return math.clamp(math.floor(math.max(0, points) / tierPoints), 0, tiers)
end

function SeasonLogic.TierCoins(tier: number, perTier: number): number
	return tier * perTier
end

-- Remet à zéro la progression si la saison a changé. Renvoie vrai si une remise à zéro a eu lieu.
function SeasonLogic.Rollover(state: SeasonState, currentId: number): boolean
	if state.Id ~= currentId then
		state.Id = currentId
		state.Points = 0
		state.Claimed = {}
		return true
	end
	return false
end

return SeasonLogic
