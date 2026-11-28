--!nocheck
-- Tests de l'IDÉE 2 « Évolution des pets » (forme 2). Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime? }
-- fournis par tests/run_evolution.py (lupa) ou tests/run.luau (Lune).
-- Partie 1 : configuration et garde-fous (aucune forme payante). Partie 2 : règle « force croît avec la rareté » sur les 10 raretés et sur chaque espèce
-- du bestiaire (78), règle de revenu. Partie 3 : assainissement et migration. Partie 4 : plan (doublons, interdits, coût). Partie 5 : atomicité
-- (stage / stillValid / apply). Partie 6 : économie (Rules.income, revente par lot, joueur-robot du lot 9 inchangé, pire cas borné).
-- Partie 7 : bout en bout avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice) : migration v13 -> v14, évolution, panne de sauvegarde.
-- Style : pas de `+=`, pas de `continue` (compatibilité lupa).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local color = {
		fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
	}
	local function loadConfig()
		return luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = { Color3 = color } })()
	end
	local Config = loadConfig()
	local Evolution = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Evolution.lua"), { debugName = "Evolution" })()
	local Bestiary = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Bestiary.lua"), { debugName = "Bestiary", environment = { Color3 = color } })()
	local PetXp = luau.load(fs.readFile("roblox/src/ReplicatedStorage/PetXp.lua"), { debugName = "PetXp" })()
	local Battle = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Battle.lua"), {
		debugName = "Battle",
		environment = {
			script = { Parent = {
				WaitForChild = function(_, n)
					return n
				end,
			} },
			require = function(n)
				return ({ Bestiary = Bestiary, PetXp = PetXp })[n]
			end,
		},
	})()
	local function clone(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	local function deep(v)
		if type(v) ~= "table" then
			return v
		end
		local c = {}
		for k, x in pairs(v) do
			c[k] = deep(x)
		end
		return c
	end
	local function power(u)
		return Battle.power({ hp = u.maxHp, atk = u.atk, spd = u.spd })
	end
	-- Config avec l'évolution ACTIVÉE (copie : la source garde enabled = false)
	local On = clone(Config)
	On.EVOLUTION = clone(Config.EVOLUTION)
	On.EVOLUTION.enabled = true
	local E = Config.EVOLUTION

	---------------------------------------------------------------- 1. Configuration et garde-fous
	suite("Idée 2 (évolution) : configuration, aucune forme payante")
	check(
		"Config.EVOLUTION : 3 doublons, 5 min de revenus, revenu x1,15, force x1,10, forme max 2, désactivée dans la source (activer après Studio)",
		E.enabled == false and E.sacrifices == 3 and E.costSeconds == 300 and E.incomeMul == 1.15 and E.powerMul == 1.10 and E.maxForm == 2 and E.visualScale > 1
	)
	check(
		"Interdits documentés : Géant et Colossal (tailles 4, 5), Arc-en-ciel, Alien, Céleste (mutations 4, 5, 6) ; Mini / Normal / Grand et sans mutation / Doré / Néon autorisés",
		Config.SIZES[4].name == "Géant"
			and Config.SIZES[5].name == "Colossal"
			and Config.MUTS[4].name == "Arc-en-ciel"
			and E.blockedSizes[4]
			and E.blockedSizes[5]
			and E.blockedMuts[4]
			and E.blockedMuts[5]
			and E.blockedMuts[6]
			and not E.blockedSizes[1]
			and not E.blockedSizes[2]
			and not E.blockedSizes[3]
			and not E.blockedMuts[1]
			and not E.blockedMuts[2]
			and not E.blockedMuts[3]
	)
	do
		local function code(txt) -- sans les commentaires (« -- ... » jusqu'à la fin de ligne)
			local out = {}
			for line in (txt .. "\n"):gmatch("(.-)\n") do
				local cut = line:find("--", 1, true)
				out[#out + 1] = cut and line:sub(1, cut - 1) or line
			end
			return table.concat(out, "\n")
		end
		local src = code(fs.readFile("roblox/src/ReplicatedStorage/Evolution.lua"))
		local main = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
		local a = main:find("function actions.evolve", 1, true)
		local b = a and main:find("\n%-%- Dialogue de la Mère Poule", a)
		local region = (a and b) and code(main:sub(a, b)) or ""
		local pay = false
		for _, w in ipairs({ "Robux", "MarketplaceService", "PromptProductPurchase", "PASSES", "PRODUCTS", "receipt", "passOn", "Prompt" }) do
			if src:find(w, 1, true) or region:find(w, 1, true) then
				pay = true
			end
		end
		check(
			"Aucune forme payante : ni Evolution.lua ni l'action evolve ne lisent un produit, un pass ou des Robux ; aucun produit EVOLUTION dans Config.PRODUCTS",
			not pay
				and region ~= ""
				and (function()
					for k in pairs(Config.PRODUCTS) do
						if tostring(k):lower():find("evo", 1, true) then
							return false
						end
					end
					return true
				end)()
		)
		local rp = main:find("MarketplaceService.ProcessReceipt = function", 1, true)
		local rr = rp and main:sub(rp, rp + 14000) or ""
		check("ProcessReceipt ne touche ni slot.f, ni evo, ni Evolution", rp ~= nil and rr:find("Evolution", 1, true) == nil and rr:find("%.f%s*=") == nil and rr:find("evo", 1, true) == nil)
	end

	---------------------------------------------------------------- 2. Règle « force croît avec la rareté » (10 raretés) et revenu
	suite("Idée 2 : la forme 2 d'une rareté reste sous la forme 1 de la rareté supérieure (10 raretés, 78 espèces)")
	-- règle évaluée pour un multiplicateur donné : pour chaque rareté r < 10, chaque taille et mutation AUTORISÉES, chaque niveau 1..20 :
	-- puissance(forme 2, r) < puissance(forme 1, r + 1) ; retourne (ok, plus petit rapport, nombre de comparaisons)
	local function forceRule(mul)
		local ok, minRatio, n = true, math.huge, 0
		for r = 1, #Battle.STATS - 1 do
			for s = 1, #Config.SIZES do
				for m = 1, #Config.MUTS do
					if not E.blockedSizes[s] and not E.blockedMuts[m] then
						for L = 1, Battle.MAX_LEVEL do
							local f2 = Battle.rawUnit({ tier = r, size = s, mut = m, level = L, scale = mul })
							local up = Battle.rawUnit({ tier = r + 1, size = s, mut = m, level = L })
							local ratio = power(up) / power(f2)
							minRatio = math.min(minRatio, ratio)
							n = n + 1
							if not (power(f2) < power(up)) then
								ok = false
							end
						end
					end
				end
			end
		end
		return ok, minRatio, n
	end
	do
		local ok, minRatio, n = forceRule(E.powerMul)
		check(
			string.format(
				"10 raretés x 3 tailles x 3 mutations x 20 niveaux (%d comparaisons) : forme 2 (x%.2f) < forme 1 de la rareté supérieure ; plus petit écart x%.3f",
				n,
				E.powerMul,
				minRatio
			),
			ok and n == 9 * 3 * 3 * 20 and #Battle.STATS == 10
		)
		local okHi = forceRule(1.3)
		check("Le test a des dents : avec une force x1,30 (au lieu de x1,10) la règle serait violée, donc le multiplicateur est bien contrôlé", okHi == false)
		local okGF = true
		for r = 1, #Battle.STATS - 1 do
			for _, s in ipairs({ 4, 5 }) do -- même un Géant / Colossal en forme 2 (interdit) resterait sous la rareté suivante, à taille égale
				local f2 = Battle.rawUnit({ tier = r, size = s, mut = 6, level = 20, scale = E.powerMul })
				local up = Battle.rawUnit({ tier = r + 1, size = s, mut = 6, level = 20 })
				okGF = okGF and power(f2) < power(up)
			end
		end
		check("Marge : même hors des tailles autorisées (Géant / Colossal, Céleste, niveau 20), la forme 2 reste sous la rareté suivante à conditions égales", okGF)
	end
	do
		-- chaque espèce du bestiaire (78) : Battle.unit avec l'échelle d'Evolution.powerScale, comparée à TOUTES les espèces de rareté supérieure
		local Cfg78 = clone(Config)
		Cfg78.PETS = Bestiary.PETS
		local byTier = {}
		for p, def in ipairs(Bestiary.PETS) do
			byTier[def.tier] = byTier[def.tier] or {}
			table.insert(byTier[def.tier], p)
		end
		local ok, n, raised = true, 0, true
		for p, def in ipairs(Bestiary.PETS) do
			for _, sm in ipairs({ { 1, 1 }, { 2, 1 }, { 3, 3 }, { 2, 2 } }) do
				for _, x in ipairs({ 0, PetXp.MAX_XP }) do
					local pet = { k = "p", p = p, s = sm[1], m = sm[2], x = x, f = 2 }
					local u2 = Battle.unit(Cfg78, pet, Evolution.powerScale(On, pet))
					local u1 = Battle.unit(Cfg78, { p = p, s = sm[1], m = sm[2], x = x })
					raised = raised and power(u2) > power(u1) and u2.maxHp > u1.maxHp and u2.atk >= u1.atk and u2.spd == u1.spd
					for t = def.tier + 1, 10 do
						for _, q in ipairs(byTier[t] or {}) do
							local uq = Battle.unit(Cfg78, { p = q, s = sm[1], m = sm[2], x = x })
							n = n + 1
							if not (power(u2) < power(uq)) then
								ok = false
							end
						end
					end
				end
			end
		end
		check(
			string.format("78 espèces : forme 2 (Battle.unit + Evolution.powerScale) < toute espèce de rareté supérieure à taille, mutation et niveau égaux (%d comparaisons)", n),
			ok and #Bestiary.PETS == 78 and n > 1000
		)
		check(
			"La forme 2 renforce bien pv et attaque (vitesse inchangée, comme les bonus de taille et de niveau) ; forme 1 : échelle nil (aucun changement)",
			raised and Evolution.powerScale(On, { k = "p", p = 1, s = 2, m = 1 }) == nil and Evolution.powerScale(On, { k = "e", f = 2 }) == nil
		)
		-- revenu : forme 2 de la meilleure espèce d'une rareté < forme 1 de la plus faible espèce de la rareté suivante PEUPLÉE (mêmes taille et mutation)
		local okI, txt = true, ""
		local tiers = {}
		for t = 1, 10 do
			if byTier[t] then
				tiers[#tiers + 1] = t
			end
		end
		for k = 1, #tiers - 1 do
			local hi, lo = 0, math.huge
			for _, p in ipairs(byTier[tiers[k]]) do
				hi = math.max(hi, Cfg78.PETS[p].inc)
			end
			for _, p in ipairs(byTier[tiers[k + 1]]) do
				lo = math.min(lo, Cfg78.PETS[p].inc)
			end
			if not (hi * E.incomeMul < lo) then
				okI = false
			end
			txt = txt .. string.format(" r%d->r%d x%.2f", tiers[k], tiers[k + 1], lo / (hi * E.incomeMul))
		end
		check("Revenu : forme 2 (x1,15) de la meilleure espèce d'une rareté < forme 1 de la plus faible de la rareté suivante :" .. txt, okI and #tiers >= 9)
		check(
			"Config.petIncome : forme 2 = x1,15 exactement, forme 1 / f absent / f invalide = inchangé",
			math.abs(Config.petIncome(5, 3, 2, 2) - Config.petIncome(5, 3, 2) * 1.15) < 1e-9
				and Config.petIncome(5, 3, 2, 1) == Config.petIncome(5, 3, 2)
				and Config.petIncome(5, 3, 2, "2") == Config.petIncome(5, 3, 2)
		)
	end

	---------------------------------------------------------------- 3. Assainissement et migration
	suite("Idée 2 : profil (evo, slot.f), migration v13 -> v14 idempotente")
	do
		local c = Evolution.sanitizeCounts(Config, { ["1"] = 3, ["2"] = 2.7, ["999"] = 4, x = 1, ["3"] = -1, ["4"] = 0 / 0, ["5"] = 1e12, ["6"] = "5", [7] = 2 })
		check(
			"sanitizeCounts : espèces existantes, entiers >= 1, plafond 1e6 ; inconnues, négatifs, NaN, chaînes retirés ; clé numérique ramenée en chaîne",
			c["1"] == 3 and c["2"] == 2 and c["999"] == nil and c.x == nil and c["3"] == nil and c["4"] == nil and c["5"] == 1e6 and c["6"] == nil and c["7"] == 2
		)
		local again = Evolution.sanitizeCounts(Config, c)
		local same = true
		for k, v in pairs(c) do
			same = same and again[k] == v
		end
		for k, v in pairs(again) do
			same = same and c[k] == v
		end
		check(
			"sanitizeCounts idempotent ; absent / chaîne / nombre = {}",
			same and next(Evolution.sanitizeCounts(Config, nil)) == nil and next(Evolution.sanitizeCounts(Config, "x")) == nil and next(Evolution.sanitizeCounts(Config, 5)) == nil
		)
		local a = { k = "p", p = 1, s = 2, m = 1, f = 2 }
		local b = { k = "p", p = 1, s = 2, m = 1, f = 3 }
		local c2 = { k = "p", p = 1, s = 2, m = 1, f = "2" }
		local e = { k = "e", t = 1, f = 2 }
		Evolution.sanitizeForm(a)
		Evolution.sanitizeForm(b)
		Evolution.sanitizeForm(c2)
		Evolution.sanitizeForm(e)
		check('sanitizeForm : f = 2 gardé ; 3, "2", f sur un œuf retirés ; idempotent', a.f == 2 and b.f == nil and c2.f == nil and e.f == nil and Evolution.sanitizeForm(a).f == 2)
		local s1 = { ver = 13 }
		Evolution.migrate(s1)
		local s2 = { ver = 13, evo = { ["1"] = 5 } }
		Evolution.migrate(s2)
		Evolution.migrate(s2)
		local s3 = { evo = "corrompu" }
		Evolution.migrate(s3)
		check(
			"migrate : evo = {} si absent ou corrompu ; compteur existant JAMAIS remis à zéro (deux passages)",
			type(s1.evo) == "table" and next(s1.evo) == nil and s2.evo["1"] == 5 and type(s3.evo) == "table"
		)
	end

	---------------------------------------------------------------- 4. Plan : doublons, interdits, coût
	suite("Idée 2 : plan d'évolution (doublons de même rareté, jamais le dernier exemplaire, interdits, coût de 5 min, prix maximal)")
	-- espèces historiques : 1 Poussin, 2 Hamster, 3 Lapin (Commun) ; 4 Chat, 5 Chien, 6 Renard (Rare)
	local function P(p, s, m, extra)
		local t = { k = "p", p = p, s = s or 2, m = m or 1 }
		for k, v in pairs(extra or {}) do
			t[k] = v
		end
		return t
	end
	local function profile(slots, extra)
		local d = { coins = 1e6, slots = {}, equip = {}, evo = {}, battle = { team = {}, pvp = { defense = {} } } }
		for i = 1, 20 do
			d.slots[i] = slots[i] or false
		end
		for k, v in pairs(extra or {}) do
			d[k] = v
		end
		return d
	end
	local ctx = function(t)
		local c = { capacity = 20, income = 10 }
		for k, v in pairs(t or {}) do
			c[k] = v
		end
		return c
	end
	do
		-- base : visé = Poussin (1), doublons Communs : Poussin x2, Hamster x2, Lapin x1 (dernier exemplaire), Chat (Rare) x2
		local d = profile({ P(1), P(1), P(1), P(2), P(2), P(3), P(4), P(4) })
		local plan, code = Evolution.plan(On, d, 1, ctx())
		check(
			"Plan valide : 3 doublons Communs choisis (Poussin, Poussin, puis Hamster : revenu croissant), jamais le Lapin (dernier exemplaire) ni un Rare ; coût 300 x 10 = 3000",
			plan ~= nil and #plan.sac == 3 and plan.sac[1] == 2 and plan.sac[2] == 3 and plan.sac[3] == 4 and plan.cost == 3000 and plan.tier == 1 and plan.p == 1,
			tostring(code)
		)
		local planOff = Evolution.plan(Config, d, 1, ctx())
		check(
			"Source (enabled = false) : refus « disabled » ; aperçu sans référence du profil",
			planOff == nil and select(2, Evolution.plan(Config, d, 1, ctx())) == "disabled" and Evolution.view(On, d, 1, ctx()).ok == true and Evolution.view(On, d, 1, ctx()).sac[3] == 4
		)
		-- jamais le dernier exemplaire : visé Lapin (3e), seuls doublons : Poussin x2 (1 sacrifiable... 2 sur 3), Hamster x2 (1 sacrifiable)
		local d2 = profile({ P(3), P(1), P(1), P(2), P(2) })
		local p2, c2, found = Evolution.plan(On, d2, 1, ctx())
		check("Jamais le dernier exemplaire d'une espèce : Poussin x2 + Hamster x2 = 2 sacrifiables seulement -> refus « dupes » (2 trouvés)", p2 == nil and c2 == "dupes" and found == 2)
		-- le pet visé compte comme exemplaire restant : visé Poussin + 3 autres Poussins -> les 3 sacrifiés
		local d3 = profile({ P(1), P(1), P(1), P(1) })
		local p3 = Evolution.plan(On, d3, 1, ctx())
		check("Le pet visé compte comme exemplaire restant : 4 Poussins -> les 3 autres sont sacrifiables", p3 ~= nil and p3.sac[1] == 2 and p3.sac[3] == 4)
		-- revenu croissant : un Poussin Grand Néon passe après les Poussins normaux
		local d4 = profile({ P(1), P(1, 3, 3), P(1), P(1), P(1) })
		local p4 = Evolution.plan(On, d4, 1, ctx())
		check("Ordre : les doublons qui rapportent le moins d'abord (le Poussin Grand Néon est gardé)", p4 ~= nil and p4.sac[1] == 3 and p4.sac[2] == 4 and p4.sac[3] == 5)
	end
	do
		local base = { P(1), P(1), P(1), P(1), P(1) }
		local function refusal(d, i, c)
			local plan, code = Evolution.plan(On, d, i or 1, c or ctx())
			return plan == nil and code or ("ok:" .. tostring(plan and #plan.sac))
		end
		check("Visé suiveur (equip) : refus « follower »", refusal(profile(base, { equip = { 1 } })) == "follower")
		check("Visé dans l'équipe de combat : refus « team »", refusal(profile(base, { battle = { team = { 1 }, pvp = { defense = {} } } })) == "team")
		check(
			"Visé dont la copie (p, s, m) est dans la défense PvP : refus « defense »",
			refusal(profile(base, { battle = { team = {}, pvp = { defense = { { p = 1, s = 2, m = 1 } } } } })) == "defense"
		)
		check("Défense d'une AUTRE taille : pas de refus", refusal(profile(base, { battle = { team = {}, pvp = { defense = { { p = 1, s = 3, m = 1 } } } } })) == "ok:3")
		local d = profile(base, { equip = { 2 }, battle = { team = { 3 }, pvp = { defense = {} } } })
		check("Suiveur et membre de l'équipe jamais sacrifiés : 2 doublons libres seulement -> « dupes »", refusal(d) == "dupes")
		local d5 = profile({ P(1), P(1), P(1), P(1), P(1), P(1) }, { equip = { 2 }, battle = { team = { 3 }, pvp = { defense = {} } } })
		local p5 = Evolution.plan(On, d5, 1, ctx())
		check("... avec 2 doublons libres de plus : sacrifiés = 4, 5, 6 (suiveur 2 et équipe 3 épargnés)", p5 ~= nil and p5.sac[1] == 4 and p5.sac[2] == 5 and p5.sac[3] == 6)
		check("Visé Géant, Colossal : refus « special »", refusal(profile({ P(1, 4), P(1), P(1), P(1) })) == "special" and refusal(profile({ P(1, 5), P(1), P(1), P(1) })) == "special")
		check(
			"Visé Arc-en-ciel, Alien, Céleste : refus « special » ; Doré, Néon, Grand, Mini : accepté",
			refusal(profile({ P(1, 2, 4), P(1), P(1), P(1) })) == "special"
				and refusal(profile({ P(1, 2, 5), P(1), P(1), P(1) })) == "special"
				and refusal(profile({ P(1, 2, 6), P(1), P(1), P(1) })) == "special"
				and refusal(profile({ P(1, 1, 2), P(1), P(1), P(1) })) == "ok:3"
				and refusal(profile({ P(1, 3, 3), P(1), P(1), P(1) })) == "ok:3"
		)
		check("Géant / Colossal / Arc-en-ciel jamais sacrifiés automatiquement (doublons précieux)", refusal(profile({ P(1), P(1, 4), P(1, 5), P(1, 2, 4), P(1) })) == "dupes")
		check(
			"Déjà en forme 2 : refus « already » ; une forme 2 n'est jamais sacrifiée",
			refusal(profile({ P(1, 2, 1, { f = 2 }), P(1), P(1), P(1) })) == "already" and refusal(profile({ P(1), P(1, 2, 1, { f = 2 }), P(1), P(1) })) == "dupes"
		)
		check(
			"Emplacement vide, œuf, hors capacité, non entier, chaîne : refus « slot »",
			refusal(profile({ false, P(1) }), 1) == "slot"
				and refusal(profile({ { k = "e", t = 1 } }), 1) == "slot"
				and refusal(profile(base), 5, ctx({ capacity = 4 })) == "slot"
				and refusal(profile(base), 1.5) == "slot"
				and refusal(profile(base), "1") == "slot"
				and refusal(profile(base), 0) == "slot"
		)
		check("Combat en cours (busy) : refus « busy »", refusal(profile(base), 1, ctx({ busy = true })) == "busy")
		check(
			"Pièces insuffisantes (coût 3000, solde 2999) : refus « coins » ; solde 3000 : accepté",
			refusal(profile(base, { coins = 2999 })) == "coins" and refusal(profile(base, { coins = 3000 })) == "ok:3"
		)
		check(
			"Prix maximal du client : coût 3000 > 2999 -> « price » ; maxCost non numérique ou NaN -> « price » ; 3000 -> accepté",
			refusal(profile(base), 1, ctx({ maxCost = 2999 })) == "price"
				and refusal(profile(base), 1, ctx({ maxCost = "9e9" })) == "price"
				and refusal(profile(base), 1, ctx({ maxCost = 0 / 0 })) == "price"
				and refusal(profile(base), 1, ctx({ maxCost = 3000 })) == "ok:3"
		)
		check(
			"Coût : 300 s x revenu, arrondi au supérieur ; revenu nul, négatif, NaN, infini = 0",
			Evolution.cost(On, 1.001) == 301
				and Evolution.cost(On, 0) == 0
				and Evolution.cost(On, -5) == 0
				and Evolution.cost(On, 0 / 0) == 0
				and Evolution.cost(On, math.huge) == 0
				and Evolution.cost(On, 2) == 600
		)
		check("Rareté différente jamais utilisée : visé Chat (Rare) + 3 Poussins -> « dupes »", refusal(profile({ P(4), P(1), P(1), P(1), P(1), P(4) })) == "dupes")
		check("Pet d'une espèce inexistante : refus « slot »", refusal(profile({ P(999), P(1), P(1), P(1) })) == "slot")
	end

	---------------------------------------------------------------- 5. Atomicité : stage, stillValid, apply
	suite("Idée 2 : sauvegarde puis octroi (copie « après », profil vivant intact jusqu'au succès)")
	do
		local d = profile({ P(1, 2, 1, { x = 40, o = 12345 }), P(1), P(1), P(2), P(2) }, { coins = 5000, evo = { ["1"] = 2 } })
		local before = deep(d)
		local plan = Evolution.plan(On, d, 1, ctx())
		local post = Evolution.stage(d, plan)
		local untouched = d.coins == 5000 and d.slots[1].f == nil and d.slots[2] ~= false and d.slots[3] ~= false and d.slots[4] ~= false and d.evo["1"] == 2
		check("stage : le profil vivant n'est PAS modifié", untouched and plan ~= nil)
		check(
			'stage : copie après évolution (forme 2, XP et « 1 sur N » gardés, 3 doublons retirés, pièces - 3000, evo["1"] = 3), tables distinctes du vivant',
			post.slots[1].f == 2
				and post.slots[1].x == 40
				and post.slots[1].o == 12345
				and post.slots[1].p == 1
				and post.slots[2] == false
				and post.slots[3] == false
				and post.slots[4] == false
				and post.slots[5] == d.slots[5]
				and post.coins == 2000
				and post.evo["1"] == 3
				and post.slots ~= d.slots
				and post.evo ~= d.evo
				and post.slots[1] ~= d.slots[1]
		)
		-- revenu gagné pendant la sauvegarde : gardé (débit en delta)
		d.coins = d.coins + 777
		check(
			"stillValid avant apply ; apply : pièces 5777 - 3000 = 2777 (le revenu gagné pendant la sauvegarde reste), forme 2 sur la MÊME table, compteur 3",
			Evolution.stillValid(d, plan)
				and Evolution.apply(d, plan)
				and d.coins == 2777
				and d.slots[1] == plan.target
				and d.slots[1].f == 2
				and d.slots[2] == false
				and d.slots[3] == false
				and d.slots[4] == false
				and d.evo["1"] == 3
		)
		check("apply rejoué : refusé (déjà en forme 2), rien ne bouge", Evolution.apply(d, plan) == false and d.coins == 2777 and d.evo["1"] == 3)
		-- un doublon remplacé pendant la sauvegarde : rien n'est appliqué
		local d2 = profile({ P(1), P(1), P(1), P(1) }, { coins = 5000 })
		local plan2 = Evolution.plan(On, d2, 1, ctx())
		d2.slots[3] = P(1)
		local snap = deep(d2)
		check(
			"Doublon remplacé (autre table) : stillValid faux, apply refusé, profil inchangé",
			not Evolution.stillValid(d2, plan2) and Evolution.apply(d2, plan2) == false and d2.coins == 5000 and d2.slots[1].f == nil and d2.slots[2] ~= false
		)
		local d3 = profile({ P(1), P(1), P(1), P(1) }, { coins = 5000 })
		local plan3 = Evolution.plan(On, d3, 1, ctx())
		d3.coins = 10
		check("Pièces passées sous le coût : apply refusé, rien ne bouge", Evolution.apply(d3, plan3) == false and d3.coins == 10 and d3.slots[2] ~= false)
		local d4 = profile({ P(1), P(1), P(1), P(1) }, { coins = 5000, evo = nil })
		d4.evo = nil
		local plan4 = Evolution.plan(On, d4, 1, ctx())
		check("Profil sans evo (ancien) : apply crée le compteur à 1", Evolution.apply(d4, plan4) and d4.evo["1"] == 1)
		check(
			"dropIndices : retire les sacrifiés d'une liste",
			(function()
				local l = Evolution.dropIndices({ 1, 2, 7, 3 }, { 2, 3 })
				return #l == 2 and l[1] == 1 and l[2] == 7
			end)()
		)
		local _ = before
		local _s = snap
	end

	---------------------------------------------------------------- 6. Économie
	suite("Idée 2 : économie (Rules.income, revente par lot, joueur-robot du lot 9)")
	do
		local Rules = luau.load(fs.readFile("roblox/src/ServerScriptService/Rules.lua"), { debugName = "Rules" })().new(Config)
		local slots = { P(1, 2, 1, { f = 2 }), P(2), { k = "e", t = 1 }, false, P(3, 2, 1, { f = 2 }) }
		local expect = (1 * 1.15 + 1.5) * 3
		check("Rules.income : la forme 2 compte x1,15 (Poussin forme 2 + Hamster, x3) ; au-delà de la capacité ignoré", math.abs(Rules.income(slots, 4, 3) - expect) < 1e-9)
		local list, total = Config.dupesToSell({ P(1), P(1, 2, 1, { f = 2 }), P(1, 3, 1) }, 3)
		check(
			"Revente des doublons : une forme 2 n'est JAMAIS revendue par lot, même si un autre exemplaire rapporte plus (Poussin Grand x1,5 > forme 2 x1,15) : seul le Poussin normal part",
			#list == 1 and list[1] == 1 and total == Config.sellValue(1, 2, 1)
		)
		local list2 = Config.dupesToSell({ P(1), P(1, 2, 1, { f = 2 }), P(1) }, 3)
		check("Revente des doublons : la forme 2 est la meilleure de l'espèce (x1,15), les deux autres sont revendues", #list2 == 2 and list2[1] == 1 and list2[2] == 3)
		local Economy = luau.load(fs.readFile("roblox/tests/Economy.lua"), { debugName = "Economy" })()
		-- (a) joueur-robot du lot 9 (aucune forme 2) : identique au bit près à un Rules sans le patch (petIncome à 3 arguments)
		local RulesOld = setmetatable({
			income = function(sl, capacity, mult)
				local t = 0
				for i = 1, capacity do
					local x = sl[i]
					if x and x.k == "p" then
						t = t + Config.PETS[x.p].inc * Config.SIZES[x.s].mult * Config.MUTS[x.m].mult
					end
				end
				return t * mult
			end,
		}, { __index = Rules })
		local same = true
		for seed = 1, 3 do
			local a = Economy.simulate(Config, Rules, 6 * 60, { seed = seed })
			local b = Economy.simulate(Config, RulesOld, 6 * 60, { seed = seed })
			same = same and a.final.coins == b.final.coins and a.final.income == b.final.income and a.final.hatched == b.final.hatched and a.firstPetTier[5] == b.firstPetTier[5]
		end
		check("Joueur-robot du lot 9 (sans évolution) : trajectoires identiques au bit près avec et sans le patch (3 graines, 6 h) : les tests de rythme et de tapis du lot 9 ne bougent pas", same)
		-- (b) robot qui FAIT évoluer ses pets (opts.evolve : dès 3 doublons de la rareté, le plus rentable d'abord, coût <= `share` des pièces).
		-- Mesure à la manière du lot 16 (tapis) : moyenne géométrique, sur 20 graines, du rapport « avec / sans évolution » de cinq jalons d'accès
		-- (premier Légendaire, premier Mythique, maisons 4, 5 et 6), puis jalons du lot 9 sur les 5 graines des tests de rythme.
		-- Joueur « normal » : share = 0,1 (évolue quand le coût vaut au plus 10 % de ses pièces) : vérifié. Joueur « acharné » : share = 0,5 : mesuré
		-- et affiché seulement (voir README, écart : l'accélération vient des places libérées par les 3 doublons, pas du revenu +15 %).
		local function evoOpts(seed, share)
			return { seed = seed, evolve = { E = Evolution, cfg = On, share = share or 0.1 } }
		end
		local H = 3600
		local function at(run, kind, n) -- jalon d'une partie (nil si non atteint) ; pas d'idiome « a and b or c » (un pet absent tomberait sur la maison)
			if kind == "pet" then
				return run.firstPetTier[n]
			end
			return run.baseLevelAt[n]
		end
		local marks = { { "pet", 5 }, { "pet", 6 }, { "house", 4 }, { "house", 5 }, { "house", 6 } }
		local logSum, nRatio, evolvedTot, firstEvo = 0, 0, 0, math.huge
		local runsOff, runsOn = {}, {}
		for seed = 1, 20 do
			local a = Economy.simulate(Config, Rules, 12 * H / 60, { seed = seed })
			local b = Economy.simulate(Config, Rules, 12 * H / 60, evoOpts(seed, 0.1))
			runsOff[seed], runsOn[seed] = a, b
			evolvedTot = evolvedTot + (b.evolved or 0)
			firstEvo = math.min(firstEvo, b.firstEvolve or math.huge)
			for _, mk in ipairs(marks) do
				local va = at(a, mk[1], mk[2])
				local vb = at(b, mk[1], mk[2])
				if va and vb then
					logSum = logSum + math.log(vb / va)
					nRatio = nRatio + 1
				end
			end
		end
		local geo = math.exp(logSum / math.max(1, nRatio))
		local logHard, nHard = 0, 0
		for seed = 1, 20 do
			local h = Economy.simulate(Config, Rules, 12 * H / 60, evoOpts(seed, 0.5))
			for _, mk in ipairs(marks) do
				local va = at(runsOff[seed], mk[1], mk[2])
				local vb = at(h, mk[1], mk[2])
				if va and vb then
					logHard = logHard + math.log(vb / va)
					nHard = nHard + 1
				end
			end
		end
		print(string.format("  [idée 2] joueur acharné (share 0,5, 20 graines, 12 h) : jalons d'accès x%.3f (mesure seulement)", math.exp(logHard / math.max(1, nHard))))
		print(
			string.format(
				"  [idée 2] robot avec évolution (share 0,1, 20 graines, 12 h) : %d évolutions (%.1f par partie, première à %ds) ; jalons d'accès x%.3f (moyenne géométrique de %d rapports, < 1 = plus tôt)",
				evolvedTot,
				evolvedTot / 20,
				firstEvo,
				geo,
				nRatio
			)
		)
		check(string.format("Le robot fait réellement évoluer ses pets (%d évolutions sur 20 parties de 12 h)", evolvedTot), evolvedTot >= 20)
		check(string.format("Effet sur le rythme borné : jalons d'accès x%.3f en moyenne géométrique (avance <= 10 %%, retard <= 10 %%)", geo), nRatio >= 60 and geo >= 0.90 and geo <= 1.10)
		-- jalons du lot 9 (graines 1 à 5 des tests de rythme) : tout jalon atteint AVANT la première évolution est identique au bit près à la partie
		-- sans évolution (même graine) ; les jalons atteints après sont affichés (les fenêtres du lot 9 restent celles de tests/run.luau, robot sans évolution)
		local okR, nSame, txtR = true, 0, ""
		for seed = 1, 5 do
			local a0, r = runsOff[seed], runsOn[seed]
			local fe = r.firstEvolve or math.huge
			for _, c in ipairs({ { "pet", 3 }, { "pet", 4 }, { "pet", 5 }, { "pet", 6 }, { "house", 2 }, { "house", 3 }, { "house", 4 }, { "house", 5 }, { "house", 6 } }) do
				local v0 = at(a0, c[1], c[2])
				local v1 = at(r, c[1], c[2])
				if v0 and v0 < fe then
					nSame = nSame + 1
					if v1 ~= v0 then
						okR = false
						txtR = txtR .. string.format(" [DIFF g%d %s%d %s->%s fe=%s]", seed, c[1], c[2], tostring(v0), tostring(v1), tostring(fe))
					end
				elseif v0 and v1 then
					txtR = txtR .. string.format(" g%d %s%d %d->%ds", seed, c[1], c[2], v0, v1)
				end
			end
		end
		print("  [idée 2] jalons du lot 9 atteints après la première évolution (sans -> avec) :" .. (txtR == "" and " aucun" or txtR))
		check(
			string.format("Rythme du lot 9 (graines 1 à 5) : les %d jalons atteints avant la première évolution du joueur normal sont identiques à la partie sans évolution", nSame),
			okR and nSame >= 20
		)
	end

	---------------------------------------------------------------- 7. Bout en bout : vrai Main.server.lua + Data.lua
	local newRuntime = env.newRuntime
	suite("Idée 2 : intégration (vrai Main.server.lua + Data.lua) : migration v13 -> v14, évolution, panne de sauvegarde, interdits, renaissance")
	if not newRuntime then
		check("Idée 2 e2e : runtime factice disponible (sinon sauté)", true)
		return
	end
	local T = {}
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game })
	if not RT then
		return
	end
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local Shared = RT.services.ReplicatedStorage:FindFirstChild("Shared")
	local cfg = RT.require(Shared:FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local DataMod = RT.require(RT.services.ServerScriptService:FindFirstChild("Data"))
	local ds = RT.dataStores["ChipeOeufs_v1"]
	local RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local function act(p, a, arg)
		RT.now = RT.now + 1.1
		RT.fire(RAction, "OnServerEvent", p, a, arg)
		RT.step(0.3)
	end
	local function notified(p, frag, from)
		for i = #RT.fired, from or 1, -1 do
			local f = RT.fired[i]
			if f[1] == "Notify" and f[2] == p and type(f[3]) == "string" and f[3]:find(frag, 1, true) then
				return true
			end
		end
		return false
	end
	local function evoMsg(p, k, from)
		for i = #RT.fired, from or 1, -1 do
			local f = RT.fired[i]
			if f[1] == "Evo" and f[2] == p and type(f[3]) == "table" and f[3].k == k then
				return f[3]
			end
		end
		return nil
	end
	check(
		"Démarrage sans erreur ; Data.VERSION = 14 ; remote Evo créé" .. errs(),
		#RT.errors == 0 and DataMod.VERSION == 14 and RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Evo") ~= nil
	)

	-- 7.1 migration v13 -> v14
	ds.data.P_20001 = {
		v = {
			ver = 13,
			coins = 4321,
			played = 9000,
			hatched = 30,
			evo = { ["1"] = 4, ["999"] = 2, ["2"] = "x" },
			slots = { { k = "p", p = 1, s = 2, m = 1, x = 10, f = 2 }, { k = "p", p = 1, s = 2, m = 1, f = 7 }, { k = "p", p = 2, s = 2, m = 1 }, { k = "e", t = 1, ends = 1800000000, f = 2 } },
			battle = { team = { 3 }, best = 2 },
		},
		t = 1700000000 + RT.now - 5000,
	}
	ds.data.P_20002 = { v = { ver = 13, coins = 50, played = 10, slots = { { k = "p", p = 1, s = 2, m = 1 } } }, t = 1700000000 + RT.now - 5000 }
	ds.data.P_20003 = { v = { ver = 15, coins = 42, evo = { ["1"] = 9 } }, t = 1700000000 + RT.now - 5000 }
	T.a = RT.addPlayer("EvoA", 20001, { from = "hub", partyId = "EVO", size = 3, late = false })
	T.b = RT.addPlayer("EvoB", 20002, { from = "hub", partyId = "EVO", size = 3, late = false })
	T.c = RT.addPlayer("EvoC", 20003, { from = "hub", partyId = "EVO", size = 3, late = false })
	RT.step(3)
	local sa, sb = hooks.session(T.a), hooks.session(T.b)
	local da, db = sa and sa.data, sb and sb.data
	check(
		"Migration v13 -> v14 : version 14, pièces et pets gardés ; evo gardé (Poussin 4) et assaini (espèce inconnue, valeur invalide retirées) ; forme 2 gardée, f invalide retiré, f sur un œuf retiré"
			.. errs(),
		da ~= nil
			and da.ver == 14
			and da.coins >= 4321
			and da.evo["1"] == 4
			and da.evo["999"] == nil
			and da.evo["2"] == nil
			and da.slots[1].f == 2
			and da.slots[1].x == 10
			and da.slots[2].f == nil
			and da.slots[2].k == "p"
			and da.slots[3].p == 2
			and da.slots[4].k == "e"
			and da.slots[4].f == nil
			and da.battle.best == 2
	)
	check(
		"Profil v13 sans evo : evo = {} (valeur par défaut), rien d'autre ne change",
		db ~= nil and db.ver == 14 and type(db.evo) == "table" and next(db.evo) == nil and db.coins >= 50 and db.slots[1].p == 1
	)
	RT.removePlayer(T.a)
	RT.removePlayer(T.b)
	RT.step(3)
	local ra = ds.data.P_20001 and ds.data.P_20001.v
	check("Sauvegarde de départ : ver 14, evo et forme 2 écrits", ra ~= nil and ra.ver == 14 and ra.evo["1"] == 4 and ra.slots[1].f == 2)
	T.a = RT.addPlayer("EvoA", 20001, { from = "hub", partyId = "EVO", size = 3, late = false })
	RT.step(3)
	sa = hooks.session(T.a)
	da = sa and sa.data
	check("Relecture du profil v14 : identique (idempotent : evo 4, forme 2, jamais de remise à zéro)", da ~= nil and da.ver == 14 and da.evo["1"] == 4 and da.slots[1].f == 2 and da.coins >= 4321)
	check("Profil d'une version plus récente (v15) : jamais écrasé", ds.data.P_20003.v.ver == 15 and ds.data.P_20003.v.coins == 42 and ds.data.P_20003.v.evo["1"] == 9)
	RT.removePlayer(T.c)

	-- 7.2 évolution désactivée dans la source
	sa.graceUntil, da.newbieOff = 0, true
	da.up.slots, sa.passes.ExtraSlots = cfg.upgrade("slots").max, true -- capacité 16 (4 + 8 + 4) : tous les emplacements utilisés ci-dessous sont débloqués
	for i = 1, 20 do
		da.slots[i] = false
	end
	da.slots[1] = { k = "p", p = 1, s = 2, m = 1, x = 25 }
	da.slots[2] = { k = "p", p = 1, s = 2, m = 1 }
	da.slots[3] = { k = "p", p = 1, s = 2, m = 1 }
	da.slots[4] = { k = "p", p = 2, s = 2, m = 1 }
	da.slots[5] = { k = "p", p = 2, s = 2, m = 1 }
	da.slots[6] = { k = "p", p = 4, s = 2, m = 1 }
	da.battle.team, da.equip = {}, {}
	da.coins = 1e6
	T.f0 = #RT.fired + 1
	act(T.a, "evolve", { i = 1 })
	check(
		"Source (enabled = false) : l'action evolve est refusée, rien ne change" .. errs(),
		da.slots[1].f == nil and da.slots[2] ~= false and da.coins >= 1e6 and notified(T.a, "pas encore disponible", T.f0)
	)
	cfg.EVOLUTION.enabled = true

	-- 7.3 aperçu puis évolution réussie
	T.f0 = #RT.fired + 1
	act(T.a, "evoPreview", 1)
	local pv = evoMsg(T.a, "preview", T.f0)
	check(
		"Aperçu : ok, sacrifiés 2, 3, 4 (Poussin, Poussin, Hamster), coût = 300 s du revenu actuel" .. errs(),
		pv ~= nil and pv.view.ok == true and pv.view.sac[1] == 2 and pv.view.sac[2] == 3 and pv.view.sac[3] == 4 and pv.view.cost > 0
	)
	T.cost = pv and pv.view.cost or 0
	T.coins0 = da.coins
	T.inc0 = da and Config.petIncome(1, 2, 1)
	act(T.a, "evolve", { i = 1, maxCost = T.cost - 1 })
	check("Prix maximal inférieur au coût : refus « prix a changé », rien ne change", da.slots[1].f == nil and da.slots[2] ~= false and notified(T.a, "prix a changé"))
	T.f0 = #RT.fired + 1
	act(T.a, "evolve", { i = 1, maxCost = T.cost + 1e6 })
	RT.step(1)
	local rec = ds.data.P_20001 and ds.data.P_20001.v
	check(
		"Évolution réussie : forme 2 (XP gardée), 3 doublons retirés, Lapin/Chat intacts, pièces débitées du coût (à un tick de revenu près), compteur Poussin 5, message et événement Evo « done »"
			.. errs(),
		da.slots[1].f == 2
			and da.slots[1].x == 25
			and da.slots[2] == false
			and da.slots[3] == false
			and da.slots[4] == false
			and da.slots[5] ~= false
			and da.slots[6] ~= false
			and da.evo["1"] == 5
			and da.coins <= T.coins0 - T.cost + 1e5
			and da.coins >= T.coins0 - T.cost - 1
			and notified(T.a, "évolue en forme 2", T.f0)
			and evoMsg(T.a, "done", T.f0) ~= nil
			and evoMsg(T.a, "done", T.f0).n == 5
	)
	check(
		"Sauvegardé AVANT l'octroi : l'enregistrement du DataStore porte la forme 2, les doublons retirés et evo = 5",
		rec ~= nil and rec.slots[1].f == 2 and rec.slots[2] == false and rec.evo["1"] == 5 and rec.coins <= T.coins0 - T.cost + 1e5
	)
	check("Revenu du joueur : le Poussin forme 2 compte x1,15 (Rules.income du serveur)", math.abs(Config.petIncome(1, 2, 1, 2) - T.inc0 * 1.15) < 1e-9 and sa.passes ~= nil)
	act(T.a, "evolve", { i = 1 })
	check("Deuxième évolution du même pet : refus « déjà en forme 2 »", notified(T.a, "déjà en forme 2") and da.evo["1"] == 5)

	-- 7.4 panne de sauvegarde : rien n'est perdu
	da.slots[7] = { k = "p", p = 2, s = 2, m = 1 }
	da.slots[8] = { k = "p", p = 2, s = 2, m = 1 }
	da.slots[9] = { k = "p", p = 3, s = 2, m = 1 }
	da.slots[10] = { k = "p", p = 3, s = 2, m = 1 }
	-- Hamster visé (5), doublons Communs : Hamster 7, 8 (le Hamster 5 compte), Lapin 9/10 (un sacrifiable)
	local snapBefore = deep(da.slots)
	local storeBefore = deep(ds.data.P_20001.v)
	T.coins1 = da.coins
	RT.dataStoreFail = "panne simulée"
	T.f0 = #RT.fired + 1
	act(T.a, "evolve", { i = 5 })
	RT.step(25) -- 3 essais de Data.save (attentes 1,5 + 3 + 4,5 s) et une éventuelle sauvegarde automatique concurrente
	RT.dataStoreFail = nil
	local intact = true
	for i = 1, 20 do
		local a, b = da.slots[i], snapBefore[i]
		if (a == false) ~= (b == false) or (a and (a.p ~= b.p or a.f ~= b.f)) then
			intact = false
		end
	end
	check(
		"Sauvegarde en panne : aucune perte (pets, forme, compteur inchangés ; pièces jamais débitées), message « rien n'a été perdu » ; DataStore inchangé" .. errs(),
		intact
			and da.slots[5].f == nil
			and da.evo["2"] == nil
			and da.coins >= T.coins1
			and notified(T.a, "rien n'a été perdu", T.f0)
			and ds.data.P_20001.v.slots[5] ~= false
			and ds.data.P_20001.v.evo["2"] == storeBefore.evo["2"]
	)
	check("Après la panne : actions de nouveau acceptées (verrou evoBusy libéré)", sa.evoBusy == nil)
	act(T.a, "evolve", { i = 5 })
	RT.step(1)
	check(
		"Nouvel essai sans panne : Hamster forme 2, compteur Hamster 1 ; Hamster 7, 8 et un Lapin sacrifiés, le dernier Lapin gardé",
		da.slots[5].f == 2 and da.evo["2"] == 1 and da.slots[7] == false and da.slots[8] == false and ((da.slots[9] == false) ~= (da.slots[10] == false))
	)

	-- 7.5 interdits côté serveur
	for i = 11, 15 do
		da.slots[i] = { k = "p", p = 4, s = 2, m = 1 } -- Chats (Rare)
	end
	da.equip = { 11 }
	act(T.a, "evolve", { i = 11 })
	check("Suiveur : refus, rien ne change", da.slots[11].f == nil and notified(T.a, "te suit"))
	da.equip = {}
	da.battle.team = { 12 }
	act(T.a, "evolve", { i = 12 })
	check("Équipe de combat : refus", da.slots[12].f == nil and notified(T.a, "équipe de combat"))
	da.battle.team = {}
	da.battle.pvp.defense = { { p = 4, s = 2, m = 1 } }
	act(T.a, "evolve", { i = 13 })
	check("Copie dans la défense PvP : refus", da.slots[13].f == nil and notified(T.a, "défense PvP"))
	da.battle.pvp.defense = {}
	da.slots[16] = { k = "p", p = 4, s = 4, m = 1 }
	act(T.a, "evolve", { i = 16 })
	check("Géant : refus « n'évoluent pas »", da.slots[16].f == nil and notified(T.a, "n'évoluent pas"))
	act(T.a, "evolve", "x")
	act(T.a, "evolve", { i = "1" })
	act(T.a, "evolve", { i = 13, maxCost = "beaucoup" })
	act(T.a, "evoPreview", { 1 })
	check("Arguments invalides (chaîne, table, prix non numérique) : sans effet ni erreur" .. errs(), #RT.errors == 0 and da.slots[13].f == nil)
	-- actions gelées pendant evoBusy
	sa.evoBusy = true
	local c0 = da.coins
	act(T.a, "sell", 14)
	check("Pendant la sauvegarde d'une évolution (evoBusy) : les autres actions sont ignorées (revente refusée)", da.slots[14] ~= false and da.coins >= c0)
	sa.evoBusy = nil

	-- 7.6 force en combat : l'équipe avec un pet forme 2 a pv et attaque x1,10
	da.slots[1].x = 0
	da.battle.team = { 1 }
	T.f0 = #RT.fired + 1
	act(T.a, "towerStart", 1)
	local st
	for i = #RT.fired, T.f0, -1 do
		local f = RT.fired[i]
		if f[1] == "Battle" and f[2] == T.a and type(f[3]) == "table" and f[3].k == "start" then
			st = f[3]
		end
	end
	local u = st and st.view.sides[1].units[1]
	local base = Battle.rawUnit({ tier = 1, size = 2, mut = 1, level = 1 })
	check(
		"Combat (tour) : le Poussin forme 2 entre avec pv et attaque x1,10 (" .. tostring(u and u.maxHp) .. " pv au lieu de " .. base.maxHp .. ")" .. errs(),
		u ~= nil and u.maxHp == math.floor(base.maxHp * 1.10 + 0.5) and u.maxHp > base.maxHp
	)
	act(T.a, "battleQuit")
	RT.step(2)

	-- 7.7 renaissance : le compteur survit
	sa.battle = nil
	da.coins = 1e30
	act(T.a, "rebirth")
	RT.step(1)
	local dr = hooks.session(T.a).data
	check("Renaissance : le compteur d'évolutions par espèce survit (Poussin 5, Hamster 1)" .. errs(), dr ~= da and dr.rb >= 1 and dr.evo["1"] == 5 and dr.evo["2"] == 1)
	RT.removePlayer(T.a)
	RT.step(3)
	check("Fin sans erreur d'exécution" .. errs(), #RT.errors == 0)
end
