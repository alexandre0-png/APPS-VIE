-- ModuleScript : ReplicatedStorage/Shared/BattleLayout   (refonte de la présentation du combat, vue face à face)
-- Module PUR (aucune instance Roblox, aucun require) : calcule la disposition de l'écran de combat à partir de la taille de la fenêtre et de la zone sûre :
--   * rectangles en pixels (et en échelle) de la carte de l'adversaire (haut à droite), de la carte du joueur (bas à gauche), du bandeau de journal (bas),
--     des 4 boutons d'action (bas à droite : Attaque, Spécial, Changer, Fuir), tous >= 44 px, jamais en dehors de la zone sûre, jamais superposés ;
--   * composition interne des cartes (nom, niveau, barre de PV, texte de PV, points d'état de l'équipe, pastilles de charge du spécial) ;
--   * scène 3D : positions des deux socles lumineux, caméra fixe en léger angle cadrée sur la zone libre entre les cartes, sable ou herbe selon le lieu ;
--   * textes et couleurs (PV « 260/260 », points d'état, charge du spécial 0..5, couleur de barre) et signaux d'animation tirés des événements du moteur ;
--   * plafond d'instances : estimation du coût de la scène, décor réduit pour rester sous MAX_INSTANCES (mobile : moins d'effets).
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
	}
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
	tray = 1 + 3 * 3, -- plateau de réserve : cadre + 3 boutons (bouton, coin, contour)
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
		local e = C.gui + 2 * C.card + (nMe + nFoe) * C.dot + BattleLayout.CHARGE_MAX * C.pip + 4 * C.button + C.log + C.tray + C.queue + C.speedBtns + C.ground + 2 * C.pedestal + 2 * C.puppet + n * C.pillar + BattleLayout.MAX_POPUPS * C.popup
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
