-- ModuleScript : ServerScriptService/Decor
-- Lot 8B-décor : pose des modèles Blender de DÉCOR DE CARTE (lots 15, 16, 17) avec repli procédural. Données : ReplicatedStorage/Shared/DecorData.
--   Decor.plan(G, config, data, deps)          : plan PUR (aucun Instance) : positions, rotations, empreintes ; déterministe ; testé hors de Roblox.
--   Decor.build(parent, G, config, deps)       : charge les modèles manquants (Assets.loadMany : lots parallèles, délai, un nouvel essai), pose chaque exemplaire
--                                                en modèle Blender ou, à défaut, en repli procédural, dans un dossier « BlenderDecor » de `parent`. Retourne un handle.
--   Decor.refresh(handle)                      : reconstruit (hook onAssetsLoaded : les modèles arrivés remplacent les replis) ; Decor.clear(handle) : nettoie.
-- Règles : rien dans l'eau, sur un chemin, une base, un territoire, la place (sauf la couronne du marché), l'arène, le château, ni sur les objets déjà posés
-- (Placement.plan/forest/scenery/decor passés par deps.placement) ni dans le disque du kiosque central. Budgets de Parts : DecorData.budget (modèles : coût MESURÉ ;
-- repli : séparé). Les ANCRES (dôme du hall, Grand Œuf, colisée, tapis) superposent un modèle à un élément procédural qu'elles masquent (Transparency 1,
-- collision conservée) SEULEMENT si le modèle est posé ; sinon l'élément procédural reste. Aucune fuite : clear() détruit le dossier et rend les transparences.
-- Ne lève jamais d'erreur (tout sous pcall) ; compatible lupa (pas de += ni continue ni math.atan2).
--
-- deps (tous facultatifs) : assets (instance de Assets.new : status, loadMany, cloneModel, place), placement (Placement.new(Config, MapGeo)), data (DecorData),
-- occupied ({ {x, z, r} }), root (racine où chercher les éléments à masquer, par défaut parent.Parent), env (surcharges Roblox : newFolder, destroy, makePart, findNamed,
-- getTransparency, setTransparency, label, yield), warn, skipLoad (true : ne charge rien).
local Decor = {}

local FOLDER_NAME = "BlenderDecor"
local current = setmetatable({}, { __mode = "k" }) -- parent -> handle (un seul décor par parent ; clés faibles)

---------------------------------------------------------------- utilitaires purs
local function num(v, default)
	if type(v) == "number" and v == v and v > -math.huge and v < math.huge then
		return v
	end
	return default
end

local function dist(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Rotation Y (degrés) pour qu'un modèle dont l'avant est -Z regarde (dx, dz) ; même formule que Placement.facing (pas de math.atan2).
local function facing(dx, dz)
	local fx, fz = -dx, -dz
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
Decor.facing = facing

local function newRng(seed)
	local s = seed
	return function()
		s = s * 16807 % 2147483647
		return s / 2147483647
	end
end

local function distToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / len2)) or 0
	return dist(px, pz, ax + dx * t, az + dz * t)
end

local function circleRect(x, z, r, rc)
	local ex = math.max(rc.x0 - x, 0, x - rc.x1)
	local ez = math.max(rc.z0 - z, 0, z - rc.z1)
	return math.sqrt(ex * ex + ez * ez) < r
end

local function validId(id)
	return type(id) == "number" and id > 0 and id % 1 == 0
end

---------------------------------------------------------------- données
local function loadData(deps)
	if deps and deps.data then
		return deps.data
	end
	local ok, mod = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DecorData"))
	end)
	if ok and type(mod) == "table" then
		return mod
	end
	error("Decor : module DecorData introuvable")
end

local function budgets(config, data)
	local A = config.Assets or {}
	local b = data.budget or {}
	return math.max(0, num(A.decorBudgetParts, num(b.blender, 0))), math.max(0, num(A.decorFallbackParts, num(b.fallback, 0)))
end

local function kioskOf(config, data)
	local k = (config.Map2 and config.Map2.kiosk) or config.KIOSK or data.kiosk
	if type(k) ~= "table" then
		return { x = 0, z = 0, r = 0 }
	end
	return { x = num(k.x, 0), z = num(k.z, 0), r = num(k.r, 0) }
end

local function isOff(config, fam)
	local off = config.Assets and config.Assets.decorOff
	return type(off) == "table" and off[fam] == true
end

---------------------------------------------------------------- plan pur
-- Emprises déjà occupées { {x, z, r} } : plan Placement (items, forêt, village, décor fin), deps.occupied, DecorData.existing.
local function gatherOccupied(data, deps)
	local occ = {}
	local function add(x, z, r)
		if type(x) == "number" and type(z) == "number" then
			occ[#occ + 1] = { x, z, num(r, 3) }
		end
	end
	local P = deps and deps.placement
	if P then
		pcall(function()
			local plan = P.plan()
			for _, it in ipairs(plan.items or {}) do
				add(it.x, it.z, it.r)
			end
			for _, it in ipairs(plan.forest or {}) do
				add(it.x, it.z, it.r)
			end
			for _, it in ipairs(P.scenery(plan.items) or {}) do
				add(it.x, it.z, it.r)
			end
			for _, it in ipairs(P.decor(plan.items) or {}) do
				add(it.x, it.z, it.r)
			end
		end)
	end
	if deps and type(deps.occupied) == "table" then
		for _, o in ipairs(deps.occupied) do
			add(o[1] or o.x, o[2] or o.z, o[3] or o.r)
		end
	end
	for _, o in ipairs(data.existing or {}) do
		add(o[1], o[2], o[3])
	end
	return occ
end

-- Fixtures de la place du marché : cercles { x, z, r } et rectangles { x0, x1, z0, z1 } d'exclusion.
local function plazaFixtures(G, config, data, kiosk)
	local M2 = config.Map2
	local P = data.plaza or {}
	local circles, rects = {}, {}
	local function circ(t, r)
		if type(t) == "table" and type(t.x) == "number" and type(t.z) == "number" then
			circles[#circles + 1] = { t.x, t.z, r }
		end
	end
	if M2.fountain then
		circ(M2.fountain, num(M2.fountain.r, 7) + num(P.fountainMargin, 4))
	end
	if M2.hall then
		circ(M2.hall, num(M2.hall.r, 18) + num(P.hallMargin, 4))
	end
	for _, st in ipairs(M2.stalls or {}) do
		circ(st, num(P.stallRadius, 8.5))
	end
	for _, p in ipairs(G.portals or {}) do
		circ(p.pad, num(P.portalPad, 8))
	end
	circ(M2.plazaArrival, num(P.arrivalRadius, 7))
	circ(M2.hen, num(P.henRadius, 6))
	if M2.bigEgg then
		circ(M2.bigEgg, num(M2.bigEgg.r, 22) + 4)
	end
	for _, rs in ipairs(M2.runeStones or {}) do
		circ(rs, num(P.runeRadius, 5))
	end
	for _, a in ipairs(G.homeArches or {}) do
		circ(a, num(P.archRadius, 8))
	end
	for _, s in ipairs(config.SECRETS or {}) do
		circ(s, num(P.secretRadius, 14))
	end
	for _, f in ipairs(G.featherList or {}) do
		circ(f, 4)
	end
	for _, rv in ipairs((config.Decor and config.Decor.reserved) or {}) do
		circ({ x = rv.x or rv[1], z = rv.z or rv[2] }, num(rv.r or rv[3], 6))
	end
	local B = M2.belt
	if B then
		local bp = P.beltPad or {}
		rects[#rects + 1] = {
			x0 = B.x0 - num(bp.x0, 3),
			x1 = (B.bin and B.bin.x or B.x1) + num(bp.x1, 8),
			z0 = B.z - B.width / 2 - num(bp.z0, 14),
			z1 = B.z + B.width / 2 + num(bp.z1, 8),
		}
	end
	local T = M2.track
	if T then
		local tp = num(P.trackPad, 5)
		rects[#rects + 1] = { x0 = T.x - T.w / 2 - tp, x1 = T.x + T.w / 2 + tp, z0 = T.z - T.d / 2 - tp, z1 = T.z + T.d / 2 + tp }
	end
	return circles, rects
end

-- Plan : { slots = { {fam, x, z, y, rot, r, label, anchor, ...} }, byFam, kiosk, occupied }. Aucune création d'instance.
function Decor.plan(G, config, data, deps)
	deps = deps or {}
	data = data or loadData(deps)
	local M2 = config.Map2
	local kiosk = kioskOf(config, data)
	local occupied = gatherOccupied(data, deps)
	local plazaC, plazaR = plazaFixtures(G, config, data, kiosk)
	local pl = M2.plaza
	local slots, byFam = {}, {}
	local yieldFn = deps.yield
	local tick = 0
	local function pause()
		tick = tick + 1
		if yieldFn and tick % 40 == 0 then
			yieldFn()
		end
	end

	-- libre vis-à-vis des objets déjà posés (autres modèles, Placement), du kiosque et de nos propres exemplaires
	local function farFree(x, z, r, gap)
		if kiosk.r > 0 and dist(x, z, kiosk.x, kiosk.z) < kiosk.r + r then
			return false
		end
		for _, o in ipairs(occupied) do
			if dist(x, z, o[1], o[2]) < r + o[3] + 1 then
				return false
			end
		end
		for _, s in ipairs(slots) do
			if not s.anchor and dist(x, z, s.x, s.z) < r + s.r + gap then
				return false
			end
		end
		return true
	end
	-- règles de MapGeo (eau, chemin, place, repère, arène, château, domaine, base, secret, plume, bord)
	local function mapFree(x, z, r, gap)
		pause()
		if G.blocked(x, z, r, {}) then
			return false
		end
		return farFree(x, z, r, gap)
	end
	-- couronne de la place du marché : dans le disque, hors fixtures, hors chemins
	local function plazaFree(x, z, r, gap)
		pause()
		if dist(x, z, pl.x, pl.z) + r > pl.r - 1 then
			return false
		end
		for _, c in ipairs(plazaC) do
			if dist(x, z, c[1], c[2]) < c[3] + r then
				return false
			end
		end
		for _, rc in ipairs(plazaR) do
			if circleRect(x, z, r + 1, rc) then
				return false
			end
		end
		if G.pathEdgeDist(x, z) < r + 1.5 then
			return false
		end
		return farFree(x, z, r, gap)
	end
	-- obstacles propres aux lacs : pontons, cabane, chemins, ponts, bases
	local function dockClear(x, z, r)
		for _, dk in ipairs(G.docks or {}) do
			if distToSegment(x, z, dk.ax, dk.az, dk.bx, dk.bz) < dk.w / 2 + r + 1.5 then
				return false
			end
		end
		return true
	end
	local function shoreFree(x, z, r, gap)
		pause()
		if not G.inBounds(x, z, 4 + r) or G.onPlateau(x, z) then
			return false
		end
		if G.waterEdgeDist(x, z, false) < 0.8 then
			return false
		end
		if not dockClear(x, z, r) then
			return false
		end
		local cab = M2.cabin
		if cab and math.abs(x - cab.x) < cab.w / 2 + r + 2 and math.abs(z - cab.z) < cab.d / 2 + r + 2 then
			return false
		end
		if G.pathEdgeDist(x, z) < r + 1.5 then
			return false
		end
		for _, b in ipairs(G.bridges or {}) do
			if dist(x, z, b.x, b.z) < b.len / 2 + r then
				return false
			end
		end
		for i = 1, #G.bases do
			if G.distToBase(i, x, z) < r + 4 then
				return false
			end
		end
		return farFree(x, z, r, gap)
	end
	local function waterFree(x, z, r, gap)
		pause()
		if G.waterEdgeDist(x, z, false) > -(r + 1.5) then
			return false
		end
		if not dockClear(x, z, r + 2) then
			return false
		end
		return farFree(x, z, r, gap)
	end

	---------------------------------------------------------------- générateurs de candidats (listes déterministes)
	local function candPlazaRim(fam, fi)
		local out = {}
		local rmin, rmax = fam.ring[1], fam.ring[2]
		for k = 1, 720 do
			local a = math.rad((k * 137.508 + fi * 31) % 360)
			local rad = rmin + ((k * 7) % 23) / 22 * (rmax - rmin)
			local x, z = pl.x + math.cos(a) * rad, pl.z + math.sin(a) * rad
			out[#out + 1] = { x = x, z = z, rot = facing(pl.x - x, pl.z - z) }
		end
		return out
	end
	local function candStallSide(fam, fi)
		local out = {}
		local anchors = {}
		for _, s in ipairs(slots) do
			if (s.fam == "stall_a" or s.fam == "stall_b") and not s.anchor then
				anchors[#anchors + 1] = { s.x, s.z }
			end
		end
		for _, st in ipairs(M2.stalls or {}) do
			anchors[#anchors + 1] = { st.x, st.z }
		end
		local o1, o2 = fam.offset[1], fam.offset[2]
		for k = 0, 35 do
			for ai, a in ipairs(anchors) do
				local ang = math.rad((k * 30 + fi * 17 + ai * 23) % 360)
				local rad = o1 + ((k * 5) % 3) / 2 * (o2 - o1)
				local x, z = a[1] + math.cos(ang) * rad, a[2] + math.sin(ang) * rad
				out[#out + 1] = { x = x, z = z, rot = facing(a[1] - x, a[2] - z) }
			end
		end
		return out
	end
	local function candRegion(fam, fi)
		local out = {}
		local rg = fam.region
		local rnd = newRng(9000 + fi * 131)
		local minP = num(fam.minPlaza, 0)
		for _ = 1, 700 do
			local x, z = rg.x0 + rnd() * (rg.x1 - rg.x0), rg.z0 + rnd() * (rg.z1 - rg.z0)
			if dist(x, z, pl.x, pl.z) >= minP then
				out[#out + 1] = { x = x, z = z, rot = rnd() * 360 }
			end
		end
		return out
	end
	-- point d'un chemin à l'abscisse curviligne s, avec la normale (nx, nz) ; nil au-delà de la fin
	local function pathPoint(pts, s)
		local acc = 0
		for k = 1, #pts - 1 do
			local ax, az, bx, bz = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
			local len = dist(ax, az, bx, bz)
			if len > 0 and acc + len >= s then
				local t = (s - acc) / len
				local dx, dz = (bx - ax) / len, (bz - az) / len
				return ax + (bx - ax) * t, az + (bz - az) * t, -dz, dx
			end
			acc = acc + len
		end
		return nil
	end
	local function eachPath(fn)
		for _, p in ipairs(M2.paths or {}) do
			if (p.y or 0) == 0 and p.name ~= "Court" then
				fn(p, p.kind == "dirt" and M2.dirtHalf or M2.pathHalf)
			end
		end
	end
	local function candPathSide(fam)
		local lists = {}
		eachPath(function(p, half)
			local list = {}
			local total = 0
			for k = 1, #p.pts - 1 do
				total = total + dist(p.pts[k][1], p.pts[k][2], p.pts[k + 1][1], p.pts[k + 1][2])
			end
			local s = 0
			local idx = 0
			while s < total do
				local x, z, nx, nz = pathPoint(p.pts, s)
				if x and dist(x, z, pl.x, pl.z) >= num(fam.pathMinPlaza, 70) then
					idx = idx + 1
					local lat = half + fam.offset + fam.r
					local side = (idx % 2 == 0) and 1 or -1
					list[#list + 1] = { x = x + nx * lat * side, z = z + nz * lat * side, rot = facing(-nx * side, -nz * side) }
					list[#list + 1] = { x = x - nx * lat * side, z = z - nz * lat * side, rot = facing(nx * side, nz * side) }
				end
				s = s + fam.step
			end
			lists[#lists + 1] = list
		end)
		local out = {}
		local k = 1
		local more = true
		while more do
			more = false
			for _, list in ipairs(lists) do
				if list[k] then
					out[#out + 1] = list[k]
					more = true
				end
			end
			k = k + 1
		end
		return out
	end
	local function candPathSign(fam)
		local out = {}
		local byName = {}
		for _, p in ipairs(M2.paths or {}) do
			byName[p.name] = p
		end
		for _, name in ipairs(data.signPaths or {}) do
			local p = byName[name]
			if p then
				local half = p.kind == "dirt" and M2.dirtHalf or M2.pathHalf
				local total = 0
				for k = 1, #p.pts - 1 do
					total = total + dist(p.pts[k][1], p.pts[k][2], p.pts[k + 1][1], p.pts[k + 1][2])
				end
				local s = 0
				local found = nil
				while s <= total do
					local x, z = pathPoint(p.pts, s)
					if x and dist(x, z, pl.x, pl.z) >= fam.signAfter then
						found = s
						break
					end
					s = s + 2
				end
				-- premier point hors de la place puis plusieurs points plus loin (au cas où le premier soit occupé) : un seul panneau par chemin est retenu
				for _, extra in ipairs({ 0, 10, 20, 32, 46 }) do
					if found and found + extra <= total then
						local x, z, nx, nz = pathPoint(p.pts, found + extra)
						local lat = half + fam.r + 2.5
						for _, side in ipairs({ 1, -1 }) do
							out[#out + 1] = { x = x + nx * lat * side, z = z + nz * lat * side, rot = facing(-nx * side, -nz * side), group = name, label = (data.signLabels or {})[name] or name }
						end
					end
				end
			end
		end
		return out
	end
	local function lakeRound(fam, fi, ringFn, perLake)
		local lists = {}
		for li, lk in ipairs(M2.lakes or {}) do
			local list = {}
			for k = 1, perLake do
				local a = math.rad((k * 137.508 + li * 53 + fi * 19) % 360)
				local rad = ringFn(lk, k)
				list[#list + 1] = { x = lk.x + math.cos(a) * rad, z = lk.z + math.sin(a) * rad, rot = (k * 47 + li * 90) % 360, group = "lake" .. li }
			end
			lists[#lists + 1] = list
		end
		local out = {}
		for k = 1, perLake do
			for _, list in ipairs(lists) do
				out[#out + 1] = list[k]
			end
		end
		return out
	end
	local function candLakeShore(fam, fi)
		return lakeRound(fam, fi, function(lk)
			return lk.r + num(lk.shore, 5) * 0.55
		end, 60)
	end
	local function candLakeWater(fam, fi)
		return lakeRound(fam, fi, function(lk, k)
			return (lk.r - 6) * (0.25 + ((k * 13) % 17) / 17 * 0.75)
		end, 70)
	end
	local function candLakeIsle(fam, fi)
		local out = {}
		for li, lk in ipairs(M2.lakes or {}) do
			-- à l'opposé du ponton de ce lac, puis autres directions
			local base = 0
			for _, dk in ipairs(G.docks or {}) do
				if dk.lake == li then
					local dx, dz = lk.x - dk.ax, lk.z - dk.az
					local d = math.sqrt(dx * dx + dz * dz)
					if d > 0 then
						base = math.deg(math.atan(dz / (dx == 0 and 1e-9 or dx))) + (dx < 0 and 180 or 0)
					end
				end
			end
			for k = 0, 11 do
				local a = math.rad(base + k * 30)
				local off = lk.r * (k < 6 and 0.3 or 0.15)
				out[#out + 1] = { x = lk.x + math.cos(a) * off, z = lk.z + math.sin(a) * off, rot = (li * 70 + k * 40) % 360, group = "lake" .. li }
			end
		end
		return out
	end

	local function addSlot(fam, f, c, y)
		local s = { fam = fam, x = c.x, z = c.z, y = y, rot = c.rot or 0, r = f.r, label = c.label, group = c.group }
		slots[#slots + 1] = s
		byFam[fam] = byFam[fam] or {}
		byFam[fam][#byFam[fam] + 1] = s
		return s
	end

	local function placeFamily(famName, f, fi, candidates, freeFn, yFn)
		local want = num(f.count, 0)
		local got = 0
		local doneGroup = {}
		for _, c in ipairs(candidates) do
			if got >= want then
				break
			end
			if not (c.group and f.zone == "pathSign" and doneGroup[c.group]) and freeFn(c.x, c.z, f.r, num(f.gap, 2)) then
				addSlot(famName, f, c, yFn(c.x, c.z))
				got = got + 1
				if c.group and f.zone == "pathSign" then
					doneGroup[c.group] = true
				end
			end
		end
	end

	---------------------------------------------------------------- ancres (superposition d'un élément procédural)
	local function anchorHall(famName, f)
		local hl = M2.hall
		if not hl then
			return
		end
		local s = { fam = famName, x = hl.x, z = hl.z, y = num(f.y0, 0), rot = 0, r = hl.r, anchor = true, length = hl.r * 2 + num(f.spanPad, 0), hide = f.hide }
		slots[#slots + 1] = s
		byFam[famName] = { s }
	end
	local function anchorEgg(famName, f)
		local E = M2.bigEgg
		if not E then
			return
		end
		local s = { fam = famName, x = E.x, z = E.z, y = num(f.y0, 0), rot = facing(pl.x - E.x, pl.z - E.z), r = num(E.r, 22), anchor = true, height = num(E.h, 16), hide = f.hide }
		slots[#slots + 1] = s
		byFam[famName] = { s }
	end
	local function anchorArena(famName, f)
		local A = M2.arena
		if not A then
			return
		end
		local ex, ez = A.entry and (A.entry.x - A.x) or 0, A.entry and (A.entry.z - A.z) or 0
		local s = { fam = famName, x = A.x, z = A.z, y = num(f.y0, 0), rot = facing(ex, ez), r = A.r, anchor = true, length = A.r * 2, hide = f.hide }
		slots[#slots + 1] = s
		byFam[famName] = { s }
	end
	-- Tapis : tuiles en `lanes` rangées + pièce de bout ; ignoré si le disque du kiosque touche le rectangle du tapis.
	local function anchorBelt(famName, f)
		local B = M2.belt
		local d = f.dims
		if not (B and d and num(d[1], 0) > 0 and num(d[2], 0) > 0 and num(d[3], 0) > 0) then
			return
		end
		local len = B.x1 - B.x0
		local rc = { x0 = B.x0, x1 = B.x1, z0 = B.z - B.width / 2, z1 = B.z + B.width / 2 }
		if kiosk.r > 0 and circleRect(kiosk.x, kiosk.z, kiosk.r, rc) then
			return
		end
		local s = num(f.topY, 1.3) / d[2]
		local L, Wt = d[1] * s, d[3] * s
		local lanes = math.max(1, math.floor(B.width / Wt + 0.5))
		local n = math.max(0, math.ceil((len - L) / L - 1e-9))
		local tiles = {}
		for lane = 1, lanes do
			local lz = B.z + (lane - (lanes + 1) / 2) * Wt
			for i = 1, n do
				local sp = (len - L) / n
				tiles[#tiles + 1] = { fam = famName, x = B.x0 + sp * (i - 0.5), z = lz, rot = 0, length = L }
			end
			tiles[#tiles + 1] = { fam = f.endKey or "conveyor_end", x = B.x1 - L / 2, z = lz, rot = 0, length = L }
		end
		local slot = { fam = famName, x = (B.x0 + B.x1) / 2, z = B.z, y = 0, rot = 0, r = 0, anchor = true, tiles = tiles, hide = f.hide }
		slots[#slots + 1] = slot
		byFam[famName] = { slot }
	end

	---------------------------------------------------------------- pose des familles dans l'ordre de priorité
	local fams = data.families or {}
	for fi, famName in ipairs(data.order or {}) do
		local f = fams[famName]
		if f and not isOff(config, famName) then
			local z = f.zone
			if z == "hall" then
				anchorHall(famName, f)
			elseif z == "bigEgg" then
				anchorEgg(famName, f)
			elseif z == "arena" then
				anchorArena(famName, f)
			elseif z == "belt" then
				anchorBelt(famName, f)
			elseif z == "plazaRim" then
				placeFamily(famName, f, fi, candPlazaRim(f, fi), plazaFree, function()
					return 0
				end)
			elseif z == "stallSide" then
				placeFamily(famName, f, fi, candStallSide(f, fi), plazaFree, function()
					return 0
				end)
			elseif z == "region" then
				placeFamily(famName, f, fi, candRegion(f, fi), mapFree, function(x, zz)
					return G.groundY(x, zz)
				end)
			elseif z == "pathSide" then
				placeFamily(famName, f, fi, candPathSide(f), mapFree, function(x, zz)
					return G.groundY(x, zz)
				end)
			elseif z == "pathSign" then
				placeFamily(famName, f, fi, candPathSign(f), mapFree, function(x, zz)
					return G.groundY(x, zz)
				end)
			elseif z == "lakeShore" then
				placeFamily(famName, f, fi, candLakeShore(f, fi), shoreFree, function()
					return 0
				end)
			elseif z == "lakeWater" then
				placeFamily(famName, f, fi, candLakeWater(f, fi), waterFree, function()
					return 0
				end)
			elseif z == "lakeIsle" then
				placeFamily(famName, f, fi, candLakeIsle(f, fi), waterFree, function()
					return 0
				end)
			end
		end
	end
	return { slots = slots, byFam = byFam, kiosk = kiosk, occupied = occupied }
end

---------------------------------------------------------------- environnement Roblox (surchargeable pour les tests)
local function defaultEnv()
	local E = {}
	function E.newFolder(name, parent)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		return f
	end
	function E.destroy(inst)
		pcall(function()
			inst:Destroy()
		end)
	end
	function E.makePart(spec, parent)
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		p.Material = Enum.Material[spec.material or "SmoothPlastic"]
		local yaw = math.rad(spec.yaw or 0)
		if spec.kind == "ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(spec.d, spec.d, spec.d)
			p.CFrame = CFrame.new(spec.x, spec.y, spec.z)
		elseif spec.kind == "cyl" then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(spec.len, spec.d, spec.d)
			p.CFrame = CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, yaw, spec.lying and 0 or math.pi / 2)
		else
			p.Size = Vector3.new(spec.sx, spec.sy, spec.sz)
			p.CFrame = CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, yaw, 0)
		end
		if spec.light then
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(spec.light.color[1], spec.light.color[2], spec.light.color[3])
			l.Range = spec.light.range
			l.Brightness = spec.light.brightness
			l.Parent = p
		end
		p.Parent = parent
		return p
	end
	function E.findNamed(root, names, skip)
		local out = {}
		local ok, list = pcall(function()
			return root:GetDescendants()
		end)
		if ok and type(list) == "table" then
			for _, d in ipairs(list) do
				if names[d.Name] and d:IsA("BasePart") and not (skip and d:IsDescendantOf(skip)) then -- jamais une pièce de nos propres modèles
					out[#out + 1] = d
				end
			end
		end
		return out
	end
	function E.getTransparency(part)
		return part.Transparency
	end
	function E.setTransparency(part, v)
		pcall(function()
			part.Transparency = v
		end)
	end
	function E.label(model, text)
		pcall(function()
			local anchor = nil
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					anchor = anchor or d
					if d.Position.Y > anchor.Position.Y then
						anchor = d
					end
				end
			end
			if not anchor then
				return
			end
			local g = Instance.new("BillboardGui")
			g.Name = "DecorLabel"
			g.Adornee = anchor
			g.Size = UDim2.fromOffset(200, 44)
			g.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
			g.MaxDistance = 70
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.GothamBold
			t.TextSize = 20
			t.TextColor3 = Color3.fromRGB(255, 240, 200)
			t.TextStrokeTransparency = 0.4
			t.Text = text
			t.Parent = g
			g.Parent = anchor
		end)
	end
	function E.yield()
		task.wait()
	end
	return E
end

local function mergeEnv(over)
	local E = defaultEnv()
	if type(over) == "table" then
		for k, v in pairs(over) do
			E[k] = v
		end
	end
	return E
end

---------------------------------------------------------------- replis procéduraux (Parts de base ; 1 à 5 Parts par exemplaire)
-- Chaque repli reçoit c (c.box / c.ball / c.cyl en coordonnées locales de l'exemplaire), la famille f et ses paramètres f.fb ; retourne rien (c.n compte les Parts).
local WOOD, WOOD2, STONE, LEAF = { 140, 100, 62 }, { 110, 76, 46 }, { 150, 146, 140 }, { 84, 150, 70 }
local FB = {}

function FB.tree(c, f)
	local h = f.height or 10
	local p = f.fb
	local trunk = p.trunk or WOOD2
	if p.shape == "none" then
		c.cyl("DecorTrunk", 0, h * 0.45, 0, h * 0.14, h * 0.9, trunk, "Wood")
		c.box("DecorBranch", h * 0.12, h * 0.72, 0, h * 0.34, h * 0.06, h * 0.06, trunk, "Wood")
		return
	end
	c.cyl("DecorTrunk", 0, h * 0.22, 0, h * 0.13, h * 0.44, trunk, "Wood")
	if p.shape == "cone" then
		c.ball("DecorLeaf", 0, h * 0.5, 0, h * 0.62, p.leaf or LEAF, "Grass")
		c.ball("DecorLeaf", 0, h * 0.8, 0, h * 0.4, p.leaf or LEAF, "Grass")
	else
		c.ball("DecorLeaf", 0, h * 0.62, 0, h * 0.7, p.leaf or LEAF, "Grass")
	end
end
function FB.stump(c, f)
	local h = f.height or 2
	c.cyl("DecorStump", 0, h / 2, 0, h * 1.1, h, WOOD2, "Wood")
end
function FB.log(c, f)
	local l = f.length or 6
	c.cyl("DecorLog", 0, l * 0.13, 0, l * 0.26, l, WOOD2, "Wood", true)
end
function FB.rock(c, f)
	local l = f.length or 8
	c.ball("DecorRock", 0, l * 0.18, 0, l * 0.4, STONE, "Slate")
	c.ball("DecorRock", l * 0.22, l * 0.12, l * 0.1, l * 0.28, { 134, 130, 124 }, "Slate")
	c.ball("DecorRock", -l * 0.2, l * 0.1, -l * 0.12, l * 0.24, { 160, 156, 148 }, "Slate")
end
function FB.bench(c, f)
	local h = f.height or 2.5
	c.box("DecorSeat", 0, h * 0.4, 0, h * 1.9, h * 0.12, h * 0.55, WOOD, "WoodPlanks")
	c.box("DecorBack", 0, h * 0.7, h * 0.22, h * 1.9, h * 0.4, h * 0.1, WOOD, "WoodPlanks")
	c.box("DecorLeg", -h * 0.8, h * 0.2, 0, h * 0.12, h * 0.4, h * 0.45, WOOD2, "Wood")
	c.box("DecorLeg", h * 0.8, h * 0.2, 0, h * 0.12, h * 0.4, h * 0.45, WOOD2, "Wood")
end
function FB.flowerbed(c, f)
	local h = f.height or 1.2
	c.box("DecorBed", 0, h * 0.25, 0, 4.4, h * 0.5, 2.4, { 120, 86, 58 }, "Wood")
	c.ball("DecorFlower", -1.3, h * 0.7, 0, 1, { 232, 96, 120 }, "SmoothPlastic")
	c.ball("DecorFlower", 0, h * 0.75, 0.2, 1, { 250, 220, 90 }, "SmoothPlastic")
	c.ball("DecorFlower", 1.3, h * 0.7, 0, 1, { 170, 120, 230 }, "SmoothPlastic")
end
function FB.well(c, f)
	local h = f.height or 5
	c.cyl("DecorWellBase", 0, h * 0.2, 0, h * 0.55, h * 0.4, STONE, "Cobblestone")
	c.box("DecorWellPost", -h * 0.22, h * 0.55, 0, h * 0.06, h * 0.7, h * 0.06, WOOD2, "Wood")
	c.box("DecorWellPost", h * 0.22, h * 0.55, 0, h * 0.06, h * 0.7, h * 0.06, WOOD2, "Wood")
	c.box("DecorWellRoof", 0, h * 0.95, 0, h * 0.62, h * 0.08, h * 0.5, { 160, 80, 60 }, "Wood")
end
function FB.lantern(c, f)
	local h = f.height or 6.5
	c.cyl("DecorLampPost", 0, h * 0.45, 0, h * 0.07, h * 0.9, { 58, 58, 66 }, "Metal")
	c.ball("DecorLampGlow", 0, h * 0.95, 0, h * 0.16, { 255, 214, 130 }, "Neon", { color = { 255, 214, 140 }, range = 16, brightness = 0.8 })
end
function FB.stall(c, f)
	local h = f.height or 8
	local aw = f.fb.awning or { 214, 90, 80 }
	c.box("DecorStallCounter", 0, h * 0.18, 0, h * 1.1, h * 0.36, h * 0.35, WOOD, "WoodPlanks")
	c.box("DecorStallPost", -h * 0.5, h * 0.45, h * 0.32, h * 0.06, h * 0.9, h * 0.06, WOOD2, "Wood")
	c.box("DecorStallPost", h * 0.5, h * 0.45, h * 0.32, h * 0.06, h * 0.9, h * 0.06, WOOD2, "Wood")
	c.box("DecorStallAwning", 0, h * 0.92, 0, h * 1.25, h * 0.05, h * 0.9, aw, "Fabric")
end
function FB.crates(c, f)
	local h = f.height or 2.6
	c.box("DecorCrate", 0, h * 0.25, 0, h * 0.5, h * 0.5, h * 0.5, WOOD, "WoodPlanks")
	c.box("DecorCrate", h * 0.4, h * 0.2, h * 0.1, h * 0.4, h * 0.4, h * 0.4, { 170, 126, 80 }, "WoodPlanks")
	c.box("DecorCrate", h * 0.1, h * 0.65, 0, h * 0.4, h * 0.4, h * 0.4, WOOD2, "WoodPlanks")
end
function FB.barrels(c, f)
	local h = f.height or 2.4
	c.cyl("DecorBarrel", -h * 0.3, h * 0.5, 0, h * 0.6, h, WOOD2, "Wood")
	c.cyl("DecorBarrel", h * 0.3, h * 0.5, 0, h * 0.6, h, WOOD, "Wood")
end
function FB.hay(c, f)
	local h = f.height or 2.2
	c.cyl("DecorHay", 0, h * 0.5, 0, h, h * 1.2, { 224, 190, 96 }, "Fabric", true)
end
function FB.bush(c, f)
	local h = f.height or 2.4
	c.ball("DecorBush", 0, h * 0.4, 0, h * 0.8, { 64, 130, 66 }, "Grass")
	c.ball("DecorBush", h * 0.3, h * 0.3, h * 0.1, h * 0.6, { 76, 148, 74 }, "Grass")
end
function FB.sign(c, f)
	local h = f.height or 4.5
	c.cyl("DecorSignPost", 0, h * 0.4, 0, h * 0.08, h * 0.8, WOOD2, "Wood")
	c.box("DecorSignBoard", 0, h * 0.78, 0, h * 0.8, h * 0.28, h * 0.05, WOOD, "WoodPlanks")
end
function FB.flag(c, f)
	local h = f.height or 7
	c.cyl("DecorFlagPole", 0, h * 0.5, 0, h * 0.04, h, { 200, 196, 188 }, "Metal")
	c.box("DecorFlag", h * 0.14, h * 0.85, 0, h * 0.24, h * 0.22, h * 0.02, { 214, 80, 70 }, "Fabric")
end
function FB.reeds(c, f)
	local h = f.height or 4
	c.box("DecorReed", 0, h * 0.5, 0, h * 0.05, h, h * 0.05, { 120, 150, 70 }, "Grass")
	c.box("DecorReed", h * 0.12, h * 0.4, h * 0.05, h * 0.05, h * 0.8, h * 0.05, { 110, 140, 64 }, "Grass")
	c.box("DecorReed", -h * 0.1, h * 0.45, -h * 0.06, h * 0.05, h * 0.9, h * 0.05, { 130, 158, 76 }, "Grass")
end
function FB.lily(c, f)
	local l = f.length or 1.6
	c.cyl("DecorLily", 0, 0.05, 0, l, 0.1, { 70, 150, 80 }, "Grass")
end
function FB.isle(c, f)
	local l = f.length or 16
	c.cyl("DecorIsle", 0, 0.4, 0, l, 0.8, { 214, 190, 140 }, "Sand")
	c.cyl("DecorIsleTrunk", 0, 2, 0, 0.9, 4, WOOD2, "Wood")
	c.ball("DecorIsleBloom", 0, 5, 0, l * 0.5, { 244, 170, 196 }, "Grass")
end

-- Contexte de construction d'un repli : coordonnées locales -> monde (rotation Y de l'exemplaire).
local function fallbackCtx(slot, folder, env)
	local rot = math.rad(slot.rot or 0)
	local cs, sn = math.cos(rot), math.sin(rot)
	local c = { n = 0, parts = {} }
	local function world(ox, oy, oz)
		return slot.x + ox * cs + oz * sn, (slot.y or 0) + oy, slot.z - ox * sn + oz * cs
	end
	local function emit(spec)
		local ok, p = pcall(env.makePart, spec, folder)
		if ok then
			c.n = c.n + 1
			c.parts[#c.parts + 1] = p
		end
	end
	function c.box(name, ox, oy, oz, sx, sy, sz, color, mat)
		local x, y, z = world(ox, oy, oz)
		emit({ kind = "box", name = name, x = x, y = y, z = z, yaw = slot.rot, sx = sx, sy = sy, sz = sz, color = color, material = mat })
	end
	function c.ball(name, ox, oy, oz, d, color, mat, light)
		local x, y, z = world(ox, oy, oz)
		emit({ kind = "ball", name = name, x = x, y = y, z = z, d = d, color = color, material = mat, light = light })
	end
	function c.cyl(name, ox, oy, oz, d, len, color, mat, lying)
		local x, y, z = world(ox, oy, oz)
		emit({ kind = "cyl", name = name, x = x, y = y, z = z, yaw = slot.rot, d = d, len = len, color = color, material = mat, lying = lying })
	end
	return c
end

-- Nombre de Parts d'un repli (mesuré en le construisant dans un contexte à blanc).
local function fallbackCost(f)
	local builder = f.fb and FB[f.fb.name]
	if not builder then
		return 0
	end
	local n = 0
	local c = { n = 0 }
	local function count()
		n = n + 1
	end
	c.box, c.ball, c.cyl = count, count, count
	builder(c, f)
	return n
end
Decor.fallbackCost = fallbackCost

---------------------------------------------------------------- construction
local function key(data, famName)
	return (data.keyPrefix or "m:decor.") .. famName
end

local function say(deps, msg)
	if deps and deps.warn then
		pcall(deps.warn, msg)
	end
end

-- Charge les modèles manquants (lots parallèles, délai, un nouvel essai : Assets.loadMany). Un modèle déjà connu (chargé ou refusé) n'est pas redemandé.
-- Retourne le nombre de modèles utilisables parmi les familles du plan.
function Decor.load(assets, data, config, planned)
	if not assets or not assets.loadMany or (config.Assets and config.Assets.Enabled ~= true) then
		return 0
	end
	local entries, seen = {}, {}
	local function want(famName)
		local f = data.families[famName]
		if f and not seen[famName] and not isOff(config, famName) then
			seen[famName] = true
			local k = key(data, famName)
			if assets.status and assets.status[k] == nil then
				if validId(f.id) then
					entries[#entries + 1] = { key = k, id = f.id, cap = f.cap }
				else
					assets.status[k] = { ok = false, reason = "ID invalide" }
				end
			end
		end
	end
	for famName, list in pairs(planned.byFam) do
		want(famName)
		for _, s in ipairs(list) do
			for _, t in ipairs(s.tiles or {}) do
				want(t.fam)
			end
		end
	end
	table.sort(entries, function(a, b)
		return a.key < b.key
	end)
	local loaded = 0
	if #entries > 0 then
		pcall(assets.loadMany, entries)
	end
	for famName in pairs(seen) do
		local st = assets.status and assets.status[key(data, famName)]
		if st and st.ok then
			loaded = loaded + 1
		end
	end
	return loaded
end

function Decor.clear(handle)
	if not handle or handle.cleared then
		return
	end
	handle.cleared = true
	for _, h in ipairs(handle.hidden or {}) do
		pcall(handle.env.setTransparency, h.part, h.orig)
	end
	handle.hidden = {}
	if handle.folder then
		pcall(handle.env.destroy, handle.folder)
		handle.folder = nil
	end
	handle.items = {}
	if handle.parent and current[handle.parent] == handle then
		current[handle.parent] = nil
	end
end

-- Construit le décor dans parent ; retourne le handle { folder, items, used, fallbackUsed, byFamily, lines, loaded, error }. Ne lève jamais d'erreur.
function Decor.build(parent, G, config, deps)
	deps = deps or {}
	local env = mergeEnv(deps.env)
	local handle = { parent = parent, geo = G, config = config, deps = deps, env = env, items = {}, hidden = {}, byFamily = {}, lines = {}, used = 0, fallbackUsed = 0, loaded = 0 }
	local ok, err = pcall(function()
		local data = loadData(deps)
		handle.data = data
		local prev = current[parent]
		if prev then
			Decor.clear(prev)
		end
		-- reste éventuel d'un décor précédent non suivi (rechargement du module)
		if parent and parent.FindFirstChild then
			local old = parent:FindFirstChild(FOLDER_NAME)
			if old then
				env.destroy(old)
			end
		end
		deps.yield = deps.yield or env.yield
		current[parent] = handle -- annonce la construction en cours : un build ou un clear concurrent (le plan et le chargement cèdent la main) l'annule
		local plan = Decor.plan(G, config, data, deps)
		handle.plan = plan
		local blenderMax, fallbackMax = budgets(config, data)
		handle.budget = { blender = blenderMax, fallback = fallbackMax }
		local assets = deps.assets
		if handle.cleared then
			return
		end
		if assets and not deps.skipLoad then
			handle.loaded = Decor.load(assets, data, config, plan)
		end
		if handle.cleared then
			return -- remplacé ou nettoyé pendant le chargement : rien n'est créé
		end
		local folder = env.newFolder(FOLDER_NAME, parent)
		handle.folder = folder

		local famUsed = {}
		local function bump(famName, field)
			local b = handle.byFamily[famName]
			if not b then
				b = { model = 0, fallback = 0, wanted = 0 }
				handle.byFamily[famName] = b
			end
			b[field] = (b[field] or 0) + 1
		end
		local function statusOf(famName)
			local st = assets and assets.status and assets.status[key(data, famName)]
			if st and st.ok and type(st.parts) == "number" then
				return st
			end
			return nil
		end
		local function share(famName)
			local f = data.families[famName]
			return math.floor(blenderMax * num(f and f.share, 0) + 1e-9)
		end
		-- pose un modèle ; retourne (nombre de Parts, clone) ou nil
		local function putModel(famName, x, z, y, rot, height, length, label)
			if not assets or not assets.cloneModel or not assets.place then
				return nil
			end
			local clone = assets.cloneModel("decor", famName)
			if not clone then
				return nil
			end
			pcall(function()
				clone.Name = "Decor_" .. famName
			end)
			local placed, count = assets.place(clone, x, z, rot, height, folder, length, y)
			if not placed then
				return nil
			end
			if label and env.label then
				env.label(clone, label)
			end
			return num(count, 0), clone
		end

		for _, famName in ipairs(data.order) do
			local f = data.families[famName]
			local list = plan.byFam[famName]
			if f and list then
				for _, s in ipairs(list) do
					handle.byFamily[famName] = handle.byFamily[famName] or { model = 0, fallback = 0, wanted = 0 }
					handle.byFamily[famName].wanted = handle.byFamily[famName].wanted + 1
					if s.anchor then
						-- ancre : tout ou rien (modèle posé -> élément procédural masqué ; sinon il reste)
						local tiles = s.tiles
						local needs = tiles or { { fam = famName, x = s.x, z = s.z, rot = s.rot, length = s.length } }
						local cost, allOk = 0, true
						for _, t in ipairs(needs) do
							local st = statusOf(t.fam)
							if not st then
								allOk = false
							else
								cost = cost + st.parts
							end
						end
						if allOk and cost <= share(famName) and handle.used + cost <= blenderMax then
							local clones, spent = {}, 0
							for _, t in ipairs(needs) do
								local y = s.y or 0
								local height = nil
								if not tiles then
									height = s.height
								end
								local count, clone = putModel(t.fam, t.x, t.z, y, t.rot, height, t.length or s.length, nil)
								if count then
									spent = spent + count
									clones[#clones + 1] = clone
								else
									allOk = false
									break
								end
							end
							if allOk then
								handle.used = handle.used + spent
								famUsed[famName] = (famUsed[famName] or 0) + spent
								bump(famName, "model")
								handle.items[#handle.items + 1] = { fam = famName, x = s.x, z = s.z, r = s.r, mode = "model", anchor = true }
								local names = {}
								for _, nme in ipairs(s.hide or {}) do
									names[nme] = true
								end
								local root = deps.root or (parent and parent.Parent) or parent
								for _, part in ipairs(env.findNamed(root, names, folder)) do
									local okT, orig = pcall(env.getTransparency, part)
									if okT and type(orig) == "number" then
										handle.hidden[#handle.hidden + 1] = { part = part, orig = orig }
										env.setTransparency(part, 1)
									end
								end
							else
								-- retour en arrière : aucun morceau posé ne reste, l'élément procédural est conservé
								for _, clone in ipairs(clones) do
									env.destroy(clone)
								end
								handle.lines[#handle.lines + 1] = "[Decor] ancre " .. famName .. " : pose partielle annulée, élément procédural conservé"
							end
						end
					else
						local placed = false
						local st = statusOf(famName)
						if st and st.parts <= share(famName) - (famUsed[famName] or 0) and handle.used + st.parts <= blenderMax then
							local jit = 1
							if f.zone == "region" or f.zone == "pathSide" then
								jit = 0.9 + ((math.abs(math.sin(s.x * 12.9898 + s.z * 78.233) * 43758.5453)) % 1) * 0.2
							end
							local count = putModel(famName, s.x, s.z, (s.y or 0) + num(f.y0, 0), s.rot, f.height and f.height * jit or nil, f.length and f.length * jit or nil, s.label)
							if count then
								handle.used = handle.used + count
								famUsed[famName] = (famUsed[famName] or 0) + count
								bump(famName, "model")
								handle.items[#handle.items + 1] = { fam = famName, x = s.x, z = s.z, r = s.r, mode = "model" }
								placed = true
							end
						end
						if not placed and f.fb and FB[f.fb.name] then
							local fcost = fallbackCost(f)
							local fb = handle.byFamily[famName]
							if fcost > 0 and (fb.fallback or 0) < num(f.fbMax, 0) and handle.fallbackUsed + fcost <= fallbackMax then
								local c = fallbackCtx({ x = s.x, z = s.z, y = (s.y or 0) + num(f.y0, 0), rot = s.rot }, folder, env)
								FB[f.fb.name](c, f)
								if s.label and c.parts[1] and env.label then
									-- le panneau de repli porte aussi son libellé (BillboardGui sur sa dernière pièce)
									pcall(env.label, { GetDescendants = function()
										return c.parts
									end }, s.label)
								end
								handle.fallbackUsed = handle.fallbackUsed + c.n
								bump(famName, "fallback")
								handle.items[#handle.items + 1] = { fam = famName, x = s.x, z = s.z, r = s.r, mode = "fallback", parts = c.n }
							end
						end
					end
				end
			end
		end
		-- journal (une ligne par famille ayant des exemplaires voulus)
		for _, famName in ipairs(data.order) do
			local f = data.families[famName]
			local slotsOf = plan.byFam[famName]
			if f and num(f.count, 0) > 0 and (not slotsOf or #slotsOf < f.count) and not isOff(config, famName) then
				handle.lines[#handle.lines + 1] = ("[Decor] %s : %d emplacement(s) libre(s) sur %d voulu(s)"):format(famName, slotsOf and #slotsOf or 0, f.count)
			end
			local b = handle.byFamily[famName]
			if b then
				handle.lines[#handle.lines + 1] = ("[Decor] %s : %d modèle(s), %d repli(s) sur %d voulu(s)"):format(famName, b.model, b.fallback, b.wanted)
			end
		end
		handle.lines[#handle.lines + 1] = ("[Decor] Parts Blender %d/%d, Parts de repli %d/%d"):format(handle.used, blenderMax, handle.fallbackUsed, fallbackMax)
	end)
	if not ok then
		handle.error = tostring(err)
		say(deps, "[Decor] erreur : " .. handle.error .. " : décor partiel retiré")
		Decor.clear(handle)
	end
	return handle
end

-- Reconstruit avec les mêmes arguments (hook onAssetsLoaded : les modèles arrivés remplacent les replis ; un modèle déjà connu n'est jamais redemandé).
function Decor.refresh(handle)
	if not handle or not handle.parent then
		return nil
	end
	local deps = handle.deps or {}
	Decor.clear(handle)
	return Decor.build(handle.parent, handle.geo, handle.config, deps)
end

return Decor
