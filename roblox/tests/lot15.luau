--!nocheck
-- Tests du lot 15 (PNJ, série de 7 jours, calendrier, quêtes, rotation, événements, plumes, sac d'œufs).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs } fournis par tests/run_lot15.py (ou, plus tard, par tests/run.luau).
-- Le Config utilisé est le VRAI Config.lua (Color3 simulé) dont le bloc « LOT 15 » porte les données (ex-Lot15Data.lua) ; la variante « full » publie les 10 raretés (espèces factices)
-- pour vérifier que toute rareté passe par Config.TIERS (par nom) et non par un indice codé en dur.
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2 (compatibilité lupa).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name })()
	end
	local Npc = load("roblox/src/ReplicatedStorage/Npc.lua", "Npc")
	local Rewards = load("roblox/src/ReplicatedStorage/Rewards.lua", "Rewards")
	local Calendar = load("roblox/src/ReplicatedStorage/Calendar.lua", "Calendar")

	local function loadConfig(full)
		local chunk = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), {
			debugName = "Config",
			environment = { Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end } },
		})
		local C = chunk() -- les données du lot 15 sont dans Config.lua (bloc « LOT 15 »)
		if full then
			for t = 1, #C.TIERS do
				if not C.tierLive(t) then
					C.PETS[#C.PETS + 1] = { tier = t, emoji = "?", name = "Factice" .. t, inc = 1 }
				end
			end
		end
		return C
	end
	local Config = loadConfig(false)
	local Full = loadConfig(true)
	local L15 = Config -- données du lot 15 (bloc « LOT 15 » de Config.lua ; ancien module Lot15Data fusionné)

	local function mkRng(seed)
		local x = (seed * 1103515245 + 12345) % 2147483647 -- brassage : des graines voisines (1, 2, 3) ne donnent pas des premiers tirages voisins
		if x <= 0 then
			x = x + 2147483646
		end
		local function step()
			x = (x * 48271) % 2147483647
			return x / 2147483647
		end
		step()
		step()
		step()
		return step
	end
	local function rint(rng, a, b)
		return a + math.floor(rng() * (b - a + 1))
	end
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
	local function copy(t)
		if type(t) ~= "table" then
			return t
		end
		local o = {}
		for k, v in pairs(t) do
			o[k] = copy(v)
		end
		return o
	end
	local function tidx(C, name)
		for i, t in ipairs(C.TIERS) do
			if t.name == name then
				return i
			end
		end
		return nil
	end
	local function eggCount(slots, cap, bag)
		local n = 0
		for i = 1, cap do
			if slots[i] then
				n = n + 1
			end
		end
		return n + #bag
	end
	local function petIdx(C, name)
		for i, p in ipairs(C.PETS) do
			if p.name == name then
				return i
			end
		end
		return nil
	end

	---------------------------------------------------------------- Données (Lot15Data)
	suite("Lot 15 : données (NPCS, NPC_ENCOUNTER, dialogues, série, rotation, événements)")
	local E = Config.NPC_ENCOUNTER
	check("NPC_ENCOUNTER : valeurs exactes de F.2", E.firstAfterMinutes == 8 and E.gapMinutes[1] == 6 and E.gapMinutes[2] == 10 and E.tradesPerDay == 4 and E.fightsPerDay == 4 and E.weeklyChampion == 1 and E.snoozeMinutes == 10 and E.offerSeconds == 60 and E.approachRange == 25)
	check("NPCS : pip, lina, bruno, kai, nora avec rôles et noms de F.1", Config.NPCS.pip.name == "Pip le Colporteur" and Config.NPCS.lina.role == "fight" and Config.NPCS.bruno.role == "fight" and Config.NPCS.kai.role == "champion" and Config.NPCS.nora.role == "trade" and Config.NPCS.nora.name == "Nora la Collectionneuse")
	check("NPCS : signatures Koala, Ours brun, Renard à neuf queues (espèces du lot 11, jamais utilisées pour l'équipe tant qu'absentes)", Config.NPCS.lina.signature == "Koala" and Config.NPCS.bruno.signature == "Ours brun" and Config.NPCS.kai.signature == "Renard à neuf queues" and petIdx(Config, "Koala") == nil)
	check("Dialogue Pip (approche) : texte exact de F.3", Npc.say(Config, "pip", "approach") == "Psst ! Hé, toi, le Chipeur ! J'ai un œuf qui n'attend que toi… On fait affaire ?")
	check("Dialogue Pip (offre 1) : variables remplacées", Npc.say(Config, "pip", "offer1", { rarity = "Rare", price = 176 }) == "Cet œuf Rare contre 🪙 176 : c'est 20 % de moins qu'à la boutique !")
	check("Dialogue Pip (offre 2, refus) exacts", Npc.say(Config, "pip", "offer2", { r = "Rare", r2 = "Épique" }) == "Tu as des doublons ? Donne-m'en 3 de rareté Rare et je te donne un œuf Épique. Promis, pas d'arnaque." and Npc.say(Config, "pip", "refuse") == "Tant pis ! Je repasse plus tard, garde tes pièces au chaud.")
	check("Dialogue Nora exact", Npc.say(Config, "nora", "offer", { species = "Lion", dupe = "Tigre", fee = 5200 }) == "Oh ! Il te manque le Lion dans ton bestiaire ? J'en ai un. Je te l'échange contre ton Tigre et 🪙 5200.")
	check("Dialogues Lina (défi, victoire, défaite), Kaï, Bruno (départ) exacts", Npc.say(Config, "lina", "approach") == "Ton équipe a l'air prometteuse… Un petit combat ? Je ne mords pas. Mon Koala, si."
		and Npc.say(Config, "lina", "win") == "Bien joué ! Choisis ta récompense, tu l'as méritée."
		and Npc.say(Config, "lina", "lose", { tip = "la Glace craint la Foudre." }) == "Pas cette fois ! Entraîne-toi à la tour et reviens me voir. Astuce : la Glace craint la Foudre."
		and Npc.say(Config, "kai", "approach") == "On m'a parlé de toi. Montre-moi ta meilleure équipe : si tu gagnes, la récompense est à la hauteur."
		and Npc.say(Config, "bruno", "gone") == "Bon, je vois que t'es occupé. À demain !")
	check("Dialogue : variable inconnue conservée, PNJ ou clé inconnus = chaîne vide", Npc.say(Config, "pip", "offer1", {}) == "Cet œuf {rarity} contre 🪙 {price} : c'est 20 % de moins qu'à la boutique !" and Npc.say(Config, "zzz", "approach") == "" and Npc.say(Config, "pip", "zzz") == "")
	-- Aucun texte ni champ de PNJ ne parle de Robux
	local robuxFree = true
	local function scan(t)
		for k, v in pairs(t) do
			if type(k) == "string" and (string.find(string.lower(k), "robux") or string.find(string.lower(k), "product")) then
				robuxFree = false
			end
			if type(v) == "string" and (string.find(v, "Robux") or string.find(v, "R%$")) then
				robuxFree = false
			end
			if type(v) == "table" then
				scan(v)
			end
		end
	end
	scan(L15.NPCS)
	scan(L15.DIALOGUES)
	scan(L15.NPC_RULES)
	scan(L15.NPC_ENCOUNTER)
	check("Aucun PNJ (données, dialogues, règles) ne mentionne Robux, produit ou achat", robuxFree)
	-- Toutes les raretés des données sont des NOMS présents dans Config.TIERS
	local names = {}
	for _, n in ipairs(L15.FORBIDDEN_GIFT_TIERS) do
		names[#names + 1] = n
	end
	for _, d in ipairs(L15.STREAK.days) do
		for _, n in ipairs(d.eggs or {}) do
			names[#names + 1] = n
		end
		for _, n in ipairs(d.eggsMonth or {}) do
			names[#names + 1] = n
		end
	end
	for _, k in ipairs({ "buyMaxTier", "dupesMaxTier", "speciesMaxTier", "giveMaxTier", "confirm2FromTier", "revealQuietTier", "fightEggCap", "champEgg" }) do
		names[#names + 1] = L15.NPC_RULES[k]
	end
	names[#names + 1] = L15.QUESTS.bonus.egg
	names[#names + 1] = L15.QUESTS.bonus.eggLate
	for _, o in ipairs(L15.QUESTS.bonus.options) do
		if o.minTier then
			names[#names + 1] = o.minTier
		end
	end
	for _, r in ipairs(L15.QUESTS.weekly.rewards) do
		names[#names + 1] = r.egg
	end
	names[#names + 1] = L15.PLUMES.exclusiveName
	local allNamed = true
	for _, n in ipairs(names) do
		if tidx(Config, n) == nil then
			allNamed = false
		end
	end
	check("Toutes les raretés de Lot15Data sont des noms résolus par Config.TIERS", allNamed and #names > 20)
	check("Tailles et mutations de F.4 résolues par nom (Géant, Arc-en-ciel, Normal)", (function()
		local function has(list, name)
			for _, e in ipairs(list) do
				if e.name == name then
					return true
				end
			end
			return false
		end
		return has(Config.SIZES, L15.NPC_RULES.forbidSizeFrom) and has(Config.MUTS, L15.NPC_RULES.forbidMutFrom) and has(Config.SIZES, L15.NPC_RULES.speciesSize)
	end)())
	local forbiddenIdx = {}
	for _, n in ipairs(L15.FORBIDDEN_GIFT_TIERS) do
		forbiddenIdx[tidx(Config, n)] = true
	end
	check("Interdits = Secret, Exclusif, Divin (indices 8, 9, 10 via TIERS)", forbiddenIdx[8] and forbiddenIdx[9] and forbiddenIdx[10] and not forbiddenIdx[7] and not forbiddenIdx[6])
	-- Série : 7 jours, aucun œuf interdit
	check("Série de 7 jours : 7 entrées", #L15.STREAK.days == 7 and L15.STREAK.mythicEveryWeeks == 4)
	-- Rotation
	check("Rotation : 9 semaines, 9 types distincts du jeu, espèces vedettes existantes, 2 cosmétiques par semaine", (function()
		local types = { Feu = true, Eau = true, Plante = true, Glace = true, Foudre = true, Terre = true, Ciel = true, Ombre = true, ["Lumière"] = true }
		local seen = {}
		if #L15.WEEKLY_ROTATION ~= 9 then
			return false
		end
		for _, r in ipairs(L15.WEEKLY_ROTATION) do
			if not types[r.type] or seen[r.type] or petIdx(Config, r.featured) == nil or #r.shop ~= 2 then
				return false
			end
			seen[r.type] = true
		end
		return true
	end)())
	-- Calendrier d'événements
	check("EVENTS_CAL : chaque événement dure 10 jours (inclus), pas deux le même mois", (function()
		local months = {}
		for _, e in ipairs(L15.EVENTS_CAL) do
			local fm, fd = string.match(e.from, "^(%d+)%-(%d+)$")
			local tm, td = string.match(e.to, "^(%d+)%-(%d+)$")
			if not fm or Rewards.daysFromCivil(2026, tonumber(tm), tonumber(td)) - Rewards.daysFromCivil(2026, tonumber(fm), tonumber(fd)) ~= 9 or months[fm] then
				return false
			end
			months[fm] = true
		end
		return #L15.EVENTS_CAL >= 4
	end)())
	check("Plumes : valeurs de G.5 (10 par quête, 2 par victoire plafond 20, 5 de connexion, Exclusif 150)", L15.PLUMES.perQuest == 10 and L15.PLUMES.perPveWin == 2 and L15.PLUMES.pveCapDay == 20 and L15.PLUMES.login == 5 and L15.PLUMES.exclusiveCost == 150)

	---------------------------------------------------------------- Temps UTC
	suite("Lot 15 : jour de la semaine, semaine, date civile (UTC)")
	check("Jour 0 = jeudi 1970-01-01 ; jour 4 = lundi ; jour 2 = samedi", Rewards.dow(0) == 4 and Rewards.dow(4) == 1 and Rewards.dow(2) == 6 and Npc.dow(4) == 1)
	check("Semaines commençant le lundi : dimanche (jour 3) = semaine 0, lundi (jour 4) = semaine 1", Rewards.weekOf(3) == 0 and Rewards.weekOf(4) == 1 and Rewards.weekOf(10) == 1 and Rewards.weekOf(11) == 2 and Npc.weekOf(11) == 2)
	check("2026-11-26 est un jeudi", Rewards.dow(Rewards.daysFromCivil(2026, 11, 26)) == 4)
	check("daysFromCivil / civil : aller-retour sur 60 000 jours dont années bissextiles", (function()
		for d = 0, 60000, 7 do
			local y, m, dd = Rewards.civil(d)
			if Rewards.daysFromCivil(y, m, dd) ~= d then
				return false
			end
		end
		local y, m, dd = Rewards.civil(Rewards.daysFromCivil(2024, 2, 29))
		local y2, m2, d2 = Rewards.civil(Rewards.daysFromCivil(2024, 2, 29) + 1)
		return y == 2024 and m == 2 and dd == 29 and y2 == 2024 and m2 == 3 and d2 == 1
	end)())

	---------------------------------------------------------------- PNJ : conditions de rencontre
	suite("Lot 15 : PNJ, conditions de rencontre (F.2), quotas, reconnexion")
	local DAY = 20000 -- un mercredi (le lendemain n'est pas un lundi)
	while Npc.dow(DAY) ~= 3 do
		DAY = DAY + 1
	end
	local T0 = DAY * 86400 + 3600 * 10 -- 10 h UTC
	local TYPES = { "Feu", "Eau", "Plante", "Glace", "Foudre", "Terre", "Ciel", "Ombre", "Lumière" }
	local function typeOf(p)
		return TYPES[(p % 9) + 1]
	end
	local function emptyInv(coins)
		return { coins = coins or 100000, pets = {}, seen = {}, typeOf = typeOf, avgLevel = 7, teamTiers = { 3, 3, 4 } }
	end
	local function okCtx(now)
		return { sessionStart = now - 9999 }
	end
	local npc0 = Npc.newState()
	local book0 = Npc.newBook()
	local rng0 = mkRng(11)
	-- Avant 8 minutes
	local o, why = Npc.encounter(Config, npc0, book0, 42, T0, DAY, { sessionStart = T0 - 479 }, emptyInv(), rng0)
	check("Aucune rencontre avant 8 min de jeu (479 s : refusé « early »)", o == nil and why == "early")
	check("Un refus ne consomme rien : compteurs, nextAt et carnet inchangés", npc0.trades == 0 and npc0.fights == 0 and npc0.enc == 0 and npc0.nextAt == 0 and next(book0.offers) == nil)
	o, why = Npc.encounter(Config, npc0, book0, 42, T0, DAY, { sessionStart = T0 - 480 }, emptyInv(), rng0)
	check("À 8 min pile : rencontre possible", o ~= nil and why == nil)
	-- États interdits
	local states = { { "carrying", "carrying" }, { "chased", "chased" }, { "inDuel", "duel" }, { "inCastle", "castle" }, { "inCinematic", "cine" }, { "flying", "flying" }, { "inTerritory", "territory" }, { "pending", "pending" } }
	for _, st in ipairs(states) do
		local n, b = Npc.newState(), Npc.newBook()
		local ctx = okCtx(T0)
		ctx[st[1]] = true
		local oo, ww = Npc.encounter(Config, n, b, 42, T0, DAY, ctx, emptyInv(), mkRng(5))
		check("Aucune rencontre pendant l'état « " .. st[1] .. " » (code " .. st[2] .. ")", oo == nil and ww == st[2] and n.enc == 0 and next(b.offers) == nil)
	end
	do
		local n, b = Npc.newState(), Npc.newBook()
		n.off = true
		local oo, ww = Npc.encounter(Config, n, b, 42, T0, DAY, okCtx(T0), emptyInv(), mkRng(5))
		check("npc.off (« Ne plus être interpellé ») : jamais de rencontre", oo == nil and ww == "off")
		local ctx = okCtx(T0)
		ctx.lastRevealAt, ctx.lastRevealTier = T0 - 30, tidx(Config, "Légendaire")
		n.off = false
		oo, ww = Npc.encounter(Config, n, b, 42, T0, DAY, ctx, emptyInv(), mkRng(5))
		check("60 s après une révélation de rareté >= 5 : refusé (30 s)", oo == nil and ww == "reveal")
		ctx.lastRevealAt = T0 - 60
		oo, ww = Npc.encounter(Config, Npc.newState(), Npc.newBook(), 42, T0, DAY, ctx, emptyInv(), mkRng(5))
		check("Révélation vieille de 60 s : plus de blocage", oo ~= nil)
		ctx.lastRevealAt, ctx.lastRevealTier = T0 - 10, tidx(Config, "Épique")
		oo, ww = Npc.encounter(Config, Npc.newState(), Npc.newBook(), 42, T0, DAY, ctx, emptyInv(), mkRng(5))
		check("Révélation Épique (rareté 4) récente : pas de blocage", oo ~= nil)
	end
	-- Quotas et alternance sur un jour
	do
		local n, b = Npc.newState(), Npc.newBook()
		local rng = mkRng(99)
		local now = T0
		local kinds = {}
		local lastWhy
		for i = 1, 12 do
			local oo, ww = Npc.encounter(Config, n, b, 42, now, DAY, okCtx(now), emptyInv(), rng)
			if oo then
				kinds[#kinds + 1] = oo.kind
				Npc.decline(Config, n, b, oo.id, 42, now) -- (les refus de suite ne comptent pas pour le quota)
				n.gone = {}
				n.refuse = {}
				n.nextAt = 0
			else
				lastWhy = ww
			end
			now = now + 700
		end
		check("Quotas : 4 échanges et 4 combats par jour (8 rencontres), puis plus de PNJ (« quota »)", #kinds == 8 and n.trades == 4 and n.fights == 4 and lastWhy == "quota")
		check("Alternance : rencontre n impaire = combat, paire = échange", kinds[1] == "fight" and kinds[2] == "trade" and kinds[3] == "fight" and kinds[4] == "trade" and kinds[7] == "fight" and kinds[8] == "trade")
		-- Reconnexion / changement de serveur : état copié (JSON simulé), nouveau carnet, nouvelle session
		local saved = Npc.sanitize(copy(n))
		local b2 = Npc.newBook()
		local oo, ww = Npc.encounter(Config, saved, b2, 42, now, DAY, { sessionStart = now }, emptyInv(), rng)
		check("Reconnexion ou autre serveur le même jour : quotas conservés, aucune nouvelle rencontre", oo == nil and (ww == "early" or ww == "quota"))
		oo, ww = Npc.encounter(Config, saved, b2, 42, now, DAY, okCtx(now), emptyInv(), rng)
		check("Session ancienne mais quotas atteints : « quota », même sur un autre serveur", oo == nil and ww == "quota")
		oo, ww = Npc.encounter(Config, saved, b2, 42, now + 86400, DAY + 1, okCtx(now + 86400), emptyInv(), rng)
		check("Le lendemain : compteurs remis à zéro, la rencontre reprend", oo ~= nil and saved.trades + saved.fights == 1)
	end
	do
		-- nextAt absolu : se reconnecter ne relance pas une rencontre
		local n, b = Npc.newState(), Npc.newBook()
		local oo = Npc.encounter(Config, n, b, 42, T0, DAY, okCtx(T0), emptyInv(), mkRng(3))
		check("Rencontre faite : nextAt absolu dans 6 à 10 min", oo ~= nil and n.nextAt >= T0 + 360 and n.nextAt <= T0 + 600)
		local copyN = Npc.sanitize(copy(n))
		local oo2, why2 = Npc.encounter(Config, copyN, Npc.newBook(), 42, T0 + 120, DAY, okCtx(T0 + 120), emptyInv(), mkRng(4))
		check("Changement de serveur 2 min plus tard (session ancienne) : « wait », pas de nouvelle rencontre", oo2 == nil and why2 == "wait")
		oo2 = Npc.encounter(Config, copyN, Npc.newBook(), 42, T0 + 601, DAY, okCtx(T0 + 601), emptyInv(), mkRng(4))
		check("Après nextAt : rencontre possible", oo2 ~= nil)
		-- « Pas maintenant » : 10 min
		local n2, b2 = Npc.newState(), Npc.newBook()
		local o3 = Npc.encounter(Config, n2, b2, 42, T0, DAY, okCtx(T0), emptyInv(), mkRng(3))
		n2.nextAt = 0
		local okd = Npc.decline(Config, n2, b2, o3.id, 42, T0 + 5)
		check("« Pas maintenant » : pas d'autre PNJ pendant 10 min", okd and n2.nextAt == T0 + 5 + 600 and select(2, Npc.encounter(Config, n2, b2, 42, T0 + 604, DAY, okCtx(T0 + 604), emptyInv(), mkRng(3))) == "wait" and Npc.encounter(Config, n2, b2, 42, T0 + 606, DAY, okCtx(T0 + 606), emptyInv(), mkRng(3)) ~= nil)
		check("Refus d'une offre déjà refusée ou inconnue", select(2, Npc.decline(Config, n2, b2, o3.id, 42, T0 + 6)) == "used" and select(2, Npc.decline(Config, n2, b2, "nimporte", 42, T0 + 6)) == "unknown")
	end
	do
		-- Sanitize d'un npc corrompu
		local s = Npc.sanitize({ day = "x", trades = 1e9, fights = -5, enc = 0 / 0, nextAt = math.huge, off = "oui", refuse = { bruno = 500, [1] = 2 }, gone = { lina = true, x = 3 } })
		check("Npc.sanitize : valeurs bornées, formes inconnues = neuf", s.day == 0 and s.trades == 99 and s.fights == 0 and s.enc == 0 and s.nextAt == 0 and s.off == false and s.refuse.bruno == 99 and s.refuse[1] == nil and s.gone.lina == true and s.gone.x == nil and deepEq(Npc.sanitize("zzz"), Npc.newState()))
	end
	do
		-- Bruno : 3 refus de suite = parti pour la journée
		local C2 = loadConfig(false)
		C2.NPCS.lina = nil
		local n, b = Npc.newState(), Npc.newBook()
		local rng = mkRng(21)
		local now = T0
		local fightsSeen, goneAt = 0, nil
		for i = 1, 8 do
			local oo = Npc.encounter(C2, n, b, 42, now, DAY, okCtx(now), emptyInv(), rng)
			if oo then
				if oo.kind == "fight" then
					fightsSeen = fightsSeen + 1
					check("Seul Bruno combat quand Lina n'existe pas", oo.npc == "bruno")
				end
				local ok2, res = Npc.decline(C2, n, b, oo.id, 42, now)
				if oo.npc == "bruno" and res.gone then
					goneAt = fightsSeen
				end
				n.refuse.pip = 0
			end
			now = now + 700
		end
		check("Bruno refusé 3 fois de suite : ne revient plus ce jour-là", goneAt == 3 and n.gone.bruno == true)
		local oo = Npc.encounter(C2, n, b, 42, now + 5000, DAY, okCtx(now + 5000), emptyInv(), rng)
		check("Après son départ, plus de combat ce jour-là (échange ou rien)", oo == nil or oo.kind == "trade")
		local fresh = Npc.sanitize(copy(n))
		local oo3 = Npc.encounter(C2, fresh, Npc.newBook(), 42, (DAY + 1) * 86400 + 40000, DAY + 1, okCtx((DAY + 1) * 86400 + 40000), emptyInv(), rng)
		check("Le lendemain Bruno revient (gone remis à zéro)", fresh.gone.bruno == nil and oo3 ~= nil)
	end
	do
		-- Champion errant : lundi, 1 fois par semaine, hors quota
		local MON = 20000
		while Npc.dow(MON) ~= 1 do
			MON = MON + 1
		end
		local n, b = Npc.newState(), Npc.newBook()
		local now = MON * 86400 + 40000
		local oo = Npc.encounter(Config, n, b, 42, now, MON, okCtx(now), emptyInv(), mkRng(8))
		check("Lundi : Maître Kaï (Champion errant), puissance x1,3, carte à 100 %, Œuf Mythique garanti", oo ~= nil and oo.npc == "kai" and oo.kind == "champion" and oo.cardPct == 100 and oo.powerMul >= 0.9 * 1.3 - 1e-9 and oo.powerMul <= 1.1 * 1.3 + 1e-9 and oo.guaranteedEgg == tidx(Config, "Mythique"))
		check("Kaï ne compte ni dans le quota de combats ni dans l'alternance ; semaine enregistrée", n.fights == 0 and n.enc == 0 and n.champ == Npc.weekOf(MON))
		local oo2 = Npc.encounter(Config, n, b, 42, now + 700, MON, okCtx(now + 700), emptyInv(), mkRng(8))
		check("Une seule fois par semaine : la rencontre suivante n'est pas Kaï", oo2 ~= nil and oo2.npc ~= "kai")
		local oo3 = Npc.encounter(Config, n, Npc.newBook(), 42, (MON + 7) * 86400 + 40000, MON + 7, okCtx((MON + 7) * 86400 + 40000), emptyInv(), mkRng(8))
		check("Lundi suivant : Kaï revient", oo3 ~= nil and oo3.npc == "kai")
		local n3, b3 = Npc.newState(), Npc.newBook()
		local oo4 = Npc.encounter(Config, n3, b3, 42, (MON + 1) * 86400 + 40000, MON + 1, okCtx((MON + 1) * 86400 + 40000), emptyInv(), mkRng(8))
		check("Mardi : pas de Kaï", oo4 ~= nil and oo4.npc ~= "kai")
	end

	---------------------------------------------------------------- PNJ : offres, valeurs, accept / expiration / rejeu
	suite("Lot 15 : PNJ, valeurs d'échange exactes, offres uniques, expiration, rejeu, propriétaire")
	check("Premisse : prix des œufs 45 / 99 / 220 / 26 000 / 7 500 000 pour r1..r5", Config.EGG_PRICE[1] == 45 and Config.EGG_PRICE[2] == 99 and Config.EGG_PRICE[3] == 220 and Config.EGG_PRICE[4] == 26000 and Config.EGG_PRICE[5] == 7500000)
	check("Œuf contre pièces = prix x 0,8 : 36 / 79 / 176 / 20 800 / 6 000 000", Npc.buyPrice(Config, 1) == 36 and Npc.buyPrice(Config, 2) == 79 and Npc.buyPrice(Config, 3) == 176 and Npc.buyPrice(Config, 4) == 20800 and Npc.buyPrice(Config, 5) == 6000000)
	check("Espèce manquante : complément = prix x 0,2 : 9 / 19 / 44 / 5 200 / 1 500 000", Npc.speciesFee(Config, 1) == 9 and Npc.speciesFee(Config, 2) == 19 and Npc.speciesFee(Config, 3) == 44 and Npc.speciesFee(Config, 4) == 5200 and Npc.speciesFee(Config, 5) == 1500000)
	local PANDA, CHAT, LION = petIdx(Config, "Panda"), petIdx(Config, "Chat"), petIdx(Config, "Lion")
	local function invWith(list, seen, coins)
		local inv = emptyInv(coins)
		for i, e in ipairs(list) do
			inv.pets[#inv.pets + 1] = { slot = i, p = e.p, s = e.s or 2, m = e.m or 1, follower = e.follower, team = e.team, defense = e.defense }
		end
		for p in pairs(seen or {}) do
			inv.seen[p] = true
		end
		for _, pet in ipairs(inv.pets) do
			inv.seen[pet.p] = true
		end
		return inv
	end
	-- Pip, œuf contre pièces : toujours possible
	local function findOffer(sub, inv, seedFrom, who)
		for seed = seedFrom or 1, (seedFrom or 1) + 400 do
			local n = Npc.newState()
			n.day, n.enc = DAY, 1 -- prochaine rencontre = échange (le jour est fixé : sinon rollDay remet enc à 0)
			local b = Npc.newBook()
			local oo = Npc.encounter(Config, n, b, 42, T0, DAY, okCtx(T0), inv, mkRng(seed))
			if oo and oo.sub == sub and (not who or oo.npc == who) then
				return oo, n, b
			end
		end
		return nil
	end
	do
		local inv = invWith({}, {}, 10000)
		local oo, n, b = findOffer("buy", inv)
		check("Pip : offre d'achat d'œuf (identifiant, 60 s, userId, aucun pet demandé)", oo ~= nil and oo.npc == "pip" and oo.userId == 42 and oo.expires == oo.created + 60 and #oo.take == 0 and #Npc.violations(Config, oo, inv, 42) == 0)
		local okA, eff = Npc.accept(Config, b, oo.id, 42, T0 + 59, inv)
		check("Accepté à 59 s : effet = -prix en pièces + 1 œuf de la rareté annoncée, quête npcTrade", okA and eff.coins == -oo.price and eff.egg == oo.getEgg and #eff.take == 0 and eff.quest == "npcTrade")
		check("Rejeu du même identifiant refusé (« used »), rien n'est donné deux fois", select(2, Npc.accept(Config, b, oo.id, 42, T0 + 60, inv)) == "used")
		local oo2, _, b2 = findOffer("buy", inv, 7)
		check("Autre joueur (userId différent) : refusé « owner »", select(2, Npc.accept(Config, b2, oo2.id, 43, T0 + 1, inv)) == "owner")
		check("Offre expirée à 60 s pile : refusée « expired » puis effacée", select(2, Npc.accept(Config, b2, oo2.id, 42, T0 + 60, inv)) == "expired" and select(2, Npc.accept(Config, b2, oo2.id, 42, T0 + 61, inv)) == "unknown")
		local oo3, _, b3 = findOffer("buy", inv, 13)
		local poor = invWith({}, {}, oo3.price - 1)
		check("Pièces insuffisantes : refusé « coins » et l'offre reste ouverte", select(2, Npc.accept(Config, b3, oo3.id, 42, T0 + 5, poor)) == "coins" and b3.offers[oo3.id] ~= nil)
		check("Identifiant inconnu, nil ou mauvais type : refusé sans erreur", select(2, Npc.accept(Config, b3, "x-1-0", 42, T0, inv)) == "unknown" and select(2, Npc.accept(Config, b3, nil, 42, T0, inv)) == "unknown" and select(2, Npc.accept(Config, b3, 12, 42, T0, inv)) == "unknown")
		local oa = findOffer("buy", inv, 21)
		local ob = findOffer("buy", inv, 22)
		check("Identifiants uniques entre offres", oa ~= nil and ob ~= nil and oa.id ~= ob.id)
		local n4, b4 = Npc.newState(), Npc.newBook()
		n4.day, n4.enc = DAY, 1
		local oo4 = Npc.encounter(Config, n4, b4, 42, T0, DAY, okCtx(T0), inv, mkRng(31))
		check("Sweep : une offre expirée est retirée du carnet sans pénalité", Npc.sweep(b4, T0 + 59) == 0 and Npc.sweep(b4, T0 + 60) == 1 and next(b4.offers) == nil and b4.current == nil and n4.refuse.pip == nil and oo4 ~= nil)
	end
	-- Pip, doublons : 3 Épiques (Panda) contre 1 Légendaire, confirmation 2
	do
		local list = {}
		for _ = 1, 4 do
			list[#list + 1] = { p = PANDA }
		end
		local inv = invWith(list, {}, 10)
		local oo, _, b = findOffer("dupes", inv)
		check("Pip, doublons : 3 pets de rareté r contre 1 œuf r+1 (Épique -> Légendaire), au moins 1 exemplaire gardé", oo ~= nil and #oo.take == 3 and oo.dupeTier == 4 and oo.getEgg == 5 and oo.price == 0 and #Npc.violations(Config, oo, inv, 42) == 0)
		check("Donner un pet de rareté >= 4 exige une 2e confirmation", Npc.needsConfirm2(Config, oo) and select(2, Npc.accept(Config, b, oo.id, 42, T0 + 1, inv)) == "confirm2" and b.offers[oo.id] ~= nil)
		local okA, eff = Npc.accept(Config, b, oo.id, 42, T0 + 2, inv, { confirm2 = true })
		check("Avec la 2e confirmation : 3 emplacements pris, 1 œuf Légendaire", okA and #eff.take == 3 and eff.egg == 5 and eff.coins == 0)
		local oo2, _, b2 = findOffer("dupes", inv, 40)
		local reduced = invWith({ { p = PANDA }, { p = PANDA } }, {}, 10) -- il ne reste plus que 2 exemplaires : plus assez de doublons
		check("Inventaire modifié après l'offre : refusé « changed »", select(2, Npc.accept(Config, b2, oo2.id, 42, T0 + 1, reduced, { confirm2 = true })) == "changed")
		local oo3, _, b3 = findOffer("dupes", inv, 90)
		local three = invWith({ { p = PANDA }, { p = PANDA }, { p = PANDA } }, {}, 10) -- les 3 emplacements existent encore, mais ce seraient les derniers exemplaires
		check("Au moment d'accepter, donner le dernier exemplaire d'une espèce est refusé (« changed »)", select(2, Npc.accept(Config, b3, oo3.id, 42, T0 + 1, three, { confirm2 = true })) == "changed")
		local view = Npc.view(Config, oo, { value = function() return 123 end, label = function(v) return "1 sur " .. v end })
		check("Vue de confirmation : 3 pets donnés avec « 1 sur N », 1 œuf reçu avec valeur de revente", #view.give == 3 and view.give[1].odds == "1 sur 123" and #view.get == 1 and view.get[1].kind == "egg" and view.get[1].sell == Config.eggSellValue(5) and view.confirm2 == true)
	end
	-- Nora : espèce manquante contre un doublon
	do
		local list = { { p = LION }, { p = LION }, { p = petIdx(Config, "Tigre") } }
		local inv = invWith(list, {}, 10000000)
		local oo, _, b = findOffer("species", inv, 1, "nora")
		check("Nora : espèce manquante de rareté <= 5 contre 1 doublon de même rareté + 20 % du prix", oo ~= nil and #oo.take == 1 and Config.PETS[oo.take[1].p].tier == Config.PETS[oo.getSpecies.p].tier and oo.price == Npc.speciesFee(Config, Config.PETS[oo.getSpecies.p].tier) and #Npc.violations(Config, oo, inv, 42) == 0)
		check("Nora ne propose jamais une espèce déjà vue, ni de taille ou mutation exceptionnelle", inv.seen[oo.getSpecies.p] == nil and oo.getSpecies.s == 2 and oo.getSpecies.m == 1)
		local okA, eff = Npc.accept(Config, b, oo.id, 42, T0 + 3, inv, { confirm2 = true })
		check("Nora accepté : -complément, 1 emplacement donné, espèce reçue", okA and eff.coins == -oo.price and #eff.take == 1 and eff.species.p == oo.getSpecies.p and eff.egg == nil)
	end
	-- Pets protégés (F.4 point 3) : un inventaire où rien n'est donnable ne produit aucune demande de pet
	do
		local lock = {}
		for _ = 1, 4 do
			lock[#lock + 1] = { p = PANDA, follower = true }
		end
		for _ = 1, 4 do
			lock[#lock + 1] = { p = petIdx(Config, "Hibou"), team = true }
		end
		for _ = 1, 4 do
			lock[#lock + 1] = { p = petIdx(Config, "Manchot"), defense = true }
		end
		for _ = 1, 3 do
			lock[#lock + 1] = { p = CHAT, m = 4 } -- Arc-en-ciel
		end
		for _ = 1, 3 do
			lock[#lock + 1] = { p = petIdx(Config, "Chien"), s = 4 } -- Géant
		end
		for _ = 1, 3 do
			lock[#lock + 1] = { p = petIdx(Config, "Dragon") } -- rareté 6
		end
		lock[#lock + 1] = { p = petIdx(Config, "Lapin") } -- dernier exemplaire
		local inv = invWith(lock, {}, 10000)
		local bad = false
		for seed = 1, 200 do
			local n = Npc.newState()
			n.day, n.enc = DAY, seed % 2
			local oo = Npc.encounter(Config, n, Npc.newBook(), 42, T0, DAY, okCtx(T0), inv, mkRng(seed))
			if oo and oo.kind == "trade" and (#oo.take > 0 or oo.sub ~= "buy") then
				bad = true
			end
		end
		check("Équipés, équipe, défense, Arc-en-ciel+, Géant+, rareté >= 6 et dernier exemplaire : jamais demandés (seul l'achat d'œuf reste)", not bad)
		local forged = { id = "x", userId = 42, created = 0, expires = 60, kind = "trade", sub = "dupes", dupeTier = 4, price = 0, getEgg = 5, take = { { slot = 1, p = PANDA, s = 2, m = 1 }, { slot = 2, p = PANDA, s = 2, m = 1 }, { slot = 3, p = PANDA, s = 2, m = 1 } } }
		check("Le contrôleur de violations détecte un pet équipé demandé", #Npc.violations(Config, forged, inv, 42) > 0)
		local inv2 = invWith({ { p = petIdx(Config, "Dragon") }, { p = petIdx(Config, "Dragon") }, { p = petIdx(Config, "Dragon") } }, {}, 10)
		forged.take = { { slot = 1, p = petIdx(Config, "Dragon"), s = 2, m = 1 }, { slot = 2, p = petIdx(Config, "Dragon"), s = 2, m = 1 }, { slot = 3, p = petIdx(Config, "Dragon"), s = 2, m = 1 } }
		check("Le contrôleur détecte une rareté >= 6 et le dernier exemplaire demandés", #Npc.violations(Config, forged, inv2, 42) >= 2)
		local forged2 = { id = "y", userId = 42, created = 0, expires = 60, kind = "trade", sub = "buy", price = 5, getEgg = 1, take = {}, robuxPrice = 5 }
		check("Le contrôleur détecte un champ Robux et un mauvais prix", #Npc.violations(Config, forged2, inv2, 42) >= 2)
		check("Le contrôleur détecte une offre liée à un autre userId et une durée anormale", #Npc.violations(Config, { id = "z", userId = 7, created = 0, expires = 600, kind = "trade", sub = "buy", price = 36, getEgg = 1, take = {} }, inv2, 42) == 2)
		local giftS = { id = "g", userId = 42, created = 0, expires = 60, kind = "trade", sub = "buy", price = Config.EGG_PRICE[8] * 8 / 10, getEgg = 8, take = {} }
		check("Le contrôleur détecte un œuf Secret offert (rareté interdite)", #Npc.violations(Config, giftS, inv2, 42) >= 1)
	end

	---------------------------------------------------------------- PNJ : combats
	suite("Lot 15 : PNJ, combats (équipes, résultat unique, défaite sans perte)")
	do
		local inv = invWith({}, {}, 100)
		local n, b = Npc.newState(), Npc.newBook()
		local oo = Npc.encounter(Config, n, b, 42, T0, DAY, okCtx(T0), inv, mkRng(17)) -- 1re rencontre = combat
		check("1re rencontre du jour = combat : équipe de 3 espèces existantes, niveau = moyenne du joueur, puissance x U(0,9 ; 1,1)", oo.kind == "fight" and #oo.team == 3 and oo.team[1].lvl == 7 and oo.powerMul >= 0.9 and oo.powerMul <= 1.1 and oo.cardPct == 60 and math.abs(oo.rewardMul - 0.6) < 1e-9)
		local eligible = true
		for _, m in ipairs(oo.team) do
			if Config.PETS[m.p] == nil or Config.PETS[m.p].tier > 4 then
				eligible = false
			end
		end
		check("Équipe PNJ : seulement des espèces de Config.PETS, pas plus rare que l'équipe du joueur", eligible)
		check("Œuf de victoire : rareté moyenne de l'équipe du joueur plafonnée à Légendaire", oo.cardEgg == 3 or oo.cardEgg == 4)
		check("Résultat avant acceptation : refusé « state »", select(2, Npc.resolve(Config, b, oo.id, 42, T0 + 5, true)) == "state")
		local okA, acc = Npc.accept(Config, b, oo.id, 42, T0 + 5, inv)
		check("Accepter un combat ne donne rien (le résultat sera déclaré par le serveur)", okA and acc.state == "accepted")
		check("Mauvais joueur : le résultat est refusé", select(2, Npc.resolve(Config, b, oo.id, 43, T0 + 20, true)) == "owner")
		local okR, res = Npc.resolve(Config, b, oo.id, 42, T0 + 30, false)
		check("Défaite : rien n'est perdu, +5 XP, aucune carte", okR and res.won == false and res.xp == 5 and res.cardPct == nil and res.egg == nil)
		check("Résultat déclaré une seule fois (rejeu refusé)", select(2, Npc.resolve(Config, b, oo.id, 42, T0 + 31, true)) == "used")
		local n2, b2 = Npc.newState(), Npc.newBook()
		local o2 = Npc.encounter(Config, n2, b2, 42, T0, DAY, okCtx(T0), inv, mkRng(18))
		Npc.accept(Config, b2, o2.id, 42, T0 + 1, inv)
		local okW, win = Npc.resolve(Config, b2, o2.id, 42, T0 + 40, true)
		check("Victoire : cartes à 60 %, valeurs x0,6, œuf de carte plafonné", okW and win.won and win.cardPct == 60 and math.abs(win.rewardMul - 0.6) < 1e-9 and win.cardEgg == o2.cardEgg and win.xp == 0)
		local o3 = Npc.encounter(Config, Npc.newState(), b2, 42, T0 + 5000, DAY, okCtx(T0 + 5000), inv, mkRng(19))
		Npc.accept(Config, b2, o3.id, 42, T0 + 5001, inv)
		check("Résultat trop tardif (15 min) : refusé « expired »", select(2, Npc.resolve(Config, b2, o3.id, 42, T0 + 5001 + 900, true)) == "expired")
		check("Astuce de défaite : type adverse craint le type qui le bat", Npc.tip(Config, { npc = "lina" }) == "le type Plante craint le type Feu." and Npc.tip(Config, { npc = "pip" }, {}) == "observe bien les types de l'équipe adverse.")
		-- Champion : œuf garanti
		local MON = 20000
		while Npc.dow(MON) ~= 1 do
			MON = MON + 1
		end
		local nk, bk = Npc.newState(), Npc.newBook()
		local ok1 = Npc.encounter(Config, nk, bk, 42, MON * 86400 + 40000, MON, okCtx(MON * 86400 + 40000), inv, mkRng(2))
		Npc.accept(Config, bk, ok1.id, 42, MON * 86400 + 40001, inv)
		local okK, wk = Npc.resolve(Config, bk, ok1.id, 42, MON * 86400 + 40100, true)
		check("Victoire contre Kaï : Œuf Mythique garanti + carte au choix à 100 %", okK and wk.champion and wk.egg == tidx(Config, "Mythique") and wk.cardPct == 100 and wk.rewardMul == 1)
	end

	---------------------------------------------------------------- 10 000 offres
	suite("Lot 15 : 10 000 offres de PNJ générées sans violation de F.4")
	do
		local rng = mkRng(2026)
		local nP, nS, nM = #Config.PETS, #Config.SIZES, #Config.MUTS
		local counts = { buy = 0, dupes = 0, species = 0, fight = 0, champion = 0, none = 0 }
		local violations, firstBad = 0, nil
		for i = 1, 10000 do
			local pool = {}
			for k = 1, rint(rng, 1, 6) do
				pool[k] = rint(rng, 1, nP)
			end
			local inv = { coins = math.floor(10 ^ (rng() * 9)), pets = {}, seen = {}, typeOf = typeOf, avgLevel = rint(rng, 1, 30), teamTiers = { rint(rng, 1, 7), rint(rng, 1, 7), rint(rng, 1, 7) } }
			for slot = 1, rint(rng, 0, 16) do
				local p = pool[rint(rng, 1, #pool)]
				local lowS = rng() < 0.8
				local lowM = rng() < 0.8
				inv.pets[#inv.pets + 1] = { slot = slot, p = p, s = lowS and rint(rng, 1, 3) or rint(rng, 1, nS), m = lowM and rint(rng, 1, 3) or rint(rng, 1, nM), follower = rng() < 0.15, team = rng() < 0.15, defense = rng() < 0.1 }
				inv.seen[p] = true
			end
			for p = 1, nP do
				if rng() < 0.4 then
					inv.seen[p] = true
				end
			end
			local npc = Npc.newState()
			local day = 20000 + rint(rng, 0, 400)
			npc.day, npc.enc = day, rint(rng, 0, 1)
			local now = day * 86400 + rint(rng, 8 * 3600, 20 * 3600)
			local book = Npc.newBook()
			local oo = Npc.encounter(Config, npc, book, 1000 + i, now, day, okCtx(now), inv, rng)
			if not oo then
				counts.none = counts.none + 1
			else
				local bad = {}
				if oo.kind == "trade" then
					counts[oo.sub] = counts[oo.sub] + 1
					bad = Npc.violations(Config, oo, inv, 1000 + i)
				else
					counts[oo.kind] = counts[oo.kind] + 1
					if #oo.team ~= 3 or #oo.take ~= 0 or oo.price ~= 0 or oo.userId ~= 1000 + i or oo.expires - oo.created ~= 60 then
						bad[#bad + 1] = "combat mal formé"
					end
					for _, m in ipairs(oo.team) do
						if Config.PETS[m.p] == nil then
							bad[#bad + 1] = "espèce inexistante"
						end
					end
					if oo.cardEgg and (oo.cardEgg > tidx(Config, "Légendaire") or oo.cardEgg < 1) then
						bad[#bad + 1] = "œuf de carte trop rare"
					end
					if oo.powerMul < 0.9 - 1e-9 or oo.powerMul > 1.1 * 1.3 + 1e-9 then
						bad[#bad + 1] = "puissance hors bornes"
					end
				end
				if #bad > 0 then
					violations = violations + 1
					firstBad = firstBad or bad[1]
				end
			end
		end
		if firstBad then
			print("  première violation : " .. tostring(firstBad))
		end
		check("10 000 inventaires aléatoires : 0 violation de F.4", violations == 0)
		check("Couverture : achats > 800, doublons > 200, espèces manquantes > 200, combats > 3 000", counts.buy > 800 and counts.dupes > 200 and counts.species > 200 and counts.fight > 3000)
		check("Au moins 98 % des tirages produisent une offre", counts.none <= 200)
		print(string.format("  offres : achat %d, doublons %d, espèce %d, combat %d, champion %d, aucune %d", counts.buy, counts.dupes, counts.species, counts.fight, counts.champion, counts.none))
	end

	---------------------------------------------------------------- Série de 7 jours
	suite("Lot 15 : série de 7 jours (G.1), grâce et sauvetage (G.2), 35 jours simulés")
	local function newG()
		return { daily = 0, streak = 0, grace = Rewards.sanitizeGrace(nil) }
	end
	local function eggNames(C, grant)
		local out = {}
		for _, t in ipairs(grant.eggs) do
			out[#out + 1] = C.TIERS[t].name
		end
		return table.concat(out, "+")
	end
	do
		local want = { "Peu commun", "Rare", "", "Épique", "Rare+Rare", "Épique+Épique", "Légendaire" }
		local ok1 = true
		for d = 1, 7 do
			local g = Rewards.streakReward(Full, d, 0, 100, false)
			if eggNames(Full, g) ~= want[d] then
				ok1 = false
			end
		end
		check("Table G.1 (10 raretés publiées) : œufs jour par jour exacts, par nom de rareté", ok1)
		local g1 = Rewards.streakReward(Full, 1, 0, 100, false)
		check("Jour 1 : Œuf Peu commun (indice 2 via TIERS) + revenus de 5 min", g1.eggs[1] == 2 and g1.coins == 100 * 60 * 5)
		check("Jour 1 avec revenus nuls : minimum 500 pièces", Rewards.streakReward(Full, 1, 0, 0, false).coins == 500 and Rewards.streakReward(Full, 4, 0, 0.001, false).coins == 500)
		local g3 = Rewards.streakReward(Full, 3, 0, 100, false)
		check("Jour 3 : Potion de chance 10 min (+25 points), aucun œuf", g3.luck.minutes == 10 and g3.luck.points == 25 and #g3.eggs == 0 and g3.coins == 0)
		local g5 = Rewards.streakReward(Full, 5, 0, 100, false)
		check("Jour 5 : 2 Œufs Rares + effet XP x2 pendant 30 min", #g5.eggs == 2 and g5.eggs[1] == 3 and g5.eggs[2] == 3 and g5.boost.key == "xp" and g5.boost.mul == 2 and g5.boost.minutes == 30)
		check("Jour 4 : Œuf Épique (4) + revenus de 10 min ; jour 6 : 2 Épiques", Rewards.streakReward(Full, 4, 0, 100, false).eggs[1] == 4 and Rewards.streakReward(Full, 4, 0, 100, false).coins == 60000 and #Rewards.streakReward(Full, 6, 0, 100, false).eggs == 2)
		local g7 = Rewards.streakReward(Full, 7, 0, 100, false)
		check("Jour 7 : Légendaire (5) + revenus de 30 min + 1 Fragment du Grand Œuf", g7.eggs[1] == 5 and #g7.eggs == 1 and g7.coins == 180000 and g7.fragments == 1 and g7.mythicWeek == false)
		check("4e semaine complète : Œuf Mythique (6) à la place du Légendaire", Rewards.streakReward(Full, 7, 3, 100, false).eggs[1] == 6 and Rewards.streakReward(Full, 7, 7, 100, false).eggs[1] == 6 and Rewards.streakReward(Full, 7, 2, 100, false).eggs[1] == 5 and Rewards.streakReward(Full, 7, 3, 100, false).mythicWeek)
		local vip = Rewards.streakReward(Full, 4, 0, 100, true)
		check("Pass VIP : pièces x2 (VIP_DAILY_MUL), pas les œufs", vip.coins == 120000 and #vip.eggs == 1 and vip.eggs[1] == 4)
		local live = Rewards.streakReward(Config, 1, 0, 100, false)
		check("Config réel (Peu commun non publié) : l'œuf prend la rareté publiée inférieure (Commun)", live.eggs[1] == 1)
	end
	do
		-- Rareté jamais interdite, par données (toutes sources) : série, quêtes, PNJ
		local maxGift = 0
		local bad = {}
		local function see(C, grant)
			for _, v in ipairs(Rewards.grantViolations(C, grant)) do
				bad[#bad + 1] = v
			end
			for _, t in ipairs(grant.eggs) do
				maxGift = math.max(maxGift, t)
				if t >= C.TIER_GATE.globalBanner or forbiddenIdx[t] then
					bad[#bad + 1] = "rareté >= globalBanner : " .. t
				end
			end
		end
		for _, C in ipairs({ Config, Full }) do
			for d = 1, 7 do
				for w = 0, 7 do
					see(C, Rewards.streakReward(C, d, w, 50, w % 2 == 0))
				end
			end
			for day = 0, 9 do
				for _, ch in ipairs({ 0, 5, 6, 40 }) do
					local q = Rewards.bonusQuest(C, day, ch)
					see(C, { eggs = { q.egg } })
				end
			end
			for _, r in ipairs(C.QUESTS.weekly.rewards) do
				see(C, { eggs = { Rewards.giftTier(C, r.egg) } })
			end
		end
		check("Série, quêtes bonus et hebdomadaires : jamais Secret / Exclusif / Divin, toujours < TIER_GATE.globalBanner", #bad == 0)
		check("Rareté maximale donnée par ces sources = Mythique (indice 6 via TIERS)", maxGift == tidx(Config, "Mythique") and maxGift < Config.TIER_GATE.globalBanner)
		check("giftTier refuse les raretés interdites et inconnues", Rewards.giftTier(Full, "Secret") == nil and Rewards.giftTier(Full, "Exclusif") == nil and Rewards.giftTier(Full, "Divin") == nil and Rewards.giftTier(Full, "Inexistante") == nil and Rewards.giftTier(Full, "Mythique") == 6)
		local C3 = loadConfig(true)
		C3.STREAK.days[1].eggs = { "Secret", "Rare" }
		check("Une donnée de série qui contiendrait « Secret » est ignorée (aucun œuf interdit possible)", eggNames(C3, Rewards.streakReward(C3, 1, 0, 10, false)) == "Rare")
		check("Le contrôleur de grants détecte un œuf Secret", #Rewards.grantViolations(Full, { eggs = { 8 } }) == 1 and #Rewards.grantViolations(Full, { eggs = { 8 } }, true) == 0 and #Rewards.grantViolations(Full, { eggs = { 99 } }) == 1)
		-- Renumérotation : une rareté insérée en tête décale tous les indices, les noms suivent
		local C4 = loadConfig(true)
		table.insert(C4.TIERS, 1, { name = "Poussière" })
		C4.tierLive = function()
			return true
		end
		check("Renumérotation de Config.TIERS : les œufs suivent les noms (Peu commun = 3, Légendaire = 6)", Rewards.streakReward(C4, 1, 0, 10, false).eggs[1] == 3 and Rewards.streakReward(C4, 7, 0, 10, false).eggs[1] == 6 and Rewards.giftTier(C4, "Mythique") == 7 and Rewards.forbiddenTier(C4, 9) and not Rewards.forbiddenTier(C4, 8))
	end
	do
		-- 35 jours simulés dont 4 manqués (indices 5, 12, 13, 19 depuis un lundi)
		local START = 20000
		while Npc.dow(START) ~= 1 do
			START = START + 1
		end
		local missed = { [5] = true, [12] = true, [13] = true, [19] = true }
		local wantDays = { 1, 2, 3, 4, 5, false, 6, 7, 1, 2, 3, 4, false, false, 5, 6, 7, 1, 2, false, 3, 4, 5, 6, 7, 1, 2, 3, 4, 5, 6, 7, 1, 2, 3 }
		local wantEggs = { [1] = "Peu commun", [2] = "Rare", [3] = "", [4] = "Épique", [5] = "Rare+Rare", [6] = "Épique+Épique" }
		local g = newG()
		local slots, bag, cap = {}, {}, 50
		local gotDays, okAll = {}, true
		local expectEggs, claims = 0, 0
		local mythics, legends = {}, {}
		local graceUsed, rescued = 0, 0
		for i = 0, 34 do
			local t = START + i
			if missed[i] then
				gotDays[#gotDays + 1] = false
			else
				local plan = Rewards.streakPlan(Full, g, t, { questsDone = 3 })
				local how
				if plan.state == "rescue" then
					how = "quest"
					rescued = rescued + 1
				elseif plan.state == "grace" then
					graceUsed = graceUsed + 1
				end
				local ok, res = Rewards.streakClaim(Full, g, t, how, { income = 100, vip = false, questsDone = 3, slots = slots, cap = cap, bag = bag })
				if not ok then
					okAll = false
					gotDays[#gotDays + 1] = false
				else
					gotDays[#gotDays + 1] = res.day
					claims = claims + 1
					local expectedNames = wantEggs[res.day]
					if res.day == 7 then
						expectedNames = (g.grace.weeks == 4) and "Mythique" or "Légendaire"
						if expectedNames == "Mythique" then
							mythics[#mythics + 1] = i
						else
							legends[#legends + 1] = i
						end
					end
					if eggNames(Full, res.grant) ~= expectedNames then
						okAll = false
					end
					expectEggs = expectEggs + #res.grant.eggs
					-- Pièces : revenus de 5 / 10 / 30 min (minimum 500)
					local c = ({ [1] = 5, [4] = 10, [7] = 30 })[res.day]
					if (c and res.grant.coins ~= 100 * 60 * c) or (not c and res.grant.coins ~= 0) then
						okAll = false
					end
				end
				-- Anti-double : une 2e réclamation le même jour est refusée
				local again, why = Rewards.streakClaim(Full, g, t, nil, { income = 100, slots = slots, cap = cap, bag = bag })
				if again or why ~= "done" then
					okAll = false
				end
			end
		end
		check("35 jours dont 4 manqués : jours de série = table attendue (1..7, grâce, sauvetage par quêtes)", deepEq(gotDays, wantDays) and okAll)
		check("31 réclamations, 2 jours de grâce (semaines 0 et 2), 1 sauvetage par quêtes", claims == 31 and graceUsed == 2 and rescued == 1)
		check("Jour 7 : Légendaire aux jours 7, 16, 24 ; Mythique à la 4e semaine complète (jour 31)", deepEq(legends, { 7, 16, 24 }) and deepEq(mythics, { 31 }))
		check("Aucune duplication d'œuf : œufs en base + sac = œufs accordés", eggCount(slots, cap, bag) == expectEggs and #bag == 0)
		check("Série finale : 35 jours de suite comptés (streak = 31 réclamations successives)", g.daily == START + 34 and g.streak == 31)
	end
	do
		-- Sans jour manqué : 28 jours, Mythique au 28e
		local g = newG()
		local ok28, last = true, nil
		for i = 0, 27 do
			local ok, res = Rewards.streakClaim(Full, g, 30000 + i, nil, { income = 1 })
			if not ok then
				ok28 = false
			end
			last = res
		end
		check("28 jours sans manquer : le 28e (jour 7 de la 4e semaine) donne un Œuf Mythique", ok28 and last.day == 7 and last.grant.eggs[1] == 6 and g.grace.weeks == 4)
		local ok29, res29 = Rewards.streakClaim(Full, g, 30028, nil, { income = 1 })
		check("Puis la série recommence au jour 1 (compteur de semaines continu)", ok29 and res29.day == 1)
	end
	do
		-- Grâce, sauvetage, remise à zéro
		local D0 = 40000 -- un lundi (les 7 jours qui suivent sont la même semaine)
		while Npc.dow(D0) ~= 1 do
			D0 = D0 + 1
		end
		local function started(day, streak)
			local g = newG()
			g.daily, g.streak = day, streak
			return g
		end
		local g = started(D0, 3)
		local p = Rewards.streakPlan(Full, g, D0 + 2, {})
		check("Un jour manqué (1re fois de la semaine) : « grace », la série continue", p.state == "grace" and p.day == 4 and p.missed == 1)
		local ok, res = Rewards.streakClaim(Full, g, D0 + 2, nil, {})
		check("Jour de grâce consommé automatiquement : jour 4, série 4, grace.used = 1", ok and res.day == 4 and g.streak == 4 and g.grace.used == 1 and g.grace.week == Rewards.weekOf(D0 + 2))
		-- Deuxième jour manqué dans la même semaine : sauvetage
		g.daily = D0 + 2
		local p2 = Rewards.streakPlan(Full, g, D0 + 4, { questsDone = 2 })
		check("2e jour manqué la même semaine : « rescue » (série de 4 en jeu), quêtes 2/3 : pas encore possible", p2.state == "rescue" and p2.canQuest == false and p2.canProduct == true and p2.lost == 4)
		local before = copy(g)
		local o1, w1 = Rewards.streakClaim(Full, g, D0 + 4, nil, { questsDone = 3 })
		local o2, w2 = Rewards.streakClaim(Full, g, D0 + 4, "quest", { questsDone = 2 })
		check("Sauvetage refusé sans choix ou avec 2 quêtes seulement ; rien n'est modifié", o1 == false and w1 == "rescue" and o2 == false and w2 == "noQuest" and deepEq(g, before))
		local o3, r3 = Rewards.streakClaim(Full, g, D0 + 4, "product", { questsDone = 0 })
		check("Sauvetage par produit StreakRestore (1 fois par semaine) : la série continue (jour 5)", o3 and r3.day == 5 and g.streak == 5 and g.grace.rweek == Rewards.weekOf(D0 + 4))
		g.daily = D0 + 4
		local o4, w4 = Rewards.streakClaim(Full, g, D0 + 6, "product", {})
		check("2e sauvetage payant la même semaine refusé (« noProduct »)", o4 == false and w4 == "noProduct")
		local o5, r5 = Rewards.streakClaim(Full, g, D0 + 6, "quest", { questsDone = 3 })
		check("Sauvetage gratuit par 3 quêtes du jour : la série continue", o5 and r5.day == 6 and g.streak == 6)
		-- Reset à 3 jours manqués
		local g3 = started(D0, 6)
		local p3 = Rewards.streakPlan(Full, g3, D0 + 4, { questsDone = 3 })
		check("3 jours manqués : « reset » (pas de rachat)", p3.state == "reset" and p3.missed == 3)
		local o6, r6 = Rewards.streakClaim(Full, g3, D0 + 4, "quest", { questsDone = 3 })
		check("Reset : retour au jour 1, série 1, semaines complètes remises à 0", o6 and r6.day == 1 and g3.streak == 1 and g3.grace.weeks == 0)
		-- Le joueur peut préférer repartir (how = reset) au lieu de sauver
		local g4 = started(D0, 6)
		local o7, r7 = Rewards.streakClaim(Full, g4, D0 + 3, "reset", {})
		check("Sauvetage refusé volontairement (« reset ») : jour 1", o7 and r7.day == 1 and g4.streak == 1)
		-- Horloge à l'envers ou jour déjà réclamé
		local g5 = started(D0 + 5, 2)
		check("Jour déjà réclamé ou horloge en arrière : « done »", select(2, Rewards.streakClaim(Full, g5, D0 + 5, nil, {})) == "done" and select(2, Rewards.streakClaim(Full, g5, D0 + 1, nil, {})) == "done")
		-- Premier jour de tous
		local g6 = newG()
		local o8, r8 = Rewards.streakClaim(Full, g6, D0, nil, { income = 10 })
		check("Tout premier jour : jour 1", o8 and r8.day == 1 and g6.streak == 1 and g6.daily == D0)
		check("Sanitize de la grâce : valeurs bornées, formes inconnues", deepEq(Rewards.sanitizeGrace("x"), { week = 0, used = 0, weeks = 0, rweek = 0 }) and Rewards.sanitizeGrace({ week = -4, used = 9, weeks = 1e9, rweek = "a" }).used == 1)
	end

	---------------------------------------------------------------- Sac d'œufs
	suite("Lot 15 : sac d'œufs (10 places, jamais de perte, atomique)")
	do
		local slots, bag, cap = {}, {}, 3
		local ok, where = Rewards.storeEggs(Full, slots, cap, bag, { 1, 2, 3, 4, 5 }, nil)
		check("Base d'abord (3 places) puis sac : 5 œufs, aucun perdu", ok and eggCount(slots, cap, bag) == 5 and #bag == 2 and where[1] == "slot" and where[4] == "bag" and bag[1] == 4 and bag[2] == 5)
		local ok2, why2 = Rewards.storeEggs(Full, slots, cap, bag, { 1, 1, 1, 1, 1, 1, 1, 1, 1 }, nil)
		check("Rien ne rentre : refus atomique « bagFull » sans modification", ok2 == false and why2 == "bagFull" and #bag == 2 and eggCount(slots, cap, bag) == 5)
		local ok3 = Rewards.storeEggs(Full, slots, cap, bag, { 6, 6, 6, 6, 6, 6, 6, 6 }, nil)
		check("Le sac se remplit jusqu'à 10 exactement", ok3 and #bag == 10 and select(2, Rewards.storeEggs(Full, slots, cap, bag, { 1 }, nil)) == "bagFull" and #bag == 10)
		slots[2] = nil
		local okT, t, i = Rewards.bagTake(slots, cap, bag, nil)
		check("Poser un œuf du sac : le plus ancien, première place libre ; sac plein de nouveau 9/10", okT and t == 4 and i == 2 and slots[2].t == 4 and #bag == 9)
		check("Sac vide / base pleine : refus sans modification", select(2, Rewards.bagTake(slots, cap, {}, nil)) == "empty" and select(2, Rewards.bagTake(slots, cap, bag, nil)) == "baseFull" and #bag == 9)
		local mk = function(tier)
			return { k = "e", t = tier, ends = 99 }
		end
		local s2, b2 = {}, {}
		Rewards.storeEggs(Full, s2, 2, b2, { 5 }, mk)
		check("mkEgg : l'emplacement créé par le serveur (ends, shield) est utilisé", s2[1].ends == 99 and s2[1].t == 5)
		local clean = Rewards.sanitizeBag(Full, { 3, "x", 99, 0, 2.7, -1, 5, 1, 1, 1, 1, 1, 1, 1, 1, 1 })
		check("sanitizeBag : entiers valides, 10 entrées au plus, le reste ignoré", #clean == 10 and clean[1] == 3 and clean[2] == 2 and Rewards.canStore(Full, {}, 0, {}, 10) and not Rewards.canStore(Full, {}, 0, {}, 11) and #Rewards.sanitizeBag(Full, "x") == 0)
		-- Série atomique : un jour à 2 œufs avec 1 seule place libre en tout
		local g = newG()
		g.daily, g.streak = 50000, 4 -- le jour 5 donne 2 œufs
		local fullSlots = { { k = "e", t = 1 }, { k = "e", t = 1 } }
		local bagNine = { 1, 1, 1, 1, 1, 1, 1, 1, 1 }
		local before = copy(g)
		local okS, whyS = Rewards.streakClaim(Full, g, 50001, nil, { income = 10, slots = fullSlots, cap = 2, bag = bagNine })
		check("Série : 2 œufs mais 1 seule place -> « bagFull », ni série ni sac modifiés (réclamation différée, pas de perte)", okS == false and whyS == "bagFull" and deepEq(g, before) and #bagNine == 9 and #fullSlots == 2)
		bagNine[10] = nil
		fullSlots[1] = nil
		local okS2, resS2 = Rewards.streakClaim(Full, g, 50001, nil, { income = 10, slots = fullSlots, cap = 2, bag = bagNine })
		check("Une place de plus : réclamation réussie, 2 œufs rangés (1 en base, 1 dans le sac qui atteint 10)", okS2 and #resS2.grant.eggs == 2 and eggCount(fullSlots, 2, bagNine) == 12 and #bagNine == 10)
	end

	---------------------------------------------------------------- Calendrier de 30 jours (réutilisé)
	suite("Lot 15 : calendrier de 30 jours (Calendar.lua réutilisé) avec sac d'œufs")
	do
		local cal = Calendar.newState(Config)
		local START = 45000
		Calendar.begin(Config, cal, START)
		local slots, bag, cap = {}, {}, 20
		local okAll, eggsExpected, draws = true, 0, 0
		local drawTable = Calendar.drawTable(Config)
		local allowed = {}
		for _, e in ipairs(drawTable) do
			allowed[e.tier] = true
		end
		for d = 1, 30 do
			local today = START + d - 1
			local ok, res = Rewards.calendarClaim(Config, Calendar, cal, today, d, "today", true, 0.5, 100, { slots = slots, cap = cap, bag = bag })
			if not ok then
				okAll = false
			else
				local r = Config.CALENDAR.rewards[d]
				if r.draw then
					draws = draws + 1
					if not allowed[res.plan.egg] then
						okAll = false
					end
				elseif res.plan.egg ~= r.egg then
					okAll = false
				end
				if res.plan.egg then
					eggsExpected = eggsExpected + 1
				end
				local ok2, why2 = Rewards.calendarClaim(Config, Calendar, cal, today, d, "today", true, 0.5, 100, { slots = slots, cap = cap, bag = bag })
				if ok2 or why2 ~= "claimed" then
					okAll = false
				end
			end
		end
		check("30 connexions : une récompense par jour UTC, égale à la table 9b, jour 30 tiré dans la table effective", okAll and draws == 1 and Calendar.claimedCount(cal) == 30)
		check("Calendrier : aucune duplication d'œuf (base + sac = œufs attendus)", eggCount(slots, cap, bag) == eggsExpected)
		check("Nouveau cycle : remise à zéro des 30 cases", Calendar.normalize(Config, cal, START + 30) and Calendar.claimedCount(cal) == 0 and cal.cycle == 2 and cal.start == START + 30)
		-- Un jour futur ou hors cycle est refusé ; sac plein : refus sans modification
		local c2 = Calendar.newState(Config)
		Calendar.begin(Config, c2, START)
		check("Jour futur refusé (« future »)", select(2, Rewards.calendarClaim(Config, Calendar, c2, START, 3, "today", true, 0.5, 100, nil)) == "future")
		local fullS, fullB = { { k = "e", t = 1 } }, { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
		Calendar.apply(Config, c2, START, 1, "today")
		local snap = copy(c2)
		local okF, whyF = Rewards.calendarClaim(Config, Calendar, c2, START + 2, 3, "today", true, 0.5, 100, { slots = fullS, cap = 1, bag = fullB })
		check("Jour 3 (œuf Légendaire) avec base et sac pleins : « bagFull », calendrier inchangé", okF == false and whyF == "bagFull" and deepEq(c2, snap))
	end

	---------------------------------------------------------------- Quêtes bonus et hebdomadaires
	suite("Lot 15 : quêtes bonus du jour et quêtes de la semaine (G.4)")
	do
		local day = 41000
		local q1 = Rewards.bonusQuest(Full, day, 3)
		local q2 = Rewards.bonusQuest(Full, day, 3)
		check("Quête bonus déterministe par jour ; Œuf Épique (chapitre < 6), Légendaire (chapitre >= 6)", deepEq(q1, q2) and q1.egg == 4 and Rewards.bonusQuest(Full, day, 6).egg == 5 and Rewards.bonusQuest(Full, day, 12).egg == 5)
		local kinds = {}
		for d = 0, 5 do
			kinds[Rewards.bonusQuest(Full, d, 0).kind] = true
		end
		check("Les deux options (2 combats PvE / 1 œuf Épique+) alternent", kinds.pve and kinds.hatch)
		local pveDay, hatchDay
		for d = 41000, 41003 do
			local k = Rewards.bonusQuest(Full, d, 0).kind
			if k == "pve" then
				pveDay = d
			else
				hatchDay = d
			end
		end
		local wk = Rewards.sanitizeWeekly(Full, nil)
		local p0 = Rewards.bonusEvent(Full, wk, pveDay, 0, false, { kind = "pve" })
		check("Verrouillée tant que les 3 quêtes du jour ne sont pas faites", p0 == 0 and select(2, Rewards.bonusClaim(Full, wk, pveDay, 0, nil)) == "notDone")
		Rewards.bonusEvent(Full, wk, pveDay, 0, true, { kind = "pve" })
		check("1 victoire sur 2 : pas terminée, réclamation refusée", select(2, Rewards.bonusClaim(Full, wk, pveDay, 0, nil)) == "notDone")
		Rewards.bonusEvent(Full, wk, pveDay, 0, true, { kind = "hatch", tier = 5 })
		check("Un événement d'un autre type ne compte pas", wk.bq.prog == 1)
		local pr, done = Rewards.bonusEvent(Full, wk, pveDay, 0, true, { kind = "pve" })
		check("2 victoires PvE : terminée", pr == 2 and done)
		local slots, bag = {}, {}
		local ok, gr = Rewards.bonusClaim(Full, wk, pveDay, 0, { slots = slots, cap = 5, bag = bag })
		check("Réclamation : Œuf Épique rangé ; une seule fois", ok and gr.eggs[1] == 4 and eggCount(slots, 5, bag) == 1 and select(2, Rewards.bonusClaim(Full, wk, pveDay, 0, { slots = slots, cap = 5, bag = bag })) == "claimed" and eggCount(slots, 5, bag) == 1)
		local pr2 = Rewards.bonusEvent(Full, wk, pveDay, 0, true, { kind = "pve" })
		check("Après réclamation la progression ne bouge plus ; le lendemain tout repart de zéro", pr2 == 2 and Rewards.bonusEvent(Full, wk, pveDay + 1, 0, true, { kind = "none" }) == 0 and wk.bq.d == pveDay + 1 and wk.bq.claimed == false)
		local wk2 = Rewards.sanitizeWeekly(Full, nil)
		Rewards.bonusEvent(Full, wk2, hatchDay, 0, true, { kind = "hatch", tier = 3 })
		check("Éclosion Rare (< Épique) ne compte pas", wk2.bq.prog == 0)
		local p3, d3 = Rewards.bonusEvent(Full, wk2, hatchDay, 0, true, { kind = "hatch", tier = 4 })
		check("Éclosion Épique compte (1 sur 1)", p3 == 1 and d3)
		local wk3 = Rewards.sanitizeWeekly(Full, nil)
		Rewards.bonusEvent(Full, wk3, hatchDay, 0, true, { kind = "hatch", tier = 4 })
		local fS, fB = { { k = "e", t = 1 } }, { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
		check("Base et sac pleins : « bagFull », la quête reste réclamable", select(2, Rewards.bonusClaim(Full, wk3, hatchDay, 0, { slots = fS, cap = 1, bag = fB })) == "bagFull" and wk3.bq.claimed == false)
	end
	do
		local wk = Rewards.sanitizeWeekly(Full, nil)
		local W = 3000
		Rewards.weeklySync(Full, wk, W)
		check("Semaine : 7 quêtes, une par thème (éclosion, vol, PvE, PvP, collection, énigme, PNJ)", #wk.prog == 7 and Full.QUESTS.weekly.themes[1].key == "hatch" and Full.QUESTS.weekly.themes[7].key == "npc")
		check("Thème inconnu : nil ; progression plafonnée à l'objectif", Rewards.weeklyAdd(Full, wk, "zzz", 1) == nil and Rewards.weeklyAdd(Full, wk, "hatch", 999) == 15 and Rewards.weeklyAdd(Full, wk, "hatch", -5) == 15 and Rewards.weeklyAdd(Full, wk, "steal", 0 / 0) == 0)
		check("1/7 : paliers 5/7 et 7/7 refusés", Rewards.weeklyDone(Full, wk) == 1 and select(2, Rewards.weeklyClaim(Full, wk, 5, nil)) == "notDone" and select(2, Rewards.weeklyClaim(Full, wk, 7, nil)) == "notDone" and select(2, Rewards.weeklyClaim(Full, wk, 6, nil)) == "which")
		for _, k in ipairs({ "steal", "pve", "pvp", "collect" }) do
			Rewards.weeklyAdd(Full, wk, k, 999)
		end
		local slots, bag = {}, {}
		local ok, gr = Rewards.weeklyClaim(Full, wk, 5, { slots = slots, cap = 5, bag = bag })
		check("5/7 : Œuf Légendaire", Rewards.weeklyDone(Full, wk) == 5 and ok and gr.eggs[1] == 5 and gr.seasonXp == 0 and eggCount(slots, 5, bag) == 1)
		check("5/7 ne se réclame qu'une fois (aucun œuf en double)", select(2, Rewards.weeklyClaim(Full, wk, 5, { slots = slots, cap = 5, bag = bag })) == "claimed" and eggCount(slots, 5, bag) == 1 and select(2, Rewards.weeklyClaim(Full, wk, 7, nil)) == "notDone")
		Rewards.weeklyAdd(Full, wk, "riddle", 999)
		Rewards.weeklyAdd(Full, wk, "npc", 999)
		local ok7, g7 = Rewards.weeklyClaim(Full, wk, 7, { slots = slots, cap = 5, bag = bag })
		check("7/7 : Œuf Mythique + 300 XP de saison", ok7 and g7.eggs[1] == 6 and g7.seasonXp == 300 and eggCount(slots, 5, bag) == 2)
		Rewards.weeklySync(Full, wk, W)
		check("Même semaine : la synchronisation ne remet rien à zéro", wk.c5 and wk.c7 and wk.prog[1] == 15)
		Rewards.weeklySync(Full, wk, W + 1)
		check("Nouvelle semaine : progression et réclamations remises à zéro", Rewards.weeklyDone(Full, wk) == 0 and not wk.c5 and not wk.c7 and wk.w == W + 1)
		local s = Rewards.sanitizeWeekly(Full, { w = "x", prog = { 99, "a", -3 }, c5 = 1, bq = { d = 5, prog = 1e9, claimed = true } })
		check("sanitizeWeekly : plafonds par objectif, formes inconnues = neuf", s.w == 0 and s.prog[1] == 15 and s.prog[2] == 0 and s.prog[3] == 0 and #s.prog == 7 and s.c5 == false and s.bq.prog == 99 and s.bq.claimed and #Rewards.sanitizeWeekly(Full, "x").prog == 7)
	end

	---------------------------------------------------------------- Rotation hebdomadaire
	suite("Lot 15 : rotation hebdomadaire de 9 semaines (déterministe, identique pour tous)")
	do
		local seen, ok = {}, true
		for w = 3000, 3008 do
			local r, i = Rewards.rotation(Full, w)
			if seen[r.type] then
				ok = false
			end
			seen[r.type] = true
			local r2 = Rewards.rotation(Full, w + 9)
			local r3 = Rewards.rotation(Full, w - 9)
			if r2 ~= r or r3 ~= r or i < 1 or i > 9 then
				ok = false
			end
		end
		check("9 semaines consécutives = 9 types différents ; la semaine w + 9 revient à l'identique", ok)
		check("Déterministe : deux appels (deux serveurs) donnent la même rotation, valeurs douteuses = semaine 0", Rewards.rotation(Full, 3333) == Rewards.rotation(Full, 3333) and Rewards.rotation(Full, 0 / 0) == Rewards.rotation(Full, 0) and Rewards.rotation(Full, -1) ~= nil)
		local r = Rewards.rotation(Full, 3000)
		local feat = petIdx(Full, r.featured)
		local other = (feat % #Full.PETS) + 1
		check("Espèce vedette : poids x2, les autres inchangés", Rewards.featuredWeight(Full, r, feat, 10) == 20 and Rewards.featuredWeight(Full, r, other, 10) == 10)
		check("Type en forme : +20 % de dégâts en PvE seulement", Rewards.typeDamage(Full, r, r.type, true) == 1.2 and Rewards.typeDamage(Full, r, r.type, false) == 1 and Rewards.typeDamage(Full, r, "Autre", true) == 1)
	end

	---------------------------------------------------------------- Événements
	suite("Lot 15 : week-end chanceux, heure dorée, événements limités")
	do
		local SAT = 2 * 86400 -- samedi 1970-01-03 00:00 UTC
		check("Week-end chanceux : samedi 00:00 oui, vendredi 23:59:59 non", Rewards.isWeekend(Full, SAT) and not Rewards.isWeekend(Full, SAT - 1))
		check("Dimanche 23:59:59 oui, lundi 00:00 non", Rewards.isWeekend(Full, 4 * 86400 - 1) and not Rewards.isWeekend(Full, 4 * 86400))
		check("Semaine suivante : mercredi non, samedi oui", not Rewards.isWeekend(Full, 7 * 86400) and Rewards.isWeekend(Full, 9 * 86400 + 5))
		check("Heure dorée : 18:00:00 oui, 17:59:59 non, 18:59:59 oui, 19:00:00 non", Rewards.isGoldenHour(Full, 18 * 3600) and not Rewards.isGoldenHour(Full, 18 * 3600 - 1) and Rewards.isGoldenHour(Full, 19 * 3600 - 1) and not Rewards.isGoldenHour(Full, 19 * 3600) and Rewards.isGoldenHour(Full, 5 * 86400 + 18 * 3600 + 30))
		check("Valeurs douteuses : jamais d'événement", not Rewards.isWeekend(Full, 0 / 0) and not Rewards.isGoldenHour(Full, "x") and Rewards.limitedEvent(Full, nil) == nil)
		local ev = Rewards.activeEvents(Full, SAT + 18 * 3600 + 5)
		check("activeEvents samedi 18 h : +5 points d'amélioration, tapis 4 s, ruée vers l'or (clé gold)", ev.weekend and ev.upgradeBonus == 5 and ev.beltSeconds == 4 and ev.golden and ev.goldKey == "gold")
		local ev2 = Rewards.activeEvents(Full, 7 * 86400 + 10 * 3600)
		check("Mercredi 10 h : aucun bonus, tapis 5 s", not ev2.weekend and ev2.upgradeBonus == 0 and ev2.beltSeconds == 5 and not ev2.golden)
		local function dayOf(y, m, d)
			return Rewards.daysFromCivil(y, m, d)
		end
		local h1, k1 = Rewards.limitedEvent(Full, dayOf(2026, 10, 22))
		local h2 = Rewards.limitedEvent(Full, dayOf(2026, 10, 31))
		check("Halloween 22-31 octobre : actif aux deux bornes, clé « halloween.2026 », espèce #72", h1 ~= nil and h1.id == "halloween" and k1 == "halloween.2026" and h2 ~= nil and h1.species == 72)
		check("Halloween : inactif le 21 octobre et le 1er novembre", Rewards.limitedEvent(Full, dayOf(2026, 10, 21)) == nil and Rewards.limitedEvent(Full, dayOf(2026, 11, 1)) == nil)
		check("Noël 16-25 décembre actif (#73), le 26 non ; le printemps revient chaque année", select(1, Rewards.limitedEvent(Full, dayOf(2026, 12, 20))).species == 73 and Rewards.limitedEvent(Full, dayOf(2026, 12, 26)) == nil and select(2, Rewards.limitedEvent(Full, dayOf(2027, 3, 25))) == "spring.2027")
		check("Événements modifiables par les données (EVENTS_CAL) sans toucher à la logique", (function()
			local C = loadConfig(true)
			C.EVENTS_CAL = { { id = "test", from = "01-05", to = "01-14", species = 1 } }
			return select(1, Rewards.limitedEvent(C, dayOf(2026, 1, 10))) ~= nil and Rewards.limitedEvent(C, dayOf(2026, 10, 25)) == nil
		end)())
	end

	---------------------------------------------------------------- Plumes
	suite("Lot 15 : plumes d'événement (plafonds par jour, Œuf Exclusif à 150)")
	do
		local ev = Rewards.sanitizeEvent(Full, nil)
		local DAY1 = Rewards.daysFromCivil(2026, 10, 22)
		local key = "halloween.2026"
		Rewards.plumeSync(Full, ev, DAY1, key)
		local q = {}
		for i = 1, 5 do
			q[i] = Rewards.plumeAdd(Full, ev, "quest", true)
		end
		check("Quêtes du jour : 10 plumes chacune, plafond 40 par jour (10, 10, 10, 10, 0)", deepEq(q, { 10, 10, 10, 10, 0 }) and ev.p == 40)
		local pv = 0
		for _ = 1, 15 do
			pv = pv + Rewards.plumeAdd(Full, ev, "pve", true)
		end
		check("Victoires PvE : 2 plumes chacune, 20 au plus par jour", pv == 20 and ev.p == 60 and Rewards.plumeAdd(Full, ev, "pve", true) == 0)
		check("Connexion : 5 plumes, une seule fois par jour", Rewards.plumeAdd(Full, ev, "login", true) == 5 and Rewards.plumeAdd(Full, ev, "login", true) == 0 and ev.p == 65)
		check("Source inconnue ou événement inactif : rien", Rewards.plumeAdd(Full, ev, "zzz", true) == 0 and Rewards.plumeAdd(Full, ev, "quest", false) == 0 and ev.p == 65)
		Rewards.plumeSync(Full, ev, DAY1, key)
		check("Même jour : la synchronisation ne remet pas les plafonds à zéro", Rewards.plumeAdd(Full, ev, "login", true) == 0 and ev.q == 40)
		Rewards.plumeSync(Full, ev, DAY1 + 1, key)
		check("Jour suivant : plafonds remis à zéro, solde conservé", ev.q == 0 and ev.v == 0 and ev.l == 0 and ev.p == 65 and Rewards.plumeAdd(Full, ev, "quest", true) == 10)
		-- Achat de l'Œuf Exclusif
		local slots, bag, cap = {}, {}, 5
		check("Œuf Exclusif refusé sous 150 plumes (149)", (function()
			ev.p = 149
			local ok, why = Rewards.plumeBuyExclusive(Full, ev, true, { slots = slots, cap = cap, bag = bag })
			return ok == false and why == "plumes" and ev.p == 149 and eggCount(slots, cap, bag) == 0
		end)())
		ev.p = 150
		local ok, t, where = Rewards.plumeBuyExclusive(Full, ev, true, { slots = slots, cap = cap, bag = bag })
		check("150 plumes : Œuf Exclusif (indice 9 via TIERS), 150 plumes retirées, rangé en base", ok and t == tidx(Full, "Exclusif") and t == 9 and ev.p == 0 and ev.x == 1 and where == "slot" and slots[1].t == 9)
		ev.p = 450
		local o2 = Rewards.plumeBuyExclusive(Full, ev, true, { slots = slots, cap = cap, bag = bag })
		local o3 = Rewards.plumeBuyExclusive(Full, ev, true, { slots = slots, cap = cap, bag = bag })
		local o4, w4 = Rewards.plumeBuyExclusive(Full, ev, true, { slots = slots, cap = cap, bag = bag })
		check("3 Exclusifs au plus par événement (« limit »), 150 plumes restantes non dépensées", o2 and o3 and o4 == false and w4 == "limit" and ev.p == 150 and eggCount(slots, cap, bag) == 3)
		check("Événement terminé : achat refusé (« inactive »)", select(2, Rewards.plumeBuyExclusive(Full, ev, false, nil)) == "inactive")
		local live = Rewards.sanitizeEvent(Config, { k = "x.1", p = 300 })
		check("Rareté Exclusif sans espèce publiée (Config réel actuel) : achat refusé « notLive », plumes intactes", select(2, Rewards.plumeBuyExclusive(Config, live, true, nil)) == "notLive" and live.p == 300)
		-- Atomique : base et sac pleins
		local ev3 = Rewards.sanitizeEvent(Full, { k = "x.1", p = 200 })
		local fS, fB = { { k = "e", t = 1 } }, { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
		check("Base et sac pleins : « bagFull », plumes non dépensées", select(2, Rewards.plumeBuyExclusive(Full, ev3, true, { slots = fS, cap = 1, bag = fB })) == "bagFull" and ev3.p == 200 and ev3.x == 0)
		-- Nouvel événement : solde remis à zéro
		local ev4 = Rewards.sanitizeEvent(Full, { k = "halloween.2026", p = 120, x = 2, d = 5 })
		Rewards.plumeSync(Full, ev4, DAY1 + 60, "xmas.2026")
		check("Nouvel événement : solde et achats remis à zéro (les plumes ne se reportent pas)", ev4.k == "xmas.2026" and ev4.p == 0 and ev4.x == 0)
		Rewards.plumeSync(Full, ev4, DAY1 + 90, nil)
		check("Aucun événement actif (clé nil) : la clé reste, aucune plume ne peut être créditée", Rewards.plumeAdd(Full, ev4, "quest", false) == 0)
		local capped = Rewards.sanitizeEvent(Full, { k = "a.1", p = 995 })
		Rewards.plumeAdd(Full, capped, "quest", true)
		check("Solde plafonné à 999", capped.p == 999)
		check("sanitizeEvent : bornes et formes inconnues", Rewards.sanitizeEvent(Full, { k = 5, q = 1e9, v = -1, l = 7, p = 1e9, x = "a" }).p == 999 and Rewards.sanitizeEvent(Full, "x").k == "" and Rewards.sanitizeEvent(Full, { q = 1e9 }).q == 40)
		-- Parcours « joueur assidu » : l'Exclusif devient possible au 3e jour
		local e5 = Rewards.sanitizeEvent(Full, nil)
		local got
		for d = 0, 9 do
			Rewards.plumeSync(Full, e5, DAY1 + d, key)
			Rewards.plumeAdd(Full, e5, "login", true)
			for _ = 1, 4 do
				Rewards.plumeAdd(Full, e5, "quest", true)
			end
			for _ = 1, 10 do
				Rewards.plumeAdd(Full, e5, "pve", true)
			end
			if not got and e5.p >= 150 then
				got = d
			end
		end
		check("Joueur assidu (65 plumes par jour au maximum) : 150 plumes au 3e jour de l'événement", got == 2)
	end

	---------------------------------------------------------------- Fuzz économie : aucune duplication d'œuf
	suite("Lot 15 : aucune duplication d'œuf (3 000 actions aléatoires, grand livre)")
	do
		local rng = mkRng(777)
		local g = newG()
		local wk = Rewards.sanitizeWeekly(Full, nil)
		local ev = Rewards.sanitizeEvent(Full, { k = "halloween.2026" })
		local cal = Calendar.newState(Config)
		local slots, bag, cap = {}, {}, 4
		local ledger = 0
		local today = 50000
		Calendar.begin(Config, cal, today)
		local sound = true
		local function store()
			return { slots = slots, cap = cap, bag = bag }
		end
		for step = 1, 3000 do
			Calendar.normalize(Config, cal, today)
			local op = rint(rng, 1, 9)
			local before = eggCount(slots, cap, bag)
			local stateBefore = copy({ g = g, wk = wk, ev = ev, cal = cal })
			local ok, gain = false, 0
			if op == 1 then
				local o, r = Rewards.streakClaim(Full, g, today, (rng() < 0.5) and "quest" or nil, { income = 10, questsDone = 3, slots = slots, cap = cap, bag = bag })
				ok = o
				gain = o and #r.grant.eggs or 0
			elseif op == 2 then
				local o, r = Rewards.weeklyClaim(Full, wk, rng() < 0.5 and 5 or 7, store())
				ok = o
				gain = o and #r.eggs or 0
			elseif op == 3 then
				local o, r = Rewards.bonusClaim(Full, wk, today, 0, store())
				ok = o
				gain = o and #r.eggs or 0
			elseif op == 4 then
				local day = rng() < 0.7 and (today - cal.start + 1) or rint(rng, 1, 30)
				local o, r = Rewards.calendarClaim(Config, Calendar, cal, today, day, "today", true, rng(), 50, store())
				ok = o
				gain = (o and r.plan.egg) and 1 or 0
			elseif op == 5 then
				ev.p = math.min(999, ev.p + rint(rng, 0, 400))
				local o = Rewards.plumeBuyExclusive(Full, ev, true, store())
				ok = o
				gain = o and 1 or 0
			elseif op == 6 then
				local o = Rewards.bagTake(slots, cap, bag, nil)
				ok = o
				gain = 0
			elseif op == 7 then
				for _, th in ipairs(Full.QUESTS.weekly.themes) do
					if rng() < 0.4 then
						Rewards.weeklyAdd(Full, wk, th.key, rint(rng, 1, 4))
					end
				end
				Rewards.bonusEvent(Full, wk, today, 0, true, { kind = "pve" })
				Rewards.bonusEvent(Full, wk, today, 0, true, { kind = "hatch", tier = 5 })
				stateBefore = nil
			elseif op == 8 then
				local o = Rewards.storeEggs(Full, slots, cap, bag, { 1 }, nil) -- gain de test direct
				ok = o
				gain = o and 1 or 0
				stateBefore = nil
			else
				-- Un joueur libère des places (vente ou éclosion d'un œuf de la base) et le temps passe
				for i = 1, cap do
					if slots[i] and rng() < 0.5 then
						slots[i] = nil
						ledger = ledger - 1
					end
				end
				if rng() < 0.5 then
					today = today + rint(rng, 1, 3)
					Rewards.weeklySync(Full, wk, Rewards.weekOf(today))
				end
				stateBefore = nil
			end
			ledger = ledger + gain
			if eggCount(slots, cap, bag) ~= ledger then
				sound = false
				print("  grand livre rompu à l'étape " .. step .. " (opération " .. op .. ")")
				break
			end
			if not ok and op <= 6 and eggCount(slots, cap, bag) ~= before then
				sound = false
				break
			end
			if not ok and (op == 1 or op == 2) and stateBefore and not deepEq(copy({ g = g, wk = wk, ev = ev, cal = cal }), stateBefore) then
				sound = false
				print("  réclamation refusée mais état modifié, opération " .. op .. " étape " .. step)
				break
			end
		end
		check("3 000 actions : œufs en base + sac = œufs accordés (grand livre exact), un refus ne modifie ni œufs ni état", sound)
		check("Sac jamais au-delà de 10, base jamais au-delà de sa capacité", #bag <= 10 and eggCount(slots, cap, {}) <= cap)
	end

	---------------------------------------------------------------- Intégration (lot 15) : données dans Config, espèce vedette exacte, produit de sauvetage
	suite("Lot 15 : intégration des données (Config), espèce vedette x2, sauvetage payant désactivé tant que l'ID manque")
	check("Config.EVENTS (événements serveur existants) intact, week-end chanceux et heure dorée dans Config.TIMED_EVENTS (aucune collision de nom)",
		type(Config.EVENTS[1]) == "table" and type(Config.EVENTS[1].key) == "string" and Config.TIMED_EVENTS.weekend.upgradePoints == 5 and Config.TIMED_EVENTS.goldenHour.fromHour == 18 and Config.TIMED_EVENTS.goldenHour.toHour == 19)
	check("Modèles du lot 29 : 5 PNJ, 3 décors d'événement, calendrier mural (IDs entiers > 0, plafond de Parts défini)", (function()
		local n = 0
		for k, id in pairs(Config.Assets.models.npc) do
			n = n + ((type(id) == "number" and id > 0 and Config.Assets.modelsMaxParts["npc." .. k] ~= nil) and 1 or 0)
		end
		for k, id in pairs(Config.Assets.models.event) do
			n = n + ((type(id) == "number" and id > 0 and Config.Assets.modelsMaxParts["event." .. k] ~= nil) and 1 or 0)
		end
		return n == 8 and Config.Assets.models.npc.pip == 123590742152774 and Config.Assets.models.npc.nora == 81037598191401 and Config.Assets.models.hub.calendar == 134196650002859 and Config.Assets.models.event.pumpkin == 73142027959966
	end)())
	check("Produit StreakRestore : 29 R$, désactivé tant que son ID vaut 0 (Config.purchasable)", Config.PRODUCTS.StreakRestore.robux == 29 and Config.purchasable(Config.PRODUCTS.StreakRestore) == false)
	do
		-- espèce vedette : P(vedette) = M / (n + M - 1) après un tirage uniforme (n espèces de la rareté), la rareté ne change jamais
		local rot = Rewards.rotation(Config, 0)
		local fIdx = petIdx(Config, rot.featured)
		local tier = Config.PETS[fIdx].tier
		local ids = {}
		for i, p in ipairs(Config.PETS) do
			if p.tier == tier then
				ids[#ids + 1] = i
			end
		end
		local n, M = #ids, Config.WEEKLY_ROTATION_MULT
		local rng = mkRng(77)
		local hits, N, sameTier = 0, 60000, true
		for _ = 1, N do
			local pick = ids[math.min(n, math.floor(rng() * n) + 1)]
			local out = Rewards.featuredPick(Config, rot, pick, rng)
			if out == fIdx then
				hits = hits + 1
			end
			sameTier = sameTier and Config.PETS[out].tier == tier
		end
		local want = M / (n + M - 1)
		check("Espèce vedette « " .. rot.featured .. " » : fréquence " .. string.format("%.4f", hits / N) .. " ~ " .. string.format("%.4f", want) .. " (poids x" .. M .. "), rareté inchangée", math.abs(hits / N - want) < 0.01 and sameTier)
		local other = nil
		for i, p in ipairs(Config.PETS) do
			if p.tier ~= tier and not other then
				other = i
			end
		end
		check("Espèce vedette : un tirage d'une autre rareté n'est jamais modifié", Rewards.featuredPick(Config, rot, other, function()
			return 0
		end) == other)
	end
end
