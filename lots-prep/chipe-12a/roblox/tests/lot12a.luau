--!nocheck
-- Tests du LOT 12 PARTIE A (moteur de combat PvE refait : Battle.lua, 9 types, charge/spécial, STATS, niveaux, tour de 45 étages).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs } fournis par tests/run_lot12a.py (lupa) ou par tests/run.luau (Lune).
-- Aucune dépendance Roblox. Style : pas de `+=`, pas de `continue` (compatibilité lupa).
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local B = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Battle.lua"), { debugName = "Battle" })()
	local TypeFx = luau.load(fs.readFile("roblox/src/ReplicatedStorage/TypeFx.lua"), { debugName = "TypeFx" })()
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), {
		debugName = "Config",
		environment = { Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end } },
	})()
	local SKILL_KEYS = { "strike", "drain", "heal", "guard", "stun", "focus", "freeze", "chain", "bulwark" }

	-- générateur de test indépendant du moteur (même Park-Miller 48271)
	local function mkRng(seed)
		local s = seed
		return function()
			s = (s * 48271) % 2147483647
			return s / 2147483647
		end
	end

	local function unit(ty, skill, o)
		o = o or {}
		return B.rawUnit({ type = ty, skill = skill, tier = o.tier or 3, level = o.level, scale = o.scale, size = o.size, mut = o.mut, p = o.p })
	end
	local function same(a, b)
		if type(a) ~= type(b) then
			return false
		end
		if type(a) ~= "table" then
			return a == b
		end
		for k, v in pairs(a) do
			if not same(v, b[k]) then
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

	------------------------------------------------------------------------------------------------ D.2 : matrice de types
	suite("Lot 12A : matrice des 9 types (D.2)")
	do
		local T = B.TYPES
		check("9 types distincts, clé Nature conservée (affichée Plante), emoji et libellé pour chacun", #T == 9 and B.TYPE_LABEL.Nature == "Plante" and B.TYPE_EMOJI.Glace ~= nil and B.TYPE_EMOJI.Foudre ~= nil and B.TYPE_EMOJI.Terre ~= nil and (function()
			for _, t in ipairs(T) do
				if not (B.TYPE_EMOJI[t] and B.TYPE_LABEL[t] and B.SPECIAL_NAME[t]) then
					return false
				end
			end
			return true
		end)())
		-- tableau de D.2 recopié tel quel (ligne = attaquant, colonne = défenseur), ordre Feu Eau Plante Glace Foudre Terre Ciel Ombre Lumière
		local order = { "Feu", "Eau", "Nature", "Glace", "Foudre", "Terre", "Ciel", "Ombre", "Lumière" }
		local EXPECT = {
			Feu = { 1, 0.67, 1.5, 1.25, 1, 0.8, 1, 1, 1 },
			Eau = { 1.5, 1, 0.67, 1, 0.8, 1, 1, 1.25, 1 },
			Nature = { 0.67, 1.5, 1, 1, 1, 1, 1, 0.8, 1.25 },
			Glace = { 0.8, 1, 1, 1, 0.67, 1.5, 1.25, 1, 1 },
			Foudre = { 1, 1.25, 1, 1.5, 1, 0.67, 1, 1, 0.8 },
			Terre = { 1.25, 1, 1, 0.67, 1.5, 1, 0.8, 1, 1 },
			Ciel = { 1, 1, 1, 0.8, 1, 1.25, 1, 0.67, 1.5 },
			Ombre = { 1, 0.8, 1.25, 1, 1, 1, 1.5, 1, 0.67 },
			["Lumière"] = { 1, 1, 0.8, 1, 1.25, 1, 0.67, 1.5, 1 },
		}
		local exact, rowsOk, anti, selfOne = true, true, true, true
		for _, a in ipairs(order) do
			local n15, n125, n08, n067, n1 = 0, 0, 0, 0, 0
			for j, d in ipairs(order) do
				local m = B.typeMul(a, d)
				if m ~= EXPECT[a][j] then
					exact = false
				end
				if m == 1.5 then n15 = n15 + 1 elseif m == 1.25 then n125 = n125 + 1 elseif m == 0.8 then n08 = n08 + 1 elseif m == 0.67 then n067 = n067 + 1 else n1 = n1 + 1 end
				local back = B.typeMul(d, a)
				local prod = m * back
				if math.abs(prod - 1) > 1e-9 and math.abs(prod - 1.005) > 1e-9 then
					anti = false
				end
			end
			if not (n15 == 1 and n125 == 1 and n08 == 1 and n067 == 1 and n1 == 5) then
				rowsOk = false
			end
			if B.typeMul(a, a) ~= 1 then
				selfOne = false
			end
		end
		check("Les 81 cases de typeMul reproduisent exactement le tableau de D.2", exact)
		check("Chaque ligne a exactement un 1,5, un 1,25, un 0,8, un 0,67 (et 5 neutres, dont le miroir)", rowsOk and selfOne)
		check("Antisymétrie : m[a][b] x m[b][a] vaut 1 ou 1,005 pour toute paire", anti)
		-- BEATS : 3 triangles de 3 ; BEATS2 : permutation (une sortante, une entrante), aucune ne contredit le primaire
		local function cycleLen(map, start)
			local n, cur = 0, start
			repeat
				cur = map[cur]
				n = n + 1
			until cur == start or n > 20 or cur == nil
			return n
		end
		local tri = true
		for _, t in ipairs(B.TYPES) do
			if cycleLen(B.BEATS, t) ~= 3 then
				tri = false
			end
		end
		local inSeen, perm, noClash = {}, true, true
		for _, t in ipairs(B.TYPES) do
			local d = B.BEATS2[t]
			if not d or inSeen[d] or d == t then
				perm = false
			end
			inSeen[d or "?"] = true
			if d and (B.BEATS[t] == d or B.BEATS[d] == t) then
				noClash = false
			end
		end
		check("BEATS = 3 triangles (Feu>Plante>Eau, Lumière>Ombre>Ciel, Terre>Foudre>Glace)", tri and B.BEATS.Terre == "Foudre" and B.BEATS.Foudre == "Glace" and B.BEATS.Glace == "Terre")
		check("BEATS2 : une relation sortante et une entrante par type, aucune ne contredit BEATS", perm and noClash and B.BEATS2.Feu == "Glace" and B.BEATS2["Lumière"] == "Foudre")
		-- cohérence avec le module de données lot 10 (TypeFx) et la table de faiblesses de Config
		local fxOk = true
		for _, t in ipairs(B.TYPES) do
			if TypeFx.get(t) == nil then
				fxOk = false
			end
		end
		check("Chaque type du moteur a ses effets dans TypeFx (Nature = alias de Plante)", fxOk and TypeFx.ALIASES.Nature == "Plante")
		local weakOk = true
		for _, t in ipairs(B.TYPES) do
			local w = Config.TYPE_WEAK and Config.TYPE_WEAK[B.TYPE_LABEL[t]]
			local wk = w == "Plante" and "Nature" or w
			if not wk or B.BEATS[wk] ~= t then
				weakOk = false
			end
		end
		check("Config.TYPE_WEAK (astuces des PNJ) : le type indiqué comme faiblesse est bien celui qui BAT (x1,5) le type, pour les 9 types", weakOk)
		check("Types inconnus : x1 (aucune erreur)", B.typeMul("?", "Feu") == 1 and B.typeMul("Feu", nil) == 1)
	end

	------------------------------------------------------------------------------------------------ D.3 : charge et spécial
	suite("Lot 12A : charge et spécial au 5e coup (D.3)")
	do
		-- A (Feu, rapide) contre B (Feu, lent) : neutre (x1), beaucoup de PV pour qu'aucun combat ne se termine
		local function duel(tA, tB, skillA)
			local a = unit(tA, skillA or "strike")
			local b = unit(tB, "strike")
			a.hp, a.maxHp, b.hp, b.maxHp = 1e6, 1e6, 1e6, 1e6 -- aucun combat ne se termine
			a.spd, b.spd = 30, 1
			return B.new(7, { a }, { b })
		end
		local st = duel("Feu", "Feu")
		check("Départ : charge 0/5, spécial refusé avec le motif « (0/5) »", st.sides[1].units[1].charge == 0 and B.validate(st, 1, { kind = "skill" }) == "spécial pas prêt (0/5)")
		local pre = true
		local turnWhenReady
		for n = 1, 6 do
			local reason = B.validate(st, 1, { kind = "skill" })
			if reason == nil then
				turnWhenReady = n
				break
			end
			B.turn(st, { kind = "attack" }, { kind = "attack" })
			if n < 5 and B.validate(st, 1, { kind = "skill" }) == nil then
				pre = false
			end
		end
		check("Spécial refusé après 1, 2, 3 et 4 attaques ; DISPONIBLE au 6e tour après 5 attaques neutres", pre and turnWhenReady == 6 and st.sides[1].units[1].charge == 5)
		-- un spécial demandé trop tôt par le client est joué comme une attaque (le serveur ne plante pas, la charge monte)
		local st2 = duel("Feu", "Feu")
		local ev = B.turn(st2, { kind = "skill" }, { kind = "attack" })
		local sawSpecial = false
		for _, e in ipairs(ev) do
			if e.special then
				sawSpecial = true
			end
		end
		check("Spécial exigé avec 0 de charge : joué comme une simple attaque (aucun événement spécial, charge 1)", not sawSpecial and st2.sides[1].units[1].charge == 1)
		-- jouer le spécial consomme 5
		local ev6 = B.turn(st, { kind = "skill" }, { kind = "attack" })
		local special
		for _, e in ipairs(ev6) do
			if e.special and e.side == 1 then
				special = e
			end
		end
		check("Au 6e tour le spécial part (événement `special`, nom du type, dégâts) et consomme 5 de charge (retour à 0)", special ~= nil and special.skill == "strike" and special.name == "Souffle ardent" and special.dmg > 0 and st.sides[1].units[1].charge == 0)
		-- coup super efficace : +1 de charge supplémentaire
		local st3 = duel("Feu", "Nature") -- Feu bat Nature : x1,5 -> +2 par coup
		B.turn(st3, { kind = "attack" }, { kind = "attack" })
		check("Coup super efficace (x1,5) : +2 de charge d'un coup", st3.sides[1].units[1].charge == 2)
		local st3b = duel("Feu", "Glace") -- Feu > Glace en secondaire : x1,25 -> +2
		B.turn(st3b, { kind = "attack" }, { kind = "attack" })
		check("Coup x1,25 : +2 de charge aussi (seuil 1,25)", st3b.sides[1].units[1].charge == 2)
		local st3c = duel("Feu", "Terre") -- Terre bat Feu en secondaire : x0,8 -> +1
		B.turn(st3c, { kind = "attack" }, { kind = "attack" })
		check("Coup peu efficace : +1 seulement", st3c.sides[1].units[1].charge == 1)
		-- un seul coup super efficace suffit pour avoir le spécial au 5e tour (4 attaques)
		local st4 = duel("Feu", "Nature")
		B.turn(st4, { kind = "attack" }, { kind = "attack" }) -- super efficace : charge 2
		st4.sides[2].units[1].type = "Feu" -- la cible redevient neutre
		for _ = 1, 3 do
			B.turn(st4, { kind = "attack" }, { kind = "attack" })
		end
		check("Un coup super efficace + 3 neutres : charge 5, spécial disponible au 5e tour", st4.turn == 4 and st4.sides[1].units[1].charge == 5 and B.validate(st4, 1, { kind = "skill" }) == nil)
		local stc = duel("Feu", "Nature")
		for _ = 1, 4 do
			B.turn(stc, { kind = "attack" }, { kind = "attack" })
		end
		check("La charge est plafonnée à 5 (jamais 6 ou plus)", stc.sides[1].units[1].charge == 5)
		-- un pet étourdi ne charge pas ; le changer de pet conserve la charge
		local sts = duel("Feu", "Feu")
		sts.sides[1].units[1].stun = 1
		B.turn(sts, { kind = "attack" }, { kind = "attack" })
		check("Pet étourdi : passe son tour, ne charge pas, l'étourdissement s'use", sts.sides[1].units[1].charge == 0 and sts.sides[1].units[1].stun == 0)
		local a1, a2, f1 = unit("Feu", "strike"), unit("Eau", "heal"), unit("Feu", "strike")
		for _, u in ipairs({ a1, a2, f1 }) do
			u.hp, u.maxHp = 1e6, 1e6
		end
		local sw = B.new(3, { a1, a2 }, { f1 })
		sw.sides[1].units[1].charge = 3
		B.turn(sw, { kind = "swap", to = 2 }, { kind = "attack" })
		B.turn(sw, { kind = "swap", to = 1 }, { kind = "attack" })
		check("Changer de pet : la charge reste attachée au pet (3 -> 3 après aller-retour)", sw.sides[1].units[1].charge == 3 and sw.sides[1].units[2].charge == 0)

		-- formule des dégâts : atk x mul x typeMul x DAMAGE_MUL x (0,9 + 0,2 r), r = 2e tirage de la graine (1er = ordre des tours)
		local function expectedHit(stt, attacker, mulSkill, tm)
			local _, s = B.nextRnd(stt.rnd)
			local r = B.nextRnd(s)
			return math.max(1, math.floor(attacker.atk * mulSkill * tm * B.DAMAGE_MUL * (0.9 + 0.2 * r) + 0.5))
		end
		local sf = duel("Feu", "Nature")
		local exp = expectedHit(sf, sf.sides[1].units[1], 1, 1.5)
		local evf = B.turn(sf, { kind = "attack" }, { kind = "attack" })
		local got
		for _, e in ipairs(evf) do
			if e.t == "hit" and e.side == 1 then
				got = e.dmg
			end
		end
		check("Dégâts d'une attaque = atk x type x (0,9 + 0,2 r) x DAMAGE_MUL (" .. tostring(got) .. " = " .. exp .. ")", got == exp)

		-- chaque spécial : effet exact
		local function ready(skill, tA, tB, tweak)
			local a = unit(tA or "Feu", skill)
			local b = unit(tB or "Feu", "strike")
			local c = unit("Feu", "strike")
			for _, u in ipairs({ a, b, c }) do
				u.hp, u.maxHp = 1e6, 1e6
			end
			a.spd, b.spd, c.spd = 30, 1, 1
			local s = B.new(11, { a }, { b, c })
			s.sides[1].units[1].charge = 5
			if tweak then
				tweak(s)
			end
			return s
		end
		local function firstHit(events, side)
			for _, e in ipairs(events) do
				if e.t == "hit" and e.side == side then
					return e
				end
			end
		end
		local mulOf = { strike = 2.5, drain = 1.6, stun = 1.2, focus = 1.4, freeze = 1.5, chain = 1.6, bulwark = 1.3 }
		local allDmg = true
		for skill, m in pairs(mulOf) do
			local s = ready(skill)
			local e = expectedHit(s, s.sides[1].units[1], m, 1)
			local h = firstHit(B.turn(s, { kind = "skill" }, { kind = "attack" }), 1)
			if not (h and h.dmg == e and h.special) then
				allDmg = false
				print("  (dégâts " .. skill .. " : attendu " .. e .. ", obtenu " .. tostring(h and h.dmg) .. ")")
			end
		end
		check("Dégâts des 7 spéciaux offensifs : strike x2,5, drain x1,6, stun x1,2, focus x1,4, freeze x1,5, chain x1,6, bulwark x1,3", allDmg)
		do
			local s = ready("drain", "Feu", "Feu", function(x)
				x.sides[1].units[1].hp = 10
			end)
			local s2 = ready("drain", "Feu", "Feu", function(x)
				x.sides[1].units[1].hp = 10
				x.sides[2].units[1].atk = 1
			end)
			local h2 = firstHit(B.turn(s2, { kind = "skill" }, { kind = "attack" }), 1)
			local lostToB = firstHit(s2.log, 2)
			local expectHp = 10 + math.floor(h2.dmg * 0.4) - (lostToB and lostToB.dmg or 0)
			check("drain : PV après = 10 + floor(40 % x " .. h2.dmg .. ") - coup reçu (" .. s2.sides[1].units[1].hp .. " = " .. expectHp .. ")", s2.sides[1].units[1].hp == expectHp)
		end
		do
			local s = ready("heal", "Feu", "Feu", function(x)
				local u = x.sides[1].units[1]
				u.hp = math.floor(u.maxHp * 0.2)
				u.stun = 1
				x.sides[2].units[1].atk = 1
			end)
			local u = s.sides[1].units[1]
			local before = u.hp
			-- le pet est étourdi : il passe son tour (pas de soin) ; on enlève l'étourdissement pour tester le spécial seul puis on teste le retrait
			u.stun = 0
			B.turn(s, { kind = "skill" }, { kind = "attack" })
			local hit = firstHit(s.log, 2)
			local expectHp = before + math.floor(u.maxHp * 0.35 + 0.5) - (hit and hit.dmg or 0)
			check("heal : soigne 35 % des PV max (" .. u.hp .. " = " .. expectHp .. ")", u.hp == expectHp and u.charge == 0)
			local s2 = ready("heal", "Feu", "Feu", function(x)
				x.sides[1].units[1].hp = 10
				x.sides[2].units[1].atk = 1
				x.sides[2].units[1].spd = 99
			end)
			s2.sides[1].units[1].stun = 0
			-- étourdi par l'adversaire (le stun d'un adversaire lent est posé avant) : on le pose à la main entre deux tours
			B.turn(s2, { kind = "attack" }, { kind = "attack" })
			s2.sides[1].units[1].charge = 5
			s2.sides[1].units[1].stun = 0
			B.turn(s2, { kind = "skill" }, { kind = "attack" })
			check("heal : le soin remet aussi à zéro l'étourdissement", s2.sides[1].units[1].stun == 0)
		end
		do
			local s = ready("guard", "Feu", "Feu", function(x)
				x.sides[2].units[1].spd = 99 -- B joue d'abord : le garde n'est pas encore posé, puis on observe les deux coups suivants
			end)
			B.turn(s, { kind = "skill" }, { kind = "attack" })
			check("guard : pose 2 coups réduits à 30 % (guard = 2, keep = 0,3)", s.sides[1].units[1].guard == 2 and s.sides[1].units[1].guardKeep == 0.3)
			local hp0 = s.sides[1].units[1].hp
			local ev1 = B.turn(s, { kind = "attack" }, { kind = "attack" })
			local hitB = firstHit(ev1, 2)
			check("guard : le coup reçu est réduit à 30 % (" .. tostring(hitB and hitB.dmg) .. " pour " .. (hp0 - s.sides[1].units[1].hp) .. " perdus), il reste 1 coup protégé", hitB ~= nil and hp0 - s.sides[1].units[1].hp == hitB.dmg and s.sides[1].units[1].guard == 1)
			B.turn(s, { kind = "attack" }, { kind = "attack" })
			check("guard : après 2 coups la protection disparaît (guard = 0, keep = 1)", s.sides[1].units[1].guard == 0 and s.sides[1].units[1].guardKeep == 1)
			local v = B.view(s)
			check("view : guard est un booléen (l'ancien écran affiche 🛡 seulement si vrai)", v.sides[1].units[1].guard == false)
		end
		do
			local s = ready("bulwark")
			local s2 = ready("bulwark", "Feu", "Feu", function(x)
				x.sides[2].units[1].spd = 1
			end)
			local ev = B.turn(s2, { kind = "skill" }, { kind = "attack" })
			local took = firstHit(ev, 2)
			-- A joue d'abord (rapide) : pose la garde ; B frappe ensuite et subit la réduction -> garde consommée
			check("bulwark : A frappe puis se garde ; le coup de B arrive réduit à 50 % et consomme la garde", took ~= nil and s2.sides[1].units[1].guard == 0 and s2.sides[1].units[1].guardKeep == 1)
			local s3 = ready("bulwark", "Feu", "Feu", function(x)
				x.sides[2].units[1].atk = 1
				x.sides[2].units[1].stun = 5
			end)
			B.turn(s3, { kind = "skill" }, { kind = "attack" })
			check("bulwark : sans coup reçu, la garde de 1 coup à 50 % reste posée", s3.sides[1].units[1].guard == 1 and s3.sides[1].units[1].guardKeep == 0.5)
		end
		do
			local s = ready("stun") -- A (rapide) étourdit B avant qu'il joue : B passe CE tour-ci
			local ev = B.turn(s, { kind = "skill" }, { kind = "attack" })
			local stunnedB = false
			for _, e in ipairs(ev) do
				if e.t == "stunned" and e.side == 2 then
					stunnedB = true
				end
			end
			check("stun (lanceur plus rapide) : l'adversaire passe son tour dans le même tour (événement `stunned`, aucun coup, charge inchangée)", stunnedB and firstHit(ev, 2) == nil and s.sides[2].units[1].charge == 0 and s.sides[2].units[1].stun == 0)
			B.turn(s, { kind = "attack" }, { kind = "attack" })
			check("stun : au tour suivant, B rejoue normalement (charge 1)", s.sides[2].units[1].charge == 1)
			local s2 = ready("stun", "Feu", "Feu", function(x)
				x.sides[1].units[1].spd, x.sides[2].units[1].spd = 1, 30 -- lanceur plus lent : B a déjà joué, l'étourdissement attend le tour suivant
			end)
			B.turn(s2, { kind = "skill" }, { kind = "attack" })
			check("stun (lanceur plus lent) : l'étourdissement est posé et sera subi au tour suivant (stun = 1, charge de B = 1)", s2.sides[2].units[1].stun == 1 and s2.sides[2].units[1].charge == 1)
			B.turn(s2, { kind = "attack" }, { kind = "attack" })
			check("stun : B est étourdi au tour suivant (stun 0, pas de nouvelle charge)", s2.sides[2].units[1].stun == 0 and s2.sides[2].units[1].charge == 1)
		end
		do
			local s = ready("focus")
			B.turn(s, { kind = "skill" }, { kind = "attack" })
			local u = s.sides[1].units[1]
			check("focus : attaque +40 % pendant les 3 tours suivants (focus = 3 après le tour du spécial)", u.focus == 3)
			local e1 = expectedHit(s, u, 1, 1)
			e1 = math.max(1, math.floor(u.atk * 1.4 * B.DAMAGE_MUL * (0.9 + 0.2 * (select(1, (function() local _, s2 = B.nextRnd(s.rnd) return B.nextRnd(s2) end)()))) + 0.5))
			local h = firstHit(B.turn(s, { kind = "attack" }, { kind = "attack" }), 1)
			check("focus : l'attaque suivante utilise atk x 1,4 (" .. tostring(h and h.dmg) .. " = " .. e1 .. ")", h ~= nil and h.dmg == e1)
			B.turn(s, { kind = "attack" }, { kind = "attack" })
			B.turn(s, { kind = "attack" }, { kind = "attack" })
			check("focus : le bonus s'éteint après 3 tours", u.focus == 0)
		end
		do
			local s = ready("freeze", "Feu", "Feu", function(x)
				x.sides[2].units[1].charge = 4
			end)
			local ev = B.turn(s, { kind = "skill" }, { kind = "attack" })
			local d
			for _, e in ipairs(ev) do
				if e.t == "discharge" then
					d = e
				end
			end
			-- B (lent) a frappé après : sa charge a ensuite +1
			check("freeze : l'ennemi perd 2 de charge (4 -> 2 puis +1 de son coup = 3), événement `discharge`", d ~= nil and d.amount == 2 and s.sides[2].units[1].charge == 3)
			local s2 = ready("freeze", "Feu", "Feu", function(x)
				x.sides[2].units[1].charge = 1
				x.sides[2].units[1].stun = 3
			end)
			B.turn(s2, { kind = "skill" }, { kind = "attack" })
			check("freeze : la charge adverse ne devient jamais négative (1 -> 0)", s2.sides[2].units[1].charge == 0)
		end
		do
			local s = ready("chain")
			local ev = B.turn(s, { kind = "skill" }, { kind = "attack" })
			local h, sp = firstHit(ev, 1), nil
			for _, e in ipairs(ev) do
				if e.t == "splash" then
					sp = e
				end
			end
			check("chain : 35 % des dégâts sur le pet suivant en réserve (" .. tostring(sp and sp.dmg) .. " = floor(35 % x " .. tostring(h and h.dmg) .. "))", h ~= nil and sp ~= nil and sp.dmg == math.max(1, math.floor(h.dmg * 0.35)) and sp.to == 2 and s.sides[2].units[2].hp == s.sides[2].units[2].maxHp - sp.dmg)
			local s2 = ready("chain", "Feu", "Feu", function(x)
				x.sides[2].units[2].hp = 1
			end)
			B.turn(s2, { kind = "skill" }, { kind = "attack" })
			check("chain : la réserve peut tomber à 0 PV sans valeur négative ; le combat continue avec le pet actif", s2.sides[2].units[2].hp == 0 and not s2.over)
			local c1, c2 = unit("Feu", "chain"), unit("Feu", "strike")
			c1.hp, c1.maxHp, c2.hp, c2.maxHp = 1e6, 1e6, 1e6, 1e6
			local s3 = B.new(5, { c1 }, { c2 })
			s3.sides[1].units[1].charge = 5
			local ev3 = B.turn(s3, { kind = "skill" }, { kind = "attack" })
			local none = true
			for _, e in ipairs(ev3) do
				if e.t == "splash" then
					none = false
				end
			end
			check("chain : sans pet en réserve, aucun événement de ricochet", none)
		end
		check("SKILLS : 9 compétences, chacune avec un nom ; aucune ne garde l'ancienne recharge `cd`", (function()
			for _, k in ipairs(SKILL_KEYS) do
				local sk = B.SKILLS[k]
				if not sk or not sk.name or sk.cd then
					return false
				end
			end
			return true
		end)())
		-- IA
		local ai1 = ready("heal", "Feu", "Feu", function(x)
			x.sides[1].units[1].hp = x.sides[1].units[1].maxHp
		end)
		check("IA : heal prêt mais PV > 70 % -> elle attend (attaque)", B.aiAction(ai1, 1).kind == "attack")
		ai1.sides[1].units[1].hp = math.floor(ai1.sides[1].units[1].maxHp * 0.5)
		check("IA : heal prêt et PV bas -> spécial", B.aiAction(ai1, 1).kind == "skill")
		local ai2 = ready("guard")
		check("IA : guard prêt mais l'ennemi n'a pas 4+ de charge -> attend", B.aiAction(ai2, 1).kind == "attack")
		ai2.sides[2].units[1].charge = 4
		check("IA : guard prêt et l'ennemi à 4 de charge -> spécial", B.aiAction(ai2, 1).kind == "skill")
		local ai3 = ready("strike")
		check("IA : strike prêt -> spécial dès 5 ; avant 5 -> attaque", B.aiAction(ai3, 1).kind == "skill" and (function()
			ai3.sides[1].units[1].charge = 4
			return B.aiAction(ai3, 1).kind == "attack"
		end)())
		-- changement de pet par l'IA : seulement si le type adverse est très favorable ET le pet blessé ET un meilleur pet existe
		local a, c = unit("Nature", "strike"), unit("Eau", "strike")
		local sx = B.new(1, { a, c }, { unit("Feu", "strike") }) -- Feu bat Nature (x1,5) ; Eau bat Feu
		sx.sides[1].units[1].hp = math.floor(sx.sides[1].units[1].maxHp * 0.4)
		local sw2 = B.aiAction(sx, 1)
		check("IA : Nature blessée face à Feu change pour l'Eau", sw2.kind == "swap" and sw2.to == 2)
		sx.sides[1].units[1].hp = sx.sides[1].units[1].maxHp
		check("IA : pet en bonne santé ne change pas de pet", B.aiAction(sx, 1).kind == "attack")
	end

	------------------------------------------------------------------------------------------------ D.4 : STATS par rareté
	suite("Lot 12A : stats par rareté (D.4)")
	do
		local okOld = true
		local txt = ""
		for old = 2, 6 do -- anciennes raretés 2..6 = raretés 3..7 du lot 9 (Config.TIER_MIGRATE)
			local r = Config.TIER_MIGRATE[old]
			local st = B.STATS[r]
			local ehp, eatk, espd = math.floor(60 * 1.45 ^ (old - 1) + 0.5), math.floor(10 * 1.4 ^ (old - 1) + 0.5), 10 + 2 * old
			if st.hp ~= ehp or st.atk ~= eatk or st.spd ~= espd then
				okOld = false
			end
			txt = txt .. " r" .. r .. "=" .. st.hp .. "/" .. st.atk .. "/" .. st.spd
		end
		check("STATS r = 3, 4, 5, 6, 7 : identiques à l'ancienne formule (60 x 1,45^(t-1), 10 x 1,4^(t-1), 10 + 2t) :" .. txt, okOld and Config.TIER_MIGRATE[2] == 3 and Config.TIER_MIGRATE[6] == 7)
		check("STATS r = 1 : valeur du lot 9 (50/8/12 ; l'ancien 60/10/12 est remplacé pour laisser la place au Peu commun, voir README « Écarts »)", B.STATS[1].hp == 50 and B.STATS[1].atk == 8 and B.STATS[1].spd == 12)
		local grow = true
		for r = 2, 10 do
			if B.power(B.STATS[r]) / B.power(B.STATS[r - 1]) < B.POWER_GROWTH_MIN then
				grow = false
			end
		end
		check("STATS : 10 raretés, puissance croissante d'un facteur >= 1,25 entre raretés consécutives (règle du lot 9)", #B.STATS == 10 and grow)
		-- une unité migrée garde exactement ses stats (taille normale = x1,00, mutation 1 = x1, niveau 1)
		local migrated = true
		for p, d in ipairs(Config.PETS) do
			local u = B.unit(Config, { p = p, s = 2, m = 1 })
			local st = B.STATS[d.tier]
			if u.maxHp ~= st.hp or u.atk ~= st.atk or u.spd ~= st.spd or u.level ~= 1 or u.charge ~= 0 then
				migrated = false
			end
		end
		check("Battle.unit (18 espèces, taille normale, niveau 1) = STATS[rareté] exactement", migrated)
		local xl = B.unit(Config, { p = 1, s = 5, m = 6 })
		local xb = B.STATS[Config.PETS[1].tier]
		check("Bonus de taille et de mutation appliqués aux pv et à l'attaque, jamais à la vitesse", xl.maxHp == math.floor(xb.hp * 1.15 * 1.12 + 0.5) and xl.atk == math.floor(xb.atk * 1.15 * 1.12 + 0.5) and xl.spd == xb.spd)
		-- rien d'achetable ne touche ces stats ni l'XP de pet (lecture du serveur de la copie)
		local main = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
		local rp = main:find("MarketplaceService.ProcessReceipt = function", 1, true)
		local region = rp and main:sub(rp, rp + 14000) or ""
		check("Aucun produit ni passe ne modifie STATS ou l'XP de pet (ProcessReceipt sans `.x =`, `STATS`, `addXp`)", rp ~= nil and region:find("STATS", 1, true) == nil and region:find("addXp", 1, true) == nil and region:find("%.x%s*=") == nil and main:find("Battle.STATS", 1, true) == nil)
		local prodOk = true
		for name, def in pairs(Config.PRODUCTS) do
			local blob = string.lower((def.name or "") .. " " .. (def.desc or ""))
			if def.xp or def.petXp or blob:find("xp", 1, true) or blob:find("expérience", 1, true) or blob:find("niveau de pet", 1, true) then
				prodOk = false
				print("  (produit suspect : " .. name .. ")")
			end
		end
		for name, def in pairs(Config.PASSES or {}) do
			local blob = string.lower((def.name or "") .. " " .. (def.desc or ""))
			if def.xp or def.petXp or blob:find("xp", 1, true) or blob:find("expérience", 1, true) then
				prodOk = false
				print("  (passe suspect : " .. name .. ")")
			end
		end
		check("Config.PRODUCTS / PASSES : aucun produit ne mentionne ni ne porte d'XP de pet", prodOk)
	end

	------------------------------------------------------------------------------------------------ D.6 : XP et niveaux
	suite("Lot 12A : expérience et niveaux de pets (D.6)")
	do
		check("xpTo(L) = floor(40 x L^1,1) : 40, 85...", B.xpTo(1) == 40 and B.xpTo(2) == math.floor(40 * 2 ^ 1.1) and B.xpTo(3) == math.floor(40 * 3 ^ 1.1) and B.xpTo(19) == math.floor(40 * 19 ^ 1.1))
		local sum = 0
		for L = 1, 19 do
			sum = sum + B.xpTo(L)
		end
		check("XP cumulée pour le niveau 20 = " .. sum .. " avec floor(40 x L^1,1) (décision de la gestion, D.6 annonçait ~ 9 600 ; même courbe que PetXp du lot 12 B)", sum == B.XP_CAP and sum == 9734 and B.MAX_LEVEL == 20 and B.XP_BASE == 40 and B.XP_EXP == 1.1)
		check("levelFromXp : 0 -> 1, seuils exacts, niveau 20 au plafond, jamais 21", B.levelFromXp(0) == 1 and B.levelFromXp(39) == 1 and B.levelFromXp(40) == 2 and B.levelFromXp(B.XP_CAP - 1) == 19 and B.levelFromXp(B.XP_CAP) == 20 and B.levelFromXp(1e9) == 20 and B.levelFromXp(nil) == 1 and B.levelFromXp("x") == 1 and B.levelFromXp(-50) == 1)
		local mono = true
		local prev = 0
		for x = 0, B.XP_CAP + 500, 7 do
			local lv = B.levelFromXp(x)
			if lv < prev or lv > 20 then
				mono = false
			end
			prev = lv
		end
		check("Niveau monotone en fonction de l'XP, borné à 20", mono)
		check("addXp : cumul, plafond à l'XP du niveau 20, jamais de recul (négatif, NaN, texte, nil)", B.addXp(0, 100) == 100 and B.addXp(B.XP_CAP - 5, 100) == B.XP_CAP and B.addXp(500, -30) == 500 and B.addXp(500, 0 / 0) == 500 and B.addXp(500, "99") == 599 and B.addXp(500, nil) == 500 and B.addXp(nil, 10) == 10 and B.addXp(B.XP_CAP, 1) == B.XP_CAP and B.addXp(10, 1e30) == B.XP_CAP)
		check("levelMul : +1,5 % par niveau (niveau 1 = x1, niveau 20 = x1,285)", B.levelMul(1) == 1 and math.abs(B.levelMul(2) - 1.015) < 1e-12 and math.abs(B.levelMul(20) - 1.285) < 1e-12 and math.abs(B.levelMul(99) - 1.285) < 1e-12)
		local base = B.unit(Config, { p = 13, s = 2, m = 1 })
		local top = B.unit(Config, { p = 13, s = 2, m = 1, x = B.XP_CAP * 5 })
		local mid = B.unit(Config, { p = 13, s = 2, m = 1, x = B.XP_AT[11] })
		check("Battle.unit niveau 20 : pv et attaque x1,285 (" .. base.maxHp .. " -> " .. top.maxHp .. "), vitesse inchangée, niveau lu dans slot.x", top.level == 20 and top.maxHp == math.floor(base.maxHp * 1.285 + 0.5) and top.atk == math.floor(base.atk * 1.285 + 0.5) and top.spd == base.spd and mid.level == 11 and base.level == 1)
		check("xpReward : PvE gagné 20 + 5 x étage, perdu 5 ; PvP 15 / 5", B.xpReward(true, 3, false) == 35 and B.xpReward(true, 45, false) == 245 and B.xpReward(false, 12, false) == 5 and B.xpReward(true, 0, true) == 15 and B.xpReward(false, 0, true) == 5)
		-- un pet de niveau 20 bat nettement un pet de niveau 1 de même rareté, sans être invincible
		local rnd = mkRng(31)
		local w, n = 0, 600
		for _ = 1, n do
			local a, b = {}, {}
			for k = 1, 3 do
				a[k] = unit(B.TYPES[1 + math.floor(rnd() * 9)], SKILL_KEYS[1 + math.floor(rnd() * 9)], { tier = 4, level = 20 })
				b[k] = unit(B.TYPES[1 + math.floor(rnd() * 9)], SKILL_KEYS[1 + math.floor(rnd() * 9)], { tier = 4, level = 1 })
			end
			if B.run(math.floor(rnd() * 1e9) + 1, a, b).winner == 1 then
				w = w + 1
			end
		end
		check("Équipe niveau 20 contre niveau 1 (même rareté) : gagne plus de 60 % et pas à tous les coups (" .. string.format("%.0f", w * 100 / n) .. " %)", w / n > 0.6 and w / n < 0.995)
	end

	------------------------------------------------------------------------------------------------ Déterminisme et générateur
	suite("Lot 12A : journal déterministe et générateur (Park-Miller 48271)")
	do
		-- vecteur de test publié : x(0) = 1, x(10000) = 399268537 (multiplicateur 48271, modulo 2^31 - 1)
		local s = 1
		local exact = true
		for _ = 1, 10000 do
			local nxt = (s * 48271) % 2147483647
			if nxt ~= math.floor(nxt) or s * 48271 >= 2 ^ 53 then
				exact = false
			end
			s = nxt
		end
		check("Park-Miller 48271 : x(10000) = 399268537 (vecteur de référence), tous les produits < 2^53 (exacts en double)", s == 399268537 and exact and B.RNG_MUL == 48271 and B.RNG_MOD == 2147483647)
		local v, ns = B.nextRnd(1)
		check("nextRnd(1) = (48271 / (2^31 - 1), 48271)", ns == 48271 and math.abs(v - 48271 / 2147483647) < 1e-15)
		local okSeed = true
		for _, sd in ipairs({ 0, 1, -5, 2147483646, 2147483647, 4e9, 1e15, 3.7, 0 / 0, "12", "x" }) do
			local x = B.seedState(sd)
			if type(x) ~= "number" or x < 1 or x > 2147483646 or x ~= math.floor(x) then
				okSeed = false
			end
		end
		check("seedState : toute graine (0, négative, énorme, décimale, NaN, texte) donne un état entier dans 1..2^31 - 2", okSeed)
		-- qualité : 100 000 tirages, 10 classes (chi-deux < 27,9 = seuil 0,1 % à 9 ddl), moyenne proche de 0,5
		local r = mkRng(B.seedState(2024))
		local bins, sum = {}, 0
		for i = 1, 10 do
			bins[i] = 0
		end
		for _ = 1, 100000 do
			local x = r()
			bins[math.floor(x * 10) + 1] = bins[math.floor(x * 10) + 1] + 1
			sum = sum + x
		end
		local chi = 0
		for i = 1, 10 do
			chi = chi + (bins[i] - 10000) ^ 2 / 10000
		end
		check("Qualité du générateur : chi-deux " .. string.format("%.1f", chi) .. " < 27,9 sur 10 classes, moyenne " .. string.format("%.4f", sum / 100000), chi < 27.9 and math.abs(sum / 100000 - 0.5) < 0.005)
		-- graines voisines : les premiers dégâts ne sont pas voisins
		local firsts = {}
		for sd = 1, 6 do
			local st = B.new(sd, { unit("Feu", "strike") }, { unit("Feu", "strike") })
			B.turn(st, { kind = "attack" }, { kind = "attack" })
			for _, e in ipairs(st.log) do
				if e.t == "hit" then
					firsts[#firsts + 1] = e.dmg
					break
				end
			end
		end
		local distinct = {}
		local nd = 0
		for _, d in ipairs(firsts) do
			if not distinct[d] then
				distinct[d] = true
				nd = nd + 1
			end
		end
		check("Graines 1..6 (échauffement du générateur) : dégâts du premier coup variés (" .. nd .. " valeurs distinctes)", nd >= 3)
		-- même graine = même journal complet ; autre graine = autre journal
		local function team(seedT)
			local rr = mkRng(seedT)
			local t = {}
			for k = 1, 3 do
				t[k] = unit(B.TYPES[1 + math.floor(rr() * 9)], SKILL_KEYS[1 + math.floor(rr() * 9)], { tier = 5, size = 1 + math.floor(rr() * 5), mut = 1 + math.floor(rr() * 6), level = 1 + math.floor(rr() * 20) })
			end
			return t
		end
		local all = true
		local diffCount = 0
		for i = 1, 200 do
			local r1 = B.run(i * 104729, team(i), team(i + 1000))
			local r2 = B.run(i * 104729, team(i), team(i + 1000))
			local r3 = B.run(i * 104729 + 1, team(i), team(i + 1000))
			if not (same(r1.log, r2.log) and r1.winner == r2.winner and r1.turn == r2.turn and r1.rnd == r2.rnd) then
				all = false
			end
			if not same(r1.log, r3.log) then
				diffCount = diffCount + 1
			end
		end
		check("200 combats rejoués avec la même graine : journal identique événement par événement (types, dégâts, charges, ordre) ; autre graine : journal différent dans " .. diffCount .. "/200 cas", all and diffCount >= 195)
		-- le journal ne dépend pas de l'historique (on peut rejouer tour par tour avec les actions de l'IA)
		local a, b = team(77), team(78)
		local full = B.run(555, a, b)
		local st = B.new(555, a, b)
		while not st.over do
			B.turn(st, B.aiAction(st, 1), B.aiAction(st, 2))
		end
		check("Rejeu tour par tour (actions de l'IA des deux camps) = Battle.run", same(full.log, st.log))
		check("Battle.new ne modifie pas les équipes passées (copie des unités)", a[1].hp == a[1].maxHp and a[1].charge == 0)
	end

	------------------------------------------------------------------------------------------------ Invariants (fuzz)
	suite("Lot 12A : invariants sous actions aléatoires (valides ou non) et limite de 40 tours")
	do
		check("MAX_TURNS = 40", B.MAX_TURNS == 40)
		local rnd = mkRng(8675309)
		local bad = ""
		local timeouts, maxTurn = 0, 0
		local N = 2500
		for i = 1, N do
			local tier = 1 + math.floor(rnd() * 10)
			local function tm()
				local t = {}
				for k = 1, 3 do
					t[k] = unit(B.TYPES[1 + math.floor(rnd() * 9)], SKILL_KEYS[1 + math.floor(rnd() * 9)], { tier = tier, size = 1 + math.floor(rnd() * 5), mut = 1 + math.floor(rnd() * 6), level = 1 + math.floor(rnd() * 20), scale = 0.5 + rnd() })
				end
				return t
			end
			local st = B.new(i * 7, tm(), tm())
			local guard = 0
			while not st.over and guard < 200 do
				guard = guard + 1
				local function junk()
					local x = rnd()
					if x < 0.4 then
						return { kind = "attack" }
					elseif x < 0.7 then
						return { kind = "skill" }
					elseif x < 0.85 then
						return { kind = "swap", to = math.floor(rnd() * 5) - 1 }
					elseif x < 0.9 then
						return "attack"
					elseif x < 0.95 then
						return { kind = "swap", to = 1.5 }
					end
					return { kind = "explode" }
				end
				B.turn(st, junk(), junk())
				for s = 1, 2 do
					local sd = st.sides[s]
					if sd.active < 1 or sd.active > #sd.units then
						bad = bad .. " actif hors plage"
					end
					for _, u in ipairs(sd.units) do
						if u.hp < 0 or u.hp > u.maxHp or u.charge < 0 or u.charge > 5 or u.guard < 0 or u.stun < 0 or u.focus < 0 or u.hp ~= math.floor(u.hp) then
							bad = bad .. " [" .. i .. ":" .. u.hp .. "/" .. u.maxHp .. " ch" .. u.charge .. " g" .. u.guard .. "]"
						end
					end
				end
			end
			if not st.over or (st.winner ~= 1 and st.winner ~= 2) or st.turn > 40 then
				bad = bad .. " fin invalide " .. i
			end
			if st.log[#st.log].t == "timeout" then
				timeouts = timeouts + 1
			end
			maxTurn = math.max(maxTurn, st.turn)
		end
		check(N .. " combats d'actions aléatoires (dont invalides) : PV, charge, garde, étourdissement toujours dans leurs bornes, fin garantie en <= 40 tours, vainqueur défini" .. (bad == "" and "" or (" : " .. bad:sub(1, 150))), bad == "")
		-- limite de tours : duel de soigneurs/gardes impossible à finir -> gagne le plus de PV (égalité : défenseur)
		local a, b = unit("Feu", "heal", { scale = 1 }), unit("Feu", "heal", { scale = 1 })
		a.atk, b.atk = 0, 0
		a.hp = a.maxHp - 3
		local st = B.new(1, { a }, { b })
		for _ = 1, 60 do
			B.turn(st, { kind = "attack" }, { kind = "attack" })
		end
		check("Limite de 40 tours : le combat s'arrête au tour 40 (timeout), le camp avec le plus de PV restants gagne (égalité : défenseur)", st.over and st.turn == 40 and st.log[#st.log].t == "timeout" and st.winner == 2)
		local tie = B.new(9, { unit("Feu", "strike") }, { unit("Feu", "strike") })
		tie.sides[1].units[1].hp, tie.sides[2].units[1].hp = 0, 0
		B.turn(tie, { kind = "attack" })
		check("Deux camps à terre : le défenseur l'emporte", tie.over and tie.winner == 2)
		-- journal : chaque événement est décrit (aucune chaîne vide) et ne fuit aucune donnée de graine dans la vue
		local st5 = B.run(42, { unit("Feu", "chain"), unit("Eau", "freeze"), unit("Glace", "bulwark") }, { unit("Nature", "drain"), unit("Foudre", "stun"), unit("Ciel", "focus") })
		local desc = true
		local kinds = {}
		for _, e in ipairs(st5.log) do
			kinds[e.t] = true
			if B.describe({ PETS = { { emoji = "x", name = "N" }, { emoji = "y", name = "M" } } }, e) == "" and e.t ~= "turn" then
				desc = false
			end
		end
		local v = B.view(st5)
		local vs = v.sides[1].units[1]
		check("describe : tous les événements du journal ont un texte ; view n'expose ni graine ni état du générateur et ajoute charge/chargeMax/cd/level", desc and v.seed == nil and v.rnd == nil and vs.charge ~= nil and vs.chargeMax == 5 and vs.cd == math.max(0, 5 - vs.charge) and vs.level == 1)
	end

	------------------------------------------------------------------------------------------------ Tour de 45 étages (D.7)
	suite("Lot 12A : tour de 45 étages (D.7)")
	do
		local T = Config.TOWER
		local tiersOk = #T.tiers == 9 and T.tiers[1] == 1 and T.tiers[8] == 8 and T.tiers[9] == 10
		local bossOk = true
		for f = 5, 45, 5 do
			if not T.bosses[f] then
				bossOk = false
			end
		end
		check("Config.TOWER : 45 étages, raretés { 1..8, 10 } par paliers de 5, 9 boss (5, 10, ..., 45), Reine de Cristal / Démon enchaîné / Séraphin aux étages 35 / 40 / 45", T.floors == 45 and tiersOk and bossOk and T.bosses[35] == "Reine de Cristal" and T.bosses[40] == "Démon enchaîné" and T.bosses[45] == "Séraphin" and T.teamSize == 3)
		local mapOk = true
		for f = 1, 45 do
			if Config.towerTier(f) ~= T.tiers[1 + (f - 1) // 5] then
				mapOk = false
			end
		end
		check("towerTier(f) = tiers[1 + (f - 1) // 5] pour les 45 étages ; étages > 45 plafonnés à la dernière rareté", mapOk and Config.towerTier(46) == 10 and Config.towerTier(0) == 1)
		local det, sizes, up = true, true, true
				for f = 1, 45 do
			local t1, t2 = B.towerTeam(Config, f), B.towerTeam(Config, f)
			if #t1 ~= 3 or not same(t1, t2) then
				det = false
			end
			for _, u in ipairs(t1) do
				if u.tier ~= Config.towerTier(f) or u.maxHp ~= math.floor(B.STATS[u.tier].hp * Config.towerScale(f) + 0.5) or u.level ~= 1 or not u.type or not u.skill then
					sizes = false
				end
			end
			if f % 5 == 1 and f > 5 then
				if t1[1].maxHp <= B.towerTeam(Config, f - 5)[1].maxHp then
					up = false
				end
			end
		end
		check("Équipes des 45 étages : 3 unités, déterministes, stats = STATS[rareté de l'étage] x towerScale, niveau 1, type et spécial définis ; le premier étage de chaque rareté est plus fort que le premier de la précédente", det and sizes and up)
		local bossScale = true
		for f = 5, 45, 5 do
			if math.abs(Config.towerScale(f) / Config.towerScale(f - 1) - 1.2 * 0.97 / 0.94) > 1e-9 and Config.towerScale(f) <= Config.towerScale(f - 1) then
				bossScale = false
			end
		end
		check("Boss (étages multiples de 5) : plus forts que l'étage précédent (towerScale x1,2)", bossScale)
		-- un combat sur chaque étage va au bout (équipe de même rareté contre l'étage)
		local rnd = mkRng(4242)
		local fine = true
		for f = 1, 45 do
			local tier = Config.towerTier(f)
			local mine = {}
			for k = 1, 3 do
				mine[k] = unit(B.TYPES[1 + math.floor(rnd() * 9)], SKILL_KEYS[1 + math.floor(rnd() * 9)], { tier = tier })
			end
			local r = B.run(f * 31, mine, B.towerTeam(Config, f))
			if not r.over or r.turn > 40 then
				fine = false
			end
		end
		check("Un combat sur chacun des 45 étages se termine en <= 40 tours", fine)
	end

	------------------------------------------------------------------------------------------------ Équilibrage
	suite("Lot 12A : 10 000 combats IA contre IA à rareté égale (équilibrage des 9 types, durée)")
	do
		local N = 10000
		local rnd = mkRng(99991)
		local RARS = { 1, 3, 4, 5, 6, 7, 8, 10 }
		local function monoTeam(ty, r)
			local t = {}
			for k = 1, 3 do
				t[k] = unit(ty, SKILL_KEYS[1 + math.floor(rnd() * 9)], { tier = r, size = 1 + math.floor(rnd() * 5), mut = 1 + math.floor(rnd() * 6) })
			end
			return t
		end
		local wins, plays, turns, timeouts = {}, {}, 0, 0
		for _, t in ipairs(B.TYPES) do
			wins[t], plays[t] = 0, 0
		end
		local aw = 0
		for _ = 1, N do
			local r = RARS[1 + math.floor(rnd() * #RARS)]
			local ta, tb = B.TYPES[1 + math.floor(rnd() * 9)], B.TYPES[1 + math.floor(rnd() * 9)]
			local res = B.run(math.floor(rnd() * 1e9) + 1, monoTeam(ta, r), monoTeam(tb, r))
			turns = turns + res.turn
			if res.log[#res.log].t == "timeout" then
				timeouts = timeouts + 1
			end
			if res.winner == 1 then
				aw = aw + 1
			end
			if ta ~= tb then -- les miroirs ne disent rien du type
				plays[ta], plays[tb] = plays[ta] + 1, plays[tb] + 1
				if res.winner == 1 then
					wins[ta] = wins[ta] + 1
				else
					wins[tb] = wins[tb] + 1
				end
			end
		end
		local hi, lo, txt = 0, 1, ""
		for _, t in ipairs(B.TYPES) do
			local q = wins[t] / plays[t]
			hi, lo = math.max(hi, q), math.min(lo, q)
			txt = txt .. " " .. B.TYPE_LABEL[t]:sub(1, 3) .. string.format("%.1f", q * 100)
		end
		local mean = turns / N
		print("  (taux de victoire par type :" .. txt .. " ; durée moyenne " .. string.format("%.2f", mean) .. " tours ; " .. timeouts .. " fins par limite de tours ; camp A " .. string.format("%.1f", aw * 100 / N) .. " %)")
		check(N .. " combats : aucun type au-dessus de 56 % de victoires (maximum " .. string.format("%.1f", hi * 100) .. " %, minimum " .. string.format("%.1f", lo * 100) .. " %)", hi <= 0.56 and lo >= 0.44)
		check("Durée moyenne d'un combat : " .. string.format("%.2f", mean) .. " tours (cible 8 à 14)", mean >= 8 and mean <= 14)
		check("Fins par limite de tours : " .. timeouts .. " sur " .. N .. " (moins de 2 %) ; camp A (joueur) gagne " .. string.format("%.1f", aw * 100 / N) .. " % (ni avantage de camp, ni de vitesse)", timeouts / N < 0.02 and math.abs(aw / N - 0.5) < 0.03)

		-- même mesure avec les 18 espèces RÉELLES du jeu (types et compétences fixés par espèce), équipes aléatoires de même rareté
		local ids = {}
		for i, d in ipairs(Config.PETS) do
			ids[d.tier] = ids[d.tier] or {}
			ids[d.tier][#ids[d.tier] + 1] = i
		end
		local tiers = {}
		for t in pairs(ids) do
			tiers[#tiers + 1] = t
		end
		table.sort(tiers)
		local function realTeam(tier)
			local t = {}
			for k = 1, 3 do
				local p = ids[tier][1 + math.floor(rnd() * #ids[tier])]
				t[k] = B.unit(Config, { p = p, s = 1 + math.floor(rnd() * 5), m = 1 + math.floor(rnd() * 6) })
			end
			return t
		end
		local w2, n2, tt = {}, {}, 0
		for _, t in ipairs(B.TYPES) do
			w2[t], n2[t] = 0, 0
		end
		local M = 10000
		for _ = 1, M do
			local tier = tiers[1 + math.floor(rnd() * #tiers)]
			local a, b = realTeam(tier), realTeam(tier)
			local res = B.run(math.floor(rnd() * 1e9) + 1, a, b)
			tt = tt + res.turn
			for _, un in ipairs(a) do
				n2[un.type] = n2[un.type] + 1
				if res.winner == 1 then
					w2[un.type] = w2[un.type] + 1
				end
			end
			for _, un in ipairs(b) do
				n2[un.type] = n2[un.type] + 1
				if res.winner == 2 then
					w2[un.type] = w2[un.type] + 1
				end
			end
		end
		local hi2, txt2 = 0, ""
		for _, t in ipairs(B.TYPES) do
			if n2[t] > 0 then
				local q = w2[t] / n2[t]
				hi2 = math.max(hi2, q)
				txt2 = txt2 .. " " .. B.TYPE_LABEL[t]:sub(1, 3) .. string.format("%.1f", q * 100)
			end
		end
		print("  (espèces réelles, équipes mixtes :" .. txt2 .. " ; durée moyenne " .. string.format("%.2f", tt / M) .. ")")
		check(M .. " combats avec les espèces réelles de Config.PETS : aucun type au-dessus de 56 % (maximum " .. string.format("%.1f", hi2 * 100) .. " %), durée moyenne " .. string.format("%.2f", tt / M) .. " tours dans 8-14", hi2 <= 0.56 and tt / M >= 8 and tt / M <= 14)
	end
end
