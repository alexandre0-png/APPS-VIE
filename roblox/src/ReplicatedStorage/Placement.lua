-- ModuleScript : ReplicatedStorage/Shared/Placement
-- Pose PLANIFIÉE du décor Blender (arbres, rochers, buissons, cabanes, barrières, ponts) : logique PURE, déterministe, testée hors de Roblox.
-- Principes : une grille de cellules parcourue dans un ordre fixe (aucun tirage libre), chaque objet a une empreinte circulaire ; il n'est posé que si son
-- empreinte ne touche NI l'eau (lacs, rivières, fontaine, douve), NI un chemin, NI la place, l'arène, un territoire, une base, un secret ou une plume
-- (règles de MapGeo.blocked), et reste à distance minimale des objets déjà posés. Cabanes tournées face au centre de leur territoire, barrières
-- alignées sur une même ligne, ponts de bois centrés sur leur cours d'eau. Forêts par rectangles et bosquets (REFONTE lot 2, carte 700 x 500).
-- Utilisation : require(Placement).new(Config).plan() (MapGeo chargé à côté ; les tests le passent : Placement.new(Config, MapGeo)).
local Placement = {}

-- Pause coopérative facultative (Builder la règle sur task.wait) : les calculs de pose cèdent la main tous les 25 essais (jamais de gel du serveur ;
-- les tests purs la laissent à nil).
Placement.yield = nil
local pauseCount = 0
local function pause()
	pauseCount = pauseCount + 1
	if Placement.yield and pauseCount % 25 == 0 then
		Placement.yield()
	end
end

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

-- Angle Y (degrés, convention Roblox : CFrame.Angles(0, a, 0) envoie +X vers (cos a, -sin a)) d'un déplacement (dx, dz). Pas de math.atan2.
function Placement.yawOfDir(dx, dz)
	local ax, az = dx, -dz -- on veut cos a = dx/len, sin a = -dz/len
	if ax == 0 and az == 0 then
		return 0
	end
	local a
	if ax == 0 then
		a = az > 0 and math.pi / 2 or -math.pi / 2
	else
		a = math.atan(az / ax)
		if ax < 0 then
			a = a + math.pi
		end
	end
	return math.deg(a) % 360
end

-- REFONTE (lot 2) : le module MapGeo (géométrie de la carte 700 x 500) est injecté par l'appelant ou chargé à côté de ce module.
local function loadGeo(MapGeo)
	if MapGeo then
		return MapGeo
	end
	if Placement.MapGeo then
		return Placement.MapGeo
	end
	local ok, mod = pcall(function()
		return require(script.Parent:WaitForChild("MapGeo"))
	end)
	if ok then
		Placement.MapGeo = mod
		return mod
	end
	error("Placement : module MapGeo introuvable (passe-le à Placement.new(Config, MapGeo))")
end

-- Variante d'arbre selon la zone : tree_sakura près des lacs et de la place, tree_pine au nord (derrière la rivière), autour des territoires et sur le
-- plateau du château, sinon prairie (chênes, bouleau, arbre rond en alternance ; tree_oak_b porte des pommes). `kind` = "tree" ou "fir" (les sapins
-- restent des pins). `k` = rang (déterministe).
function Placement.treeVariant(Config, kind, x, z, k, MapGeo)
	if kind == "fir" then
		return "tree_pine"
	end
	local M2 = Config.Map2
	for _, lk in ipairs(M2.lakes) do
		if math.sqrt((x - lk.x) ^ 2 + (z - lk.z) ^ 2) < lk.r + 40 then
			return "tree_sakura"
		end
	end
	if math.sqrt((x - M2.plaza.x) ^ 2 + (z - M2.plaza.z) ^ 2) < M2.plaza.r + 50 then
		return "tree_sakura"
	end
	if z < -180 then
		return "tree_pine"
	end
	for _, key in ipairs(Config.TERR_ORDER) do
		local t = Config.TERR[key]
		if math.sqrt((x - t.x) ^ 2 + (z - t.z) ^ 2) < t.r + 25 then
			return "tree_pine"
		end
	end
	return ({ "tree_oak_a", "tree_oak_b", "tree_birch", "tree_round" })[(k or 0) % 4 + 1]
end

-- Modèles d'arbre possibles dans la zone de (x, z) : même découpage que treeVariant, mais en liste (lot graphismes : Graphics.assignStyles choisit dans la liste, avec
-- une classe de taille, de sorte que deux arbres voisins ne soient jamais identiques). Les sapins restent des pins ; près des lacs et de la place : sakura et bouleau.
function Placement.treePool(Config, kind, x, z)
	if kind == "fir" then
		return { "tree_pine" }
	end
	local M2 = Config.Map2
	for _, lk in ipairs(M2.lakes) do
		if math.sqrt((x - lk.x) ^ 2 + (z - lk.z) ^ 2) < lk.r + 40 then
			return { "tree_sakura", "tree_birch" }
		end
	end
	if math.sqrt((x - M2.plaza.x) ^ 2 + (z - M2.plaza.z) ^ 2) < M2.plaza.r + 50 then
		return { "tree_sakura", "tree_birch" }
	end
	if z < -180 then
		return { "tree_pine" }
	end
	for _, key in ipairs(Config.TERR_ORDER) do
		local t = Config.TERR[key]
		if math.sqrt((x - t.x) ^ 2 + (z - t.z) ^ 2) < t.r + 25 then
			return { "tree_pine" }
		end
	end
	return { "tree_oak_a", "tree_oak_b", "tree_birch", "tree_round" }
end

-- Échelle aléatoire déterministe 1 ± jitter d'après la position (jamais de tirage libre).
function Placement.jitter(x, z, jitter)
	local h = math.abs(math.sin(x * 12.9898 + z * 78.233) * 43758.5453)
	return 1 + ((h - math.floor(h)) * 2 - 1) * jitter
end

-- Chemin sinueux : la polyligne est rééchantillonnée tous les `tile` studs et décalée latéralement d'une sinusoïde (amplitude `wind`, nulle aux
-- extrémités et aux sommets). Retourne { tiles = { {kind, x, z, rot} }, borders = { {x, z, rot} } } : tuiles droites (le long de X, tournées vers la
-- direction), tuile de virage quand la direction tourne de 50° à 130° (rotation par pas de 90°), bordures de pierres de part et d'autre.
function Placement.pathTiles(poly, tile, wind)
	local pts, cum = {}, { 0 }
	local verts = {}
	local total = 0
	for k = 1, #poly - 1 do
		local ax, az, bx, bz = poly[k][1], poly[k][2], poly[k + 1][1], poly[k + 1][2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		verts[#verts + 1] = total
		local n = math.max(1, math.floor(len / tile + 0.5))
		for j = 0, n - 1 do
			local t = j / n
			local dx, dz = (bx - ax) / len, (bz - az) / len
			pts[#pts + 1] = { x = ax + (bx - ax) * t, z = az + (bz - az) * t, nx = -dz, nz = dx, d = total + len * t }
		end
		total = total + len
	end
	local last = poly[#poly]
	local pdx, pdz = last[1] - poly[#poly - 1][1], last[2] - poly[#poly - 1][2]
	local pl = math.sqrt(pdx * pdx + pdz * pdz)
	pts[#pts + 1] = { x = last[1], z = last[2], nx = -pdz / pl, nz = pdx / pl, d = total }
	verts[#verts + 1] = total
	for _, p in ipairs(pts) do
		local near = total
		for _, v in ipairs(verts) do
			near = math.min(near, math.abs(p.d - v))
		end
		local env = math.min(1, near / (tile * 2))
		local off = (wind or 0) * math.sin(p.d / 38) * env
		p.x, p.z = p.x + p.nx * off, p.z + p.nz * off
	end
	local tiles, borders = {}, {}
	local snap = function(dx, dz)
		if math.abs(dx) >= math.abs(dz) then
			return dx > 0 and 1 or -1, 0
		end
		return 0, dz > 0 and 1 or -1
	end
	for i = 1, #pts do
		local a, b = pts[i], pts[i + 1] or pts[i]
		local pa = pts[i - 1]
		local dx, dz = b.x - a.x, b.z - a.z
		if i == #pts then
			dx, dz = a.x - pa.x, a.z - pa.z
		end
		local rot = Placement.yawOfDir(dx, dz)
		local kind = "path_straight"
		if pa and i < #pts then
			local ix, iz = a.x - pa.x, a.z - pa.z
			local li, lo = math.sqrt(ix * ix + iz * iz), math.sqrt(dx * dx + dz * dz)
			local cosT = (ix * dx + iz * dz) / (li * lo)
			if cosT < 0.64 and cosT > -0.64 then -- tourne de 50° à 130°
				local ux, uz = snap(ix, iz)
				local vx, vz = snap(dx, dz)
				-- virage de base : on entre en allant vers +X et on sort vers -Z ; 4 rotations x (sens direct / inverse)
				local found
				for q = 0, 3 do
					local th = math.rad(q * 90)
					local function rot90(x, z) -- image de (x, z) par Angles(0, th, 0)
						return math.floor(x * math.cos(th) + z * math.sin(th) + 0.5), math.floor(-x * math.sin(th) + z * math.cos(th) + 0.5)
					end
					local ex, ez = rot90(1, 0)
					local fx, fz = rot90(0, -1)
					if ex == ux and ez == uz and fx == vx and fz == vz then
						found = q * 90
					elseif -fx == ux and -fz == uz and -ex == vx and -ez == vz then
						found = q * 90 -- tuile parcourue en sens inverse
					end
				end
				if found then
					kind, rot = "path_curve", found
				end
			end
		end
		tiles[#tiles + 1] = { kind = kind, x = a.x, z = a.z, rot = rot }
		local nxl, nzl = -dz, dx
		local nl = math.sqrt(nxl * nxl + nzl * nzl)
		if nl > 0 then
			for _, side in ipairs({ -1, 1 }) do
				borders[#borders + 1] = { x = a.x + side * nxl / nl * (tile / 2 + 1.2), z = a.z + side * nzl / nl * (tile / 2 + 1.2), rot = rot }
			end
		end
	end
	return { tiles = tiles, borders = borders, length = total }
end

function Placement.new(Config, MapGeo)
	local MG = loadGeo(MapGeo)
	local G = MG.new(Config)
	local P = { G = G }
	local M2 = Config.Map2
	local B = M2.bounds

	-- Segments des chemins au sol (mêmes polylignes que Scenery.paths) : { ax, az, bx, bz } ; les ponts sont des chemins.
	function P.pathSegments()
		local out = {}
		for _, sg in ipairs(G.pathSegs) do
			if (sg.y or 0) == 0 then
				out[#out + 1] = { sg[1], sg[2], sg[3], sg[4], half = sg.half }
			end
		end
		return out
	end

	-- Altitude du sol en (x, z) : plateau du château, colline, sinon 0.
	function P.groundY(x, z)
		return G.groundY(x, z)
	end

	-- Pourquoi une empreinte (x, z, r) est interdite : "eau", "chemin", "place", "repère", "arène", "château", "domaine", "base", "secret",
	-- "plume", "bord" ou nil si libre. opts.allowDomain : dans un territoire (cabanes, barrières) ; opts.allowPlateau : sur le plateau du château.
	function P.blocked(x, z, r, opts)
		return G.blocked(x, z, r, opts)
	end

	-- Empreintes réservées dans les territoires : nids et postes des gardiens (rien n'y est posé).
	local reserved = {}
	for _, t in ipairs(G.terrs) do
		for _, n in ipairs(t.nests or {}) do
			reserved[#reserved + 1] = { n[1], n[2], 5 }
		end
		for _, p in ipairs(t.posts or {}) do
			reserved[#reserved + 1] = { p[1], p[2], 6 }
		end
	end
	reserved[#reserved + 1] = { G.keep.x, G.keep.z, G.keep.half + 4 }
	local function freeOfReserved(x, z, r)
		for _, q in ipairs(reserved) do
			if math.sqrt((x - q[1]) ^ 2 + (z - q[2]) ^ 2) < q[3] + r then
				return false
			end
		end
		return true
	end

	-- Arbres PROCÉDURAUX des forêts (rectangles de Map2.forests, débordant sur le décor de fond au bord de la carte) et des bosquets : positions
	-- déterministes, rien dans l'eau, sur un chemin, une base ou un territoire. { {x, z, r, y, grove} } ; au plus Map2.procTrees en forêt.
	function P.forest()
		if G._forest then
			return G._forest
		end
		local out = {}
		local r = 3.5
		local function freeHere(x, z)
			pause()
			if math.abs(x) > M2.backdrop.w / 2 - 6 or math.abs(z) > M2.backdrop.d / 2 - 6 then
				return false
			end
			local why = G.blocked(x, z, r, {})
			if why and not (why == "bord" and not G.inBounds(x, z, 0)) then
				return false
			end
			if not freeOfReserved(x, z, r) then
				return false
			end
			for _, o in ipairs(out) do
				if math.sqrt((x - o.x) ^ 2 + (z - o.z) ^ 2) < 2 * r + Placement.MIN_GAP then
					return false
				end
			end
			return true
		end
		-- bosquets : groveTrees arbres en couronne
		for gi, gv in ipairs(M2.groves) do
			for k = 1, M2.groveTrees do
				local a = (k / M2.groveTrees + gi * 0.13) * math.pi * 2
				local rad = M2.groveRadius * (k % 2 == 0 and 0.75 or 0.35)
				local x, z = gv.x + math.cos(a) * rad, gv.z + math.sin(a) * rad
				if freeHere(x, z) then
					out[#out + 1] = { x = x, z = z, r = r, y = G.groundY(x, z), grove = gi }
				end
			end
		end
		-- forêts : quota proportionnel au maximum de chaque rectangle ; un rectangle collé au bord déborde de 24 studs dans le décor de fond
		local sumMax = 0
		for _, f in ipairs(M2.forests) do
			sumMax = sumMax + f.max
		end
		local seed = 2711
		local function rnd()
			seed = seed * 16807 % 2147483647
			return seed / 2147483647
		end
		for _, f in ipairs(M2.forests) do
			local quota = math.floor(M2.procTrees * f.max / sumMax + 0.5)
			local x0, x1, z0, z1 = f.x0, f.x1, f.z0, f.z1
			if x0 <= B.x0 then
				x0 = x0 - 24
			end
			if x1 >= B.x1 then
				x1 = x1 + 24
			end
			if z0 <= B.z0 then
				z0 = z0 - 24
			end
			if z1 >= B.z1 then
				z1 = z1 + 24
			end
			local cells = {}
			local step = 11
			for gx = x0 + step / 2, x1, step do
				for gz = z0 + step / 2, z1, step do
					cells[#cells + 1] = { gx, gz }
				end
			end
			for i = #cells, 2, -1 do
				local j = 1 + math.floor(rnd() * i)
				cells[i], cells[j] = cells[j], cells[i]
			end
			local got = 0
			for _, c in ipairs(cells) do
				if got >= quota then
					break
				end
				local x, z = c[1] + (rnd() - 0.5) * 5, c[2] + (rnd() - 0.5) * 5
				if freeHere(x, z) then
					out[#out + 1] = { x = x, z = z, r = r, y = G.groundY(x, z) }
					got = got + 1
				end
			end
		end
		G._forest = out
		return out
	end

	-- Plan complet : { items = { {kind, x, z, rot, r, y} }, bridges = { {x, z, rot, length, name} }, forest = P.forest() }. Déterministe.
	function P.plan()
		if G._plan then
			return G._plan
		end
		local items = {}
		local forest = P.forest()
		local function fits(kind, x, z, opts)
			pause()
			local r = KIND_RADIUS[kind]
			if P.blocked(x, z, r, opts) or not freeOfReserved(x, z, r) then
				return false
			end
			for _, it in ipairs(items) do
				if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + Placement.MIN_GAP then
					return false
				end
			end
			for _, it in ipairs(forest) do
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
		-- 1. par rival (premier territoire) : une ligne de barrières alignée puis une cabane face au centre du territoire (jamais dans l'eau)
		for i = 1, #Config.RIVALS do
			local cx, cz = Config.rivalCenter(i)
			local t = G.terr(Config.rivalTerritories(i)[1].key)
			local inner = t.r - 10
			local opts = { allowDomain = true, allowPlateau = true }
			local perDomain = math.ceil((plan.fence or 0) / #Config.RIVALS)
			for k = 0, perDomain - 1 do
				local fx, fz = cx - 20.25 + k * 13.5, cz - (t.r - 12) -- côté nord du territoire
				if fits("fence", fx, fz, opts) then
					add("fence", fx, fz, 0) -- alignées sur l'axe X, même rotation : jamais de barrières qui se croisent
				end
			end
			for _, off in ipairs({ { -1, 0.3 }, { 1, 0.3 }, { -0.7, -0.7 }, { 0.7, -0.7 }, { 0, 1 }, { 0, -1 }, { 0, 0.55 }, { 0.55, 0 }, { -0.55, 0 }, { 0, -0.55 } }) do
				local hx, hz = cx + off[1] * inner, cz + off[2] * inner
				if (plan.hut or 0) > 0 and fits("hut", hx, hz, opts) then
					add("hut", hx, hz, Placement.facing(cx - hx, cz - hz))
					break
				end
			end
		end
		-- 2. décor libre : les sapins et les arbres vont d'abord dans les forêts, puis partout ; rochers et buissons sur toute la carte
		local seed = 4093 -- Park–Miller : mélange déterministe des cellules
		local function rnd()
			seed = seed * 16807 % 2147483647
			return seed / 2147483647
		end
		local cell = Placement.CELL
		local cells, forestCells = {}, {}
		for gx = B.x0 + 10, B.x1 - 10, cell do
			for gz = B.z0 + 10, B.z1 - 10, cell do
				local c = { gx + cell / 2, gz + cell / 2 }
				cells[#cells + 1] = c
				for _, f in ipairs(M2.forests) do
					if c[1] >= f.x0 - 10 and c[1] <= f.x1 + 10 and c[2] >= f.z0 - 10 and c[2] <= f.z1 + 10 then
						forestCells[#forestCells + 1] = c
						break
					end
				end
			end
		end
		local function shuffle(list)
			for i = #list, 2, -1 do
				local j = 1 + math.floor(rnd() * i)
				list[i], list[j] = list[j], list[i]
			end
		end
		shuffle(cells)
		shuffle(forestCells)
		-- grouped : arbres posés par GROUPES (lot graphismes) : une graine, puis jusqu'à (taille du groupe - 1) compagnons à groupRadius studs, tous soumis à fits()
		local groupSeq = 0
		local function scatter(kind, count, list, grouped)
			local got = 0
			local GT = Config.GRAPHICS and Config.GRAPHICS.trees
			for _, c in ipairs(list) do
				if got >= count then
					break
				end
				local x, z = c[1] + (rnd() - 0.5) * 14, c[2] + (rnd() - 0.5) * 14
				if fits(kind, x, z) then
					add(kind, x, z, rnd() * 360)
					got = got + 1
					if grouped and GT then
						groupSeq = groupSeq + 1
						local size = GT.groupSizes[(groupSeq - 1) % #GT.groupSizes + 1]
						local a0 = rnd() * math.pi * 2
						for k = 1, size - 1 do
							if got < count then
								local a = a0 + k * (math.pi * 2 / (size - 1)) + (rnd() - 0.5) * 0.5
								local rad = GT.groupRadius[1] + rnd() * (GT.groupRadius[2] - GT.groupRadius[1])
								local gx, gz = x + math.cos(a) * rad, z + math.sin(a) * rad
								if fits(kind, gx, gz) then
									add(kind, gx, gz, rnd() * 360)
									got = got + 1
								end
							end
						end
					end
				end
			end
			return got
		end
		local firs = scatter("fir", plan.fir or 0, forestCells, true)
		scatter("fir", (plan.fir or 0) - firs, cells, true)
		local trees = scatter("tree", math.ceil((plan.tree or 0) / 2), forestCells, true)
		scatter("tree", (plan.tree or 0) - trees, cells, true)
		scatter("rock", plan.rock or 0, cells)
		scatter("bush", plan.bush or 0, cells)
		-- 3. ponts de bois (Blender) : centrés sur leur cours d'eau, axe du pont ; le pont de pierre du château (rampe) reste procédural
		local bridges = {}
		for _, b in ipairs(G.bridges) do
			if not b.stone then
				bridges[#bridges + 1] = { x = b.x, z = b.z, rot = b.axis == "NS" and 90 or 0, length = b.len, name = b.name, river = b.river }
			end
		end
		G._plan = { items = items, bridges = bridges, forest = forest }
		return G._plan
	end

	-- Décor fin (fleurs, touffes, pierres, lanternes) : mêmes règles (rien dans l'eau ni sur un chemin), espacement plus serré, après le plan principal.
	-- Retourne { {kind, x, z, rot, r} } ; kinds : flower_a/b/c, tuft, stone_flat, stone_round, lantern. Les lanternes bordent les chemins (à 5 studs).
	local DECO_RADIUS = { flower_a = 1, flower_b = 1, flower_c = 1, tuft = 1, stone_flat = 1.5, stone_round = 1.5, lantern = 1 }
	Placement.DECO_RADIUS = DECO_RADIUS
	function P.decor(planItems, counts)
		counts = counts or { flowers = 36, tufts = 24, stones = 18, lanterns = 12 }
		local out = {}
		local function fits(kind, x, z)
			pause()
			local r = DECO_RADIUS[kind]
			if P.blocked(x, z, r, { allowDomain = true }) then
				return false
			end
			for _, it in ipairs(planItems or {}) do
				if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + 1 then
					return false
				end
			end
			for _, it in ipairs(P.forest()) do
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
				local x, z = seg[1] + dx * t + nx * ((seg.half or M2.pathHalf) + 3.5), seg[2] + dz * t + nz * ((seg.half or M2.pathHalf) + 3.5)
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
		local cell = 24
		for gx = B.x0 + 12, B.x1 - 12, cell do
			for gz = B.z0 + 12, B.z1 - 12, cell do
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

	-- Décor de village de la carte (modèles scn_*) : candidats sur des anneaux autour de la place, ordre fixe ; mêmes règles que plan() (rien dans l'eau, sur un
	-- chemin, une base, un territoire ni sur un objet du plan). Retourne { {kind, x, z, rot, r, y} }.
	local VILLAGE = { { "scn_tour_cloche", 1 }, { "scn_maison_colombages", 3 }, { "scn_puits", 2 }, { "scn_pin_haut", 6 }, { "scn_rocher_a", 3 }, { "scn_rocher_b", 3 }, { "scn_rocher_c", 3 } }
	Placement.VILLAGE = VILLAGE
	function P.scenery(planItems)
		local out = {}
		local dims = Config.Assets.sceneryDims
		for _, entry in ipairs(VILLAGE) do
			local kind, want = entry[1], entry[2]
			local r = dims[kind].r
			local got, tries = 0, 0
			while got < want and tries < 400 do
				tries = tries + 1
				pause()
				local ang = math.rad((tries * 137.5 + #out * 23) % 360)
				local rad = 75 + (tries * 29) % 250 -- anneaux de 75 à 325 studs autour de la place
				local x, z = math.sin(ang) * rad, -math.cos(ang) * rad
				local ok = not P.blocked(x, z, r, {}) and freeOfReserved(x, z, r)
				if ok then
					for _, it in ipairs(planItems or {}) do
						if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + 2 then
							ok = false
							break
						end
					end
				end
				if ok then
					for _, it in ipairs(P.forest()) do
						if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + 2 then
							ok = false
							break
						end
					end
				end
				if ok then
					for _, it in ipairs(out) do
						if math.sqrt((x - it.x) ^ 2 + (z - it.z) ^ 2) < r + it.r + 3 then
							ok = false
							break
						end
					end
				end
				if ok then
					out[#out + 1] = { kind = kind, x = x, z = z, rot = Placement.facing(-x, -z), r = r, y = P.groundY(x, z) }
					got = got + 1
				end
			end
		end
		return out
	end

	return P
end

return Placement
