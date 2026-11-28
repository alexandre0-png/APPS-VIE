--!nocheck
-- Tests de l'idée 3 « Vitrine pet du jour » : module pur ReplicatedStorage/Showcase (sélection du jour, bonus, anti-abus, réclamation atomique avec faux DataStore),
-- patchs Config (Config.SHOWCASE), Data (champ showcase, migration idempotente depuis v13) et Main (branchement, analyse du texte).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs }. Style : pas de `+=`, pas de `continue`.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local C3 = { Color3 = {
		fromRGB = function(r, g, b)
			return { R = r / 255, G = g / 255, B = b / 255 }
		end,
	} }
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = C3 })()
	local Mod = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Showcase.lua"), { debugName = "Showcase" })()
	local SC = Mod.new(Config)
	local DAY = 86400
	local D0 = 20400 -- un jour UTC fixe
	local T0 = D0 * DAY + 3600
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end

	-- Faux DataStore : UpdateAsync atomique (la transformation voit la valeur courante), erreurs injectables.
	local function fakeStore()
		local st = { data = {}, calls = 0, failNext = 0, getCalls = 0 }
		function st:UpdateAsync(key, fn)
			self.calls = self.calls + 1
			if self.failNext > 0 then
				self.failNext = self.failNext - 1
				error("DataStore indisponible")
			end
			local new = fn(self.data[key])
			if new ~= nil then
				self.data[key] = new
			end
			return self.data[key]
		end
		function st:GetAsync(key)
			self.getCalls = self.getCalls + 1
			if self.failNext > 0 then
				self.failNext = self.failNext - 1
				error("DataStore indisponible")
			end
			return self.data[key]
		end
		return st
	end
	local noWait = function() end

	---------------------------------------------------------------- 1. Config et sélection
	suite("Vitrine : Config.SHOWCASE et espèces éligibles")
	check(
		"Config.SHOWCASE existe, activé, +5 %, 24 h, 7 jours",
		type(Config.SHOWCASE) == "table" and Config.SHOWCASE.enabled == true and Config.SHOWCASE.bonusPct == 0.05 and Config.SHOWCASE.bonusSeconds == 86400 and Config.SHOWCASE.cooldownDays == 7
	)
	check(
		"aucun champ Robux / produit / prix dans Config.SHOWCASE",
		(function()
			for k in pairs(Config.SHOWCASE) do
				local l = string.lower(k)
				if has(l, "robux") or has(l, "product") or has(l, "price") or has(l, "pass") then
					return false
				end
			end
			return true
		end)()
	)
	local elig = SC.eligible()
	check("au moins 2 espèces éligibles dans Config.PETS (rareté >= 6)", #elig >= 2)
	local allOk = true
	for i = 1, #elig do
		local p = Config.PETS[elig[i]]
		if p.tier < 6 then
			allOk = false
		end
		if i > 1 and elig[i] <= elig[i - 1] then
			allOk = false
		end
	end
	check("éligibles : rareté >= 6, ordre croissant, sans doublon", allOk)
	local want = 0
	for _, p in ipairs(Config.PETS) do
		if p.tier >= 6 and p.event == nil then
			want = want + 1
		end
	end
	check("éligibles = toutes les espèces de rareté >= 6 hors espèces d'événement (aucune oubliée)", #elig == want)
	check(
		"espèces d'événement / de saison (event) jamais en vitrine : introuvables hors fenêtre (audit A5)",
		(function()
			local C2 = { SHOWCASE = Config.SHOWCASE, PETS = { { tier = 6, name = "A" }, { tier = 9, name = "Ev", event = "halloween" }, { tier = 7, name = "B" }, { tier = 9, name = "S1", event = "saison1" } } }
			local e2 = Mod.new(C2).eligible()
			for i = 1, #elig do
				if Config.PETS[elig[i]].event ~= nil then
					return false
				end
			end
			return #e2 == 2 and e2[1] == 1 and e2[2] == 3
		end)()
	)
	check(
		"minTier modifiable : Config.SHOWCASE.minTier = 99 -> aucune espèce, pick = nil",
		(function()
			local C2 = setmetatable({ SHOWCASE = { minTier = 99 } }, { __index = Config })
			local S2 = Mod.new(C2)
			return #S2.eligible() == 0 and S2.pick(D0) == nil
		end)()
	)
	check("PETS vide ou absent : pas d'erreur", Mod.new({}).pick(D0) == nil and Mod.new(nil).pick(D0) == nil)
	check("pick(NaN / inf) = nil", SC.pick(0 / 0) == nil and SC.pick(math.huge) == nil)

	suite("Vitrine : sélection déterministe par jour UTC")
	local isElig = {}
	for _, i in ipairs(elig) do
		isElig[i] = true
	end
	local seen, nSeen, repeatAdj, allIn, same = {}, 0, 0, true, true
	local SC2 = Mod.new(Config) -- seconde instance : même résultat (aucun état caché)
	for day = D0, D0 + 399 do
		local a = SC.pick(day)
		if not isElig[a] then
			allIn = false
		end
		if a ~= SC2.pick(day) or a ~= SC.pick(day) then
			same = false
		end
		if SC.pick(day - 1) == a then
			repeatAdj = repeatAdj + 1
		end
		if not seen[a] then
			seen[a] = true
			nSeen = nSeen + 1
		end
	end
	check("400 jours : toujours une espèce éligible", allIn)
	check("même jour = même espèce (deux instances, appels répétés)", same)
	check("jamais la même espèce deux jours de suite", repeatAdj == 0)
	check("toutes les espèces éligibles ressortent sur 400 jours (rotation équitable)", nSeen == #elig)
	check("deux instants du même jour UTC -> même jour", SC.dayOf(D0 * DAY) == D0 and SC.dayOf(D0 * DAY + DAY - 1) == D0 and SC.dayOf(D0 * DAY + DAY) == D0 + 1)
	check("valeur de référence figée : pick(20400) identique entre exécutions", SC.pick(20400) == SC.pick(20400) and type(SC.pick(20400)) == "number")
	check(
		"une seule espèce éligible : pas de boucle ni d'erreur",
		(function()
			local C2 = setmetatable({ PETS = { { tier = 6 } } }, { __index = Config })
			local S2 = Mod.new(C2)
			return S2.pick(D0) == 1 and S2.pick(D0 + 1) == 1
		end)()
	)

	---------------------------------------------------------------- 2. Nom et vue publique
	suite("Vitrine : nom assaini, aucun identifiant exposé")
	check("nom simple conservé", SC.sanitizeName("Alice") == "Alice")
	check("nom nil / nombre / table -> nom de secours", SC.sanitizeName(nil) == "Un dresseur" and SC.sanitizeName(5) == "Un dresseur" and SC.sanitizeName({}) == "Un dresseur")
	check("nom vide ou espaces -> nom de secours", SC.sanitizeName("") == "Un dresseur" and SC.sanitizeName("   ") == "Un dresseur")
	check("caractères de contrôle retirés", SC.sanitizeName("Al\nic\te\0") == "Alice")
	check("tronqué à 20 caractères", #SC.sanitizeName(string.rep("a", 80)) == 20)
	check(
		"tronqué sans couper un caractère UTF-8",
		(function()
			local s = SC.sanitizeName(string.rep("é", 30))
			return utf8.len(s) == 20
		end)()
	)
	check("UTF-8 invalide : octets retirés, pas d'erreur", type(SC.sanitizeName("ab\255\254cd")) == "string")
	local rec = SC.claimTransform(nil, D0, SC.pick(D0), 123456789, "Alice")
	local view = SC.publicView(rec, D0)
	check("publicView : espèce + nom + claimed", view.species == SC.pick(D0) and view.name == "Alice" and view.claimed == true)
	check(
		"publicView ne contient aucun identifiant (ni u, ni userId, ni 123456789)",
		(function()
			for k, v in pairs(view) do
				if k == "u" or string.lower(tostring(k)) == "userid" or tostring(v) == "123456789" then
					return false
				end
			end
			return true
		end)()
	)
	check("publicView sans enregistrement : claimed = false, name = nil", SC.publicView(nil, D0).claimed == false and SC.publicView(nil, D0).name == nil)
	check("publicView d'un autre jour ou d'une autre espèce : non réclamé", SC.publicView(rec, D0 + 1).claimed == false and SC.publicView({ d = D0, sp = -1, n = "X" }, D0).claimed == false)

	---------------------------------------------------------------- 3. Bonus et anti-abus
	suite("Vitrine : bonus +5 % pendant 24 h, un seul actif")
	local sc = SC.sanitize(nil, T0)
	check("profil neuf : last = 0, ends = 0", sc.last == 0 and sc.ends == 0)
	check("sans bonus : multiplicateur 1", SC.multiplier(sc, T0) == 1)
	check("canOwn sur profil neuf", SC.canOwn(sc, D0, T0) == true)
	check("grant accorde", SC.grant(sc, D0, T0) == true and sc.last == D0 and sc.ends == T0 + DAY)
	check("multiplicateur 1,05 pendant 24 h", SC.multiplier(sc, T0) == 1.05 and SC.multiplier(sc, T0 + DAY - 1) == 1.05)
	check("multiplicateur 1 à l'expiration exacte et après", SC.multiplier(sc, T0 + DAY) == 1 and SC.multiplier(sc, T0 + DAY * 5) == 1)
	check("bonus actif : aucun nouveau bonus, aucune prolongation", SC.grant(sc, D0, T0 + 10) == false and sc.ends == T0 + DAY and select(2, SC.canOwn(sc, D0 + 30, T0 + 10)) == "active")
	check("même jour après expiration : refusé (sameDay)", select(2, SC.canOwn(sc, D0, T0 + DAY)) == "sameDay")
	check(
		"cooldown : jours 1 à 6 après refusés",
		(function()
			for k = 1, 6 do
				local ok, why = SC.canOwn(sc, D0 + k, T0 + DAY + k * DAY)
				if ok or why ~= "cooldown" then
					return false
				end
			end
			return true
		end)()
	)
	check("une semaine plus tard : de nouveau possible", SC.canOwn(sc, D0 + 7, T0 + 8 * DAY) == true)
	check("multiplicateur d'un champ corrompu (NaN, texte, nil) = 1", SC.multiplier({ ends = 0 / 0 }, T0) == 1 and SC.multiplier({ ends = "x" }, T0) == 1 and SC.multiplier(nil, T0) == 1)
	check("fin de bonus anormalement lointaine : pas de bonus (> 24 h)", SC.multiplier({ ends = T0 + DAY * 400 }, T0) == 1)
	check("bonus +5 % seulement : jamais plus", SC.multiplier(sc, T0) <= 1.05 + 1e-12)

	suite("Vitrine : assainissement idempotent (migration depuis v13)")
	check(
		"sanitize(nil / texte / liste) -> valeurs neuves",
		(function()
			for _, v in ipairs({ "x", 5, true }) do
				local r = SC.sanitize(v, T0)
				if r.last ~= 0 or r.ends ~= 0 then
					return false
				end
			end
			return true
		end)()
	)
	local good = { last = D0 - 3, ends = T0 + 1000 }
	local s1 = SC.sanitize(good, T0)
	check("champ valide conservé tel quel (jamais de réinitialisation)", s1.last == D0 - 3 and s1.ends == T0 + 1000)
	local s2 = SC.sanitize(s1, T0)
	check("idempotent : sanitize(sanitize(x)) = sanitize(x)", s2.last == s1.last and s2.ends == s1.ends)
	local bad = SC.sanitize({ last = 0 / 0, ends = -5 }, T0)
	check("NaN / négatif -> 0", bad.last == 0 and bad.ends == 0)
	local fut = SC.sanitize({ last = D0 + 9999, ends = T0 + DAY * 999 }, T0)
	check("jour futur ramené à aujourd'hui, fin lointaine ramenée à 24 h", fut.last == D0 and fut.ends == T0 + DAY)
	check("décimaux arrondis", SC.sanitize({ last = 5.7, ends = 0 }, T0).last == 5)
	check(
		"sanitize ne modifie pas l'entrée",
		(function()
			local inp = { last = 1, ends = 2, extra = "z" }
			SC.sanitize(inp, T0)
			return inp.last == 1 and inp.ends == 2 and inp.extra == "z"
		end)()
	)

	---------------------------------------------------------------- 4. Réclamation atomique
	suite("Vitrine : premier joueur gagne (UpdateAsync), concurrence, erreurs")
	local sp = SC.pick(D0)
	local other = nil
	for _, i in ipairs(elig) do
		if i ~= sp then
			other = i
		end
	end
	local st = fakeStore()
	local a, b = Mod.new(Config), Mod.new(Config) -- deux « serveurs » distincts partageant le même DataStore
	local pa, pb = { userId = 111, name = "Alice" }, { userId = 222, name = "Bob" }
	local sa, sb = SC.sanitize(nil, T0), SC.sanitize(nil, T0)
	check("mauvaise espèce : notFeatured, aucun appel DataStore", a.tryClaim(st, sa, other, pa, T0, noWait) == "notFeatured" and st.calls == 0)
	check("Alice gagne", a.tryClaim(st, sa, sp, pa, T0, noWait) == "won")
	check("Alice a le bonus daté (+24 h, last = jour)", sa.ends == T0 + DAY and sa.last == D0 and SC.multiplier(sa, T0 + 5) == 1.05)
	check("Bob (autre serveur) perd : taken, pas de bonus", b.tryClaim(st, sb, sp, pb, T0 + 5, noWait) == "taken" and sb.ends == 0 and sb.last == 0)
	check("enregistrement stocké : jour, espèce, nom assaini", st.data[SC.key(D0)].d == D0 and st.data[SC.key(D0)].sp == sp and st.data[SC.key(D0)].n == "Alice")
	local callsBefore = st.calls
	check("Bob de nouveau sur le même serveur : taken SANS appel DataStore (cache)", b.tryClaim(st, SC.sanitize(nil, T0), sp, pb, T0 + 9, noWait) == "taken" and st.calls == callsBefore)
	check("le gagnant garde son enregistrement : écriture seule, pas d'écrasement", st.data[SC.key(D0)].u == 111)
	check("Alice rejoue : bloquée (bonus actif)", a.tryClaim(st, sa, sp, pa, T0 + 50, noWait) == "blocked:active")
	check(
		"vue publique du cache : nom seulement",
		(function()
			local v = a.cache.view
			return v.name == "Alice" and v.claimed == true and v.u == nil
		end)()
	)
	-- jour suivant : nouvelle vitrine, ancien gagnant bloqué (cooldown 7 jours)
	local T1 = T0 + DAY * 2
	local sp1 = SC.pick(D0 + 2)
	check("jour J+2 : Alice bloquée par la semaine (cooldown)", a.tryClaim(st, sa, sp1, pa, T1, noWait) == "blocked:cooldown")
	check("jour J+2 : Bob gagne la nouvelle vitrine", b.tryClaim(st, sb, sp1, pb, T1, noWait) == "won" and st.data[SC.key(D0 + 2)].n == "Bob")
	check("jour J+2 : Alice (cache d'hier) ne reçoit rien et ne peut pas écraser", st.data[SC.key(D0 + 2)].u == 222)
	-- jour J+8 : Alice de nouveau éligible
	local T8 = T0 + DAY * 8
	local sp8 = SC.pick(D0 + 8)
	check("J+8 : Alice de nouveau éligible et gagne", a.tryClaim(st, sa, sp8, pa, T8, noWait) == "won")
	-- erreurs DataStore
	local st2 = fakeStore()
	local c = Mod.new(Config)
	local sc3 = SC.sanitize(nil, T0)
	st2.failNext = 5
	check("DataStore en panne : error, AUCUN bonus", c.tryClaim(st2, sc3, sp, pa, T0, noWait) == "error" and sc3.ends == 0 and sc3.last == 0)
	check("3 tentatives faites (backoff)", st2.calls == 3)
	local waits = {}
	st2.failNext = 2
	local r = c.tryClaim(st2, sc3, sp, pa, T0, function(n)
		waits[#waits + 1] = n
	end)
	check("panne de 2 appels puis succès : won, attente croissante 2 s puis 4 s", r == "won" and #waits == 2 and waits[1] == 2 and waits[2] == 4)
	check("verrou interne libéré après erreur (pas de joueur bloqué « busy »)", next(c.busy) == nil)
	-- relecture quand la transformation annule et que UpdateAsync renvoie nil (comportement de certains faux)
	local st3 = fakeStore()
	st3.data[SC.key(D0)] = { v = 1, d = D0, sp = sp, u = 999, n = "Zed" }
	function st3:UpdateAsync(key, fn)
		self.calls = self.calls + 1
		local new = fn(self.data[key])
		if new ~= nil then
			self.data[key] = new
		end
		return nil
	end
	local d3 = Mod.new(Config)
	check("UpdateAsync annulé (nil) : relecture GetAsync, taken", d3.tryClaim(st3, SC.sanitize(nil, T0), sp, pa, T0, noWait) == "taken")
	check(
		"Vitrine aussi : joueur qui a déjà une vitrine ce jour ne la prend pas",
		(function()
			local e = Mod.new(Config)
			local s5 = { last = D0, ends = 0 }
			return e.tryClaim(fakeStore(), s5, sp, pa, T0, noWait) == "blocked:sameDay"
		end)()
	)
	check(
		"busy : deux éclosions simultanées du même joueur = un seul appel",
		(function()
			local e = Mod.new(Config)
			local stx = fakeStore()
			e.busy[111] = true
			return e.tryClaim(stx, SC.sanitize(nil, T0), sp, pa, T0, noWait) == "busy" and stx.calls == 0
		end)()
	)
	check(
		"race de profil : bonus accordé pendant l'appel -> blocked:race, rien de cumulé",
		(function()
			local e = Mod.new(Config)
			local sx = SC.sanitize(nil, T0)
			local stx = fakeStore()
			local base = stx.UpdateAsync
			function stx:UpdateAsync(key, fn)
				sx.ends = T0 + 500 -- un autre bonus est arrivé pendant l'attente
				return base(self, key, fn)
			end
			local res = e.tryClaim(stx, sx, sp, pa, T0, noWait)
			return res == "blocked:race" and sx.ends == T0 + 500
		end)()
	)

	suite("Vitrine : propriétaire qui ne se connecte pas / se connecte tard")
	local st4 = fakeStore()
	st4.data[SC.key(D0)] = { v = 1, d = D0, sp = sp, u = 111, n = "Alice" }
	local e1 = Mod.new(Config)
	local sl = SC.sanitize(nil, T0)
	check("propriétaire se reconnecte le même jour (profil non enregistré) : granted une fois", e1.onLogin(st4, sl, pa, T0 + 7200, noWait) == "granted" and sl.ends == T0 + 7200 + DAY)
	check("deuxième connexion le même jour : aucun nouveau bonus (pas de répétition)", e1.onLogin(st4, sl, pa, T0 + 7300, noWait) == "none" and sl.ends == T0 + 7200 + DAY)
	check("autre joueur : aucun bonus", Mod.new(Config).onLogin(st4, SC.sanitize(nil, T0), pb, T0 + 100, noWait) == "none")
	check("le lendemain (jour UTC suivant) : bonus non accordé", Mod.new(Config).onLogin(st4, SC.sanitize(nil, T0 + DAY), pa, T0 + DAY, noWait) == "none")
	check(
		"onLogin refuse un propriétaire encore en cooldown",
		(function()
			local sx = { last = D0 - 3, ends = 0 }
			return Mod.new(Config).onLogin(st4, sx, pa, T0 + 10, noWait) == "none" and sx.ends == 0
		end)()
	)
	check(
		"onLogin : DataStore en panne -> error, aucun bonus",
		(function()
			local sx = SC.sanitize(nil, T0)
			local stx = fakeStore()
			stx.failNext = 9
			return Mod.new(Config).onLogin(stx, sx, pa, T0, noWait) == "error" and sx.ends == 0
		end)()
	)
	check("onLogin sans enregistrement : none", Mod.new(Config).onLogin(fakeStore(), SC.sanitize(nil, T0), pa, T0, noWait) == "none")
	check("claimTransform n'écrase jamais une vitrine valide du même jour", SC.claimTransform({ d = D0, sp = sp, u = 1, n = "A" }, D0, sp, 2, "B") == nil)
	check(
		"claimTransform remplace un enregistrement d'un autre jour ou corrompu",
		SC.claimTransform({ d = D0 - 1, sp = sp, u = 1 }, D0, sp, 2, "B").u == 2 and SC.claimTransform("x", D0, sp, 2, "B").u == 2
	)

	---------------------------------------------------------------- 5. Patchs : Config / Data / Main (texte et exécution)
	suite("Vitrine : branchement dans Data.lua et Main.server.lua")
	local dataSrc = fs.readFile("roblox/src/ServerScriptService/Data.lua")
	local mainSrc = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
	check("Data : version du schéma inchangée (13)", has(dataSrc, "local VERSION = 13\n"))
	check(
		"Data : require Showcase, valeur par défaut et assainissement du champ",
		has(dataSrc, "ShowcaseMod = require(") and has(dataSrc, "showcase = ShowcaseMod.sanitize(nil, os.time())") and has(dataSrc, "d.showcase = ShowcaseMod.sanitize(saved.showcase, os.time())")
	)
	check("Data : aucune réinitialisation du champ showcase hors défaut et assainissement", select(2, string.gsub(dataSrc, "showcase =", "")) == 2)
	check("Main : multiplicateur branché sur gmult, désactivable par Config.SHOWCASE.enabled", has(mainSrc, "Config.SHOWCASE.enabled and L15.SC.multiplier(s.data.showcase, os.time())"))
	check(
		"Main : réclamation à l'éclosion hors du fil principal (task.spawn + pcall GetDataStore)",
		has(mainSrc, "L15.SC.tryClaim(store, d.showcase") and has(mainSrc, "task.spawn(function()\n\t\t\tlocal okStore")
	)
	check("Main : bonus à la connexion via onLogin", has(mainSrc, "L15.SC.onLogin(store, d.showcase"))
	check(
		"Main : aucun achat, aucun Robux dans le code de la vitrine",
		not has(string.lower(fs.readFile("roblox/src/ReplicatedStorage/Showcase.lua")), "marketplace") and not has(string.lower(fs.readFile("roblox/src/ReplicatedStorage/Showcase.lua")), "robux")
	)
	check(
		"Showcase : pas d'API dépréciée (wait/spawn/delay nus) ni de += / continue",
		(function()
			local src = fs.readFile("roblox/src/ReplicatedStorage/Showcase.lua")
			return not string.find(src, "[^%.%w_]wait%(") and not string.find(src, "[^%.%w_]spawn%(") and not string.find(src, "+=", 1, true) and not string.find(src, "continue", 1, true)
		end)()
	)
end
