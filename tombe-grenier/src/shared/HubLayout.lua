--[[
  HubLayout : disposition du décor du hub, en coordonnées locales (0, 0 = centre du hub, y = sol). Données pures,
  sans objet Roblox : testées en Python (nombre de pièces, éclairage, zone de spawn dégagée, aucun
  chevauchement). HubDecor.lua construit ces éléments ; rien ici n'est cliquable ni collisionnable.

  Thème : grenier et maison hantée. Étagères, malles, lampes chaudes, bougies, toiles d'araignée,
  tapis, cadres, plantes mortes, panneaux explicatifs devant chaque borne, tableau des règles.
]]
local HubLayout = {}

-- Géométrie fixe du hub (voir Hub.build) : sol 60 x 60, deux bornes, piliers, banc, panneau d'arrivée
HubLayout.HALF = 30
HubLayout.CLEAR_RADIUS = 8 -- zone d'arrivée dégagée autour du point d'apparition (0, 0)
HubLayout.PADS = {
	solo = { x = -9, z = 12, half = 4 },
	duo = { x = 9, z = 12, half = 4 },
}
HubLayout.PILLARS = { { -26, -26 }, { 26, -26 }, { -26, 26 }, { 26, 26 } }
HubLayout.PILLAR_HALF = 1.5
HubLayout.BENCH = { x = 0, z = -18, hx = 5, hz = 1 }
HubLayout.BOARD = { x = 0, z = -29, hx = 11, hz = 0.3 }

-- Limites : pièces totales du décor ajouté, lumières (par rapport à RoomBudget.qualityLimits)
HubLayout.MAX_PARTS = 250
HubLayout.EXISTING_LIGHTS = 5 -- lampe centrale + une lueur par pilier (Hub.build)
HubLayout.LIGHTS_FACTOR = 2 -- le hub est un espace ouvert : deux fois la limite d'une pièce

-- Types : nombre de pièces, nombre de lumières, empreinte au sol (largeur x, largeur z), hauteur, plat ou posé
HubLayout.KINDS = {
	etagere = { parts = 9, size = { 2.5, 7, 6 } },
	malle = { parts = 3, size = { 4, 2.5, 2.5 } },
	cadre = { parts = 2, size = { 0.2, 2.4, 1.8 }, wall = true },
	tapis = { parts = 2, size = { 16, 0.06, 12 }, flat = true },
	toile = { parts = 1, size = { 0.05, 2.5, 2.5 }, wall = true },
	plante_morte = { parts = 4, size = { 1.6, 3, 1.6 } },
	poutre = { parts = 1, size = { 52, 0.8, 1.2 }, high = true },
	bougie = { parts = 3, size = { 0.6, 0.8, 0.6 }, small = true },
	lampe = { parts = 3, light = true, size = { 1.6, 6.5, 1.6 } },
	panneau = { parts = 3, size = { 7, 4.6, 0.4 } },
	tableau_regles = { parts = 3, size = { 0.4, 7, 14 } },
}

-- Modèles Config.Assets utilisés à la place du décor procédural quand ils se chargent
HubLayout.ASSETS = {
	etagere = "HubBibliotheque",
	lampe = "LampeHorreur",
	plante_morte = "Plante",
}

-- Une ligne = { kind, x, z, [y], [facing], [on], [light], [label] }
-- facing : direction vers laquelle regarde la face visible ("+x", "-x", "+z", "-z")
HubLayout.ITEMS = {
	-- Étagères le long du bord ouest
	{ kind = "etagere", x = -28, z = -14, facing = "+x" },
	{ kind = "etagere", x = -28, z = 0, facing = "+x" },
	{ kind = "etagere", x = -28, z = 14, facing = "+x" },
	-- Malles de voyage, avec une bougie posée dessus
	{ kind = "malle", x = 27, z = -12 },
	{ kind = "malle", x = 26.5, z = 10 },
	{ kind = "malle", x = -22, z = -20 },
	{ kind = "malle", x = 20, z = -22 },
	{ kind = "bougie", x = 27, z = -12, y = 2.5, on = true, light = true },
	{ kind = "bougie", x = 26.5, z = 10, y = 2.5, on = true, light = true },
	{ kind = "bougie", x = -22, z = -20, y = 2.5, on = true, light = true },
	{ kind = "bougie", x = 20, z = -22, y = 2.5, on = true },
	-- Bougies au sol, près des étagères
	{ kind = "bougie", x = -25, z = 7, light = true },
	{ kind = "bougie", x = -25, z = -7 },
	{ kind = "bougie", x = 24, z = 3 },
	-- Lampes à lueur chaude
	{ kind = "lampe", x = -16, z = -6, light = true },
	{ kind = "lampe", x = 16, z = -6, light = true },
	{ kind = "lampe", x = -16, z = 22, light = true },
	{ kind = "lampe", x = 16, z = 22, light = true },
	-- Plantes mortes
	{ kind = "plante_morte", x = -22, z = 20 },
	{ kind = "plante_morte", x = 22, z = 20 },
	{ kind = "plante_morte", x = -20, z = -12 },
	{ kind = "plante_morte", x = 18, z = -12 },
	-- Cadres accrochés aux piliers (face tournée vers le centre)
	{ kind = "cadre", x = -24.4, z = -26, y = 6, facing = "+x" },
	{ kind = "cadre", x = 24.4, z = -26, y = 6, facing = "-x" },
	{ kind = "cadre", x = -24.4, z = 26, y = 6, facing = "+x" },
	{ kind = "cadre", x = 24.4, z = 26, y = 6, facing = "-x" },
	-- Toiles d'araignée, en haut des piliers et sur les étagères
	{ kind = "toile", x = -24.4, z = -26, y = 10, facing = "+x" },
	{ kind = "toile", x = 24.4, z = -26, y = 10, facing = "-x" },
	{ kind = "toile", x = -24.4, z = 26, y = 10, facing = "+x" },
	{ kind = "toile", x = 24.4, z = 26, y = 10, facing = "-x" },
	{ kind = "toile", x = -26.6, z = -14, y = 6.2, facing = "+x" },
	{ kind = "toile", x = -26.6, z = 14, y = 6.2, facing = "+x" },
	-- Poutres entre les sommets des piliers : dessus, la poussière tombe
	{ kind = "poutre", x = 0, z = -26, y = 12.4, facing = "-z" },
	{ kind = "poutre", x = 0, z = 26, y = 12.4, facing = "-z" },
	{ kind = "poutre", x = -26, z = 0, y = 12.4, facing = "+x", size = { 1.2, 0.8, 52 } },
	{ kind = "poutre", x = 26, z = 0, y = 12.4, facing = "+x", size = { 1.2, 0.8, 52 } },
	-- Tapis : sous l'arrivée, et entre les deux bornes
	{ kind = "tapis", x = 0, z = 0 },
	{ kind = "tapis", x = 0, z = 12, size = { 8, 0.06, 8 } },
	-- Panneaux explicatifs, entre l'arrivée et chaque borne, tournés vers l'arrivée
	{ kind = "panneau", x = -9, z = 6.5, facing = "-z", label = "solo" },
	{ kind = "panneau", x = 9, z = 6.5, facing = "-z", label = "duo" },
	-- Tableau des règles, contre le bord est, tourné vers le centre
	{ kind = "tableau_regles", x = 29, z = 0, facing = "-x", label = "regles" },
}

-- Empreinte d'un élément. Les tailles sont données dans les axes du monde pour l'orientation prévue
-- (facing) : aucune rotation à appliquer pour la calculer.
function HubLayout.footprint(item)
	local size = item.size or HubLayout.KINDS[item.kind].size
	return {
		x0 = item.x - size[1] / 2,
		x1 = item.x + size[1] / 2,
		z0 = item.z - size[3] / 2,
		z1 = item.z + size[3] / 2,
	}
end

-- Totaux : pièces, lumières
function HubLayout.totals(items)
	local parts, lights = 0, 0
	for _, it in ipairs(items) do
		local spec = HubLayout.KINDS[it.kind]
		parts = parts + spec.parts
		if it.light or spec.light then
			lights = lights + 1
		end
	end
	return parts, lights
end

-- Applique les limites : au-delà de maxParts les éléments sont écartés (les derniers d'abord), au-delà de
-- maxLights les éléments perdent leur lumière (noLight). Renvoie { items, dropped, parts, lights }.
function HubLayout.plan(items, maxParts, maxLights)
	local out, dropped = {}, 0
	local parts, lights = 0, 0
	for _, it in ipairs(items) do
		local spec = HubLayout.KINDS[it.kind]
		if parts + spec.parts > maxParts then
			dropped = dropped + 1
		else
			local copy = {}
			for k, v in pairs(it) do
				copy[k] = v
			end
			if copy.light or spec.light then
				if lights < maxLights then
					lights = lights + 1
				else
					copy.noLight = true
				end
			end
			parts = parts + spec.parts
			table.insert(out, copy)
		end
	end
	return { items = out, dropped = dropped, parts = parts, lights = lights }
end

-- Lumières autorisées au total dans le hub (existantes comprises) pour un niveau de RoomBudget
function HubLayout.lightLimit(qualityLimits)
	return qualityLimits.lights * HubLayout.LIGHTS_FACTOR
end

-- Texte du tableau des règles (valeurs lues dans Config)
function HubLayout.rulesText(cfg)
	local solo, duo = cfg.Balance.solo, cfg.Balance.duo
	return "RÈGLES\n"
		.. ("Solo : %d vies. Duo : %d vies chacun.\n"):format(solo.lives, duo.lives)
		.. "Une mort coûte une vie. En duo, ton partenaire peut te réanimer.\n"
		.. "Ctrl : pas silencieux · Maj : courir · C : s'accroupir\n"
		.. "F : lampe · G : lancer un objet · H : indice\n"
		.. "Cache-toi dans une armoire quand le monstre approche.\n"
		.. "Trois photos et la clé ouvrent la sortie."
end

-- Textes des panneaux devant les bornes
function HubLayout.padText(mode, cfg)
	if mode == "duo" then
		return "PARTIE DUO\n"
			.. ("Deux joueurs, %d vies chacun.\n"):format(cfg.Balance.duo.lives)
			.. ("Attente d'un second joueur : %d s au plus."):format(cfg.Game.DuoWait)
	end
	return "PARTIE SOLO\n"
		.. ("Seul dans la maison, %d vies.\n"):format(cfg.Balance.solo.lives)
		.. "La partie démarre tout de suite."
end

return HubLayout
