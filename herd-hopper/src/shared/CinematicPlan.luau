-- Plans des cinématiques (purs : testés avec Lune). Décrit les séquences, leur état (durée, passage, reprise)
-- et décide lesquelles jouer. L'application (caméra, textes) est faite côté client par Cinematics.

local Config = require(script.Parent.Config)
local Species = require(script.Parent.Species)

local Plan = {}

-- Séquences : liste de plans { dur = secondes, cam = "orbit" | "flyover" | "none", caption, sub }.
Plan.sequences = {
	intro = {
		{ dur = 4, cam = "orbit", caption = "Un zoo, ça se remplit !", sub = "Bienvenue, gardienne ou gardien." },
		{ dur = 4, cam = "orbit", caption = "Ta tante t'a laissé ce zoo.", sub = "Il est vide... pour l'instant." },
		{
			dur = 4,
			cam = "orbit",
			caption = "Pars en expédition !",
			sub = "Saute d'animal en animal. Le sol est mortel !",
		},
		{
			dur = 4,
			cam = "orbit",
			caption = "Un cœur rose ?",
			sub = "Récupère l'animal : il rejoint ton zoo et rapporte de l'or.",
			heart = true,
		},
	},
	tutorial = {
		{
			dur = 5,
			cam = "none",
			caption = "SAUTER",
			sub = "Appuie sur ESPACE (ou le bouton SAUTER) pour quitter ton animal.",
		},
		{
			dur = 5,
			cam = "none",
			caption = "LASSO DE SAUT",
			sub = "En l'air, maintiens ESPACE : tu t'accroches à l'animal suivant.",
		},
		{
			dur = 5,
			cam = "none",
			caption = "CŒUR ROSE",
			sub = "Reste en selle jusqu'à la barre pleine, puis appuie sur RÉCUPÉRER (E).",
			heart = true,
		},
		{
			dur = 5,
			cam = "none",
			caption = "LASSO DE CAPTURE",
			sub = "Appuie sur Q (ou LASSO) pour attraper de loin un animal à cœur.",
		},
	},
}

-- Séquence d'aperçu d'une zone (index 2 à 4) et de capture d'un boss : construites à partir de la config.
function Plan.zoneSequence(zoneIndex)
	local zone = Config.Zones[zoneIndex]
	if not zone then
		return nil
	end
	local names = {}
	for _, id in ipairs(zone.animals) do
		table.insert(names, Species.ById[id].name)
	end
	local boss = Species.ById[zone.boss]
	return {
		{
			dur = 4,
			cam = "flyover",
			caption = "NOUVELLE ZONE : " .. zone.name,
			sub = "Tu peux maintenant y partir en expédition !",
		},
		{
			dur = 4,
			cam = "flyover",
			caption = "Danger : " .. zone.hazard.name,
			sub = "Animaux : " .. table.concat(names, ", ") .. ".",
		},
		{ dur = 4, cam = "flyover", caption = "Un boss rôde", sub = boss.name .. " t'attend au bout de la zone." },
	}
end

function Plan.bossSequence(bossId)
	local def = Species.ById[bossId]
	if not def or not def.boss then
		return nil
	end
	return {
		{ dur = 4, cam = "orbit", caption = "BOSS CAPTURÉ !", sub = def.name .. " rejoint ton zoo !", heart = true },
		{ dur = 4, cam = "orbit", caption = "Quelle prise !", sub = "Un boss rapporte énormément d'or à ton zoo." },
		{ dur = 3, cam = "orbit", caption = "Et ce n'est que le début...", sub = "Continue d'explorer les zones." },
	}
end

-- Renvoie la séquence d'une clé ("intro", "tutorial", "zone_2", "boss_elephant") ou nil si la clé est invalide.
function Plan.sequenceFor(key)
	if type(key) ~= "string" then
		return nil
	end
	if Plan.sequences[key] then
		return Plan.sequences[key]
	end
	local zoneIndex = key:match("^zone_(%d+)$")
	if zoneIndex then
		local index = tonumber(zoneIndex)
		if index and index >= 2 then
			return Plan.zoneSequence(index)
		end
		return nil
	end
	local bossId = key:match("^boss_(.+)$")
	if bossId then
		return Plan.bossSequence(bossId)
	end
	return nil
end

function Plan.validKey(key)
	return Plan.sequenceFor(key) ~= nil
end

function Plan.total(shots)
	local total = 0
	for _, shot in ipairs(shots) do
		total = total + shot.dur
	end
	return total
end

-- Plan en cours à t secondes : renvoie index, progression (0..1) dans le plan, ou nil une fois la séquence finie.
function Plan.shotAt(shots, t)
	local acc = 0
	for index, shot in ipairs(shots) do
		if t < acc + shot.dur then
			return index, (t - acc) / shot.dur
		end
		acc = acc + shot.dur
	end
	return nil, 1
end

-- ---------------------------------------------------------------- état (passage et reprise)

function Plan.newState(shots, maxSeconds)
	return {
		shots = shots,
		t = 0,
		total = math.min(Plan.total(shots), maxSeconds or math.huge),
		skipped = false,
		done = false,
	}
end

function Plan.step(state, dt)
	if state.done then
		return state
	end
	state.t = state.t + dt
	if state.t >= state.total then
		state.t = state.total
		state.done = true
	end
	return state
end

function Plan.skip(state)
	if not state.done then
		state.skipped = true
		state.done = true
	end
	return state
end

-- Faut-il considérer la cinématique comme vue ? Oui si elle est allée au bout, a été passée, ou a duré assez
-- longtemps ; sinon (interrompue tout de suite, par exemple par un départ en expédition) elle sera reproposée.
function Plan.completed(state)
	return state.done or state.t >= math.min(3, state.total * 0.25)
end

-- ---------------------------------------------------------------- décision

-- Cinématiques à jouer, dans l'ordre. data = instantané du profil (seen, zones, bossCaptured).
function Plan.pending(data, cfg)
	local list = {}
	if not cfg.Enabled or type(data) ~= "table" then
		return list
	end
	local seen = data.seen or {}
	if cfg.Intro and not seen.intro then
		table.insert(list, "intro")
	end
	if cfg.Tutorial and not seen.tutorial then
		table.insert(list, "tutorial")
	end
	if cfg.ZoneOpening and data.zones then
		for index = 2, #Config.Zones do
			local key = "zone_" .. index
			if data.zones[Config.Zones[index].key] and not seen[key] then
				table.insert(list, key)
			end
		end
	end
	if cfg.BossCaptured and data.bossCaptured then
		for index = 1, #Config.Zones do
			local bossId = Config.Zones[index].boss
			local key = "boss_" .. bossId
			if data.bossCaptured[bossId] and not seen[key] then
				table.insert(list, key)
			end
		end
	end
	return list
end

return Plan
