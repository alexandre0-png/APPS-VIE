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
check("rebirthCost(0)", Config.rebirthCost(0) == 2e6)
check("rebirthCost(1)", Config.rebirthCost(1) == 1.2e7)

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

print(("Tests Config : %d réussis, %d échoués"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
