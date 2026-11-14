--[[
  Challenges : défis optionnels, jamais obligatoires, évalués à la fin de chaque partie. Logique pure, testée.
  result = { ending = "lose" | "sealed" | "truth", mode = "solo" | "duo", duration = secondes, deaths = nombre }
  Un défi terminé une fois n'est plus compté (profil.challenges). Le défi du jour change chaque jour (UTC).
]]
local Challenges = {}

Challenges.LIST = {
	{ id = "sans_mort", title = "Sans une égratignure", text = "Terminer la partie sans mourir.",
	  test = function(r) return r.ending ~= "lose" and r.deaths == 0 end },
	{ id = "verite", title = "Porteur de vérité", text = "Libérer l'enfant (fin vérité).",
	  test = function(r) return r.ending == "truth" end },
	{ id = "express", title = "Sans hésiter", text = "Fin vérité en moins de 15 minutes.",
	  test = function(r) return r.ending == "truth" and r.duration <= 900 end },
	{ id = "solitaire", title = "Seul face au noir", text = "Fin vérité en solo.",
	  test = function(r) return r.ending == "truth" and r.mode == "solo" end },
	{ id = "duo_fidele", title = "Inséparables", text = "Fin vérité en duo, sans aucune mort.",
	  test = function(r) return r.ending == "truth" and r.mode == "duo" and r.deaths == 0 end },
	{ id = "piege", title = "Pris au piège", text = "Découvrir la fin du piège.",
	  test = function(r) return r.ending == "sealed" end },
}

local BY_ID = {}
for _, c in ipairs(Challenges.LIST) do
	BY_ID[c.id] = c
end

function Challenges.get(id)
	return BY_ID[id]
end

-- { [id] = titre } pour Ranks.award
function Challenges.titles()
	local out = {}
	for _, c in ipairs(Challenges.LIST) do
		out[c.id] = c.title
	end
	return out
end

-- Défis réussis pour cette partie et pas encore dans le profil ; completed = profil.challenges
function Challenges.evaluate(result, completed)
	local out = {}
	for _, c in ipairs(Challenges.LIST) do
		if not (completed and completed[c.id]) and c.test(result) then
			table.insert(out, c.id)
		end
	end
	return out
end

-- Défi du jour : jour = secondes Unix // 86400
function Challenges.daily(day)
	return Challenges.LIST[(day % #Challenges.LIST) + 1]
end

return Challenges
