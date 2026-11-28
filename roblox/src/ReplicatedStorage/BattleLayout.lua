-- ModuleScript : ReplicatedStorage/Shared/BattleLayout   (refonte de la présentation du combat, vue face à face)
-- Module PUR (aucune instance Roblox, aucun require) : calcule la disposition de l'écran de combat à partir de la taille de la fenêtre et de la zone sûre :
--   * rectangles en pixels (et en échelle) de la carte de l'adversaire (haut à droite), de la carte du joueur (bas à gauche), du bandeau de journal (bas),
--     des 4 boutons d'action (bas à droite : Attaque, Spécial, Changer, Fuir), tous >= 44 px, jamais en dehors de la zone sûre, jamais superposés ;
--   * composition interne des cartes (nom, niveau, barre de PV, texte de PV, points d'état de l'équipe, pastilles de charge du spécial) ;
--   * scène 3D : positions des deux socles lumineux, caméra fixe en léger angle cadrée sur la zone libre entre les cartes, sable ou herbe selon le lieu ;
--   * textes et couleurs (PV « 260/260 », points d'état, charge du spécial 0..5, couleur de barre) et signaux d'animation tirés des événements du moteur ;
--   * plafond d'instances : estimation du coût de la scène, décor réduit pour rester sous MAX_INSTANCES (mobile : moins d'effets) ;
--   * états sous les cartes (pastilles), écran « Changer », flash du spécial, sons par action (Config.SOUNDS seulement), XP de fin (message du serveur seulement).
-- Ne lit que ce que le serveur envoie déjà (vue Battle.view, événements, payload « start »). Pas de += / -= / continue, pas de math.atan2 (lanceur lupa).
local BattleLayout = {}

BattleLayout.MAX_INSTANCES = 220 -- plafond de la scène (même plafond que HatchFx) ; l'intro (120) et les effets de type (80) ont leurs propres plafonds
BattleLayout.MIN_TOUCH = 44 -- cible tactile minimale (pixels)
BattleLayout.MARGIN = 8
BattleLayout.GAP = 6
BattleLayout.SPEED_BUTTON = 52 -- largeur des boutons de vitesse et de saut (hauteur 48)
BattleLayout.QUEUE_W, BattleLayout.QUEUE_H = 104, 28
BattleLayout.MAX_DOTS = 6 -- points d'état d'équipe par camp
BattleLayout.CHARGE_MAX = 5
BattleLayout.WIDE_MIN_WIDTH = 520 -- en dessous : disposition étroite (téléphone en portrait)
BattleLayout.DEFAULT_VIEWPORT = { w = 640, h = 360 }
BattleLayout.MIN_VIEWPORT = { w = 240, h = 320 }

-- Couleurs propres à Chipe-Œufs (aucune reprise d'un autre jeu).
BattleLayout.PALETTE = {
	sand = { ground = { 226, 196, 132 }, rim = { 168, 134, 84 }, skyTop = { 255, 206, 150 }, skyBottom = { 255, 238, 205 }, deco = { 214, 196, 160 }, ambient = { 190, 170, 140 }, light = { 255, 240, 215 } },
	grass = { ground = { 112, 192, 94 }, rim = { 70, 140, 72 }, skyTop = { 136, 202, 255 }, skyBottom = { 218, 242, 255 }, deco = { 66, 158, 76 }, ambient = { 150, 175, 160 }, light = { 255, 252, 235 } },
}
BattleLayout.UI = {
	card = { 24, 38, 46 }, cardStroke = { 244, 232, 196 }, text = { 250, 247, 238 }, muted = { 176, 196, 200 },
	hp = { 91, 227, 125 }, hpWarn = { 255, 196, 60 }, hpLow = { 255, 99, 99 }, hpBack = { 52, 36, 44 },
	dotOn = { 91, 227, 125 }, dotOff = { 70, 78, 84 }, pipOn = { 255, 210, 63 }, pipOff = { 62, 58, 84 },
	attack = { 255, 159, 28 }, special = { 74, 163, 255 }, specialOff = { 70, 74, 86 }, swap = { 184, 120, 255 }, flee = { 255, 99, 99 },
	log = { 16, 26, 32 }, status = { 255, 226, 140 },
	darkText = { 14, 28, 18 }, lightText = { 244, 244, 252 }, fleeText = { 40, 8, 8 }, swapText = { 14, 20, 30 }, offText = { 220, 222, 232 },
	meChip = { 74, 163, 255 }, foeChip = { 255, 107, 107 },
	rowActive = { 58, 72, 86 }, specialFill = { 78, 88, 124 },
}
-- Couleur du socle lumineux par type (le type est « Nature » ou « Plante » selon la source).
BattleLayout.TYPE_COLOR = {
	Feu = { 255, 122, 61 }, Eau = { 66, 170, 255 }, Nature = { 96, 214, 98 }, Plante = { 96, 214, 98 }, Glace = { 150, 228, 255 }, Foudre = { 255, 224, 64 },
	Terre = { 196, 146, 90 }, Ciel = { 170, 190, 255 }, Ombre = { 160, 110, 210 }, ["Lumière"] = { 255, 244, 170 },
}
BattleLayout.NEUTRAL_COLOR = { 220, 220, 230 }

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function clamp(v, lo, hi)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

local function int(v, default)
	if isNum(v) then
		return math.floor(v)
	end
	return default
end

local function rect(x, y, w, h)
	return { x = x, y = y, w = w, h = h }
end

function BattleLayout.typeColor(typ)
	return BattleLayout.TYPE_COLOR[typ] or BattleLayout.NEUTRAL_COLOR
end

---------------------------------------------------------------- fenêtre, zone sûre

-- Taille de fenêtre assainie (valeurs invalides -> 640 x 360 ; minimum 240 x 320 : sous cette taille rien ne tient de toute façon).
function BattleLayout.viewport(vw, vh)
	local d, m = BattleLayout.DEFAULT_VIEWPORT, BattleLayout.MIN_VIEWPORT
	local w = isNum(vw) and vw > 0 and vw or d.w
	local h = isNum(vh) and vh > 0 and vh or d.h
	return math.floor(math.max(m.w, w)), math.floor(math.max(m.h, h))
end

-- Zone sûre { l, t, r, b } (pixels) assainie ; jamais plus de 25 % de la fenêtre par bord.
function BattleLayout.safe(raw, vw, vh)
	local s = type(raw) == "table" and raw or {}
	return {
		l = clamp(isNum(s.l) and s.l or 0, 0, vw * 0.25),
		t = clamp(isNum(s.t) and s.t or 0, 0, vh * 0.25),
		r = clamp(isNum(s.r) and s.r or 0, 0, vw * 0.25),
		b = clamp(isNum(s.b) and s.b or 0, 0, vh * 0.25),
	}
end

-- Composition interne d'une carte de largeur w : retourne des rectangles RELATIFS à la carte.
--   adversaire : ligne de contexte (étage / dresseur), ligne nom + niveau, barre de PV, points d'état.
--   joueur : ligne nom + niveau, barre de PV, texte « PV » + points d'état à droite, pastilles de charge.
function BattleLayout.cardInner(w, isMe)
	local pad = 8
	local iw = math.max(40, w - 2 * pad)
	local out = { pad = pad }
	if isMe then
		out.h = 82
		out.icon = rect(pad, 6, 22, 22)
		out.name = rect(pad + 26, 6, iw - 26 - 62, 22)
		out.level = rect(w - pad - 60, 6, 60, 22)
		out.bar = rect(pad, 32, iw, 12)
		out.hp = rect(pad, 47, iw - 90, 16)
		out.dots = rect(w - pad - 84, 49, 84, 12)
		out.pips = rect(pad, 66, iw, 10)
	else
		out.h = 76
		out.ctx = rect(pad, 4, iw, 14)
		out.icon = rect(pad, 20, 22, 22)
		out.name = rect(pad + 26, 20, iw - 26 - 62, 22)
		out.level = rect(w - pad - 60, 20, 60, 22)
		out.bar = rect(pad, 46, iw, 12)
		out.dots = rect(pad, 62, iw, 10)
		out.pips = nil
	end
	return out
end

---------------------------------------------------------------- disposition de l'écran

-- Disposition en pixels pour une fenêtre vw x vh et une zone sûre (optionnelle). Retourne :
--   { mode = "wide"|"narrow", vw, vh, safe, area = zone utile, foeCard, meCard, log, actions = { attack, special, swap, flee }, stage = zone libre pour les
--     créatures, swapTray = plateau des pets de réserve (au-dessus des boutons), cardW }
-- Le plateau de réserve (swapTray) recouvre le journal pendant qu'il est ouvert.
-- Garanties (testées sur une matrice d'appareils) : rectangles dans la zone utile, sans superposition, boutons >= MIN_TOUCH, coin haut gauche libre (boutons
-- natifs de Roblox : menu, discussion), carte adverse en haut à droite, carte du joueur en bas à gauche.
function BattleLayout.rects(vw, vh, safeIn)
	vw, vh = BattleLayout.viewport(vw, vh)
	local sf = BattleLayout.safe(safeIn, vw, vh)
	local m, gap = BattleLayout.MARGIN, BattleLayout.GAP
	local ax0, ay0 = sf.l + m, sf.t + m
	local ax1, ay1 = vw - sf.r - m, vh - sf.b - m
	local aw, ah = ax1 - ax0, ay1 - ay0
	local wide = vw >= BattleLayout.WIDE_MIN_WIDTH and vw > vh
	local meI = BattleLayout.cardInner(100, true)
	local foeI = BattleLayout.cardInner(100, false)
	local out = { mode = wide and "wide" or "narrow", vw = vw, vh = vh, safe = sf, area = rect(ax0, ay0, aw, ah), actions = {} }
	local bh = BattleLayout.MIN_TOUCH + 4 -- boutons de 48 px de haut
	if wide then
		local cardW = math.floor(clamp(vw * 0.36, 200, 300))
		local bw = math.floor(clamp(vw * 0.16, 88, 132))
		local gw, gh = 2 * bw + gap, 2 * bh + gap
		local logH = 56
		out.cardW = cardW
		out.foeCard = rect(ax1 - cardW, ay0, cardW, foeI.h)
		out.fullLog = rect(ax0, ay1 - logH, aw - gw - gap, logH)
		local gx, gy = ax1 - gw, ay1 - gh
		out.log = out.fullLog
		out.actions.attack = rect(gx, gy, bw, bh)
		out.actions.special = rect(gx + bw + gap, gy, bw, bh)
		out.actions.swap = rect(gx, gy + bh + gap, bw, bh)
		out.actions.flee = rect(gx + bw + gap, gy + bh + gap, bw, bh)
		out.meCard = rect(ax0, out.fullLog.y - gap - meI.h, cardW, meI.h)
	else
		local cardW = math.floor(clamp(aw * 0.7, 200, 260))
		local bw = math.floor((aw - 3 * gap) / 4)
		local logH = 60
		out.cardW = cardW
		out.foeCard = rect(ax1 - cardW, ay0, cardW, foeI.h)
		out.fullLog = rect(ax0, ay1 - logH, aw, logH)
		out.log = out.fullLog
		local ay = out.fullLog.y - gap - bh
		out.actions.attack = rect(ax0, ay, bw, bh)
		out.actions.special = rect(ax0 + (bw + gap), ay, bw, bh)
		out.actions.swap = rect(ax0 + 2 * (bw + gap), ay, bw, bh)
		out.actions.flee = rect(ax0 + 3 * (bw + gap), ay, bw, bh)
		out.meCard = rect(ax0, ay - gap - meI.h, cardW, meI.h)
	end
	-- plateau de réserve (3 boutons) : il remplace le journal tant qu'il est ouvert (le journal est alors masqué) ; jamais sur les cartes ni sur les boutons
	local fl = out.fullLog
	out.swapTray = rect(fl.x, fl.y + math.floor((fl.h - bh) / 2), fl.w, bh)
	local sb = BattleLayout.SPEED_BUTTON
	local by = fl.y + math.floor((fl.h - bh) / 2)
	out.skip = rect(fl.x + fl.w - sb, by, sb, bh) -- « Passer l'animation » (visible dès le 2e combat vu)
	out.speed = rect(fl.x + fl.w - 2 * sb - gap, by, sb, bh) -- vitesse 1x / 2x / 3x
	out.log = rect(fl.x, fl.y, fl.w - 2 * sb - 2 * gap, fl.h)
	out.queue = rect(out.foeCard.x + out.foeCard.w - BattleLayout.QUEUE_W, out.foeCard.y + out.foeCard.h + 4, BattleLayout.QUEUE_W, BattleLayout.QUEUE_H) -- ordre du tour : 3 pastilles sous la carte adverse
	if wide then -- les cartes sont dans les coins : la scène occupe toute la hauteur utile (la carte du joueur peut mordre sur les 36 derniers pixels du socle)
		out.stage = rect(0, ay0, vw, math.max(40, out.meCard.y + 36 - ay0))
	else -- cartes empilées : la scène occupe l'espace libre entre elles
		local top = out.queue.y + out.queue.h + 4
		out.stage = rect(0, top, vw, math.max(40, out.meCard.y - top))
	end
	return out
end

-- Rectangle en fractions de la fenêtre : { sx, sy, sw, sh } (pour les positions et tailles en échelle).
function BattleLayout.toScale(r, vw, vh)
	vw, vh = BattleLayout.viewport(vw, vh)
	return { sx = r.x / vw, sy = r.y / vh, sw = r.w / vw, sh = r.h / vh }
end

-- Deux rectangles se recouvrent-ils ? (bords qui se touchent = non)
function BattleLayout.overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

---------------------------------------------------------------- scène 3D (socles, caméra, décor)

local function vec(x, y, z)
	return { x = x, y = y, z = z }
end

-- Lieu du combat -> « sand » (colisée : duel, classé enregistré, classé en direct) ou « grass » (arène PvE : tour, PNJ). Inconnu -> herbe.
function BattleLayout.mode(p)
	local t = type(p) == "table" and p or {}
	if t.duel == true then
		return "duel"
	elseif t.live == true then
		return "live"
	elseif t.pvp == true then
		return "pvp"
	elseif t.npc == true then
		return "npc"
	end
	return "tower"
end

-- « Fuir » : un appui là où l'abandon ne coûte rien (tour, PNJ : simple défaite sans perte), deux appuis là où il coûte (duel : forfait ; classé
-- enregistré : trophées perdus ; classé en direct : forfait). Mode inconnu -> deux appuis (prudence). Accepte un mode ou un message « start ».
function BattleLayout.fleeNeedsConfirm(modeOrPayload)
	local mode = modeOrPayload
	if type(modeOrPayload) == "table" then
		mode = BattleLayout.mode(modeOrPayload)
	end
	if mode == "tower" or mode == "npc" then
		return false
	end
	return true
end

function BattleLayout.ground(modeOrPayload)
	local mode = modeOrPayload
	if type(modeOrPayload) == "table" then
		mode = BattleLayout.mode(modeOrPayload)
	end
	if mode == "duel" or mode == "live" or mode == "pvp" or mode == "colisee" then
		return "sand"
	end
	return "grass"
end

function BattleLayout.palette(ground)
	return BattleLayout.PALETTE[ground] or BattleLayout.PALETTE.grass
end

-- Scène : socles (rayon `pedestal`), caméra fixe en léger angle (16°), champ de vision vertical 40°. La distance de la caméra est calculée pour que les deux
-- socles et leurs créatures tiennent dans la zone libre (`stage` de rects) ; la cible est décalée pour que cette zone soit le centre visuel. Coordonnées en studs.
function BattleLayout.scene(vw, vh, safeIn, ground)
	local r = BattleLayout.rects(vw, vh, safeIn)
	local narrow = r.mode == "narrow"
	local sc = { ground = ground == "sand" and "sand" or "grass", fov = 40, pedestal = 3.2, elevation = 16 }
	local spread, depth = narrow and 5 or 6.5, narrow and 4 or 3
	sc.me = vec(-spread, 0, depth)
	sc.foe = vec(spread, 0, -depth)
	sc.center = vec(0, 2.5, 0)
	local tanHalf = math.tan(math.rad(sc.fov / 2))
	local aspect = r.vw / r.vh
	local needX = spread + sc.pedestal + 2
	local fitW = narrow and 1 or 0.62 -- largeur écran utilisable par les créatures (les cartes occupent les coins en disposition large)
	local dH = needX / (tanHalf * aspect * fitW)
	local stageFrac = r.stage.h / r.vh
	local dV = 6.5 / (tanHalf * math.max(0.15, stageFrac))
	local d = clamp(math.max(dH, dV), 20, 120)
	local el = math.rad(sc.elevation)
	local cy = (r.stage.y + r.stage.h / 2) / r.vh -- ordonnée écran voulue pour le centre de la scène (0 = haut)
	local halfH = d * tanHalf
	local up = (cy - 0.5) * 2 * halfH -- cible au-dessus du centre de la scène si la zone libre est sous le milieu de l'écran
	sc.target = vec(0, sc.center.y + up, 0)
	sc.eye = vec(0, sc.target.y + d * math.sin(el), d * math.cos(el))
	sc.distance = d
	sc.stage = r.stage
	return sc
end

-- Point de l'écran (pixels, approximation pour les effets lorsque la caméra ne sait pas projeter) au-dessus de chaque socle : 1 = joueur, 2 = adversaire.
function BattleLayout.anchor(side, vw, vh, safeIn)
	local r = BattleLayout.rects(vw, vh, safeIn)
	local st = r.stage
	if side == 1 then
		return { x = st.x + st.w * 0.3, y = st.y + st.h * 0.62 }
	end
	return { x = st.x + st.w * 0.7, y = st.y + st.h * 0.4 }
end

---------------------------------------------------------------- textes, couleurs, états

function BattleLayout.hpFraction(u)
	if type(u) ~= "table" or not isNum(u.hp) or not isNum(u.maxHp) or u.maxHp <= 0 then
		return 0
	end
	return clamp(u.hp / u.maxHp, 0, 1)
end

-- « 260/260 » (entiers, jamais négatif, jamais au-dessus du maximum).
function BattleLayout.hpText(u)
	if type(u) ~= "table" then
		return "0/0"
	end
	local max = math.max(0, int(u.maxHp, 0))
	local hp = clamp(int(u.hp, 0), 0, max)
	return hp .. "/" .. max
end

-- Vert au-dessus de 50 %, ambre jusqu'à 25 %, rouge en dessous.
function BattleLayout.hpColor(frac)
	local U = BattleLayout.UI
	local f = isNum(frac) and frac or 0
	if f > 0.5 then
		return U.hp
	elseif f > 0.25 then
		return U.hpWarn
	end
	return U.hpLow
end

-- Niveau affiché : « Niv. 7 » (au moins 1 ; 1 si le serveur ne l'envoie pas).
function BattleLayout.levelText(u)
	local lv = 1
	if type(u) == "table" and isNum(u.level) then
		lv = clamp(math.floor(u.level), 1, 999)
	end
	return "Niv. " .. lv
end

-- Points d'état de l'équipe : un point par pet (plein = vivant), au plus MAX_DOTS. `active` (indice du pet au combat) est marqué pour l'affichage.
function BattleLayout.teamDots(side)
	local dots = {}
	local units = type(side) == "table" and type(side.units) == "table" and side.units or {}
	local active = type(side) == "table" and isNum(side.active) and math.floor(side.active) or 1
	for i = 1, math.min(#units, BattleLayout.MAX_DOTS) do
		local u = units[i]
		local alive = type(u) == "table" and isNum(u.hp) and u.hp > 0
		dots[i] = { alive = alive == true, active = i == active }
	end
	return dots
end

function BattleLayout.aliveCount(side)
	local n = 0
	for _, d in ipairs(BattleLayout.teamDots(side)) do
		if d.alive then
			n = n + 1
		end
	end
	return n
end

-- Pastilles de charge du spécial : { true, true, false, false, false } pour 2/5 ; `ready` à 5/5.
function BattleLayout.chargePips(charge, max)
	local mx = isNum(max) and clamp(math.floor(max), 1, 10) or BattleLayout.CHARGE_MAX
	local c = isNum(charge) and clamp(math.floor(charge), 0, mx) or 0
	local pips = {}
	for i = 1, mx do
		pips[i] = i <= c
	end
	return { pips = pips, charge = c, max = mx, ready = c >= mx }
end

-- Bouton « Spécial » : texte « Spécial 3/5 », prêt ou non. `ss` = BattleUi.specialState (module existant, réutilisé : jamais dupliqué) ; sans charge (moteur du lot 8) :
-- le texte de recharge de `ss` est conservé.
function BattleLayout.specialButton(ss)
	local s = type(ss) == "table" and ss or {}
	local info = BattleLayout.chargePips(s.charge, s.max)
	return { text = type(s.text) == "string" and s.text or ("Spécial " .. info.charge .. "/" .. info.max), ready = s.ready == true, charge = info.charge, max = info.max }
end

-- Réserve : pets du camp (hors actif) avec PV, pour le plateau « Changer » : { { index, alive, hp, maxHp, p } }.
function BattleLayout.bench(side)
	local out = {}
	local units = type(side) == "table" and type(side.units) == "table" and side.units or {}
	local active = type(side) == "table" and isNum(side.active) and math.floor(side.active) or 1
	for i, u in ipairs(units) do
		if i ~= active and type(u) == "table" then
			out[#out + 1] = { index = i, alive = isNum(u.hp) and u.hp > 0, hp = clamp(int(u.hp, 0), 0, 9999999), maxHp = int(u.maxHp, 0), p = u.p }
		end
	end
	return out
end

-- Efficacité de type : texte court, icône (jamais la couleur seule), couleur du nombre de dégâts. Seuils identiques à BattleUi.EFFICACY / TypeFx.efficacy.
--   super (x1,5 et plus) : vert + « ▲ » ; bon (x1,2) : vert clair + « ▲ » ; neutre : gris clair, aucun texte ; peu efficace (x0,95 et moins) : rouge pâle + « ▼ ».
function BattleLayout.efficacy(mul)
	local U = BattleLayout.UI
	local neutral = { kind = "neutral", text = nil, icon = "", rgb = { 214, 218, 224 } }
	if not isNum(mul) or mul <= 0 then
		return neutral
	end
	if mul >= 1.5 - 1e-9 then
		return { kind = "super", text = "Super efficace !", icon = "▲", rgb = { 96, 232, 120 } }
	elseif mul >= 1.2 - 1e-9 then
		return { kind = "good", text = "Efficace", icon = "▲", rgb = { 160, 236, 130 } }
	elseif mul <= 0.7 + 1e-9 then
		return { kind = "resist", text = "Pas très efficace…", icon = "▼", rgb = { 255, 150, 150 } }
	elseif mul <= 0.95 + 1e-9 then
		return { kind = "weak", text = "Peu efficace", icon = "▼", rgb = { 255, 176, 160 } }
	end
	return neutral
end

-- Signal d'animation tiré d'un événement du moteur (côté 1 = joueur, y compris en duel : la vue miroir est déjà appliquée par le serveur) :
--   { anim = "attack"|"heal"|"guard"|"swap"|"ko"|nil, actor = 1|2, target = 1|2, message = { text, rgb, icon } | nil (type : affiché AVANT le nombre),
--     popup = { text, rgb, side } | nil (nombre de dégâts : couleur par efficacité + icône) }
function BattleLayout.cue(ev)
	if type(ev) ~= "table" or (ev.side ~= 1 and ev.side ~= 2) then
		return nil
	end
	local actor = ev.side
	local foe = actor == 1 and 2 or 1
	local U = BattleLayout.UI
	if ev.t == "hit" then
		local dmg = isNum(ev.dmg) and math.max(0, math.floor(ev.dmg)) or 0
		local ef = BattleLayout.efficacy(ev.mul)
		local sp = ev.special == true
		local msg = ef.text and { text = ef.text, rgb = ef.rgb, icon = ef.icon } or nil
		return { anim = "attack", actor = actor, target = foe, special = sp, message = msg, kind = ef.kind,
			popup = { text = "-" .. dmg .. (ef.icon ~= "" and (" " .. ef.icon) or "") .. (sp and " ✨" or ""), rgb = ef.rgb, side = foe } }
	elseif ev.t == "heal" then
		local amount = isNum(ev.amount) and math.max(0, math.floor(ev.amount)) or 0
		return { anim = "heal", actor = actor, target = actor, popup = { text = "+" .. amount .. " ♥", rgb = U.hp, side = actor } }
	elseif ev.t == "guard" then
		return { anim = "guard", actor = actor, target = actor }
	elseif ev.t == "swap" then
		return { anim = "swap", actor = actor, target = actor }
	elseif ev.t == "ko" then
		return { anim = "ko", actor = actor, target = actor }
	elseif ev.t == "splash" then
		local dmg = isNum(ev.dmg) and math.max(0, math.floor(ev.dmg)) or 0
		return { anim = "attack", actor = actor, target = foe, popup = { text = "-" .. dmg .. " ⚡", rgb = { 255, 224, 64 }, side = foe } }
	end
	return nil
end

---------------------------------------------------------------- animations : PV qui défilent, cadence, vitesse, ordre du tour

BattleLayout.HP_ROLL_SECONDS = 0.5
BattleLayout.MAX_ANIM = 1.2 -- aucune animation ne dépasse 1,2 s (à vitesse 1x) : jamais de temps mort
BattleLayout.SPEEDS = { 1, 2, 3 }

-- Valeur de PV affichée à l'instant a (0..1) d'un défilement de `from` vers `to` : ralentissement progressif (cubique), extrémités exactes, jamais de dépassement.
function BattleLayout.hpRoll(from, to, a)
	local f = isNum(from) and from or 0
	local t = isNum(to) and to or f
	local k = isNum(a) and clamp(a, 0, 1) or 1
	local e = 1 - (1 - k) * (1 - k) * (1 - k)
	return f + (t - f) * e
end

-- Entier affiché pendant le défilement (arrondi vers le bas en descente, vers le haut en montée : le chiffre n'atteint la cible qu'à la fin).
function BattleLayout.hpRollInt(from, to, a)
	local v = BattleLayout.hpRoll(from, to, a)
	local f = isNum(from) and from or 0
	local t = isNum(to) and to or f
	if t < f then
		return math.max(math.floor(t), math.ceil(v - 1e-9))
	end
	return math.min(math.floor(t), math.floor(v + 1e-9))
end

function BattleLayout.speedNext(cur)
	local n = isNum(cur) and math.floor(cur) or 1
	if n >= 3 then
		return 1
	elseif n < 1 then
		return 1
	end
	return n + 1
end
function BattleLayout.speedLabel(speed)
	return (isNum(speed) and clamp(math.floor(speed), 1, 3) or 1) .. "×"
end

-- Durée réelle d'une animation de base `seconds` (secondes) à la vitesse `speed` : jamais plus de MAX_ANIM, divisée par la vitesse (1x, 2x, 3x).
function BattleLayout.animSeconds(seconds, speed)
	local sp = isNum(speed) and clamp(speed, 1, 3) or 1
	local base = isNum(seconds) and clamp(seconds, 0, BattleLayout.MAX_ANIM) or 0
	return base / sp
end

-- « Passer l'animation » : jamais au premier combat vu ; proposé dès que le joueur en a déjà vu `seen` >= 1 (donc à partir du 2e).
function BattleLayout.skipAvailable(seen)
	return isNum(seen) and seen >= 1
end

-- Cadence d'un tour : instants (s) de chacun des `n` coups d'un tour (0,6 s d'écart à 1x), la durée totale reste <= 3 coups x 0,6 + MAX_ANIM.
function BattleLayout.cadence(n, speed)
	local count = isNum(n) and clamp(math.floor(n), 0, 8) or 0
	local out = {}
	for i = 1, count do
		out[i] = BattleLayout.animSeconds(0.6, speed) * (i - 1)
	end
	return out, (count > 0 and (BattleLayout.animSeconds(0.6, speed) * (count - 1) + BattleLayout.animSeconds(BattleLayout.MAX_ANIM, speed)) or 0)
end

-- Ordre du tour : qui agit en premier d'après les événements du dernier tour (premier événement d'action), sinon d'après la vitesse des créatures actives si la
-- vue la fournit, sinon le joueur. Retourne `n` côtés (1 = joueur, 2 = adversaire) en alternant : { 1, 2, 1 } ou { 2, 1, 2 }.
function BattleLayout.firstActor(events, view)
	if type(events) == "table" then
		for _, ev in ipairs(events) do
			if type(ev) == "table" and (ev.side == 1 or ev.side == 2) and (ev.t == "hit" or ev.t == "heal" or ev.t == "guard" or ev.t == "swap" or ev.t == "stunned" or ev.t == "discharge") then
				return ev.side
			end
		end
	end
	if type(view) == "table" and type(view.sides) == "table" then
		local a, b = view.sides[1], view.sides[2]
		local ua = type(a) == "table" and type(a.units) == "table" and a.units[a.active or 1] or nil
		local ub = type(b) == "table" and type(b.units) == "table" and b.units[b.active or 1] or nil
		if type(ua) == "table" and type(ub) == "table" and isNum(ua.spd) and isNum(ub.spd) and ub.spd > ua.spd then
			return 2
		end
	end
	return 1
end
function BattleLayout.turnQueue(events, view, n)
	local first = BattleLayout.firstActor(events, view)
	local other = first == 1 and 2 or 1
	local out = {}
	for i = 1, clamp(isNum(n) and math.floor(n) or 3, 1, 6) do
		out[i] = i % 2 == 1 and first or other
	end
	return out
end

---------------------------------------------------------------- fin de combat : progression, contraste

-- Progression vers le palier suivant : { name, next, nextName, percent } d'après le total de trophées et la liste triée Config.LEAGUES ({ name, min }).
function BattleLayout.leagueProgress(total, leagues)
	local t = isNum(total) and math.max(0, math.floor(total)) or 0
	local list = type(leagues) == "table" and leagues or {}
	local cur, nxt
	for _, lg in ipairs(list) do
		if type(lg) == "table" and isNum(lg.min) then
			if t >= lg.min then
				cur = lg
			elseif nxt == nil then
				nxt = lg
			end
		end
	end
	local pct = 100
	if nxt then
		local base = cur and cur.min or 0
		pct = math.floor(clamp((t - base) / math.max(1, nxt.min - base), 0, 1) * 100)
	end
	return { name = cur and cur.name or "", next = nxt and nxt.min or nil, nextName = nxt and nxt.name or nil, percent = pct, total = t }
end

local function lin(c)
	local v = c / 255
	if v <= 0.03928 then
		return v / 12.92
	end
	return ((v + 0.055) / 1.055) ^ 2.4
end
function BattleLayout.luminance(rgb)
	return 0.2126 * lin(rgb[1]) + 0.7152 * lin(rgb[2]) + 0.0722 * lin(rgb[3])
end
-- Rapport de contraste WCAG (1..21) entre deux couleurs { r, g, b }.
function BattleLayout.contrast(a, b)
	local la, lb = BattleLayout.luminance(a), BattleLayout.luminance(b)
	local hi, lo = math.max(la, lb), math.min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
end
-- Couples (texte, fond) réellement affichés par la scène ; chacun doit atteindre 4,5:1 (testé).
function BattleLayout.textPairs()
	local U = BattleLayout.UI
	return {
		{ "nom, PV", U.text, U.card }, { "niveau, contexte", U.muted, U.card }, { "bandeau d'état", U.status, U.log }, { "journal", U.text, U.log },
		{ "Attaque", U.darkText, U.attack }, { "Spécial prêt", U.darkText, U.special }, { "Spécial en charge", U.offText, U.specialOff },
		{ "Changer", U.swapText, U.swap }, { "Fuir", U.fleeText, U.flee }, { "pet K.O.", U.offText, U.specialOff },
		{ "vitesse / saut", U.darkText, { 255, 226, 140 } },
		{ "super efficace", BattleLayout.efficacy(1.5).rgb, U.log }, { "efficace", BattleLayout.efficacy(1.25).rgb, U.log },
		{ "peu efficace", BattleLayout.efficacy(0.8).rgb, U.log }, { "pas très efficace", BattleLayout.efficacy(0.6).rgb, U.log }, { "neutre", BattleLayout.efficacy(1).rgb, U.log },
		{ "soin", U.hp, U.log },
		{ "pastille étourdi", BattleLayout.STATUS_UI.stun.fg, BattleLayout.STATUS_UI.stun.bg }, { "pastille garde", BattleLayout.STATUS_UI.guard.fg, BattleLayout.STATUS_UI.guard.bg },
		{ "pastille concentration", BattleLayout.STATUS_UI.focus.fg, BattleLayout.STATUS_UI.focus.bg }, { "info-bulle d'état", U.text, U.log }, { "pastille +n", BattleLayout.STATUS_MORE.fg, BattleLayout.STATUS_MORE.bg },
		{ "Changer : pet disponible", U.swapText, U.swap }, { "Changer : pet au combat", U.text, U.rowActive }, { "Changer : pet K.O.", U.offText, U.specialOff },
		{ "Spécial en charge (remplie)", U.offText, U.specialFill }, { "Changer : titre", U.text, U.card }, { "Changer : note", U.muted, U.card },
	}
end

---------------------------------------------------------------- états sous les cartes, écran « Changer », flash du spécial, sons, XP de fin

-- États que le moteur (Battle.view, lot 12A) expose réellement : `stun` (nombre de tours à passer), `guard` (booléen : les prochains coups reçus sont réduits ; le
-- nombre de coups restants n'est PAS dans la vue) et `focus` (nombre de tours d'attaque +40 %). Le moteur n'a ni brûlure, ni gel d'état (le spécial « Gel » retire
-- seulement de la charge), ni autre état : AUCUN n'est inventé ici. Chaque pastille porte une icône et un chiffre, jamais la couleur seule ; la durée est lue au toucher.
BattleLayout.STATUS_ORDER = { "stun", "guard", "focus" }
BattleLayout.STATUS_UI = {
	stun = { icon = "💫", label = "Étourdi", bg = { 255, 226, 140 }, fg = { 30, 24, 0 } },
	guard = { icon = "🛡", label = "Garde", bg = { 120, 190, 255 }, fg = { 8, 20, 38 } },
	focus = { icon = "⚡", label = "Concentration", bg = { 255, 170, 70 }, fg = { 38, 20, 0 } },
}
BattleLayout.PILL_W, BattleLayout.PILL_H = 46, 44 -- chaque pastille est aussi sa zone tactile (44 px de haut)
BattleLayout.STATUS_MORE = { bg = { 230, 230, 238 }, fg = { 20, 20, 30 } } -- pastille « +n » (états regroupés faute de place)
BattleLayout.PILL_GAP = 4
BattleLayout.MAX_PILLS = 3
BattleLayout.TIP_SECONDS = 3 -- l'info-bulle d'une pastille disparaît seule après 3 s

-- Pastilles d'une unité de la vue : { { key, icon, label, turns (nombre ou nil), text, bg, fg } }, dans l'ordre stun, guard, focus ; unité KO ou invalide : aucune.
function BattleLayout.statusPills(u)
	local out = {}
	if type(u) ~= "table" or not isNum(u.hp) or u.hp <= 0 then
		return out
	end
	local U = BattleLayout.STATUS_UI
	local function add(key, turns)
		local d = U[key]
		out[#out + 1] = { key = key, icon = d.icon, label = d.label, turns = turns, text = d.icon .. (turns and (" " .. turns) or ""), bg = d.bg, fg = d.fg }
	end
	if isNum(u.stun) and u.stun > 0 then
		add("stun", clamp(math.floor(u.stun), 1, 99))
	end
	if u.guard == true then
		add("guard", nil)
	end
	if isNum(u.focus) and u.focus > 0 then
		add("focus", clamp(math.floor(u.focus), 1, 99))
	end
	return out
end

local function plural(n, one, many)
	return n .. " " .. (n > 1 and many or one)
end

-- Texte affiché au toucher d'une pastille : icône, nom, durée. `Battle` (facultatif) fournit le bonus de concentration réel (Battle.SKILLS.focus.boost).
function BattleLayout.pillDetail(pill, Battle)
	if type(pill) ~= "table" then
		return ""
	end
	if pill.key == "stun" then
		local n = isNum(pill.turns) and pill.turns or 1
		return pill.icon .. " Étourdi : passe " .. (n > 1 and ("ses " .. n .. " prochains tours") or "son prochain tour")
	elseif pill.key == "guard" then
		return pill.icon .. " Garde : les prochains coups reçus font moins de dégâts"
	elseif pill.key == "focus" then
		local n = isNum(pill.turns) and pill.turns or 1
		local boost = type(Battle) == "table" and type(Battle.SKILLS) == "table" and type(Battle.SKILLS.focus) == "table" and Battle.SKILLS.focus.boost or 1.4
		return pill.icon .. " Concentration : attaque +" .. math.floor((boost - 1) * 100 + 0.5) .. " % pendant " .. plural(n, "tour", "tours")
	end
	return ""
end

-- Rectangles des `n` pastilles (au plus MAX_PILLS) d'un camp : camp 2 (adversaire) sous l'ordre du tour, alignées à droite sous la carte ; camp 1 (joueur) au-dessus de
-- sa carte, alignées à gauche. `R` = BattleLayout.rects(...). Chaque rectangle fait PILL_W x PILL_H (>= 44 px de haut) et sert aussi de zone tactile.
function BattleLayout.pillRects(side, R, n)
	local count = clamp(int(n, 0), 0, BattleLayout.MAX_PILLS)
	local W, H, G = BattleLayout.PILL_W, BattleLayout.PILL_H, BattleLayout.PILL_GAP
	local out = {}
	for i = 1, count do
		if side == 2 then
			local right = R.foeCard.x + R.foeCard.w
			out[i] = rect(right - i * W - (i - 1) * G, R.queue.y + R.queue.h + G, W, H)
		else
			out[i] = rect(R.meCard.x + (i - 1) * (W + G), R.meCard.y - G - H, W, H)
		end
	end
	return out
end

-- Placement des pastilles des deux camps sans AUCUNE superposition : pour chaque camp (adversaire d'abord) on garde les premiers emplacements de pillRects qui sont dans la zone
-- utile et libres (ni carte, ni journal, ni bouton, ni vitesse, ni « Passer », ni ordre du tour, ni pastille déjà posée). S'il y a plus d'états que de place, la dernière pastille
-- devient une pastille « +n » qui regroupe le reste (son info-bulle les détaille tous) : aucun état n'est perdu tant qu'une place existe. nFoe / nMe = nombre d'états de chaque camp.
-- Retourne { [1] = { rects, cap, shown, overflow }, [2] = { ... } } ; `shown` pastilles à afficher, `overflow` > 0 si la dernière est une pastille « +n ».
function BattleLayout.pillLayout(R, nFoe, nMe)
	local obstacles = { R.foeCard, R.meCard, R.log, R.actions.attack, R.actions.special, R.actions.swap, R.actions.flee, R.speed, R.skip, R.queue }
	local placed = {}
	local out = {}
	local function free(r)
		local a = R.area
		if r.x < a.x - 1e-6 or r.y < a.y - 1e-6 or r.x + r.w > a.x + a.w + 1e-6 or r.y + r.h > a.y + a.h + 1e-6 then
			return false
		end
		for _, o in ipairs(obstacles) do
			if BattleLayout.overlap(r, o) then
				return false
			end
		end
		for _, o in ipairs(placed) do
			if BattleLayout.overlap(r, o) then
				return false
			end
		end
		return true
	end
	for _, side in ipairs({ 2, 1 }) do
		local n = clamp(int(side == 2 and nFoe or nMe, 0), 0, BattleLayout.MAX_PILLS)
		local all = BattleLayout.pillRects(side, R, BattleLayout.MAX_PILLS)
		local cap = 0
		for i = 1, BattleLayout.MAX_PILLS do
			if free(all[i]) then
				cap = i
			else
				break
			end
		end
		local shown = math.min(n, cap)
		local rects = {}
		for i = 1, shown do
			rects[i] = all[i]
			placed[#placed + 1] = all[i]
		end
		out[side] = { rects = rects, cap = cap, shown = shown, overflow = (n > cap and cap >= 1) and (n - cap + 1) or 0 }
	end
	return out
end

-- Contenu des `shown` pastilles à afficher pour la liste `pills` (BattleLayout.statusPills) : une pastille par état, ou, en cas de manque de place, les premières puis une
-- pastille « +n » qui regroupe les états restants. Chaque élément : { text, bg, fg, detail, merged }.
function BattleLayout.pillChips(pills, shown, Battle)
	local list = type(pills) == "table" and pills or {}
	local n = #list
	local show = clamp(int(shown, 0), 0, n)
	local chips = {}
	if show >= n then
		for i = 1, n do
			chips[i] = { text = list[i].text, bg = list[i].bg, fg = list[i].fg, detail = BattleLayout.pillDetail(list[i], Battle), merged = false }
		end
	elseif show >= 1 then
		for i = 1, show - 1 do
			chips[i] = { text = list[i].text, bg = list[i].bg, fg = list[i].fg, detail = BattleLayout.pillDetail(list[i], Battle), merged = false }
		end
		local details = {}
		for i = show, n do
			details[#details + 1] = BattleLayout.pillDetail(list[i], Battle)
		end
		chips[show] = { text = "+" .. (n - show + 1), bg = BattleLayout.STATUS_MORE.bg, fg = BattleLayout.STATUS_MORE.fg, detail = table.concat(details, "\n"), merged = true }
	end
	return chips
end

-- Fil des PV de toute l'équipe pour l'écran « Changer » : une ligne par pet (au plus MAX_DOTS) avec indice, PV, charge du spécial, état. Un pet à 0 PV est « ko » (grisé,
-- jamais cliquable) ; le pet au combat est « active » (affiché, non cliquable : on ne change pas pour soi-même) ; les autres sont « ready » (cliquables).
function BattleLayout.swapRows(side)
	local rows = {}
	local units = type(side) == "table" and type(side.units) == "table" and side.units or {}
	local active = type(side) == "table" and isNum(side.active) and math.floor(side.active) or 1
	for i = 1, math.min(#units, BattleLayout.MAX_DOTS) do
		local u = units[i]
		if type(u) == "table" then
			local alive = isNum(u.hp) and u.hp > 0
			local info = BattleLayout.chargePips(u.charge, u.chargeMax)
			local state = (not alive) and "ko" or (i == active and "active" or "ready")
			local pipsText = ""
			for k = 1, info.max do
				pipsText = pipsText .. (info.pips[k] and "●" or "○")
			end
			local tag = state == "ko" and "💀 K.O." or (state == "active" and "▶ Au combat" or "🔁 Changer")
			rows[#rows + 1] = {
				index = i, p = u.p, alive = alive, active = state == "active", state = state, clickable = state == "ready", tag = tag,
				hp = clamp(int(u.hp, 0), 0, 9999999), maxHp = math.max(0, int(u.maxHp, 0)), frac = BattleLayout.hpFraction(u), hpText = BattleLayout.hpText(u),
				level = BattleLayout.levelText(u), charge = info.charge, chargeMax = info.max, chargeReady = info.ready, pipsText = pipsText,
				chargeText = "Charge " .. info.charge .. "/" .. info.max, statuses = BattleLayout.statusPills(u),
			}
		end
	end
	return rows
end

BattleLayout.SWAP_ROW_MIN = 44 -- une ligne de l'écran « Changer » est un bouton : 44 px de haut au moins
BattleLayout.SWAP_ROW_MAX = 64

-- Écran « Changer » : panneau centré (titre, note, lignes, bouton « Retour »). Les lignes passent sur 2 colonnes quand la fenêtre est trop basse pour 44 px chacune.
-- Retourne { panel, title, note, back, cols, rowH, rows = { rect } } ; tout est dans la zone utile, aucune superposition, boutons >= 44 px (testé sur la matrice d'appareils).
function BattleLayout.swapRects(vw, vh, safeIn, n)
	local R = BattleLayout.rects(vw, vh, safeIn)
	local count = clamp(int(n, 3), 1, BattleLayout.MAX_DOTS)
	local a = R.area
	local pw = math.floor(math.min(a.w, 440))
	local pad, gap = 10, 6
	local titleH, noteH, backH = 28, 18, BattleLayout.MIN_TOUCH + 4
	local fixed = pad + titleH + noteH + gap * 2 + backH + pad
	local ph = math.floor(a.h)
	local panel = rect(math.floor(a.x + (a.w - pw) / 2), math.floor(a.y), pw, ph)
	local avail = ph - fixed
	local cols = 1
	local rowsPerCol = count
	local rowH = math.floor((avail - (rowsPerCol - 1) * gap) / rowsPerCol)
	if rowH < BattleLayout.SWAP_ROW_MIN and count > 1 then
		cols = 2
		rowsPerCol = math.ceil(count / 2)
		rowH = math.floor((avail - (rowsPerCol - 1) * gap) / rowsPerCol)
	end
	rowH = clamp(rowH, BattleLayout.SWAP_ROW_MIN, BattleLayout.SWAP_ROW_MAX)
	local out = { panel = panel, cols = cols, rowH = rowH, rows = {} }
	out.title = rect(panel.x + pad, panel.y + pad, pw - 2 * pad, titleH)
	out.note = rect(panel.x + pad, out.title.y + titleH, pw - 2 * pad, noteH)
	local rowsY = out.note.y + noteH + gap
	local colW = math.floor((pw - 2 * pad - (cols - 1) * gap) / cols)
	for i = 1, count do
		local col = (i - 1) // rowsPerCol
		local row = (i - 1) % rowsPerCol
		out.rows[i] = rect(panel.x + pad + col * (colW + gap), rowsY + row * (rowH + gap), colW, rowH)
	end
	out.back = rect(panel.x + pad, panel.y + ph - pad - backH, pw - 2 * pad, backH)
	return out
end

-- Flash du spécial : déclenché UNIQUEMENT quand la charge du MÊME pet passe de « pas pleine » à « pleine » (jamais au changement de pet ni à la 1re vue).
-- prev / cur = { key = identité du pet, full = charge pleine ? } (ou nil). Retourne "flash" ou "set" (mise à jour silencieuse).
function BattleLayout.specialTransition(prev, cur)
	if type(prev) == "table" and type(cur) == "table" and prev.key ~= nil and prev.key == cur.key and prev.full ~= true and cur.full == true then
		return "flash"
	end
	return "set"
end

BattleLayout.FLASH_SECONDS = 0.7
BattleLayout.MAX_FLASH = 1.5 -- aucun flash ne dure plus de 1,5 s, quelle que soit la vitesse choisie

-- Durée réelle du flash : 0,7 s (0,35 s en effets réduits), divisée par la vitesse du combat, jamais au-dessus de MAX_FLASH.
function BattleLayout.flashSeconds(reduced, speed)
	local base = reduced == true and BattleLayout.FLASH_SECONDS / 2 or BattleLayout.FLASH_SECONDS
	return math.min(BattleLayout.MAX_FLASH, BattleLayout.animSeconds(base, speed))
end

-- Image du flash à l'instant a (0..1) : voile blanc qui s'éteint, bouton qui gonfle de 1 à 1,12 puis revient, contour qui s'estompe ; extrémités exactes.
function BattleLayout.specialFlash(a)
	local k = isNum(a) and clamp(a, 0, 1) or 1
	local pulse = math.sin(math.pi * k)
	return { veilTransparency = 1 - 0.75 * (1 - k) * (1 - k), scale = 1 + 0.12 * pulse, strokeAlpha = 1 - k }
end

-- Remplissage du bouton Spécial selon la charge (animation de charge) : fraction 0..1.
function BattleLayout.chargeFill(charge, max)
	local info = BattleLayout.chargePips(charge, max)
	return info.charge / info.max
end

-- Points de dégradé du bouton Spécial (animation de charge) : le fond multiplie sa couleur par `m` (1 = clair) sur la partie chargée et par `dim` sur le reste, avec une
-- coupure nette à la fraction de charge. Retourne { { t, m } } avec t strictement croissant de 0 à 1 (exigence de ColorSequence).
function BattleLayout.chargeStops(frac, dim)
	local f = isNum(frac) and clamp(frac, 0, 1) or 0
	local d = isNum(dim) and clamp(dim, 0, 1) or 0.55
	if f <= 0 then
		return { { t = 0, m = d }, { t = 1, m = d } }
	elseif f >= 1 then
		return { { t = 0, m = 1 }, { t = 1, m = 1 } }
	end
	local cut = math.min(0.999, f)
	return { { t = 0, m = 1 }, { t = cut, m = 1 }, { t = math.min(1, cut + 0.001), m = d }, { t = 1, m = d } }
end

-- Sons : clés de Config.SOUNDS seulement (aucun identifiant inventé). Une clé est jouable si Config.SOUNDS_ENABLED n'est pas faux et si sa définition a un id non vide.
function BattleLayout.soundKey(Config, key)
	if type(Config) ~= "table" or type(key) ~= "string" or Config.SOUNDS_ENABLED == false or type(Config.SOUNDS) ~= "table" then
		return nil
	end
	local def = Config.SOUNDS[key]
	if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
		return nil
	end
	return key
end

-- Son de chaque action d'un tour : attaque = son du type de l'attaquant (Config.ATK_SOUND), spécial = special_hit, changement de pet = click. Soin, garde, K.O., étourdissement :
-- aucun son n'existe dans Config.SOUNDS, donc silence (rien d'inventé). opts = { typeOf = fn(espèce) -> type, speed, attackSounds = false pour laisser les effets de type jouer
-- les attaques }. Retourne { { at = secondes, key, kind } } aux mêmes instants que les animations de BattleScene.cues (un coup ou un soin tous les 0,6 s à 1x).
function BattleLayout.soundPlan(Config, events, opts)
	local o = type(opts) == "table" and opts or {}
	local out = {}
	local step = BattleLayout.animSeconds(0.6, o.speed)
	local k = 0
	for _, ev in ipairs(type(events) == "table" and events or {}) do
		local cue = BattleLayout.cue(ev)
		if cue then
			local at = step * k
			local key, kind
			if cue.anim == "attack" and cue.special == true then
				key, kind = BattleLayout.soundKey(Config, "special_hit"), "special"
			elseif cue.anim == "attack" and ev.t == "hit" and o.attackSounds ~= false then
				local typ = type(o.typeOf) == "function" and o.typeOf(ev.p) or nil
				key, kind = BattleLayout.soundKey(Config, type(Config) == "table" and type(Config.ATK_SOUND) == "table" and Config.ATK_SOUND[typ] or nil), "attack"
			elseif cue.anim == "swap" and ev.forced ~= true then
				key, kind = BattleLayout.soundKey(Config, "click"), "swap"
			end
			if key then
				out[#out + 1] = { at = at, key = key, kind = kind }
			end
			if cue.anim == "attack" or cue.anim == "heal" then
				k = k + 1
			end
		end
	end
	return out
end

-- XP du pet à l'écran de fin : lue UNIQUEMENT dans le message « end » du serveur (`xp` ou `rewards.xp`) ; le client ne la calcule pas (le serveur n'envoie ni l'XP avant
-- le combat ni le détail du barème). Formes acceptées : un nombre (gain par pet de l'équipe) ou une liste { { p = espèce, gain = nombre, total = XP cumulée (facultatif) } }
-- avec PetXp (facultatif) pour détecter la montée de niveau. Retourne au plus 4 lignes ; valeurs invalides ignorées ; aucune ligne si le serveur n'envoie rien.
function BattleLayout.xpLines(msg, Config, PetXp)
	local lines = {}
	if type(msg) ~= "table" then
		return lines
	end
	local src = msg.xp
	if src == nil and type(msg.rewards) == "table" then
		src = msg.rewards.xp
	end
	if isNum(src) then
		if src >= 1 then
			lines[1] = "⭐ +" .. math.floor(math.min(src, 100000)) .. " XP pour chaque pet de l'équipe"
		end
		return lines
	end
	if type(src) ~= "table" then
		return lines
	end
	for _, e in ipairs(src) do
		if #lines >= 4 then
			break
		end
		if type(e) == "table" and isNum(e.gain) and e.gain >= 1 then
			local def = type(Config) == "table" and type(Config.PETS) == "table" and Config.PETS[e.p] or nil
			local who = def and (tostring(def.emoji or "") .. " " .. tostring(def.name or "?")) or "⭐ Pet"
			local line = who .. " : +" .. math.floor(math.min(e.gain, 100000)) .. " XP"
			if isNum(e.total) and type(PetXp) == "table" and type(PetXp.levelOf) == "function" then
				local after = PetXp.levelOf(e.total)
				local before = PetXp.levelOf(math.max(0, e.total - e.gain))
				if isNum(after) and isNum(before) and after > before then
					line = line .. " · ⬆ Niv. " .. before .. " → " .. after
				end
			end
			lines[#lines + 1] = line
		end
	end
	return lines
end

---------------------------------------------------------------- plafond d'instances

-- Coût estimé (instances) de la scène : interface + monde. Les constantes suivent BattleScene (un test compare à la construction réelle).
BattleLayout.COST = {
	gui = 6, -- racine, fond de ciel, dégradé, viewport, filtre d'assombrissement, caméra
	card = 14, -- cadre, coin, contour, bandeau de couleur, icône (texte + image), nom, niveau, barre (4), texte de PV ou contexte
	dot = 2, -- point + coin
	pip = 2,
	button = 4, -- bouton, coin, contour, étiquette de charge
	log = 5,
	swapPanel = 6, -- écran « Changer » (construit à l'ouverture, détruit à la fermeture) : cadre, titre, note, bouton Retour (+ coin, contour)
	swapRow = 4, -- une ligne par pet : bouton, coin, fond et remplissage de la barre de PV
	pill = 2, -- pastille d'état : bouton + coin (3 par camp au plus)
	tip = 1, -- info-bulle d'une pastille : une étiquette
	flash = 5, -- flash et charge du spécial : barre derrière le bouton (cadre, coin, dégradé), échelle, voile
	ground = 2, -- sol, anneau
	pedestal = 2, -- socle de pierre, disque néon
	beam = 1, -- colonne de lumière translucide (néon)
	puppet = 13, -- créature procédurale : corps, tête, yeux, oreilles, queue, ombre, modèle
	pillar = 1,
	popup = 1, -- nombre flottant ou message de type (une étiquette), au plus MAX_POPUPS simultanés
	queue = 11, -- ordre du tour : étiquette + 3 pastilles (cadre, coin, emoji)
	speedBtns = 6, -- vitesse et saut (bouton, coin, contour chacun)
}
BattleLayout.MAX_POPUPS = 6

---------------------------------------------------------------- modèles Blender des pets en combat (mobs, étape 1)
-- Le combat clone la copie légère publiée par le serveur (ReplicatedStorage.PetModels, au plus 40 Parts). Le plan ci-dessus reste calculé pour la créature
-- procédurale (COST.puppet) : un modèle n'est posé que s'il tient dans ce qui RESTE sous le plafond à cet instant, réserve gardée pour ce qui peut encore
-- apparaître (étiquettes flottantes, écran « Changer » complet, info-bulle, flash du spécial) ; sinon, repli procédural.
BattleLayout.MODEL_MAX_INSTANCES = 48 -- instances d'un modèle cloné (Model + 40 Parts + quelques maillages)
BattleLayout.MODEL_RESERVE = BattleLayout.MAX_POPUPS * BattleLayout.COST.popup + BattleLayout.COST.swapPanel + BattleLayout.MAX_DOTS * BattleLayout.COST.swapRow + BattleLayout.COST.tip + BattleLayout.COST.flash
BattleLayout.MODEL_K = 3 / 1.7 -- hauteur de combat = hauteur au monde (Config.petTargetHeight) x MODEL_K : un pet Commun « Normal » mesure 3 studs, comme la créature procédurale
BattleLayout.MODEL_MIN_H = 2.2
BattleLayout.MODEL_MAX_H = 4.5 -- jamais plus large que le socle

-- Vrai si un modèle de `n` instances peut être posé : n valide, n <= MODEL_MAX_INSTANCES et used + n + MODEL_RESERVE <= cap.
function BattleLayout.modelFits(n, used, cap)
	if not (isNum(n) and isNum(used) and isNum(cap)) or n < 1 then
		return false
	end
	return n <= BattleLayout.MODEL_MAX_INSTANCES and used + n + BattleLayout.MODEL_RESERVE <= cap
end

-- Hauteur de combat (studs) du modèle d'un pet : même règle que le monde (rareté, échelle de taille bornée 0,8 à 1,4 comme la créature procédurale),
-- x MODEL_K, bornée [MODEL_MIN_H, MODEL_MAX_H]. `targetHeight` = Config.petTargetHeight (absente : 1,7 à 2,5 selon la rareté sur 10).
function BattleLayout.modelHeight(tier, sizeScale, targetHeight, tierCount)
	local s = isNum(sizeScale) and clamp(sizeScale, 0.8, 1.4) or 1
	local h
	if type(targetHeight) == "function" then
		local ok, v = pcall(targetHeight, tier, s)
		h = (ok and isNum(v) and v > 0) and v or nil
	end
	if h == nil then
		local n = isNum(tierCount) and tierCount > 1 and tierCount or 10
		local t = isNum(tier) and clamp(tier, 1, n) or 1
		h = (1.7 + 0.8 * (t - 1) / (n - 1)) * s
	end
	return clamp(h * BattleLayout.MODEL_K, BattleLayout.MODEL_MIN_H, BattleLayout.MODEL_MAX_H)
end

-- Facteur d'échelle pour passer de la hauteur mesurée `measured` à `target`, ou nil si la mesure est absurde (le combat garde alors le repli).
function BattleLayout.modelScale(measured, target)
	if not (isNum(measured) and isNum(target)) or measured < 0.05 or target <= 0 then
		return nil
	end
	local f = target / measured
	if f < 0.02 or f > 100 then
		return nil
	end
	return f
end

-- Plan de la scène selon l'appareil : { pillars, beams, bob, decor, estimate }. `reduced` (mobile) : moitié du décor, ni faisceaux ni balancement.
-- Le décor (piliers ou touffes) est réduit jusqu'à tenir sous MAX_INSTANCES, avec une marge de 20 instances pour les remplacements de créature.
function BattleLayout.plan(opts)
	local o = type(opts) == "table" and opts or {}
	local reduced = o.reduced == true
	local nMe = clamp(int(o.units1, 3), 1, BattleLayout.MAX_DOTS)
	local nFoe = clamp(int(o.units2, 3), 1, BattleLayout.MAX_DOTS)
	local C = BattleLayout.COST
	local beams = not reduced
	local decor = reduced and 6 or 12
	local function estimate(n)
		local e = C.gui + 2 * C.card + (nMe + nFoe) * C.dot + BattleLayout.CHARGE_MAX * C.pip + 4 * C.button + C.log + C.swapPanel + nMe * C.swapRow + 2 * BattleLayout.MAX_PILLS * C.pill + C.tip + C.flash + C.queue + C.speedBtns + C.ground + 2 * C.pedestal + 2 * C.puppet + n * C.pillar + BattleLayout.MAX_POPUPS * C.popup
		if beams then
			e = e + 2 * C.beam
		end
		return e
	end
	local budget = BattleLayout.MAX_INSTANCES - 20
	while decor > 0 and estimate(decor) > budget do
		decor = decor - 1
	end
	if estimate(decor) > budget then
		beams = false
	end
	return { pillars = decor, beams = beams, bob = not reduced, decor = decor, reduced = reduced, estimate = estimate(decor), cap = BattleLayout.MAX_INSTANCES }
end

-- Positions des éléments de décor (piliers du colisée ou touffes d'herbe) en arc derrière les socles : { { x, z, h } } (studs), déterministe.
function BattleLayout.decorSpots(n)
	local spots = {}
	local count = clamp(int(n, 0), 0, 24)
	for i = 1, count do
		local t = count == 1 and 0.5 or (i - 1) / (count - 1)
		local ang = math.rad(200 + 140 * t) -- demi-cercle derrière
		local R = 30
		spots[i] = { x = math.floor(math.cos(ang) * R * 100 + 0.5) / 100, z = math.floor(math.sin(ang) * R * 100 + 0.5) / 100 - 4, h = 7 + (i % 3) * 1.5 }
	end
	return spots
end

return BattleLayout
