--!nocheck
-- Tests du lot 17 (idée 1 : onboarding des 5 premières minutes) : partie PURE (Onboarding.lua : états, transitions, textes, garde-fous, migration idempotente)
-- puis intégration avec le VRAI Main.server.lua + Data.lua dans le runtime factice (séquence réelle, « Passer », rebirth, reconnexion, profil v13 existant).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (voir run_onboarding.py). Style : pas de `+=`, pas de `continue`, état dans une table.
return function(env)
	local check, suite, fs, luau, newRuntime = env.check, env.suite, env.fs, env.luau, env.newRuntime
	local T = {}
	local Onboarding = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Onboarding.lua"), { debugName = "Onboarding" })()
	local Cfg0 = luau.load(
		fs.readFile("roblox/src/ReplicatedStorage/Config.lua"),
		{ debugName = "Config", environment = { Color3 = {
			fromRGB = function(r, g, b)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
		} } }
	)()
	local function deep(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, v in pairs(a) do
			if not deep(v, b[k]) then
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
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end

	---------------------------------------------------------------- 1. Contenu de la séquence
	suite("Lot 17 : séquence fixe de 5 étapes, textes, configuration")
	local O = Onboarding.new(Cfg0.ONBOARDING)
	check(
		"Config.ONBOARDING présent (enabled, stepSeconds = 45, minDwell, earnGoal, houseLevel >= 2)",
		type(Cfg0.ONBOARDING) == "table" and Cfg0.ONBOARDING.enabled == true and Cfg0.ONBOARDING.stepSeconds == 45 and Cfg0.ONBOARDING.houseLevel >= 2
	)
	check(
		"Exactement 5 étapes dans l'ordre œuf offert / éclosion / revenu / maison / arène",
		O.TOTAL == 5 and O.STEPS[1].id == "gift" and O.STEPS[2].id == "hatch" and O.STEPS[3].id == "income" and O.STEPS[4].id == "house" and O.STEPS[5].id == "arena"
	)
	T.bad = {}
	for i, st in ipairs(O.STEPS) do
		if type(st.text) ~= "string" or #st.text < 10 or type(st.hint) ~= "string" or #st.hint < 10 or st.text == st.hint or #st.text > 90 or #st.hint > 90 then
			T.bad[#T.bad + 1] = i
		end
		if st.kind ~= "tick" and st.kind ~= "earn" and st.kind ~= "arena" then
			T.bad[#T.bad + 1] = "kind" .. i
		end
	end
	check("Chaque étape a un texte et une aide distincts (10 à 90 caractères) et un type d'événement connu (" .. table.concat(T.bad, ",") .. ")", #T.bad == 0)
	check("Durée visée par étape : stepSeconds <= 45", O.cfg.stepSeconds <= 45 and Onboarding.DEFAULTS.stepSeconds <= 45)
	check(
		"Config absente ou corrompue : valeurs par défaut sûres",
		(function()
			local a, b, c = Onboarding.new(nil), Onboarding.new({ stepSeconds = -3, earnGoal = 0 / 0, houseLevel = 1, minDwell = "x" }), Onboarding.new("zzz")
			return a.cfg.stepSeconds == 45 and b.cfg.stepSeconds == 45 and b.cfg.earnGoal == 10 and b.cfg.houseLevel == 2 and b.cfg.minDwell == 3 and c.cfg.earnGoal == 10
		end)()
	)

	---------------------------------------------------------------- 2. Transitions et garde-fous
	suite("Lot 17 : transitions, une étape ne se valide que par l'action réelle attendue")
	local st = O.default()
	check(
		"Séquence neuve : étape 1, active, vue = étape 1/5 avec flèche vers la base",
		O.status(st) == "active" and st.step == 1 and st.v == 1 and O.view(st, 100).index == 1 and O.view(st, 100).total == 5 and O.view(st, 100).target == "home"
	)
	check(
		"Aucun événement avant le démarrage ne valide : le premier démarre l'étape (at posé), même avec le fait vrai",
		(function()
			local ok, why = O.event(st, "tick", { near = true }, 1000)
			return ok == false and why == "dwell" and st.at == 1000 and st.step == 1
		end)()
	)
	check(
		"Pas de validation avant minDwell (2 s), validation à 3 s",
		(function()
			local ok1 = O.event(st, "tick", { near = true }, 1002)
			local ok2, info = O.event(st, "tick", { near = true }, 1003)
			return ok1 == false and ok2 == true and info == "step" and st.step == 2 and st.at == 1003
		end)()
	)
	-- étape 2 : un clic libre ou un mauvais type d'événement ne valide rien
	check(
		"Étape 2 : événements d'un autre type (earn, arena) ignorés",
		(function()
			local a, ra = O.event(st, "earn", 50, 1100)
			local b, rb = O.event(st, "arena", nil, 1100)
			return a == false and ra == "wrong_step" and b == false and rb == "wrong_step" and st.step == 2
		end)()
	)
	check(
		"Étape 2 : faits faux (hatched = 0, texte, NaN, négatif, table) ne valident pas",
		(function()
			local bad = { { hatched = 0 }, { hatched = "1" }, { hatched = 0 / 0 }, { hatched = -5 }, { hatched = {} }, { hatched = math.huge * 0 }, {}, { near = true, level = 9 } }
			for _, f in ipairs(bad) do
				if O.event(st, "tick", f, 1100) then
					return false
				end
			end
			return st.step == 2 and select(2, O.event(st, "tick", "texte", 1100)) == "bad_arg" and select(2, O.event(st, "tick", nil, 1100)) == "bad_arg"
		end)()
	)
	check(
		"Étape 2 : hatched = 1 valide (éclosion lue dans le profil)",
		(function()
			local ok = O.event(st, "tick", { hatched = 1 }, 1100)
			return ok == true and st.step == 3 and st.prog == 0
		end)()
	)
	-- étape 3 : revenu
	check(
		"Étape 3 : `tick` (même avec tous les faits vrais) ne valide pas le revenu",
		(function()
			local ok, why = O.event(st, "tick", { near = true, hatched = 9, level = 9 }, 1200)
			return ok == false and why == "wrong_step" and st.step == 3
		end)()
	)
	check(
		"Étape 3 : montants invalides (0, négatif, NaN, texte, infini) ne comptent pas",
		(function()
			for _, v in ipairs({ 0, -5, 0 / 0, "5", math.huge, -math.huge }) do
				local ok, why = O.event(st, "earn", v, 1200)
				if ok or why ~= "bad_arg" then
					return false
				end
			end
			return st.prog == 0 and st.step == 3
		end)()
	)
	check(
		"Étape 3 : le revenu s'additionne (goal 10) et la vue montre prog / goal",
		(function()
			O.event(st, "earn", 4, 1201)
			local v = O.view(st, 1201)
			return st.prog == 4 and v.prog == 4 and v.goal == 10 and v.id == "income"
		end)()
	)
	check(
		"Étape 3 : valide à 10 pièces (un gros montant saturé à goal), jamais d'étape sautée",
		(function()
			local ok = O.event(st, "earn", 1e9, 1210)
			return ok == true and st.step == 4 and st.prog == 0
		end)()
	)
	-- étape 4 : maison
	check(
		"Étape 4 : niveau 1 ne valide pas, niveau 2 valide (après le délai d'affichage)",
		(function()
			local a = O.event(st, "tick", { level = 1, hatched = 5, near = true }, 1211)
			local b = O.event(st, "tick", { level = 2 }, 1212)
			local c = O.event(st, "tick", { level = 2 }, 1213)
			return a == false and b == false and c == true and st.step == 5
		end)()
	)
	-- étape 5 : arène
	check(
		"Étape 5 : seul `arena` valide ; `tick` et `earn` non",
		(function()
			local a = O.event(st, "tick", { near = true, hatched = 3, level = 8 }, 1214)
			local b = O.event(st, "earn", 100, 1214)
			local c, why = O.event(st, "arena", nil, 1214)
			local d, info = O.event(st, "arena", nil, 1216)
			return a == false and b == false and c == false and why == "dwell" and d == true and info == "done" and O.status(st) == "done" and st.step == 6
		end)()
	)
	check(
		"Terminée : plus aucun événement ne la modifie, plus de vue, ne se rejoue pas",
		(function()
			local before = { step = st.step, at = st.at, prog = st.prog }
			for _, k in ipairs({ "tick", "earn", "arena" }) do
				local ok, why = O.event(st, k, { near = true, hatched = 1, level = 9 }, 5000)
				if ok or why ~= "inactive" then
					return false
				end
			end
			O.resume(st, 9999)
			return st.step == before.step and st.at == before.at and st.prog == before.prog and O.view(st, 9999) == nil and O.active(st) == false and O.skip(st) == false
		end)()
	)
	check(
		"Aucun saut d'étape : un état à l'étape 1 + tous les types d'événements dans le désordre n'avance que d'une étape à la fois",
		(function()
			local s2 = O.default()
			s2.at = 1
			local advanced = 0
			local seq = { { "arena" }, { "earn", 99 }, { "tick", { near = true, hatched = 1, level = 9 } }, { "arena" }, { "earn", 99 } }
			for _, e in ipairs(seq) do
				if O.event(s2, e[1], e[2], 100) then
					advanced = advanced + 1
				end
			end
			return advanced == 1 and s2.step == 2
		end)()
	)
	check(
		"Horloge invalide (nil, NaN, négatif, texte) : rien ne bouge",
		(function()
			local s2 = O.default()
			s2.at = 5
			for _, n in ipairs({ -1, 0 / 0, math.huge }) do
				local ok, why = O.event(s2, "tick", { near = true }, n)
				if ok or why ~= "bad_now" then
					return false
				end
			end
			return not O.event(s2, "tick", { near = true }, nil) and not O.event(s2, "tick", { near = true }, "9") and s2.step == 1
		end)()
	)
	check(
		"Texte d'aide : après stepSeconds (45 s) sans progrès la vue passe au texte d'aide, sans valider",
		(function()
			local s2 = O.default()
			s2.at = 1000
			local n1, n2 = O.view(s2, 1045), O.view(s2, 1046)
			return n1.stalled == false and n1.text == O.STEPS[1].text and n2.stalled == true and n2.text == O.STEPS[1].hint and s2.step == 1
		end)()
	)
	check(
		"Passer : définitif, la vue disparaît, plus d'événement, ne se rejoue pas ; double appel sans effet",
		(function()
			local s2 = O.default()
			s2.step = 3
			local a = O.skip(s2)
			local b = O.skip(s2)
			local ok, why = O.event(s2, "earn", 100, 100)
			return a == true and b == false and O.status(s2) == "skipped" and O.view(s2, 5) == nil and ok == false and why == "inactive" and s2.step == 3
		end)()
	)
	check(
		"enabled = false : rien n'est actif, rien n'est modifié, la vue est nil",
		(function()
			local Off = Onboarding.new({ enabled = false })
			local s2 = Off.default()
			local ok, why = Off.event(s2, "tick", { near = true }, 100)
			return Off.active(s2) == false and ok == false and why == "inactive" and Off.view(s2, 100) == nil and s2.step == 1 and s2.at == 0 and Off.skip(s2) == false
		end)()
	)
	check(
		"Reprise (resume) : l'étape repart de maintenant, aucun texte d'aide juste après une absence",
		(function()
			local s2 = O.default()
			s2.at = 10
			O.resume(s2, 100000)
			local v = O.view(s2, 100001)
			return s2.at == 100000 and v.stalled == false
		end)()
	)
	check(
		"Faits transmis jamais modifiés par l'événement",
		(function()
			local f = { near = true, hatched = 1, level = 2 }
			local s2 = O.default()
			O.event(s2, "tick", f, 10)
			return deep(f, { near = true, hatched = 1, level = 2 })
		end)()
	)

	---------------------------------------------------------------- 3. Migration idempotente
	suite("Lot 17 : migration depuis le profil v13, idempotente, sans jamais réinitialiser un profil existant")
	T.new1 = O.migrate(nil)
	check("Profil absent : séquence neuve", deep(T.new1, O.default()))
	check("Profil v13 neuf (0 éclosion, 10 s de jeu, sans onb) : séquence neuve", deep(O.migrate({ ver = 13, hatched = 0, played = 10 }), O.default()))
	check(
		"Profil v13 existant (12 éclosions) sans onb : terminé (legacy), jamais rejoué",
		(function()
			local r = O.migrate({ ver = 13, hatched = 12, played = 9000, coins = 5 })
			return r.step == 6 and O.status(r) == "done" and not O.active(r)
		end)()
	)
	check("Profil v13 avec beaucoup de jeu mais 0 éclosion : terminé (pas de tutoriel pour un vétéran)", O.status(O.migrate({ hatched = 0, played = 100000 })) == "done")
	check(
		"Profil sans éclosion mais joué moins de 120 s : séquence neuve ; 120 s pile : terminé",
		O.status(O.migrate({ played = 119 })) == "active" and O.status(O.migrate({ played = 120 })) == "done"
	)
	check(
		"Valeurs corrompues (hatched / played texte, NaN) : traitées comme 0, pas d'erreur",
		O.status(O.migrate({ hatched = "x", played = 0 / 0 })) == "active" and O.status(O.migrate("zzz")) == "active"
	)
	check(
		"onb présent : assaini seulement (étape, prog gardés), jamais réinitialisé",
		(function()
			local r = O.migrate({ hatched = 0, onb = { v = 1, step = 4, at = 777, prog = 3, skip = false } })
			return r.step == 4 and r.at == 777 and r.prog == 3 and r.skip == false and r.v == 1
		end)()
	)
	check(
		"onb terminé ou passé : conservé tel quel même si le profil n'a aucune éclosion",
		O.status(O.migrate({ hatched = 0, played = 0, onb = { step = 6 } })) == "done" and O.status(O.migrate({ hatched = 0, played = 0, onb = { step = 2, skip = true } })) == "skipped"
	)
	check(
		"onb corrompu (champs hors bornes, NaN, textes) : valeurs neuves par champ, jamais d'erreur",
		(function()
			local r = O.migrate({ onb = { step = 99, at = -5, prog = 1 / 0, skip = "oui" } })
			local r2 = O.migrate({ onb = { step = "x", at = 0 / 0, prog = {}, skip = 1 } })
			return r.step == 6 and r.at == 0 and r.prog == 0 and r.skip == false and r2.step == 1 and r2.at == 0 and r2.prog == 0 and r2.skip == false
		end)()
	)
	check(
		"onb non-table (nombre, texte) : retombe sur la règle du profil sans onb",
		O.status(O.migrate({ hatched = 50, onb = 5 })) == "done" and O.status(O.migrate({ hatched = 0, played = 0, onb = "x" })) == "active"
	)
	check(
		"Idempotence : migrate(migrate(x)) == migrate(x) pour 12 profils variés",
		(function()
			local samples = {
				{},
				{ hatched = 3 },
				{ played = 5 },
				{ onb = { step = 3, at = 50, prog = 2 } },
				{ onb = { step = 9 } },
				{ onb = { step = 2, skip = true } },
				{ hatched = 0, onb = { step = -4 } },
				{ onb = 3 },
				{ hatched = 7, played = 1e9 },
				{ onb = { step = 1.7, prog = 3.5, at = 12.9 } },
				{ ver = 13, onb = { v = 5, step = 2 } },
				{ hatched = -3, played = -1 },
			}
			for _, sample in ipairs(samples) do
				local a = O.migrate(sample)
				local b = O.migrate({ hatched = sample.hatched, played = sample.played, onb = a })
				if not deep(a, b) then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"La migration ne modifie jamais le profil reçu",
		(function()
			local p = { hatched = 0, played = 3, coins = 12, onb = { step = 2, at = 5, prog = 1, skip = false, extra = 1 } }
			local before = { hatched = 0, played = 3, coins = 12, onb = { step = 2, at = 5, prog = 1, skip = false, extra = 1 } }
			O.migrate(p)
			return deep(p, before)
		end)()
	)
	check(
		"Sanitize : copie neuve, entiers pour step et at, prog borné, version posée à 1",
		(function()
			local raw = { step = 3.9, at = 12.6, prog = 5.5, skip = true, junk = 1 }
			local r = O.sanitize(raw)
			return r ~= raw and r.step == 3 and r.at == 12 and r.prog == 5.5 and r.skip == true and r.junk == nil and r.v == 1 and O.sanitize(nil) == nil and O.sanitize(5) == nil
		end)()
	)

	---------------------------------------------------------------- 4. Intégration (vrai Main + Data)
	suite("Lot 17 : intégration (vrai Main.server.lua + Data.lua) : séquence réelle, Passer, rebirth, reconnexion, profil v13 existant")
	T.RT = newRuntime({ fs = fs, luau = luau, placeId = Cfg0.Game.Places.game })
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
	local function errs()
		return #RT.errors == 0 and "" or (" : " .. tostring(RT.errors[1]))
	end
	local function act(p, a, arg)
		RT.now = RT.now + 1.1
		RT.fire(RAction, "OnServerEvent", p, a, arg)
		RT.step(0.2)
	end
	local function lastState(p)
		for i = #RT.fired, 1, -1 do
			local f = RT.fired[i]
			if f[1] == "State" and f[2] == p and type(f[3]) == "table" then
				return f[3]
			end
		end
		return nil
	end
	local function toBase(p)
		local s = hooks.session(p)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if s and r and s.plot then
			rawget(r, "__props").Position = RT.vec(s.plot.cf.X, 4, s.plot.cf.Z)
		end
	end
	local function toFar(p)
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			rawget(r, "__props").Position = RT.vec(300, 4, 300)
		end
	end

	T.p = RT.addPlayer("OnbA", 17001, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	T.s = hooks.session(T.p)
	T.d = T.s and T.s.data
	check(
		"Profil neuf : onb = étape 1 active, version 1, pas de skip" .. errs(),
		T.d ~= nil and type(T.d.onb) == "table" and T.d.onb.step == 1 and T.d.onb.v == 1 and T.d.onb.skip == false and T.d.ver == 13
	)
	T.st0 = lastState(T.p)
	check(
		"Le snapshot envoyé contient onb (étape 1/5, texte, cible home)",
		T.st0 ~= nil and type(T.st0.onb) == "table" and T.st0.onb.index == 1 and T.st0.onb.total == 5 and T.st0.onb.target == "home" and has(T.st0.onb.text, "œuf")
	)
	-- Étape 1 : le joueur n'est pas dans sa base -> rien
	toFar(T.p)
	RT.step(6)
	check("Étape 1 : joueur loin de sa base : l'étape ne se valide pas" .. errs(), T.d.onb.step == 1)
	toBase(T.p)
	RT.step(2.5)
	check("Étape 1 : dans la base, validation après le délai d'affichage minimal (pas avant 3 s)" .. errs(), T.d.onb.step == 1 or T.d.onb.step == 2)
	RT.step(3)
	check("Étape 1 -> 2 : validée par la position lue côté serveur" .. errs(), T.d.onb.step >= 2)
	-- Un client ne peut rien forcer : actions inventées et onbSkip avec arguments étranges
	T.stepBefore = T.d.onb.step
	for _, a in ipairs({ "onbAdvance", "onbStep", "onb", "onbDone", "tutorialDone" }) do
		act(T.p, a, { step = 6, done = true })
	end
	check("Actions inventées par le client (onbAdvance, onbDone...) : aucun effet" .. errs(), T.d.onb.step == T.stepBefore and T.d.onb.skip == false)
	-- Étape 2 : éclosion de l'œuf de départ (12 s)
	RT.step(15)
	toBase(T.p)
	RT.step(6)
	check("Étape 2 -> 3 : après l'éclosion réelle (hatched >= 1) l'étape revenu est atteinte" .. errs(), T.d.hatched >= 1 and T.d.onb.step >= 3)
	-- Étape 3 : revenu réel (joueur actif)
	T.guard = 0
	while T.d.onb.step == 3 and T.guard < 40 do
		act(T.p, "sync")
		RT.step(2)
		T.guard = T.guard + 1
	end
	check("Étape 3 -> 4 : après 10 pièces de revenu réellement versées" .. errs(), T.d.onb.step == 4 and T.guard < 40)
	-- Étape 4 : la maison
	RT.step(8)
	check("Étape 4 : niveau de maison 1 : reste à l'étape 4" .. errs(), T.d.onb.step == 4 and (T.s.baseLevel or 1) == 1)
	T.s.baseLevel = 2 -- fait lu côté serveur par le tick (simule la montée de niveau)
	RT.step(4)
	check("Étape 4 -> 5 : maison niveau 2" .. errs(), T.d.onb.step == 5)
	-- Étape 5 : arène
	T.d.newbieOff, T.s.graceUntil = true, 0
	T.d.slots[1] = { k = "p", p = 1, s = 2, m = 1 }
	act(T.p, "towerStart", 1) -- équipe vide : combat refusé, étape non validée
	check("Étape 5 : combat refusé (équipe vide) : étape non validée" .. errs(), T.d.onb.step == 5)
	act(T.p, "setTeam", { 1 })
	RT.step(3)
	act(T.p, "towerStart", 1)
	RT.step(1)
	check("Étape 5 -> terminé : combat de tour accepté avec une équipe" .. errs(), T.d.onb.step == 6 and O.status(T.d.onb) == "done")
	T.stF = lastState(T.p)
	check("Terminé : le snapshot n'a plus d'onb (nil)" .. errs(), T.stF ~= nil and T.stF.onb == nil)

	-- Rebirth : onb terminé survit
	T.d.coins = 1e15
	T.onbRef = { step = T.d.onb.step, skip = T.d.onb.skip }
	act(T.p, "rebirth")
	RT.step(1)
	T.d2 = hooks.session(T.p).data
	check("Renaissance : onb terminé reporté, le tutoriel ne repart pas" .. errs(), T.d2.rb >= 1 and T.d2.onb ~= nil and T.d2.onb.step == 6 and lastState(T.p).onb == nil)

	-- Sauvegarde / reconnexion : un tutoriel terminé ne se rejoue pas
	RT.removePlayer(T.p)
	RT.step(3)
	T.p = RT.addPlayer("OnbA", 17001, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	T.d3 = hooks.session(T.p).data
	check("Reconnexion : onb terminé relu du DataStore, toujours terminé" .. errs(), T.d3.onb.step == 6 and lastState(T.p).onb == nil)

	-- « Passer » : serveur, persistant
	T.q = RT.addPlayer("OnbB", 17002, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	T.sq = hooks.session(T.q)
	check("Joueur B neuf : séquence active" .. errs(), T.sq.data.onb.step == 1 and lastState(T.q).onb ~= nil)
	act(T.q, "onbSkip", "n'importe quoi")
	check("Passer : le serveur termine le tutoriel (skip = true) et le snapshot n'a plus d'onb" .. errs(), T.sq.data.onb.skip == true and lastState(T.q).onb == nil)
	toBase(T.q)
	RT.step(20)
	check("Après Passer : aucune avancée ni réactivation, même dans la base après éclosion" .. errs(), T.sq.data.onb.skip == true and T.sq.data.onb.step <= 2 and lastState(T.q).onb == nil)
	RT.removePlayer(T.q)
	RT.step(3)
	T.q = RT.addPlayer("OnbB", 17002, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	check("Reconnexion après Passer : toujours passé, jamais rejoué" .. errs(), hooks.session(T.q).data.onb.skip == true and lastState(T.q).onb == nil)

	-- Profil v13 existant sans onb : jamais de tutoriel, rien d'autre modifié
	ds.data.P_17003 = { v = { ver = 13, coins = 4321, starter = true, played = 9000, hatched = 12, eggBag = { 3 }, up = { food = 2 } } }
	T.r = RT.addPlayer("OnbC", 17003, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	T.sr = hooks.session(T.r)
	check("Profil v13 existant sans onb : onb terminé (legacy), snapshot sans onb, ver 13" .. errs(), T.sr.data.onb.step == 6 and T.sr.data.ver == 13 and lastState(T.r).onb == nil)
	check(
		"Profil v13 existant : pièces, sac, améliorations, éclosions intacts" .. errs(),
		T.sr.data.coins >= 4321 and #T.sr.data.eggBag == 1 and T.sr.data.up.food == 2 and T.sr.data.hatched == 12 and T.sr.data.once.StarterPack == true
	)
	-- Profil v13 vide (0 éclosion, 5 s de jeu, sans onb) : reçoit la séquence
	ds.data.P_17004 = { v = { ver = 13, coins = 0, played = 5, hatched = 0 } }
	T.u = RT.addPlayer("OnbD", 17004, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	check("Profil v13 sans éclosion et quasi sans jeu : reçoit la séquence (étape 1)" .. errs(), hooks.session(T.u).data.onb.step == 1 and lastState(T.u).onb ~= nil)
	-- Profil avec un onb à l'étape 3 : repris tel quel
	ds.data.P_17005 = { v = { ver = 13, coins = 10, played = 300, hatched = 1, onb = { v = 1, step = 3, at = 5, prog = 4, skip = false } } }
	T.w = RT.addPlayer("OnbE", 17005, { from = "hub", partyId = "L17A", size = 5, late = false })
	RT.step(3)
	T.sw = hooks.session(T.w)
	check("Profil avec onb à l'étape 3 : repris à l'étape 3 (prog gardé), jamais remis à l'étape 1" .. errs(), T.sw.data.onb.step >= 3 and T.sw.data.onb.step <= 4)
	check("Aucune erreur serveur pendant toute la séquence" .. errs(), #RT.errors == 0)
end
