-- ModuleScript : ReplicatedStorage/EggAura (lot graphismes 4 : halos d'œufs et bulles de protection). Logique PURE, sans service Roblox.
-- Un halo lumineux par rareté (couleur = Config.TIERS[tier].color, pulsation lente, plus visible quand la rareté monte) sur les œufs du tapis, portés et posés,
-- et une bulle transparente sur les œufs protégés (bouclier d'une base, nid surveillé par un gardien). AUCUNE PointLight : une Part néon (halo) ou champ de
-- force (bulle) par œuf retenu, au plus `maxHalos` / `maxBubbles` (plafonds réduits sur mobile), les plus proches de la caméra à moins de `range` studs.
-- Le script client EggAura.client.lua ne fait qu'appliquer : sélection, styles et gestion du réservoir d'objets (sans fuite) sont ici et testés.
-- Style : compatible lupa (affectations composées et saut de boucle évités), aucune comparaison sans garde de type.
local EggAura = {}

EggAura.DEFAULTS = {
	enabled = true,
	range = 110, -- studs : au-delà, ni halo ni bulle
	maxHalos = 24,
	maxHalosMobile = 10,
	maxBubbles = 12,
	maxBubblesMobile = 6,
	interval = 0.25, -- s entre deux sélections (mobile : intervalMobile)
	intervalMobile = 0.5,
	frameStep = 1 / 30, -- s entre deux mises à jour de pulsation (mobile : frameStepMobile)
	frameStepMobile = 1 / 10,
	halo = {
		scaleMin = 1.22, -- taille du halo / taille de l'œuf, rareté 1 -> rareté max
		scaleMax = 1.7,
		transparencyMax = 0.9, -- rareté 1 : à peine visible
		transparencyMin = 0.6, -- rareté max : bien visible
		amplitudeMin = 0.03, -- amplitude de pulsation (transparence)
		amplitudeMax = 0.16,
		periodMax = 3.6, -- s : pulsation lente (rareté 1) -> un peu plus vive (rareté max), jamais sous 2 s
		periodMin = 2.4,
		material = "Neon",
	},
	bubble = {
		scale = 2.0, -- diamètre de la bulle / plus grande dimension de l'œuf
		transparency = 0.2,
		material = "ForceField", -- champ de force animé : bien visible, translucide
		shieldColor = { 140, 215, 255 }, -- bouclier d'une base
		guardColor = { 255, 214, 120 }, -- nid surveillé par un gardien
	},
}

local function finite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function lerp(a, b, k)
	return a + (b - a) * k
end

-- Config fusionné (Config.EGG_AURA par-dessus DEFAULTS, sous-tables comprises).
function EggAura.cfg(Config)
	local out = {}
	for k, v in pairs(EggAura.DEFAULTS) do
		if type(v) == "table" then
			local sub = {}
			for k2, v2 in pairs(v) do
				sub[k2] = v2
			end
			out[k] = sub
		else
			out[k] = v
		end
	end
	local src = type(Config) == "table" and Config.EGG_AURA or nil
	if type(src) == "table" then
		for k, v in pairs(src) do
			if type(v) == "table" and type(out[k]) == "table" then
				for k2, v2 in pairs(v) do
					out[k][k2] = v2
				end
			else
				out[k] = v
			end
		end
	end
	return out
end

local function tierCount(Config)
	return (type(Config) == "table" and type(Config.TIERS) == "table" and #Config.TIERS > 0) and #Config.TIERS or 10
end

-- Position de la rareté entre 0 (rareté 1) et 1 (rareté max).
function EggAura.rank(Config, tier)
	local n = tierCount(Config)
	if not finite(tier) or n <= 1 then
		return 0
	end
	local t = math.min(n, math.max(1, math.floor(tier)))
	return (t - 1) / (n - 1)
end

-- Style du halo d'un œuf de rareté `tier` : { color, scale, transparency, amplitude, period, material }.
function EggAura.halo(Config, tier)
	local c = EggAura.cfg(Config)
	local h = c.halo
	local k = EggAura.rank(Config, tier)
	local n = tierCount(Config)
	local t = finite(tier) and math.min(n, math.max(1, math.floor(tier))) or 1
	local def = type(Config) == "table" and type(Config.TIERS) == "table" and Config.TIERS[t] or nil
	return {
		tier = t,
		color = def and def.color or nil,
		scale = lerp(h.scaleMin, h.scaleMax, k),
		transparency = lerp(h.transparencyMax, h.transparencyMin, k),
		amplitude = lerp(h.amplitudeMin, h.amplitudeMax, k),
		period = math.max(2, lerp(h.periodMax, h.periodMin, k)),
		material = h.material,
	}
end

-- Transparence du halo à l'instant `t` (s) : base + amplitude x (0,5 + 0,5 sin), bornée à [0, 1]. `phase` désynchronise les œufs.
function EggAura.alpha(style, t, phase)
	if type(style) ~= "table" or not finite(t) then
		return 1
	end
	local ph = finite(phase) and phase or 0
	local v = style.transparency + style.amplitude * (0.5 + 0.5 * math.sin(2 * math.pi * t / style.period + ph))
	return math.min(1, math.max(0, v))
end

-- Style de la bulle : kind = "shield" (bouclier de base) ou "guard" (nid surveillé). { color = {r, g, b}, scale, transparency, material }.
function EggAura.bubble(Config, kind)
	local b = EggAura.cfg(Config).bubble
	return { color = kind == "guard" and b.guardColor or b.shieldColor, scale = b.scale, transparency = b.transparency, material = b.material, kind = kind == "guard" and "guard" or "shield" }
end

-- Diamètre (studs) du halo ou de la bulle d'un œuf : plus grande dimension (Part racine, ou hauteur du modèle de la rareté via Config.eggHeight) x échelle.
function EggAura.diameter(Config, tier, sizeMax, kind)
	local base = finite(sizeMax) and sizeMax > 0 and sizeMax or 3.2
	if type(Config) == "table" and type(Config.eggHeight) == "function" then
		local ok, h = pcall(Config.eggHeight, tier)
		if ok and finite(h) and h > base then
			base = h
		end
	end
	if kind == "bubble" then
		return base * EggAura.cfg(Config).bubble.scale
	end
	return base * EggAura.halo(Config, tier).scale
end

-- Plafonds et cadences selon l'appareil.
function EggAura.caps(Config, mobile)
	local c = EggAura.cfg(Config)
	if mobile then
		return { halos = c.maxHalosMobile, bubbles = c.maxBubblesMobile, interval = c.intervalMobile, frameStep = c.frameStepMobile, range = c.range }
	end
	return { halos = c.maxHalos, bubbles = c.maxBubbles, interval = c.interval, frameStep = c.frameStep, range = c.range }
end

-- Sélection : items = { { key, x, y, z, tier, protect = nil | "shield" | "guard" } }, cam = { x, y, z }.
-- Retourne { halos = { item... }, bubbles = { item... } } : les plus proches d'abord, à moins de caps.range, au plus caps.halos / caps.bubbles.
function EggAura.select(items, cam, caps)
	local out = { halos = {}, bubbles = {} }
	if type(items) ~= "table" or type(cam) ~= "table" or type(caps) ~= "table" then
		return out
	end
	local cx, cy, cz = cam.x, cam.y, cam.z
	if not (finite(cx) and finite(cy) and finite(cz)) then
		return out
	end
	local range = finite(caps.range) and caps.range or 0
	local near = {}
	for _, it in ipairs(items) do
		if type(it) == "table" and finite(it.x) and finite(it.y) and finite(it.z) and finite(it.tier) then
			local dx, dy, dz = it.x - cx, it.y - cy, it.z - cz
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 <= range * range then
				near[#near + 1] = { it = it, d2 = d2 }
			end
		end
	end
	table.sort(near, function(a, b)
		if a.d2 ~= b.d2 then
			return a.d2 < b.d2
		end
		return tostring(a.it.key) < tostring(b.it.key)
	end)
	local maxH = finite(caps.halos) and caps.halos or 0
	local maxB = finite(caps.bubbles) and caps.bubbles or 0
	for _, e in ipairs(near) do
		if #out.halos < maxH then
			out.halos[#out.halos + 1] = e.it
		end
		if (e.it.protect == "shield" or e.it.protect == "guard") and #out.bubbles < maxB then
			out.bubbles[#out.bubbles + 1] = e.it
		end
	end
	return out
end

-- Gestionnaire d'objets (réservoir) : factory = { make(kind) -> obj, hide(obj), destroy(obj) }. kind = "halo" | "bubble".
-- sync(sel) attache un objet à chaque œuf retenu (réutilisé si l'œuf l'avait déjà), rend au réservoir ceux des œufs disparus, et détruit l'excédent du
-- réservoir au-delà de `poolMax` (pas de fuite : objets vivants <= plafonds, réservoir <= poolMax). Retourne { [kind] = { [key] = obj } }.
function EggAura.newManager(factory, poolMax)
	local M = { live = { halo = {}, bubble = {} }, pool = { halo = {}, bubble = {} }, created = 0, destroyed = 0, poolMax = finite(poolMax) and poolMax or 8 }
	local function take(kind)
		local p = M.pool[kind]
		local n = #p
		if n > 0 then
			local obj = p[n]
			p[n] = nil
			return obj
		end
		M.created = M.created + 1
		return factory.make(kind)
	end
	local function give(kind, obj)
		local p = M.pool[kind]
		if #p < M.poolMax then
			factory.hide(obj)
			p[#p + 1] = obj
		else
			M.destroyed = M.destroyed + 1
			factory.destroy(obj)
		end
	end
	local function syncKind(kind, list)
		local want = {}
		for _, it in ipairs(list or {}) do
			want[it.key] = it
		end
		local live = M.live[kind]
		for key, obj in pairs(live) do
			if not want[key] then
				live[key] = nil
				give(kind, obj)
			end
		end
		for key in pairs(want) do
			if not live[key] then
				live[key] = take(kind)
			end
		end
	end
	function M.sync(sel)
		syncKind("halo", type(sel) == "table" and sel.halos or nil)
		syncKind("bubble", type(sel) == "table" and sel.bubbles or nil)
		return M.live
	end
	function M.count(kind)
		local n = 0
		for _ in pairs(M.live[kind]) do
			n = n + 1
		end
		return n
	end
	-- Tout rendre (désactivation) : objets vivants détruits, réservoir vidé.
	function M.clear()
		for _, kind in ipairs({ "halo", "bubble" }) do
			for key, obj in pairs(M.live[kind]) do
				M.live[kind][key] = nil
				M.destroyed = M.destroyed + 1
				factory.destroy(obj)
			end
			for i = #M.pool[kind], 1, -1 do
				M.destroyed = M.destroyed + 1
				factory.destroy(M.pool[kind][i])
				M.pool[kind][i] = nil
			end
		end
	end
	return M
end

return EggAura
