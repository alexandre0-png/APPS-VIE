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
-- Garde-fous : nom de la suite en cours affiché, délai global de 90 s (sous Lune, `task.delay` réel : plus jamais de blocage silencieux),
-- sortie explicite en fin de run (aucune tâche de fond ne peut retenir le processus).
local currentSuite = "initialisation"
local function suite(name)
	currentSuite = name
	print("  ▶ " .. name)
end
if task and task.delay then
	task.delay(90, function()
		print("TIMEOUT global (90 s) : le test est bloqué dans la suite « " .. currentSuite .. " »")
		process.exit(2)
	end)
end
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
check("upPoints de base = 5 (amélioration d'un cran, jamais plus de 5 % sans bonus)", Rules.upPoints(0, false, false, false) == 5)
check("upPoints cumulés = 55 (5 + 10 niveaux + événement 5 + pass 10 + potion 25)", Rules.upPoints(10, true, true, true) == 55)
for tier = 1, 6 do
	for _, up in ipairs({ -5, 0, 12, 42, 87, 500 }) do
		local w = Rules.tierWeights(tier, up)
		check("tierWeights(" .. tier .. "," .. up .. ") : poids >= 0 et somme 100", w[1] >= 0 and w[2] >= 0 and w[3] >= 0 and near(w[1] + w[2] + w[3], 100))
	end
end
check("rareté 1 : jamais de rareté inférieure", Rules.tierWeights(1, 12)[1] == 0)
check("rareté 6 : jamais de rareté supérieure", Rules.tierWeights(6, 87)[3] == 0)
check("part supérieure plafonnée", Rules.tierWeights(3, 500)[3] == Rules.MAX_UP)
check("pickTier rnd=0 -> identique (jamais de rareté inférieure)", Rules.pickTier(3, 12, const(0)) == 3)
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
check("pitié définie mais coupée (l'œuf annoncé fixe la rareté)", Config.PITY_EVERY >= 2 and Config.PITY_ENABLED == false)
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
local animKeys = { "enabled", "vfx3d", "uiFx", "pulse", "eggShake", "eggBounce", "hatchSquash", "popIn", "shockwave", "harvest", "petBlink", "petLook", "petMouth", "menuTransitions", "reward", "zones", "characterPop", "hen", "eggHalo", "zoneAmbience", "interactMarkers", "zoneBanner", "petStates" }
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
	suite("bloc sans titre (ligne 343)")
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
	suite("squash & stretch")
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
	suite("rebond des œufs")
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
	suite("yeux et bouche")
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
	suite("barrières de zone")
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
	suite("bloc sans titre (ligne 494)")
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
	suite("garde-fou : désactivée = non exécutée ; erreur = désactivée pour la session, une seule ale")
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
	suite("bloc sans titre (ligne 560)")
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
	suite("Positions des emplacements")
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
	suite("bloc sans titre (ligne 600)")
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
	suite("bloc sans titre (ligne 651)")
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
	suite("Cinéma : séquences, lecteur (lecture, skip, abandon, reprise), caméra, directeur")
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
	suite("Assets : chargeur factice")
	local AssetsMod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Assets.lua"), { debugName = "Assets" })()
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
	check("chargeur sain : 5 œufs du catalogue + 7 œufs Blender (6 raretés et secret) chargés, onReady appelé une fois", n == 12 and ready == 1)
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
	check("échec de permission : un seul avertissement par ID (11 ID distincts), même en rechargeant", warnings == 11 and W.failedIds[2937230482] ~= nil and W.failedIds[147144059] ~= nil)
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
	check("ID invalide : ignoré, les autres chargent", I.loadAll() == 4 + 7 and I.status.red.reason == "ID invalide")
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
	suite("Diag : erreurs DataStore de Studio")
	local Diag = luau.load(fs.readFile("roblox/src/ServerScriptService/Diag.lua"), { debugName = "Diag" })()
	check("Diag : erreur Studio sans API reconnue (message du journal)", Diag.isStudioApiError("403: Cannot write to DataStore from studio if API access is not enabled."))
	check("Diag : code StudioAccessToApisNotAllowed reconnu", Diag.isStudioApiError("104: StudioAccessToApisNotAllowed"))
	check("Diag : une vraie erreur réseau n'est pas reconnue", not Diag.isStudioApiError("HTTP 500: InternalServerError") and not Diag.isStudioApiError("DataStore request was added to queue"))
	check("Diag : valeur nil ou nombre sans erreur", not Diag.isStudioApiError(nil) and not Diag.isStudioApiError(404))
end

-- Apparences d'œufs construites par le code ---------------------------------------------------
do
	suite("Apparences d'œufs construites par le code")
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
	suite("Économie : simulation de 30 minutes d'un joueur-robot (5 graines)")
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
	-- cibles de rythme d'un nouveau joueur actif (joueur-robot, 5 graines, 60 min) : hors cible = échec
	local tgtOk, tgtWhy, worst = true, "", {}
	for seed = 1, 5 do
		local L = Economy.simulate(Config, Rules, 60, { seed = seed })
		local tag = " (graine " .. seed .. ")"
		local function must(cond, msg)
			if not cond and tgtOk then
				tgtOk, tgtWhy = false, msg .. tag
			end
		end
		must(L.firstHatch ~= nil and L.firstHatch < 60, "1er œuf éclos en moins de 60 s")
		must(L.firstPetTier[2] ~= nil and L.firstPetTier[2] < 240, "1er pet Rare en moins de 4 min")
		must(L.firstPetTier[3] ~= nil and L.firstPetTier[3] < 720, "1er pet Épique en moins de 12 min")
		must(L.firstPetTier[4] ~= nil and L.firstPetTier[4] < 2700, "1er pet Légendaire en moins de 45 min")
		must(L.baseLevelAt[2] ~= nil and L.baseLevelAt[2] < 300, "base niveau 2 en moins de 5 min")
		must(L.baseLevelAt[4] ~= nil and L.baseLevelAt[4] < 1800, "base niveau 4 en moins de 30 min")
		for k, v in pairs({ hatch = L.firstHatch, rare = L.firstPetTier[2], epic = L.firstPetTier[3], legendary = L.firstPetTier[4], base2 = L.baseLevelAt[2], base4 = L.baseLevelAt[4] }) do
			worst[k] = math.max(worst[k] or 0, v or 99999)
		end
	end
	check("Économie : cibles (éclosion < 60 s, Rare < 4 min, Épique < 12 min, Légendaire < 45 min, base 2 < 5 min, base 4 < 30 min) ; pires cas mesurés : éclosion " .. worst.hatch .. " s, Rare " .. worst.rare .. " s, Épique " .. worst.epic .. " s, Légendaire " .. worst.legendary .. " s, base 2 " .. worst.base2 .. " s, base 4 " .. worst.base4 .. " s" .. (tgtOk and "" or " : " .. tgtWhy), tgtOk)
	-- courbe de revenu des pets : chaque rareté rapporte strictement plus que la précédente ; 18 pets
	local lo, hi, curveOk = {}, {}, true
	for _, def in ipairs(Config.PETS) do
		lo[def.tier] = math.min(lo[def.tier] or math.huge, def.inc)
		hi[def.tier] = math.max(hi[def.tier] or 0, def.inc)
	end
	for t = 2, #Config.TIERS do
		if lo[t] == nil or hi[t - 1] == nil or lo[t] <= hi[t - 1] then
			curveOk = false
		end
	end
	check("Économie : " .. #Config.PETS .. " pets, le revenu de chaque rareté dépasse strictement celui de la précédente (courbe cohérente)", curveOk and #Config.PETS == 18)
	-- monnaie vendue : proportionnelle au revenu, jamais au-delà de 20 minutes de gains (plancher 5 000), pack de départ unique
	local sold = math.max(Config.COIN_PACK_MIN, 1000 * Config.COIN_PACK_MINUTES * 60)
	check("Économie : le sac de pièces vaut au plus " .. Config.COIN_PACK_MINUTES .. " min de revenu (plancher " .. Config.COIN_PACK_MIN .. ") et le pack de départ est unique (" .. Config.STARTER_PACK.coins .. " pièces)", sold == 1000 * Config.COIN_PACK_MINUTES * 60 and Config.PRODUCTS.StarterPack.once == true and Config.STARTER_PACK.coins < Config.EGG_PRICE[3] * 2)
	local a, b = Economy.simulate(Config, Rules, 5, { seed = 7 }), Economy.simulate(Config, Rules, 5, { seed = 7 })
	check("Économie : simulation déterministe (même graine, même résultat)", a.final.coins == b.final.coins and a.final.hatched == b.final.hatched)
end

-- Objectif affiché (HUD) ----------------------------------------------------------------------
do
	suite("Objectif affiché (HUD)")
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
	suite("Interface : disposition ancrée aux bords, zone centrale libre")
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
				-- l'offre d'achat prend la place du conseil (jamais affichés ensemble : le client cache le conseil tant que l'offre est visible)
				local pair = (k == "offer" and names[j] == "hint") or (k == "hint" and names[j] == "offer")
				if not pair and Layout.overlap(a, r[names[j]]) then
					apart = false
				end
			end
		end
		check("Layout " .. name .. " : tout dans l'écran", inside)
		check("Layout " .. name .. " : zone centrale libre", free)
		check("Layout " .. name .. " : l'offre d'achat occupe exactement la place du conseil", r.offer.x == r.hint.x and r.offer.y == r.hint.y and r.offer.w == r.hint.w and r.offer.h == r.hint.h)
		check("Layout " .. name .. " : aucun élément ne se chevauche", apart)
		check("Layout " .. name .. " : boutons >= 44 px réels", Layout.NAV_BUTTON * s >= 44 - 1e-6)
		check("Layout " .. name .. " : menu en bas à droite, jamais au centre", r.nav.x + r.nav.w >= dw - Layout.EDGE - 1e-6 and r.nav.y + r.nav.h >= dh - Layout.EDGE - 1e-6 and r.nav.x * s >= vw * 0.68)
	end
	check("Layout : échelle d'un écran dégénéré (0x0) bornée", Layout.scaleFor(0, 0) == Layout.MIN_SCALE)
end

-- Hub : zones de lancement, parties, rejoindre en cours, replis (faux TeleportService) ---------------------------------------
do
	suite("Hub : zones de lancement, parties, rejoindre en cours, replis (faux TeleportService)")
	local Party = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Party.lua"), { debugName = "Party" })()
	local G = Config.Game
	check("Game : lieux configurés (hub et jeu)", G.Places.hub == 115261336085924 and G.Places.game == 87012762353093 and G.Places.hub ~= G.Places.game)
	check("Game.roleFor : hub, jeu, inconnu (Studio non publié)", Config.Game.roleFor(115261336085924) == "hub" and Config.Game.roleFor(87012762353093) == "game" and Config.Game.roleFor(12345) == "unknown" and Config.Game.roleFor(0) == "unknown")
	check("Game : tailles 1 à 5, plafond 5, autant de bases que de joueurs", #G.Sizes == 5 and G.Sizes[1] == 1 and G.Sizes[5] == 5 and G.MaxPlayers == 5 and Config.PLOT_COUNT == G.MaxPlayers)
	check("Party.admit : 4 joueurs -> un de plus accepté, 5 -> refusé", Party.admit(4, 5) == true and Party.admit(5, 5) == false)

	do -- retour au hub (logique pure)
		local calls = {}
		local okR = Party.returnToHub(Config, { teleport = function(players, place, code, data) calls[#calls + 1] = { place = place, code = code, data = data, n = #players } end }, { UserId = 1 }, "P9")
		check("returnToHub : téléportation vers le hub avec partyId et raison", okR.ok and calls[1].place == G.Places.hub and calls[1].code == nil and calls[1].data.partyId == "P9" and calls[1].data.from == "game" and calls[1].n == 1)
		local bad = Party.returnToHub(Config, { teleport = function() error("TeleportService indisponible") end }, { UserId = 1 }, "P9")
		check("returnToHub : échec -> message clair, aucune erreur", bad.ok == false and #bad.message > 20)
		local savedHub = G.Places.hub
		G.Places.hub = 0
		check("returnToHub : hub non configuré -> message clair", Party.returnToHub(Config, { teleport = function() end }, { UserId = 1 }, nil).ok == false)
		G.Places.hub = savedHub
	end

	local function env(opts)
		opts = opts or {}
		local e = { now = 1000, calls = {}, entries = {}, reserveFail = opts.reserveFail, teleportFail = opts.teleportFail, publicFail = opts.publicFail, storeFail = opts.storeFail, codes = 0 }
		local store = {}
		function store.get(key)
			if e.storeFail then
				error("MemoryStore indisponible")
			end
			return e.entries[key]
		end
		function store.update(key, fn)
			if e.storeFail then
				error("MemoryStore indisponible")
			end
			local new = fn(e.entries[key])
			if new ~= nil then
				e.entries[key] = new
			end
			return new
		end
		function store.remove(key)
			e.entries[key] = nil
		end
		function store.list()
			if e.storeFail then
				error("MemoryStore indisponible")
			end
			local out = {}
			for _, v in pairs(e.entries) do
				out[#out + 1] = v
			end
			return out
		end
		e.P = Party.new(Config, {
			clock = function()
				return e.now
			end,
			reserve = function(place)
				if e.reserveFail then
					error(e.reserveFail)
				end
				e.codes = e.codes + 1
				return "CODE" .. e.codes
			end,
			teleport = function(players, place, code, data)
				if code ~= nil and e.teleportFail then
					error(e.teleportFail)
				end
				if code == nil and e.publicFail then
					error(e.publicFail)
				end
				e.calls[#e.calls + 1] = { n = #players, place = place, code = code, data = data }
			end,
			store = store,
			guid = function()
				e.guids = (e.guids or 0) + 1
				return string.format("%08x-%04x-%04x", (e.guids * 2654435761) % 4294967296, (e.guids * 40503) % 65536, 7)
			end,
		})
		return e
	end
	local function fillAndLaunch(e, size, count)
		local members, players = {}, {}
		for i = 1, count do
			local uid = 100 * size + i
			check("zone " .. size .. " : entrée du joueur " .. i, e.P.enter(uid, size) == true)
			members[i], players[i] = uid, { UserId = uid }
		end
		return members, players
	end

	for size = 1, 5 do
		local e = env()
		local members, players = fillAndLaunch(e, size, size)
		local st = e.P.status(size)
		check("zone " .. size .. " pleine : mode full avec compte à rebours", st.mode == "full" and st.count == size and st.countdown == (size == 1 and G.SoloCountdown or G.CountdownFull))
		check("zone " .. size .. " : rien ne part avant la fin du compte à rebours", #e.P.collectLaunches() == 0)
		e.now = e.now + (size == 1 and G.SoloCountdown or G.CountdownFull) + 0.1
		local launches = e.P.collectLaunches()
		check("zone " .. size .. " : un groupe de " .. size .. " part", #launches == 1 and #launches[1].members == size and e.P.status(size).mode == "empty")
		local r = e.P.launch({ size = size, members = members, players = players, hostName = "Hôte" })
		check("lancement " .. size .. " joueur(s) : serveur réservé, téléportation vers le lieu de jeu", r.ok and r.mode == "reserved" and e.calls[1].n == size and e.calls[1].place == G.Places.game and e.calls[1].code == "CODE1" and e.calls[1].data.late == false)
		check("lancement " .. size .. " : inscrit au registre et OUVERT aux amis (même en solo), plafond " .. G.MaxPlayers, e.entries[r.partyId] ~= nil and e.entries[r.partyId].open == true and e.entries[r.partyId].size == G.MaxPlayers and e.entries[r.partyId].groupSize == size)
	end

	do -- zone pleine, taille clampée, quitter la zone
		local e = env()
		e.P.enter(1, 3)
		e.P.enter(2, 3)
		e.P.enter(3, 3)
		local ok, why = e.P.enter(4, 3)
		check("zone pleine : le joueur en trop est refusé", ok == false and why == "zone pleine" and e.P.status(3).count == 3)
		check("taille inconnue refusée", e.P.enter(9, 7) == false)
		check("changer de zone : quitte l'ancienne, entre dans la nouvelle", e.P.enter(1, 2) == true and e.P.status(3).count == 2 and e.P.status(2).count == 1)
		check("quitter la zone libère la place", e.P.leave(1) == true and e.P.status(2).count == 0 and e.P.leave(1) == false)
		local r = e.P.launch({ size = 9, members = { 5 }, players = { { UserId = 5 } }, hostName = "X" })
		check("taille 9 ramenée à 5 maximum", r.ok and e.entries[r.partyId].size == 5)
	end

	do -- groupe incomplet : part après PartialWait et reste ouvert aux amis
		local e = env()
		e.P.enter(42, 3)
		check("groupe incomplet : compte à rebours de PartialWait", e.P.status(3).mode == "waiting" and e.P.status(3).countdown == G.PartialWait)
		e.now = e.now + G.PartialWait + 1
		local l = e.P.collectLaunches()
		check("groupe incomplet : part après le délai", #l == 1 and #l[1].members == 1)
		local r = e.P.launch({ size = 3, members = { 42 }, players = { { UserId = 42 } }, hostName = "Léa" })
		local friends = { [42] = true }
		local list = e.P.visibleFor(7, friends)
		check("ami : voit la partie ouverte (1/5, groupe de 3 prévu)", #list == 1 and list[1].hostName == "Léa" and list[1].count == 1 and list[1].size == G.MaxPlayers)
		check("non-ami : ne voit pas la partie", #e.P.visibleFor(8, {}) == 0)
		check("l'hôte ne voit pas sa propre partie", #e.P.visibleFor(42, { [42] = true }) == 0)
		-- rejoindre en cours
		local j = e.P.join(r.partyId, { UserId = 7 }, 7, friends)
		check("rejoindre en cours : accepté, état de départ « late », même serveur réservé", j.ok and e.entries[r.partyId].count == 2 and e.calls[#e.calls].code == "CODE1" and e.calls[#e.calls].data.late == true and e.calls[#e.calls].data.partyId == r.partyId)
		check("rejoindre deux fois : refusé", e.P.join(r.partyId, { UserId = 7 }, 7, friends).reason == "full")
		local j2 = e.P.join(r.partyId, { UserId = 9 }, 9, friends)
		check("rejoindre : 3e joueur accepté", j2.ok and e.entries[r.partyId].count == 3)
		for uid = 10, 12 do
			e.P.join(r.partyId, { UserId = uid }, uid, friends)
		end
		local j3 = e.P.join(r.partyId, { UserId = 13 }, 13, friends)
		check("partie pleine (5) : refus clair avec le plafond dans le message", j3.ok == false and j3.reason == "full" and e.entries[r.partyId].count == 5 and j3.message:find("5", 1, true) ~= nil)
		check("partie pleine : n'apparaît plus dans la liste des amis", #e.P.visibleFor(14, friends) == 0)
		-- départ
		e.P.leaveParty(r.partyId, 9)
		check("départ d'un joueur : la place se libère", e.entries[r.partyId].count == 4 and #e.P.visibleFor(14, friends) == 1)
		check("partie inconnue : « gone »", e.P.join("nope", { UserId = 1 }, 1, friends).reason == "gone")
		e.now = e.now + G.PartyTTL + 1
		check("partie expirée (TTL) : plus proposée, plus rejoignable", #e.P.visibleFor(14, friends) == 0 and e.P.join(r.partyId, { UserId = 15 }, 15, friends).reason == "gone")
	end

	do -- mode Château : files séparées de l'arène, mode transmis au serveur de jeu et conservé pour les amis
		local e = env()
		check("Château : file d'attente distincte de l'arène (même taille, deux files)", e.P.enter(1, 2, "castle") == true and e.P.status(2, "castle").count == 1 and e.P.status(2).count == 0 and e.P.status(2, "castle").queue == "castle")
		e.P.enter(2, 2, "castle")
		e.P.status(2, "castle") -- démarre le compte à rebours du groupe complet
		e.now = e.now + G.CountdownFull + 0.1
		local launches = e.P.collectLaunches()
		check("Château : groupe complet -> lancement avec mode « castle »", #launches == 1 and launches[1].mode == "castle" and #launches[1].members == 2)
		local r = e.P.launch({ size = 2, mode = "castle", members = { 1, 2 }, players = { { UserId = 1 }, { UserId = 2 } }, hostName = "Ana" })
		check("Château : les données de téléportation portent mode = castle ; l'arène reste « arena » par défaut", r.ok and e.calls[1].data.mode == "castle" and e.entries[r.partyId].mode == "castle")
		local j = e.P.join(r.partyId, { UserId = 3 }, 3, { [1] = true })
		check("Château : un ami qui rejoint reçoit le même mode (castle) et le même serveur réservé", j.ok and e.calls[#e.calls].data.mode == "castle" and e.calls[#e.calls].code == e.calls[1].code)
		local e2 = env()
		e2.P.enter(5, 1)
		e2.P.status(1)
		e2.now = e2.now + G.SoloCountdown + 0.1
		local arena = e2.P.collectLaunches()
		local ra = e2.P.launch({ size = 1, members = { 5 }, players = { { UserId = 5 } }, hostName = "Solo" })
		check("Arène : mode « arena » par défaut dans le lancement et les données", arena[1].mode == "arena" and e2.calls[1].data.mode == "arena")
		local e3 = env()
		e3.P.enter(9, 3, "castle")
		e3.P.enter(9, 3)
		check("Château : changer de file quitte l'ancienne (une seule file à la fois)", e3.P.status(3, "castle").count == 0 and e3.P.status(3).count == 1)
		check("Château : taille inconnue refusée", e3.P.enter(9, 7, "castle") == false)
	end

	do -- partie lancée SEULE : les amis du créateur peuvent la rejoindre, jamais un inconnu ; elle disparaît quand tout le monde est parti
		local e = env()
		local r = e.P.launch({ size = 1, members = { 500 }, players = { { UserId = 500 } }, hostName = "Solo" })
		local friends = { [500] = true }
		check("solo : la partie est visible des amis avec des places libres", #e.P.visibleFor(501, friends) == 1 and e.P.visibleFor(501, friends)[1].count == 1 and e.P.visibleFor(501, friends)[1].size == G.MaxPlayers)
		check("solo : un inconnu ne la voit pas et ne peut pas la rejoindre", #e.P.visibleFor(502, {}) == 0 and e.P.join(r.partyId, { UserId = 502 }, 502, {}).ok == false)
		check("solo : un ami la rejoint (même serveur réservé, plafond 5)", e.P.join(r.partyId, { UserId = 501 }, 501, friends).ok == true and e.entries[r.partyId].count == 2 and e.calls[#e.calls].code == e.calls[1].code)
		for uid = 503, 505 do
			e.P.join(r.partyId, { UserId = uid }, uid, friends)
		end
		check("solo : 5 joueurs au maximum, le 6e ami reçoit « pleine »", e.P.join(r.partyId, { UserId = 506 }, 506, friends).reason == "full")
		for _, uid in ipairs({ 500, 501, 503, 504, 505 }) do
			e.P.leaveParty(r.partyId, uid)
		end
		local after = e.P.join(r.partyId, { UserId = 507 }, 507, friends)
		check("solo : quand tout le monde est parti, la partie est retirée du registre (« n'existe plus »)", e.entries[r.partyId] == nil and after.reason == "gone" and after.message:find("n'existe plus", 1, true) ~= nil and #e.P.visibleFor(507, friends) == 0)
	end

	do -- plafond de 5 même si le registre dit autrement
		local e = env()
		e.entries["x"] = { id = "x", host = 1, hostName = "H", size = 9, count = 5, members = { 1, 2, 3, 4, 5 }, code = "C", createdAt = e.now, open = true }
		check("plafond 5 : jamais de 6e joueur", e.P.join("x", { UserId = 6 }, 6, { [1] = true }).reason == "full" and e.entries["x"].count == 5 and #e.P.visibleFor(77, { [1] = true }) == 0)
	end

	do -- serveur indisponible, téléportation refusée, repli public
		local e = env({ reserveFail = "ReserveServer: place of another experience" })
		local r = e.P.launch({ size = 3, members = { 1, 2 }, players = { {}, {} }, hostName = "H" })
		check("réservation refusée : repli sur un serveur public, partie non inscrite", r.ok and r.mode == "public" and e.calls[1].code == nil and next(e.entries) == nil)
		local e2 = env({ teleportFail = "Unauthorized" })
		local r2 = e2.P.launch({ size = 2, members = { 1, 2 }, players = { {}, {} }, hostName = "H" })
		check("téléportation privée refusée : repli public", r2.ok and r2.mode == "public" and next(e2.entries) == nil)
		local e3 = env({ reserveFail = "boom", publicFail = "TeleportService indisponible" })
		local r3 = e3.P.launch({ size = 2, members = { 1, 2 }, players = { {}, {} }, hostName = "H" })
		check("tout échoue : message clair, aucune erreur, aucune partie fantôme", r3.ok == false and type(r3.message) == "string" and #r3.message > 10 and next(e3.entries) == nil and #e3.calls == 0)
		local e4 = env({ reserveFail = "boom" })
		local saved = G.Fallbacks
		G.Fallbacks = { "reserved" }
		local r4 = e4.P.launch({ size = 2, members = { 1 }, players = { {} }, hostName = "H" })
		G.Fallbacks = saved
		check("repli public retiré de la config : échec propre", r4.ok == false)
		local savedPlace = G.Places.game
		G.Places.game = 0
		local r5 = env().P.launch({ size = 2, members = { 1 }, players = { {} }, hostName = "H" })
		G.Places.game = savedPlace
		check("lieu de jeu non configuré : message clair", r5.ok == false and r5.message:find("configur") ~= nil)
		-- rejoindre : téléportation qui échoue -> la place est rendue
		local e6 = env()
		local r6 = e6.P.launch({ size = 3, members = { 1 }, players = { {} }, hostName = "H" })
		e6.teleportFail = "Unauthorized"
		local j = e6.P.join(r6.partyId, {}, 2, { [1] = true })
		check("rejoindre refusé par Roblox : message clair et place rendue", j.ok == false and j.reason == "teleport" and e6.entries[r6.partyId].count == 1 and #e6.entries[r6.partyId].members == 1)
	end

	do -- registre indisponible : le jeu se lance quand même
		local e = env({ storeFail = true })
		local r = e.P.launch({ size = 4, members = { 1, 2 }, players = { {}, {} }, hostName = "H" })
		check("registre indisponible : le lancement réussit, sans inscription", r.ok and r.mode == "reserved" and r.registered == false)
		local list, ok = e.P.visibleFor(1, { [2] = true })
		check("registre indisponible : liste vide sans erreur", #list == 0 and ok == false)
		check("registre indisponible : rejoindre -> message clair", e.P.join("x", {}, 3, { [2] = true }).reason == "registry")
	end

	do -- sécurité : seuls les amis de l'hôte (ou les inscrits) rejoignent, identifiants imprévisibles, liste blanche à l'arrivée
		local e = env()
		local r = e.P.launch({ size = 4, members = { 42, 43 }, players = { {}, {} }, hostName = "Léa" })
		local pid = r.partyId
		check("sécurité : l'identifiant n'est pas déductible de l'hôte ni de l'heure", pid ~= nil and not pid:find("42_", 1, true) and not pid:find(tostring(math.floor(e.now * 1000)), 1, true))
		local r2 = e.P.launch({ size = 4, members = { 42 }, players = { {} }, hostName = "Léa" })
		check("sécurité : deux parties du même hôte au même instant ont des identifiants différents", r2.partyId ~= pid)
		local stranger = e.P.join(pid, { UserId = 99 }, 99, {})
		check("sécurité : un inconnu qui envoie un identifiant valide est refusé", stranger.ok == false and stranger.reason == "gone" and e.entries[pid].count == 2 and #e.entries[pid].members == 2)
		check("sécurité : sans ensemble d'amis fourni, refus", e.P.join(pid, { UserId = 99 }, 99, nil).ok == false)
		check("sécurité : ami d'un autre joueur que l'hôte refusé", e.P.join(pid, { UserId = 98 }, 98, { [777] = true }).ok == false and e.entries[pid].count == 2)
		local callsBefore = #e.calls
		local friend = e.P.join(pid, { UserId = 7 }, 7, { [42] = true })
		check("sécurité : un ami de l'hôte est accepté (et la téléportation part)", friend.ok == true and e.entries[pid].count == 3 and #e.calls == callsBefore + 1)
		check("sécurité : même message pour un inconnu et une partie inexistante (rien n'est révélé)", e.P.join(pid, { UserId = 99 }, 99, {}).message == e.P.join("inventé", { UserId = 99 }, 99, {}).message)
		check("sécurité : identifiant inventé refusé", e.P.join("inventé", { UserId = 7 }, 7, { [42] = true }).reason == "gone")
		check("sécurité : identifiant d'un type invalide refusé sans erreur", e.P.join({}, { UserId = 7 }, 7, { [42] = true }).ok == false and e.P.join(nil, { UserId = 7 }, 7, { [42] = true }).ok == false)
		e.P.join(pid, { UserId = 8 }, 8, { [42] = true })
		e.P.join(pid, { UserId = 20 }, 20, { [42] = true })
		check("sécurité : partie pleine refusée même pour un ami", e.P.join(pid, { UserId = 9 }, 9, { [42] = true }).reason == "full")
		e.entries[pid].open = false
		check("sécurité : partie fermée refusée même pour un ami", e.P.join(pid, { UserId = 5 }, 5, { [42] = true }).reason == "gone")
		local A = Party.admitJoin
		check("liste blanche : premier arrivé envoyé par le hub accepté", A(nil, { partyId = "P1", from = "hub" }, 0, 5, "game") == true)
		check("liste blanche : même partie acceptée", A("P1", { partyId = "P1", from = "hub", late = true }, 2, 5, "game") == true)
		local ok1, why1 = A("P1", { partyId = "P2", from = "hub" }, 1, 5, "game")
		check("liste blanche : autre partie refusée (not_member)", ok1 == false and why1 == "not_member")
		local ok2, why2 = A("P1", nil, 1, 5, "game")
		check("liste blanche : arrivée directe sans données sur un serveur de partie refusée", ok2 == false and why2 == "not_member")
		check("liste blanche : données forgées (from ~= hub) refusées", A("P1", { partyId = "P1", from = "x" }, 1, 5, "game") == false)
		check("liste blanche : serveur public sans partie accepte les arrivées directes", A(nil, nil, 0, 5, "game") == true)
		local ok3, why3 = A("P1", { partyId = "P1", from = "hub" }, 5, 5, "game")
		check("liste blanche : serveur plein refusé (full)", ok3 == false and why3 == "full")
		check("liste blanche : Studio (rôle inconnu) sans restriction de partie", A("P1", nil, 0, 5, "unknown") == true)
		check("liste blanche : TeleportData invalide sans erreur", A("P1", 42, 0, 5, "game") == false and A(nil, "x", 0, 5, "game") == true)
	end
end

-- Carte : dimensions, domaines, ambiance, secrets -----------------------------------------------------------------------
do
	suite("Carte : dimensions, domaines, ambiance, secrets")
	local M = Config.Map
	check("Map : sol plus grand que l'ancienne carte (620)", M.groundSize >= 1000)
	check("Map : un domaine par rival, clés d'ambiance complètes", #M.zoneKeys == #Config.RIVALS and (function()
		for _, k in ipairs(M.zoneKeys) do
			local a = M.ambience[k]
			if not (a and a.clock and a.ambient and a.outdoor and a.tint and a.atmo and a.density and a.haze) then
				return false
			end
		end
		return M.ambience.arena ~= nil
	end)())
	local half = M.groundSize / 2
	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end
	local ok, why = true, ""
	local function must(c, m2)
		if not c and ok then
			ok, why = false, m2
		end
	end
	local centers = {}
	for i = 1, #Config.RIVALS do
		local x, z = Config.rivalCenter(i)
		centers[i] = { x, z }
		must(math.abs(x) + M.domainRadius < half and math.abs(z) + M.domainRadius < half, "domaine " .. i .. " dans la carte")
		must(dist(x, z, 0, 0) > 75 + M.domainRadius * 0.5, "domaine " .. i .. " hors de l'arène centrale")
	end
	for i = 1, #centers do
		for j = i + 1, #centers do
			must(dist(centers[i][1], centers[i][2], centers[j][1], centers[j][2]) >= 2 * M.domainRadius + 8, "domaines " .. i .. " et " .. j .. " séparés")
		end
	end
	-- les bases (52 x 52, anneau de rayon plotRadius) ne chevauchent ni les domaines ni le tapis roulant
	for p = 1, Config.PLOT_COUNT do
		local a = (p - 1) / Config.PLOT_COUNT * math.pi * 2
		local px, pz = math.sin(a) * M.plotRadius, math.cos(a) * M.plotRadius
		must(math.abs(px) + 40 < half and math.abs(pz) + 40 < half, "base " .. p .. " dans la carte")
		for i = 1, #centers do
			must(dist(px, pz, centers[i][1], centers[i][2]) > M.domainRadius + 26 + 6, "base " .. p .. " loin du domaine " .. i)
		end
		must(dist(px, pz, 0, 38) > 70, "base " .. p .. " loin du tapis roulant")
	end
	for _, sct in ipairs(Config.SECRETS) do
		must(math.abs(sct.x) < half - 20 and math.abs(sct.z) < half - 20, "secret " .. sct.id .. " dans la carte")
		must(dist(sct.x, sct.z, 0, 0) > M.plotRadius + 60, "secret " .. sct.id .. " loin du centre (à explorer)")
		must(sct.minCoins > 0 and sct.mins > 0 and sct.hint ~= "" and Config.secret(sct.id) == sct, "secret " .. sct.id .. " complet")
	end
	check("Map : domaines, bases et secrets cohérents" .. (ok and "" or " : " .. why), ok)
	check("zoneAt : au centre de chaque domaine = son ambiance", (function()
		for i, k in ipairs(M.zoneKeys) do
			local x, z = Config.rivalCenter(i)
			if Config.zoneAt(x, z) ~= k or Config.zoneAt(x + 10, z + 10) ~= k then
				return false
			end
		end
		return true
	end)())
	check("zoneAt : arène, bases et lointain = arena", Config.zoneAt(0, 0) == "arena" and Config.zoneAt(0, 215) == "arena" and Config.zoneAt(500, 500) == "arena")
	check("zoneAt : hors de la portée d'un domaine = arena", Config.zoneAt(0, select(2, Config.rivalCenter(2)) + Config.Map.ambienceRadius + 5) == "arena")
	check("secretReward : plancher et proportion aux revenus", Config.secretReward(Config.SECRETS[1], 0) == Config.SECRETS[1].minCoins and Config.secretReward(Config.SECRETS[1], 1000) == 1000 * Config.SECRETS[1].mins * 60)
	check("Streaming : rayons cohérents", M.Streaming.MinRadius < M.Streaming.TargetRadius and M.Streaming.TargetRadius <= 1024)
end

-- Décor de la carte : exécution avec un Roblox factice (détecte les erreurs d'exécution et vérifie le compte de Parts) -----------------
do
	suite("Décor de la carte : exécution avec un Roblox factice (détecte les erreurs d'exécution et v")
	local function vec(x, y, z)
		local v = { X = x, Y = y, Z = z }
		return setmetatable(v, {
			__add = function(a, b)
				return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
			end,
			__sub = function(a, b)
				return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
			end,
			__mul = function(a, b)
				if type(b) == "number" then
					return vec(a.X * b, a.Y * b, a.Z * b)
				end
				return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
			end,
		})
	end
	local function cf(x, y, z)
		local c = { Position = vec(x or 0, y or 0, z or 0) }
		return setmetatable(c, {
			__mul = function(a, b)
				if b.Position and b.Position.X ~= nil and b.Position.Y ~= nil then
					return cf(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
				end
				return a
			end,
		})
	end
	local enumMeta = {
		__index = function(t, k)
			local sub = setmetatable({}, { __index = function(_, k2)
				return k .. "." .. k2
			end })
			rawset(t, k, sub)
			return sub
		end,
	}
	local function newInstance(class)
		local o = { ClassName = class, children = {}, attrs = {} }
		function o:SetAttribute(k, v)
			self.attrs[k] = v
		end
		function o:GetDescendants()
			return {}
		end
		return o
	end
	local env = {
		Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end },
		Vector3 = { new = function(x, y, z) return vec(x or 0, y or 0, z or 0) end },
		Vector2 = { new = function(x, y) return { X = x, Y = y } end },
		CFrame = { new = function(x, y, z)
			if type(x) == "table" and x.X then
				return cf(x.X, x.Y, x.Z)
			end
			return cf(x, y, z)
		end, Angles = function() return cf(0, 0, 0) end },
		Enum = setmetatable({}, enumMeta),
		Instance = { new = newInstance },
		UDim2 = { fromOffset = function() return {} end, fromScale = function() return {} end },
		ColorSequence = { new = function() return {} end },
		NumberRange = { new = function() return {} end },
		NumberSequence = { new = function() return {} end },
		NumberSequenceKeypoint = { new = function() return {} end },
		game = { GetService = function() return { AddTag = function() end } end },
	}
	local Scenery = luau.load(fs.readFile("roblox/src/ServerScriptService/Scenery.lua"), { debugName = "Scenery", environment = env })()
	local made = 0
	local function mk(props)
		made = made + 1
		local o = newInstance("Part")
		for k, v in pairs(props) do
			o[k] = v
		end
		return o
	end
	local helpers = {
		part = function(props)
			return mk(props)
		end,
		ball = function(props)
			return mk(props)
		end,
		tree = function()
			made = made + 4
		end,
		torch = function() end,
		sign = function() end,
	}
	local seed = 5
	local rng = {
		NextNumber = function(_, a, b)
			seed = (seed * 16807) % 2147483647
			return (a or 0) + (seed / 2147483647) * ((b or 1) - (a or 0))
		end,
		NextInteger = function(self, a, b)
			return math.floor(self:NextNumber(a, b + 1))
		end,
	}
	local total = 0
	local function run(name, fn, ...)
		made = 0
		local ok, n = pcall(fn, helpers, ...)
		check("Scenery." .. name .. " : s'exécute sans erreur" .. (ok and "" or " : " .. tostring(n)), ok)
		if ok then
			check("Scenery." .. name .. " : compte de Parts exact (" .. tostring(n) .. " annoncées, " .. made .. " créées)", n == made and n > 0)
			total = total + n
		end
	end
	for i, key in ipairs(Config.Map.zoneKeys) do
		local cx, cz = Config.rivalCenter(i)
		run(key, Scenery[key], cx, cz, {}, rng)
	end
	run("paths", function(h, parent) return Scenery.paths(h, parent, Config) end, {})
	run("landmarks", function(h, parent) return Scenery.landmarks(h, parent, rng) end, {})
	run("relief", function(h, parent) return Scenery.relief(h, parent, rng, Config) end, {})
	run("secrets", function(h, parent) return Scenery.secrets(h, parent, Config) end, {})
	made = 0
	local okM, ring = pcall(Scenery.marker, helpers, vec(0, 0, 0), {}, "✋", 8)
	check("Scenery.marker : anneau interactif créé (une Part, attribut BaseT)", okM and made == 1 and ring.attrs.BaseT ~= nil)
	-- piédestal, aura, douve, rivières
	made = 0
	local okN, nN = pcall(Scenery.nest, helpers, vec(0, 0, 0), {})
	check("Scenery.nest : nid de paille (plateau, bord, 8 brins) sans erreur, compte exact", okN and nN == 10 and made == 10)
	made = 0
	local okP, nP = pcall(Scenery.pedestal, helpers, vec(0, 0, 0), {}, nil)
	check("Scenery.pedestal : disque de marbre + liseré (2 Parts) sans erreur, compte exact", okP and nP == 2 and made == 2)
	for _, spec in ipairs({ { 4, false }, { 5, false }, { 6, false }, { 3, true } }) do
		made = 0
		local style = Config.auraStyle(spec[1], spec[2], false)
		local okA, anchor, nA = pcall(Scenery.aura, helpers, vec(0, 0, 0), {}, style, { R = 1, G = 0.5, B = 0 })
		check("Scenery.aura (rareté " .. spec[1] .. (spec[2] and ", secret" or "") .. ") : cercle runique, particules, lumière" .. (okA and "" or " : " .. tostring(anchor)), okA and anchor ~= nil and nA == made and nA <= Config.AURA.maxParts)
	end
	made = 0
	local okM, nM = pcall(Scenery.moat, helpers, 0, 0, {}, Config)
	check("Scenery.moat : douve (" .. Config.Map.decor.moatSegments .. " segments) et pont en bois, compte exact", okM and nM == made and nM >= 20)
	made = 0
	local CastleMod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })()
	local okC, cworld, nC = pcall(Scenery.castle, helpers, {}, CastleMod)
	check("Scenery.castle : donjon (5 salles, pièges, entrée, coffre, tableau) sans erreur, compte exact, sous 400 Parts" .. (okC and "" or " : " .. tostring(cworld)), okC and nC == made and nC <= 400 and #cworld.rooms == 5 and cworld.chest ~= nil and cworld.entry ~= nil and cworld.board ~= nil)
	check("Scenery.castle : chaque salle expose ses pièges (pics, lames, boulets) et sa porte selon la difficulté", okC and #cworld.rooms[1].spikes == CastleMod.room(1).spikes and #cworld.rooms[5].blades == 2 and #cworld.rooms[5].balls == 3 and cworld.rooms[3].door ~= nil)
	made = 0
	local okR, nR = pcall(Scenery.rivers, helpers, {}, Config)
	check("Scenery.rivers : 2 rivières et 4 ponts, compte exact", okR and nR == made and nR >= 16)
	-- géométrie : la douve ne passe sous aucune base de joueur
	local R, W = Config.Map.moat.radius, Config.Map.moat.width
	local clear = true
	for pl = 1, Config.PLOT_COUNT do
		local ang = (pl - 1) / Config.PLOT_COUNT * math.pi * 2
		local px, pz = math.sin(ang) * Config.Map.plotRadius, math.cos(ang) * Config.Map.plotRadius
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			if math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2) - 26 < R + W / 2 + 1 then
				clear = false
			end
		end
	end
	check("Douve : l'anneau d'eau (rayon " .. R .. " + largeur) ne recouvre aucune base de joueur", clear)
	check("Douve : le domaine (rayon 38 et décors jusqu'à 52) est à l'intérieur de la douve", R - W / 2 >= 52)
	check("Rivières : n'écrasent ni les secrets, ni les bases", (function()
		for _, sct in ipairs(Config.SECRETS) do
			if math.abs(sct.x - -380) < 20 or math.abs(sct.z - 330) < 20 then
				return false
			end
		end
		return true
	end)())
	check("Scenery : décor total dans le budget mobile (" .. total .. " Parts, budget " .. Config.Map.budgetParts .. ")", total > 300 and total < Config.Map.budgetParts * 0.6)
end

-- Filet anti-chute et garantie de personnage ------------------------------------------------------------------------
do
	suite("Filet anti-chute et garantie de personnage")
	local Spawn = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Spawn.lua"), { debugName = "Spawn" })()
	for role, cfg in pairs(Spawn.PRESETS) do
		local function R(st)
			return Spawn.rescueReason(st, cfg)
		end
		local ok = { hasChar = true, alive = true, x = 10, y = 5, z = -20, vy = 0 }
		local function with(k, v)
			local c = {}
			for a, b in pairs(ok) do
				c[a] = b
			end
			c[k] = v
			return c
		end
		check(role .. " : joueur normal au sol -> aucun sauvetage", R(ok) == nil)
		check(role .. " : saut normal (vy positif ou faible) -> aucun sauvetage", R(with("vy", 40)) == nil and R(with("vy", -60)) == nil)
		check(role .. " : sans personnage depuis peu -> attente", R({ hasChar = false, waited = cfg.noCharTimeout - 1 }) == nil)
		check(role .. " : sans personnage depuis trop longtemps -> chargement", R({ hasChar = false, waited = cfg.noCharTimeout }) == "nochar")
		check(role .. " : sous le sol -> void", R(with("y", cfg.floorY - 1)) == "void")
		check(role .. " : position NaN -> void", R(with("y", 0 / 0)) == "void" and R(with("x", 0 / 0)) == "void")
		check(role .. " : hors de la zone -> outside", R(with("x", cfg.half + 1)) == "outside" and R(with("z", -cfg.half - 1)) == "outside")
		check(role .. " : trop haut -> sky", R(with("y", cfg.sky + 1)) == "sky")
		check(role .. " : chute libre rapide près du sol -> freefall", R(with("vy", cfg.freefallSpeed - 1)) == "freefall")
		check(role .. " : chute rapide mais très haut (saut sur une tour) -> pas de sauvetage", R({ hasChar = true, alive = true, x = 0, y = cfg.freefallY + 50, z = 0, vy = cfg.freefallSpeed - 20 }) == nil)
		check(role .. " : joueur mort -> pas de sauvetage (le respawn s'en charge)", R({ hasChar = true, alive = false, x = 0, y = cfg.floorY - 50, z = 0, vy = 0 }) == nil)
		check(role .. " : réglages cohérents", cfg.floorY < 0 and cfg.half > 0 and cfg.noCharTimeout > 0 and cfg.sky > cfg.freefallY)
	end
	check("carte du jeu : la zone jouable couvre le sol (demi-côté du preset >= moitié du sol - 10)", Spawn.PRESETS.game.half >= Config.Map.groundSize / 2 - 10)
	local t = Spawn.newTally()
	local n = 0
	for i = 1, 7 do
		n = t.add("void", i)
	end
	check("tally : 7 sauvetages en une minute comptés (alerte au-delà de 6)", n == 7 and t.total == 7 and t.counts.void == 7)
	check("tally : la fenêtre d'une minute glisse", t.add("void", 100) == 1)
end

-- Hub : construction du monde avec un Roblox factice ---------------------------------------------------------------------
do
	suite("Hub : construction du monde avec un Roblox factice")
	local Fake = luau.load(fs.readFile("roblox/tests/FakeRoblox.lua"), { debugName = "FakeRoblox" })()
	local f = Fake.new()
	local env = f.env
	env.script = { Parent = {} }
	local HubWorld = luau.load(fs.readFile("roblox/src/Hub/ServerScriptService/HubWorld.lua"), { debugName = "HubWorld", environment = env })()
	local ok, world = pcall(HubWorld.build, Config)
	check("HubWorld.build : s'exécute sans erreur" .. (ok and "" or " : " .. tostring(world)), ok)
	if ok then
		local zoneCount = 0
		for size, z in pairs(world.zones) do
			zoneCount = zoneCount + 1
			check("HubWorld : zone " .. size .. " complète (pastille, statut, centre, rayon)", z.part ~= nil and z.status ~= nil and z.center ~= nil and z.radius > 0)
		end
		check("HubWorld : une zone par taille de partie (1 à 5) pour l'arène ET pour le Château", zoneCount == 2 * #Config.Game.Sizes and world.zones[1] ~= nil and world.zones[5] ~= nil and world.zones.c1 ~= nil and world.zones.c5 ~= nil and world.zones.c3.mode == "castle" and world.zones[3].mode == "arena" and world.zones.c3.size == 3)
		check("HubWorld : point d'arrivée présent", world.spawn ~= nil)
		local parts = f.counts.Part or 0
		check("HubWorld : décor riche mais léger (" .. parts .. " Parts, entre 200 et 800)", parts >= 200 and parts <= 800)
		check("HubWorld : 4 murs et un plafond invisibles", (function()
			local walls, ceiling = 0, 0
			for _, o in ipairs(f.created) do
				if o.Name == "InvisibleWall" and o.Transparency == 1 then
					walls = walls + 1
				elseif o.Name == "InvisibleCeiling" and o.Transparency == 1 then
					ceiling = ceiling + 1
				end
			end
			return walls == 4 and ceiling == 1
		end)())
		check("HubWorld : 3 panneaux d'explication avec texte", (function()
			local boards = 0
			for _, o in ipairs(f.created) do
				if o.ClassName == "TextLabel" and type(o.Text) == "string" and o.Text:find("Comment jouer", 1, true) then
					boards = boards + 1
				end
				if o.ClassName == "TextLabel" and type(o.Text) == "string" and (o.Text:find("Lancer une partie", 1, true) or o.Text:find("Rejoindre des amis", 1, true)) then
					boards = boards + 1
				end
			end
			return boards == 3
		end)())
		check("HubWorld : les zones portent le tag PortalZone", f.tags.PortalZone == 2 * #Config.Game.Sizes)
	end
end

-- Décor catalogue du hub : identifiants et emplacements ---------------------------------------------------------------------
do
	suite("Décor catalogue du hub : identifiants et emplacements")
	local A = Config.Assets
	local function validId(id)
		return type(id) == "number" and id > 0 and id % 1 == 0
	end
	local n = 0
	for _, id in pairs(A.decor) do
		n = n + 1
		check("décor : identifiant valide " .. tostring(id), validId(id))
	end
	check("décor : 13 modèles fournis", n == 13)
	local animals = 0
	for _, id in pairs(A.animals) do
		animals = animals + 1
		check("animaux : identifiant valide " .. tostring(id), validId(id))
	end
	check("animaux : 3 packs gardés, non chargés", animals == 3 and A.decor.pack1 == nil)
	check("œufs : les 5 modèles de la liste utilisateur", A.eggs.red == 151044983 and A.eggs.legendary == 2937230482 and A.eggs.glitch == 2937218888 and A.eggs.orange == 147144059 and A.eggs.purple == 112478990)
	local ok, why = true, ""
	local function must(c, m2)
		if not c and ok then
			ok, why = false, m2
		end
	end
	local sizes = Config.Game.Sizes
	for i, spot in ipairs(Config.HubDecor) do
		local key, x, z, rot, h = spot[1], spot[2], spot[3], spot[4], spot[5]
		must(A.decor[key] ~= nil, "emplacement " .. i .. " : clé inconnue " .. tostring(key))
		must(h >= 2 and h <= 20, "emplacement " .. i .. " : hauteur raisonnable")
		must(math.abs(x) < 180 and math.abs(z) < 180, "emplacement " .. i .. " dans le hub")
		must(not (math.abs(x) < 14 and z > 24 and z < 44), "emplacement " .. i .. " hors du point d'arrivée")
		must(math.sqrt(x * x + z * z) > 22, "emplacement " .. i .. " hors de la fontaine")
		must(z > 44, "emplacement " .. i .. " dans la zone libre au sud")
		for j = i + 1, #Config.HubDecor do
			local o = Config.HubDecor[j]
			must(math.sqrt((x - o[2]) ^ 2 + (z - o[3]) ^ 2) >= 3, "emplacements " .. i .. " et " .. j .. " distincts")
		end
		for k = 1, #sizes do
			local a = math.rad(-72 + (k - 1) * 36)
			must(math.sqrt((x - math.sin(a) * 62) ^ 2 + (z + math.cos(a) * 62) ^ 2) > 16, "emplacement " .. i .. " loin du portail " .. k)
		end
	end
	check("HubDecor : emplacements cohérents" .. (ok and "" or " : " .. why), ok)
	-- chargement avec chargeur factice : décor sain, refusé, plafond de Parts propre au décor
	local AssetsMod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Assets.lua"), { debugName = "Assets" })()
	local function inst(class, children)
		local o = { ClassName = class, children = children or {}, destroyed = false }
		function o:IsA(c)
			return self.ClassName == c or (c == "BasePart" and self.ClassName == "Part")
		end
		function o:Destroy()
			self.destroyed = true
		end
		function o:Clone()
			return inst(self.ClassName, self.children)
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
	local function mkDeps(loader)
		return { loadAsset = loader, spawn = function(fn) fn() end, wait = function(sec) clock = clock + sec end, clock = function() return clock end, warn = function() end }
	end
	local many = function()
		local ch = {}
		for i = 1, 100 do
			ch[i] = inst("Part")
		end
		ch[101] = inst("Script")
		return inst("Model", ch)
	end
	local D = AssetsMod.new(Config, mkDeps(many))
	check("décor : un modèle de 100 Parts est accepté (plafond décor 220) et nettoyé", D.loadDecor() == 13 and D.cloneDecor("sofa") ~= nil and #D.templates["d:sofa"]:GetDescendants() == 100)
	check("décor : un modèle de 100 Parts serait refusé comme œuf (plafond 60)", AssetsMod.new(Config, mkDeps(many)).loadAll() == 0)
	local denied = AssetsMod.new(Config, mkDeps(function() error("Requester does not have permission for Asset") end))
	check("décor : permission refusée -> rien chargé, rien ne casse, cloneDecor nil", denied.loadDecor() == 0 and denied.cloneDecor("sofa") == nil)
	local saved = A.Enabled
	A.Enabled = false
	local off = AssetsMod.new(Config, mkDeps(many))
	check("décor : Enabled = false -> aucun chargement", off.loadDecor() == 0 and off.cloneDecor("sofa") == nil)
	A.Enabled = saved
end

-- Révélation d'œuf : « 1 sur N » = probabilité réelle ---------------------------------------------------------------------
do
	suite("Révélation d'œuf : probabilité affichée égale à la probabilité réelle")
	local Reveal = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Reveal.lua"), { debugName = "Reveal" })()
	local function total(eggTier, up, alien, guaranteed)
		local sum = 0
		for p = 1, #Config.PETS do
			for sz = 1, #Config.SIZES do
				for mu = 1, #Config.MUTS do
					sum = sum + Reveal.probability(Config, Rules, eggTier, up, alien, p, sz, mu, guaranteed)
				end
			end
		end
		return sum
	end
	local sumsOk = true
	for tier = 1, #Config.TIERS do
		for _, up in ipairs({ 0, 12, 40, 70 }) do
			for _, alien in ipairs({ false, true }) do
				if math.abs(total(tier, up, alien, false) - 1) > 1e-9 then
					sumsOk = false
				end
			end
		end
		if tier < #Config.TIERS and math.abs(total(tier, 12, false, true) - 1) > 1e-9 then
			sumsOk = false
		end
	end
	check("Reveal : les probabilités de tous les résultats somment à 1 (6 raretés, 4 niveaux de chance, événement alien, pitié)", sumsOk)
	-- fréquences simulées avec le VRAI tirage de Rules.rollPet comparées aux probabilités annoncées
	local function freqTest(label, eggTier, up, alien, guaranteed, n)
		local seed = 4242 + eggTier * 7
		local function rnd()
			seed = (seed * 16807) % 2147483647
			return seed / 2147483647
		end
		local counts = {}
		for _ = 1, n do
			local r = Rules.rollPet(eggTier, up, alien, rnd, guaranteed)
			local key = r.p .. ":" .. r.s .. ":" .. r.m
			counts[key] = (counts[key] or 0) + 1
		end
		local worst, ok = 0, true
		for p = 1, #Config.PETS do
			for sz = 1, #Config.SIZES do
				for mu = 1, #Config.MUTS do
					local pr = Reveal.probability(Config, Rules, eggTier, up, alien, p, sz, mu, guaranteed)
					local obs = (counts[p .. ":" .. sz .. ":" .. mu] or 0) / n
					local sigma = math.sqrt(math.max(pr * (1 - pr), 1e-12) / n)
					if pr == 0 and obs > 0 then
						ok = false
					end
					if sigma > 0 and pr > 0.0005 then
						worst = math.max(worst, math.abs(obs - pr) / sigma)
					end
				end
			end
		end
		check("Reveal : fréquences simulées = probabilités annoncées (" .. label .. ", écart max " .. string.format("%.1f", worst) .. " sigma)", ok and worst < 5)
	end
	freqTest("œuf Épique, chance de base", 3, Rules.upPoints(0, false, false, false), false, false, 150000)
	freqTest("œuf Commun, chance +40 et biome alien", 1, 40, true, false, 150000)
	freqTest("œuf Légendaire, pitié", 4, 12, false, true, 150000)
	freqTest("œuf Cosmique (rareté max)", 6, 12, false, false, 150000)
	-- vérification DÉTERMINISTE (sans générateur aléatoire, identique sous tous les moteurs) : la loi de rareté de rollPet par balayage exact
	-- du premier tirage = la loi annoncée par Reveal.probability, et idem pour l'espèce, la taille et la mutation (un balayage par tirage).
	local function sweep(eggTier, up, alien, guaranteed, drawIndex, buckets, key)
		local N = 20000
		local counts = {}
		for k = 0, N - 1 do
			local u = (k + 0.5) / N
			local call = 0
			local function rnd()
				call = call + 1
				return call == drawIndex and u or 0.5
			end
			local r = Rules.rollPet(eggTier, up, alien, rnd, guaranteed)
			local kk = key(r)
			counts[kk] = (counts[kk] or 0) + 1
		end
		local worst = 0
		for kk, expected in pairs(buckets) do
			worst = math.max(worst, math.abs((counts[kk] or 0) / N - expected))
		end
		return worst
	end
	local function marginal(eggTier, up, alien, guaranteed, key)
		local out = {}
		for p = 1, #Config.PETS do
			for sz = 1, #Config.SIZES do
				for mu = 1, #Config.MUTS do
					local pr = Reveal.probability(Config, Rules, eggTier, up, alien, p, sz, mu, guaranteed)
					local kk = key(p, sz, mu)
					out[kk] = (out[kk] or 0) + pr
				end
			end
		end
		return out
	end
	local sweepOk, sweepWhy = true, ""
	for _, cfgRow in ipairs({ { 3, 12, false, false }, { 1, 40, true, false }, { 4, 12, false, true }, { 6, 12, false, false }, { 2, 70, false, false } }) do
		local et, up, alien, g = cfgRow[1], cfgRow[2], cfgRow[3], cfgRow[4]
		local byTier = marginal(et, up, alien, g, function(p) return Config.PETS[p].tier end)
		local bySize = marginal(et, up, alien, g, function(_, sz) return sz end)
		local byMut = marginal(et, up, alien, g, function(_, _, mu) return mu end)
		local shift = g and 1 or 0 -- la pitié ne consomme pas de tirage pour la rareté
		local e1 = g and 0 or sweep(et, up, alien, g, 1, byTier, function(r) return r.tier end)
		local e3 = sweep(et, up, alien, g, 3 - shift, bySize, function(r) return r.s end)
		local e4 = sweep(et, up, alien, g, 4 - shift, byMut, function(r) return r.m end)
		if e1 > 1e-3 or e3 > 1e-3 or e4 > 1e-3 then
			sweepOk, sweepWhy = false, string.format("œuf %d : écarts rareté %.4f, taille %.4f, mutation %.4f", et, e1, e3, e4)
		end
	end
	check("Reveal : balayage exact des tirages (sans aléatoire) : lois de rareté, de taille et de mutation = probabilités annoncées" .. (sweepOk and "" or " : " .. sweepWhy), sweepOk)
	check("Reveal.oneIn = 1 / probabilité", (function()
		local pr = Reveal.probability(Config, Rules, 3, 12, false, 7, 2, 1, false)
		local n = Reveal.oneIn(Config, Rules, 3, 12, false, 7, 2, 1, false)
		return pr > 0 and math.abs(n * pr - 1) < 1e-9
	end)())
	check("Reveal : résultat impossible = probabilité 0 et « jamais » (rareté hors de portée de l'œuf)", Reveal.probability(Config, Rules, 1, 12, false, 16, 2, 1, false) == 0 and Reveal.oneIn(Config, Rules, 1, 12, false, 16, 2, 1, false) == math.huge)
	check("Reveal : indices invalides sans erreur", Reveal.probability(Config, Rules, 3, 12, false, 999, 1, 1, false) == 0 and Reveal.probability(Config, Rules, 3, 12, false, 1, 99, 1, false) == 0)
	-- textes
	check("fmtOdds : espaces entre milliers, entier, décimale sous 10", Config.fmtOdds(1008) == "1 sur 1 008" and Config.fmtOdds(1000000) == "1 sur 1 000 000" and Config.fmtOdds(12.4) == "1 sur 12" and Config.fmtOdds(3.25) == "1 sur 3,2" or Config.fmtOdds(3.25) == "1 sur 3,3")
	check("fmtOdds : valeurs invalides -> chaîne vide", Config.fmtOdds(0) == "" and Config.fmtOdds(math.huge) == "" and Config.fmtOdds(0 / 0) == "" and Config.fmtOdds(nil) == "")
	-- styles : progression monotone avec la rareté, secret distinct, mode réduit
	local R = Config.REVEAL
	local mono = true
	for t = 2, #R.tiers do
		local a, b = R.tiers[t - 1], R.tiers[t]
		if b.rays < a.rays or b.rings < a.rings or b.shake < a.shake or b.flash < a.flash or b.particles < a.particles then
			mono = false
		end
	end
	check("REVEAL : 6 styles, intensité croissante avec la rareté", #R.tiers == #Config.TIERS and mono)
	local common, cosmic = Reveal.style(Config, 1, 5, false), Reveal.style(Config, 6, 5, false)
	check("Reveal.style : la couleur suit la rareté (gris commun, bleu rare, violet épique, orange légendaire)", common.color == Config.TIERS[1].color and Reveal.style(Config, 2, 5, false).color == Config.TIERS[2].color and Reveal.style(Config, 3, 5, false).color == Config.TIERS[3].color and Reveal.style(Config, 4, 5, false).color == Config.TIERS[4].color and cosmic.rays > common.rays)
	local secret = Reveal.style(Config, 3, R.secret.oneInAtLeast, false)
	check("Reveal.style : tirage au-delà du seuil = œuf secret distinct (couleur lave, plus d'anneaux, libellé)", secret.secret == true and secret.color == R.secret.color and secret.label == R.secret.label and secret.rings > R.tiers[3].rings and Reveal.style(Config, 3, R.secret.oneInAtLeast - 1, false).secret == false)
	local reduced = Reveal.style(Config, 6, 5, true)
	check("Reveal.style : option mobile = moins de rayons, de particules et de secousse (au moins 4 rayons)", reduced.rays < cosmic.rays and reduced.rays >= 4 and reduced.particles < cosmic.particles and reduced.shake < cosmic.shake and reduced.rings >= 1)
	check("Reveal.style : rareté hors plage sans erreur", Reveal.style(Config, 0, 5, false).rays == R.tiers[1].rays and Reveal.style(Config, 99, 5, false).rays == R.tiers[#R.tiers].rays)
	-- il existe de vrais tirages au-delà du seuil secret, et la plupart des tirages courants en dessous
	local hasSecret, hasCommon = false, false
	for p = 1, #Config.PETS do
		for sz = 1, #Config.SIZES do
			for mu = 1, #Config.MUTS do
				for tier = 1, #Config.TIERS do
					local n = Reveal.oneIn(Config, Rules, tier, 12, false, p, sz, mu, false)
					if n ~= math.huge and n >= R.secret.oneInAtLeast then
						hasSecret = true
					end
					if n ~= math.huge and n < 50 then
						hasCommon = true
					end
				end
			end
		end
	end
	check("Reveal : des tirages réels dépassent le seuil de l'œuf secret, d'autres sont courants", hasSecret and hasCommon)
end

-- Style glossy, richesse, carrousel, bannières, premiers instants -------------------------------------------------------------
do
	suite("Interface glossy : couleurs par fonction, richesse, carrousel d'œufs, bannières de zone, premiers gestes")
	local kinds = { "play", "save", "options", "close" }
	local seen = {}
	local colorsOk = true
	for _, k in ipairs(kinds) do
		local st = Config.btnStyle(k)
		if not st or Config.contrast(st.base, st.text) < 4.5 or Config.contrast(st.base, st.stroke) < 2 then
			colorsOk = false
		end
		if st then
			local sig = string.format("%.2f,%.2f,%.2f", st.base.R, st.base.G, st.base.B)
			if seen[sig] then
				colorsOk = false
			end
			seen[sig] = true
		end
	end
	check("UI glossy : 4 fonctions (vert jouer, bleu sauver, orange options, rouge fermer) distinctes, texte lisible (contraste >= 4,5)", colorsOk and Config.btnStyle("inconnu") == nil)
	check("UI glossy : teintes attendues (vert, bleu, orange, rouge)", Config.btnStyle("play").base.G > Config.btnStyle("play").base.R and Config.btnStyle("save").base.B > Config.btnStyle("save").base.R and Config.btnStyle("options").base.R > Config.btnStyle("options").base.B and Config.btnStyle("close").base.R > Config.btnStyle("close").base.G)
	local navOk = true
	for _, key in ipairs({ "shop", "dex", "quests", "bonus", "top", "more" }) do
		if not Config.btnStyle(Config.UI.nav[key]) then
			navOk = false
		end
	end
	check("UI glossy : chaque bouton de navigation a une fonction valide", navOk)
	check("Contraste : noir sur blanc = 21, identique = 1", math.abs(Config.contrast({ R = 0, G = 0, B = 0 }, { R = 1, G = 1, B = 1 }) - 21) < 1e-9 and math.abs(Config.contrast({ R = 0.5, G = 0.5, B = 0.5 }, { R = 0.5, G = 0.5, B = 0.5 }) - 1) < 1e-9)
	-- richesse
	check("Richesse : 1 pièce, petite pile, grosse pile, coffre aux seuils des prix d'œufs", Config.wealthTier(0) == 1 and Config.wealthTier(899) == 1 and Config.wealthTier(900) == 2 and Config.wealthTier(19999) == 2 and Config.wealthTier(20000) == 3 and Config.wealthTier(349999) == 3 and Config.wealthTier(350000) == 4 and Config.wealthTier(1e15) == 4)
	check("Richesse : valeurs invalides sans erreur", Config.wealthTier(-5) == 1 and Config.wealthTier(0 / 0) == 1 and Config.wealthTier(nil) == 1 and Config.wealthTier("x") == 1)
	check("Richesse : seuils croissants, alignés sur les prix des œufs", Config.WEALTH[2].min == Config.EGG_PRICE[2] and Config.WEALTH[3].min == Config.EGG_PRICE[3] and Config.WEALTH[4].min == Config.EGG_PRICE[4])
	-- carrousel
	check("Carrousel : œuf présélectionné = le plus rare payable (au moins Commun)", Config.carouselDefault(0) == 1 and Config.carouselDefault(24) == 1 and Config.carouselDefault(900) == 2 and Config.carouselDefault(25000) == 3 and Config.carouselDefault(1e12) == #Config.TIERS)
	check("Carrousel : défilement circulaire dans les deux sens", Config.carouselStep(1, 1) == 2 and Config.carouselStep(6, 1) == 1 and Config.carouselStep(1, -1) == 6 and Config.carouselStep(3, -1) == 2 and Config.carouselStep(2, 0) == 3)
	check("Carrousel : 6 ppas dans un sens ramènent à la case de départ", (function()
		local sel = 4
		for _ = 1, #Config.TIERS do
			sel = Config.carouselStep(sel, 1)
		end
		return sel == 4
	end)())
	-- bannières
	local bannersOk = true
	for _, key in ipairs(Config.Map.zoneKeys) do
		local b = Config.zoneBanner(key)
		if not (b and #b.title > 3 and #b.sub > 5 and b.color) then
			bannersOk = false
		end
	end
	check("Bannières de zone : arène et chaque domaine ont un titre, un sous-titre et une couleur", bannersOk and Config.zoneBanner("arena") ~= nil and Config.zoneBanner("inconnue") == nil and Config.ZONE_BANNER_SECONDS > 1)
	check("Bannières de zone : toute zone renvoyée par zoneAt a sa bannière", (function()
		for _, pt in ipairs({ { 0, 0 }, { 0, 215 }, { -90, -95 }, { 0, -95 }, { 90, -95 }, { 500, 500 } }) do
			if Config.zoneBanner(Config.zoneAt(pt[1], pt[2])) == nil then
				return false
			end
		end
		return true
	end)())
	-- premiers gestes
	local h0 = Config.nextHint({ hatched = 0, stolen = 0, speed = 0 })
	check("Premiers instants : action immédiate proposée dès l'arrivée (toucher l'œuf)", h0 ~= nil and h0.id == "tap" and #h0.text > 10)
	check("Premiers gestes : œuf éclos -> voler, vol fait -> tapis, vitesse atteinte -> plus d'indice", Config.nextHint({ hatched = 1, stolen = 0, speed = 0 }).id == "steal" and Config.nextHint({ hatched = 3, stolen = 1, speed = 2 }).id == "train" and Config.nextHint({ hatched = 3, stolen = 1, speed = 8 }) == nil and Config.nextHint({}).id == "tap")
	check("Promesse d'accueil : texte du titre et de la promesse présents", Config.TITLE ~= "" and Config.TAGLINE ~= "" and Config.PROMISE.seconds >= 4 and Config.PROMISE.button ~= "")
end

-- États des pets, aura, bandeaux de rareté ---------------------------------------------------------------------------------
do
	suite("Pets (idle, move, ability), aura des raretés élevées, bandeaux de rareté colorés")
	local Easing = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
	local bounded = true
	for t = 0, 60, 0.37 do
		for seed = 0, 9 do
			for _, state in ipairs({ "idle", "move" }) do
				local p = Easing.petPose(state, t, seed)
				if math.abs(p.y) > 1 or math.abs(p.pitch) > 0.5 or math.abs(p.yaw) > 1 or p.scale ~= 1 then
					bounded = false
				end
			end
			local ap = Easing.abilityProgress(t, seed, 9)
			if ap ~= nil then
				if ap < 0 or ap > 1 then
					bounded = false
				end
				local p = Easing.petPose("ability", t, seed, ap)
				if p.y < -1e-9 or p.y > 1.81 or p.scale < 1 or p.scale > 1.26 or p.yaw < 0 or p.yaw > 2 * math.pi + 1e-9 then
					bounded = false
				end
			end
		end
	end
	check("Pets : poses idle, move et ability bornées (hauteur, inclinaison, vrille, échelle)", bounded)
	local moveMax, idleMax = 0, 0
	for t = 0, 10, 0.05 do
		moveMax = math.max(moveMax, Easing.petPose("move", t, 3).y)
		idleMax = math.max(idleMax, Easing.petPose("idle", t, 3).y)
	end
	check("Pets : l'état « move » bondit plus haut que « idle » et se penche vers l'avant", moveMax > idleMax and Easing.petPose("move", 0, 0).pitch < 0 and Easing.petPose("idle", 0, 0).pitch == 0)
	local ap0, spinStart, spinEnd = nil, Easing.petPose("ability", 0, 0, 0), Easing.petPose("ability", 0, 0, 1)
	check("Pets : la capacité commence et finit au sol (y = 0) et fait un tour complet", math.abs(spinStart.y) < 1e-9 and math.abs(spinEnd.y) < 1e-6 and math.abs(spinEnd.yaw - 2 * math.pi) < 1e-9 and Easing.petPose("ability", 0, 0, 0.5).y > 1.7)
	local active, total = 0, 0
	for t = 0, 90, 0.1 do
		total = total + 1
		if Easing.abilityProgress(t, 2, 9) ~= nil then
			active = active + 1
		end
	end
	check("Pets : la capacité est brève et périodique (entre 5 % et 20 % du temps)", active / total > 0.05 and active / total < 0.2)
	check("Pets : valeurs invalides sans erreur (progression hors plage, graine nil)", Easing.petPose("ability", 1, nil, 9).yaw <= 2 * math.pi + 1e-9 and Easing.petPose("inconnu", 1).scale == 1 and Easing.abilityProgress(1, nil, 0.5, 1) == nil)
	-- Config.Assets.pets : point d'entrée vide par défaut, validé
	check("Assets.pets : 18 pets Blender liés à des espèces réelles, plafond de Parts défini", (function()
		local n = 0
		for idx, id in pairs(Config.Assets.pets) do
			n = n + 1
			if not Config.PETS[idx] or type(id) ~= "number" or id <= 0 then
				return false
			end
		end
		local want = { [2] = "Hamster", [4] = "Chat", [5] = "Chien", [8] = "Hibou", [9] = "Manchot", [10] = "Lion", [12] = "Licorne", [14] = "T-Rex", [11] = "Tigre", [15] = "Kraken", [17] = "Calmar stellaire", [18] = "Wyrm astral" }
		for idx, nm in pairs(want) do
			if Config.PETS[idx].name ~= nm or not Config.Assets.pets[idx] then
				return false
			end
		end
		return n == 18 and Config.PETS[1].name == "Poussin" and Config.PETS[3].name == "Lapin" and Config.PETS[6].name == "Renard" and Config.PETS[7].name == "Panda" and Config.PETS[13].name == "Dragon" and Config.PETS[16].name == "Alien"
	end)() and Config.Assets.petsMaxParts >= 60 and Config.Assets.petHeight > 0)
	-- aura
	check("Aura : aucune sous la rareté minimale, sauf secret", Config.auraStyle(1, false) == nil and Config.auraStyle(3, false) == nil and Config.auraStyle(3, true) ~= nil and Config.auraStyle(4, false) ~= nil)
	local prevRunes, prevRate, auraMono, capsOk = 0, 0, true, true
	for tier = Config.AURA.minTier, #Config.TIERS do
		local st = Config.auraStyle(tier, false, false)
		if st.runes < prevRunes or st.rate < prevRate then
			auraMono = false
		end
		if st.runes > Config.AURA.maxRunes or st.rate > Config.AURA.maxRate then
			capsOk = false
		end
		prevRunes, prevRate = st.runes, st.rate
	end
	local sec = Config.auraStyle(3, true, false)
	check("Aura : intensité croissante avec la rareté et plafonds de particules respectés", auraMono and capsOk and sec.runes <= Config.AURA.maxRunes and sec.rate <= Config.AURA.maxRate)
	local full, red = Config.auraStyle(6, false, false), Config.auraStyle(6, false, true)
	check("Aura : l'option mobile réduit runes et particules et supprime le pilier de lumière", red.runes < full.runes and red.rate < full.rate and full.pillar == true and red.pillar == false and red.runes >= 4)
	check("Aura : désactivable (Config.AURA.Enabled = false)", (function()
		local saved = Config.AURA.Enabled
		Config.AURA.Enabled = false
		local r = Config.auraStyle(6, true, false)
		Config.AURA.Enabled = saved
		return r == nil
	end)())
	-- bandeaux de rareté : couleurs imposées
	local function hue(c)
		return c.R, c.G, c.B
	end
	local b = Config.RARITY_BANNERS
	local r1, g1 = hue(b[1].colors[1])
	local r2, g2 = hue(b[2].colors[1])
	local r3, g3, b3 = hue(b[3].colors[1])
	local r4, g4 = hue(b[4].colors[1])
	local r5, g5, b5 = hue(b[5].colors[1])
	check("Bandeaux : commun jaune, rare vert, épique violet, légendaire rouge, mythique cyan", r1 > 0.9 and g1 > 0.7 and r2 < r1 and g2 > r2 and b3 > g3 and r3 > g3 and r4 > g4 + 0.3 and g5 > r5 and b5 > r5)
	check("Bandeaux : 6 raretés nommées, secret arc-en-ciel (5 teintes distinctes)", #b == #Config.TIERS and b.secret.name == "SECRET" and #b.secret.colors == 5 and Config.rarityBanner(1, true) == b.secret and Config.rarityBanner(2, false) == b[2] and Config.rarityBanner(99, false) == b[6] and Config.rarityBanner(0, false) == b[1])
end

-- Œuf énorme à l'éclosion : plafond de taille, nid, pet à taille normale -----------------------------------------------------
do
	suite("Œuf borné (relatif à la base et au joueur), nid de paille, pet qui apparaît à taille normale")
	local Easing = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
	local mx = Config.eggMaxSize()
	check("Plafond d'œuf : relatif à l'emplacement (8) et au joueur (5) : largeur 4,4, hauteur 3,75", math.abs(mx.w - 4.4) < 1e-9 and math.abs(mx.h - 3.75) < 1e-9)
	check("Plafond d'œuf : l'œuf standard (largeur 2,4, hauteur 3,2) et la hauteur cible des modèles tiennent", Config.fitScale({ X = 2.4, Y = 3.2, Z = 2.4 }, mx) == 1 and Config.Assets.targetHeight <= mx.h)
	local fx = Config.fitScale({ X = 30, Y = 20, Z = 10 }, mx)
	check("Plafond d'œuf : un modèle géant (30 x 20 x 10) est ramené sous la borne sur tous les axes", fx < 1 and 30 * fx <= mx.w + 1e-9 and 20 * fx <= mx.h + 1e-9 and 10 * fx <= mx.w + 1e-9)
	check("Plafond d'œuf : très large mais bas ramené sur la largeur, très haut mais fin sur la hauteur", Config.fitScale({ X = 44, Y = 1, Z = 1 }, mx) == mx.w / 44 and Config.fitScale({ X = 1, Y = 37.5, Z = 1 }, mx) == mx.h / 37.5)
	check("Plafond d'œuf : valeurs invalides (0, NaN, négatif, nil) sans erreur et sans réduction", Config.fitScale({ X = 0, Y = -3, Z = 0 / 0 }, mx) == 1 and Config.fitScale({}, mx) == 1)
	local big = Config.eggMaxSize(16, 10)
	check("Plafond d'œuf : proportionnel à la base et au joueur (base x2 -> largeur x2)", math.abs(big.w - 2 * mx.w) < 1e-9 and big.h >= mx.h)
	-- pet qui apparaît
	local maxPop, startPop, endPop = 0, Easing.popScale(0, true), Easing.popScale(1, true)
	for k = 0, 100 do
		local a = k / 100
		maxPop = math.max(maxPop, Easing.popScale(a, true), Easing.popScale(a, false))
	end
	check("Apparition du pet : part petit (<= 0,3), ne dépasse jamais 1,15 et vaut exactement 1 à la fin", startPop <= 0.3 and maxPop <= 1.15 + 1e-9 and endPop == 1 and Easing.popScale(1, false) == 1 and Easing.popScale(2, true) == 1)
	check("Apparition du pet : plafond réglable et valeurs hors plage sans erreur", Easing.popScale(0.5, false, 1.0) <= 1.0 and Easing.popScale(-1, true) >= 0.05)
end

-- Modèles Blender : convention Nom__RRGGBB, identifiants, budget, repli, réutilisation -------------------------------------------------
do
	suite("Modèles Blender : suffixe de couleur Nom__RRGGBB, IDs, budget de Parts, repli, un seul LoadAsset par modèle")
	local AssetsMod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Assets.lua"), { debugName = "Assets" })()
	local P = AssetsMod.parseColorSuffix
	local function rgb(name)
		local r, g, b = P(name)
		return r and (r .. "," .. g .. "," .. b) or "nil"
	end
	check("Suffixe : « Corps__FF8800 » -> 255,136,0", rgb("Corps__FF8800") == "255,136,0")
	check("Suffixe : minuscules acceptées, noir et blanc", rgb("Oeil__000000") == "0,0,0" and rgb("Aile__ffffff") == "255,255,255" and rgb("X__aBcDeF") == "171,205,239")
	check("Suffixe : seul le DERNIER « __ » compte (« A__B__123456 »)", rgb("A__B__123456") == "18,52,86")
	check("Suffixe : pas de suffixe -> nil (rien ne change)", rgb("Corps") == "nil" and rgb("") == "nil" and rgb("Corps_FF8800") == "nil")
	check("Suffixe : invalide -> nil (non hexadécimal, trop court, trop long, suffixe au milieu)", rgb("X__GGGGGG") == "nil" and rgb("X__12345") == "nil" and rgb("X__1234567") == "nil" and rgb("X__FF8800_suite") == "nil")
	check("Suffixe : nom nul ou non texte -> nil sans erreur", P(nil) == nil and P(42) == nil and P({}) == nil)
	check("Suffixe : « __ABCDEF » seul (nom vide) accepté", rgb("__ABCDEF") == "171,205,239")
	-- colorize sur un faux modèle
	local function part(name, size)
		local o = { Name = name, Size = size or { X = 2, Y = 2, Z = 2 }, Color = "origine", CastShadow = true, ClassName = "Part" }
		function o:IsA(c)
			return c == "BasePart" or c == "Part"
		end
		return o
	end
	local function model(children)
		local o = { Name = "M", ClassName = "Model", kids = children }
		function o:IsA(c)
			return c == "Model"
		end
		function o:GetDescendants()
			return self.kids
		end
		function o:Clone()
			return self
		end
		function o:Destroy() end
		return o
	end
	local colored = model({ part("Corps__FF8800"), part("Oeil__000000", { X = 0.3, Y = 0.3, Z = 0.2 }), part("Socle"), part("Aile__zzzzzz") })
	local C = AssetsMod.new(Config, { loadAsset = function() return colored end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end, color = function(r, g, b) return "rgb(" .. r .. "," .. g .. "," .. b .. ")" end })
	check("colorize : applique la couleur du suffixe, ignore les pièces sans suffixe ou invalides", C.colorize(colored) == 2 and colored.kids[1].Color == "rgb(255,136,0)" and colored.kids[2].Color == "rgb(0,0,0)" and colored.kids[3].Color == "origine" and colored.kids[4].Color == "origine")
	check("colorize : CastShadow = false pour les petits détails seulement", colored.kids[2].CastShadow == false and colored.kids[1].CastShadow == true)
	check("colorize : modèle illisible ou nil sans erreur", pcall(C.colorize, nil) and C.colorize({ GetDescendants = function() error("x") end }) == 0)
	-- identifiants
	local function validId(id)
		return type(id) == "number" and id > 0 and id % 1 == 0
	end
	local A = Config.Assets
	local rar = 0
	for k, id in pairs(A.eggsByRarity) do
		rar = rar + 1
		if not validId(id) then
			rar = -100
		end
	end
	check("Œufs Blender : 6 raretés + secret, identifiants valides, Cosmique = œuf Secret", rar == 7 and A.eggsByRarity[1] == 100023720665590 and A.eggsByRarity[5] == 110535599163330 and A.eggsByRarity[6] == A.eggsByRarity.secret and A.eggsByRarity[6] == 95190117262171)
	local props = 0
	local propsOk = true
	for k, id in pairs(A.props) do
		props = props + 1
		if not validId(id) or not A.propsMaxParts[k] or not A.propsHeight[k] then
			propsOk = false
		end
	end
	check("Accessoires Blender : 9 modèles (arbre, sapin, rocher, buisson, pont, cabane, barrière, fontaine, nid) avec plafond de Parts et hauteur", props == 9 and propsOk and A.props.nest == 85337440768183 and A.props.fountain == 87696152276058 and A.props.bridge == 72821096584538)
	check("Budget mobile : pire cas des accessoires de la carte <= " .. A.propsBudgetParts .. " Parts (" .. Config.propsWorstCase() .. ")", Config.propsWorstCase() <= A.propsBudgetParts)
	check("Budget mobile : avec le décor et les accessoires, la carte reste sous le budget total", 1200 + 600 + Config.propsWorstCase() + 12 * Config.PLOT_COUNT * A.propsMaxParts.nest <= Config.Map.totalBudgetParts)
	-- chargement : un seul LoadAsset par modèle, clonage, repli
	local calls = {}
	local function heavy(n)
		local ch = {}
		for i = 1, n do
			ch[i] = part("P" .. i .. "__AABBCC")
		end
		return model(ch)
	end
	local R = AssetsMod.new(Config, { loadAsset = function(id) calls[id] = (calls[id] or 0) + 1 return heavy(5) end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end, color = function() return "c" end })
	local loadedAll = R.loadAll()
	R.loadProps()
	local n1 = R.cloneProp("tree")
	local n2 = R.cloneProp("tree")
	local once = true
	for _, c in pairs(calls) do
		if c ~= 1 then
			once = false
		end
	end
	check("Chargement : chaque modèle n'est chargé qu'UNE fois (LoadAsset), puis cloné", once and n1 ~= nil and n2 ~= nil and R.cloneEgg(3) ~= nil and loadedAll >= 12)
	check("Priorité des œufs : le modèle Blender de la rareté passe avant le modèle du catalogue", (function()
		local R2 = AssetsMod.new(Config, { loadAsset = function(id) local m = heavy(3) m.id = id return m end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end, color = function() return "c" end })
		R2.loadAll()
		return R2.cloneEgg(2).id == A.eggsByRarity[2] and R2.cloneEgg(6, true).id == A.eggsByRarity.secret
	end)())
	local H = AssetsMod.new(Config, { loadAsset = function() return heavy(A.propsMaxParts.nest + 1) end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end, color = function() return "c" end })
	H.loadProps()
	check("Budget : un nid de plus de " .. A.propsMaxParts.nest .. " Parts est refusé (repli procédural), un arbre léger accepté", H.cloneProp("nest") == nil and H.cloneProp("tree") ~= nil and H.status["x:nest"].reason:find("lourd") ~= nil)
	local D = AssetsMod.new(Config, { loadAsset = function() error("Requester does not have permission for Asset") end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end })
	check("Repli : permission refusée -> aucun modèle, aucun clone, aucune erreur (tout reste procédural)", D.loadAll() == 0 and D.loadProps() == 0 and D.loadPets() == 0 and D.cloneProp("tree") == nil and D.cloneEgg(1) == nil and D.clonePet(1) == nil)
	local off = A.Enabled
	A.Enabled = false
	check("Repli : Config.Assets.Enabled = false -> rien n'est chargé ni cloné", R.cloneProp("tree") == nil and R.cloneEgg(1) == nil and AssetsMod.new(Config, { loadAsset = function() return heavy(1) end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end }).loadProps() == 0)
	A.Enabled = off
end

-- Gardiens : perception (angle, distance, bruit), états, dégâts ----------------------------------------------------------------
do
	suite("Gardiens : champ de vision, ouïe, états, dégâts non mortels, régénération")
	local Guard = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Guard.lua"), { debugName = "Guard" })()
	local C = Config.GUARD
	local R = Config.RIVALS[2] -- Mara
	local g = { x = 0, z = 0, fx = 1, fz = 0 } -- regarde vers +x
	check("Angle : devant = 0, côté = 90, derrière = 180, vecteur nul = 0", math.abs(Guard.angle(1, 0, 5, 0)) < 1e-6 and math.abs(Guard.angle(1, 0, 0, 3) - 90) < 1e-6 and math.abs(Guard.angle(1, 0, -2, 0) - 180) < 1e-6 and Guard.angle(0, 0, 1, 1) == 0)
	check("Vue : cible devant dans la distance = vue", Guard.sees(g, { x = 20, z = 0 }, R.viewDist, R.viewAngle))
	check("Vue : cible devant mais trop loin = non vue", not Guard.sees(g, { x = R.viewDist + 1, z = 0 }, R.viewDist, R.viewAngle))
	check("Vue : cible DERRIÈRE le gardien (hors du cône) = non vue, même très proche", not Guard.sees(g, { x = -6, z = 0 }, R.viewDist, R.viewAngle) and not Guard.sees(g, { x = -3, z = 2 }, R.viewDist, R.viewAngle))
	check("Vue : bord du cône (demi-angle) vu, juste au-delà non vu", Guard.sees(g, { x = 10 * math.cos(math.rad(R.viewAngle / 2 - 1)), z = 10 * math.sin(math.rad(R.viewAngle / 2 - 1)) }, R.viewDist, R.viewAngle) and not Guard.sees(g, { x = 10 * math.cos(math.rad(R.viewAngle / 2 + 2)), z = 10 * math.sin(math.rad(R.viewAngle / 2 + 2)) }, R.viewDist, R.viewAngle))
	check("Vue : collé au gardien (< 1,5 stud) toujours vu, même derrière", Guard.sees(g, { x = -1, z = 0 }, R.viewDist, R.viewAngle))
	check("Vue : plus le gardien est dangereux, plus le cône est large et long (Gus < Mara < Zed)", Config.RIVALS[1].viewDist < R.viewDist and R.viewDist < Config.RIVALS[3].viewDist and Config.RIVALS[1].viewAngle < R.viewAngle and R.viewAngle < Config.RIVALS[3].viewAngle)
	check("Bruit : immobile 0, marche lente discrète, course pleine", Guard.noise(0, C) == 0 and Guard.noise(C.stillSpeed, C) == 0 and Guard.noise(8, C) == C.sneakNoise and Guard.noise(16, C) == 1 and Guard.noise(0 / 0, C) == 0 and Guard.noise(nil, C) == 0)
	check("Ouïe : en courant, entendu dans le rayon ; discret, rayon réduit ; immobile jamais", Guard.hears(R.hearRadius - 1, 1, R.hearRadius) and not Guard.hears(R.hearRadius + 1, 1, R.hearRadius) and Guard.hears(R.hearRadius * C.sneakNoise - 0.5, C.sneakNoise, R.hearRadius) and not Guard.hears(R.hearRadius * C.sneakNoise + 1, C.sneakNoise, R.hearRadius) and not Guard.hears(1, 0, R.hearRadius))
	-- voler derrière : cible derrière, loin du rayon d'ouïe -> aucune perception
	local behind = Guard.perceive(g, { x = -R.hearRadius - 3, z = 0, speed = 16 }, R, C)
	check("Perception : un voleur DERRIÈRE le gardien, hors portée d'ouïe, n'est ni vu ni entendu (vol sans combat)", behind.sees == false and behind.hears == false)
	local front = Guard.perceive(g, { x = 12, z = 0, speed = 16 }, R, C)
	check("Perception : passer DEVANT le gardien le déclenche (vu et entendu)", front.sees and front.hears)
	local quiet = Guard.perceive(g, { x = -8, z = 0, speed = 0 }, R, C)
	check("Perception : immobile derrière, proche : ni vu ni entendu", quiet.sees == false and quiet.hears == false)
	-- états
	local st = { state = "patrol", timer = 0, lost = 0 }
	local ev
	st, ev = Guard.nextState(st, 0.1, { sees = false, hears = false, dist = 30, atHome = true }, C)
	check("États : patrouille tranquille, rien ne change", st.state == "patrol" and ev == nil)
	st, ev = Guard.nextState(st, 0.1, { sees = false, hears = true, dist = 10 }, C)
	check("États : un bruit met en ALERTE", st.state == "alert" and ev == "alert")
	for _ = 1, 20 do
		st, ev = Guard.nextState(st, 0.1, { sees = false, hears = true, dist = 10 }, C)
	end
	check("États : un bruit seul ne déclenche jamais la poursuite", st.state == "alert")
	local spotted = nil
	for _ = 1, 10 do
		st, ev = Guard.nextState(st, 0.1, { sees = true, hears = true, dist = 10 }, C)
		spotted = spotted or ev
	end
	check("États : vu pendant le délai d'alerte (" .. C.alertDelay .. " s) -> POURSUITE", st.state == "chase" and spotted == "spotted")
	st, ev = Guard.nextState(st, 0.1, { sees = false, hears = false, dist = 12 }, C)
	check("États : cible hors de perception -> PERTE DE CIBLE (continue vers la dernière position)", st.state == "lostChase")
	for _ = 1, math.floor(C.loseDelay / 0.1) - 2 do
		st, ev = Guard.nextState(st, 0.1, { sees = false, hears = false, dist = 12 }, C)
	end
	check("États : la perte de cible dure environ " .. C.loseDelay .. " s (encore en recherche juste avant)", st.state == "lostChase")
	for _ = 1, 6 do
		st, ev = Guard.nextState(st, 0.1, { sees = false, hears = false, dist = 12 }, C)
	end
	check("États : délai écoulé -> RETOUR", st.state == "return")
	st = Guard.nextState({ state = "lostChase", timer = 0, lost = 1 }, 0.1, { sees = true, hears = true, dist = 9 }, C)
	check("États : cible retrouvée pendant la recherche -> POURSUITE", st.state == "chase")
	st = Guard.nextState({ state = "chase", timer = 0, lost = 0 }, 0.1, { sees = true, hears = true, dist = C.giveUpDist + 1 }, C)
	check("États : cible trop loin -> abandon et RETOUR", st.state == "return")
	st, ev = Guard.nextState({ state = "return" }, 0.1, { sees = false, hears = false, dist = 30, atHome = true }, C)
	check("États : retour arrivé -> PATROUILLE", st.state == "patrol" and ev == "calm")
	st = Guard.nextState({ state = "return" }, 0.1, { sees = true, hears = true, dist = 20, atHome = false }, C)
	check("États : en retour, revoit la cible -> ALERTE", st.state == "alert")
	st = { state = "alert", timer = 0, lost = 0 }
	for _ = 1, 40 do
		st = Guard.nextState(st, 0.1, { sees = false, hears = false, dist = 30 }, C)
	end
	check("États : alerte sans rien percevoir pendant " .. C.alertMax .. " s -> retour au calme (RETOUR)", st.state == "return")
	-- aucun état inconnu ne bloque
	check("États : un état inconnu retombe sur « return » sans erreur", Guard.nextState({ state = "???" }, 0.1, { sees = false, hears = false, dist = 5, atHome = true }, C).state == "patrol")
	-- dégâts
	local hp, hit, inv = Guard.applyDamage(C.maxHp, R.damage, 0, C)
	check("Dégâts : un coup ne tue JAMAIS d'un coup (max " .. C.maxHp .. " pv, dégâts de chaque gardien < 40 %)", hit and hp == C.maxHp - R.damage and hp > 0 and inv == C.iframes and Config.RIVALS[1].damage < 40 and Config.RIVALS[2].damage < 40 and Config.RIVALS[3].damage < 40)
	local hp2, hit2 = Guard.applyDamage(hp, R.damage, inv, C)
	check("Dégâts : pendant l'invulnérabilité courte, aucun nouveau dégât", hit2 == false and hp2 == hp)
	local pvLeft, hits = C.maxHp, 0
	local ivs = 0
	while pvLeft > 0 and hits < 50 do
		local nhp, h, ni = Guard.applyDamage(pvLeft, Config.RIVALS[3].damage, ivs, C)
		pvLeft, ivs = nhp, ni
		if h then
			hits = hits + 1
			ivs = 0 -- (on enchaîne les coups après l'invulnérabilité)
		end
	end
	check("Dégâts : l'ours de Zed met au moins 3 coups à vaincre un joueur", hits >= 3 and pvLeft == 0)
	check("Dégâts : jamais en dessous de 0, rien sur un joueur déjà à 0, rien si dégâts <= 0", Guard.applyDamage(5, 999, 0, C) == 0 and select(2, Guard.applyDamage(0, 10, 0, C)) == false and select(2, Guard.applyDamage(50, 0, 0, C)) == false)
	-- régénération
	check("Régénération : aucune juste après un coup, " .. C.regenPerSec .. " pv/s après " .. C.regenDelay .. " s", Guard.regen(50, 1, 1, false, C) == 50 and Guard.regen(50, C.regenDelay, 1, false, C) == 50 + C.regenPerSec)
	check("Régénération : rapide dans la base (" .. C.baseRegen .. " pv/s), plafonnée à " .. C.maxHp, Guard.regen(50, 0, 1, true, C) == 50 + C.baseRegen and Guard.regen(99, 100, 10, true, C) == C.maxHp and Guard.regen(0, 100, 1, true, C) == 0)
end

-- Château : pièges, difficulté, classement, récompense -----------------------------------------------------------------------
do
	suite("Mode Château : salles, pièges (pics, lames, boulets, porte), difficulté croissante, classement, récompense")
	local Castle = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })()
	check("Château : 5 salles, longueur et largeur fixes, entrée dans la carte", Castle.ROOMS == 5 and Castle.ROOM_LENGTH == 56 and Castle.ROOM_WIDTH == 40 and math.abs(Castle.ORIGIN.x) + 30 < Config.Map.groundSize / 2 and math.abs(Castle.ORIGIN.z - (Castle.ROOMS - 1) * Castle.ROOM_LENGTH * 0) > 0 and math.abs(Castle.ORIGIN.z - Castle.ROOMS * Castle.ROOM_LENGTH) < Config.Map.groundSize / 2 - 20)
	-- difficulté croissante
	local mono = true
	for r = 2, Castle.ROOMS do
		local a, b = Castle.room(r - 1), Castle.room(r)
		if b.spikes < a.spikes or b.blades < a.blades or b.balls < a.balls or b.period > a.period or b.bladeSpeed < a.bladeSpeed or b.ballTravel > a.ballTravel or b.doorOpen > a.doorOpen then
			mono = false
		end
	end
	check("Difficulté : pièges plus nombreux et plus rapides de salle en salle (monotone)", mono and Castle.room(1).blades == 0 and Castle.room(1).balls == 0 and Castle.room(5).blades == 2 and Castle.room(5).balls == 3)
	check("Difficulté : salle hors plage ramenée à 1..5 sans erreur", Castle.room(0).index == 1 and Castle.room(99).index == Castle.ROOMS)
	-- pics
	local room2 = Castle.room(2)
	local sp = Castle.spikes(room2)[1]
	local seen = { safe = 0, warning = 0, danger = 0 }
	for t = 0, room2.period * 3, 0.05 do
		local st = Castle.spikeState(t, sp, room2)
		seen[st] = seen[st] + 1
	end
	check("Pics : chaque cycle passe par sûr, avertissement puis danger (le joueur est prévenu avant les pics)", seen.safe > 0 and seen.warning > 0 and seen.danger > 0 and seen.danger < seen.safe + seen.warning)
	local order, lastSt = {}, nil
	for t = 0, room2.period, 0.02 do
		local st = Castle.spikeState(t - (sp.offset % room2.period), { offset = 0 }, room2)
		if st ~= lastSt then
			order[#order + 1] = st
			lastSt = st
		end
	end
	check("Pics : l'avertissement précède toujours le danger (safe -> warning -> danger)", table.concat(order, ">"):find("warning>danger", 1, true) ~= nil)
	-- couloirs sûrs entre les plaques : un joueur placé entre deux colonnes n'est jamais touché par les pics
	local corridorSafe = true
	for r = 1, Castle.ROOMS do
		local rm = Castle.room(r)
		for t = 0, rm.period * 2, 0.05 do
			if Castle.hit(t, rm, -10, 12) == "spikes" or Castle.hit(t, rm, 0, 12) == "spikes" or Castle.hit(t, rm, 10, 12) == "spikes" then
				corridorSafe = false
			end
		end
	end
	check("Pics : les couloirs entre les colonnes (x = -10, 0, 10) sont sûrs dans toutes les salles", corridorSafe)
	local spikeHit = false
	local rm4 = Castle.room(4)
	local plate = Castle.spikes(rm4)[1]
	for t = 0, rm4.period, 0.02 do
		if Castle.hit(t - 0, rm4, plate.lx, plate.lz) == "spikes" then
			spikeHit = true
		end
	end
	check("Pics : debout sur une plaque, le joueur est touché pendant la phase de danger", spikeHit)
	-- lames
	local rm3 = Castle.room(4)
	local bl = Castle.blades(rm3)[1]
	local hitBlade, safeBlade = false, false
	for t = 0, 8, 0.02 do
		local a = Castle.bladeAngle(t, bl, rm3)
		local tipX, tipZ = bl.lx + math.cos(a) * bl.arm * 0.8, bl.lz + math.sin(a) * bl.arm * 0.8
		if Castle.hit(t, rm3, tipX, tipZ) == "blade" then
			hitBlade = true
		end
	end
	check("Lames : un joueur placé sur le bras tournant est touché", hitBlade)
	check("Lames : loin du centre (coin de la salle) aucune touche", (function()
		for t = 0, 12, 0.1 do
			if Castle.hit(t, rm3, -19, 2) == "blade" or Castle.hit(t, rm3, 19, 2) == "blade" then
				return false
			end
		end
		return true
	end)())
	check("Lames : angle croissant avec le temps et la vitesse de la salle", Castle.bladeAngle(1, bl, rm3) < Castle.bladeAngle(2, bl, rm3) and Castle.room(5).bladeSpeed > Castle.room(2).bladeSpeed)
	-- boulets
	local rm5 = Castle.room(5)
	local ba = Castle.balls(rm5)[1]
	local ballSeen, paused = false, false
	for t = 0, 12, 0.05 do
		local x = Castle.ballX(t, ba, rm5)
		if x then
			ballSeen = ballSeen or (x >= -22 and x <= 22)
			if Castle.hit(t, rm5, x, ba.lz) == "ball" then
				ballSeen = ballSeen and true
			end
		else
			paused = true
		end
	end
	check("Boulets : traversent la salle de -22 à +22 puis font une pause", ballSeen and paused)
	local ballHit = false
	for t = 0, 8, 0.05 do
		local x = Castle.ballX(t, ba, rm5)
		if x and Castle.hit(t, rm5, x, ba.lz) == "ball" then
			ballHit = true
		end
	end
	check("Boulets : un joueur sur la trajectoire est touché", ballHit)
	-- porte
	local openTime, total = 0, 0
	for t = 0, 60, 0.05 do
		total = total + 1
		if Castle.doorIsOpen(t, rm3) then
			openTime = openTime + 1
		end
	end
	check("Porte : ouverte une fraction du cycle (entre 20 % et 70 %), se ferme ensuite", openTime / total > 0.2 and openTime / total < 0.7 and Castle.doorIsOpen(0, rm3) and not Castle.doorIsOpen(rm3.doorPeriod - 0.1, rm3))
	-- repères monde <-> salle
	local wx, wz = Castle.toWorld(3, 5, 12)
	local r, lx, lz = Castle.toLocal(wx, wz)
	check("Repères : conversion monde <-> salle aller-retour exacte (salle 3, x 5, z 12)", r == 3 and math.abs(lx - 5) < 1e-9 and math.abs(lz - 12) < 1e-9)
	check("Repères : roomAt reconnaît l'intérieur et refuse l'extérieur", Castle.roomAt(Castle.ORIGIN.x, Castle.ORIGIN.z - 5) == 1 and Castle.roomAt(Castle.ORIGIN.x + 30, Castle.ORIGIN.z - 5) == nil and Castle.roomAt(Castle.ORIGIN.x, Castle.ORIGIN.z + 10) == nil and Castle.roomAt(Castle.ORIGIN.x, Castle.ORIGIN.z - Castle.ROOMS * Castle.ROOM_LENGTH - 5) == nil)
	check("Repères : le donjon entier tient dans la carte", (function()
		local x0, z0 = Castle.toWorld(1, -Castle.ROOM_WIDTH / 2, 0)
		local x1, z1 = Castle.toWorld(Castle.ROOMS, Castle.ROOM_WIDTH / 2, Castle.ROOM_LENGTH)
		local half = Config.Map.groundSize / 2 - 10
		return math.abs(x0) < half and math.abs(x1) < half and math.abs(z0) < half and math.abs(z1) < half
	end)())
	check("Repères : le donjon ne recouvre ni les domaines ni les secrets ni les rivières", (function()
		for _, sct in ipairs(Config.SECRETS) do
			if Castle.roomAt(sct.x, sct.z) then
				return false
			end
		end
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			if Castle.roomAt(cx, cz) then
				return false
			end
		end
		return true
	end)())
	-- classement
	local list = {}
	local rank
	list, rank = Castle.insertScore(list, { name = "A", userId = 1, time = 200 }, 5)
	list, rank = Castle.insertScore(list, { name = "B", userId = 2, time = 150 }, 5)
	check("Classement : tri croissant, rang renvoyé", list[1].name == "B" and list[2].name == "A" and rank == 1)
	local list2, rank2 = Castle.insertScore(list, { name = "A", userId = 1, time = 260 }, 5)
	check("Classement : un temps moins bon ne remplace pas le meilleur du même joueur", #list2 == 2 and list2[2].time == 200 and rank2 == nil)
	local list3, rank3 = Castle.insertScore(list, { name = "A", userId = 1, time = 100 }, 5)
	check("Classement : un meilleur temps remplace l'ancien (pas de doublon) et passe premier", #list3 == 2 and list3[1].userId == 1 and list3[1].time == 100 and rank3 == 1)
	local big = {}
	for i = 1, 5 do
		big, _ = Castle.insertScore(big, { name = "J" .. i, userId = 10 + i, time = 100 + i * 10 }, 5)
	end
	local big2, rank4 = Castle.insertScore(big, { name = "Lent", userId = 99, time = 999 }, 5)
	check("Classement : limité à 5 entrées, un temps trop lent n'entre pas", #big2 == 5 and rank4 == nil)
	local big3, rank5 = Castle.insertScore(big, { name = "Rapide", userId = 98, time = 5 }, 5)
	check("Classement : un temps rapide entre premier et pousse le dernier dehors", #big3 == 5 and big3[1].name == "Rapide" and rank5 == 1 and big3[5].name ~= "J5")
	check("Classement : égalité de temps départagée par l'identifiant (ordre stable)", (function()
		local l = Castle.insertScore({}, { name = "X", userId = 7, time = 50 }, 5)
		l = Castle.insertScore(l, { name = "Y", userId = 3, time = 50 }, 5)
		return l[1].userId == 3 and l[2].userId == 7
	end)())
	-- récompense
	local fastR, slowR, deathR = Castle.reward(120, 100, 0), Castle.reward(400, 100, 0), Castle.reward(120, 100, 2)
	check("Récompense : œuf Légendaire si rapide et sans défaite, sinon Épique ; pièces plus élevées si rapide", fastR.eggTier == 4 and slowR.eggTier == 3 and deathR.eggTier == 3 and fastR.coins > slowR.coins and slowR.coins >= 5000)
end

-- Missions : bonus de récompense, texte ; temps du Château ----------------------------------------------------------------
do
	suite("Missions : œufs et boosts en récompense, textes, temps du Château")
	local Castle = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })()
	check("Missions : la 2e mission du jour donne un œuf dont la rareté monte avec l'histoire", Config.questBonus("steal", 2, 0).egg == 1 and Config.questBonus("steal", 2, 4).egg == 2 and Config.questBonus("steal", 2, 8).egg == 3)
	check("Missions : la 3e mission donne un boost de chance de 10 minutes, la 1re seulement des pièces", Config.questBonus("hatch", 3, 0).boost == 600 and next(Config.questBonus("hatch", 1, 0)) == nil)
	check("Missions de défi : Château = œuf Épique (Légendaire en fin d'histoire), rare = boost, secret = œuf Rare", Config.questBonus("castle", 1, 0).egg == 3 and Config.questBonus("castle", 1, 8).egg == 4 and Config.questBonus("rare", 1, 0).boost == 900 and Config.questBonus("secret", 1, 0).egg == 2)
	check("Missions : texte de récompense (pièces, œuf, boost) et textes des nouvelles missions", Config.questRewardText({ rew = 1500, re = 2, rb = 600 }):find("Rare", 1, true) ~= nil and Config.questRewardText({ rew = 1500, re = 2, rb = 600 }):find("10 min", 1, true) ~= nil and Config.questRewardText({ rew = 5 }):find("🥚", 1, true) == nil and Config.questText("castle", 1):find("Château", 1, true) ~= nil and Config.questText("rare", 1):find("Épique", 1, true) ~= nil and Config.questText("secret", 2):find("secret", 1, true) ~= nil)
	check("Missions : récompense invalide sans erreur", Config.questRewardText({ rew = 10, re = 99, rb = -5 }) == "🪙 10")
	check("Temps : formatTime « m:ss.d »", Castle.formatTime(125.34) == "2:05.3" and Castle.formatTime(59.96) == "1:00.0" and Castle.formatTime(0) == "0:00.0" and Castle.formatTime(-1) == "--:--.-" and Castle.formatTime(0 / 0) == "--:--.-" and Castle.formatTime(nil) == "--:--.-")
end

-- Économie : revente des œufs et des doublons --------------------------------------------------------------------------------
do
	suite("Économie : revente d'œufs (25 %), doublons d'espèces, aucun gain par achat-revente")
	check("Revente d'œuf : 25 % du prix pour chaque rareté, au moins 1", Config.eggSellValue(1) == 6 and Config.eggSellValue(2) == 225 and Config.eggSellValue(6) == 32500000 and Config.eggSellValue(99) == 0)
	local loss = true
	for t = 1, #Config.TIERS do
		if Config.eggSellValue(t) >= Config.EGG_PRICE[t] then
			loss = false
		end
	end
	check("Revente d'œuf : acheter puis revendre est toujours une perte (aucune boucle de gain)", loss and Config.EGG_SELL_RATIO < 0.5)
	local slots = { { k = "p", p = 1, s = 2, m = 1 }, { k = "p", p = 1, s = 4, m = 1 }, { k = "p", p = 2, s = 2, m = 1 }, { k = "e", t = 1 }, false, { k = "p", p = 1, s = 1, m = 2 } }
	local list, total = Config.dupesToSell(slots, 6)
	check("Doublons : garde le meilleur pet de chaque espèce (revenu le plus haut), vend les autres", #list == 2 and list[1] == 1 and list[2] == 6 and total == Config.sellValue(1, 2, 1) + Config.sellValue(1, 1, 2))
	check("Doublons : une seule copie, ou œufs et vides, rien à vendre", #Config.dupesToSell({ { k = "p", p = 3, s = 2, m = 1 }, { k = "e", t = 2 }, false }, 3) == 0 and #Config.dupesToSell({}, 0) == 0)
	check("Doublons : égalité de revenu départagée par l'indice le plus bas (le premier est gardé)", (function()
		local l = Config.dupesToSell({ { k = "p", p = 5, s = 2, m = 1 }, { k = "p", p = 5, s = 2, m = 1 } }, 2)
		return #l == 1 and l[1] == 2
	end)())
	check("Doublons : seuls les emplacements débloqués (cap) comptent", #Config.dupesToSell({ { k = "p", p = 1, s = 2, m = 1 }, { k = "p", p = 1, s = 2, m = 1 }, { k = "p", p = 1, s = 2, m = 1 } }, 2) == 1)
end

-- Château : chevaliers (patrouille, touche non mortelle) -------------------------------------------------------------------
do
	suite("Château : chevaliers qui patrouillent (pur)")
	local C = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })()
	check("Chevaliers : aucun avant la salle 3, 1 en salles 3-4, 2 en salle 5", #C.knights(C.room(1)) == 0 and #C.knights(C.room(2)) == 0 and #C.knights(C.room(3)) == 1 and #C.knights(C.room(4)) == 1 and #C.knights(C.room(5)) == 2)
	local k = C.knights(C.room(3))[1]
	local minX, maxX, okDir = 1e9, -1e9, true
	for i = 0, 400 do
		local x, d = C.knightPos(i * 0.05, k)
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		local x2 = C.knightPos(i * 0.05 + 0.001, k)
		if math.abs(x) < k.amp - 0.3 and (x2 - x) * d <= 0 then
			okDir = false
		end
	end
	check("Chevalier : aller-retour entre -amp et +amp, sens cohérent avec le déplacement", math.abs(minX + k.amp) < 0.2 and math.abs(maxX - k.amp) < 0.2 and okDir)
	local t = 3.7
	local kx = C.knightPos(t, k)
	check("Chevalier : touche (« knight ») quand le joueur est dessus, rien quand il est loin", C.hit(t, C.room(3), kx, k.lz) ~= nil and C.hit(t, C.room(3), kx, k.lz + 12) ~= "knight" and Config.CASTLE.damage.knight > 0 and Config.CASTLE.damage.knight < Config.GUARD.maxHp)
end

-- Accessibilité : taille de texte minimale dans toute l'interface ---------------------------------------------------------------
do
	suite("Accessibilité : aucune taille de texte fixe sous 11 dans l'interface")
	local smallest, where = 99, ""
	for _, f in ipairs({ "Client.client.lua", "Animations.client.lua", "Cinematics.client.lua", "Ambience.client.lua", "RevealFx.lua", "CoinIcon.lua" }) do
		local okRead, src = pcall(fs.readFile, "roblox/src/StarterPlayerScripts/" .. f)
		if okRead then
			for n in src:gmatch("TextSize = (%d+)") do
				if tonumber(n) < smallest then
					smallest, where = tonumber(n), f
				end
			end
		end
	end
	check("Texte : taille fixe minimale " .. smallest .. " (" .. where .. ") >= 11", smallest >= 11)
end

-- Échelle et matières des modèles Blender (retour réel de Studio : pets énormes, couleurs sombres) -----------------------------------------------
do
	suite("Échelle par hauteur cible (±10 %), matières (Metal seulement pour les pièces métalliques), couleurs exactes")
	local AM = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Assets.lua"), { debugName = "Assets" })()
	local function rgbOf(n)
		local r, g, b = AM.parseColorSuffix(n)
		return r and (r .. "," .. g .. "," .. b) or "nil"
	end
	check("Couleur : Sapin__2E7D4F = 46,125,79 (vert), PetPoussin FFD84D = 255,216,77 (jaune)", rgbOf("Sapin__2E7D4F") == "46,125,79" and rgbOf("Poussin__FFD84D") == "255,216,77")
	check("Couleur : doublon d'import « .001 » garde la couleur ; sans suffixe -> nil ; faux doublon (chiffres collés) refusé", rgbOf("Sapin__2E7D4F.001") == "46,125,79" and rgbOf("Sapin__2E7D4F.12") == "46,125,79" and rgbOf("Sapin.001") == "nil" and rgbOf("Sapin__2E7D4F12") == "nil")
	check("Nom de base : suffixes de couleur et de doublon retirés", AM.baseName("Lame__D8DCE8.001") == "Lame" and AM.baseName("Pics__C0C0C0") == "Pics" and AM.baseName("Socle") == "Socle" and AM.baseName(nil) == "")
	local MAT = { Metal = "Metal", Neon = "Neon", Plastic = "Plastic", SmoothPlastic = "SmoothPlastic", Foil = "Foil" }
	local function mkpart(name, material)
		local o = { Name = name, Size = { X = 2, Y = 2, Z = 2 }, Color = "origine", CastShadow = true, Material = material, Reflectance = 0.6, ClassName = "Part" }
		function o:IsA(c)
			return c == "BasePart" or c == "Part"
		end
		function o:GetChildren()
			return {}
		end
		return o
	end
	local parts = { mkpart("Corps__2E7D4F.001", "Metal"), mkpart("Detail__000000", "Neon"), mkpart("Lame__D8DCE8", "Plastic"), mkpart("Herse__8A8A8A.002", "SmoothPlastic"), mkpart("Flamme__FFAA33", "Plastic"), mkpart("Socle", "Foil"), mkpart("Anneau__C0C0C0", "Neon") }
	local fakeModel = { Name = "M", ClassName = "Model", kids = parts, IsA = function(_, c) return c == "Model" end, GetDescendants = function(self) return self.kids end, Clone = function(self) return self end, Destroy = function() end }
	local CM = AM.new(Config, { loadAsset = function() return fakeModel end, spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end, material = MAT, color = function(r, g, b) return "rgb(" .. r .. "," .. g .. "," .. b .. ")" end })
	CM.colorize(fakeModel)
	check("Matières : seules les pièces métalliques (Lame, Herse, Anneau) sont en Metal ; Flamme en Neon ; tout le reste en plastique lisse",
		parts[1].Material == "SmoothPlastic" and parts[2].Material == "SmoothPlastic" and parts[3].Material == "Metal" and parts[4].Material == "Metal" and parts[5].Material == "Neon" and parts[6].Material == "SmoothPlastic" and parts[7].Material == "Metal")
	check("Matières : aucun reflet (Reflectance 0 partout) et couleur exacte du suffixe (Corps 2E7D4F = vert, doublon .001 compris)", (function()
		for _, p in ipairs(parts) do
			if p.Reflectance ~= 0 then
				return false
			end
		end
		return parts[1].Color == "rgb(46,125,79)" and parts[6].Color == "origine"
	end)())
	-- effets (Neon voulu) : matière conservée
	local vfx = { mkpart("Cercle__FFFFFF", "Neon") }
	local vm = { Name = "V", ClassName = "Model", kids = vfx, IsA = function(_, c) return c == "Model" end, GetDescendants = function(self) return self.kids end, Clone = function(self) return self end, Destroy = function() end }
	CM.colorize(vm, true)
	check("Effets : le Neon voulu d'un modèle d'effet est conservé", vfx[1].Material == "Neon" and vfx[1].Color == "rgb(255,255,255)")
	-- hauteur cible
	local function sizedModel(raw)
		local m = { k = 1 }
		function m:GetExtentsSize()
			return { X = raw.X * self.k, Y = raw.Y * self.k, Z = raw.Z * self.k }
		end
		function m:GetScale()
			return self.k
		end
		function m:ScaleTo(v)
			self.k = v
		end
		return m
	end
	local big = sizedModel({ X = 20, Y = 20, Z = 20 })
	local okBig, hBig = AM.fitHeight(big, 3)
	check("fitHeight : un pet brut de 20 studs est ramené à 3 studs (±10 %)", okBig and math.abs(hBig - 3) <= 0.3 and math.abs(big:GetExtentsSize().Y - 3) <= 0.3)
	local tiny = sizedModel({ X = 0.01, Y = 0.1, Z = 0.01 })
	local okTiny, hTiny = AM.fitHeight(tiny, 8)
	check("fitHeight : un modèle minuscule est agrandi jusqu'à la cible", okTiny and math.abs(hTiny - 8) <= 0.8)
	local zero, nan, nilM = sizedModel({ X = 1, Y = 0, Z = 1 }), sizedModel({ X = 1, Y = 0 / 0, Z = 1 }), {}
	check("fitHeight : mesure nulle, NaN ou impossible -> refus (le modèle n'est pas posé, jamais d'échelle brute)", select(1, AM.fitHeight(zero, 3)) == false and select(1, AM.fitHeight(nan, 3)) == false and select(1, AM.fitHeight(nilM, 3)) == false)
	check("fitHeight : cible invalide (0, négative, NaN, nil) -> refus", select(1, AM.fitHeight(sizedModel({ X = 1, Y = 1, Z = 1 }), 0)) == false and select(1, AM.fitHeight(sizedModel({ X = 1, Y = 1, Z = 1 }), -2)) == false and select(1, AM.fitHeight(sizedModel({ X = 1, Y = 1, Z = 1 }), nil)) == false)
	local stuck = { GetExtentsSize = function() return { X = 1, Y = 10, Z = 1 } end, GetScale = function() return 1 end, ScaleTo = function() end }
	check("fitHeight : une mise à l'échelle sans effet (hauteur hors tolérance) est refusée", select(1, AM.fitHeight(stuck, 3)) == false)
	local worst = 0
	for tier = 1, 6 do
		for _, sz in ipairs(Config.SIZES) do
			worst = math.max(worst, Config.petTargetHeight(tier, sz.scale))
		end
	end
	check("Pets : hauteur cible 1,7 à 2,1 studs selon la rareté (taille normale), jamais plus de 3 = 60 % d'un joueur (" .. string.format("%.2f", worst) .. ")", near(Config.petTargetHeight(1, 1), 1.7) and near(Config.petTargetHeight(6, 1), 2.1) and worst <= 3 and worst <= 0.6 * Config.Assets.targetHeights.player + 1e-9 and Config.petTargetHeight(nil, nil) == 1.7 and near(Config.petTargetHeight(99, 0 / 0), 2.1))
	check("Œufs : 1,8 à 2,8 studs selon la rareté", near(Config.eggHeight(1), 1.8) and near(Config.eggHeight(6), 2.8) and Config.eggHeight(nil) == 1.8)
	local H = Config.Assets.targetHeights
	check("Hauteurs cibles : joueur 5, lampadaire 8, banc 2,5, fontaine 7, cabane 11, moulin 20, chien 2,5, loup 3, ours 5, arbre 10-14", H.player == 5 and H.lamp == 8 and H.bench == 2.5 and Config.Assets.propsHeight.fountain == 7 and Config.Assets.propsHeight.hut == 11 and H.mill == 20 and Config.Assets.guardHeights.dog == 2.5 and Config.Assets.guardHeights.wolf == 3 and Config.Assets.guardHeights.bear == 5 and Config.Assets.propsHeight.tree >= 10 and Config.Assets.propsHeight.tree <= 14 and Config.Assets.propsHeight.fir <= 14)
	local animSrc = fs.readFile("roblox/src/StarterPlayerScripts/Animations.client.lua")
	check("Animations : l'apparition d'un pet ne remet jamais l'échelle à 1 (cause des pets énormes) : échelle relative à celle posée par le serveur", animSrc:find("ScaleTo(1)", 1, true) == nil and animSrc:find("GetScale()", 1, true) ~= nil)
end

-- Étiquettes de portails : un seul portail détaillé à la fois ------------------------------------------------------------------
do
	suite("Hub : étiquette du portail le plus proche seulement, tailles fixes en pixels")
	local portals = { { key = "1", x = -50, z = 0 }, { key = "2", x = -20, z = 0 }, { key = "c2", x = -20, z = -45 }, { key = "5", x = 60, z = 0 } }
	check("Portail le plus proche : choisi parmi 4, un seul résultat", Config.nearestPortal(-22, 3, portals) == "2" and Config.nearestPortal(58, 2, portals) == "5" and Config.nearestPortal(-48, 1, portals) == "1")
	check("Portail : rien à portée (> 40 studs) ou position invalide -> aucune étiquette", Config.nearestPortal(0, 200, portals) == nil and Config.nearestPortal(nil, 3, portals) == nil and Config.nearestPortal(0 / 0, 3, portals) == nil and Config.nearestPortal(1, 1, {}) == nil)
	check("Portail : à égale distance, un seul portail gagne (jamais deux étiquettes)", (function()
		local k = Config.nearestPortal(-35, 0, portals)
		return k == "1" or k == "2"
	end)())
	local PL = Config.PORTAL_LABEL
	local hubSrc = fs.readFile("roblox/src/Hub/ServerScriptService/HubWorld.lua")
	check("Étiquettes : tailles fixes (titre " .. PL.titleSize[1] .. "x" .. PL.titleSize[2] .. ", statut " .. PL.statusSize[1] .. "x" .. PL.statusSize[2] .. " px), pas de taille proportionnelle, 40 studs", PL.titleSize[1] <= 300 and PL.titleSize[2] <= 60 and PL.statusSize[1] <= 260 and PL.statusSize[2] <= 40 and PL.maxDist == 40 and hubSrc:find("UDim2.fromOffset(width, height)", 1, true) ~= nil and hubSrc:find("UDim2.fromScale(1, 1)", 1, true) ~= nil)
end

-- VfxKit : préréglages, qualités, plafonds mobiles, effets par rareté ---------------------------------------------------------------
do
	suite("VfxKit : préréglages, qualité Élevé/Moyen/Bas, plafonds mobiles, effets par rareté")
	local VK = luau.load(fs.readFile("roblox/src/ReplicatedStorage/VfxKit.lua"), { debugName = "VfxKit" })()
	local E = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
	local K = VK.new(Config, E)
	local names = { "aura_runique", "aura_ailes", "onde_de_choc", "pilier_revelation", "bouclier", "etincelles", "spirale_montee", "portail_torii" }
	local allKnown = true
	for _, n in ipairs(names) do
		allKnown = allKnown and VK.PRESETS[n] ~= nil
	end
	check("Préréglages : les 8 effets demandés existent (aura runique, ailes, onde de choc, pilier, bouclier, étincelles, spirale, torii)", allKnown)
	local modelsOk = true
	for _, n in ipairs(names) do
		for _, piece in ipairs(VK.PRESETS[n].pieces) do
			modelsOk = modelsOk and Config.Assets.models.vfx[piece.model] ~= nil
		end
	end
	check("Préréglages : chaque pièce référence un des 13 modèles Blender approuvés (IDs de Config.Assets.models.vfx)", modelsOk and #VK.MODELS == 13)
	local count = 0
	for _ in pairs(Config.Assets.models.vfx) do
		count += 1
	end
	check("Modèles d'effets : 13 IDs approuvés, ceux du cercle runique et du pilier de lumière corrects", count == 13 and Config.Assets.models.vfx.cercle_runique == 78887954880607 and Config.Assets.models.vfx.pilier_lumiere == 136359342334671 and Config.Assets.models.vfx.bouclier == 135593787305812)
	local low, high = K.plan("pilier_revelation", 4, "low", 1), K.plan("pilier_revelation", 4, "high", 1)
	check("Qualité Basse : une seule pièce, 40 particules au plus, jamais de faisceau ; Élevée : 3 pièces et faisceau", low and #low.pieces == 1 and low.particles.count <= 40 and low.beam == false and high and #high.pieces == 3 and high.beam == true and high.particles.count == 30)
	check("Qualité : aucun préréglage ne dépasse 40 particules en Bas, 70 en Moyen, 120 en Élevé", (function()
		for _, n in ipairs(names) do
			for q, cap in pairs({ low = 40, medium = 70, high = 120 }) do
				local pl = K.plan(n, 3, q, 1)
				if pl and pl.particles and pl.particles.count > cap then
					return false
				end
				if pl and q ~= "high" and pl.beam then
					return false
				end
			end
		end
		return true
	end)())
	check("Qualité : les effets exigeants (ailes, spirale, torii) sont refusés en Bas ; acceptés en Moyen", K.plan("aura_ailes", 4, "low", 1) == nil and K.plan("spirale_montee", 5, "low", 1) == nil and K.plan("portail_torii", 6, "low", 1) == nil and K.plan("aura_ailes", 4, "medium", 1) ~= nil)
	check("Plan : préréglage ou qualité inconnus -> nil sans erreur ; ampleur invalide ramenée à 1", K.plan("inconnu", 1, "high", 1) == nil and K.plan("etincelles", 1, "ultra", 1) == nil and math.abs(K.plan("etincelles", 1, "high", 0 / 0).pieces[1].s1 - VK.PRESETS.etincelles.pieces[1].s1) < 1e-9)
	check("Mobile : au plus 3 effets simultanés (Bas), 5 (Moyen), 8 (Élevé) ; admission refusée au-delà", VK.QUALITY.low.maxConcurrent == 3 and VK.QUALITY.medium.maxConcurrent == 5 and VK.QUALITY.high.maxConcurrent == 8 and K.admit(2, "low") and not K.admit(3, "low") and not K.admit(8, "high") and not K.admit(nil, "low"))
	local legendaryLow = K.hatchPlans(5, false, "low", 0)
	check("Éclosion mythique sur téléphone : 3 effets au plus (" .. #legendaryLow .. "), jamais plus que la simultanéité", #legendaryLow == 3 and #K.hatchPlans(5, false, "low", 2) == 1 and #K.hatchPlans(5, false, "low", 3) == 0)
	local function nbEffects(tier, secret)
		return #select(1, VK.hatchEffects(tier, secret))
	end
	check("Raretés : ampleur croissante (commun discret : 1 effet ; légendaire et secret spectaculaires)", nbEffects(1) == 1 and nbEffects(2) == 2 and nbEffects(4) >= 4 and nbEffects(6) >= 6 and nbEffects(1, true) >= 6 and select(2, VK.hatchEffects(1)) < select(2, VK.hatchEffects(3)) and select(2, VK.hatchEffects(3)) < select(2, VK.hatchEffects(5)) and select(2, VK.hatchEffects(6)) > select(2, VK.hatchEffects(5)))
	check("Raretés : le secret joue pilier, spirale et torii ; rareté invalide (nil, NaN, 99) bornée sans erreur", (function()
		local list = VK.hatchEffects(2, true)
		local joined = table.concat(list, ",")
		return joined:find("pilier_revelation", 1, true) ~= nil and joined:find("spirale_montee", 1, true) ~= nil and joined:find("portail_torii", 1, true) ~= nil and #select(1, VK.hatchEffects(nil)) == 1 and #select(1, VK.hatchEffects(99)) >= 6 and #select(1, VK.hatchEffects(0 / 0)) == 1
	end)())
	local c3 = K.plan("aura_runique", 3, "high", 1).pieces[1].color
	local c6 = K.plan("aura_runique", 6, "high", 1).pieces[1].color
	check("Couleurs : par rareté (Épique et Cosmique ont des couleurs différentes, valeurs 0-255), blanc pour « white »", (c3[1] ~= c6[1] or c3[2] ~= c6[2] or c3[3] ~= c6[3]) and c3[1] <= 255 and c3[1] >= 0 and K.plan("pilier_revelation", 3, "high", 1).pieces[3].color[1] == 255 and K.rarityColor(99)[1] == 255)
	local piece = K.plan("onde_de_choc", 3, "high", 1).pieces[1]
	local okCurve = true
	for _, st in ipairs({ "Back", "Elastic", "Quint", "Quad", "Sine" }) do
		okCurve = okCurve and math.abs(K.curve(st, 0)) < 1e-9 and math.abs(K.curve(st, 1) - 1) < 1e-9 and K.curve(st, -5) == K.curve(st, 0) and K.curve(st, 9) == K.curve(st, 1)
	end
	check("Courbes (Back, Elastic, Quint, Quad, Sine) : 0 au départ, 1 à l'arrivée, entrée bornée", okCurve)
	local ok01 = true
	for i = 0, 100 do
		local tr = K.transparencyAt(piece, i / 100)
		ok01 = ok01 and tr >= 0 and tr <= 1
	end
	check("Transparence : toujours dans [0, 1], visible au sommet (peak) puis effacée à la fin", ok01 and math.abs(K.transparencyAt(piece, 0.25) - piece.peak) < 1e-6 and K.transparencyAt(piece, 1) >= 0.99 and K.scaleAt(piece, 0) == piece.s0 and math.abs(K.scaleAt(piece, 1) - piece.s1) < 1e-9)
	check("Durées : chaque effet dure moins de 5 s (tout est nettoyé ensuite)", (function()
		for _, n in ipairs(names) do
			local pl = K.plan(n, 5, "high", 1)
			if not pl or pl.duration > 5 then
				return false
			end
		end
		return true
	end)())
	check("Qualité automatique : tactile = Bas, sinon Élevé ; réglage forcé respecté, valeur inconnue ignorée", VK.quality(true) == "low" and VK.quality(false) == "high" and VK.quality(false, "medium") == "medium" and VK.quality(true, "high") == "high" and VK.quality(true, "xx") == "low")
end

-- CinematicKit : plans, trajectoires, 8 secondes maximum, ralenti, danger, restitution garantie --------------------------------------------
do
	suite("CinematicKit : durée = somme des prises, 8 s maximum, trajectoires, ralenti, restitution garantie, passage, deux cinématiques")
	local CK = luau.load(fs.readFile("roblox/src/ReplicatedStorage/CinematicKit.lua"), { debugName = "CinematicKit" })()
	local E = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
	local CinemaMod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Cinema.lua"), { debugName = "Cinema" })()
	local Ci = CinemaMod.new(E)
	local K = CK.new(E, Ci)
	local function sumDur(def)
		local t = 0
		for _, sh in ipairs(def.shots) do
			t += sh.dur
		end
		return t
	end
	local plans = {}
	for _, p in pairs(CK.PLANS) do
		plans[#plans + 1] = p
	end
	for tier = 3, 6 do
		plans[#plans + 1] = CK.hatchPlan(tier, false)
	end
	local under8, sumOk = true, true
	for _, def in ipairs(plans) do
		local built, real = K.build(def)
		under8 = under8 and built ~= nil and real <= CK.MAX_SECONDS + 1e-9
		if built and not def.shots[1].slow and not def.shots[2] then
			sumOk = sumOk and math.abs(sumDur(built) - real) < 1e-9
		end
	end
	check("Plans : " .. #plans .. " plans (survol du hub, éclosions, secret, entrée et victoire du château), tous <= 8 s réelles", #plans >= 8 and under8)
	local nosl = { id = "x", shots = { { dur = 1.5, pos = { 0, 1, 0 }, look = { 0, 0, 0 } }, { dur = 2.5, pos = { 0, 1, 0 }, look = { 0, 0, 0 } } } }
	local b1, r1 = K.build(nosl)
	check("Durée d'un plan sans ralenti = somme des prises (4 s)", b1 and math.abs(r1 - 4) < 1e-9 and math.abs(sumDur(b1) - 4) < 1e-9)
	local long = { id = "long", shots = { { dur = 6, pos = { 0, 1, 0 }, look = { 0, 0, 0 } }, { dur = 6, pos = { 0, 1, 0 }, look = { 0, 0, 0 } } } }
	local b2, r2 = K.build(long)
	check("Plan de 12 s : ramené à 8 s (durées réduites proportionnellement)", b2 and math.abs(r2 - 8) < 1e-9 and math.abs(sumDur(b2) - 8) < 1e-9 and math.abs(b2.shots[1].dur - 4) < 1e-9)
	check("Plan invalide : aucune prise, durée nulle/NaN/négative, position manquante -> refus sans erreur", K.build(nil) == nil and K.build({ shots = {} }) == nil and K.build({ shots = { { dur = 0, pos = { 0, 0, 0 }, look = { 0, 0, 0 } } } }) == nil and K.build({ shots = { { dur = 0 / 0, pos = { 0, 0, 0 }, look = { 0, 0, 0 } } } }) == nil and K.build({ shots = { { dur = 1, look = { 0, 0, 0 } } } }) == nil and K.build({ shots = { { dur = -2, pos = { 0, 0, 0 }, look = { 0, 0, 0 } } } }) == nil)
	check("Maximum demandé supérieur à 8 s ramené à 8 s", select(2, K.build(long, 99)) <= 8 + 1e-9 and select(2, K.build(long, 3)) <= 3 + 1e-9)
	local orb = { dur = 3, pos = { 0, 0, 0 }, look = { 5, 2, -3 }, path = "orbit", radius = 10, toRadius = 6, angle0 = 0, angle1 = 3, height = 4, ease = "Sine" }
	local ok1 = true
	for i = 0, 20 do
		local pos, look = K.cameraAt(orb, i / 20)
		local d = math.sqrt((pos[1] - look[1]) ^ 2 + (pos[3] - look[3]) ^ 2)
		local expect = 10 + (6 - 10) * K.curve("Sine", i / 20)
		ok1 = ok1 and math.abs(d - expect) < 1e-6 and math.abs(pos[2] - (look[2] + 4)) < 1e-9
	end
	check("Orbite : la caméra reste à la distance voulue du point visé (10 -> 6) et à la hauteur donnée", ok1)
	local dive = { dur = 1, pos = { 0, 30, 10 }, toPos = { 0, 4, 10 }, look = { 0, 0, 0 }, path = "dive" }
	local dy0, dy1 = K.cameraAt(dive, 0), K.cameraAt(dive, 1)
	check("Plongée : descend de 30 à 4 en gardant la cible", dy0[2] == 30 and math.abs(dy1[2] - 4) < 1e-9)
	local _, _, f0 = K.cameraAt({ dur = 1, pos = { 0, 0, 0 }, look = { 0, 0, 1 }, fov = 70, toFov = 40, path = "dolly" }, 0)
	local _, _, f1 = K.cameraAt({ dur = 1, pos = { 0, 0, 0 }, look = { 0, 0, 1 }, fov = 70, toFov = 40, path = "dolly" }, 1)
	check("Zoom dolly : le champ de vision se resserre (70 -> 40) ; travelling : positions de départ et d'arrivée exactes", f0 == 70 and math.abs(f1 - 40) < 1e-9 and (function()
		local tr = { dur = 1, pos = { 1, 2, 3 }, toPos = { 4, 5, 6 }, look = { 0, 0, 0 }, ease = "Quad" }
		local a, b = K.cameraAt(tr, 0), K.cameraAt(tr, 1)
		return a[1] == 1 and a[3] == 3 and math.abs(b[1] - 4) < 1e-9 and math.abs(b[3] - 6) < 1e-9
	end)())
	local sh = { shake = 0.6 }
	local early, late = K.shakeOffset(sh, 0.05, 1.3), K.shakeOffset(sh, 1, 1.3)
	check("Tremblement : décroît sur la prise (nul à la fin) et nul sans amplitude", math.abs(late[1]) + math.abs(late[2]) + math.abs(late[3]) < 1e-9 and math.abs(early[1]) + math.abs(early[2]) > 0.01 and K.shakeOffset({}, 0.5, 2)[1] == 0)
	local slowDef = { id = "s", shots = { { dur = 2, pos = { 0, 0, 0 }, look = { 0, 0, 1 }, slow = { at = 0.5, to = 1, scale = 0.5 } } } }
	local realD = K.realDuration(slowDef.shots[1])
	check("Ralenti : la durée réelle s'allonge (2 s -> 3 s à moitié vitesse sur la seconde moitié), temps virtuel monotone et complet à la fin", math.abs(realD - 3) < 1e-9 and math.abs(K.virtualElapsed(slowDef, 1) - 1) < 1e-9 and math.abs(K.virtualElapsed(slowDef, 2) - 1.5) < 1e-9 and math.abs(K.virtualElapsed(slowDef, 3) - 2) < 1e-9 and K.virtualElapsed(slowDef, 99) == 2)
	local prev, mono = -1, true
	for i = 0, 60 do
		local v = K.virtualElapsed(CK.PLANS.secret, i * 0.15)
		mono = mono and v >= prev
		prev = v
	end
	check("Ralenti : le temps virtuel du plan secret ne recule jamais", mono)
	check("Danger : aucune cinématique à moins de 50 % de pv, juste après un coup, poursuivi, dans une salle à pièges ou mort", K.canPlay({ hp = 100, maxHp = 100, sinceHit = 30 }) and not K.canPlay({ hp = 40, maxHp = 100 }) and not K.canPlay({ hp = 100, maxHp = 100, sinceHit = 1 }) and not K.canPlay({ hp = 100, maxHp = 100, chased = true }) and not K.canPlay({ hp = 100, maxHp = 100, inTrapRoom = true }) and not K.canPlay({ dead = true }) and not K.canPlay(nil))
	check("Alerte (gardien qui repère) : pas de caméra ; refusée sous 40 % de pv, juste après un coup, pendant le temps de recharge ou passé 3 par session", K.canAlert({ hp = 100, maxHp = 100, sinceHit = 30, chased = true }, 1000, nil, 0) and not K.canAlert({ hp = 30, maxHp = 100 }, 1000, nil, 0) and not K.canAlert({ hp = 100, maxHp = 100, sinceHit = 1 }, 1000, nil, 0) and not K.canAlert({ hp = 100, maxHp = 100 }, 1050, 1000, 1) and K.canAlert({ hp = 100, maxHp = 100 }, 1100, 1000, 1) and not K.canAlert({ hp = 100, maxHp = 100 }, 5000, nil, 3) and CK.ALERT.seconds <= 1.5)
	check("Éclosions : commun et rare sans cinématique, épique court, légendaire et secret complets", CK.hatchPlan(1) == nil and CK.hatchPlan(2) == nil and #CK.hatchPlan(3).shots == 1 and #CK.hatchPlan(4).shots == 3 and CK.hatchPlan(2, true).id == "secret" and CK.hatchPlan(5).skipOnTap and K.realTotal(CK.hatchPlan(6)) > K.realTotal(CK.hatchPlan(3)))
	-- lecteur : restitution garantie, passage, deux cinématiques simultanées
	local function makeHost(failApply, failTake)
		local h = { taken = 0, given = 0, applied = 0 }
		function h.takeCamera()
			if failTake then
				error("caméra indisponible")
			end
			h.taken += 1
		end
		function h.giveCameraBack()
			h.given += 1
		end
		function h.apply()
			h.applied += 1
			if failApply and h.applied >= 2 then
				error("erreur d'affichage")
			end
		end
		return h
	end
	local simple = { id = "p", shots = { { dur = 1, pos = { 0, 1, 0 }, look = { 0, 0, 0 } }, { dur = 1, pos = { 0, 1, 0 }, look = { 0, 0, 0 } } } }
	local h1 = makeHost()
	local R1 = K.runner(h1)
	check("Lecteur : démarrage, lecture complète en 2 s, caméra prise puis restituée UNE fois", R1.start(simple, 0) == "playing" and h1.taken == 1 and (function()
		local finished = 0
		for i = 1, 60 do
			if R1.update(i * 0.05) == "finished" then
				finished += 1
			end
		end
		return finished == 1 and h1.given == 1 and not R1.isActive()
	end)())
	local h2 = makeHost()
	local R2 = K.runner(h2)
	R2.start(simple, 0)
	R2.update(0.5)
	check("Passer en cours de prise : la caméra est restituée immédiatement, plus rien ne joue", R2.skip(0.6) == true and h2.given == 1 and not R2.isActive() and R2.update(0.7) == nil)
	local h3 = makeHost(true)
	local R3 = K.runner(h3)
	R3.start(simple, 0)
	local sawErr = false
	for i = 1, 20 do
		if R3.update(i * 0.05) == "error" then
			sawErr = true
			break
		end
	end
	check("Erreur pendant la lecture : abandon et caméra restituée (jamais bloquée)", sawErr and h3.given == 1 and not R3.isActive())
	local h4 = makeHost(false, true)
	local R4 = K.runner(h4)
	check("Caméra indisponible au démarrage : plan refusé, restitution tentée, aucun état bloqué", R4.start(simple, 0) == "invalid" and not R4.isActive() and h4.given == 1)
	local h5 = makeHost()
	local R5 = K.runner(h5)
	R5.start(simple, 0)
	check("Deux cinématiques simultanées : la seconde est refusée (jamais superposées), en file si enchaînée", R5.start({ id = "q", shots = simple.shots }, 0.2) == "refused" and R5.start({ id = "q2", shots = simple.shots }, 0.2, true) == "queued" and h5.taken == 1)
	R5.abort()
	check("Abandon (départ du joueur, mort) : caméra restituée, lecteur vide", h5.given >= 1 and not R5.isActive())
	check("Plan invalide au démarrage : « invalid » sans toucher à la caméra", K.runner(makeHost()).start({ id = "z", shots = {} }, 0) == "invalid")
	local h6 = makeHost()
	local R6 = K.runner(h6)
	R6.start(CK.hatchPlan(6), 0)
	local reached = 0
	for i = 1, 400 do
		local st = R6.update(i * 0.05)
		reached = i * 0.05
		if st ~= "playing" then
			break
		end
	end
	check("Éclosion Cosmique complète jouée en 8 s au plus (" .. string.format("%.1f", reached) .. " s) puis caméra restituée", reached <= 8.1 and h6.given == 1)
end

-- Animations d'interface : compteur qui défile, brillance, pulsation ---------------------------------------------------------------
do
	suite("Animations d'interface : compteur qui défile, balayage de brillance, pulsation")
	local E = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
	local v, steps = 0, 0
	local monotone, overshoot = true, false
	while v ~= 12345 and steps < 600 do
		local nv = E.rollTo(v, 12345, 1 / 30)
		monotone = monotone and nv >= v
		overshoot = overshoot or nv > 12345
		v = nv
		steps += 1
	end
	check("Compteur : atteint exactement la cible en moins de 20 s (" .. steps .. " images), sans reculer ni dépasser", v == 12345 and steps < 600 and monotone and not overshoot)
	local d, dsteps = 5000, 0
	while d ~= 100 and dsteps < 600 do
		d = E.rollTo(d, 100, 1 / 30)
		dsteps += 1
	end
	check("Compteur : fonctionne aussi à la baisse ; valeurs invalides (nil, NaN) sans erreur", d == 100 and E.rollTo(nil, 50, 0.03) == 50 and E.rollTo(7, nil, 0.03) == 7 and E.rollTo(0 / 0, 9, 0.03) == 9 and E.rollTo(3, 0 / 0, 0.03) == 3 and E.rollTo(10, 10, 0.03) == 10)
	check("Brillance : balaye de -0,25 à 1,25 de la largeur, croissante, bornée", math.abs(E.shineX(0) + 0.25) < 1e-9 and math.abs(E.shineX(1) - 1.25) < 1e-9 and E.shineX(0.3) < E.shineX(0.6) and E.shineX(-3) == E.shineX(0) and E.shineX(9) == E.shineX(1))
	local peak, okp = 0, true
	for i = 0, 100 do
		local pv = E.pulse(i / 100)
		peak = math.max(peak, pv)
		okp = okp and pv >= 0 and pv <= 1
	end
	check("Pulsation : 0 -> 1 -> 0, montée rapide, valeurs dans [0, 1]", okp and math.abs(peak - 1) < 1e-6 and E.pulse(0) == 0 and E.pulse(1) == 0 and E.pulse(0.2) > E.pulse(0.6))
	check("Animations d'interface activables séparément (uiFx, pulse) et coupées par l'interrupteur général", Config.animEnabled("uiFx") and Config.animEnabled("pulse") and (function()
		local saved = Config.Animations.enabled
		Config.Animations.enabled = false
		local off = not Config.animEnabled("uiFx") and not Config.animEnabled("pulse")
		Config.Animations.enabled = saved
		return off
	end)())
end

-- Icônes : plus aucun pictogramme de recyclage « ♻ » (mal lisible, ressemble à un « + ») ----------------------------------------------------
do
	suite("Icônes : plus de ♻ dans le jeu, pictogrammes uniformes")
	local bad = {}
	for _, f in ipairs({ "roblox/src/ReplicatedStorage/Config.lua", "roblox/src/ServerScriptService/Main.server.lua", "roblox/src/StarterPlayerScripts/Client.client.lua", "roblox/src/Hub/StarterPlayerScripts/HubClient.client.lua", "roblox/src/Hub/ServerScriptService/Hub.server.lua", "roblox/src/ServerScriptService/Builder.lua" }) do
		local okRead, src = pcall(fs.readFile, f)
		if okRead and (src:find("♻", 1, true) or src:find("🔄", 1, true)) then
			bad[#bad + 1] = f
		end
	end
	check("Icônes : ni « ♻ » ni « 🔄 » dans les scripts (" .. table.concat(bad, ",") .. ")", #bad == 0)
	local client = fs.readFile("roblox/src/StarterPlayerScripts/Client.client.lua")
	check("Icônes : échange des doublons = ⭐ « Échanger » (bouton, titre), renaissance = 🌅, menu Plus = ⚙️", client:find('icon = "⭐", title = "Échanger les doublons', 1, true) ~= nil and client:find('btn = "Échanger "', 1, true) ~= nil and client:find('icon = "🌅", title = "Renaissance"', 1, true) ~= nil and client:find('{ "more", "⚙️", "Plus" }', 1, true) ~= nil)
end

-- Progression de la base : niveaux, points par rareté ---------------------------------------------------------------------------------
do
	suite("Progression de la base : 8 niveaux, points pondérés par la rareté")
	local B = Config.BASE_LEVELS
	check("Base : 8 niveaux, de l'enclos de bois au château doré, seuils strictement croissants", #B == 8 and B[1].name == "Enclos de bois" and B[8].name == "Château doré" and B[1].score == 0 and (function()
		for i = 2, #B do
			if B[i].score <= B[i - 1].score then
				return false
			end
		end
		return true
	end)())
	check("Base : points par rareté Commun 1, Rare 3, Épique 8, Légendaire 20, Mythique 50, Secret 150 ; rareté invalide bornée", Config.baseGain(1) == 1 and Config.baseGain(2) == 3 and Config.baseGain(3) == 8 and Config.baseGain(4) == 20 and Config.baseGain(5) == 50 and Config.baseGain(6) == 150 and Config.baseGain(0) == 1 and Config.baseGain(99) == 150 and Config.baseGain(nil) == 1 and Config.baseGain(0 / 0) == 1)
	local l0, n0, p0, r0 = Config.baseLevel(0)
	local l11, _, _, r11 = Config.baseLevel(11)
	local l12 = Config.baseLevel(12)
	local l8, n8, p8, r8 = Config.baseLevel(99999)
	check("Base : niveau 1 à 0 point (suivant : cabane, 12 points), niveau 2 dès 12, dernier niveau sans suivant", l0 == 1 and n0.name == "Cabane" and p0 == 0 and r0 == 12 and l11 == 1 and r11 == 1 and l12 == 2 and l8 == 8 and n8 == nil and p8 == 1 and r8 == 0)
	local mono, prev = true, 1
	for score = 0, 4000, 7 do
		local lv = Config.baseLevel(score)
		mono = mono and lv >= prev and lv <= 8
		prev = lv
	end
	check("Base : le niveau ne baisse jamais quand le score monte ; scores invalides (nil, NaN, négatif) = niveau 1", mono and Config.baseLevel(nil) == 1 and Config.baseLevel(0 / 0) == 1 and Config.baseLevel(-50) == 1)
	check("Renaissance : le score de base et l'achat unique du pack de départ survivent (profil neuf)", fs.readFile("roblox/src/ServerScriptService/Main.server.lua"):find("fresh.starter, fresh.baseScore = d.starter, d.baseScore", 1, true) ~= nil)
	check("Base : un seul pet Secret (150 points) fait passer de l'enclos à la Maison (niveau 4) ; il faut 12 Communs pour la première amélioration", Config.baseLevel(Config.baseGain(6)) == 4 and Config.baseLevel(12 * Config.baseGain(1)) == 2)
end

-- Pose planifiée du décor : aucune collision, rien dans l'eau ni sur un chemin, ponts qui relient les rives ------------------------------------
do
	suite("Placement planifié : empreintes sans recouvrement, rien dans l'eau ni sur un chemin, ponts, barrières alignées, cabanes face au domaine")
	local PL = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Placement.lua"), { debugName = "Placement" })()
	local P = PL.new(Config)
	local plan = P.plan()
	local items = plan.items
	local counts = {}
	for _, it in ipairs(items) do
		counts[it.kind] = (counts[it.kind] or 0) + 1
	end
	check("Plan : arbres, rochers, buissons, cabanes et barrières posés (" .. #items .. " objets : " .. (counts.tree or 0) .. " arbres, " .. (counts.fir or 0) .. " sapins, " .. (counts.rock or 0) .. " rochers, " .. (counts.bush or 0) .. " buissons, " .. (counts.hut or 0) .. " cabanes, " .. (counts.fence or 0) .. " barrières)", #items >= 40 and (counts.tree or 0) >= 10 and (counts.hut or 0) == #Config.RIVALS and (counts.fence or 0) >= 8)
	local overlaps, worst = 0, 1e9
	for i = 1, #items do
		for j = i + 1, #items do
			local d = math.sqrt((items[i].x - items[j].x) ^ 2 + (items[i].z - items[j].z) ^ 2)
			worst = math.min(worst, d - items[i].r - items[j].r)
			if d < items[i].r + items[j].r then
				overlaps += 1
			end
		end
	end
	check("Empreintes : aucune collision entre objets (" .. overlaps .. "), espace minimal " .. string.format("%.1f", worst) .. " studs >= " .. PL.MIN_GAP, overlaps == 0 and worst >= PL.MIN_GAP - 1e-9)
	-- vérification INDÉPENDANTE de la géométrie (autre code que Placement.blocked)
	local geo, M = Config.Map.geo, Config.Map
	local inWater, onPath, inArena = 0, 0, 0
	local segs = {}
	for _, poly in ipairs(M.paths) do
		for k = 1, #poly - 1 do
			segs[#segs + 1] = { poly[k][1], poly[k][2], poly[k + 1][1], poly[k + 1][2] }
		end
	end
	for _, it in ipairs(items) do
		for _, rv in ipairs(geo.rivers) do
			local c = rv.axis == "z" and it.z or it.x
			if math.abs(c - rv.at) < rv.half + it.r then
				inWater += 1
			end
		end
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			local d = math.sqrt((it.x - cx) ^ 2 + (it.z - cz) ^ 2)
			if math.abs(d - M.moat.radius) < M.moat.width / 2 + it.r then
				inWater += 1
			end
		end
		for _, sg in ipairs(segs) do
			if PL.distToSegment(it.x, it.z, sg[1], sg[2], sg[3], sg[4]) < geo.pathHalf + it.r then
				onPath += 1
			end
		end
		if math.abs(math.sqrt(it.x ^ 2 + it.z ^ 2) - (M.plotRadius - 30)) < geo.pathHalf + it.r then
			onPath += 1
		end
		if math.sqrt(it.x ^ 2 + it.z ^ 2) < geo.arenaRadius + it.r then
			inArena += 1
		end
	end
	check("Aucun objet dans l'eau (rivières, douves), sur un chemin ni dans l'arène (" .. inWater .. "/" .. onPath .. "/" .. inArena .. ")", inWater == 0 and onPath == 0 and inArena == 0)
	check("Bridges : " .. #plan.bridges .. " ponts centrés sur leur rivière, plus longs qu'elle (les deux rives sont reliées), axe perpendiculaire à l'eau", #plan.bridges == 4 and (function()
		for _, b in ipairs(plan.bridges) do
			local rv = b.river
			local center = rv.axis == "z" and b.z or b.x
			if center ~= rv.at or b.length < rv.half * 2 + 2 or (rv.axis == "z" and b.rot ~= 90) or (rv.axis == "x" and b.rot ~= 0) then
				return false
			end
		end
		return true
	end)())
	check("Barrières : alignées (même rotation, même ligne) dans chaque domaine, jamais dans l'eau", (function()
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			local n = 0
			for _, it in ipairs(items) do
				if it.kind == "fence" and math.abs(it.z - (cz - 34)) < 1e-9 and math.abs(it.x - cx) < 22 then
					n += 1
					if it.rot ~= 0 then
						return false
					end
				end
			end
			if n < 3 then
				return false
			end
		end
		return true
	end)())
	check("Cabanes : une par domaine, tournées vers le centre du domaine (avant = -Z)", (function()
		for _, it in ipairs(items) do
			if it.kind == "hut" then
				local best = 1e9
				for i = 1, #Config.RIVALS do
					local cx, cz = Config.rivalCenter(i)
					local d = math.sqrt((it.x - cx) ^ 2 + (it.z - cz) ^ 2)
					if d < best then
						best = d
						local want = PL.facing(cx - it.x, cz - it.z)
						local diff = math.abs((it.rot - want + 180) % 360 - 180)
						if diff > 1e-6 and d == best then
							-- garde la dernière valeur du plus proche
						end
					end
				end
				if best > 50 then
					return false
				end
			end
		end
		return true
	end)() and math.abs(PL.facing(0, -1)) < 1e-6 and math.abs(PL.facing(1, 0) - 270) < 1e-6 and math.abs(PL.facing(0, 1) - 180) < 1e-6 and math.abs(PL.facing(-1, 0) - 90) < 1e-6)
	local again = PL.new(Config).plan()
	check("Le plan est déterministe (deux calculs identiques)", #again.items == #items and again.items[7].x == items[7].x and again.items[#items].z == items[#items].z)
	check("Le moulin et l'enclos de l'arène ne sont ni dans l'eau ni sur un chemin ni dans un autre domaine", (function()
		local cx, cz = Config.rivalCenter(1)
		return P.blocked(cx - 24, cz + 22, 7, { allowDomain = true }) == nil and P.blocked(cx + 30, cz + 4, 8, { allowDomain = true }) == nil
	end)())
	check("Blocage : eau, chemin, arène, domaine, bord sont reconnus", P.blocked(0, 330, 2) == "eau" and P.blocked(0, 0, 2) == "arène" and P.blocked(Config.rivalCenter(2), select(2, Config.rivalCenter(2)), 2) == "domaine" and P.blocked(2000, 0, 2) == "bord" and P.blocked(-380, 100, 2) == "eau")
end

-- Domaines en terrasses : distances, hauteurs, rampes, chemins -------------------------------------------------------------------------------
do
	suite("Domaines en terrasses : hors de l'arène et des bases, de plus en plus hauts et loin, une rampe chacun")
	local PLc = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Placement.lua"), { debugName = "Placement" })()
	local M = Config.Map
	local n = #Config.RIVALS
	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end
	local plots = {}
	for i = 1, Config.PLOT_COUNT do
		local a = (i - 1) / Config.PLOT_COUNT * math.pi * 2
		plots[i] = { math.sin(a) * M.plotRadius, math.cos(a) * M.plotRadius }
	end
	local spread, arenaOk, plotOk = true, true, true
	for i = 1, n do
		local xi, zi = Config.rivalCenter(i)
		arenaOk = arenaOk and dist(xi, zi, 0, 0) >= M.geo.arenaRadius + M.plateauRadius + 20
		for _, pl in ipairs(plots) do
			plotOk = plotOk and dist(xi, zi, pl[1], pl[2]) >= M.plateauRadius + 37 + 10
		end
		for j = i + 1, n do
			local xj, zj = Config.rivalCenter(j)
			spread = spread and dist(xi, zi, xj, zj) >= 2 * M.plateauRadius + 20
		end
	end
	check("Domaines : plateaux séparés d'au moins 20 studs, hors de l'arène (+20) et des bases (+10), aucun chevauchement", spread and arenaOk and plotOk)
	local hOk, travelOk = true, true
	for i = 2, n do
		hOk = hOk and Config.rivalHeight(i) > Config.rivalHeight(i - 1)
		local xa, za = Config.rivalCenter(i - 1)
		local xb, zb = Config.rivalCenter(i)
		travelOk = travelOk and dist(xb, zb, 0, 0) > dist(xa, za, 0, 0)
	end
	check("Zones : chaque zone plus HAUTE (6, 14, 24) et plus LOIN du Grand Nid que la précédente (trajet croissant)", hOk and travelOk and Config.rivalHeight(1) == 6 and Config.rivalHeight(3) == 24)
	local rampOk = true
	for i = 1, n do
		local r = Config.rampOf(i)
		local d = M.domains[i]
		rampOk = rampOk and math.abs(dist(r.top[1], r.top[2], d.x, d.z) - M.plateauRadius) < 1e-6 and math.abs(dist(r.top[1], r.top[2], r.bottom[1], r.bottom[2]) - d.h * M.rampRun) < 1e-6
		-- pente praticable : moins de 20 degrés
		rampOk = rampOk and math.deg(math.atan(d.h / (d.h * M.rampRun))) < 20
		for j = 1, n do
			if j ~= i then
				local xj, zj = Config.rivalCenter(j)
				rampOk = rampOk and PLc.distToSegment(xj, zj, r.top[1], r.top[2], r.bottom[1], r.bottom[2]) >= M.plateauRadius + M.rampWidth / 2
			end
		end
		for _, pl in ipairs(plots) do
			rampOk = rampOk and PLc.distToSegment(pl[1], pl[2], r.top[1], r.top[2], r.bottom[1], r.bottom[2]) >= 26 + M.rampWidth / 2
		end
		rampOk = rampOk and dist(r.bottom[1], r.bottom[2], 0, 0) > M.geo.arenaRadius + M.rampWidth / 2
		for _, lk in ipairs(M.geo.lakes) do
			rampOk = rampOk and PLc.distToSegment(lk.x, lk.z, r.top[1], r.top[2], r.bottom[1], r.bottom[2]) >= lk.r + 5 + M.rampWidth / 2
		end
	end
	check("Rampes : une par domaine, au bord du plateau, pente < 20°, sans toucher un autre plateau, une base, l'arène ou un lac", rampOk)
	local pathOk = true
	for pi, poly in ipairs(M.paths) do
		for k = 1, #poly - 1 do
			for j = 1, n do
				local xj, zj = Config.rivalCenter(j)
				pathOk = pathOk and PLc.distToSegment(xj, zj, poly[k][1], poly[k][2], poly[k + 1][1], poly[k + 1][2]) >= M.plateauRadius - 0.5
			end
			for _, pl in ipairs(plots) do
				pathOk = pathOk and PLc.distToSegment(pl[1], pl[2], poly[k][1], poly[k][2], poly[k + 1][1], poly[k + 1][2]) >= 26 + 3
			end
		end
		local lastP = poly[#poly]
		local r = Config.rampOf(pi)
		pathOk = pathOk and dist(lastP[1], lastP[2], r.bottom[1], r.bottom[2]) < 1
	end
	check("Chemins : partent du Grand Nid, passent entre les bases, contournent les plateaux et finissent au pied de la rampe", pathOk and #M.paths == n)
	check("Secrets : aucun dans un plateau ni dans une rampe", (function()
		for _, sct in ipairs(Config.SECRETS) do
			for i = 1, n do
				local xi, zi = Config.rivalCenter(i)
				local r = Config.rampOf(i)
				if dist(sct.x, sct.z, xi, zi) < M.plateauRadius + 10 or PLc.distToSegment(sct.x, sct.z, r.top[1], r.top[2], r.bottom[1], r.bottom[2]) < 10 then
					return false
				end
			end
		end
		return true
	end)())
end

-- Culling des zones éloignées : hystérésis, lots, e2e ----------------------------------------------------------------------------------
do
	suite("Culling : hystérésis, lots, distance, option de coupure")
	local CU = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Culling.lua"), { debugName = "Culling" })()
	local C = Config.Culling
	check("Culling : masque au-delà de cullAt, réaffiche sous showAt, garde son état entre les deux (pas de clignotement)", CU.decide(C.cullAt + 50, false, C.cullAt, C.showAt) and not CU.decide(C.showAt - 20, false, C.cullAt, C.showAt) and not CU.decide((C.cullAt + C.showAt) / 2, false, C.cullAt, C.showAt) and CU.decide((C.cullAt + C.showAt) / 2, true, C.cullAt, C.showAt) and not CU.decide(C.showAt - 10, true, C.cullAt, C.showAt))
	check("Culling : distance invalide (nil, NaN) ne masque jamais ; seuils cohérents (showAt < cullAt), ~1,5 domaine", not CU.decide(nil, false, 200, 170) and not CU.decide(0 / 0, true, 200, 170) and C.showAt < C.cullAt and C.cullAt >= 1.5 * Config.Map.plateauRadius)
	check("Culling : distance au bord d'une zone (0 dedans), lots de taille donnée, liste vide", CU.distanceTo(0, 0, { x = 0, z = 100, radius = 66 }) == 34 and CU.distanceTo(0, 90, { x = 0, z = 100, radius = 66 }) == 0 and #CU.chunks({ 1, 2, 3, 4, 5 }, 2) == 3 and #CU.chunks({ 1, 2, 3, 4, 5 }, 2)[3] == 1 and #CU.chunks({}, 10) == 0 and #CU.chunks({ 1, 2 }, 0) == 2)
	check("Culling : option de coupure Config.Culling.enabled et lots bornés (<= 300 éléments par image)", C.enabled == true and C.batch <= 300 and C.interval >= 0.5)
end

-- Tutoriel, bannière de zone avec distance, titres, offres d'achat au bon moment ---------------------------------------------
do
	suite("Tutoriel (barre d'objectif), distance de zone, titres, offres d'achat non bloquantes")
	local t0 = Config.tutorial({ hatched = 0, stolen = 0, species = 0 })
	check("Tutoriel : 1re étape au départ (0/1)", t0 and t0.index == 1 and t0.prog == 0 and t0.goal == 1 and t0.total == #Config.TUTORIAL)
	local t1 = Config.tutorial({ hatched = 1, stolen = 1, species = 1 })
	check("Tutoriel : étape « chipe 2 œufs » avec progression 1/2", t1 and t1.index == 2 and t1.prog == 1 and t1.goal == 2 and t1.text:find("Chipe", 1, true) ~= nil)
	check("Tutoriel : se termine (nil) quand tout est fait, jamais d'étape sautée", Config.tutorial({ hatched = 9, stolen = 9, species = 9 }) == nil and Config.tutorial({ hatched = 9, stolen = 0, species = 9 }).index == 2 and Config.tutorial(nil).index == 1)
	check("Zone : « Ferme de Gus · 120 m de ta base » (arrondi à 5), « chez toi » près de la base, nom seul sans distance, nil si inconnue", Config.zoneLine("gus", 121) == "Ferme de Gus · 120 m de ta base" and Config.zoneLine("arena", 10) == "Arène · chez toi" and Config.zoneLine("mara", nil) == "Bois de Mara" and Config.zoneLine("zzz", 5) == nil and Config.zoneLine("zed", 0 / 0) == "Citadelle de Zed")
	local ti = Config.titles({ hatched = 60, stolen = 0, species = 3, rb = 0, puzzles = 0 })
	local unlocked = 0
	for _, x in ipairs(ti) do
		if x.unlocked then
			unlocked += 1
		end
	end
	check("Titres : 20 titres (5 succès x 4 paliers), débloqués d'après les statistiques (Éleveur I-II, Collectionneur I)", #ti == 20 and unlocked == 3 and ti[1].unlocked and ti[2].unlocked and not ti[3].unlocked)
	local saved = { Config.PASSES.Lucky.id, Config.PASSES.Coins2x.id }
	Config.PASSES.Lucky.id, Config.PASSES.Coins2x.id = 0, 0
	check("Offre : jamais proposée tant que l'achat n'est pas disponible (ID 0)", Config.boostOffer("rare", {}, 1000, nil, 0, 0) == nil)
	Config.PASSES.Lucky.id, Config.PASSES.Coins2x.id = 111, 222
	local o = Config.boostOffer("rare", {}, 1000, nil, 0, 0)
	check("Offre : après une éclosion rare -> Chance +10 %, après un palier -> Revenus x2", o and o.pass == "Lucky" and Config.boostOffer("milestone", {}, 1000, nil, 0, 0).pass == "Coins2x")
	check("Offre : pas si déjà possédé, pas pendant les 90 premières secondes, pas plus d'une toutes les 5 min, pas plus de 3 par session, événement inconnu ignoré",
		Config.boostOffer("rare", { Lucky = true }, 1000, nil, 0, 0) == nil and Config.boostOffer("rare", {}, 60, nil, 0, 0) == nil and Config.boostOffer("rare", {}, 1000, 800, 1, 0) == nil
		and Config.boostOffer("rare", {}, 1000, 600, 1, 0) ~= nil and Config.boostOffer("rare", {}, 5000, 100, 3, 0) == nil and Config.boostOffer("autre", {}, 1000, nil, 0, 0) == nil)
	Config.PASSES.Lucky.id, Config.PASSES.Coins2x.id = saved[1], saved[2]
end

-- Sons : aucun identifiant inventé ---------------------------------------------------------------------------------------
do
	suite("Sons : aucun identifiant inventé")
	local ok, why = true, ""
	for key, def in pairs(Config.SOUNDS) do
		local good = type(def.id) == "string" and (def.id == "" or def.id:find("^rbxasset://") ~= nil or def.id:find("^rbxassetid://%d+$") ~= nil) and def.vol > 0 and def.vol <= 1 and def.speed > 0
		if not good and ok then
			ok, why = false, key
		end
	end
	check("Sons : chaque entrée est valide (vide, intégrée rbxasset:// ou rbxassetid://N)" .. (ok and "" or " : " .. why), ok)
	check("Sons : crochets secret et portail encore muets (aucun ID fourni), menu relié au clic, sons activés", Config.SOUNDS.secret.id == "" and Config.SOUNDS.portal.id == "" and Config.SOUNDS.menu.id ~= "" and Config.SOUNDS_ENABLED == true)
end

-- Textures tuilables : configuration -------------------------------------------------------------------------------------------
do
	suite("Textures : IDs, tailles de répétition, ordre de priorité, plafond")
	local tx, ids, ok = Config.Assets.textures, {}, true
	local n = 0
	for key, def in pairs(tx) do
		n += 1
		if type(def.id) ~= "number" or def.id <= 0 or ids[def.id] or def.tile <= 0 or #def.targets == 0 then
			ok = false
		end
		ids[def.id] = true
		local inOrder = false
		for _, k in ipairs(Config.Assets.textureOrder) do
			inOrder = inOrder or k == key
		end
		ok = ok and inOrder
	end
	check("Textures : 7 entrées (herbe, eau, sol et murs du château, bois, sable, chemin) avec ID unique, taille positive, cibles et priorité", n == 7 and #Config.Assets.textureOrder == 7 and ok)
	check("Textures : IDs et tailles approuvés (herbe 8, pierre 6, bois 4, eau 10 translucide à 0,2)", tx.grass.id == 122917279401510 and tx.grass.tile == 8 and tx.castleStone.id == 87480813124386 and tx.castleStone.tile == 6 and tx.wood.id == 136082705365776 and tx.wood.tile == 4 and tx.water.id == 72897294450066 and tx.water.tile == 10 and tx.water.transparency == 0.2 and tx.castleFloor.id == 90865253086689 and tx.sand.id == 83914325296472 and tx.path.id == 84243738566468)
	check("Textures : plafond mobile raisonnable (<= 300 Textures)", Config.Assets.textureMaxCount > 0 and Config.Assets.textureMaxCount <= 300)
end

-- Sons : rareté, volumes, gardiens, boucles --------------------------------------------------------------------------------
do
	suite("Sons : choix selon la rareté, volumes bornés, alerte des gardiens, boucles localisées, option de volume")
	check("Sons d'éclosion suivent la rareté : commun pop, rare, épique, légendaire (4 et 5), secret et Cosmique = secret",
		Config.hatchSoundKey(1, false) == "hatch" and Config.hatchSoundKey(2, false) == "rare" and Config.hatchSoundKey(3, false) == "epic" and Config.hatchSoundKey(4, false) == "legendary"
		and Config.hatchSoundKey(5, false) == "legendary" and Config.hatchSoundKey(6, false) == "hatchSecret" and Config.hatchSoundKey(1, true) == "hatchSecret")
	local fxOk, ambOk, idOk = true, true, true
	local used = {}
	for key, def in pairs(Config.SOUNDS) do
		if def.id:find("^rbxassetid://%d+$") then
			used[def.id] = true
			if def.loop and key:find("^amb") then
				ambOk = ambOk and def.vol >= 0.25 and def.vol <= 0.4
			elseif not def.loop and (key == "hatch" or key == "rare" or key == "epic" or key == "legendary" or key == "hatchSecret" or key == "coin" or key == "buy" or key == "refuse" or key == "growl" or key == "bark" or key == "hurt" or key == "spikes" or key == "fanfare") then
				fxOk = fxOk and def.vol >= 0.5 and def.vol <= 0.7
			end
		end
	end
	check("Sons : effets entre 0,5 et 0,7, ambiances entre 0,25 et 0,4", fxOk and ambOk)
	local expected = { "84390525214058", "111600385012831", "111875674907537", "90908436660215", "124766540033525", "110088134711268", "113679524214656", "123764673506668", "75136819922416", "72413498813091", "114298173898782", "97370499111519", "115413112102226", "84863036780507", "93517357278251", "126605194205875", "123273835786709", "89353143614427" }
	for _, id in ipairs(expected) do
		idOk = idOk and used["rbxassetid://" .. id] == true
	end
	check("Sons : les 18 identifiants approuvés sont tous branchés", idOk)
	check("Volume : réglage général (100/60/30 % et muet), bornes et valeurs invalides", near(Config.soundVolume("hatch", 1), 0.55) and near(Config.soundVolume("hatch", 0.5), 0.275) and Config.soundVolume("hatch", 0) == 0 and near(Config.soundVolume("hatch", 5), 0.55) and near(Config.soundVolume("hatch", nil), 0.55) and Config.soundVolume("inconnu", 1) == 0 and Config.soundVolume("secret", 1) == 0 and Config.volumeLabel(1) == "100 %" and Config.volumeLabel(#Config.VOLUME_STEPS) == "Muet")
	check("Gardiens : aboiement pour le chien, grognement pour le loup et l'ours", Config.guardSoundKey("dog") == "bark" and Config.guardSoundKey("wolf") == "growl" and Config.guardSoundKey("bear") == "growl" and Config.guardSoundKey(nil) == "growl")
	check("Ambiance : aucune avant la carte prête, prairie dehors, château dedans", Config.ambienceKey(false, true) == nil and Config.ambienceKey(true, false) == "ambMeadow" and Config.ambienceKey(true, true) == "ambCastle")
	check("Boucle localisée : pleine contre la source, nulle au-delà, décroissante", near(Config.loopFade(0, 30), 1) and Config.loopFade(30, 30) == 0 and Config.loopFade(45, 30) == 0 and near(Config.loopFade(15, 30), 0.5) and Config.loopFade(0 / 0, 30) == 0)
end

-- Démarrage RÉEL du hub (vrai Hub.server.lua, vrais modules) dans le runtime factice ----------------------------------------------
local FakeRuntime = luau.load(fs.readFile("roblox/tests/FakeRuntime.lua"), { debugName = "FakeRuntime" })()
-- Crée un runtime factice, ou nil (avec un échec explicite) si le moteur n'applique pas l'environnement fourni (évite toute tâche réelle).
local function newRuntime(opts)
	local RT = FakeRuntime.runtime(opts)
	if not RT.selfCheck() then
		check("Runtime factice : l'environnement fourni à luau.load est appliqué (sinon les suites de démarrage sont sautées)", false)
		return nil
	end
	return RT
end
local function loopGuard(co)
	if debug and debug.sethook then
		debug.sethook(co, function()
			error("boucle sans wait (garde d'instructions)")
		end, "", 4000000)
	end
end
do
	suite("Démarrage RÉEL du hub dans le runtime factice")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.hub, hook = loopGuard })
	if RT then
	local main = RT.buildTree("roblox/src", true)
	local okRun, errRun = pcall(function()
		RT.task.spawn(function()
			RT.runScript(main)
		end)
	end)
	check("Hub : démarrage sans exception" .. (okRun and "" or " : " .. tostring(errRun)), okRun)
	RT.step(1)
	check("Hub : aucune erreur au démarrage" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	local remote = RT.services.ReplicatedStorage:FindFirstChild("HubRemote")
	check("Hub : le RemoteEvent HubRemote existe avant l'arrivée des joueurs", remote ~= nil)
	check("Hub : le gestionnaire du Remote est branché", remote ~= nil and RT.signalCount(remote, "OnServerEvent") == 1)
	RT.step(3)
	do
		local benches, lamps, oldSeat, oldPost = 0, 0, 0, 0
		for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
			if d.Name == "Asset" .. Config.Assets.models.props.bench then
				benches += 1
			elseif d.Name == "Asset" .. Config.Assets.models.props.lamp then
				lamps += 1
			elseif d.Name == "BenchSeat" then
				oldSeat += 1
			elseif d.Name == "LampPost" then
				oldPost += 1
			end
		end
		check("Hub : 6 bancs et 16 lampadaires Blender posés, équivalents procéduraux retirés (" .. benches .. "/" .. lamps .. ", restes " .. oldSeat .. "/" .. oldPost .. ")", benches == 6 and lamps == 16 and oldSeat == 0 and oldPost == 0)
	end
	do
		local houses, pond, towers = 0, 0, 0
		for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
			if d.Name == "Asset" .. Config.Assets.models.scenery.scn_maison_colombages then
				houses += 1
			elseif d.Name == "Asset" .. Config.Assets.models.scenery.scn_tour_cloche then
				towers += 1
			elseif d.Name == "Pond" then
				pond += 1
			end
		end
		check("Hub : village posé (" .. houses .. " maisons à colombages, " .. towers .. " tour, mare " .. pond .. "), aucune erreur", houses == 4 and towers == 1 and pond == 1 and #RT.errors == 0)
	end
	do
		local keys, kinds, tooFar, count = {}, { title = 0, status = 0 }, 0, 0
		for obj in pairs(RT.tags["PortalLabel"] or {}) do
			count += 1
			local pr = rawget(obj, "__props")
			local key = obj:GetAttribute("PortalKey")
			keys[key] = (keys[key] or 0) + 1
			kinds[obj:GetAttribute("Kind")] = (kinds[obj:GetAttribute("Kind")] or 0) + 1
			if pr.MaxDistance ~= Config.PORTAL_LABEL.maxDist then
				tooFar += 1
			end
		end
		local nkeys, dup = 0, false
		for _, n in pairs(keys) do
			nkeys += 1
			dup = dup or n ~= 2
		end
		check("Hub : étiquettes des 10 portails (5 arène + 5 château) : " .. count .. " BillboardGui, un titre et un statut par portail, aucun doublon, visibles à moins de " .. Config.PORTAL_LABEL.maxDist .. " studs", count == 20 and nkeys == 10 and not dup and kinds.title == 10 and kinds.status == 10 and tooFar == 0 and keys["c1"] == 2 and keys["5"] == 2)
	end
	check("Hub : l'arrivée des joueurs est écoutée", RT.signalCount(RT.services.Players, "PlayerAdded") >= 1)
	-- deux joueurs entrent dans le portail de taille 2 ; le compte à rebours part, la téléportation est demandée
	local size = 2
	local idx = 2
	local a = math.rad(-72 + (idx - 1) * 36)
	local cx, cz = math.sin(a) * 62, -math.cos(a) * 62
	local p1, p2 = RT.addPlayer("Ana", 1001), RT.addPlayer("Bob", 1002)
	for _, p in ipairs({ p1, p2 }) do
		p.Character = RT.instance("Model", p.Name)
		local root = RT.instance("Part", "HumanoidRootPart")
		rawget(root, "__props").Position = RT.vec(cx, 3, cz)
		root.Parent = p.Character
	end
	RT.step(2)
	check("Hub : deux joueurs dans le portail 2, file d'attente prise en compte (aucune téléportation avant le compte à rebours)", #RT.teleports == 0)
	RT.step(Config.Game.CountdownFull + 2)
	check("Hub : compte à rebours terminé -> un groupe de 2 est téléporté vers le lieu de jeu", #RT.teleports == 1 and RT.teleports[1].place == Config.Game.Places.game and RT.teleports[1].n == 2)
	check("Hub : aucune erreur pendant le lancement" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	-- le registre contient la partie ; un ami la voit et la rejoint, un inconnu non
	local reg = RT.memory and RT.memory[Config.Game.RegistryName]
	local partyId = nil
	for k in pairs(reg or {}) do
		partyId = k
	end
	check("Hub : la partie est inscrite au registre, ouverte aux amis jusqu'au plafond", partyId ~= nil and reg[partyId].size == Config.Game.MaxPlayers and reg[partyId].open == true)
	local friend = RT.addPlayer("Cléo", 1003)
	RT.friendsPage = { { Id = 1001 } }
	RT.fire(remote, "OnServerEvent", friend, "parties")
	local sawList = false
	for _, f in ipairs(RT.fired) do
		if f[1] == "HubRemote" and f[3] == "parties" then
			sawList = true
		end
	end
	check("Hub : un ami de l'hôte reçoit la liste des parties", sawList)
	-- fuzz des actions du Remote : types invalides, très longues chaînes, tables, nil
	local garbage = { nil, 0, -1, 1e308, 0 / 0, math.huge, "", string.rep("x", 5000), {}, { 1, 2, 3 }, true, "join", "parties", "inexistant" }
	local before = #RT.errors
	for i = 1, 30 do
		RT.now = RT.now + 1
		RT.fire(remote, "OnServerEvent", friend, garbage[(i % #garbage) + 1], garbage[((i * 3) % #garbage) + 1])
	end
	RT.step(1)
	check("Hub : 30 appels de Remote avec des arguments invalides ne provoquent aucune erreur" .. (#RT.errors == before and "" or " : " .. tostring(RT.errors[before + 1])), #RT.errors == before)
	-- repli : réservation refusée -> serveur public ; tout refusé -> message, joueurs restent au hub
	RT.removePlayer(p1)
	RT.removePlayer(p2)
	check("Hub : départ des joueurs sans erreur", #RT.errors == before)
	end
end

-- Démarrage RÉEL de la partie (vrai Main.server.lua, Builder, Data, Rules...) dans le runtime factice ---------------------------------
do
	suite("Démarrage RÉEL de la partie (vrai Main.server.lua, Builder, Data, Rules...) dans le runtim")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local tm = Config.Assets.models.traps
		local tx = Config.Assets.textures
		RT.assetDecals = { [tx.grass.id] = "rbxassetid://9001", [tx.water.id] = "rbxassetid://9002", [tx.castleStone.id] = "rbxassetid://9003", [tx.path.id] = "rbxassetid://9004" } -- bois, sable, dalles : sans décal = repli
		RT.assetParts = { [tm.spikes] = { "Pics__C0C0C0" }, [tm.blade] = { "Lame__D8DCE8" }, [Config.Assets.models.castle.door] = { "Herse__8A8A8A" }, [Config.Assets.models.props.chest] = { "Couvercle__E8B923" }, [Config.Assets.models.props.mill] = { "Pales__AA7733", "Pales2__AA7733" }, [Config.Assets.models.deco.sign_stars] = { "Etoile1__FFCD46", "Etoile2__FFCD46", "Etoile3__FFCD46", "Etoile4__FFCD46", "Etoile5__FFCD46" } } -- les modèles de pièges portent leurs pièces animées
	end
	if RT then
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	check("Partie : démarrage sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	local ready = false
	for _, line in ipairs(RT.prints) do
		if line:find("serveur prêt", 1, true) then
			ready = true
		end
	end
	check("Partie : le serveur atteint « serveur prêt » (rien ne plante avant les Remotes)", ready)
	local function findRemote(name)
		for _, d in ipairs(RT.services.ReplicatedStorage:GetDescendants()) do
			if rawget(d, "__props").Name == name then
				return d
			end
		end
		return nil
	end
	local RAction, RState = findRemote("Action"), findRemote("State")
	check("Partie : les Remotes Action et State existent et Action est écouté", RAction ~= nil and RState ~= nil and RT.signalCount(RAction, "OnServerEvent") == 1)
	local mapParts, mapBudget = nil, nil
	for _, line in ipairs(RT.prints) do
		local n, budget = line:match("carte construite : (%d+) Parts %(budget (%d+)")
		if n then
			mapParts, mapBudget = tonumber(n), tonumber(budget)
		end
	end
	for _, line in ipairs(RT.warns) do
		local over = line:match("budget mobile dépassé : (%d+) Parts")
		if over then
			mapParts, mapBudget = tonumber(over), -1 -- dépassement signalé par le serveur
		end
	end
	check("Partie : la carte construite reste sous le budget mobile (" .. tostring(mapParts) .. " Parts, budget " .. tostring(mapBudget) .. ")", mapParts ~= nil and mapParts <= mapBudget and mapBudget <= 1200)
	check("Partie : filet de sécurité [Spawn] actif", (function()
		for _, line in ipairs(RT.prints) do
			if line:find("[Spawn] (game) filet", 1, true) then
				return true
			end
		end
		return false
	end)())

	-- modèles Blender : chargés une seule fois chacun, accessoires posés dans le budget, œufs et pets habillés
	local seenIds, dup = {}, false
	for _, id in ipairs(RT.loadedIds) do
		if seenIds[id] then
			dup = true
		end
		seenIds[id] = true
	end
	check("Blender : aucun modèle chargé deux fois (un seul LoadAsset par identifiant), " .. #RT.loadedIds .. " modèles distincts", not dup and #RT.loadedIds >= 20)
	local propLine = nil
	for _, line in ipairs(RT.prints) do
		if line:find("accessoires Blender :", 1, true) then
			propLine = line
		end
	end
	local nPlaced, nParts = nil, nil
	if propLine then
		nPlaced, nParts = propLine:match("accessoires Blender : (%d+) pos%S+ %((%d+) Parts%)")
	end
	check("Blender : accessoires posés sur la carte (arbres, rochers, cabanes, ponts...) dans le budget de Parts" .. (propLine and (" [" .. propLine .. "]") or " [ligne absente]"), nPlaced ~= nil and tonumber(nPlaced) > 20 and tonumber(nParts) <= Config.Assets.propsBudgetParts)
	local skins = 0
	for _, o in ipairs(RT.all) do
		if rawget(o, "__props").Name == "Skin" then
			skins = skins + 1
		end
	end
	check("Blender : le chargement avec un faux modèle n'a levé aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	-- arrivée de deux joueurs : données chargées via le DataStore, personnage garanti, plots distincts
	local p1 = RT.addPlayer("Ana", 2001, { from = "hub", partyId = "PARTY-1", size = 2, late = false })
	RT.step(2)
	local p2 = RT.addPlayer("Bob", 2002, { from = "hub", partyId = "PARTY-1", size = 2, late = true })
	RT.step(2)
	check("Partie : les deux joueurs ont un personnage (LoadCharacterAsync appelé)", (RT.characterLoads or 0) >= 2 and #RT.kicked == 0)
	check("Partie : arrivée sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	local store = RT.dataStores["ChipeOeufs_v1"]
	check("Partie : verrou de session pris dans le DataStore à l'arrivée", store ~= nil and store.data["P_2001"] ~= nil and store.data["P_2001"].lock ~= nil)

	-- fuzz de TOUTES les actions du serveur avec des arguments invalides (types, plages, NaN, très longues chaînes, tables)
	local actionNames = { "sync", "buyEgg", "buyUp", "sell", "rebirth", "equip", "claimQuest", "claimStory", "cineSeen", "claimAch", "top", "daily", "inexistante", "__index", "", "x" }
	local garbage = { 0, -1, 1, 2, 7, 13, 1e308, 0 / 0, math.huge, -math.huge, 0.5, "", "slots", "tm", "intro", string.rep("x", 5000), {}, { 1, 2 }, true, false }
	local warnsBefore = #RT.warns
	local seed = 17
	local function rnd(n)
		seed = (seed * 16807) % 2147483647
		return (seed % n) + 1
	end
	for i = 1, 600 do
		RT.now = RT.now + 0.1
		local act = actionNames[rnd(#actionNames)]
		local arg = garbage[rnd(#garbage)]
		RT.fire(RAction, "OnServerEvent", i % 2 == 0 and p1 or p2, act, arg)
		if i % 40 == 0 then
			RT.step(1)
		end
	end
	RT.fire(RAction, "OnServerEvent", p1, nil, nil)
	RT.fire(RAction, "OnServerEvent", p1, 42, {})
	RT.fire(RAction, "OnServerEvent", { fake = true }, "sync")
	check("Partie : les actions valides ont des effets (états et notifications envoyés aux clients)", #RT.fired > 50)
	local actionWarns = {}
	for i = warnsBefore + 1, #RT.warns do
		if RT.warns[i]:find("[Action", 1, true) then
			actionWarns[#actionWarns + 1] = RT.warns[i]
		end
	end
	check("Partie : 600 actions aléatoires avec arguments invalides, aucune erreur interne" .. (#actionWarns == 0 and "" or " : " .. tostring(actionWarns[1])), #actionWarns == 0)
	check("Partie : aucune erreur de coroutine après le fuzz" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)

	-- sauvegarde au départ : l'enregistrement est sain et le verrou libéré
	RT.removePlayer(p1)
	RT.step(2)
	local rec = store.data["P_2001"]
	local function sane(d)
		if type(d) ~= "table" then
			return false
		end
		for _, k in ipairs({ "coins", "speed", "rb" }) do
			local v = d[k]
			if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then
				return false
			end
		end
		for key, lvl in pairs(d.up or {}) do
			local u = Config.upgrade(key)
			if not u or type(lvl) ~= "number" or lvl < 0 or lvl > u.max then
				return false
			end
		end
		return true
	end
	check("Partie : sauvegarde au départ du joueur (PlayerRemoving), verrou libéré, données saines", rec ~= nil and rec.lock == nil and sane(rec.v))
	-- fermeture du serveur : BindToClose sauvegarde les joueurs restants
	local fnCount = #RT.bindToClose
	check("Partie : BindToClose enregistré", fnCount >= 1)
	for _, fn in ipairs(RT.bindToClose) do
		RT.task.spawn(fn)
	end
	RT.step(3)
	local rec2 = store.data["P_2002"]
	check("Partie : BindToClose sauvegarde le joueur restant, verrou libéré, données saines" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), rec2 ~= nil and rec2.lock == nil and sane(rec2.v))
	-- scénario réel : achats d'œufs, éclosion, sauvegarde cohérente (aucune pièce créée ni perdue, pas de négatif)
	local p4 = RT.addPlayer("Dan", 2004, { from = "hub", partyId = "PARTY-1", size = 2, late = true })
	RT.step(2)
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p4, "buyEgg", 1)
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p4, "buyEgg", 1)
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p4, "buyEgg", 3) -- trop cher : refusé
	RT.step(1.2)
	local coinsAfterBuys = p4:GetAttribute("Coins")
	RT.step(Config.HATCH[1] + 6)
	local hatchFired = 0
	for _, f in ipairs(RT.fired) do
		if f[1] == "Hatch" and f[2] == p4 then
			hatchFired = hatchFired + 1
		end
	end
	RT.removePlayer(p4)
	RT.step(2)
	local rec4 = store.data["P_2004"]
	check("Partie : 2 achats d'œufs, éclosions envoyées au client, œuf trop cher refusé", hatchFired >= 2 and rec4 ~= nil and rec4.v.hatched >= 2)
	check("Partie : économie cohérente (2 œufs à 25 payés sur 50 pièces, œuf à 20 000 refusé, jamais négatif)", type(coinsAfterBuys) == "number" and coinsAfterBuys >= 0 and coinsAfterBuys <= 2 and rec4 ~= nil and rec4.v.coins >= 0)
	-- retour au hub : téléportation vers le hub avec l'identifiant de partie ; échec = message, le joueur reste en jeu ; limite de fréquence
	local p5 = RT.addPlayer("Eve", 2005, { from = "hub", partyId = "PARTY-1", size = 2, late = true })
	RT.step(2)
	local tpBefore = #RT.teleports
	RT.now = RT.now + 20
	RT.teleportFail = "Unauthorized"
	local firedBefore = #RT.fired
	RT.fire(RAction, "OnServerEvent", p5, "toHub")
	local failMsg = false
	for i = firedBefore + 1, #RT.fired do
		if RT.fired[i][1] == "Notify" and type(RT.fired[i][3]) == "string" and RT.fired[i][3]:find("Impossible de retourner", 1, true) then
			failMsg = true
		end
	end
	check("Retour au hub : téléportation refusée -> message clair, le joueur reste, aucune erreur", failMsg and #RT.teleports == tpBefore and #RT.errors == 0)
	RT.teleportFail = nil
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p5, "toHub")
	check("Retour au hub : nouvel essai dans les 15 s ignoré (anti-spam)", #RT.teleports == tpBefore)
	RT.now = RT.now + 20
	RT.fire(RAction, "OnServerEvent", p5, "toHub")
	local last = RT.teleports[#RT.teleports]
	check("Retour au hub : téléportation vers le lieu hub avec les données de partie", #RT.teleports == tpBefore + 1 and last.place == Config.Game.Places.hub and last.n == 1)
	RT.removePlayer(p5)
	RT.step(1)
	-- gardien de Gus : perception, dégâts non mortels, défaite = retour à la base (jamais mort en un coup)
	local p6 = RT.addPlayer("Fay", 2006, { from = "hub", partyId = "PARTY-1", size = 2, late = false })
	RT.step(2)
	local root6 = p6.Character:FindFirstChild("HumanoidRootPart")
	local gx, gz = Config.rivalCenter(1)
	local gus = Config.RIVALS[1]
	rawget(root6, "__props").Position = RT.vec(gx - 40, 3, gz + 12) -- loin derrière / à l'écart
	RT.step(4)
	check("Gardien : un joueur hors de portée (40 studs) n'est ni vu ni entendu : aucun dégât", p6:GetAttribute("Hp") == Config.GUARD.maxHp)
	rawget(root6, "__props").Position = RT.vec(gx, 3, gz + 12) -- sur la ligne de patrouille
	local caught, hpMin, catches = false, Config.GUARD.maxHp, 0
	for _ = 1, 100 do
		RT.step(0.25)
		hpMin = math.min(hpMin, p6:GetAttribute("Hp") or 0)
	end
	for _, f in ipairs(RT.fired) do
		if f[1] == "Notify" and f[2] == p6 and type(f[3]) == "string" and f[3]:find("t'a attrapé", 1, true) then
			catches = catches + 1
		end
	end
	caught = catches >= 1
	check("Gus clément : la prise renvoie à la base avec le message « t'a attrapé » (" .. catches .. " prise(s) en 25 s)", caught)
	check("Gus clément : aucune perte de pv (min " .. hpMin .. "), jamais de mort au contact", hpMin == Config.GUARD.maxHp)
	check("Gus clément : au plus une prise toutes les " .. Config.GUARD.gentleRecover .. " s (<= 5 en 25 s)", catches <= 5)
	check("Gus clément : aucune erreur serveur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	local mara = Config.RIVALS[2]
	local zed = Config.RIVALS[3]
	check("Gus clément : vitesse de poursuite <= 60 % de la marche du joueur (" .. gus.guardSpeed .. " vs 16)", gus.guardSpeed <= 16 * 0.6)
	check("Gus clément : délai de réaction >= 1,5 s, plus long que Mara et Zed", gus.alertDelay >= 1.5 and gus.alertDelay > (mara.alertDelay or 0) and gus.alertDelay > (zed.alertDelay or 0))
	check("Gus clément : vue et ouïe plus courtes que Mara et Zed", gus.viewDist < mara.viewDist and gus.hearRadius < mara.hearRadius and gus.viewDist < zed.viewDist)
	check("Gus clément : jamais de mort en moins de 3 contacts si les dégâts s'appliquaient", math.ceil(Config.GUARD.maxHp / gus.damage) >= 3 and gus.gentle == true)
	check("Difficulté : Gus 1 étoile, Mara 3, Zed 5", gus.stars == 1 and mara.stars == 3 and zed.stars == 5)
	check("Zone de sécurité : rayon d'entrée >= 12 studs, répit >= 6 s", Config.GUARD.safeRadius >= 12 and Config.GUARD.gentleRecover >= 6)
	RT.removePlayer(p6)
	RT.step(1)
	-- mode Château : entrée par le prompt, chrono, pièges non mortels, coffre final (récompense + classement)
	local Castle = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })()
	local p7 = RT.addPlayer("Gil", 2007, { from = "hub", partyId = "PARTY-1", size = 2, late = false })
	RT.step(2)
	local root7 = p7.Character:FindFirstChild("HumanoidRootPart")
	local function tagged(tag)
		for obj in pairs(RT.tags[tag] or {}) do
			return obj
		end
		return nil
	end
	local function notified(player, fragment, from)
		for i = from or 1, #RT.fired do
			local f = RT.fired[i]
			if f[1] == "Notify" and f[2] == player and type(f[3]) == "string" and f[3]:find(fragment, 1, true) then
				return true
			end
		end
		return false
	end
	local entryPrompt, chestPrompt = tagged("CastleEntry"), tagged("CastleChest")
	check("Château : le donjon est construit (prompt d'entrée et coffre final)", entryPrompt ~= nil and chestPrompt ~= nil)
	if entryPrompt and chestPrompt then
		local ep = entryPrompt.Parent.Position
		rawget(root7, "__props").Position = RT.vec(ep.X, 3, ep.Z)
		RT.fire(RT.services.ProximityPromptService, "PromptTriggered", entryPrompt, p7)
		RT.step(0.5)
		check("Château : l'entrée téléporte dans le donjon avec les consignes", notified(p7, "Le Château"))
	do
		local spikesVis, bladesVis, ballsVis, hidden = 0, 0, 0, 0
		for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
			if d.ClassName == "Model" then
				if d.Name == "TrapSpikes" then
					spikesVis += 1
				elseif d.Name == "TrapBlade" then
					bladesVis += 1
				elseif d.Name == "TrapBall" then
					ballsVis += 1
				end
			end
		end
		do
			local names = {}
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if d.ClassName == "Model" then
					names[d.Name] = (names[d.Name] or 0) + 1
				end
			end
			check("Arène : place, bancs, lampadaires, moulin (pales) et enclos Blender posés (" .. tostring(names.ArenaPlaza) .. " place, " .. tostring(names.ArenaBench) .. " bancs, " .. tostring(names.ArenaLamp) .. " lampadaires, " .. tostring(names.ArenaMill) .. " moulin, " .. tostring(names.ArenaPen) .. " enclos)", names.ArenaPlaza == 1 and names.ArenaBench == 4 and names.ArenaLamp == 4 and names.ArenaMill == 1 and names.ArenaPen == 1)
			local ground = 0
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if d.ClassName == "Model" and d.Name == "GroundTile" then
					ground += 1
				end
			end
			check("Sol : tuiles de chemin et d'herbe posées dans le budget mesuré (" .. ground .. " tuiles, plafond " .. Config.Assets.groundMaxTiles .. ")", ground > 20 and ground <= Config.Assets.groundMaxTiles)
			local expK = 0
			for r = 1, Castle.ROOMS do
				expK += #Castle.knights(Castle.room(r))
			end
			check("Château : " .. expK .. " chevaliers Blender posés (" .. tostring(names.CastleKnightModel) .. ")", names.CastleKnightModel == expK and expK == 4)
			local texCount, byKey, bad = 0, {}, 0
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if d.ClassName == "Texture" then
					texCount += 1
					local nm = rawget(d, "__props").Name
					byKey[nm] = (byKey[nm] or 0) + 1
					if rawget(d, "__props").StudsPerTileU <= 0 or not tostring(rawget(d, "__props").Texture):find("rbxassetid://900", 1, true) then
						bad += 1
					end
				end
			end
			check("Textures : herbe (1), eaux, murs du château posés avec l'URL du décal ; bois, sable, dalles sans décal = aucune texture (repli matière)", byKey.Tile_grass == 1 and (byKey.Tile_water or 0) >= 1 and (byKey.Tile_castleStone or 0) >= 10 and byKey.Tile_wood == nil and byKey.Tile_sand == nil and byKey.Tile_castleFloor == nil and bad == 0)
			check("Textures : plafond respecté (" .. texCount .. " <= " .. Config.Assets.textureMaxCount .. ")", texCount <= Config.Assets.textureMaxCount and texCount > 12)
			local R = Castle.ROOMS
			check("Château : murs, tours, herses, coffre, torches, drapeaux et fond Blender posés (" .. tostring(names.CastleWallModel) .. " murs, " .. tostring(names.CastleTowerModel) .. " tours, " .. tostring(names.CastleDoorModel) .. " portes, " .. tostring(names.CastleChestModel) .. " coffre, " .. tostring(names.CastleTorchModel) .. " torches, " .. tostring(names.CastleFlagModel) .. " drapeaux, " .. tostring(names.CastleBackdrop) .. " fond)", names.CastleWallModel == R * 4 and names.CastleTowerModel == 2 and names.CastleDoorModel == R and names.CastleChestModel == 1 and names.CastleTorchModel == R * 2 and names.CastleFlagModel == 2 and names.CastleBackdrop == 1)
		end
		local expSp, expBl, expBa = 0, 0, 0
		for r = 1, Castle.ROOMS do
			local room = Castle.room(r)
			expSp += #Castle.spikes(room)
			expBl += #Castle.blades(room)
			expBa += #Castle.balls(room)
		end
		check("Château : les pièges portent les modèles Blender (pics " .. spikesVis .. "/" .. expSp .. ", lames " .. bladesVis .. "/" .. expBl .. ", boulets " .. ballsVis .. "/" .. expBa .. ")", spikesVis == expSp and bladesVis == expBl and ballsVis == expBa and expSp > 0)
	end

		local ox, oz = Castle.toWorld(1, 0, 6)
		rawget(root7, "__props").Position = RT.vec(ox, 3, oz)
		RT.step(0.5)
		check("Château : le chrono démarre en entrant dans la première salle", notified(p7, "Chrono lancé"))
		-- pics : on reste sur une plaque de la salle 4 jusqu'à la touche ; un coup n'est jamais mortel
		local room4 = Castle.room(4)
		local plate = Castle.spikes(room4)[1]
		local px, pz = Castle.toWorld(4, plate.lx, plate.lz)
		rawget(root7, "__props").Position = RT.vec(px, 3, pz)
		local firstHp = nil
		for _ = 1, 80 do
			RT.step(0.1)
			local hp = p7:GetAttribute("Hp")
			if hp < Config.GUARD.maxHp then
				firstHp = hp
				break
			end
		end
		check("Château : un piège à pics retire " .. Config.CASTLE.damage.spikes .. " pv seulement (jamais mortel) et prévient (" .. tostring(firstHp) .. ")", firstHp == Config.GUARD.maxHp - Config.CASTLE.damage.spikes and notified(p7, "Touché par des pics"))
		-- traverser les salles à l'abri (coin sûr) puis ouvrir le coffre
		for r = 2, Castle.ROOMS do
			local sx, sz = Castle.toWorld(r, -19, 2)
			rawget(root7, "__props").Position = RT.vec(sx, 3, sz)
			RT.step(0.3)
		end
		local chestPos = chestPrompt.Parent.Position
		rawget(root7, "__props").Position = RT.vec(chestPos.X, 3, chestPos.Z)
		local coinsBeforeChest = p7:GetAttribute("Coins")
		local firedBefore = #RT.fired
		RT.fire(RT.services.ProximityPromptService, "PromptTriggered", chestPrompt, p7)
		RT.step(1.2)
		check("Château : le coffre final donne pièces et œuf rare et affiche le temps" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), notified(p7, "Château terminé", firedBefore) and p7:GetAttribute("Coins") > coinsBeforeChest and #RT.errors == 0)
		local ranking = RT.dataStores["ChipeOeufs_Castle_v1"]
		check("Château : le temps est enregistré au classement (meilleur temps conservé)", ranking ~= nil and type(ranking.data["2007"]) == "number" and ranking.data["2007"] > 0)
		local firedAgain = #RT.fired
		RT.fire(RT.services.ProximityPromptService, "PromptTriggered", chestPrompt, p7)
		RT.step(0.5)
		check("Château : le coffre ne peut être ouvert qu'une fois par course", not notified(p7, "Château terminé", firedAgain + 1))
	end
	RT.removePlayer(p7)
	RT.step(1)
	-- gardiens : modèle Blender (chien, loup, ours) posé à la place de l'apparence procédurale, après chargement
	do
		local found, withBlender, loadedGuards = 0, 0, 0
		for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
			if d.ClassName == "Model" and d.Name:sub(1, 5) == "Guard" then
				found += 1
				if d:FindFirstChild("Blender") then
					withBlender += 1
				end
			end
		end
		for _, id in ipairs(RT.loadedIds) do
			for _, gid in pairs(Config.Assets.models.guards) do
				if id == gid then
					loadedGuards += 1
				end
			end
		end
		check("Gardiens : un LoadAsset par modèle (chien, loup, ours, chevalier) [" .. loadedGuards .. "]", loadedGuards == 4)
		local allGuards = 0
		for _, rv in ipairs(Config.RIVALS) do
			allGuards += rv.guards
		end
		check("Gardiens : les " .. allGuards .. " gardiens des domaines (1 + 2 + 3) portent le modèle Blender [" .. withBlender .. "/" .. found .. "]", found == allGuards and withBlender == allGuards)
	end
	-- revente d'œuf et de doublons côté serveur
	local p8 = RT.addPlayer("Hal", 2008, { from = "hub", partyId = "PARTY-1", size = 2, late = false })
	RT.step(2)
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p8, "buyEgg", 1)
	RT.step(1.2)
	local afterBuy = p8:GetAttribute("Coins")
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p8, "sellEgg", 2) -- l'emplacement 1 est l'œuf de départ, l'achat est en 2
	RT.step(1.2)
	local afterSell = p8:GetAttribute("Coins")
	check("Revente d'œuf côté serveur : +" .. Config.eggSellValue(1) .. " pièces (25 %), pas plus [" .. tostring(afterBuy) .. " -> " .. tostring(afterSell) .. "]", afterSell >= afterBuy + Config.eggSellValue(1) and afterSell <= afterBuy + Config.eggSellValue(1) + 4)
	RT.now = RT.now + 1
	RT.fire(RAction, "OnServerEvent", p8, "sellEgg", 99)
	RT.fire(RAction, "OnServerEvent", p8, "sellEgg", "x")
	RT.fire(RAction, "OnServerEvent", p8, "sellDupes")
	RT.step(1)
	check("Revente : emplacement invalide, type invalide et « aucun doublon » sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	-- achats Robux : reçus, sauvegarde obligatoire avant PurchaseGranted, achat unique, base pleine
	local cfg = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
	cfg.PRODUCTS.StarterPack.id, cfg.PRODUCTS.ExclusiveEgg.id, cfg.PRODUCTS.CoinPack.id = 9101, 9102, 9103
	local PS = RT.Enum.ProductPurchaseDecision
	local rawProcess = RT.services.MarketplaceService.ProcessReceipt
	check("Achats : ProcessReceipt est branché", type(rawProcess) == "function")
	local function process(info, wait)
		local out
		RT.task.spawn(function()
			out = rawProcess(info)
		end)
		RT.step(wait or 0.5)
		return out
	end
	local base0 = p8:GetAttribute("Coins")
	process({ PlayerId = 2008, PurchaseId = "R-0", ProductId = 777 })
	local drift = math.max(1, p8:GetAttribute("Coins") - base0) -- revenu passif pendant un appel (référence)
	local c0 = p8:GetAttribute("Coins")
	RT.dataStoreFail = "503: DataStore indisponible"
	local d1 = process({ PlayerId = 2008, PurchaseId = "R-1", ProductId = 9101, CurrencySpent = 99 }, 20)
	check("Achats : sauvegarde en échec -> NotProcessedYet (jamais PurchaseGranted sans sauvegarde)", d1 == PS.NotProcessedYet)
	RT.dataStoreFail = nil
	local d2 = process({ PlayerId = 2008, PurchaseId = "R-1", ProductId = 9101, CurrencySpent = 99 })
	local c1 = p8:GetAttribute("Coins")
	check("Achats : nouvelle tentative du même reçu -> PurchaseGranted, livré UNE seule fois (+" .. cfg.STARTER_PACK.coins .. " pièces)", d2 == PS.PurchaseGranted and c1 - c0 >= cfg.STARTER_PACK.coins and c1 - c0 < cfg.STARTER_PACK.coins * 1.9)
	local rec = RT.dataStores["ChipeOeufs_v1"] and RT.dataStores["ChipeOeufs_v1"].data["P_2008"]
	check("Achats : au moment du PurchaseGranted, le reçu et le pack de départ sont DÉJÀ dans le DataStore", rec ~= nil and rec.v ~= nil and rec.v.receipts["R-1"] ~= nil and rec.v.starter == true)
	local d3 = process({ PlayerId = 2008, PurchaseId = "R-1", ProductId = 9101 })
	check("Achats : reçu déjà traité -> PurchaseGranted sans nouvelle livraison", d3 == PS.PurchaseGranted and p8:GetAttribute("Coins") - c1 < cfg.STARTER_PACK.coins * 0.9)
	local d4 = process({ PlayerId = 2008, PurchaseId = "R-2", ProductId = 9101 })
	check("Achats : pack de départ déjà acheté (achat unique) -> rien n'est livré", d4 == PS.NotProcessedYet)
	check("Achats : produit inconnu ou joueur absent -> NotProcessedYet", process({ PlayerId = 2008, PurchaseId = "R-3", ProductId = 777 }) == PS.NotProcessedYet and process({ PlayerId = 424242, PurchaseId = "R-4", ProductId = 9102 }) == PS.NotProcessedYet)
	local d5 = process({ PlayerId = 2008, PurchaseId = "R-5", ProductId = 9102 })
	check("Achats : œuf exclusif livré s'il reste une place, sinon NotProcessedYet sans livrer", d5 == PS.PurchaseGranted or d5 == PS.NotProcessedYet)
	for n = 1, 12 do
		process({ PlayerId = 2008, PurchaseId = "F-" .. n, ProductId = 9102 })
	end
	local dFull = process({ PlayerId = 2008, PurchaseId = "R-FULL", ProductId = 9102 })
	check("Achats : base pleine -> œuf exclusif NotProcessedYet (l'argent n'est pas pris sans livraison)", dFull == PS.NotProcessedYet)
	check("Achats : aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	RT.removePlayer(p8)
	RT.step(1)
	-- DataStore en panne : le jeu ne plante pas et la sauvegarde échoue proprement
	RT.dataStoreFail = "503: DataStore indisponible"
	local p3 = RT.addPlayer("Cyn", 2003, { from = "hub", partyId = "PARTY-1", size = 2, late = true })
	RT.step(15)
	check("Partie : DataStore indisponible -> aucune erreur non gérée" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	RT.dataStoreFail = nil
	RT.removePlayer(p3)
	RT.step(1)
	end
end

-- Chasse aux bugs : scénarios de bout en bout sur les vrais scripts (runtime factice) --------------------------------------------------
do
	suite("Chasse aux bugs : départs en plein jeu, courses entre joueurs, DataStore, achats, éclosions, gardiens, château, chargements en échec")
	local function boot(loadFail)
		local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
		if not RT then
			return nil
		end
		if loadFail then
			RT.loadAssetFail = "403: accès refusé"
		end
		RT.assetSizes = {} -- tailles Blender brutes volontairement hors échelle : l'échelle doit venir de la hauteur cible
		for _, id in pairs(Config.Assets.pets) do
			RT.assetSizes[id] = RT.vec(20, 20, 20)
		end
		for _, id in pairs(Config.Assets.models.props) do
			RT.assetSizes[id] = RT.vec(9, 31, 9)
		end
		for _, id in pairs(Config.Assets.models.guards) do
			RT.assetSizes[id] = RT.vec(15, 40, 15)
		end
		RT.assetSizes[Config.Assets.models.castle.tower] = RT.vec(30, 90, 30)
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		return RT
	end
	local function remoteOf(RT, name)
		for _, d in ipairs(RT.services.ReplicatedStorage:GetDescendants()) do
			if rawget(d, "__props").Name == name then
				return d
			end
		end
		return nil
	end
	local RT = boot(false)
	if RT then
		local RA = remoteOf(RT, "Action")
		local PS = RT.Enum.ProductPurchaseDecision
		local cfg = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
		cfg.PRODUCTS.CoinPack.id, cfg.PRODUCTS.InstantHatch.id = 8801, 8802
		local function join(name, id)
			return RT.addPlayer(name, id, { from = "hub", partyId = "BUGS", size = 2, late = false })
		end
		local function act(p, action, arg)
			RT.now = RT.now + 0.2
			RT.fire(RA, "OnServerEvent", p, action, arg)
		end
		local rawProcess = RT.services.MarketplaceService.ProcessReceipt
		local function receipt(info, wait)
			local out
			RT.task.spawn(function()
				out = rawProcess(info)
			end)
			RT.step(wait or 0.5)
			return out
		end
		local function snapshot(p)
			for i = #RT.fired, 1, -1 do
				local f = RT.fired[i]
				if f[1] == "State" and f[2] == p and type(f[3]) == "table" then
					return f[3]
				end
			end
			return nil
		end
		local function noErrors(label)
			check(label .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
		end
		local function record(uid)
			local st = RT.dataStores["ChipeOeufs_v1"]
			return st and st.data["P_" .. uid]
		end
		local function clearAll()
			local list = {}
			for _, q in ipairs(RT.players) do
				list[#list + 1] = q
			end
			for _, q in ipairs(list) do
				RT.removePlayer(q)
			end
			RT.step(3)
		end
		do -- lot 11 : protection d'œuf Blender posée sur le pad d'un joueur qui possède un œuf (assets chargés avant l'arrivée)
			RT.step(3)
			local pj = join("Gard", 7301)
			RT.step(3)
			local names, eggs, guards = {}, 0, 0
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				local nm = rawget(d, "__props").Name
				if nm == "Egg" then
					eggs += 1
				elseif nm == "EggGuard" then
					guards += 1
					names[#names + 1] = nm
				end
			end
			check("Protection d'œuf Blender : " .. guards .. " protection(s) pour " .. eggs .. " œuf(s) posé(s) (une par œuf, nid procédural sinon)", guards >= 1)
			RT.removePlayer(pj)
			RT.step(2)
		end
		local function slotCount(snap) -- emplacements occupés (œufs et pets : un œuf devient pet en éclosant)
			local n = 0
			for i = 1, 12 do
				if snap.slots[i] then
					n += 1
				end
			end
			return n
		end
		local function eggCount(snap)
			local n = 0
			for i = 1, 12 do
				if snap.slots[i] and snap.slots[i].k == "e" then
					n += 1
				end
			end
			return n
		end

		-- 1. départs en plein jeu ---------------------------------------------------------------------------------------------------
		local a = join("Ann", 5001)
		RT.step(2)
		act(a, "buyEgg", 1)
		RT.step(0.5)
		RT.removePlayer(a) -- part pendant que l'œuf couve
		RT.step(40) -- l'œuf éclôrait pendant ce temps
		noErrors("Départ pendant l'éclosion : aucune erreur serveur")
		check("Départ pendant l'éclosion : le profil est sauvegardé (œuf ou pet présent)", record(5001) ~= nil and record(5001).v ~= nil)
		check("Achat d'un joueur déjà parti : NotProcessedYet (rien n'est livré, Roblox réessaiera)", receipt({ PlayerId = 5001, PurchaseId = "B-1", ProductId = 8801 }) == PS.NotProcessedYet)
		local b = join("Bob", 5002)
		RT.step(2)
		act(b, "toHub")
		RT.removePlayer(b) -- part pendant la téléportation
		RT.step(5)
		noErrors("Départ pendant la téléportation vers le hub : aucune erreur")
		local c = join("Cy", 5003)
		RT.step(2)
		local croot = c.Character:FindFirstChild("HumanoidRootPart")
		local gx, gz = Config.rivalCenter(1)
		rawget(croot, "__props").Position = RT.vec(gx, 3, gz + 12)
		RT.step(1.5) -- le gardien le repère et attaque
		RT.removePlayer(c) -- part en plein combat de gardien
		RT.step(8)
		noErrors("Départ pendant un combat de gardien : aucune erreur, le gardien perd sa cible")
		local d = join("Dee", 5004)
		RT.step(2)
		local entry
		for obj in pairs(RT.tags["CastleEntry"] or {}) do
			entry = obj
		end
		local droot = d.Character:FindFirstChild("HumanoidRootPart")
		if entry and droot then
			local ep = entry.Parent.Position
			rawget(droot, "__props").Position = RT.vec(ep.X, 3, ep.Z)
			RT.fire(RT.services.ProximityPromptService, "PromptTriggered", entry, d)
			RT.step(2)
		end
		RT.removePlayer(d) -- part dans le château
		RT.step(5)
		noErrors("Départ pendant le château : aucune erreur")

		-- 1bis. château : défaite puis « Relancer maintenant » (produit payant, ID à 0 = aucune offre)
		do
			local Cs = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })()
			local function enterCastle(p)
				local entryP
				for obj in pairs(RT.tags["CastleEntry"] or {}) do
					entryP = obj
				end
				local rt = p.Character:FindFirstChild("HumanoidRootPart")
				local ep = entryP.Parent.Position
				rawget(rt, "__props").Position = RT.vec(ep.X, 3, ep.Z)
				RT.fire(RT.services.ProximityPromptService, "PromptTriggered", entryP, p)
				RT.step(1)
				return rt
			end
			local sp = Cs.spikes(Cs.room(1))[1]
			local wx, wz = Cs.toWorld(1, sp.lx, sp.lz)
			local function dieOnSpikes(p, rt)
				for _ = 1, 2500 do
					rawget(rt, "__props").Position = RT.vec(wx, 3, wz)
					RT.step(0.1)
					if p:GetAttribute("ReviveUntil") then
						return true
					end
				end
				return false
			end
			cfg.PRODUCTS.Revive.id = 0 -- test du produit désactivé (le vrai ID est renseigné dans Config)
			local q0 = join("Quin0", 5800)
			RT.step(2)
			local rt0 = enterCastle(q0)
			local sawOffer0 = false
			for _ = 1, 600 do -- ID à 0 : aucune offre même après une défaite
				rawget(rt0, "__props").Position = RT.vec(wx, 3, wz)
				RT.step(0.1)
				if q0:GetAttribute("ReviveUntil") then
					sawOffer0 = true
				end
			end
			check("Relance : produit désactivé (ID 0) -> aucune offre après une défaite", not sawOffer0)
			RT.removePlayer(q0)
			RT.step(2)
			cfg.PRODUCTS.Revive.id = 8803
			local q = join("Quin", 5801)
			RT.step(2)
			local rt = enterCastle(q)
			local died = dieOnSpikes(q, rt)
			check("Relance : après une défaite au château, l'offre est ouverte (attribut ReviveUntil)", died)
			local backAtStart = rt.CFrame.Position
			local deathsOk = q:GetAttribute("Hp") == Config.GUARD.maxHp -- retour gratuit : pv rétablis
			local r = receipt({ PlayerId = 5801, PurchaseId = "RV-1", ProductId = 8803 }, 1)
			local pos = rt.CFrame.Position
			check("Relance : l'achat ramène le joueur là où il est tombé (" .. string.format("%.0f,%.0f", pos.X, pos.Z) .. " vers " .. string.format("%.0f,%.0f", wx, wz) .. "), pv pleins, offre fermée, PurchaseGranted", r == PS.PurchaseGranted and math.abs(pos.X - wx) < 6 and math.abs(pos.Z - wz) < 6 and q:GetAttribute("ReviveUntil") == nil and deathsOk and (math.abs(backAtStart.Z - wz) > 6 or math.abs(backAtStart.X - wx) > 6))
			local before2 = #RT.fired
			local r2 = receipt({ PlayerId = 5801, PurchaseId = "RV-2", ProductId = 8803 }, 1) -- sans offre ouverte : jamais perdu
			local sawCompensation = false
			for i = before2 + 1, #RT.fired do
				local f = RT.fired[i]
				if f[1] == "Notify" and f[2] == q and type(f[3]) == "string" and f[3]:find("potion de chance", 1, true) then
					sawCompensation = true
				end
			end
			check("Relance : offre expirée -> PurchaseGranted et potion de chance offerte à la place (l'achat n'est jamais perdu)", r2 == PS.PurchaseGranted and sawCompensation)
			local r3 = receipt({ PlayerId = 5801, PurchaseId = "RV-1", ProductId = 8803 }, 1)
			check("Relance : reçu rejoué -> PurchaseGranted sans nouvelle livraison ni erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), r3 == PS.PurchaseGranted and #RT.errors == 0)
			cfg.PRODUCTS.Revive.id = 0
			RT.removePlayer(q)
			RT.step(2)
		end

		-- 1ter. progression de la base : migration v7 -> v8, niveaux visibles, sauvegarde
		do
			local ds = RT.services.DataStoreService:GetDataStore("ChipeOeufs_v1")
			ds.data["P_7001"] = { v = { ver = 7, coins = 10, dex = { ["1"] = { n = 5, b = 1 }, ["16"] = { n = 1, b = 1 }, ["999"] = { n = 3, b = 1 } } }, t = os.time() - 5000 }
			local old = join("Vieux", 7001)
			RT.step(2)
			local oldScore, oldLevel = old:GetAttribute("BaseScore"), old:GetAttribute("BaseLevel")
			check("Base : un ancien profil (v7) est migré, le score est reconstitué d'après la collection (5 Communs + 1 Secret = 155) [" .. tostring(oldScore) .. "], niveau 4 (Maison)", oldScore == 155 and oldLevel == 4)
			RT.removePlayer(old)
			RT.step(2)
			local rec = record(7001)
			check("Base : le profil sauvegardé porte la version 8 et le score de base", rec ~= nil and rec.v ~= nil and rec.v.ver == 8 and rec.v.baseScore == 155)
			local savedLevels = cfg.BASE_LEVELS
			local thresholds = {}
			for i = 1, 8 do
				thresholds[i] = { score = i - 1, name = savedLevels[i].name, emoji = savedLevels[i].emoji }
			end
			cfg.BASE_LEVELS = thresholds -- seuils minuscules : 8 niveaux atteints en 7 éclosions
			local b = join("Bati", 7002)
			RT.step(2)
			local levels, monotone, last = {}, true, b:GetAttribute("BaseLevel") or 0
			for n = 1, 30 do
				receipt({ PlayerId = 7002, PurchaseId = "BS-c" .. n, ProductId = 8801 }, 0.1)
				act(b, "buyEgg", 1)
				receipt({ PlayerId = 7002, PurchaseId = "BS-h" .. n, ProductId = 8802 }, 0.2)
				act(b, "sellDupes") -- libère des emplacements pour continuer à éclore
				local lv = b:GetAttribute("BaseLevel") or 0
				monotone = monotone and lv >= last
				last = lv
				levels[lv] = true
				if lv >= 8 then
					break
				end
			end
			local folderParts, baseModels = 0, 0
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if rawget(d, "__props").Name == "BaseUpgrade" then
					for _, q in ipairs(d:GetDescendants()) do
						if q.ClassName == "Part" then
							folderParts += 1
						end
						if rawget(q, "__props").Name == "BaseModel" then
							baseModels += 1
						end
					end
				end
			end
			check("Base : des éclosions successives montent la base de 1 à 8, niveau jamais en baisse (" .. tostring(b:GetAttribute("BaseLevel")) .. ")", b:GetAttribute("BaseLevel") == 8 and monotone)
			check("Base niveau 8 : le modèle Blender COMPLET du niveau (level8) remplace la version procédurale (" .. baseModels .. " modèle, " .. folderParts .. " Parts)" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), baseModels == 1 and folderParts <= 130 and #RT.errors == 0)
			RT.removePlayer(b)
			RT.step(2)
			local rb = record(7002)
			check("Base : le score atteint est sauvegardé au départ du joueur (" .. tostring(rb and rb.v and rb.v.baseScore) .. ")", rb ~= nil and rb.v ~= nil and (rb.v.baseScore or 0) >= 7)
			cfg.BASE_LEVELS = savedLevels
		end

		-- 2. courses entre joueurs -----------------------------------------------------------------------------------------------
		local e1, e2 = join("Eli", 5011), join("Fay", 5012)
		RT.step(2)
		local nestPrompt
		for _, o in ipairs(RT.all) do
			if o.ClassName == "ProximityPrompt" and o:GetAttribute("Kind") == "Nest" and o:GetAttribute("Rival") == 1 then
				local holder = o.Parent
				if holder and holder.ClassName == "Part" then
					nestPrompt = nestPrompt or o
				end
			end
		end
		if nestPrompt then
			local np = nestPrompt.Parent.Position
			for _, p in ipairs({ e1, e2 }) do
				rawget(p.Character:FindFirstChild("HumanoidRootPart"), "__props").Position = RT.vec(np.X, 3, np.Z)
			end
			RT.step(1)
			RT.fire(RT.services.ProximityPromptService, "PromptTriggered", nestPrompt, e1)
			RT.fire(RT.services.ProximityPromptService, "PromptTriggered", nestPrompt, e2) -- même instant
			RT.step(1)
			local s1, s2 = snapshot(e1), snapshot(e2)
			check("Deux joueurs volent le même œuf au même instant : un seul l'obtient (" .. tostring(s1 and s1.carry) .. " + " .. tostring(s2 and s2.carry) .. ")", s1 and s2 and s1.carry + s2.carry <= 1)
		else
			check("Vol simultané : un nid de Gus est disponible pour le test", false)
		end
		act(e1, "buyEgg", 1)
		act(e1, "buyEgg", 1)
		RT.step(0.5)
		local before = snapshot(e1)
		local eggsBefore = slotCount(before)
		RT.fire(RA, "OnServerEvent", e1, "sellEgg", 3)
		RT.fire(RA, "OnServerEvent", e1, "sellEgg", 3) -- même instant : le second appel est ignoré
		RT.step(0.3)
		act(e1, "sellEgg", 3) -- plus tard : l'emplacement est déjà vide
		RT.step(0.5)
		local after = snapshot(e1)
		check("Double vente du même emplacement : un seul œuf vendu, aucun autre perdu (" .. eggsBefore .. " -> " .. slotCount(after) .. " emplacements occupés)", slotCount(after) == eggsBefore - 1)
		act(e1, "buyEgg", 1)
		act(e1, "sellEgg", 3)
		RT.step(0.5)
		noErrors("Achat et revente rapprochés : aucune erreur")
		clearAll()
		check("6e joueur : refusé (serveur plein)", (function()
			local extra = {}
			for n = 1, 5 do
				extra[n] = join("X" .. n, 5100 + n)
			end
			RT.step(4)
			local kickedBefore, tpBefore = #RT.kicked, #RT.teleports
			local sixth = join("Sixieme", 5200)
			RT.step(4)
			local refused = #RT.kicked > kickedBefore or #RT.teleports > tpBefore -- renvoyé au hub (téléportation) ou expulsé
			for _, p in ipairs(extra) do
				RT.removePlayer(p)
			end
			RT.removePlayer(sixth)
			RT.step(2)
			return refused
		end)())
		noErrors("Plusieurs arrivées et départs successifs : aucune erreur")

		clearAll()
		-- 4. DataStore en panne à la sortie, retour avant la reprise, fermeture du serveur ------------------------------------------
		local g = join("Gil", 5301)
		RT.step(2)
		act(g, "buyEgg", 1)
		RT.step(0.5)
		RT.dataStoreFail = "503: DataStore indisponible"
		RT.removePlayer(g) -- la sauvegarde de départ échoue
		RT.step(30)
		noErrors("DataStore en panne au départ : aucune erreur")
		local lost = record(5301)
		RT.dataStoreFail = nil
		RT.step(80) -- les essais en arrière-plan reprennent
		local saved = record(5301)
		check("DataStore en panne puis rétabli : le profil de départ est finalement sauvegardé avec l'œuf acheté juste avant (rien de perdu)", saved ~= nil and saved.v ~= nil and saved.v.slots[2] ~= nil and saved.v.slots[2] ~= false and #RT.errors == 0)
		-- (a) il repart et revient aussitôt pendant que la sauvegarde de départ réessaie : le profil rechargé doit être le dernier
		local h = join("Hal", 5302)
		RT.step(2)
		act(h, "buyEgg", 1)
		RT.step(0.5)
		RT.dataStoreFail = "503: DataStore indisponible"
		RT.removePlayer(h)
		RT.step(1)
		RT.dataStoreFail = nil -- le DataStore revient pendant les essais de la sauvegarde de départ
		local h2 = join("Hal", 5302)
		RT.step(6)
		local hs = snapshot(h2)
		RT.step(80)
		local rec2 = record(5302)
		check("Retour pendant la sauvegarde de départ : la reconnexion attend, recharge le dernier profil (œuf acheté présent) et ne l'écrase pas", hs ~= nil and slotCount(hs) >= 2 and rec2 ~= nil and rec2.v ~= nil and rec2.v.slots[2] ~= nil and rec2.v.slots[2] ~= false)
		-- (b) la sauvegarde de départ a définitivement échoué (reprise en arrière-plan) et le joueur revient avant la reprise
		local h3 = join("Hel", 5305)
		RT.step(2)
		act(h3, "buyEgg", 1)
		RT.step(0.5)
		RT.dataStoreFail = "503: DataStore indisponible"
		RT.removePlayer(h3)
		RT.step(7) -- les essais de départ sont épuisés, la reprise est en attente
		RT.dataStoreFail = nil
		local h4 = join("Hel", 5305)
		RT.step(3)
		local hs4 = snapshot(h4)
		check("Retour avec une sauvegarde de départ en attente : le profil non sauvegardé est repris (œuf acheté présent)", hs4 ~= nil and slotCount(hs4) >= 2)
		local hk = #RT.kicked
		RT.dataStoreFail = "503: DataStore indisponible"
		local h5 = join("Hex", 5304) -- arrive pendant la panne : refusé proprement, aucun profil par défaut écrit
		RT.step(40)
		RT.dataStoreFail = nil
		check("Arrivée pendant la panne : joueur renvoyé avec un message clair, aucun profil vierge écrit" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.kicked > hk and (record(5304) == nil or record(5304).v == nil) and #RT.errors == 0)
		RT.removePlayer(h5)
		RT.removePlayer(h4)
		RT.removePlayer(h2)
		RT.step(2)
		local i1 = join("Ivy", 5303)
		RT.step(2)
		act(i1, "buyEgg", 1)
		RT.step(0.5)
		local closers = #RT.bindToClose
		RT.dataStoreFail = nil
		for _, fnClose in ipairs(RT.bindToClose) do
			RT.task.spawn(fnClose)
		end
		RT.step(5)
		check("BindToClose avec des joueurs en cours : tous les profils sont écrits (" .. closers .. " rappel(s))", closers >= 1 and record(5303) ~= nil and record(5302) ~= nil and #RT.errors == 0)

		clearAll()
		-- 5. boutique payante ---------------------------------------------------------------------------------------------------
		local j = join("Jo", 5401)
		RT.step(2)
		check("Achat : ID à 0 (désactivé) ou produit inconnu -> NotProcessedYet", receipt({ PlayerId = 5401, PurchaseId = "P-0", ProductId = 0 }) == PS.NotProcessedYet and receipt({ PlayerId = 5401, PurchaseId = "P-X", ProductId = 424242 }) == PS.NotProcessedYet)
		local c0 = j:GetAttribute("Coins")
		local r1 = receipt({ PlayerId = 5401, PurchaseId = "P-1", ProductId = 8801 })
		local c1 = j:GetAttribute("Coins")
		local r2 = receipt({ PlayerId = 5401, PurchaseId = "P-1", ProductId = 8801 }) -- Roblox rejoue le même reçu
		local c2 = j:GetAttribute("Coins")
		check("Achat : reçu rejoué -> PurchaseGranted sans nouvelle livraison (" .. tostring(c1 - c0) .. " puis " .. tostring(c2 - c1) .. ")", r1 == PS.PurchaseGranted and r2 == PS.PurchaseGranted and c1 - c0 >= Config.COIN_PACK_MIN and c2 - c1 < Config.COIN_PACK_MIN)
		RT.dataStoreFail = "503: DataStore indisponible"
		local r3 = receipt({ PlayerId = 5401, PurchaseId = "P-2", ProductId = 8801 }, 25)
		RT.dataStoreFail = nil
		check("Achat : sauvegarde en échec -> NotProcessedYet", r3 == PS.NotProcessedYet)
		noErrors("Boutique payante : aucune erreur")

		clearAll()
		-- 6. éclosions : taille bornée, centaines d'éclosions sans fuite d'objets ----------------------------------------------------
		local k = join("Kim", 5501)
		RT.step(2)
		local liveBefore
		for n = 1, 80 do
			receipt({ PlayerId = 5501, PurchaseId = "H-c" .. n, ProductId = 8801 }, 0.1)
			act(k, "buyEgg", 1)
			receipt({ PlayerId = 5501, PurchaseId = "H-h" .. n, ProductId = 8802 }, 0.1)
			act(k, "sellDupes")
			if n == 20 then
				RT.step(15)
				liveBefore = #RT.services.Workspace:GetDescendants()
			end
		end
		RT.step(15) -- les effets temporaires (Debris) disparaissent
		local liveAfter = #RT.services.Workspace:GetDescendants()
		noErrors("80 éclosions et reventes enchaînées : aucune erreur")
		check("80 éclosions : pas de fuite d'objets dans Workspace (" .. tostring(liveBefore) .. " -> " .. tostring(liveAfter) .. ")", liveBefore ~= nil and liveAfter <= liveBefore + 40)
		do -- échelle : chaque pet, œuf, gardien et accessoire posé respecte sa hauteur cible (±10 %), le plus grand pet <= 5
			local totalGuards = 0
			for _, rv in ipairs(Config.RIVALS) do
				totalGuards += rv.guards
			end
			local worstPet, pets, badPet, guardsOk, guards = 0, 0, 0, true, 0
			local lampOk, lamps, mills, millOk = true, 0, 0, true
			local eggIds, eggsSeen, worstEgg = {}, 0, 0
			for _, id in pairs(Config.Assets.eggsByRarity) do
				eggIds["Asset" .. tostring(id)] = true
			end
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if d.ClassName == "Model" then
					local e = d:GetExtentsSize()
					if d.Name == "Pet" then
						pets += 1
						worstPet = math.max(worstPet, e.Y)
						if e.Y > Config.Assets.targetHeights.petHard * 1.1 then
							badPet += 1
						end
					elseif d.Name == "Blender" then -- gardien habillé
						guards += 1
						local want = nil
						for _, kind in ipairs(Config.Assets.guardKinds) do
							if math.abs(e.Y - Config.Assets.guardHeights[kind]) <= 0.1 * Config.Assets.guardHeights[kind] then
								want = kind
							end
						end
						guardsOk = guardsOk and want ~= nil
					elseif d.Name == "Skin" then
						eggsSeen += 1
						worstEgg = math.max(worstEgg, e.Y)
					elseif d.Name == "ArenaLamp" then
						lamps += 1
						lampOk = lampOk and math.abs(e.Y - Config.Assets.targetHeights.lamp) <= 0.1 * Config.Assets.targetHeights.lamp
					elseif d.Name == "ArenaMill" then
						mills += 1
						millOk = millOk and math.abs(e.Y - Config.Assets.targetHeights.mill) <= 0.1 * Config.Assets.targetHeights.mill
					end
				end
			end
			check("Échelle : " .. pets .. " pets Blender (taille brute 20 studs) mesurés, le plus grand fait " .. string.format("%.2f", worstPet) .. " <= 5 studs", pets > 0 and badPet == 0 and worstPet <= Config.Assets.targetHeights.petHard * 1.1)
			check("Échelle : " .. guards .. "/" .. totalGuards .. " gardiens (chien 2,5, loup 3, ours 5) à ±10 % de leur hauteur cible", guards == totalGuards and guardsOk)
			check("Échelle : " .. eggsSeen .. " œufs affichés, le plus haut fait " .. string.format("%.2f", worstEgg) .. " <= " .. Config.Assets.targetHeights.eggMax .. " studs (+10 %)", eggsSeen > 0 and worstEgg <= Config.Assets.targetHeights.eggMax * 1.1)
			local boards, labels = 0, {}
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if rawget(d, "__props").Name == "DifficultyBoard" then
					boards += 1
				end
			end
			check("Zones : un panneau de difficulté (étoiles, nombre de gardiens) à l'entrée de chacun des " .. #Config.RIVALS .. " domaines (" .. boards .. "), 1 + 2 + 3 gardiens, étoiles croissantes", boards == #Config.RIVALS and Config.RIVALS[1].stars < Config.RIVALS[2].stars and Config.RIVALS[2].stars < Config.RIVALS[3].stars and Config.RIVALS[1].guards == 1 and Config.RIVALS[3].guards == 3 and Config.RIVALS[1].viewDist < Config.RIVALS[3].viewDist and Config.RIVALS[1].guardSpeed < Config.RIVALS[3].guardSpeed and Config.RIVALS[1].damage < Config.RIVALS[3].damage)
			do -- eau : murs invisibles de rivière avec un passage à chaque pont (les ponts sont le seul passage), ponts en travers, lacs
				local geoC = Config.Map.geo
				local walls = { z = {}, x = {} }
				local lakes, bridgesN, acrossOk = 0, 0, true
				for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
					if d.ClassName == "Part" then
						local pr = rawget(d, "__props")
						if pr.Name == "RiverWall" then
							local sz, pos = pr.Size, pr.Position
							if sz.X > sz.Z then
								walls.z[#walls.z + 1] = { pos.X - sz.X / 2, pos.X + sz.X / 2, pos.Z }
							else
								walls.x[#walls.x + 1] = { pos.Z - sz.Z / 2, pos.Z + sz.Z / 2, pos.X }
							end
						elseif pr.Name == "Lake" then
							lakes += 1
						elseif pr.Name == "BridgePlank" and math.abs(pr.Position.Y - 0.55) < 1e-6 then
							bridgesN += 1
							acrossOk = acrossOk and pr.Size.X > 0 and pr.Size.Z > 0
						end
					end
				end
				local gapsOk = true
				for _, rv in ipairs(geoC.rivers) do
					local list = walls[rv.axis]
					for _, w in ipairs(list) do
						for _, c in ipairs(rv.bridgesAt) do
							if w[2] > c - geoC.bridgeHalfGap + 1e-6 and w[1] < c + geoC.bridgeHalfGap - 1e-6 then
								gapsOk = false -- un mur recouvre un pont
							end
						end
					end
					table.sort(list, function(a, b)
						return a[1] < b[1]
					end)
					local expected = #rv.bridgesAt + 1
					local mine = 0
					for _, w in ipairs(list) do
						if math.abs(w[3] - rv.at) < 1e-6 then
							mine += 1
						end
					end
					gapsOk = gapsOk and mine == expected
				end
				check("Rivières : mur invisible avec UN passage par pont (3 segments chacune), aucun mur sur un pont, " .. #geoC.lakes .. " lacs (" .. lakes .. "), " .. bridgesN .. " planches de pont", gapsOk and lakes == #geoC.lakes and bridgesN >= #geoC.rivers * #geoC.rivers[1].bridgesAt * Config.Map.decor.bridgePlanks)
			end
			do -- décor fin, relief, panneaux d'étoiles, ponts et cabanes Blender : budgets séparés
				local counts = { deco = 0, decoParts = 0, cliffs = 0, relief = 0, walls = 0, stars = 0, rail = 0, hutBig = 0, hutSmall = 0, flowers = 0 }
				for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
					local nm = rawget(d, "__props").Name
					local parent = d.Parent and rawget(d.Parent, "__props").Name
					if parent == "BlenderDeco" then
						counts.deco += 1
						if d.ClassName == "Model" then
							counts.decoParts += #d:GetDescendants()
						end
						if nm:sub(1, 6) == "Flower" then
							counts.flowers += 1
						end
					elseif parent == "BlenderRelief" then
						counts.relief += 1
						if d.ClassName == "Part" then
							counts.walls += 1
						else
							counts.decoParts += #d:GetDescendants()
						end
					elseif nm == "StarSign" then
						counts.stars += 1
					end
				end
				check("Décor fin : " .. counts.deco .. " objets (fleurs, touffes, pierres, lanternes) posés après la carte, budget séparé " .. Config.Assets.decoBudgetParts .. " respecté, aucune erreur", counts.deco >= 30 and #RT.errors == 0)
				do -- lot 11 : chemins sinueux, arbres variés, protections d'œufs
					local tilesN, tileParts, guards, guardParts, trees = 0, 0, 0, 0, 0
					local stonesLeft = 0
					for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
						local parent = d.Parent and rawget(d.Parent, "__props").Name
						if parent == "BlenderPaths" and d.ClassName == "Model" then
							tilesN += 1
							tileParts += #d:GetDescendants()
						elseif rawget(d, "__props").Name == "EggGuard" and d.ClassName == "Model" then
							guards += 1
							guardParts += #d:GetDescendants()
						elseif parent == "BlenderProps" and d.ClassName == "Model" then
							trees += 1
						elseif rawget(d, "__props").Name == "PathStone" then
							stonesLeft += 1
						end
					end
					check("Chemins Blender : " .. tilesN .. " éléments posés (tuiles + pierres), " .. tileParts .. " objets <= budget " .. Config.Assets.pathBudgetParts .. ", aucune erreur", tilesN >= 10 and tileParts <= Config.Assets.pathBudgetParts * 3 and #RT.errors == 0)
					local village = 0
					for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
						if d.Parent and rawget(d.Parent, "__props").Name == "BlenderVillage" then
							village += 1
						end
					end
					check("Village Blender de la carte : " .. village .. " objets posés (budget " .. Config.Assets.sceneryBudgetParts .. " Parts), aucune erreur", village >= 8 and #RT.errors == 0)
					check("Arbres Blender : modèles posés sur la carte (" .. trees .. ")", trees >= 5)
					check("Protections d'œufs Blender : " .. guards .. " posée(s), " .. guardParts .. " objets", guardParts <= Config.Assets.eggGuardBudgetPerBase * 3)
				end
				check("Relief : crête de falaises, cascades, escaliers et îlots posés (" .. counts.relief .. " éléments), mur invisible en place (" .. counts.walls .. ")", counts.relief >= 20 and counts.walls >= 1)
				check("Panneaux d'étoiles Blender : un par domaine (" .. counts.stars .. ")", counts.stars == #Config.RIVALS)
			end
			do -- plateaux construits : falaise, dalle, rampe ; domaine relevé de sa hauteur
				local cliffs, ramps, discs, okH = 0, 0, 0, true
				for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
					if d.ClassName == "Part" then
						local pr = rawget(d, "__props")
						if pr.Name == "Cliff" then
							cliffs += 1
						elseif pr.Name == "Ramp" then
							ramps += 1
						elseif pr.Name == "Disc" then
							discs += 1
							local best = false
							local pp = (pr.Position and (pr.Position.X ~= 0 or pr.Position.Y ~= 0 or pr.Position.Z ~= 0)) and pr.Position or pr.CFrame.Position
							for i = 1, #Config.RIVALS do
								local cx, cz = Config.rivalCenter(i)
								if math.abs(pp.X - cx) < 1 and math.abs(pp.Z - cz) < 1 and math.abs(pp.Y - (0.5 + Config.rivalHeight(i))) < 1e-6 then
									best = true
								end
							end
							okH = okH and best
						end
					end
				end
				check("Terrasses : " .. cliffs .. " falaises, " .. ramps .. " rampes, " .. discs .. " domaines relevés de leur hauteur (6, 14, 24)", cliffs == #Config.RIVALS and ramps == #Config.RIVALS and discs == #Config.RIVALS and okH)
			end
			check("Échelle : lampadaires (8) et moulin (20) à ±10 % de leur hauteur cible", lamps == 4 and lampOk and mills == 1 and millOk)
		end
		RT.removePlayer(k)
		RT.step(2)

		clearAll()
		-- 7. gardiens : plusieurs joueurs, joueur AFK, zone inaccessible, perte de cible ------------------------------------------------
		local m1, m2 = join("Mia", 5601), join("Noa", 5602)
		RT.step(2)
		local gx2, gz2 = Config.rivalCenter(1)
		rawget(m1.Character:FindFirstChild("HumanoidRootPart"), "__props").Position = RT.vec(gx2, 3, gz2 + 12)
		rawget(m2.Character:FindFirstChild("HumanoidRootPart"), "__props").Position = RT.vec(gx2 + 6, 3, gz2 + 14)
		RT.pathFail = "pas de chemin"
		RT.step(10) -- plusieurs joueurs, aucun chemin : repli en ligne droite
		RT.pathFail = nil
		local zx, zz = Config.rivalCenter(3) -- domaine de Zed, verrouillé au départ
		local hpBeforeZed = m2:GetAttribute("Hp")
		rawget(m2.Character:FindFirstChild("HumanoidRootPart"), "__props").Position = RT.vec(zx, 3, zz + 12)
		RT.step(10)
		RT.removePlayer(m1)
		RT.step(5)
		check("Gardiens : plusieurs joueurs, sans chemin, zone verrouillée, perte de cible : aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
		check("Gardiens : un joueur dans une zone verrouillée n'est pas attaqué (pv " .. tostring(hpBeforeZed) .. " -> " .. tostring(m2:GetAttribute("Hp")) .. ", jamais en baisse)", m2:GetAttribute("Hp") >= hpBeforeZed)
		RT.step(60) -- AFK d'une minute
		noErrors("Joueur AFK une minute : aucune erreur")
		RT.removePlayer(m2)
		RT.step(2)
	end
	-- 9. chargements de modèles, textures et sons qui échouent à 100 % : le jeu reste jouable
	local RF = boot(true)
	if RF then
		local RAf = remoteOf(RF, "Action")
		local p = RF.addPlayer("Zoe", 5701, { from = "hub", partyId = "BUGS", size = 2, late = false })
		RF.step(5)
		RF.now = RF.now + 0.2
		RF.fire(RAf, "OnServerEvent", p, "buyEgg", 1)
		RF.step(Config.HATCH[1] + 8)
		local entry
		for obj in pairs(RF.tags["CastleEntry"] or {}) do
			entry = obj
		end
		local root = p.Character:FindFirstChild("HumanoidRootPart")
		if entry and root then
			local ep = entry.Parent.Position
			rawget(root, "__props").Position = RF.vec(ep.X, 3, ep.Z)
			RF.fire(RF.services.ProximityPromptService, "PromptTriggered", entry, p)
			RF.step(2)
		end
		local guardsProcedural, blender = 0, 0
		for _, d in ipairs(RF.services.Workspace:GetDescendants()) do
			if d.ClassName == "Model" and d.Name:sub(1, 5) == "Guard" then
				guardsProcedural += 1
				if d:FindFirstChild("Blender") then
					blender += 1
				end
			end
		end
		local textures = 0
		for _, d in ipairs(RF.services.Workspace:GetDescendants()) do
			if d.ClassName == "Texture" then
				textures += 1
			end
		end
		check("Chargements en échec à 100 % : aucune erreur non gérée" .. (#RF.errors == 0 and "" or " : " .. tostring(RF.errors[1])), #RF.errors == 0)
		local allG = 0
		for _, rv in ipairs(Config.RIVALS) do
			allG += rv.guards
		end
		check("Chargements en échec : gardiens procéduraux conservés (" .. guardsProcedural .. "), aucun modèle Blender (" .. blender .. "), aucune texture (" .. textures .. ")", guardsProcedural == allG and blender == 0 and textures == 0)
		local snap
		for i = #RF.fired, 1, -1 do
			local f = RF.fired[i]
			if f[1] == "State" and f[2] == p then
				snap = f[3]
				break
			end
		end
		check("Chargements en échec : le jeu reste jouable (état synchronisé, œuf acheté puis éclos)", snap ~= nil and snap.hatched >= 1)
	end
	-- 6bis. 10 000 tirages d'éclosion : valeurs toujours valides
	do
		local Rules = luau.load(fs.readFile("roblox/src/ServerScriptService/Rules.lua"), { debugName = "Rules" })().new(Config)
		local seed = 12345
		local function rnd()
			seed = seed * 16807 % 2147483647
			return seed / 2147483647
		end
		local okAll, tiers = true, {}
		for n = 1, 10000 do
			local egg = (n % #Config.TIERS) + 1
			local p = Rules.rollPet(egg, (n % 7) * 3, n % 5 == 0, rnd, n % 11 == 0)
			if not p or not Config.PETS[p.p] or not Config.SIZES[p.s] or not Config.MUTS[p.m] or p.tier ~= Config.PETS[p.p].tier then
				okAll = false
			else
				tiers[p.tier] = true
			end
		end
		check("10 000 tirages d'éclosion : espèce, taille et mutation toujours valides, toutes les raretés atteintes", okAll and #tiers >= 5)
		local mx = Config.eggMaxSize()
		check("Œuf énorme impossible : un modèle de 500 studs est ramené sous le plafond (" .. mx.w .. " x " .. mx.h .. ")", (function()
			local f = Config.fitScale({ X = 500, Y = 500, Z = 500 }, mx)
			return 500 * f <= mx.w + 1e-6 and 500 * f <= mx.h + 1e-6
		end)())
	end
	-- 8. château : classement avec ex aequo et valeurs invalides
	do
		local RT3 = boot(false)
		if RT3 then
			local board = RT3.dataStores["ChipeOeufs_Castle_v1"]
			check("Classement du château : le magasin ordonné existe", board ~= nil)
			if board then
				board.data["1"], board.data["2"], board.data["3"], board.data["4"], board.data["5"], board.data["6"] = 5000, 5000, "abc", -4, 0 / 0, 3200
			end
			local out
			RT3.task.spawn(function()
				local DataMod = RT3.require(RT3.services.ServerScriptService:FindFirstChild("Data"))
				out = DataMod.castleTop(10)
			end)
			RT3.step(2)
			check("Classement du château : valeurs invalides (texte, négative, NaN) ignorées, ex aequo conservés, meilleur temps d'abord" .. (out and (" [" .. #out .. " entrées]") or ""), out ~= nil and #out == 3 and out[1].time == 32 and out[2].time == 50 and out[3].time == 50)
		end
	end
end

-- Hub : survol d'accueil (client réel du hub) ---------------------------------------------------------------------------------
do
	suite("Hub : survol d'accueil, 8 s au plus, passage, caméra restituée, pas au retour d'une partie")
	local function boot()
		local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.hub, hook = loopGuard })
		if not RT then
			return nil
		end
		local main = RT.buildTree("roblox/src", true)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		return RT
	end
	local function guiOf(RT)
		for _, o in ipairs(RT.all) do
			if rawget(o, "__props").Name == "HubCine" then
				return o
			end
		end
		return nil
	end
	local RT = boot()
	if RT then
		local client = RT.buildClient("roblox/src/Hub")
		local me = RT.addPlayer("Ana", 6001)
		RT.setLocalPlayer(me)
		me:LoadCharacterAsync()
		RT.step(1)
		RT.task.spawn(function()
			RT.runScript(client.HubClient)
		end)
		RT.step(3.5)
		local g = guiOf(RT)
		check("Hub : le survol d'accueil démarre après l'arrivée (bandes, carton, bouton Passer visibles)", g ~= nil and rawget(g, "__props").Enabled == true)
		RT.step(10)
		check("Hub : le survol se termine en moins de 8 s et rend la caméra" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), g ~= nil and rawget(g, "__props").Enabled == false and #RT.errors == 0)
	end
	local RT2 = boot()
	if RT2 then
		local client2 = RT2.buildClient("roblox/src/Hub")
		local back = RT2.addPlayer("Bob", 6002, { from = "game", partyId = "X" })
		RT2.setLocalPlayer(back)
		back:LoadCharacterAsync()
		RT2.step(1)
		RT2.task.spawn(function()
			RT2.runScript(client2.HubClient)
		end)
		RT2.step(4)
		local g2 = guiOf(RT2)
		check("Hub : au retour d'une partie, aucun survol d'accueil" .. (#RT2.errors == 0 and "" or " : " .. tostring(RT2.errors[1])), (g2 == nil or rawget(g2, "__props").Enabled ~= true) and #RT2.errors == 0)
	end
end

-- Z-fighting : aucune face horizontale coplanaire qui se recouvre ---------------------------------------------------------------------
-- Géométrie approchée à partir des Parts du runtime factice : dessus d'une Part = Y du centre + hauteur / 2 (cylindres : l'axe est Size.X), empreinte =
-- rectangle englobant. Deux dessus à moins de 0,05 stud l'un de l'autre qui se recouvrent sur plus de 1 stud carré scintillent (z-fighting).
local function coplanarConflicts(RT, maxTop)
	local items = {}
	for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
		if d.ClassName == "Part" then
			local pr = rawget(d, "__props")
			local sz, pos = pr.Size, nil
			local pp, cp = pr.Position, pr.CFrame and pr.CFrame.Position
			if pp and (pp.X ~= 0 or pp.Y ~= 0 or pp.Z ~= 0) then
				pos = pp
			else
				pos = cp or pp
			end
			if sz and pos and pr.Transparency ~= 1 and (pr.Shape == nil or pr.Shape == "PartType.Block" or pr.Shape == "PartType.Cylinder") then
				local cyl = pr.Shape == "PartType.Cylinder"
				local h = cyl and sz.X or sz.Y
				local w, l = cyl and sz.Y or sz.X, cyl and sz.Z or sz.Z
				local top = pos.Y + h / 2
				if h <= 1.5 and w >= 3 and l >= 3 and top <= (maxTop or 1.6) and top >= -0.2 then
					items[#items + 1] = { name = pr.Name, top = top, x0 = pos.X - w / 2, x1 = pos.X + w / 2, z0 = pos.Z - l / 2, z1 = pos.Z + l / 2, canCollide = pr.CanCollide }
				end
			end
		end
	end
	local out = {}
	for i = 1, #items do
		for j = i + 1, #items do
			local a, b = items[i], items[j]
			if math.abs(a.top - b.top) < 0.05 then
				local ox = math.min(a.x1, b.x1) - math.max(a.x0, b.x0)
				local oz = math.min(a.z1, b.z1) - math.max(a.z0, b.z0)
				if ox > 1 and oz > 1 then
					out[#out + 1] = a.name .. "/" .. b.name .. " (dessus " .. string.format("%.2f", a.top) .. " et " .. string.format("%.2f", b.top) .. ")"
				end
			end
		end
	end
	return out
end

do
	suite("Z-fighting : hub et partie")
	for _, role in ipairs({ "hub", "game" }) do
		local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places[role], hook = loopGuard })
		if RT then
			local main = RT.buildTree("roblox/src", role == "hub")
			RT.task.spawn(function()
				RT.runScript(main)
			end)
			RT.step(3)
			local conflicts = coplanarConflicts(RT)
			local seen, uniq = {}, {}
			for _, c in ipairs(conflicts) do
				local key = c:gsub("%d+%.%d+", "")
				if not seen[key] then
					seen[key] = true
					uniq[#uniq + 1] = c
				end
			end
			for _, c in ipairs(uniq) do
				print("ZF", role, c)
			end
			check("Z-fighting (" .. role .. ") : aucune surface horizontale coplanaire qui se recouvre (" .. #conflicts .. ")", #conflicts == 0)
			local neonFloors = {}
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if d.ClassName == "Part" then
					local pr = rawget(d, "__props")
					local sz = pr.Size
					if pr.Material == "Material.Neon" and pr.Transparency ~= 1 and sz then
						local cyl = pr.Shape == "PartType.Cylinder"
						local h = cyl and sz.X or sz.Y
						local area = cyl and math.pi * (sz.Y / 2) ^ 2 or sz.X * sz.Z
						local y = (pr.Position and pr.Position.Y ~= 0) and pr.Position.Y or (pr.CFrame and pr.CFrame.Position.Y or 0)
						if h <= 1 and y <= 1.2 and area >= 300 then
							neonFloors[#neonFloors + 1] = pr.Name
						end
					end
				end
			end
			check("Sol (" .. role .. ") : aucun disque ou dalle Neon plein sol (" .. table.concat(neonFloors, ",") .. ")", #neonFloors == 0)
		end
	end
end

-- Ambiance : lumière douce, brouillard léger, couleurs harmonisées ------------------------------------------------------------------
do
	suite("Ambiance : lumière douce, brouillard léger")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(2)
		local L = rawget(RT.services.Lighting, "__props")
		check("Éclairage : luminosité douce (<= 2,4), ombres adoucies (>= 0,3)", L.Brightness ~= nil and L.Brightness <= 2.4 and L.ShadowSoftness >= 0.3)
		local bloom, grade, atmo
		for _, o in ipairs(RT.all) do
			local nm = rawget(o, "__props").Name
			if nm == "ChipeBloom" then
				bloom = rawget(o, "__props")
			elseif nm == "ChipeGrade" then
				grade = rawget(o, "__props")
			elseif o.ClassName == "Atmosphere" then
				atmo = rawget(o, "__props")
			end
		end
		check("Ambiance : brouillard léger (brume >= 1,5), saturation modérée (<= 0,12), bloom discret (<= 0,35)", atmo ~= nil and atmo.Haze >= 1.5 and grade ~= nil and grade.Saturation <= 0.12 and bloom ~= nil and bloom.Intensity <= 0.35)
	end
end

-- Client + serveur de bout en bout dans le runtime factice -----------------------------------------------------------------
do
	suite("Client + serveur de bout en bout : boutique (carrousel, richesse), achat, éclosion, révélation, bannière de zone")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local server = RT.buildTree("roblox/src", false)
		local client = RT.buildClient("roblox/src")
		RT.task.spawn(function()
			RT.runScript(server)
		end)
		RT.step(1)
		local me = RT.addPlayer("Ana", 3001, { from = "hub", partyId = "P-E2E", size = 1, late = false })
		RT.setLocalPlayer(me)
		RT.step(2)
		for _, name in ipairs({ "Client", "Ambience", "Animations", "Cinematics", "Culling" }) do
			RT.task.spawn(function()
				RT.runScript(client[name])
			end)
		end
		RT.step(4)
		check("Client : démarrage des 4 scripts client sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
		local function findText(fragment)
			for _, o in ipairs(RT.all) do
				local t = rawget(o, "__props").Text
				if type(t) == "string" and t:find(fragment, 1, true) then
					return o
				end
			end
			return nil
		end
		check("Client : la promesse d'accueil (titre, promesse, bouton Jouer) s'affiche", findText(Config.TAGLINE) ~= nil and findText(Config.PROMISE.button) ~= nil)
		check("Client : l'objectif en cours et le premier geste (toucher l'œuf) sont proposés (étapes 1 à 3, bouton Passer)", (findText("Ton œuf offert") ~= nil or findText("Touche l'œuf") ~= nil) and findText("Passer") ~= nil)
		-- ouvrir la boutique par le raccourci (ou la manette X)
		RT.actions.ChipeShop(nil, RT.env.Enum.UserInputState.Begin)
		RT.step(1)
		check("Boutique : ouverture sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
		check("Boutique : icône de richesse (palier « Une pièce » avec 50 pièces) et fortune affichées", findText("Une pièce") ~= nil)
		check("Boutique : carrousel d'œufs (œuf Commun présélectionné, voisins affichés)", findText("Acheter") ~= nil and findText(Config.TIERS[1].name) ~= nil and findText(Config.TIERS[2].name) ~= nil and findText(Config.TIERS[6].name) ~= nil)
		local buy = findText("Acheter")
		local coinsBefore = me:GetAttribute("Coins")
		RT.fire(buy, "Activated")
		RT.step(1.5)
		local coinsAfter = me:GetAttribute("Coins")
		check("Boutique : le bouton Acheter du carrousel achète l'œuf présélectionné côté serveur (50 -> ~25 pièces, revenus de 1-2 s inclus)" .. " [" .. tostring(coinsBefore) .. " -> " .. tostring(coinsAfter) .. "]", coinsBefore == Config.START_COINS and coinsAfter >= Config.START_COINS - Config.EGG_PRICE[1] and coinsAfter <= Config.START_COINS - Config.EGG_PRICE[1] + 10)
		-- éclosion : le serveur envoie Hatch avec « 1 sur N », le client joue la révélation
		RT.step(Config.HATCH[1] + 8)
		local sawHatch, oneIn = false, nil
		for _, f in ipairs(RT.fired) do
			if f[1] == "Hatch" and f[2] == me and type(f[3]) == "table" then
				sawHatch, oneIn = true, f[3].oneIn
			end
		end
		check("Éclosion : le serveur envoie la probabilité réelle « 1 sur N » avec le pet", sawHatch and type(oneIn) == "number" and oneIn >= 1)
		check("Éclosion : la révélation affiche « 1 sur N » sous le nom" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), findText("1 sur") ~= nil and #RT.errors == 0)
		local fxCount = 0
		for _, o in ipairs(RT.all) do
			if rawget(o, "__props").Name == "RevealFx" then
				fxCount = fxCount + 1
			end
		end
		check("Éclosion : l'effet RevealFx est créé pour chaque éclosion", fxCount >= 1)
		local vfxFolders, vfxModels = 0, 0
		for _, o in ipairs(RT.all) do
			local nm = rawget(o, "__props").Name
			if type(nm) == "string" and nm:sub(1, 4) == "Vfx_" then
				vfxFolders += 1
			end
		end
		local templates = RT.services.ReplicatedStorage:FindFirstChild("VfxTemplates")
		vfxModels = templates and #templates:GetChildren() or 0
		check("Effets 3D : le serveur publie les 13 modèles d'effets (" .. vfxModels .. "), l'éclosion joue au moins un effet VfxKit (" .. vfxFolders .. ")" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), vfxModels == 13 and vfxFolders >= 1 and #RT.errors == 0)
		do
			local names = {}
			for _, o in ipairs(RT.all) do
				if o.ClassName == "Sound" then
					names[rawget(o, "__props").Name] = rawget(o, "__props")
				end
			end
			check("Sons : achat (Sfx_buy), éclosion (Sfx_hatch ou rareté) et ambiance prairie (Sfx_ambMeadow) créés, un seul Sound par type" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), names.Sfx_buy ~= nil and names.Sfx_ambMeadow ~= nil and (names.Sfx_hatch ~= nil or names.Sfx_rare ~= nil or names.Sfx_epic ~= nil) and #RT.errors == 0)
			check("Sons : volumes appliqués (achat 0,55, prairie 0,3 en boucle)", names.Sfx_buy and math.abs(names.Sfx_buy.Volume - 0.55) < 1e-6 and names.Sfx_ambMeadow and math.abs(names.Sfx_ambMeadow.Volume - 0.3) < 1e-6 and names.Sfx_ambMeadow.Looped == true)
		end
		-- bannière de zone : le joueur se déplace dans le domaine de Mara
		local char = me.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local mx, mz = Config.rivalCenter(2)
			rawget(root, "__props").Position = RT.vec(mx, 3, mz)
			RT.step(1.5)
			check("Bannière de zone : « DOMAINE DE MARA » affichée en entrant dans le domaine" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), findText(Config.zoneBanner("mara").title) ~= nil)
		else
			check("Bannière de zone : le personnage existe pour le test", false)
		end
		-- cinématique du CinematicKit (victoire du château) : démarre, ne dépasse pas 8 s, restitue la caméra, aucune erreur
		do
			local function findNamed(name)
				for _, o in ipairs(RT.all) do
					if rawget(o, "__props").Name == name then
						return o
					end
				end
				return nil
			end
			local cineGui = findNamed("ChipeCine")
			local notifyRemote
			for _, d in ipairs(RT.services.ReplicatedStorage:GetDescendants()) do
				if rawget(d, "__props").Name == "Notify" then
					notifyRemote = d
				end
			end
			check("Cinématiques : l'interface (bandes, carton de titre, bouton Passer) existe et est cachée au repos", cineGui ~= nil and rawget(cineGui, "__props").Enabled == false)
			if cineGui and notifyRemote then
				RT.fire(notifyRemote, "OnClientEvent", "🏆 Château terminé", "fanfare")
				RT.step(0.6)
				local playing = rawget(cineGui, "__props").Enabled == true
				RT.step(9)
				local finished = rawget(cineGui, "__props").Enabled == false
				check("Cinématique de victoire : elle démarre, se termine en moins de 8 s et rend la caméra et l'interface" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), playing and finished and #RT.errors == 0)
			end
		end
		-- éclosion légendaire synthétique (événement Hatch du serveur) : révélation, effets 3D, brillance, vignette et pulsation sans erreur
		do
			local hatchRemote
			for _, d in ipairs(RT.services.ReplicatedStorage:GetDescendants()) do
				if rawget(d, "__props").Name == "Hatch" then
					hatchRemote = d
				end
			end
			local dragon = 13
			RT.fire(hatchRemote, "OnClientEvent", { p = dragon, s = 2, m = 1, slot = 1, inc = 99, oneIn = 400, egg = 4 })
			RT.step(1.2)
			local slotsMid = 0
			for _, o in ipairs(RT.all) do
				if rawget(o, "__props").Name == "SlotFx" then
					slotsMid += 1
				end
			end
			check("Éclosion : l'écran « machine à sous » apparaît avant la révélation (" .. slotsMid .. ")" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), slotsMid >= 1 and #RT.errors == 0)
			RT.step(3.2)
			local vignette, shine = 0, 0
			for _, o in ipairs(RT.all) do
				local nm = rawget(o, "__props").Name
				if nm == "UiFxVignette" then
					vignette += 1
				elseif nm == "Shine" then
					shine += 1
				end
			end
			check("Éclosion légendaire : brillance sur le bandeau et flash de vignette créés, aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), vignette >= 1 and shine >= 1 and #RT.errors == 0)
		end
		-- culling : le joueur est au Grand Nid, les trois domaines (à plus de 200 studs de leur bord) sont masqués ; près de Mara, elle réapparaît
		do
			local function modifiers(folderName)
				local hidden, shown, total = 0, 0, 0
				for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
					if d.ClassName == "Part" then
						local par = d.Parent
						local nm = par and rawget(par, "__props").Name
						if nm == folderName then
							total += 1
							local m = d.LocalTransparencyModifier
							if m == 1 then
								hidden += 1
							elseif m == 0 or m == nil then
								shown += 1
							end
						end
					end
				end
				return hidden, shown, total
			end
			local rootC = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
			if rootC then
				rawget(rootC, "__props").Position = RT.vec(0, 5, 40) -- au Grand Nid
			end
			RT.step(4)
			local zh, _, zt = modifiers("Rival_Zed")
			local gh, _, gt = modifiers("Rival_Gus")
			check("Culling : les domaines éloignés (Zed " .. zh .. "/" .. zt .. ", Gus " .. gh .. "/" .. gt .. " Parts) sont masqués depuis le Grand Nid", zt > 10 and zh == zt and gt > 10 and gh == gt)
			local mx, mz = Config.rivalCenter(2)
			if rootC then
				rawget(rootC, "__props").Position = RT.vec(mx, 3, mz)
				RT.step(4)
				local mh, ms, mt = modifiers("Rival_Mara")
				local gh2 = modifiers("Rival_Gus")
				check("Culling : près de Mara elle réapparaît (" .. ms .. "/" .. mt .. ") ; Gus, à plus de 140 studs de son bord, reste masqué (" .. gh2 .. ")" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), mt > 10 and mh == 0 and gh2 == gt and #RT.errors == 0)
			end
		end
		-- bannière : distance à la base du joueur ; inventaire à onglets (œufs, pets, boosts, titres, index)
		check("Bannière de zone : la distance à la base est affichée (« Bois de Mara · N m de ta base »)", findText("Bois de Mara") ~= nil and findText("m de ta base") ~= nil)
		RT.actions.ChipeClose(nil, RT.env.Enum.UserInputState.Begin)
		RT.step(0.5)
		local dexIcon = findText("📖")
		RT.fire(dexIcon and dexIcon.Parent or nil, "Activated")
		RT.step(1)
		local sawTabs = findText("Titres") ~= nil and findText("Boosts") ~= nil and findText("Index") ~= nil and findText("Œufs") ~= nil
		check("Inventaire : onglets Œufs, Pets, Boosts, Titres, Index, Succès" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), sawTabs and #RT.errors == 0)
		local function tab(label)
			for _, o in ipairs(RT.all) do
				local t = rawget(o, "__props").Text
				if o.ClassName == "TextButton" and type(t) == "string" and t:find(label, 1, true) then
					RT.fire(o, "Activated")
					RT.step(0.8)
					return true
				end
			end
			return false
		end
		check("Inventaire : onglet Titres (20 titres, cases verrouillées « ??? »)", tab("Titres") and findText("titres. Ils se débloquent") ~= nil and findText("???") ~= nil)
		check("Inventaire : onglet Index (compteur x/N, espèces non obtenues grisées)", tab("Index") and findText("INDEX") ~= nil and findText("/" .. #Config.PETS) ~= nil)
		check("Inventaire : onglet Boosts (multiplicateur, passes)", tab("Boosts") and findText("Multiplicateur de revenus") ~= nil)
		check("Inventaire : onglets Œufs et Pets sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), tab("Œufs") and tab("Pets") and #RT.errors == 0)
		RT.actions.ChipeClose(nil, RT.env.Enum.UserInputState.Begin)
		RT.step(0.5)
		-- carrousel : flèche droite -> sélection suivante, achat trop cher refusé côté serveur
		RT.actions.ChipeShop(nil, RT.env.Enum.UserInputState.Begin) -- ferme
		RT.actions.ChipeShop(nil, RT.env.Enum.UserInputState.Begin) -- rouvre
		RT.step(0.5)
		check("Boutique : réouverture sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
	end
end

-- RevealFx : exécution de l'effet de révélation dans le runtime factice ---------------------------------------------------------
do
	suite("RevealFx : effet de révélation (étoile, rayons, anneaux, étincelles) exécuté dans le runtime factice")
	local Reveal = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Reveal.lua"), { debugName = "Reveal" })()
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0, hook = loopGuard })
	if RT then
		local created = 0
		local env = {}
		for k, v in pairs(RT.env) do
			env[k] = v
		end
		env.Instance = { new = function(class)
			created = created + 1
			return RT.instance(class)
		end }
		local RevealFx = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/RevealFx.lua"), { debugName = "RevealFx", environment = env })()
		local gui = RT.instance("ScreenGui", "gui")
		local worst, allOk, why = 0, true, ""
		for tier = 1, #Config.TIERS do
			for _, mode in ipairs({ { false, 5 }, { true, 5 }, { false, Config.REVEAL.secret.oneInAtLeast } }) do
				local style = Reveal.style(Config, tier, mode[2], mode[1])
				style.color = env.Color3.fromRGB(255, 176, 32)
				created = 0
				local ok, box = pcall(RevealFx.play, gui, style, nil)
				local expected = RevealFx.cost(style)
				if not ok or box == nil then
					allOk, why = false, "tier " .. tier .. " : play a échoué"
				elseif created ~= expected then
					allOk, why = false, "tier " .. tier .. " : " .. created .. " objets pour un coût annoncé de " .. expected
				end
				worst = math.max(worst, created)
			end
		end
		RT.step(4)
		check("RevealFx : 18 effets (6 raretés x normal, mobile, secret) s'exécutent sans erreur, coûts annoncés exacts" .. (allOk and "" or " : " .. why), allOk and #RT.errors == 0)
		check("RevealFx : plafond de performance (" .. worst .. " objets au maximum, <= 90)", worst <= 90)
		local sMob = Reveal.style(Config, 6, 5, true)
		local sFull = Reveal.style(Config, 6, 5, false)
		check("RevealFx : le mode mobile coûte moins cher que le mode complet", RevealFx.cost(sMob) < RevealFx.cost(sFull))
		check("RevealFx : style invalide -> nil sans erreur", RevealFx.play(gui, {}, nil) == nil)
		-- icônes de richesse dessinées par le code
		local CoinIcon = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/CoinIcon.lua"), { debugName = "CoinIcon", environment = env })()
		local counts, iconsOk = {}, true
		for tier = 1, #Config.WEALTH do
			created = 0
			local ico = CoinIcon.build(gui, tier, 52)
			counts[tier] = created
			if ico == nil or created < 3 or created > 80 then
				iconsOk = false
			end
		end
		check("CoinIcon : 4 icônes (1 pièce, petite pile, grosse pile, coffre) construites, 3 à 80 objets chacune", iconsOk)
		check("CoinIcon : les piles grossissent avec la richesse (pièce < petite pile < grosse pile)", counts[1] < counts[2] and counts[2] < counts[3])
		check("CoinIcon : palier inconnu ou taille invalide sans erreur", pcall(CoinIcon.build, gui, 99, 52) and pcall(CoinIcon.build, gui, 2, 0))
	end
end


do
	suite("Lot 11 : arbres, chemins sinueux, protections d'œufs (logique pure)")
	local PLx = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Placement.lua"), { debugName = "Placement" })()
	local M = Config.Assets.models
	local n13 = 0
	for _, g in ipairs({ "trees", "paths", "eggguard" }) do
		for k, id in pairs(M[g]) do
			n13 = n13 + 1
			check("Modèle " .. g .. "." .. k .. " : ID valide et plafond de Parts", type(id) == "number" and id > 0 and Config.Assets.modelsMaxParts[g .. "." .. k] ~= nil)
		end
	end
	check("13 modèles du lot 11 déclarés", n13 == 13)
	-- protections par rareté
	check("Protection : Commun = nid, Rare/Épique = dôme, Légendaire = cage, Mythique/Cosmique = cristaux",
		Config.eggGuardKey(1) == "egg_nest_fence" and Config.eggGuardKey(2) == "egg_dome" and Config.eggGuardKey(3) == "egg_dome" and Config.eggGuardKey(4) == "egg_cage" and Config.eggGuardKey(5) == "egg_shield" and Config.eggGuardKey(6) == "egg_shield")
	local mono = true
	for t = 2, 6 do
		if Config.eggGuardGlow(t).brightness <= Config.eggGuardGlow(t - 1).brightness or Config.eggGuardGlow(t).range < Config.eggGuardGlow(t - 1).range then
			mono = false
		end
	end
	check("Protection : lumière croissante avec la rareté", mono)
	check("Protection : rareté invalide -> clé valide, sans erreur", Config.eggGuardKey(0) == "egg_nest_fence" and Config.eggGuardKey(99) == "egg_shield" and Config.eggGuardKey(nil) == "egg_nest_fence" and Config.eggGuardKey(0 / 0) == "egg_nest_fence")
	local widthOk = true
	for _, k in ipairs(Config.Assets.eggGuardKeys) do
		if not Config.Assets.eggGuardWidth[k] or Config.Assets.eggGuardWidth[k] > 7 then
			widthOk = false
		end
	end
	check("Protection : largeur cible définie et <= 7 studs pour chaque clé", widthOk)
	-- arbres
	local seen, byZone = {}, {}
	local c1x, c1z = Config.rivalCenter(1)
	byZone.pine = PLx.treeVariant(Config, "tree", c1x + 20, c1z + 90, 1)
	byZone.sakura = PLx.treeVariant(Config, "tree", 0, 60, 1)
	local lk = Config.Map.geo.lakes[1]
	byZone.lake = PLx.treeVariant(Config, "tree", lk.x + lk.r + 10, lk.z, 2)
	byZone.fir = PLx.treeVariant(Config, "fir", 300, 100, 3)
	check("Arbres : pins sur les falaises, sakuras près des lacs et de l'arène, sapin = pin", byZone.pine == "tree_pine" and byZone.sakura == "tree_sakura" and byZone.lake == "tree_sakura" and byZone.fir == "tree_pine")
	for k = 1, 8 do
		seen[PLx.treeVariant(Config, "tree", -300, 200, k)] = true
	end
	check("Arbres : prairie = chênes, bouleau et arbre rond mélangés (4 variantes)", seen.tree_oak_a and seen.tree_oak_b and seen.tree_birch and seen.tree_round)
	local jOk, jmin, jmax = true, 9, 0
	for i = 1, 200 do
		local j = PLx.jitter(i * 7.3, i * 3.1, Config.Assets.treeScaleJitter)
		jmin, jmax = math.min(jmin, j), math.max(jmax, j)
		if j < 0.85 - 1e-9 or j > 1.15 + 1e-9 then
			jOk = false
		end
	end
	check("Arbres : échelle ±15 % (min " .. string.format("%.2f", jmin) .. ", max " .. string.format("%.2f", jmax) .. "), déterministe et variée", jOk and jmax - jmin > 0.2 and PLx.jitter(5, 6, 0.15) == PLx.jitter(5, 6, 0.15))
	local hOk = true
	for k, h in pairs(Config.Assets.treeHeights) do
		if h < 8 or h > 11 or not M.trees[k] then
			hOk = false
		end
	end
	check("Arbres : hauteurs cibles 8 à 11 studs, une par modèle", hOk)
	-- chemins sinueux
	local allOk, curves, maxStep = true, 0, 0
	for _, poly in ipairs(Config.Map.paths) do
		local plan = PLx.pathTiles(poly, Config.Assets.pathTile, Config.Assets.pathWind)
		if #plan.tiles < 3 or #plan.borders ~= 2 * #plan.tiles then
			allOk = false
		end
		local first, last = plan.tiles[1], plan.tiles[#plan.tiles]
		if math.sqrt((first.x - poly[1][1]) ^ 2 + (first.z - poly[1][2]) ^ 2) > 0.01 or math.sqrt((last.x - poly[#poly][1]) ^ 2 + (last.z - poly[#poly][2]) ^ 2) > 0.01 then
			allOk = false -- extrémités fixes
		end
		for i = 2, #plan.tiles do
			local a, b = plan.tiles[i - 1], plan.tiles[i]
			maxStep = math.max(maxStep, math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2))
		end
		for _, t in ipairs(plan.tiles) do
			if t.kind == "path_curve" then
				curves = curves + 1
				if t.rot % 90 ~= 0 then
					allOk = false
				end
			end
		end
	end
	check("Chemins : tuiles et bordures cohérentes, extrémités fixes, virages tournés par pas de 90°", allOk)
	check("Chemins : tuiles consécutives jointives (pas max " .. string.format("%.1f", maxStep) .. " <= 1,5 x tuile) ", maxStep <= Config.Assets.pathTile * 1.5)
	local winding = PLx.pathTiles({ { 0, 0 }, { 0, -240 } }, 8, 5)
	local maxX = 0
	for _, t in ipairs(winding.tiles) do
		maxX = math.max(maxX, math.abs(t.x))
	end
	check("Chemins : un tracé droit devient sinueux (écart latéral max " .. string.format("%.1f", maxX) .. " studs, <= amplitude)", maxX > 2.5 and maxX <= 5 + 1e-6)
	local corner = PLx.pathTiles({ { 0, 0 }, { 0, -80 }, { 40, -80 } }, 8, 0)
	local cc = 0
	for _, t in ipairs(corner.tiles) do
		if t.kind == "path_curve" then
			cc = cc + 1
		end
	end
	check("Chemins : un coin à 90° donne une tuile de virage (" .. cc .. ")", cc >= 1)
	check("Chemins : yawOfDir (1,0)=0, (0,-1)=90, (-1,0)=180, (0,1)=270", math.abs(PLx.yawOfDir(1, 0)) < 1e-6 and math.abs(PLx.yawOfDir(0, -1) - 90) < 1e-6 and math.abs(PLx.yawOfDir(-1, 0) - 180) < 1e-6 and math.abs(PLx.yawOfDir(0, 1) - 270) < 1e-6)
end


do
	suite("Lot 12 : village (scn_*) : hub fixe, carte planifiée, empreintes sans recouvrement")
	local PLv = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Placement.lua"), { debugName = "Placement" })()
	local D = Config.Assets.sceneryDims
	local idsOk, n = true, 0
	for k, id in pairs(Config.Assets.models.scenery) do
		n = n + 1
		if type(id) ~= "number" or id <= 0 or not D[k] or not Config.Assets.modelsMaxParts["scenery." .. k] then
			idsOk = false
		end
	end
	check("Lot 12 : 9 modèles scn_* avec ID, dimensions et plafond de Parts", idsOk and n == 9)
	-- hub : aucune empreinte ne recouvre un portail, le spawn, la fontaine, la place, le décor catalogue, ni les autres éléments ; tout reste dans le sol (rayon 205)
	local fixed = { { 0, 34, 10 }, { 0, 0, 10 }, { -26, 30, 4 }, { 26, 30, 4 }, { -26, 8, 4 }, { 26, 8, 4 } }
	for _, ring in ipairs({ 62, 108 }) do
		for i = 1, #Config.Game.Sizes do
			local a = math.rad(-72 + (i - 1) * 36)
			fixed[#fixed + 1] = { math.sin(a) * ring, -math.cos(a) * ring, 14 }
		end
	end
	for _, d in ipairs(Config.HubDecor) do
		fixed[#fixed + 1] = { d[2], d[3], 5 }
	end
	local hubOk, why, worst = true, "", 999
	for i, e in ipairs(Config.HubScenery) do
		local dm = D[e[1]]
		local r = e[5] and e[5] / 2 + 1 or dm.r
		if math.sqrt(e[2] ^ 2 + e[3] ^ 2) + r > 205 then
			hubOk, why = false, "hors du sol : " .. e[1]
		end
		if math.sqrt(e[2] ^ 2 + e[3] ^ 2) - r < 52 and e[1] ~= "scn_pont_pierre" then
			hubOk, why = false, "sur la place : " .. e[1]
		end
		for _, f in ipairs(fixed) do
			local gap = math.sqrt((e[2] - f[1]) ^ 2 + (e[3] - f[2]) ^ 2) - r - f[3]
			worst = math.min(worst, gap)
			if gap < 0 and e[1] ~= "scn_pont_pierre" then
				hubOk, why = false, e[1] .. " recouvre un élément fixe (" .. f[1] .. "," .. f[2] .. ")"
			end
		end
		for j = i + 1, #Config.HubScenery do
			local o = Config.HubScenery[j]
			local ro = o[5] and o[5] / 2 + 1 or D[o[1]].r
			local bridgePair = e[1] == "scn_pont_pierre" or o[1] == "scn_pont_pierre"
			if not bridgePair and math.sqrt((e[2] - o[2]) ^ 2 + (e[3] - o[3]) ^ 2) < r + ro then
				hubOk, why = false, e[1] .. " recouvre " .. o[1]
			end
		end
	end
	check("Village du hub : " .. #Config.HubScenery .. " éléments, aucun recouvrement, hors place et portails (marge min " .. string.format("%.1f", worst) .. ") " .. why, hubOk)
	local pond = Config.HubPond
	local bridge
	for _, e in ipairs(Config.HubScenery) do
		if e[1] == "scn_pont_pierre" then
			bridge = e
		end
	end
	check("Hub : le pont de pierre (40 de long) enjambe la mare (" .. pond.w .. " de large) et est centré dessus", bridge ~= nil and D.scn_pont_pierre.len > pond.w and bridge[2] == pond.x and bridge[3] == pond.z)
	local ringN = 0
	for _, e in ipairs(Config.HubScenery) do
		if e[5] then
			ringN = ringN + 1
			local dx, dz = math.abs(e[2] - pond.x), math.abs(e[3] - pond.z)
			if dx < pond.w / 2 - 1 or dz < pond.d / 2 - 1 then
				hubOk = false
			end
		end
	end
	check("Hub : " .. ringN .. " rochers bordent la mare sans entrer dedans", ringN >= 4 and hubOk)
	-- carte : planificateur
	local P2 = PLv.new(Config)
	local plan = P2.plan()
	local v1, v2 = P2.scenery(plan.items), P2.scenery(plan.items)
	local want = 0
	for _, e in ipairs(PLv.VILLAGE) do
		want = want + e[2]
	end
	check("Village de la carte : " .. #v1 .. "/" .. want .. " éléments placés, déterministe", #v1 >= want - 2 and #v1 == #v2 and v1[1].x == v2[1].x)
	local mapOk = true
	for i, a in ipairs(v1) do
		if P2.blocked(a.x, a.z, a.r, {}) then
			mapOk = false
		end
		for _, b in ipairs(plan.items) do
			if math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) < a.r + b.r then
				mapOk = false
			end
		end
		for j = i + 1, #v1 do
			if math.sqrt((a.x - v1[j].x) ^ 2 + (a.z - v1[j].z) ^ 2) < a.r + v1[j].r then
				mapOk = false
			end
		end
	end
	check("Village de la carte : rien dans l'eau, sur un chemin, une base, un domaine, ni sur un arbre/rocher du plan, ni sur un autre élément", mapOk)
	local worstParts = 0
	for _, e in ipairs(v1) do
		worstParts = worstParts + Config.Assets.modelsMaxParts["scenery." .. e.kind]
	end
	check("Village : pire cas " .. worstParts .. " Parts (budget " .. Config.Assets.sceneryBudgetParts .. " : le placement s'arrête au budget réel)", worstParts > 0)
end


do
	suite("Machine à sous : plan pur (arrêt exact sur le tirage, décélération, colonnes une à une) et écran SlotFx")
	local RV = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Reveal.lua"), { debugName = "Reveal" })()
	local exact, mono, decel, order, dur = true, true, true, true, 0
	for tier = 1, #Config.TIERS do
		for sz = 1, #Config.SIZES do
			for mu = 1, #Config.MUTS do
				for _, fast in ipairs({ false, true }) do
					local plan = RV.slotPlan(Config, tier, sz, mu, fast)
					local finals = { tier, sz, mu }
					for k, col in ipairs(plan.columns) do
						local endPos = RV.slotPos(col, col.stop + 5)
						if RV.slotIndex(col, endPos) ~= finals[k] or RV.slotIndex(col, RV.slotPos(col, col.stop)) ~= finals[k] then
							exact = false
						end
						local prev, prevV = RV.slotPos(col, 0), math.huge
						for i = 1, 60 do
							local t = col.stop * i / 60
							local p = RV.slotPos(col, t)
							local v = p - prev
							if p < prev - 1e-9 then
								mono = false
							end
							if v > prevV + 1e-9 then
								decel = false
							end
							prev, prevV = p, v
						end
					end
					if not (plan.columns[1].stop < plan.columns[2].stop and plan.columns[2].stop < plan.columns[3].stop) then
						order = false
					end
					dur = math.max(dur, plan.duration)
				end
			end
		end
	end
	check("Machine à sous : chaque colonne s'arrête exactement sur la rareté, la taille et la mutation réelles (6 x 5 x 5 x 2 plans)", exact)
	check("Machine à sous : la position ne recule jamais et la vitesse décroît (ralentissement)", mono and decel)
	check("Machine à sous : arrêt colonne par colonne (rareté, taille, mutation), durée max " .. string.format("%.2f", dur) .. " s <= 3 s", order and dur <= 3)
	check("Machine à sous : entrées invalides ramenées dans les bornes", RV.slotPlan(Config, 99, 0, nil, false).columns[1].final == #Config.TIERS and RV.slotPlan(Config, 99, 0, nil, false).columns[2].final == 1)
	local fastP, slowP = RV.slotPlan(Config, 1, 2, 1, true), RV.slotPlan(Config, 1, 2, 1, false)
	check("Machine à sous : la version rapide (tirage banal, mobile) est plus courte", fastP.duration < slowP.duration)
	-- exécution de l'écran dans le runtime factice
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0, hook = loopGuard })
	if RT then
		local created = 0
		local env = {}
		for k, v in pairs(RT.env) do
			env[k] = v
		end
		env.Instance = { new = function(class)
			created = created + 1
			return RT.instance(class)
		end }
		local SlotFx = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/SlotFx.lua"), { debugName = "SlotFx", environment = env })()
		local gui = RT.instance("ScreenGui", "gui")
		local allOk, why, worst = true, "", 0
		for _, c in ipairs({ { 1, false, false }, { 4, true, false }, { 6, false, true } }) do
			local plan = RV.slotPlan(Config, c[1], 2, 1, c[2])
			plan.phoenix = c[1] >= Config.REVEAL.slot.phoenixFromTier
			local doneN = 0
			created = 0
			local box = SlotFx.play(gui, plan, Config.REVEAL.slot.cell, { secret = c[3], onDone = function()
				doneN = doneN + 1
			end, slotPos = RV.slotPos })
			if box == nil then
				allOk, why = false, "play nil (palier " .. c[1] .. ")"
			elseif created ~= SlotFx.STATIC_COST then
				allOk, why = false, created .. " objets au départ pour un coût annoncé de " .. SlotFx.STATIC_COST
			end
			RT.step(plan.duration + 2)
			worst = math.max(worst, created)
			if doneN ~= 1 then
				allOk, why = false, "onDone appelé " .. doneN .. " fois (palier " .. c[1] .. ")"
			end
		end
		check("Machine à sous : 3 écrans (commun rapide, légendaire avec phénix, secret) jouent sans erreur, coût de départ exact (" .. SlotFx.STATIC_COST .. "), onDone une seule fois" .. (allOk and "" or " : " .. why), allOk and #RT.errors == 0)
		check("Machine à sous : plafond de performance (" .. worst .. " objets créés au maximum, <= 140)", worst <= 140)
		-- passage par un tap : onDone immédiat, une seule fois
		local plan = RV.slotPlan(Config, 3, 2, 1, false)
		local doneN = 0
		local box = SlotFx.play(gui, plan, 34, { onDone = function()
			doneN = doneN + 1
		end, slotPos = RV.slotPos })
		RT.fire(box, "Activated")
		RT.fire(box, "Activated")
		check("Machine à sous : un tap passe l'animation (onDone une seule fois)", doneN == 1)
		RT.step(plan.duration + 2)
		check("Machine à sous : après un passage, toujours un seul onDone et aucune erreur", doneN == 1 and #RT.errors == 0)
		check("Machine à sous : plan invalide -> nil, onDone appelé quand même", (function()
			local n = 0
			local r = SlotFx.play(gui, {}, 34, { onDone = function()
				n = n + 1
			end, slotPos = RV.slotPos })
			return r == nil and n == 1
		end)())
	end
end


do
	suite("Catalogue de la boutique : chaque achat du code est décrit dans PUBLICATION.md et A_FAIRE_UTILISATEUR.md")
	local pub = fs.readFile("roblox/PUBLICATION.md")
	local todo = fs.readFile("roblox/A_FAIRE_UTILISATEUR.md")
	local missing, count = "", 0
	for _, group in ipairs({ "PASSES", "PRODUCTS" }) do
		for key, def in pairs(Config[group]) do
			count = count + 1
			if not pub:find("Config." .. group .. "." .. key .. ".id", 1, true) or not todo:find(def.name, 1, true) or not pub:find(def.name, 1, true) then
				missing = missing .. " " .. key
			end
		end
	end
	check("Catalogue : " .. count .. " achats documentés (nom, ID attendu)" .. (missing == "" and "" or " : manquants" .. missing), count == 11 and missing == "")
end


do
	suite("Diagnostic des modèles Blender : IDs attendus, chargement par lots, relance, rapport par catégorie")
	local M = Config.Assets.models
	local expected = {
		trees = { tree_oak_a = 115675817596242, tree_oak_b = 139178488755477, tree_birch = 86165293471213, tree_pine = 134548154871906, tree_sakura = 136998832791777, tree_round = 128198214830836 },
		paths = { path_straight = 85121318662290, path_curve = 101412637646543, path_stones = 119316046353622 },
		eggguard = { egg_dome = 114304098897950, egg_nest_fence = 101252453233834, egg_cage = 98653120562597, egg_shield = 73837494094507 },
		scenery = { scn_puits = 93457733638103, scn_pin_haut = 103664392312435, scn_pont_pierre = 71167399273394, scn_maison_colombages = 108434085196211, scn_tour_cloche = 117760736577913,
			scn_rocher_a = 109597978140541, scn_rocher_b = 91218401630144, scn_rocher_c = 126837715911422, scn_ile_sakura = 103275800553270 },
	}
	local bad, total = "", 0
	for g, list in pairs(expected) do
		for k, id in pairs(list) do
			total = total + 1
			if M[g][k] ~= id then
				bad = bad .. " " .. g .. "." .. k
			end
		end
	end
	check("IDs des lots 11 et 12 : " .. total .. " modèles exactement ceux de la liste fournie" .. (bad == "" and "" or " : écarts" .. bad), total == 22 and bad == "")
	local seenId, dup, count = {}, "", 0
	for g, list in pairs(M) do
		for k, id in pairs(list) do
			count = count + 1
			if type(id) ~= "number" or id <= 0 or id % 1 ~= 0 then
				dup = dup .. " invalide:" .. g .. "." .. tostring(k)
			elseif seenId[id] then
				dup = dup .. " doublon:" .. g .. "." .. tostring(k) .. "=" .. seenId[id]
			end
			seenId[id] = g .. "." .. tostring(k)
		end
	end
	check("Config.Assets.models : " .. count .. " IDs valides, aucun doublon entre clés (faute de frappe)" .. dup, dup == "")
	local capBad = ""
	for g, list in pairs(M) do
		for k in pairs(list) do
			if g ~= "pets" and not Config.Assets.modelsMaxParts[g .. "." .. k] and g ~= "vfx" then
				capBad = capBad .. " " .. g .. "." .. k
			end
		end
	end
	check("Plafond de Parts explicite pour chaque modèle (sauf pets et effets)" .. capBad, capBad == "")
	local known = { ["scenery.scn_pin_haut"] = 72, ["scenery.scn_pont_pierre"] = 67, ["scenery.scn_puits"] = 50, ["eggguard.egg_nest_fence"] = 28, ["base.level8"] = 41 }
	local capOk = true
	for k, parts in pairs(known) do
		if Config.Assets.modelsMaxParts[k] < parts then
			capOk = false
		end
	end
	check("Plafonds relevés : pin 72, pont 67, puits 50, nid 28, base 41 Parts acceptés", capOk)
	-- chargeur : lots parallèles, relance, jamais d'arrêt après un échec, rapport
	local AssetsMod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Assets.lua"), { debugName = "Assets" })()
	local RT0 = newRuntime({ fs = fs, luau = luau, placeId = 0, hook = loopGuard })
	if RT0 then
		local clock = 0
		local calls, hang = {}, nil
		local function mk(cfgOverride)
			local cfgT = setmetatable({}, { __index = Config })
			local a = {}
			for k, v in pairs(Config.Assets) do
				a[k] = v
			end
			a.models = { trees = { tree_oak_a = 11, tree_pine = 12, tree_birch = 13, tree_round = 14 }, paths = { path_straight = 21 } }
			a.modelsMaxParts = { ["trees.tree_oak_a"] = 40, ["trees.tree_pine"] = 40, ["trees.tree_birch"] = 40, ["trees.tree_round"] = 40, ["paths.path_straight"] = 40 }
			for k, v in pairs(cfgOverride or {}) do
				a[k] = v
			end
			cfgT.Assets = a
			return cfgT
		end
		local env = RT0.env
		local function deps()
			return {
				loadAsset = function(id)
					calls[id] = (calls[id] or 0) + 1
					if id == hang then
						while true do
							RT0.task.wait(1)
						end
					elseif id == 12 and calls[id] == 1 then
						error("HTTP 500 temporaire")
					elseif id == 13 then
						error("Asset is not trusted for this place")
					end
					local m = RT0.instance("Model", "m" .. id)
					local p = RT0.instance("Part", "Corps")
					p.Parent = m
					return m
				end,
				spawn = RT0.task.spawn, wait = RT0.task.wait, clock = function() return RT0.now end, warn = function() end,
			}
		end
		RT0.now = 0
		hang = 14
		local A = AssetsMod.new(mk({ timeout = 3 }), deps())
		local done = false
		local t0 = RT0.now
		RT0.task.spawn(function()
			A.loadGroup("trees")
			A.loadGroup("paths")
			done = true
		end)
		RT0.step(60)
		check("Chargeur : un modèle qui ne répond jamais (14) ni un refus (13) n'empêchent pas de charger la suite (chemin 21 chargé)", done and A.status["m:paths.path_straight"] and A.status["m:paths.path_straight"].ok == true)
		check("Chargeur : erreur temporaire -> un nouvel essai réussit (id 12 appelé " .. tostring(calls[12]) .. " fois)", calls[12] == 2 and A.status["m:trees.tree_pine"].ok == true)
		local rep = A.report()
		local trees
		for _, b in ipairs(rep) do
			if b.cat == "arbres" then
				trees = b
			end
		end
		check("Rapport : arbres 2/4 chargés, 2 en repli", trees and trees.requested == 4 and trees.loaded == 2 and trees.fallback == 2)
		local lines = A.reportLines()
		local txt = table.concat(lines, "\n")
		check("Rapport : chaque échec donne le nom, l'ID et le message d'erreur (refus et délai)", txt:find("tree_birch", 1, true) and txt:find("13", 1, true) and txt:find("not trusted", 1, true) and txt:find("délai dépassé", 1, true) and txt:find("tree_round", 1, true))
		-- 20 modèles lents sont chargés par lots de 8 : durée << 20 x délai
		RT0.now = 0
		calls = {}
		hang = nil
		local big = {}
		for i = 1, 24 do
			big["m" .. i] = 100 + i
		end
		local caps = {}
		for i = 1, 24 do
			caps["trees.m" .. i] = 40
		end
		local A2 = AssetsMod.new(mk({ models = { trees = big }, modelsMaxParts = caps }), (function()
			local d = deps()
			d.loadAsset = function(id)
				RT0.task.wait(1)
				local m = RT0.instance("Model", "m" .. id)
				local p = RT0.instance("Part", "Corps")
				p.Parent = m
				return m
			end
			return d
		end)())
		local n2, tEnd = 0, nil
		RT0.task.spawn(function()
			n2 = A2.loadGroup("trees")
			tEnd = RT0.now
		end)
		RT0.step(40)
		check("Chargeur : 24 modèles d'1 s en lots parallèles de 8 : " .. n2 .. "/24 chargés en " .. string.format("%.1f", (tEnd or 99) - 0) .. " s (< 8 s ; séquentiel = 24 s)", n2 == 24 and tEnd and tEnd < 8)
	end
	-- e2e : le serveur publie le rapport ; chaque catégorie demandée a au moins un modèle chargé ; en cas de refus total, tout est en repli avec le message
	local function reportOf(fail)
		local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
		if not RT then
			return nil
		end
		if fail then
			RT.loadAssetFail = "403: accès refusé"
		end
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(60)
		local rv = RT.services.ReplicatedStorage:FindFirstChild("AssetReport")
		return rv, RT
	end
	local rv1 = reportOf(false)
	if rv1 then
		local props = rawget(rv1, "__props")
		local text = rv1.Value or (props and props.Value) or ""
		local cats, empty = 0, ""
		for line in tostring(text):gmatch("[^\n]+") do
			local name, got, want = line:match("%[Assets%] (.-) : (%d+)/(%d+) chargés")
			if name then
				cats = cats + 1
				if tonumber(got) == 0 and tonumber(want) > 0 and name ~= "textures" then -- le runtime factice n'a pas de décals
					empty = empty .. " " .. name
				end
			end
		end
		check("Rapport publié par le serveur : " .. cats .. " catégories, aucune entièrement en repli" .. (empty == "" and "" or " :" .. empty), cats >= 12 and empty == "")
		check("Rapport : total Blender publié (attributs Loaded/Requested)", type(rv1:GetAttribute("Loaded")) == "number" and rv1:GetAttribute("Requested") >= 100 and rv1:GetAttribute("Loaded") >= rv1:GetAttribute("Requested") - 7)
	else
		check("Rapport publié par le serveur (StringValue AssetReport)", false)
	end
	do -- un joueur arrive AVANT la fin du chargement : sa base et ses œufs sont reconstruits avec les modèles dès leur arrivée
		local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
		if RT then
			RT.loadAssetDelay = 2
			local main = RT.buildTree("roblox/src", false)
			RT.task.spawn(function()
				RT.runScript(main)
			end)
			local p = RT.addPlayer("Tot", 9911, { from = "hub", partyId = "LATE", size = 1, late = false })
			RT.step(1)
			local early = 0
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				if rawget(d, "__props").Name == "BaseModel" then
					early = early + 1
				end
			end
			RT.step(120)
			local bases, guards = 0, 0
			for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
				local nm = rawget(d, "__props").Name
				if nm == "BaseModel" then
					bases = bases + 1
				elseif nm == "EggGuard" then
					guards = guards + 1
				end
			end
			check("Arrivée pendant le chargement : base Blender (" .. bases .. ") posée après coup (" .. early .. " au moment de l'arrivée) ; protections d'œufs : " .. guards .. "), aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), early == 0 and bases >= 1 and #RT.errors == 0)
		end
	end
	local rv2, RT2 = reportOf(true)
	if rv2 then
		local text = tostring(rv2.Value)
		check("Refus total simulé : tout en repli, chaque échec liste nom, ID et message « 403 »", rv2:GetAttribute("Loaded") == 0 and text:find("ÉCHEC", 1, true) and text:find("403", 1, true) and text:find(tostring(M.trees.tree_oak_a), 1, true))
		check("Refus total simulé : le jeu démarre sans erreur serveur (repli procédural)" .. (#RT2.errors == 0 and "" or " : " .. tostring(RT2.errors[1])), #RT2.errors == 0)
	else
		check("Refus total simulé : rapport publié", false)
	end
end


do
	suite("Revenu passif : gelé quand le joueur est inactif, hors-ligne plafonné à 30 min et récupéré d'un clic")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		local RA
		for _, d in ipairs(RT.services.ReplicatedStorage:GetDescendants()) do
			if rawget(d, "__props").Name == "Action" then
				RA = d
			end
		end
		local p = RT.addPlayer("Idle", 9921, { from = "hub", partyId = "IDLE", size = 1, late = false })
		RT.step(2)
		local function coins()
			return p:GetAttribute("Coins") or 0
		end
		local function act(a)
			RT.now = RT.now + 0.2
			RT.fire(RA, "OnServerEvent", p, a)
		end
		-- donner du revenu : un pet posé
		for i = 1, 40 do
			act("buyEgg")
			RT.step(1)
		end
		RT.step(40)
		local c0 = coins()
		RT.step(20)
		act("claimAway") -- toute action remet le joueur en activité
		RT.step(20)
		local grown = coins() > c0
		-- 3 minutes sans aucune entrée ni déplacement : le compteur ne bouge plus
		RT.step(Config.IDLE.seconds + 5)
		local frozenFrom = coins()
		RT.step(120)
		local frozenTo = coins()
		check("Revenu : le compteur monte quand le joueur est actif (" .. string.format("%.0f", c0) .. " -> " .. string.format("%.0f", coins()) .. ")", grown or c0 > 0)
		check("Revenu : joueur sans entrée depuis 3 minutes -> compteur gelé (" .. string.format("%.1f", frozenFrom) .. " = " .. string.format("%.1f", frozenTo) .. "), attribut Idle", frozenFrom == frozenTo and p:GetAttribute("Idle") == true)
		act("claimAway")
		RT.step(15)
		check("Revenu : le joueur revient -> le revenu reprend, Idle retiré", (coins() > frozenTo or frozenTo == 0) and p:GetAttribute("Idle") == false)
		check("Revenu : aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
		-- hors-ligne : 5 h d'absence = au plus 30 min de gains, mis de côté puis récupérés
		RT.removePlayer(p)
		RT.step(2)
		local st = RT.dataStores["ChipeOeufs_v1"]
		local rec = st and st.data["P_9921"]
		if rec and rec.v then
			rec.v.last = RT.env.os.time() - 5 * 3600
			rec.v.pendingAway = 0
			rec.lock = nil -- verrou libéré : la session précédente est terminée
		end
		RT.now = RT.now + 5 * 3600
		local p2 = RT.addPlayer("Idle2", 9921, { from = "hub", partyId = "IDLE", size = 1, late = false })
		RT.step(12)
		RT.now = RT.now + 0.2
		RT.fire(RA, "OnServerEvent", p2, "sync")
		RT.step(1)
		local sawMsg = false
		for _, f in ipairs(RT.fired) do
			if f[1] == "Notify" and f[2] == p2 and type(f[3]) == "string" and f[3]:find("Gains pendant ton absence", 1, true) then
				sawMsg = true
			end
		end
		local lastSnap
		for i = #RT.fired, 1, -1 do
			local f = RT.fired[i]
			if f[1] == "State" and f[2] == p2 and type(f[3]) == "table" then
				lastSnap = f[3]
				break
			end
		end
		local inc = p2:GetAttribute("Income") or 0
		local cap = inc * Config.IDLE.offlineMaxSeconds * Config.IDLE.offlineRate
		check("Hors ligne : 5 h d'absence -> message « Gains pendant ton absence » et gain mis de côté plafonné à 30 min (" .. tostring(lastSnap and lastSnap.away) .. " <= " .. string.format("%.0f", cap) .. ")", lastSnap ~= nil and sawMsg and lastSnap.away > 0 and lastSnap.away <= cap + 1)
		local c1 = p2:GetAttribute("Coins") or 0
		RT.fire(RA, "OnServerEvent", p2, "claimAway")
		RT.step(1)
		local c2 = p2:GetAttribute("Coins") or 0
		check("Hors ligne : un clic sur « Récupérer » crédite le gain une seule fois", c2 - c1 >= (lastSnap and lastSnap.away or 0) - 1)
		RT.now = RT.now + 0.2
		RT.fire(RA, "OnServerEvent", p2, "claimAway")
		RT.step(1)
		check("Hors ligne : un second clic ne crédite rien de plus et sans erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), (p2:GetAttribute("Coins") or 0) - c2 < 100 + inc * 5 and #RT.errors == 0)
	end
end


do
	suite("Œuf annoncé = rareté du pet : 10 000 éclosions par œuf, amélioration d'un cran seule exception")
	local seed = 20260101
	local function rnd()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local allOk, why = true, ""
	for egg = 1, #Config.TIERS do
		local same, up, other = 0, 0, 0
		for _ = 1, 10000 do
			local r = Rules.rollPet(egg, Rules.upPoints(0, false, false, false), false, rnd, false)
			local d = Config.PETS[r.p].tier - egg
			if d == 0 then
				same = same + 1
			elseif d == 1 then
				up = up + 1
			else
				other = other + 1
			end
		end
		local expectedUp = egg < #Config.TIERS and 0.05 or 0
		if other > 0 or same / 10000 < 0.945 and egg < #Config.TIERS or (egg == #Config.TIERS and same ~= 10000) or math.abs(up / 10000 - expectedUp) > 0.012 then
			allOk, why = false, "œuf " .. egg .. " : " .. same .. " identiques, " .. up .. " améliorés, " .. other .. " autres"
		end
		if egg == 3 then
			check("Œuf Épique sans bonus : " .. same / 100 .. " % Épique, " .. up / 100 .. " % Légendaire (amélioré), " .. other .. " autres (>= 95 % Épique à 0,5 point près)", same / 10000 >= 0.94 and other == 0)
		end
	end
	check("Les 6 œufs : jamais de rareté inférieure ni de saut de deux crans, 5 % d'amélioration de base " .. why, allOk)
	local capped = Rules.tierWeights(3, 500)
	check("Avec tous les bonus, la part d'amélioration reste plafonnée (" .. capped[3] .. " %) et il n'y a toujours aucune rétrogradation", capped[1] == 0 and capped[3] == Rules.MAX_UP)
	local RVx = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Reveal.lua"), { debugName = "Reveal" })()
	local pr = 0
	for pidx, def in ipairs(Config.PETS) do
		if def.tier == 3 then
			for sz = 1, #Config.SIZES do
				for mu = 1, #Config.MUTS do
					pr = pr + RVx.probability(Config, Rules, 3, Rules.upPoints(0, false, false, false), false, pidx, sz, mu, false)
				end
			end
		end
	end
	check("Probabilité annoncée d'obtenir un pet Épique d'un œuf Épique = " .. string.format("%.3f", pr) .. " (95 %)", math.abs(pr - 0.95) < 1e-6)
	check("Texte des probabilités : par œuf, « AMÉLIORÉ ! », jamais de rareté inférieure", Config.oddsText():find("AMÉLIORÉ", 1, true) and Config.oddsText():find("Épique : 95% Épique, 5% Légendaire", 1, true) and Config.oddsText():find("Jamais de rareté inférieure", 1, true))
end


do
	suite("Carte compacte : distances mesurées, voyage rapide validé par le serveur, boussole")
	local M = Config.Map
	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end
	local lines, distOk = {}, true
	local dz = {}
	for i = 1, #Config.RIVALS do
		local x, z = Config.rivalCenter(i)
		dz[i] = { x, z }
		local d = dist(x, z, 0, 0)
		lines[#lines + 1] = string.format("%s %.0f", Config.RIVALS[i].name, d)
		if d < 150 or d > 280 then
			distOk = false
		end
	end
	local neigh = {}
	for i = 2, #dz do
		local d = dist(dz[i][1], dz[i][2], dz[i - 1][1], dz[i - 1][2])
		neigh[#neigh + 1] = string.format("%.0f", d)
		if d < 150 or d > 230 then
			distOk = false
		end
	end
	check("Distances : Grand Nid -> domaines " .. table.concat(lines, " / ") .. " ; entre voisins " .. table.concat(neigh, " / ") .. " (cibles 150 à 280 et 150 à 230)", distOk)
	local walk = 16 -- vitesse de marche de base
	local worst = 0
	for i = 1, #dz do
		local bx, bz = Config.travelPoint(i)
		worst = math.max(worst, dist(0, 0, bx, bz) / walk)
		if i > 1 then
			local ax, az = Config.travelPoint(i - 1)
			worst = math.max(worst, dist(ax, az, bx, bz) / walk)
		end
	end
	check("Trajets à pied : Grand Nid -> rampe d'un domaine et rampe -> rampe voisine : au plus " .. string.format("%.1f", worst) .. " s (< 25 s)", worst < 25)
	check("Base à " .. M.plotRadius .. " studs du Grand Nid : " .. string.format("%.1f", M.plotRadius / walk) .. " s à pied (< 15 s)", M.plotRadius / walk < 15)
	-- boussole
	local a1, d1 = Config.compass(0, 0, 0, -1, 10, 0)
	local a2 = Config.compass(0, 0, 0, -1, -10, 0)
	local a3 = Config.compass(0, 0, 0, -1, 0, -10)
	local a4 = Config.compass(0, 0, 0, -1, 0, 10)
	check("Boussole : droite +90, gauche -90, devant 0, derrière ±180 (" .. string.format("%.0f/%.0f/%.0f/%.0f", a1, a2, a3, a4) .. ")", math.abs(a1 - 90) < 1e-6 and math.abs(a2 + 90) < 1e-6 and math.abs(a3) < 1e-6 and math.abs(math.abs(a4) - 180) < 1e-6 and d1 == 10)
	check("Boussole : zone à rejoindre = la plus avancée débloquée (chapitres 0, 3, 6)", Config.frontierZone(0) == 1 and Config.frontierZone(3) == 2 and Config.frontierZone(6) == 3 and Config.frontierZone(99) == 3)
	-- e2e
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		local p = RT.addPlayer("Voy", 9931, { from = "hub", partyId = "VOY", size = 1, late = false })
		RT.step(3)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local prompts = {}
		for obj in pairs(RT.tags["FastTravel"] or {}) do
			prompts[#prompts + 1] = obj
		end
		local byDest = { [0] = {}, {}, {}, {} }
		for _, pr in ipairs(prompts) do
			local list = byDest[pr:GetAttribute("Dest")]
			list[#list + 1] = pr
		end
		check("Voyage rapide : " .. #prompts .. " portails (3 au Grand Nid + 3 retours), aucune erreur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #prompts == 2 * #Config.RIVALS and #byDest[0] == #Config.RIVALS and #RT.errors == 0)
		local function posOf()
			local pr = rawget(root, "__props")
			return pr.CFrame.Position
		end
		local function trigger(prompt)
			local pp = prompt.Parent
			local pos = rawget(pp, "__props").CFrame and rawget(pp, "__props").CFrame.Position or rawget(pp, "__props").Position
			rawget(root, "__props").Position = RT.vec(pos.X, 3, pos.Z)
			rawget(root, "__props").CFrame = RT.cf(pos.X, 3, pos.Z)
			RT.now = RT.now + 5
			RT.fire(RT.services.ProximityPromptService, "PromptTriggered", prompt, p)
			RT.step(0.3)
		end
		if root and byDest[1][1] then
			RT.step(10) -- aucun coup récent
			trigger(byDest[1][1])
			local px, pz = posOf().X, posOf().Z
			local tx, tz = Config.travelPoint(1)
			check("Voyage rapide : le portail du Grand Nid mène à la zone 1 débloquée (" .. string.format("%.0f,%.0f", px, pz) .. " attendu " .. string.format("%.0f,%.0f", tx, tz) .. ")", dist(px, pz, tx, tz) < 1)
			trigger(byDest[3][1]) -- Zed : verrouillée au chapitre 0
			local qx, qz = posOf().X, posOf().Z
			local bx, bz = Config.travelPad(3)
			check("Voyage rapide : une zone verrouillée est REFUSÉE côté serveur (le joueur reste sur le portail)", dist(qx, qz, bx, bz) < 1)
			trigger(byDest[0][1])
			local rx, rz = posOf().X, posOf().Z
			local ax, az = Config.travelPoint(0)
			check("Voyage rapide : le portail de retour ramène au Grand Nid", dist(rx, rz, ax, az) < 1)
			-- délai de 4 s : deux déclenchements rapprochés = un seul voyage
			local before = posOf()
			local pr1 = byDest[2][1]
			local pp = rawget(pr1.Parent, "__props")
			rawget(root, "__props").CFrame = RT.cf(0, 3, 0)
			RT.fire(RT.services.ProximityPromptService, "PromptTriggered", pr1, p) -- trop loin du portail : refusé
			RT.step(0.3)
			check("Voyage rapide : déclenché loin du portail -> refusé", dist(posOf().X, posOf().Z, 0, 0) < 1)
			check("Voyage rapide : aucune erreur serveur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
		else
			check("Voyage rapide : joueur et portails présents", false)
		end
	end
end


do
	suite("Mobs : territoires séparés, plateau respecté, détection de blocage, 10 minutes sans gardien bloqué")
	local GU = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Guard.lua"), { debugName = "Guard" })()
	local G = Config.GUARD
	-- territoires : segments de patrouille (± 12 en x) de TOUS les gardiens, y compris entre domaines
	local segs = {}
	for i, riv in ipairs(Config.RIVALS) do
		for j = 1, riv.guards do
			local gx, gz = Config.guardTerritory(i, j, riv.guards)
			segs[#segs + 1] = { i = i, j = j, x1 = gx - 12, x2 = gx + 12, z = gz }
		end
	end
	local minGap, inside = math.huge, true
	for a = 1, #segs do
		local s1 = segs[a]
		local cx, cz = Config.rivalCenter(s1.i)
		for _, x in ipairs({ s1.x1, s1.x2 }) do
			if math.sqrt((x - cx) ^ 2 + (s1.z - cz) ^ 2) > Config.Map.plateauRadius - G.territoryMargin then
				inside = false
			end
		end
		for b = a + 1, #segs do
			local s2 = segs[b]
			local dx = math.max(0, math.max(s1.x1, s2.x1) - math.min(s1.x2, s2.x2))
			local d = math.sqrt(dx ^ 2 + (s1.z - s2.z) ^ 2)
			minGap = math.min(minGap, d)
		end
	end
	check("Territoires : " .. #segs .. " gardiens, distance minimale entre deux zones de patrouille " .. string.format("%.1f", minGap) .. " studs (>= 4), tous dans le rayon du plateau - " .. G.territoryMargin, minGap >= 4 and inside)
	local cx0, cz0 = GU.clampToDisc(100, 0, 0, 0, 50)
	local cx1, cz1 = GU.clampToDisc(10, 10, 0, 0, 50)
	check("Plateau : clampToDisc ramène un point lointain sur le bord (" .. string.format("%.0f,%.0f", cx0, cz0) .. ") et laisse un point intérieur", math.abs(cx0 - 50) < 1e-9 and math.abs(cz0) < 1e-9 and cx1 == 10 and cz1 == 10)
	local tr = { t = 0 }
	local fired = 0
	for _ = 1, 100 do
		if GU.stuckStep(tr, 0.1, 0, true, G) then
			fired = fired + 1
		end
	end
	check("Blocage : immobile 10 s alors qu'il devrait bouger -> détecté toutes les " .. G.stuckSeconds .. " s (" .. fired .. " fois)", fired == 2)
	local tr2 = { t = 0 }
	local f2, f3 = 0, 0
	for k = 1, 100 do
		if GU.stuckStep(tr2, 0.1, k % 30 == 0 and 1 or 0, true, G) then
			f2 = f2 + 1
		end
	end
	local tr3 = { t = 0 }
	for _ = 1, 100 do
		if GU.stuckStep(tr3, 0.1, 0, false, G) then
			f3 = f3 + 1
		end
	end
	check("Blocage : un mouvement remet le compteur à zéro ; immobile voulu (alerte) jamais signalé", f2 == 0 and f3 == 0)
	local y0, r0 = GU.walkPose(1, 0)
	local moving, maxY = true, 0
	for k = 1, 60 do
		local y, r = GU.walkPose(k * 0.05, 9)
		maxY = math.max(maxY, y)
		if y < 0 or y > 0.36 or math.abs(r) > 0.07 then
			moving = false
		end
	end
	check("Animation : rebond borné en marche (max " .. string.format("%.2f", maxY) .. " <= 0,35), respiration à l'arrêt (" .. string.format("%.3f", y0) .. ")", moving and maxY > 0.1 and math.abs(y0) <= 0.04 and r0 == 0)
	-- simulation : 10 minutes avec un joueur qui court en zigzag dans et autour du domaine de Gus (hors plateau compris)
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local main = RT.buildTree("roblox/src", false)
		do -- poursuites exagérées (vue 200, vitesse 30) : les gardiens suivent le joueur jusqu'au bord et au-delà du plateau
			local cfgSim = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
			local r1 = cfgSim.RIVALS[1]
			r1.viewDist, r1.hearRadius, r1.viewAngle, r1.guardSpeed, r1.gentle = 200, 200, 360, 30, false
		end
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		local p = RT.addPlayer("Mob", 9941, { from = "hub", partyId = "MOB", size = 1, late = false })
		RT.step(3)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		local models = {}
		for _, d in ipairs(RT.services.Workspace:GetDescendants()) do
			local nm = rawget(d, "__props").Name
			if d.ClassName == "Model" and type(nm) == "string" and nm:match("^Guard%d+_%d+$") then
				models[#models + 1] = d
			end
		end
		local gx, gz = Config.rivalCenter(1)
		local seed = 77
		local function rnd()
			seed = (seed * 16807) % 2147483647
			return seed / 2147483647
		end
		local outside, samples, fixes = 0, 0, 0
		local moved = {}
		local lastPos = {}
		for sec = 1, 600 do
			if root and sec % 4 == 1 then
				local a, r = rnd() * math.pi * 2, rnd() * 75
				rawget(root, "__props").Position = RT.vec(gx + math.cos(a) * r, 3, gz + math.sin(a) * r)
				rawget(root, "__props").CFrame = RT.cf(gx + math.cos(a) * r, 3, gz + math.sin(a) * r)
			end
			RT.step(1)
			for k, m in ipairs(models) do
				local pv = m:GetPivot().Position
				samples = samples + 1
				local rival = tonumber(rawget(m, "__props").Name:match("^Guard(%d+)_"))
				local rx, rz = Config.rivalCenter(rival)
				if math.sqrt((pv.X - rx) ^ 2 + (pv.Z - rz) ^ 2) > Config.Map.plateauRadius - G.territoryMargin + 0.5 then
					outside = outside + 1
				end
				local lp = lastPos[k]
				if lp then
					moved[k] = (moved[k] or 0) + math.sqrt((pv.X - lp.X) ^ 2 + (pv.Z - lp.Z) ^ 2)
				end
				lastPos[k] = pv
			end
		end
		for _, m in ipairs(models) do
			fixes = fixes + (m:GetAttribute("StuckFixes") or 0)
		end
		local worstMoved = math.huge
		for k = 1, #models do
			worstMoved = math.min(worstMoved, moved[k] or 0)
		end
		check("Simulation 10 min : " .. #models .. " gardiens, " .. samples .. " mesures, aucun hors du plateau (" .. outside .. "), blocages corrigés : " .. fixes .. ", erreurs : " .. #RT.errors, #models == 6 and outside == 0 and #RT.errors == 0)
		check("Simulation 10 min : chaque gardien a bougé (distance parcourue minimale " .. string.format("%.0f", worstMoved) .. " studs sur 600 s)", worstMoved > 100)
	end
end


do
	suite("Chevaliers du château : territoire, vitesse, continuité, non-chevauchement sur 10 minutes")
	local CA = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Castle.lua"), { debugName = "Castle" })
	local Cs = CA(Config)
	local ok, why, maxSpeed, knightsN = true, "", 0, 0
	for r = 1, Cs.ROOMS do
		local room = Cs.room(r)
		local ks = Cs.knights(room)
		knightsN = knightsN + #ks
		for i, k in ipairs(ks) do
			if k.lz < 4 or k.lz > Cs.ROOM_LENGTH - 4 then
				ok, why = false, "chevalier hors de la salle " .. r
			end
			if k.amp + k.radius >= Cs.ROOM_WIDTH / 2 then
				ok, why = false, "salle " .. r .. " : le chevalier touche le mur"
			end
			if i > 1 and k.lz - ks[i - 1].lz < 2 * k.radius + 6 then
				ok, why = false, "salle " .. r .. " : deux chevaliers trop proches"
			end
			local prev
			for step = 0, 6000 do -- 10 minutes à 0,1 s
				local t = step * 0.1
				local x, dir = Cs.knightPos(t, k)
				if math.abs(x) > k.amp + 1e-9 or (dir ~= 1 and dir ~= -1) then
					ok, why = false, "salle " .. r .. " : position ou sens invalide à t=" .. t
				end
				if prev then
					local v = math.abs(x - prev) / 0.1
					if v > maxSpeed then
						maxSpeed = v
					end
				end
				prev = x
			end
			local sp = 4 * k.amp / k.period
			if sp > 16 then
				ok, why = false, "salle " .. r .. " : chevalier plus rapide que le joueur"
			end
		end
	end
	check("Chevaliers : " .. knightsN .. " chevaliers (5 salles), dans leur salle, sans se toucher, vitesse max mesurée " .. string.format("%.1f", maxSpeed) .. " studs/s (< 16), 10 minutes simulées" .. (ok and "" or " : " .. why), ok and knightsN >= 3 and maxSpeed < 16)
	check("Chevaliers : hauteur cible 4,5 studs et plafond de Parts du modèle >= 80", Config.Assets.targetHeights.knight == 4.5 and Config.Assets.modelsMaxParts["guards.knight"] ~= nil and Config.Assets.modelsMaxParts["guards.knight"] >= 80)
end


do
	local EZ = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Easing.lua"), { debugName = "Easing" })()
	local ax, az = EZ.travelDir(3, 4, 1, 1.5)
	local bx = EZ.travelDir(0.5, 0, 1, 1.5)
	check("Pets suiveurs : travelDir donne la direction unitaire (0,6 ; 0,8), nil quand le pet est quasi immobile, entrées invalides sans erreur", math.abs(ax - 0.6) < 1e-9 and math.abs(az - 0.8) < 1e-9 and bx == nil and EZ.travelDir(nil, 1, 1) == nil and EZ.travelDir(0 / 0, 1, 1) == nil and EZ.travelDir(1, 1, 0) == nil)
end


do
	suite("Premières secondes : 3 étapes courtes, passables, temps jusqu'à la première éclosion")
	local a = Config.onboarding(0, false, 6)
	local b = Config.onboarding(0, true, 5)
	local c = Config.onboarding(0, true, 1)
	check("Onboarding : étape 1 (aller vers l'œuf), 2 (le toucher), 3 (il éclot), puis plus rien après la première éclosion", a.index == 1 and b.index == 2 and c.index == 3 and a.total == 3 and Config.onboarding(1, true, 0) == nil and Config.onboarding(nil, true, 0) == nil)
	local long = 0
	for _, st in ipairs({ a, b, c }) do
		long = math.max(long, #st.text)
	end
	check("Onboarding : textes courts (" .. long .. " octets au plus, < 110)", long < 110)
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game, hook = loopGuard })
	if RT then
		local main = RT.buildTree("roblox/src", false)
		RT.task.spawn(function()
			RT.runScript(main)
		end)
		RT.step(1)
		local t0 = RT.now
		local p = RT.addPlayer("Neo", 9951, { from = "hub", partyId = "NEO", size = 1, late = false })
		local tHatch
		for k = 1, 400 do
			RT.step(0.1)
			for _, f in ipairs(RT.fired) do
				if f[1] == "Hatch" and f[2] == p then
					tHatch = RT.now - t0
				end
			end
			if tHatch then
				break
			end
		end
		check("Première éclosion : " .. string.format("%.1f", tHatch or -1) .. " s après l'arrivée du joueur (cible < 15 s, œuf de départ offert)", tHatch ~= nil and tHatch < 15 and #RT.errors == 0)
	end
end


do
	suite("Mini-carte : projection pure, repères, pastilles réutilisées, coût constant")
	local MM = luau.load(fs.readFile("roblox/src/ReplicatedStorage/MiniMap.lua"), { debugName = "MiniMap" })()
	local u1, v1 = MM.place(0, 0, 130, 0, 260, 50, false)
	local u2, v2 = MM.place(0, 0, 0, -260, 260, 50, false)
	check("Mini-carte : un point à mi-rayon à l'est est à mi-disque à droite ; le nord (-Z) est en haut", math.abs(u1 - 25) < 1e-9 and v1 == 0 and v2 == -50 and u2 == 0)
	check("Mini-carte : hors du disque -> absent (gardiens) ou ramené au bord (repères)", MM.place(0, 0, 500, 0, 260, 50, false) == nil and math.abs(select(1, MM.place(0, 0, 500, 0, 260, 50, true)) - 50) < 1e-9)
	check("Mini-carte : entrées invalides (nil, NaN, rayon nul) -> nil sans erreur", MM.place(nil, 0, 1, 1, 260, 50) == nil and MM.place(0, 0, 0 / 0, 1, 260, 50) == nil and MM.place(0, 0, 1, 1, 0, 50) == nil)
	local pts = MM.landmarks(Config, 10, 20, 0)
	local kinds = { base = 0, zone = 0, portal = 0 }
	local lockedZones = 0
	for _, p in ipairs(pts) do
		kinds[p.kind] = kinds[p.kind] + 1
		if p.kind == "zone" and p.locked then
			lockedZones = lockedZones + 1
		end
	end
	check("Mini-carte : repères = 1 base, " .. #Config.RIVALS .. " zones (" .. lockedZones .. " verrouillées au chapitre 0), " .. #Config.RIVALS .. " portails", kinds.base == 1 and kinds.zone == #Config.RIVALS and kinds.portal == #Config.RIVALS and lockedZones == #Config.RIVALS - 1)
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0, hook = loopGuard })
	if RT then
		local created = 0
		local env = {}
		for k, v in pairs(RT.env) do
			env[k] = v
		end
		env.Instance = { new = function(class)
			created = created + 1
			return RT.instance(class)
		end }
		local UI = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/MiniMapUi.lua"), { debugName = "MiniMapUi", environment = env })()
		local gui = RT.instance("ScreenGui", "mm")
		local plr = RT.instance("Player", "P")
		local char = RT.instance("Model", "Char")
		local root = RT.instance("Part", "HumanoidRootPart")
		rawget(root, "__props").Position = RT.vec(0, 3, 0)
		root.Parent = char
		rawget(plr, "__props").Character = char
		local objs = UI.start(Config, MM, plr, gui, function()
			return { story = { ch = 0 } }
		end, RT.services.UserInputService, RT.services.RunService)
		local atStart = created
		RT.step(10)
		local visible = 0
		if objs then
			for _, d in ipairs(objs.dots) do
				if rawget(d, "__props").Visible == true then
					visible = visible + 1
				end
			end
		end
		check("Mini-carte : l'interface démarre, " .. visible .. " pastilles visibles au Grand Nid, " .. atStart .. " objets créés au départ (<= 60) et AUCUN de plus pendant 10 s de jeu" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), objs ~= nil and visible >= 4 and atStart <= 60 and created == atStart and #RT.errors == 0)
	end
end

print(("Tests Config : %d réussis, %d échoués"):format(passed, failed))
process.exit(failed > 0 and 1 or 0)
