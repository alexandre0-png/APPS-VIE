-- Les 7 espèces de bêtes. Chaque bête est construite en blocs Roblox (aucun asset externe).
-- Repère local : l'avant est -Z, le dessus est +Y. Les offsets "o" sont relatifs au centre du corps.
-- Palette : body / dark / light / accent / eye.

local function V(x, y, z)
	return Vector3.new(x, y, z)
end

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function addEyes(parts, y, z, dx)
	table.insert(parts, { n = "EyeL", s = V(0.45, 0.55, 0.3), o = V(-dx, y, z), c = "eye" })
	table.insert(parts, { n = "EyeR", s = V(0.45, 0.55, 0.3), o = V(dx, y, z), c = "eye" })
end

-- Quatre pattes en trot diagonal.
local function quadLegs(size, hipY, hx, hz)
	return {
		{ n = "LegFL", s = size, hip = V(-hx, hipY, -hz), phase = 0, c = "dark" },
		{ n = "LegFR", s = size, hip = V(hx, hipY, -hz), phase = math.pi, c = "dark" },
		{ n = "LegBL", s = size, hip = V(-hx, hipY, hz), phase = math.pi, c = "dark" },
		{ n = "LegBR", s = size, hip = V(hx, hipY, hz), phase = 0, c = "dark" },
	}
end

local Species = {}

Species.List = {}

local function add(def)
	def.seat = V(0, def.body.s.Y / 2 + 2.1, def.seatZ or 0.4)
	table.insert(Species.List, def)
end

-- 1. Sanglier : petit, zigzag.
do
	local parts = {
		{ n = "Head", s = V(3.8, 3.4, 3.6), o = V(0, 0.3, -5.5), c = "dark" },
		{ n = "Snout", s = V(2.2, 1.6, 1.8), o = V(0, -0.4, -7.6), c = "accent" },
		{ n = "TuskL", s = V(0.4, 0.4, 1.4), o = V(-1.0, -1.1, -7.6), c = "light" },
		{ n = "TuskR", s = V(0.4, 0.4, 1.4), o = V(1.0, -1.1, -7.6), c = "light" },
		{ n = "EarL", s = V(0.8, 1.2, 0.5), o = V(-1.5, 2.3, -4.8), c = "dark" },
		{ n = "EarR", s = V(0.8, 1.2, 0.5), o = V(1.5, 2.3, -4.8), c = "dark" },
		{ n = "Mane", s = V(1.2, 0.8, 6), o = V(0, 2.3, 0), c = "dark" },
		{ n = "Tail", s = V(0.5, 0.5, 1.6), o = V(0, 1.2, 4.7), c = "dark" },
	}
	addEyes(parts, 0.9, -7.35, 1.1)
	add({
		id = "boar", name = "Sanglier", desc = "Petit et nerveux. Il zigzague sans cesse.",
		speed = 38, value = 1, weight = 26, tameTime = 5, buckAfter = 9, trait = "weave",
		weaveAmp = 14, weaveFreq = 0.9, rootY = 4.4,
		body = { s = V(5, 4, 8), c = "body" },
		palette = { body = C(139, 94, 60), dark = C(92, 60, 38), light = C(238, 226, 200), accent = C(255, 150, 170), eye = C(20, 20, 20) },
		parts = parts, legs = quadLegs(V(1.3, 2.4, 1.3), -2, 1.7, 2.8), wings = {},
	})
end

-- 2. Autruche des cimes : la plus rapide au sol.
do
	local parts = {
		{ n = "Neck", s = V(1.1, 4.5, 1.1), o = V(0, 3.9, -2.1), c = "light" },
		{ n = "Head", s = V(1.9, 1.7, 2.8), o = V(0, 6.6, -3.0), c = "body" },
		{ n = "Beak", s = V(0.9, 0.9, 2), o = V(0, 6.3, -5.0), c = "accent" },
		{ n = "Crest", s = V(0.5, 1.4, 1.2), o = V(0, 7.8, -2.6), c = "dark" },
		{ n = "TailA", s = V(2.4, 2.6, 1.6), o = V(0, 1.4, 3.8), c = "light" },
		{ n = "TailB", s = V(1.4, 2.0, 1.2), o = V(0, 2.8, 4.4), c = "dark" },
		{ n = "WingL", s = V(0.5, 2.4, 3.2), o = V(-1.9, 0.4, 0.3), c = "dark" },
		{ n = "WingR", s = V(0.5, 2.4, 3.2), o = V(1.9, 0.4, 0.3), c = "dark" },
	}
	addEyes(parts, 6.9, -4.1, 0.95)
	add({
		id = "ostrich", name = "Autruche des cimes", desc = "Foncière et rapide. Parfaite pour gagner du terrain.",
		speed = 52, value = 1.2, weight = 16, tameTime = 5, buckAfter = 8, trait = "sprint",
		weaveAmp = 2, weaveFreq = 0.6, rootY = 7,
		body = { s = V(3.4, 4, 6), c = "body" },
		palette = { body = C(176, 72, 56), dark = C(112, 44, 38), light = C(238, 214, 176), accent = C(255, 200, 50), eye = C(20, 20, 20) },
		parts = parts,
		legs = {
			{ n = "LegL", s = V(0.9, 5, 0.9), hip = V(-1.1, -2, 0.6), phase = 0, c = "accent" },
			{ n = "LegR", s = V(0.9, 5, 0.9), hip = V(1.1, -2, 0.6), phase = math.pi, c = "accent" },
		},
		wings = {},
	})
end

-- 3. Rhinocéros : charge par rafales.
do
	local parts = {
		{ n = "Head", s = V(4, 4, 4), o = V(0, -0.2, -6.2), c = "dark" },
		{ n = "Horn", s = V(0.9, 0.9, 2.8), o = V(0, 2.3, -8.1), c = "light", rot = V(-25, 0, 0) },
		{ n = "EarL", s = V(0.6, 1.2, 0.8), o = V(-1.6, 2.4, -4.6), c = "dark" },
		{ n = "EarR", s = V(0.6, 1.2, 0.8), o = V(1.6, 2.4, -4.6), c = "dark" },
		{ n = "Plates", s = V(6.4, 0.8, 2.2), o = V(0, 2.7, -2.5), c = "accent" },
		{ n = "Tail", s = V(0.5, 0.5, 2), o = V(0, 1.5, 5.4), c = "dark" },
	}
	addEyes(parts, 0.7, -8.15, 1.6)
	add({
		id = "rhino", name = "Rhinocéros", desc = "Charge par rafales : +50 % de vitesse toutes les 6 s.",
		speed = 33, value = 1.5, weight = 15, tameTime = 6, buckAfter = 11, trait = "charge",
		weaveAmp = 0, weaveFreq = 1, rootY = 5.5,
		body = { s = V(6, 5, 9), c = "body" },
		palette = { body = C(136, 138, 150), dark = C(96, 98, 110), light = C(236, 232, 218), accent = C(170, 120, 80), eye = C(20, 20, 20) },
		parts = parts, legs = quadLegs(V(1.7, 3, 1.7), -2.5, 2.0, 3.2), wings = {},
	})
end

-- 4. Bélier : bondit en courant.
do
	local parts = {
		{ n = "Head", s = V(2.6, 2.8, 2.8), o = V(0, 0.9, -4.3), c = "dark" },
		{ n = "HornL", s = V(0.9, 0.9, 1.8), o = V(-1.6, 1.9, -4.0), c = "accent" },
		{ n = "HornLB", s = V(0.9, 0.9, 0.9), o = V(-1.9, 1.2, -5.0), c = "accent" },
		{ n = "HornR", s = V(0.9, 0.9, 1.8), o = V(1.6, 1.9, -4.0), c = "accent" },
		{ n = "HornRB", s = V(0.9, 0.9, 0.9), o = V(1.9, 1.2, -5.0), c = "accent" },
		{ n = "EarL", s = V(0.4, 0.5, 1.0), o = V(-1.5, 1.8, -3.2), c = "dark" },
		{ n = "EarR", s = V(0.4, 0.5, 1.0), o = V(1.5, 1.8, -3.2), c = "dark" },
		{ n = "Tail", s = V(0.7, 0.7, 0.7), o = V(0, 0.8, 3.5), c = "body" },
	}
	addEyes(parts, 1.4, -5.65, 0.8)
	add({
		id = "ram", name = "Bélier", desc = "Il bondit à chaque foulée : spectaculaire et rapide.",
		speed = 42, value = 1.3, weight = 15, tameTime = 5, buckAfter = 9, trait = "hop",
		weaveAmp = 5, weaveFreq = 0.8, rootY = 4.8,
		body = { s = V(4, 3.6, 6.4), c = "body" },
		palette = { body = C(244, 240, 228), dark = C(70, 58, 56), light = C(255, 255, 255), accent = C(210, 180, 130), eye = C(255, 255, 255) },
		parts = parts, legs = quadLegs(V(1, 3, 1), -1.8, 1.3, 2.2), wings = {},
	})
end

-- 5. Mammouth : lent, très rentable, ne désarçonne jamais.
do
	local parts = {
		{ n = "Head", s = V(5, 5, 5), o = V(0, 1.0, -8.0), c = "body" },
		{ n = "TrunkA", s = V(1.6, 1.6, 3.2), o = V(0, -0.6, -11.0), c = "dark" },
		{ n = "TrunkB", s = V(1.4, 2.6, 1.4), o = V(0, -1.9, -12.2), c = "dark" },
		{ n = "TuskL", s = V(0.8, 0.8, 4.2), o = V(-1.8, -0.8, -10.8), c = "light", rot = V(0, 12, 0) },
		{ n = "TuskR", s = V(0.8, 0.8, 4.2), o = V(1.8, -0.8, -10.8), c = "light", rot = V(0, -12, 0) },
		{ n = "EarL", s = V(0.7, 4, 3.8), o = V(-3.1, 1.4, -7.2), c = "dark" },
		{ n = "EarR", s = V(0.7, 4, 3.8), o = V(3.1, 1.4, -7.2), c = "dark" },
		{ n = "Tuft", s = V(3, 1.2, 3), o = V(0, 3.8, -7.6), c = "dark" },
		{ n = "Tail", s = V(0.8, 0.8, 2.2), o = V(0, 1.4, 6.1), c = "dark" },
	}
	addEyes(parts, 1.8, -10.45, 1.6)
	add({
		id = "mammoth", name = "Mammouth", desc = "Lent mais très rentable. Ne te désarçonne jamais.",
		speed = 25, value = 2.5, weight = 9, tameTime = 8, buckAfter = nil, trait = "stable",
		weaveAmp = 0, weaveFreq = 1, rootY = 7.5,
		body = { s = V(8, 7, 11), c = "body" },
		palette = { body = C(118, 78, 50), dark = C(80, 52, 34), light = C(242, 232, 204), accent = C(200, 90, 60), eye = C(20, 20, 20) },
		parts = parts, legs = quadLegs(V(2.4, 4, 2.4), -3.5, 2.6, 3.8), wings = {},
	})
end

-- 6. Tricératops : solide, rentable.
do
	local parts = {
		{ n = "Head", s = V(3.6, 3.6, 3.8), o = V(0, 0.2, -6.2), c = "body" },
		{ n = "Frill", s = V(7, 6, 0.8), o = V(0, 2.0, -4.3), c = "accent", rot = V(-20, 0, 0) },
		{ n = "NoseHorn", s = V(0.8, 0.8, 1.8), o = V(0, 0.6, -8.9), c = "light" },
		{ n = "BrowL", s = V(0.7, 0.7, 2.6), o = V(-1.2, 1.8, -8.0), c = "light", rot = V(-15, 0, 0) },
		{ n = "BrowR", s = V(0.7, 0.7, 2.6), o = V(1.2, 1.8, -8.0), c = "light", rot = V(-15, 0, 0) },
		{ n = "Tail", s = V(1.4, 1.4, 3.5), o = V(0, 0, 6.3), c = "dark" },
	}
	addEyes(parts, 1.0, -8.05, 1.5)
	add({
		id = "trike", name = "Tricératops", desc = "Un bouclier vivant. Rentable et endurant.",
		speed = 30, value = 2, weight = 12, tameTime = 7, buckAfter = 14, trait = "tank",
		weaveAmp = 2, weaveFreq = 0.7, rootY = 4.85,
		body = { s = V(5.5, 4.5, 9), c = "body" },
		palette = { body = C(96, 166, 98), dark = C(64, 120, 72), light = C(246, 240, 214), accent = C(230, 120, 60), eye = C(20, 20, 20) },
		parts = parts, legs = quadLegs(V(1.6, 2.6, 1.6), -2.25, 1.9, 3.0), wings = {},
	})
end

-- 7. Wyverne : vole haut, rare et très rentable. Il faut la lasso en plein bond.
do
	local parts = {
		{ n = "Head", s = V(2.4, 2.4, 3), o = V(0, 0.8, -5.0), c = "body" },
		{ n = "Snout", s = V(1.4, 1.2, 1.6), o = V(0, 0.4, -6.8), c = "dark" },
		{ n = "Tail", s = V(1.2, 1.2, 4), o = V(0, -0.2, 5.5), c = "dark" },
		{ n = "TailTip", s = V(2, 0.4, 2), o = V(0, -0.2, 8), c = "accent" },
		{ n = "HornL", s = V(0.4, 0.4, 1.4), o = V(-0.7, 2.2, -4.5), c = "light" },
		{ n = "HornR", s = V(0.4, 0.4, 1.4), o = V(0.7, 2.2, -4.5), c = "light" },
		{ n = "Spine", s = V(0.6, 1, 5), o = V(0, 2.0, 0.5), c = "accent" },
	}
	addEyes(parts, 1.3, -6.45, 0.8)
	add({
		id = "wyvern", name = "Wyverne", desc = "Elle vole à 12 m du sol. Lasso-la en plein bond !",
		speed = 56, value = 3.5, weight = 7, tameTime = 6, buckAfter = 10, trait = "fly",
		weaveAmp = 8, weaveFreq = 0.5, rootY = 12, flying = true,
		body = { s = V(3, 3, 7), c = "body" },
		palette = { body = C(120, 70, 190), dark = C(70, 40, 120), light = C(240, 230, 255), accent = C(255, 110, 200), eye = C(255, 240, 80) },
		parts = parts, legs = {},
		wings = {
			{ n = "WingL", s = V(7, 0.35, 3.6), hip = V(-1.5, 1.0, -0.4), side = -1, c = "accent" },
			{ n = "WingR", s = V(7, 0.35, 3.6), hip = V(1.5, 1.0, -0.4), side = 1, c = "accent" },
		},
	})
end

Species.ById = {}
for _, def in ipairs(Species.List) do
	Species.ById[def.id] = def
end

return Species
