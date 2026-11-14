--[[
  RoomMood : ambiance propre à chaque pièce (données seules).
  - light : couleur (RVB 0-255), intensité (0-1) et portée (studs) de la lueur d'ambiance de la pièce.
  - sound : clé du manifeste audio (boucle très basse), ou nil.
  - detail : repère visuel marquant (nom, couleur) posé au sol, au centre de la pièce.
  La progression ne dépend jamais de ces valeurs. Testé par tools/lua/test_moods.py.
]]
local RoomMood = {}

RoomMood.rooms = {
	-- Sous-sol
	pn = { light = { 120, 110, 90 }, brightness = 0.35, range = 14, sound = "ventilation", volume = 0.04, detail = { "caisse marquée", { 90, 60, 40 } } },
	cave = { light = { 140, 120, 80 }, brightness = 0.30, range = 18, sound = "ambiance_longue", volume = 0.03, detail = { "chaîne au mur", { 80, 80, 85 } } },
	ps = { light = { 110, 130, 150 }, brightness = 0.30, range = 14, sound = "ventilation", volume = 0.03, detail = { "vieux portemanteau", { 60, 50, 40 } } },
	cel = { light = { 150, 140, 100 }, brightness = 0.30, range = 12, sound = "porte_grince", volume = 0.03, detail = { "tonneau", { 100, 70, 40 } } },
	-- Rez-de-chaussée
	salon = { light = { 255, 190, 120 }, brightness = 0.40, range = 18, sound = nil, volume = 0, detail = { "tapis usé", { 120, 40, 40 } } },
	hall = { light = { 255, 220, 160 }, brightness = 0.50, range = 22, sound = "ventilation", volume = 0.03, detail = { "tapis rouge d'entrée", { 130, 30, 30 } } },
	cuis = { light = { 200, 230, 255 }, brightness = 0.40, range = 14, sound = "courant", volume = 0.02, detail = { "torchon sur le plan", { 210, 210, 200 } } },
	sam = { light = { 255, 200, 140 }, brightness = 0.35, range = 16, sound = nil, volume = 0, detail = { "nappe brodée", { 200, 190, 170 } } },
	entree = { light = { 170, 190, 210 }, brightness = 0.40, range = 16, sound = "ventilation", volume = 0.03, detail = { "miroir mural", { 160, 180, 190 } } },
	bureau = { light = { 220, 200, 160 }, brightness = 0.35, range = 14, sound = nil, volume = 0, detail = { "pile de papiers", { 230, 225, 210 } } },
	-- Premier étage
	chp = { light = { 180, 150, 140 }, brightness = 0.30, range = 14, sound = nil, volume = 0, detail = { "couverture froissée", { 110, 70, 80 } } },
	palier = { light = { 190, 180, 200 }, brightness = 0.30, range = 16, sound = "grincement_escalier", volume = 0.02, detail = { "horloge à balancier", { 80, 60, 40 } } },
	che = { light = { 200, 170, 220 }, brightness = 0.30, range = 14, sound = nil, volume = 0, detail = { "peluche au sol", { 200, 160, 190 } } },
	cha = { light = { 210, 190, 150 }, brightness = 0.30, range = 14, sound = nil, volume = 0, detail = { "couvre-lit", { 150, 120, 90 } } },
	sdb2 = { light = { 150, 200, 210 }, brightness = 0.35, range = 10, sound = "courant", volume = 0.02, detail = { "rideau de douche", { 200, 220, 230 } } },
	couloir = { light = { 200, 160, 120 }, brightness = 0.25, range = 18, sound = "ambiance_longue", volume = 0.03, detail = { "tapis long", { 100, 40, 40 } } },
	sdb = { light = { 190, 220, 220 }, brightness = 0.35, range = 12, sound = nil, volume = 0, detail = { "baignoire", { 235, 235, 235 } } },
	deb = { light = { 160, 150, 130 }, brightness = 0.25, range = 10, sound = "ventilation", volume = 0.02, detail = { "cartons empilés", { 140, 110, 70 } } },
	-- Grenier
	gro = { light = { 120, 110, 100 }, brightness = 0.20, range = 20, sound = "ambiance_longue", volume = 0.04, detail = { "toile d'araignée", { 210, 210, 200 } } },
	tombe = { light = { 140, 80, 80 }, brightness = 0.25, range = 14, sound = "ventilation", volume = 0.03, detail = { "cercueil ouvert", { 60, 40, 30 } } },
}

return RoomMood
