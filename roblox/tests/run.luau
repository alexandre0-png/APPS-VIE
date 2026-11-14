--!nocheck
-- Tests de la logique pure (aucun service Roblox) avec Lune, à lancer depuis la racine du dépôt :
--   lune run roblox/tests/run.luau
-- Config n'utilise que Color3.fromRGB : on charge le module avec un Color3 simulé dans son environnement.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local chunk = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), {
	debugName = "Config",
	environment = {
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
		},
	},
})
local Config = chunk()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then
		passed += 1
	else
		failed += 1
		print("  ECHEC : " .. name)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- fmt ---------------------------------------------------------------------------------
check("fmt(0)", Config.fmt(0) == "0")
check("fmt(9.5)", Config.fmt(9.5) == "9.5")
check("fmt(999)", Config.fmt(999) == "999")
check("fmt(999.9) arrondi vers le bas", Config.fmt(999.9) == "999")
check("fmt(1000)", Config.fmt(1000) == "1.00K")
check("fmt(15500)", Config.fmt(15500) == "15.5K")
check("fmt(123456)", Config.fmt(123456) == "123K")
check("fmt(1e6)", Config.fmt(1e6) == "1.00M")
check("fmt(1e12)", Config.fmt(1e12) == "1.00T")
check("fmt(NaN) sans erreur", Config.fmt(0 / 0) == "0")
check("fmt(inf)", Config.fmt(math.huge) == "∞")

-- fmtTime -----------------------------------------------------------------------------
check("fmtTime(0)", Config.fmtTime(0) == "0s")
check("fmtTime(59)", Config.fmtTime(59) == "59s")
check("fmtTime(60)", Config.fmtTime(60) == "1m00")
check("fmtTime(125)", Config.fmtTime(125) == "2m05")
check("fmtTime(0.2) arrondi au-dessus", Config.fmtTime(0.2) == "1s")
check("fmtTime négatif", Config.fmtTime(-5) == "0s")

-- vitesse, vol, renaissance ---------------------------------------------------------------
check("stealTime(0)", near(Config.stealTime(0), 1.3))
check("stealTime décroît", Config.stealTime(5) < Config.stealTime(4))
check("stealTime(8) ~ 0.354", near(Config.stealTime(8), 0.3542, 0.0005))
check("walkSpeed(0) = 16", near(Config.walkSpeed(0), 16))
check("walkSpeed croît", Config.walkSpeed(100) > Config.walkSpeed(10))
check("walkSpeed plafonné à 60", Config.walkSpeed(1e9) <= 60)
check("rebirthCost(0)", Config.rebirthCost(0) == 5e7)
check("rebirthCost(1)", Config.rebirthCost(1) == 3.5e8)

-- pets ----------------------------------------------------------------------------------
check("petIncome Poussin normal", near(Config.petIncome(1, 2, 1), 1))
check("petIncome Alien Colossal Alien", near(Config.petIncome(16, 5, 5), 9000 * 5 * 10))
check("sellValue Poussin", Config.sellValue(1, 2, 1) == 45)
check("petName simple", Config.petName(1, 2, 1) == "Poussin")
check("petName mutation + taille", Config.petName(1, 3, 2) == "Poussin Doré Grand")

-- intégrité des tables --------------------------------------------------------------------
check("6 raretés", #Config.TIERS == 6 and #Config.EGG_PRICE == 6 and #Config.HATCH == 6)
local perTier = {}
for i, p in ipairs(Config.PETS) do
	check("pet " .. i .. " rareté valide", p.tier >= 1 and p.tier <= 6)
	check("pet " .. i .. " revenu > 0", p.inc > 0)
	perTier[p.tier] = (perTier[p.tier] or 0) + 1
end
for t = 1, 6 do
	check("rareté " .. t .. " a au moins un pet", (perTier[t] or 0) >= 1)
end
for t = 2, 6 do
	check("prix des œufs croissants (" .. t .. ")", Config.EGG_PRICE[t] > Config.EGG_PRICE[t - 1])
	check("temps d'éclosion croissants (" .. t .. ")", Config.HATCH[t] > Config.HATCH[t - 1])
end
check("MUTS[1] = aucune mutation x1", Config.MUTS[1].name == "" and Config.MUTS[1].mult == 1)
for i, s in ipairs(Config.SIZES) do
	check("taille " .. i .. " poids > 0", s.weight > 0)
end
for i, r in ipairs(Config.RIVALS) do
	local sum = 0
	for _, w in ipairs(r.weights) do
		sum += w
	end
	check("rival " .. i .. " : 6 poids et somme > 0", #r.weights == 6 and sum > 0)
end

-- améliorations ---------------------------------------------------------------------------
check("Config.upgrade(slots)", Config.upgrade("slots") ~= nil)
check("Config.upgrade(inconnu) = nil", Config.upgrade("nimportequoi") == nil)
for _, u in ipairs(Config.UPGRADES) do
	check(u.key .. " : max > 0", u.max > 0)
	local prev = 0
	for l = 0, u.max - 1 do
		local c = u.cost(l)
		check(u.key .. " niv " .. l .. " : coût fini et croissant", c > prev and c < math.huge)
		check(u.key .. " niv " .. l .. " : description non vide", type(u.desc(l)) == "string" and #u.desc(l) > 0)
		prev = c
	end
end

-- missions et probabilités affichées -------------------------------------------------------------
for _, t in ipairs({ "steal", "hatch", "earn", "train", "pvp", "discover", "sell" }) do
	check("questText " .. t, #Config.questText(t, 3) > 0)
end
local odds = Config.oddsText()
check("oddsText affiche des pourcentages", odds:find("%%") ~= nil)
local w = 0
for _, m in ipairs(Config.MUTS) do
	w += m.weight
end
check("poids des mutations = 100", near(w, 100, 0.0001))
w = 0
for _, z in ipairs(Config.SIZES) do
	w += z.weight
end
check("poids des tailles = 100", near(w, 100, 0.0001))

-- Rules (règles pures du serveur) ---------------------------------------------------------------
local Rules = luau.load(fs.readFile("roblox/src/ServerScriptService/Rules.lua"), { debugName = "Rules" })().new(Config)
local function const(v)
	return function()
		return v
	end
end

-- wpick
check("wpick rnd=0 -> premier poids positif", Rules.wpick({ 0, 5, 5 }, const(0)) == 2)
check("wpick rnd~1 -> dernier poids positif", Rules.wpick({ 5, 5, 0 }, const(0.999999)) == 2)
check("wpick ignore un poids à 0", Rules.wpick({ 0, 0, 5 }, const(0.3)) == 3)
check("wpick traite un poids négatif comme 0", Rules.wpick({ 22, -9, 87 }, const(0.21)) == 3)
check("wpick poids tous nuls -> dernier index", Rules.wpick({ 0, 0, 0 }, const(0.5)) == 3)

-- tierWeights / upPoints / pickTier
check("upPoints de base = 12", Rules.upPoints(0, false, false, false) == 12)
check("upPoints cumulés = 87", Rules.upPoints(10, true, true, true) == 87)
for tier = 1, 6 do
	for _, up in ipairs({ -5, 0, 12, 42, 87, 500 }) do
		local w = Rules.tierWeights(tier, up)
		check("tierWeights(" .. tier .. "," .. up .. ") : poids >= 0 et somme 100", w[1] >= 0 and w[2] >= 0 and w[3] >= 0 and near(w[1] + w[2] + w[3], 100))
	end
end
check("rareté 1 : jamais de rareté inférieure", Rules.tierWeights(1, 12)[1] == 0)
check("rareté 6 : jamais de rareté supérieure", Rules.tierWeights(6, 87)[3] == 0)
check("part supérieure plafonnée", Rules.tierWeights(3, 500)[3] == Rules.MAX_UP)
check("pickTier rnd=0 -> inférieure", Rules.pickTier(3, 12, const(0)) == 2)
check("pickTier rnd=0.5 -> identique", Rules.pickTier(3, 12, const(0.5)) == 3)
check("pickTier rnd=0.99 -> supérieure", Rules.pickTier(3, 12, const(0.99)) == 4)
check("pickTier rareté 1 jamais < 1", Rules.pickTier(1, 12, const(0)) >= 1)
check("pickTier rareté 6 jamais > 6", Rules.pickTier(6, 87, const(0.9999)) <= 6)

-- rollPet : résultat toujours valide + distributions
math.randomseed(42)
local nUp, nAlien, nAlienBoost, N = 0, 0, 0, 20000
local valid = true
for _ = 1, N do
	local r = Rules.rollPet(3, 12, false, math.random)
	local def = Config.PETS[r.p]
	if not def or def.tier < 2 or def.tier > 4 or r.s < 1 or r.s > #Config.SIZES or r.m < 1 or r.m > #Config.MUTS then
		valid = false
	end
	if def and def.tier == 4 then
		nUp += 1
	end
	if r.m == 5 then
		nAlien += 1
	end
	if Rules.rollPet(3, 12, true, math.random).m == 5 then
		nAlienBoost += 1
	end
end
check("rollPet : espèce, taille et mutation toujours valides", valid)
check("rollPet : ~12% de rareté supérieure", near(nUp / N, 0.12, 0.02))
check("rollPet : ~1.4% d'Alien sans événement", near(nAlien / N, 0.014, 0.006))
check("rollPet : Alien ~6.8% avec le Biome Alien", near(nAlienBoost / N, 7 / 105 * 1.0, 0.012))

-- revenus, capacités, durées
check("multiplier neutre = 1", Rules.multiplier(0, 0, false, false) == 1)
check("multiplier cumulé = 8.4", near(Rules.multiplier(1, 2, true, true), 1.5 * 1.4 * 2 * 2))
check("capacity", Rules.capacity({ slots = 3 }) == 7)
check("carryCapacity", Rules.carryCapacity({ bag = 2 }) == 3)
check("hatchTime niveau 0", Rules.hatchTime(1, 0) == 8)
check("hatchTime niveau 10", near(Rules.hatchTime(1, 10), 8 * 0.9 ^ 10))
check("shieldTime", Rules.shieldTime(2) == Config.SHIELD_BASE + 2 * Config.SHIELD_PER_LEVEL)
local slots = { { k = "p", p = 1, s = 2, m = 1 }, { k = "e", t = 1, ends = 0 }, false, { k = "p", p = 1, s = 2, m = 1 }, { k = "p", p = 1, s = 2, m = 1 } }
check("income : ignore œufs, vides et emplacements au-delà de la capacité", near(Rules.income(slots, 4, 2), 2 * 2))

-- Rules : pitié, pass d'éclosion, bonus de collection -------------------------------------------
check("rollPet garanti : toujours une rareté au-dessus", (function()
	for tier = 1, 5 do
		for _ = 1, 50 do
			if Config.PETS[Rules.rollPet(tier, 12, false, math.random, true).p].tier ~= tier + 1 then
				return false
			end
		end
	end
	return true
end)())
check("rollPet garanti : rareté max inchangée", Rules.rollPet(6, 12, false, math.random, true).tier <= 6)
check("hatchTime pass rapide x0.75", near(Rules.hatchTime(2, 0, true), Config.HATCH[2] * 0.75))
check("hatchTime sans pass inchangé", Rules.hatchTime(2, 0, false) == Config.HATCH[2])
check("multiplier avec bonus de collection", near(Rules.multiplier(0, 0, false, false, 1.3), 1.3))

-- Univers : histoire, zones, rangs, collection ---------------------------------------------------
check("histoire non vide", #Config.STORY >= 5)
local validTypes = { hatch = true, steal = true, train = true, species = true, tier = true, mut = true, puzzle = true, rebirth = true }
for i, c in ipairs(Config.STORY) do
	check("chapitre " .. i .. " : type valide", validTypes[c.type] == true)
	check("chapitre " .. i .. " : objectif > 0 et titre / texte non vides", c.goal > 0 and #c.title > 0 and #c.text > 0)
	check("chapitre " .. i .. " : récompense > 0", Config.storyReward(c, 0) > 0)
	check("chapitre " .. i .. " : type tier a une rareté valide", c.type ~= "tier" or (c.tier ~= nil and c.tier >= 1 and c.tier <= 6))
	check("chapitre " .. i .. " : rival valide", c.rival == nil or Config.RIVALS[c.rival] ~= nil)
	check("chapitre " .. i .. " : texte d'objectif non vide", #Config.storyGoalText(c) > 0)
	check("chapitre " .. i .. " : les espèces demandées existent", c.type ~= "species" or c.goal <= #Config.PETS)
end
check("récompense proportionnelle au revenu", Config.storyReward({ coins = 100, mins = 10 }, 1000) == 600000)
check("une zone par rival", #Config.ZONES == #Config.RIVALS)
check("premier domaine toujours ouvert", Config.zoneUnlocked(0, 1))
for i, z in ipairs(Config.ZONES) do
	check("zone " .. i .. " : chapitre requis atteignable", z.chapter >= 0 and z.chapter <= #Config.STORY)
	check("zone " .. i .. " : ouverte une fois le chapitre réussi", Config.zoneUnlocked(z.chapter, i))
	check("zone " .. i .. " : fermée avant", z.chapter == 0 or not Config.zoneUnlocked(z.chapter - 1, i))
end
check("zone inconnue fermée", not Config.zoneUnlocked(99, 99))
check("rang 0 = Apprenti", Config.rankFor(0).name == "Apprenti")
check("dernier rang à la fin de l'histoire", Config.rankFor(#Config.STORY).name == "Roi des Couvées")
for i = 2, #Config.RANKS do
	check("rangs croissants (" .. i .. ")", Config.RANKS[i].chapter > Config.RANKS[i - 1].chapter)
end
check("bonus de collection neutre", Config.collectionBonus(0) == 1 and Config.collectionBonus(2) == 1)
check("bonus de collection par paliers", near(Config.collectionBonus(3), 1.05) and near(Config.collectionBonus(18), 1.30))
check("pitié définie", Config.PITY_EVERY >= 2)
check("sons : chaque clé a id, speed, vol", (function()
	for _, def in pairs(Config.SOUNDS) do
		if type(def.id) ~= "string" or type(def.speed) ~= "number" or type(def.vol) ~= "number" then
			return false
		end
	end
	return true
end)())

-- Achats : un ID à 0 (ou invalide) désactive proprement l'achat --------------------------------------
check("purchasable(0) = faux", not Config.purchasable({ id = 0 }))
check("purchasable(négatif) = faux", not Config.purchasable({ id = -5 }))
check("purchasable(décimal) = faux", not Config.purchasable({ id = 12.5 }))
check("purchasable(texte) = faux", not Config.purchasable({ id = "123" }))
check("purchasable(nil) = faux", not Config.purchasable({}))
check("purchasable(ID valide) = vrai", Config.purchasable({ id = 123456789 }))
check("message d'indisponibilité défini", #Config.UNAVAILABLE_MESSAGE > 0)
for name, def in pairs(Config.PASSES) do
	check("pass " .. name .. " : id numérique, nom et description", type(def.id) == "number" and #def.name > 0 and #def.desc > 0)
end
for name, def in pairs(Config.PRODUCTS) do
	check("produit " .. name .. " : id numérique, nom et description", type(def.id) == "number" and #def.name > 0 and #def.desc > 0)
end

-- Énigmes des runes -----------------------------------------------------------------------------
check("4 runes et 4 directions", #Config.RUNES == 4 and #Config.RUNE_DIRECTIONS == 4)
local seen, texts = {}, {}
for day = 20000, 20119 do
	local r = Config.riddleFor(day)
	local used, ok = {}, #r.answer == 4
	for _, v in ipairs(r.answer) do
		ok = ok and v >= 1 and v <= 4 and not used[v]
		used[v] = true
	end
	check("énigme jour " .. day .. " : réponse = permutation de 1..4", ok)
	check("énigme jour " .. day .. " : énoncé complet (4 indices)", select(2, r.text:gsub("%.", "")) == 4 and r.text:find("Nord", 1, true) ~= nil and r.text:find("Ouest", 1, true) ~= nil)
	local again = Config.riddleFor(day)
	check("énigme jour " .. day .. " : déterministe", again.text == r.text and table.concat(again.answer, ",") == table.concat(r.answer, ","))
	seen[table.concat(r.answer, ",")] = true
	texts[r.text] = true
end
local distinctAnswers, distinctTexts = 0, 0
for _ in pairs(seen) do
	distinctAnswers += 1
end
for _ in pairs(texts) do
	distinctTexts += 1
end
check("les énigmes varient (>= 12 combinaisons sur 120 jours)", distinctAnswers >= 12)
check("les énoncés varient (>= 60 textes sur 120 jours)", distinctTexts >= 60)
check("puzzleCoins : plancher 2000", Config.puzzleCoins(0) == 2000)
check("puzzleCoins : proportionnel au revenu", Config.puzzleCoins(1000) == 600000)
check("récompense d'énigme : rareté valide", Config.PUZZLE_EGG_TIER >= 1 and Config.PUZZLE_EGG_TIER <= 6)
check("un chapitre d'histoire porte sur l'énigme", (function()
	for _, c in ipairs(Config.STORY) do
		if c.type == "puzzle" then
			return true
		end
	end
	return false
end)())

-- Succès à paliers -----------------------------------------------------------------------------------
check("succès définis", #Config.ACHIEVEMENTS >= 4)
local statNames = { hatched = true, stolen = true, species = true, rb = true, puzzles = true }
for _, a in ipairs(Config.ACHIEVEMENTS) do
	check("succès " .. a.id .. " : statistique connue", statNames[a.stat] == true)
	check("succès " .. a.id .. " : 4 paliers", #a.goals == #Config.ACH_REWARD.coins and #a.goals == #Config.ACH_REWARD.mins)
	for i = 2, #a.goals do
		check("succès " .. a.id .. " : paliers croissants (" .. i .. ")", a.goals[i] > a.goals[i - 1])
	end
	check("succès " .. a.id .. " : Config.achievement retrouve l'id", Config.achievement(a.id) == a)
	if a.stat == "species" then
		check("succès espèces : dernier palier atteignable", a.goals[#a.goals] <= #Config.PETS)
	end
end
check("Config.achievement(inconnu) = nil", Config.achievement("nimportequoi") == nil)
for tier = 1, 4 do
	check("achReward palier " .. tier .. " : plancher", Config.achReward(tier, 0) == Config.ACH_REWARD.coins[tier])
	check("achReward palier " .. tier .. " : proportionnel au revenu", Config.achReward(tier, 1e6) == 1e6 * Config.ACH_REWARD.mins[tier] * 60)
end
for tier = 2, 4 do
	check("récompenses de succès croissantes (" .. tier .. ")", Config.ACH_REWARD.coins[tier] > Config.ACH_REWARD.coins[tier - 1])
end

-- Animations : configuration et garde-fou ---------------------------------------------------------------
local animKeys = { "enabled", "eggShake", "eggBounce", "hatchSquash", "popIn", "shockwave", "harvest", "petBlink", "petLook", "petMouth", "menuTransitions", "reward", "zones", "characterPop", "hen", "eggHalo" }
for _, k in ipairs(animKeys) do
	check("Config.Animations." .. k .. " défini (booléen)", type(Config.Animations[k]) == "boolean")
end
local expectedAnim = {}
for _, k in ipairs(animKeys) do
	expectedAnim[k] = true
end
for k, v in pairs(Config.Animations) do
	check("Config.Animations." .. k .. " est une clé attendue (pas de faute de frappe)", expectedAnim[k] == true and type(v) == "boolean")
end
check("animEnabled : actif par défaut", Config.animEnabled("eggShake") and Config.animEnabled("zones"))
check("animEnabled : clé inconnue = faux", not Config.animEnabled("nimportequoi"))
do
	local saved = Config.Animations.enabled
	Config.Animations.enabled = false
	local anyOn = false
	for _, k in ipairs(animKeys) do
		anyOn = anyOn or Config.animEnabled(k)
	end
	check("animEnabled : interrupteur général coupe tout", not anyOn)
	Config.Animations.enabled = saved
	local one = Config.Animations.petBlink
	Config.Animations.petBlink = false
	check("animEnabled : une animation peut être coupée seule", not Config.animEnabled("petBlink") and Config.animEnabled("petLook"))
	Config.Animations.petBlink = one
end

local Easing = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
local pi = math.pi

-- courbes
check("outBack(0) = 0 et outBack(1) = 1", near(Easing.outBack(0), 0, 1e-9) and near(Easing.outBack(1), 1, 1e-9))
check("outBack dépasse 1 (rebond)", (function()
	local m = 0
	for i = 0, 100 do
		m = math.max(m, Easing.outBack(i / 100))
	end
	return m > 1.05
end)())
check("outElastic bornes", Easing.outElastic(0) == 0 and Easing.outElastic(1) == 1)
check("outBounce bornes", near(Easing.outBounce(0), 0, 1e-9) and near(Easing.outBounce(1), 1, 1e-6))
check("outQuad croissante", (function()
	local prev = -1
	for i = 0, 20 do
		local v = Easing.outQuad(i / 20)
		if v < prev then
			return false
		end
		prev = v
	end
	return true
end)())
check("courbes : entrées hors [0,1] bornées", Easing.outQuad(-3) == 0 and Easing.outQuad(5) == 1 and Easing.clamp01(2) == 1 and Easing.clamp01(-1) == 0)

-- squash & stretch
do
	local sx0, sy0 = Easing.squashStretch(0, 0.4)
	check("squashStretch(0) : écrasé en hauteur, élargi", sy0 < 1 and sx0 > 1)
	local sx1, sy1 = Easing.squashStretch(1, 0.4)
	check("squashStretch(1) = (1, 1)", sx1 == 1 and sy1 == 1)
	local sx2, sy2 = Easing.squashStretch(5, 0.4)
	check("squashStretch(>1) = (1, 1)", sx2 == 1 and sy2 == 1)
	local positive = true
	for i = 0, 100 do
		local sx, sy = Easing.squashStretch(i / 100, 0.9)
		positive = positive and sx >= 0.2 and sy >= 0.2
	end
	check("squashStretch : toujours positif, même fort", positive)
	local _, syEarly = Easing.squashStretch(0.05, 0.4)
	local _, syLate = Easing.squashStretch(0.9, 0.4)
	check("squashStretch : l'amplitude décroît", math.abs(syLate - 1) < math.abs(syEarly - 1))
end

-- rebond des œufs
do
	local ok, hopped = true, false
	for i = 0, 640 do
		local y, sx, sy = Easing.eggHop(i * 0.01, 0.7, 0.6)
		ok = ok and y >= 0 and y <= 0.6 + 1e-9 and sx > 0 and sy > 0
		hopped = hopped or y > 0.3
	end
	check("eggHop : décalage dans [0, hauteur], échelles positives", ok)
	check("eggHop : il y a bien un saut", hopped)
	local y, sx, sy = Easing.eggHop(1.0, 0, 0.6)
	check("eggHop : au repos = (0, 1, 1)", y == 0 and sx == 1 and sy == 1)
	check("eggHop : sommet = hauteur", near(Easing.eggHop(0.3, 0, 0.6), 0.6, 1e-9))
	local _, _, sl = Easing.eggHop(0.52, 0, 0.6)
	check("eggHop : écrasement à l'atterrissage", sl < 1)
	check("eggHop : périodique", near(Easing.eggHop(0.3, 0, 0.6, 3.2), Easing.eggHop(0.3 + 3.2, 0, 0.6, 3.2), 1e-9))
	check("runBounce immobile = 0", Easing.runBounce(1.234, false) == 0)
	local rb = true
	for i = 0, 200 do
		local v = Easing.runBounce(i * 0.05, true)
		rb = rb and v >= 0 and v <= 0.25 + 1e-9
	end
	check("runBounce en mouvement dans [0, 0.25]", rb)
end

-- yeux et bouche
do
	local inRange, minOpen, openCount, total = true, 1, 0, 0
	for seed = 0, 9 do
		for i = 0, 3000 do
			local o = Easing.blinkOpenness(i * 0.01, seed)
			inRange = inRange and o >= 0 and o <= 1
			minOpen = math.min(minOpen, o)
			total += 1
			if o == 1 then
				openCount += 1
			end
		end
	end
	check("blinkOpenness dans [0, 1]", inRange)
	check("blinkOpenness : l'œil se ferme presque entièrement", minOpen <= 0.05)
	check("blinkOpenness : œil ouvert plus de 80 % du temps", openCount / total > 0.8)
	check("blinkOpenness : déterministe", Easing.blinkOpenness(1.7, 3) == Easing.blinkOpenness(1.7, 3))
	local differs = false
	for i = 0, 500 do
		differs = differs or Easing.blinkOpenness(i * 0.01, 0) ~= Easing.blinkOpenness(i * 0.01, 1)
	end
	check("blinkOpenness : deux pets clignent à des moments différents", differs)

	local lookOk, varies, lastDx = true, false, nil
	for i = 0, 2000 do
		local dx, dy = Easing.look(i * 0.05, 2)
		lookOk = lookOk and math.abs(dx) <= 0.85 + 1e-9 and math.abs(dy) <= 0.3 + 1e-9
		if lastDx and dx ~= lastDx then
			varies = true
		end
		lastDx = dx
	end
	check("look : décalages bornés", lookOk)
	check("look : le regard bouge", varies)

	local mOk, zero, wide = true, false, false
	for i = 0, 3000 do
		local m = Easing.mouthOpen(i * 0.01, 4)
		mOk = mOk and m >= 0 and m <= 1
		zero = zero or m == 0
		wide = wide or m > 0.9
	end
	check("mouthOpen dans [0, 1]", mOk)
	check("mouthOpen : tantôt fermée, tantôt grande ouverte", zero and wide)
end

-- barrières de zone
do
	local g = true
	for i = 0, 200 do
		local p = Easing.gatePulse(i * 0.1, 2)
		g = g and p >= 0 and p <= 1
	end
	check("gatePulse dans [0, 1]", g)
end

-- récompenses et secousses de caméra
check("rewardBurst : claim, event, rare définis", Easing.rewardBurst("claim") ~= nil and Easing.rewardBurst("event") ~= nil and Easing.rewardBurst("rare") ~= nil)
check("rewardBurst : pas de confettis pour steal / caught / nil", Easing.rewardBurst("steal") == nil and Easing.rewardBurst("caught") == nil and Easing.rewardBurst(nil) == nil)
check("rewardBurst : intensité croissante claim < event < rare", Easing.REWARD.claim.count < Easing.REWARD.event.count and Easing.REWARD.event.count < Easing.REWARD.rare.count)
for name, b in pairs(Easing.REWARD) do
	check("rewardBurst " .. name .. " : paramètres valides", b.count > 0 and b.minSpeed > 0 and b.maxSpeed > b.minSpeed and b.life > 0)
end
check("FOV_KICK : steal vers l'avant, caught vers l'arrière", Easing.FOV_KICK.steal.delta > 0 and Easing.FOV_KICK.caught.delta < 0 and Easing.FOV_KICK.steal.time > 0 and Easing.FOV_KICK.caught.time > 0)
do
	local b = Easing.REWARD.rare
	local ok, angles = true, {}
	for i = 1, b.count do
		local p = Easing.confettiParticle(i, b.count, b)
		ok = ok and p.angle >= -pi / 2 - 0.9 - 1e-9 and p.angle <= -pi / 2 + 0.9 + 1e-9
		ok = ok and p.speed >= b.minSpeed and p.speed <= b.maxSpeed
		ok = ok and p.hue >= 0 and p.hue < 1 and p.w >= 6 and p.h >= 10
		angles[string.format("%.4f", p.angle)] = true
	end
	check("confettiParticle : éventail vers le haut, vitesses et couleurs valides", ok)
	local distinct = 0
	for _ in pairs(angles) do
		distinct += 1
	end
	check("confettiParticle : angles bien répartis", distinct >= 60)
	check("confettiParticle : déterministe", Easing.confettiParticle(7, b.count, b).angle == Easing.confettiParticle(7, b.count, b).angle)
end

-- garde-fou : désactivée = non exécutée ; erreur = désactivée pour la session, une seule alerte
do
	local failed, calls, errors = {}, 0, 0
	local function yes()
		return true
	end
	local function no()
		return false
	end
	local function onError()
		errors += 1
	end
	check("guard : animation désactivée non exécutée", Easing.guard(no, failed, "a", function()
		calls += 1
	end, onError) == false and calls == 0)
	check("guard : animation active exécutée", Easing.guard(yes, failed, "a", function()
		calls += 1
	end, onError) == true and calls == 1)
	check("guard : l'erreur est capturée (pas de propagation)", Easing.guard(yes, failed, "b", function()
		error("boom")
	end, onError) == false)
	check("guard : l'erreur est signalée une seule fois et l'animation désactivée", errors == 1 and failed.b == true)
	local again = Easing.guard(yes, failed, "b", function()
		calls += 1
	end, onError)
	check("guard : une animation en erreur n'est plus exécutée", again == false and calls == 1 and errors == 1)
	check("guard : les autres animations ne sont pas touchées", Easing.guard(yes, failed, "c", function()
		calls += 1
	end, onError) == true and calls == 2)
	check("guard : sans onError, pas de plantage", Easing.guard(yes, {}, "d", function()
		error("x")
	end) == false)
end

-- Easing : adoucissement et coups de bec ------------------------------------------------------------------
check("inOutSine bornes et milieu", near(Easing.inOutSine(0), 0, 1e-9) and near(Easing.inOutSine(1), 1, 1e-9) and near(Easing.inOutSine(0.5), 0.5, 1e-9))
check("inOutSine croissante", (function()
	local prev = -1
	for i = 0, 40 do
		local v = Easing.inOutSine(i / 40)
		if v < prev then
			return false
		end
		prev = v
	end
	return true
end)())
do
	local inRange, zeros, total, maxPeck = true, 0, 0, 0
	for seed = 0, 5 do
		for i = 0, 3000 do
			local v = Easing.peck(i * 0.01, seed)
			inRange = inRange and v >= 0 and v <= 1
			total += 1
			if v == 0 then
				zeros += 1
			end
			maxPeck = math.max(maxPeck, v)
		end
	end
	check("peck dans [0, 1]", inRange)
	check("peck : la poule picore peu de temps (tête levée > 70 % du temps)", zeros / total > 0.7)
	check("peck : coup de bec profond", maxPeck > 0.95)
	check("peck : déterministe", Easing.peck(3.3, 2) == Easing.peck(3.3, 2))
end

-- Positions des emplacements -----------------------------------------------------------------------------
do
	local seen, ok = {}, true
	for i = 1, 12 do
		local x, z = Config.padLocal(i)
		ok = ok and math.abs(x) <= 26 and math.abs(z) <= 26
		seen[x .. "," .. z] = true
	end
	local n = 0
	for _ in pairs(seen) do
		n += 1
	end
	check("padLocal : 12 emplacements distincts dans la plateforme", ok and n == 12)
	local x1, z1 = Config.padLocal(1)
	local x12, z12 = Config.padLocal(12)
	check("padLocal : coins de la grille", x1 == -15 and z1 == -6 and x12 == 15 and z12 == 16)
end

-- Cinématiques : configuration -----------------------------------------------------------------------------
check("cineEnabled : actif par défaut", Config.cineEnabled("intro") and Config.cineEnabled("tutorial") and Config.cineEnabled("firstZone") and Config.cineEnabled("firstRare"))
check("cineEnabled : clé inconnue = faux", not Config.cineEnabled("nimportequoi"))
do
	local saved = Config.Cinematics.enabled
	Config.Cinematics.enabled = false
	local any = false
	for _, id in ipairs(Config.CINE_IDS) do
		any = any or Config.cineEnabled(id)
	end
	check("cineEnabled : interrupteur général coupe tout", not any)
	Config.Cinematics.enabled = saved
	local one = Config.Cinematics.intro
	Config.Cinematics.intro = false
	check("cineEnabled : une cinématique peut être coupée seule", not Config.cineEnabled("intro") and Config.cineEnabled("tutorial"))
	Config.Cinematics.intro = one
end
check("CINE_IDS : chaque identifiant est un réglage booléen", (function()
	for _, id in ipairs(Config.CINE_IDS) do
		if type(Config.Cinematics[id]) ~= "boolean" then
			return false
		end
	end
	return #Config.CINE_IDS == 4
end)())
check("Cinematics : watchdog positif", type(Config.Cinematics.watchdog) == "number" and Config.Cinematics.watchdog > 0)

local Cinema = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Cinema.lua"), { debugName = "Cinema" })().new(Easing)

local function checkDef(label, def, maxTotal, minTotal)
	local seq, err = Cinema.sequence(def)
	check(label .. " : séquence valide (" .. tostring(err) .. ")", seq ~= nil)
	if not seq then
		return
	end
	check(label .. " : durée totale " .. seq.total .. " s dans [" .. minTotal .. ", " .. maxTotal .. "]", seq.total >= minTotal and seq.total <= maxTotal)
	for i, shot in ipairs(seq.shots) do
		local pre = label .. " plan " .. i
		check(pre .. " : ancre connue", Config.CINE_ANCHORS[shot.anchor] == true)
		check(pre .. " : pos et look = 3 nombres", #shot.pos == 3 and #shot.look == 3 and type(shot.pos[1]) == "number" and type(shot.look[3]) == "number")
		check(pre .. " : toPos / toLook valides si présents", (shot.toPos == nil or #shot.toPos == 3) and (shot.toLook == nil or #shot.toLook == 3))
		check(pre .. " : durée dans ]0, 8]", shot.dur > 0 and shot.dur <= 8)
		check(pre .. " : texte non vide et court", #shot.text > 0 and (utf8.len(shot.text) or 999) <= 140)
		check(pre .. " : caméra au-dessus du sol", shot.pos[2] > 1 and (shot.toPos == nil or shot.toPos[2] > 1))
	end
end
checkDef("intro", Config.CINE.intro, 20, 10)
checkDef("tutoriel", Config.CINE.tutorial, 15, 6)
for idx = 2, #Config.ZONES do
	local def = Config.cineFirstZone(idx)
	checkDef("première zone " .. idx, def, 10, 3)
	check("première zone " .. idx .. " : ancre du bon domaine", def.shots[1].anchor == "rival" .. idx)
	check("première zone " .. idx .. " : le nom de la zone est dans le texte", def.shots[1].text:find(Config.ZONES[idx].name, 1, true) ~= nil)
end
do
	local def = Config.cineFirstRare("Dragon Doré", "Mythique", "+1.1K/s.")
	checkDef("premier pet rare", def, 10, 3)
	check("premier pet rare : ancre = emplacement, nom dans le texte", def.shots[1].anchor == "pad" and def.shots[1].text:find("Dragon Doré", 1, true) ~= nil)
end
check("l'intro explique le contexte : ferme, poule, œufs, but", (function()
	local all = ""
	for _, shot in ipairs(Config.CINE.intro.shots) do
		all = all .. " " .. shot.text
	end
	return all:find("ferme", 1, true) and all:find("Poule", 1, true) and all:find("œufs", 1, true) and all:find("reconstruis", 1, true)
end)() ~= nil)
check("le tutoriel couvre récolte, éclosion, zones", (function()
	local all = ""
	for _, shot in ipairs(Config.CINE.tutorial.shots) do
		all = all .. " " .. shot.text
	end
	return all:find("RÉCOLTE", 1, true) and all:find("ÉCLOSION", 1, true) and all:find("ZONES", 1, true)
end)() ~= nil)

-- Cinéma : séquences, lecteur (lecture, skip, abandon, reprise), caméra, directeur -------------------------
do
	check("sequence : refuse nil, vide et durées invalides", Cinema.sequence(nil) == nil and Cinema.sequence({}) == nil and Cinema.sequence({ shots = {} }) == nil
		and Cinema.sequence({ shots = { { dur = 0 } } }) == nil and Cinema.sequence({ shots = { { dur = -1 } } }) == nil and Cinema.sequence({ shots = { { dur = "3" } } }) == nil)
	local seq = Cinema.sequence({ id = "t", shots = { { dur = 2, pos = { 0, 0, 0 }, look = { 0, 0, 1 } }, { dur = 3, pos = { 0, 0, 0 }, look = { 0, 0, 1 }, toPos = { 10, 20, 30 } }, { dur = 1.5, pos = { 1, 1, 1 }, look = { 0, 0, 1 } } } })
	check("sequence : durée totale et départs cumulés", seq.total == 6.5 and seq.starts[1] == 0 and seq.starts[2] == 2 and seq.starts[3] == 5)
	local i, p = Cinema.shotAt(seq, 0)
	check("shotAt(0) = plan 1, progression 0", i == 1 and p == 0)
	i, p = Cinema.shotAt(seq, 1)
	check("shotAt(1) = plan 1, progression 0.5", i == 1 and near(p, 0.5))
	i, p = Cinema.shotAt(seq, 2)
	check("shotAt(frontière) = plan suivant à 0", i == 2 and p == 0)
	i, p = Cinema.shotAt(seq, 4.999)
	check("shotAt(juste avant la fin du plan 2)", i == 2 and p > 0.99 and p < 1)
	i, p = Cinema.shotAt(seq, 5)
	check("shotAt(5) = plan 3 à 0", i == 3 and p == 0)
	check("shotAt(fin) et au-delà = nil", Cinema.shotAt(seq, 6.5) == nil and Cinema.shotAt(seq, 100) == nil)
	i, p = Cinema.shotAt(seq, -5)
	check("shotAt(temps négatif) ramené au début", i == 1 and p == 0)

	local shot = seq.shots[2]
	local pos0 = Cinema.cameraAt(shot, 0)
	local pos1 = Cinema.cameraAt(shot, 1)
	local posMid, lookMid = Cinema.cameraAt(shot, 0.5)
	check("cameraAt : début = pos, fin = toPos", pos0[1] == 0 and pos1[1] == 10 and pos1[2] == 20 and pos1[3] == 30)
	check("cameraAt : milieu = milieu du trajet", near(posMid[1], 5) and near(posMid[2], 10) and near(posMid[3], 15))
	check("cameraAt : sans toLook, le point visé reste fixe", lookMid[1] == 0 and lookMid[3] == 1)
	local pa = Cinema.cameraAt(shot, -3)
	local pb = Cinema.cameraAt(shot, 9)
	check("cameraAt : progression bornée", pa[1] == 0 and pb[1] == 10)
	local fixed = Cinema.cameraAt(seq.shots[1], 0.7)
	check("cameraAt : sans toPos, position constante", fixed[1] == 0 and fixed[2] == 0 and fixed[3] == 0)

	-- lecteur
	local pl = Cinema.player(seq)
	check("player : au repos, update = nil et skip / abort refusés", pl.update(0) == nil and pl.skip() == false and pl.abort() == false and pl.state == "idle")
	pl.play(10)
	local ev = pl.update(10)
	check("player : premier plan signalé", ev.shot == 1 and ev.shotChanged == true and ev.finished == false)
	ev = pl.update(10.5)
	check("player : pas de nouveau signal dans le même plan", ev.shot == 1 and ev.shotChanged == false)
	ev = pl.update(12)
	check("player : changement de plan signalé une fois", ev.shot == 2 and ev.shotChanged == true)
	ev = pl.update(12.1)
	check("player : puis plus rien", ev.shotChanged == false)
	ev = pl.update(16.5)
	check("player : fin = completed, une seule fois", ev.finished == true and ev.reason == "completed" and pl.state == "done" and pl.reason == "completed")
	check("player : après la fin, update = nil", pl.update(17) == nil and pl.update(99) == nil)

	-- salve complète à 60 images/s : autant de signaux de plan que de plans, un seul signal de fin
	local pf = Cinema.player(seq)
	pf.play(0)
	local changes, finishes, last = 0, 0, nil
	for f = 0, math.ceil(seq.total * 60) + 5 do
		local e = pf.update(f / 60)
		if e then
			if e.shotChanged then
				changes += 1
			end
			if e.finished then
				finishes += 1
			end
			last = e
		end
	end
	check("lecture complète : un signal par plan et une seule fin", changes == 3 and finishes == 1 and last.reason == "completed")

	-- skip / reprise
	local ps = Cinema.player(seq)
	ps.play(0)
	ps.update(3)
	check("skip en cours de lecture", ps.skip() == true and ps.state == "done" and ps.reason == "skipped")
	check("après un skip : update = nil, second skip refusé", ps.update(4) == nil and ps.skip() == false)
	ps.play(100)
	ev = ps.update(100)
	check("reprise après un skip : repart au plan 1", ps.state == "playing" and ps.reason == nil and ev.shot == 1 and ev.shotChanged == true)
	check("abort : raison aborted", ps.abort() == true and ps.reason == "aborted" and ps.update(101) == nil)

	-- horloge capricieuse
	local pt = Cinema.player(seq)
	pt.play(50)
	ev = pt.update(40)
	check("temps qui recule : plan 1 à 0 sans erreur", ev.shot == 1 and ev.progress == 0)
	ev = pt.update(50 + 1000)
	check("gros saut de temps : fin normale", ev.finished == true and ev.reason == "completed")

	-- directeur : intro puis tutoriel en file, jamais de superposition
	local seqA = Cinema.sequence({ id = "intro", shots = { { dur = 2, pos = { 0, 5, 0 }, look = { 0, 0, 0 } } } })
	local seqB = Cinema.sequence({ id = "tutorial", shots = { { dur = 2, pos = { 0, 5, 0 }, look = { 0, 0, 0 } } } })
	local seqC = Cinema.sequence({ id = "firstRare", shots = { { dur = 1, pos = { 0, 5, 0 }, look = { 0, 0, 0 } } } })
	local d = Cinema.director()
	check("director : au repos, rien à jouer", d.update(0) == nil and d.isActive() == false and d.skip(0) == nil)
	check("director : demande acceptée", d.request("intro", seqA, 0, false) == "playing" and d.isActive())
	check("director : demande chaînée mise en file", d.request("tutorial", seqB, 0.1, true) == "queued")
	check("director : demande non chaînée refusée pendant une lecture", d.request("firstRare", seqC, 0.2, false) == "refused")
	local id, e = d.update(0.5)
	check("director : update renvoie l'identifiant et le plan", id == "intro" and e.shot == 1 and e.shotChanged == true)
	id, e = d.update(2.1)
	check("director : fin de l'intro signalée une fois", id == "intro" and e.finished == true and e.reason == "completed")
	check("director : le tutoriel enchaîne tout seul", d.isActive() == true and d.current.id == "tutorial")
	id, e = d.update(2.2)
	check("director : le tutoriel démarre au plan 1", id == "tutorial" and e.shot == 1 and e.shotChanged == true)
	id, e = d.update(4.3)
	check("director : fin du tutoriel, plus rien ensuite", id == "tutorial" and e.finished == true and d.isActive() == false and d.update(5) == nil)
	check("director : reprise possible une fois libre", d.request("firstRare", seqC, 6, false) == "playing")

	-- skip : la file continue ; skipAll : tout s'arrête ; abort : rien n'est considéré comme vu
	local d2 = Cinema.director()
	d2.request("intro", seqA, 0, false)
	d2.request("tutorial", seqB, 0, true)
	check("director.skip : renvoie l'intro passée, le tutoriel démarre", d2.skip(1) == "intro" and d2.current.id == "tutorial")
	check("director.skip : puis le tutoriel", d2.skip(1.1) == "tutorial" and d2.isActive() == false and d2.skip(1.2) == nil)
	local d3 = Cinema.director()
	d3.request("intro", seqA, 0, false)
	d3.request("tutorial", seqB, 0, true)
	local ids = d3.skipAll()
	check("director.skipAll : intro et tutoriel marqués passés, plus rien ne joue", #ids == 2 and ids[1] == "intro" and ids[2] == "tutorial" and d3.isActive() == false and d3.update(1) == nil)
	local d4 = Cinema.director()
	d4.request("intro", seqA, 0, false)
	d4.request("tutorial", seqB, 0, true)
	d4.abort()
	check("director.abort : tout s'arrête, file vidée", d4.isActive() == false and #d4.queue == 0 and d4.update(1) == nil)
	check("director : nouvelle demande acceptée après un abort", d4.request("intro", seqA, 5, false) == "playing")
end

-- Assets : chargeur factice -----------------------------------------------------------------
do
	local AssetsMod = luau.load(fs.readFile("roblox/src/ServerScriptService/Assets.lua"), { debugName = "Assets" })()
	-- Instances factices
	local function inst(class, props)
		local o = { ClassName = class, children = {}, destroyed = false }
		for k, v in pairs(props or {}) do
			o[k] = v
		end
		function o:IsA(c)
			return self.ClassName == c or (c == "BasePart" and self.ClassName == "Part")
		end
		function o:Destroy()
			self.destroyed = true
			self.dead = true
		end
		function o:Clone()
			return inst(self.ClassName, { children = self.children })
		end
		function o:GetDescendants()
			local out = {}
			for _, ch in ipairs(self.children) do
				if not ch.destroyed then
					out[#out + 1] = ch
				end
			end
			return out
		end
		return o
	end
	local clock = 0
	local function deps(loader, store)
		return {
			loadAsset = loader,
			spawn = function(fn)
				fn()
			end,
			wait = function(s)
				clock = clock + s
			end,
			clock = function()
				return clock
			end,
			warn = function() end,
			store = store,
		}
	end
	local function make(loader)
		return AssetsMod.new(Config, deps(loader))
	end
	local goodModel = function()
		return inst("Model", { children = { inst("Part"), inst("Script"), inst("RemoteEvent"), inst("BindableEvent"), inst("ModuleScript"), inst("LocalScript"), inst("Sound"), inst("ParticleEmitter", { Rate = 500 }) } })
	end

	check("Config.Assets : 5 IDs entiers positifs", (function()
		local n = 0
		for _, id in pairs(Config.Assets.eggs) do
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				n = n + 1
			end
		end
		return n == 5
	end)())
	check("Config.Assets : chaque rareté 1..6 pointe vers un modèle déclaré", (function()
		for t = 1, #Config.TIERS do
			if Config.eggAssetId(t) == nil then
				return false
			end
		end
		return true
	end)())
	check("Config.eggAssetId : rareté inconnue -> nil", Config.eggAssetId(99) == nil and Config.eggAssetId(0) == nil)
	check("Config.isBlockedClass", Config.isBlockedClass("Script") and Config.isBlockedClass("LocalScript") and Config.isBlockedClass("ModuleScript") and Config.isBlockedClass("RemoteEvent") and Config.isBlockedClass("BindableEvent") and not Config.isBlockedClass("Part") and not Config.isBlockedClass("MeshPart"))

	-- modèle sain : nettoyé, rangé, clonable
	local stored = {}
	local A = AssetsMod.new(Config, deps(function() return goodModel() end, function(k, m) stored[k] = m end))
	local ready = 0
	local n = A.loadAll(function() ready = ready + 1 end)
	check("chargeur sain : 5 modèles chargés, onReady appelé une fois", n == 5 and ready == 1)
	local m1 = A.templates.red
	check("nettoyage : plus aucun Script/LocalScript/ModuleScript/RemoteEvent/BindableEvent/Sound", (function()
		for _, d in ipairs(m1:GetDescendants()) do
			if Config.isBlockedClass(d.ClassName) then
				return false
			end
		end
		return #m1:GetDescendants() == 2
	end)())
	check("nettoyage : particules plafonnées", (function()
		for _, d in ipairs(m1:GetDescendants()) do
			if d.ClassName == "ParticleEmitter" then
				return d.Rate == Config.Assets.maxParticleRate
			end
		end
		return false
	end)())
	check("modèle sain : rangé via deps.store et cloneEgg non nil", stored.red == m1 and A.cloneEgg(1) ~= nil and A.cloneEgg(6) ~= nil)
	check("cloneEgg : rareté inconnue -> nil", A.cloneEgg(99) == nil)

	-- modèle vide
	local E = make(function() return inst("Model", { children = {} }) end)
	check("modèle vide : refusé, cloneEgg nil, aucune erreur", E.loadAll() == 0 and E.cloneEgg(1) == nil and E.status.red.ok == false)
	-- modèle sans géométrie (seulement du code)
	local C0 = make(function() return inst("Model", { children = { inst("Script") } }) end)
	check("modèle code seul : refusé", C0.loadAll() == 0 and C0.cloneEgg(2) == nil)
	-- modèle corrompu (GetDescendants lève une erreur)
	local bad = make(function()
		local o = inst("Model")
		function o:GetDescendants()
			error("corrompu")
		end
		return o
	end)
	check("modèle corrompu : refusé sans erreur", bad.loadAll() == 0 and bad.cloneEgg(1) == nil)
	-- instance corrompue (ClassName illisible)
	local bad2 = make(function()
		return inst("Model", { children = { setmetatable({ destroyed = false }, { __index = function() error("x") end }) } })
	end)
	check("instance corrompue : refusée", bad2.loadAll() == 0)
	-- chargeur qui lève une erreur / retourne nil
	check("LoadAsset en erreur : tolérée", make(function() error("HTTP 403") end).loadAll() == 0)
	check("LoadAsset retourne nil : toléré", make(function() return nil end).loadAll() == 0)
	-- trop lourd
	local heavy = make(function()
		local ch = {}
		for i = 1, Config.Assets.maxParts + 1 do
			ch[i] = inst("Part")
		end
		return inst("Model", { children = ch })
	end)
	check("modèle trop lourd : refusé", heavy.loadAll() == 0 and heavy.status.red.reason:find("lourd") ~= nil)
	-- délai dépassé : le chargeur ne répond jamais (spawn différé, jamais exécuté)
	clock = 0
	local slowDeps = deps(function() return goodModel() end)
	local pending = {}
	slowDeps.spawn = function(fn)
		pending[#pending + 1] = fn
	end
	local S = AssetsMod.new(Config, slowDeps)
	local okSlow = S.loadOne("red", 151044983)
	check("délai dépassé : abandon, temps écoulé >= timeout", okSlow == false and clock >= Config.Assets.timeout and S.status.red.reason:find("délai") ~= nil)
	-- réponse tardive : le modèle arrivé après coup est détruit
	local late = goodModel()
	slowDeps.loadAsset = function() return late end
	pending[1] = nil
	for _, fn in ipairs(pending) do
		fn()
	end
	check("après le délai, le modèle tardif n'est pas utilisé", S.templates.red == nil and S.cloneEgg(1) == nil)
	-- un seul avertissement par ID, échecs mémorisés
	local warnings = 0
	local W = AssetsMod.new(Config, (function()
		local dd = deps(function() error("Requester does not have permission for Asset") end)
		dd.warn = function() warnings = warnings + 1 end
		return dd
	end)())
	W.loadAll()
	W.loadAll()
	check("échec de permission : un seul avertissement par ID, même en rechargeant", warnings == 5 and W.failedIds[2937230482] ~= nil and W.failedIds[147144059] ~= nil)
	-- réglage de désactivation
	local savedEnabled = Config.Assets.Enabled
	Config.Assets.Enabled = false
	local called = 0
	local D = make(function() called = called + 1 return goodModel() end)
	check("enabled = false : aucun chargement, aucun clone, aucun ID", D.loadAll() == 0 and called == 0 and D.cloneEgg(1) == nil and Config.eggAssetId(1) == nil)
	Config.Assets.Enabled = savedEnabled
	-- ID invalide
	local savedId = Config.Assets.eggs.red
	Config.Assets.eggs.red = -4
	local I = make(function() return goodModel() end)
	check("ID invalide : ignoré, les autres chargent", I.loadAll() == 4 and I.status.red.reason == "ID invalide")
	Config.Assets.eggs.red = savedId

	-- l'éclosion ne dépend pas des modèles : mêmes tirages, chargement réussi ou en échec
	local function hatchRun()
		local out = {}
		for tier = 1, 6 do
			for k = 0, 20 do
				local r = Rules.rollPet(tier, 10, false, function() return (k * 0.047 + tier * 0.013) % 1 end, false)
				out[#out + 1] = r.p .. ":" .. r.s .. ":" .. r.m .. ":" .. r.tier
			end
		end
		return table.concat(out, ",")
	end
	local ref = hatchRun()
	A.cloneEgg(3)
	check("éclosion identique avec chargeur sain", hatchRun() == ref)
	E.cloneEgg(3)
	bad.cloneEgg(3)
	check("éclosion identique avec modèle vide/corrompu", hatchRun() == ref)
end

-- Diag : erreurs DataStore de Studio -----------------------------------------------------------
do
	local Diag = luau.load(fs.readFile("roblox/src/ServerScriptService/Diag.lua"), { debugName = "Diag" })()
	check("Diag : erreur Studio sans API reconnue (message du journal)", Diag.isStudioApiError("403: Cannot write to DataStore from studio if API access is not enabled."))
	check("Diag : code StudioAccessToApisNotAllowed reconnu", Diag.isStudioApiError("104: StudioAccessToApisNotAllowed"))
	check("Diag : une vraie erreur réseau n'est pas reconnue", not Diag.isStudioApiError("HTTP 500: InternalServerError") and not Diag.isStudioApiError("DataStore request was added to queue"))
	check("Diag : valeur nil ou nombre sans erreur", not Diag.isStudioApiError(nil) and not Diag.isStudioApiError(404))
end

-- Apparences d'œufs construites par le code ---------------------------------------------------
do
	local seen = {}
	local distinct = true
	for key in pairs(Config.Assets.eggs) do
		local look = Config.EggFx.looks[key]
		check("EggFx : apparence définie pour " .. key, look ~= nil and look.color ~= nil and look.material ~= nil and look.light ~= nil)
		if look then
			local sig = string.format("%.2f,%.2f,%.2f,%s", look.color.R, look.color.G, look.color.B, look.material)
			if seen[sig] then
				distinct = false
			end
			seen[sig] = true
		end
	end
	check("EggFx : cinq apparences toutes distinctes (couleur + matériau)", distinct)
	check("EggFx : chaque rareté 1..6 a une apparence", (function()
		for t = 1, #Config.TIERS do
			if Config.eggLook(t) == nil then
				return false
			end
		end
		return true
	end)())
	check("EggFx : matériaux valides", (function()
		local ok = { SmoothPlastic = true, Plastic = true, Neon = true, Metal = true, Glass = true, Marble = true }
		for _, look in pairs(Config.EggFx.looks) do
			if not ok[look.material] then
				return false
			end
		end
		return true
	end)())
	check("EggFx : halos et particules plafonnés (performance)", (function()
		for _, look in pairs(Config.EggFx.looks) do
			if look.particles and look.particles.rate > 20 then
				return false
			end
			if look.halo and (look.halo.transparency < 0 or look.halo.transparency > 1 or look.halo.scale < 1 or look.halo.scale > 2) then
				return false
			end
		end
		return true
	end)())
	check("EggFx : raretés supérieures plus marquées (le légendaire et le glitch ont un halo, le rouge non)", Config.EggFx.looks.legendary.halo ~= nil and Config.EggFx.looks.glitch.halo ~= nil and Config.EggFx.looks.red.halo == nil)
end

-- Économie : simulation de 30 minutes d'un joueur-robot (5 graines) ------------------------------------------------------
do
	local Economy = luau.load(fs.readFile("roblox/tests/Economy.lua"), { debugName = "Economy" })()
	local allOk, why = true, ""
	local function expect(cond, msg)
		if not cond and allOk then
			allOk, why = false, msg
		end
	end
	for seed = 1, 5 do
		local L = Economy.simulate(Config, Rules, 30, { seed = seed })
		local f = L.final
		local tag = " (graine " .. seed .. ")"
		expect(L.firstIncome10 ~= nil and L.firstIncome10 <= 120, "10 pièces/s en moins de 2 min" .. tag)
		expect(L.firstIncome100 ~= nil and L.firstIncome100 <= 300, "100 pièces/s en moins de 5 min" .. tag)
		expect(L.firstIncome1000 ~= nil and L.firstIncome1000 <= 900, "1000 pièces/s en moins de 15 min" .. tag)
		expect(L.firstEggTier[2] ~= nil and L.firstEggTier[2] >= 60 and L.firstEggTier[2] <= 200, "premier œuf Rare entre 1 et 3,3 min" .. tag)
		expect(L.firstEggTier[3] ~= nil and L.firstEggTier[3] >= 150 and L.firstEggTier[3] <= 700, "premier œuf Épique entre 2,5 et 11,7 min" .. tag)
		expect(L.firstEggTier[4] == nil or L.firstEggTier[4] >= 500, "pas d'œuf Légendaire avant 8 min" .. tag)
		expect(L.firstEggTier[5] == nil and L.firstEggTier[6] == nil, "ni Mythique ni Cosmique en 30 min" .. tag)
		expect(f.income >= 1000 and f.income <= 100000, "revenu à 30 min entre 1 000 et 100 000 /s" .. tag)
		expect(L.maxStall <= 900, "jamais plus de 15 min sans progression de revenu" .. tag)
		expect(f.coins < Config.rebirthCost(0), "renaissance hors de portée avant 30 min" .. tag)
		expect(f.up.slots >= 3 and f.up.food >= 5, "les améliorations de base sont achetées" .. tag)
	end
	check("Économie : rythme des 30 premières minutes" .. (allOk and "" or " : " .. why), allOk)
	local a, b = Economy.simulate(Config, Rules, 5, { seed = 7 }), Economy.simulate(Config, Rules, 5, { seed = 7 })
	check("Économie : simulation déterministe (même graine, même résultat)", a.final.coins == b.final.coins and a.final.hatched == b.final.hatched)
end

-- Objectif affiché (HUD) ----------------------------------------------------------------------
do
	local o = Config.objective({ ch = 0, prog = 0 })
	check("objective : chapitre 1 au départ", o ~= nil and o.index == 1 and o.total == #Config.STORY and o.done == false and o.prog == 0 and o.goal == Config.STORY[1].goal)
	check("objective : progression plafonnée et terminée", Config.objective({ ch = 0, prog = 99 }).prog == Config.STORY[1].goal and Config.objective({ ch = 0, prog = 99 }).done == true)
	check("objective : valeurs négatives ou nil sans erreur", Config.objective({ ch = 0, prog = -5 }).prog == 0 and Config.objective({}).index == 1)
	check("objective : histoire terminée -> nil", Config.objective({ ch = #Config.STORY, prog = 0 }) == nil)
	check("objective : texte non vide pour chaque chapitre", (function()
		for ch = 0, #Config.STORY - 1 do
			local x = Config.objective({ ch = ch, prog = 0 })
			if not x or x.text == "" or x.title == "" then
				return false
			end
		end
		return true
	end)())
end

-- Interface : disposition ancrée aux bords, zone centrale libre ----------------------------------------------------
do
	local Layout = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Layout.lua"), { debugName = "Layout" })()
	local devices = {
		{ "téléphone portrait 390x844", 390, 844 },
		{ "petit téléphone 360x640", 360, 640 },
		{ "téléphone paysage 844x390", 844, 390 },
		{ "petit paysage 640x360", 640, 360 },
		{ "tablette portrait 820x1180", 820, 1180 },
		{ "tablette paysage 1180x820", 1180, 820 },
		{ "PC 1920x1080", 1920, 1080 },
		{ "PC 1366x768", 1366, 768 },
		{ "ultra-large 2560x1080", 2560, 1080 },
		{ "fenêtre Studio 1000x600", 1000, 600 },
	}
	for _, dev in ipairs(devices) do
		local name, vw, vh = dev[1], dev[2], dev[3]
		local r, s, dw, dh = Layout.rects(vw, vh, 6)
		local center = Layout.centerRect(vw, vh)
		check("Layout " .. name .. " : échelle bornée", s >= Layout.MIN_SCALE and s <= Layout.MAX_SCALE)
		local inside, free, apart = true, true, true
		local names = {}
		for k in pairs(r) do
			names[#names + 1] = k
		end
		table.sort(names)
		for i, k in ipairs(names) do
			local a = r[k]
			if a.x < 0 or a.y < 0 or a.x + a.w > dw + 1e-6 or a.y + a.h > dh + 1e-6 or a.w <= 0 or a.h <= 0 then
				inside = false
			end
			if Layout.overlap(a, center) then
				free = false
			end
			for j = i + 1, #names do
				if Layout.overlap(a, r[names[j]]) then
					apart = false
				end
			end
		end
		check("Layout " .. name .. " : tout dans l'écran", inside)
		check("Layout " .. name .. " : zone centrale libre", free)
		check("Layout " .. name .. " : aucun élément ne se chevauche", apart)
		check("Layout " .. name .. " : boutons >= 44 px réels", Layout.NAV_BUTTON * s >= 44 - 1e-6)
		check("Layout " .. name .. " : menu en bas à droite, jamais au centre", r.nav.x + r.nav.w >= dw - Layout.EDGE - 1e-6 and r.nav.y + r.nav.h >= dh - Layout.EDGE - 1e-6 and r.nav.x * s >= vw * 0.68)
	end
	check("Layout : échelle d'un écran dégénéré (0x0) bornée", Layout.scaleFor(0, 0) == Layout.MIN_SCALE)
end

print(("Tests Config : %d réussis, %d échoués"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
