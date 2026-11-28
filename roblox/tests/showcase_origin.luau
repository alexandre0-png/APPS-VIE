--!nocheck
-- Vitrine : « pas de bonus pour un œuf acheté » (décision utilisateur, 2026-11-28).
-- 1. Module pur Showcase : origines admises, tryClaim refuse un œuf payé ou d'origine inconnue AVANT tout appel DataStore, rattrapage à la connexion impossible sans victoire.
-- 2. Données : Data.lua assainit slot.og (idempotent, ancien slot = inconnu, jamais promu).
-- 3. Bout en bout (vrai Main.server.lua + Data.lua, runtime factice) : origine figée à l'octroi (pièces, reçu Robux, sac d'œufs, coffre de débordement) et
--    aucune réclamation de vitrine pour un œuf payé / inconnu même quand la vitrine est activée et l'espèce en vitrine.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime? }. Style : pas de `+=`, pas de `continue`. État dans une table T.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local C3 = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } }
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = C3 })()
	local Mod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Showcase.lua"), { debugName = "Showcase" })()
	local DAY = 86400
	local D0 = 20400
	local T0 = D0 * DAY + 3600
	local noWait = function() end
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end
	local function fakeStore()
		local st = { data = {}, calls = 0, getCalls = 0 }
		function st:UpdateAsync(key, fn)
			self.calls = self.calls + 1
			local new = fn(self.data[key])
			if new ~= nil then
				self.data[key] = new
			end
			return self.data[key]
		end
		function st:GetAsync(key)
			self.getCalls = self.getCalls + 1
			return self.data[key]
		end
		return st
	end
	-- Config factice avec des espèces de rareté >= 6 (le Config chargé ici n'a pas le bestiaire du lot 11).
	local FakeCfg = { PETS = {}, SHOWCASE = Config.SHOWCASE }
	for i = 1, 12 do
		FakeCfg.PETS[i] = { name = "E" .. i, tier = (i % 2 == 0) and 7 or 3 }
	end

	---------------------------------------------------------------- 1. Config et module pur
	suite("Vitrine (œufs achetés exclus) : Config, origines admises, tryClaim, rattrapage")
	check("Config.SHOWCASE.enabled = false par défaut (décision utilisateur : la vitrine n'agit pas tant que non activée)", Config.SHOWCASE.enabled == false)
	check("Config.SHOWCASE.origins : g (gagné) et c (pièces) admis, r (payé) jamais", type(Config.SHOWCASE.origins) == "table" and Config.SHOWCASE.origins.g == true and Config.SHOWCASE.origins.c == true and Config.SHOWCASE.origins.r == nil)
	T.SC = Mod.new(FakeCfg)
	local SC = T.SC
	check("originOk : g et c admis", SC.originOk("g") == true and SC.originOk("c") == true)
	check("originOk : r (payé), nil (inconnu), valeur étrangère ou d'un autre type refusés", SC.originOk("r") == false and SC.originOk(nil) == false and SC.originOk("x") == false and SC.originOk(5) == false and SC.originOk({}) == false)
	check(
		"originOk : un Config qui « admettrait » r ne peut pas rendre un œuf payé éligible",
		Mod.new({ PETS = FakeCfg.PETS, SHOWCASE = { origins = { r = true, g = true } } }).originOk("r") == false
	)
	check("validOrigin : seules g, c, r sont des origines connues", Mod.validOrigin("g") and Mod.validOrigin("c") and Mod.validOrigin("r") and not Mod.validOrigin("b") and not Mod.validOrigin(nil))
	T.sp = SC.pick(D0)
	check("une espèce est en vitrine le jour D0 (Config factice)", type(T.sp) == "number" and SC.featured(T.sp, T0) == true and SC.featured(T.sp + 1000, T0) == false and SC.featured(T.sp, 0 / 0) == false)
	-- Œuf payé (r) et origine inconnue (nil, sac, coffre, boutique Robux) : refus AVANT tout appel DataStore, aucun bonus, aucun enregistrement.
	for _, case in ipairs({ { og = "r", label = "payé (r)" }, { og = nil, label = "inconnu (nil)" }, { og = "zz", label = "invalide" } }) do
		local st = fakeStore()
		local sc = SC.sanitize(nil, T0)
		local r = Mod.new(FakeCfg).tryClaim(st, sc, T.sp, { userId = 7, name = "Payeur", og = case.og }, T0, noWait)
		check(
			"œuf " .. case.label .. " de l'espèce en vitrine : notEarned, 0 appel DataStore, aucun bonus (multiplicateur 1), aucun enregistrement",
			r == "notEarned" and st.calls == 0 and st.getCalls == 0 and sc.ends == 0 and sc.last == 0 and SC.multiplier(sc, T0) == 1 and next(st.data) == nil
		)
		-- rattrapage à la connexion : aucune victoire enregistrée -> rien
		check("œuf " .. case.label .. " : rattrapage à la connexion sans effet (none, multiplicateur 1)", Mod.new(FakeCfg).onLogin(st, sc, { userId = 7, name = "Payeur" }, T0 + 60, noWait) == "none" and SC.multiplier(sc, T0 + 60) == 1)
	end
	check("tryClaim sans table joueur : notEarned (aucune erreur)", Mod.new(FakeCfg).tryClaim(fakeStore(), SC.sanitize(nil, T0), T.sp, nil, T0, noWait) == "notEarned")
	T.st = fakeStore()
	T.scg = SC.sanitize(nil, T0)
	check("œuf gagné (g) de l'espèce en vitrine : gagné, +5 %", Mod.new(FakeCfg).tryClaim(T.st, T.scg, T.sp, { userId = 8, name = "Joueur", og = "g" }, T0, noWait) == "won" and SC.multiplier(T.scg, T0) == 1.05)
	-- Course : un payeur arrive APRÈS un gagnant : rien ne change ; un payeur arrive AVANT : le gagnant légitime reste possible.
	T.st2 = fakeStore()
	T.mod2 = Mod.new(FakeCfg)
	T.scp, T.scw = SC.sanitize(nil, T0), SC.sanitize(nil, T0)
	T.rp = T.mod2.tryClaim(T.st2, T.scp, T.sp, { userId = 9, name = "Payeur", og = "r" }, T0, noWait)
	T.rw = T.mod2.tryClaim(T.st2, T.scw, T.sp, { userId = 10, name = "Joueur", og = "c" }, T0 + 5, noWait)
	check("un œuf payé éclos en premier ne « prend » pas la vitrine : le premier œuf gagné (ici en pièces) la gagne", T.rp == "notEarned" and T.rw == "won" and T.scp.ends == 0 and T.st2.data[T.mod2.key(D0)].u == 10)
	check("rattrapage à la connexion du payeur : none (la vitrine du jour appartient à un autre)", T.mod2.onLogin(T.st2, T.scp, { userId = 9, name = "Payeur" }, T0 + 60, noWait) == "none" and T.scp.ends == 0)

	---------------------------------------------------------------- 2. Textes : chaque octroi marque son origine
	suite("Vitrine (œufs achetés exclus) : origine figée à chaque octroi (Main, HenQuest, Data)")
	local mainSrc = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
	local dataSrc = fs.readFile("roblox/src/ServerScriptService/Data.lua")
	local henSrc = fs.readFile("roblox/src/ServerScriptService/HenQuest.lua")
	check("éclosion : condition = activée ET origine admise (sl.og) ET espèce en vitrine ; og transmis à tryClaim", has(mainSrc, "Config.SHOWCASE.enabled and L15.SC.originOk(sl.og) and L15.SC.featured(p.p, os.time())") and has(mainSrc, "name = s.player.DisplayName, og = sl.og }"))
	check("boutique en pièces : og = \"c\"", has(mainSrc, 'shield = os.time() + shieldTime(s), og = "c" }'))
	check("tapis et nids : og = \"g\" sur l'œuf porté, recopié au dépôt", has(mainSrc, 'belt = true, paid = egg.price, og = "g" }') and has(mainSrc, 'os.clock()), og = "g" }') and has(mainSrc, "rvAt = e.rvAt, og = e.og }"))
	check("vol (joueur, corbeau) et retour d'un œuf : l'origine suit l'œuf (un œuf payé volé reste payé)", has(mainSrc, "rvAt = sl.rvAt, og = sl.og }") and has(mainSrc, "rvAt = now, og = f.ref.og }") and has(mainSrc, "rv = e.rv, rvAt = e.rvAt, og = e.og }"))
	check("tapis privé (passe payant) : og = \"r\"", has(mainSrc, 'rv = true, og = "r" }'))
	check("calendrier : rattrapage payant -> \"r\", sinon \"g\" ; série sauvée par produit -> \"r\"", has(mainSrc, 'applyReward(s, plan, how == "paid" and "r" or "g")') and has(mainSrc, 'L15.mkEgg(s, how == "product" and "r" or "g")'))
	check("Château, quêtes du jour, ligue, cartes de combat, victoire PvE, quêtes bonus / semaine / plumes : \"g\"",
		has(mainSrc, 'giveEgg(s, reward.eggTier, "g")') and has(mainSrc, 'giveEgg(s, q.re, "g")') and has(mainSrc, 'Lot7.L16.storeEgg(s, eggT, "g")') and has(mainSrc, 'h.where = Lot7.L16.storeEgg(s, t, "g")')
		and has(mainSrc, 'L15.storeEggs(s, { eggT }, "g")') and select(2, string.gsub(mainSrc, 'store%(s, "g"%)', "")) == 3)
	check("sac d'œufs et coffre de débordement : posés SANS origine (inconnue = exclue)", has(mainSrc, "Rewards.bagTake(d.slots, cap(s), d.eggBag, L15.mkEgg(s))") and has(mainSrc, "local where = L15.storeEggs(s, { t })\n"))
	check("achats Robux (boutique, packs, offres, passe de combat) : jamais d'origine \"g\" (L16.storeEgg sans og)", has(mainSrc, "L16.storeEgg(s, e.tier)\n") and has(mainSrc, "L16.storeEgg(s, g.tier)\n"))
	check("Mère Poule et œuf de départ : og = \"g\"", has(henSrc, 'og = "g" }') and has(dataSrc, 'rv = true, og = "g" }'))
	check("Data : og assaini (g / c / r sur un œuf, sinon retiré)", has(dataSrc, 'sl.og = (sl.k == "e" and (sl.og == "g" or sl.og == "c" or sl.og == "r")) and sl.og or nil'))
	check("Data : aucune nouvelle version pour og (14)", has(dataSrc, "local VERSION = 14\n"))

	---------------------------------------------------------------- 3. Bout en bout
	if type(env.newRuntime) ~= "function" then
		return
	end
	suite("Vitrine (œufs achetés exclus) : bout en bout (vrai Main + Data) : origine figée, sac, coffre, reçus, éclosion")
	T.RT = env.newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game })
	if not T.RT then
		return
	end
	local RT = T.RT
	local main = RT.buildTree("roblox/src", false)
	local Shared = RT.services.ReplicatedStorage:FindFirstChild("Shared")
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local cfg = RT.require(Shared:FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local ds = RT.dataStores["ChipeOeufs_v1"]
	local RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local rawProcess = RT.services.MarketplaceService.ProcessReceipt
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local function act(p, a, arg)
		RT.now = RT.now + 1.1
		RT.fire(RAction, "OnServerEvent", p, a, arg)
		RT.step(0.2)
	end
	local function receipt(p, rid, product)
		local out
		RT.task.spawn(function()
			out = rawProcess({ PlayerId = p.UserId, PurchaseId = rid, ProductId = cfg.PRODUCTS[product].id })
		end)
		RT.step(0.6)
		return out and tostring(out):find("Granted", 1, true) ~= nil
	end
	local function newEggSlots(d, before)
		local out = {}
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "e" and not before[i] then
				out[#out + 1] = i
			end
		end
		return out
	end
	local function snap(d)
		local b = {}
		for i = 1, cfg.SLOTS_MAX do
			b[i] = d.slots[i] and d.slots[i].k == "e" or false
		end
		return b
	end
	check("Démarrage sans erreur" .. errs(), #RT.errors == 0 and type(hooks) == "table" and type(hooks.showcase) == "function" and type(rawProcess) == "function")
	-- Profil sauvegardé : origines valides gardées, invalides retirées, pet nettoyé ; relu deux fois = identique.
	ds.data.P_17501 = { v = { ver = 14, coins = 100, played = 9000, hatched = 3, slots = {
		{ k = "e", t = 2, ends = 1700000000 + 1e6, shield = 0, og = "g" },
		{ k = "e", t = 2, ends = 1700000000 + 1e6, shield = 0, og = "r" },
		{ k = "e", t = 2, ends = 1700000000 + 1e6, shield = 0, og = "b" },
		{ k = "e", t = 2, ends = 1700000000 + 1e6, shield = 0, og = 5 },
		{ k = "e", t = 2, ends = 1700000000 + 1e6, shield = 0 },
	} }, t = 1700000000 + RT.now - 5000 }
	T.p1 = RT.addPlayer("ORIG", 17501, { from = "hub", partyId = "ORIG", size = 1, late = false })
	RT.step(3)
	T.s = hooks.session(T.p1)
	local d = T.s and T.s.data
	check("Migration idempotente : g et r gardés, valeur inconnue ou d'un autre type retirée, ancien slot sans origine = inconnu" .. errs(),
		d ~= nil and d.slots[1].og == "g" and d.slots[2].og == "r" and d.slots[3].og == nil and d.slots[4].og == nil and d.slots[5].og == nil and d.slots[5].k == "e")
	T.s.graceUntil, d.coins = 0, 1e15
	for i = 1, cfg.SLOTS_MAX do
		d.slots[i] = false
	end
	while #d.eggBag > 0 do
		table.remove(d.eggBag)
	end
	-- Pièces
	T.b = snap(d)
	act(T.p1, "buyEgg", 2)
	T.n = newEggSlots(d, T.b)
	check("Boutique en pièces : œuf posé avec og = \"c\"" .. errs(), #T.n == 1 and d.slots[T.n[1]].og == "c")
	T.coinSlot = T.n[1]
	-- Reçu Robux (œuf R2) : base libre -> slot SANS origine
	T.b = snap(d)
	T.ok = receipt(T.p1, "ORIG-1", "EggR2")
	T.n = newEggSlots(d, T.b)
	check("Reçu Robux EggR2 : œuf posé dans la base SANS origine (inconnue = exclue)" .. errs(), T.ok and #T.n == 1 and d.slots[T.n[1]].og == nil and d.slots[T.n[1]].t == 2)
	T.paidSlot = T.n[1]
	-- Base pleine -> reçu EggR3 va au sac ; une place libérée -> bagPlace pose l'œuf sans origine
	for i = 1, cfg.SLOTS_MAX do
		if not d.slots[i] then
			d.slots[i] = { k = "e", t = 1, ends = 1700000000 + RT.now + 1e7, shield = 0, og = "g" }
		end
	end
	T.bag0 = #d.eggBag
	T.ok = receipt(T.p1, "ORIG-2", "EggR3")
	check("Reçu EggR3 base pleine : rangé dans le sac (rareté seule, aucune origine)" .. errs(), T.ok and #d.eggBag == T.bag0 + 1 and d.eggBag[#d.eggBag] == 3)
	T.free = 3 -- capacité de départ : 4 emplacements
	d.slots[T.free] = false
	while #d.eggBag > 1 do
		table.remove(d.eggBag, 1)
	end
	act(T.p1, "bagPlace")
	check("Sac d'œufs -> base : l'œuf payé ressort SANS origine (jamais promu \"g\")" .. errs(), d.slots[T.free] and d.slots[T.free].k == "e" and d.slots[T.free].t == 3 and d.slots[T.free].og == nil)
	T.bagSlot = T.free
	-- Base ET sac pleins -> reçu EggR4 au coffre de débordement ; overflowTake pose l'œuf sans origine
	while #d.eggBag < cfg.EGG_BAG.size do
		d.eggBag[#d.eggBag + 1] = 1
	end
	for k in pairs(d.overflow) do
		d.overflow[k] = nil
	end
	T.ok = receipt(T.p1, "ORIG-3", "EggR4")
	check("Reçu EggR4 base + sac pleins : coffre de débordement" .. errs(), T.ok and d.overflow["4"] == 1)
	while #d.eggBag > 0 do
		table.remove(d.eggBag)
	end
	T.free = 4
	d.slots[T.free] = false
	-- le sac est vide : la reprise va dans la base
	act(T.p1, "overflowTake")
	check("Coffre de débordement -> base : œuf SANS origine" .. errs(), d.slots[T.free] and d.slots[T.free].k == "e" and d.slots[T.free].t == 4 and d.slots[T.free].og == nil and d.overflow["4"] == nil)
	T.ovfSlot = T.free
	-- Éclosion : vitrine activée, espèce TOUJOURS en vitrine (forcée), espion de tryClaim. Seuls les œufs gagnés (g, c) déclenchent une réclamation.
	T.SCs = hooks.showcase()
	T.oldF, T.oldT = T.SCs.featured, T.SCs.tryClaim
	T.calls = {}
	T.SCs.featured = function()
		return true
	end
	T.SCs.tryClaim = function(_, _, _, player)
		T.calls[#T.calls + 1] = player and player.og or "?"
		return "taken"
	end
	cfg.SHOWCASE.enabled = true
	T.hatchPaid = { T.paidSlot, T.bagSlot, T.ovfSlot }
	for _, i in ipairs(T.hatchPaid) do
		d.slots[i].ends = 0
	end
	RT.step(2.5)
	T.allHatched = true
	for _, i in ipairs(T.hatchPaid) do
		T.allHatched = T.allHatched and d.slots[i] and d.slots[i].k == "p"
	end
	check("Vitrine activée + espèce en vitrine : œufs du reçu Robux, sortis du sac et du coffre éclosent SANS aucune réclamation de vitrine" .. errs(), T.allHatched and #T.calls == 0 and d.showcase.ends == 0)
	d.slots[T.paidSlot] = { k = "e", t = 2, ends = 0, shield = 0, og = "r" } -- calendrier rattrapé en payant / tapis privé / série sauvée par produit
	RT.step(2.5)
	check("Œuf payé (og = r) : éclos sans réclamation" .. errs(), d.slots[T.paidSlot].k == "p" and #T.calls == 0 and d.showcase.ends == 0)
	check("…et aucun enregistrement dans le DataStore de la vitrine", RT.dataStores[cfg.SHOWCASE.storeName] == nil or next(RT.dataStores[cfg.SHOWCASE.storeName].data or {}) == nil)
	check("…ni multiplicateur de revenus (+5 %)", hooks.showcase().multiplier(d.showcase, 1700000000 + RT.now) == 1)
	d.slots[T.coinSlot].ends = 0
	d.slots[3] = { k = "e", t = 1, ends = 0, shield = 0, og = "g" }
	RT.step(2.5)
	check("Œufs gagnés (pièces c, jeu g) : réclamation tentée, avec leur origine" .. errs(), #T.calls == 2 and ((T.calls[1] == "c" and T.calls[2] == "g") or (T.calls[1] == "g" and T.calls[2] == "c")))
	cfg.SHOWCASE.enabled = false
	d.slots[4] = { k = "e", t = 1, ends = 0, shield = 0, og = "g" }
	RT.step(2.5)
	check("Vitrine désactivée (défaut) : même un œuf gagné ne déclenche rien", #T.calls == 2 and d.slots[4] and d.slots[4].k == "p")
	T.SCs.featured, T.SCs.tryClaim = T.oldF, T.oldT
	RT.removePlayer(T.p1)
	RT.step(3)
	check("Fin sans erreur" .. errs(), #RT.errors == 0)
end
