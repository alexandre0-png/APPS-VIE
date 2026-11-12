--!strict
-- Logique de partie pure : spawn, équipes, vainqueurs.
local MatchLogic = {}

export type Point = { X: number, Z: number }
export type ScoreEntry = { Id: number, Score: number }
type Scored = { Index: number, Dist: number }

-- Choisit le point d'apparition le plus éloigné des ennemis (maximise la distance minimale).
function MatchLogic.PickSpawn(spawns: { Point }, enemies: { Point }, rand: number): number
	if #spawns == 0 then
		return 0
	end
	if #enemies == 0 then
		return math.clamp(math.floor(rand * #spawns) + 1, 1, #spawns)
	end
	local scored: { Scored } = {}
	for i, s in ipairs(spawns) do
		local minDist = math.huge
		for _, e in ipairs(enemies) do
			local dx, dz = s.X - e.X, s.Z - e.Z
			minDist = math.min(minDist, math.sqrt(dx * dx + dz * dz))
		end
		table.insert(scored, { Index = i, Dist = minDist })
	end
	table.sort(scored, function(a: Scored, b: Scored)
		return a.Dist > b.Dist
	end)
	-- on tire au hasard parmi les 3 meilleurs pour éviter la prévisibilité
	local pool = math.min(3, #scored)
	local pick = math.clamp(math.floor(rand * pool) + 1, 1, pool)
	return scored[pick].Index
end

-- Équipe à attribuer à un nouvel arrivant : la moins peuplée, sinon la moins bien classée.
function MatchLogic.BalanceTeam(redCount: number, blueCount: number, redScore: number, blueScore: number, rand: number): string
	if redCount < blueCount then
		return "Red"
	elseif blueCount < redCount then
		return "Blue"
	end
	if redScore < blueScore then
		return "Red"
	elseif blueScore < redScore then
		return "Blue"
	end
	return if rand < 0.5 then "Red" else "Blue"
end

-- Vainqueur(s) en mêlée générale : meilleur score strictement positif.
function MatchLogic.FFAWinners(entries: { ScoreEntry }): { number }
	local best = 0
	for _, e in ipairs(entries) do
		best = math.max(best, e.Score)
	end
	local winners = {}
	if best <= 0 then
		return winners
	end
	for _, e in ipairs(entries) do
		if e.Score == best then
			table.insert(winners, e.Id)
		end
	end
	return winners
end

-- "Red" | "Blue" | "Draw"
function MatchLogic.TeamWinner(red: number, blue: number): string
	if red > blue then
		return "Red"
	elseif blue > red then
		return "Blue"
	end
	return "Draw"
end

function MatchLogic.NextMode(modes: { string }, index: number): (string, number)
	local nextIndex = (index % #modes) + 1
	return modes[nextIndex], nextIndex
end

function MatchLogic.StreakLabel(streak: number): string?
	if streak == 2 then
		return "Double élimination !"
	elseif streak == 3 then
		return "Triple élimination !"
	elseif streak == 5 then
		return "Série de 5 : une prime est posée sur votre tête !"
	elseif streak == 7 then
		return "Inarrêtable !"
	elseif streak == 10 then
		return "LÉGENDAIRE !"
	elseif streak > 10 and streak % 5 == 0 then
		return "Divin !"
	end
	return nil
end

function MatchLogic.Bounty(streak: number, minStreak: number, perStreak: number, cap: number): number
	if streak < minStreak then
		return 0
	end
	return math.min(cap, streak * perStreak)
end

return MatchLogic
