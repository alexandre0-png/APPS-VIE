--!nocheck
-- A11 : quêtes du jour duel, typeWin, odds, pve, npcTrade (Config.QUESTS.newTypes) : règles pures (Rewards.newQuestGoal / teamHasType / questKinds, Config.questText)
-- puis bout en bout avec le VRAI Main.server.lua et le VRAI Data.lua (runtime factice) : tirage des quêtes, éclosion « 1 sur 1 000 », branchement des 5 événements.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau ou tests/run_quests.py).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, pas de math.random (Park-Miller 48271 mod 2^31-1). État dans une table.
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	local COLOR = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
	local Cfg = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = { Color3 = COLOR } })()
	local Rewards = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Rewards.lua"), { debugName = "Rewards" })()

	---------------------------------------------------------------- 1. Règles pures
	suite("A11 : quêtes du jour duel, typeWin, odds, pve, npcTrade (règles pures)")
	local NEW = { "duel", "typeWin", "odds", "pve", "npcTrade" }
	local okGoal, okText = true, true
	for _, t in ipairs(NEW) do
		local goals = Cfg.QUESTS.newTypes[t].goals
		local seed = 4242
		for _ = 1, 2000 do
			seed = (seed * 48271) % 2147483647
			local g = Rewards.newQuestGoal(Cfg, t, (seed - 1) / 2147483646)
			local found = false
			for _, x in ipairs(goals) do
				if x == g then
					found = true
				end
			end
			if not found then
				okGoal = false
			end
		end
		if Rewards.newQuestGoal(Cfg, t, 0) ~= goals[1] or Rewards.newQuestGoal(Cfg, t, 0.9999999) ~= goals[#goals] then
			okGoal = false
		end
		local txt = Cfg.questText(t, 2)
		if txt == t or txt:find("{", 1, true) or (t ~= "odds" and not txt:find("2", 1, true)) then
			okText = false
		end
	end
	check("newQuestGoal : objectif toujours pris dans Config.QUESTS.newTypes[t].goals (bornes comprises) ; nil pour un ancien type ou un type inconnu",
		okGoal and Rewards.newQuestGoal(Cfg, "steal", 0.5) == nil and Rewards.newQuestGoal(Cfg, "x", 0.5) == nil and Rewards.newQuestGoal(Cfg, "pve", 0 / 0) == 2)
	check("questText : texte lisible pour les 5 types (nombre inséré sauf « odds » à objectif fixe, aucun « {n} » restant), anciens types inchangés", okText and Cfg.questText("hatch", 4) == "Faire éclore 4 œufs")
	local function kinds(kind, info)
		local out = {}
		for _, e in ipairs(Rewards.questKinds(Cfg, kind, info)) do
			out[#out + 1] = e[1] .. "+" .. e[2]
		end
		return table.concat(out, ",")
	end
	local team = { { type = "Feu" }, { type = "Nature" } }
	check("pveWin récompensée : pve +1 ; typeWin +1 seulement avec un pet du type de la semaine (Nature = Plante)",
		kinds("pveWin", { rewarded = true, units = team, weekType = "Eau" }) == "pve+1" and kinds("pveWin", { rewarded = true, units = team, weekType = "Plante" }) == "pve+1,typeWin+1"
			and kinds("pveWin", { rewarded = true, units = team, weekType = "Feu" }) == "pve+1,typeWin+1")
	check("pveWin non récompensée (rejeu de tour au-delà de la limite) : rien ne compte", kinds("pveWin", { rewarded = false, units = team, weekType = "Feu" }) == "" and kinds("pveWin", nil) == "")
	check("duelPaid : +1 seulement pour un duel payé (pièces > 0 : plafonds jour / paire, abandon précoce = 0)", kinds("duelPaid", { coins = 120 }) == "duel+1" and kinds("duelPaid", { coins = 0 }) == "" and kinds("duelPaid", {}) == "")
	check("hatch : odds +1 si le compteur de référence >= 1 000 (Config.ODDS.billboardMin), sinon rien", kinds("hatch", { odds = 1000 }) == "odds+1" and kinds("hatch", { odds = 999 }) == "" and kinds("hatch", { odds = nil }) == "" and kinds("hatch", { odds = 0 / 0 }) == "")
	check("npcTrade : +1 par échange conclu ; type inconnu = rien", kinds("npcTrade") == "npcTrade+1" and kinds("inconnu", {}) == "")
	check("teamHasType : entrées invalides sans erreur", Rewards.teamHasType(nil, "Feu") == false and Rewards.teamHasType({ 1, "x" }, "Feu") == false and Rewards.teamHasType(team, nil) == false)

	---------------------------------------------------------------- 2. Bout en bout (vrai Main + Data)
	suite("A11 : quêtes du jour (vrai Main.server.lua + Data.lua) : tirage, éclosion « 1 sur 1 000 », branchement des événements")
	local main = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
	check("Main : QUEST_TYPES contient duel, typeWin, odds, pve, npcTrade", main:find('"duel", "typeWin", "odds", "pve", "npcTrade" }', 1, true) ~= nil)
	check("Main : un appel par événement serveur (éclosion, tour récompensé, PNJ gagné, duel payé, échange de PNJ)",
		select(2, main:gsub('L15%.qk%(s, "hatch"', "")) == 1 and select(2, main:gsub('L15%.qk%(s, "pveWin"', "")) == 2 and select(2, main:gsub('L15%.qk%(me, "duelPaid"', "")) == 1 and select(2, main:gsub('L15%.qk%(s, "npcTrade"%)', "")) == 1)
	-- le qk du tour est DANS la branche récompensée (premier passage ou rejeu dans la limite), jamais avant
	local a = main:find("if first or b.repeats < TW.dailyRepeats", 1, true)
	local b = a and main:find('L15.qk(s, "pveWin"', a, true)
	local c = a and main:find("rewards.limited = true", a, true)
	check("Main : la quête PvE de la tour n'avance que dans la branche récompensée (aucun gain en rejouant le même étage au-delà de la limite)", a ~= nil and b ~= nil and c ~= nil and b < c)
	local e = main:find("if coins > 0 then\n\t\t\t\t\tL15.qk(me, \"duelPaid\"", 1, true)
	check("Main : la quête duel n'avance que pour un duel payé (même paire : 3 par jour au plus, Duel.settle)", e ~= nil)

	T.RT = newRuntime({ fs = fs, luau = luau, placeId = Cfg.Game.Places.game })
	if not T.RT then
		return
	end
	local RT = T.RT
	local tree = RT.buildTree("roblox/src", false)
	local SD = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("SeasonData"))
	SD.SEASON.start = 1700000000 - 5 * 86400 -- saison 1 en cours dans l'horloge du runtime factice
	RT.task.spawn(function()
		RT.runScript(tree)
	end)
	RT.step(1)
	local Shared = RT.services.ReplicatedStorage:FindFirstChild("Shared")
	local cfg = RT.require(Shared:FindFirstChild("Config"))
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	check("Démarrage du serveur sans erreur" .. errs(), hooks ~= nil and #RT.errors == 0)
	if not hooks then
		return
	end
	T.p = RT.addPlayer("QA", 18001, { from = "hub", partyId = "QA", size = 1, late = false })
	RT.step(3)
	local s = hooks.session(T.p)
	local d = s and s.data
	check("Session ouverte" .. errs(), d ~= nil)
	if not d then
		return
	end
	-- tirage réel des quêtes : sur 40 jours simulés, des nouveaux types apparaissent, chacun avec un objectif de newTypes et un texte
	T.seen, T.badQ = {}, false
	for _ = 1, 40 do
		d.qday = 0
		RT.step(0.3)
		for _, q in ipairs(d.quests) do
			T.seen[q.t] = true
			local nt = cfg.QUESTS.newTypes[q.t]
			if nt then
				local ok = false
				for _, g in ipairs(nt.goals) do
					if g == q.goal then
						ok = true
					end
				end
				if not ok or q.prog ~= 0 or cfg.questText(q.t, q.goal) == q.t then
					T.badQ = true
				end
			end
		end
	end
	T.nNew = 0
	for _, t in ipairs(NEW) do
		if T.seen[t] then
			T.nNew = T.nNew + 1
		end
	end
	check("Tirage serveur (40 jours) : au moins 3 des 5 nouveaux types tirés, objectifs et textes valides (" .. T.nNew .. "/5)" .. errs(), T.nNew >= 3 and not T.badQ)
	-- quêtes imposées : les 5 nouveaux types, puis une éclosion Ultra Rare (compteur de référence toujours >= 1 000 : 3 espèces à 0,21 %)
	local function setQuests()
		d.quests = {}
		for _, t in ipairs(NEW) do
			d.quests[#d.quests + 1] = { t = t, goal = 2, prog = 0, rew = 1, re = 0, rb = 0, claimed = false }
		end
		d.qday = (1700000000 + math.floor(RT.now)) // 86400
	end
	local function prog(t)
		for _, q in ipairs(d.quests) do
			if q.t == t then
				return q.prog
			end
		end
		return -1
	end
	setQuests()
	d.slots[2] = { k = "e", t = 7, ends = 0, shield = 0 }
	RT.step(1.5)
	T.o = d.slots[2] and d.slots[2].o
	check("Éclosion Ultra Rare : pet posé, compteur de référence >= 1 000, quête « odds » +1 (une seule fois), autres quêtes intactes" .. errs(),
		d.slots[2] and d.slots[2].k == "p" and type(T.o) == "number" and T.o >= 1000 and prog("odds") == 1 and prog("duel") == 0 and prog("pve") == 0 and prog("typeWin") == 0 and prog("npcTrade") == 0)
	RT.step(2)
	check("Pas de double progression : rien ne bouge sans nouvel événement", prog("odds") == 1)
	RT.removePlayer(T.p)
	RT.step(3)
	check("A11 : aucune erreur serveur" .. errs(), #RT.errors == 0)
end
