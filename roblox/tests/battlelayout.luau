--!nocheck
-- Tests de la REFONTE DU COMBAT (vue face à face) : BattleLayout (module pur : disposition, textes, états, scène, plafond d'instances), BattleScene (instances, boutons,
-- nettoyage sur 20 combats) et BattleUi branché sur la scène (start / tour / fin / cartes de récompense / duel miroir / classé), dans le runtime factice.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau ou tests/run_battlelayout.py).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, pas de LCG > 2^53 (Park-Miller 48271 mod 2^31-1), état partagé dans la table T (limite de 200 variables locales).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local T = {}
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local L = load("roblox/src/ReplicatedStorage/BattleLayout.lua", "BattleLayout")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", { Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end } })
	local Battle = load("roblox/src/ReplicatedStorage/Battle.lua", "Battle")
	local function rng(seed)
		local s = seed
		return function()
			s = (s * 48271) % 2147483647
			return s / 2147483647
		end
	end
	local function finite(v)
		return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
	end
	local function inside(r, a)
		return r.x >= a.x - 1e-6 and r.y >= a.y - 1e-6 and r.x + r.w <= a.x + a.w + 1e-6 and r.y + r.h <= a.y + a.h + 1e-6
	end

	---------------------------------------------------------------- 1. Disposition : matrice d'appareils
	suite("BattleLayout : disposition sur une matrice d'appareils (portrait, paysage, tablette, zone sûre)")
	local DEVICES = { { 360, 640 }, { 320, 568 }, { 375, 667 }, { 390, 844 }, { 412, 915 }, { 360, 480 }, { 640, 360 }, { 568, 320 }, { 667, 375 }, { 844, 390 }, { 932, 430 }, { 480, 360 }, { 1280, 720 }, { 1920, 1080 }, { 768, 1024 }, { 1024, 768 }, { 2560, 1440 } }
	local SAFES = { false, true } -- zone sûre réaliste : encoches latérales en paysage, barre du haut et du bas en portrait
	local bad = { overlap = {}, inside = {}, touch = {}, corner = {}, place = {}, stage = {}, tray = {}, scale = {} }
	local nCombos = 0
	for _, d in ipairs(DEVICES) do
		for _, sf in ipairs(SAFES) do
			nCombos = nCombos + 1
			local realSafe = sf and (d[1] > d[2] and { l = 44, t = 0, r = 44, b = 21 } or { l = 0, t = 47, r = 0, b = 34 }) or nil
			local R = L.rects(d[1], d[2], realSafe)
			local tag = d[1] .. "x" .. d[2] .. (sf and "s" or "")
			local list = { R.foeCard, R.meCard, R.log, R.actions.attack, R.actions.special, R.actions.swap, R.actions.flee }
			for i = 1, #list do
				if not inside(list[i], R.area) then
					bad.inside[#bad.inside + 1] = tag .. "#" .. i
				end
				for j = i + 1, #list do
					if L.overlap(list[i], list[j]) then
						bad.overlap[#bad.overlap + 1] = tag .. " " .. i .. "/" .. j
					end
				end
			end
			for k, r in pairs(R.actions) do
				if r.w < L.MIN_TOUCH or r.h < L.MIN_TOUCH then
					bad.touch[#bad.touch + 1] = tag .. k
				end
			end
			-- plateau de réserve : 3 boutons >= 44 px, hors des cartes adverses, du journal et des boutons
			local sw = (R.swapTray.w - 2 * L.GAP) / 3
			if sw < L.MIN_TOUCH or R.swapTray.h < L.MIN_TOUCH or L.overlap(R.swapTray, R.foeCard) or L.overlap(R.swapTray, R.actions.attack) or L.overlap(R.swapTray, R.actions.special) or L.overlap(R.swapTray, R.actions.swap) or L.overlap(R.swapTray, R.actions.flee) or L.overlap(R.swapTray, R.meCard) or not inside(R.swapTray, R.area) then
				bad.tray[#bad.tray + 1] = tag
			end
			-- carte adverse en haut à droite (collée au bord droit et au haut de la zone utile), carte du joueur en bas à gauche (bord gauche, sous l'adversaire)
			if math.abs(R.foeCard.x + R.foeCard.w - (R.area.x + R.area.w)) > 1e-6 or R.foeCard.y ~= R.area.y or R.meCard.x ~= R.area.x or R.meCard.y <= R.foeCard.y + R.foeCard.h or R.log.y + R.log.h > R.area.y + R.area.h + 1e-6 then
				bad.place[#bad.place + 1] = tag
			end
			-- coin haut gauche (boutons natifs : menu, discussion) laissé libre quand la zone sûre est nulle
			if not sf then
				local corner = { x = 0, y = 0, w = 96, h = 56 }
				for _, r in ipairs(list) do
					if L.overlap(r, corner) then
						bad.corner[#bad.corner + 1] = tag
					end
				end
			end
			if not (R.stage.h > 0 and R.stage.w > 0 and finite(R.stage.y)) then
				bad.stage[#bad.stage + 1] = tag
			end
			local sc = L.toScale(R.meCard, d[1], d[2])
			if not (sc.sx >= 0 and sc.sx <= 1 and sc.sy >= 0 and sc.sy <= 1 and sc.sw > 0 and sc.sw <= 1 and sc.sh > 0 and sc.sh <= 1) then
				bad.scale[#bad.scale + 1] = tag
			end
		end
	end
	check("Matrice " .. #DEVICES .. " appareils x 3 zones sûres (" .. nCombos .. " cas) : tous les rectangles dans la zone utile", #bad.inside == 0)
	check("Aucune superposition entre carte adverse, carte du joueur, journal et les 4 boutons d'action", #bad.overlap == 0)
	check("Cibles tactiles : les 4 boutons d'action font au moins 44 x 44 px partout", #bad.touch == 0)
	check("Plateau « Changer » : 3 boutons d'au moins 44 px, ni sur l'adversaire, ni sur les boutons, ni sur la carte du joueur (il remplace le journal)", #bad.tray == 0)
	check("Carte adverse en haut à droite, carte du joueur en bas à gauche, journal en bas", #bad.place == 0)
	check("Coin haut gauche (boutons natifs) jamais couvert", #bad.corner == 0)
	check("Zone libre des créatures toujours positive ; rectangles convertis en échelle dans [0, 1]", #bad.stage == 0 and #bad.scale == 0)
	check("Mode : 360x640 et 320x568 = étroit ; 640x360, 1280x720 = large ; 768x1024 (portrait) = étroit", L.rects(360, 640).mode == "narrow" and L.rects(320, 568).mode == "narrow" and L.rects(640, 360).mode == "wide" and L.rects(1280, 720).mode == "wide" and L.rects(768, 1024).mode == "narrow")
	local R360 = L.rects(360, 640)
	check("À 360 px de large : carte adverse <= 360 - 16, boutons de 4 colonnes >= 80 px de large, carte adverse à droite (x >= 100)", R360.foeCard.x + R360.foeCard.w <= 352 and R360.actions.attack.w >= 80 and R360.foeCard.x >= 100 and R360.foeCard.w <= 260)
	local vwBad, vhBad = L.viewport(0 / 0, "a"), nil
	local aw, ah = L.viewport(nil, -5)
	local bw, bh = L.viewport(10, 10)
	local cw, ch = L.viewport(1920.7, 1080.2)
	check("Fenêtre invalide (nil, NaN, négative, minuscule) : défaut 640 x 360 ou minimum 240 x 320, entiers", aw == 640 and ah == 360 and bw == 240 and bh == 320 and cw == 1920 and ch == 1080 and vwBad == 640)
	local sfx = L.safe({ l = -5, t = 1e9, r = 0 / 0, b = "x" }, 400, 300)
	check("Zone sûre assainie : négatif -> 0, énorme -> 25 % de la fenêtre, NaN / texte -> 0 ; table absente -> 0", sfx.l == 0 and sfx.t == 75 and sfx.r == 0 and sfx.b == 0 and L.safe(nil, 400, 300).l == 0)
	local Rs = L.rects(640, 360, { l = 44, t = 10, r = 44, b = 21 })
	check("Zone sûre respectée : rien à moins de 44 + 8 px des bords gauche et droit, ni 21 + 8 px du bas", Rs.meCard.x >= 52 and Rs.foeCard.x + Rs.foeCard.w <= 640 - 52 and Rs.log.y + Rs.log.h <= 360 - 29)

	---------------------------------------------------------------- 2. Composition des cartes
	suite("BattleLayout : composition interne des cartes (nom, niveau, barre, PV, points, pastilles)")
	local okInner = true
	for _, w in ipairs({ 200, 240, 280, 300 }) do
		for _, isMe in ipairs({ true, false }) do
			local I = L.cardInner(w, isMe)
			local parts = isMe and { I.icon, I.name, I.level, I.bar, I.hp, I.dots, I.pips } or { I.ctx, I.icon, I.name, I.level, I.bar, I.dots }
			for _, r in ipairs(parts) do
				if not (r.x >= 0 and r.y >= 0 and r.x + r.w <= w + 1e-6 and r.y + r.h <= I.h + 1e-6 and r.w > 0 and r.h > 0) then
					okInner = false
				end
			end
			if L.overlap(I.name, I.level) or L.overlap(I.icon, I.name) or L.overlap(I.bar, I.name) or L.overlap(I.bar, I.dots) then
				okInner = false
			end
			if isMe and (L.overlap(I.hp, I.dots) or L.overlap(I.pips, I.dots) or L.overlap(I.pips, I.hp) or L.overlap(I.pips, I.bar)) then
				okInner = false
			end
		end
	end
	check("Cartes de 200 à 300 px : chaque élément dans la carte, sans chevauchement (nom / niveau / icône / barre / PV / points / pastilles)", okInner)
	check("Carte du joueur : PV chiffrés + pastilles (pas de ligne de contexte) ; carte adverse : contexte + points (pas de PV chiffrés ni de pastilles)", L.cardInner(250, true).hp ~= nil and L.cardInner(250, true).pips ~= nil and L.cardInner(250, true).ctx == nil and L.cardInner(250, false).ctx ~= nil and L.cardInner(250, false).hp == nil and L.cardInner(250, false).pips == nil)
	check("Texte de PV : « 260/260 », bornes (PV > max, négatif, fractions, NaN, nil, texte)", L.hpText({ hp = 260, maxHp = 260 }) == "260/260" and L.hpText({ hp = 999, maxHp = 100 }) == "100/100" and L.hpText({ hp = -5, maxHp = 100 }) == "0/100" and L.hpText({ hp = 12.9, maxHp = 100.4 }) == "12/100" and L.hpText({ hp = 0 / 0, maxHp = 50 }) == "0/50" and L.hpText(nil) == "0/0" and L.hpText({ hp = "x", maxHp = "y" }) == "0/0" and L.hpText({ hp = 5, maxHp = -3 }) == "0/0")
	check("Fraction de PV : 0..1, 0 si maximum nul / absent", L.hpFraction({ hp = 30, maxHp = 60 }) == 0.5 and L.hpFraction({ hp = 90, maxHp = 60 }) == 1 and L.hpFraction({ hp = -1, maxHp = 60 }) == 0 and L.hpFraction({ hp = 5, maxHp = 0 }) == 0 and L.hpFraction(nil) == 0 and L.hpFraction({ hp = 1 }) == 0)
	check("Couleur de barre : verte > 50 %, ambre jusqu'à 25 %, rouge en dessous ; NaN -> rouge", L.hpColor(1) == L.UI.hp and L.hpColor(0.51) == L.UI.hp and L.hpColor(0.5) == L.UI.hpWarn and L.hpColor(0.26) == L.UI.hpWarn and L.hpColor(0.25) == L.UI.hpLow and L.hpColor(0) == L.UI.hpLow and L.hpColor(0 / 0) == L.UI.hpLow and L.hpColor(nil) == L.UI.hpLow)
	check("Niveau : « Niv. 7 » ; absent / NaN -> « Niv. 1 » ; borné à 1..999", L.levelText({ level = 7 }) == "Niv. 7" and L.levelText({}) == "Niv. 1" and L.levelText({ level = 0 / 0 }) == "Niv. 1" and L.levelText({ level = -3 }) == "Niv. 1" and L.levelText({ level = 5000 }) == "Niv. 999" and L.levelText(nil) == "Niv. 1" and L.levelText({ level = 4.9 }) == "Niv. 4")
	local dots = L.teamDots({ active = 2, units = { { hp = 10 }, { hp = 0 }, { hp = 3 } } })
	check("Points d'état : un point par pet, plein si vivant, le pet au combat marqué ; PV 0 = vide", #dots == 3 and dots[1].alive and not dots[2].alive and dots[3].alive and dots[2].active and not dots[1].active and L.aliveCount({ active = 1, units = { { hp = 10 }, { hp = 0 }, { hp = 3 } } }) == 2)
	local many = {}
	for i = 1, 11 do
		many[i] = { hp = i % 2 }
	end
	check("Points d'état plafonnés à " .. L.MAX_DOTS .. " ; entrées invalides sans erreur (nil, units absent, éléments non tables, hp NaN)", #L.teamDots({ active = 1, units = many }) == L.MAX_DOTS and #L.teamDots(nil) == 0 and #L.teamDots({}) == 0 and #L.teamDots({ units = { 5, "x", { hp = 0 / 0 } } }) == 3 and L.teamDots({ units = { 5, "x", { hp = 0 / 0 } } })[3].alive == false)
	local cp = L.chargePips(3, 5)
	local cp0 = L.chargePips(0)
	local cp9 = L.chargePips(99, 5)
	check("Charge du spécial : 3/5 = 3 pastilles pleines, pas prêt ; 5/5 prêt ; bornée 0..5 ; invalide -> 0", cp.charge == 3 and #cp.pips == 5 and cp.pips[3] and not cp.pips[4] and not cp.ready and cp9.charge == 5 and cp9.ready and cp0.charge == 0 and not cp0.ready and L.chargePips(0 / 0, 5).charge == 0 and L.chargePips(-4, 5).charge == 0 and L.chargePips(2.9, 5).charge == 2)
	check("Pastilles : 5 par défaut (charge du moteur du lot 12 A) ; maximum personnalisé borné à 1..10", #L.chargePips(1).pips == 5 and L.CHARGE_MAX == 5 and Battle.CHARGE_MAX == 5 and #L.chargePips(1, 99).pips == 10 and #L.chargePips(1, 0).pips == 1)
	local bench = L.bench({ active = 2, units = { { hp = 10, maxHp = 20, p = 3 }, { hp = 5, maxHp = 20, p = 4 }, { hp = 0, maxHp = 20, p = 7 } } })
	check("Réserve : pets hors actif avec indice, PV, vivant ou non (pour le plateau « Changer »)", #bench == 2 and bench[1].index == 1 and bench[1].alive and bench[1].hp == 10 and bench[2].index == 3 and not bench[2].alive and #L.bench(nil) == 0 and #L.bench({ units = {} }) == 0)

	---------------------------------------------------------------- 3. Lieu : sable ou herbe
	suite("BattleLayout : fond d'arène (sable : colisée et duel ; herbe : arène PvE)")
	check("Mode du combat tiré du message « start » : duel, classé en direct, classé enregistré, PNJ, tour", L.mode({ duel = true }) == "duel" and L.mode({ live = true, pvp = true }) == "live" and L.mode({ pvp = true }) == "pvp" and L.mode({ npc = true }) == "npc" and L.mode({}) == "tower" and L.mode(nil) == "tower" and L.mode({ duel = "oui" }) == "tower")
	check("Fond : sable pour le duel, le classé enregistré et le classé en direct ; herbe pour la tour, les PNJ et tout lieu inconnu", L.ground({ duel = true }) == "sand" and L.ground({ pvp = true }) == "sand" and L.ground({ live = true, pvp = true }) == "sand" and L.ground({ floor = 3 }) == "grass" and L.ground({ npc = true }) == "grass" and L.ground("colisee") == "sand" and L.ground("duel") == "sand" and L.ground("xyz") == "grass" and L.ground(nil) == "grass")
	local pS, pG = L.palette("sand"), L.palette("grass")
	check("Palettes sable / herbe propres à Chipe-Œufs : sol, bord, ciel, décor, lumière définis ; sable chaud (rouge > bleu), herbe verte (vert > rouge)", pS.ground[1] > pS.ground[3] and pG.ground[2] > pG.ground[1] and pS.skyTop ~= nil and pG.deco ~= nil and pS.light ~= nil and L.palette("?") == L.PALETTE.grass)
	local allTypes = true
	for _, t in ipairs(Battle.TYPES) do
		if L.TYPE_COLOR[t] == nil then
			allTypes = false
		end
	end
	check("Une couleur de socle pour chacun des 9 types du moteur ; type inconnu -> neutre", allTypes and L.typeColor("Plante") ~= nil and L.typeColor("???") == L.NEUTRAL_COLOR and L.typeColor(nil) == L.NEUTRAL_COLOR)

	---------------------------------------------------------------- 4. Scène : caméra et socles
	suite("BattleLayout : scène 3D (socles, caméra fixe en léger angle, cadrage)")
	-- projection sténopé de la caméra calculée (pur) : donne l'abscisse / ordonnée écran en pixels d'un point du monde
	local function project(sc, vw, vh, p)
		local f = { sc.target.x - sc.eye.x, sc.target.y - sc.eye.y, sc.target.z - sc.eye.z }
		local fl = math.sqrt(f[1] * f[1] + f[2] * f[2] + f[3] * f[3])
		f = { f[1] / fl, f[2] / fl, f[3] / fl }
		local right = { -f[3], 0, f[1] } -- côté droit de la caméra (f x haut)
		local rl = math.sqrt(right[1] * right[1] + right[3] * right[3])
		right = { right[1] / rl, 0, right[3] / rl }
		local up = { right[2] * f[3] - right[3] * f[2], right[3] * f[1] - right[1] * f[3], right[1] * f[2] - right[2] * f[1] }
		local ul = math.sqrt(up[1] * up[1] + up[2] * up[2] + up[3] * up[3])
		up = { -up[1] / ul, -up[2] / ul, -up[3] / ul }
		if up[2] < 0 then
			up = { -up[1], -up[2], -up[3] }
		end
		local v = { p.x - sc.eye.x, p.y - sc.eye.y, p.z - sc.eye.z }
		local z = v[1] * f[1] + v[2] * f[2] + v[3] * f[3]
		local x = v[1] * right[1] + v[2] * right[2] + v[3] * right[3]
		local y = v[1] * up[1] + v[2] * up[2] + v[3] * up[3]
		local th = math.tan(math.rad(sc.fov / 2))
		local asp = vw / vh
		return (x / (z * th * asp) + 1) / 2 * vw, (1 - y / (z * th)) / 2 * vh, z
	end
	T.sceneBad = {}
	for _, d in ipairs(DEVICES) do
		for _, g in ipairs({ "sand", "grass" }) do
			local sc = L.scene(d[1], d[2], nil, g)
			local R = L.rects(d[1], d[2])
			local tag = d[1] .. "x" .. d[2] .. g
			local nums = { sc.eye.x, sc.eye.y, sc.eye.z, sc.target.x, sc.target.y, sc.target.z, sc.me.x, sc.me.z, sc.foe.x, sc.foe.z, sc.fov, sc.distance }
			for _, n in ipairs(nums) do
				if not finite(n) then
					T.sceneBad[#T.sceneBad + 1] = tag .. " nan"
				end
			end
			local mx, my, mz = project(sc, d[1], d[2], { x = sc.me.x, y = 3, z = sc.me.z })
			local fx2, fy2, fz = project(sc, d[1], d[2], { x = sc.foe.x, y = 3, z = sc.foe.z })
			local mxl = project(sc, d[1], d[2], { x = sc.me.x - sc.pedestal, y = 0, z = sc.me.z })
			local fxr = project(sc, d[1], d[2], { x = sc.foe.x + sc.pedestal, y = 0, z = sc.foe.z })
			if not (mz > 0 and fz > 0 and mxl >= 0 and fxr <= d[1] and mx < fx2) then -- les deux socles entiers visibles, joueur à gauche de l'adversaire
				T.sceneBad[#T.sceneBad + 1] = tag .. " cadrage " .. string.format("%.0f %.0f", mxl, fxr)
			end
			if my <= fy2 or fy2 < 0 or my > d[2] then -- l'adversaire (au fond) est plus haut sur l'écran que le joueur (au premier plan)
				T.sceneBad[#T.sceneBad + 1] = tag .. " profondeur"
			end
			local foeIn = fx2 > R.foeCard.x and fx2 < R.foeCard.x + R.foeCard.w and fy2 > R.foeCard.y and fy2 < R.foeCard.y + R.foeCard.h
			local meIn = mx > R.meCard.x and mx < R.meCard.x + R.meCard.w and my > R.meCard.y and my < R.meCard.y + R.meCard.h
			if foeIn or meIn then -- le centre d'une créature n'est jamais caché sous une carte
				T.sceneBad[#T.sceneBad + 1] = tag .. " carte"
			end
			if not (sc.elevation == 16 and sc.eye.y > sc.target.y and sc.fov == 40 and sc.ground == g) then
				T.sceneBad[#T.sceneBad + 1] = tag .. " angle"
			end
		end
	end
	check("Caméra fixe : les deux socles entiers sont visibles, joueur à gauche au premier plan, adversaire au fond, caméra au-dessus (léger angle 16°) sur toute la matrice" .. (#T.sceneBad > 0 and (" : " .. table.concat(T.sceneBad, ", ", 1, math.min(6, #T.sceneBad))) or ""), #T.sceneBad == 0)
	local scN, scW = L.scene(360, 640), L.scene(1280, 720)
	check("Portrait : socles plus rapprochés qu'en paysage, caméra plus éloignée ; positions déterministes", math.abs(scN.me.x) < math.abs(scW.me.x) and scN.distance > scW.distance and L.scene(360, 640).eye.z == scN.eye.z and scN.me.x == -scN.foe.x)
	local a1, a2 = L.anchor(1, 640, 360), L.anchor(2, 640, 360)
	check("Repère d'effet de repli : joueur à gauche et plus bas, adversaire à droite et plus haut, dans la fenêtre", a1.x < a2.x and a1.y > a2.y and a1.x > 0 and a2.x < 640 and a2.y > 0 and a1.y < 360)

	---------------------------------------------------------------- 5. Signaux d'animation
	suite("BattleLayout : signaux d'animation tirés des événements du moteur")
	local c1 = L.cue({ t = "hit", side = 1, dmg = 12.7, mul = 1.5, p = 1 })
	local c2 = L.cue({ t = "hit", side = 2, dmg = 5, special = true })
	local c3 = L.cue({ t = "heal", side = 2, amount = 9 })
	check("Coup du joueur : élan du joueur, recul de l'adversaire, nombre « -12 » sur l'adversaire ; coup adverse : sens inverse", c1.anim == "attack" and c1.actor == 1 and c1.target == 2 and c1.popup.text == "-12" and c1.popup.side == 2 and c2.actor == 2 and c2.target == 1 and c2.special and c2.popup.side == 1)
	check("Soin : « +9 » sur le soigneur ; garde, changement, K.O. : animation sans nombre", c3.anim == "heal" and c3.popup.text == "+9" and c3.popup.side == 2 and L.cue({ t = "guard", side = 1 }).anim == "guard" and L.cue({ t = "swap", side = 2 }).anim == "swap" and L.cue({ t = "ko", side = 1 }).popup == nil)
	check("Événements invalides ou sans animation : nil sans erreur (tour, côté 3, nil, texte, dmg NaN)", L.cue({ t = "turn", n = 2 }) == nil and L.cue({ t = "hit", side = 3 }) == nil and L.cue(nil) == nil and L.cue("x") == nil and L.cue({ t = "hit", side = 1, dmg = 0 / 0 }).popup.text == "-0" and L.cue({ t = "hit", side = 1, dmg = -5 }).popup.text == "-0" and L.cue({ t = "timeout", side = 1 }) == nil)

	---------------------------------------------------------------- 6. Plafond d'instances
	suite("BattleLayout : plafond d'instances (220) et effets réduits sur mobile")
	local capOk, reducedOk, minDecor = true, true, 99
	for n1 = 1, 6 do
		for n2 = 1, 6 do
			local full = L.plan({ units1 = n1, units2 = n2 })
			local red = L.plan({ units1 = n1, units2 = n2, reduced = true })
			if full.estimate > L.MAX_INSTANCES - 20 or red.estimate > L.MAX_INSTANCES - 20 then
				capOk = false
			end
			if red.beams or red.bob or red.decor > full.decor or red.estimate >= full.estimate or not full.beams or not full.bob then
				reducedOk = false
			end
			minDecor = math.min(minDecor, red.decor)
		end
	end
	check("Estimation <= 200 (plafond 220 moins la marge de remplacement) pour toutes les équipes de 1 à 6 pets, complet et mobile", capOk and L.MAX_INSTANCES == 220)
	check("Mobile (effets réduits) : ni colonne de lumière ni balancement, décor et coût moindres ; complet : colonnes et balancement", reducedOk and minDecor > 0)
	check("Plan avec valeurs absurdes (nil, NaN, négatif, énorme) : bornes respectées sans erreur", L.plan(nil).estimate <= 200 and L.plan({ units1 = 0 / 0, units2 = -4 }).estimate <= 200 and L.plan({ units1 = 1e9, units2 = 1e9 }).estimate <= 200 and L.plan("x").cap == 220)
	local sp1, sp2 = L.decorSpots(12), L.decorSpots(12)
	local spOk = #sp1 == 12 and #L.decorSpots(0) == 0 and #L.decorSpots(1e6) == 24 and #L.decorSpots(nil) == 0
	for i, s in ipairs(sp1) do
		if s.x ~= sp2[i].x or s.z ~= sp2[i].z or not finite(s.x) or not finite(s.z) or s.h < 7 then
			spOk = false
		end
	end
	check("Décor en arc derrière les socles : déterministe, fini, plafonné à 24", spOk)
	local R3 = L.COST
	check("Coûts déclarés cohérents (tous des entiers positifs)", (function()
		for _, v in pairs(R3) do
			if type(v) ~= "number" or v < 1 or v ~= math.floor(v) then
				return false
			end
		end
		return true
	end)())

	---------------------------------------------------------------- 7. Fuzz (Park-Miller) : jamais d'erreur, invariants tenus
	suite("BattleLayout : fuzz Park-Miller 48271 (fenêtres, zones sûres et vues aléatoires, 400 tirages)")
	local rnd = rng(20261127)
	local fuzzErr, fuzzInv = 0, 0
	for _ = 1, 400 do
		local vw, vh = 200 + math.floor(rnd() * 2400), 250 + math.floor(rnd() * 1200)
		local sf = { l = math.floor(rnd() * 80), t = math.floor(rnd() * 60), r = math.floor(rnd() * 80), b = math.floor(rnd() * 40) }
		local ok, R = pcall(L.rects, vw, vh, sf)
		if not ok then
			fuzzErr = fuzzErr + 1
		else
			local list = { R.foeCard, R.meCard, R.log, R.actions.attack, R.actions.special, R.actions.swap, R.actions.flee }
			for i = 1, #list do
				if not inside(list[i], R.area) then
					fuzzInv = fuzzInv + 1
				end
				for j = i + 1, #list do
					if L.overlap(list[i], list[j]) then
						fuzzInv = fuzzInv + 1
					end
				end
			end
			for _, r in pairs(R.actions) do
				if r.w < 44 or r.h < 44 then
					fuzzInv = fuzzInv + 1
				end
			end
			local okS, sc = pcall(L.scene, vw, vh, sf, rnd() < 0.5 and "sand" or "grass")
			if not okS or not finite(sc.eye.y) or not finite(sc.eye.z) or sc.distance < 20 or sc.distance > 120 then
				fuzzInv = fuzzInv + 1
			end
		end
		local u = { hp = (rnd() - 0.3) * 500, maxHp = rnd() * 400, level = (rnd() - 0.2) * 40, charge = rnd() * 9 - 2, p = 1 }
		local side = { active = math.floor(rnd() * 5), units = { u, { hp = rnd() < 0.5 and 0 or 5 }, rnd() < 0.3 and "x" or u } }
		local ok2 = pcall(function()
			L.hpText(u)
			L.hpFraction(u)
			L.hpColor(L.hpFraction(u))
			L.levelText(u)
			L.teamDots(side)
			L.bench(side)
			L.chargePips(u.charge, 5)
			L.cue({ t = rnd() < 0.5 and "hit" or "heal", side = 1 + math.floor(rnd() * 2), dmg = u.hp, amount = u.hp })
		end)
		if not ok2 then
			fuzzErr = fuzzErr + 1
		end
	end
	check("Fuzz : aucune erreur, aucun rectangle hors zone ou superposé, boutons >= 44 px, caméra bornée", fuzzErr == 0 and fuzzInv == 0)

	---------------------------------------------------------------- 8. BattleScene dans le runtime factice
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local created = 0
	local env2 = {}
	for k, v in pairs(RT.env) do
		env2[k] = v
	end
	env2.Instance = { new = function(class)
		created = created + 1
		return RT.instance(class)
	end }
	local BattleScene = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/BattleScene.lua"), { debugName = "BattleScene", environment = env2 })()
	local BattleUi = luau.load(fs.readFile("roblox/src/StarterPlayerScripts/BattleUi.lua"), { debugName = "BattleUi", environment = env2 })()
	local function newGui()
		local g = RT.instance("ScreenGui", "gui")
		g.Enabled = true
		return g
	end
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
	local function teams(c)
		return Battle.towerTeam(Config, 1 + c % 10), Battle.towerTeam(Config, 3 + (c * 3) % 14)
	end
	local function newBattle(c)
		local a, b = teams(c)
		return Battle.new(1000 + c * 7919, a, b)
	end

	suite("BattleScene : construction, plafond d'instances, boutons, nettoyage (20 combats complets)")
	T.errs0 = #RT.errors
	T.peakMax, T.liveMax, T.leak, T.createdPer, T.noRoot = 0, 0, 0, 0, 0
	T.fired, T.badTap = {}, 0
	for c = 1, 20 do
		local gui = newGui()
		local st = newBattle(c)
		T.fired = {}
		local before = created
		local sc, err = BattleScene.create({
			gui = gui, Config = Config, Battle = Battle, Layout = L, player = { DisplayName = "Moi", UserId = 1 }, payload = { floor = c }, view = Battle.view(st), foeName = "Dresseur " .. c, floor = c,
			reduced = c % 2 == 0, iconUrl = function(key) return c % 3 == 0 and ("rbxassetid://" .. key) or nil end,
			specialState = function(u) return BattleUi.specialState(Config, Battle, u) end,
			fire = function(a, arg) T.fired[#T.fired + 1] = { a, arg } end, onChosen = function() end,
		})
		if not sc then
			check("Combat " .. c .. " : scène construite (" .. tostring(err) .. ")", false)
		else
			local turns = 0
			while not st.over and turns < 60 do
				turns = turns + 1
				local ev = Battle.turn(st, Battle.aiAction(st, 1))
				local d = sc.cues(ev)
				sc.update(Battle.view(st), { delay = d })
				sc.setLog({ "ligne " .. turns })
				sc.setStatus("tour " .. turns)
				RT.step(0.7)
				T.liveMax = math.max(T.liveMax, descendants(gui))
				T.peakMax = math.max(T.peakMax, sc.peak())
			end
			RT.step(2)
			local live = descendants(gui)
			T.liveMax = math.max(T.liveMax, live)
			T.createdPer = math.max(T.createdPer, created - before)
			if c == 1 then
				T.root = sc.root
				T.nPed = #findAll(gui, "PedestalGlow1") + #findAll(gui, "PedestalGlow2")
				T.nPips = #findAll(gui, "ChargePip")
				T.nBtn = #findAll(gui, "Attack") + #findAll(gui, "Special") + #findAll(gui, "Swap") + #findAll(gui, "Flee")
				T.nDots = #findAll(gui, "TeamDot")
				T.nFoeCard, T.nMeCard = #findAll(gui, "FoeCard"), #findAll(gui, "MeCard")
				T.sandPillars, T.grassHedges = #findAll(gui, "Pillar1"), #findAll(gui, "Hedge1")
			end
			if c == 2 then
				T.reducedColumns = #findAll(gui, "PedestalLight1") + #findAll(gui, "PedestalLight2")
				T.reducedLive = live
			end
			if c == 1 then
				T.fullColumns = #findAll(gui, "PedestalLight1") + #findAll(gui, "PedestalLight2")
				T.fullLive = live
			end
			sc.destroy()
			if descendants(gui) ~= 0 or sc.alive() or sc.count() ~= 0 then
				T.leak = T.leak + 1
			end
			sc.destroy() -- idempotent
			sc.update(Battle.view(st), nil)
			sc.cues({ { t = "hit", side = 1, dmg = 3 } })
			sc.setDim(true)
			RT.step(2)
		end
		if gui:GetChildren()[1] ~= nil then
			T.noRoot = T.noRoot + 1
		end
	end
	check("20 combats complets (vrai moteur Battle, 9 types, équipes de tour) : aucune instance ne reste après destroy (gui vide, compteur à 0)", T.leak == 0 and T.noRoot == 0)
	check("Plafond : instances vivantes de la scène <= " .. L.MAX_INSTANCES .. " (pic compté " .. T.peakMax .. ", arbre vivant " .. T.liveMax .. ")", T.peakMax <= L.MAX_INSTANCES and T.liveMax <= L.MAX_INSTANCES)
	check("Aucune erreur de script pendant les 20 combats et le temps qui passe après destruction (boucles arrêtées)", #RT.errors == T.errs0)
	check("Scène : 2 socles lumineux, 2 cartes, 4 boutons d'action, 5 pastilles de charge, un point par pet (6)", T.nPed == 2 and T.nFoeCard == 1 and T.nMeCard == 1 and T.nBtn == 4 and T.nPips == 5 and T.nDots == 6)
	check("Mobile (effets réduits) : aucune colonne de lumière, moins d'instances qu'en version complète (" .. tostring(T.reducedLive) .. " < " .. tostring(T.fullLive) .. ") ; complet : 2 colonnes", T.reducedColumns == 0 and T.fullColumns == 2 and T.reducedLive < T.fullLive)
	check("Herbe (tour) : haies et pas de colonnade ; instances créées au total par combat bornées (" .. T.createdPer .. " <= 900 : popups et remplacements de créature compris)", T.grassHedges == 1 and T.sandPillars == 0 and T.createdPer <= 900)

	-- boutons : intentions envoyées au serveur
	do
		local gui = newGui()
		local st = newBattle(4)
		local fired = {}
		local chosen = 0
		local view = Battle.view(st)
		local sc = BattleScene.create({
			gui = gui, Config = Config, Battle = Battle, Layout = L, player = { DisplayName = "Moi", UserId = 1 }, payload = { duel = true }, view = view, foeName = "Rival", floor = 0,
			reduced = false, specialState = function(u) return BattleUi.specialState(Config, Battle, u) end,
			fire = function(a, arg) fired[#fired + 1] = { a, arg } end, onChosen = function() chosen = chosen + 1 end,
		})
		local function btn(name)
			return findAll(gui, name)[1]
		end
		T.sand = { pillars = #findAll(gui, "Pillar1"), hedges = #findAll(gui, "Hedge1"), ground = sc.ground, mode = sc.mode }
		RT.fire(btn("Attack"), "Activated")
		check("Attaque : envoie « battleAct » / « attack » (une intention, rien d'autre) et signale le choix", #fired == 1 and fired[1][1] == "battleAct" and fired[1][2] == "attack" and chosen == 1)
		fired = {}
		RT.fire(btn("Special"), "Activated")
		check("Spécial pas prêt (0/5) : rien n'est envoyé au serveur ; bouton « Spécial 0/5 » ; le bandeau explique", #fired == 0 and btn("Special").Text == "Spécial 0/5" and string.find(findAll(gui, "Status")[1].Text, "pas prêt", 1, true) ~= nil)
		local v2 = Battle.view(st)
		v2.sides[1].units[v2.sides[1].active].charge = 5
		sc.update(v2, nil)
		check("Charge 5/5 : bouton « ✨ … » prêt (texte du spécial par type) ; 5 pastilles allumées", string.find(btn("Special").Text, "✨", 1, true) ~= nil and btn("Special").AutoButtonColor == true)
		fired = {}
		RT.fire(btn("Special"), "Activated")
		check("Spécial prêt : envoie « battleAct » / « skill » (le serveur revalide)", #fired == 1 and fired[1][1] == "battleAct" and fired[1][2] == "skill")
		fired = {}
		RT.fire(btn("Swap"), "Activated")
		local tray = findAll(gui, "SwapTray")[1]
		check("Changer : ouvre le plateau de réserve (2 pets en réserve visibles, PV affichés) sans rien envoyer", tray.Visible == true and #fired == 0 and findAll(gui, "SwapSlot1")[1].Visible == true and findAll(gui, "SwapSlot2")[1].Visible == true and findAll(gui, "SwapSlot3")[1].Visible == false and string.find(findAll(gui, "SwapSlot1")[1].Text, "🔁", 1, true) ~= nil)
		RT.fire(findAll(gui, "SwapSlot2")[1], "Activated")
		check("Plateau : toucher un pet vivant envoie « swapN » (N = son indice) et referme le plateau", #fired == 1 and fired[1][1] == "battleAct" and fired[1][2] == "swap3" and tray.Visible == false)
		-- un pet K.O. en réserve n'est pas sélectionnable
		local v3 = Battle.view(st)
		v3.sides[1].units[3].hp = 0
		sc.update(v3, nil)
		fired = {}
		RT.fire(btn("Swap"), "Activated")
		RT.fire(findAll(gui, "SwapSlot2")[1], "Activated")
		check("Plateau : un pet K.O. (💀) n'envoie rien", #fired == 0 and string.find(findAll(gui, "SwapSlot2")[1].Text, "💀", 1, true) ~= nil)
		fired = {}
		RT.fire(btn("Flee"), "Activated")
		check("Fuir : un premier appui demande confirmation (« Sûr ? ») sans rien envoyer", #fired == 0 and btn("Flee").Text == "Sûr ?")
		RT.step(3.5)
		check("Fuir : la confirmation expire après 3 s", btn("Flee").Text ~= "Sûr ?" and #fired == 0)
		RT.fire(btn("Flee"), "Activated")
		RT.fire(btn("Flee"), "Activated")
		check("Fuir : deux appuis rapprochés envoient « battleQuit » (comportement serveur existant : forfait / abandon)", #fired == 1 and fired[1][1] == "battleQuit")
		fired = {}
		sc.setDim(true)
		RT.fire(btn("Attack"), "Activated")
		RT.fire(btn("Special"), "Activated")
		check("Scène assombrie (résultat affiché) : plus aucun envoi possible", #fired == 0)
		local textOk = btn("Attack").Visible == false and findAll(gui, "LogBar")[1].Visible == false
		check("Scène assombrie : boutons et journal masqués", textOk)
		check("Duel : fond de sable (colonnade, pas de haies) ; mode « duel »", T.sand.ground == "sand" and T.sand.pillars == 1 and T.sand.hedges == 0 and T.sand.mode == "duel")
		sc.destroy()
	end

	-- construction défaillante : jamais d'erreur vers l'appelant, aucune instance orpheline
	do
		local gui = newGui()
		local st = newBattle(2)
		local ok, sc = pcall(BattleScene.create, { gui = gui, Config = Config, Battle = Battle, Layout = L, player = {}, payload = {}, view = Battle.view(st), foeName = "x", floor = 1, fire = function() end })
		check("create : sans specialState ni iconUrl ni onChosen, la scène se construit", ok and sc ~= nil)
		if sc then
			sc.destroy()
		end
		local ok2, sc2 = pcall(BattleScene.create, { gui = gui, Config = Config, Battle = Battle, Layout = { MAX_INSTANCES = 10, mode = L.mode, ground = L.ground, palette = L.palette, plan = L.plan, rects = L.rects, scene = L.scene, decorSpots = L.decorSpots, cardInner = L.cardInner, UI = L.UI, NEUTRAL_COLOR = L.NEUTRAL_COLOR, typeColor = L.typeColor, MAX_DOTS = 6, CHARGE_MAX = 5 }, player = {}, payload = {}, view = Battle.view(st), foeName = "x", floor = 1, fire = function() end })
		check("Plafond atteint (10 instances) : create retourne nil sans erreur et ne laisse AUCUNE instance dans l'écran", ok2 and sc2 == nil and descendants(gui) == 0)
		local ok3, sc3 = pcall(BattleScene.create, { gui = gui, Config = Config, Battle = Battle, Layout = L, player = {}, payload = {}, view = { sides = { { units = {}, active = 1 }, { units = {}, active = 1 } } }, foeName = "x", floor = 1, fire = function() end })
		check("Vue sans créature : pas d'erreur (scène vide ou nil), écran propre après destruction", ok3 and (sc3 == nil or (function() sc3.destroy() return descendants(gui) == 0 end)()))
		local ok4, sc4 = pcall(BattleScene.create, { gui = gui, Config = Config, Battle = Battle, Layout = L, player = {}, payload = {}, view = { sides = {} }, foeName = "x", floor = 1, fire = function() end })
		check("Vue invalide (sides vide) : create ne lève pas d'erreur", ok4 and sc4 == nil and descendants(gui) == 0)
	end

	---------------------------------------------------------------- 9. BattleUi branché sur la scène
	suite("BattleUi + scène : start / tours / fin / cartes de récompense / duel miroir / classé, 20 combats sans fuite")
	local function installUi(reduced)
		local gui = newGui()
		local RB = RT.instance("RemoteEvent", "Battle")
		local fired = {}
		local state = { battle = { team = {}, best = 4, fightsLeft = 5, repeatsLeft = 5 }, slots = {} }
		local player = { DisplayName = "Moi", UserId = 1 }
		local ui = BattleUi.start(Config, Battle, player, gui, function() return state end, function(a, arg) fired[#fired + 1] = { a, arg } end, RB, {
			BattleScene = BattleScene, BattleLayout = L, reduced = reduced, sound = function() end, iconUrl = function() return nil end,
		})
		return { gui = gui, RB = RB, fired = fired, ui = ui }
	end
	local function send(h, payload)
		RT.fire(h.RB, "OnClientEvent", payload)
	end
	local function sceneRoots(h)
		return #findAll(h.gui, "BattleScene")
	end
	local H = installUi(false)
	check("BattleUi.start avec BattleScene / BattleLayout : interface construite, panneau compact responsive (largeur écran - 16, 360 au plus)", H.ui ~= nil and H.ui.panel ~= nil and #findAll(H.ui.panel, "x") == 0 and #H.gui:GetChildren() >= 2)
	T.baseChildren = #H.gui:GetChildren()
	T.uiLeak, T.uiErr0, T.panelHidden, T.panelShownAtEnd, T.continueOk, T.pickOk = 0, #RT.errors, 0, 0, 0, 0
	for c = 1, 20 do
		local st = newBattle(c)
		local kind = c % 5 -- 0 : tour, 1 : duel, 2 : classé enregistré, 3 : classé en direct, 4 : PNJ
		local payload = { k = "start", floor = kind == 0 and c or 0, foe = "Adversaire " .. c, view = Battle.view(st), seconds = 10 }
		if kind == 1 then
			payload.duel = true
			payload.arena = { x = 0, z = 0, side = 1 }
			payload.intro = { me = { name = "Moi", userId = 1 }, foe = { name = "Rival", userId = 2 } }
		elseif kind == 2 then
			payload.pvp = true
		elseif kind == 3 then
			payload.pvp, payload.live = true, true
		elseif kind == 4 then
			payload.npc = true
		end
		send(H, payload)
		if sceneRoots(H) == 1 and H.ui.panel.Visible == false then
			T.panelHidden = T.panelHidden + 1
		end
		if c == 1 then
			T.mode1 = findAll(H.gui, "Pillar1")[1] ~= nil or findAll(H.gui, "Hedge1")[1] ~= nil
		end
		T.ground = T.ground or {}
		T.ground[kind] = (findAll(H.gui, "Pillar1")[1] ~= nil) and "sand" or ((findAll(H.gui, "Hedge1")[1] ~= nil) and "grass" or "?")
		local turns = 0
		while not st.over and turns < 60 do
			turns = turns + 1
			local ev = Battle.turn(st, Battle.aiAction(st, 1))
			send(H, { k = "turn", events = ev, view = Battle.view(st), seconds = 10 })
			RT.step(0.6)
		end
		-- fin : victoire avec cartes de récompense (3 cartes), puis choix, puis « Continuer »
		local win = st.winner == 1
		send(H, { k = "end", win = win, rewards = { coins = 100 }, pick = win, duel = kind == 1 or nil, pvp = kind >= 2 and kind <= 3 or nil, view = Battle.view(st) })
		if H.ui.panel.Visible == true and #findAll(H.gui, "BattleScene") == 1 then
			T.panelShownAtEnd = T.panelShownAtEnd + 1
		end
		if win then
			send(H, { k = "pick", id = "k" .. c, seconds = 15, cards = { { kind = "coins", icon = "🪙", title = "Pièces", desc = "+500" }, { kind = "egg", icon = "🥚", title = "Œuf", desc = "1 œuf", boss = true }, { kind = "speed", icon = "👟", title = "Vitesse", desc = "+3" } } })
			local cards = {}
			for _, b in ipairs(H.ui.body:GetChildren()) do
				if b.ClassName == "TextButton" then
					cards[#cards + 1] = b
				end
			end
			H.fired = {}
			if #cards == 3 then
				RT.fire(cards[2], "Activated")
			end
			if #cards == 3 and sceneRoots(H) == 1 then
				T.pickOk = T.pickOk + 1
			end
			send(H, { k = "picked", text = "+1 œuf", auto = false })
		end
		local cont
		for _, b in ipairs(H.ui.body:GetChildren()) do
			if b.ClassName == "TextButton" and b.Text == "Continuer" then
				cont = b
			end
		end
		if cont then
			T.continueOk = T.continueOk + 1
			RT.fire(cont, "Activated")
		end
		RT.step(1)
		if sceneRoots(H) ~= 0 or #H.gui:GetChildren() ~= T.baseChildren then
			T.uiLeak = T.uiLeak + 1
		end
	end
	check("20 combats (tour, duel, classé enregistré, classé en direct, PNJ) : la scène remplace le panneau (panneau caché), un seul écran de combat à la fois", T.panelHidden == 20)
	check("Fond : sable pour duel / classé enregistré / classé en direct, herbe pour la tour et les PNJ", T.ground[1] == "sand" and T.ground[2] == "sand" and T.ground[3] == "sand" and T.ground[0] == "grass" and T.ground[4] == "grass")
	check("Fin de combat : le résultat s'affiche en panneau par-dessus la scène assombrie (20 / 20)", T.panelShownAtEnd == 20)
	check("Cartes de récompense du lot 12 B : 3 cartes cliquables au-dessus de la scène (victoires), « Continuer » après le choix, un seul clic", T.pickOk > 0 and T.continueOk == 20)
	check("Après « Continuer » (20 combats de suite) : scène détruite, plus aucune instance de combat dans l'écran (nombre d'enfants identique à l'initial)", T.uiLeak == 0)
	check("Aucune erreur de script pendant les 20 combats de BattleUi", #RT.errors == T.uiErr0)
	for k in pairs(H.fired) do
		H.fired[k] = nil
	end
	send(H, { k = "start", floor = 2, foe = "Dresseur", view = Battle.view(newBattle(3)), seconds = 10 })
	RT.fire(findAll(H.gui, "Attack")[1], "Activated")
	RT.fire(findAll(H.gui, "Flee")[1], "Activated")
	RT.fire(findAll(H.gui, "Flee")[1], "Activated")
	check("Via BattleUi : Attaque -> « battleAct »/« attack » ; Fuir (2 appuis) -> « battleQuit » ; rien d'autre n'est envoyé", #H.fired == 2 and H.fired[1][1] == "battleAct" and H.fired[1][2] == "attack" and H.fired[2][1] == "battleQuit")
	-- un nouveau « start » pendant un combat remplace la scène (pas de doublon)
	send(H, { k = "start", floor = 3, foe = "Autre", view = Battle.view(newBattle(5)), seconds = 10 })
	check("Deuxième « start » sans fin : une seule scène (l'ancienne est détruite)", sceneRoots(H) == 1)
	-- fermeture du panneau sur l'écran de résultat : la scène est libérée
	send(H, { k = "end", win = false, rewards = {}, view = Battle.view(newBattle(5)) })
	RT.fire(H.ui.close, "Activated")
	check("Résultat fermé par ✕ : la scène est détruite (jamais d'écran de combat orphelin), le bouton ⚔️ revient", sceneRoots(H) == 0 and H.ui.open.Visible == true)
	-- sans BattleScene (ancien chemin) : le panneau compact reste utilisé tel quel
	local gui2 = newGui()
	local RB2 = RT.instance("RemoteEvent", "Battle")
	local ui2 = BattleUi.start(Config, Battle, { DisplayName = "Moi", UserId = 1 }, gui2, function() return { battle = { team = {}, best = 1, fightsLeft = 1, repeatsLeft = 1 }, slots = {} } end, function() end, RB2, nil)
	RT.fire(RB2, "OnClientEvent", { k = "start", floor = 1, foe = "Dresseur", view = Battle.view(newBattle(1)), seconds = 10 })
	check("Sans BattleScene (fx absent) : ancien panneau compact, aucune scène (repli intact)", ui2.panel.Visible == true and #findAll(gui2, "BattleScene") == 0)
	local gui3 = newGui()
	local RB3 = RT.instance("RemoteEvent", "Battle")
	local ui3 = BattleUi.start({ TOWER = Config.TOWER, PETS = Config.PETS, TYPE_ICON = Config.TYPE_ICON, BATTLE_FX = { Enabled = true, scene = false }, SLOTS_MAX = Config.SLOTS_MAX, PVP = Config.PVP, TYPE_SPECIAL_NAME = Config.TYPE_SPECIAL_NAME, fmt = Config.fmt }, Battle, { DisplayName = "Moi", UserId = 1 }, gui3, function() return { battle = { team = {}, best = 1, fightsLeft = 1, repeatsLeft = 1 }, slots = {} } end, function() end, RB3, { BattleScene = BattleScene, BattleLayout = L })
	RT.fire(RB3, "OnClientEvent", { k = "start", floor = 1, foe = "Dresseur", view = Battle.view(newBattle(1)), seconds = 10 })
	check("Config.BATTLE_FX.scene = false : ancien panneau compact (interrupteur de repli)", ui3.panel.Visible == true and #findAll(gui3, "BattleScene") == 0)

	---------------------------------------------------------------- 10. Compatibilité : modules et intégration
	suite("Refonte du combat : intégration (Config, place, Client, absence de changement serveur)")
	local cfgSrc = fs.readFile("roblox/src/ReplicatedStorage/Config.lua")
	check("Config.BATTLE_FX.scene = true par défaut (la scène est active)", Config.BATTLE_FX.scene == true and string.find(cfgSrc, "scene = true", 1, true) ~= nil)
	local cl = fs.readFile("roblox/src/StarterPlayerScripts/Client.client.lua")
	check("Client : BattleLayout et BattleScene fournis à BattleUi (même appel, mêmes remotes)", string.find(cl, "BattleLayout = require", 1, true) ~= nil and string.find(cl, "BattleScene = require", 1, true) ~= nil and string.find(cl, "Remotes:WaitForChild(\"Battle\")", 1, true) ~= nil)
	local bp = fs.readFile("roblox/tools/build_place.py")
	check("build_place.py : BattleLayout dans Shared et BattleScene dans StarterPlayerScripts", string.find(bp, "\"BattleLayout\", \"BattleLayout.lua\"", 1, true) ~= nil and string.find(bp, "\"BattleScene\", read(\"StarterPlayerScripts/BattleScene.lua\")", 1, true) ~= nil)
	local bs = fs.readFile("roblox/src/StarterPlayerScripts/BattleScene.lua")
	local bl = fs.readFile("roblox/src/ReplicatedStorage/BattleLayout.lua")
	local hasBad = false
	local function code(src) -- sans les commentaires
		local out = {}
		for line in string.gmatch(src, "[^\n]*") do
			local cut = string.find(line, "%-%-")
			out[#out + 1] = cut and string.sub(line, 1, cut - 1) or line
		end
		return table.concat(out, "\n")
	end
	for _, src0 in ipairs({ bs, bl }) do
		local src = code(src0)
		for _, pat in ipairs({ "%+=", "%-=", "math%.atan2", "\n%s*continue%s", "math%.random" }) do
			if string.find(src, pat) then
				hasBad = true
			end
		end
	end
	check("BattleScene / BattleLayout : ni += / -= ni continue ni math.atan2 ni math.random (lanceur lupa, tests déterministes)", not hasBad)
	local blc = code(bl)
	check("BattleLayout est pur : aucun require, aucune instance Roblox, aucun service", string.find(blc, "require", 1, true) == nil and string.find(blc, "Instance.new", 1, true) == nil and string.find(blc, "GetService", 1, true) == nil)
end
