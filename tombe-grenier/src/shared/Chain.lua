--[[
  Chain : la chaîne de progression, strictement séquentielle (données pures, testées).
  Une seule étape est active à la fois : la première qui n'est pas faite. Une étape ne peut s'accomplir que
  si toutes les précédentes sont faites (canAct). Le serveur applique cette règle à chaque action ;
  le client n'a aucun rôle dans l'état de la partie.

  Ordre : grenier (papier, reflet, coffret, malle, clé) -> étages (mélodie, horloge, statues, photos) ->
  sortie par la porte d'entrée -> sous-sol (porte de la cave, puis la cave) -> l'enfant, enfermé dans une cage au fond
  de la cave -> retour dehors par le sous-sol. L'enfant n'est sauvable qu'après être entré dans la cave.
]]
local Chain = {}

-- id, lieu, objectif affiché, indice, message de verrou (quand on tente cette étape trop tôt)
Chain.STEPS = {
	{
		id = "note",
		area = "grenier",
		objective = "Trouve le papier du code, dans le grenier",
		hint = "Un papier froissé se cache sur une surface plate, dans le grenier.",
	},
	{
		id = "reflet",
		area = "grenier",
		objective = "Lis les deux derniers chiffres dans un miroir (le texte est à l'envers)",
		hint = "Un miroir garde la fin du code. Le texte y est écrit à l'envers.",
	},
	{
		id = "coffret",
		area = "grenier",
		objective = "Ouvre le coffret à bijoux avec le code complet",
		hint = "Le coffret à bijoux est posé sur la table de la salle de la tombe.",
	},
	{
		id = "chest",
		area = "grenier",
		objective = "Ouvre la malle du grenier avec la petite clé",
		hint = "La petite clé du coffret ouvre la malle, dans la salle de la tombe.",
	},
	{
		id = "key",
		area = "grenier",
		objective = "Prends la clé rouillée dans la malle",
		hint = "La clé rouillée est au fond de la malle.",
	},
	{
		id = "melodie",
		area = "étages",
		objective = "Rejoue la mélodie du gramophone sur la boîte à musique (premier étage)",
		hint = "Le gramophone joue trois notes. Rejoue-les sur la boîte à musique, dans le même ordre.",
	},
	{
		id = "horloge",
		area = "étages",
		objective = "Règle l'horloge du hall sur la date gravée sur la plaque du cercueil",
		hint = "Une date est gravée sur la plaque du cercueil. L'horloge du hall attend cette date, mois puis jour.",
	},
	{
		id = "statues",
		area = "étages",
		objective = "Oriente les trois statues du rez-de-chaussée, toutes dans la même direction",
		hint = "Les trois statues doivent regarder la même direction. La lampe UV montre la cible de deux d'entre elles.",
	},
	{
		id = "photos",
		area = "étages",
		objective = "Rassemble les souvenirs",
		hint = "Les souvenirs traînent sur les meubles, dans les pièces ouvertes. Une lampe aide à les voir dans le noir.",
	},
	{
		id = "sortie",
		area = "sortie",
		objective = "Sors par la porte d'entrée",
		hint = "La porte d'entrée s'ouvre avec les trois photos, la clé rouillée et les statues résolues.",
	},
	{
		id = "cave",
		area = "sous-sol",
		objective = "Ouvre la porte métallique du sous-sol (au pied du mur sud, par le jardin)",
		hint = "Les cris viennent d'en bas, au pied du mur sud : la porte du sous-sol, puis la porte métallique de la cave.",
	},
	{
		id = "sous_sol",
		area = "sous-sol",
		objective = "Entre dans la cave",
		hint = "La porte métallique est ouverte : avance dans la cave, quelqu'un y est enfermé.",
	},
	{
		id = "enfant",
		area = "sous-sol",
		objective = "Dans la cave, lis les quatre documents et libère l'enfant dans la cage",
		hint = "L'enfant est dans la cage, au fond de la cave. Lis les quatre documents de la maison, puis entre la date de la plaque devant la cage.",
	},
	{
		id = "retour",
		area = "sous-sol",
		objective = "Ressors de la maison par le sous-sol, avec l'enfant",
		hint = "Remonte par la porte du sous-sol, côté jardin. L'enfant te suit, et le monstre aussi.",
	},
}

local INDEX = {}
for i, step in ipairs(Chain.STEPS) do
	INDEX[step.id] = i
end

function Chain.index(id)
	return INDEX[id]
end

function Chain.get(id)
	return Chain.STEPS[INDEX[id]]
end

-- done : table { [id] = true }. Étape active : la première non faite (nil si tout est fait).
function Chain.current(done)
	for _, step in ipairs(Chain.STEPS) do
		if not done[step.id] then
			return step.id
		end
	end
	return nil
end

-- Une étape (déjà faite ou active) est accessible si toutes les précédentes sont faites.
function Chain.canAct(done, id)
	local idx = INDEX[id]
	if not idx then
		return false
	end
	for i = 1, idx - 1 do
		if not done[Chain.STEPS[i].id] then
			return false
		end
	end
	return true
end

-- L'ensemble des étapes faites doit toujours être un préfixe de la chaîne.
function Chain.isPrefix(done)
	local seenGap = false
	for _, step in ipairs(Chain.STEPS) do
		if done[step.id] then
			if seenGap then
				return false
			end
		else
			seenGap = true
		end
	end
	return true
end

-- Message d'un verrou : explique ce qu'il faut faire d'abord
function Chain.lockedText(done, id)
	local current = Chain.current(done)
	local step = current and Chain.get(current)
	if not step then
		return "Il n'y a plus rien à faire ici."
	end
	return "Pas encore. D'abord : " .. step.objective:sub(1, 1):lower() .. step.objective:sub(2) .. "."
end

-- Nombre d'étapes faites et nombre total (pour « Étape n sur N »)
function Chain.progress(done)
	local n = 0
	for _, step in ipairs(Chain.STEPS) do
		if done[step.id] then
			n += 1
		end
	end
	return n, #Chain.STEPS
end

-- Journal de quêtes : l'étape active en tête, puis les étapes faites (la plus récente d'abord),
-- puis le nombre d'étapes encore à découvrir (leur contenu n'est pas dévoilé).
function Chain.journal(done)
	local lines = {}
	local current = Chain.current(done)
	if current then
		table.insert(lines, "Étape active : " .. Chain.get(current).objective)
	else
		table.insert(lines, "Étape active : plus aucune, la chaîne est terminée.")
	end
	for i = #Chain.STEPS, 1, -1 do
		local step = Chain.STEPS[i]
		if done[step.id] then
			table.insert(lines, "✓ " .. step.objective)
		end
	end
	local remaining = 0
	for _, step in ipairs(Chain.STEPS) do
		if not done[step.id] and step.id ~= current then
			remaining += 1
		end
	end
	if remaining > 0 then
		table.insert(lines, ("… %d étape(s) à découvrir"):format(remaining))
	end
	return lines
end

return Chain
