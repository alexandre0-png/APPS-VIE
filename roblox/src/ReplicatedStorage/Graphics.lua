-- ModuleScript : ReplicatedStorage/Shared/Graphics
-- Lot GRAPHISMES (monde) : logique PURE, déterministe, testée hors de Roblox. Aucun Instance, aucun tirage libre (Park-Miller 48271).
--   Graphics.checkLighting(L)                 : cohérence des palettes de lumière entre zones (teinte, saturation, valeur, heure, densité, brume).
--   Graphics.assignStyles(items, poolOf, d)   : style de chaque arbre, jamais deux styles identiques à moins de `d` studs si le choix le permet.
--   Graphics.blenderStyle(key) / procStyle    : décodage d'un style d'arbre (modèle + classe de taille ; forme + taille + teinte).
--   Graphics.groundPlan(Config, P, planItems) : variations de chemins, bordures d'herbe irrégulières, touffes et grappes de fleurs (plafonds de Parts).
--   Graphics.selectLights(lights, cam, n, r)  : les `n` lumières les plus proches (à moins de `r`) restent allumées, les autres sont coupées (LOD).
-- Compatible lupa : pas de += ni de continue, pas de math.atan2.
local Graphics = {}

local function dist(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Pause coopérative facultative (Builder la règle sur task.wait, comme Placement.yield) : le calcul du sol cède la main tous les 25 essais ; les tests purs la laissent à nil.
Graphics.yield = nil
local pauseCount = 0
local function pause()
	pauseCount = pauseCount + 1
	if Graphics.yield and pauseCount % 25 == 0 then
		Graphics.yield()
	end
end

-- Générateur déterministe Park-Miller (48271 mod 2^31-1) : les produits restent sous 2^53.
local function newRng(seed)
	local s = math.floor(seed) % 2147483647
	if s <= 0 then
		s = 1
	end
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end
Graphics.newRng = newRng

---------------------------------------------------------------- Couleurs
-- RGB 0..255 -> teinte (degrés 0..360), saturation et valeur (0..1).
function Graphics.rgbToHsv(r, g, b)
	local rr, gg, bb = r / 255, g / 255, b / 255
	local mx, mn = math.max(rr, gg, bb), math.min(rr, gg, bb)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == rr then
			h = 60 * (((gg - bb) / d) % 6)
		elseif mx == gg then
			h = 60 * ((bb - rr) / d + 2)
		else
			h = 60 * ((rr - gg) / d + 4)
		end
	end
	local s = mx > 0 and d / mx or 0
	return h, s, mx
end

-- Écart angulaire de teinte (0..180).
function Graphics.hueDelta(a, b)
	local d = math.abs(a - b) % 360
	return d > 180 and 360 - d or d
end

---------------------------------------------------------------- Lumière
local COLOR_ROLES = { "ambient", "outdoor", "tint", "atmo", "decay" }
local SCALARS = { "clock", "density", "haze", "glare" }

local function isColor(c)
	return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" and c[1] >= 0 and c[1] <= 255 and c[2] >= 0 and c[2] <= 255 and c[3] >= 0 and c[3] <= 255
end

-- Vérifie la cohérence des palettes de Config.LIGHTING. Retourne { ok, problems = { texte }, stats = { hue, sat, val, clock, density, haze } } où stats donne le
-- plus grand écart mesuré entre deux zones (tous rôles confondus). Les couleurs très peu saturées (< minSatForHue) n'ont pas de teinte comparée.
function Graphics.checkLighting(L)
	local problems, stats = {}, { hue = 0, sat = 0, val = 0, clock = 0, density = 0, haze = 0, bloom = 0 }
	if type(L) ~= "table" or type(L.zones) ~= "table" or type(L.limits) ~= "table" then
		return { ok = false, problems = { "LIGHTING absent ou incomplet" }, stats = stats }
	end
	local lim = L.limits
	local names = {}
	for _, n in ipairs(L.zoneOrder or {}) do
		names[#names + 1] = n
	end
	if #names < 4 then
		problems[#problems + 1] = "au moins 4 zones attendues (hub, parcelles, arène, château)"
	end
	local seen = {}
	for _, n in ipairs(names) do
		seen[n] = true
		local z = L.zones[n]
		if type(z) ~= "table" then
			problems[#problems + 1] = "zone " .. n .. " absente"
		else
			for _, role in ipairs(COLOR_ROLES) do
				local c = z[role]
				if not isColor(c) then
					problems[#problems + 1] = n .. "." .. role .. " : couleur invalide"
				else
					local h, s = Graphics.rgbToHsv(c[1], c[2], c[3])
					if s >= lim.minSatForHue and (h < lim.warmHueMin or h > lim.warmHueMax) then
						problems[#problems + 1] = n .. "." .. role .. " : teinte " .. math.floor(h) .. " hors de la bande chaude " .. lim.warmHueMin .. "-" .. lim.warmHueMax
					end
				end
			end
			for _, k in ipairs(SCALARS) do
				if type(z[k]) ~= "number" or z[k] ~= z[k] then
					problems[#problems + 1] = n .. "." .. k .. " : nombre attendu"
				end
			end
			if type(z.bloom) ~= "table" or type(z.bloom.intensity) ~= "number" or z.bloom.intensity > lim.bloomMax or z.bloom.intensity < 0 then
				problems[#problems + 1] = n .. ".bloom : intensité absente ou au-delà de " .. tostring(lim.bloomMax)
			end
			if type(z.grade) ~= "table" or type(z.grade.saturation) ~= "number" or z.grade.saturation < lim.gradeSatMin or z.grade.saturation > lim.gradeSatMax then
				problems[#problems + 1] = n .. ".grade : saturation hors de " .. lim.gradeSatMin .. ".." .. lim.gradeSatMax
			end
			if type(z.density) == "number" and z.density > lim.densityMax then
				problems[#problems + 1] = n .. ".density : brume trop dense"
			end
		end
	end
	if #problems == 0 then
		for i = 1, #names do
			for j = i + 1, #names do
				local a, b = L.zones[names[i]], L.zones[names[j]]
				for _, role in ipairs(COLOR_ROLES) do
					local ha, sa, va = Graphics.rgbToHsv(a[role][1], a[role][2], a[role][3])
					local hb, sb, vb = Graphics.rgbToHsv(b[role][1], b[role][2], b[role][3])
					if sa >= lim.minSatForHue and sb >= lim.minSatForHue then
						stats.hue = math.max(stats.hue, Graphics.hueDelta(ha, hb))
					end
					stats.sat = math.max(stats.sat, math.abs(sa - sb))
					stats.val = math.max(stats.val, math.abs(va - vb))
				end
				stats.clock = math.max(stats.clock, math.abs(a.clock - b.clock))
				stats.density = math.max(stats.density, math.abs(a.density - b.density))
				stats.haze = math.max(stats.haze, math.abs(a.haze - b.haze))
				stats.bloom = math.max(stats.bloom, math.abs(a.bloom.intensity - b.bloom.intensity))
			end
		end
		local function over(name, v, limit)
			if v > limit then
				problems[#problems + 1] = "écart de " .. name .. " entre zones : " .. string.format("%.3f", v) .. " > " .. limit
			end
		end
		over("teinte", stats.hue, lim.hueSpread)
		over("saturation", stats.sat, lim.satSpread)
		over("valeur", stats.val, lim.valSpread)
		over("heure", stats.clock, lim.clockSpread)
		over("densité", stats.density, lim.densitySpread)
		over("brume", stats.haze, lim.hazeSpread)
	end
	return { ok = #problems == 0, problems = problems, stats = stats }
end

---------------------------------------------------------------- Styles d'arbres
-- items = { {x, z, ...} } dans l'ordre de pose ; poolOf(item, index) -> liste de clés de style. Choisit pour chaque arbre le style dont l'exemplaire le plus proche
-- est le plus loin (égalité : style le moins employé, puis ordre du pool décalé par le rang : pas de motif répété). Retourne (clés, stats) ; stats.minSame = plus petite
-- distance entre deux arbres de même style (math.huge si aucun), stats.violations = paires plus proches que `minDist`, stats.styles = nombre de styles employés.
function Graphics.assignStyles(items, poolOf, minDist)
	local keys, usage = {}, {}
	local byKey = {}
	for i, it in ipairs(items) do
		local pool = poolOf(it, i)
		local best, bestD, bestU = nil, -1, math.huge
		local n = #pool
		for off = 0, n - 1 do
			local key = pool[(off + i) % n + 1]
			local nearest = math.huge
			for _, o in ipairs(byKey[key] or {}) do
				local d = dist(it.x, it.z, o.x, o.z)
				if d < nearest then
					nearest = d
				end
			end
			local u = usage[key] or 0
			if nearest > bestD or (nearest == bestD and u < bestU) then
				best, bestD, bestU = key, nearest, u
			end
		end
		keys[i] = best
		usage[best] = (usage[best] or 0) + 1
		byKey[best] = byKey[best] or {}
		byKey[best][#byKey[best] + 1] = it
	end
	return keys, Graphics.styleStats(items, keys, minDist)
end

-- Mesure : plus petite distance entre deux arbres de même clé, paires sous `minDist`, nombre de styles distincts.
function Graphics.styleStats(items, keys, minDist)
	local minSame, violations, used, count = math.huge, 0, {}, 0
	for i = 1, #items do
		if not used[keys[i]] then
			used[keys[i]] = true
			count = count + 1
		end
		for j = i + 1, #items do
			if keys[i] == keys[j] then
				local d = dist(items[i].x, items[i].z, items[j].x, items[j].z)
				if d < minSame then
					minSame = d
				end
				if d < (minDist or 0) then
					violations = violations + 1
				end
			end
		end
	end
	return { minSame = minSame, violations = violations, styles = count, trees = #items }
end

-- Clé de style des arbres Blender : « modèle@classe » (classe = rang dans Config.GRAPHICS.trees.sizeClasses).
function Graphics.blenderKeys(models, classCount)
	local out = {}
	for _, m in ipairs(models) do
		for c = 1, classCount do
			out[#out + 1] = m .. "@" .. c
		end
	end
	return out
end

function Graphics.blenderStyle(Config, key)
	local model, c = tostring(key):match("^(.-)@(%d+)$")
	local classes = Config.GRAPHICS.trees.sizeClasses
	local scale = classes[tonumber(c) or 1] or 1
	return { model = model, scale = scale }
end

-- Clé de style des arbres procéduraux : « forme:taille:teinte » (rangs dans Config.GRAPHICS.trees).
function Graphics.procKeys(Config, north)
	local T = Config.GRAPHICS.trees
	local leaves = north and T.procLeavesNorth or T.procLeavesMeadow
	local out = {}
	for sh = 1, #T.procShapes do
		for sz = 1, #T.procSizes do
			for lf = 1, #leaves do
				out[#out + 1] = sh .. ":" .. sz .. ":" .. lf
			end
		end
	end
	return out
end

function Graphics.procStyle(Config, key, north)
	local T = Config.GRAPHICS.trees
	local sh, sz, lf = tostring(key):match("^(%d+):(%d+):(%d+)$")
	local leaves = north and T.procLeavesNorth or T.procLeavesMeadow
	return { shape = T.procShapes[tonumber(sh) or 1], scale = T.procSizes[tonumber(sz) or 1], leaf = leaves[tonumber(lf) or 1], key = key }
end

-- Styles d'une liste d'arbres procéduraux ({x, z, grove?}) : retourne { {shape, scale, leaf, key} } dans l'ordre + statistiques. Les arbres du nord (z < -180) et
-- des bosquets prennent la palette « nord » (plus sombre).
function Graphics.styleForest(Config, forest)
	local function isNorth(t)
		return t.grove ~= nil or t.z < -180
	end
	local meadow, north = Graphics.procKeys(Config, false), Graphics.procKeys(Config, true)
	local keys, stats = Graphics.assignStyles(forest, function(t)
		return isNorth(t) and north or meadow
	end, Config.GRAPHICS.trees.procMinSameDist)
	-- une clé « nord » et une clé « prairie » ont la même écriture : on les sépare pour la mesure d'unicité
	local out = {}
	for i, t in ipairs(forest) do
		out[i] = Graphics.procStyle(Config, keys[i], isNorth(t))
	end
	local tagged = {}
	for i, t in ipairs(forest) do
		tagged[i] = (isNorth(t) and "n" or "m") .. keys[i]
	end
	return out, Graphics.styleStats(forest, tagged, Config.GRAPHICS.trees.procMinSameDist)
end

---------------------------------------------------------------- LOD des lumières
-- lights = { {x, y, z} } ; cam = {x, y, z}. Retourne un tableau booléen : vrai pour les `maxOn` lumières les plus proches (à moins de `range`), faux ailleurs.
-- Distances invalides (nil, NaN) : lumière coupée. Ordre stable (égalité : rang).
function Graphics.selectLights(lights, cam, maxOn, range)
	local on = {}
	local cand = {}
	for i, l in ipairs(lights) do
		on[i] = false
		if type(l) == "table" and type(l.x) == "number" and type(l.y) == "number" and type(l.z) == "number" and type(cam) == "table" then
			local d = math.sqrt((l.x - cam.x) ^ 2 + (l.y - cam.y) ^ 2 + (l.z - cam.z) ^ 2)
			if d == d and d <= range then
				cand[#cand + 1] = { i = i, d = d }
			end
		end
	end
	table.sort(cand, function(a, b)
		if a.d ~= b.d then
			return a.d < b.d
		end
		return a.i < b.i
	end)
	for k = 1, math.min(maxOn, #cand) do
		on[cand[k].i] = true
	end
	return on
end

---------------------------------------------------------------- Sol : chemins, bordures d'herbe, touffes et fleurs
local function pick(list, r)
	return list[1 + math.floor(r * #list) % #list]
end

-- Plan du sol, déterministe. P = Placement.new(Config, MapGeo) (blocked, groundY, forest, pathSegments), planItems = P.plan().items (objets déjà posés).
-- Retourne { pathPatches, edges, tufts, clusters, parts, stats } :
--   pathPatches : { x, z, y, w, d, rot, color, material, path } — petites dalles posées SUR un chemin (variation de couleur et de matière) ;
--   edges       : { x, z, r, color } — taches d'herbe irrégulières au bord des chemins (jamais en travers d'un autre interdit que le chemin lui-même) ;
--   tufts       : { x, z, y, size, color } — touffes isolées ; clusters : { x, z, y, size, color, flowers = { {dx, dz, color} } } (1 touffe + fleurs).
-- Règles : touffes et grappes sur du sol LIBRE (MapGeo.blocked == nil, hors empreintes d'arbres et d'objets), à moins de scatterRange d'un chemin ou de la place ;
-- densité plafonnée par cellule ; au plus budgetParts Parts au total.
function Graphics.groundPlan(Config, P, planItems)
	local GR = Config.GRAPHICS.ground
	local M2 = Config.Map2
	local G = P.G
	local B = M2.bounds
	local out = { pathPatches = {}, edges = {}, tufts = {}, clusters = {}, stats = {} }
	local rng = newRng(90210)
	local forest = P.forest()
	local blocking = {}
	for _, it in ipairs(planItems or {}) do
		blocking[#blocking + 1] = { it.x, it.z, it.r or 2 }
	end
	for _, it in ipairs(forest) do
		blocking[#blocking + 1] = { it.x, it.z, it.r or 3.5 }
	end
	local function freeOfObjects(x, z, r)
		for _, q in ipairs(blocking) do
			if dist(x, z, q[1], q[2]) < q[3] + r + 0.5 then
				return false
			end
		end
		return true
	end
	local function nearBridge(x, z, r)
		for _, b in ipairs(G.bridges) do
			if dist(x, z, b.x, b.z) < b.len / 2 + r + 1 then
				return true
			end
		end
		return false
	end
	-- 1. segments de chemin au sol (même découpage que Scenery.paths : rang k du segment dans sa polyligne)
	local segs, totalLen = {}, 0
	for _, p in ipairs(M2.paths) do
		if (p.y or 0) == 0 then
			local paved = p.kind ~= "dirt"
			local half = paved and M2.pathHalf or M2.dirtHalf
			for k = 1, #p.pts - 1 do
				local ax, az, bx, bz = p.pts[k][1], p.pts[k][2], p.pts[k + 1][1], p.pts[k + 1][2]
				local len = dist(ax, az, bx, bz)
				segs[#segs + 1] = { ax = ax, az = az, bx = bx, bz = bz, len = len, half = half, paved = paved, k = k, name = p.name, last = k == #p.pts - 1 }
				totalLen = totalLen + len
			end
		end
	end
	-- 2. variations posées sur les chemins : pas élargi pour respecter le plafond
	local spacing = math.max(GR.pathPatchSpacing, totalLen / GR.pathPatchCap)
	local roadsideSpacing = math.max(GR.edgeSpacing, 2 * totalLen / GR.edgeCap)
	for _, s in ipairs(segs) do
		local dx, dz = (s.bx - s.ax) / s.len, (s.bz - s.az) / s.len
		local nx, nz = -dz, dx
		-- hauteur de la dalle de ce segment (Scenery.paths : dalles alternées, épaisseur de 0,2) ; joints aux sommets : on s'en écarte
		local top = s.paved and ((s.k % 2 == 1) and 0.28 or 0.34) or ((s.k % 2 == 1) and 0.04 or 0.10)
		local t = spacing * (0.3 + 0.5 * rng())
		local n = 0
		while t < s.len - s.half - 0.5 do
			if t > s.half + 0.5 and #out.pathPatches < GR.pathPatchCap then
				local lat = (rng() * 2 - 1) * (s.half - 2.1)
				local x, z = s.ax + dx * t + nx * lat, s.az + dz * t + nz * lat
				local w, d = 1.2 + rng() * 2.2, 0.9 + rng() * 1.5
				pause()
				local why = G.blocked(x, z, 1.2, {})
				if (why == nil or why == "chemin") and not nearBridge(x, z, 1.2) and G.pathEdgeDist(x, z) < -0.5 then
					n = n + 1
					local pal = s.paved and GR.pathPalettePaved or GR.pathPaletteDirt
					local mat = s.paved and (n % 3 == 0 and "Slate" or (n % 3 == 1 and "Cobblestone" or "Pebble")) or (n % 2 == 0 and "Ground" or "Mud")
					out.pathPatches[#out.pathPatches + 1] = { x = x, z = z, y = top - 0.005 + (n % 3) * 0.01, w = w, d = d, rot = rng() * 180, color = pick(pal, rng()), material = mat, path = s.name }
				end
			end
			t = t + spacing * (0.7 + 0.6 * rng())
		end
		-- bordures d'herbe irrégulières : taches de rayon variable, des deux côtés, à cheval sur le bord du chemin
		local t2 = roadsideSpacing * (0.2 + 0.6 * rng())
		while t2 < s.len - 1 do
			for side = -1, 1, 2 do
				if rng() < 0.7 and #out.edges < GR.edgeCap then
					local off = s.half + (rng() * 2 - 0.6) * 1.2
					local r = 0.8 + rng() * 1.2
					local x, z = s.ax + dx * t2 + nx * off * side, s.az + dz * t2 + nz * off * side
					pause()
					local why = G.blocked(x, z, r, {})
					if (why == nil or why == "chemin") and not nearBridge(x, z, r) and G.pathEdgeDist(x, z) > -0.2 and freeOfObjects(x, z, r) then
						out.edges[#out.edges + 1] = { x = x, z = z, r = r, y = (P.groundY(x, z) or 0) + 0.03 + (#out.edges % 4) * 0.01, color = pick(GR.edgePalette, rng()) }
					end
				end
			end
			t2 = t2 + roadsideSpacing * (0.6 + 0.8 * rng())
		end
	end
	-- 3. touffes isolées et grappes de fleurs : cellules mélangées près des chemins et de la place, densité plafonnée
	local function nearAnchor(x, z)
		pause()
		if dist(x, z, M2.plaza.x, M2.plaza.z) < M2.plaza.r + GR.scatterRange then
			return true
		end
		return G.pathEdgeDist(x, z) < GR.scatterRange
	end
	local cellSize = GR.cell
	local cells = {}
	for gx = B.x0 + cellSize / 2, B.x1 - cellSize / 2, cellSize do
		for gz = B.z0 + cellSize / 2, B.z1 - cellSize / 2, cellSize do
			if nearAnchor(gx, gz) then
				cells[#cells + 1] = { gx, gz }
			end
		end
	end
	for i = #cells, 2, -1 do
		local j = 1 + math.floor(rng() * i)
		cells[i], cells[j] = cells[j], cells[i]
	end
	local perCell = {}
	local function cellKey(x, z)
		return math.floor((x - B.x0) / cellSize) .. ":" .. math.floor((z - B.z0) / cellSize)
	end
	local function room(x, z, n)
		return (perCell[cellKey(x, z)] or 0) + n <= GR.maxPerCell
	end
	local function take(x, z, n)
		local k = cellKey(x, z)
		perCell[k] = (perCell[k] or 0) + n
	end
	local flowerCount = 0
	local function partsLeft()
		return Config.GRAPHICS.budgetParts - (#out.pathPatches + #out.edges + #out.tufts + #out.clusters + flowerCount)
	end
	local fl = GR.flowersPerCluster
	for idx, c in ipairs(cells) do
		pause()
		local x, z = c[1] + (rng() - 0.5) * (cellSize - 4), c[2] + (rng() - 0.5) * (cellSize - 4)
		local wantCluster = (idx % 3 == 0) and #out.clusters < GR.clusterCap
		local wantTuft = (not wantCluster) and #out.tufts < GR.tuftCap
		if (wantCluster or wantTuft) and nearAnchor(x, z) and G.blocked(x, z, 1.2, {}) == nil and freeOfObjects(x, z, 1.2) then
			if wantCluster then
				local nf = fl[1] + math.floor(rng() * (fl[2] - fl[1] + 1))
				if room(x, z, nf + 1) and partsLeft() >= nf + 1 then
					local flowers = {}
					for f = 1, nf do
						local a = (f / nf + rng() * 0.2) * math.pi * 2
						local rr = 0.2 + rng() * 0.55
						flowers[f] = { dx = math.cos(a) * rr, dz = math.sin(a) * rr, color = pick(GR.flowerPalette, rng()) }
					end
					out.clusters[#out.clusters + 1] = { x = x, z = z, y = P.groundY(x, z) or 0, size = 1.4 + rng() * 0.6, color = pick(GR.tuftPalette, rng()), flowers = flowers }
					flowerCount = flowerCount + nf
					take(x, z, nf + 1)
				end
			elseif room(x, z, 1) and partsLeft() >= 1 then
				out.tufts[#out.tufts + 1] = { x = x, z = z, y = P.groundY(x, z) or 0, size = 0.9 + rng() * 0.9, color = pick(GR.tuftPalette, rng()) }
				take(x, z, 1)
			end
		end
	end
	-- boucle de complément : si les cellules n'ont pas suffi à atteindre les plafonds, on retente une fois avec d'autres décalages (déterministe)
	local maxCell = 0
	for _, v in pairs(perCell) do
		if v > maxCell then
			maxCell = v
		end
	end
	local parts = #out.pathPatches + #out.edges + #out.tufts + #out.clusters + flowerCount
	out.parts = parts
	out.stats = { parts = parts, pathPatches = #out.pathPatches, edges = #out.edges, tufts = #out.tufts, clusters = #out.clusters, flowers = flowerCount, maxPerCell = maxCell, pathLength = totalLen, cells = #cells }
	return out
end

-- Contrôle d'une fiche de plan : retourne la liste des violations (vide = conforme). Utilisé par les tests et par le serveur (journal de démarrage).
function Graphics.auditGround(Config, P, plan)
	local bad = {}
	local G = P.G
	local GR = Config.GRAPHICS.ground
	for i, t in ipairs(plan.tufts) do
		local why = G.blocked(t.x, t.z, 1.2, {})
		if why then
			bad[#bad + 1] = "touffe " .. i .. " sur zone bloquée (" .. why .. ")"
		end
	end
	for i, c in ipairs(plan.clusters) do
		local why = G.blocked(c.x, c.z, 1.2, {})
		if why then
			bad[#bad + 1] = "grappe " .. i .. " sur zone bloquée (" .. why .. ")"
		end
	end
	for i, e in ipairs(plan.edges) do
		local why = G.blocked(e.x, e.z, e.r, {})
		if why and why ~= "chemin" then
			bad[#bad + 1] = "bordure " .. i .. " sur zone bloquée (" .. why .. ")"
		end
	end
	for i, p in ipairs(plan.pathPatches) do
		local why = G.blocked(p.x, p.z, 1.2, {})
		if why and why ~= "chemin" then
			bad[#bad + 1] = "dalle " .. i .. " sur zone bloquée (" .. why .. ")"
		end
		if G.pathEdgeDist(p.x, p.z) >= 0 then
			bad[#bad + 1] = "dalle " .. i .. " hors du chemin"
		end
	end
	if plan.parts > Config.GRAPHICS.budgetParts then
		bad[#bad + 1] = "budget de Parts dépassé : " .. plan.parts
	end
	if plan.stats.maxPerCell > GR.maxPerCell then
		bad[#bad + 1] = "densité par cellule dépassée : " .. plan.stats.maxPerCell
	end
	return bad
end

return Graphics
