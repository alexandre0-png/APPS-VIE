-- Tests purs (sans moteur Roblox) : données, économie, validation des sauvegardes, simulation de progression.
-- Exécutés avec une VM Lua + stubs minimaux de Color3/Vector3 (voir run.js).
-- SRC : table { nom = code source Luau } injectée par run.js.

local failures, passes = 0, 0
local function check(cond, msg)
	if cond then
		passes = passes + 1
	else
		failures = failures + 1
		print("  ECHEC : " .. msg)
	end
end
local function section(name)
	print("\n== " .. name)
end

-- Stubs Roblox minimaux --------------------------------------------------
local V3 = {}
V3.__index = V3
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }

local loaded = {}
local function loadModule(name, parentTable)
	script = { Parent = parentTable or loaded }
	local fn, err = load(SRC[name], "=" .. name)
	assert(fn, err)
	local m = fn()
	loaded[name] = m
	return m
end
function require(m) return m end

local Config = loadModule("Config")
local Util = loadModule("Util")
local DinoShapes = loadModule("DinoShapes")
local Economy = loadModule("Economy")

-- Utilitaires de test
local function newData()
	return {
		cash = 0, fossils = Config.StartFossils, pending = 0, totalCash = 0, rebirths = 0,
		dinos = {}, discovered = {}, buildables = {}, stats = { digs = 0, hatched = 0, collected = 0 }, secrets = { bones = {} }, story = { claimed = 0 }, level = 1, riddle = { total = 0 },
		upgrades = { shovel = 0, luck = 0, hatch = 0, ticket = 0 },
	}
end
local rngState = 12345
local function rng() -- LCG déterministe
	rngState = (rngState * 1103515245 + 12345) % 2147483648
	return rngState / 2147483648
end

----------------------------------------------------------------------
section("Config : intégrité des données")
----------------------------------------------------------------------
check(#Config.Dinos == 18, "18 dinos attendus, trouvé " .. #Config.Dinos)
for _, d in ipairs(Config.Dinos) do
	check(Config.RarityById[d.rarity] ~= nil, d.id .. " : rareté inconnue")
	check(DinoShapes[d.archetype] ~= nil, d.id .. " : archétype inconnu " .. tostring(d.archetype))
	check(d.scale > 0 and d.scale < 3, d.id .. " : échelle absurde")
end
for _, rid in ipairs(Config.RarityOrder) do
	check(#Config.DinosByRarity[rid] >= 1, "aucun dino non secret de rareté " .. rid)
end
check(Config.DinoById[Config.SecretDinoId] and Config.DinoById[Config.SecretDinoId].secret, "dino secret défini")
for id, egg in pairs(Config.Eggs) do
	local total = 0
	for rid, w in pairs(egg.weights) do
		check(Config.RarityById[rid] ~= nil, id .. " : rareté inconnue " .. rid)
		total = total + w
	end
	check(total == 100, id .. " : les poids doivent totaliser 100 (" .. total .. ")")
	check(egg.cost > 0 and egg.time > 0, id .. " : coût/temps invalides")
end
for _, id in ipairs(Config.EggOrder) do
	check(Config.Eggs[id] ~= nil, "EggOrder référence un œuf inexistant " .. id)
end
local seenPad, seenId = {}, {}
local penCount, incubCount, diggerCount = 0, 0, 0
for _, b in ipairs(Config.Buildables) do
	check(not seenId[b.id], "id de bâtiment dupliqué " .. b.id)
	seenId[b.id] = true
	check(b.cost > 0, b.id .. " : coût invalide")
	if b.requires then
		check(Config.BuildableById[b.requires] ~= nil, b.id .. " : requires inconnu")
		check(Config.BuildableOrder[b.requires] < Config.BuildableOrder[b.id], b.id .. " : requires doit précéder")
	end
	local key = string.format("%.1f,%.1f", b.pad.X, b.pad.Z)
	check(not seenPad[key], b.id .. " : bouton superposé à " .. tostring(seenPad[key]))
	seenPad[key] = b.id
	if b.kind == "pen" then penCount = penCount + 1 check(Config.Pens[b.index] ~= nil, b.id .. " : enclos inexistant") end
	if b.kind == "incubator" then incubCount = incubCount + 1 check(b.index >= 2 and b.index <= 4 and Config.Stands[b.index] ~= nil, b.id .. " : socle inexistant") end
	if b.kind == "digger" then diggerCount = diggerCount + 1 end
	if b.kind == "shop" then check(b.bonus and b.bonus > 0 and b.center, b.id .. " : boutique incomplète") end
end
check(penCount == 5 and incubCount == 3 and diggerCount == 4, "5 enclos achetables, 3 incubateurs, 4 ouvriers")
check(#Config.Pens == 6 and #Config.Stands == 4, "6 enclos et 4 socles")
-- les boutons ne doivent pas être dans la zone de fouille ni dans un enclos
for _, b in ipairs(Config.Buildables) do
	for i, pen in ipairs(Config.Pens) do
		local inside = math.abs(b.pad.X - pen.center.X) < Config.PenSize.X / 2 and math.abs(b.pad.Z - pen.center.Z) < Config.PenSize.Z / 2
		check(not inside, b.id .. " : bouton à l'intérieur de l'enclos " .. i)
	end
end
check(Config.QuestCount <= #Config.QuestTypes, "assez de types de quêtes")
-- niveaux : portes cohérentes
for _, b in ipairs(Config.Buildables) do
	check(b.level >= 1 and b.level <= Config.MaxLevel, b.id .. " : niveau requis hors bornes")
	if b.requires then
		check(b.level >= Config.BuildableById[b.requires].level, b.id .. " : niveau inférieur à celui de son prérequis")
	end
end
for id, e in pairs(Config.Eggs) do check(e.level >= 1 and e.level <= Config.MaxLevel, id .. " : niveau d'œuf hors bornes") end
check(Config.LevelThresholds[#Config.LevelThresholds] <= #Config.Dinos - 1, "le niveau max est atteignable sans le dino secret")
for i, ch in ipairs(Config.Story) do
	local t = ch.cond.type
	check(t == "digs" or t == "hatched" or t == "collected" or t == "buildable" or t == "discovered" or t == "level" or t == "bones" or t == "rebirths" or t == "riddles", "chapitre " .. i .. " : condition inconnue")
	if t == "buildable" then check(Config.BuildableById[ch.cond.id] ~= nil, "chapitre " .. i .. " : bâtiment inconnu") end
	local r = ch.reward
	check((r.fossils or r.cashMinutes or r.egg) ~= nil, "chapitre " .. i .. " : sans récompense")
	if r.egg then check(Config.Eggs[r.egg] ~= nil, "chapitre " .. i .. " : œuf inconnu") end
end
do
	local seen = {}
	for i, r in ipairs(Config.Riddles) do
		check(#r.options == 3 and r.answer >= 1 and r.answer <= 3 and r.q ~= "" and r.hint ~= "", "énigme " .. i .. " bien formée")
		check(not seen[r.q], "énigme " .. i .. " : question dupliquée")
		seen[r.q] = true
		local opts = {}
		for _, o in ipairs(r.options) do check(not opts[o], "énigme " .. i .. " : options dupliquées") opts[o] = true end
	end
	check(#Config.Riddles >= 7, "au moins une semaine d'énigmes différentes")
	for u = 1, 3 do
		local a, b = Economy.riddleIndex(100, u), Economy.riddleIndex(100, u)
		check(a == b and a >= 1 and a <= #Config.Riddles, "énigme du jour stable et dans les bornes")
	end
	local first = Economy.riddleIndex(100, 5)
	check(Economy.riddleIndex(101, 5) ~= first, "l'énigme change d'un jour à l'autre")
end
for k, p in pairs(Config.Passes) do check(p.id == 0 and p.price > 0 and p.name and p.desc, "pass " .. k .. " bien formé") end
for k, p in pairs(Config.Products) do check(p.id == 0 and p.price > 0 and p.name and p.desc, "produit " .. k .. " bien formé") end
check(#Config.DailyRewards == 7, "7 jours de récompenses")

----------------------------------------------------------------------
section("Formes de dinos : géométrie")
----------------------------------------------------------------------
local maxLen, maxWide = 0, 0
for _, d in ipairs(Config.Dinos) do
	local parts = DinoShapes.get(d.archetype)
	check(#parts >= 10, d.id .. " : trop peu de pièces")
	local minY, maxY, minZ, maxZ, maxX = 1e9, -1e9, 1e9, -1e9, 0
	for _, p in ipairs(parts) do
		local s, pos = p.size, p.pos
		check(s[1] > 0 and s[2] > 0 and s[3] > 0, d.id .. " : pièce de taille nulle")
		minY = math.min(minY, pos[2] - s[2] / 2)
		maxY = math.max(maxY, pos[2] + s[2] / 2)
		minZ = math.min(minZ, pos[3] - s[3] / 2)
		maxZ = math.max(maxZ, pos[3] + s[3] / 2)
		maxX = math.max(maxX, math.abs(pos[1]) + s[1] / 2)
	end
	local len = (maxZ - minZ) * d.scale
	local wide = maxX * 2 * d.scale
	maxLen = math.max(maxLen, len)
	maxWide = math.max(maxWide, wide)
	local isFlyer = d.archetype == "ptero"
	check(isFlyer or minY > -0.05, d.id .. " : sous le sol (" .. minY .. ")")
	check(isFlyer or minY < 0.35, d.id .. " : flotte au-dessus du sol (" .. minY .. ")")
	-- chaque emplacement mesure 18 x 13 studs dans l'enclos
	check(len <= 16.5, d.id .. " : trop long pour l'emplacement (" .. string.format("%.1f", len) .. ")")
	check(wide <= 16.5 or isFlyer, d.id .. " : trop large pour l'emplacement")
end
print(string.format("  plus long dino : %.1f studs, plus large : %.1f studs", maxLen, maxWide))

----------------------------------------------------------------------
section("Util")
----------------------------------------------------------------------
check(Util.formatNumber(0) == "0", "format 0")
check(Util.formatNumber(999) == "999", "format 999")
check(Util.formatNumber(1000) == "1K", "format 1000 = " .. Util.formatNumber(1000))
check(Util.formatNumber(1500) == "1.5K", "format 1500 = " .. Util.formatNumber(1500))
check(Util.formatNumber(2500000) == "2.5M", "format 2.5M = " .. Util.formatNumber(2500000))
check(Util.formatNumber(1e12) == "1T", "format 1e12 = " .. Util.formatNumber(1e12))
check(Util.formatNumber(0 / 0) == "0", "NaN -> 0")
check(Util.formatNumber(math.huge) == "0", "inf -> 0")
check(Util.formatNumber(-1500) == "-1.5K", "négatif")
check(Util.formatTime(125) == "2:05", "formatTime 125 = " .. Util.formatTime(125))
check(Util.formatTime(3700) == "1h 01m", "formatTime 3700 = " .. Util.formatTime(3700))
check(Util.formatTime(-5) == "0:00", "formatTime négatif")
check(Util.clamp(5, 0, 3) == 3 and Util.clamp(-1, 0, 3) == 0, "clamp")
do
	local counts = { a = 0, b = 0 }
	for _ = 1, 20000 do
		local k = Util.weightedPick({ a = 70, b = 30 }, rng)
		counts[k] = counts[k] + 1
	end
	check(math.abs(counts.a / 20000 - 0.7) < 0.02, "weightedPick ~70% (" .. counts.a / 20000 .. ")")
end
do
	local d = { a = 1, t = { x = 1 } }
	Util.reconcile(d, { a = 9, b = 2, t = { x = 5, y = 6 } })
	check(d.a == 1 and d.b == 2 and d.t.x == 1 and d.t.y == 6, "reconcile")
end

----------------------------------------------------------------------
section("Economy")
----------------------------------------------------------------------
local id, g = Economy.parseKey("rex:g")
check(id == "rex" and g == true, "parseKey doré")
id, g = Economy.parseKey("rex")
check(id == "rex" and g == false, "parseKey normal")
local RI = function(r) return Config.RarityById[r].income end
check(Economy.dinoIncome("compy") == RI("commun"), "compy = revenu commun")
check(Economy.dinoIncome("rex") == RI("epique"), "rex = revenu épique")
check(Economy.dinoIncome("rex:g") == RI("epique") * Config.GoldenMultiplier, "rex doré = x3")
check(Economy.dinoIncome("inconnu") == 0, "dino inconnu = 0")

local d = newData()
check(Economy.slotCount(d) == 4, "4 emplacements au départ")
d.buildables.pen2 = true
check(Economy.slotCount(d) == 8, "8 emplacements avec enclos 2")
check(Economy.incubatorCount(d) == 1, "1 incubateur au départ")
d.buildables.incub2 = true
check(Economy.incubatorCount(d) == 2, "2 incubateurs")

d = newData()
d.dinos = { compy = 3, rex = 1, ["rex:g"] = 1, velo = 2 }
local displayed, reserve = Economy.displayAndReserve(d)
check(#displayed == 4, "4 dinos exposés")
check(displayed[1] == "rex:g" and displayed[2] == "rex", "tri par revenu décroissant : " .. table.concat(displayed, ","))
check(displayed[3] == "velo" and displayed[4] == "velo", "vélos ensuite")
check((reserve.compy or 0) == 3, "compys en réserve")
check(Economy.baseIncome(displayed) == RI("epique") * 3 + RI("epique") + RI("peucommun") * 2, "revenu de base")
d.discovered = { compy = true, rex = true, velo = true }
local m = Economy.multipliers(d, {})
check(math.abs(m.collection - 1.06) < 1e-9, "bonus collection 3 découverts")
check(math.abs(m.total - 1.06) < 1e-9, "multiplicateur total de départ")
d.rebirths = 2
d.upgrades.ticket = 5
d.buildables.cafe = true
m = Economy.multipliers(d, { doubleCash = true, boost = 2 })
local expected = 1.06 * 2.0 * 1.5 * 1.2 * 2 * 2
check(math.abs(m.total - expected) < 1e-9, "multiplicateur composé " .. m.total .. " vs " .. expected)
check(Economy.incomePerSecond(d, {}) > 0, "revenu positif")

-- Fossiles / fouille
d = newData()
check(Economy.digAmount(d) == 1, "1 fossile/coup au départ")
d.upgrades.shovel = 4
check(Economy.digAmount(d) == 5, "5 fossiles/coup niveau 4")
d.rebirths = 2
check(Economy.digAmount(d) == math.floor(5 * 1.5), "bonus renaissance fossiles")
check(Economy.critChance(newData()) == 0.05, "critique de base 5%")
d = newData(); d.upgrades.luck = 15
check(math.abs(Economy.critChance(d) - 0.35) < 1e-9, "critique max niveau 15")
d = newData(); d.buildables.digger1 = true; d.buildables.digger2 = true
check(math.abs(Economy.autoDigRate(d) - 1.2) < 1e-9, "2 ouvriers = 1.2 fossiles/s")

-- Oeufs
d = newData()
check(Economy.hatchTime("basic", d, nil) == 10, "temps basique")
d.upgrades.hatch = 15
check(Economy.hatchTime("basic", d, nil) == 4, "temps réduit niveau 15 (plancher 40%)")
check(Economy.hatchTime("cosmic", newData(), { fastHatch = true }) == math.floor(Config.Eggs.cosmic.time * 0.5), "pass éclosion rapide x2")
do
	-- distribution observée vs théorique pour chaque œuf
	for _, eggId in ipairs(Config.EggOrder) do
		local dd = newData()
		local N, byRarity = 20000, {}
		for _ = 1, N do
			local key, dino = Economy.rollEgg(eggId, dd, rng)
			check(Config.DinoById[(Economy.parseKey(key))] ~= nil, "rollEgg renvoie un dino valide")
			check(not dino.secret, "le dino secret ne sort jamais d'un œuf")
			byRarity[dino.rarity] = (byRarity[dino.rarity] or 0) + 1
		end
		for rid, w in pairs(Config.Eggs[eggId].weights) do
			local obs = (byRarity[rid] or 0) / N * 100
			check(math.abs(obs - w) < 1.5, string.format("%s/%s : observé %.1f%% vs %d%%", eggId, rid, obs, w))
		end
		for rid in pairs(byRarity) do
			check(Config.Eggs[eggId].weights[rid] ~= nil, eggId .. " : rareté hors table " .. rid)
		end
	end
	-- dorés ~2%
	local gold = 0
	for _ = 1, 20000 do
		local key = Economy.rollEgg("basic", newData(), rng)
		if string.find(key, ":g", 1, true) then gold = gold + 1 end
	end
	check(math.abs(gold / 20000 - 0.02) < 0.006, "dorés ~2% (" .. gold / 20000 .. ")")
end
-- la chance augmente les raretés hautes
do
	local lo, hi = 0, 0
	for _ = 1, 10000 do
		local _, dn = Economy.rollEgg("jungle", newData(), rng)
		if Config.RarityById[dn.rarity].order >= 3 then lo = lo + 1 end
		local d2 = newData(); d2.upgrades.luck = 15
		local _, dn2 = Economy.rollEgg("jungle", d2, rng)
		if Config.RarityById[dn2.rarity].order >= 3 then hi = hi + 1 end
	end
	check(hi > lo, "le radar augmente les trouvailles rares (" .. lo .. " -> " .. hi .. ")")
end

-- Coûts
for _, uid in ipairs(Config.UpgradeOrder) do
	local u = Config.Upgrades[uid]
	local prev = 0
	for lv = 0, u.max - 1 do
		local c = Economy.upgradeCost(uid, lv)
		check(c > prev, uid .. " : coût strictement croissant niveau " .. lv)
		prev = c
	end
end
check(Economy.rebirthCost(0) == Config.RebirthBaseCost and Economy.rebirthCost(1) == Config.RebirthBaseCost * Config.RebirthGrowth, "coût de renaissance")
check(Economy.sellValue("rex") == RI("epique") * 120, "valeur de vente")

-- Niveau du parc et aventure
d = newData()
check(Economy.parkLevel(d) == 1, "niveau 1 au départ")
d.discovered = { compy = true, velo = true, rex = true }
check(Economy.parkLevel(d) == 2, "niveau 2 avec 3 dinos")
local lv, have, need = Economy.levelProgress(d)
check(lv == 2 and have == 3 and need == 6, "progression vers le niveau 3")
for _, dn in ipairs(Config.Dinos) do d.discovered[dn.id] = true end
check(Economy.parkLevel(d) == Config.MaxLevel and select(3, Economy.levelProgress(d)) == nil, "niveau max sans seuil suivant")
d = newData()
check(not Economy.eggUnlocked(d, "cosmic") and Economy.eggUnlocked(d, "basic"), "œuf cosmique verrouillé au niveau 1")
local idx, val, tgt = Economy.storyCurrent(d)
check(idx == 1 and val == 0 and tgt == 10, "aventure : chapitre 1")
d.stats.digs = 25
idx, val = Economy.storyCurrent(d)
check(val == 25, "aventure : progression des fouilles")
d.story.claimed = #Config.Story
check(Economy.storyCurrent(d) == nil, "aventure terminée")

-- canBuy
d = newData(); d.cash = 100
local ok, why = Economy.canBuy(d, "pen2")
check(not ok and why == "pas assez de pièces", "achat refusé : pas assez")
d.cash = 1e6
ok = Economy.canBuy(d, "pen2")
check(ok, "achat pen2 autorisé")
ok, why = Economy.canBuy(d, "pen3")
check(not ok and why == "verrouillé", "pen3 verrouillé sans pen2")
d.buildables.pen2 = true
ok, why = Economy.canBuy(d, "pen2")
check(not ok and why == "déjà acheté", "pen2 déjà acheté")
d.cash = 1e9
ok, why = Economy.canBuy(d, "pen3")
check(not ok and why == "niveau", "pen3 verrouillé par le niveau")
d.discovered = { compy = true, velo = true, rex = true }
ok = Economy.canBuy(d, "pen3")
check(ok, "pen3 achetable au niveau 2")
ok, why = Economy.canBuy(d, "n_importe_quoi")
check(not ok, "id inconnu refusé")

----------------------------------------------------------------------
section("Sauvegarde : validation / nettoyage (DataService.sanitize)")
----------------------------------------------------------------------
do
	local stubService = setmetatable({}, { __index = function() return function() return setmetatable({ Connect = function() end }, { __index = function() return function() end end }) end end })
	local sharedFolder = { Config = Config, Util = Util }
	local rs = { WaitForChild = function() return sharedFolder end }
	game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then return rs end
		if name == "RunService" then return { IsStudio = function() return true end } end
		return { PlayerRemoving = { Connect = function() end }, GetDataStore = function() end }
	end, JobId = "job" }
	os.time = os.time or function() return 0 end
	local DS = loadModule("DataService", loaded)
	local dirty = {
		cash = 0 / 0, fossils = -50, pending = math.huge, rebirths = 999, totalCash = "oops",
		dinos = { rex = 3, ["rex:g"] = 2, fake = 5, compy = -1, velo = 0 / 0 },
		discovered = { rex = true, fake = true },
		buildables = { pen2 = true, hack = true },
		upgrades = { shovel = 9999, luck = -3, hatch = "x", ticket = 2.7 },
		eggSlots = { ["1"] = { egg = "basic", finish = 100 }, ["9"] = { egg = "basic", finish = 1 }, ["2"] = { egg = "nope", finish = 1 }, ["3"] = { egg = "jungle", finish = 0 / 0 } },
		_lock = { jobId = "x" },
	}
	local s = DS.sanitize(dirty)
	check(s.cash == 0, "cash NaN -> 0")
	check(s.fossils == 0, "fossiles négatifs -> 0")
	check(s.pending == 0, "pending infini -> 0")
	check(s.rebirths == Config.RebirthMax, "renaissances bornées")
	check(s.totalCash == 0, "type invalide -> 0")
	check(s.dinos.rex == 3 and s.dinos["rex:g"] == 2, "dinos valides conservés")
	check(s.dinos.fake == nil and s.dinos.compy == nil and s.dinos.velo == nil, "dinos invalides supprimés")
	check(s.discovered.rex and not s.discovered.fake, "découvertes nettoyées")
	check(s.buildables.pen2 and not s.buildables.hack, "bâtiments inconnus supprimés")
	check(s.upgrades.shovel == Config.Upgrades.shovel.max, "amélioration bornée au max")
	check(s.upgrades.luck == 0 and s.upgrades.hatch == 0, "améliorations négatives/invalides -> 0")
	check(s.upgrades.ticket == 2, "amélioration arrondie")
	check(type(s.riddle) == "table" and s.riddle.total == 0 and s.riddle.solved == false, "énigme : champs par défaut")
	local d2 = DS.sanitize({ riddle = { total = -5, streak = 0 / 0, solved = "oui", tries = 1e99, day = "x" } })
	check(d2.riddle.total == 0 and d2.riddle.streak == 0 and d2.riddle.solved == false and d2.riddle.day == 0 and d2.riddle.tries <= 1e6, "énigme : valeurs invalides nettoyées")
	check(s.eggSlots["1"] and not s.eggSlots["9"] and not s.eggSlots["2"] and not s.eggSlots["3"], "œufs invalides supprimés")
	check(s._lock == nil, "verrou retiré")
	check(type(s.stats) == "table" and type(s.quests.list) == "table" and type(s.receipts) == "table", "champs manquants complétés")
	local fresh = DS.sanitize(nil)
	check(fresh.fossils == Config.StartFossils and fresh.cash == 0, "données neuves par défaut")
	local fresh2 = DS.newData()
	check(fresh2.stats ~= DS.newData().stats, "newData renvoie des tables distinctes")
end

----------------------------------------------------------------------
section("Simulation de progression (joueur automatique)")
----------------------------------------------------------------------
-- Politique : clic de fouille 4 fois/s en moyenne tant que le joueur est actif (80% du temps),
-- éclôt toujours le meilleur œuf abordable, achète toujours l'élément le moins cher disponible.
local function simulate(maxHours, clicksPerSec, activeRatio)
	local dd = newData()
	dd.cash = 0
	local t = 0
	local dt = 1
	local incubators = {} -- slot -> finish time
	local milestones, order = {}, {}
	local function mark(name)
		if not milestones[name] then
			milestones[name] = t
			table.insert(order, name)
		end
	end
	local rebirthAt
	while t < maxHours * 3600 do
		t = t + dt
		local displayed = Economy.displayAndReserve(dd)
		local inc = Economy.baseIncome(displayed) * Economy.multipliers(dd, {}).total
		dd.cash = dd.cash + inc * dt
		dd.fossils = dd.fossils + Economy.autoDigRate(dd) * dt
		if rng() < activeRatio then
			local clicks = clicksPerSec * dt
			local per = Economy.digAmount(dd) * (1 + Economy.critChance(dd) * (Config.CritMultiplier - 1))
			dd.fossils = dd.fossils + clicks * per
		end
		-- incubateurs
		for slot = 1, Economy.incubatorCount(dd) do
			if incubators[slot] and t >= incubators[slot].finish then
				local key = Economy.rollEgg(incubators[slot].egg, dd, rng)
				dd.dinos[key] = (dd.dinos[key] or 0) + 1
				local did = Economy.parseKey(key)
				dd.discovered[did] = true
				incubators[slot] = nil
				mark("1er dino")
				mark("niveau " .. Economy.parkLevel(dd))
				local dn = Config.DinoById[did]
				if dn.rarity == "rare" then mark("1er rare") end
				if dn.rarity == "epique" then mark("1er épique") end
				if dn.rarity == "legendaire" then mark("1er légendaire") end
				if dn.rarity == "mythique" then mark("1er mythique") end
			end
			if not incubators[slot] then
				local best
				for _, eid in ipairs(Config.EggOrder) do
					if dd.fossils >= Config.Eggs[eid].cost * 1.0 and Economy.eggUnlocked(dd, eid) then best = eid end
				end
				-- garde une réserve pour les améliorations en fossiles : n'achète l'œuf cosmique que si fossiles >= 2x coût
				if best then
					dd.fossils = dd.fossils - Config.Eggs[best].cost
					incubators[slot] = { egg = best, finish = t + Economy.hatchTime(best, dd, nil) }
				end
			end
		end
		-- achats : l'élément le moins cher (bâtiment ou amélioration)
		local bestCost, bestAct = math.huge, nil
		for _, b in ipairs(Config.Buildables) do
			if b.cost < bestCost and Economy.canBuy(dd, b.id) then
				bestCost, bestAct = b.cost, function() dd.cash = dd.cash - b.cost; dd.buildables[b.id] = true; mark("achat " .. b.id) end
			end
		end
		for _, uid in ipairs(Config.UpgradeOrder) do
			local u = Config.Upgrades[uid]
			local lv = dd.upgrades[uid]
			if lv < u.max then
				local c = Economy.upgradeCost(uid, lv)
				if dd[u.currency] >= c and (u.currency ~= "cash" or c < bestCost) and u.currency == "cash" then
					bestCost, bestAct = c, function() dd.cash = dd.cash - c; dd.upgrades[uid] = lv + 1 end
				elseif u.currency == "fossils" and dd.fossils >= c * 2 then
					dd.fossils = dd.fossils - c
					dd.upgrades[uid] = lv + 1
				end
			end
		end
		if bestAct then bestAct() end
		if dd.cash >= Economy.rebirthCost(0) and not rebirthAt then
			rebirthAt = t
			mark("renaissance possible")
		end
		if dd.buildables.pen6 and rebirthAt then break end
	end
	return milestones, order, dd, t
end

local ms, order, final, tEnd = simulate(12, 4, 0.8)
local function fmt(s) return string.format("%dh%02dm%02ds", s // 3600, (s % 3600) // 60, s % 60) end
for _, name in ipairs(order) do
	print(string.format("  %-24s %s", name, fmt(ms[name])))
end
print(string.format("  fin de simulation : %s, revenu %.0f/s, %d dinos", fmt(tEnd), Economy.incomePerSecond(final, {}), (function() local n = 0 for _, c in pairs(final.dinos) do n = n + c end return n end)()))
check(ms["1er dino"] and ms["1er dino"] <= 60, "premier dino en moins d'une minute")
check(ms["achat pen2"] and ms["achat pen2"] <= 20 * 60, "2e enclos en moins de 20 minutes")
check(ms["achat pen6"] and ms["achat pen6"] >= 3600 and ms["achat pen6"] <= 6 * 3600, "6e enclos entre 1 h et 6 h")
check(ms["renaissance possible"] and ms["renaissance possible"] >= 2 * 3600, "pas de renaissance avant 2 heures")
check(ms["renaissance possible"] and ms["renaissance possible"] <= 6 * 3600, "première renaissance en moins de 6 heures")

print(string.format("\nRésultat : %d vérifications réussies, %d échec(s)", passes, failures))
return failures
