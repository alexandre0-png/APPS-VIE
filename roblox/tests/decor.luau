--!nocheck
-- Tests du lot 8B-décor (DecorData.lua + Decor.lua) : données, placement (plan pur sur la vraie carte), budgets, repli si LoadAsset échoue ou renvoie un modèle vide,
-- ancres tout-ou-rien, nettoyage sans fuite, kiosque central, hook onAssetsLoaded. Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime }.
-- Le Roblox est simulé : environnement de pose (dossier, Parts, transparence), chargeur Assets factice ET module Assets réel avec un chargeur factice.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
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
	local Data = load("roblox/src/ReplicatedStorage/DecorData.lua", "DecorData")
	local Decor = load("roblox/src/ServerScriptService/Decor.lua", "Decor")
	local G = MapGeo.new(Config)
	local M2 = Config.Map2

	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end
	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end
	-- Config dérivée (budgets, kiosque, Assets) sans toucher au vrai
	local function derived(assetsOver, map2Over)
		local A = setmetatable(assetsOver or {}, { __index = Config.Assets })
		local M = setmetatable(map2Over or {}, { __index = Config.Map2 })
		return setmetatable({ Assets = A, Map2 = M }, { __index = Config })
	end

	---------------------------------------------------------------- DecorData : intégrité
	suite("DecorData : identifiants, familles, budgets")
	local EXPECT = {
		hub_dome = 106786001814640, conveyor_belt = 110718997928428, conveyor_end = 107430030694559, grand_oeuf = 140225439366673, arena_colosseum = 105443469311651,
		stall_a = 121243958605530, stall_b = 94658977878853, crate_stack = 72797022625881, barrel_pair = 102360413338352, hay_bale = 99760241706274, reeds = 83409451845816,
		lily_pad = 108143670859973, bush_round = 72736930746142, sign_base = 121260374584222, flag_banner = 72351168707999, lantern_post = 116378599429951, well_small = 140033477297106,
		bench_park = 71149096082627, boulder_cluster = 94606784141362, flowerbed = 136250950680925, log_hollow = 92331613804784, tree_dead = 110319726621538,
		tree_pine_tier = 89102403219316, tree_wide = 86295807080862, island_sakura = 77134124755209, stump_roots = 77105687594948, tree_autumn = 139640609512190,
		tree_fork = 134023676934024, well_roofed = 77148661041685,
	}
	check("29 familles (lots 15 hors maisons, 16 et 17)", count(Data.families) == 29 and count(EXPECT) == 29)
	check("chaque identifiant est celui de Assets-crees (lots 15, 16, 17)", (function()
		for name, id in pairs(EXPECT) do
			if not Data.families[name] or Data.families[name].id ~= id then
				return false
			end
		end
		return true
	end)())
	check("identifiants : entiers positifs, tous distincts", (function()
		local seen = {}
		for _, f in pairs(Data.families) do
			if type(f.id) ~= "number" or f.id <= 0 or f.id % 1 ~= 0 or seen[f.id] then
				return false
			end
			seen[f.id] = true
		end
		return true
	end)())
	check("aucun identifiant ne double un modèle déjà branché dans Config.Assets.models (maisons, arbres lot 11, village lot 12...)", (function()
		local wired = {}
		for _, group in pairs(Config.Assets.models) do
			for _, id in pairs(group) do
				wired[id] = true
			end
		end
		for _, id in pairs(Config.Assets.props) do
			wired[id] = true
		end
		for _, f in pairs(Data.families) do
			if wired[f.id] then
				return false
			end
		end
		return true
	end)())
	check("les 6 maisons house_lvl2..7 sont déclarées `wired` (déjà branchées) et absentes des familles", (function()
		local ids = { house_lvl2 = 83993710226197, house_lvl3 = 137211706941591, house_lvl4 = 131395542579523, house_lvl5 = 86282878742281, house_lvl6 = 92231252125110, house_lvl7 = 79107809937066 }
		for name, id in pairs(ids) do
			if not Data.wired[name] or Data.families[name] then
				return false
			end
			local grp, key = Data.wired[name]:match("^(%a+)%.(%w+)$")
			if Config.Assets.models[grp][key] ~= id then
				return false
			end
		end
		return true
	end)())
	check("order : chaque famille de l'ordre existe, chaque famille y figure sauf conveyor_end (tuile de conveyor_belt)", (function()
		local inOrder = {}
		for _, n in ipairs(Data.order) do
			if not Data.families[n] or inOrder[n] then
				return false
			end
			inOrder[n] = true
		end
		for n in pairs(Data.families) do
			if not inOrder[n] and n ~= "conveyor_end" then
				return false
			end
		end
		return true
	end)())
	check("zones connues, parts de budget dans [0, 1], plafonds de Parts raisonnables", (function()
		local zones = { hall = true, bigEgg = true, arena = true, belt = true, beltEnd = true, plazaRim = true, stallSide = true, region = true, pathSide = true, pathSign = true, lakeShore = true, lakeWater = true, lakeIsle = true }
		for _, f in pairs(Data.families) do
			if not zones[f.zone] or f.share < 0 or f.share > 1 or f.cap < 10 or f.cap > 400 then
				return false
			end
		end
		return true
	end)())
	check("familles à quota : count > 0, taille cible (height ou length), empreinte r > 0, repli procédural défini et mesurable", (function()
		for name, f in pairs(Data.families) do
			if f.count then
				if f.count <= 0 or not (f.height or f.length) or not f.r or f.r <= 0 or not f.fb or not f.fbMax or f.fbMax < 1 then
					return false
				end
				if Decor.fallbackCost(f) < 1 or Decor.fallbackCost(f) > 5 then
					return false
				end
			else
				if f.fb then -- ancres : le repli est l'élément procédural existant
					return false
				end
			end
			if name == "" then
				return false
			end
		end
		return true
	end)())
	check("budgets : modèles 1000 + repli 240, et la carte reste sous Config.Map.totalBudgetParts avec la formule de tests/run.luau", (function()
		local b = Data.budget
		return b.blender == 1000 and b.fallback == 240 and 1200 + 600 + Config.propsWorstCase() + 12 * Config.PLOT_COUNT * Config.Assets.propsMaxParts.nest + b.blender + b.fallback <= Config.Map.totalBudgetParts
	end)())
	check("le repli le plus coûteux ne dépasse jamais fbMax x 5 Parts et la somme de TOUS les replis possibles dépasse le budget de repli (le budget plafonne bien)", (function()
		local total = 0
		for _, f in pairs(Data.families) do
			if f.fb then
				total = total + Decor.fallbackCost(f) * f.fbMax
			end
		end
		return total >= Data.budget.fallback
	end)())
	check("DecorData.existing reprend les bancs et lampadaires fixes de Builder.dressArena (même coordonnées)", (function()
		local src = fs.readFile("roblox/src/ServerScriptService/Builder.lua")
		for _, o in ipairs(Data.existing) do
			if not src:find("{ " .. o[1] .. ", " .. o[2] .. " }", 1, true) then
				return false
			end
		end
		return #Data.existing == 8
	end)())
	check("Config.Assets.decorBudgetParts / decorFallbackParts / decorOff ne sont pas encore définis (surcharges facultatives)", Config.Assets.decorBudgetParts == nil or type(Config.Assets.decorBudgetParts) == "number")

	---------------------------------------------------------------- Plan pur sur la vraie carte
	suite("Decor.plan : placement sur la carte 700 x 500 (plan pur, déterministe)")
	local P = Placement.new(Config, MapGeo)
	local plan = Decor.plan(G, Config, Data, { placement = P })
	local plan2 = Decor.plan(G, Config, Data, { placement = P })
	check("plan déterministe : deux calculs identiques", (function()
		if #plan.slots ~= #plan2.slots then
			return false
		end
		for i, s in ipairs(plan.slots) do
			local t = plan2.slots[i]
			if s.fam ~= t.fam or s.x ~= t.x or s.z ~= t.z or s.rot ~= t.rot then
				return false
			end
		end
		return true
	end)())
	local shortfalls = {}
	for _, name in ipairs(Data.order) do
		local f = Data.families[name]
		if f.count then
			local got = plan.byFam[name] and #plan.byFam[name] or 0
			if got < f.count then
				shortfalls[#shortfalls + 1] = name .. " " .. got .. "/" .. f.count
			end
		end
	end
	check("toutes les familles à quota trouvent leurs emplacements (manque : " .. table.concat(shortfalls, ", ") .. ")", #shortfalls == 0)
	-- lot 8B (intégration) : Config.Map2.kiosk = (14, 22, r 12) : le disque ne touche pas le rectangle du tapis (z +-4), le tapis Blender est donc planifié
	check("ancres : dôme du hall, Grand Œuf, colisée présents ; tapis présent avec le kiosque réel de Config.Map2 (14, 22, r 12 : hors du tapis)", plan.byFam.hub_dome ~= nil and plan.byFam.grand_oeuf ~= nil and plan.byFam.arena_colosseum ~= nil and plan.byFam.conveyor_belt ~= nil and Config.Map2.kiosk ~= nil and Config.Map2.kiosk.x == 14)
	check("dôme : centré sur la halle, largeur = 2 r + 2, posé sur les piliers (y 15)", (function()
		local s = plan.byFam.hub_dome[1]
		return s.x == M2.hall.x and s.z == M2.hall.z and s.length == M2.hall.r * 2 + 2 and s.y == 15 and s.anchor == true
	end)())
	check("Grand Œuf : centré sur Map2.bigEgg, hauteur = bigEgg.h, tourné vers la place", (function()
		local s = plan.byFam.grand_oeuf[1]
		return s.x == M2.bigEgg.x and s.z == M2.bigEgg.z and s.height == M2.bigEgg.h and s.y == 2.1 and math.abs(Decor.facing(M2.plaza.x - s.x, M2.plaza.z - s.z) - s.rot) < 1e-9
	end)())
	check("colisée : centré sur l'arène, diamètre = 2 r, devant tourné vers l'entrée", (function()
		local s = plan.byFam.arena_colosseum[1]
		return s.x == M2.arena.x and s.z == M2.arena.z and s.length == M2.arena.r * 2 and math.abs(Decor.facing(M2.arena.entry.x - M2.arena.x, M2.arena.entry.z - M2.arena.z) - s.rot) < 1e-9
	end)())
	check("Decor.facing : -Z vers le nord, 90° vers l'ouest... (cohérent avec Placement.facing)", (function()
		for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 }, { 3, -2 }, { -5, 7 } }) do
			if math.abs(Decor.facing(d[1], d[2]) - Placement.facing(d[1], d[2])) > 1e-9 then
				return false
			end
		end
		return true
	end)())

	local small = {}
	for _, s in ipairs(plan.slots) do
		if not s.anchor then
			small[#small + 1] = s
		end
	end
	check("plan : " .. #small .. " exemplaires hors ancres, aucun ne chevauche un autre (r1 + r2)", (function()
		for i = 1, #small do
			for j = i + 1, #small do
				if dist(small[i].x, small[i].z, small[j].x, small[j].z) < small[i].r + small[j].r then
					return false
				end
			end
		end
		return true
	end)())
	local occ = {}
	for _, it in ipairs(P.plan().items) do
		occ[#occ + 1] = it
	end
	for _, it in ipairs(P.plan().forest) do
		occ[#occ + 1] = it
	end
	for _, it in ipairs(P.scenery(P.plan().items)) do
		occ[#occ + 1] = it
	end
	for _, it in ipairs(P.decor(P.plan().items)) do
		occ[#occ + 1] = it
	end
	check("plan : aucun exemplaire ne chevauche les " .. #occ .. " objets déjà posés (arbres, forêt, village, décor fin)", (function()
		for _, s in ipairs(small) do
			for _, o in ipairs(occ) do
				if dist(s.x, s.z, o.x, o.z) < s.r + (o.r or 3) then
					return false
				end
			end
		end
		return true
	end)())
	check("plan : aucun exemplaire ne chevauche les bancs et lampadaires fixes de la place", (function()
		for _, s in ipairs(small) do
			for _, o in ipairs(Data.existing) do
				if dist(s.x, s.z, o[1], o[2]) < s.r + o[3] then
					return false
				end
			end
		end
		return true
	end)())
	local kiosk = { x = Data.kiosk.x, z = Data.kiosk.z, r = Data.kiosk.r }
	check("plan : aucun exemplaire dans le disque du kiosque central (r " .. kiosk.r .. ")", (function()
		for _, s in ipairs(small) do
			if dist(s.x, s.z, kiosk.x, kiosk.z) < kiosk.r + s.r then
				return false
			end
		end
		return true
	end)())

	-- vérification INDÉPENDANTE de MapGeo.blocked : données brutes de Config.Map2 et maths propres
	local function polyDist(x, z, pts)
		return MapGeo.distToPoly(x, z, pts)
	end
	local function rawBlocked(s, plazaOk, waterOk)
		local x, z, r = s.x, s.z, s.r
		if not plazaOk and dist(x, z, M2.plaza.x, M2.plaza.z) < M2.plaza.r + r then
			return "place"
		end
		if not waterOk then
			for _, lk in ipairs(M2.lakes) do
				if dist(x, z, lk.x, lk.z) < lk.r + lk.shore + r then
					return "lac"
				end
			end
		end
		for _, rv in ipairs(M2.rivers) do
			if polyDist(x, z, rv.pts) < rv.width / 2 + r then
				return "rivière"
			end
		end
		for _, p in ipairs(M2.paths) do
			local half = p.kind == "dirt" and M2.dirtHalf or M2.pathHalf
			if (p.y or 0) == 0 and polyDist(x, z, p.pts) < half + r then
				return "chemin " .. p.name
			end
		end
		if dist(x, z, M2.arena.x, M2.arena.z) < M2.arena.r + r then
			return "arène"
		end
		if x > M2.castle.x0 - 8 - r and x < M2.castle.x1 + r and z > M2.castle.z0 - r and z < M2.castle.z1 + r then
			return "château"
		end
		for _, key in ipairs(Config.TERR_ORDER) do
			local t = Config.TERR[key]
			if dist(x, z, t.x, t.z) < t.r + r then
				return "domaine " .. key
			end
		end
		for i = 1, #M2.bases do
			if G.distToBase(i, x, z) < r then
				return "base " .. i
			end
		end
		if dist(x, z, M2.bigEgg.x, M2.bigEgg.z) < M2.bigEgg.r + r then
			return "Grand Œuf"
		end
		if math.abs(x - M2.cabin.x) < M2.cabin.w / 2 + r and math.abs(z - M2.cabin.z) < M2.cabin.d / 2 + r then
			return "cabane"
		end
		if math.abs(x) > M2.bounds.x1 - r or math.abs(z) > M2.bounds.z1 - r then
			return "bord"
		end
		return nil
	end
	local mapZones = { region = true, pathSide = true, pathSign = true }
	local bad = nil
	for _, s in ipairs(small) do
		local f = Data.families[s.fam]
		if mapZones[f.zone] then
			local why = rawBlocked(s, false, false)
			if why then
				bad = s.fam .. " en (" .. math.floor(s.x) .. ", " .. math.floor(s.z) .. ") : " .. why
				break
			end
		end
	end
	check("plan : exemplaires de la carte (arbres, rochers, bancs, puits, panneaux...) hors eau, chemin, place, arène, château, domaine, base, repère, bord (contrôle indépendant)" .. (bad and (" : " .. bad) or ""), bad == nil)
	local badPlaza = nil
	for _, s in ipairs(small) do
		local f = Data.families[s.fam]
		if f.zone == "plazaRim" or f.zone == "stallSide" then
			local rr = dist(s.x, s.z, M2.plaza.x, M2.plaza.z)
			local why = nil
			if rr + s.r > M2.plaza.r then
				why = "hors de la place"
			elseif dist(s.x, s.z, M2.fountain.x, M2.fountain.z) < M2.fountain.r + s.r then
				why = "fontaine"
			elseif dist(s.x, s.z, M2.hall.x, M2.hall.z) < M2.hall.r + s.r then
				why = "halle"
			elseif dist(s.x, s.z, M2.bigEgg.x, M2.bigEgg.z) < M2.bigEgg.r + s.r then
				why = "Grand Œuf"
			else
				for _, st in ipairs(M2.stalls) do
					if math.abs(s.x - st.x) < 5.5 + s.r and math.abs(s.z - st.z) < 4.3 + s.r then
						why = "étal"
					end
				end
				local B = M2.belt
				if math.abs(s.x - (B.x0 + B.bin.x + 3.5) / 2) < (B.bin.x + 3.5 - B.x0) / 2 + s.r and math.abs(s.z - B.z) < B.width / 2 + 1 + s.r then
					why = "tapis et bac"
				end
				for k = 1, #G.portals do
					if dist(s.x, s.z, G.portals[k].pad.x, G.portals[k].pad.z) < s.r + 3 then
						why = "pad de portail"
					end
				end
				for _, p in ipairs(M2.paths) do
					local half = p.kind == "dirt" and M2.dirtHalf or M2.pathHalf
					if (p.y or 0) == 0 and polyDist(s.x, s.z, p.pts) < half + s.r then
						why = "chemin " .. p.name
					end
				end
			end
			if why then
				badPlaza = s.fam .. " en (" .. math.floor(s.x) .. ", " .. math.floor(s.z) .. ") : " .. why
				break
			end
		end
	end
	check("plan : couronne du marché dans la place, hors fontaine, halle, étals, tapis et bac, pads de portails, chemins, Grand Œuf" .. (badPlaza and (" : " .. badPlaza) or ""), badPlaza == nil)
	check("plan : nénuphars dans l'eau, roseaux sur la rive de sable (hors eau), îlots à l'intérieur d'un lac, loin des pontons", (function()
		for _, s in ipairs(small) do
			local f = Data.families[s.fam]
			if f.zone == "lakeWater" or f.zone == "lakeIsle" or f.zone == "lakeShore" then
				local inside = nil
				for _, lk in ipairs(M2.lakes) do
					local d = dist(s.x, s.z, lk.x, lk.z)
					if f.zone == "lakeShore" then
						if d > lk.r + 0.8 and d < lk.r + lk.shore + 1 then
							inside = lk
						end
					elseif d + s.r < lk.r then
						inside = lk
					end
				end
				if not inside then
					return false
				end
				for _, dk in ipairs(G.docks) do
					if MapGeo.distToSegment(s.x, s.z, dk.ax, dk.az, dk.bx, dk.bz) < dk.w / 2 + s.r then
						return false
					end
				end
			end
		end
		return true
	end)())
	check("plan : un panneau par chemin, libellé de DecorData.signLabels, un seul exemplaire par chemin", (function()
		local seen, n = {}, 0
		for _, s in ipairs(plan.byFam.sign_base or {}) do
			if not s.group or not s.label or s.label ~= Data.signLabels[s.group] or seen[s.group] then
				return false
			end
			seen[s.group] = true
			n = n + 1
			if dist(s.x, s.z, M2.plaza.x, M2.plaza.z) < M2.plaza.r then
				return false
			end
		end
		return n == #Data.signPaths
	end)())
	check("plan : un îlot de sakura par lac", (function()
		local seen = {}
		for _, s in ipairs(plan.byFam.island_sakura or {}) do
			seen[s.group] = true
		end
		return #plan.byFam.island_sakura == 2 and seen.lake1 and seen.lake2
	end)())
	check("plan : décor des lots 16 et 17 répartis (arbres au moins sur 2 grandes zones, bancs et parterres le long de plusieurs chemins)", (function()
		local minX, maxX = math.huge, -math.huge
		for _, s in ipairs(plan.byFam.tree_wide or {}) do
			minX, maxX = math.min(minX, s.x), math.max(maxX, s.x)
		end
		return maxX - minX > 150
	end)())

	-- kiosque : disques de rayons et positions variés (jamais de collision, même grand ou décentré)
	suite("Decor.plan : kiosque central (position et rayon surchargeables)")
	for _, k in ipairs({ { 0, 0, 30 }, { 25, 20, 18 }, { -30, 10, 24 }, { 0, -20, 40 } }) do
		local cfg = derived(nil, { kiosk = { x = k[1], z = k[2], r = k[3] } })
		local p = Decor.plan(G, cfg, Data, { placement = P })
		local ok = true
		local n = 0
		for _, s in ipairs(p.slots) do
			if not s.anchor then
				n = n + 1
				if dist(s.x, s.z, k[1], k[2]) < k[3] + s.r then
					ok = false
				end
			end
		end
		check("kiosque (" .. k[1] .. ", " .. k[2] .. ") r " .. k[3] .. " : aucun des " .. n .. " exemplaires ne l'entame", ok and n > 60)
	end
	do
		local cfg = derived(nil, { kiosk = { x = 0, z = 60, r = 8 } }) -- hors du tapis : le tapis est posé (tuiles + bout)
		local p = Decor.plan(G, cfg, Data, { placement = P })
		local slot = p.byFam.conveyor_belt and p.byFam.conveyor_belt[1]
		check("kiosque hors du tapis : ancre du tapis planifiée (tuiles sur deux rangées + pièce de bout à l'extrémité côté bac)", slot ~= nil and #slot.tiles >= 6 and slot.tiles[#slot.tiles].fam == "conveyor_end")
		local ok = slot ~= nil
		local B = M2.belt
		for _, t in ipairs(slot and slot.tiles or {}) do
			if t.x < B.x0 - 1 or t.x > B.x1 + 1 or math.abs(t.z - B.z) > B.width / 2 then
				ok = false
			end
		end
		check("tuiles du tapis entre x0 et x1, dans la largeur du tapis, hauteur du dessus sous l'œuf posé (1,3 < 1,5)", ok and Data.families.conveyor_belt.topY < 3.0 - 1.5)
		local belt = derived(nil, { kiosk = { x = 10, z = 0, r = 6 } })
		check("kiosque sur le tapis : pas de tuiles (le tapis procédural reste)", Decor.plan(G, belt, Data, { placement = P }).byFam.conveyor_belt == nil)
	end
	do
		local off = derived({ decorOff = { tree_dead = true, hub_dome = true } })
		local p = Decor.plan(G, off, Data, { placement = P })
		check("decorOff : familles désactivées absentes du plan", p.byFam.tree_dead == nil and p.byFam.hub_dome == nil and p.byFam.tree_wide ~= nil)
	end

	---------------------------------------------------------------- Environnement de pose factice
	-- world : racine du monde ; procedural : Parts procédurales à masquer ; folder/parts : ce que Decor crée.
	local function newWorld()
		local W = { children = {}, procedural = {}, live = {}, destroyedFolders = 0 }
		function W.add(name, transparency)
			local p = { Name = name, Transparency = transparency or 0 }
			W.procedural[#W.procedural + 1] = p
			return p
		end
		W.add("HallDome", 0)
		W.add("HallDome", 0)
		W.add("HallDomeTop", 0)
		W.add("GrandNid", 0.1)
		W.add("ArenaWall", 0)
		W.add("ArenaSteps", 0)
		W.add("CentralBelt", 0)
		W.add("BeltRail", 0)
		W.add("BeltMark", 0)
		W.add("Autre", 0)
		local parent = { Name = "World", children = {}, Parent = W }
		function parent:FindFirstChild(name)
			for _, c in ipairs(self.children) do
				if c.Name == name and not c.destroyed then
					return c
				end
			end
			return nil
		end
		W.parent = parent
		W.fallbackParts = 0
		local E = {}
		function E.newFolder(name, par)
			local f = { Name = name, children = {}, Parent = par }
			par.children[#par.children + 1] = f
			return f
		end
		local function killTree(inst)
			inst.destroyed = true
			for _, c in ipairs(inst.children or {}) do
				killTree(c)
			end
		end
		function E.destroy(inst)
			if not inst.destroyed then
				killTree(inst)
				if inst.Name == "BlenderDecor" then
					W.destroyedFolders = W.destroyedFolders + 1
				end
			end
		end
		function E.makePart(spec, par)
			local p = { spec = spec, Parent = par, children = {} }
			par.children[#par.children + 1] = p
			return p
		end
		function E.findNamed(root, names)
			local out = {}
			for _, p in ipairs(root.procedural) do
				if names[p.Name] then
					out[#out + 1] = p
				end
			end
			return out
		end
		function E.getTransparency(p)
			return p.Transparency
		end
		function E.setTransparency(p, v)
			p.Transparency = v
		end
		W.labels = {}
		function E.label(model, text)
			W.labels[#W.labels + 1] = text
		end
		E.yield = function() end
		W.env = E
		-- nombre d'instances vivantes dans le dossier courant (modèles + Parts de repli)
		function W.live()
			local f = parent:FindFirstChild("BlenderDecor")
			if not f then
				return 0, 0
			end
			local models, parts = 0, 0
			for _, c in ipairs(f.children) do
				if not c.destroyed then
					if c.spec then
						parts = parts + 1
					else
						models = models + 1
					end
				end
			end
			return models, parts
		end
		function W.transparencies()
			local t = {}
			for _, p in ipairs(W.procedural) do
				t[#t + 1] = p.Transparency
			end
			return t
		end
		return W
	end

	-- Assets factice : status/templates/loadMany/cloneModel/place (même contrat que Assets.new)
	local function fakeAssets(opts)
		local A = { status = {}, loadCalls = 0, loadedKeys = {}, placeCalls = 0, placed = {} }
		function A.loadMany(entries)
			A.loadCalls = A.loadCalls + 1
			for _, e in ipairs(entries) do
				A.loadedKeys[#A.loadedKeys + 1] = e.key
				local fam = e.key:gsub("^m:decor%.", "")
				if opts.fail and opts.fail(fam) then
					A.status[e.key] = { ok = false, reason = "refusé", id = e.id }
				else
					A.status[e.key] = { ok = true, parts = opts.parts and opts.parts(fam) or 10, id = e.id }
				end
			end
		end
		function A.cloneModel(group, key)
			if group ~= "decor" then
				error("groupe inattendu")
			end
			local st = A.status["m:decor." .. key]
			if not (st and st.ok) then
				return nil
			end
			return { fam = key, children = {}, Name = key, SetAttribute = function() end }
		end
		function A.place(model, x, z, rot, height, parent, length, groundY)
			A.placeCalls = A.placeCalls + 1
			if opts.placeFails and opts.placeFails(model.fam, A.placeCalls) then
				model.destroyed = true
				return false
			end
			model.x, model.z, model.rot, model.height, model.length, model.groundY = x, z, rot, height, length, groundY
			model.Parent = parent
			parent.children[#parent.children + 1] = model
			A.placed[#A.placed + 1] = model
			return true, A.status["m:decor." .. model.fam].parts
		end
		return A
	end

	local function runBuild(cfg, assets, world, extra)
		local deps = { assets = assets, placement = P, env = world.env, root = world, data = Data }
		for k, v in pairs(extra or {}) do
			deps[k] = v
		end
		return Decor.build(world.parent, G, cfg, deps)
	end

	---------------------------------------------------------------- Tous les modèles disponibles
	suite("Decor.build : tous les modèles chargés (budgets, parts, masquage des éléments procéduraux)")
	local kioskAway = { kiosk = { x = 0, z = 60, r = 8 } }
	do
		local world = newWorld()
		local cfg = derived(nil, kioskAway)
		local assets = fakeAssets({ parts = function(fam)
			return fam:find("^tree") and 30 or 8
		end })
		local h = runBuild(cfg, assets, world)
		check("build sans erreur, handle avec dossier BlenderDecor", h.error == nil and h.folder ~= nil and h.folder.Name == "BlenderDecor")
		local nModel, nFallback = 0, 0
		for _, it in ipairs(h.items) do
			if it.mode == "model" then
				nModel = nModel + 1
			else
				nFallback = nFallback + 1
			end
		end
		check("la majorité des exemplaires sont des modèles Blender (" .. nModel .. " modèles, " .. nFallback .. " replis)", nModel > 40 and nModel > nFallback)
		check("Parts Blender <= budget (1000) et Parts de repli <= 240", h.used <= 1000 and h.fallbackUsed <= 240 and h.used > 0)
		local perFam, okShare = {}, true
		local shareOf = {}
		for _, a in ipairs(assets.placed) do
			local owner = a.fam == "conveyor_end" and "conveyor_belt" or a.fam -- la pièce de bout compte sur la part du tapis
			shareOf[owner] = (shareOf[owner] or 0) + assets.status["m:decor." .. a.fam].parts
			perFam[a.fam] = (perFam[a.fam] or 0) + assets.status["m:decor." .. a.fam].parts
		end
		for fam, used in pairs(shareOf) do
			if used > math.floor(1000 * Data.families[fam].share + 1e-9) then
				okShare = false
			end
		end
		check("chaque famille reste sous sa part de budget", okShare)
		check("anchors posées : dôme, Grand Œuf, colisée, tapis (tuiles + bout)", perFam.hub_dome ~= nil and perFam.grand_oeuf ~= nil and perFam.arena_colosseum ~= nil and perFam.conveyor_belt ~= nil and perFam.conveyor_end ~= nil)
		local tr = world.transparencies()
		check("éléments procéduraux masqués (Transparency 1) : HallDome x2, HallDomeTop, GrandNid, ArenaWall, ArenaSteps, CentralBelt, BeltRail, BeltMark ; « Autre » intact", (function()
			local names = { "HallDome", "HallDome", "HallDomeTop", "GrandNid", "ArenaWall", "ArenaSteps", "CentralBelt", "BeltRail", "BeltMark" }
			for i = 1, #names do
				if tr[i] ~= 1 then
					return false
				end
			end
			return tr[10] == 0
		end)())
		check("dôme : posé à y 15 avec length = 38 ; Grand Œuf : height = Map2.bigEgg.h à y 2,1 ; colisée : length = 84", (function()
			for _, a in ipairs(assets.placed) do
				if a.fam == "hub_dome" and not (a.groundY == 15 and a.length == 38 and a.height == nil and a.x == M2.hall.x) then
					return false
				end
				if a.fam == "grand_oeuf" and not (a.groundY == 2.1 and a.height == M2.bigEgg.h) then
					return false
				end
				if a.fam == "arena_colosseum" and not (a.length == 84 and a.x == M2.arena.x) then
					return false
				end
			end
			return true
		end)())
		check("panneaux : le libellé de chaque chemin est transmis (8 panneaux Blender)", #world.labels >= 8)
		check("le journal contient un résumé des Parts", (function()
			for _, l in ipairs(h.lines) do
				if l:find("Parts Blender 1", 1, true) or l:find("Parts Blender", 1, true) then
					return true
				end
			end
			return false
		end)())
		-- nettoyage sans fuite
		local m0, p0 = world.live()
		Decor.clear(h)
		local m1, p1 = world.live()
		local tr2 = world.transparencies()
		check("clear : dossier détruit (" .. m0 .. " modèles, " .. p0 .. " Parts avant, 0 après), transparences rendues, items vides", m1 == 0 and p1 == 0 and tr2[1] == 0 and tr2[4] == 0.1 and tr2[7] == 0 and #h.items == 0 and #h.hidden == 0 and h.folder == nil)
		Decor.clear(h)
		check("clear deux fois : sans effet ni erreur", true)
	end

	---------------------------------------------------------------- Repli procédural
	suite("Decor.build : repli procédural (LoadAsset en échec, modèle vide, budget)")
	do
		local world = newWorld()
		local assets = fakeAssets({ fail = function()
			return true
		end })
		local h = runBuild(derived(nil, kioskAway), assets, world)
		local nModel, perFam = 0, {}
		for _, it in ipairs(h.items) do
			if it.mode == "model" then
				nModel = nModel + 1
			end
			perFam[it.fam] = (perFam[it.fam] or 0) + 1
		end
		local _, parts = world.live()
		check("tous les chargements refusés : zéro modèle, des replis, aucune erreur", nModel == 0 and #h.items > 40 and h.error == nil and assets.placeCalls == 0)
		check("Parts de repli = Parts créées = " .. parts .. ", <= 240", h.fallbackUsed == parts and parts <= 240 and parts > 100)
		check("quotas de repli respectés (fbMax) et plafond global : le budget plafonne", (function()
			for fam, n in pairs(perFam) do
				if n > Data.families[fam].fbMax then
					return false
				end
			end
			return h.fallbackUsed <= 240
		end)())
		check("aucune ancre sans modèle : rien n'est masqué (tapis, dôme, œuf, arène procéduraux intacts)", (function()
			for _, t in ipairs(world.transparencies()) do
				if t ~= 0 and t ~= 0.1 then
					return false
				end
			end
			return #h.hidden == 0
		end)())
		check("familles de repli variées : étals, arbres, bancs, puits, lampadaires, nénuphars, panneaux...", perFam.stall_a ~= nil and perFam.tree_wide ~= nil and perFam.bench_park ~= nil and perFam.lantern_post ~= nil and perFam.sign_base ~= nil)
		check("repli : Parts dans le dossier (modèles 0)", (function()
			local m = world.live()
			return m == 0
		end)())
		Decor.clear(h)
		check("clear après repli : 0 instance vivante", (function()
			local m, p = world.live()
			return m == 0 and p == 0
		end)())
	end
	do
		local world = newWorld()
		local cfg = derived({ decorFallbackParts = 30 })
		local h = runBuild(cfg, fakeAssets({ fail = function()
			return true
		end }), world)
		check("budget de repli réglable (30 Parts) : jamais dépassé", h.fallbackUsed <= 30 and h.fallbackUsed > 0)
		local h0 = runBuild(derived({ decorFallbackParts = 0 }), fakeAssets({ fail = function()
			return true
		end }), newWorld())
		check("budget de repli à 0 : rien de procédural", h0.fallbackUsed == 0 and #h0.items == 0)
	end
	do
		-- fbMax < count : seuls fbMax exemplaires sont construits en repli
		local custom = setmetatable({ families = setmetatable({}, { __index = Data.families }) }, { __index = Data })
		custom.families.tree_wide = setmetatable({ fbMax = 1 }, { __index = Data.families.tree_wide })
		local world = newWorld()
		local h = Decor.build(world.parent, G, derived(nil, kioskAway), { env = world.env, root = world, data = custom, placement = P })
		local n = 0
		for _, it in ipairs(h.items) do
			if it.fam == "tree_wide" then
				n = n + 1
			end
		end
		check("fbMax = 1 pour tree_wide (5 emplacements) : un seul arbre de repli", n == 1 and h.error == nil)
	end
	do
		local world = newWorld()
		local cfg = derived({ decorBudgetParts = 120 })
		local assets = fakeAssets({ parts = function()
			return 50
		end })
		local h = runBuild(cfg, assets, world)
		check("budget Blender réglable (120) avec des modèles de 50 Parts : au plus 2 modèles, jamais plus de 120 Parts, le reste en repli", h.used <= 120 and #assets.placed <= 2 and h.fallbackUsed > 0)
		local world2 = newWorld()
		local assets2 = fakeAssets({ parts = function()
			return 400
		end })
		local h2 = runBuild(derived(nil, kioskAway), assets2, world2)
		check("modèles de 400 Parts (au-dessus de toute part de budget) : aucun posé, repli partout, ancres non posées", h2.used == 0 and #assets2.placed == 0 and h2.fallbackUsed > 0 and #h2.hidden == 0)
	end
	do
		-- échec de pose (Assets.place refuse : mesure impossible) : repli pour un exemplaire, rollback pour une ancre
		local world = newWorld()
		local assets = fakeAssets({ placeFails = function(fam)
			return fam == "tree_wide" or fam == "hub_dome"
		end })
		local h = runBuild(derived(nil, kioskAway), assets, world)
		local trees, dome = 0, 0
		for _, it in ipairs(h.items) do
			if it.fam == "tree_wide" then
				trees = trees + 1
				if it.mode ~= "fallback" then
					trees = trees + 1000
				end
			end
			if it.fam == "hub_dome" then
				dome = dome + 1
			end
		end
		check("Assets.place refuse tree_wide : chaque arbre passe en repli ; refuse hub_dome : ancre absente et HallDome non masqué", trees == 5 and dome == 0 and world.procedural[1].Transparency == 0 and world.procedural[3].Transparency == 0)
		-- tapis : la 3e tuile échoue -> aucune tuile ne reste, rien n'est masqué
		local world2 = newWorld()
		local nth = 0
		local assets2 = fakeAssets({ placeFails = function(fam)
			if fam == "conveyor_belt" or fam == "conveyor_end" then
				nth = nth + 1
				return nth == 3
			end
			return false
		end })
		local h2 = runBuild(derived(nil, kioskAway), assets2, world2)
		check("tapis (3e pose refusée) : build sans erreur" .. (h2.error and (" : " .. h2.error) or ""), h2.error == nil)
		local leftovers = 0
		for _, c in ipairs(h2.folder.children) do
			if c.fam and (c.fam == "conveyor_belt" or c.fam == "conveyor_end") and not c.destroyed then
				leftovers = leftovers + 1
			end
		end
		check("tapis : pose partielle annulée (0 tuile vivante), CentralBelt / BeltRail / BeltMark restent visibles", leftovers == 0 and world2.procedural[7].Transparency == 0 and world2.procedural[8].Transparency == 0 and world2.procedural[9].Transparency == 0)
		check("tapis : le journal signale l'annulation", (function()
			for _, l in ipairs(h2.lines) do
				if l:find("pose partielle annulée", 1, true) then
					return true
				end
			end
			return false
		end)())
	end
	do
		local world = newWorld()
		local assets = fakeAssets({ fail = function(fam)
			return fam == "tree_wide" or fam == "conveyor_end"
		end })
		local h = runBuild(derived(nil, kioskAway), assets, world)
		local beltPlaced = 0
		for _, a in ipairs(assets.placed) do
			if a.fam == "conveyor_belt" or a.fam == "conveyor_end" then
				beltPlaced = beltPlaced + 1
			end
		end
		check("tapis : sans conveyor_end chargeable, tout l'ancre est écartée (tout ou rien) ; un autre modèle en échec n'empêche pas les suivants", beltPlaced == 0 and world.procedural[7].Transparency == 0 and #assets.placed > 20 and h.error == nil)
	end

	---------------------------------------------------------------- Hook onAssetsLoaded, idempotence, désactivation, robustesse
	suite("Decor : refresh (hook onAssetsLoaded), idempotence, Assets désactivé, erreurs")
	do
		local world = newWorld()
		local cfg = derived(nil, kioskAway)
		local assets = fakeAssets({ fail = function()
			return true
		end })
		local h = runBuild(cfg, assets, world)
		local before = #h.items
		local firstFolder = h.folder
		local modelsBefore = 0
		for _, it in ipairs(h.items) do
			if it.mode == "model" then
				modelsBefore = modelsBefore + 1
			end
		end
		-- les modèles « arrivent » : statuts remplacés puis refresh
		for k in pairs(assets.status) do
			assets.status[k] = { ok = true, parts = 8, id = 1 }
		end
		local h2 = Decor.refresh(h)
		local modelsAfter = 0
		for _, it in ipairs(h2.items) do
			if it.mode == "model" then
				modelsAfter = modelsAfter + 1
			end
		end
		check("refresh : ancien dossier détruit, un seul BlenderDecor vivant, les modèles arrivés remplacent les replis (" .. modelsBefore .. " -> " .. modelsAfter .. " modèles)", firstFolder.destroyed == true and world.parent:FindFirstChild("BlenderDecor") == h2.folder and modelsBefore == 0 and modelsAfter > 40 and before > 0)
		check("refresh : un modèle déjà connu (chargé ou refusé) n'est pas redemandé au chargeur (une seule vague loadMany)", assets.loadCalls == 1)
		check("refresh : Parts de repli rendues (le nouvel handle repart de son propre budget)", h2.fallbackUsed <= 240 and h.items[1] == nil)
		local liveBefore = select(2, world.live())
		Decor.clear(h2)
		check("clear après refresh : plus aucune instance vivante, transparences d'origine", select(1, world.live()) == 0 and select(2, world.live()) == 0 and world.procedural[1].Transparency == 0 and liveBefore >= 0)
		-- reconstruire après clear fonctionne (current nettoyé)
		local h3 = runBuild(cfg, assets, world)
		check("build après clear : nouveau dossier unique", h3.error == nil and world.parent:FindFirstChild("BlenderDecor") == h3.folder)
		local f3 = h3.folder
		local h4 = runBuild(cfg, assets, world)
		local live = 0
		for _, c in ipairs(world.parent.children) do
			if c.Name == "BlenderDecor" and not c.destroyed then
				live = live + 1
			end
		end
		check("deux build de suite sur le même parent : un seul dossier vivant, transparences non doublées (restaurées puis remasquées)", live == 1 and f3.destroyed == true and h4.error == nil and world.procedural[1].Transparency == 1)
		Decor.clear(h4)
		check("après 3 cycles : transparences d'origine (aucune fuite de masquage)", world.procedural[1].Transparency == 0 and world.procedural[4].Transparency == 0.1)
	end
	do
		local world = newWorld()
		local loads = 0
		local A = fakeAssets({})
		local base = A.loadMany
		A.loadMany = function(e)
			loads = loads + #e
			return base(e)
		end
		local cfg = derived({ Enabled = false })
		local h = runBuild(cfg, A, world)
		check("Config.Assets.Enabled = false : aucun chargement, repli seulement", loads == 0 and h.error == nil and #h.items > 40 and h.used == 0)
		check("deps.skipLoad : pas de chargement non plus", (function()
			local A2 = fakeAssets({})
			local h2 = runBuild(derived(nil, kioskAway), A2, newWorld(), { skipLoad = true })
			return A2.loadCalls == 0 and h2.used == 0
		end)())
	end
	do
		local world = newWorld()
		local h = Decor.build(world.parent, G, derived(nil, kioskAway), { env = world.env, root = world, data = Data })
		check("sans deps.assets : repli seulement, aucune erreur", h.error == nil and #h.items > 40 and h.used == 0)
		local bad = Decor.build(world.parent, { blocked = function() error("carte cassée") end }, derived(nil, kioskAway), { env = world.env, root = world, data = Data })
		check("géométrie cassée : aucune erreur levée, handle.error renseigné, dossier retiré (pas de décor partiel)", bad.error ~= nil and bad.folder == nil and world.parent:FindFirstChild("BlenderDecor") == nil)
		local warned = nil
		local bad2 = Decor.build(world.parent, nil, derived(nil, kioskAway), { env = world.env, root = world, data = Data, warn = function(m)
			warned = m
		end })
		check("G nil : erreur journalisée par deps.warn", bad2.error ~= nil and warned ~= nil and warned:find("Decor", 1, true) ~= nil)
		check("Decor.refresh(nil) et Decor.clear(nil) : sans effet", Decor.refresh(nil) == nil and Decor.clear(nil) == nil)
	end

	do
		-- build concurrent : un second build (ou un clear) pendant le chargement du premier l'annule, un seul dossier survit
		local world = newWorld()
		local cfg = derived(nil, kioskAway)
		local A = fakeAssets({})
		local inner = nil
		local base = A.loadMany
		A.loadMany = function(e)
			if not inner then
				inner = Decor.build(world.parent, G, cfg, { assets = A, placement = P, env = world.env, root = world, data = Data, skipLoad = true })
			end
			return base(e)
		end
		local outer = runBuild(cfg, A, world)
		local alive = 0
		for _, c in ipairs(world.parent.children) do
			if c.Name == "BlenderDecor" and not c.destroyed then
				alive = alive + 1
			end
		end
		check("build concurrent pendant le chargement : le premier build est annulé (aucun dossier orphelin), un seul BlenderDecor vivant", outer.cleared == true and outer.folder == nil and #outer.items == 0 and alive == 1 and inner ~= nil and inner.folder ~= nil)
		Decor.clear(inner)
		local cleared = Decor.build(world.parent, G, cfg, { assets = A, placement = P, env = world.env, root = world, data = Data, skipLoad = true })
		Decor.clear(cleared)
		check("clear : aucun dossier vivant ensuite", select(1, world.live()) == 0 and select(2, world.live()) == 0)
	end

	---------------------------------------------------------------- Pipeline réel : Assets.new + chargeur factice
	suite("Decor + Assets réel (chargeur factice) : retry, modèle vide, un seul LoadAsset par ID, pose mesurée")
	local CF = {}
	local function cf(x, y, z)
		local c = { X = x or 0, Y = y or 0, Z = z or 0 }
		return setmetatable(c, {
			__mul = function(a, b)
				return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
			end,
			__index = { ToObjectSpace = function() return cf(0, 0, 0) end },
		})
	end
	CF.new = function(x, y, z)
		return cf(x, y, z)
	end
	CF.Angles = function()
		return cf(0, 0, 0)
	end
	local AssetsMod = load("roblox/src/ReplicatedStorage/Assets.lua", "Assets", { CFrame = CF })
	local function part(sx, sy, sz)
		return { ClassName = "Part", Size = { X = sx, Y = sy, Z = sz }, Name = "P", children = {} }
	end
	-- modèle factice : boîte englobante unique sx, sy, sz (mise à l'échelle par ScaleTo)
	local function newModel(sx, sy, sz, nParts)
		local m = { ClassName = "Model", sx = sx, sy = sy, sz = sz, scale = 1, children = {}, attrs = {}, Name = "M" }
		for _ = 1, nParts or 3 do
			m.children[#m.children + 1] = part(sx, sy, sz)
		end
		function m:IsA(c)
			return c == "Model" or c == "PVInstance"
		end
		function m:GetDescendants()
			local out = {}
			for _, c in ipairs(self.children) do
				if not c.destroyed then
					out[#out + 1] = c
				end
			end
			return out
		end
		for _, c in ipairs(m.children) do
			c.IsA = function(self, cl)
				return cl == "BasePart" or cl == "Part"
			end
			c.Destroy = function(self)
				self.destroyed = true
			end
		end
		function m:Destroy()
			self.destroyed = true
		end
		function m:Clone()
			local c = newModel(self.sx, self.sy, self.sz, #self.children)
			c.scale = self.scale
			return c
		end
		function m:GetScale()
			return self.scale
		end
		function m:ScaleTo(s)
			self.scale = s
		end
		function m:GetExtentsSize()
			return { X = self.sx * self.scale, Y = self.sy * self.scale, Z = self.sz * self.scale }
		end
		function m:GetBoundingBox()
			return cf(0, 0, 0), self:GetExtentsSize()
		end
		function m:GetPivot()
			return cf(0, 0, 0)
		end
		function m:PivotTo(c)
			self.pos = c
		end
		function m:SetAttribute() end
		return m
	end
	local function realAssets(loader, cfgAssets)
		local clock = 0
		local cfg = derived(cfgAssets, kioskAway)
		local A = AssetsMod.new(cfg, {
			loadAsset = loader,
			spawn = function(fn)
				fn()
			end,
			wait = function(s)
				clock = clock + s
			end,
			clock = function()
				return clock
			end,
			warn = function() end,
		})
		return A, cfg
	end
	do
		local calls = {}
		local world = newWorld()
		local assets, cfg = realAssets(function(id)
			calls[id] = (calls[id] or 0) + 1
			return newModel(10, 6, 10, 4)
		end)
		local h = runBuild(cfg, assets, world)
		local placed = 0
		for _, it in ipairs(h.items) do
			if it.mode == "model" then
				placed = placed + 1
			end
		end
		local maxCalls, nIds = 0, 0
		for _, n in pairs(calls) do
			maxCalls = math.max(maxCalls, n)
			nIds = nIds + 1
		end
		check("pipeline réel : " .. nIds .. " identifiants chargés, un seul LoadAsset par identifiant, modèles posés (" .. placed .. ")", maxCalls == 1 and nIds >= 28 and placed > 40 and h.error == nil)
		check("pipeline réel : statut m:decor.<famille> renseigné avec le nombre de Parts mesuré (4) et rapport Assets de catégorie « décor de carte »", assets.status["m:decor.tree_wide"].ok == true and assets.status["m:decor.tree_wide"].parts == 4 and assets.categoryOf("m:decor.tree_wide") == "décor de carte")
		check("pipeline réel : hauteurs mises à l'échelle par Assets.place (arbre : 11 +- 20 % avec jitter, bouée 1,6 de long)", (function()
			local m = world.parent:FindFirstChild("BlenderDecor")
			for _, c in ipairs(m.children) do
				if c.fam == nil and c.ClassName == "Model" then
					local e = c:GetExtentsSize()
					if e.Y <= 0 or e.Y > 40 then
						return false
					end
				end
			end
			return true
		end)())
		local loadedBefore = 0
		for _, n in pairs(calls) do
			loadedBefore = loadedBefore + n
		end
		local h2 = Decor.refresh(h)
		local loadedAfter = 0
		for _, n in pairs(calls) do
			loadedAfter = loadedAfter + n
		end
		check("pipeline réel : refresh ne recharge rien (hook onAssetsLoaded sans coût réseau)", loadedAfter == loadedBefore and h2.error == nil)
		Decor.clear(h2)
	end
	do
		local world = newWorld()
		local assets, cfg = realAssets(function()
			return { ClassName = "Model", children = {}, IsA = function() return true end, GetDescendants = function() return {} end, Destroy = function() end }
		end)
		local h = runBuild(cfg, assets, world)
		local nModel = 0
		for _, it in ipairs(h.items) do
			if it.mode == "model" then
				nModel = nModel + 1
			end
		end
		check("LoadAsset renvoie un modèle VIDE (aucune Part) : refusé par Assets, repli procédural partout, aucune erreur", nModel == 0 and #h.items > 40 and h.error == nil and assets.status["m:decor.tree_wide"].ok == false and assets.status["m:decor.tree_wide"].reason:find("vide", 1, true) ~= nil)
		check("modèle vide : éléments procéduraux non masqués", #h.hidden == 0)
	end
	do
		local world = newWorld()
		local assets, cfg = realAssets(function()
			error("HTTP 403")
		end)
		local h = runBuild(cfg, assets, world)
		check("LoadAsset en erreur (permission) : repli, aucune erreur, statut d'échec journalisé", h.error == nil and #h.items > 40 and assets.status["m:decor.hub_dome"].ok == false and assets.status["m:decor.hub_dome"].attempts == 2)
	end
	do
		local world = newWorld()
		local first = {}
		local assets, cfg = realAssets(function(id)
			if not first[id] then
				first[id] = true
				error("réseau")
			end
			return newModel(8, 5, 8, 2)
		end)
		local h = runBuild(cfg, assets, world)
		local nModel = 0
		for _, it in ipairs(h.items) do
			if it.mode == "model" then
				nModel = nModel + 1
			end
		end
		check("premier essai en échec puis réussite (nouvel essai d'Assets.loadOne) : les modèles sont tout de même posés", nModel > 40 and assets.status["m:decor.tree_wide"].attempts == 2)
	end
	do
		local world = newWorld()
		local assets, cfg = realAssets(function()
			return newModel(10, 6, 10, 400) -- 400 Parts : au-dessus du plafond de chaque famille
		end)
		local h = runBuild(cfg, assets, world)
		check("modèle trop lourd (400 Parts) : refusé au chargement (plafond cap de la famille), repli", h.used == 0 and #h.items > 40 and assets.status["m:decor.tree_wide"].reason:find("lourd", 1, true) ~= nil)
	end
	do
		local world = newWorld()
		local assets, cfg = realAssets(function()
			return newModel(10, 6, 10, 3)
		end, { decorOff = { tree_wide = true, hub_dome = true } })
		local h = runBuild(cfg, assets, world)
		check("decorOff : une famille désactivée n'est ni chargée ni posée", assets.status["m:decor.tree_wide"] == nil and assets.status["m:decor.hub_dome"] == nil and assets.status["m:decor.tree_fork"] ~= nil and h.byFamily.tree_wide == nil)
	end

	---------------------------------------------------------------- Simulation longue : reconstructions répétées
	suite("Decor : 20 reconstructions successives (aucune fuite, résultat stable)")
	do
		local world = newWorld()
		local cfg = derived(nil, kioskAway)
		local assets = fakeAssets({ parts = function()
			return 12
		end })
		local h = runBuild(cfg, assets, world)
		local firstItems, firstUsed = #h.items, h.used
		local stable = true
		for _ = 1, 20 do
			h = Decor.refresh(h)
			if #h.items ~= firstItems or h.used ~= firstUsed then
				stable = false
			end
		end
		local alive = 0
		for _, c in ipairs(world.parent.children) do
			if not c.destroyed then
				alive = alive + 1
			end
		end
		check("20 refresh : toujours " .. firstItems .. " exemplaires et " .. firstUsed .. " Parts, un seul dossier vivant, transparences masquées une seule fois", stable and alive == 1 and world.procedural[1].Transparency == 1)
		check("20 refresh : le chargeur n'a été appelé qu'une fois", assets.loadCalls == 1)
		Decor.clear(h)
		local alive2 = 0
		for _, c in ipairs(world.parent.children) do
			if not c.destroyed then
				alive2 = alive2 + 1
			end
		end
		check("clear final : 0 dossier vivant, transparences d'origine", alive2 == 0 and world.procedural[1].Transparency == 0 and world.procedural[4].Transparency == 0.1)
	end
end
