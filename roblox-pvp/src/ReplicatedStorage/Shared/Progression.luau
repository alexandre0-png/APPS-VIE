--!strict
-- Courbe d'expérience et titres (fonctions pures).
local Progression = {}

-- XP nécessaire pour passer du niveau `level` au niveau suivant.
function Progression.XpToNext(level: number): number
	return 80 + level * 40
end

-- Ajoute de l'XP et renvoie (niveau, xp, niveaux gagnés).
function Progression.AddXp(level: number, xp: number, gained: number, maxLevel: number): (number, number, number)
	local levelsGained = 0
	xp += math.max(0, math.floor(gained))
	while level < maxLevel and xp >= Progression.XpToNext(level) do
		xp -= Progression.XpToNext(level)
		level += 1
		levelsGained += 1
	end
	if level >= maxLevel then
		xp = 0
	end
	return level, xp, levelsGained
end

function Progression.LevelUpReward(level: number): number
	return 40 * level
end

function Progression.TitleFor(level: number, titles: { { any } }): string
	local current = titles[1][2] :: string
	for _, entry in ipairs(titles) do
		if level >= (entry[1] :: number) then
			current = entry[2] :: string
		end
	end
	return current
end

return Progression
