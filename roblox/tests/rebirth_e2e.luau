--!nocheck
-- Non-régression de la renaissance (actions.rebirth) avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice, tests/FakeRuntime.lua).
-- Profil riche (champs des lots 8 à 16) -> renaissance -> tout ce qui est permanent est intact (achats uniques, saison, calendrier, série, quêtes de la semaine,
-- plumes d'événement, sac d'œufs, coffre de débordement, PNJ, réglages, ligues, jetons, titres, cosmétiques, boosts payés), seuls les champs de la liste
-- blanche (pièces, améliorations, emplacements, suiveurs, gains hors ligne) repartent de zéro ; aucun achat unique rachetable ; aucune duplication d'œuf.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2. État dans une table (limite de 200 variables locales).
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	suite("Renaissance (vrai Main.server.lua + Data.lua) : champs permanents des lots 8 à 16 conservés, liste blanche remise à zéro")
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
	T.SD.SEASON.start = 1700000000 - 5 * 86400 -- saison 1 en cours dans l'horloge du runtime factice
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(1)
	local cfg = RT.require(Shared:FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local RAction = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local function act(p, a, arg)
		RT.now = RT.now + 1.1
		RT.fire(RAction, "OnServerEvent", p, a, arg)
		RT.step(0.2)
	end
	local function copy(v)
		if type(v) ~= "table" then
			return v
		end
		local o = {}
		for k, x in pairs(v) do
			o[k] = copy(x)
		end
		return o
	end
	local function same(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, x in pairs(a) do
			if not same(x, b[k]) then
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
	local function eggCount(d)
		local n = #d.eggBag
		for i = 1, cfg.SLOTS_MAX do
			if d.slots[i] and d.slots[i].k == "e" then
				n = n + 1
			end
		end
		for _, c in pairs(d.overflow) do
			n = n + c
		end
		return n
	end

	T.p = RT.addPlayer("RB", 17001, { from = "hub", partyId = "RB", size = 1, late = false })
	RT.step(3)
	local s = hooks.session(T.p)
	local d = s and s.data
	check("Session ouverte" .. errs(), d ~= nil)
	if not d then
		return
	end
	s.graceUntil = 0
	local now = 1700000000 + math.floor(RT.now)
	-- profil riche : un champ de chaque lot (valeurs reconnaissables)
	d.coins = cfg.rebirthCost(d.rb) + 12345
	d.once = { StarterPack = true, EmoteVictory2 = true, BundleRoyal = true }
	d.starter = true
	d.season.xp, d.season.premium, d.season.claimedFree = 777, d.season.n, 3
	d.cal.days = 9
	d.calStreak, d.calLast = 7, now - 86400
	d.grace = { g = 1, w = 2, last = 5, r = 0 }
	d.weekly.prog = 4
	d.event.p, d.event.x = 77, 1
	d.eggBag = { 3, 4 }
	d.overflow = { ["5"] = 1 }
	d.npc.off = true
	d.settings.duelOff, d.settings.blockFriendRavens = true, true
	d.battle.best, d.battle.pvp.trophies, d.battle.duel.w = 12, 900, 4
	d.tokens.remoteSteal = 3
	d.scrolls, d.plumes, d.fightTokens = 5, 9, 2
	d.titles.cal10, d.titles.oldCosmic = true, true
	d.cosm = { s1_pose = true, s1_trail = true }
	d.emote, d.doubleUntil, d.xp2Until = 2, now + 999, now + 444
	d.boosts = { luck10 = now + 500 }
	d.trainer = { xp = 1234 }
	d.arenaTk = { day = math.floor(now / 86400), n = 2 }
	d.played, d.newbieOff = 99999, true
	d.receipts = { R1 = now }
	d.ach = { hatch = 2 }
	d.secrets = { s1 = 10 }
	d.dex = { ["1"] = { n = 3 } }
	d.stealLog = { { n = "x", t = 2, at = now, k = "p" } }
	d.raven = { day = 1, n = 1, cd = 0, sh = 0, ic = 0, icDay = 0 }
	d.srvBuff = { g = now + 10, l = 0 }
	d.pb = { 2 }
	d.firstSeen = 19000
	d.up[cfg.UPGRADES[1].key] = 3
	d.slots[2] = { k = "p", p = 4, s = 2, m = 1 }
	d.slots[3] = { k = "e", t = 3, ends = now + 100, shield = 0 }
	d.equip = { 2 }
	d.pendingAway = 5000
	T.rb0 = d.rb
	T.bag0, T.over0 = #d.eggBag, copy(d.overflow)
	T.KEEP = { "once", "starter", "season", "cal", "calStreak", "calLast", "grace", "weekly", "event", "eggBag", "overflow", "npc", "settings", "battle", "tokens", "scrolls", "plumes",
		"fightTokens", "titles", "cosm", "emote", "doubleUntil", "xp2Until", "boosts", "trainer", "arenaTk", "played", "newbieOff", "receipts", "ach", "secrets", "dex", "stealLog",
		"raven", "srvBuff", "pb", "firstSeen", "speed", "daily", "streak", "stolen", "hatched", "quests", "qday", "luckUntil", "story", "pity", "puzzle", "cine", "baseLevelFloor", "baseScore" }
	T.before = {}
	for _, k in ipairs(T.KEEP) do
		T.before[k] = copy(d[k])
	end
	act(T.p, "rebirth")
	d = s.data
	T.lost = {}
	for _, k in ipairs(T.KEEP) do
		if not same(T.before[k], d[k]) then
			T.lost[#T.lost + 1] = k
		end
	end
	check("Renaissance faite : rb + 1, pièces au départ, améliorations à 0, base vidée (œuf de départ seul), aucun suiveur, gains hors ligne remis à 0" .. errs(),
		d.rb == T.rb0 + 1 and d.coins == cfg.START_COINS and d.up[cfg.UPGRADES[1].key] == 0 and not d.slots[2] and not d.slots[3] and d.slots[1] and d.slots[1].k == "e" and d.slots[1].t == 1
			and #d.equip == 0 and d.pendingAway == 0)
	check("Tous les champs permanents intacts (achats uniques, saison, calendrier, série, semaine, événement, sac, débordement, PNJ, réglages, ligues, jetons, titres, cosmétiques, boosts...)"
		.. (#T.lost == 0 and "" or (" : perdus " .. table.concat(T.lost, ", "))), #T.lost == 0)
	check("Aucune duplication d'œuf : sac et coffre de débordement identiques, la base ne garde que l'œuf de départ gratuit (non indemnisable)",
		#d.eggBag == T.bag0 and same(d.overflow, T.over0) and eggCount(d) == T.bag0 + 1 + 1 and d.slots[1].rv == true)
	T.n0 = #RT.prompts + 1
	act(T.p, "shopBuy", "StarterPack")
	local promptedStarter = false
	for i = T.n0, #RT.prompts do
		if RT.prompts[i].userId == T.p.UserId and RT.prompts[i].id == cfg.PRODUCTS.StarterPack.id then
			promptedStarter = true
		end
	end
	check("Après renaissance : Pack de départ toujours possédé (aucune invite d'achat, jamais rachetable)", not promptedStarter and d.once.StarterPack == true)
	-- seconde renaissance trop pauvre : refusée, rien ne change
	T.rb1 = d.rb
	act(T.p, "rebirth")
	check("Renaissance sans assez de pièces : refusée, rien ne change", s.data.rb == T.rb1 and s.data.once.StarterPack == true)
	RT.removePlayer(T.p)
	RT.step(3)
	check("Renaissance : aucune erreur serveur" .. errs(), #RT.errors == 0)
end
