-- ModuleScript : ReplicatedStorage/Shared/Placement
-- Pose PLANIFIÉE du décor Blender (arbres, rochers, buissons, cabanes, barrières, ponts) : logique PURE, déterministe, testée hors de Roblox.
-- Principes : une grille de cellules parcourue dans un ordre fixe (aucun tirage libre), chaque objet a une empreinte circulaire ; il n'est posé que si son
-- empreinte ne touche NI l'eau (rivières, douves), NI un chemin, NI l'arène, un domaine, une base ou un secret, et reste à distance minimale des objets
-- déjà posés. Cabanes tournées face au centre de leur domaine, barrières alignées sur une même ligne, ponts centrés sur leur rivière et plus longs
-- qu'elle (les deux rives sont reliées). Utilisation : require(Placement).new(Config).plan().
local Placement = {}

local KIND_RADIUS = { tree = 3.5, fir = 3.5, rock = 2.5, bush = 2, hut = 7, fence = 5.5 }
Placement.KIND_RADIUS = KIND_RADIUS
Placement.MIN_GAP = 2 -- espace libre minimal entre deux empreintes (studs)
Placement.CELL = 30

-- Angle (degrés) de rotation autour de Y pour qu'un modèle dont l'avant est -Z regarde la direction (dx, dz). Portable (pas de math.atan2).
function Placement.facing(dx, dz)
	local fx, fz = -dx, -dz -- on veut sin(theta) = -dx/len et cos(theta) = -dz/len
	if fx == 0 and fz == 0 then
		return 0
	end
	local theta
	if fz == 0 then
		theta = fx > 0 and math.pi / 2 or -math.pi / 2
	else
		theta = math.atan(fx / fz)
		if fz < 0 then
			theta = theta + math.pi
		end
	end
	return math.deg(theta) % 360
end

local function distToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / len2)) or 0
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end
Placement.distToSegment = distToSegment

function Placement.new(Config)
	local P = {}
	local M = Config.Map
	local geo = M.geo
	local half = M.groundSize / 2

	-- Segments de chemin (mêmes extrémités que Scenery.paths) : de la moitié du x du domaine, devant l'arène, jusqu'au domaine.
	function P.pathSegments()
		local out = {}
		for _, poly in ipairs(M.paths) do
			for k = 1, #poly - 1 do
				out[#out + 1] = { poly[k][1], poly[k][2], poly[k + 1][1], poly[k + 1][2] }
			end
		end
		for i = 1, #Config.RIVALS do -- les rampes sont des chemins larges
			local r = Config.rampOf(i)
			out[#out + 1] = { r.top[1], r.top[2], r.bottom[1], r.bottom[2] }
		end
		return out
	end

	-- Altitude du sol en (x, z) : la hauteur du plateau d'un domaine si le point est sur ce plateau, sinon 0.
	function P.groundY(x, z)
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			if math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) < M.plateauRadius - 1 then
				return Config.rivalHeight(i)
			end
		end
		return 0
	end

	-- Pourquoi une empreinte (x, z, r) est interdite : "eau", "chemin", "arène", "domaine", "base", "secret", "bord" ou nil si libre.
	-- opts.allowDomain : l'empreinte peut se trouver dans un domaine (cabane et barrières d'un domaine).
	function P.blocked(x, z, r, opts)
		local margin = 1.5
		if math.abs(x) > half - 50 or math.abs(z) > half - 50 then
			return "bord"
		end
		for _, rv in ipairs(geo.rivers) do
			local c = rv.axis == "z" and z or x
			if math.abs(c - rv.at) < rv.half + r + margin then
				return "eau"
			end
		end
		for _, lk in ipairs(geo.lakes or {}) do
			if math.sqrt((x - lk.x) ^ 2 + (z - lk.z) ^ 2) < lk.r + 5 + r + margin then
				return "eau"
			end
		end
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
			if d < M.plateauRadius + r + margin and (opts and opts.allowDomain) then
				-- sur le plateau : on ne pose rien dans la douve
				if math.abs(d - M.moat.radius) < M.moat.width / 2 + r + margin then
					return "eau"
				end
			elseif d < M.plateauRadius + r + margin then
				return "domaine"
			end
		end
		if math.sqrt(x * x + z * z) < geo.arenaRadius + r + margin then
			return "arène"
		end
		for _, seg in ipairs(P.pathSegments()) do
			if distToSegment(x, z, seg[1], seg[2], seg[3], seg[4]) < geo.pathHalf + r + margin then
				return "chemin"
			end
		end
		local ring = math.abs(math.sqrt(x * x + z * z) - (M.plotRadius - 30))
		if ring < geo.pathHalf + r + margin then
			return "chemin"
		end
		if math.abs(math.sqrt(x * x + z * z) - M.plotRadius) < geo.baseBand + r then
			return "base"
		end
		for _, sct in ipairs(Config.SECRETS) do
			if math.sqrt((x - sct.x) ^ 2 + (z - sct.z) ^ 2) < 40 + r then
				return "secret"
			end
		end
		return nil
	end

	-- Plan complet : { items = { {kind, x, z, rot, r} }, bridges = { {x, z, rot, length, river} } }. Déterministe.
	function P.plan()
		local items = {}
		local function fits(kind, x, z, opts)
			local r = KIND_RADIUS[kind]
			if P.blocked(x, z, r, opts) then
				return false
			end
			for _, it in ipairs(items) do
				if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + Placement.MIN_GAP then
					return false
				end
			end
			return true
		end
		local function add(kind, x, z, rot)
			items[#items + 1] = { kind = kind, x = x, z = z, rot = rot, r = KIND_RADIUS[kind], y = P.groundY(x, z) }
		end
		local plan = Config.Assets.propsPlan
		-- 1. par domaine : une cabane face au centre du domaine et une ligne de barrières alignée (jamais dans l'eau)
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			for _, off in ipairs({ { -28, 12 }, { 28, 12 }, { -28, -12 }, { 28, -12 } }) do
				if (plan.hut or 0) > 0 and fits("hut", cx + off[1], cz + off[2], { allowDomain = true }) then
					add("hut", cx + off[1], cz + off[2], Placement.facing(cx - (cx + off[1]), cz - (cz + off[2])))
					break
				end
			end
			local perDomain = math.ceil((plan.fence or 0) / #Config.RIVALS)
			for k = 0, perDomain - 1 do
				local fx, fz = cx - 20.25 + k * 13.5, cz - 34 -- côté nord (le côté sud porte le chemin d'arrivée)
				if fits("fence", fx, fz, { allowDomain = true }) then
					add("fence", fx, fz, 0) -- alignées sur l'axe X, même rotation : jamais de barrières qui se croisent
				end
			end
		end
		-- 2. décor libre : grille de cellules parcourue dans un ordre fixe (mélange déterministe), un genre par cellule selon les quantités du plan
		local kinds = {}
		local remaining = { tree = plan.tree or 0, fir = plan.fir or 0, rock = plan.rock or 0, bush = plan.bush or 0 }
		local order = { "tree", "rock", "fir", "bush" }
		local left = remaining.tree + remaining.fir + remaining.rock + remaining.bush
		local idx = 0
		while left > 0 do
			idx = idx % #order + 1
			local k = order[idx]
			if remaining[k] > 0 then
				remaining[k] = remaining[k] - 1
				left = left - 1
				kinds[#kinds + 1] = k
			end
		end
		local cells = {}
		local lo, hi = -half + 70, half - 70
		local cell = Placement.CELL
		for gx = lo, hi, cell do
			for gz = lo, hi, cell do
				cells[#cells + 1] = { gx + cell / 2, gz + cell / 2 }
			end
		end
		local seed = 4093 -- Park–Miller : mélange déterministe des cellules
		local function rnd()
			seed = seed * 16807 % 2147483647
			return seed / 2147483647
		end
		for i = #cells, 2, -1 do
			local j = 1 + math.floor(rnd() * i)
			cells[i], cells[j] = cells[j], cells[i]
		end
		local ki = 1
		for _, c in ipairs(cells) do
			if ki > #kinds then
				break
			end
			local kind = kinds[ki]
			local x, z = c[1] + (rnd() - 0.5) * 12, c[2] + (rnd() - 0.5) * 12
			if fits(kind, x, z) then
				add(kind, x, z, rnd() * 360)
				ki = ki + 1
			end
		end
		-- 3. ponts : centrés sur la rivière, plus longs qu'elle (les deux rives sont reliées)
		local bridges = {}
		for _, rv in ipairs(geo.rivers) do
			local length = rv.half * 2 + 2 * geo.bridgeBank
			for _, along in ipairs(rv.bridgesAt) do
				if rv.axis == "z" then
					bridges[#bridges + 1] = { x = along, z = rv.at, rot = 90, length = length, river = rv }
				else
					bridges[#bridges + 1] = { x = rv.at, z = along, rot = 0, length = length, river = rv }
				end
			end
		end
		return { items = items, bridges = bridges }
	end

	-- Décor fin (fleurs, touffes, pierres, lanternes) : mêmes règles (rien dans l'eau ni sur un chemin), espacement plus serré, après le plan principal.
	-- Retourne { {kind, x, z, rot, r} } ; kinds : flower_a/b/c, tuft, stone_flat, stone_round, lantern. Les lanternes bordent les chemins (à 5 studs).
	local DECO_RADIUS = { flower_a = 1, flower_b = 1, flower_c = 1, tuft = 1, stone_flat = 1.5, stone_round = 1.5, lantern = 1 }
	Placement.DECO_RADIUS = DECO_RADIUS
	function P.decor(planItems, counts)
		counts = counts or { flowers = 36, tufts = 24, stones = 18, lanterns = 12 }
		local out = {}
		local function fits(kind, x, z)
			local r = DECO_RADIUS[kind]
			if P.blocked(x, z, r, { allowDomain = true }) then
				return false
			end
			for _, it in ipairs(planItems or {}) do
				if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + 1 then
					return false
				end
			end
			for _, it in ipairs(out) do
				if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + 0.5 then
					return false
				end
			end
			return true
		end
		local seed = 7919
		local function rnd()
			seed = seed * 16807 % 2147483647
			return seed / 2147483647
		end
		-- lanternes le long des chemins (un côté, tous les ~28 studs)
		local placedLanterns = 0
		for _, seg in ipairs(P.pathSegments()) do
			local dx, dz = seg[3] - seg[1], seg[4] - seg[2]
			local len = math.sqrt(dx * dx + dz * dz)
			local nx, nz = -dz / len, dx / len
			local steps = math.max(1, math.floor(len / 28))
			for k = 1, steps do
				if placedLanterns >= counts.lanterns then
					break
				end
				local t = (k - 0.5) / steps
				local x, z = seg[1] + dx * t + nx * (geo.pathHalf + 3.5), seg[2] + dz * t + nz * (geo.pathHalf + 3.5)
				if fits("lantern", x, z) then
					out[#out + 1] = { kind = "lantern", x = x, z = z, rot = 0, r = DECO_RADIUS.lantern, y = P.groundY(x, z) }
					placedLanterns = placedLanterns + 1
				end
			end
		end
		-- fleurs, touffes, pierres : cellules de 24 studs dans un ordre mélangé déterministe ; les fleurs se regroupent autour des domaines et des chemins
		local kinds = {}
		for i = 1, counts.flowers do
			kinds[#kinds + 1] = ({ "flower_a", "flower_b", "flower_c" })[i % 3 + 1]
		end
		for _ = 1, counts.tufts do
			kinds[#kinds + 1] = "tuft"
		end
		for i = 1, counts.stones do
			kinds[#kinds + 1] = i % 2 == 0 and "stone_flat" or "stone_round"
		end
		local cells = {}
		local cell, lo, hi = 24, -half + 60, half - 60
		for gx = lo, hi, cell do
			for gz = lo, hi, cell do
				cells[#cells + 1] = { gx + cell / 2, gz + cell / 2 }
			end
		end
		for i = #cells, 2, -1 do
			local j = 1 + math.floor(rnd() * i)
			cells[i], cells[j] = cells[j], cells[i]
		end
		local ki = 1
		for _, c in ipairs(cells) do
			if ki > #kinds then
				break
			end
			local x, z = c[1] + (rnd() - 0.5) * 14, c[2] + (rnd() - 0.5) * 14
			if fits(kinds[ki], x, z) then
				out[#out + 1] = { kind = kinds[ki], x = x, z = z, rot = rnd() * 360, r = DECO_RADIUS[kinds[ki]], y = P.groundY(x, z) }
				ki = ki + 1
			end
		end
		return out
	end

	return P
end

return Placement
