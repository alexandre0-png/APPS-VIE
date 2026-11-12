-- Tests de la logique pure (aucune API Roblox requise hormis Vector3 / Color3).
-- Le fichier renvoie une fonction (Config, Species, Util) -> nombre d'échecs.
-- Exécutable avec Lune (tools/lune/run.luau) ou avec la simulation fengari (node tools/sim/run.js UNIT).

return function(Config, Species, Util)
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
	test("Config : biomes contigus et couvrant la piste", function()
		eq(Config.biomeAt(-100).key, "savane")
		eq(Config.biomeAt(899).key, "savane")
		eq(Config.biomeAt(900).key, "desert")
		eq(Config.biomeAt(1700).key, "forest")
		eq(Config.biomeAt(2500).key, "volcano")
		eq(Config.biomeAt(99999).key, "volcano")
		for i = 2, #Config.Biomes do
			eq(Config.Biomes[i].from, Config.Biomes[i - 1].to, "biome " .. i .. " contigu")
		end
		truthy(Config.Track.FinishZ > Config.Biomes[#Config.Biomes].from, "arrivée dans le dernier biome")
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
		unique(Config.Upgrades, "amélioration")
		unique(Config.QuestPool, "quête")
		unique(Config.Monetization.GamePasses, "pass")
		unique(Config.Monetization.Products, "produit")
		unique(Species.List, "espèce")
	end)

	test("Config : tarifs et niveaux cohérents", function()
		for _, up in ipairs(Config.Upgrades) do
			eq(#up.costs, up.max, "coûts de " .. up.id)
			for i = 2, #up.costs do
				truthy(up.costs[i] > up.costs[i - 1], "coûts croissants pour " .. up.id)
			end
		end
		eq(Config.findById(Config.Hats, "none").price, 0, "chapeau gratuit")
		eq(Config.findById(Config.Ropes, "classic").price, 0, "corde gratuite")
		truthy(Config.findById(Config.Hats, "inconnu") == nil, "findById absent")
	end)

	test("Config : variantes et quêtes", function()
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
		for _, ratio in ipairs({ Config.Score.Finish[1], Config.Score.Finish[2], Config.Score.Finish[3] }) do
			truthy(ratio > Config.Score.FinishOther, "bonus d'arrivée")
		end
	end)

	test("Config : le mur de lave reste battable puis devient dangereux", function()
		local w = Config.Wall
		truthy(w.Speed0 < 25, "départ plus lent que le mammouth (25)")
		truthy(w.MaxSpeed > 38, "finit plus vite que le sanglier (38)")
		truthy(w.MaxSpeed >= w.Speed0, "plafond cohérent")
		local reaches = (w.MaxSpeed - w.Speed0) / w.Accel
		truthy(reaches < Config.Round.Duration, "le plafond est atteint avant la fin de la manche")
	end)

	test("Config : durées de dressage et de désarçonnement", function()
		truthy(Config.Tame.MinTime > 0)
		for _, def in ipairs(Species.List) do
			local fastest = math.max(Config.Tame.MinTime, def.tameTime * (1 - Config.Tame.PerLevel * 5))
			truthy(fastest >= Config.Tame.MinTime, def.id)
			if def.buckAfter then
				truthy(def.buckAfter > def.tameTime, def.id .. " : dressage possible avant désarçonnement")
			end
		end
	end)

	-- ---------------------------------------------------------------- Species
	test("Species : poids, vitesses et valeurs", function()
		local total = 0
		for _, def in ipairs(Species.List) do
			total = total + def.weight
			truthy(def.speed > Config.Wall.Speed0, def.id .. " plus rapide que le départ du mur")
			truthy(def.value > 0, def.id)
			truthy(Species.ById[def.id] == def, "index par id")
		end
		eq(total, 100, "somme des poids")
		eq(#Species.List, 7, "nombre d'espèces")
	end)

	test("Species : pièces bien formées", function()
		local keys = { body = true, dark = true, light = true, accent = true, eye = true }
		for _, def in ipairs(Species.List) do
			truthy(def.palette[def.body.c], def.id .. " : palette du corps")
			for _, part in ipairs(def.parts) do
				truthy(keys[part.c] and (part.c == "eye" or def.palette[part.c]), def.id .. "/" .. part.n .. " couleur")
				truthy(part.s.X > 0 and part.s.Y > 0 and part.s.Z > 0, def.id .. "/" .. part.n .. " taille")
			end
			for _, leg in ipairs(def.legs) do
				truthy(leg.hip.Y < 0, def.id .. "/" .. leg.n .. " attache sous le corps")
			end
			truthy(def.seat.Y > def.body.s.Y / 2, def.id .. " : selle au-dessus du dos")
			if not def.flying then
				local legLength = def.legs[1] and def.legs[1].s.Y or 0
				truthy(math.abs(def.rootY - (legLength + def.body.s.Y / 2)) < 0.01, def.id .. " : hauteur au sol")
			end
		end
	end)

	test("Species : une aile à gauche et une à droite pour la wyverne", function()
		local def = Species.ById.wyvern
		eq(#def.wings, 2)
		eq(def.wings[1].side + def.wings[2].side, 0)
		truthy(def.flying == true)
	end)

	return failures, passed
end
