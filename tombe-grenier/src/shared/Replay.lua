--[[
  Replay : graines de partie. Une nouvelle partie évite les graines récentes du joueur ;
  la graine du jour est la même pour tout le monde (défi quotidien). Logique pure, testée.
]]
local Replay = {}

local MODULUS = 2147483646

function Replay.day(unixSeconds)
	return math.floor(unixSeconds / 86400)
end

function Replay.dailySeed(day)
	return (day * 7919 + 104729) % MODULUS + 1
end

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- Tire une graine absente des `avoid` dernières du historique ; draw() renvoie un entier de 1 à MODULUS
function Replay.fresh(history, avoid, draw)
	local recent = {}
	for i = math.max(1, #history - avoid + 1), #history do
		table.insert(recent, history[i])
	end
	local seed = draw()
	for _ = 1, 20 do
		if not contains(recent, seed) then
			break
		end
		seed = draw()
	end
	return seed
end

-- Ajoute une graine à l'historique (taille bornée)
function Replay.push(history, seed, keep)
	table.insert(history, seed)
	while #history > keep do
		table.remove(history, 1)
	end
end

return Replay
