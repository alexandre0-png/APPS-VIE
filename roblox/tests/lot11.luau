--!nocheck
-- Tests du lot 11 (bestiaire de 78 espèces : données, types et compétences, modèles Blender, bonus de collection, repli procédural).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } fournis par tests/run.luau ou par tests/run_lot11.py.
-- Deux Config sont chargés : « plain » (Config.lua seul, SANS module Bestiary : repli sur les 18 espèces historiques) et « full » (Config.lua avec `script` et `require`
-- simulés qui rendent roblox/src/ReplicatedStorage/Bestiary.lua : 78 espèces). Les tests existants qui chargent Config seul voient donc toujours 18 espèces.
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2 (compatibilité lupa).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local COLOR = {
		fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
	}
	local function loadMod(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local Bestiary = loadMod("roblox/src/ReplicatedStorage/Bestiary.lua", "Bestiary", { Color3 = COLOR })
	local function loadConfig(bestiary)
		local environment = { Color3 = COLOR }
		if bestiary then
			environment.script = { Parent = {
				WaitForChild = function(_, name)
					return name
				end,
			} }
			environment.require = function(_)
				return bestiary
			end
		end
		return loadMod("roblox/src/ReplicatedStorage/Config.lua", "Config", environment)
	end
	local plain = loadConfig(nil)
	local full = loadConfig(Bestiary)
	local Battle = loadMod("roblox/src/ReplicatedStorage/Battle.lua", "Battle", {
		script = { Parent = { WaitForChild = function(_, n) return n end } },
		require = function(n)
			if n == "Bestiary" then return Bestiary end
			return loadMod("roblox/src/ReplicatedStorage/PetXp.lua", "PetXp")
		end,
	})
	local P = Bestiary.PETS

	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end
	local function near(a, b)
		return math.abs(a - b) < 1e-9
	end
	local function rgbEq(a, b)
		return near(a.R, b.R) and near(a.G, b.G) and near(a.B, b.B)
	end

	---------------------------------------------------------------- 1. Données : 78 espèces, indices 1 à 18 inchangés
	suite("Lot 11 : Bestiary, 78 espèces, indices 1-18 inchangés, branchement dans Config.PETS")
	check("Bestiary : 78 espèces (COUNT = 78), 18 historiques", #P == 78 and Bestiary.COUNT == 78 and Bestiary.LEGACY_COUNT == 18)
	check("Config seul (sans module Bestiary) : repli sur les 18 espèces historiques, Config.BESTIARY vide", #plain.PETS == 18 and plain.BESTIARY == nil)
	check("Config avec Bestiary : Config.PETS = les 78 espèces, Config.BESTIARY branché", #full.PETS == 78 and full.PETS == P and full.BESTIARY == Bestiary)
	local legacyOk, why = true, ""
	for i = 1, 18 do
		local a, b = plain.PETS[i], P[i]
		if a.tier ~= b.tier or a.name ~= b.name or a.inc ~= b.inc or a.emoji ~= b.emoji or a.ears ~= b.ears or a.extra ~= b.extra or not rgbEq(a.color, b.color) then
			legacyOk, why = false, why .. " " .. i
		end
	end
	check("Indices 1 à 18 : nom, rareté, revenu, emoji, couleur et repli identiques à l'ancien Config.PETS" .. why, legacyOk)
	check(
		"Indices 1 à 18 : noms historiques dans l'ordre (Poussin ... Wyrm astral)",
		P[1].name == "Poussin" and P[3].name == "Lapin" and P[6].name == "Renard" and P[13].name == "Dragon" and P[16].name == "Alien" and P[18].name == "Wyrm astral"
	)
	local drift = loadMod("roblox/src/ReplicatedStorage/Bestiary.lua", "Bestiary", { Color3 = COLOR })
	drift.PETS[5] = { tier = 3, name = "Intrus", inc = 8, emoji = "?", color = COLOR.fromRGB(1, 1, 1), ears = "none", extra = "none" }
	local cfgDrift = loadConfig(drift)
	check("Garde-fou : un Bestiary dont une des 18 premières entrées a changé est REFUSÉ (liste historique conservée)", #cfgDrift.PETS == 18 and cfgDrift.BESTIARY == nil)
	local short = { PETS = { P[1], P[2] } }
	check("Garde-fou : un Bestiary trop court est refusé", #loadConfig(short).PETS == 18)

	local wantCounts = { 10, 10, 10, 10, 9, 9, 8, 5, 3, 4 }
	local perTier = {}
	for t = 1, 10 do
		perTier[t] = {}
	end
	for i, d in ipairs(P) do
		perTier[d.tier][#perTier[d.tier] + 1] = i
	end
	local countsOk = true
	for t = 1, 10 do
		if #perTier[t] ~= wantCounts[t] then
			countsOk = false
		end
	end
	check("Répartition par rareté : 10, 10, 10, 10, 9, 9, 8, 5, 3, 4 (C.2)", countsOk)
	local liveOk, minOk = true, true
	for t = 1, 10 do
		liveOk = liveOk and full.tierLive(t) and full.liveEggTier(t) == t
		minOk = minOk and (t == 9 and #perTier[t] >= 1 or #perTier[t] >= 3)
	end
	check("Chaque rareté a au moins 3 espèces publiées (Exclusif : au moins 1) et les 10 raretés sont publiées dans Config", liveOk and minOk)
	check(
		"Config seul : les raretés 2, 8, 9, 10 restent non publiées (comportement historique)",
		not plain.tierLive(2) and not plain.tierLive(8) and not plain.tierLive(9) and not plain.tierLive(10)
	)
	local newSorted = true
	for i = 20, #P do
		if P[i].tier < P[i - 1].tier then
			newSorted = false
		end
	end
	check("Indices 19 à 78 : rangés par rareté croissante (ordre de la table C.2)", newSorted)
	local names, namesOk = {}, true
	for _, d in ipairs(P) do
		if names[d.name] or type(d.name) ~= "string" or d.name == "" or type(d.emoji) ~= "string" or d.emoji == "" then
			namesOk = false
		end
		names[d.name] = true
	end
	check("Noms uniques et emoji présents pour les 78 espèces", namesOk)

	-- Revenus
	local incOk, incWhy = true, ""
	for i, d in ipairs(P) do
		local r = full.INCOME_RANGE[d.tier]
		if type(d.inc) ~= "number" or d.inc ~= d.inc or d.inc < r[1] or d.inc > r[2] then
			incOk, incWhy = false, incWhy .. " " .. i
		end
	end
	check("Revenus : chaque espèce est dans la fourchette de sa rareté (Config.INCOME_RANGE)" .. incWhy, incOk)
	local growOk, growWhy = true, ""
	for t = 1, 9 do
		local maxT, minNext = 0, math.huge
		for _, i in ipairs(perTier[t]) do
			maxT = math.max(maxT, P[i].inc)
		end
		for _, i in ipairs(perTier[t + 1]) do
			minNext = math.min(minNext, P[i].inc)
		end
		if minNext < full.INCOME_GROWTH_MIN * maxT then
			growOk, growWhy = false, growWhy .. " r" .. t .. "->r" .. (t + 1)
		end
	end
	check("Revenus : le plus faible de la rareté r+1 gagne au moins " .. full.INCOME_GROWTH_MIN .. " x le plus fort de la rareté r (10 raretés)" .. growWhy, growOk)
	local distinctOk, incOrderOk = true, true
	for t = 1, 10 do
		local seen, prev = {}, 0
		for _, i in ipairs(perTier[t]) do
			if seen[P[i].inc] then
				distinctOk = false
			end
			seen[P[i].inc] = true
			if i > 18 then
				if P[i].inc <= prev then
					incOrderOk = false
				end
				prev = P[i].inc
			end
		end
	end
	check("Revenus : aucun revenu en double à l'intérieur d'une rareté", distinctOk)
	check("Revenus : à l'intérieur d'une rareté, les nouvelles espèces sont croissantes dans l'ordre de la table C.2", incOrderOk)
	local typesOk = true
	for t = 1, 10 do
		local seen = {}
		for _, i in ipairs(perTier[t]) do
			seen[Bestiary.SPECIES_TYPE[i]] = true
		end
		if count(seen) < 3 then
			typesOk = false
		end
	end
	check("Profils : au moins 3 types différents dans chaque rareté", typesOk)
	local keyOk = true
	for t = 1, 10 do
		local lo = math.huge
		for _, i in ipairs(perTier[t]) do
			lo = math.min(lo, P[i].inc)
		end
		-- la plus faible de la rareté est strictement plus forte que toute espèce de la rareté inférieure
		if t > 1 then
			for _, i in ipairs(perTier[t - 1]) do
				if P[i].inc >= lo then
					keyOk = false
				end
			end
		end
	end
	check("Revenus : tout revenu d'une rareté est strictement supérieur à tout revenu de la rareté inférieure", keyOk)
	local evOk = true
	for i, d in ipairs(P) do
		if (d.tier == 9) ~= (d.event ~= nil) then
			evOk = false
		end
	end
	check(
		"Exclusif (R9) : les 3 espèces portent un événement (halloween, noel, saison1), aucune autre espèce n'en porte",
		evOk and P[72].event == "halloween" and P[73].event == "noel" and P[74].event == "saison1"
	)

	-- Quelques valeurs de la spec (C.2)
	check(
		"C.2 : Souris #19 Commun, Tortue #26 Peu commun, Crocodile #36 Rare, Ours brun #43 Épique, Léopard des neiges #50 Légendaire, Phénix de feu #56 Mythique",
		P[19].name == "Souris"
			and P[19].tier == 1
			and P[26].name == "Tortue"
			and P[26].tier == 2
			and P[36].name == "Crocodile"
			and P[36].tier == 3
			and P[43].name == "Ours brun"
			and P[43].tier == 4
			and P[50].name == "Léopard des neiges"
			and P[50].tier == 5
			and P[56].name == "Phénix de feu"
			and P[56].tier == 6
	)
	check(
		"C.2 : Loup de cristaux #62 Ultra Rare, Démon enchaîné #67 Secret, Loup-garou citrouille #72 Exclusif, Séraphin-lion #75 Divin, Baleine des étoiles #78 Divin",
		P[62].tier == 7
			and P[67].name == "Démon enchaîné"
			and P[67].tier == 8
			and P[72].tier == 9
			and P[75].name == "Séraphin-lion"
			and P[75].tier == 10
			and P[78].name == "Baleine des étoiles"
			and P[78].tier == 10
	)

	---------------------------------------------------------------- 2. Repli procédural
	suite("Lot 11 : repli procédural de chacune des 78 espèces")
	local fbOk, fbWhy = true, ""
	for i, d in ipairs(P) do
		local f = Bestiary.fallback(i)
		local ok = f ~= nil and Bestiary.EARS[d.ears] == true and Bestiary.EXTRAS[d.extra] == true and (d.extra2 == nil or Bestiary.EXTRAS[d.extra2] == true)
		ok = ok and type(d.color) == "table" and d.color.R >= 0 and d.color.R <= 1 and d.color.G >= 0 and d.color.G <= 1 and d.color.B >= 0 and d.color.B <= 1
		ok = ok and (d.accent == nil or type(d.accent) == "table") and (d.scale == nil or (type(d.scale) == "number" and d.scale >= 0.7 and d.scale <= 1.3))
		if not ok then
			fbOk, fbWhy = false, fbWhy .. " " .. i
		end
	end
	check("Chaque espèce a un repli valide (couleur, oreilles et extras connus du Builder, échelle 0,7 à 1,3)" .. fbWhy, fbOk and Bestiary.fallback(79) == nil and Bestiary.fallback(0) == nil)
	local newExtras = { shell = false, wings2 = false, heads3 = false, segments = false, crystals = false, chains = false, halo = false }
	for i = 19, 78 do
		for _, e in ipairs({ P[i].extra, P[i].extra2 or "none" }) do
			if newExtras[e] ~= nil then
				newExtras[e] = true
			end
		end
	end
	local allNew = true
	for _, used in pairs(newExtras) do
		allNew = allNew and used
	end
	check("Les 7 nouveaux extras du repli (shell, wings2, heads3, segments, crystals, chains, halo) sont tous utilisés par au moins une espèce", allNew)
	check(
		"Espèces d'une rareté donnée : speciesOfTier rend les bons indices",
		#Bestiary.speciesOfTier(8) == 5 and Bestiary.speciesOfTier(8)[1] == 67 and Bestiary.speciesOfTier(10)[4] == 78 and #Bestiary.speciesOfTier(11) == 0
	)

	---------------------------------------------------------------- 3. Types et compétences
	suite("Lot 11 : SPECIES_TYPE / SPECIES_SKILL pour les 78 espèces (vocabulaire final du lot 12 et vocabulaire actuel de Battle.lua)")
	local isType, isSkill = {}, {}
	for _, t in ipairs(Bestiary.TYPES9) do
		isType[t] = true
	end
	for _, s in ipairs(Bestiary.SKILLS9) do
		isSkill[s] = true
	end
	local tOk, perType = #Bestiary.SPECIES_TYPE == 78 and #Bestiary.SPECIES_SKILL == 78, {}
	for i = 1, 78 do
		local t, s = Bestiary.SPECIES_TYPE[i], Bestiary.SPECIES_SKILL[i]
		if not isType[t] or not isSkill[s] then
			tOk = false
		end
		perType[t] = (perType[t] or 0) + 1
	end
	check("Types finaux : 78 valeurs parmi les 9 types, 78 compétences parmi les 9 compétences", tOk)
	check(
		"Types finaux (C.2) : Feu 9, Eau 10, Plante 7, Glace 10, Foudre 10, Terre 8, Ciel 6, Ombre 8, Lumière 10",
		perType["Feu"] == 9
			and perType["Eau"] == 10
			and perType["Plante"] == 7
			and perType["Glace"] == 10
			and perType["Foudre"] == 10
			and perType["Terre"] == 8
			and perType["Ciel"] == 6
			and perType["Ombre"] == 8
			and perType["Lumière"] == 10
	)
	local c1 = { "Ciel", "Ombre", "Lumière", "Eau", "Plante", "Feu", "Lumière", "Ombre", "Glace", "Feu", "Plante", "Lumière", "Feu", "Terre", "Eau", "Foudre", "Eau", "Ciel" }
	local c1ok = true
	for i = 1, 18 do
		if Bestiary.SPECIES_TYPE[i] ~= c1[i] then
			c1ok = false
		end
	end
	check(
		"C.1 : les 18 types finaux, avec les 6 changements (Manchot Glace, Licorne Lumière, Dragon Feu, T-Rex Terre, Kraken Eau, Alien Foudre, Wyrm astral Ciel)",
		c1ok and Bestiary.SPECIES_SKILL[9] == "freeze" and Bestiary.SPECIES_SKILL[14] == "bulwark" and Bestiary.SPECIES_SKILL[16] == "chain"
	)
	check(
		"C.2 : spot checks (Loup de glace Glace/freeze, Séraphin-lion Lumière/heal, Titan de l'orage Foudre/chain, Dragon céleste Ciel/focus, Hérisson Plante/drain)",
		Bestiary.SPECIES_TYPE[57] == "Glace"
			and Bestiary.SPECIES_SKILL[57] == "freeze"
			and Bestiary.SPECIES_TYPE[75] == "Lumière"
			and Bestiary.SPECIES_SKILL[75] == "heal"
			and Bestiary.SPECIES_TYPE[71] == "Foudre"
			and Bestiary.SPECIES_SKILL[71] == "chain"
			and Bestiary.SPECIES_TYPE[76] == "Ciel"
			and Bestiary.SPECIES_SKILL[76] == "focus"
			and Bestiary.SPECIES_TYPE[29] == "Plante"
			and Bestiary.SPECIES_SKILL[29] == "drain"
	)
	local battleOk, battleWhy = #Battle.SPECIES_TYPE == 78 and #Battle.SPECIES_SKILL == 78, ""
	local known9, knownSkill = {}, {}
	for _, t in ipairs(Battle.TYPES) do
		known9[t] = true
	end
	for sk in pairs(Battle.SKILLS) do
		knownSkill[sk] = true
	end
	for i = 1, 78 do
		local wantT = Bestiary.SPECIES_TYPE[i] == "Plante" and "Nature" or Bestiary.SPECIES_TYPE[i]
		if Battle.SPECIES_TYPE[i] ~= wantT or Battle.SPECIES_SKILL[i] ~= Bestiary.SPECIES_SKILL[i] or not known9[Battle.SPECIES_TYPE[i]] or not knownSkill[Battle.SPECIES_SKILL[i]] then
			battleOk, battleWhy = false, battleWhy .. " " .. i
		end
	end
	check(
		"FUSION 11+12 : Battle.SPECIES_TYPE / SPECIES_SKILL = Bestiary.SPECIES_TYPE / SKILL (78 espèces, 9 types, Plante -> clé Nature), tous connus du moteur" .. battleWhy,
		battleOk
	)
	local skills6 = {}
	for i = 1, 78 do
		skills6[Battle.SPECIES_SKILL[i]] = (skills6[Battle.SPECIES_SKILL[i]] or 0) + 1
	end
	check(
		"Battle : les 9 compétences sont toutes utilisées par au moins 2 espèces (aucune compétence orpheline)",
		skills6.strike >= 2 and skills6.drain >= 2 and skills6.heal >= 2 and skills6.guard >= 2 and skills6.stun >= 2 and skills6.focus >= 2 and skills6.freeze >= 2 and skills6.chain >= 2 and skills6.bulwark >= 2
	)
	-- Unités et combats avec les 78 espèces
	local unitOk, unitWhy = true, ""
	for i = 1, 78 do
		local okU, u = pcall(function()
			return Battle.unit(full, { p = i, s = 2, m = 1 })
		end)
		if not okU or type(u) ~= "table" or u.type ~= Battle.SPECIES_TYPE[i] or u.skill ~= Battle.SPECIES_SKILL[i] or not (u.maxHp > 0) then
			unitOk, unitWhy = false, unitWhy .. " " .. i
		end
	end
	check("Battle.unit : les 78 espèces donnent une unité valide (type, compétence, PV)" .. unitWhy, unitOk)
	local prevMax, powOk = 0, true
	for t = 1, 10 do
		local lo, hi = math.huge, 0
		for _, i in ipairs(perTier[t]) do
			local u = Battle.unit(full, { p = i, s = 2, m = 1 })
			local pw = u.maxHp + 3 * u.atk + 2 * u.spd
			lo, hi = math.min(lo, pw), math.max(hi, pw)
		end
		if lo <= prevMax then
			powOk = false
		end
		prevMax = hi
	end
	check("Force : la puissance de combat croît avec la rareté pour les 78 espèces (toute espèce d'une rareté plus forte que toute espèce de la rareté inférieure)", powOk)
	local seed = 20261127
	local function rnd()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	local brOk, brWhy = true, ""
	for n = 1, 300 do
		local function team()
			local t = {}
			for k = 1, 3 do
				t[k] = Battle.unit(full, { p = 1 + math.floor(rnd() * 78), s = 1 + math.floor(rnd() * 5), m = 1 + math.floor(rnd() * 6) })
			end
			return t
		end
		local okB, res = pcall(function()
			return Battle.run(1000 + n, team(), team())
		end)
		if not okB or not res.over or (res.winner ~= 1 and res.winner ~= 2) or res.turn > Battle.MAX_TURNS then
			brOk, brWhy = false, brWhy .. " " .. n .. (okB and "" or (" " .. tostring(res):sub(1, 60)))
		end
	end
	check("Battle : 300 combats d'équipes aléatoires parmi les 78 espèces, sans erreur, tous terminés dans la limite de tours" .. brWhy, brOk)

	---------------------------------------------------------------- 4. Modèles Blender
	suite("Lot 11 : modèles Blender des 60 créatures (lots 22 à 26) : Bestiary.ASSET_IDS, Config.Assets.petsNew, Assets.loadPets")
	local ids, idsOk, byId = Bestiary.ASSET_IDS, true, {}
	for i = 1, 78 do
		local id = ids[i]
		if i <= 18 then
			idsOk = idsOk and id == nil
		else
			idsOk = idsOk and type(id) == "number" and id > 0 and id % 1 == 0 and not byId[id]
			byId[id] = true
		end
	end
	check("ASSET_IDS : exactement 60 identifiants entiers positifs uniques, pour les indices 19 à 78 (aucun pour les 18 historiques)", idsOk and count(ids) == 60)
	local invOk = count(Bestiary.ASSET_SPECIES) == 60
	for i = 19, 78 do
		local nm = P[i].model
		if type(nm) ~= "string" or nm:sub(1, 4) ~= "pet_" or Bestiary.ASSET_SPECIES[nm] ~= i then
			invOk = false
		end
	end
	for i = 1, 18 do
		if P[i].model ~= nil then
			invOk = false
		end
	end
	check("Correspondance asset -> espèce : 60 noms de modèle (pet_*) uniques, chacun rend l'indice de son espèce", invOk)
	local spot = Bestiary.ASSET_SPECIES.pet_loup_de_glace == 57
		and ids[57] == 85636324524964
		and Bestiary.ASSET_SPECIES.pet_cochon == 27
		and ids[27] == 120209362861524
		and Bestiary.ASSET_SPECIES.pet_baleine_des_etoiles == 78
		and ids[78] == 122467490138604
		and Bestiary.ASSET_SPECIES.pet_demon_enchaine == 67
		and ids[67] == 135810765401304
		and Bestiary.ASSET_SPECIES.pet_requin == 44
		and ids[44] == 74168168387947
		and Bestiary.ASSET_SPECIES.pet_souris == 19
		and ids[19] == 121918353604833
	check("Assets-crees.md : identifiants de contrôle (Loup de glace #57, Cochon #27, Baleine #78, Démon #67, Requin #44, Souris #19)", spot)
	check(
		"Config avec Bestiary : Config.Assets.petsNew = les 60 identifiants, plafond petsMaxPartsNew = 40, anciens Assets.pets (18) inchangés",
		count(full.Assets.petsNew) == 60
			and full.Assets.petsNew[57] == 85636324524964
			and full.Assets.petsMaxPartsNew == 40
			and count(full.Assets.pets) == count(plain.Assets.pets)
			and count(plain.Assets.petsNew) == 0
	)
	-- Assets.loadPets avec un chargeur factice
	local AssetsMod = loadMod("roblox/src/ReplicatedStorage/Assets.lua", "Assets")
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
		end
		function o:Clone()
			return inst(self.ClassName, { children = self.children, id = self.id })
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
	local function model(nParts, id)
		local ch = {}
		for k = 1, nParts do
			ch[k] = inst("Part", { Name = "P" .. k .. "__AABBCC" })
		end
		return inst("Model", { children = ch, id = id })
	end
	local clock = 0
	local function deps(loader)
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
			color = function()
				return "c"
			end,
		}
	end
	local A1 = AssetsMod.new(
		full,
		deps(function(id)
			return model(30, id)
		end)
	)
	local loaded = A1.loadPets()
	check("Assets.loadPets : les anciens pets ET les 60 nouveaux sont chargés (" .. loaded .. ")", loaded == count(full.Assets.pets) + 60)
	check(
		"Assets.clonePet : un nouveau pet (Cochon #27, Baleine #78) est cloné avec le bon identifiant, un indice hors bestiaire (79) rend nil",
		A1.clonePet(27) ~= nil and A1.clonePet(78) ~= nil and A1.clonePet(27).id == 120209362861524 and A1.clonePet(79) == nil
	)
	local A2 = AssetsMod.new(
		full,
		deps(function(id)
			return model(41, id)
		end)
	)
	A2.loadPets()
	check(
		"Plafond : un nouveau modèle de 41 Parts est refusé (petsMaxPartsNew = 40, repli procédural), un ancien de 41 Parts reste accepté (plafond 120)",
		A2.clonePet(27) == nil and A2.clonePet(10) ~= nil and A2.status["p:27"] ~= nil and A2.status["p:27"].ok == false
	)
	local A3 = AssetsMod.new(
		full,
		deps(function(id)
			return model(40, id)
		end)
	)
	A3.loadPets()
	check("Plafond : un nouveau modèle de 40 Parts est accepté", A3.clonePet(27) ~= nil)
	local A4 = AssetsMod.new(
		plain,
		deps(function(id)
			return model(30, id)
		end)
	)
	check("Sans Bestiary : seuls les anciens pets sont chargés (aucun indice > 18)", A4.loadPets() == count(plain.Assets.pets) and A4.clonePet(27) == nil)
	local A5 = AssetsMod.new(
		full,
		deps(function()
			error("Requester does not have permission for Asset")
		end)
	)
	check("Repli : permission refusée sur les 60 modèles -> aucun clone, aucune erreur", A5.loadPets() == 0 and A5.clonePet(27) == nil)

	---------------------------------------------------------------- 5. Bonus de collection
	suite("Lot 11 : bonus de collection (+5 % par 3 espèces jusqu'à 18, puis +5 % par 6, maximum +80 %)")
	local function oldBonus(n)
		return 1 + 0.05 * math.floor(n / 3)
	end
	local sameOld = true
	for n = 0, 18 do
		if not near(full.collectionBonus(n), oldBonus(n)) or not near(plain.collectionBonus(n), oldBonus(n)) then
			sameOld = false
		end
	end
	check("De 0 à 18 espèces : identique à l'ancienne formule (+30 % à 18), donc jamais en baisse pour un profil migré", sameOld and near(full.collectionBonus(18), 1.3))
	check(
		"Au-delà de 18 : 21 -> +30 %, 24 -> +35 %, 30 -> +40 %, 48 -> +55 %, 77 -> +75 %, 78 -> +80 %",
		near(full.collectionBonus(21), 1.3)
			and near(full.collectionBonus(23), 1.3)
			and near(full.collectionBonus(24), 1.35)
			and near(full.collectionBonus(30), 1.4)
			and near(full.collectionBonus(48), 1.55)
			and near(full.collectionBonus(77), 1.75)
			and near(full.collectionBonus(78), 1.8)
	)
	check(
		"Plafond +80 % (même avec 200 espèces), valeurs invalides = aucun bonus (nil, NaN, négatif, texte)",
		near(full.collectionBonus(200), 1.8) and full.collectionBonus(nil) == 1 and full.collectionBonus(0 / 0) == 1 and full.collectionBonus(-5) == 1 and full.collectionBonus("x") == 1
	)
	local mono = true
	for n = 1, 120 do
		if full.collectionBonus(n) < full.collectionBonus(n - 1) - 1e-12 then
			mono = false
		end
	end
	check("Le bonus ne baisse jamais quand une espèce de plus est découverte (0 à 120)", mono)
	check(
		"Constantes : COLLECTION_STEP 3, COLLECTION_BONUS 0,05, base 18, palier 6, max 0,8 ; 78 espèces donnent exactement le maximum",
		full.COLLECTION_STEP == 3
			and full.COLLECTION_BONUS == 0.05
			and full.COLLECTION_BASE_COUNT == 18
			and full.COLLECTION_STEP2 == 6
			and full.COLLECTION_MAX == 0.8
			and near(full.collectionBonus(#full.PETS), 1 + full.COLLECTION_MAX)
	)

	---------------------------------------------------------------- 6. Tirages avec les 78 espèces
	suite("Lot 11 : tirages d'espèces (Rules.rollPet) avec les 10 raretés publiées")
	local Rules = loadMod("roblox/src/ServerScriptService/Rules.lua", "Rules").new(full)
	local seed2 = 4242
	local function rnd2()
		seed2 = (seed2 * 16807) % 2147483647
		return seed2 / 2147483647
	end
	local rollOk, rollWhy = true, ""
	local ALL_OPEN = { halloween = true, noel = true, saison1 = true } -- A5 : toutes les fenêtres ouvertes (sinon les espèces d'événement ne sortent pas)
	for t = 1, 10 do
		local seen = {}
		for _ = 1, 6000 do
			local r = Rules.rollPet(t, 0, false, rnd2, false, ALL_OPEN)
			if type(r.p) ~= "number" or not P[r.p] or P[r.p].tier ~= r.tier or r.tier < t then
				rollOk, rollWhy = false, rollWhy .. " r" .. t
			end
			seen[r.p or 0] = true
		end
		for _, i in ipairs(perTier[t]) do
			if not seen[i] then
				rollOk, rollWhy = false, rollWhy .. " (#" .. i .. " jamais tirée de l'œuf r" .. t .. ")"
			end
		end
	end
	check("rollPet (toutes fenêtres ouvertes) : de l'œuf de rareté r, chaque espèce de la rareté r sort, jamais de rareté inférieure, l'espèce correspond à la rareté annoncée" .. rollWhy, rollOk)
	local foldOk = true
	local w = full.foldWeights({ 10, 10, 10, 10, 10, 10, 10, 10, 10, 20 })
	for t = 1, 10 do
		foldOk = foldOk and w[t] == (t == 10 and 20 or 10)
	end
	check(
		"Toutes les raretés publiées : foldWeights ne reporte plus aucun poids, tierRank(10) = 10, nextLiveTier(1) = 2",
		foldOk and full.tierRank(10) == 10 and full.nextLiveTier(1) == 2 and full.nextLiveTier(10) == nil
	)

	---------------------------------------------------------------- 7. Builder : repli procédural des 78 espèces dans le vrai Builder (runtime factice)
	suite("Lot 11 : Builder.pet construit les 78 espèces (repli procédural, runtime factice)")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = plain.Game.Places.game })
	if not RT then
		return
	end
	local main = RT.buildTree("roblox/src", false)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local rcfg = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
	local Builder = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder"))
	check(
		"Runtime factice : Config.PETS compte 78 espèces dans l'arborescence (Bestiary rangé sous Shared), aucune erreur au démarrage",
		#rcfg.PETS == 78 and rcfg.BESTIARY ~= nil and #RT.errors == 0
	)
	local assetsWere = rcfg.Assets.Enabled
	rcfg.Assets.Enabled = false -- repli procédural : aucun modèle Blender (le Builder fabrique le pet avec ses Parts)
	local function names(model)
		local set, n = {}, 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				set[d.Name] = true
				n = n + 1
			end
		end
		return set, n
	end
	local buildOk, buildWhy, maxParts = true, "", 0
	local extraPart = {
		shell = "Shell",
		wings2 = "WingL2",
		heads3 = "Head2",
		segments = "Seg3",
		crystals = "Crystal3",
		chains = "ChainL",
		halo = "PetHalo",
		wings = "WingL",
		tail = "Tail",
		beak = "Beak",
		horn = "Horn",
		mane = "Mane",
		tentacles = "Tent4",
		antenna = "Ant",
	}
	for i = 1, 78 do
		for _, sz in ipairs({ 1, 3, 5 }) do
			for _, mu in ipairs({ 1, 3, 4 }) do
				local okP, m, lift = pcall(function()
					return Builder.pet(i, sz, mu)
				end)
				if not okP or m == nil or type(lift) ~= "number" or lift ~= lift then
					buildOk, buildWhy = false, buildWhy .. " #" .. i .. "/" .. sz .. "/" .. mu .. (okP and "" or (" " .. tostring(m):sub(1, 70)))
				else
					local set, n = names(m)
					maxParts = math.max(maxParts, n)
					if not m.PrimaryPart or not set.Body then
						buildOk, buildWhy = false, buildWhy .. " #" .. i .. " sans corps"
					end
					for _, e in ipairs({ rcfg.PETS[i].extra, rcfg.PETS[i].extra2 or "none" }) do
						if extraPart[e] and not set[extraPart[e]] then
							buildOk, buildWhy = false, buildWhy .. " #" .. i .. " extra " .. e .. " absent"
						end
					end
				end
			end
		end
	end
	check("Builder.pet : 78 espèces x 3 tailles x 3 mutations construites sans erreur, corps (PrimaryPart) et extras présents" .. buildWhy, buildOk)
	check("Builder.pet : au plus 60 Parts par pet procédural (plus gros mesuré : " .. maxParts .. ")", maxParts <= 60)
	local legacyBuild = true
	for i = 1, 18 do
		local m = Builder.pet(i, 2, 1)
		local set = names(m)
		local d = rcfg.PETS[i]
		if d.accent ~= nil or d.extra2 ~= nil or d.scale ~= nil or set.Shell or set.WingL2 or set.Head2 or set.Seg1 or set.Crystal1 or set.PetHalo then
			legacyBuild = false
		end
	end
	check("Les 18 espèces historiques gardent leur apparence procédurale (aucun nouvel extra, accent ni échelle propre)", legacyBuild)
	rcfg.Assets.Enabled = assetsWere
	RT.step(1)
	check("Builder : aucune erreur serveur après la construction des pets" .. (#RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))), #RT.errors == 0)

	---------------------------------------------------------------- 8. Intégration lot 11 x lot 16 (boutique, passe de combat, calendrier, compteur 1 sur N, éclosion)
	suite("Lot 11 x lot 16 : offres des raretés publiées, espèce de saison, tirage du jour 30, Odds, HatchPlan")
	local function loadPure(name, environment)
		return loadMod("roblox/src/ReplicatedStorage/" .. name .. ".lua", name, environment)
	end
	local Shop = loadPure("Shop")
	local SD = loadPure("SeasonData")
	local Season = loadPure("Season")
	local Cal = loadPure("Calendar")
	local Odds = loadPure("Odds")
	local HP = loadPure("HatchPlan")
	local function visibleKeys(cfg, open)
		local set = {}
		for _, cat in ipairs(Shop.visibleOffers({ season = { cur = 1 }, open = open or { saison1 = true } }, cfg, false, nil)) do
			for _, o in ipairs(cat.offers) do
				set[o.key] = true
			end
		end
		return set
	end
	local vFull, vPlain = visibleKeys(full), visibleKeys(plain)
	check("Boutique (78 espèces) : EggR2, EggSecret, EggExclusive, EggDivine affichés (raretés publiées par le bestiaire)", vFull.EggR2 == true and vFull.EggSecret == true and vFull.EggExclusive == true and vFull.EggDivine == true)
	check("Boutique (18 espèces, repli) : ces 4 œufs restent masqués (rareté sans espèce publiée : rien d'invendable)", not vPlain.EggR2 and not vPlain.EggSecret and not vPlain.EggExclusive and not vPlain.EggDivine)
	local okSecret = Shop.canBuy({ season = { cur = 1 }, cap = 10, slots = {}, eggBag = {} }, full, "EggSecret", false)
	local okSecretPlain = Shop.canBuy({ season = { cur = 1 }, cap = 10, slots = {}, eggBag = {} }, plain, "EggSecret", false)
	check("Shop.canBuy : œuf Secret achetable avec le bestiaire, refusé sans espèce Secret (contrôle serveur avant l'invite)", okSecret == true and okSecretPlain == false)
	-- passe de combat : palier 30 premium de la saison 1 = espèce Exclusif du bestiaire (par NOM), saisons sans espèce = trophée de repli
	local SFull = Season.new(full, SD)
	local exIdx
	for i, t in ipairs(full.TIERS) do
		if t.name == "Exclusif" then
			exIdx = i
		end
	end
	local function speciesAt(S, n)
		for _, g in ipairs(S.rewardFor(n, 30, "premium") or {}) do
			if g.kind == "species" then
				return g
			end
		end
		return nil
	end
	local g1 = speciesAt(SFull, 1)
	local s1def
	for _, d in ipairs(full.PETS) do
		if g1 and d.name == g1.name then
			s1def = d
		end
	end
	check("Passe de combat saison 1 : palier 30 premium = « Corbeau couronné » (espèce Exclusif du bestiaire, event saison1)", g1 ~= nil and g1.name == "Corbeau couronné" and g1.tier == exIdx and s1def ~= nil and s1def.tier == exIdx and s1def.event == "saison1")
	local fb2 = SFull.rewardFor(2, 30, "premium")[1]
	check("Passe de combat saison 2 (espèce pas encore créée) : trophée Exclusif de repli, jamais de récompense perdue", speciesAt(SFull, 2) == nil and fb2.kind == "cosmetic" and fb2.fallback == true and fb2.id == "s2_trophy")
	local fbPlain = Season.new(plain, SD).rewardFor(1, 30, "premium")[1]
	check("Passe de combat saison 1 sans bestiaire : trophée de repli (Config seul)", fbPlain.kind == "cosmetic" and fbPlain.fallback == true and fbPlain.id == "s1_trophy")
	-- calendrier : le jour 30 tire vraiment du Secret (15 %) dès que le bestiaire publie des Secrets
	local cnt, st = { 0, 0, 0 }, 4242
	for _ = 1, 200000 do
		st = (st * 48271) % 2147483647
		local t = Cal.draw(full, (st - 1) / 2147483646)
		cnt[t - 5] = cnt[t - 5] + 1
	end
	check("Calendrier J30 (78 espèces) : Secret disponible, 40 / 45 / 15 % à +-0,5 pt sur 200 000 tirages Park-Miller (" .. cnt[1] / 2000 .. " / " .. cnt[2] / 2000 .. " / " .. cnt[3] / 2000 .. ")",
		Cal.tierAvailable(full, 8) and math.abs(cnt[1] / 2000 - 40) <= 0.5 and math.abs(cnt[2] / 2000 - 45) <= 0.5 and math.abs(cnt[3] / 2000 - 15) <= 0.5 and Cal.rewardText(full, 30):find("15 % Secret", 1, true) ~= nil)
	check("Calendrier J30 sans bestiaire : repli Ultra Rare (60 %), jamais d'œuf Secret", not Cal.tierAvailable(plain, 8) and Cal.draw(plain, 0.9999) == 7 and Cal.rewardText(plain, 30):find("60 % Ultra Rare", 1, true) ~= nil)
	-- compteur « 1 sur N » et plan d'éclosion sur les 78 espèces
	local okV, probs = Odds.validate(full)
	check("Odds.validate (78 espèces) : REF complète, chaque rareté publiée" .. (okV and "" or (" : " .. tostring(probs[1]))), okV and #full.ODDS.REF == #full.TIERS)
	local oddsOk, hpOk, mono = true, true, true
	local lastByTier = {}
	for i, d in ipairs(full.PETS) do
		local n = Odds.forPet(full, i, 2, 1)
		if type(n) ~= "number" or n < 1 or n ~= n then
			oddsOk = false
		end
		if lastByTier[d.tier] and lastByTier[d.tier] ~= n then
			mono = false -- même rareté, même taille, même mutation : même N (pas de biais par espèce)
		end
		lastByTier[d.tier] = n
		local plan = HP.plan(d.tier, n, {})
		local okP = HP.check(plan)
		if not okP then
			hpOk = false
		end
	end
	check("Odds.forPet : un N fini >= 1 pour chacune des 78 espèces, identique dans une même rareté", oddsOk and mono)
	check("Odds : N croissant avec la rareté (Commun < Peu commun < ... < Divin, hors Exclusif jamais tiré au tapis)", (function()
		local prev = 0
		for t = 1, 10 do
			if t ~= 9 then
				local n = lastByTier[t]
				if type(n) ~= "number" or n <= prev then
					return false
				end
				prev = n
			end
		end
		return true
	end)())
	check("HatchPlan.plan / check : plan d'éclosion valide pour les 78 espèces (rareté et N réels)", hpOk)
	check("Config.Assets.petsNew : un modèle Blender (60) ou le repli procédural pour chaque espèce 19 à 78, plafond de 40 Parts pour les nouveaux", (function()
		local n = 0
		for i = 19, 78 do
			if full.Assets.petsNew[i] ~= nil then
				n = n + 1
			end
		end
		return n == 60 and full.Assets.petsMaxPartsNew == 40
	end)())
	---------------------------------------------------------------- A5 : espèces d'événement et de saison seulement dans leur fenêtre
	;(function()
		suite("A5 : espèces d'événement / de saison (champ event) tirées seulement dans leur fenêtre (EVENTS_CAL, saison)")
		local Rewards = loadMod("roblox/src/ReplicatedStorage/Rewards.lua", "Rewards")
		local Reveal = loadMod("roblox/src/ReplicatedStorage/Reveal.lua", "Reveal")
		local OddsA = loadMod("roblox/src/ReplicatedStorage/Odds.lua", "Odds")
		local ShopA = loadMod("roblox/src/ReplicatedStorage/Shop.lua", "Shop")
		local SDA = loadMod("roblox/src/ReplicatedStorage/SeasonData.lua", "SeasonData")
		local SA = loadMod("roblox/src/ReplicatedStorage/Season.lua", "Season").new(full, SDA)
		local eventIdx = {}
		for i, d in ipairs(full.PETS) do
			if d.event ~= nil then
				eventIdx[#eventIdx + 1] = i
			end
		end
		check("Bestiaire : 3 espèces d'événement / de saison (#72 halloween, #73 noel, #74 saison1)", #eventIdx == 3 and eventIdx[1] == 72 and eventIdx[2] == 73 and eventIdx[3] == 74)
		-- fenêtres calculées par Rewards.openSpeciesEvents (dates UTC, saison 1 = 1er déc. 2026 + 60 jours)
		local function openAt(now)
			return Rewards.openSpeciesEvents(full, now, SA.currentSeason(now).n)
		end
		local T_NONE, T_HALLO, T_HALLO_END, T_AFTER, T_XMAS, T_SEASON, T_SPRING = 1795867200, 1792929600, 1793491199, 1793491200, 1797768000, 1800014400, 1774440000
		local function keys(o)
			local out = {}
			for k, v in pairs(o) do
				if v == true then
					out[#out + 1] = k
				end
			end
			table.sort(out)
			return table.concat(out, ",")
		end
		check("Fenêtres : 28 nov. 2026 = aucune ; 25 et 31 oct. 23:59:59 = halloween ; 1er nov. 00:00 = aucune ; 20 déc. = xmas, noel, saison1 ; 15 janv. 2027 = saison1 ; printemps = spring seul",
			keys(openAt(T_NONE)) == "" and keys(openAt(T_HALLO)) == "halloween" and keys(openAt(T_HALLO_END)) == "halloween" and keys(openAt(T_AFTER)) == ""
				and keys(openAt(T_XMAS)) == "noel,saison1,xmas" and keys(openAt(T_SEASON)) == "saison1" and keys(openAt(T_SPRING)) == "spring")
		check("openSpeciesEvents : entrées invalides = ensemble vide, jamais d'erreur", keys(Rewards.openSpeciesEvents(full, nil, nil)) == "" and keys(Rewards.openSpeciesEvents(full, 0 / 0, 1.5)) == "" and keys(Rewards.openSpeciesEvents(full, "x", -1)) == "")
		local RulesA = loadMod("roblox/src/ServerScriptService/Rules.lua", "Rules").new(full)
		-- Park-Miller 48271 mod 2^31-1 (aucun produit > 2^53)
		local seed = 20261128
		local function pm()
			seed = (seed * 48271) % 2147483647
			return (seed - 1) / 2147483646
		end
		-- 1. hors fenêtre (open = {} et open = nil) : 200 000 tirages sur les 10 œufs, avec chance, Alien et pitié : jamais une espèce d'événement
		local hits, badTier, n9, n9low = 0, 0, 0, 0
		for k = 1, 200000 do
			local egg = (k % 10) + 1
			local r = RulesA.rollPet(egg, (k % 8) * 10, k % 7 == 0, pm, k % 13 == 0, (k % 2 == 0) and {} or nil)
			if full.PETS[r.p].event ~= nil then
				hits = hits + 1
			end
			if full.PETS[r.p].tier ~= r.tier then
				badTier = badTier + 1
			end
			if egg == 9 then
				n9 = n9 + 1
				if r.tier == 8 then
					n9low = n9low + 1
				end
			end
		end
		check("Hors fenêtre : 0 espèce d'événement / de saison sur 200 000 tirages Park-Miller (" .. hits .. ")", hits == 0 and badTier == 0)
		check("Hors fenêtre : un œuf Exclusif (aucune espèce tirable) donne la rareté inférieure publiée (Secret), jamais rien d'invalide", n9 == 20000 and n9low == n9)
		-- 2. dans la fenêtre : seule l'espèce de la fenêtre sort, fréquence conforme à Reveal.probability
		local function tier9(open, N)
			local cnt = {}
			for _ = 1, N do
				local r = RulesA.rollPet(9, 0, false, pm, false, open)
				cnt[r.p] = (cnt[r.p] or 0) + 1
			end
			return cnt
		end
		local ch = tier9(openAt(T_HALLO), 20000)
		check("Halloween : l'œuf Exclusif donne toujours #72 (Loup-garou citrouille), jamais #73 / #74", ch[72] == 20000 and ch[73] == nil and ch[74] == nil)
		local cs = tier9(openAt(T_SEASON), 20000)
		check("Saison 1 (hors événement) : l'œuf Exclusif donne toujours #74 (Corbeau couronné)", cs[74] == 20000 and cs[72] == nil and cs[73] == nil)
		local cx = tier9(openAt(T_XMAS), 40000)
		local px = Reveal.probability(full, RulesA, 9, 0, false, 73, 2, 1, false, openAt(T_XMAS)) / (full.SIZES[2].weight / 100) -- part de l'espèce (taille Normal, sans mutation retirées)
		local sumM = 0
		for _, m in ipairs(full.MUTS) do
			sumM = sumM + m.weight
		end
		px = px / (full.MUTS[1].weight / sumM)
		check("Noël + saison 1 : #73 et #74 à 50 % chacune (+-1,5 pt sur 40 000), Reveal.probability conforme (0,5), #72 jamais (" .. (cx[73] or 0) / 400 .. " %)",
			cx[72] == nil and math.abs((cx[73] or 0) / 40000 - 0.5) <= 0.015 and math.abs((cx[74] or 0) / 40000 - 0.5) <= 0.015 and math.abs(px - 0.5) < 1e-9)
		check("Reveal.probability : 0 pour une espèce hors fenêtre (open nil ou autre fenêtre), > 0 dans sa fenêtre",
			Reveal.probability(full, RulesA, 9, 0, false, 72, 2, 1, false, nil) == 0 and Reveal.probability(full, RulesA, 9, 0, false, 72, 2, 1, false, openAt(T_SEASON)) == 0
				and Reveal.probability(full, RulesA, 9, 0, false, 72, 2, 1, false, openAt(T_HALLO)) > 0 and Reveal.oneIn(full, RulesA, 9, 0, false, 74, 2, 1, false, nil) == math.huge)
		check("Reveal.probability : œuf Exclusif hors fenêtre = loi de l'œuf Secret (même rareté effective)",
			full.PETS[perTier[8][1]].tier == 8 and Reveal.probability(full, RulesA, 9, 0, false, perTier[8][1], 2, 1, false, nil) > 0
				and math.abs(Reveal.probability(full, RulesA, 9, 0, false, perTier[8][1], 2, 1, false, nil) - Reveal.probability(full, RulesA, 8, 0, false, perTier[8][1], 2, 1, false, nil)) < 1e-15)
		-- 3. tirage normal inchangé pour les raretés sans espèce d'événement (mêmes tirages avec ou sans fenêtre)
		local same = true
		for t = 1, 10 do
			if t ~= 9 then
				local s1, s2 = 777 + t, 777 + t
				local function g1()
					s1 = (s1 * 48271) % 2147483647
					return (s1 - 1) / 2147483646
				end
				local function g2()
					s2 = (s2 * 48271) % 2147483647
					return (s2 - 1) / 2147483646
				end
				for _ = 1, 500 do
					local a, b = RulesA.rollPet(t, 20, false, g1, false, nil), RulesA.rollPet(t, 20, false, g2, false, ALL_OPEN)
					if a.p ~= b.p or a.s ~= b.s or a.m ~= b.m or a.tier ~= b.tier then
						same = false
					end
				end
			end
		end
		check("Raretés 1-8 et 10 : tirage identique avec ou sans fenêtre ouverte (rien d'autre ne change)", same)
		-- 4. tapis : aucune rareté Exclusif (poids nul, standard et doré) ; Odds : compteur de référence inchangé, indépendant de la date
		local fw, fg = full.foldWeights(full.BELT.weights.normal), full.foldWeights(full.BELT.weights.golden)
		check("Tapis (standard et doré) : poids Exclusif nul, aucune espèce d'événement ne peut y sortir", fw[9] == 0 and fg[9] == 0 and full.BELT.weights.normal[9] == 0 and full.BELT.weights.golden[9] == 0)
		check("Odds.forPet : compteur de référence fini et figé pour #72-#74 (indépendant des fenêtres, jamais recalculé)", type(OddsA.forPet(full, 72, 2, 1)) == "number" and OddsA.forPet(full, 72, 2, 1) == OddsA.forPet(full, 74, 2, 1))
		-- 5. boutique : œuf Exclusif en vente seulement dans une fenêtre ; texte d'espèces = espèces tirables ; plumes refusées hors espèce
		local function eggExVisible(open)
			for _, cat in ipairs(ShopA.visibleOffers({ season = { cur = 1 }, open = open }, full, false, nil)) do
				for _, o in ipairs(cat.offers) do
					if o.key == "EggExclusive" then
						return true
					end
				end
			end
			return false
		end
		local okNo, whyNo = ShopA.canBuy({ season = { cur = 1 }, cap = 10, slots = {}, eggBag = {} }, full, "EggExclusive", false)
		local okH = ShopA.canBuy({ season = { cur = 1 }, cap = 10, slots = {}, eggBag = {}, open = openAt(T_HALLO) }, full, "EggExclusive", false)
		check("Boutique : œuf Exclusif masqué et refusé par le serveur hors fenêtre (« closed »), en vente pendant Halloween ; Secret toujours en vente",
			not eggExVisible(nil) and not eggExVisible(openAt(T_NONE)) and eggExVisible(openAt(T_HALLO)) and okNo == false and whyNo == "closed" and okH == true
				and ShopA.canBuy({ season = { cur = 1 }, cap = 10, slots = {}, eggBag = {} }, full, "EggSecret", false) == true)
		local txH = ShopA.eggContentText(full, "EggExclusive", nil, openAt(T_HALLO))
		local txX = ShopA.eggContentText(full, "EggExclusive", nil, openAt(T_XMAS))
		check("Fiche de l'œuf Exclusif : « 1 espèce possible » à Halloween, « 2 espèces possibles » à Noël (saison 1)", txH:find("1 espèce possible", 1, true) ~= nil and txX:find("2 espèces possibles", 1, true) ~= nil)
		local evS = { k = "spring.2026", d = 0, q = 0, v = 0, l = 0, p = 300, x = 0 }
		local okS, whyS = Rewards.plumeBuyExclusive(full, evS, true, nil, openAt(T_SPRING))
		local evH = { k = "halloween.2026", d = 0, q = 0, v = 0, l = 0, p = 300, x = 0 }
		local okPH = Rewards.plumeBuyExclusive(full, evH, true, nil, openAt(T_HALLO))
		check("Plumes : œuf Exclusif refusé « closed » au printemps (aucune espèce Exclusif), plumes intactes ; accordé à Halloween", okS == false and whyS == "closed" and evS.p == 300 and okPH == true and evH.p == 150)
		-- 6. passe de combat : l'espèce de saison reste donnée par NOM au palier 30 (récompense directe, pas un tirage)
		local g = nil
		for _, x in ipairs(SA.rewardFor(1, 30, "premium") or {}) do
			if x.kind == "species" then
				g = x
			end
		end
		check("Passe de combat : palier 30 premium de la saison 1 = Corbeau couronné (récompense fixe, hors tirage)", g ~= nil and g.name == "Corbeau couronné")
	end)()
end
