--!nocheck
-- Tests du lot 16 : 8 vendeurs PNJ du hub (SellersData pur, Sellers.build avec repli procédural, Sellers.handle : validation serveur).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } fournis par tests/run_sellers.py (ou par run.luau une fois branché).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2.
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name, environment = RT.env })()
	end
	local D = load("roblox/src/ReplicatedStorage/SellersData.lua", "SellersData")
	local K = load("roblox/src/ReplicatedStorage/KioskData.lua", "KioskData")
	local DecorData = load("roblox/src/ReplicatedStorage/DecorData.lua", "DecorData")
	local Sellers = load("roblox/src/ServerScriptService/Sellers.lua", "Sellers")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config")
	local M2 = Config.Map2

	local function near(a, b, eps)
		return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
	end
	local function count(t)
		local n = 0
		for _ in pairs(t) do
			n = n + 1
		end
		return n
	end
	local function dist(ax, az, bx, bz)
		return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
	end
	local function cfg(extra)
		local c = { Config = Config, data = D, kioskData = K, decor = DecorData, quiet = true }
		for k, v in pairs(extra or {}) do
			c[k] = v
		end
		return c
	end
	local none = function()
		return nil
	end
	-- Modèle Blender factice d'un vendeur : Etiquette, Lueur, un étal ; taille mesurée réglable.
	local function fakeModel(opts)
		opts = opts or {}
		local m = RT.instance("Model", "vendor_model")
		rawset(m, "__fakeSize", RT.vec(opts.width or 6.4, 8.1, opts.depth or 5.5))
		local names = opts.names or { "Etiquette__3A2C24", "Lueur__FFE296", "Etal__B0A082" }
		for i, n in ipairs(names) do
			local p = RT.instance("Part", n)
			p.Anchored = false
			p.Parent = m
			p.Position = RT.vec(0, 6, -3 + i * 0.01)
		end
		for i = 1, (opts.extraParts or 0) do
			RT.instance("Part", "Extra" .. i).Parent = m
		end
		if opts.script then
			RT.instance("Script", "Mauvais").Parent = m
		end
		return m
	end
	local function descendants(o)
		return #o:GetDescendants()
	end
	local function newParent()
		return RT.instance("Folder", "world")
	end

	---------------------------------------------------------------- données
	suite("SellersData : 8 catégories, un vendeur chacune")
	check("8 vendeurs", #D.VENDORS == 8)
	local wanted = { "eggs", "luck", "coins", "base", "combat", "pass", "packs", "cosmetics" }
	check("Exactement un vendeur par catégorie, dans l'ordre des onglets", (function()
		for i, id in ipairs(wanted) do
			if D.VENDORS[i].id ~= id then
				return false
			end
		end
		return count(D.ACTIONS) == 8
	end)())
	check("Identifiants, onglets et clés de modèle uniques ; onglet = catégorie", (function()
		local ids, tabs, keys, assets = {}, {}, {}, {}
		for _, v in ipairs(D.VENDORS) do
			if ids[v.id] or tabs[v.tab] or keys[v.key] or assets[v.asset] or v.tab ~= v.id or v.key ~= "vendor_" .. v.id then
				return false
			end
			ids[v.id], tabs[v.tab], keys[v.key], assets[v.asset] = true, true, true, true
		end
		return true
	end)())
	check("Identifiants de modèles Blender de la spec", (function()
		local exp = { eggs = 138633300069014, luck = 137414127061497, coins = 82919202214027, base = 79064954843258, combat = 105059296701916, pass = 72959276245033, packs = 80912619819088, cosmetics = 82243751363820 }
		for id, asset in pairs(exp) do
			if D.vendor(id).asset ~= asset then
				return false
			end
		end
		return true
	end)())
	check("D.vendor : nil pour un identifiant inconnu ou de mauvais type", D.vendor("zzz") == nil and D.vendor(5) == nil and D.vendor(nil) == nil)
	check("Étiquettes : titre, emoji, 2 lignes d'exemple, texte d'étiquette non vides", (function()
		for _, v in ipairs(D.VENDORS) do
			if type(v.title) ~= "string" or #v.title == 0 or type(v.emoji) ~= "string" or #v.emoji == 0 or #v.lines ~= 2 or #v.lines[1] == 0 or #v.lines[2] == 0 or #D.labelText(v) <= #v.title then
				return false
			end
			if #D.priceLine(v, nil) == 0 or #D.priceLine(v, Config) == 0 then
				return false
			end
		end
		return true
	end)())
	check("Chaque achat de Config.PRODUCTS / PASSES appartient à un vendeur (aucun oublié)", (function()
		local owner = {}
		for _, v in ipairs(D.VENDORS) do
			for _, k in ipairs(v.keys) do
				if owner[k] then
					return false -- un achat dans deux catégories
				end
				owner[k] = v.id
			end
		end
		for k in pairs(Config.PRODUCTS) do
			if not owner[k] then
				return false
			end
		end
		for k in pairs(Config.PASSES) do
			if not owner[k] then
				return false
			end
		end
		return true
	end)())
	check("Tous les achats listés ont un prix de référence", (function()
		for _, v in ipairs(D.VENDORS) do
			for _, k in ipairs(v.keys) do
				if type(D.PRICES[k]) ~= "number" then
					return false
				end
			end
		end
		return true
	end)())
	check("Ligne de prix sans Config : « Œufs : de 15 à 6 999 R$ »", D.priceLine(D.vendor("eggs"), nil) == "Œufs : de 15 à 6 999 R$")
	check("fmtR : milliers et entrées invalides", D.fmtR(6999) == "6 999" and D.fmtR(15) == "15" and D.fmtR(1000000) == "1 000 000" and D.fmtR("x") == "?" and D.fmtR(nil) == "?")
	check("Prix du Config réel : seuls les achats disponibles comptent (id réel ET rareté publiée : les œufs sans espèce sont exclus)", (function()
		local lo, hi, n = D.priceRange(D.vendor("eggs"), Config)
		local liveLo, liveHi, liveN = nil, nil, 0
		for _, k in ipairs(D.vendor("eggs").keys) do
			local def = Config.PRODUCTS[k]
			if def and Config.purchasable(def) and Config.tierLive(def.eggTier) then
				liveN = liveN + 1
				liveLo = (liveLo == nil or def.robux < liveLo) and def.robux or liveLo
				liveHi = (liveHi == nil or def.robux > liveHi) and def.robux or liveHi
			end
		end
		return n == liveN and n >= 4 and lo == liveLo and hi == liveHi and D.priceLine(D.vendor("eggs"), Config) == "Œufs : de " .. D.fmtR(liveLo) .. " à " .. D.fmtR(liveHi) .. " R$"
	end)())
	check("Aucun achat ouvert : « bientôt disponible », sans urgence", (function()
		local empty = { PRODUCTS = {}, PASSES = {} }
		local line = D.priceLine(D.vendor("cosmetics"), empty)
		return string.find(line, "bientôt disponible", 1, true) ~= nil and string.find(line, "!", 1, true) == nil
	end)())
	check("Un seul prix : « Pièces : 19 R$ »", (function()
		local one = { PRODUCTS = { CoinPackS = { id = 5, robux = 19 } }, PASSES = {} }
		return D.priceLine(D.vendor("coins"), one) == "Pièces : 19 R$"
	end)())
	check("Textes d'étiquette sans urgence ni appel (aucun ❗, aucun point d'exclamation)", (function()
		for _, v in ipairs(D.VENDORS) do
			local all = D.labelText(v) .. D.priceLine(v, nil) .. v.lines[1] .. v.lines[2]
			if string.find(all, "❗", 1, true) or string.find(all, "!", 1, true) then
				return false
			end
		end
		return true
	end)())

	---------------------------------------------------------------- placement
	suite("SellersData.layout : cercle autour du kiosque, aucun chevauchement")
	local L = D.layout(M2, K, { decor = DecorData })
	check("8 vendeurs placés, aucun manquant", #L.list == 8 and #L.missing == 0)
	check("Centre = Config.Map2.kiosk", L.center.x == M2.kiosk.x and L.center.z == M2.kiosk.z)
	check("Au moins 2 vendeurs à 14 à 22 studs du kiosque (écart de spec : les autres plus loin, voir RING_FAR), tous à 14 à 45", (function()
		local inner = 0
		for _, p in ipairs(L.list) do
			local d = dist(p.x, p.z, L.center.x, L.center.z)
			if d < 14 - 1e-6 or d > 45 then
				return false
			end
			if d <= 22 + 1e-6 then
				inner = inner + 1
			end
		end
		return inner >= 2
	end)())
	check("Les vendeurs du cercle intérieur passent avant les lointains (ordre des onglets)", L.list[1].ring <= 22 and L.list[2].ring <= 22)
	check("Chaque vendeur fait face au centre du kiosque", (function()
		for _, p in ipairs(L.list) do
			if p.faceX ~= L.center.x or p.faceZ ~= L.center.z then
				return false
			end
		end
		return true
	end)())
	check("Hors kiosque (socle 7,7) avec marge", (function()
		for _, p in ipairs(L.list) do
			if dist(p.x, p.z, L.center.x, L.center.z) < K.RADIUS + D.RADIUS + D.MARGIN then
				return false
			end
		end
		return true
	end)())
	local worst = ""
	check("Aucun obstacle de Config.Map2 (halle, fontaine, tapis, bac, étals, piste, portails, arrivée, bord, chemins)", (function()
		for _, p in ipairs(L.list) do
			local hit, what = K.overlap(M2, p.x, p.z, D.RADIUS, D.MARGIN)
			if hit then
				worst = p.id .. " : " .. tostring(what)
				return false
			end
		end
		return true
	end)())
	check("Jamais sur le chemin des tapis (emprise du tapis du marché + arrivée)", (function()
		local b = M2.belt
		for _, p in ipairs(L.list) do
			if p.x > b.x0 - 3 - D.RADIUS and p.x < b.bin.x + 8 + D.RADIUS and p.z > -(b.width / 2 + 14) - D.RADIUS and p.z < b.width / 2 + 8 + D.RADIUS then
				return false
			end
			if dist(p.x, p.z, M2.plazaArrival.x, M2.plazaArrival.z) < 4 + D.RADIUS then
				return false
			end
		end
		return true
	end)())
	check("Jamais sur le décor existant (bancs et lampadaires de la place)", (function()
		for _, p in ipairs(L.list) do
			for _, e in ipairs(DecorData.existing) do
				if dist(p.x, p.z, e[1], e[2]) < e[3] + D.RADIUS then
					return false
				end
			end
		end
		return true
	end)())
	check("Jamais dans les zones de vol, de combat ou de portail (piste, portails, grand œuf, arène, château)", (function()
		for _, p in ipairs(L.list) do
			if dist(p.x, p.z, M2.bigEgg.x, M2.bigEgg.z) < M2.bigEgg.r + D.RADIUS or dist(p.x, p.z, M2.arena.x, M2.arena.z) < M2.arena.r + D.RADIUS then
				return false
			end
			if p.x > M2.castle.x0 - 20 then
				return false
			end
			if math.abs(p.z - M2.portalHub.z) < 12 and p.x > M2.portalHub.x0 - 12 and p.x < M2.portalHub.x1 + 12 then
				return false
			end
		end
		return true
	end)())
	check("Aucun chevauchement entre vendeurs (deux rayons + espace)", (function()
		for i = 1, #L.list do
			for j = i + 1, #L.list do
				if dist(L.list[i].x, L.list[i].z, L.list[j].x, L.list[j].z) < 2 * D.RADIUS + D.SPACING - 1e-6 then
					return false
				end
			end
		end
		return true
	end)())
	check("Dans la place (rayon 60)", (function()
		for _, p in ipairs(L.list) do
			if dist(p.x, p.z, M2.plaza.x, M2.plaza.z) + D.RADIUS > M2.plaza.r then
				return false
			end
		end
		return true
	end)())
	check("Placement déterministe (deux appels identiques)", (function()
		local L2 = D.layout(M2, K, { decor = DecorData })
		for i, p in ipairs(L.list) do
			if p.id ~= L2.list[i].id or p.x ~= L2.list[i].x or p.z ~= L2.list[i].z then
				return false
			end
		end
		return true
	end)())
	check("Un centre bloqué (sur le tapis) : vendeurs manquants signalés, pas d'erreur", (function()
		local bad = D.layout(M2, K, { center = { x = 40, z = 0 }, decor = DecorData })
		return #bad.list + #bad.missing == 8 and #bad.missing > 0
	end)())
	check("footprints : 8 emprises { x, z, r } pour le décor", (function()
		local f = D.footprints(L)
		return #f == 8 and f[1].r == D.RADIUS + D.MARGIN and #D.footprints(nil) == 0
	end)())
	print("    (placement : " .. (worst ~= "" and worst or "ok") .. ")")

	---------------------------------------------------------------- construction
	suite("Sellers.build : repli procédural (aucun modèle chargeable)")
	local parent = newParent()
	local folder, prompts, info = Sellers.build(parent, cfg({ loadAsset = none }))
	check("Dossier « Sellers » seul enfant du parent", folder.Name == D.MODEL_NAME and #parent:GetChildren() == 1 and folder.Parent == parent)
	check("8 modèles Vendor_<id>", (function()
		local seen = 0
		for _, id in ipairs(wanted) do
			local m = folder:FindFirstChild("Vendor_" .. id)
			if m ~= nil and m:GetAttribute("SellerId") == id then
				seen = seen + 1
			end
		end
		return seen == 8 and #folder:GetChildren() == 8
	end)())
	check("Tous en repli avec une raison lisible", (function()
		for _, id in ipairs(wanted) do
			local v = info.vendors[id]
			if v == nil or v.usedAsset ~= false or type(v.reason) ~= "string" or #v.reason == 0 then
				return false
			end
		end
		return true
	end)())
	check("Chaque vendeur a une Etiquette et une Lueur (avec PointLight)", (function()
		for _, id in ipairs(wanted) do
			local m = info.vendors[id].model
			local et, lu = m:FindFirstChild(D.LABEL_PART, true), m:FindFirstChild(D.LIGHT_PART, true)
			if et == nil or lu == nil or lu:FindFirstChildOfClass("PointLight") == nil then
				return false
			end
		end
		return true
	end)())
	check("Étiquette : SurfaceGui avec un texte non vide = emoji + titre", (function()
		for _, id in ipairs(wanted) do
			local et = info.vendors[id].model:FindFirstChild(D.LABEL_PART, true)
			local gui = et:FindFirstChildOfClass("SurfaceGui")
			local lab = gui ~= nil and gui:FindFirstChildOfClass("TextLabel") or nil
			if lab == nil or lab.Text ~= D.labelText(D.vendor(id)) or #lab.Text == 0 then
				return false
			end
		end
		return true
	end)())
	check("Aucun texte vide dans tout le dossier (TextLabel)", (function()
		local n = 0
		for _, d in ipairs(folder:GetDescendants()) do
			if d.ClassName == "TextLabel" then
				n = n + 1
				if type(d.Text) ~= "string" or d.Text == "" then
					return false
				end
			end
		end
		return n == 8 * 5
	end)())
	check("Billboard : 60 studs, taille fixe lisible mobile, icône + nom + prix + 2 exemples", (function()
		for _, id in ipairs(wanted) do
			local v = D.vendor(id)
			local g = info.vendors[id].billboard
			if g == nil or g.MaxDistance ~= 60 or g.AlwaysOnTop ~= false or g.Size == nil or D.BILLBOARD.width < 240 or D.BILLBOARD.height < 100 then
				return false
			end
			local fond = g:FindFirstChild("Fond")
			if fond == nil or fond:FindFirstChild("Icone").Text ~= v.emoji .. " " .. v.title or fond:FindFirstChild("Prix").Text ~= D.priceLine(v, Config) then
				return false
			end
			if fond:FindFirstChild("Exemple1").Text ~= v.lines[1] or fond:FindFirstChild("Exemple2").Text ~= v.lines[2] or fond:FindFirstChild("Icone").TextSize < 24 or fond:FindFirstChild("Prix").TextSize < 18 then
				return false
			end
		end
		return true
	end)())
	check("Prompts : « Parler », un par vendeur, étiquetés, distance 9, tag SellerPrompt", (function()
		if count(prompts) ~= 8 then
			return false
		end
		for _, id in ipairs(wanted) do
			local pr = prompts[id]
			if pr == nil or pr:GetAttribute("SellerAction") ~= id or pr.ActionText ~= "Parler" or pr.ObjectText ~= D.vendor(id).title then
				return false
			end
			if pr.MaxActivationDistance ~= D.PROMPT.distance or pr.HoldDuration ~= D.PROMPT.hold or pr.RequiresLineOfSight ~= false then
				return false
			end
			if not RT.services.CollectionService:HasTag(pr, "SellerPrompt") then
				return false
			end
		end
		return true
	end)())
	check("Les vendeurs n'interpellent pas : aucun ❗, aucun Sound, aucun Script, aucun mouvement (tout ancré)", (function()
		for _, d in ipairs(folder:GetDescendants()) do
			if d.ClassName == "Sound" or d.ClassName == "Script" or d.ClassName == "LocalScript" or d.ClassName == "Humanoid" or d.ClassName == "BodyMover" then
				return false
			end
			if d.ClassName == "TextLabel" and string.find(d.Text, "❗", 1, true) ~= nil then
				return false
			end
			if d.ClassName == "Part" and d.Anchored ~= true then
				return false
			end
		end
		return true
	end)())
	check("Budget : au plus 14 Parts par vendeur", (function()
		for _, id in ipairs(wanted) do
			local v = info.vendors[id]
			if v.parts < 8 or v.parts > 14 then
				return false
			end
		end
		return true
	end)())
	check("Positions construites = placement calculé, tournées vers le centre", (function()
		for _, p in ipairs(L.list) do
			local v = info.vendors[p.id]
			if not near(v.x, p.x) or not near(v.z, p.z) then
				return false
			end
			-- le point « devant » (local 0,-1) arrive du côté du centre du kiosque
			local fx, fz = K.toWorld(p.x, p.z, v.yaw, 0, -1)
			if dist(fx, fz, p.faceX, p.faceZ) >= dist(p.x, p.z, p.faceX, p.faceZ) then
				return false
			end
		end
		return true
	end)())
	check("Config.Assets.Enabled = false : repli partout, raison « Assets désactivé »", (function()
		local C2 = {}
		for k, v in pairs(Config) do
			C2[k] = v
		end
		C2.Assets = { Enabled = false, decorMaxParts = 220 }
		local f2, _, i2 = Sellers.build(newParent(), cfg({ Config = C2, loadAsset = function()
			return fakeModel()
		end }))
		return #f2:GetChildren() == 8 and i2.vendors.eggs.usedAsset == false and string.find(i2.vendors.eggs.reason, "Assets", 1, true) ~= nil
	end)())

	suite("Sellers.build : modèles Blender, repli par vendeur")
	local loaded = {}
	local _, _, iMix = Sellers.build(newParent(), cfg({ loadAsset = function(id)
		loaded[#loaded + 1] = id
		if id == D.vendor("eggs").asset or id == D.vendor("luck").asset then
			return fakeModel()
		elseif id == D.vendor("coins").asset then
			return fakeModel({ width = 80 }) -- dimensions absurdes
		elseif id == D.vendor("base").asset then
			return fakeModel({ extraParts = 100 }) -- trop de Parts
		elseif id == D.vendor("combat").asset then
			return fakeModel({ script = true, names = { "Etal__B0A082" } }) -- script retiré ; ni Etiquette ni Lueur : créées
		elseif id == D.vendor("pass").asset then
			error("hors ligne")
		end
		return nil
	end }))
	check("Chaque vendeur charge SON modèle (8 ids demandés)", #loaded == 8)
	check("Modèles valides utilisés", iMix.vendors.eggs.usedAsset == true and iMix.vendors.luck.usedAsset == true)
	check("Modèle absurde, trop lourd, erreur réseau, vide : repli procédural pour CE vendeur seulement", iMix.vendors.coins.usedAsset == false and iMix.vendors.base.usedAsset == false and iMix.vendors.pass.usedAsset == false and iMix.vendors.packs.usedAsset == false and iMix.vendors.cosmetics.usedAsset == false)
	check("Modèle sans Etiquette ni Lueur : elles sont créées, le Script est retiré", (function()
		local m = iMix.vendors.combat.model
		if iMix.vendors.combat.usedAsset ~= true or m:FindFirstChild(D.LABEL_PART, true) == nil or m:FindFirstChild(D.LIGHT_PART, true) == nil then
			return false
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d.ClassName == "Script" then
				return false
			end
		end
		return true
	end)())
	check("Modèle Blender : Etiquette suffixée « __3A2C24 » reconnue, prompt et billboard posés dessus", (function()
		local v = iMix.vendors.eggs
		return v.prompt ~= nil and v.prompt.Parent ~= nil and string.find(v.prompt.Parent.Name, "Etiquette", 1, true) == 1 and v.billboard ~= nil and v.billboard.Parent == v.prompt.Parent
	end)())
	check("8 vendeurs construits malgré les échecs", count(iMix.vendors) == 8)
	check("Modèle mélangé : étiquette texte non vide sur tous", (function()
		for _, id in ipairs(wanted) do
			local et = iMix.vendors[id].prompt.Parent
			local gui = et:FindFirstChildOfClass("SurfaceGui")
			if gui == nil or #gui:FindFirstChildOfClass("TextLabel").Text == 0 then
				return false
			end
		end
		return true
	end)())

	suite("Sellers.build : idempotence, aucune fuite d'instances (20 reconstructions)")
	local pI = newParent()
	local liveCounts, allDeltas = {}, {}
	local prevAll
	local lastFolder
	for i = 1, 20 do
		local f = Sellers.build(pI, cfg({ loadAsset = (i % 2 == 0) and none or function()
			return fakeModel()
		end }))
		lastFolder = f
		liveCounts[i] = descendants(pI)
		if i == 1 then
			prevAll = #RT.all
		elseif i % 2 == 0 and i > 2 then
			allDeltas[#allDeltas + 1] = #RT.all - prevAll
			prevAll = #RT.all
		else
			prevAll = #RT.all
		end
	end
	check("Un seul dossier « Sellers » dans le parent après 20 reconstructions", #pI:GetChildren() == 1 and pI:GetChildren()[1] == lastFolder)
	check("Instances vivantes constantes (même nombre à chaque reconstruction de même type)", (function()
		for i = 3, 20 do
			if liveCounts[i] ~= liveCounts[i - 2] then
				return false
			end
		end
		return liveCounts[1] > 100
	end)())
	check("Aucune accumulation : création par reconstruction constante", (function()
		for i = 2, #allDeltas do
			if allDeltas[i] ~= allDeltas[1] then
				return false
			end
		end
		return #allDeltas >= 5
	end)())
	check("Les anciens dossiers sont détruits (hors de l'arbre)", (function()
		local p2 = newParent()
		local f1 = Sellers.build(p2, cfg({ loadAsset = none }))
		local f2 = Sellers.build(p2, cfg({ loadAsset = none }))
		local kids = p2:GetChildren()
		return #kids == 1 and kids[1] == f2 and kids[1] ~= f1
	end)())
	check("Sans Config : assertion claire", (function()
		local ok = pcall(Sellers.build, newParent(), {})
		return ok == false
	end)())

	---------------------------------------------------------------- validation serveur
	suite("Sellers.handle : chaque vendeur ouvre le bon onglet, validation serveur")
	local player = { Name = "Alice", UserId = 1 }
	local clockNow = 100
	local near_ = true
	local asked = {}
	local function ctx(extra)
		local c = {
			Config = Config, data = D,
			inRange = function(_, id)
				asked[#asked + 1] = id
				return near_
			end,
			clock = function()
				return clockNow
			end,
		}
		for k, v in pairs(extra or {}) do
			c[k] = v
		end
		return c
	end
	local allBefore = #RT.all
	check("Sans contexte / sans inRange / contexte non table : refus « contexte »", Sellers.handle(player, "eggs").reason == "contexte" and Sellers.handle(player, "eggs", { Config = Config }).reason == "contexte" and Sellers.handle(player, "eggs", 5).reason == "contexte")
	check("Joueur nil : refus « joueur »", Sellers.handle(nil, "eggs", ctx()).reason == "joueur")
	local badOk = true
	for _, bad in ipairs({ 5, true, {}, { id = 7 }, { id = {} }, "", "Eggs", "EGGS", "eggs ", "eggs\0", "__index", "shop", "calendar", string.rep("a", 500), "oeufs" }) do
		local r = Sellers.handle(player, bad, ctx())
		if r.ok ~= false or r.reason ~= "action" then
			badOk = false
		end
	end
	check("Actions invalides : refus « action »", badOk)
	check("Aucune distance interrogée pour une action invalide", #asked == 0)
	local tabsOk = true
	for i, id in ipairs(wanted) do
		clockNow = 1000 + i * 10
		local r = Sellers.handle({ Name = "P" .. i, UserId = 10 + i }, id, ctx())
		if not (r.ok == true and r.id == id and r.tab == id and r.payload.panel == "shop" and r.payload.tab == id and r.payload.vendor == id) then
			tabsOk = false
		end
	end
	check("Chaque vendeur ouvre la boutique sur SON onglet (8 sur 8)", tabsOk)
	check("Action sous forme de table { id = ... } acceptée", (function()
		clockNow = 3000
		local r = Sellers.handle({ Name = "T" }, { id = "packs" }, ctx())
		return r.ok == true and r.tab == "packs"
	end)())
	near_ = false
	check("Trop loin : refus « distance » (mesure serveur)", Sellers.handle(player, "eggs", ctx()).reason == "distance")
	check("inRange qui plante : refus « distance »", Sellers.handle(player, "eggs", ctx({ inRange = function()
		error("boum")
	end })).reason == "distance")
	check("inRange qui renvoie autre chose que vrai : refus", Sellers.handle(player, "eggs", ctx({ inRange = function()
		return "oui"
	end })).reason == "distance")
	near_ = true
	clockNow = 100
	local okFirst = Sellers.handle(player, "luck", ctx())
	clockNow = 100.2
	local tooSoon = Sellers.handle(player, "luck", ctx())
	clockNow = 100 + D.COOLDOWN + 0.01
	local later = Sellers.handle(player, "luck", ctx())
	check("Pause par joueur : 2e demande trop rapide refusée, puis acceptée", okFirst.ok == true and tooSoon.ok == false and tooSoon.reason == "pause" and later.ok == true)
	check("La pause d'un joueur ne bloque pas un autre", (function()
		clockNow = 200
		local a = Sellers.handle({ Name = "A" }, "eggs", ctx())
		clockNow = 200.1
		local b = Sellers.handle({ Name = "B" }, "eggs", ctx())
		return a.ok and b.ok
	end)())
	check("Horloge qui recule : demande acceptée (pas de blocage définitif)", (function()
		local pl = { Name = "C" }
		clockNow = 500
		Sellers.handle(pl, "eggs", ctx())
		clockNow = 5
		return Sellers.handle(pl, "eggs", ctx()).ok == true
	end)())
	check("Horloge invalide : refus « contexte »", Sellers.handle({ Name = "D" }, "eggs", ctx({ clock = function()
		return "x"
	end })).reason == "contexte")
	check("Sellers.forget : oublie la pause du joueur", (function()
		local pl = { Name = "E" }
		clockNow = 700
		Sellers.handle(pl, "eggs", ctx())
		clockNow = 700.1
		local blocked = Sellers.handle(pl, "eggs", ctx()).reason == "pause"
		Sellers.forget(pl)
		return blocked and Sellers.handle(pl, "eggs", ctx()).ok == true
	end)())
	check("handle ne crée aucune instance", #RT.all == allBefore)
	check("Sellers.inRange : portée serveur mesurée sur la position construite", (function()
		local v = info.vendors.eggs
		return Sellers.inRange(info, "eggs", v.x + 5, v.z, D) and not Sellers.inRange(info, "eggs", v.x + D.SERVER_RANGE + 1, v.z, D) and not Sellers.inRange(info, "zzz", v.x, v.z, D) and not Sellers.inRange(info, "eggs", "x", v.z, D) and not Sellers.inRange(nil, "eggs", 0, 0, D)
	end)())
	check("Portée serveur plus large que celle du prompt (latence)", D.SERVER_RANGE > D.PROMPT.distance)

	suite("Sellers.handle : charge (1000 appels) sans fuite")
	local before = #RT.all
	local accepted = 0
	for i = 1, 1000 do
		clockNow = 9000 + i
		if Sellers.handle({ Name = "P" .. i, UserId = i }, D.VENDORS[(i % 8) + 1].id, ctx()).ok then
			accepted = accepted + 1
		end
	end
	check("1000 joueurs distincts : tous acceptés, aucune instance créée", accepted == 1000 and #RT.all == before)
end
