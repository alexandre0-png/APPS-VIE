--[[
  Ranks : rangs, titres et points de progression (affichés au hub). Logique pure, testée.
  Profil : { points, runs, endings = { [fin] = n }, challenges = { [id] = true }, tutorialDone, seeds = { ... } }
]]
local Ranks = {}

-- Seuil de points -> nom du rang, du plus bas au plus haut
Ranks.LIST = {
	{ points = 0, name = "Visiteur" },
	{ points = 20, name = "Curieux" },
	{ points = 60, name = "Rôdeur" },
	{ points = 130, name = "Veilleur" },
	{ points = 250, name = "Survivant" },
	{ points = 450, name = "Gardien du grenier" },
}

function Ranks.newProfile()
	return { points = 0, runs = 0, endings = {}, challenges = {}, tutorialDone = false, seeds = {}, lastDay = 0 }
end

-- Complète un profil lu depuis la sauvegarde (champs absents ou invalides remplacés)
function Ranks.normalize(p)
	local out = Ranks.newProfile()
	if type(p) ~= "table" then
		return out
	end
	out.points = type(p.points) == "number" and math.max(0, math.floor(p.points)) or 0
	out.runs = type(p.runs) == "number" and math.max(0, math.floor(p.runs)) or 0
	out.tutorialDone = p.tutorialDone == true
	out.lastDay = type(p.lastDay) == "number" and math.floor(p.lastDay) or 0
	for k, v in pairs(type(p.endings) == "table" and p.endings or {}) do
		if type(k) == "string" and type(v) == "number" then
			out.endings[k] = v
		end
	end
	for k, v in pairs(type(p.challenges) == "table" and p.challenges or {}) do
		if type(k) == "string" and v == true then
			out.challenges[k] = true
		end
	end
	for _, s in ipairs(type(p.seeds) == "table" and p.seeds or {}) do
		if type(s) == "number" then
			table.insert(out.seeds, s)
		end
	end
	if type(p.title) == "string" then
		out.title = p.title
	end
	return out
end

function Ranks.rankIndex(points)
	local idx = 1
	for i, r in ipairs(Ranks.LIST) do
		if points >= r.points then
			idx = i
		end
	end
	return idx
end

function Ranks.rankName(points)
	return Ranks.LIST[Ranks.rankIndex(points)].name
end

-- Points restants avant le rang suivant (nil au rang maximal)
function Ranks.toNext(points)
	local nextRank = Ranks.LIST[Ranks.rankIndex(points) + 1]
	return nextRank and (nextRank.points - points) or nil
end

-- Texte affiché au-dessus d'un joueur : « Rôdeur · Fantôme » (titre éventuel)
function Ranks.label(profile)
	local text = Ranks.rankName(profile.points)
	if profile.title then
		text = text .. " · " .. profile.title
	end
	return text
end

-- Points gagnés pour une partie : result = { ending, mode, challenges = { ids terminés } }
function Ranks.pointsFor(cfg, result)
	local pts = cfg.PointsPerRun + (cfg.PointsPerEnding[result.ending] or 0)
	pts += cfg.PointsPerChallenge * #(result.challenges or {})
	if result.mode == "duo" then
		pts += cfg.DuoBonus
	end
	return pts
end

-- Met le profil à jour (modifié sur place). Renvoie { gained, rankUp = nom du nouveau rang ou nil }
-- titles : table { [challengeId] = titre } ; le dernier défi terminé donne le titre affiché.
function Ranks.award(cfg, profile, result, titles)
	local before = Ranks.rankIndex(profile.points)
	local gained = Ranks.pointsFor(cfg, result)
	profile.points += gained
	profile.runs += 1
	profile.endings[result.ending] = (profile.endings[result.ending] or 0) + 1
	for _, id in ipairs(result.challenges or {}) do
		profile.challenges[id] = true
		if titles and titles[id] then
			profile.title = titles[id]
		end
	end
	local after = Ranks.rankIndex(profile.points)
	return { gained = gained, rankUp = after > before and Ranks.LIST[after].name or nil }
end

return Ranks
