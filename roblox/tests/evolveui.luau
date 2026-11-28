--!nocheck
-- Tests de l'interface « ✨ Évoluer » (idée 2, DÉSACTIVÉE) : EvolveLayout (module pur : liste, aperçu, doublons, machine d'états à deux étapes, retour visuel, disposition,
-- contrastes) et EvolveUi (instances, boutons, aucun envoi tant que Config.EVOLUTION.enabled = false, nettoyage) dans le runtime factice.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau ou tests/run_evolveui.py).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, pas de LCG > 2^53 (Park-Miller 48271 mod 2^31-1), état partagé dans la table T (limite de 200 variables locales).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local T = {}
	local color = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local EL = load("roblox/src/ReplicatedStorage/EvolveLayout.lua", "EvolveLayout")
	local E = load("roblox/src/ReplicatedStorage/Evolution.lua", "Evolution")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", { Color3 = color })
	local function clone(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	local On = clone(Config) -- Config avec l'évolution ACTIVÉE (copie : la source garde enabled = false)
	On.EVOLUTION = clone(Config.EVOLUTION)
	On.EVOLUTION.enabled = true
	local function rng(seed)
		local s = seed
		return function()
			s = (s * 48271) % 2147483647
			return s / 2147483647
		end
	end
	-- espèces par rareté
	local byTier = {}
	for i, d in ipairs(Config.PETS) do
		byTier[d.tier] = byTier[d.tier] or {}
		byTier[d.tier][#byTier[d.tier] + 1] = i
	end
	local tiersSeen = {}
	for t in pairs(byTier) do
		tiersSeen[#tiersSeen + 1] = t
	end
	table.sort(tiersSeen)
	local A1, B1, A2, C3 = byTier[tiersSeen[1]][1], byTier[tiersSeen[1]][2], byTier[tiersSeen[2]][1], byTier[tiersSeen[2]][2]
	local function pet(p, s, m, f)
		return { k = "p", p = p, s = s or 2, m = m or 1, f = f }
	end

	---------------------------------------------------------------- 1. Interrupteur et textes « bientôt »
	suite("EvolveLayout : interrupteur (Config.EVOLUTION.enabled reste false), « bientôt », aucun bouton actif")
	local cfgSrc = fs.readFile("roblox/src/ReplicatedStorage/Config.lua")
	check("Config.EVOLUTION.enabled = false dans la source ET à l'exécution", Config.EVOLUTION.enabled == false and string.find(cfgSrc, "enabled = false, sacrifices = 3, costSeconds = 300", 1, true) ~= nil)
	check("EvolveLayout.enabled : faux (réel), vrai (copie), faux (Config absente ou invalide)", EL.enabled(Config) == false and EL.enabled(On) == true and EL.enabled(nil) == false and EL.enabled({}) == false and EL.enabled({ EVOLUTION = { enabled = "yes" } }) == false)
	local st0 = { cap = 8, slots = { pet(A1), pet(A1), pet(A1), pet(A1) }, equip = {}, battle = { team = {} } }
	local rows0 = EL.list(Config, E, st0)
	local head0 = EL.header(Config, rows0)
	check("En-tête désactivé : « bientôt », titre et sous-titre non vides", head0.soon == true and head0.title ~= "" and string.find(head0.subtitle, "Bientôt", 1, true) ~= nil)
	local f0 = EL.newFlow()
	local f0b, a0 = EL.select(f0, 1, 10, EL.enabled(Config))
	check("Désactivé : select ne démarre rien et n'envoie aucun aperçu", a0 == nil and f0b.phase == "idle" and f0b.i == nil)
	local _, a1 = EL.press(f0, 11, EL.enabled(Config))
	check("Désactivé : press ne fait rien", a1 == nil and f0.phase == "idle")
	local b0 = EL.button(f0, EL.enabled(Config), E)
	check("Désactivé : bouton principal « Bientôt disponible », inactif, sans « Annuler »", b0.active == false and b0.kind == "soon" and string.find(b0.text, "Bientôt", 1, true) ~= nil and b0.cancel == false)
	-- même avec un aperçu forcé et un flux « prêt » bricolé, press reste muet quand l'interrupteur est coupé
	local fx0 = EL.newFlow()
	fx0.phase, fx0.i, fx0.view = "ready", 1, { ok = true, i = 1, sac = { 2, 3, 4 }, cost = 10, need = 3 }
	local _, a2 = EL.press(fx0, 5, false)
	check("Désactivé : même un état « prêt » ne produit aucune action", a2 == nil and fx0.phase == "ready")

	---------------------------------------------------------------- 2. Liste, états, tri, estimation
	suite("EvolveLayout : liste des pets évoluables, états, tri, cas limites")
	local rowsOn = EL.list(On, E, st0)
	check("Liste activée : 4 pets, le 1er est prêt (3 doublons) et marqué « Prêt »", #rowsOn == 4 and rowsOn[1].status == "ready" and string.find(rowsOn[1].tag, "Prêt", 1, true) ~= nil)
	check("Chaque ligne a un nom, un emoji, une rareté et un texte d'état (jamais la couleur seule)", (function()
		for _, r in ipairs(rowsOn) do
			if r.name == "" or r.emoji == "" or r.tierName == "" or r.tag == "" or r.tag == nil then
				return false
			end
		end
		return true
	end)())
	local stFew = { cap = 8, slots = { pet(A1), pet(A1), pet(B1) }, equip = {}, battle = { team = {} } }
	local rowsFew = EL.list(On, E, stFew)
	local r1 = rowsFew[1]
	check("Pas assez de doublons : statut « dupes », « Doublons n/3 », jamais « prêt »", (function()
		for _, r in ipairs(rowsFew) do
			if r.status == "ready" then
				return false
			end
		end
		return rowsFew[1].status == "dupes" and string.find(rowsFew[1].tag, "/3", 1, true) ~= nil and r1.found ~= nil and r1.need == 3
	end)())
	local stForm = { cap = 8, slots = { pet(A1, 2, 1, 2), pet(A1), pet(A1), pet(A1), pet(A1) }, equip = {}, battle = { team = {} } }
	local rowsForm = EL.list(On, E, stForm)
	local last = rowsForm[#rowsForm]
	check("Pet en forme 2 : statut « done », étiquette ★2, classé en dernier, revenu = revenu forme 2", last.status == "done" and last.form == 2 and last.tag == "★2" and math.abs(last.income - Config.petIncome(A1, 2, 1, 2)) < 1e-9)
	local stLock = { cap = 8, slots = { pet(A1, 4, 1), pet(A1), pet(A1), pet(A1), pet(A1, 2, 4) }, equip = { 2 }, battle = { team = { 3 } } }
	local rowsLock = EL.list(On, E, stLock)
	local byI = {}
	for _, r in ipairs(rowsLock) do
		byI[r.i] = r
	end
	check("Interdits : Géant (taille 4), Arc-en-ciel (mutation 4), suiveur, équipe de combat = « locked » avec 🔒", byI[1].status == "locked" and byI[1].code == "special" and byI[5].status == "locked" and byI[2].status == "locked" and byI[2].code == "follower" and byI[3].status == "locked" and byI[3].code == "team" and byI[1].tag == "🔒")
	local rowsOrd = EL.list(On, E, { cap = 8, slots = { pet(B1), pet(A2), pet(A1), pet(A1), pet(A1), pet(A1, 2, 1, 2) }, equip = {}, battle = { team = {} } })
	check("Tri : prêts, puis doublons manquants, puis forme 2 ; à statut égal rareté décroissante", rowsOrd[1].status == "ready" and rowsOrd[#rowsOrd].status == "done" and (function()
		local seenDupes = false
		for _, r in ipairs(rowsOrd) do
			if r.status == "dupes" then
				seenDupes = true
			end
			if r.status == "ready" and seenDupes then
				return false
			end
		end
		return true
	end)())
	local junk = { {}, { cap = 0 }, { cap = 5 }, { cap = 5, slots = "x" }, { cap = -3, slots = {} }, { cap = 5, slots = { 1, "a", true, false, {} } }, { cap = 5, slots = { { k = "p", p = 99999 } } }, { cap = 5, slots = { { k = "e", t = 1 } } }, { cap = 1e9, slots = { pet(A1) } }, { cap = 0 / 0, slots = { pet(A1) } } }
	T.junkOk = true
	for n, js in ipairs(junk) do
		local ok, rr = pcall(EL.list, On, E, js)
		if not ok or type(rr) ~= "table" or #rr > EL.MAX_ROWS then
			T.junkOk = false
			print("  junk " .. n .. " : " .. tostring(rr))
		end
	end
	check("Cas limites : état vide, capacité invalide, cases bizarres, espèce inconnue, œufs : jamais d'erreur, jamais plus de MAX_ROWS lignes", T.junkOk and #EL.list(On, E, nil) == 0 and #EL.list(On, E, {}) == 0)
	check("Les œufs et les emplacements vides ne sont jamais listés", #EL.list(On, E, { cap = 5, slots = { { k = "e", t = 1 }, false, false } }) == 0)

	-- estimation = règle du serveur (Evolution.plan), sur 400 états tirés au hasard (hors défense PvP, que le client ne voit pas)
	suite("EvolveLayout.estimate : même verdict que Evolution.plan du serveur sur 400 états aléatoires")
	local rnd = rng(20261128)
	local mism, tested, readyN = 0, 0, 0
	for _ = 1, 400 do
		local n = 3 + math.floor(rnd() * 9)
		local slots = {}
		for i = 1, n do
			local x = rnd()
			if x < 0.1 then
				slots[i] = false
			else
				local sp = ({ A1, B1, A2, C3 })[1 + math.floor(rnd() * 4)]
				slots[i] = pet(sp, rnd() < 0.15 and 4 or 2, rnd() < 0.15 and 4 or 1, rnd() < 0.15 and 2 or nil)
			end
		end
		local equip, team = {}, {}
		if rnd() < 0.5 then
			equip[1] = 1 + math.floor(rnd() * n)
		end
		if rnd() < 0.5 then
			team[1] = 1 + math.floor(rnd() * n)
		end
		local state = { cap = n, slots = slots, equip = equip, battle = { team = team } }
		local d = { slots = slots, equip = equip, battle = { team = team }, coins = 1e15, evo = {} }
		for i = 1, n do
			local sl = slots[i]
			if sl and sl.f ~= 2 then
				local est = EL.estimate(On, E, state, i)
				local plan, code = E.plan(On, d, i, { capacity = n, income = 1 })
				tested = tested + 1
				if est.ok then
					readyN = readyN + 1
				end
				if (plan ~= nil) ~= est.ok or (not plan and code ~= est.code) then
					mism = mism + 1
				elseif plan and table.concat(plan.sac, ",") ~= table.concat(est.sac, ",") then
					mism = mism + 1
				end
			end
		end
	end
	check("Estimation du client = plan du serveur (verdict, code de refus et doublons choisis) : " .. tested .. " pets, " .. readyN .. " prêts, " .. mism .. " écarts", mism == 0 and tested > 500 and readyN > 20)

	---------------------------------------------------------------- 3. Gains, doublons, vérification de sélection
	suite("EvolveLayout : gains (revenu +15 %, force +10 %), doublons sacrifiés, sélection invalide")
	local g = EL.gains(Config, pet(A1, 3, 2))
	check("Gains : revenu après = avant x 1,15 ; pourcentages 15 et 10 lus dans Config.EVOLUTION", math.abs(g.incomeAfter - g.incomeBefore * 1.15) < 1e-9 and g.incomePct == 15 and g.powerPct == 10 and g.incomeBefore == Config.petIncome(A1, 3, 2))
	check("Gains : espèce inconnue ou entrée invalide = nil, sans erreur", EL.gains(Config, pet(99999)) == nil and EL.gains(Config, nil) == nil and EL.gains(nil, pet(A1)) == nil and EL.gains({}, pet(A1)) == nil)
	check("pct : 1,15 -> 15, 1,10 -> 10, 1 -> 0, NaN / texte / nil -> 0", EL.pct(1.15) == 15 and EL.pct(1.10) == 10 and EL.pct(1) == 0 and EL.pct(0 / 0) == 0 and EL.pct("x") == 0 and EL.pct(nil) == 0)
	local stS = { cap = 8, slots = { pet(A1), pet(A1), pet(A1), pet(A1), pet(A2) }, equip = {}, battle = { team = {} } }
	check("validateSelection : 3 doublons distincts de même rareté = valide", EL.validateSelection(On, stS, 1, { 2, 3, 4 }, 3) == true)
	local function bad(i, sac, need)
		local ok, why = EL.validateSelection(On, stS, i, sac, need)
		return ok == false and why ~= nil
	end
	check("validateSelection : mauvais nombre, doublon de l'indice, le pet visé lui-même, autre rareté, case vide, texte : refusé", bad(1, { 2, 3 }, 3) and bad(1, { 2, 2, 3 }, 3) and bad(1, { 1, 2, 3 }, 3) and bad(1, { 2, 3, 5 }, 3) and bad(1, { 2, 3, 9 }, 3) and bad(1, { "a", 3, 4 }, 3) and bad(1, nil, 3) and bad(1, { 2, 3, 4 }, nil) and bad(5, { 2, 3, 4 }, 3) and bad(9, { 2, 3, 4 }, 3) and bad(1, { 2.5, 3, 4 }, 3))
	local chips = EL.sacChips(Config, stS, { 2, 3, 4 })
	check("Pastilles des doublons : une par indice, avec emoji, nom et rareté", #chips == 3 and chips[1].i == 2 and chips[1].emoji ~= "" and chips[1].tierName == Config.TIERS[tiersSeen[1]].name and #EL.sacChips(Config, stS, nil) == 0 and EL.sacChips(Config, stS, { 17 })[1].emoji == "?")

	---------------------------------------------------------------- 4. Machine d'états : sélection, aperçu, deux étapes, envoi, retour visuel
	suite("EvolveLayout : machine d'états (aperçu -> prêt -> confirmer -> envoi -> fait) et états refusés")
	local VIEW = { ok = true, i = 1, sac = { 2, 3, 4 }, cost = 120, need = 3 }
	local f = EL.newFlow()
	local _, act = EL.select(f, 1, 100, true)
	check("Sélection : phase « loading », demande d'aperçu pour l'indice choisi", f.phase == "loading" and f.i == 1 and act ~= nil and act.kind == "preview" and act.i == 1)
	local _, act2 = EL.select(f, 1, 100.1, true)
	check("Re-toucher le même pet pendant la vérification n'envoie rien de plus", act2 == nil and f.phase == "loading")
	EL.onPreview(f, { ok = true, i = 7, sac = { 2, 3, 4 }, cost = 1, need = 3 }, 100.2)
	check("Aperçu d'un AUTRE pet : ignoré", f.phase == "loading" and f.view == nil)
	EL.onPreview(f, VIEW, 100.3)
	check("Aperçu valide : phase « prêt », bouton « Évoluer (120 🪙) » actif", f.phase == "ready" and EL.button(f, true, E).active == true and string.find(EL.button(f, true, E).text, "120", 1, true) ~= nil and string.find(EL.button(f, true, E).text, "Évoluer", 1, true) ~= nil)
	local _, e1 = EL.press(f, 101, true)
	check("1er appui : confirmation armée, RIEN n'est envoyé ; bouton « Confirmer » + « Annuler »", e1 == nil and f.phase == "confirm" and EL.button(f, true, E).cancel == true and string.find(EL.button(f, true, E).text, "Confirmer", 1, true) ~= nil)
	local _, e2 = EL.press(f, 102, true)
	check("2e appui : envoi de { i, maxCost = prix vu } UNE fois, phase « sending », bouton inactif", e2 ~= nil and e2.kind == "evolve" and e2.i == 1 and e2.maxCost == 120 and f.phase == "sending" and EL.button(f, true, E).active == false)
	local _, e3 = EL.press(f, 102.1, true)
	local _, e3b = EL.select(f, 2, 102.2, true)
	check("Pendant l'envoi : ni nouvel appui, ni nouvelle sélection (aucun double envoi)", e3 == nil and e3b == nil and f.phase == "sending" and f.i == 1)
	EL.onDone(f, { k = "done", i = 1, p = A1, n = 1 }, 103)
	check("Réponse « done » : phase « done », bouton « Évolué ! » inactif, retour visuel démarré", f.phase == "done" and f.doneAt == 103 and EL.button(f, true, E).active == false and string.find(EL.button(f, true, E).text, "Évolué", 1, true) ~= nil)
	EL.tick(f, 103.5)
	check("Retour visuel encore en cours à 0,5 s", f.phase == "done")
	EL.tick(f, 103 + EL.FX_SECONDS + 0.01)
	check("Retour visuel terminé à FX_SECONDS : retour au repos (aucun pet choisi)", f.phase == "idle" and f.i == nil and f.view == nil)
	check("FX_SECONDS et MAX_FX <= 1,2 s ; version réduite plus courte ; jamais au-dessus de MAX_FX", EL.FX_SECONDS <= 1.2 and EL.MAX_FX <= 1.2 and EL.fxSeconds(false) <= 1.2 and EL.fxSeconds(true) < EL.fxSeconds(false) and EL.fxSeconds(true) > 0)
	-- expiration de la 2e étape
	local fe = EL.newFlow()
	EL.select(fe, 1, 0, true)
	EL.onPreview(fe, VIEW, 0.1)
	EL.press(fe, 1, true)
	EL.tick(fe, 1 + EL.CONFIRM_SECONDS + 0.1)
	check("La 2e étape expire après CONFIRM_SECONDS : retour à « prêt », rien envoyé", fe.phase == "ready" and fe.armedAt == nil)
	EL.press(fe, 20, true)
	local _, late = EL.press(fe, 20 + EL.CONFIRM_SECONDS + 1, true)
	check("Appui tardif sur « Confirmer » (sans tick entre-temps) : refusé, retour à « prêt »", late == nil and fe.phase == "ready")
	EL.press(fe, 30, true)
	EL.cancel(fe)
	check("« Annuler » ramène à « prêt » (le pet reste choisi)", fe.phase == "ready" and fe.i == 1)
	-- aucun envoi sans confirmation en deux appuis
	local fn = EL.newFlow()
	EL.select(fn, 1, 0, true)
	local _, early = EL.press(fn, 0.1, true)
	check("Appui avant l'aperçu : aucune action", early == nil and fn.phase == "loading")
	-- refus
	T.codes = { "disabled", "slot", "already", "special", "follower", "team", "defense", "busy", "dupes", "coins", "price", "save", "changed" }
	T.refuseOk = true
	for _, code in ipairs(T.codes) do
		local fr = EL.newFlow()
		EL.select(fr, 1, 0, true)
		EL.onPreview(fr, { ok = false, i = 1, code = code, found = 1, need = 3, cost = 99 }, 0.1)
		local b = EL.button(fr, true, E)
		if fr.phase ~= "refused" or b.active ~= false or b.kind ~= "refused" or string.find(b.text, "✖", 1, true) == nil or #b.text < 10 then
			T.refuseOk = false
			print("  refus " .. code)
		end
	end
	check("13 codes de refus du serveur : phase « refused », bouton inactif, texte explicite précédé de « ✖ » (jamais la couleur seule)", T.refuseOk)
	check("Texte « dupes » avec nombres : « Doublons : 1/3 » ; « coins » avec le prix ; code inconnu = repli, jamais vide", string.find(EL.refuseText(E, "dupes", { found = 1, need = 3 }), "1/3", 1, true) ~= nil and string.find(EL.refuseText(E, "coins", { cost = 450 }), "450", 1, true) ~= nil and EL.refuseText(E, "zzz", nil) ~= "" and EL.refuseText(nil, "dupes", nil) ~= "")
	local fr2 = EL.newFlow()
	EL.select(fr2, 1, 0, true)
	EL.onPreview(fr2, { ok = false, i = 1, code = "dupes", found = 2, need = 3 }, 0.1)
	local _, a5 = EL.press(fr2, 1, true)
	check("État refusé : appuyer sur le bouton ne fait rien", a5 == nil and fr2.phase == "refused")
	local _, a6 = EL.select(fr2, 1, 1, true)
	check("État refusé : re-toucher le pet redemande l'aperçu (peut-être de nouveaux doublons)", a6 ~= nil and a6.kind == "preview" and fr2.phase == "loading")
	-- le serveur refuse pendant l'envoi : aperçu ok = false
	local fs2 = EL.newFlow()
	EL.select(fs2, 1, 0, true)
	EL.onPreview(fs2, VIEW, 0.1)
	EL.press(fs2, 1, true)
	EL.press(fs2, 1.1, true)
	EL.onPreview(fs2, { ok = false, i = 1, code = "coins", cost = 120 }, 1.5)
	check("Refus du serveur après l'envoi (« coins ») : phase « refused », plus d'envoi en cours", fs2.phase == "refused" and fs2.sentAt == nil and fs2.msg == "coins")
	-- envoi sans réponse
	local ft = EL.newFlow()
	EL.select(ft, 1, 0, true)
	EL.onPreview(ft, VIEW, 0.1)
	EL.press(ft, 1, true)
	EL.press(ft, 1.1, true)
	local _, tact = EL.tick(ft, 1.1 + EL.SEND_TIMEOUT + 0.1)
	check("Envoi sans réponse : retour à « loading » avec aperçu redemandé (resynchronisation), message « timeout »", ft.phase == "loading" and ft.msg == "timeout" and tact ~= nil and tact.kind == "preview" and tact.i == 1)
	-- « done » d'un autre pet ou hors envoi : ignoré
	local fd = EL.newFlow()
	EL.select(fd, 1, 0, true)
	EL.onPreview(fd, VIEW, 0.1)
	EL.onDone(fd, { k = "done", i = 1 }, 1)
	check("« done » reçu sans envoi en cours : ignoré (aucun faux retour visuel)", fd.phase == "ready")
	EL.press(fd, 1, true)
	EL.press(fd, 1.1, true)
	EL.onDone(fd, { k = "done", i = 5 }, 2)
	check("« done » d'un autre emplacement : ignoré", fd.phase == "sending")
	-- limitation de débit des aperçus côté client
	local fq = EL.newFlow()
	local _, q1 = EL.select(fq, 1, 10, true)
	local _, q2 = EL.select(fq, 2, 10.05, true)
	local q3 = EL.due(fq, 10.1)
	local q4 = EL.due(fq, 10 + EL.PREVIEW_COOLDOWN + 0.01)
	check("Débit : un 2e choix 50 ms plus tard est différé (aucune demande), puis envoyé après le délai, une seule fois", q1 ~= nil and q2 == nil and fq.i == 2 and q3 == nil and q4 ~= nil and q4.i == 2 and EL.due(fq, 11) == nil)
	local fz = EL.newFlow()
	for _, bad_i in ipairs({ 0, -1, 1.5, "a", 0 / 0, math.huge }) do
		local _, z = EL.select(fz, bad_i, 0, true)
		if z ~= nil then
			T.badSel = true
		end
	end
	check("Indices invalides (0, négatif, décimal, texte, NaN, infini) : aucune demande", T.badSel ~= true and fz.phase == "idle")
	check("Entrées invalides dans onPreview / onDone / press / tick : jamais d'erreur", (function()
		local fx = EL.newFlow()
		local ok1 = pcall(EL.onPreview, fx, nil, 0)
		local ok2 = pcall(EL.onPreview, fx, "x", 0)
		local ok3 = pcall(EL.onDone, fx, nil, 0)
		local ok4 = pcall(EL.press, fx, nil, true)
		local ok5 = pcall(EL.tick, fx, nil)
		local ok6 = pcall(EL.cancel, fx)
		local ok7 = pcall(EL.detail, Config, nil, fx)
		return ok1 and ok2 and ok3 and ok4 and ok5 and ok6 and ok7
	end)())
	-- détail du pet choisi
	local fdt = EL.newFlow()
	EL.select(fdt, 1, 0, true)
	EL.onPreview(fdt, VIEW, 0.1)
	local det = EL.detail(On, st0, fdt)
	check("Détail : nom, 2 lignes de gains (+15 % revenu, +10 % force) et 3 pastilles de doublons", det ~= nil and #det.lines == 2 and string.find(det.lines[1], "15 %", 1, true) ~= nil and string.find(det.lines[2], "10 %", 1, true) ~= nil and #det.chips == 3)
	check("Détail : nil sans pet choisi ou si l'emplacement n'est plus un pet", EL.detail(On, st0, EL.newFlow()) == nil and EL.detail(On, { slots = { false } }, fdt) == nil)
	local hdOn = EL.header(On, rowsOn)
	check("En-tête activé : règle « 3 doublons de même rareté + 5 min de revenus » et nombre de pets prêts", hdOn.soon == false and string.find(hdOn.rule, "3 doublons", 1, true) ~= nil and string.find(hdOn.rule, "5 min", 1, true) ~= nil and string.find(hdOn.subtitle, "prêt", 1, true) ~= nil and string.find(EL.header(On, {}).subtitle, "éclore", 1, true) ~= nil)

	---------------------------------------------------------------- 5. Retour visuel : propriétés mesurables
	suite("EvolveLayout.fx : retour visuel court (échelle, halo, étoile) mesuré")
	local f0v, f1v, fmid = EL.fx(0), EL.fx(1), EL.fx(0.5)
	check("fx : départ et fin à l'échelle exacte 1, halo plein au début et éteint à la fin, étoile visible à la fin", f0v.scale == 1 and math.abs(f1v.scale - 1) < 1e-9 and f0v.haloAlpha == 1 and f1v.haloAlpha == 0 and f1v.starAlpha == 1 and f0v.starAlpha == 0)
	check("fx : pic d'échelle 1,25 au milieu, jamais au-dessus ; entrées invalides = fin de l'animation", math.abs(fmid.scale - 1.25) < 1e-9 and EL.fx(nil).scale == 1 and EL.fx("x").haloAlpha == 0 and EL.fx(-5).scale == 1 and EL.fx(9).scale == 1)
	T.fxOk = true
	local prev = EL.fx(0)
	for n = 1, 100 do
		local cur = EL.fx(n / 100)
		if cur.haloAlpha > prev.haloAlpha + 1e-12 or cur.scale > 1.25 + 1e-9 or cur.scale < 1 - 1e-9 or cur.haloTransparency < 0 or cur.haloTransparency > 1 or cur.starAlpha < prev.starAlpha - 1e-12 then
			T.fxOk = false
		end
		prev = cur
	end
	check("fx : halo décroissant, étoile croissante, échelle dans [1 ; 1,25], transparence dans [0 ; 1] sur 100 pas", T.fxOk)

	---------------------------------------------------------------- 6. Disposition : appareils, zone sûre, cibles tactiles
	suite("EvolveLayout.rects : matrice d'appareils, zone sûre, cibles >= 44 px, aucune superposition")
	local DEVICES = { { 360, 640 }, { 320, 568 }, { 375, 667 }, { 390, 844 }, { 412, 915 }, { 360, 480 }, { 640, 360 }, { 568, 320 }, { 667, 375 }, { 844, 390 }, { 932, 430 }, { 480, 360 }, { 1280, 720 }, { 1920, 1080 }, { 768, 1024 }, { 1024, 768 }, { 2560, 1440 } }
	T.lay = { inside = {}, overlap = {}, touch = {}, rows = {} }
	local combos = 0
	for _, d in ipairs(DEVICES) do
		for _, sf in ipairs({ false, true }) do
			combos = combos + 1
			local safe = sf and (d[1] > d[2] and { l = 44, t = 0, r = 44, b = 21 } or { l = 0, t = 47, r = 0, b = 34 }) or nil
			local R = EL.rects(d[1], d[2], safe)
			local tag = d[1] .. "x" .. d[2] .. (sf and "s" or "")
			local list = { R.close, R.header, R.subtitle, R.list, R.detail, R.cancel, R.primary }
			for i = 1, #list do
				local r = list[i]
				if r.x < R.area.x - 1e-6 or r.y < R.area.y - 1e-6 or r.x + r.w > R.area.x + R.area.w + 1e-6 or r.y + r.h > R.area.y + R.area.h + 1e-6 or r.w <= 0 or r.h <= 0 then
					T.lay.inside[#T.lay.inside + 1] = tag .. "#" .. i
				end
				for j = i + 1, #list do
					if EL.overlap(list[i], list[j]) then
						T.lay.overlap[#T.lay.overlap + 1] = tag .. " " .. i .. "/" .. j
					end
				end
			end
			for _, b in ipairs({ R.close, R.cancel, R.primary }) do
				if b.w < EL.MIN_TOUCH or b.h < EL.MIN_TOUCH then
					T.lay.touch[#T.lay.touch + 1] = tag
				end
			end
			if EL.visibleRows(R) < 1 or R.rowH < EL.MIN_TOUCH then
				T.lay.rows[#T.lay.rows + 1] = tag
			end
		end
	end
	check("Disposition : " .. combos .. " combinaisons appareil x zone sûre, tous les éléments dans la zone utile", #T.lay.inside == 0 and combos == #DEVICES * 2)
	if #T.lay.inside > 0 then print("  hors zone : " .. table.concat(T.lay.inside, ", ", 1, math.min(8, #T.lay.inside))) end
	check("Disposition : aucune superposition entre en-tête, liste, détail et boutons", #T.lay.overlap == 0)
	if #T.lay.overlap > 0 then print("  superpositions : " .. table.concat(T.lay.overlap, ", ", 1, math.min(8, #T.lay.overlap))) end
	check("Disposition : fermer, annuler et le bouton principal font au moins 44 x 44 px ; lignes de 44 px au moins, au moins une visible", #T.lay.touch == 0 and #T.lay.rows == 0)
	local Rnan = EL.rects(0 / 0, "x", { l = 9999, t = -5, r = 0 / 0, b = 1e9 })
	check("Entrées invalides (NaN, texte, zone sûre énorme ou négative) : repli sur 640 x 360, rectangles finis et dans la fenêtre", Rnan.vw == 640 and Rnan.vh == 360 and Rnan.panel.w > 0 and Rnan.panel.x >= 0 and Rnan.panel.y >= 0)

	---------------------------------------------------------------- 7. Contraste
	suite("EvolveLayout : accessibilité (contraste >= 4,5:1)")
	T.minC, T.minName = 99, ""
	for _, p in ipairs(EL.textPairs()) do
		local c = EL.contrast(p[2], p[3])
		if c < T.minC then
			T.minC, T.minName = c, p[1]
		end
	end
	check("Tous les couples texte / fond atteignent 4,5:1 (le plus faible : " .. T.minName .. " " .. string.format("%.2f", T.minC) .. ")", T.minC >= 4.5 and #EL.textPairs() >= 12)
	check("Contraste : noir sur blanc = 21, identique = 1", math.abs(EL.contrast({ 0, 0, 0 }, { 255, 255, 255 }) - 21) < 1e-6 and math.abs(EL.contrast({ 9, 9, 9 }, { 9, 9, 9 }) - 1) < 1e-9)

	---------------------------------------------------------------- 8. EvolveUi dans le runtime factice
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local env2 = {}
	for k, v in pairs(RT.env) do
		env2[k] = v
	end
	local EvolveUi = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/EvolveUi.lua"), { debugName = "EvolveUi", environment = env2 })()
	local function descendants(o)
		return #o:GetDescendants()
	end
	local function findAll(root, name)
		local out = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d.Name == name then
				out[#out + 1] = d
			end
		end
		return out
	end
	local function install(cfg, state)
		local gui = RT.instance("ScreenGui", "gui")
		local REvo = RT.instance("RemoteEvent", "Evo")
		local fired, sounds = {}, {}
		local RAction = { FireServer = function(_, a, b) fired[#fired + 1] = { a, b } end }
		local ui = EvolveUi.start({ Config = cfg, Evolution = E, Layout = EL, player = {}, gui = gui, FONT = RT.Enum.Font.GothamBold, RAction = RAction, REvo = REvo, playSound = function(k) sounds[#sounds + 1] = k end, getState = function() return state end, reduced = false })
		return { gui = gui, REvo = REvo, fired = fired, sounds = sounds, ui = ui }
	end
	local function played(h, key)
		for _, k in ipairs(h.sounds) do
			if k == key then
				return true
			end
		end
		return false
	end
	suite("EvolveUi : désactivée (« bientôt », aucun envoi), activée (parcours complet), nettoyage")
	T.err0 = #RT.errors
	local H = install(Config, st0)
	check("Désactivée : l'interface se construit (bouton ✨ et panneau)", H.ui ~= nil and #findAll(H.gui, "EvolveButton") == 1 and #findAll(H.gui, "EvolvePanel") == 1)
	RT.fire(findAll(H.gui, "EvolveButton")[1], "Activated")
	RT.step(0.3)
	local panel = findAll(H.gui, "EvolvePanel")[1]
	check("Désactivée : le panneau s'ouvre et affiche « Bientôt disponible », bouton principal inactif", panel.Visible == true and string.find(findAll(H.gui, "Subtitle")[1].Text, "Bientôt", 1, true) ~= nil and findAll(H.gui, "Primary")[1].Text == "Bientôt disponible" and findAll(H.gui, "Primary")[1].AutoButtonColor == false and #findAll(H.gui, "Row1") == 0)
	RT.fire(findAll(H.gui, "Primary")[1], "Activated")
	RT.fire(findAll(H.gui, "Cancel")[1], "Activated")
	RT.fire(H.REvo, "OnClientEvent", { k = "preview", view = { ok = true, i = 1, sac = { 2, 3, 4 }, cost = 10, need = 3 } })
	RT.fire(H.REvo, "OnClientEvent", { k = "done", i = 1, p = A1, n = 1 })
	RT.step(3)
	check("Désactivée : AUCUN message envoyé au serveur (ni evoPreview ni evolve), même après des appuis et des réponses forcées", #H.fired == 0)
	check("Désactivée : aucune ligne de pet, pas de pastille « prêt »", #findAll(H.gui, "ReadyDot") == 1 and findAll(H.gui, "ReadyDot")[1].Visible == false)
	RT.fire(findAll(H.gui, "Close")[1], "Activated")
	check("Désactivée : fermeture du panneau", panel.Visible == false)
	H.ui.destroy()
	check("Désactivée : destroy retire tout (0 instance restante)", descendants(H.gui) == 0)

	local HS = { cap = 8, slots = { pet(A1), pet(A1), pet(A1), pet(A1), pet(B1) }, equip = {}, battle = { team = {} } }
	local G = install(On, HS)
	check("Activée : pastille « prêt » visible dès la construction (un pet peut évoluer)", findAll(G.gui, "ReadyDot")[1].Visible == true)
	RT.fire(findAll(G.gui, "EvolveButton")[1], "Activated")
	RT.step(0.3)
	local rowsBuilt = 0
	for _, d in ipairs(G.gui:GetDescendants()) do
		if string.sub(d.Name, 1, 3) == "Row" and d.ClassName == "TextButton" then
			rowsBuilt = rowsBuilt + 1
		end
	end
	check("Activée : 5 lignes (un bouton par pet), bouton principal « Choisis un pet » inactif", rowsBuilt == 5 and findAll(G.gui, "Primary")[1].Text == "Choisis un pet" and #G.fired == 0)
	check("Activée : la ligne du pet prêt porte un état écrit « Prêt » (pas seulement une couleur)", string.find(findAll(G.gui, "Row1")[1].Text, "Prêt", 1, true) ~= nil)
	RT.fire(findAll(G.gui, "Row1")[1], "Activated")
	RT.step(0.3)
	check("Activée : toucher un pet envoie UN « evoPreview » avec l'indice, bouton « Vérification… » inactif", #G.fired == 1 and G.fired[1][1] == "evoPreview" and G.fired[1][2] == 1 and findAll(G.gui, "Primary")[1].Text == "Vérification…")
	RT.fire(G.REvo, "OnClientEvent", { k = "preview", view = { ok = true, i = 1, sac = { 2, 3, 4 }, cost = 120, need = 3 } })
	RT.step(0.3)
	check("Aperçu reçu : « ✨ Évoluer (120 🪙) » actif, détail avec gains et doublons #2 #3 #4", string.find(findAll(G.gui, "Primary")[1].Text, "Évoluer (120", 1, true) ~= nil and findAll(G.gui, "Primary")[1].AutoButtonColor == true and string.find(findAll(G.gui, "DetailText")[1].Text, "15 %", 1, true) ~= nil and string.find(findAll(G.gui, "DetailText")[1].Text, "#2", 1, true) ~= nil and string.find(findAll(G.gui, "DetailText")[1].Text, "#4", 1, true) ~= nil)
	RT.fire(findAll(G.gui, "Primary")[1], "Activated")
	RT.step(0.3)
	check("1er appui : rien d'envoyé, bouton « Confirmer… » et « Annuler » visible", #G.fired == 1 and string.find(findAll(G.gui, "Primary")[1].Text, "Confirmer", 1, true) ~= nil and findAll(G.gui, "Cancel")[1].Visible == true)
	RT.step(EL.CONFIRM_SECONDS + 1)
	check("Sans 2e appui : la confirmation expire (retour à « Évoluer »), toujours rien d'envoyé", #G.fired == 1 and string.find(findAll(G.gui, "Primary")[1].Text, "Évoluer (", 1, true) ~= nil and findAll(G.gui, "Cancel")[1].Visible == false)
	RT.fire(findAll(G.gui, "Primary")[1], "Activated")
	RT.fire(findAll(G.gui, "Cancel")[1], "Activated")
	check("« Annuler » désarme la confirmation", #G.fired == 1 and findAll(G.gui, "Cancel")[1].Visible == false)
	RT.fire(findAll(G.gui, "Primary")[1], "Activated")
	RT.fire(findAll(G.gui, "Primary")[1], "Activated")
	RT.fire(findAll(G.gui, "Primary")[1], "Activated")
	T.evolves = 0
	for _, m in ipairs(G.fired) do
		if m[1] == "evolve" then
			T.evolves = T.evolves + 1
		end
	end
	check("2e appui : UN seul « evolve » { i = 1, maxCost = 120 } même avec un 3e appui (aucun double envoi)", T.evolves == 1 and G.fired[#G.fired][1] == "evolve" and G.fired[#G.fired][2].i == 1 and G.fired[#G.fired][2].maxCost == 120 and string.find(findAll(G.gui, "Primary")[1].Text, "Évolution", 1, true) ~= nil)
	local before = descendants(G.gui)
	RT.fire(G.REvo, "OnClientEvent", { k = "done", i = 1, p = A1, n = 1 })
	RT.step(0.1)
	check("Réponse « done » : retour visuel affiché (halo, pet, ★2), bouton « Évolué ! », son de montée de niveau", findAll(G.gui, "EvolveFx")[1].Visible == true and #findAll(G.gui, "Halo") == 1 and #findAll(G.gui, "Star") == 1 and findAll(G.gui, "Primary")[1].Text == "✨ Évolué !" and played(G, "levelup"))
	RT.step(EL.MAX_FX + 0.1)
	check("Le retour visuel disparaît en <= 1,2 s : plus de halo, instances revenues au niveau d'avant", findAll(G.gui, "EvolveFx")[1].Visible == false and #findAll(G.gui, "Halo") == 0 and descendants(G.gui) <= before)
	-- l'évolution est faite côté serveur : le pet est en forme 2 et les doublons ont disparu
	HS.slots = { pet(A1, 2, 1, 2), false, false, false, pet(B1) }
	G.ui.onState()
	RT.step(0.6)
	check("Après évolution (forme 2, doublons disparus) : liste mise à jour, plus aucun envoi", #findAll(G.gui, "Row1") == 1 and string.find(findAll(G.gui, "Row1")[1].Text, "★2", 1, true) ~= nil and #G.fired == 2)
	G.ui.destroy()
	check("Activée : destroy retire tout (0 instance restante)", descendants(G.gui) == 0)

	-- refus du serveur dans l'interface
	local HR = { cap = 8, slots = { pet(A1), pet(A1), pet(A1), pet(A1) }, equip = {}, battle = { team = {} } }
	local R2 = install(On, HR)
	RT.fire(findAll(R2.gui, "EvolveButton")[1], "Activated")
	RT.fire(findAll(R2.gui, "Row1")[1], "Activated")
	RT.fire(R2.REvo, "OnClientEvent", { k = "preview", view = { ok = false, i = 1, code = "defense", need = 3 } })
	RT.step(0.3)
	check("Refus « défense PvP » : message explicite dans le bouton (inactif), son de refus joué, aucun envoi d'évolution", string.find(findAll(R2.gui, "Primary")[1].Text, "défense", 1, true) ~= nil and findAll(R2.gui, "Primary")[1].AutoButtonColor == false and played(R2, "refuse") and #R2.fired == 1)
	-- messages mal formés
	RT.fire(R2.REvo, "OnClientEvent", nil)
	RT.fire(R2.REvo, "OnClientEvent", "x")
	RT.fire(R2.REvo, "OnClientEvent", { k = "preview", view = "x" })
	RT.fire(R2.REvo, "OnClientEvent", { k = "done" })
	RT.fire(R2.REvo, "OnClientEvent", { k = "preview", view = { i = {}, ok = true } })
	RT.step(1)
	R2.ui.destroy()
	RT.step(3)
	check("Messages mal formés, destruction, 3 s de temps virtuel : aucune erreur de script (boucles arrêtées)", #RT.errors == T.err0)
	check("Construction invalide : start retourne nil sans erreur", EvolveUi.start(nil) == nil and EvolveUi.start({}) == nil and EvolveUi.start({ Config = Config, Layout = EL, Evolution = E }) == nil)

	-- 12 ouvertures / fermetures : pas de fuite d'instances
	local LK = install(On, st0)
	local base = descendants(LK.gui)
	for _ = 1, 12 do
		RT.fire(findAll(LK.gui, "EvolveButton")[1], "Activated")
		RT.step(0.3)
		RT.fire(findAll(LK.gui, "Row1")[1], "Activated")
		RT.fire(findAll(LK.gui, "Close")[1], "Activated")
		RT.step(0.3)
	end
	RT.fire(findAll(LK.gui, "EvolveButton")[1], "Activated")
	RT.step(0.3)
	RT.fire(findAll(LK.gui, "Close")[1], "Activated")
	check("12 ouvertures / fermetures : le nombre d'instances ne grandit pas (liste reconstruite, anciennes lignes détruites)", descendants(LK.gui) <= base + 4 * 8)
	LK.ui.destroy()

	---------------------------------------------------------------- 9. Intégration, style
	suite("Interface Évoluer : intégration (Client, place, style) et aucun changement de logique serveur")
	local cl = fs.readFile("roblox/src/StarterPlayerScripts/Client.client.lua")
	check("Client : une seule ligne d'enregistrement (EvolveUi.start avec EvolveLayout, Evolution, remote Evo et RAction)", string.find(cl, "WaitForChild(\"EvolveUi\")", 1, true) ~= nil and string.find(cl, "WaitForChild(\"EvolveLayout\")", 1, true) ~= nil and string.find(cl, "REvo = L15.REvo", 1, true) ~= nil)
	local bp = fs.readFile("roblox/tools/build_place.py")
	check("build_place.py : EvolveLayout dans Shared et EvolveUi dans StarterPlayerScripts", string.find(bp, "(\"EvolveLayout\", \"EvolveLayout.lua\")", 1, true) ~= nil and string.find(bp, "\"EvolveUi\", read(\"StarterPlayerScripts/EvolveUi.lua\")", 1, true) ~= nil)
	local function code(src)
		local out = {}
		for line in string.gmatch(src, "[^\n]*") do
			local cut = string.find(line, "%-%-")
			out[#out + 1] = cut and string.sub(line, 1, cut - 1) or line
		end
		return table.concat(out, "\n")
	end
	local el, eu = code(fs.readFile("roblox/src/ReplicatedStorage/EvolveLayout.lua")), code(fs.readFile("roblox/src/StarterPlayerScripts/EvolveUi.lua"))
	T.styleBad = false
	for _, src in ipairs({ el, eu }) do
		for _, pat in ipairs({ "%+=", "%-=", "math%.atan2", "\n%s*continue%s", "math%.random" }) do
			if string.find(src, pat) then
				T.styleBad = true
			end
		end
	end
	check("EvolveLayout / EvolveUi : ni += / -= ni continue ni math.atan2 ni math.random (lanceur lupa, tests déterministes)", not T.styleBad)
	check("EvolveLayout est pur : aucun require, aucune instance Roblox, aucun service", string.find(el, "require", 1, true) == nil and string.find(el, "Instance.new", 1, true) == nil and string.find(el, "GetService", 1, true) == nil)
	check("Aucune forme payante : ni Robux, ni produit, ni passe, ni achat dans les deux modules", string.find(el .. eu, "Robux", 1, true) == nil and string.find(el .. eu, "Marketplace", 1, true) == nil and string.find(el .. eu, "Product", 1, true) == nil and string.find(el .. eu, "Purchase", 1, true) == nil and string.find(el .. eu, "Pass", 1, true) == nil)
	T.sends = 0
	for _ in string.gmatch(eu, "FireServer%(") do
		T.sends = T.sends + 1
	end
	check("EvolveUi n'envoie que deux actions au serveur (evoPreview et evolve) depuis 3 sites d'appel, via la machine d'états", T.sends == 3 and string.find(eu, "\"evoPreview\"", 1, true) ~= nil and string.find(eu, "\"evolve\"", 1, true) ~= nil)
	check("Aucune action serveur nouvelle : Main.server.lua garde exactement actions.evoPreview et actions.evolve (pas d'autre action evo*)", (function()
		local main = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
		local n = 0
		for _ in string.gmatch(main, "function actions%.evo[%w]*") do
			n = n + 1
		end
		return n == 2
	end)())
end
