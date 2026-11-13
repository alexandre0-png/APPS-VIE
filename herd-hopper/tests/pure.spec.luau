-- Tests de la logique pure (aucune API Roblox requise hormis Vector3 / Color3).
-- Le fichier renvoie une fonction (Config, Species, Util, Zoo) -> échecs, réussites.
-- Exécutable avec Lune (tools/lune/run.luau) ou avec la simulation fengari (node tools/sim/run.js UNIT).

return function(Config, Species, Util, Zoo, AnimMath, Plan)
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

	-- ---------------------------------------------------------------- Animations
	test("Config.Animations : interrupteurs complets", function()
		local expected =
			{ "Walk", "Jump", "HeartReact", "Capture", "Joy", "Lasso", "ZoneIntro", "ZoneTransition", "Boss", "Death" }
		eq(type(Config.Animations.Enabled), "boolean", "interrupteur général")
		for _, key in ipairs(expected) do
			eq(type(Config.Animations[key]), "boolean", "interrupteur " .. key)
		end
		local count = 0
		for _ in pairs(Config.Animations) do
			count = count + 1
		end
		eq(count, #expected + 1, "aucun interrupteur inconnu")
	end)

	test("AnimMath : bornes et courbes d'adoucissement", function()
		eq(AnimMath.clamp01(-1), 0)
		eq(AnimMath.clamp01(2), 1)
		eq(AnimMath.easeOutQuad(0), 0)
		eq(AnimMath.easeOutQuad(1), 1)
		eq(AnimMath.easeInOut(0.5), 0.5)
		eq(AnimMath.easeOutBack(0), 0)
		eq(AnimMath.easeOutBack(1), 1)
		truthy(AnimMath.easeOutBack(0.6) > 1, "dépassement du pop")
		local previous = -1
		for i = 0, 10 do
			local v = AnimMath.easeInOut(i / 10)
			truthy(v >= previous, "croissance")
			previous = v
		end
	end)

	test("AnimMath : marche, saut, ailes", function()
		for t = 0, 3, 0.25 do
			local walk = AnimMath.gait(t, 8, 0, 0, 0)
			truthy(math.abs(walk) <= 0.7001, "amplitude au sol")
			local joy = AnimMath.gait(t, 8, 0, 0, 1)
			truthy(math.abs(joy) <= 1.0501, "amplitude joyeuse")
		end
		eq(AnimMath.tuck(0), 0)
		eq(AnimMath.tuck(5), 1)
		eq(AnimMath.gait(1, 8, 0, 5, 0), -0.9, "pattes repliées en l'air")
		truthy(math.abs(AnimMath.flap(1, 60)) <= 0.5501, "amplitude d'aile")
	end)

	test("AnimMath : cœur, capture et joie", function()
		eq(AnimMath.heartPop(0), 0)
		eq(AnimMath.heartPop(1), 1)
		local rise0, spin0 = AnimMath.capture(0)
		eq(rise0, 0)
		eq(spin0, 0)
		local rise1, spin1, hop1 = AnimMath.capture(1)
		eq(rise1, 16)
		truthy(math.abs(spin1 - math.pi * 4) < 1e-9, "deux tours")
		truthy(math.abs(hop1) < 1e-9, "rebond nul à la fin")
		local midRise, _, midHop = AnimMath.capture(0.5)
		truthy(midRise > 8 and midHop > 2.9, "à mi-parcours")
		local y0 = AnimMath.joy(-1, 2.5)
		eq(y0, 0, "avant le début")
		local yEnd = AnimMath.joy(2.6, 2.5)
		eq(yEnd, 0, "après la fin")
		local maxY = 0
		for t = 0.05, 2.4, 0.05 do
			local y = AnimMath.joy(t, 2.5)
			truthy(y >= 0 and y <= 2.2001, "rebond borné")
			maxY = math.max(maxY, y)
		end
		truthy(maxY > 1, "la joie rebondit vraiment")
	end)

	test("AnimMath : lasso, bras, balayage, étoiles, fumée, boss, zoom", function()
		local c0, w0 = AnimMath.lassoCurve(0)
		local c1, w1 = AnimMath.lassoCurve(1)
		truthy(c0 > c1 and c1 == 0, "la corde se tend")
		truthy(w1 > w0, "la corde s'épaissit")
		eq(AnimMath.loopRadius(0, 10, 4), 10)
		eq(AnimMath.loopRadius(1, 10, 4), 4)
		eq(AnimMath.throwArm(-0.1), 0)
		eq(AnimMath.throwArm(0.5), 0)
		truthy(AnimMath.throwArm(0.12) < -2.3, "bras armé")
		truthy(AnimMath.throwArm(0.3) > 1.1, "bras lancé")
		local x0, a0 = AnimMath.wipe(0)
		local x1, a1 = AnimMath.wipe(1)
		local _, aMid = AnimMath.wipe(0.5)
		eq(x0, -1)
		eq(x1, 1)
		eq(a0, 0)
		eq(a1, 0)
		truthy(aMid > 0.5, "opacité maximale au milieu")
		for i = 1, 4 do
			local x, z = AnimMath.orbit(0.7, i, 4, 3)
			truthy(math.abs(math.sqrt(x * x + z * z) - 3) < 1e-9, "étoile sur le cercle")
		end
		local s0, t0 = AnimMath.poof(0)
		local s1, t1 = AnimMath.poof(1)
		truthy(s1 > s0 and t1 > t0, "la fumée grossit et s'estompe")
		for age = 0, 5, 0.1 do
			local stomp = AnimMath.bossStomp(age)
			truthy(stomp >= 0 and stomp <= 1.2001, "piétinement borné")
		end
		local e, h = AnimMath.flyover(1)
		eq(e, 1)
		eq(h, 14)
		eq(select(2, AnimMath.flyover(0)), 60)
		eq(AnimMath.fovPunch(-1, 1, 14), 0)
		eq(AnimMath.fovPunch(2, 1, 14), 0)
		truthy(math.abs(AnimMath.fovPunch(0.2, 1, 14) - 14) < 1e-9, "pic du zoom")
		truthy(AnimMath.fovPunch(0.6, 1, 14) < 14, "retour progressif")
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

	test("Modèles du catalogue : configuration cohérente", function()
		local a = Config.Assets
		truthy(a.LoadTimeout > 0 and a.MaxParts > 0 and a.LengthFactor > 0)
		local ids = {}
		for _, pack in ipairs(a.Animals) do
			truthy(type(pack.id) == "number" and pack.id > 0, "identifiant de pack")
			truthy(not ids[pack.id], "identifiant en double")
			ids[pack.id] = true
			for _, key in ipairs(pack.zones) do
				truthy(Config.zoneByKey(key) ~= nil, "zone inconnue " .. key)
			end
		end
		for _, item in ipairs(a.DecorItems) do
			truthy(type(item.id) == "number" and not ids[item.id], "identifiant de décor")
			ids[item.id] = true
			truthy(item.height > 0 and item.count > 0)
			for _, key in ipairs(item.zones) do
				truthy(Config.zoneByKey(key) ~= nil, "zone inconnue " .. key)
			end
		end
		for _, def in ipairs(Species.List) do
			truthy(a.Aliases[def.id] ~= nil and #a.Aliases[def.id] > 0, "mots-clés manquants : " .. def.id)
		end
	end)

	test("Cinématiques : config et durées", function()
		local cfg = Config.Cinematics
		truthy(cfg.Enabled ~= nil and cfg.MaxSeconds > 0 and cfg.GraceSeconds >= 0)
		local keys = { "intro", "tutorial", "zone_2", "zone_3", "zone_4" }
		for _, zone in ipairs(Config.Zones) do
			table.insert(keys, "boss_" .. zone.boss)
		end
		for _, key in ipairs(keys) do
			local shots = Plan.sequenceFor(key)
			truthy(shots ~= nil, key)
			truthy(Plan.total(shots) <= cfg.MaxSeconds, key .. " dépasse MaxSeconds")
			truthy(Plan.total(shots) >= 8, key .. " trop courte")
			for _, shot in ipairs(shots) do
				truthy(shot.dur > 0 and #shot.caption > 0, key)
			end
		end
	end)

	test("Cinématiques : clés valides / invalides", function()
		truthy(Plan.validKey("intro"))
		truthy(Plan.validKey("zone_2"))
		truthy(not Plan.validKey("zone_1"), "la première zone n'a pas de cinématique")
		truthy(not Plan.validKey("zone_99"))
		truthy(not Plan.validKey("boss_boar"), "un animal normal n'est pas un boss")
		truthy(not Plan.validKey("boss_"))
		truthy(not Plan.validKey(""))
		truthy(not Plan.validKey(nil))
		truthy(not Plan.validKey(42))
		truthy(not Plan.validKey("intro; drop"))
	end)

	test("Cinématiques : shotAt aux frontières", function()
		local shots = Plan.sequenceFor("intro")
		local i, p = Plan.shotAt(shots, 0)
		eq(i, 1)
		eq(p, 0)
		i = Plan.shotAt(shots, shots[1].dur)
		eq(i, 2, "bascule exacte au plan suivant")
		i = Plan.shotAt(shots, Plan.total(shots) - 0.01)
		eq(i, #shots)
		i = Plan.shotAt(shots, Plan.total(shots))
		eq(i, nil, "fin de séquence")
	end)

	test("Cinématiques : état, durée, passage et reprise", function()
		local shots = Plan.sequenceFor("tutorial")
		local state = Plan.newState(shots, 45)
		eq(state.total, 20)
		for _ = 1, 100 do
			Plan.step(state, 0.1)
		end
		truthy(not state.done, "10 s sur 20 : pas finie")
		for _ = 1, 150 do
			Plan.step(state, 0.1)
		end
		truthy(state.done and state.t == 20, "finie et bornée")
		truthy(Plan.completed(state))
		-- passage : fige l'état, plus aucun avancement
		local s2 = Plan.newState(shots, 45)
		Plan.step(s2, 1)
		Plan.skip(s2)
		truthy(s2.skipped and s2.done and Plan.completed(s2))
		local before = s2.t
		Plan.step(s2, 5)
		eq(s2.t, before, "aucun avancement après passage")
		-- interruption immédiate : non considérée comme vue, donc reproposée
		local s3 = Plan.newState(shots, 45)
		Plan.step(s3, 0.5)
		truthy(not Plan.completed(s3), "interrompue à 0,5 s : sera reproposée")
		Plan.step(s3, 3)
		truthy(Plan.completed(s3), "assez regardée")
		-- plafond MaxSeconds
		eq(Plan.newState(shots, 7).total, 7)
	end)

	test("Cinématiques : choix des cinématiques à jouer", function()
		local cfg = Config.Cinematics
		local fresh = { seen = {}, zones = { savane = true }, bossCaptured = {} }
		local list = Plan.pending(fresh, cfg)
		eq(#list, 2)
		eq(list[1], "intro", "l'intro d'abord")
		eq(list[2], "tutorial")
		local data = {
			seen = { intro = true, tutorial = true },
			zones = { savane = true, [Config.Zones[2].key] = true },
			bossCaptured = { [Config.Zones[1].boss] = true },
		}
		list = Plan.pending(data, cfg)
		eq(#list, 2)
		eq(list[1], "zone_2")
		eq(list[2], "boss_" .. Config.Zones[1].boss)
		data.seen.zone_2 = true
		data.seen["boss_" .. Config.Zones[1].boss] = true
		eq(#Plan.pending(data, cfg), 0, "tout est vu")
		-- interrupteurs
		local off = { Enabled = false, Intro = true, Tutorial = true, ZoneOpening = true, BossCaptured = true }
		eq(#Plan.pending(fresh, off), 0, "désactivé globalement")
		local noIntro = { Enabled = true, Intro = false, Tutorial = true, ZoneOpening = false, BossCaptured = false }
		local only = Plan.pending(fresh, noIntro)
		eq(#only, 1)
		eq(only[1], "tutorial")
		eq(#Plan.pending(nil, cfg), 0, "données absentes")
	end)

	return failures, passed
end
