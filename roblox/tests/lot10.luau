--!nocheck
-- Tests du lot 10 (compteur de rareté, plans et effets d'éclosion, intro de combat, effets par type).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } fournis par le test principal (tests/run.luau) ou par tests/run_lot10.py.
-- Le Config utilisé ici est FICTIF (10 raretés, A.1 à A.6) : le lot 10 ne dépend pas de l'état du lot 9.
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local Odds = load("roblox/src/ReplicatedStorage/Odds.lua", "Odds")
	local HatchPlan = load("roblox/src/ReplicatedStorage/HatchPlan.lua", "HatchPlan")
	local IntroPlan = load("roblox/src/ReplicatedStorage/IntroPlan.lua", "IntroPlan")
	local TypeFxData = load("roblox/src/ReplicatedStorage/TypeFx.lua", "TypeFxData")
	local NB = "\u{00A0}"

	local function deepEq(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, v in pairs(a) do
			if not deepEq(v, b[k]) then
				return false
			end
		end
		for k in pairs(b) do
			if a[k] == nil then
				return false
			end
		end
		return true
	end

	-- Config FICTIF à 10 raretés (A.1 à A.6) : 78 espèces publiées (R3 = 10, R5 = 9, R6 = 9, R10 = 4).
	local COUNTS = { 15, 10, 10, 9, 9, 9, 6, 5, 1, 4 }
	local function fakeConfig()
		local C = {
			SIZES = { { name = "Mini", weight = 20 }, { name = "Normal", weight = 62 }, { name = "Grand", weight = 14 }, { name = "Géant", weight = 3.5 }, { name = "Colossal", weight = 0.5 } },
			MUTS = {
				{ name = "", weight = 81.9 }, { name = "Doré", weight = 9 }, { name = "Néon", weight = 5 }, { name = "Arc-en-ciel", weight = 2.6 }, { name = "Alien", weight = 1.4 }, { name = "Céleste", weight = 0.1 },
			},
			ODDS = { version = 1, billboardMin = 1000, REF = { 50, 25, 14, 7, 2.9, 0.85, 0.2, 0.04, 2, 0.01 } },
			BELT = { weights = { normal = { 50, 25, 14, 7, 2.9, 0.85, 0.2, 0.04, 0, 0.01 }, golden = { 32, 26, 20, 12, 6.5, 2.5, 0.75, 0.2, 0, 0.05 } } },
			UPGRADE = { pass = 10, clover = 5 },
			PETS = {},
		}
		for r = 1, 10 do
			for _ = 1, COUNTS[r] do
				C.PETS[#C.PETS + 1] = { tier = r, name = "p" .. #C.PETS }
			end
		end
		return C
	end
	local Config = fakeConfig()
	local function throws(fn, ...)
		local ok = pcall(fn, ...)
		return not ok
	end

	---------------------------------------------------------------- Odds : formule et exemples
	suite("Odds : formule du compteur, 4 exemples exacts de B.1, formats")
	check("Config fictif : 78 espèces publiées", #Config.PETS == 78)
	check("Odds.speciesCount : R3 = 10, R5 = 9, R6 = 9, R10 = 4", Odds.speciesCount(Config, 3) == 10 and Odds.speciesCount(Config, 5) == 9 and Odds.speciesCount(Config, 6) == 9 and Odds.speciesCount(Config, 10) == 4)
	check("Exemple 1 : Chat (R3), Normal, sans mutation = 141", Odds.value(Config, 3, 2, 1) == 141)
	check("Exemple 2 : Requin éclair (R5), Grand, Doré = 24 631", Odds.value(Config, 5, 3, 2) == 24631)
	check("Exemple 3 : Loup de glace (R6), Géant, Néon = 605 042", Odds.value(Config, 6, 4, 3) == 605042)
	check("Exemple 4 : Dragon céleste (R10), Colossal, Céleste = 8 Md (8 000 000 000)", Odds.value(Config, 10, 5, 6) == 8000000000)
	check("Libellé exemple 1 : « 1 sur 141 »", Odds.label(Odds.value(Config, 3, 2, 1)) == "1 sur 141")
	check("Libellé exemple 2 : « 1 sur 24 631 »", Odds.label(Odds.value(Config, 5, 3, 2)) == "1 sur 24" .. NB .. "631")
	check("Libellé exemple 3 : « 1 sur 605 042 »", Odds.label(Odds.value(Config, 6, 4, 3)) == "1 sur 605" .. NB .. "042")
	check("Libellé exemple 4 : « 1 sur 8 Md »", Odds.label(Odds.value(Config, 10, 5, 6)) == "1 sur 8" .. NB .. "Md")
	local p1 = Odds.pRef(Config, 3, 2, 1)
	check("Probabilité de l'exemple 1 = 7,109e-3", p1 ~= nil and math.abs(p1 - 7.109e-3) < 1e-6)
	check("Odds.forPet : le Chat (indice d'une espèce R3) donne 141", (function()
		local idx
		for i = 1, #Config.PETS do
			if Config.PETS[i].tier == 3 then
				idx = i
				break
			end
		end
		return Odds.forPet(Config, idx, 2, 1) == 141
	end)())
	check("Formats : 7,3 / 38 494 / 12,5 M / 8 Md", Odds.label(7.3) == "1 sur 7,3" and Odds.label(38494) == "1 sur 38" .. NB .. "494" and Odds.label(12500000) == "1 sur 12,5" .. NB .. "M" and Odds.label(8e9) == "1 sur 8" .. NB .. "Md")
	check("Formats : bornes 9,96 -> 10 ; 10 000 000 -> 10 M ; 9 999 999 -> chiffres complets", Odds.label(9.96) == "1 sur 10" and Odds.label(1e7) == "1 sur 10" .. NB .. "M" and Odds.label(9999999) == "1 sur 9" .. NB .. "999" .. NB .. "999")
	check("Formats : 999 999 999 -> « 1 Md » (pas « 1000 M ») ; 12,34 Md -> 12,3 ; 123 Md -> entier", Odds.label(999999999) == "1 sur 1" .. NB .. "Md" and Odds.label(12.34e9) == "1 sur 12,3" .. NB .. "Md" and Odds.label(123e9) == "1 sur 123" .. NB .. "Md")
	check("Formats : 1 -> « 1 sur 1,0 » ; 10 -> « 1 sur 10 » ; 1000 -> « 1 sur 1 000 »", Odds.label(1) == "1 sur 1,0" and Odds.label(10) == "1 sur 10" and Odds.label(1000) == "1 sur 1" .. NB .. "000")
	check("Arrondi : 140,66 -> 141 ; 9,949 -> 9,9 ; 9,95 -> 10 ; 0,2 -> 1 ; 1e300 -> 2^53", Odds.round(140.66) == 141 and Odds.round(9.949) == 9.9 and Odds.round(9.95) == 10 and Odds.round(0.2) == 1 and Odds.round(1e300) == Odds.MAX)
	check("2^53 : le format ne plante pas et finit par Md", (function()
		local s = Odds.label(Odds.MAX)
		return s:sub(-2) == "Md" and #s > 6
	end)())

	suite("Odds : référence identique pour tous (aucun achat ne gonfle le chiffre), cohérence, ordre")
	local before = {}
	for r = 1, 10 do
		for s = 1, 5 do
			for m = 1, 6 do
				before[#before + 1] = Odds.value(Config, r, s, m)
			end
		end
	end
	check("300 combinaisons (10 raretés x 5 tailles x 6 mutations) : toutes finies, >= 1", (function()
		for i = 1, #before do
			local v = before[i]
			if type(v) ~= "number" or v ~= v or v < 1 or v == math.huge then
				return false
			end
		end
		return #before == 300
	end)())
	-- on modifie tout ce qui est « bonus » : le chiffre ne bouge pas
	Config.UPGRADE.pass, Config.UPGRADE.clover, Config.BELT.weights.golden[10], Config.BELT.weights.normal[1] = 99, 99, 50, 1
	Config.LUCK, Config.POTION, Config.EVENT = 1000, 1000, { weekend = true }
	local after = {}
	for r = 1, 10 do
		for s = 1, 5 do
			for m = 1, 6 do
				after[#after + 1] = Odds.value(Config, r, s, m, nil, { luck = 1000, clover = true, pass = true })
			end
		end
	end
	check("Bonus, trèfle, passe, potion, événement, tapis : compteur de référence strictement identique", deepEq(before, after))
	check("Même combinaison appelée deux fois : même résultat (déterministe)", Odds.value(Config, 5, 3, 2) == Odds.value(Config, 5, 3, 2))
	Config = fakeConfig()
	check("Un joueur ou un autre : aucun paramètre joueur n'existe (arité 5 maximum, nr compris)", (function()
		local ok = pcall(function()
			return Odds.value(Config, 5, 3, 2, nil, "autre joueur")
		end)
		return ok and Odds.value(Config, 5, 3, 2, nil, "autre joueur") == Odds.value(Config, 5, 3, 2)
	end)())
	check("REF[1..8, 10] = poids du tapis standard (r9 = 2 : événement)", (function()
		for r = 1, 10 do
			if r ~= 9 and Config.ODDS.REF[r] ~= Config.BELT.weights.normal[r] then
				return false
			end
		end
		return Config.ODDS.REF[9] == 2
	end)())
	check("Odds.validate : Config fictive valide ; somme des tailles fausse ou REF manquante détectées", (function()
		local ok = Odds.validate(Config)
		local bad = fakeConfig()
		bad.SIZES[1].weight = 21
		local ok2, problems = Odds.validate(bad)
		local bad2 = fakeConfig()
		bad2.ODDS.REF = nil
		local ok3 = Odds.validate(bad2)
		return ok and not ok2 and #problems >= 1 and not ok3 and not Odds.validate(nil)
	end)())
	check("Plus la taille ou la mutation est rare, plus N est grand (ordre strict)", (function()
		for r = 1, 10 do
			local prev = 0
			for _, s in ipairs({ 2, 1, 3, 4, 5 }) do -- Normal(62) > Mini(20) > Grand(14) > Géant(3,5) > Colossal(0,5)
				local v = Odds.value(Config, r, s, 1)
				if v <= prev then
					return false
				end
				prev = v
			end
			prev = 0
			for _, m in ipairs({ 1, 2, 3, 4, 5, 6 }) do
				local v = Odds.value(Config, r, 2, m)
				if v <= prev then
					return false
				end
				prev = v
			end
		end
		return true
	end)())
	check("Rareté supérieure -> compteur plus grand (même taille, même mutation) pour r1..r8", (function()
		for r = 1, 7 do
			if Odds.value(Config, r + 1, 2, 1) <= Odds.value(Config, r, 2, 1) then
				return false
			end
		end
		return true
	end)())
	check("Une espèce de plus dans la rareté multiplie N par (n+1)/n sans réécrire l'ancien chiffre stocké", (function()
		local stored = Odds.value(Config, 3, 2, 1)
		Config.PETS[#Config.PETS + 1] = { tier = 3 }
		local newer = Odds.value(Config, 3, 2, 1)
		Config.PETS[#Config.PETS] = nil
		return stored == 141 and newer == Odds.round(1 / (0.14 * (1 / 11) * 0.62 * 0.819))
	end)())
	check("Espèce non publiée (published = false ou hidden = true) exclue du compte", (function()
		local C = fakeConfig()
		for i = 1, #C.PETS do
			if C.PETS[i].tier == 10 then
				C.PETS[i].published = false
				break
			end
		end
		for i = #C.PETS, 1, -1 do
			if C.PETS[i].tier == 10 then
				C.PETS[i].hidden = true
				break
			end
		end
		return Odds.speciesCount(C, 10) == 2
	end)())

	suite("Odds : entrées invalides (nil, NaN, négatif, énorme, mauvais types), seuils spéciaux")
	local junk = { 0 / 0, -1, 0, math.huge, -math.huge, 1e300, -1e300, "x", {}, true, false, 2 ^ 53, 1e-300 }
	local noErr = true
	local function try(fn, ...)
		local ok = pcall(fn, ...)
		if not ok then
			noErr = false
		end
	end
	try(Odds.value, nil, nil, nil, nil)
	try(Odds.value, {}, 1, 1, 1)
	try(Odds.value, "x", 1, 1, 1)
	try(Odds.forPet, nil, 1, 1, 1)
	try(Odds.forPet, Config, {}, 1, 1)
	for _, a in ipairs(junk) do
		try(Odds.short, a)
		try(Odds.label, a)
		try(Odds.round, a)
		try(Odds.isSpecial, a)
		try(Odds.isSpecial, a, a)
		try(Odds.level, a)
		try(Odds.fx, a, a)
		try(Odds.fx, a, a, a)
		try(Odds.countSteps, a, a)
		try(Odds.speciesCount, a, a)
		try(Odds.pRef, Config, a, a, a, a)
		try(Odds.value, Config, a, 1, 1)
		try(Odds.value, Config, 3, a, 1)
		try(Odds.value, Config, 3, 1, a)
		try(Odds.value, Config, 3, 1, 1, a)
		try(Odds.forPet, Config, a, 1, 1)
		try(Odds.validate, a)
	end
	check("Aucune erreur sur ~200 appels invalides (nil, NaN, ±inf, ±1e300, texte, table, booléens)", noErr)
	check("Valeurs invalides : value/label/short ramènent nil ou chaîne vide", Odds.value(Config, 0, 1, 1) == nil and Odds.value(Config, 11, 1, 1) == nil and Odds.value(Config, 3, 0, 1) == nil and Odds.value(Config, 3, 6, 1) == nil
		and Odds.value(Config, 3, 1, 7) == nil and Odds.value(Config, 3, 1.5, 1) == nil and Odds.value(Config, 3, 1, 1, 0) == nil and Odds.value(Config, 3, 1, 1, -2) == nil and Odds.value(nil, 3, 1, 1) == nil
		and Odds.label(0 / 0) == "" and Odds.label(-5) == "" and Odds.label(nil) == "" and Odds.label("x") == "" and Odds.short(math.huge) == "")
	check("isSpecial : 9 999 non, 10 000 oui, NaN/nil non ; seuil lu dans Config.ODDS.specialMin", not Odds.isSpecial(9999) and Odds.isSpecial(10000) and not Odds.isSpecial(0 / 0) and not Odds.isSpecial(nil) and Odds.isSpecial(500, { ODDS = { specialMin = 500 } }) and not Odds.isSpecial(499, { ODDS = { specialMin = 500 } }))
	check("Niveaux d'effet : 0 / 1 / 2 / 3 / 4 / 5 aux seuils 10 k, 100 k, 1 M, 100 M, 1 Md", Odds.level(9999) == 0 and Odds.level(10000) == 1 and Odds.level(99999) == 1 and Odds.level(100000) == 2 and Odds.level(1e6) == 3 and Odds.level(1e8) == 4 and Odds.level(1e9) == 5 and Odds.level(8e9) == 5)
	local fx = Odds.fx(1000000, 3)
	check("Odds.fx : 1 M -> bandeau + son secret + annonce serveur et tous serveurs", fx.special and fx.banner and fx.secretSound and fx.announceServer and fx.announceWorld and not fx.pillar and fx.billboard)
	check("Odds.fx B.2 : r >= 7 -> annonce serveur ; r >= 8 -> tous serveurs ; r = 10 -> pilier ; N < 1000 -> pas d'étiquette", (function()
		local a, b, c, d = Odds.fx(5, 7), Odds.fx(5, 8), Odds.fx(5, 10), Odds.fx(999, 3)
		local e = Odds.fx(5, 6)
		return a.announceServer and not a.announceWorld and b.announceWorld and c.pillar and not d.billboard and not e.announceServer and not e.special
	end)())

	suite("Odds : paliers du compteur animé")
	local steps = Odds.countSteps(38494)
	check("12 paliers par défaut, croissants, premier >= 1, dernier = N exact", (function()
		if #steps ~= 12 or steps[12] ~= 38494 or steps[1] < 1 then
			return false
		end
		for i = 2, 12 do
			if steps[i] < steps[i - 1] then
				return false
			end
		end
		return true
	end)())
	check("Ralentissement final : le dernier pas est plus petit que le premier (ease out)", (steps[12] - steps[11]) < (steps[2] - steps[1]))
	check("N < 10 : paliers à une décimale, dernier = N ; N invalide -> pas d'erreur", (function()
		local s = Odds.countSteps(7.3, 5)
		return #s == 5 and s[5] == 7.3 and #Odds.countSteps(nil) == 12 and #Odds.countSteps(0 / 0, 1000) == 60 and #Odds.countSteps(5, -3) == 1
	end)())

	---------------------------------------------------------------- HatchPlan
	suite("HatchPlan : 10 plans purs, déterministes, durée <= 8 s, plafonds")
	local SPEC = { 1.2, 1.5, 2.0, 2.8, 4.0, 5.0, 6.0, 7.0, 6.5, 8.0 }
	local Ns = { 5, 141, 24631, 605042, 8e9 }
	local allOk, why, signatures, maxDur = true, "", {}, 0
	for r = 1, 10 do
		for _, N in ipairs(Ns) do
			for _, reduced in ipairs({ false, true }) do
				local plan = HatchPlan.plan(r, N, { reduced = reduced })
				local again = HatchPlan.plan(r, N, { reduced = reduced })
				local ok, reason = HatchPlan.check(plan)
				maxDur = math.max(maxDur, plan.duration)
				if not ok then
					allOk, why = false, "r" .. r .. " : " .. reason
				elseif not deepEq(plan, again) then
					allOk, why = false, "r" .. r .. " non déterministe"
				elseif plan.duration > 8 or math.abs(plan.duration - SPEC[r]) > 0.05 then
					allOk, why = false, "r" .. r .. " durée " .. plan.duration
				elseif plan.objects > 30 or plan.peakRate > 40 then
					allOk, why = false, "r" .. r .. " objets " .. plan.objects .. " débit " .. plan.peakRate
				elseif plan.revealAt >= plan.duration or plan.counter == nil or plan.counter.t + plan.counter.d > plan.duration + 1e-9 or plan.counter.to ~= N then
					allOk, why = false, "r" .. r .. " révélation/compteur"
				end
			end
		end
		local kinds = {}
		for _, b in ipairs(HatchPlan.plan(r, 141).beats) do
			kinds[#kinds + 1] = b.kind
		end
		signatures[r] = table.concat(kinds, ",")
	end
	check("10 raretés x 5 compteurs x (complet, mobile) : durée = table B.3 (r10 plafonnée à 8 s), <= 30 objets, <= 40 objets/s, compteur dans la durée" .. (allOk and "" or " : " .. why), allOk)
	check("Durée maximale de tous les plans : " .. maxDur .. " s <= 8", maxDur <= 8)
	check("Durées exactes B.3 (±0,05 s) : 1,2 / 1,5 / 2 / 2,8 / 4 / 5 / 6 / 7 / 6,5 et 8 (r10 : 9 -> 8 documenté)", (function()
		for r = 1, 10 do
			if math.abs(HatchPlan.plan(r, 5).duration - SPEC[r]) > 0.05 then
				return false
			end
		end
		return true
	end)())
	check("Les 10 séquences sont toutes différentes (10 animations distinctes)", (function()
		local seen = {}
		for r = 1, 10 do
			if seen[signatures[r]] then
				return false
			end
			seen[signatures[r]] = true
		end
		return true
	end)())
	check("Version réduite : <= 50 % des particules et jamais plus d'objets que la version complète (10 raretés)", (function()
		for r = 1, 10 do
			local f, m = HatchPlan.plan(r, 24631), HatchPlan.plan(r, 24631, { reduced = true })
			if m.particles * 2 > f.particles or m.objects > f.objects or not m.reduced then
				return false
			end
		end
		return true
	end)())
	check("Le plan trié par temps, chaque prise dans la durée, n >= 0, r1 à r4 : pas de zoom", (function()
		for r = 1, 10 do
			local plan = HatchPlan.plan(r, 141)
			local last = -1
			for _, b in ipairs(plan.beats) do
				if b.t < last or b.n < 0 or b.t + b.d > plan.duration + 1e-9 then
					return false
				end
				last = b.t
				if b.kind == "zoom" and r < 5 then
					return false
				end
			end
		end
		return true
	end)())
	check("Cercle runique : min(12, 4 + (r-4) x 2) runes avant ajustement (r5 = 6, r6 = 8, r7 = 10, r8+ = 12)", HatchPlan.runes(5) == 6 and HatchPlan.runes(6) == 8 and HatchPlan.runes(7) == 10 and HatchPlan.runes(8) == 12 and HatchPlan.runes(10) == 12)
	check("Caméra : r5 et r10 zooment ; still (œuf porté) : plus de zoom et camera = false", (function()
		local function hasZoom(plan)
			for _, b in ipairs(plan.beats) do
				if b.kind == "zoom" then
					return true
				end
			end
			return false
		end
		return hasZoom(HatchPlan.plan(5, 5)) and hasZoom(HatchPlan.plan(10, 5)) and not hasZoom(HatchPlan.plan(5, 5, { still = true })) and not hasZoom(HatchPlan.plan(10, 5, { still = true }))
			and HatchPlan.plan(5, 5, { still = true }).camera == false and HatchPlan.plan(5, 5).camera == true
	end)())
	check("Passable : skipAfter 1,5 s ; non passable seulement la première fois pour r >= 8", HatchPlan.plan(3, 5).skipAfter == 1.5 and not HatchPlan.plan(3, 5, { firstTime = true }).noSkip and not HatchPlan.plan(7, 5, { firstTime = true }).noSkip
		and HatchPlan.plan(8, 5, { firstTime = true }).noSkip and HatchPlan.plan(10, 5, { firstTime = true }).noSkip and not HatchPlan.plan(8, 5).noSkip)
	check("Sons : hatch / rare / epic / legendary / hatchSecret, fanfare dès r8", (function()
		local want = { "hatch", "hatch", "rare", "epic", "legendary", "legendary", "hatchSecret", "hatchSecret", "hatchSecret", "hatchSecret" }
		for r = 1, 10 do
			local s = HatchPlan.plan(r, 5).sound
			if s.key ~= want[r] or s.fanfare ~= (r >= 8) then
				return false
			end
		end
		return true
	end)())
	check("Tirage exceptionnel : N >= 100 000 -> texte + exceptional ; N >= 1 M -> son secret ; N >= 10 000 -> special", (function()
		local a, b, c, d = HatchPlan.plan(3, 9999), HatchPlan.plan(3, 10000), HatchPlan.plan(3, 100000), HatchPlan.plan(3, 1e6)
		local function hasExc(plan)
			for _, x in ipairs(plan.beats) do
				if x.glyph == "exceptional" then
					return true
				end
			end
			return false
		end
		return not a.special and b.special and not b.exceptional and c.exceptional and hasExc(c) and not hasExc(b) and not c.secretSound and d.secretSound and HatchPlan.plan(1, 1e6).duration == 1.2
	end)())
	check("Entrées invalides : r (nil, NaN, 0, -5, 99, texte, table, 3,7) et N (nil, NaN, <= 0, inf, 1e300, texte) -> plan valide sans erreur", (function()
		local rs = { 0 / 0, 0, -5, 99, "3", {}, 3.7, math.huge, -math.huge, true }
		local Nsx = { 0 / 0, 0, -1, math.huge, -math.huge, "x", {}, true }
		local okAll = pcall(HatchPlan.plan)
		okAll = okAll and pcall(HatchPlan.plan, nil, nil, nil) and pcall(HatchPlan.plan, 5, 5, "x") and pcall(HatchPlan.plan, 5, 5, 5)
		for _, r in ipairs(rs) do
			for _, N in ipairs(Nsx) do
				local ok, plan = pcall(HatchPlan.plan, r, N, { reduced = true, firstTime = true, still = true })
				if not ok or not HatchPlan.check(plan) or plan.counter ~= nil or plan.r < 1 or plan.r > 10 then
					return false
				end
			end
		end
		return okAll and HatchPlan.plan(3.7, 5).r == 3 and HatchPlan.plan(nil, 5).r == 1 and HatchPlan.plan(99, 5).r == 10 and HatchPlan.plan(5, 1e300).counter.to == 9007199254740992
	end)())
	check("HatchPlan.check rejette un plan cassé (durée 9 s, prise hors durée, nil)", not HatchPlan.check(nil) and not HatchPlan.check({ beats = {}, duration = 9 }) and not HatchPlan.check({ beats = { { t = 1, d = 5, kind = "x", n = 0 } }, duration = 2 }))

	---------------------------------------------------------------- IntroPlan
	suite("IntroPlan : ratio V/D, plan de l'intro de combat (<= 3 s)")
	check("Ratio : « 124 V / 37 D (77 %) » ; 0/0 -> 0 % ; 5/0 -> 100 % ; 1/2 -> 33 %", IntroPlan.record(124, 37) == "124 V / 37 D (77 %)" and IntroPlan.record(0, 0) == "0 V / 0 D (0 %)" and IntroPlan.record(5, 0) == "5 V / 0 D (100 %)" and IntroPlan.record(1, 2) == "1 V / 2 D (33 %)")
	check("Ratio PNJ fictif « Lina : 312 V / 140 D » -> 69 %", IntroPlan.record(312, 140) == "312 V / 140 D (69 %)")
	check("Ratio invalide : NaN, négatif, texte, inf, énorme -> 0 ou borne, sans erreur", IntroPlan.record(0 / 0, -4) == "0 V / 0 D (0 %)" and IntroPlan.record("x", {}) == "0 V / 0 D (0 %)" and IntroPlan.record(math.huge, 1) == "0 V / 1 D (0 %)" and IntroPlan.percent(1e300, 1e300) == 50)
	check("Multiplicateur en français : 1,5 / 1,25 / 0,67 / 0,8 / 1", IntroPlan.fmtMult(1.5) == "1,5" and IntroPlan.fmtMult(1.25) == "1,25" and IntroPlan.fmtMult(0.67) == "0,67" and IntroPlan.fmtMult(0.8) == "0,8" and IntroPlan.fmtMult(1) == "1" and IntroPlan.fmtMult(nil) == "1")
	local info = {
		mode = "pvp", countdown = true, advantage = 1.5,
		me = { name = "Moi", userId = 12, wins = 124, losses = 37, league = "Or", trophies = 812, pets = { { type = "Feu", odds = 38494, tier = 5 }, { type = "Eau", odds = 141, tier = 3 }, { type = "Ciel", odds = 7.3, tier = 1 }, { type = "Ombre", odds = 5, tier = 2 } } },
		foe = { name = "Lina", wins = 312, losses = 140, league = "Argent", trophies = 640, pets = { { type = "Plante", odds = 24631, tier = 5 } } },
	}
	local ip = IntroPlan.plan(info, { fmtOdds = Odds.label })
	check("Intro : 3,0 s avec décompte, 2,2 s sans ; passable après 1 s ; prises dans la durée", ip.duration == 3.0 and IntroPlan.plan({}).duration == 2.2 and ip.skipAfter == 1 and IntroPlan.check(ip) and IntroPlan.check(IntroPlan.plan({ countdown = true })))
	check("Intro : ratio des deux camps affiché", ip.left.record == "124 V / 37 D (77 %)" and ip.right.record == "312 V / 140 D (69 %)" and ip.left.name == "Moi" and ip.right.league == "Argent" and ip.left.trophies == 812)
	check("Intro : 3 vignettes au plus par camp, compteur formaté « 1 sur 38 494 »", #ip.left.pets == 3 and #ip.right.pets == 1 and ip.left.pets[1].oddsText == "1 sur 38" .. NB .. "494" and ip.left.pets[1].type == "Feu")
	check("Intro : flèche verte « Avantage ×1,5 » ; rouge « Désavantage ×0,67 » ; aucune si x1", ip.arrow ~= nil and ip.arrow.good and ip.arrow.text == "Avantage ×1,5" and IntroPlan.plan({ advantage = 0.67 }).arrow.text == "Désavantage ×0,67" and not IntroPlan.plan({ advantage = 0.67 }).arrow.good
		and IntroPlan.plan({ advantage = 1 }).arrow == nil and IntroPlan.plan({ advantage = 0 / 0 }).arrow == nil)
	check("Intro : « VS » échelle 2 -> 1, secousse 0,3 s, fanfare à 0,5 ; décompte 3-2-1 dans la durée", ip.vs.from == 2 and ip.vs.to == 1 and ip.vs.shake == 0.3 and ip.vs.volume == 0.5 and #ip.count == 3 and ip.count[1].text == "3" and ip.count[3].text == "1" and ip.count[3].t + 0.4 <= ip.duration + 1e-9)
	check("Intro : fmtOdds qui plante ou renvoie n'importe quoi -> repli sans erreur", (function()
		local p = IntroPlan.plan(info, { fmtOdds = function()
			error("boum")
		end })
		local q = IntroPlan.plan(info, { fmtOdds = function()
			return 5
		end })
		return p.left.pets[1].oddsText == "1 sur 38494" and q.left.pets[1].oddsText == "1 sur 38494"
	end)())
	check("Intro : entrées invalides (nil, nombres, texte, tables cassées) sans erreur et plan valide", (function()
		local bad = { nil, 5, "x", true, {}, { me = 5, foe = "x" }, { me = { pets = 5 }, foe = { pets = { 5, "x", {} } } }, { advantage = "x", mode = 5, countdown = "oui" }, { me = { wins = 0 / 0, losses = -1e300, name = 123, pets = { { odds = 0 / 0, tier = 1e300 } } } } }
		for i = 1, 9 do
			local ok, plan = pcall(IntroPlan.plan, bad[i], i == 2 and 5 or nil)
			if not ok or not IntroPlan.check(plan) or #plan.left.pets > 3 then
				return false
			end
		end
		return not IntroPlan.check(nil) and not IntroPlan.check({ duration = 4, beats = {} })
	end)())
	check("Intro : déterministe", deepEq(IntroPlan.plan(info, { fmtOdds = Odds.label }), IntroPlan.plan(info, { fmtOdds = Odds.label })))

	---------------------------------------------------------------- TypeFx (données)
	suite("TypeFx (données) : 9 types, coûts, efficacité")
	local D = TypeFxData.DATA
	check("9 types de D.2 : Feu, Eau, Plante, Glace, Foudre, Terre, Ciel, Ombre, Lumière", #TypeFxData.TYPES == 9 and (function()
		for _, t in ipairs(TypeFxData.TYPES) do
			if D[t] == nil then
				return false
			end
		end
		return true
	end)())
	check("Couleurs de B.6 : Feu FF6A1A, Eau 3C96DC, Plante 5CB256, Glace BFEFFF, Foudre FFE14A, Terre 9C6B45, Ciel DDEBFF, Ombre 8A3CFF, Lumière FFE680", D.Feu.hex == "FF6A1A" and D.Eau.hex == "3C96DC" and D.Plante.hex == "5CB256" and D.Glace.hex == "BFEFFF" and D.Foudre.hex == "FFE14A"
		and D.Terre.hex == "9C6B45" and D.Ciel.hex == "DDEBFF" and D.Ombre.hex == "8A3CFF" and D["Lumière"].hex == "FFE680" and D.Feu.rgb[1] == 255 and D.Feu.rgb[2] == 106 and D.Feu.rgb[3] == 26)
	check("Base 0,5 s et spécial 1,2 s pour chaque type ; spécial : cercle runique + secousse 0,4 s", (function()
		for _, t in ipairs(TypeFxData.TYPES) do
			local d = D[t]
			if d.basic.d ~= 0.5 or d.special.d ~= 1.2 or d.special.shake ~= 0.4 then
				return false
			end
			local hasRunes = false
			for _, l in ipairs(d.special.layers) do
				if l.prim == "runes" then
					hasRunes = true
				end
			end
			for _, l in ipairs(d.basic.layers) do
				if l.prim == "runes" then
					return false
				end
			end
			if not hasRunes then
				return false
			end
		end
		return true
	end)())
	check("Coûts : base <= 14 objets, spécial <= 30 objets ; réduit <= complet", (function()
		for _, t in ipairs(TypeFxData.TYPES) do
			if TypeFxData.cost(t, false) > 14 or TypeFxData.cost(t, true) > 30 or TypeFxData.cost(t, true, true) > TypeFxData.cost(t, true) or TypeFxData.cost(t, false, true) > TypeFxData.cost(t, false) then
				return false
			end
		end
		return true
	end)())
	check("Chaque couche : début + durée dans la durée de l'effet, n >= 1", (function()
		for _, t in ipairs(TypeFxData.TYPES) do
			for _, mode in ipairs({ "basic", "special" }) do
				local fx = D[t][mode]
				for _, l in ipairs(fx.layers) do
					if l.n < 1 or l.t < 0 or l.t + l.d > fx.d + 1e-9 then
						return false
					end
				end
			end
		end
		return true
	end)())
	check("Alias « Nature » -> Plante ; get/canonical invalides -> nil sans erreur ; cost invalide = 0", TypeFxData.canonical("Nature") == "Plante" and TypeFxData.get("Nature") == D.Plante and TypeFxData.get("Inconnu") == nil and TypeFxData.get(nil) == nil and TypeFxData.get(5) == nil
		and TypeFxData.cost("Inconnu", true) == 0 and TypeFxData.cost(nil, false) == 0)
	check("Efficacité : x1,5 « Super efficace ! » / x1,25 « Efficace » / x0,8 « Peu efficace » / x0,67 « Pas très efficace… » / x1 rien", (function()
		local a, ca = TypeFxData.efficacy(1.5)
		local b = TypeFxData.efficacy(1.25)
		local c = TypeFxData.efficacy(0.8)
		local d = TypeFxData.efficacy(0.67)
		return a == "Super efficace !" and b == "Efficace" and c == "Peu efficace" and d == "Pas très efficace…" and TypeFxData.efficacy(1) == nil and ca[2] > ca[1]
	end)())
	check("Efficacité : valeurs invalides (nil, NaN, 0, négatif, texte, inf) sans erreur", (function()
		for _, v in ipairs({ 0 / 0, 0, -1, "x", {} }) do
			if TypeFxData.efficacy(v) ~= nil then
				return false
			end
		end
		return TypeFxData.efficacy(nil) == nil and TypeFxData.efficacy(math.huge) == "Super efficace !"
	end)())

	---------------------------------------------------------------- Exécution dans le runtime factice
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local created = 0
	local env2 = {}
	for k, v in pairs(RT.env) do
		env2[k] = v
	end
	env2.Instance = { new = function(class)
		created = created + 1
		return RT.instance(class)
	end }
	local HatchFx = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/HatchFx.lua"), { debugName = "HatchFx", environment = env2 })()
	local BattleIntro = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/BattleIntro.lua"), { debugName = "BattleIntro", environment = env2 })()
	local TypeFx = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/TypeFx.lua"), { debugName = "TypeFxClient", environment = env2 })()
	local cam = RT.workspace.CurrentCamera
	local Lighting = RT.services.Lighting
	local function newGui()
		local g = RT.instance("ScreenGui", "gui")
		g.Enabled = true
		return g
	end
	local function kids(o)
		return #o:GetChildren()
	end

	suite("HatchFx : 10 raretés x (complet, mobile) dans le runtime factice : caméra, interface, objets, durée")
	cam.FieldOfView = 70
	local okAll, reason, worst, minFov, latest = true, "", 0, 70, 0
	for r = 1, 10 do
		for _, reduced in ipairs({ false, true }) do
			local gui, other, other2 = newGui(), newGui(), newGui()
			other2.Enabled = false
			local plan = HatchPlan.plan(r, r == 6 and 605042 or 24631, { reduced = reduced })
			local revealN, doneN, doneAt, sounds = 0, 0, nil, {}
			local t0 = RT.now
			created = 0
			local h = HatchFx.play(gui, plan, {
				colors = { main = env2.Color3.fromRGB(255, 194, 26), second = env2.Color3.fromRGB(184, 134, 11) }, rarityName = "Légendaire", petText = "🐉",
				slot = { rarity = "Légendaire", size = "Grand", mut = "Doré", pools = { rarity = { "Commun", "Rare" }, size = { "Mini", "Grand" }, mut = { "", "Doré" } } },
				fmtOdds = function(n)
					return "1 sur " .. tostring(n)
				end,
				sound = function(key)
					sounds[#sounds + 1] = key
				end,
				onReveal = function()
					revealN = revealN + 1
				end,
				onDone = function()
					doneN = doneN + 1
					doneAt = RT.now - t0
				end,
				hide = { other, other2 },
			})
			local during = created
			if h == nil then
				allOk, reason = false, "r" .. r .. " : play a renvoyé nil"
			else
				local hiddenDuring = other.Enabled == false and other2.Enabled == false
				local t = 0
				while t < plan.duration + 1 do
					RT.step(0.1)
					t = t + 0.1
					local fov = cam.FieldOfView
					if type(fov) == "number" then
						minFov = math.min(minFov, fov)
					end
				end
				worst = math.max(worst, h.created())
				latest = math.max(latest, doneAt or 99)
				if not hiddenDuring then
					allOk, reason = false, "r" .. r .. " : interface non masquée pendant l'animation"
				elseif revealN ~= 1 or doneN ~= 1 then
					allOk, reason = false, "r" .. r .. " : onReveal " .. revealN .. " fois, onDone " .. doneN .. " fois"
				elseif doneAt == nil or doneAt > plan.duration + 0.2 or doneAt > 8.2 then
					allOk, reason = false, "r" .. r .. " : fin à " .. tostring(doneAt) .. " s"
				elseif cam.FieldOfView ~= 70 then
					allOk, reason = false, "r" .. r .. " : caméra non restituée (" .. tostring(cam.FieldOfView) .. ")"
				elseif other.Enabled ~= true or other2.Enabled ~= false then
					allOk, reason = false, "r" .. r .. " : interface non restituée"
				elseif kids(gui) ~= 0 or kids(Lighting) ~= 0 then
					allOk, reason = false, "r" .. r .. " : objets résiduels (gui " .. kids(gui) .. ", lighting " .. kids(Lighting) .. ")"
				elseif not h.isDone() or #sounds < 1 or during > HatchFx.MAX_INSTANCES then
					allOk, reason = false, "r" .. r .. " : état final ou son"
				end
			end
		end
	end
	RT.step(2)
	check("HatchFx : 20 animations jouées jusqu'au bout : onReveal et onDone une fois, caméra et interface restituées, plus aucun objet" .. (allOk and "" or " : " .. reason), allOk and #RT.errors == 0)
	check("HatchFx : la caméra a réellement zoomé pendant l'animation (FOV minimum " .. string.format("%.1f", minFov) .. " < 70), puis retour à 70", minFov < 70 and cam.FieldOfView == 70)
	check("HatchFx : plafond d'instances (" .. worst .. " au maximum, <= " .. HatchFx.MAX_INSTANCES .. ") et fin au plus tard à " .. string.format("%.2f", latest) .. " s (<= 8,2)", worst <= HatchFx.MAX_INSTANCES and latest <= 8.2)
	check("HatchFx : aucune erreur dans le runtime (" .. #RT.errors .. ")", #RT.errors == 0)

	suite("HatchFx : passage par un tap, première fois non passable, erreurs, restitution forcée")
	do
		local gui = newGui()
		local plan = HatchPlan.plan(5, 24631)
		local revealN, doneN = 0, 0
		local h = HatchFx.play(gui, plan, { onReveal = function()
			revealN = revealN + 1
		end, onDone = function()
			doneN = doneN + 1
		end })
		RT.step(0.6)
		RT.fire(h.root, "Activated")
		check("Tap avant 1,5 s : ignoré (l'animation continue)", doneN == 0 and not h.isDone())
		RT.step(2.1) -- t = 2,7 : zoom en cours
		local fovMid = cam.FieldOfView
		check("Au milieu de l'animation r5, la caméra est zoomée (FOV < 70)", type(fovMid) == "number" and fovMid < 70)
		RT.fire(h.root, "Activated")
		RT.fire(h.root, "Activated")
		check("Tap après 1,5 s : onDone immédiat, une seule fois, onReveal une seule fois", doneN == 1 and revealN == 1 and h.isDone())
		check("Passage : caméra à 70, plus d'objets dans l'interface ni dans Lighting", cam.FieldOfView == 70 and kids(gui) == 0 and kids(Lighting) == 0)
		RT.step(5)
		check("Après le passage : toujours un seul onDone/onReveal et aucune erreur (prises restantes inertes)", doneN == 1 and revealN == 1 and #RT.errors == 0)
	end
	do
		local gui = newGui()
		local plan = HatchPlan.plan(9, 141, { firstTime = true })
		local doneN = 0
		local h = HatchFx.play(gui, plan, { onDone = function()
			doneN = doneN + 1
		end })
		RT.step(3)
		RT.fire(h.root, "Activated")
		h.skip()
		check("Première fois r >= 8 : le tap et skip() sont ignorés", doneN == 0 and not h.isDone() and plan.noSkip)
		RT.step(plan.duration)
		check("Première fois r9 : l'animation va à son terme (6,5 s) et restitue tout", doneN == 1 and kids(gui) == 0 and cam.FieldOfView == 70 and kids(Lighting) == 0)
		-- r9 désature l'image : le ColorCorrection temporaire a bien existé puis disparu
		check("r9 : aucun ColorCorrection résiduel dans Lighting", kids(Lighting) == 0)
	end
	do
		local gui = newGui()
		local plan = HatchPlan.plan(10, 8e9)
		local doneN, stopped = 0, false
		local h = HatchFx.play(gui, plan, { onDone = function()
			doneN = doneN + 1
		end })
		RT.step(3.5)
		h.stop()
		stopped = h.isDone() and doneN == 1 and cam.FieldOfView == 70 and kids(gui) == 0
		check("stop() : arrêt forcé immédiat (même non passable), tout est restitué, onDone une fois", stopped)
		RT.step(6)
		check("Après stop() : rien ne revient (onDone toujours 1 fois, aucune erreur)", doneN == 1 and #RT.errors == 0)
	end
	do
		local gui = newGui()
		local revealN, doneN = 0, 0
		local h1 = HatchFx.play(gui, nil, { onReveal = function()
			revealN = revealN + 1
		end, onDone = function()
			doneN = doneN + 1
		end })
		check("Plan nil : play renvoie nil, onReveal et onDone appelés une fois, aucune erreur", h1 == nil and doneN == 1 and revealN == 1 and kids(gui) == 0)
		local h2 = HatchFx.play(gui, { beats = "x", sound = {}, duration = 2 }, nil)
		local h3 = HatchFx.play(gui, 5, 5)
		check("Plan cassé ou options invalides : nil sans erreur", h2 == nil and h3 == nil)
		-- prises corrompues : types inconnus, nombres NaN/énormes/négatifs
		local bad = { r = 5, duration = 3, skipAfter = "x", camera = true, revealAt = 0 / 0, sound = { key = "hatch" }, special = true,
			beats = { { kind = "burst", t = 0, d = 0 / 0, n = 1e9 }, { kind = "inconnu", t = 1, d = 1, n = 1 }, { kind = "rays", t = -5, d = -1, n = -3 }, "x", { kind = 5 }, { kind = "zoom", t = 0, d = 1, k = "x" },
				{ kind = "ring", t = 0.1, d = 1, n = 99, mode = "converge" }, { kind = "slot", t = 0, d = 1, n = 4 }, { kind = "text", t = 0, d = 1, n = 1, glyph = 5 } },
			counter = { to = 0 / 0 } }
		local n3, r3 = 0, 0
		local ok = pcall(function()
			local h = HatchFx.play(gui, bad, { onDone = function()
				n3 = n3 + 1
			end, onReveal = function()
				r3 = r3 + 1
			end, sound = function()
				error("son cassé")
			end, fmtOdds = function()
				error("format cassé")
			end })
			RT.step(5)
			return h
		end)
		check("Prises corrompues, son et format qui plantent : aucune erreur, fin garantie, révélation garantie", ok and n3 == 1 and r3 == 1 and cam.FieldOfView == 70 and kids(gui) == 0 and #RT.errors == 0)
		local doneN2 = 0
		HatchFx.play(gui, HatchPlan.plan(4, 141), { onReveal = function()
			error("onReveal cassé")
		end, onDone = function()
			doneN2 = doneN2 + 1
		end })
		RT.step(4)
		check("onReveal qui plante : l'animation se termine quand même (onDone une fois)", doneN2 == 1 and kids(gui) == 0 and #RT.errors == 0)
	end
	do
		-- la caméra dont le FOV n'est pas un nombre n'est jamais touchée ni comparée
		local fakeCam = RT.workspace.CurrentCamera
		local saved = fakeCam.FieldOfView
		rawget(fakeCam, "__props").FieldOfView = RT.newProxy("fov", "Unknown")
		local gui = newGui()
		local doneN = 0
		HatchFx.play(gui, HatchPlan.plan(5, 5), { onDone = function()
			doneN = doneN + 1
		end })
		RT.step(5)
		check("FOV non numérique : aucune erreur, animation terminée", doneN == 1 and #RT.errors == 0)
		rawget(fakeCam, "__props").FieldOfView = saved
	end
	do
		-- interface : une interface détruite pendant l'animation ne bloque pas la restitution des autres
		local gui, other, other2 = newGui(), newGui(), newGui()
		local doneN = 0
		HatchFx.play(gui, HatchPlan.plan(3, 5), { hide = { other, other2, "pas une interface", 5 }, onDone = function()
			doneN = doneN + 1
		end })
		RT.step(0.3)
		other:Destroy()
		RT.step(3)
		check("Interface détruite en cours de route : les autres sont restituées, onDone appelé", doneN == 1 and other2.Enabled == true and #RT.errors == 0)
	end
	do
		-- 200 éclosions simulées par rareté sans erreur
		local gui = newGui()
		local total, doneCount = 0, 0
		for r = 1, 10 do
			for i = 1, 20 do
				local N = ({ 5, 141, 24631, 605042, 8e9 })[(i % 5) + 1]
				local plan = HatchPlan.plan(r, N, { reduced = i % 2 == 0, firstTime = i % 7 == 0, still = i % 3 == 0 })
				total = total + 1
				local h = HatchFx.play(gui, plan, { petText = "🐉", onDone = function()
					doneCount = doneCount + 1
				end })
				RT.step(i % 4 == 0 and 2 or 0.4)
				if h and i % 3 == 0 then
					h.skip()
				end
				if h and i % 5 == 0 then
					h.stop()
				end
			end
			RT.step(9)
		end
		check("200 éclosions (20 par rareté, options variées, tap/stop en cours) : toutes terminées, aucune erreur, aucun résidu (" .. doneCount .. "/" .. total .. ")", doneCount == total and #RT.errors == 0 and kids(gui) == 0 and kids(Lighting) == 0 and cam.FieldOfView == 70)
	end

	suite("BattleIntro : intro <= 3 s, passable, restitution")
	do
		local gui = newGui()
		local plan = IntroPlan.plan(info, { fmtOdds = Odds.label })
		local doneN, doneAt, sounds = 0, nil, {}
		local t0 = RT.now
		created = 0
		local h = BattleIntro.play(gui, plan, {
			thumbnail = function(id)
				return "rbxthumb://" .. id
			end,
			sound = function(key, vol)
				sounds[#sounds + 1] = key .. ":" .. tostring(vol)
			end,
			onDone = function()
				doneN = doneN + 1
				doneAt = RT.now - t0
			end,
		})
		local made = created
		RT.step(0.5)
		RT.fire(h.root, "Activated")
		check("Intro : tap avant 1 s ignoré", doneN == 0)
		RT.step(3.6)
		check("Intro : onDone une seule fois à <= 3,1 s (" .. string.format("%.2f", doneAt or -1) .. " s), interface vide ensuite", doneN == 1 and doneAt ~= nil and doneAt <= 3.1 and kids(gui) == 0 and h.isDone())
		check("Intro : fanfare jouée à 0,5 de volume", sounds[1] == "fanfare:0.5")
		check("Intro : plafond d'instances (" .. made .. " <= " .. BattleIntro.MAX_INSTANCES .. ")", made <= BattleIntro.MAX_INSTANCES)
		local d2 = 0
		local h2 = BattleIntro.play(gui, IntroPlan.plan({ countdown = true }), { onDone = function()
			d2 = d2 + 1
		end })
		RT.step(1.2)
		RT.fire(h2.root, "Activated")
		RT.fire(h2.root, "Activated")
		check("Intro : tap après 1 s -> fin immédiate, une seule fois", d2 == 1 and kids(gui) == 0)
		RT.step(4)
		check("Intro : rien ne revient après le passage, aucune erreur", d2 == 1 and #RT.errors == 0)
		local d3 = 0
		local h3 = BattleIntro.play(gui, nil, { onDone = function()
			d3 = d3 + 1
		end })
		local h4 = BattleIntro.play(gui, { left = 5, right = {} }, nil)
		check("Intro : plan invalide -> nil, onDone appelé une fois, sans erreur", h3 == nil and d3 == 1 and h4 == nil and #RT.errors == 0)
		local d5 = 0
		BattleIntro.play(gui, IntroPlan.plan(info), { thumbnail = function()
			error("miniature cassée")
		end, sound = function()
			error("son cassé")
		end, onDone = function()
			d5 = d5 + 1
		end })
		RT.step(4)
		check("Intro : miniature et son qui plantent -> terminée quand même", d5 == 1 and kids(gui) == 0 and #RT.errors == 0)
		local d6 = 0
		local h6 = BattleIntro.play(gui, { duration = 99, left = IntroPlan.plan({}).left, right = IntroPlan.plan({}).right, beats = {}, count = "x", arrow = 5 }, { onDone = function()
			d6 = d6 + 1
		end })
		RT.step(3.6)
		check("Intro : une durée de plan aberrante est plafonnée à 3 s", d6 == 1 and h6 ~= nil)
	end

	suite("TypeFx (client) : 9 types x base/spécial x (complet, mobile)")
	do
		local gui = newGui()
		local allOk2, why2, worst2 = true, "", 0
		local n = 0
		for _, t in ipairs(TypeFxData.TYPES) do
			for _, special in ipairs({ false, true }) do
				for _, reduced in ipairs({ false, true }) do
					n = n + 1
					local frame = RT.instance("Frame", "panel")
					local doneN = 0
					local sounds = {}
					created = 0
					local h = TypeFx.play(gui, D[t], special, { from = env2.Vector2.new(200, 300), to = env2.Vector2.new(600, 300), reduced = reduced, shakeFrame = frame, sound = function(k)
						sounds[#sounds + 1] = k
					end, onDone = function()
						doneN = doneN + 1
					end })
					if h == nil then
						allOk2, why2 = false, t .. " nil"
					else
						local expected = TypeFxData.cost(t, special, reduced)
						local fx = special and D[t].special or D[t].basic
						RT.step(fx.d + 0.2) -- toutes les couches sont lancées (la dernière commence avant d)
						if h.created() ~= expected then
							allOk2, why2 = false, t .. (special and " spécial" or " base") .. (reduced and " mobile" or "") .. " : " .. h.created() .. " objets pour un coût de " .. expected
						end
						worst2 = math.max(worst2, h.created())
						RT.step((fx.linger or 0) + 1)
						if doneN ~= 1 or kids(gui) ~= 0 or sounds[1] ~= (special and "special" or "attack") then
							allOk2, why2 = false, t .. " : résidu ou onDone (" .. doneN .. ", " .. kids(gui) .. ")"
						end
					end
				end
			end
		end
		check("TypeFx : 36 effets jouent sans erreur, objets créés = coût annoncé, détruits tout seuls, onDone une fois" .. (allOk2 and "" or " : " .. why2), allOk2 and n == 36 and #RT.errors == 0)
		check("TypeFx : plafond d'instances (" .. worst2 .. " <= " .. TypeFx.MAX_INSTANCES .. ")", worst2 <= TypeFx.MAX_INSTANCES)
		local h = TypeFx.play(gui, D.Feu, true, {})
		h.stop()
		check("TypeFx : stop() détruit tout de suite, positions par défaut acceptées", h.isDone() and kids(gui) == 0)
		RT.step(3)
		check("TypeFx : def invalide, nil, texte -> nil sans erreur ; positions invalides ignorées", TypeFx.play(gui, nil, false, nil) == nil and TypeFx.play(gui, "x", true, {}) == nil and TypeFx.play(gui, {}, true, {}) == nil and TypeFx.play(gui, { rgb = {} }, true, {}) == nil
			and TypeFx.play(gui, D.Eau, false, { from = "x", to = 5 }) ~= nil and #RT.errors == 0)
		RT.step(2)
		local lab = TypeFx.floatText(gui, "Super efficace !", { 70, 220, 90 }, 300, 200)
		local lab2 = TypeFx.floatText(gui, nil, nil, "x", {})
		RT.step(2)
		check("floatText : texte flottant créé puis détruit ; entrées invalides sans erreur", lab ~= nil and lab.Text == "Super efficace !" and lab2 ~= nil and kids(gui) == 0 and #RT.errors == 0)
	end
	check("Fin du lot 10 : aucune erreur dans le runtime factice (" .. #RT.errors .. ")", #RT.errors == 0)
	---------------------------------------------------------------- A9 : Config.Debug.forceHatch (Studio seulement, désactivé par défaut)
	;(function()
		suite("A9 : Config.Debug.forceHatch désactivé par défaut, sans effet hors Studio, tirage normal inchangé")
		local COLOR = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
		local Best = load("roblox/src/ReplicatedStorage/Bestiary.lua", "Bestiary", { Color3 = COLOR })
		local function realConfig()
			return load("roblox/src/ReplicatedStorage/Config.lua", "Config", {
				Color3 = COLOR,
				script = { Parent = { WaitForChild = function(_, n) return n end } },
				require = function(_) return Best end,
			})
		end
		local C = realConfig()
		check("Config.Debug.forceHatch : false par défaut (aucune rareté imposée), même en Studio", (C.Debug.forceHatch == false or C.Debug.forceHatch == nil) and C.debugForceTier(true) == nil and C.debugForceTier(false) == nil)
		C.Debug.forceHatch = 8
		check("forceHatch = 8 : sans effet hors Studio (production : IsStudio() = false), actif en Studio", C.debugForceTier(false) == nil and C.debugForceTier(nil) == nil and C.debugForceTier(true) == 8)
		local bad = true
		for _, v in ipairs({ 0, 11, 2.5, -1, 0 / 0, math.huge, "8", true }) do
			C.Debug.forceHatch = v
			if C.debugForceTier(true) ~= nil then
				bad = false
			end
		end
		check("forceHatch invalide (0, 11, 2,5, -1, NaN, inf, chaîne, booléen) : ignoré", bad)
		local tags = C.allEventTags()
		check("Avec forceHatch, toutes les fenêtres d'événement ouvertes (halloween, noel, saison1) pour tester l'Exclusif", tags.halloween == true and tags.noel == true and tags.saison1 == true)
		-- tirage normal inchangé : deux Config (défaut / forceHatch posé) donnent EXACTEMENT les mêmes tirages hors Studio (le crochet n'est pas dans Rules)
		local C1, C2 = realConfig(), realConfig()
		C2.Debug.forceHatch = 10
		local R1 = load("roblox/src/ServerScriptService/Rules.lua", "Rules").new(C1)
		local R2 = load("roblox/src/ServerScriptService/Rules.lua", "Rules").new(C2)
		local a, b = 4242, 4242
		local function g1() a = (a * 48271) % 2147483647 return (a - 1) / 2147483646 end
		local function g2() b = (b * 48271) % 2147483647 return (b - 1) / 2147483646 end
		local same = true
		for k = 1, 5000 do
			local egg = (k % 10) + 1
			local t1 = C1.debugForceTier(false) or egg
			local t2 = C2.debugForceTier(false) or egg
			local x, y = R1.rollPet(t1, 15, false, g1, false, nil), R2.rollPet(t2, 15, false, g2, false, nil)
			if t1 ~= t2 or x.p ~= y.p or x.s ~= y.s or x.m ~= y.m or x.tier ~= y.tier then
				same = false
			end
		end
		check("Tirage normal inchangé : 5 000 éclosions identiques avec et sans forceHatch hors Studio", same)
		-- en Studio : chaque rareté publiée sort bien de l'œuf imposé (Secret r8 et Divin r10 compris)
		local okAll = true
		for t = 1, 10 do
			C2.Debug.forceHatch = t
			local ft = C2.debugForceTier(true)
			if ft ~= t then
				okAll = false
			else
				for _ = 1, 50 do
					local r = R2.rollPet(ft, 0, false, g2, false, C2.allEventTags())
					if r.tier ~= t then
						okAll = false
					end
				end
			end
		end
		check("Studio : forceHatch = r donne toujours la rareté r (1 à 10, Exclusif compris)", okAll)
		local main = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
		check("Main : le crochet n'est lu qu'avec RunService:IsStudio() (éclosion et fenêtres)", select(2, main:gsub("Config%.debugForceTier%(RunService:IsStudio%(%)%)", "")) == 2 and main:find("debugForceTier%(true%)") == nil)
	end)()
end
