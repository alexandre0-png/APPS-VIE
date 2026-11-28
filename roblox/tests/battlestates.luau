--!nocheck
-- Tests du COMBAT, suite de la refonte (écarts de BattleUi du commit cf15a4b) : pastilles d'états sous les cartes (seulement les états du moteur du lot 12A), écran
-- « Changer » (PV et charge de chaque pet, pet K.O. grisé et non cliquable), flash du spécial, sons par action (Config.SOUNDS seulement, SOUNDS_ENABLED respecté),
-- XP à l'écran de fin (message du serveur seulement), accessibilité. Logique PURE dans BattleLayout, instances dans BattleScene (runtime factice).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau ou tests/run_battlestates.py).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, pas de LCG > 2^53 (Park-Miller 48271 mod 2^31-1), état partagé dans la table T (limite de 200 variables locales).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local T = {}
	local color = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local L = load("roblox/src/ReplicatedStorage/BattleLayout.lua", "BattleLayout")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", { Color3 = color })
	local Battle = load("roblox/src/ReplicatedStorage/Battle.lua", "Battle")
	local PetXp = load("roblox/src/ReplicatedStorage/PetXp.lua", "PetXp")
	local function rng(seed)
		local s = seed
		return function()
			s = (s * 48271) % 2147483647
			return s / 2147483647
		end
	end
	local function clone(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	local function inside(r, a)
		return r.x >= a.x - 1e-6 and r.y >= a.y - 1e-6 and r.x + r.w <= a.x + a.w + 1e-6 and r.y + r.h <= a.y + a.h + 1e-6
	end
	local DEVICES = { { 360, 640 }, { 320, 568 }, { 375, 667 }, { 390, 844 }, { 412, 915 }, { 360, 480 }, { 640, 360 }, { 568, 320 }, { 667, 375 }, { 844, 390 }, { 932, 430 }, { 480, 360 }, { 1280, 720 }, { 1920, 1080 }, { 768, 1024 }, { 1024, 768 }, { 2560, 1440 } }
	local function safeFor(d, sf)
		return sf and (d[1] > d[2] and { l = 44, t = 0, r = 44, b = 21 } or { l = 0, t = 47, r = 0, b = 34 }) or nil
	end

	---------------------------------------------------------------- 1. États : seulement ceux du moteur
	suite("États : pastilles tirées de la vue du moteur (stun, guard, focus), rien d'inventé")
	local teamA, teamB = Battle.towerTeam(Config, 3), Battle.towerTeam(Config, 4)
	local v0 = Battle.view(Battle.new(7, teamA, teamB))
	local keys = {}
	for k in pairs(v0.sides[1].units[1]) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	check("Champs d'une unité de la vue du moteur : exactement p, s, m, type, hp, maxHp, skill, level, charge, chargeMax, cd, guard, stun, focus (un nouvel état du moteur fera échouer ce test : il faudra l'afficher)", table.concat(keys, ",") == "cd,charge,chargeMax,focus,guard,hp,level,m,maxHp,p,s,skill,stun,type")
	check("Les pastilles couvrent exactement les trois états du moteur, dans l'ordre stun, guard, focus", table.concat(L.STATUS_ORDER, ",") == "stun,guard,focus" and #L.STATUS_ORDER == L.MAX_PILLS)
	check("Aucune pastille pour une unité saine, K.O., absente ou invalide", #L.statusPills({ hp = 10, stun = 0, guard = false, focus = 0 }) == 0 and #L.statusPills({ hp = 0, stun = 2, guard = true, focus = 3 }) == 0 and #L.statusPills(nil) == 0 and #L.statusPills("x") == 0 and #L.statusPills({}) == 0 and #L.statusPills({ hp = 0 / 0, stun = 1 }) == 0)
	local all3 = L.statusPills({ hp = 10, stun = 2, guard = true, focus = 3 })
	check("Trois états à la fois : 3 pastilles, ordre stun, guard, focus ; chaque texte porte une icône (jamais la couleur seule) ; durée en chiffre pour stun et focus, aucun chiffre pour guard", #all3 == 3 and all3[1].key == "stun" and all3[2].key == "guard" and all3[3].key == "focus" and all3[1].text == "💫 2" and all3[2].text == "🛡" and all3[3].text == "⚡ 3" and all3[2].turns == nil)
	check("Durées absurdes (NaN, négatif, texte, énorme) : ignorées ou bornées à 99", #L.statusPills({ hp = 5, stun = 0 / 0, focus = -3, guard = "yes" }) == 0 and L.statusPills({ hp = 5, stun = 1e9 })[1].turns == 99)
	check("Info-bulle : étourdi (1 tour / n tours), garde (aucun chiffre inventé), concentration (+40 % lu dans Battle.SKILLS, n tours)", string.find(L.pillDetail(all3[1], Battle), "2 prochains tours", 1, true) ~= nil and string.find(L.pillDetail(L.statusPills({ hp = 5, stun = 1 })[1], Battle), "son prochain tour", 1, true) ~= nil and string.find(L.pillDetail(all3[3], Battle), "+40 %", 1, true) ~= nil and string.find(L.pillDetail(all3[3], Battle), "3 tours", 1, true) ~= nil and string.find(L.pillDetail(all3[2], Battle), "%d") == nil and string.find(L.pillDetail(all3[2], Battle), "🛡", 1, true) ~= nil)
	check("Info-bulle : pastille invalide = texte vide, sans erreur ; bonus de concentration suit Battle.SKILLS.focus.boost", L.pillDetail(nil) == "" and L.pillDetail({}) == "" and L.pillDetail({ key = "zzz" }) == "" and string.find(L.pillDetail(all3[3], { SKILLS = { focus = { boost = 1.5 } } }), "+50 %", 1, true) ~= nil and string.find(L.pillDetail(all3[3]), "+40 %", 1, true) ~= nil)
	-- vrais combats : toutes les compétences l'une contre l'autre
	local skills = { "strike", "drain", "heal", "guard", "stun", "focus", "freeze", "chain", "bulwark" }
	local seen, fights, turns, badPill = { stun = 0, guard = 0, focus = 0 }, 0, 0, 0
	local rnd = rng(20261128)
	for _, sa in ipairs(skills) do
		for _, sb in ipairs(skills) do
			local function team(sk)
				local t = {}
				for k = 1, 3 do
					t[k] = Battle.rawUnit({ p = k, type = ({ "Feu", "Eau", "Nature" })[k], skill = sk, tier = 3 + k, level = 1 + k })
				end
				return t
			end
			local st = Battle.new(1000 + fights, team(sa), team(sb))
			fights = fights + 1
			local guardN = 0
			while not st.over and guardN < 60 do
				guardN = guardN + 1
				local act = Battle.aiAction(st, 1)
				if rnd() < 0.15 then
					act = { kind = "swap", to = 1 + math.floor(rnd() * 3) }
				end
				Battle.turn(st, act)
				turns = turns + 1
				local v = Battle.view(st)
				for side = 1, 2 do
					local sd = v.sides[side]
					for _, u in ipairs(sd.units) do
						local pills = L.statusPills(u)
						local want = {}
						if u.hp > 0 and u.stun > 0 then want[#want + 1] = "stun" end
						if u.hp > 0 and u.guard then want[#want + 1] = "guard" end
						if u.hp > 0 and u.focus > 0 then want[#want + 1] = "focus" end
						local got = {}
						for _, p in ipairs(pills) do
							got[#got + 1] = p.key
							seen[p.key] = seen[p.key] + 1
							if p.text == "" or L.pillDetail(p, Battle) == "" or #pills > 3 then
								badPill = badPill + 1
							end
						end
						if table.concat(got, ",") ~= table.concat(want, ",") then
							badPill = badPill + 1
						end
					end
				end
			end
		end
	end
	check("Vrais combats (" .. fights .. " combats, " .. turns .. " tours, toutes compétences) : les pastilles reflètent exactement stun, guard et focus de la vue, jamais un état absent (" .. seen.stun .. " étourdi, " .. seen.guard .. " garde, " .. seen.focus .. " concentration observés)", badPill == 0 and seen.stun > 2 and seen.guard > 5 and seen.focus > 5)

	---------------------------------------------------------------- 2. Pastilles : disposition
	suite("Pastilles : disposition (appareils, zone sûre) : >= 44 px, dans la zone, sans AUCUNE superposition, repli « +n » faute de place")
	T.pill = { inside = {}, overlap = {}, touch = {}, cap0 = {}, reduced = 0, cases = 0, merged = 0 }
	for _, d in ipairs(DEVICES) do
		for _, sf in ipairs({ false, true }) do
			local R = L.rects(d[1], d[2], safeFor(d, sf))
			local tag = d[1] .. "x" .. d[2] .. (sf and "s" or "")
			local others = { R.foeCard, R.meCard, R.log, R.actions.attack, R.actions.special, R.actions.swap, R.actions.flee, R.speed, R.skip, R.queue }
			for nf = 0, 3 do
				for nm = 0, 3 do
					T.pill.cases = T.pill.cases + 1
					local lay = L.pillLayout(R, nf, nm)
					local all = {}
					for side = 1, 2 do
						local n = side == 2 and nf or nm
						local ls = lay[side]
						if ls.cap < 1 and n > 0 then
							T.pill.cap0[#T.pill.cap0 + 1] = tag .. " s" .. side
						end
						if ls.shown ~= math.min(n, ls.cap) or #ls.rects ~= ls.shown then
							T.pill.inside[#T.pill.inside + 1] = tag .. " shown"
						end
						if ls.cap < 3 and n > ls.cap then
							T.pill.reduced = T.pill.reduced + 1
						end
						if (ls.overflow > 0) ~= (n > ls.cap and ls.cap >= 1) then
							T.pill.inside[#T.pill.inside + 1] = tag .. " overflow"
						end
						for i, r in ipairs(ls.rects) do
							if not inside(r, R.area) then
								T.pill.inside[#T.pill.inside + 1] = tag .. " s" .. side .. " " .. nf .. "/" .. nm .. "#" .. i
							end
							if r.w < L.MIN_TOUCH or r.h < L.MIN_TOUCH then
								T.pill.touch[#T.pill.touch + 1] = tag
							end
							for j, o2 in ipairs(others) do
								if L.overlap(r, o2) then
									T.pill.overlap[#T.pill.overlap + 1] = tag .. " s" .. side .. " " .. nf .. "/" .. nm .. "#" .. i .. "/o" .. j
								end
							end
							for _, q in ipairs(all) do
								if L.overlap(r, q) then
									T.pill.overlap[#T.pill.overlap + 1] = tag .. " pastilles " .. nf .. "/" .. nm
								end
							end
						end
						for _, r in ipairs(ls.rects) do
							all[#all + 1] = r
						end
					end
				end
			end
		end
	end
	check("Pastilles : " .. T.pill.cases .. " cas (17 appareils x zone sûre x 0 à 3 états par camp), toutes dans la zone utile, comptes cohérents", #T.pill.inside == 0)
	if #T.pill.inside > 0 then print("  hors zone : " .. table.concat(T.pill.inside, ", ", 1, math.min(8, #T.pill.inside))) end
	check("Pastilles : aucune ne recouvre une carte, le journal, un bouton, la vitesse, « Passer » ou l'ordre du tour ; aucune entre elles (" .. T.pill.reduced .. " cas avec repli « +n » faute de place)", #T.pill.overlap == 0)
	if #T.pill.overlap > 0 then print("  superpositions : " .. table.concat(T.pill.overlap, ", ", 1, math.min(8, #T.pill.overlap))) end
	check("Pastilles : zone tactile d'au moins 44 x 44 px ; chaque camp garde au moins une place sur tous les appareils (aucun état n'est entièrement caché)", #T.pill.touch == 0 and L.PILL_H >= 44 and L.PILL_W >= 44 and #T.pill.cap0 == 0)
	if #T.pill.cap0 > 0 then print("  sans place : " .. table.concat(T.pill.cap0, ", ", 1, math.min(8, #T.pill.cap0))) end
	check("pillRects : nombre borné (0 à 3), valeurs invalides sans erreur", #L.pillRects(1, L.rects(640, 360), 99) == 3 and #L.pillRects(2, L.rects(640, 360), -4) == 0 and #L.pillRects(1, L.rects(640, 360), 0 / 0) == 0 and #L.pillRects(2, L.rects(640, 360), nil) == 0)
	local three = L.statusPills({ hp = 5, stun = 2, guard = true, focus = 3 })
	local c3, c2, c1 = L.pillChips(three, 3, Battle), L.pillChips(three, 2, Battle), L.pillChips(three, 1, Battle)
	check("Puces : 3 places = 3 puces ; 2 places = 1 puce + « +2 » (détails des deux états regroupés, sur 2 lignes) ; 1 place = « +3 » ; 0 place = rien ; jamais un état perdu", #c3 == 3 and c3[1].merged == false and #c2 == 2 and c2[2].text == "+2" and c2[2].merged == true and select(2, string.gsub(c2[2].detail, "\n", "")) == 1 and string.find(c2[2].detail, "Garde", 1, true) ~= nil and string.find(c2[2].detail, "Concentration", 1, true) ~= nil and #c1 == 1 and c1[1].text == "+3" and #L.pillChips(three, 0, Battle) == 0 and #L.pillChips(nil, 3, Battle) == 0)
	check("Disposition large (1280 x 720) : les 3 + 3 pastilles tiennent sans repli", (function()
		local lay = L.pillLayout(L.rects(1280, 720), 3, 3)
		return lay[1].shown == 3 and lay[2].shown == 3 and lay[1].overflow == 0 and lay[2].overflow == 0
	end)())
	check("pillLayout : valeurs invalides (nil, NaN, négatif, énorme) sans erreur", pcall(L.pillLayout, L.rects(640, 360), nil, nil) and pcall(L.pillLayout, L.rects(640, 360), 0 / 0, -2) and L.pillLayout(L.rects(640, 360), 99, 99)[1].shown <= 3)

	---------------------------------------------------------------- 3. Écran Changer
	suite("Écran « Changer » : lignes (PV, charge, état), pet K.O. et pet au combat non cliquables, disposition")
	local sideRows = { active = 2, units = {
		{ p = 3, hp = 40, maxHp = 80, level = 4, charge = 3, chargeMax = 5, stun = 0, guard = false, focus = 0 },
		{ p = 4, hp = 80, maxHp = 80, level = 5, charge = 5, chargeMax = 5, stun = 0, guard = true, focus = 0 },
		{ p = 7, hp = 0, maxHp = 60, level = 2, charge = 1, chargeMax = 5, stun = 1, guard = true, focus = 2 },
	} }
	local rows = L.swapRows(sideRows)
	check("3 lignes : pet 1 disponible, pet 2 au combat (affiché, non cliquable), pet 3 K.O.", #rows == 3 and rows[1].state == "ready" and rows[1].clickable == true and rows[2].state == "active" and rows[2].clickable == false and rows[2].active == true and rows[3].state == "ko" and rows[3].clickable == false and rows[3].alive == false)
	check("Chaque ligne porte PV (« 40/80 »), niveau, charge (« Charge 3/5 »), pastilles « ●●●○○ » et un état ÉCRIT (🔁 Changer / ▶ Au combat / 💀 K.O.) : jamais la couleur seule", rows[1].hpText == "40/80" and rows[1].level == "Niv. 4" and rows[1].chargeText == "Charge 3/5" and rows[1].pipsText == "●●●○○" and string.find(rows[1].tag, "Changer", 1, true) ~= nil and string.find(rows[2].tag, "Au combat", 1, true) ~= nil and string.find(rows[3].tag, "K.O.", 1, true) ~= nil and rows[2].chargeReady == true and rows[2].pipsText == "●●●●●")
	check("Barre de PV : fraction 0,5 / 1 / 0 ; un pet K.O. n'a aucune pastille d'état ; un pet vivant garde les siennes", rows[1].frac == 0.5 and rows[2].frac == 1 and rows[3].frac == 0 and #rows[3].statuses == 0 and #rows[2].statuses == 1 and rows[2].statuses[1].key == "guard")
	check("Cas limites : équipe vide, nil, unités invalides, PV négatifs ou NaN, plus de 6 pets", #L.swapRows(nil) == 0 and #L.swapRows({}) == 0 and #L.swapRows({ units = {} }) == 0 and L.swapRows({ active = 1, units = { "x", { hp = -5, maxHp = 10 }, { hp = 0 / 0 } } })[1].state == "ko" and #L.swapRows({ active = 1, units = { {}, {}, {}, {}, {}, {}, {}, {} } }) == 6)
	check("Le pet actif peut aussi être K.O. (changement forcé) : état « ko », non cliquable ; sans actif valide : le premier est l'actif", L.swapRows({ active = 1, units = { { hp = 0, maxHp = 5 }, { hp = 5, maxHp = 5 } } })[1].clickable == false and L.swapRows({ active = 1, units = { { hp = 0, maxHp = 5 }, { hp = 5, maxHp = 5 } } })[2].clickable == true and L.swapRows({ units = { { hp = 5, maxHp = 5 }, { hp = 5, maxHp = 5 } } })[1].state == "active")
	T.swap = { inside = {}, overlap = {}, touch = {}, cols = 0 }
	local swapCombos = 0
	for _, d in ipairs(DEVICES) do
		for _, sf in ipairs({ false, true }) do
			for n = 1, 6 do
				swapCombos = swapCombos + 1
				local R = L.rects(d[1], d[2], safeFor(d, sf))
				local S = L.swapRects(d[1], d[2], safeFor(d, sf), n)
				local tag = d[1] .. "x" .. d[2] .. (sf and "s" or "") .. " n" .. n
				if S.cols == 2 then
					T.swap.cols = T.swap.cols + 1
				end
				local list = { S.title, S.note, S.back }
				for i = 1, n do
					list[#list + 1] = S.rows[i]
				end
				if #S.rows ~= n then
					T.swap.inside[#T.swap.inside + 1] = tag .. " rows"
				end
				if not inside(S.panel, R.area) then
					T.swap.inside[#T.swap.inside + 1] = tag .. " panel"
				end
				for i, r in ipairs(list) do
					if r == nil or not inside(r, S.panel) then
						T.swap.inside[#T.swap.inside + 1] = tag .. "#" .. i
					elseif i > 3 and (r.h < L.MIN_TOUCH or r.w < L.MIN_TOUCH) or (i == 3 and (r.h < L.MIN_TOUCH or r.w < L.MIN_TOUCH)) then
						T.swap.touch[#T.swap.touch + 1] = tag .. "#" .. i
					end
					for j = 1, i - 1 do
						if r and list[j] and L.overlap(r, list[j]) then
							T.swap.overlap[#T.swap.overlap + 1] = tag .. " " .. i .. "/" .. j
						end
					end
				end
			end
		end
	end
	check("Écran Changer : " .. swapCombos .. " cas (appareils x zone sûre x 1 à 6 pets) : panneau dans la zone utile, titre, note, lignes et « Retour » dans le panneau", #T.swap.inside == 0)
	if #T.swap.inside > 0 then print("  hors zone : " .. table.concat(T.swap.inside, ", ", 1, math.min(8, #T.swap.inside))) end
	check("Écran Changer : aucune superposition ; chaque ligne et « Retour » font au moins 44 px de haut et de large (2 colonnes sur " .. T.swap.cols .. " cas trop bas pour 44 px par ligne)", #T.swap.overlap == 0 and #T.swap.touch == 0)
	if #T.swap.overlap > 0 then print("  superpositions : " .. table.concat(T.swap.overlap, ", ", 1, math.min(8, #T.swap.overlap))) end
	if #T.swap.touch > 0 then print("  trop petit : " .. table.concat(T.swap.touch, ", ", 1, math.min(8, #T.swap.touch))) end
	check("swapRects : valeurs invalides (nil, NaN, 0, 99 pets) sans erreur et bornées", #L.swapRects(nil, nil, nil, nil).rows == 3 and #L.swapRects(0 / 0, "x", { l = 1e9 }, 99).rows == 6 and #L.swapRects(640, 360, nil, 0).rows == 1)

	---------------------------------------------------------------- 4. Flash du spécial
	suite("Flash du spécial : transitions, durée < 1,5 s, animation de charge mesurée")
	local function tr(a, b)
		return L.specialTransition(a, b)
	end
	check("Transition : flash seulement quand la charge du MÊME pet passe de pas pleine à pleine", tr({ key = "1:1", full = false }, { key = "1:1", full = true }) == "flash" and tr({ key = "1:1", full = true }, { key = "1:1", full = true }) == "set" and tr({ key = "1:1", full = true }, { key = "1:1", full = false }) == "set" and tr({ key = "1:1", full = false }, { key = "1:1", full = false }) == "set")
	check("Transition : jamais au changement de pet, à la 1re vue ou sur entrée invalide", tr({ key = "1:1", full = false }, { key = "2:2", full = true }) == "set" and tr(nil, { key = "1:1", full = true }) == "set" and tr({ key = "1:1", full = false }, nil) == "set" and tr("x", "y") == "set" and tr({ full = false }, { full = true }) == "set")
	T.flashOk, T.flashMax = true, 0
	for _, sp in ipairs({ 1, 2, 3, 0, -5, 99, 0 / 0, "x", 1.5 }) do
		for _, red in ipairs({ true, false, nil }) do
			local d = L.flashSeconds(red, sp)
			T.flashMax = math.max(T.flashMax, d)
			if d <= 0 or d > 1.5 or d ~= d then
				T.flashOk = false
			end
		end
	end
	check("Durée du flash : toujours entre 0 et 1,5 s (max mesuré " .. string.format("%.2f", T.flashMax) .. " s), plus courte en effets réduits et à vitesse 3x", T.flashOk and L.MAX_FLASH <= 1.5 and L.flashSeconds(true, 1) < L.flashSeconds(false, 1) and L.flashSeconds(false, 3) < L.flashSeconds(false, 1))
	local fa, fb, fm = L.specialFlash(0), L.specialFlash(1), L.specialFlash(0.5)
	check("Image du flash : départ voile quasi plein et échelle 1 ; milieu échelle 1,12 ; fin voile transparent (1), échelle 1 exacte, contour éteint", math.abs(fa.scale - 1) < 1e-9 and fa.veilTransparency < 0.3 and math.abs(fm.scale - 1.12) < 1e-9 and fb.veilTransparency == 1 and math.abs(fb.scale - 1) < 1e-9 and fb.strokeAlpha == 0 and fa.strokeAlpha == 1)
	T.fOk = true
	local pv = L.specialFlash(0)
	for n = 1, 100 do
		local c = L.specialFlash(n / 100)
		if c.veilTransparency < pv.veilTransparency - 1e-12 or c.veilTransparency > 1 or c.scale < 1 - 1e-9 or c.scale > 1.12 + 1e-9 or c.strokeAlpha > pv.strokeAlpha + 1e-12 then
			T.fOk = false
		end
		pv = c
	end
	check("Flash : voile de plus en plus transparent, échelle dans [1 ; 1,12], contour décroissant sur 100 pas ; entrées invalides = fin", T.fOk and L.specialFlash(nil).scale == 1 and L.specialFlash("x").veilTransparency == 1 and L.specialFlash(-3).scale == 1)
	check("Animation de charge : fraction charge / max (0, 0,4, 1) ; valeurs invalides = 0", L.chargeFill(0, 5) == 0 and L.chargeFill(2, 5) == 0.4 and L.chargeFill(5, 5) == 1 and L.chargeFill(9, 5) == 1 and L.chargeFill(nil, 5) == 0 and L.chargeFill(0 / 0, 5) == 0)
	T.stopsOk = true
	local rs = rng(99)
	for n = 0, 200 do
		local f = n <= 100 and n / 100 or rs() * 1.4 - 0.2
		local st2 = L.chargeStops(f, 0.55)
		if st2[1].t ~= 0 or st2[#st2].t ~= 1 then
			T.stopsOk = false
		end
		for i = 2, #st2 do
			if not (st2[i].t > st2[i - 1].t) or st2[i].m < 0 or st2[i].m > 1 then
				T.stopsOk = false
			end
		end
	end
	check("Dégradé de charge : points strictement croissants de 0 à 1 (exigence de ColorSequence), multiplicateurs dans [0 ; 1], coupure à la fraction de charge", T.stopsOk and #L.chargeStops(0.4) == 4 and L.chargeStops(0.4)[2].t == 0.4 and L.chargeStops(1)[1].m == 1 and L.chargeStops(0)[1].m == 0.55 and #L.chargeStops(nil) == 2 and #L.chargeStops("x") == 2)

	---------------------------------------------------------------- 5. Sons
	suite("Sons par action : Config.SOUNDS seulement, SOUNDS_ENABLED respecté, rien d'inventé")
	local needed = { "special_ready", "special_hit", "battle_start", "battle_win", "battle_lose", "click", "refuse", "atk_feu", "atk_eau", "atk_plante", "atk_glace", "atk_foudre", "atk_terre", "atk_ciel", "atk_ombre", "atk_lumiere" }
	T.missing = {}
	for _, k in ipairs(needed) do
		if L.soundKey(Config, k) ~= k then
			T.missing[#T.missing + 1] = k
		end
	end
	check("Les 16 clés utilisées existent dans Config.SOUNDS avec un identifiant : " .. (#T.missing > 0 and table.concat(T.missing, ", ") or "toutes présentes"), #T.missing == 0)
	T.atkOk = true
	for _, typ in ipairs(Battle.TYPES) do
		local key = Config.ATK_SOUND[typ] or Config.ATK_SOUND[Battle.TYPE_LABEL[typ]]
		if key == nil or L.soundKey(Config, key) == nil then
			T.atkOk = false
		end
	end
	check("Chacun des 9 types du moteur a un son d'attaque (Config.ATK_SOUND -> Config.SOUNDS), « Nature » = atk_plante", T.atkOk and Config.ATK_SOUND.Nature == "atk_plante")
	local Off = clone(Config)
	Off.SOUNDS_ENABLED = false
	check("SOUNDS_ENABLED = false : aucune clé jouable, plan vide", L.soundKey(Off, "click") == nil and #L.soundPlan(Off, { { t = "hit", side = 1, dmg = 5, mul = 1, p = 1 } }, { typeOf = function() return "Feu" end }) == 0)
	local NoId = clone(Config)
	NoId.SOUNDS = clone(Config.SOUNDS)
	NoId.SOUNDS.click = { id = "", speed = 1, vol = 0.4 }
	check("Son sans identifiant ou clé inconnue / invalide : jamais jouable, sans erreur", L.soundKey(NoId, "click") == nil and L.soundKey(Config, "zzz") == nil and L.soundKey(Config, nil) == nil and L.soundKey(nil, "click") == nil and L.soundKey({}, "click") == nil and L.soundKey(Config, 42) == nil)
	local typeOf = function(p) return Battle.SPECIES_TYPE[p] end
	local evs = {
		{ t = "turn", n = 1 },
		{ t = "hit", side = 1, dmg = 9, mul = 1, p = 6 },
		{ t = "hit", side = 2, dmg = 30, mul = 1.5, special = true, skill = "strike", p = 3 },
		{ t = "swap", side = 1, to = 2, p = 4 },
		{ t = "heal", side = 2, amount = 12, p = 4 },
		{ t = "guard", side = 1, p = 4 },
		{ t = "swap", side = 2, to = 3, forced = true, p = 7 },
		{ t = "ko", side = 2 },
	}
	local plan = L.soundPlan(Config, evs, { typeOf = typeOf, speed = 1 })
	check("Plan d'un tour : attaque = son du type de l'attaquant (" .. tostring(plan[1] and plan[1].key) .. "), spécial = special_hit, changement voulu = click ; soin, garde, K.O., changement forcé : silence (aucun son n'existe)", #plan == 3 and plan[1].kind == "attack" and plan[1].key == Config.ATK_SOUND[Battle.SPECIES_TYPE[6]] and plan[2].key == "special_hit" and plan[3].key == "click")
	check("Instants alignés sur les animations : 0 s, 0,6 s, puis 1,2 s (le changement voulu passe après les 2 coups) ; vitesse 2x : moitié ; croissants", plan[1].at == 0 and math.abs(plan[2].at - 0.6) < 1e-9 and math.abs(plan[3].at - 1.2) < 1e-9 and math.abs(L.soundPlan(Config, evs, { typeOf = typeOf, speed = 2 })[2].at - 0.3) < 1e-9)
	check("attackSounds = false (les effets de type jouent déjà l'attaque) : plus de son d'attaque, le spécial et le changement restent", (function()
		local p2 = L.soundPlan(Config, evs, { typeOf = typeOf, attackSounds = false })
		return #p2 == 2 and p2[1].key == "special_hit" and p2[2].key == "click"
	end)())
	check("Type inconnu (typeOf absent ou nil) : pas de son d'attaque, pas d'erreur ; événements invalides ignorés", #L.soundPlan(Config, { { t = "hit", side = 1, dmg = 1, mul = 1, p = 1 } }, nil) == 0 and #L.soundPlan(Config, { { t = "hit", side = 1, dmg = 1, mul = 1, p = 1 } }, { typeOf = function() return "Zzz" end }) == 0 and #L.soundPlan(Config, nil, nil) == 0 and #L.soundPlan(Config, { "x", 5, {}, { t = "hit" } }, nil) == 0 and #L.soundPlan(nil, evs, nil) == 0)
	T.planOk = true
	local rp = rng(31337)
	local kinds = { "hit", "heal", "guard", "swap", "ko", "splash", "turn", "buff", "stunned", "discharge", "zzz" }
	for _ = 1, 300 do
		local list = {}
		for i = 1, 1 + math.floor(rp() * 8) do
			list[i] = { t = kinds[1 + math.floor(rp() * #kinds)], side = 1 + math.floor(rp() * 2), dmg = rp() * 50, mul = ({ 0.67, 0.8, 1, 1.25, 1.5 })[1 + math.floor(rp() * 5)], special = rp() < 0.3, forced = rp() < 0.3, p = 1 + math.floor(rp() * 18), amount = rp() * 20 }
		end
		local okp, pl = pcall(L.soundPlan, Config, list, { typeOf = typeOf, speed = 1 + math.floor(rp() * 3) })
		if not okp then
			T.planOk = false
		else
			local lastAt = -1
			for _, e in ipairs(pl) do
				if Config.SOUNDS[e.key] == nil or Config.SOUNDS[e.key].id == "" or e.at < lastAt then
					T.planOk = false
				end
				lastAt = e.at
			end
		end
	end
	check("Fuzz Park-Miller (300 tours aléatoires) : toute clé du plan existe dans Config.SOUNDS avec un id, instants croissants, jamais d'erreur", T.planOk)
	local codeSrc = {}
	for _, path in ipairs({ "roblox/src/ReplicatedStorage/BattleLayout.lua", "roblox/src/StarterPlayerScripts/BattleScene.lua", "roblox/src/StarterPlayerScripts/BattleUi.lua" }) do
		codeSrc[#codeSrc + 1] = fs.readFile(path)
	end
	local joined = table.concat(codeSrc, "\n")
	check("Aucun identifiant de son codé en dur (rbxassetid) dans BattleLayout, BattleScene ni BattleUi : tout passe par Config.SOUNDS", string.find(joined, "rbxassetid", 1, true) == nil and string.find(joined, "rbxasset:", 1, true) == nil)

	---------------------------------------------------------------- 6. XP de fin
	suite("XP à l'écran de fin : lue dans le message « end » du serveur seulement")
	check("Message sans XP (cas actuel du serveur) : aucune ligne, rien d'inventé", #L.xpLines({ k = "end", win = true, rewards = { coins = 5 } }, Config, PetXp) == 0 and #L.xpLines(nil, Config, PetXp) == 0 and #L.xpLines("x", Config, PetXp) == 0 and #L.xpLines({}, Config, PetXp) == 0)
	local l1 = L.xpLines({ k = "end", xp = 12 }, Config, PetXp)
	check("XP numérique (champ xp ou rewards.xp) : « ⭐ +12 XP pour chaque pet de l'équipe »", #l1 == 1 and l1[1] == "⭐ +12 XP pour chaque pet de l'équipe" and L.xpLines({ rewards = { xp = 7 } }, Config)[1] == "⭐ +7 XP pour chaque pet de l'équipe")
	local total = PetXp.CUM[3] + 5 -- niveau 3 atteint (juste après le seuil)
	local l2 = L.xpLines({ k = "end", xp = { { p = 3, gain = 20, total = total }, { p = 4, gain = 5, total = total } } }, Config, PetXp)
	check("XP par pet : nom, gain et montée de niveau détectée avec PetXp (« ⬆ Niv. 2 → 3 ») ; pas de montée = pas de flèche", #l2 == 2 and string.find(l2[1], "+20 XP", 1, true) ~= nil and string.find(l2[1], "Niv. 2 → 3", 1, true) ~= nil and string.find(l2[2], "⬆", 1, true) == nil and string.find(l2[1], Config.PETS[3].name, 1, true) ~= nil)
	check("Sans PetXp : le gain s'affiche, pas de niveau ; valeurs invalides (0, négatif, NaN, texte, espèce inconnue) ignorées ou repliées ; au plus 4 lignes", #L.xpLines({ xp = { { p = 3, gain = 20, total = total } } }, Config, nil) == 1 and string.find(L.xpLines({ xp = { { p = 3, gain = 20, total = total } } }, Config, nil)[1], "⬆", 1, true) == nil and #L.xpLines({ xp = 0 }, Config) == 0 and #L.xpLines({ xp = -4 }, Config) == 0 and #L.xpLines({ xp = 0 / 0 }, Config) == 0 and #L.xpLines({ xp = "12" }, Config) == 0 and #L.xpLines({ xp = { { p = 3, gain = "x" }, { gain = 0 }, "y" } }, Config) == 0 and #L.xpLines({ xp = { { p = 999, gain = 4 } } }, Config) == 1 and #L.xpLines({ xp = { { p = 1, gain = 1 }, { p = 1, gain = 1 }, { p = 1, gain = 1 }, { p = 1, gain = 1 }, { p = 1, gain = 1 }, { p = 1, gain = 1 } } }, Config) == 4)
	check("Gain absurde plafonné à 100 000", string.find(L.xpLines({ xp = 1e12 }, Config)[1], "+100000 XP", 1, true) ~= nil)

	---------------------------------------------------------------- 7. Accessibilité et plafond
	suite("Accessibilité (contraste >= 4,5:1) et plafond d'instances avec les nouveaux éléments")
	T.minC, T.minName, T.badPairs = 99, "", {}
	for _, p in ipairs(L.textPairs()) do
		local c = L.contrast(p[2], p[3])
		if c < T.minC then
			T.minC, T.minName = c, p[1]
		end
		if c < 4.5 then
			T.badPairs[#T.badPairs + 1] = p[1]
		end
	end
	check("Tous les couples texte / fond (" .. #L.textPairs() .. ", dont pastilles, écran Changer, bouton en charge) atteignent 4,5:1 ; le plus faible : " .. T.minName .. " " .. string.format("%.2f", T.minC), #T.badPairs == 0 and #L.textPairs() >= 25)
	check("Chaque pastille d'état a une couleur de fond propre ET une icône propre (états distinguables sans la couleur)", (function()
		local seenIcon, seenBg = {}, {}
		for _, key in ipairs(L.STATUS_ORDER) do
			local d = L.STATUS_UI[key]
			local bgk = table.concat(d.bg, ",")
			if seenIcon[d.icon] or seenBg[bgk] then
				return false
			end
			seenIcon[d.icon], seenBg[bgk] = true, true
		end
		return true
	end)())
	T.capOk, T.minDecor = true, 99
	for n1 = 1, 6 do
		for n2 = 1, 6 do
			local full, red = L.plan({ units1 = n1, units2 = n2 }), L.plan({ units1 = n1, units2 = n2, reduced = true })
			if full.estimate > 200 or red.estimate > 200 then
				T.capOk = false
			end
			T.minDecor = math.min(T.minDecor, red.decor)
		end
	end
	check("Plafond : estimation <= 200 pour toutes les équipes de 1 à 6 pets avec pastilles, écran Changer et flash (décor mobile minimal : " .. T.minDecor .. ")", T.capOk and T.minDecor > 0)

	---------------------------------------------------------------- 8. BattleScene dans le runtime factice
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local env2 = {}
	for k, v in pairs(RT.env) do
		env2[k] = v
	end
	local BattleScene = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/BattleScene.lua"), { debugName = "BattleScene", environment = env2 })()
	local BattleUi = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/BattleUi.lua"), { debugName = "BattleUi", environment = env2 })()
	local function findAll(root, name)
		local out = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d.Name == name then
				out[#out + 1] = d
			end
		end
		return out
	end
	local function descendants(o)
		return #o:GetDescendants()
	end
	local function newGui()
		local g = RT.instance("ScreenGui", "gui")
		g.Enabled = true
		return g
	end
	local function mkView(modify)
		local st = Battle.new(4242, Battle.towerTeam(Config, 2), Battle.towerTeam(Config, 5))
		local v = Battle.view(st)
		if modify then
			modify(v)
		end
		return v
	end
	local function mkScene(view, extra)
		local gui = newGui()
		local fired, sounds = {}, {}
		local o = { gui = gui, Config = Config, Battle = Battle, Layout = L, player = { DisplayName = "Moi", UserId = 1 }, payload = { duel = true }, view = view, foeName = "Rival", floor = 0,
			reduced = false, specialState = function(u) return BattleUi.specialState(Config, Battle, u) end,
			fire = function(a, arg) fired[#fired + 1] = { a, arg } end, sound = function(k) sounds[#sounds + 1] = k end }
		for k, v in pairs(extra or {}) do
			o[k] = v
		end
		local sc, err = BattleScene.create(o)
		return { sc = sc, err = err, gui = gui, fired = fired, sounds = sounds }
	end
	local function count(list, key)
		local n = 0
		for _, k in ipairs(list) do
			if k == key then
				n = n + 1
			end
		end
		return n
	end
	suite("BattleScene : pastilles d'état, info-bulle, écran Changer, flash du spécial, sons")
	T.err0 = #RT.errors
	local H = mkScene(mkView(function(v)
		v.sides[1].units[1].stun, v.sides[1].units[1].guard, v.sides[1].units[1].focus = 2, true, 3
		v.sides[2].units[1].guard = true
	end))
	check("Scène construite avec états sur les deux camps : 6 pastilles préparées (3 par camp), seules les pastilles utiles visibles", H.sc ~= nil and #findAll(H.gui, "StatePill") == 6)
	local vis = {}
	for _, p in ipairs(findAll(H.gui, "StatePill")) do
		if p.Visible == true then
			vis[#vis + 1] = p.Text
		end
	end
	table.sort(vis)
	local joined2 = table.concat(vis, "|")
	check("Pastilles visibles : « 💫 2 », « ⚡ 3 » et « 🛡 » (joueur) + « 🛡 » (adversaire) ; chaque texte porte une icône", #vis == 4 and string.find(joined2, "💫 2", 1, true) ~= nil and string.find(joined2, "⚡ 3", 1, true) ~= nil and count(vis, "🛡") == 2)
	local pills = findAll(H.gui, "StatePill")
	local target
	for _, p in ipairs(pills) do
		if p.Visible == true and p.Text == "💫 2" then
			target = p
		end
	end
	RT.fire(target, "Activated")
	local tip = findAll(H.gui, "StateTip")[1]
	check("Toucher la pastille ouvre l'info-bulle : icône, nom et durée (« 2 prochains tours »)", tip.Visible == true and string.find(tip.Text, "Étourdi", 1, true) ~= nil and string.find(tip.Text, "2 prochains tours", 1, true) ~= nil and #H.fired == 0)
	RT.fire(target, "Activated")
	check("Toucher la même pastille referme l'info-bulle", tip.Visible == false)
	RT.fire(target, "Activated")
	RT.step(L.TIP_SECONDS + 0.5)
	check("L'info-bulle disparaît seule après 3 s", tip.Visible == false)
	-- l'état disparaît : la pastille aussi
	H.sc.update(mkView(), nil)
	local anyVisible = 0
	for _, p in ipairs(findAll(H.gui, "StatePill")) do
		if p.Visible == true then
			anyVisible = anyVisible + 1
		end
	end
	check("Mise à jour sans état : plus aucune pastille visible", anyVisible == 0)
	-- pet K.O. : pas de pastille
	H.sc.update(mkView(function(v)
		v.sides[2].units[1].hp, v.sides[2].units[1].guard = 0, true
	end), nil)
	anyVisible = 0
	for _, p in ipairs(findAll(H.gui, "StatePill")) do
		if p.Visible == true then
			anyVisible = anyVisible + 1
		end
	end
	check("Pet K.O. avec un état résiduel : pas de pastille", anyVisible == 0)
	-- placement : la disposition pure garantit l'absence de superposition (testée ci-dessus) ; le runtime factice ne lit pas les UDim2, donc seule l'absence d'erreur est vérifiée ici
	H.sc.update(mkView(function(v)
		v.sides[1].units[1].guard = true
		v.sides[2].units[1].guard = true
	end), nil)
	check("Mise à jour avec une pastille par camp : aucune erreur de script", #RT.errors == T.err0)
	H.sc.destroy()

	-- écran Changer
	local HS = mkScene(mkView(function(v)
		v.sides[1].units[2].hp = 0
		v.sides[1].units[3].charge = 4
		v.sides[1].units[3].hp = math.floor(v.sides[1].units[3].maxHp / 2)
	end))
	local before = descendants(HS.gui)
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	local scr = findAll(HS.gui, "SwapScreen")[1]
	local r2, r3 = findAll(HS.gui, "SwapRow2")[1], findAll(HS.gui, "SwapRow3")[1]
	check("Écran Changer : 3 lignes avec PV et charge de chaque pet, la charge 4/5 et les PV du pet 3 sont écrits", scr ~= nil and #findAll(HS.gui, "SwapRow1") == 1 and string.find(r3.Text, "Charge 4/5", 1, true) ~= nil and string.find(r3.Text, "●●●●○", 1, true) ~= nil and string.find(r3.Text, tostring(math.floor(mkView().sides[1].units[3].maxHp / 2)), 1, true) ~= nil)
	check("Pet K.O. : ligne grisée, « 💀 K.O. », bouton non actif ; pet au combat : « Au combat », non actif ; pet disponible : actif", string.find(r2.Text, "💀", 1, true) ~= nil and string.find(r2.Text, "K.O.", 1, true) ~= nil and r2.AutoButtonColor == false and r2.Active == false and string.find(findAll(HS.gui, "SwapRow1")[1].Text, "Au combat", 1, true) ~= nil and findAll(HS.gui, "SwapRow1")[1].AutoButtonColor == false and r3.AutoButtonColor == true and r3.Active == true)
	RT.fire(r2, "Activated")
	RT.fire(findAll(HS.gui, "SwapRow1")[1], "Activated")
	check("Toucher le pet K.O. ou le pet au combat : rien n'est envoyé (son de refus), l'écran reste ouvert", #HS.fired == 0 and findAll(HS.gui, "SwapScreen")[1] ~= nil and count(HS.sounds, "refuse") == 2)
	RT.fire(findAll(HS.gui, "Flee")[1], "Activated")
	check("Fuir pendant l'écran Changer : toujours un premier appui de confirmation (« Sûr ? »), rien envoyé", findAll(HS.gui, "Flee")[1].Text == "Sûr ?" and #HS.fired == 0)
	check("Fuir referme aussi l'écran Changer (le premier appui ne l'efface pas du jeu : il se rouvre)", #findAll(HS.gui, "SwapScreen") == 0)
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	check("Le bouton « Changer » ouvre puis referme l'écran (bascule)", #findAll(HS.gui, "SwapScreen") == 0)
	RT.step(3.5)
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	RT.fire(findAll(HS.gui, "SwapRow3")[1], "Activated")
	check("Pet disponible : « swap3 » envoyé UNE fois (intention seule), écran refermé, son « click »", #HS.fired == 1 and HS.fired[1][1] == "battleAct" and HS.fired[1][2] == "swap3" and #findAll(HS.gui, "SwapScreen") == 0 and count(HS.sounds, "click") >= 1)
	check("Le nombre d'instances revient au niveau d'avant l'ouverture (écran détruit, rien ne traîne)", descendants(HS.gui) == before)
	-- 30 ouvertures / fermetures
	local base = descendants(HS.gui)
	for _ = 1, 30 do
		RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
		RT.fire(findAll(HS.gui, "SwapBack")[1], "Activated")
	end
	check("30 ouvertures / fermetures de l'écran Changer : aucune instance de plus, aucune connexion qui s'accumule", descendants(HS.gui) == base and HS.sc.count() <= L.MAX_INSTANCES)
	-- plus aucun pet vivant en réserve : bouton inactif
	HS.sc.update(mkView(function(v)
		v.sides[1].units[2].hp, v.sides[1].units[3].hp = 0, 0
	end), nil)
	HS.fired = {}
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	check("Aucun pet vivant en réserve : « Changer » n'ouvre rien", #findAll(HS.gui, "SwapScreen") == 0 and findAll(HS.gui, "Swap")[1].AutoButtonColor == false)
	-- l'écran se ferme quand la vue change
	HS.sc.update(mkView(), nil)
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	HS.sc.update(mkView(), nil)
	check("Une nouvelle vue du serveur referme l'écran Changer (jamais d'écran périmé)", #findAll(HS.gui, "SwapScreen") == 0)
	RT.fire(findAll(HS.gui, "Swap")[1], "Activated")
	HS.sc.setDim(true)
	check("Scène assombrie (résultat) : l'écran Changer et les pastilles disparaissent", #findAll(HS.gui, "SwapScreen") == 0)
	HS.sc.destroy()
	check("destroy : plus aucune instance", descendants(HS.gui) == 0)
	local HE = mkScene(mkView())
	RT.fire(findAll(HE.gui, "Swap")[1], "Activated")
	HE.sc.destroy()
	check("destroy avec l'écran Changer ouvert : plus aucune instance, aucune erreur", descendants(HE.gui) == 0)

	-- flash du spécial
	local HF = mkScene(mkView(function(v)
		v.sides[1].units[1].charge = 4
	end))
	local special = findAll(HF.gui, "Special")[1]
	local veil, scale = findAll(HF.gui, "SpecialFlash")[1], findAll(HF.gui, "SpecialScale")[1]
	check("Charge 4/5 : pas de flash, voile caché, échelle 1, bouton « Spécial 4/5 »", veil.Visible == false and scale.Scale == 1 and special.Text == "Spécial 4/5" and count(HF.sounds, "special_ready") == 0)
	HF.sc.update(mkView(function(v)
		v.sides[1].units[1].charge = 5
	end), nil)
	check("Charge pleine pour le même pet : flash lancé (voile visible), son « special_ready » joué UNE fois", veil.Visible == true and count(HF.sounds, "special_ready") == 1 and string.find(special.Text, "✨", 1, true) ~= nil)
	RT.step(0.3)
	local midScale = scale.Scale
	check("Pendant le flash : le bouton gonfle (échelle > 1, <= 1,12)", midScale > 1 and midScale <= 1.12 + 1e-9)
	RT.step(L.MAX_FLASH + 0.2)
	check("Le flash se termine en moins de 1,5 s : voile caché, échelle revenue à 1", veil.Visible == false and scale.Scale == 1)
	HF.sc.update(mkView(function(v)
		v.sides[1].units[1].charge = 5
	end), nil)
	check("Charge toujours pleine (nouvelle vue) : pas de nouveau flash ni de nouveau son", veil.Visible == false and count(HF.sounds, "special_ready") == 1)
	HF.sc.update(mkView(function(v)
		v.sides[1].active = 2
		v.sides[1].units[2].charge = 5
	end), nil)
	check("Changement de pet vers un pet à charge pleine : pas de flash (jamais au changement de pet)", veil.Visible == false and count(HF.sounds, "special_ready") == 1)
	HF.sc.update(mkView(function(v)
		v.sides[1].active = 2
		v.sides[1].units[2].charge = 0
	end), nil)
	HF.sc.update(mkView(function(v)
		v.sides[1].active = 2
		v.sides[1].units[2].charge = 5
	end), { delay = 0.5 })
	check("Flash différé avec les coups du tour (delay) : pas encore visible, puis visible après le délai", veil.Visible == false)
	RT.step(0.6)
	check("Après le délai : flash visible, son joué (2e fois)", veil.Visible == true and count(HF.sounds, "special_ready") == 2)
	RT.step(2)
	HF.sc.skip()
	check("Fin des flashs : voile caché", veil.Visible == false)
	-- « Passer » termine le flash tout de suite
	HF.sc.update(mkView(function(v)
		v.sides[1].active = 2
		v.sides[1].units[2].charge = 3
	end), nil)
	HF.sc.update(mkView(function(v)
		v.sides[1].active = 2
		v.sides[1].units[2].charge = 5
	end), nil)
	RT.step(0.1)
	HF.sc.skip()
	RT.step(0.1)
	check("« Passer l'animation » termine le flash aussitôt", veil.Visible == false and scale.Scale == 1)
	-- effets réduits : pas de gonflement
	local HR = mkScene(mkView(function(v)
		v.sides[1].units[1].charge = 4
	end), { reduced = true })
	HR.sc.update(mkView(function(v)
		v.sides[1].units[1].charge = 5
	end), nil)
	RT.step(0.15)
	check("Effets réduits : le flash a lieu (voile, son) mais le bouton ne gonfle pas ; durée plus courte", findAll(HR.gui, "SpecialScale")[1].Scale == 1 and count(HR.sounds, "special_ready") == 1)
	RT.step(1)
	check("Effets réduits : flash terminé en 0,35 s au plus", findAll(HR.gui, "SpecialFlash")[1].Visible == false)
	HR.sc.destroy()
	HF.sc.destroy()
	check("Vitesse 3x : flash plus court, jamais plus de 1,5 s", L.flashSeconds(false, 3) <= 0.7 / 3 + 1e-9)

	-- sons des actions du tour
	local HA = mkScene(mkView(), { attackSounds = true })
	HA.sc.cues({ { t = "hit", side = 1, dmg = 9, mul = 1, p = 6 }, { t = "hit", side = 2, dmg = 30, mul = 1.5, special = true, skill = "strike", p = 3 }, { t = "swap", side = 1, to = 2, p = 4 }, { t = "heal", side = 2, amount = 3, p = 4 } })
	RT.step(0.05)
	local first = HA.sounds[1]
	RT.step(2.5)
	check("Sons du tour joués dans l'ordre par la scène : son du type (" .. tostring(first) .. "), special_hit, click ; rien pour le soin", first == Config.ATK_SOUND[Battle.SPECIES_TYPE[6]] and count(HA.sounds, "special_hit") == 1 and count(HA.sounds, "click") == 1 and #HA.sounds == 3)
	HA.sc.destroy()
	local HN = mkScene(mkView(), { attackSounds = false })
	HN.sc.cues({ { t = "hit", side = 1, dmg = 9, mul = 1, p = 6 }, { t = "hit", side = 2, dmg = 30, mul = 1.5, special = true, skill = "strike", p = 3 } })
	RT.step(2)
	check("attackSounds = false : l'attaque simple est muette (les effets de type la jouent), le spécial joue special_hit une fois", #HN.sounds == 1 and HN.sounds[1] == "special_hit")
	HN.sc.destroy()
	local OffCfg = clone(Config)
	OffCfg.SOUNDS_ENABLED = false
	local HM = mkScene(mkView(), { Config = OffCfg })
	HM.sc.cues({ { t = "hit", side = 1, dmg = 9, mul = 1, p = 6 }, { t = "swap", side = 1, to = 2, p = 4 } })
	RT.step(2)
	check("SOUNDS_ENABLED = false : la scène ne demande aucun son d'action", #HM.sounds == 0)
	HM.sc.destroy()
	local HK = mkScene(mkView(), { attackSounds = true })
	HK.sc.cues({ { t = "hit", side = 1, dmg = 9, mul = 1, p = 6 }, { t = "hit", side = 2, dmg = 9, mul = 1, p = 3 }, { t = "hit", side = 1, dmg = 9, mul = 1, p = 6 } })
	RT.step(0.7)
	HK.sc.skip()
	RT.step(3)
	check("« Passer l'animation » annule les sons qui n'ont pas encore démarré", #HK.sounds < 3)
	HK.sc.destroy()

	-- plafond d'instances avec les nouveaux éléments, 6 pets de chaque côté, tout ouvert
	local function bigTeam(floor)
		local t = {}
		for k = 1, 6 do
			t[k] = Battle.towerTeam(Config, floor)[(k - 1) % 3 + 1]
		end
		return t
	end
	for _, red in ipairs({ false, true }) do
		local v = Battle.view(Battle.new(5, bigTeam(3), bigTeam(4)))
		for side = 1, 2 do
			for _, u in ipairs(v.sides[side].units) do
				u.stun, u.guard, u.focus = 1, true, 2
			end
		end
		local HB = mkScene(v, { reduced = red })
		HB.sc.update(v, { events = {} })
		RT.fire(findAll(HB.gui, "Swap")[1], "Activated")
		local peak = HB.sc.peak()
		check("6 pets par camp, 3 pastilles par camp, écran Changer ouvert (" .. (red and "mobile" or "complet") .. ") : pic de " .. peak .. " instances sous le plafond de " .. L.MAX_INSTANCES, HB.sc ~= nil and peak <= L.MAX_INSTANCES and #findAll(HB.gui, "SwapRow6") == 1)
		HB.sc.destroy()
	end

	-- BattleUi : XP de fin
	suite("BattleUi : XP de fin du message serveur, sons non doublés, aucun changement de protocole")
	local function installUi(reducedFlag, fxExtra)
		local gui = newGui()
		local RB = RT.instance("RemoteEvent", "Battle")
		local fired, sounds = {}, {}
		local state = { battle = { team = {}, best = 4, fightsLeft = 5, repeatsLeft = 5 }, slots = {} }
		local fx = { BattleScene = BattleScene, BattleLayout = L, reduced = reducedFlag, sound = function(k) sounds[#sounds + 1] = k end, iconUrl = function() return nil end }
		for k, v in pairs(fxExtra or {}) do
			fx[k] = v
		end
		local ui = BattleUi.start(Config, Battle, { DisplayName = "Moi", UserId = 1 }, gui, function() return state end, function(a, arg) fired[#fired + 1] = { a, arg } end, RB, fx)
		return { gui = gui, RB = RB, fired = fired, sounds = sounds, ui = ui }
	end
	local function resultText(h)
		for _, d in ipairs(h.gui:GetDescendants()) do
			if d.ClassName == "TextLabel" and type(d.Text) == "string" and (string.find(d.Text, "Victoire", 1, true) or string.find(d.Text, "Défaite", 1, true)) then
				return d.Text
			end
		end
		return ""
	end
	local function run(h, endMsg)
		local v = mkView()
		RT.fire(h.RB, "OnClientEvent", { k = "start", view = v, foe = "Rival", floor = 2, seconds = 15 })
		RT.step(0.2)
		endMsg.k, endMsg.view = "end", v
		RT.fire(h.RB, "OnClientEvent", endMsg)
		RT.step(0.2)
	end
	local U1 = installUi(false)
	run(U1, { win = true, rewards = { coins = 5, first = true }, floor = 2 })
	local t1 = resultText(U1)
	check("Fin de combat sans XP dans le message (cas actuel du serveur) : aucune ligne d'XP, le reste inchangé (« Victoire », pièces)", string.find(t1, "Victoire", 1, true) ~= nil and string.find(t1, "XP", 1, true) == nil and string.find(t1, "5", 1, true) ~= nil)
	local U2 = installUi(false)
	run(U2, { win = true, rewards = { coins = 5 }, floor = 2, xp = 18 })
	check("Fin de combat avec xp = 18 dans le message : « ⭐ +18 XP pour chaque pet de l'équipe » affiché sous le résultat", string.find(resultText(U2), "+18 XP", 1, true) ~= nil)
	local U3 = installUi(false)
	run(U3, { win = false, rewards = {}, floor = 2, xp = { { p = 3, gain = 6 } } })
	check("Défaite avec XP par pet : ligne « nom +6 XP » affichée (l'XP est versée aussi en cas de défaite)", string.find(resultText(U3), "+6 XP", 1, true) ~= nil and string.find(resultText(U3), "Défaite", 1, true) ~= nil)
	local U4 = installUi(false)
	run(U4, { win = true, rewards = {}, floor = 2, duel = true, xp = 50 })
	check("Duel : aucune ligne d'XP (le texte du duel vient du serveur)", string.find(resultText(U4), "XP", 1, true) == nil)
	check("Sons de début et de fin passent toujours par Config.SOUNDS (battle_start, battle_win)", count(U1.sounds, "battle_start") >= 1 and count(U1.sounds, "battle_win") == 1 and count(U3.sounds, "battle_lose") == 1)
	-- pas de double son d'attaque : BattleUi ne laisse la scène jouer l'attaque que si les effets de type (TypeFx) ne la jouent pas déjà
	check("BattleUi passe attackSounds = false à la scène quand les effets de type sont actifs (jamais deux sons d'attaque) et ne rejoue plus « special_ready » à 4/5 en scène face à face", string.find(fs.readFile("roblox/src/StarterPlayerScripts/BattleUi.lua"), "attackSounds = not (FX.on and Config.BATTLE_FX.typeFx and fx.TypeFx and fx.TypeFxData)", 1, true) ~= nil and string.find(fs.readFile("roblox/src/StarterPlayerScripts/BattleUi.lua"), "readySoon and not SC.scene", 1, true) ~= nil)
	check("Aucune erreur de script dans toute la suite (boucles arrêtées après destruction)", (function()
		RT.step(5)
		return #RT.errors == T.err0
	end)())

	---------------------------------------------------------------- 9. Intégration et style
	suite("Combat (suite) : style, pureté et protocole inchangé")
	local function code(src)
		local out = {}
		for line in string.gmatch(src, "[^\n]*") do
			local cut = string.find(line, "%-%-")
			out[#out + 1] = cut and string.sub(line, 1, cut - 1) or line
		end
		return table.concat(out, "\n")
	end
	local bl, bs, bu = code(codeSrc[1]), code(codeSrc[2]), code(codeSrc[3])
	T.bad = false
	for _, src in ipairs({ bl, bs }) do
		for _, pat in ipairs({ "%+=", "%-=", "math%.atan2", "\n%s*continue%s", "math%.random" }) do
			if string.find(src, pat) then
				T.bad = true
			end
		end
	end
	check("BattleLayout / BattleScene : ni += / -= ni continue ni math.atan2 ni math.random (lanceur lupa, tests déterministes)", not T.bad)
	check("BattleLayout reste pur : aucun require, aucune instance Roblox, aucun service", string.find(bl, "require", 1, true) == nil and string.find(bl, "Instance.new", 1, true) == nil and string.find(bl, "GetService", 1, true) == nil)
	local sent = {}
	for a in string.gmatch(bs .. bu, "fire%(\"([%w]+)\"") do
		sent[a] = true
	end
	for a in string.gmatch(bs, "o%.fire%(\"([%w]+)\"") do
		sent[a] = true
	end
	check("Protocole inchangé : la scène n'envoie que battleAct (attack, skill, swapN) et battleQuit ; aucune nouvelle action", (function()
		for a in pairs(sent) do
			if a ~= "battleAct" and a ~= "battleQuit" and a ~= "setTeam" and a ~= "pvpDefense" and a ~= "pvpStart" and a ~= "liveQueue" and a ~= "liveCancel" and a ~= "towerStart" and a ~= "battlePick" and a ~= "duelAnswer" then
				return false
			end
		end
		return true
	end)())
	check("« Fuir » reste à deux appuis (premier : « Sûr ? », expire en 3 s)", string.find(bs, "S.btn.flee.Text = \"Sûr ?\"", 1, true) ~= nil and string.find(bs, "task.delay(3,", 1, true) ~= nil)
end
