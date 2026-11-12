-- Tests de la logique pure (aucune API Roblox requise hormis Vector3 / Color3).
-- Le fichier renvoie une fonction (Config, Species, Util, Zoo) -> échecs, réussites.
-- Exécutable avec Lune (tools/lune/run.luau) ou avec la simulation fengari (node tools/sim/run.js UNIT).

return function(Config, Species, Util, Zoo)
	local failures, passed = 0, 0

	local function test(name, fn)
		local ok, err = pcall(fn)
		if ok then
			passed = passed + 1
		else
			failures = failures + 1
			print("ECHEC  " .. name .. " : " .. tostring(err))
		end
	end

	local function eq(actual, expected, label)
		if actual ~= expected then
			error((label or "valeur") .. " : attendu " .. tostring(expected) .. ", obtenu " .. tostring(actual), 2)
		end
	end

	local function truthy(value, label)
		if not value then
			error((label or "condition") .. " fausse", 2)
		end
	end

	-- ---------------------------------------------------------------- Util
	test("Util.formatNumber", function()
		eq(Util.formatNumber(0), "0")
		eq(Util.formatNumber(999), "999")
		eq(Util.formatNumber(1000), "1 000")
		eq(Util.formatNumber(1234567), "1 234 567")
		eq(Util.formatNumber(2499.6), "2 500")
	end)

	test("Util.formatTime", function()
		eq(Util.formatTime(0), "0:00")
		eq(Util.formatTime(59.2), "1:00")
		eq(Util.formatTime(83), "1:23")
		eq(Util.formatTime(-5), "0:00")
	end)

	test("Util.isFiniteNumber", function()
		truthy(Util.isFiniteNumber(3.5))
		truthy(not Util.isFiniteNumber(0 / 0), "NaN")
		truthy(not Util.isFiniteNumber(math.huge), "inf")
		truthy(not Util.isFiniteNumber("3"), "chaîne")
		truthy(not Util.isFiniteNumber(nil), "nil")
	end)

	test("Util.allow (limiteur de fréquence)", function()
		local p = {}
		truthy(Util.allow(p, "x", 1000), "premier appel")
		truthy(not Util.allow(p, "x", 1000), "second appel refusé")
		truthy(Util.allow(p, "y", 1000), "autre clé indépendante")
		Util.forget(p)
		truthy(Util.allow(p, "x", 1000), "après oubli")
	end)

	test("Util.pickWeighted respecte les poids", function()
		local list = { { weight = 1, id = "a" }, { weight = 0, id = "b" }, { weight = 3, id = "c" } }
		local seq = { 0.0, 0.2, 0.26, 0.99 }
		local index = 0
		local rng = {
			NextNumber = function()
				index = index + 1
				return seq[index]
			end,
		}
		eq(Util.pickWeighted(list, rng).id, "a")
		eq(Util.pickWeighted(list, rng).id, "a")
		eq(Util.pickWeighted(list, rng).id, "c")
		eq(Util.pickWeighted(list, rng).id, "c")
	end)

	-- ---------------------------------------------------------------- Config
	test("Config : zones contiguës et couvrant la piste", function()
		eq(Config.zoneAt(-100).key, "savane")
		eq(Config.zoneAt(799).key, "savane")
		eq(Config.zoneAt(800).key, "marais")
		eq(Config.zoneAt(1600).key, "desert")
		eq(Config.zoneAt(2400).key, "volcan")
		eq(Config.zoneAt(99999).key, "volcan")
		eq(Config.zoneIndex(1000), 2)
		for i = 2, #Config.Zones do
			eq(Config.Zones[i].from, Config.Zones[i - 1].to, "zone " .. i .. " contiguë")
			eq(Config.Zones[i].start, Config.Zones[i].from, "départ de la zone " .. i)
			truthy(Config.Zones[i].unlock > Config.Zones[i - 1].unlock, "déblocage croissant")
		end
		eq(Config.Zones[1].unlock, 0, "première zone libre")
		truthy(Config.Track.FinishZ > Config.Zones[#Config.Zones].from, "arrivée dans la dernière zone")
		local zone, index = Config.zoneByKey("desert")
		eq(index, 3)
		eq(zone.key, "desert")
		truthy(Config.zoneByKey("nope") == nil, "zone inconnue")
	end)

	test("Config : identifiants uniques", function()
		local function unique(list, label)
			local seen = {}
			for _, item in ipairs(list) do
				local key = item.key or item.id
				truthy(not seen[key], label .. " en double : " .. tostring(key))
				seen[key] = true
			end
		end
		unique(Config.Hats, "chapeau")
		unique(Config.Ropes, "corde")
		unique(Config.Upgrades, "équipement")
		unique(Config.ZooUpgrades, "amélioration du zoo")
		unique(Config.QuestPool, "quête")
		unique(Config.Story, "chapitre")
		unique(Config.Monetization.GamePasses, "pass")
		unique(Config.Monetization.Products, "produit")
		unique(Config.Zones, "zone")
		unique(Species.List, "espèce")
	end)

	test("Config : tarifs et niveaux cohérents", function()
		for _, list in ipairs({ Config.Upgrades, Config.ZooUpgrades }) do
			for _, up in ipairs(list) do
				eq(#up.costs, up.max, "coûts de " .. up.id)
				for i = 2, #up.costs do
					truthy(up.costs[i] > up.costs[i - 1], "coûts croissants pour " .. up.id)
				end
			end
		end
		eq(Config.findById(Config.Hats, "none").price, 0, "chapeau gratuit")
		eq(Config.findById(Config.Ropes, "classic").price, 0, "corde gratuite")
		truthy(Config.findById(Config.Hats, "inconnu") == nil, "findById absent")
	end)

	test("Config : variantes, quêtes et histoire", function()
		local total = 0
		for index, v in ipairs(Config.Variants) do
			eq(v.id, index, "id de variante")
			total = total + v.weight
		end
		eq(total, 100, "poids des variantes")
		for _, q in ipairs(Config.QuestPool) do
			truthy(q.target > 0 and q.reward > 0, "quête " .. q.id)
			truthy(q.mode == "add" or q.mode == "max", "mode de " .. q.id)
			truthy(string.find(q.label, "%%d") ~= nil, "libellé de " .. q.id)
		end
		local goalTypes =
			{ animals = true, captures = true, zooUpgrades = true, boss = true, zone = true, level = true }
		for _, chapter in ipairs(Config.Story) do
			truthy(goalTypes[chapter.goal.type], "type d'objectif de " .. chapter.id)
			truthy(chapter.goal.n > 0 and chapter.reward.gold > 0, "récompense de " .. chapter.id)
		end
		truthy(
			Config.Score.Finish[1] > Config.Score.Finish[2] and Config.Score.Finish[2] > Config.Score.Finish[3],
			"bonus d'arrivée"
		)
	end)

	test("Config : achats Robux (partie de base gratuite)", function()
		local m = Config.Monetization
		eq(Config.Run.BaseLives, 1, "une vie gratuite")
		truthy(Config.Run.BaseLasso >= 1, "lasso gratuit")
		truthy(Zoo.slots(0, false) >= 4, "zoo gratuit utilisable")
		local kinds = { gold = true, bones = true, boost = true, revive = true }
		for _, product in ipairs(m.Products) do
			truthy(kinds[product.kind], "type de produit " .. product.key)
			truthy(product.amount > 0, "quantité de " .. product.key)
		end
		for _, pass in ipairs(m.GamePasses) do
			eq(pass.id, 0, "les identifiants sont à renseigner par l'utilisateur : " .. pass.key)
		end
	end)

	-- ---------------------------------------------------------------- Species
	test("Species : rosters des zones valides et complets", function()
		local used = {}
		for _, zone in ipairs(Config.Zones) do
			truthy(#zone.animals >= 4, zone.key .. " : au moins 4 animaux")
			truthy(zone.heartChance > 0 and zone.heartChance < 1, zone.key .. " : chance de cœur")
			for _, id in ipairs(zone.animals) do
				local def = Species.ById[id]
				truthy(def ~= nil, zone.key .. " : animal inconnu " .. id)
				truthy(not def.boss, zone.key .. " : un boss ne peut pas être dans le roster normal")
				truthy(def.weight > 0, id .. " : poids de tirage")
				used[id] = true
			end
			local boss = Species.ById[zone.boss]
			truthy(boss ~= nil and boss.boss == true, zone.key .. " : boss valide")
			truthy(boss.value > 5, zone.key .. " : un boss rapporte beaucoup")
		end
		for _, def in ipairs(Species.List) do
			if not def.boss then
				truthy(used[def.id], def.id .. " n'apparaît dans aucune zone")
			end
		end
	end)

	test("Species : vitesses, durées et pièces bien formées", function()
		local keys = { body = true, dark = true, light = true, accent = true, eye = true }
		local count = 0
		for _, def in ipairs(Species.List) do
			count = count + 1
			truthy(def.speed > 20 and def.value > 0, def.id)
			truthy(Species.ById[def.id] == def, "index par id")
			if def.buckAfter and not def.boss then
				truthy(
					def.buckAfter >= def.tameTime + Config.Run.CollectWindow,
					def.id .. " : le temps de récupération doit tenir avant le désarçonnement"
				)
			end
			truthy(def.palette[def.body.c], def.id .. " : palette du corps")
			for _, part in ipairs(def.parts) do
				truthy(keys[part.c] and (part.c == "eye" or def.palette[part.c]), def.id .. "/" .. part.n .. " couleur")
				truthy(part.s.X > 0 and part.s.Y > 0 and part.s.Z > 0, def.id .. "/" .. part.n .. " taille")
			end
			for _, leg in ipairs(def.legs) do
				truthy(leg.hip.Y < 0, def.id .. "/" .. leg.n .. " attache sous le corps")
			end
			truthy(def.seat.Y > 0, def.id .. " : selle")
			if not def.flying then
				local legLength = def.legs[1] and def.legs[1].s.Y or 0
				truthy(math.abs(def.rootY - (legLength + def.body.s.Y / 2)) < 0.01, def.id .. " : hauteur au sol")
			end
		end
		eq(count, 18, "14 animaux + 4 boss")
	end)

	test("Species : boss = versions agrandies, une seule variante", function()
		local bosses = 0
		for _, def in ipairs(Species.List) do
			if def.boss then
				bosses = bosses + 1
				eq(Species.variantCount(def, #Config.Variants), 1, def.id)
				truthy(def.bossRide > 0, def.id .. " : durée de confiance")
			else
				eq(Species.variantCount(def, #Config.Variants), #Config.Variants, def.id)
			end
		end
		eq(bosses, #Config.Zones, "un boss par zone")
		truthy(
			Species.ById.elephant.body.s.Z > Species.ById.mammoth.body.s.Z,
			"l'éléphant Alpha est plus grand que le mammouth"
		)
	end)

	test("Species : une aile à gauche et une à droite pour la wyverne", function()
		local def = Species.ById.wyvern
		eq(#def.wings, 2)
		eq(def.wings[1].side + def.wings[2].side, 0)
		truthy(def.flying == true)
		local dragon = Species.ById.dragon
		eq(#dragon.wings, 2, "le dragon garde ses ailes")
	end)

	test("Config : énigmes (une par animal normal, réponses valides)", function()
		local answers = {}
		for _, riddle in ipairs(Config.Riddles) do
			local def = Species.ById[riddle.answer]
			truthy(def ~= nil and not def.boss, "réponse valide : " .. tostring(riddle.answer))
			truthy(#riddle.text > 20, "texte de l'énigme " .. riddle.answer)
			truthy(not answers[riddle.answer], "réponse en double " .. riddle.answer)
			answers[riddle.answer] = true
		end
		for _, def in ipairs(Species.List) do
			if not def.boss then
				truthy(answers[def.id], "pas d'énigme pour " .. def.id)
			end
		end
		truthy(Config.RiddleReward.gold > 0 and Config.RiddleReward.bones > 0, "récompense")
	end)

	-- ---------------------------------------------------------------- Zoo (économie)
	test("Zoo : clés d'animaux", function()
		eq(Zoo.key("boar", 2), "boar_2")
		local def, variant = Zoo.parseKey("zebra_3")
		eq(def.id, "zebra")
		eq(variant, 3)
		truthy(Zoo.parseKey("boar_9") == nil, "variante inexistante")
		truthy(Zoo.parseKey("inconnu_1") == nil, "espèce inconnue")
		truthy(Zoo.parseKey("elephant_2") == nil, "un boss n'a qu'une variante")
		truthy(Zoo.parseKey(42) == nil, "type invalide")
		truthy(Zoo.parseKey("dragon_1") ~= nil, "boss valide")
	end)

	test("Zoo : revenus et niveaux des animaux", function()
		local boar = Species.ById.boar
		eq(Zoo.animalIncome(boar, 1, 1), 6, "phacochère niveau 1")
		eq(math.floor(Zoo.animalIncome(boar, 1, 3) * 100 + 0.5), 1080, "niveau 3 : +80 %")
		eq(Zoo.animalIncome(boar, 3, 1), 24, "variante dorée x4")
		truthy(
			Zoo.animalIncome(Species.ById.dragon, 1, 1) > Zoo.animalIncome(Species.ById.lion, 3, 1) / 2,
			"un boss est très rentable"
		)
		eq(
			Zoo.baseIncome({ boar_1 = { level = 1 }, boar_3 = { level = 1 }, faux_1 = { level = 5 } }),
			30,
			"somme des revenus (clés invalides ignorées)"
		)
	end)

	test("Zoo : coût des améliorations en os", function()
		local boar = Species.ById.boar
		eq(Zoo.upgradeCost(boar, 1, 1), 3)
		eq(Zoo.upgradeCost(boar, 1, 2), 5)
		eq(Zoo.upgradeCost(boar, 3, 1), 8, "variante dorée plus chère")
		eq(Zoo.upgradeCost(boar, 1, Config.Zoo.MaxAnimalLevel), nil, "niveau maximum")
		for level = 2, Config.Zoo.MaxAnimalLevel - 1 do
			truthy(Zoo.upgradeCost(boar, 1, level) > Zoo.upgradeCost(boar, 1, level - 1), "coûts croissants")
		end
		truthy(Zoo.upgradeCost(Species.ById.dragon, 1, 1) > Zoo.upgradeCost(boar, 1, 1), "boss plus cher")
	end)

	test("Zoo : os des doublons", function()
		eq(Zoo.duplicateBones(Species.ById.boar, 1), 4)
		eq(Zoo.duplicateBones(Species.ById.boar, 3), 16)
		eq(Zoo.duplicateBones(Species.ById.sphinx, 1), Config.Zoo.BossBones)
	end)

	test("Zoo : visiteurs et enclos", function()
		eq(Zoo.visitorFactor(0, false), 1)
		eq(math.floor(Zoo.visitorFactor(2, false) * 100 + 0.5), 120)
		eq(math.floor(Zoo.visitorFactor(2, true) * 100 + 0.5), 180, "Zoo Premium x1,5")
		eq(Zoo.slots(0, false), 6)
		eq(Zoo.slots(3, false), 12)
		eq(Zoo.slots(6, false), 18)
		eq(Zoo.slots(6, true), 24, "plafonné au nombre d'enclos construits")
		eq(Zoo.slots(0, true), 12)
	end)

	test("Zoo : caisse (revenu hors ligne, plafond, boost)", function()
		local now = 1000000
		eq(Zoo.pendingGold(60, now - 600, now, 0, 0), 600, "10 min à 60 or/min")
		eq(Zoo.pendingGold(60, now - 5000, now, 0, 0), 1200, "plafonné à 20 min")
		eq(Zoo.pendingGold(60, now - 5000, now, 2, 0), 2400, "capacité étendue : 40 min")
		eq(Zoo.pendingGold(60, now + 100, now, 0, 0), 0, "horloge incohérente")
		eq(Zoo.pendingGold(60, now - 600, now, 0, now + 1000), 1200, "boost actif x2")
		eq(Zoo.pendingGold(60, now - 600, now, 0, now - 300), 900, "boost fini à mi-chemin")
		eq(Zoo.pendingGold(60, now - 600, now, 0, now - 5000), 600, "boost expiré avant")
		eq(Zoo.pendingGold(0, now - 600, now, 0, 0), 0, "zoo vide")
	end)

	test("Zoo : or d'expédition", function()
		eq(Zoo.runGold(1000, 0, false), 50)
		eq(Zoo.runGold(1000, 2, false), 60, "boutique de souvenirs niveau 2")
		eq(Zoo.runGold(1000, 2, true), 120, "pass Or x2")
		eq(Zoo.runGold(0, 5, true), 0)
	end)

	test("Zoo : déblocage des zones par nombre d'animaux", function()
		local animals = { boar_1 = {}, zebra_1 = {}, ostrich_1 = {}, rhino_1 = {} }
		eq(Zoo.countOwned(animals), 4)
		truthy(Zoo.zoneUnlocked(Config.Zones[1], animals), "savane toujours libre")
		truthy(Zoo.zoneUnlocked(Config.Zones[2], animals), "marais à 4 animaux")
		truthy(not Zoo.zoneUnlocked(Config.Zones[3], animals), "désert verrouillé")
		animals.fake_9 = {}
		eq(Zoo.countOwned(animals), 4, "les clés invalides ne comptent pas")
	end)

	return failures, passed
end
