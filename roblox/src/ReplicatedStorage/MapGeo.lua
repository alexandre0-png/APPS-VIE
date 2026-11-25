-- ModuleScript : ReplicatedStorage/Shared/MapGeo
-- REFONTE (lot 2) : géométrie PURE de la carte 700 x 500 (Config.Map2 et Config.TERR), testée hors de Roblox. Source unique pour Builder, Scenery,
-- Placement, la mini-carte et les tests : bases orientées vers la place (spawn devant), territoires, chemins, eau (lacs, rivières en polylignes,
-- fontaine, douve), murs invisibles de la rivière du Nord coupés aux ponts, hauteur du sol (plateau du château, collines), accessibilité d'un point.
-- Nord = -Z, Est = +X. Aucun service Roblox ; pas de math.atan2. Utilisation : require(MapGeo).new(Config).
local MapGeo = {}

local function dist(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end
MapGeo.dist = dist

local function distToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / len2)) or 0
	return dist(px, pz, ax + dx * t, az + dz * t)
end
MapGeo.distToSegment = distToSegment

-- Distance d'un point à une polyligne { {x, z}, ... }.
function MapGeo.distToPoly(px, pz, pts)
	local best = math.huge
	for k = 1, #pts - 1 do
		best = math.min(best, distToSegment(px, pz, pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]))
	end
	return best
end

function MapGeo.polyLength(pts)
	local total = 0
	for k = 1, #pts - 1 do
		total = total + dist(pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2])
	end
	return total
end

local function cross(ax, az, bx, bz)
	return ax * bz - az * bx
end

-- Les segments [A, B] et [C, D] se coupent-ils (contact compris) ? Deux segments parallèles ne se coupent pas (un mur ne se longe pas « à travers »).
function MapGeo.segmentsCross(ax, az, bx, bz, cx, cz, dx, dz)
	local rx, rz = bx - ax, bz - az
	local sx, sz = dx - cx, dz - cz
	local den = cross(rx, rz, sx, sz)
	if math.abs(den) < 1e-12 then
		return false
	end
	local t = cross(cx - ax, cz - az, sx, sz) / den
	local u = cross(cx - ax, cz - az, rx, rz) / den
	return t >= -1e-9 and t <= 1 + 1e-9 and u >= -1e-9 and u <= 1 + 1e-9
end

-- Colline en calotte sphérique (rayon au sol r, hauteur h) : rayon de la sphère et hauteur de son centre (sous le sol).
function MapGeo.hillSphere(hill)
	local R = (hill.r * hill.r + hill.h * hill.h) / (2 * hill.h)
	return R, hill.h - R
end

local cache = setmetatable({}, { __mode = "k" })

function MapGeo.new(Config, fresh)
	if cache[Config] and not fresh then
		return cache[Config]
	end
	local M = Config.Map2
	local G = { M = M }
	cache[Config] = G
	local B = M.bounds

	function G.inBounds(x, z, margin)
		margin = margin or 0
		return x >= B.x0 + margin and x <= B.x1 - margin and z >= B.z0 + margin and z <= B.z1 - margin
	end

	---------------------------------------------------------------- Bases : façade (-Z local) tournée vers la place, spawn devant
	G.bases = {}
	for i, b in ipairs(M.bases) do
		local d = dist(b.x, b.z, M.plaza.x, M.plaza.z)
		local fx, fz = (M.plaza.x - b.x) / d, (M.plaza.z - b.z) / d
		G.bases[i] = { i = i, x = b.x, z = b.z, fx = fx, fz = fz, half = M.baseSizeMax / 2, spawn = { x = b.x + fx * M.spawnForward, z = b.z + fz * M.spawnForward } }
	end
	-- Coordonnées locales d'un point dans la base i : (avant = vers la place, côté = à droite).
	function G.baseLocal(i, x, z)
		local b = G.bases[i]
		local rx, rz = x - b.x, z - b.z
		return rx * b.fx + rz * b.fz, rx * -b.fz + rz * b.fx
	end
	-- Distance d'un point au carré de la base i (demi-côté `half`, par défaut l'emprise maximale) ; 0 dedans.
	function G.distToBase(i, x, z, half)
		local a, s = G.baseLocal(i, x, z)
		half = half or G.bases[i].half
		local ex, ez = math.max(0, math.abs(a) - half), math.max(0, math.abs(s) - half)
		return math.sqrt(ex * ex + ez * ez)
	end

	---------------------------------------------------------------- Territoires (Config.TERR, ordre TERR_ORDER)
	G.terrs = {}
	for _, key in ipairs(Config.TERR_ORDER) do
		local t = Config.TERR[key]
		local ex, ez = Config.territoryEntry(key)
		G.terrs[#G.terrs + 1] = { key = key, x = t.x, z = t.z, r = t.r, rival = t.rival, guards = t.guards, nests = t.nests, posts = t.posts or {}, entry = { x = ex, z = ez }, data = t }
	end
	function G.terr(key)
		for _, t in ipairs(G.terrs) do
			if t.key == key then
				return t
			end
		end
		return nil
	end
	-- Territoire qui contient (x, z) (marge facultative), ou nil.
	function G.terrAt(x, z, margin)
		for _, t in ipairs(G.terrs) do
			if dist(x, z, t.x, t.z) < t.r + (margin or 0) then
				return t
			end
		end
		return nil
	end

	---------------------------------------------------------------- Chemins
	G.paths = M.paths
	-- Segments de tous les chemins : { ax, az, bx, bz, half, name, y }.
	G.pathSegs = {}
	for _, p in ipairs(M.paths) do
		local half = p.kind == "dirt" and M.dirtHalf or M.pathHalf
		for k = 1, #p.pts - 1 do
			G.pathSegs[#G.pathSegs + 1] = { p.pts[k][1], p.pts[k][2], p.pts[k + 1][1], p.pts[k + 1][2], half = half, name = p.name, y = p.y or 0 }
		end
	end
	function G.path(name)
		for _, p in ipairs(M.paths) do
			if p.name == name then
				return p
			end
		end
		return nil
	end
	-- Distance au bord du chemin le plus proche (négative sur le chemin).
	function G.pathEdgeDist(x, z)
		local best = math.huge
		for _, s in ipairs(G.pathSegs) do
			best = math.min(best, distToSegment(x, z, s[1], s[2], s[3], s[4]) - s.half)
		end
		return best
	end

	---------------------------------------------------------------- Eau
	-- Distance au bord de l'eau la plus proche (négative dans l'eau) et son nom. withShore : la rive de sable des lacs compte comme de l'eau.
	function G.waterEdgeDist(x, z, withShore)
		local best, name = math.huge, nil
		local function try(d, n)
			if d < best then
				best, name = d, n
			end
		end
		for _, lk in ipairs(M.lakes) do
			try(dist(x, z, lk.x, lk.z) - lk.r - (withShore and lk.shore or 0), lk.name)
		end
		for _, rv in ipairs(M.rivers) do
			try(MapGeo.distToPoly(x, z, rv.pts) - rv.width / 2, rv.name)
		end
		try(dist(x, z, M.fountain.x, M.fountain.z) - M.fountain.r, "Fountain")
		local mo = G.moat
		local ex = math.max(mo.x0 - x, 0, x - mo.x1)
		local ez = math.max(mo.z0 - z, 0, z - mo.z1)
		try(math.sqrt(ex * ex + ez * ez) - ((ex == 0 and ez == 0) and 0.01 or 0), "CastleMoat")
		return best, name
	end
	-- Douve décorative : bande de 6 au pied de la falaise sud du château, entre la rivière et le plateau.
	G.moat = { x0 = M.castle.x0 + 8, x1 = M.castle.x1, z0 = M.castle.z1, z1 = M.castle.z1 + 6 }

	---------------------------------------------------------------- Ponts et murs de la rivière du Nord
	-- Pont : rivière franchie (la plus proche), point de franchissement sur la rivière, demi-passage dans le mur.
	G.bridges = {}
	for _, b in ipairs(M.bridges) do
		local bestR, bestD = nil, math.huge
		for ri, rv in ipairs(M.rivers) do
			local d = MapGeo.distToPoly(b.x, b.z, rv.pts)
			if d < bestD then
				bestR, bestD = ri, d
			end
		end
		local pts = M.rivers[bestR].pts
		local cxp, czp, cd = b.x, b.z, math.huge -- point de la rivière le plus proche du centre du pont
		for k = 1, #pts - 1 do
			local ax, az, bx, bz = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
			local dx, dz = bx - ax, bz - az
			local t = math.max(0, math.min(1, ((b.x - ax) * dx + (b.z - az) * dz) / (dx * dx + dz * dz)))
			local qx, qz = ax + dx * t, az + dz * t
			local d = dist(b.x, b.z, qx, qz)
			if d < cd then
				cxp, czp, cd = qx, qz, d
			end
		end
		G.bridges[#G.bridges + 1] = { name = b.name, x = b.x, z = b.z, axis = b.axis, w = b.w, len = b.len, stone = b.stone, river = bestR, cross = { x = cxp, z = czp }, gapHalf = math.max(b.w / 2, M.bridgeHalfGap) }
	end
	-- Murs invisibles de la rivière du Nord (rivière 1) : sa ligne médiane découpée, sans les passages des ponts. { {ax, az, bx, bz}, ... }
	function G.riverWalls(ri)
		ri = ri or 1
		local pts = M.rivers[ri].pts
		local gaps = {}
		for _, b in ipairs(G.bridges) do
			if b.river == ri then
				gaps[#gaps + 1] = b
			end
		end
		local out = {}
		for k = 1, #pts - 1 do
			local ax, az, bx, bz = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
			local dx, dz = bx - ax, bz - az
			local len = math.sqrt(dx * dx + dz * dz)
			local cuts = {} -- intervalles [t0, t1] retirés (points à moins de gapHalf du point de franchissement)
			for _, b in ipairs(gaps) do
				-- |A + t D - C|^2 = g^2  ->  t^2 L^2 + 2 t (A-C).D + |A-C|^2 - g^2 = 0
				local ox, oz = ax - b.cross.x, az - b.cross.z
				local qa, qb, qc = len * len, 2 * (ox * dx + oz * dz), ox * ox + oz * oz - b.gapHalf * b.gapHalf
				local disc = qb * qb - 4 * qa * qc
				if disc > 0 then
					local s = math.sqrt(disc)
					local t0, t1 = (-qb - s) / (2 * qa), (-qb + s) / (2 * qa)
					if t1 > 0 and t0 < 1 then
						cuts[#cuts + 1] = { math.max(0, t0), math.min(1, t1) }
					end
				end
			end
			table.sort(cuts, function(p, q)
				return p[1] < q[1]
			end)
			local from = 0
			local function add(t0, t1)
				if (t1 - t0) * len > 0.5 then
					out[#out + 1] = { ax + dx * t0, az + dz * t0, ax + dx * t1, az + dz * t1 }
				end
			end
			for _, c in ipairs(cuts) do
				add(from, c[1])
				from = math.max(from, c[2])
			end
			add(from, 1)
		end
		return out
	end
	-- Le trajet [A, B] traverse-t-il un mur de la rivière du Nord ?
	function G.crossesRiverWall(ax, az, bx, bz)
		for _, w in ipairs(G.riverWalls(1)) do
			if MapGeo.segmentsCross(ax, az, bx, bz, w[1], w[2], w[3], w[4]) then
				return true
			end
		end
		return false
	end

	---------------------------------------------------------------- Relief : plateau du château, collines
	local C = M.castle
	-- Palier du pont du château : relie le pont (dont la moitié ouest dépasse du plateau) au plateau.
	G.landing = { x0 = C.x0 - 7, x1 = C.x0, z0 = C.z1 - 8, z1 = C.z1 }
	function G.onPlateau(x, z)
		return (x >= C.x0 and x <= C.x1 and z >= C.z0 and z <= C.z1) or (x >= G.landing.x0 and x <= G.landing.x1 and z >= G.landing.z0 and z <= G.landing.z1)
	end
	function G.hillHeight(x, z)
		local best = 0
		for _, h in ipairs(M.hills) do
			local d = dist(x, z, h.x, h.z)
			if d < h.r then
				local R, cy = MapGeo.hillSphere(h)
				best = math.max(best, math.sqrt(R * R - d * d) + cy)
			end
		end
		return best
	end
	-- Hauteur du sol : plateau du château, sinon colline, sinon 0.
	function G.groundY(x, z)
		if G.onPlateau(x, z) then
			return C.h
		end
		return G.hillHeight(x, z)
	end

	---------------------------------------------------------------- Accessibilité (plumes, arrivées) : approximation documentée
	-- Un point est atteignable s'il est dans les bornes, hors de l'eau (sauf sur un ponton), hors des bâtiments pleins (donjon, cabane), et pas dans la
	-- bande close entre la rivière du Nord et la falaise du château (à l'est du pont : on n'y accède ni par le pont ni par le plateau).
	G.docks = {}
	for _, dk in ipairs(M.docks) do
		local lk = M.lakes[dk.lake]
		local d = dist(dk.x, dk.z, lk.x, lk.z)
		local ux, uz = (lk.x - dk.x) / d, (lk.z - dk.z) / d -- vers le centre du lac
		G.docks[#G.docks + 1] = { ax = dk.x - ux * 4, az = dk.z - uz * 4, bx = dk.x + ux * dk.len, bz = dk.z + uz * dk.len, w = dk.w, lake = dk.lake }
	end
	function G.onDock(x, z)
		for _, dk in ipairs(G.docks) do
			if distToSegment(x, z, dk.ax, dk.az, dk.bx, dk.bz) <= dk.w / 2 then
				return true
			end
		end
		return false
	end
	G.keep = { x = C.keep.x, z = C.keep.z, half = 12 }
	function G.reachable(x, z)
		if not G.inBounds(x, z, 2) then
			return false, "bord"
		end
		if not G.onDock(x, z) and G.waterEdgeDist(x, z, false) < 1 then
			return false, "eau"
		end
		if math.abs(x - G.keep.x) < G.keep.half and math.abs(z - G.keep.z) < G.keep.half then
			return false, "donjon"
		end
		local cab = M.cabin
		if math.abs(x - cab.x) < cab.w / 2 and math.abs(z - cab.z) < cab.d / 2 then
			return false, "cabane"
		end
		if x > C.x0 + 6 and z > C.z1 and z < C.z1 + 30 then -- entre le plateau et la rivière, à l'est du pont : bande close
			local rz = nil
			local pts = M.rivers[1].pts
			for k = 1, #pts - 1 do
				if x >= pts[k][1] and x <= pts[k + 1][1] then
					local t = (x - pts[k][1]) / (pts[k + 1][1] - pts[k][1])
					rz = pts[k][2] + (pts[k + 1][2] - pts[k][2]) * t
				end
			end
			if rz and z < rz then
				return false, "bande close"
			end
		end
		return true, nil
	end

	---------------------------------------------------------------- Portails et repères de la place
	G.portals = {}
	for k, p in ipairs(Config.TRAVEL2.portals) do
		local px, pz = Config.portalPad(k)
		G.portals[k] = { k = k, name = p.name, pad = { x = px, z = pz }, to = { x = p.to[1], z = p.to[2] }, back = { x = p.back[1], z = p.back[2] }, chapter = p.chapter or 0 }
	end
	G.homeArches = {}
	for i = 1, #M.bases do
		local x, z = Config.homeArch(i)
		G.homeArches[i] = { x = x, z = z }
	end

	---------------------------------------------------------------- Emprises occupées (pose du décor) : raison du blocage ou nil
	-- opts.allowDomain : l'empreinte peut être dans un territoire (cabanes, barrières) ; opts.allowPlateau : sur le plateau du château.
	local function feathers()
		local out = {}
		for _, list in pairs(Config.FEATHER_SPOTS or {}) do
			for _, f in ipairs(list) do
				out[#out + 1] = f
			end
		end
		return out
	end
	G.featherList = feathers()
	function G.blocked(x, z, r, opts)
		local margin = 1.5
		if not G.inBounds(x, z, 4 + r) then
			return "bord"
		end
		if G.waterEdgeDist(x, z, true) < r + margin then
			return "eau"
		end
		if dist(x, z, M.plaza.x, M.plaza.z) < M.plaza.r + r + margin then
			return "place"
		end
		if dist(x, z, M.bigEgg.x, M.bigEgg.z) < M.bigEgg.r + r + margin then
			return "repère"
		end
		local tr = M.track
		if math.abs(x - tr.x) < tr.w / 2 + r + margin and math.abs(z - tr.z) < tr.d / 2 + r + margin then
			return "repère"
		end
		for _, p in ipairs(G.portals) do
			if dist(x, z, p.back.x, p.back.z) < 6 + r or dist(x, z, p.to.x, p.to.z) < 4 + r then
				return "repère"
			end
		end
		local A = M.arena
		if dist(x, z, A.x, A.z) < A.r + r + margin then
			return "arène"
		end
		if G.onPlateau(x, z) or (x > C.x0 - 8 - r and x < C.x1 + r and z > C.z0 - r and z < C.z1 + r) then
			if not (opts and opts.allowPlateau) then
				return "château"
			end
		end
		for _, t in ipairs(G.terrs) do
			if dist(x, z, t.x, t.z) < t.r + r + margin and not (opts and opts.allowDomain) then
				return "domaine"
			end
		end
		if G.pathEdgeDist(x, z) < r + margin then
			return "chemin"
		end
		for _, b in ipairs(G.bridges) do
			if dist(x, z, b.x, b.z) < b.len / 2 + r then
				return "chemin"
			end
		end
		for i = 1, #G.bases do
			if G.distToBase(i, x, z) < r + 4 then
				return "base"
			end
		end
		for _, sct in ipairs(Config.SECRETS) do
			if dist(x, z, sct.x, sct.z) < 14 + r then
				return "secret"
			end
		end
		for _, f in ipairs(G.featherList) do
			if dist(x, z, f.x, f.z) < 4 + r then
				return "plume"
			end
		end
		local cab = M.cabin
		if math.abs(x - cab.x) < cab.w / 2 + r + 2 and math.abs(z - cab.z) < cab.d / 2 + r + 2 then
			return "repère"
		end
		return nil
	end

	return G
end

return MapGeo
