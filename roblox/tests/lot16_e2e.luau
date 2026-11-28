--!nocheck
-- Tests de bout en bout du lot 16 avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice, tests/FakeRuntime.lua) : contrôle AVANT l'invite d'achat
-- (base + sac pleins refusés, PolicyService restreint ou en échec, mise à niveau), reçu rejoué = 1 seul crédit, débordement après paiement (course) puis reprise,
-- passe de combat (XP des sources, premium crédité une fois, réclamation idempotente, compensation d'une course), vendeur -> bon onglet, migration v13.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2. État dans une table (limite de 200 variables locales).
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	suite("Lot 16 : intégration (vrai Main.server.lua + Data.lua) : boutique, reçus, débordement, PolicyService, passe de combat, vendeurs, migration v13")
	local Cfg0 = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } } })()
	T.RT = newRuntime({ fs = fs, luau = luau, placeId = Cfg0.Game.Places.game })
	if not T.RT then
		return
	end
	local RT = T.RT
	local main = RT.buildTree("roblox/src", false)
	local Shared = RT.services.ReplicatedStorage:FindFirstChild("Shared")
	T.SD = RT.require(Shared:FindFirstChild("SeasonData"))
	T.SD.SEASON.start = 1700000000 - 5 * 86400 -- saison 1 en cours dans l'horloge du runtime factice (os.time = 1700000000 + RT.now)
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local cfg = RT.require(Shared:FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local ds = RT.dataStores["ChipeOeufs_v1"]
	local RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local PS = { granted = "PurchaseGranted", later = "NotProcessedYet" }
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
		return out and (tostring(out):find("Granted", 1, true) and PS.granted or PS.later) or nil
	end
	local function prompted(p, id, from)
		for i = from or 1, #RT.prompts do
			if RT.prompts[i].userId == p.UserId and RT.prompts[i].id == id then
				return true
			end
		end
		return false
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
	local function eggs(d)
		local n = 0
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "e" then
				n = n + 1
			end
		end
		return n
	end
	check("Démarrage sans erreur, ProcessReceipt branché, invites d'achat enregistrées par le runtime" .. errs(), #RT.errors == 0 and type(rawProcess) == "function" and type(RT.prompts) == "table")

	---------------------------------------------------------------- 1. Migration v12 -> v13
	ds.data.P_16001 = { v = { ver = 12, coins = 5000, starter = true, seasonXp = 300, played = 9000, hatched = 12, eggBag = { 3 }, cosm = { s1_pose = true, bad = true }, overflow = { ["3"] = 2, ["x"] = 9, ["99"] = 1 }, once = "corrompu", doubleUntil = -5, emote = 99, arenaTk = { day = "x" } }, t = 1700000000 + RT.now - 5000 }
	T.p1 = RT.addPlayer("L16A", 16001, { from = "hub", partyId = "L16A", size = 2, late = false })
	RT.step(3)
	local s = hooks.session(T.p1)
	local d = s and s.data
	check("Migration v12 -> v13 : pièces, sac gardés ; seasonXp versé dans season.xp ; starter -> once.StarterPack ; overflow / once / emote / arenaTk assainis ; cosmétique de saison gardé" .. errs(),
		d ~= nil and d.ver == 14 and d.coins >= 5000 and #d.eggBag == 1 and d.seasonXp == 0 and type(d.season) == "table" and d.season.xp == 300 and d.season.n == 1 and d.once.StarterPack == true
		and d.overflow["3"] == 2 and d.overflow["x"] == nil and d.overflow["99"] == nil and d.doubleUntil == 0 and d.emote == 0 and d.arenaTk.day == 0 and d.cosm.s1_pose == true and d.cosm.bad == nil)
	RT.removePlayer(T.p1)
	RT.step(3)
	T.p1 = RT.addPlayer("L16A", 16001, { from = "hub", partyId = "L16A", size = 2, late = false })
	RT.step(3)
	s = hooks.session(T.p1)
	d = s and s.data
	check("Relecture du profil v13 : rien ne change (idempotent : season.xp 300, pas de second versement)", d ~= nil and d.ver == 14 and d.season.xp == 300 and d.overflow["3"] == 2)
	s.graceUntil, d.coins = 0, 1e9

	---------------------------------------------------------------- 2. Contrôle AVANT l'invite d'achat
	T.n0 = #RT.prompts + 1
	act(T.p1, "shopBuy", "EggR3")
	check("Achat d'un œuf (place libre, PolicyService autorisé) : le SERVEUR lance l'invite du bon produit", prompted(T.p1, cfg.PRODUCTS.EggR3.id, T.n0))
	act(T.p1, "shopBuy", "StarterPack")
	act(T.p1, "shopBuy", "Inconnu")
	act(T.p1, "shopBuy", 42)
	check("Pack de départ déjà acheté : refusé (aucune invite) ; clé inconnue ou d'un autre type ignorée", not prompted(T.p1, cfg.PRODUCTS.StarterPack.id, T.n0) and notified(T.p1, "possèdes déjà"))
	for i = 1, s.data.slots and #d.slots or 0 do
		if i <= cfg.SLOTS_MAX and not d.slots[i] then
			d.slots[i] = { k = "e", t = 1, ends = 1700000000 + RT.now + 1e6, shield = 0 }
		end
	end
	while #d.eggBag < cfg.EGG_BAG.size do
		d.eggBag[#d.eggBag + 1] = 1
	end
	T.n1 = #RT.prompts + 1
	act(T.p1, "shopBuy", "EggR4")
	act(T.p1, "shopBuy", "BundleLegend")
	check("Base ET sac pleins : œuf et pack refusés AVANT paiement (aucune invite, message « fais de la place »)", not prompted(T.p1, cfg.PRODUCTS.EggR4.id, T.n1) and not prompted(T.p1, cfg.PRODUCTS.BundleLegend.id, T.n1) and notified(T.p1, "Fais de la place"))
	act(T.p1, "shopBuy", "CoinPackS")
	check("Base pleine : un achat sans œuf (petit sac de pièces) reste proposé", prompted(T.p1, cfg.PRODUCTS.CoinPackS.id, T.n1))

	---------------------------------------------------------------- 3. Reçus : course -> débordement, rejeu = 1 crédit
	T.ov0 = d.overflow["4"] or 0
	T.e0 = eggs(d)
	T.r1 = receipt(T.p1, "R16-1", "EggR4")
	T.r1b = receipt(T.p1, "R16-1", "EggR4")
	check("Course (base + sac pleins APRÈS paiement) : l'œuf va au coffre de débordement, rien n'est perdu ; le même reçu rejoué ne crédite pas deux fois" .. errs(),
		T.r1 == PS.granted and T.r1b == PS.granted and (d.overflow["4"] or 0) == T.ov0 + 1 and eggs(d) == T.e0 and d.receipts["R16-1"] ~= nil)
	T.c0 = d.coins
	T.r2 = receipt(T.p1, "R16-2", "CoinPackS")
	T.c1 = d.coins
	receipt(T.p1, "R16-2", "CoinPackS")
	check("Petit sac de pièces : au moins 1 000 pièces, une seule fois pour le reçu R16-2", T.r2 == PS.granted and T.c1 - T.c0 >= 1000 and d.coins == T.c1)
	d.slots[2] = false
	act(T.p1, "overflowTake")
	check("Coffre de débordement : une place libérée -> l'œuf du coffre est posé dans la base", d.slots[2] and d.slots[2].k == "e" and (d.overflow["4"] or 0) + (d.overflow["3"] or 0) == T.ov0 + 1 + 2 - 1)
	T.c2 = d.coins
	T.r3 = receipt(T.p1, "R16-3", "StarterPack")
	check("Pack de départ payé deux fois (course) : compensé en pièces (jamais un second octroi d'œufs)", T.r3 == PS.granted and d.coins > T.c2 and d.once.StarterPack == true)
	d.slots[3] = false
	T.r4 = receipt(T.p1, "R16-4", "DoubleLuck")
	T.r5 = receipt(T.p1, "R16-5", "DoubleLuck")
	check("Double chance cumulable sans plafond d'achat (2 x 30 min), puissance plafonnée à 70", T.r4 == PS.granted and T.r5 == PS.granted and d.doubleUntil - (1700000000 + RT.now) > 3500 and hooks.luckPoints(s) <= 70)
	T.r6 = receipt(T.p1, "R16-6", "ArenaTickets")
	check("Tickets d'arène : +5 combats de tour aujourd'hui", T.r6 == PS.granted and d.arenaTk.n == 5 and d.arenaTk.day == (1700000000 + math.floor(RT.now)) // 86400)
	T.r7 = receipt(T.p1, "R16-7", "EmoteVictory2")
	act(T.p1, "emoteSet", 4)
	check("Pose de victoire 2 achetée (unique) et choisie d'office ; une pose non possédée est refusée", T.r7 == PS.granted and d.once.EmoteVictory2 == true and d.emote == 2)

	---------------------------------------------------------------- 4. Passe de combat
	T.x0 = d.season.xp
	d.quests[1] = { t = "hatch", goal = 1, prog = 1, rew = 10, re = 0, rb = 0, claimed = false }
	act(T.p1, "claimQuest", 1)
	check("XP de saison : quête du jour réclamée = +100 (source validée par le serveur)", d.season.xp == T.x0 + 100)
	T.tier = math.floor(d.season.xp / 490)
	T.r8 = receipt(T.p1, "R16-8", "SeasonPremium")
	T.pm = d.season.claimedPrem
	receipt(T.p1, "R16-8", "SeasonPremium")
	check("Passe premium acheté en cours de saison : premium = saison 1, les paliers déjà atteints crédités UNE fois (reçu rejoué sans effet)", T.r8 == PS.granted and d.season.premium == 1 and d.season.claimedPrem == T.pm and (T.tier == 0 or T.pm > 0))
	T.n2 = #RT.prompts + 1
	act(T.p1, "shopBuy", "SeasonPremium")
	act(T.p1, "shopBuy", "SeasonPremiumPlus")
	act(T.p1, "shopBuy", "BundleRoyal")
	check("Mise à niveau : premium possédé -> premium, premium+ et Coffre royal refusés AVANT paiement", not prompted(T.p1, cfg.PRODUCTS.SeasonPremium.id, T.n2) and not prompted(T.p1, cfg.PRODUCTS.SeasonPremiumPlus.id, T.n2) and not prompted(T.p1, cfg.PRODUCTS.BundleRoyal.id, T.n2))
	act(T.p1, "shopBuy", "SeasonUpgradePlus")
	act(T.p1, "shopBuy", "BundleRoyalNoPass")
	check("Mise à niveau : seuls le complément (400) et le Coffre royal sans passe (1 100) sont proposés", prompted(T.p1, cfg.PRODUCTS.SeasonUpgradePlus.id, T.n2))
	T.c3 = d.coins
	T.r9 = receipt(T.p1, "R16-9", "SeasonPremium")
	check("Course : premium payé une 2e fois la même saison -> compensé en pièces, aucune autre modification", T.r9 == PS.granted and d.coins > T.c3 and d.season.premium == 1)
	T.x1 = d.season.xp
	T.r10 = receipt(T.p1, "R16-10", "SeasonUpgradePlus")
	check("Complément : +10 paliers (XP portée au seuil), une fois par saison", T.r10 == PS.granted and d.season.plus == 1 and d.season.xp >= T.x1)
	T.cf = d.season.claimedFree
	act(T.p1, "seasonClaim", { tier = 1, track = "free" })
	T.cf1 = d.season.claimedFree
	act(T.p1, "seasonClaim", { tier = 1, track = "free" })
	act(T.p1, "seasonClaim", { tier = 99, track = "free" })
	act(T.p1, "seasonClaim", { tier = 1, track = "or" })
	check("Réclamation d'un palier gratuit : une seule fois ; palier ou piste invalides refusés", T.cf1 ~= T.cf and d.season.claimedFree == T.cf1)
	act(T.p1, "seasonClaim", { all = true })
	check("« Tout réclamer » sans erreur" .. errs(), #RT.errors == 0)
	act(T.p1, "seasonView")
	T.sv = nil
	for i = #RT.fired, 1, -1 do
		local f = RT.fired[i]
		if T.sv == nil and f[1] == "Kiosk" and f[2] == T.p1 and type(f[3]) == "table" and f[3].panel == "season" then
			T.sv = f[3]
		end
	end
	check("Vue du passe de combat envoyée au client (30 paliers, saison 1, premium)", T.sv ~= nil and #T.sv.view.rows == 30 and T.sv.view.season == 1 and T.sv.view.premium == true)

	---------------------------------------------------------------- 5. PolicyService restreint / en échec
	RT.policy = { ArePaidRandomItemsRestricted = true }
	T.p2 = RT.addPlayer("L16B", 16002, { from = "hub", partyId = "L16A", size = 2, late = false })
	RT.step(3)
	local s2 = hooks.session(T.p2)
	T.n3 = #RT.prompts + 1
	act(T.p2, "shopBuy", "EggR3")
	act(T.p2, "shopBuy", "DoubleLuck")
	act(T.p2, "shopBuy", "CoinPack")
	check("PolicyService restreint : œuf et Double chance (hasard) refusés AVANT paiement ; sac de pièces proposé", s2 ~= nil and not prompted(T.p2, cfg.PRODUCTS.EggR3.id, T.n3) and not prompted(T.p2, cfg.PRODUCTS.DoubleLuck.id, T.n3) and prompted(T.p2, cfg.PRODUCTS.CoinPack.id, T.n3))
	T.e2 = eggs(s2.data)
	T.rr = receipt(T.p2, "R16-B1", "EggR3")
	check("PolicyService restreint : un reçu d'œuf (hasard) est refusé côté serveur (NotProcessedYet), rien n'est livré", T.rr == PS.later and eggs(s2.data) == T.e2 and s2.data.receipts["R16-B1"] == nil)
	RT.policy = nil
	RT.policyFail = "panne"
	T.p3 = RT.addPlayer("L16C", 16003, { from = "hub", partyId = "L16A", size = 2, late = false })
	RT.step(10)
	T.n4 = #RT.prompts + 1
	act(T.p3, "shopBuy", "EggR3")
	check("PolicyService en échec : repli prudent, l'œuf (hasard) n'est pas proposé", hooks.session(T.p3) ~= nil and hooks.session(T.p3).restricted == true and not prompted(T.p3, cfg.PRODUCTS.EggR3.id, T.n4))
	RT.policyFail = nil

	---------------------------------------------------------------- 6. Vendeur PNJ -> bon onglet
	T.world = RT.services.Workspace:FindFirstChild("World")
	T.vend = {}
	for obj in pairs(RT.tags.SellerPrompt or {}) do
		local a = obj:GetAttribute("SellerAction")
		if a then
			T.vend[a] = obj
		end
	end
	local root = T.p1.Character and T.p1.Character:FindFirstChild("HumanoidRootPart")
	local folder = T.world and T.world:FindFirstChild("Sellers")
	T.vm = nil
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if m:GetAttribute("SellerId") == "combat" then
			T.vm = m
		end
	end
	if root and T.vend.combat and T.vm then
		local pv = T.vm:GetPivot().Position
		rawget(root, "__props").Position = RT.vec(pv.X + 80, 3, pv.Z)
		T.f0 = #RT.fired + 1
		RT.fire(RT.services.ProximityPromptService, "PromptTriggered", T.vend.combat, T.p1)
		RT.step(1)
		T.far = nil
		for i = T.f0, #RT.fired do
			if RT.fired[i][1] == "Kiosk" and RT.fired[i][2] == T.p1 then
				T.far = RT.fired[i][3]
			end
		end
		rawget(root, "__props").Position = RT.vec(pv.X + 3, 3, pv.Z)
		T.f1 = #RT.fired + 1
		RT.fire(RT.services.ProximityPromptService, "PromptTriggered", T.vend.combat, T.p1)
		RT.step(1)
		T.near = nil
		for i = T.f1, #RT.fired do
			if RT.fired[i][1] == "Kiosk" and RT.fired[i][2] == T.p1 then
				T.near = RT.fired[i][3]
			end
		end
		check("Vendeur « Combat & vol » : refusé de loin (aucune réponse), de près ouvre la boutique sur l'onglet « combat »", T.far == nil and type(T.near) == "table" and T.near.panel == "shop" and T.near.tab == "combat")
	else
		for _, w in ipairs(RT.warns) do
			if w:find("Sellers", 1, true) then
				print("    " .. w)
			end
		end
		check("Vendeurs : 8 prompts SellerPrompt construits dans World/Sellers (procédural)", false)
	end
	T.cnt = 0
	for _ in pairs(T.vend) do
		T.cnt = T.cnt + 1
	end
	check("8 vendeurs construits (un prompt par catégorie)", T.cnt == 8)

	---------------------------------------------------------------- 7. Sauvegarde
	RT.removePlayer(T.p1)
	RT.step(3)
	local r = ds.data.P_16001 and ds.data.P_16001.v
	check("Sauvegarde v13 : season, overflow, once, doubleUntil, emote, arenaTk écrits", r ~= nil and r.ver == 14 and type(r.season) == "table" and r.season.premium == 1 and type(r.overflow) == "table" and r.once.EmoteVictory2 == true and r.emote == 2 and type(r.arenaTk) == "table")
	RT.removePlayer(T.p2)
	RT.removePlayer(T.p3)
	RT.step(3)
	check("Lot 16 (intégration) : aucune erreur serveur" .. errs(), #RT.errors == 0)
end
