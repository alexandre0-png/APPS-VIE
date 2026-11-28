-- ModuleScript : ReplicatedStorage/TypeFx   (lot 10, B.6)
-- DONNÉES PURES des effets d'attaque par type (9 types de la matrice D.2) : couleur, attaque de base (0,5 s) et spécial (1,2 s). Aucune dépendance.
-- Sera exposé plus tard comme `Config.TYPE_FX = TypeFx.DATA` ; le client StarterPlayerScripts/TypeFx.lua lit ces données (passées en paramètre, pas de require).
-- Forme : DATA[type] = { hex = "FF6A1A", rgb = {r, g, b}, basic = Effet, special = Effet }
--   Effet = { d = durée (s), shake = secousse de l'écran (s) | nil, linger = durée de persistance au sol (s) | nil, layers = { Couche, ... } }
--   Couche = { prim = "shoot"|"burst"|"bolt"|"column"|"ring"|"cone"|"flash"|"runes"|"decal"|"spiral"|"chainring"|"beam", n = nombre d'objets créés (>= 1),
--              t = début (s), d = durée (s), glyph = texte | nil, size = taille px | nil, color = "main"|"white"|"dark" | nil, ... }
-- Coût d'un effet = 1 (conteneur) + somme des n (TypeFx.cost) ; plafonds : base <= 14, spécial <= 30 (vérifiés par les tests).
-- Noms de types : ceux de D.2 (Feu, Eau, Plante, Glace, Foudre, Terre, Ciel, Ombre, Lumière) ; l'ancien nom « Nature » est un alias de « Plante » (TypeFx.get).
-- Pas de += ni de continue (lanceur lupa).
local TypeFx = {}

TypeFx.TYPES = { "Feu", "Eau", "Plante", "Glace", "Foudre", "Terre", "Ciel", "Ombre", "Lumière" }
TypeFx.ALIASES = { Nature = "Plante" }
TypeFx.BASIC_MAX, TypeFx.SPECIAL_MAX = 14, 30
TypeFx.BASIC_SECONDS, TypeFx.SPECIAL_SECONDS = 0.5, 1.2

local function rgb(hex)
	return { tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16) }
end

local function L(prim, n, t, d, extra)
	local l = { prim = prim, n = n, t = t, d = d }
	if extra then
		for k, v in pairs(extra) do
			l[k] = v
		end
	end
	return l
end

local function def(hex, basic, special)
	return { hex = hex, rgb = rgb(hex), basic = basic, special = special }
end

TypeFx.DATA = {
	Feu = def("FF6A1A",
		{ d = 0.5, layers = { L("shoot", 1, 0, 0.35, { glyph = "●", size = 28 }), L("burst", 5, 0.3, 0.2, { glyph = "✦", dist = 40 }) } },
		{ d = 1.2, shake = 0.4, linger = 2, layers = { L("runes", 6, 0, 1.2), L("cone", 10, 0.1, 0.8, { glyph = "●", size = 26 }), L("decal", 1, 0.6, 0.6, { color = "dark" }), L("burst", 6, 0.6, 0.5, { glyph = "✦", dist = 70 }) } }),
	Eau = def("3C96DC",
		{ d = 0.5, layers = { L("shoot", 4, 0, 0.35, { glyph = "💧", size = 20 }), L("burst", 4, 0.3, 0.2, { glyph = "•", dist = 36 }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 6, 0, 1.2), L("ring", 3, 0.2, 0.9), L("burst", 8, 0.5, 0.6, { glyph = "💧", dist = 80 }) } }),
	Plante = def("5CB256",
		{ d = 0.5, layers = { L("shoot", 3, 0, 0.4, { glyph = "🍃", size = 24, spin = true }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 6, 0, 1.2), L("column", 6, 0.2, 0.7, { glyph = "vine", size = 18 }), L("burst", 4, 0.8, 0.3, { glyph = "🍃", dist = 50 }) } }),
	Glace = def("BFEFFF",
		{ d = 0.5, layers = { L("shoot", 3, 0, 0.35, { glyph = "❄", size = 24, spin = true }), L("burst", 4, 0.3, 0.2, { glyph = "✧", dist = 36 }) } },
		{ d = 1.2, shake = 0.4, linger = 2, layers = { L("runes", 6, 0, 1.2), L("column", 6, 0.2, 0.6, { glyph = "spike", size = 20 }), L("decal", 1, 0.6, 0.5, { color = "white" }), L("burst", 6, 0.7, 0.4, { glyph = "❄", dist = 70 }) } }),
	Foudre = def("FFE14A",
		{ d = 0.5, layers = { L("bolt", 6, 0, 0.3), L("flash", 1, 0.3, 0.1, { alpha = 0.3 }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 6, 0, 1.2), L("bolt", 6, 0.2, 0.4), L("bolt", 6, 0.55, 0.4), L("flash", 1, 0.9, 0.1, { alpha = 0.6 }) } }),
	Terre = def("9C6B45",
		{ d = 0.5, layers = { L("column", 4, 0, 0.4, { glyph = "rock", size = 26 }), L("burst", 4, 0.3, 0.2, { glyph = "•", dist = 34 }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 6, 0, 1.2), L("ring", 2, 0.2, 0.9), L("bolt", 4, 0.3, 0.5, { color = "dark" }), L("burst", 8, 0.5, 0.6, { glyph = "•", dist = 80 }) } }),
	Ciel = def("DDEBFF",
		{ d = 0.5, layers = { L("shoot", 5, 0, 0.4, { glyph = "✧", size = 22, spin = true }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 6, 0, 1.2), L("spiral", 10, 0.2, 1.0, { glyph = "☁", size = 24 }), L("burst", 4, 0.9, 0.3, { glyph = "✧", dist = 60 }) } }),
	Ombre = def("8A3CFF",
		{ d = 0.5, layers = { L("shoot", 3, 0, 0.4, { glyph = "●", size = 24 }), L("burst", 4, 0.3, 0.2, { glyph = "☁", dist = 40 }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 6, 0, 1.2), L("chainring", 6, 0.2, 0.9), L("burst", 6, 0.7, 0.5, { glyph = "☁", dist = 70 }) } }),
	["Lumière"] = def("FFE680",
		{ d = 0.5, layers = { L("beam", 1, 0, 0.4), L("burst", 3, 0.3, 0.2, { glyph = "✦", dist = 36 }) } },
		{ d = 1.2, shake = 0.4, layers = { L("runes", 8, 0, 1.2), L("column", 1, 0.2, 0.9, { glyph = "pillar", size = 70 }), L("flash", 1, 0.3, 0.15, { alpha = 0.5 }), L("burst", 6, 0.6, 0.5, { glyph = "✦", dist = 70 }) } }),
}

-- Nom canonique d'un type (alias « Nature » -> « Plante »), ou nil.
function TypeFx.canonical(name)
	if type(name) ~= "string" then
		return nil
	end
	local n = TypeFx.ALIASES[name] or name
	if TypeFx.DATA[n] then
		return n
	end
	return nil
end

function TypeFx.get(name)
	local n = TypeFx.canonical(name)
	return n and TypeFx.DATA[n] or nil
end

-- Coût (objets créés, conteneur compris) d'un effet ; reduced : moitié des objets de chaque couche (arrondi bas, au moins 1).
function TypeFx.cost(name, special, reduced)
	local def = TypeFx.get(name)
	if def == nil then
		return 0
	end
	local fx = special and def.special or def.basic
	local total = 1
	for i = 1, #fx.layers do
		local n = fx.layers[i].n
		if reduced then
			n = math.max(1, math.floor(n / 2))
		end
		total = total + n
	end
	return total
end

-- Texte d'efficacité flottant (B.6) pour un multiplicateur de type : texte, couleur RGB ; nil si neutre (x1) ou invalide.
TypeFx.EFFICACY = {
	{ min = 1.5, text = "Super efficace !", rgb = { 70, 220, 90 } },
	{ min = 1.2, text = "Efficace", rgb = { 150, 230, 120 } },
	{ max = 0.7, text = "Pas très efficace…", rgb = { 230, 70, 70 } },
	{ max = 0.95, text = "Peu efficace", rgb = { 255, 160, 50 } },
}

function TypeFx.efficacy(mult)
	if type(mult) ~= "number" or mult ~= mult or mult <= 0 then
		return nil
	end
	for i = 1, #TypeFx.EFFICACY do
		local e = TypeFx.EFFICACY[i]
		if (e.min ~= nil and mult >= e.min - 1e-9) or (e.max ~= nil and mult <= e.max + 1e-9) then
			return e.text, e.rgb
		end
	end
	return nil
end

return TypeFx
