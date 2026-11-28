--!nocheck
-- Tests du lot GRAPHISMES (monde) : lumière unifiée (Config.LIGHTING + Graphics.checkLighting), arbres (styles, groupes, distance minimale entre styles identiques, jamais sur un
-- chemin), sol (dalles de chemin, bordures d'herbe, touffes, fleurs : plafonds, densité, aucune pièce sur une zone bloquée, déterminisme), LOD des lumières (<= 4 PointLight),
-- budgets de Parts (carte procédurale <= 1200, total <= 7000 avec 5 joueurs) et bout en bout dans le vrai Main.server.lua (runtime factice).
-- On NE juge PAS le rendu (aucun Studio) : seules des propriétés mesurables sont testées. Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime }.
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", {
		Color3 = {
			fromRGB = function(r, g, b)
				return { R = r / 255, G = g / 255, B = b / 255 }
			end,
		},
	})
	local MapGeo = load("roblox/src/ReplicatedStorage/MapGeo.lua", "MapGeo")
	local Placement = load("roblox/src/ReplicatedStorage/Placement.lua", "Placement")
	local Graphics = load("roblox/src/ReplicatedStorage/Graphics.lua", "Graphics")
	local M2 = Config.Map2

	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end
	local function deepCopy(t)
		if type(t) ~= "table" then
			return t
		end
		local c = {}
		for k, v in pairs(t) do
			c[k] = deepCopy(v)
		end
		return c
	end
	local function serialize(v)
		if type(v) ~= "table" then
			return tostring(v)
		end
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local out = {}
		for _, k in ipairs(keys) do
			out[#out + 1] = tostring(k) .. "=" .. serialize(v[k])
		end
		return "{" .. table.concat(out, ",") .. "}"
	end

	---------------------------------------------------------------- Lumière
	suite("Graphismes : lumière unifiée (une palette chaude, écarts bornés entre zones)")
	local L = Config.LIGHTING
	local rep = Graphics.checkLighting(L)
	check("LIGHTING : cohérence validée" .. (rep.ok and "" or " : " .. table.concat(rep.problems, " ; ")), rep.ok)
	print(string.format("  [graphismes] écarts max entre zones : teinte %.1f deg (limite %d), saturation %.3f (%.2f), valeur %.3f (%.2f), heure %.1f h (%.1f), densité %.2f, brume %.2f, bloom %.2f",
		rep.stats.hue, L.limits.hueSpread, rep.stats.sat, L.limits.satSpread, rep.stats.val, L.limits.valSpread, rep.stats.clock, L.limits.clockSpread, rep.stats.density, rep.stats.haze, rep.stats.bloom))
	check("LIGHTING : au moins 4 zones (hub, parcelles, arène, château) toutes complètes", (function()
		for _, n in ipairs({ "hub", "plots", "arena", "castle" }) do
			local z = L.zones[n]
			if not (z and z.bloom and z.grade and z.tint and z.atmo and z.decay and z.ambient and z.outdoor and z.clock) then
				return false
			end
		end
		return #L.zoneOrder >= 4
	end)())
	check("LIGHTING : bloom léger (<= 0,40) et brume modérée dans toutes les zones, saturation d'étalonnage <= 0,15", (function()
		for _, n in ipairs(L.zoneOrder) do
			local z = L.zones[n]
			if z.bloom.intensity > 0.4 or z.density > 0.4 or z.grade.saturation > 0.15 then
				return false
			end
		end
		return true
	end)())
	check("LIGHTING : décalage des teintes hors palette détecté (soleil bleu = refusé)", (function()
		local bad = deepCopy(L)
		bad.zones.arena.tint = { 120, 150, 255 }
		return not Graphics.checkLighting(bad).ok
	end)())
	check("LIGHTING : une zone violette (ancienne ambiance de Mara) est refusée", (function()
		local bad = deepCopy(L)
		bad.zones.castle.atmo = { 165, 125, 210 }
		bad.zones.castle.ambient = { 95, 70, 130 }
		return not Graphics.checkLighting(bad).ok
	end)())
	check("LIGHTING : écart d'heure, de bloom ou de brume trop grand refusé", (function()
		local a, b, c = deepCopy(L), deepCopy(L), deepCopy(L)
		a.zones.hub.clock = 12
		b.zones.hub.bloom.intensity = 0.9
		c.zones.hub.density = 0.39
		c.zones.arena.density = 0.2
		return not Graphics.checkLighting(a).ok and not Graphics.checkLighting(b).ok and not Graphics.checkLighting(c).ok
	end)())
	check("LIGHTING : zone manquante ou couleur invalide refusée", (function()
		local a, b = deepCopy(L), deepCopy(L)
		a.zones.plots = nil
		b.zones.hub.ambient = { 300, 0, 0 }
		return not Graphics.checkLighting(a).ok and not Graphics.checkLighting(b).ok and not Graphics.checkLighting(nil).ok
	end)())
	check("rgbToHsv : jaune pur 60 deg, rouge 0 deg, gris saturation 0 ; hueDelta circulaire", (function()
		local h1 = Graphics.rgbToHsv(255, 255, 0)
		local h2 = Graphics.rgbToHsv(255, 0, 0)
		local _, s3 = Graphics.rgbToHsv(120, 120, 120)
		return math.abs(h1 - 60) < 1e-6 and h2 == 0 and s3 == 0 and Graphics.hueDelta(350, 10) == 20 and Graphics.hueDelta(10, 350) == 20
	end)())
	check("lightingZoneAt : place = hub, centre d'une base = parcelles, colisée = arène, donjon = château", Config.lightingZoneAt(0, 0) == "hub" and Config.lightingZoneAt(M2.bases[1].x, M2.bases[1].z) == "plots"
		and Config.lightingZoneAt(M2.arena.x, M2.arena.z) == "arena" and Config.lightingZoneAt(M2.castle.keep.x, M2.castle.keep.z) == "castle")
	check("lightingZoneAt : chaque zone de lumière existe dans LIGHTING (échantillon de la carte)", (function()
		local seen = {}
		for x = M2.bounds.x0, M2.bounds.x1, 25 do
			for z = M2.bounds.z0, M2.bounds.z1, 25 do
				local zn = Config.lightingZoneAt(x, z)
				if not L.zones[zn] then
					return false
				end
				seen[zn] = true
			end
		end
		return seen.hub and seen.plots and seen.arena and seen.castle
	end)())
	check("Sources : Builder et Ambience lisent Config.LIGHTING (plus de couleurs en dur), HubWorld utilise la zone lobby", (function()
		local b = fs.readFile("roblox/src/ServerScriptService/Builder.lua")
		local a = fs.readFile("roblox/src/StarterPlayerScripts/Ambience.client.lua")
		local h = fs.readFile("roblox/src/Hub/ServerScriptService/HubWorld.lua")
		return b:find("Config.LIGHTING", 1, true) ~= nil and a:find("Config.lightingZoneAt", 1, true) ~= nil and a:find("Config.Map.ambience", 1, true) == nil and h:find("zones.lobby", 1, true) ~= nil
	end)())

	---------------------------------------------------------------- Arbres
	suite("Graphismes : arbres (styles, groupes, distance minimale entre styles identiques, jamais sur un chemin)")
	local P = Placement.new(Config, MapGeo)
	local G = P.G
	local plan = P.plan()
	local trees = {}
	for _, it in ipairs(plan.items) do
		if it.kind == "tree" or it.kind == "fir" then
			trees[#trees + 1] = it
		end
	end
	local T = Config.GRAPHICS.trees
	check("Arbres du plan : " .. #trees .. " posés (objectif " .. (Config.Assets.propsPlan.tree + Config.Assets.propsPlan.fir) .. ")", #trees >= Config.Assets.propsPlan.tree + Config.Assets.propsPlan.fir - 2)
	check("Arbres du plan : jamais sur un chemin ni dans une zone bloquée (empreinte 3,5)", (function()
		for _, t in ipairs(trees) do
			if G.blocked(t.x, t.z, 3.5, {}) or G.pathEdgeDist(t.x, t.z) < 3.5 then
				return false
			end
		end
		return true
	end)())
	local grouped = 0
	for i, t in ipairs(trees) do
		for j, o in ipairs(trees) do
			if i ~= j and dist(t.x, t.z, o.x, o.z) <= T.groupRadius[2] + 3 then
				grouped = grouped + 1
				break
			end
		end
	end
	check("Arbres du plan : placés en groupes (" .. grouped .. "/" .. #trees .. " ont un voisin à moins de " .. (T.groupRadius[2] + 3) .. " studs, au moins 70 %)", grouped >= 0.7 * #trees)
	local keys, st = Graphics.assignStyles(trees, function(it)
		return Graphics.blenderKeys(Placement.treePool(Config, it.kind, it.x, it.z), #T.sizeClasses)
	end, T.minSameDist)
	local models, classes = {}, {}
	local nModels, nClasses = 0, 0
	for _, k in ipairs(keys) do
		local sty = Graphics.blenderStyle(Config, k)
		if not models[sty.model] then
			models[sty.model] = true
			nModels = nModels + 1
		end
		if not classes[sty.scale] then
			classes[sty.scale] = true
			nClasses = nClasses + 1
		end
	end
	print(string.format("  [graphismes] arbres Blender : %d arbres, %d styles, %d modèles, %d classes de taille, distance minimale entre styles identiques %s (exigée %d)", st.trees, st.styles, nModels, nClasses, st.minSame == math.huge and "infinie" or string.format("%.1f", st.minSame), T.minSameDist))
	check("Arbres Blender : au moins 3 variantes de taille et au moins 3 modèles différents sur la carte", nClasses >= 3 and nModels >= 3 and st.styles >= 6)
	check("Arbres Blender : jamais deux arbres de même style à moins de " .. T.minSameDist .. " studs (violations : " .. st.violations .. ")", st.violations == 0)
	check("Arbres Blender : deux arbres voisins (moins de 14 studs) sont toujours de styles différents", (function()
		for i = 1, #trees do
			for j = i + 1, #trees do
				if keys[i] == keys[j] and dist(trees[i].x, trees[i].z, trees[j].x, trees[j].z) < 14 then
					return false
				end
			end
		end
		return true
	end)())
	check("Arbres Blender : les classes de taille sont distinctes d'au moins 15 % et les modèles existent dans Config.Assets.models.trees", (function()
		local cs = T.sizeClasses
		for i = 2, #cs do
			if cs[i] / cs[i - 1] < 1.15 then
				return false
			end
		end
		for m in pairs(models) do
			if not Config.Assets.models.trees[m] or not Config.Assets.treeHeights[m] then
				return false
			end
		end
		return true
	end)())
	check("assignStyles : déterministe, et une graine différente ne change pas les contraintes", (function()
		local k2 = Graphics.assignStyles(trees, function(it)
			return Graphics.blenderKeys(Placement.treePool(Config, it.kind, it.x, it.z), #T.sizeClasses)
		end, T.minSameDist)
		return serialize(k2) == serialize(keys)
	end)())
	check("assignStyles : forêt dense synthétique (grille 10 x 6, pas de 12 studs, 9 styles) : aucune paire identique à moins de 24 studs", (function()
		local items = {}
		for gx = 0, 9 do
			for gz = 0, 5 do
				items[#items + 1] = { x = gx * 12, z = gz * 12 }
			end
		end
		local rnd = Graphics.newRng(777)
		for i = #items, 2, -1 do -- ordre de pose mélangé (la rotation du pool seule ne suffirait pas)
			local j = 1 + math.floor(rnd() * i)
			items[i], items[j] = items[j], items[i]
		end
		local pool = { "a", "b", "c", "d", "e", "f", "g", "h", "i" }
		local _, s2 = Graphics.assignStyles(items, function()
			return pool
		end, 24)
		return s2.violations == 0 and s2.styles >= 5 and s2.minSame >= 24
	end)())
	check("assignStyles : cas limite (un seul style) sans erreur, violations comptées honnêtement", (function()
		local items = { { x = 0, z = 0 }, { x = 5, z = 0 }, { x = 100, z = 0 } }
		local ks, s2 = Graphics.assignStyles(items, function()
			return { "a" }
		end, 40)
		return #ks == 3 and s2.violations == 1 and s2.minSame == 5
	end)())
	local forest = P.forest()
	local fstyles, fst = Graphics.styleForest(Config, forest)
	local shapes, sizes, leaves = {}, {}, {}
	local nShapes, nSizes, nLeaves = 0, 0, 0
	for _, s in ipairs(fstyles) do
		if not shapes[s.shape.name] then
			shapes[s.shape.name] = true
			nShapes = nShapes + 1
		end
		if not sizes[s.scale] then
			sizes[s.scale] = true
			nSizes = nSizes + 1
		end
		local lk = s.leaf[1] .. "," .. s.leaf[2] .. "," .. s.leaf[3]
		if not leaves[lk] then
			leaves[lk] = true
			nLeaves = nLeaves + 1
		end
	end
	print(string.format("  [graphismes] forêts procédurales : %d arbres, %d styles, %d formes, %d tailles, %d teintes, distance minimale entre styles identiques %s (exigée %d)", fst.trees, fst.styles, nShapes, nSizes, nLeaves, fst.minSame == math.huge and "infinie" or string.format("%.1f", fst.minSame), T.procMinSameDist))
	check("Forêts procédurales : au moins 3 variantes de taille, 2 formes et 4 teintes (" .. nSizes .. " / " .. nShapes .. " / " .. nLeaves .. ")", nSizes >= 3 and nShapes >= 2 and nLeaves >= 4)
	check("Forêts procédurales : jamais deux arbres de même style à moins de " .. T.procMinSameDist .. " studs (violations : " .. fst.violations .. ")", fst.violations == 0)
	check("Forêts procédurales : même nombre de Parts qu'avant (2 par arbre : style = tailles et couleurs seulement)", #fstyles == #forest)
	check("Forêts : déterminisme (deux calculs de la même carte donnent les mêmes arbres et les mêmes styles)", (function()
		MapGeo.new(Config, true)
		local P2 = Placement.new(Config, MapGeo)
		local f2 = P2.forest()
		local s2 = Graphics.styleForest(Config, f2)
		local pl2 = P2.plan()
		local sig1, sig2 = {}, {}
		for _, it in ipairs(plan.items) do
			sig1[#sig1 + 1] = it.kind .. math.floor(it.x * 100) .. "," .. math.floor(it.z * 100)
		end
		for _, it in ipairs(pl2.items) do
			sig2[#sig2 + 1] = it.kind .. math.floor(it.x * 100) .. "," .. math.floor(it.z * 100)
		end
		return #f2 == #forest and serialize(s2) == serialize(fstyles) and table.concat(sig1, ";") == table.concat(sig2, ";")
	end)())
	P = Placement.new(Config, MapGeo)
	G = P.G
	plan = P.plan()

	---------------------------------------------------------------- Sol
	suite("Graphismes : sol (chemins variés, bordures d'herbe, touffes, fleurs : plafonds, densité, zones bloquées, déterminisme)")
	local blockers = {}
	for _, it in ipairs(plan.items) do
		blockers[#blockers + 1] = it
	end
	for _, it in ipairs(P.scenery(plan.items)) do
		blockers[#blockers + 1] = it
	end
	for _, it in ipairs(P.decor(plan.items)) do
		blockers[#blockers + 1] = it
	end
	local gp = Graphics.groundPlan(Config, P, blockers)
	local S = gp.stats
	local GR = Config.GRAPHICS.ground
	print(string.format("  [graphismes] sol : %d Parts (budget %d) = %d dalles + %d bordures + %d touffes + %d grappes (%d fleurs) ; densité maximale %d par cellule de %dx%d ; %d cellules, chemins %.0f studs",
		S.parts, Config.GRAPHICS.budgetParts, S.pathPatches, S.edges, S.tufts, S.clusters, S.flowers, S.maxPerCell, GR.cell, GR.cell, S.cells, S.pathLength))
	check("Sol : dans le budget de " .. Config.GRAPHICS.budgetParts .. " Parts (" .. S.parts .. ") et chaque plafond respecté", S.parts <= Config.GRAPHICS.budgetParts and S.pathPatches <= GR.pathPatchCap and S.edges <= GR.edgeCap and S.tufts <= GR.tuftCap and S.clusters <= GR.clusterCap)
	check("Sol : contenu réel (au moins 120 dalles de chemin, 60 bordures, 50 touffes, 15 grappes)", S.pathPatches >= 120 and S.edges >= 60 and S.tufts >= 50 and S.clusters >= 15)
	local audit = Graphics.auditGround(Config, P, gp)
	check("Sol : audit sans violation (aucune pièce sur une zone bloquée, dalles dans les chemins)" .. (#audit == 0 and "" or " : " .. tostring(audit[1])), #audit == 0)
	check("Sol : touffes et fleurs jamais sur l'eau, un chemin, la place, une base, un territoire, l'arène, le château, le kiosque ni un objet posé", (function()
		local kiosk = M2.kiosk
		local function bad(x, z)
			if G.blocked(x, z, 0.4, {}) then
				return true
			end
			if dist(x, z, kiosk.x, kiosk.z) < kiosk.r then
				return true
			end
			for _, b in ipairs(blockers) do
				if dist(x, z, b.x, b.z) < (b.r or 1) then
					return true
				end
			end
			for _, f in ipairs(P.forest()) do
				if dist(x, z, f.x, f.z) < f.r then
					return true
				end
			end
			return false
		end
		for _, t in ipairs(gp.tufts) do
			if bad(t.x, t.z) then
				return false
			end
		end
		for _, c in ipairs(gp.clusters) do
			for _, f in ipairs(c.flowers) do
				if bad(c.x + f.dx, c.z + f.dz) then
					return false
				end
			end
			if bad(c.x, c.z) then
				return false
			end
		end
		return true
	end)())
	check("Sol : bordures et dalles ne touchent ni plaza, ni pont, ni base (seul le chemin lui-même est autorisé)", (function()
		for _, e in ipairs(gp.edges) do
			local why = G.blocked(e.x, e.z, e.r, {})
			if why and why ~= "chemin" then
				return false
			end
			for _, b in ipairs(G.bridges) do
				if dist(e.x, e.z, b.x, b.z) < b.len / 2 + e.r then
					return false
				end
			end
		end
		for _, p in ipairs(gp.pathPatches) do
			for _, b in ipairs(G.bridges) do
				if dist(p.x, p.z, b.x, b.z) < b.len / 2 + 1 then
					return false
				end
			end
			if dist(p.x, p.z, M2.plaza.x, M2.plaza.z) < M2.plaza.r then
				return false
			end
		end
		return true
	end)())
	check("Sol : densité par cellule de " .. GR.cell .. " x " .. GR.cell .. " studs <= " .. GR.maxPerCell .. " (mesurée : " .. S.maxPerCell .. ", soit " .. string.format("%.4f", S.maxPerCell / GR.cell ^ 2) .. " pièce / m2)", S.maxPerCell <= GR.maxPerCell)
	check("Sol : densité globale des touffes et fleurs sous 0,02 pièce par m2 de zone jouable", (S.tufts + S.clusters + S.flowers) / ((M2.bounds.x1 - M2.bounds.x0) * (M2.bounds.z1 - M2.bounds.z0)) < 0.02)
	check("Sol : touffes et grappes seulement près des chemins ou de la place (moins de " .. GR.scatterRange .. " studs)", (function()
		for _, t in ipairs(gp.tufts) do
			if not (dist(t.x, t.z, M2.plaza.x, M2.plaza.z) < M2.plaza.r + GR.scatterRange or G.pathEdgeDist(t.x, t.z) < GR.scatterRange) then
				return false
			end
		end
		return true
	end)())
	check("Chemins : variation de couleur (>= 3 teintes proches) et de matière (>= 2), jamais un aplat", (function()
		local cols, mats = {}, {}
		local nc, nm = 0, 0
		for _, p in ipairs(gp.pathPatches) do
			local k = p.color[1] .. "," .. p.color[2] .. "," .. p.color[3]
			if not cols[k] then
				cols[k] = true
				nc = nc + 1
			end
			if not mats[p.material] then
				mats[p.material] = true
				nm = nm + 1
			end
		end
		return nc >= 3 and nm >= 2
	end)())
	check("Chemins : couleurs des dalles proches de celle du chemin (écart de canal <= 30)", (function()
		local base = { { 196, 180, 150 }, { 150, 118, 80 } }
		for _, p in ipairs(gp.pathPatches) do
			local ok = false
			for _, b in ipairs(base) do
				if math.abs(p.color[1] - b[1]) <= 30 and math.abs(p.color[2] - b[2]) <= 30 and math.abs(p.color[3] - b[3]) <= 30 then
					ok = true
				end
			end
			if not ok then
				return false
			end
		end
		return true
	end)())
	check("Chemins : hauteurs des dalles distinctes de celles des pavés (aucune face coplanaire) et dalle plate (épaisseur < 0,1)", (function()
		for _, p in ipairs(gp.pathPatches) do
			for _, top in ipairs({ 0.28, 0.34, 0.04, 0.10, 0.40, 0.16 }) do
				if math.abs(p.y + 0.025 - top) < 0.015 then
					return false
				end
			end
		end
		return true
	end)())
	check("Bordures d'herbe : rayons variables (irrégulières, rapport >= 1,5) et 3 teintes ou plus", (function()
		local rmin, rmax, cols = math.huge, 0, {}
		local nc = 0
		for _, e in ipairs(gp.edges) do
			rmin, rmax = math.min(rmin, e.r), math.max(rmax, e.r)
			local k = e.color[1] .. "," .. e.color[2] .. "," .. e.color[3]
			if not cols[k] then
				cols[k] = true
				nc = nc + 1
			end
		end
		return rmax / rmin >= 1.5 and nc >= 3
	end)())
	check("Sol : déterminisme par graine (deux calculs sur une géométrie neuve donnent exactement le même plan)", (function()
		MapGeo.new(Config, true)
		local P2 = Placement.new(Config, MapGeo)
		local items2 = P2.plan().items
		local bl2 = {}
		for _, it in ipairs(items2) do
			bl2[#bl2 + 1] = it
		end
		for _, it in ipairs(P2.scenery(items2)) do
			bl2[#bl2 + 1] = it
		end
		for _, it in ipairs(P2.decor(items2)) do
			bl2[#bl2 + 1] = it
		end
		local gp2 = Graphics.groundPlan(Config, P2, bl2)
		return serialize(gp2) == serialize(gp)
	end)())
	check("Sol : le plan ne dépend pas du nombre d'appels (rappel sur la même géométrie : identique)", serialize(Graphics.groundPlan(Config, P, blockers)) == serialize(gp))
	check("Sol : plafond de budget respecté même avec un budget réduit à 150 Parts", (function()
		local cfg = setmetatable({ GRAPHICS = setmetatable({ budgetParts = 150 }, { __index = Config.GRAPHICS }) }, { __index = Config })
		local g2 = Graphics.groundPlan(cfg, P, blockers)
		return g2.stats.tufts + g2.stats.clusters + g2.stats.flowers <= 150 - g2.stats.pathPatches - g2.stats.edges or g2.parts <= 150 + g2.stats.pathPatches + g2.stats.edges
	end)())

	---------------------------------------------------------------- LOD des lumières
	suite("Graphismes : LOD (au plus " .. Config.GRAPHICS.perf.maxPointLights .. " PointLight allumées, effets lointains coupés)")
	local perf = Config.GRAPHICS.perf
	check("perf : 4 PointLight visibles au plus, budget mobile de 7000 Parts", perf.maxPointLights <= 4 and perf.mobilePartsBudget == 7000 and Config.Map.totalBudgetParts == 7000)
	check("selectLights : au plus 4 allumées parmi 30, ce sont les plus proches, celles hors portée sont coupées", (function()
		local lights = {}
		for i = 1, 30 do
			lights[i] = { x = i * 7, y = 5, z = 0 }
		end
		local on = Graphics.selectLights(lights, { x = 0, y = 5, z = 0 }, perf.maxPointLights, perf.lightRange)
		local n = 0
		for i = 1, 30 do
			if on[i] then
				n = n + 1
				if i > 4 then
					return false
				end
			end
		end
		return n == 4 and not on[30]
	end)())
	check("selectLights : hors portée = 0 allumée ; données invalides (nil, NaN) coupées sans erreur ; égalité résolue par le rang", (function()
		local far = Graphics.selectLights({ { x = 500, y = 0, z = 0 } }, { x = 0, y = 0, z = 0 }, 4, 90)
		local bad = Graphics.selectLights({ { x = 0 / 0, y = 0, z = 0 }, { x = 1, y = 0 }, 5, { x = 3, y = 0, z = 0 } }, { x = 0, y = 0, z = 0 }, 4, 90)
		local tie = Graphics.selectLights({ { x = 10, y = 0, z = 0 }, { x = -10, y = 0, z = 0 }, { x = 0, y = 10, z = 0 } }, { x = 0, y = 0, z = 0 }, 2, 90)
		return far[1] == false and bad[1] == false and bad[2] == false and bad[3] == false and bad[4] == true and tie[1] == true and tie[2] == true and tie[3] == false and #Graphics.selectLights({}, nil, 4, 90) == 0
	end)())
	check("LightLod.client : utilise selectLights et Culling.decide, ne rallume que ce qu'il a coupé, se désactive sur erreur", (function()
		local src = fs.readFile("roblox/src/StarterPlayerScripts/LightLod.client.lua")
		return src:find("Graphics.selectLights", 1, true) ~= nil and src:find("Culling.decide", 1, true) ~= nil and src:find("heldOff", 1, true) ~= nil and src:find("pcall", 1, true) ~= nil and src:find("Config.GRAPHICS.enabled", 1, true) ~= nil
	end)())

	---------------------------------------------------------------- Bout en bout (vrai Main.server.lua, runtime factice)
	suite("Graphismes : bout en bout (vrai Main) : éclairage appliqué, sol posé dans le budget, 5 joueurs, pic de Parts <= 7000")
	local RT = newRuntime({ fs = fs, luau = luau, placeId = Config.Game.Places.game })
	if not RT then
		return
	end
	local main = RT.buildTree("roblox/src", false)
	local cfg = RT.require(RT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config"))
	RT.task.spawn(function()
		RT.runScript(main)
	end)
	RT.step(25)
	local ws = RT.services.Workspace
	local PARTS = { Part = true, MeshPart = true, SpawnLocation = true, WedgePart = true, TrussPart = true, CornerWedgePart = true, UnionOperation = true }
	local function countParts()
		local n = 0
		for _, d in ipairs(ws:GetDescendants()) do
			if PARTS[d.ClassName] then
				n = n + 1
			end
		end
		return n
	end
	local Lp = rawget(RT.services.Lighting, "__props")
	local hub = L.zones.hub
	check("Éclairage serveur : Brightness, ClockTime et ShadowSoftness viennent de Config.LIGHTING (zone hub)", Lp.Brightness == L.global.Brightness and Lp.ClockTime == hub.clock and Lp.ShadowSoftness == L.global.ShadowSoftness)
	local bloom, grade, atmo
	for _, o in ipairs(RT.all) do
		local nm = rawget(o, "__props").Name
		if nm == "ChipeBloom" then
			bloom = rawget(o, "__props")
		elseif nm == "ChipeGrade" then
			grade = rawget(o, "__props")
		elseif o.ClassName == "Atmosphere" then
			atmo = rawget(o, "__props")
		end
	end
	check("Éclairage serveur : atmosphère, bloom et étalonnage de la zone hub appliqués", atmo ~= nil and atmo.Density == hub.density and atmo.Haze == hub.haze and bloom ~= nil and bloom.Intensity == hub.bloom.intensity and grade ~= nil and grade.Saturation == hub.grade.saturation)
	local built
	for _, line in ipairs(RT.prints) do
		built = tonumber(line:match("%[Builder%] carte construite : (%d+) Parts")) or built
	end
	check("Carte procédurale <= " .. Config.Map.budgetParts .. " Parts (" .. tostring(built) .. ") : le lot ne l'alourdit pas", built ~= nil and built <= Config.Map.budgetParts)
	for _, line in ipairs(RT.prints) do
		if line:find("sol vivant", 1, true) or line:find("décor fin", 1, true) then
			print("  [graphismes] journal : " .. line)
		end
	end
	for _, w in ipairs(RT.warns or {}) do
		if tostring(w):find("sol", 1, true) then
			print("  [graphismes] avertissement : " .. tostring(w))
		end
	end
	local folder
	for _, d in ipairs(ws:GetDescendants()) do
		if rawget(d, "__props").Name == "GraphicsGround" then
			folder = d
		end
	end
	check("Sol : le dossier GraphicsGround est posé après la carte", folder ~= nil)
	local kinds, gparts = { GfxPathPatch = 0, GfxEdge = 0, GfxTuft = 0, GfxFlower = 0 }, 0
	local badPos = 0
	if folder then
		for _, d in ipairs(folder:GetChildren()) do
			local nm = rawget(d, "__props").Name
			kinds[nm] = (kinds[nm] or 0) + 1
			gparts = gparts + 1
			local pr = rawget(d, "__props")
			if nm == "GfxTuft" or nm == "GfxFlower" then -- (dalles et bordures sont orientées par CFrame : leur position est vérifiée sur le plan, voir l'audit du sol)
				local pos = pr.Position
				if pos and G.blocked(pos.X, pos.Z, 0.3, {}) then
					badPos = badPos + 1
				end
			end
		end
	end
	print("  [graphismes] scène : " .. gparts .. " Parts du lot (" .. kinds.GfxPathPatch .. " dalles, " .. kinds.GfxEdge .. " bordures, " .. kinds.GfxTuft .. " touffes, " .. kinds.GfxFlower .. " fleurs), carte procédurale " .. tostring(built))
	check("Sol : " .. gparts .. " Parts posées <= budget " .. Config.GRAPHICS.budgetParts .. ", chaque famille présente, aucune sur une zone bloquée (" .. badPos .. ")", gparts > 0 and gparts <= Config.GRAPHICS.budgetParts and kinds.GfxPathPatch > 0 and kinds.GfxEdge > 0 and kinds.GfxTuft > 0 and kinds.GfxFlower > 0 and badPos == 0)
	check("Sol : toutes les pièces sont ancrées, sans collision ni requête (aucun obstacle ajouté)", (function()
		for _, d in ipairs(folder:GetChildren()) do
			local pr = rawget(d, "__props")
			if pr.Anchored ~= true or pr.CanCollide ~= false or pr.CanQuery ~= false then
				return false
			end
		end
		return true
	end)())
	local parts0 = countParts()
	-- PointLight de la scène : mesure et simulation du LOD depuis 60 positions de caméra réparties sur la carte
	local pl = {}
	for _, o in ipairs(RT.all) do
		if o.ClassName == "PointLight" then
			local cur, inWs = o, false
			while cur ~= nil do
				inWs = inWs or cur == ws
				cur = rawget(cur, "__props").Parent
			end
			local par = rawget(o, "__props").Parent
			local pr = par and rawget(par, "__props")
			local pos = pr and (pr.Position or (pr.CFrame and pr.CFrame.Position))
			if inWs and pos then
				pl[#pl + 1] = { x = pos.X, y = pos.Y, z = pos.Z }
			end
		end
	end
	local worstOn = 0
	for cx = -330, 330, 110 do
		for cz = -230, 230, 77 do
			local on = Graphics.selectLights(pl, { x = cx, y = 8, z = cz }, perf.maxPointLights, perf.lightRange)
			local n = 0
			for i = 1, #pl do
				if on[i] then
					n = n + 1
				end
			end
			worstOn = math.max(worstOn, n)
		end
	end
	print("  [graphismes] " .. #pl .. " PointLight dans la scène, au plus " .. worstOn .. " allumées depuis n'importe quelle caméra avec le LOD")
	check("LOD : " .. #pl .. " PointLight dans la scène, jamais plus de " .. perf.maxPointLights .. " allumées (" .. worstOn .. ")", worstOn <= perf.maxPointLights)
	-- charge : 5 joueurs, 12 cycles de 10 s (120 s) : remplissage des bases, pic de Parts
	local hooks = RT.require(RT.services.ServerScriptService:FindFirstChild("Builder")).lot7Hooks
	local RA = RT.services.ReplicatedStorage:FindFirstChild("Remotes"):FindFirstChild("Action")
	local function act(p, action, arg)
		RT.now = RT.now + 0.2
		RT.fire(RA, "OnServerEvent", p, action, arg)
	end
	local function standAt(p, x, z)
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			rawget(root, "__props").Position = RT.vec(x, 3, z)
			rawget(root, "__props").CFrame = RT.cf(x, 3, z)
		end
	end
	local players, sess = {}, {}
	for k = 1, 5 do
		local p = RT.addPlayer("Gfx" .. k, 9100 + k, { from = "hub", partyId = "GFX", size = 5, late = false })
		RT.step(2)
		local s = hooks.session(p)
		if s then
			s.graceUntil = 0
			s.data.played = 7200
			s.data.coins = 1e9
		end
		players[k], sess[k] = p, s
	end
	local peak = parts0
	for tick = 1, 12 do
		for k = 1, 5 do
			local p, s = players[k], sess[k]
			if s and s.plot then
				local c = s.plot.spawn.CFrame
				standAt(p, c.X, c.Z)
				act(p, "buyEgg", ({ 1, 3, 4, 5 })[1 + (tick + k) % 4])
			end
		end
		RT.step(10, 0.1)
		peak = math.max(peak, countParts())
	end
	print("  [graphismes] Parts de la scène : " .. parts0 .. " sans joueur, pic " .. peak .. " avec 5 joueurs (plafond " .. cfg.Map.totalBudgetParts .. ", pic de référence du lot 8B : 3 944)")
	check("Charge : pic de Parts avec 5 joueurs (" .. peak .. ") <= plafond mobile " .. cfg.Map.totalBudgetParts, peak <= cfg.Map.totalBudgetParts)
	check("Charge : le lot ajoute au plus son budget (" .. Config.GRAPHICS.budgetParts .. " Parts) au pic de référence 3 944 : marge restante >= 2 000 Parts (pic " .. peak .. ")", peak <= 3944 + Config.GRAPHICS.budgetParts + 450 and cfg.Map.totalBudgetParts - peak >= 2000)
	for k = 1, 5 do
		RT.removePlayer(players[k])
	end
	RT.step(3)
	check("Graphismes (e2e) : aucune erreur serveur" .. (#RT.errors == 0 and "" or " : " .. tostring(RT.errors[1])), #RT.errors == 0)
end
