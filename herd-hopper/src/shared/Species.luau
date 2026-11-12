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
	def.seat = V(0, def.seatY or (def.body.s.Y / 2 + 2.1), def.seatZ or 0.4)
	table.insert(Species.List, def)
end

-- Copie agrandie d'une espèce (pour les boss). Toutes les dimensions sont multipliées par k.
local function scaled(base, k, patch)
	local function sv(v)
		return v * k
	end
	local def = table.clone(base)
	def.body = { s = sv(base.body.s), c = base.body.c }
	def.rootY = base.rootY * k
	def.seat = nil
	def.seatY = (base.seatY or (base.body.s.Y / 2 + 2.1)) * k
	def.parts = {}
	for _, part in ipairs(base.parts) do
		table.insert(def.parts, { n = part.n, s = sv(part.s), o = sv(part.o), c = part.c, rot = part.rot })
	end
	def.legs = {}
	for _, leg in ipairs(base.legs) do
		table.insert(def.legs, { n = leg.n, s = sv(leg.s), hip = sv(leg.hip), phase = leg.phase, c = leg.c })
	end
	def.wings = {}
	for _, wing in ipairs(base.wings) do
		table.insert(def.wings, { n = wing.n, s = sv(wing.s), hip = sv(wing.hip), side = wing.side, c = wing.c })
	end
	for key, value in pairs(patch) do
		def[key] = value
	end
	return def
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
		id = "boar",
		name = "Phacochère",
		desc = "Petit et nerveux. Il zigzague sans cesse.",
		speed = 38,
		value = 1,
		weight = 26,
		tameTime = 5,
		buckAfter = 9,
		trait = "weave",
		weaveAmp = 14,
		weaveFreq = 0.9,
		rootY = 4.4,
		body = { s = V(5, 4, 8), c = "body" },
		palette = {
			body = C(139, 94, 60),
			dark = C(92, 60, 38),
			light = C(238, 226, 200),
			accent = C(255, 150, 170),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1.3, 2.4, 1.3), -2, 1.7, 2.8),
		wings = {},
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
		id = "ostrich",
		name = "Autruche des cimes",
		desc = "Foncière et rapide. Parfaite pour gagner du terrain.",
		speed = 52,
		value = 1.2,
		weight = 16,
		tameTime = 5,
		buckAfter = 10,
		trait = "sprint",
		weaveAmp = 2,
		weaveFreq = 0.6,
		rootY = 7,
		body = { s = V(3.4, 4, 6), c = "body" },
		palette = {
			body = C(176, 72, 56),
			dark = C(112, 44, 38),
			light = C(238, 214, 176),
			accent = C(255, 200, 50),
			eye = C(20, 20, 20),
		},
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
		id = "rhino",
		name = "Rhinocéros",
		desc = "Charge par rafales : +50 % de vitesse toutes les 6 s.",
		speed = 33,
		value = 1.5,
		weight = 15,
		tameTime = 6,
		buckAfter = 11,
		trait = "charge",
		weaveAmp = 0,
		weaveFreq = 1,
		rootY = 5.5,
		body = { s = V(6, 5, 9), c = "body" },
		palette = {
			body = C(136, 138, 150),
			dark = C(96, 98, 110),
			light = C(236, 232, 218),
			accent = C(170, 120, 80),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1.7, 3, 1.7), -2.5, 2.0, 3.2),
		wings = {},
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
		id = "ram",
		name = "Bouquetin",
		desc = "Il bondit à chaque foulée : spectaculaire et rapide.",
		speed = 42,
		value = 1.3,
		weight = 15,
		tameTime = 5,
		buckAfter = 9,
		trait = "hop",
		weaveAmp = 5,
		weaveFreq = 0.8,
		rootY = 4.8,
		body = { s = V(4, 3.6, 6.4), c = "body" },
		palette = {
			body = C(244, 240, 228),
			dark = C(70, 58, 56),
			light = C(255, 255, 255),
			accent = C(210, 180, 130),
			eye = C(255, 255, 255),
		},
		parts = parts,
		legs = quadLegs(V(1, 3, 1), -1.8, 1.3, 2.2),
		wings = {},
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
		id = "mammoth",
		name = "Mammouth",
		desc = "Lent mais très rentable. Ne te désarçonne jamais.",
		speed = 25,
		value = 2.5,
		weight = 9,
		tameTime = 8,
		buckAfter = nil,
		trait = "stable",
		weaveAmp = 0,
		weaveFreq = 1,
		rootY = 7.5,
		body = { s = V(8, 7, 11), c = "body" },
		palette = {
			body = C(118, 78, 50),
			dark = C(80, 52, 34),
			light = C(242, 232, 204),
			accent = C(200, 90, 60),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(2.4, 4, 2.4), -3.5, 2.6, 3.8),
		wings = {},
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
		id = "trike",
		name = "Tricératops",
		desc = "Un bouclier vivant. Rentable et endurant.",
		speed = 30,
		value = 2,
		weight = 12,
		tameTime = 7,
		buckAfter = 14,
		trait = "tank",
		weaveAmp = 2,
		weaveFreq = 0.7,
		rootY = 4.85,
		body = { s = V(5.5, 4.5, 9), c = "body" },
		palette = {
			body = C(96, 166, 98),
			dark = C(64, 120, 72),
			light = C(246, 240, 214),
			accent = C(230, 120, 60),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1.6, 2.6, 1.6), -2.25, 1.9, 3.0),
		wings = {},
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
		id = "wyvern",
		name = "Wyverne",
		desc = "Elle vole à 12 m du sol. Lasso-la en plein bond !",
		speed = 56,
		value = 3.5,
		weight = 7,
		tameTime = 6,
		buckAfter = 10,
		trait = "fly",
		weaveAmp = 8,
		weaveFreq = 0.5,
		rootY = 12,
		flying = true,
		body = { s = V(3, 3, 7), c = "body" },
		palette = {
			body = C(120, 70, 190),
			dark = C(70, 40, 120),
			light = C(240, 230, 255),
			accent = C(255, 110, 200),
			eye = C(255, 240, 80),
		},
		parts = parts,
		legs = {},
		wings = {
			{ n = "WingL", s = V(7, 0.35, 3.6), hip = V(-1.5, 1.0, -0.4), side = -1, c = "accent" },
			{ n = "WingR", s = V(7, 0.35, 3.6), hip = V(1.5, 1.0, -0.4), side = 1, c = "accent" },
		},
	})
end

-- 8. Zèbre : rapide, rayures.
do
	local parts = {
		{ n = "Head", s = V(2.6, 2.8, 3.2), o = V(0, 1.2, -5.2), c = "light" },
		{ n = "Muzzle", s = V(2, 1.6, 1.4), o = V(0, 0.4, -7.1), c = "dark" },
		{ n = "EarL", s = V(0.5, 1.2, 0.5), o = V(-0.9, 3.2, -4.2), c = "dark" },
		{ n = "EarR", s = V(0.5, 1.2, 0.5), o = V(0.9, 3.2, -4.2), c = "dark" },
		{ n = "Mane", s = V(0.8, 1.2, 3), o = V(0, 2.5, -3), c = "dark" },
		{ n = "Tail", s = V(0.5, 2.2, 0.5), o = V(0, 0.2, 4.1), c = "dark" },
		{ n = "StripeA", s = V(4.6, 4.2, 0.7), o = V(0, 0, -2.4), c = "dark" },
		{ n = "StripeB", s = V(4.6, 4.2, 0.7), o = V(0, 0, -0.8), c = "dark" },
		{ n = "StripeC", s = V(4.6, 4.2, 0.7), o = V(0, 0, 0.8), c = "dark" },
		{ n = "StripeD", s = V(4.6, 4.2, 0.7), o = V(0, 0, 2.4), c = "dark" },
	}
	addEyes(parts, 1.7, -6.75, 1.0)
	add({
		id = "zebra",
		name = "Zèbre",
		desc = "Rapide et élégant, on le repère de loin.",
		speed = 46,
		value = 1.2,
		weight = 22,
		tameTime = 5,
		buckAfter = 9,
		trait = "weave",
		weaveAmp = 6,
		weaveFreq = 0.8,
		rootY = 5.2,
		body = { s = V(4.4, 4, 7.6), c = "body" },
		palette = {
			body = C(246, 246, 246),
			dark = C(34, 34, 40),
			light = C(250, 250, 250),
			accent = C(200, 170, 140),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1, 3.2, 1), -2, 1.4, 2.6),
		wings = {},
	})
end

-- 9. Lion : rare, rapide, très rentable.
do
	local parts = {
		{ n = "Mane", s = V(4.6, 4.6, 3.4), o = V(0, 0.9, -5.4), c = "dark" },
		{ n = "Face", s = V(2.8, 2.6, 2.4), o = V(0, 0.5, -7.0), c = "body" },
		{ n = "Nose", s = V(0.9, 0.7, 0.5), o = V(0, 0.4, -8.3), c = "accent" },
		{ n = "EarL", s = V(0.7, 0.7, 0.5), o = V(-1.5, 3.2, -5.4), c = "dark" },
		{ n = "EarR", s = V(0.7, 0.7, 0.5), o = V(1.5, 3.2, -5.4), c = "dark" },
		{ n = "Tail", s = V(0.5, 0.5, 3), o = V(0, 0.8, 5), c = "body" },
		{ n = "TailTuft", s = V(1, 1, 1.2), o = V(0, 0.8, 6.8), c = "dark" },
	}
	addEyes(parts, 1.0, -8.0, 0.9)
	add({
		id = "lion",
		name = "Lion",
		desc = "Rare et rapide. Un vrai roi pour ton zoo.",
		speed = 50,
		value = 2.4,
		weight = 7,
		tameTime = 6,
		buckAfter = 10,
		trait = "sprint",
		weaveAmp = 3,
		weaveFreq = 0.6,
		rootY = 4.7,
		body = { s = V(4.4, 3.8, 7), c = "body" },
		palette = {
			body = C(214, 160, 80),
			dark = C(140, 88, 40),
			light = C(240, 215, 170),
			accent = C(60, 40, 40),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1.3, 2.8, 1.3), -1.9, 1.5, 2.4),
		wings = {},
	})
end

-- 10. Hippopotame : lent, costaud.
do
	local parts = {
		{ n = "Head", s = V(4.4, 3.6, 4.6), o = V(0, 0.2, -6.6), c = "body" },
		{ n = "Jaw", s = V(4.2, 1.6, 2.2), o = V(0, -1.6, -8.4), c = "dark" },
		{ n = "NostrilL", s = V(0.7, 0.5, 0.5), o = V(-1.1, 1.2, -8.8), c = "dark" },
		{ n = "NostrilR", s = V(0.7, 0.5, 0.5), o = V(1.1, 1.2, -8.8), c = "dark" },
		{ n = "EarL", s = V(0.9, 0.9, 0.5), o = V(-1.7, 2.4, -5), c = "dark" },
		{ n = "EarR", s = V(0.9, 0.9, 0.5), o = V(1.7, 2.4, -5), c = "dark" },
		{ n = "Tail", s = V(0.6, 0.6, 1.4), o = V(0, 1.4, 5.2), c = "dark" },
	}
	addEyes(parts, 1.7, -8.8, 1.7)
	add({
		id = "hippo",
		name = "Hippopotame",
		desc = "Lent mais massif. Il adore la boue du marais.",
		speed = 28,
		value = 1.8,
		weight = 24,
		tameTime = 6,
		buckAfter = 12,
		trait = "stable",
		weaveAmp = 2,
		weaveFreq = 0.5,
		rootY = 4.4,
		body = { s = V(6.4, 4.8, 8.4), c = "body" },
		palette = {
			body = C(132, 120, 146),
			dark = C(96, 84, 110),
			light = C(230, 220, 236),
			accent = C(220, 150, 160),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1.8, 2, 1.8), -2.4, 2.2, 2.8),
		wings = {},
	})
end

-- 11. Crocodile : long et bas, ondule.
do
	local parts = {
		{ n = "Head", s = V(2.6, 1.6, 5), o = V(0, 0, -8), c = "body" },
		{ n = "Teeth", s = V(2.4, 0.4, 4.6), o = V(0, -0.9, -8), c = "light" },
		{ n = "Tail", s = V(2.4, 1.6, 6), o = V(0, 0, 8), c = "dark" },
		{ n = "TailTip", s = V(1.2, 1, 3), o = V(0, 0, 12), c = "dark" },
		{ n = "PlateA", s = V(1.4, 0.7, 1.4), o = V(0, 1.4, -2), c = "dark" },
		{ n = "PlateB", s = V(1.4, 0.7, 1.4), o = V(0, 1.4, 0.2), c = "dark" },
		{ n = "PlateC", s = V(1.4, 0.7, 1.4), o = V(0, 1.4, 2.4), c = "dark" },
	}
	addEyes(parts, 1.1, -6.2, 1.0)
	add({
		id = "crocodile",
		name = "Crocodile",
		desc = "Il ondule dans le marais. Garde tes distances !",
		speed = 40,
		value = 1.9,
		weight = 9,
		tameTime = 6,
		buckAfter = 10,
		trait = "weave",
		weaveAmp = 10,
		weaveFreq = 1.1,
		rootY = 2.5,
		body = { s = V(3.8, 2.2, 10), c = "body" },
		palette = {
			body = C(86, 130, 70),
			dark = C(52, 88, 48),
			light = C(240, 236, 210),
			accent = C(200, 160, 60),
			eye = C(255, 240, 80),
		},
		parts = parts,
		legs = quadLegs(V(1, 1.4, 1), -1.1, 1.8, 3.2),
		wings = {},
	})
end

-- 12. Flamant : ostrich-like, rose.
do
	local parts = {
		{ n = "Neck", s = V(0.9, 4.5, 0.9), o = V(0, 3.9, -2.1), c = "light" },
		{ n = "Head", s = V(1.7, 1.5, 2.4), o = V(0, 6.5, -3.0), c = "body" },
		{ n = "Beak", s = V(1, 0.9, 2), o = V(0, 6.2, -4.8), c = "dark" },
		{ n = "TailA", s = V(2.2, 2.2, 1.6), o = V(0, 1.4, 3.8), c = "light" },
		{ n = "WingL", s = V(0.5, 2.4, 3.2), o = V(-1.9, 0.4, 0.3), c = "accent" },
		{ n = "WingR", s = V(0.5, 2.4, 3.2), o = V(1.9, 0.4, 0.3), c = "accent" },
	}
	addEyes(parts, 6.8, -3.9, 0.85)
	add({
		id = "flamingo",
		name = "Flamant rose",
		desc = "Haut sur pattes et très rapide dans les marais.",
		speed = 48,
		value = 1.3,
		weight = 20,
		tameTime = 5,
		buckAfter = 10,
		trait = "sprint",
		weaveAmp = 2,
		weaveFreq = 0.6,
		rootY = 7,
		body = { s = V(3.2, 3.8, 5.6), c = "body" },
		palette = {
			body = C(255, 130, 168),
			dark = C(220, 90, 130),
			light = C(255, 200, 216),
			accent = C(255, 90, 140),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = {
			{ n = "LegL", s = V(0.7, 5, 0.7), hip = V(-1, -1.9, 0.4), phase = 0, c = "dark" },
			{ n = "LegR", s = V(0.7, 5, 0.7), hip = V(1, -1.9, 0.4), phase = math.pi, c = "dark" },
		},
		wings = {},
	})
end

-- 13. Chameau : bosse confortable, endurant.
do
	local parts = {
		{ n = "Hump", s = V(2.6, 2.2, 2.6), o = V(0, 3.1, 0.4), c = "dark" },
		{ n = "Neck", s = V(1.4, 3.4, 1.4), o = V(0, 2.8, -4.2), c = "body" },
		{ n = "Head", s = V(2.2, 2, 3), o = V(0, 4.6, -5.2), c = "body" },
		{ n = "Lip", s = V(1.6, 1, 1), o = V(0, 4.2, -6.9), c = "light" },
		{ n = "Tail", s = V(0.5, 2, 0.5), o = V(0, 0.4, 4.1), c = "dark" },
	}
	addEyes(parts, 5.1, -6.2, 0.9)
	add({
		id = "camel",
		name = "Chameau",
		desc = "Une bosse confortable et une grande endurance.",
		speed = 36,
		value = 1.5,
		weight = 26,
		tameTime = 6,
		buckAfter = 13,
		trait = "stable",
		weaveAmp = 3,
		weaveFreq = 0.6,
		rootY = 6.2,
		seatY = 5.6,
		body = { s = V(4.4, 4.2, 7.6), c = "body" },
		palette = {
			body = C(205, 165, 105),
			dark = C(160, 120, 70),
			light = C(240, 220, 180),
			accent = C(180, 90, 60),
			eye = C(20, 20, 20),
		},
		parts = parts,
		legs = quadLegs(V(1.1, 4.2, 1.1), -2.1, 1.4, 2.8),
		wings = {},
	})
end

-- 14. Salamandre de lave : rapide, rentable.
do
	local parts = {
		{ n = "Head", s = V(2.8, 1.6, 4), o = V(0, 0, -6.6), c = "body" },
		{ n = "Tail", s = V(2.2, 1.4, 6), o = V(0, 0, 7), c = "dark" },
		{ n = "SpotA", s = V(1.2, 0.5, 1.2), o = V(-0.8, 1.2, -1), c = "accent" },
		{ n = "SpotB", s = V(1.2, 0.5, 1.2), o = V(0.8, 1.2, 1.2), c = "accent" },
		{ n = "SpotC", s = V(1.2, 0.5, 1.2), o = V(-0.6, 1.2, 3), c = "accent" },
	}
	addEyes(parts, 0.9, -8.3, 1.0)
	add({
		id = "salamander",
		name = "Salamandre de lave",
		desc = "Sa peau brille comme la braise.",
		speed = 44,
		value = 2.2,
		weight = 14,
		tameTime = 6,
		buckAfter = 10,
		trait = "weave",
		weaveAmp = 8,
		weaveFreq = 1.0,
		rootY = 2.4,
		body = { s = V(3.4, 2, 9), c = "body" },
		palette = {
			body = C(96, 44, 34),
			dark = C(60, 30, 26),
			light = C(255, 200, 120),
			accent = C(255, 120, 30),
			eye = C(255, 230, 80),
		},
		parts = parts,
		legs = quadLegs(V(1, 1.4, 1), -1, 1.6, 2.8),
		wings = {},
	})
end

-- Boss : versions géantes, rapportent beaucoup au zoo. Un seul exemplaire (variante unique).
local boss = {}
local function addBoss(base, k, patch)
	local def = scaled(Species.ById_[base], k, patch)
	def.boss = true
	def.weight = 0
	def.bossRide = 9
	def.buckAfter = 3
	add(def)
end
Species.ById_ = {}
for _, def in ipairs(Species.List) do
	Species.ById_[def.id] = def
end
boss.elephant = {
	id = "elephant",
	name = "Éléphant Alpha",
	desc = "Le roi de la savane. Gris, immense, impossible à ignorer.",
	speed = 34,
	value = 9,
	palette = {
		body = C(150, 150, 160),
		dark = C(110, 110, 124),
		light = C(250, 244, 226),
		accent = C(220, 100, 90),
		eye = C(20, 20, 20),
	},
}
boss.croc_king = {
	id = "croc_king",
	name = "Crocodile Roi",
	desc = "Une couronne d'or, un sourire de dents. Il règne sur le marais.",
	speed = 40,
	value = 10,
	palette = {
		body = C(60, 110, 60),
		dark = C(40, 70, 40),
		light = C(250, 240, 200),
		accent = C(255, 205, 60),
		eye = C(255, 90, 60),
	},
}
boss.sphinx = {
	id = "sphinx",
	name = "Sphinx des sables",
	desc = "Un lion de légende au pelage d'or. Il garde le désert.",
	speed = 46,
	value = 11,
	palette = {
		body = C(236, 196, 96),
		dark = C(190, 140, 50),
		light = C(255, 240, 190),
		accent = C(90, 60, 40),
		eye = C(255, 255, 255),
	},
}
boss.dragon = {
	id = "dragon",
	name = "Dragon Ancien",
	desc = "Le maître du volcan. Il crache la braise.",
	speed = 54,
	value = 14,
	palette = {
		body = C(190, 40, 40),
		dark = C(110, 20, 30),
		light = C(255, 220, 160),
		accent = C(255, 150, 30),
		eye = C(255, 240, 80),
	},
}
addBoss("mammoth", 1.5, boss.elephant)
addBoss("crocodile", 1.9, boss.croc_king)
addBoss("lion", 1.8, boss.sphinx)
addBoss("wyvern", 1.9, boss.dragon)

Species.ById = {}
for _, def in ipairs(Species.List) do
	Species.ById[def.id] = def
end
Species.ById_ = nil

function Species.isBoss(def)
	return def.boss == true
end

-- Nombre de variantes obtenables : 3 pour un animal normal, 1 pour un boss.
function Species.variantCount(def, totalVariants)
	return def.boss and 1 or totalVariants
end

return Species
