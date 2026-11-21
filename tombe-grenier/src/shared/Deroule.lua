--[[
  Deroule : le déroulé de la partie pièce par pièce (données pures, testées, et source de docs/DEROULE.md).
  Une partie suit les étapes de Chain dans l'ordre. Chaque étape a sa pièce, son objet clé, le passage qu'elle ouvre,
  son indice et les voix qui l'accompagnent. Les passages (trappes, porte d'entrée, cave) restent fermés, avec un
  message « Verrouillé : il te manque … », tant que la dernière étape de leur pièce n'est pas faite.
]]
local Chain = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Chain)

local Deroule = {}

-- Étapes : pièce, objet clé, passage ouvert à la fin de l'étape (nil : aucun), voix (monstre / enfant)
Deroule.STEPS = {
	note = { room = "Salle de la tombe et grenier ouest", key = "papier du code (surface plate)", opens = nil },
	reflet = { room = "Salle de la tombe", key = "miroir inquiétant (texte à l'envers)", opens = nil },
	coffret = { room = "Salle de la tombe", key = "coffret à bijoux (code à 4 chiffres)", opens = nil },
	chest = { room = "Salle de la tombe", key = "malle (petite clé du coffret)", opens = nil },
	key = {
		room = "Salle de la tombe",
		key = "clé rouillée, au fond de la malle",
		opens = "trappe du grenier",
		voice = "Le monstre s'éveille après le délai de calme (60 s en solo) : « Je te vois. » à la poursuite.",
	},
	melodie = {
		room = "Premier étage (palier)",
		key = "gramophone puis boîte à musique",
		opens = "trappe du premier étage",
	},
	horloge = { room = "Hall", key = "horloge du hall, date de la plaque du cercueil", opens = nil },
	statues = { room = "Salon, cuisine, bureau", key = "trois statues à orienter", opens = nil },
	photos = { room = "Toute la maison ouverte", key = "trois souvenirs (photos)", opens = "porte d'entrée" },
	sortie = {
		room = "Entrée",
		key = "porte d'entrée (trois souvenirs, clé, statues)",
		opens = "sortie vers le jardin",
	},
	cave = {
		room = "Jardin, escalier du sous-sol",
		key = "porte du sous-sol puis porte métallique",
		opens = "cave",
		voice = "Une voix d'enfant appelle à l'aide, sous les pieds du joueur.",
	},
	sous_sol = { room = "Cave centrale", key = "entrer dans la cave", opens = nil },
	enfant = {
		room = "Cave centrale",
		key = "cage de l'enfant, quatre documents, date de la plaque",
		opens = "cage",
		voice = "L'enfant remercie, puis suit le joueur ; le monstre le cherche.",
	},
	retour = { room = "Cave, escalier du sous-sol, jardin", key = "porte du sous-sol, portail", opens = nil },
}

-- Passages verrouillés : ouverts par la dernière étape de leur pièce. text : message « Verrouillé : … ».
Deroule.GATES = {
	grenier = {
		name = "trappe du grenier",
		opensAt = "key",
		text = "Verrouillé : il te manque la clé rouillée, au fond de la malle de la salle de la tombe.",
	},
	premier = {
		name = "trappe du premier étage",
		opensAt = "melodie",
		text = "Verrouillé : il te manque la mélodie. Rejoue sur la boîte à musique les trois notes du gramophone.",
	},
	rez = {
		name = "porte d'entrée",
		opensAt = "photos",
		text = "Verrouillé : il te manque les trois souvenirs, la clé rouillée et les statues bien orientées.",
	},
	cave = {
		name = "cave (par le jardin)",
		opensAt = "sortie",
		text = "Verrouillé : sors d'abord de la maison par la porte d'entrée, la cave s'ouvre depuis le jardin.",
	},
}

-- Pièces de la carte (identifiants de MapData) regroupées par partie de la maison, dans l'ordre de la partie
Deroule.STAGES = {
	{
		id = "grenier",
		name = "Le grenier",
		rooms = { "tombe", "gro" },
		steps = { "note", "reflet", "coffret", "chest", "key" },
	},
	{
		id = "premier",
		name = "Le premier étage",
		rooms = { "palier", "chp", "che", "cha", "sdb2", "couloir", "sdb", "deb" },
		steps = { "melodie" },
	},
	{
		id = "rez",
		name = "Le rez-de-chaussée",
		rooms = { "hall", "salon", "cuis", "sam", "entree", "bureau" },
		steps = { "horloge", "statues", "photos", "sortie" },
	},
	{
		id = "cave",
		name = "La cave",
		rooms = { "cave", "pn", "ps", "cel" },
		steps = { "cave", "sous_sol", "enfant", "retour" },
	},
}

local STAGE_OF_STEP, STAGE_OF_ROOM, STAGE_INDEX = {}, {}, {}
for i, stage in ipairs(Deroule.STAGES) do
	STAGE_INDEX[stage.id] = i
	for _, step in ipairs(stage.steps) do
		STAGE_OF_STEP[step] = stage
	end
	for _, room in ipairs(stage.rooms) do
		STAGE_OF_ROOM[room] = stage
	end
end

function Deroule.stageOfStep(stepId)
	return STAGE_OF_STEP[stepId]
end

function Deroule.stageOfRoom(roomId)
	return STAGE_OF_ROOM[roomId]
end

-- Message d'un passage verrouillé
function Deroule.lockedText(gateId)
	local gate = Deroule.GATES[gateId]
	return gate and gate.text or "Verrouillé."
end

-- Passage ouvert ? done : { [étape] = true }
function Deroule.gateOpen(gateId, done)
	local gate = Deroule.GATES[gateId]
	return gate ~= nil and done[gate.opensAt] == true
end

-- Bannière d'entrée dans une pièce : titre (nom de la pièce) et consigne en une phrase selon l'étape active.
-- Retourne la consigne seulement ; le nom vient de MapData.
function Deroule.roomLine(roomId, stepId)
	local stage = STAGE_OF_ROOM[roomId]
	local current = stepId and STAGE_OF_STEP[stepId]
	if not stage or not current then
		return nil
	end
	local step = Chain.get(stepId)
	local here, now = STAGE_INDEX[stage.id], STAGE_INDEX[current.id]
	if here == now then
		return step and step.objective or nil
	elseif here < now then
		return "Cette partie de la maison est derrière toi. " .. (step and step.objective or "")
	end
	return "Pas encore : " .. (step and step.objective or "")
end

return Deroule
