--[[
  Markers : style lisible de chaque objet interactif (pure donnée, testée hors Roblox).
  Un objet interactif porte une étiquette (tag) ; son style donne la catégorie, la couleur du halo,
  l'icône courte et le nom affiché. Le décor n'a aucune étiquette de cette liste : il n'a ni halo ni icône.
  Catégories : clé, porte, document, levier, cachette, enfant, outil, énigme.
]]
local Markers = {}

-- tags : étiquettes CollectionService ; color : halo ; icon : pastille ; label : nom au survol
Markers.STYLES = {
	{
		category = "clé",
		tags = { "Key", "CaveKey", "BathKey", "Decoy" },
		color = { 255, 210, 60 },
		icon = "CLÉ",
		label = "Clé",
	},
	{
		category = "porte",
		tags = { "ExitDoor", "CaveDoor", "Door", "Trappe", "TrappeGrenier", "TrappePalier" },
		color = { 120, 200, 255 },
		icon = "PORTE",
		label = "Porte",
	},
	{
		category = "document",
		tags = { "Photo", "CodeNote", "IntroPhoto", "Plaque", "Livre", "Tableau" },
		color = { 245, 245, 235 },
		icon = "DOC",
		label = "Document",
	},
	{
		category = "levier",
		tags = { "Switch", "Phone", "TV", "Tiroir", "Rocking", "MusicBox" },
		color = { 255, 90, 60 },
		icon = "LEVIER",
		label = "Mécanisme",
	},
	{ category = "cachette", tags = { "Hiding" }, color = { 110, 230, 150 }, icon = "CACHE", label = "Cachette" },
	{ category = "enfant", tags = { "Tombe" }, color = { 255, 110, 190 }, icon = "ENFANT", label = "L'enfant" },
	{
		category = "outil",
		tags = { "Battery", "Throwable" },
		color = { 60, 120, 255 },
		icon = "OBJET",
		label = "Objet utile",
	},
	{
		category = "énigme",
		tags = { "Mirror", "Horloge", "Compteur", "Coffret", "Chest", "Statue", "Mannequin", "Interactable" },
		color = { 190, 130, 255 },
		icon = "ÉNIGME",
		label = "Énigme",
	},
}

Markers.MAX_DISTANCE = 16 -- les icônes n'apparaissent qu'à proximité

-- Style d'une étiquette (nil si l'étiquette n'est pas interactive : c'est du décor)
function Markers.styleForTag(tag)
	for _, style in ipairs(Markers.STYLES) do
		for _, t in ipairs(style.tags) do
			if t == tag then
				return style
			end
		end
	end
	return nil
end

-- Style d'un objet portant plusieurs étiquettes : la première qui correspond
function Markers.styleFor(tags)
	for _, tag in ipairs(tags) do
		local style = Markers.styleForTag(tag)
		if style then
			return style
		end
	end
	return nil
end

function Markers.isInteractiveTag(tag)
	return Markers.styleForTag(tag) ~= nil
end

-- Étiquettes de l'objet à utiliser à chaque étape de la chaîne (Chain.lua). Les étapes « sous_sol » et « retour »
-- se jouent en se déplaçant : aucun objet à mettre en avant.
Markers.STEP_TAGS = {
	note = { "CodeNote" },
	reflet = { "Mirror" },
	coffret = { "Coffret" },
	chest = { "Chest" },
	key = { "Key" },
	melodie = { "MusicBox" },
	horloge = { "Horloge" },
	statues = { "Statue" },
	photos = { "Photo" },
	sortie = { "ExitDoor" },
	cave = { "CaveDoor", "CaveKey" },
	enfant = { "Tombe" },
}

Markers.MAX_HALOS = 24 -- Roblox n'affiche qu'environ 31 halos à la fois : on en garde une marge

-- Cet objet (liste d'étiquettes) sert-il à l'étape donnée ?
function Markers.isCurrent(step, tags)
	local wanted = Markers.STEP_TAGS[step]
	if not wanted then
		return false
	end
	for _, tag in ipairs(tags) do
		for _, w in ipairs(wanted) do
			if tag == w then
				return true
			end
		end
	end
	return false
end

-- entries : { { dist = nombre, current = booléen } }. Retourne l'ensemble des indices à garder allumés (au plus limit) :
-- d'abord les objets de l'étape active (du plus proche au plus loin), puis les autres par distance.
function Markers.select(entries, limit)
	local order = {}
	for i = 1, #entries do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local ea, eb = entries[a], entries[b]
		if ea.current ~= eb.current then
			return ea.current
		end
		if ea.dist ~= eb.dist then
			return ea.dist < eb.dist
		end
		return a < b
	end)
	local keep = {}
	for k = 1, math.min(limit, #order) do
		keep[order[k]] = true
	end
	return keep
end

return Markers
