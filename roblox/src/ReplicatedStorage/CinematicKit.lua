-- ModuleScript : ReplicatedStorage/Shared/CinematicKit
-- Caméras de cinématique : LOGIQUE PURE (aucun service Roblox) testée hors de Roblox. Un « plan » est une liste de prises { dur, pos, look, toPos, toLook,
-- fov, toFov, path, ease, shake, slow, text, title, fx, anchor } dans le repère de son ancre ; trajectoires : travelling (linéaire), orbite autour du
-- point visé, plongée (de haut en bas), zoom dolly (la caméra avance et le champ de vision se resserre). Bandes noires, cartons de titre, tremblement,
-- ralenti et bouton Passer sont appliqués par le client (Cinematics.client.lua) à partir de ces valeurs.
-- Garanties : jamais plus de 8 secondes réelles (MAX_SECONDS) ; aucune cinématique si le joueur est en danger (`canPlay`) ; la caméra et le contrôle
-- sont restitués par le client quoi qu'il arrive (fin, passage, erreur, départ). Utilisation : require(CinematicKit).new(Easing, Cinema).
local CinematicKit = {}

CinematicKit.MAX_SECONDS = 8

-- Plans nommés. Les positions sont { x, y, z } dans le repère de l'ancre (arena, base, pad, rival1..3, castle, world, hubfountain, hubportals).
-- `slow = { at, to, scale }` : entre ces progressions de la prise (0..1), le temps s'écoule à `scale` (0.35 = ralenti), ce qui allonge la durée réelle.
CinematicKit.PLANS = {
	hub_survol = { id = "hub_survol", shots = {
		{ anchor = "hubfountain", pos = { 0, 30, 70 }, look = { 0, 3, 0 }, toPos = { 0, 18, 40 }, path = "travel", dur = 2.2, ease = "Quint", title = "🥚 Bienvenue !" },
		{ anchor = "hubportals", pos = { 0, 22, 100 }, look = { 0, 8, -60 }, toPos = { 0, 14, 30 }, toLook = { 0, 8, -80 }, path = "travel", dur = 2.8, ease = "Sine", text = "Choisis un portail : seul, ou avec des amis." },
	} },
	secret = { id = "secret", shots = {
		{ anchor = "pad", pos = { 0, 6, 10 }, look = { 0, 3, 0 }, toPos = { 0, 14, 6 }, path = "dive", dur = 1.4, ease = "Quint", shake = 0.25, title = "✦ ???" },
		{ anchor = "pad", pos = { 0, 12, 12 }, look = { 0, 3, 0 }, path = "orbit", radius = 12, toRadius = 8, angle0 = 0, angle1 = 2.4, height = 8, dur = 3.4, ease = "Sine", shake = 0.5, slow = { at = 0.35, to = 0.6, scale = 0.4 }, fx = "flash" },
		{ anchor = "pad", pos = { 0, 5, 9 }, look = { 0, 4, 0 }, path = "dolly", fov = 70, toFov = 46, toPos = { 0, 4, 3 }, dur = 1.4, ease = "Back", title = "✦ SECRET ✦" },
	} },
	chateau_entree = { id = "chateau_entree", shots = {
		{ anchor = "castle", pos = { -40, 16, 34 }, look = { 0, 6, -8 }, toPos = { 40, 14, 34 }, toLook = { 0, 8, -8 }, path = "travel", dur = 2.6, ease = "Sine", title = "🏰 Le Château" },
		{ anchor = "castle", pos = { 0, 5, 16 }, look = { 0, 7, 0 }, toPos = { 0, 6, 9 }, path = "dolly", fov = 70, toFov = 55, dur = 2.2, ease = "Quint", text = "La herse se lève…", fx = "gate" },
	} },
	-- Montée de niveau de la maison (D.4) : 4,5 s au total (2,7 + 1,8), plan large depuis l'avant de la base vers la maison à l'arrière ; passable (Passer, toucher l'écran).
	base_niveau = { id = "base_niveau", skipOnTap = true, shots = {
		{ anchor = "base", pos = { 0, 24, -62 }, look = { 0, 6, 14 }, toPos = { 0, 20, -50 }, path = "travel", dur = 2.7, ease = "Sine", title = "🏠 Ta base évolue !" },
		{ anchor = "base", pos = { -34, 16, -26 }, look = { 0, 8, 16 }, toPos = { 34, 16, -26 }, path = "travel", dur = 1.8, ease = "Sine" },
	} },
	chateau_victoire = { id = "chateau_victoire", shots = {
		{ anchor = "castle_chest", pos = { 6, 7, 10 }, look = { 0, 3, 0 }, toPos = { 3, 5, 6 }, path = "dolly", fov = 70, toFov = 52, dur = 1.6, ease = "Quint", slow = { at = 0.4, to = 0.9, scale = 0.35 }, shake = 0.3, fx = "sparks" },
		{ anchor = "castle_chest", pos = { 0, 6, 11 }, look = { 0, 3, 0 }, path = "orbit", radius = 11, toRadius = 9, angle0 = 0.6, angle1 = 2.0, height = 6, dur = 2.4, ease = "Sine", title = "🏆 Victoire !" },
	} },
}

-- Plan d'éclosion selon la rareté (1..6) : plus la rareté monte, plus la caméra s'engage (orbite, zoom, secousse, ralenti, pilier de lumière côté VfxKit).
-- Commun et Rare : AUCUNE cinématique (les effets 3D de VfxKit suffisent) ; Épique : plan court ; Légendaire et au-delà : plan complet.
function CinematicKit.hatchPlan(tier, secret)
	tier = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), 6)
	if secret then
		return CinematicKit.PLANS.secret
	elseif tier <= 2 then
		return nil
	elseif tier == 3 then
		return { id = "eclosion_epique", skipOnTap = true, shots = {
			{ anchor = "pad", pos = { 0, 8, 12 }, look = { 0, 3, 0 }, toPos = { 0, 5, 7 }, path = "dolly", fov = 70, toFov = 56, dur = 1.6, ease = "Quint", shake = 0.15 },
		} }
	end
	local big = tier >= 5
	return { id = "eclosion", skipOnTap = true, shots = {
		{ anchor = "pad", pos = { 0, 7, 12 }, look = { 0, 3, 0 }, path = "orbit", radius = 12, toRadius = 8, angle0 = 0, angle1 = big and 2.2 or 1.6, height = 6, dur = big and 2.4 or 1.8, ease = "Sine" },
		{ anchor = "pad", pos = { 0, 5, 8 }, look = { 0, 3.2, 0 }, path = "dolly", fov = 70, toFov = big and 44 or 52, toPos = { 0, 4, 4 }, dur = big and 1.8 or 1.2, ease = "Back", shake = big and 0.6 or 0.4, slow = { at = 0.5, to = 1, scale = 0.35 }, fx = "crack" },
		{ anchor = "pad", pos = { 0, 6, 9 }, look = { 0, 4, 0 }, toPos = { 0, 7, 11 }, path = "travel", fov = big and 52 or 60, toFov = 70, dur = big and 1.6 or 1.2, ease = "Quint", title = nil },
	} }
end

-- Plan court « gardien ou chevalier qui repère le joueur » : AUCUN mouvement de caméra (le joueur garde le contrôle, il est en danger) : un à-coup
-- de champ de vision, un peu de tremblement et un « ❗ » (voir `overlay`). Retourne le descriptif d'effet d'interface.
CinematicKit.ALERT = { seconds = 1.2, fovPunch = 8, shake = 0.35, title = "❗", cooldown = 90, perSession = 3 }

function CinematicKit.new(Easing, Cinema)
	local K = {}

	-- Courbe nommée (style de TweenService).
	function K.curve(style, x)
		x = Easing.clamp01(x)
		if style == "Back" then
			return Easing.outBack(x)
		elseif style == "Elastic" then
			return Easing.outElastic(x)
		elseif style == "Quint" then
			return 1 - (1 - x) ^ 5
		elseif style == "Quad" then
			return Easing.outQuad(x)
		end
		return Easing.inOutSine(x)
	end

	local function lerp(a, b, e)
		return a + (b - a) * e
	end
	local function lerp3(a, b, e)
		return { lerp(a[1], b[1], e), lerp(a[2], b[2], e), lerp(a[3], b[3], e) }
	end

	-- Durée RÉELLE d'une prise (le ralenti l'allonge) : dur x (1 + (1/scale - 1) x largeur de la zone lente).
	function K.realDuration(shot)
		local s = shot.slow
		if not s then
			return shot.dur
		end
		local width = math.max(0, math.min(1, s.to) - math.max(0, s.at))
		return shot.dur * (1 + (1 / math.max(0.05, s.scale) - 1) * width)
	end

	function K.realTotal(def)
		local t = 0
		for _, shot in ipairs(def.shots) do
			t = t + K.realDuration(shot)
		end
		return t
	end

	-- Plan normalisé : durées réduites proportionnellement si la durée RÉELLE dépasse `maxSeconds` (8 par défaut) ; prise invalide (durée <= 0, NaN) = refus.
	-- Retourne (définition prête pour Cinema.sequence, durée réelle) ou (nil, raison).
	function K.build(def, maxSeconds)
		if type(def) ~= "table" or type(def.shots) ~= "table" or #def.shots == 0 then
			return nil, "aucune prise"
		end
		maxSeconds = (type(maxSeconds) == "number" and maxSeconds > 0) and math.min(maxSeconds, CinematicKit.MAX_SECONDS) or CinematicKit.MAX_SECONDS
		for i, shot in ipairs(def.shots) do
			if type(shot.dur) ~= "number" or shot.dur ~= shot.dur or shot.dur <= 0 or type(shot.pos) ~= "table" or type(shot.look) ~= "table" then
				return nil, "prise invalide (" .. i .. ")"
			end
		end
		local real = K.realTotal(def)
		local k = real > maxSeconds and (maxSeconds / real) or 1
		local shots = {}
		for i, shot in ipairs(def.shots) do
			local copy = {}
			for key, v in pairs(shot) do
				copy[key] = v
			end
			copy.dur = shot.dur * k
			shots[i] = copy
		end
		local out = { id = def.id, shots = shots, skipOnTap = def.skipOnTap }
		return out, real * k
	end

	-- Temps virtuel (celui des prises) atteint après `realElapsed` secondes réelles : le ralenti fait avancer le temps plus lentement dans sa zone.
	function K.virtualElapsed(def, realElapsed)
		local virtual, left = 0, math.max(0, realElapsed)
		for _, shot in ipairs(def.shots) do
			local rd = K.realDuration(shot)
			if left >= rd then
				virtual = virtual + shot.dur
				left = left - rd
			else
				local s = shot.slow
				if not s then
					return virtual + left
				end
				local a, b = math.max(0, s.at) * shot.dur, math.min(1, s.to) * shot.dur
				local slowReal = (b - a) / math.max(0.05, s.scale)
				if left <= a then
					return virtual + left
				elseif left <= a + slowReal then
					return virtual + a + (left - a) * math.max(0.05, s.scale)
				end
				return virtual + b + (left - a - slowReal)
			end
		end
		return virtual
	end

	-- Caméra à la progression p d'une prise : (position, point visé, champ de vision) dans le repère de l'ancre.
	function K.cameraAt(shot, p)
		local e = K.curve(shot.ease or "Sine", p)
		local fov = lerp(shot.fov or 70, shot.toFov or shot.fov or 70, e)
		local look = lerp3(shot.look, shot.toLook or shot.look, e)
		local path = shot.path
		if path == "orbit" then
			local r = lerp(shot.radius or 10, shot.toRadius or shot.radius or 10, e)
			local a = lerp(shot.angle0 or 0, shot.angle1 or (shot.angle0 or 0), e)
			return { look[1] + math.sin(a) * r, look[2] + (shot.height or 5), look[3] + math.cos(a) * r }, look, fov
		elseif path == "dive" then
			return lerp3(shot.pos, shot.toPos or shot.pos, e), look, fov -- plongée : de haut en bas (ou l'inverse) en gardant la cible
		elseif path == "dolly" then
			return lerp3(shot.pos, shot.toPos or shot.pos, e), look, fov -- zoom dolly : la caméra avance, le champ de vision se resserre
		end
		return lerp3(shot.pos, shot.toPos or shot.pos, e), look, fov -- travelling
	end

	-- Décalage de caméra dû au tremblement (amplitude shot.shake en studs, décroissante sur la prise, bruit déterministe).
	function K.shakeOffset(shot, p, time)
		local amp = shot.shake
		if not amp or amp <= 0 then
			return { 0, 0, 0 }
		end
		local decay = (1 - Easing.clamp01(p)) ^ 1.5
		local a = amp * decay
		return { math.sin(time * 47.3) * a * 0.5, math.sin(time * 61.1 + 1.7) * a * 0.4, math.cos(time * 39.7) * a * 0.3 }
	end

	-- Le joueur peut-il voir une cinématique maintenant ? ctx = { hp, maxHp, sinceHit (s depuis le dernier coup), chased (poursuivi par un gardien),
	-- inTrapRoom (dans une salle à pièges du château), dead }. Jamais en danger : peu de pv, coup récent, poursuite, salle à pièges, mort.
	function K.canPlay(ctx)
		if type(ctx) ~= "table" or ctx.dead then
			return false
		end
		local maxHp = (type(ctx.maxHp) == "number" and ctx.maxHp > 0) and ctx.maxHp or 100
		local hp = type(ctx.hp) == "number" and ctx.hp == ctx.hp and ctx.hp or maxHp
		if hp / maxHp < 0.5 or (type(ctx.sinceHit) == "number" and ctx.sinceHit < 4) or ctx.chased or ctx.inTrapRoom then
			return false
		end
		return true
	end

	-- Alerte (gardien ou chevalier qui repère le joueur) : pas une cinématique (aucune caméra) ; autorisée même poursuivi, mais pas à moins de 40 % de pv
	-- ni juste après un coup, avec temps de recharge et nombre maximum par session.
	function K.canAlert(ctx, now, lastAt, shown)
		if type(ctx) ~= "table" or ctx.dead then
			return false
		end
		local maxHp = (type(ctx.maxHp) == "number" and ctx.maxHp > 0) and ctx.maxHp or 100
		local hp = type(ctx.hp) == "number" and ctx.hp == ctx.hp and ctx.hp or maxHp
		if hp / maxHp < 0.4 or (type(ctx.sinceHit) == "number" and ctx.sinceHit < 2) then
			return false
		end
		if (shown or 0) >= CinematicKit.ALERT.perSession or (lastAt and now - lastAt < CinematicKit.ALERT.cooldown) then
			return false
		end
		return true
	end

	-- Gestionnaire de lecture : une seule cinématique à la fois (le directeur de Cinema refuse la seconde), passage immédiat, restitution garantie.
	-- host = { takeCamera(), giveCameraBack(), apply(shotIndex, progress, shot) } ; toute erreur de host.apply restitue la caméra et abandonne.
	-- Retourne un objet { start(def, now), update(now), skip(now), abort(), isActive(), restored } pour le client et les tests.
	function K.runner(host)
		local R = { restored = 0 }
		local director = Cinema.director()
		local current = nil
		local function restore()
			if current then
				current = nil
			end
			R.restored = R.restored + 1
			pcall(host.giveCameraBack)
		end
		-- Retourne "playing", "queued" ou "refused" (ou "invalid").
		function R.start(def, now, chain)
			local built, real = K.build(def)
			if not built then
				return "invalid"
			end
			local seq = Cinema.sequence(built)
			if not seq then
				return "invalid"
			end
			local result = director.request(def.id, seq, now, chain)
			if result == "playing" then
				current = { def = built, startedAt = now, seq = seq, real = real }
				local ok = pcall(host.takeCamera)
				if not ok then
					director.abort()
					restore()
					return "invalid"
				end
			end
			return result
		end
		function R.update(now)
			if not current then
				return nil
			end
			local virtual = K.virtualElapsed(current.def, now - current.startedAt)
			local id, ev = director.update(current.startedAt + virtual)
			if not id or (ev and ev.finished) then
				restore()
				return "finished"
			end
			if ev and ev.shot then
				local ok = pcall(host.apply, ev.shot, ev.progress, current.def.shots[ev.shot])
				if not ok then
					director.abort()
					restore()
					return "error"
				end
			end
			return "playing"
		end
		function R.skip(now)
			if director.skip(now) then
				restore()
				return true
			end
			return false
		end
		function R.abort()
			director.abort()
			if current then
				restore()
			end
		end
		function R.isActive()
			return director.isActive()
		end
		return R
	end

	return K
end

return CinematicKit
