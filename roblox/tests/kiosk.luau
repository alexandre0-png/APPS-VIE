--!nocheck
-- Tests du lot 8B-kiosque (KioskData pur, Kiosk.build avec repli procédural, Kiosk.handle : validation serveur).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } fournis par tests/run_kiosk.py (ou par run.luau le jour où le coordinateur le branche).
-- Style des tests : pas de `+=`, pas de `continue`, pas de math.atan2 (limites du runner lupa).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local function load(path, name)
		return luau.load(fs.readFile(path), { debugName = name, environment = RT.env })()
	end
	local D = load("roblox/src/ReplicatedStorage/KioskData.lua", "KioskData")
	local Kiosk = load("roblox/src/ServerScriptService/Kiosk.lua", "Kiosk")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config")

	local function near(a, b, eps)
		return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
	end
	local function count(list)
		local n = 0
		for _ in pairs(list) do
			n = n + 1
		end
		return n
	end
	local function newParent()
		local f = RT.instance("Folder", "world")
		return f
	end
	local function descendants(o)
		return #o:GetDescendants()
	end
	-- Modèle Blender factice : 4 panneaux (noms à suffixe de couleur), Lueur, une pièce de plus ; taille mesurée réglable.
	local function fakeModel(opts)
		opts = opts or {}
		local m = RT.instance("Model", "hub_kiosk")
		rawset(m, "__fakeSize", RT.vec(opts.width or 15.4, 12.75, opts.width or 15.4))
		local names = opts.names or { "PanneauBoutique__3A2C24", "PanneauCalendrier__3A2C24", "PanneauProba__3A2C24", "PanneauClassement__3A2C24", "Lueur__FFE296", "Socle__B0A082" }
		for i, n in ipairs(names) do
			local p = RT.instance("Part", n)
			p.Anchored = false
			p.Parent = m
			p.Position = RT.vec(i, 2, 0)
		end
		for i = 1, (opts.extraParts or 0) do
			local p = RT.instance("Part", "Extra" .. i)
			p.Parent = m
		end
		if opts.script then
			local s = RT.instance("Script", "Mauvais")
			s.Parent = m
		end
		return m
	end
	local function cfg(extra)
		local c = { Config = Config, data = D }
		for k, v in pairs(extra or {}) do
			c[k] = v
		end
		return c
	end
	local function promptsOk(prompts)
		for _, p in ipairs(D.PANELS) do
			local pr = prompts[p.id]
			if pr == nil or pr:GetAttribute("KioskAction") ~= p.id or pr.ActionText ~= p.action or pr.ObjectText ~= p.object then
				return false
			end
			if pr.MaxActivationDistance ~= D.PROMPT.distance or pr.HoldDuration ~= D.PROMPT.hold or pr.RequiresLineOfSight ~= false then
				return false
			end
			if not RT.services.CollectionService:HasTag(pr, "KioskPrompt") then
				return false
			end
		end
		return count(prompts) == 4
	end

	---------------------------------------------------------------- données pures
	suite("KioskData : angle sans atan2, orientation vers la halle, emprise sans obstacle")
	check("Config réel chargé (Map2, BELT, PRICING, TIERS)", type(Config.Map2) == "table" and type(Config.BELT) == "table" and type(Config.PRICING) == "table" and #Config.TIERS == 10)
	check("ID du modèle = 90238570290603, son = 82723287691994", D.ASSET_ID == 90238570290603 and D.SOUND.id == "rbxassetid://82723287691994")
	check("4 panneaux aux noms du modèle Blender", #D.PANELS == 4 and D.PANELS[1].part == "PanneauBoutique" and D.PANELS[2].part == "PanneauCalendrier" and D.PANELS[3].part == "PanneauProba" and D.PANELS[4].part == "PanneauClassement")
	check("4 actions : shop, calendar, odds, ranking", D.ACTIONS.shop and D.ACTIONS.calendar and D.ACTIONS.odds and D.ACTIONS.ranking and count(D.ACTIONS) == 4)
	check("D.panel retrouve un panneau, nil sinon", D.panel("odds").part == "PanneauProba" and D.panel("zzz") == nil)
	check("angle : 8 directions", near(D.angle(1, 0), 0) and near(D.angle(0, 1), math.pi / 2) and near(D.angle(-1, 0), math.pi) and near(D.angle(0, -1), -math.pi / 2) and near(D.angle(1, 1), math.pi / 4) and near(D.angle(-1, 1), 3 * math.pi / 4) and near(D.angle(-1, -1), -3 * math.pi / 4) and near(D.angle(1, -1), -math.pi / 4))
	check("angle : entrées invalides = 0", D.angle(nil, 1) == 0 and D.angle("a", 1) == 0 and D.angle(0, 0) == 0 and D.angle(0 / 0, 1) == 0)
	local okDir = true
	for _, u in ipairs({ { -1, 0 }, { 1, 0 }, { 0, 1 }, { 0, -1 }, { -52, -20 }, { 30, 70 }, { -3, 90 } }) do
		local len = math.sqrt(u[1] * u[1] + u[2] * u[2])
		-- repli procédural : comptoir en local (0, -1) ; la pièce du modèle Blender peut être n'importe où
		for _, loc in ipairs({ { 0, -1 }, { 0, 1 }, { 5, 0 }, { -2, -7 } }) do
			local th = D.yawFor(loc[1], loc[2], u[1], u[2])
			local wx, wz = D.toWorld(0, 0, th, loc[1], loc[2])
			local wl = math.sqrt(wx * wx + wz * wz)
			if not (near(wx / wl, u[1] / len, 1e-6) and near(wz / wl, u[2] / len, 1e-6)) then
				okDir = false
			end
		end
	end
	check("yawFor : le point local arrive exactement dans la direction visée (7 directions x 4 positions)", okDir)
	check("yawFor : vecteur local nul ou invalide = défaut (0, -1)", near(D.yawFor(0, 0, -1, 0), D.yawFor(0, -1, -1, 0)) and near(D.yawFor(nil, nil, -1, 0), D.yawFor(0, -1, -1, 0)))
	check("yawFor reste dans [-pi, pi]", (function()
		for _, loc in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local th = D.yawFor(loc[1], loc[2], -52, -20)
			if th < -math.pi - 1e-9 or th > math.pi + 1e-9 then
				return false
			end
		end
		return true
	end)())
	local C = D.CENTER
	local thetaC = D.yawFor(0, -1, D.FACE.x - C.x, D.FACE.z - C.z)
	local sx, sz = D.toWorld(C.x, C.z, thetaC, D.PANELS[1].rel.x, D.PANELS[1].rel.z)
	check("Le comptoir (boutique) est plus près de la halle que le centre du kiosque", math.sqrt((sx - D.FACE.x) ^ 2 + (sz - D.FACE.z) ^ 2) < math.sqrt((C.x - D.FACE.x) ^ 2 + (C.z - D.FACE.z) ^ 2) - 5)
	local calX, calZ = D.toWorld(C.x, C.z, thetaC, D.PANELS[2].rel.x, D.PANELS[2].rel.z)
	check("Le calendrier est derrière (côté opposé à la halle)", math.sqrt((calX - D.FACE.x) ^ 2 + (calZ - D.FACE.z) ^ 2) > math.sqrt((C.x - D.FACE.x) ^ 2 + (C.z - D.FACE.z) ^ 2))
	local ov, what = D.overlap(Config.Map2, C.x, C.z, D.RADIUS, 2)
	check("Emplacement proposé sans obstacle (marge 2 studs) : " .. tostring(what), ov == false)
	check("overlap détecte la halle, le tapis, la fontaine, un étal, un chemin, le bord", (function()
		local M = Config.Map2
		return D.overlap(M, -30, 0, D.RADIUS, 0) == true and D.overlap(M, 10, 0, D.RADIUS, 0) == true and D.overlap(M, M.fountain.x, M.fountain.z + 10, D.RADIUS, 0) == true
			and D.overlap(M, 5, 38, D.RADIUS, 0) == true and D.overlap(M, 0, 40, D.RADIUS, 0) == true and D.overlap(M, 55, 20, D.RADIUS, 0) == true
	end)())
	check("Dans la place (rayon 60) et à portée de marche de la halle (< 80)", math.sqrt(C.x ^ 2 + C.z ^ 2) + D.RADIUS < Config.Map2.plaza.r and math.sqrt((C.x - D.FACE.x) ^ 2 + (C.z - D.FACE.z) ^ 2) < 80)

	---------------------------------------------------------------- construction : repli procédural
	suite("Kiosk.build : repli procédural (chargement impossible)")
	local parent = newParent()
	local model, prompts, info = Kiosk.build(parent, { x = C.x, z = C.z }, cfg({ loadAsset = function()
		return nil
	end }))
	check("Model nommé « Kiosk », seul enfant du parent", model.Name == "Kiosk" and #parent:GetChildren() == 1 and model.Parent == parent)
	check("Repli : usedAsset = false avec une raison lisible", info.usedAsset == false and type(info.reason) == "string" and #info.reason > 0)
	check("4 prompts correctement étiquetés (attribut, tag, textes, distance)", promptsOk(prompts))
	check("Prompts posés sur les panneaux (parents distincts, nommés comme le modèle Blender)", (function()
		for _, p in ipairs(D.PANELS) do
			if prompts[p.id].Parent == nil or prompts[p.id].Parent.Name ~= p.part then
				return false
			end
		end
		return true
	end)())
	check("Pièces : Socle, Toit, Pointe, 4 piliers, Lueur, panneaux, pastille", (function()
		local seen = {}
		for _, d in ipairs(model:GetDescendants()) do
			seen[d.Name] = (seen[d.Name] or 0) + 1
		end
		return seen.Socle == 1 and seen.Toit == 1 and seen.Pointe == 1 and seen.Pilier == 4 and seen.Lueur == 1 and seen.PanneauBoutique == 1 and seen.PanneauCalendrier == 1 and seen.PanneauProba == 1 and seen.PanneauClassement == 1 and seen.PastilleCalendrier == 1
	end)())
	check("Budget de Parts : info.parts <= 40 (mobile)", info.parts >= 15 and info.parts <= 40)
	check("Toutes les Parts sont ancrées", (function()
		for _, d in ipairs(model:GetDescendants()) do
			if d.ClassName == "Part" and d.Anchored ~= true then
				return false
			end
		end
		return true
	end)())
	check("Pastille cachée au départ (Transparency 1, Ready = false)", info.badge ~= nil and info.badge.Transparency == 1 and info.badge:GetAttribute("Ready") == false)
	check("Ambiance : Sound en boucle, id 82723287691994, volume bas, atténuation par distance", info.sound ~= nil and info.sound.Looped == true and info.sound.SoundId == "rbxassetid://82723287691994" and info.sound.Volume > 0 and info.sound.Volume <= 0.3 and info.sound.RollOffMaxDistance == D.SOUND.maxDist and info.sound.RollOffMinDistance == D.SOUND.minDist and info.sound.Playing == true)
	check("Centre mémorisé (attributs du Model et info.center)", model:GetAttribute("KioskCenterX") == C.x and model:GetAttribute("KioskCenterZ") == C.z and info.center.X == C.x and info.center.Z == C.z)
	check("info.yaw = rotation vers la halle", near(info.yaw, thetaC))

	suite("Kiosk.build : sons coupés, volume surchargé par Config.SOUNDS.kiosk_ambience")
	Config.SOUNDS_ENABLED = false
	local _, _, infoMute = Kiosk.build(newParent(), nil, cfg({ loadAsset = function()
		return nil
	end }))
	check("SOUNDS_ENABLED = false : aucun Sound créé", infoMute.sound == nil)
	Config.SOUNDS_ENABLED = true
	Config.SOUNDS.kiosk_ambience = { id = "rbxassetid://1", speed = 1, vol = 0.1 }
	local _, _, infoOver = Kiosk.build(newParent(), nil, cfg({ loadAsset = function()
		return nil
	end }))
	check("Config.SOUNDS.kiosk_ambience remplace id et volume", infoOver.sound ~= nil and infoOver.sound.SoundId == "rbxassetid://1" and near(infoOver.sound.Volume, 0.1))
	Config.SOUNDS.kiosk_ambience = { id = "", vol = 0.1 }
	local _, _, infoEmpty = Kiosk.build(newParent(), nil, cfg({ loadAsset = function()
		return nil
	end }))
	check("Id vide : pas de Sound", infoEmpty.sound == nil)
	Config.SOUNDS.kiosk_ambience = { id = "rbxassetid://1", vol = 9 }
	local _, _, infoLoud = Kiosk.build(newParent(), nil, cfg({ loadAsset = function()
		return nil
	end }))
	check("Volume plafonné à 0,5", infoLoud.sound ~= nil and infoLoud.sound.Volume <= 0.5)
	Config.SOUNDS.kiosk_ambience = nil

	suite("Kiosk.build : modèle Blender (chargement réussi) et tous les refus")
	local loaded = 0
	local p2 = newParent()
	local m2, pr2, i2 = Kiosk.build(p2, nil, cfg({ loadAsset = function(id)
		loaded = loaded + 1
		check("LoadAsset appelé avec l'id du kiosque", id == 90238570290603)
		return fakeModel({ script = true })
	end }))
	check("Modèle chargé utilisé (usedAsset), un seul chargement", i2.usedAsset == true and loaded == 1 and m2.Name == "Kiosk" and m2.Parent == p2)
	check("4 prompts posés sur les pièces du modèle (suffixes de couleur ignorés)", promptsOk(pr2) and pr2.shop.Parent.Name == "PanneauBoutique__3A2C24")
	check("Script du modèle supprimé, Parts ancrées", (function()
		for _, d in ipairs(m2:GetDescendants()) do
			if d.ClassName == "Script" then
				return false
			end
			if d.ClassName == "Part" and d.Anchored ~= true then
				return false
			end
		end
		return true
	end)())
	check("Orientation calculée (info.yaw numérique) et modèle déplacé (PivotTo)", type(i2.yaw) == "number" and rawget(m2, "__pivot") ~= nil)
	check("Pastille et Lueur créées/trouvées", i2.badge ~= nil and i2.badge.Parent == m2 and i2.light ~= nil and i2.light.Name == "Lueur__FFE296")
	check("Ambiance présente avec le modèle", i2.sound ~= nil and i2.sound.Looped == true)

	local wrapped = 0
	local _, _, iw = Kiosk.build(newParent(), nil, cfg({ loadAsset = function()
		wrapped = wrapped + 1
		local container = RT.instance("Model", "LoadAssetResult")
		local inner = fakeModel()
		inner.Parent = container
		return container
	end }))
	check("Conteneur de LoadAsset déballé (modèle intérieur retenu)", iw.usedAsset == true and iw.model.Name == "Kiosk" and iw.model.Parent ~= nil and iw.model.Parent.Name ~= "LoadAssetResult")

	local function refused(label, loader, extra)
		local p = newParent()
		local mm, prs, inf = Kiosk.build(p, nil, cfg(extra and { loadAsset = loader, Config = extra } or { loadAsset = loader }))
		check(label .. " : repli procédural, aucun résidu", inf.usedAsset == false and type(inf.reason) == "string" and #p:GetChildren() == 1 and promptsOk(prs) and mm.Parent == p)
		return inf
	end
	refused("LoadAsset lève une erreur", function()
		error("HTTP 403")
	end)
	local infThrow = refused("LoadAsset lève une erreur (raison)", function()
		error("HTTP 403", 0)
	end)
	check("La raison de l'échec est conservée", string.find(infThrow.reason, "HTTP 403", 1, true) ~= nil)
	refused("LoadAsset renvoie nil", function()
		return nil
	end)
	local heavy = fakeModel({ extraParts = D.MAX_PARTS + 5 })
	local heavyStore = newParent()
	heavy.Parent = heavyStore
	refused("Modèle trop lourd", function()
		return heavy
	end)
	check("Modèle trop lourd détruit (retiré de son dossier)", #heavyStore:GetChildren() == 0)
	local tiny = fakeModel({ width = 1 })
	refused("Modèle minuscule (1 stud) refusé : échelle absurde", function()
		return tiny
	end)
	local empty = RT.instance("Model", "vide")
	rawset(empty, "__fakeSize", RT.vec(15.4, 12, 15.4))
	refused("Modèle sans aucune Part", function()
		return empty
	end)
	local offSize = fakeModel({ width = 20 }) -- 20 / 15,4 = +30 % : hors tolérance, remis à l'échelle (ScaleTo absolu du faux runtime) puis accepté
	local pOff = newParent()
	local _, _, infOff = Kiosk.build(pOff, nil, cfg({ loadAsset = function()
		return offSize
	end }))
	check("Largeur hors tolérance : mise à l'échelle puis modèle accepté", infOff.usedAsset == true and near(offSize:GetExtentsSize().X, 15.4, 0.2))
	local badCfg = {}
	for k, v in pairs(Config) do
		badCfg[k] = v
	end
	badCfg.Assets = { Enabled = false }
	local pDis = newParent()
	local _, _, infDis = Kiosk.build(pDis, nil, { Config = badCfg, data = D, loadAsset = function()
		error("ne doit pas être appelé")
	end })
	check("Config.Assets.Enabled = false : aucun chargement, repli", infDis.usedAsset == false and string.find(infDis.reason, "désactivé", 1, true) ~= nil)
	local fromAssets = 0
	local pAs = newParent()
	local _, _, infAs = Kiosk.build(pAs, nil, cfg({ assets = { cloneModel = function(group, key)
		fromAssets = fromAssets + 1
		check("cloneModel('hub', 'kiosk')", group == "hub" and key == "kiosk")
		return fakeModel()
	end } }))
	check("Module Assets (cloneModel) utilisé en priorité, aucun LoadAsset", infAs.usedAsset == true and fromAssets == 1)
	local _, _, infAs2 = Kiosk.build(newParent(), nil, cfg({ assets = { cloneModel = function()
		return nil
	end } }))
	check("cloneModel sans modèle préchargé : repli", infAs2.usedAsset == false)
	local _, _, infAs3 = Kiosk.build(newParent(), nil, cfg({ assets = { cloneModel = function()
		error("boom")
	end } }))
	check("cloneModel qui lève une erreur : repli", infAs3.usedAsset == false)
	local missing = fakeModel({ names = { "PanneauBoutique", "Socle" } })
	local pMiss = newParent()
	local mMiss, prMiss, infMiss = Kiosk.build(pMiss, nil, cfg({ loadAsset = function()
		return missing
	end }))
	check("Panneaux absents du modèle : socles invisibles, 4 prompts quand même, Lueur et pastille ajoutées", infMiss.usedAsset == true and promptsOk(prMiss) and prMiss.calendar.Parent.Transparency == 1 and infMiss.light ~= nil and infMiss.badge ~= nil)
	check("Config invalide : erreur claire (assert)", not pcall(Kiosk.build, parent, nil, {}) and not pcall(Kiosk.build, parent, nil, nil))
	local pBadCenter = newParent()
	local _, _, infBC = Kiosk.build(pBadCenter, { x = "a", z = 0 / 0 }, cfg({ loadAsset = function()
		return nil
	end }))
	check("Centre invalide : centre par défaut", infBC.center.X == C.x and infBC.center.Z == C.z)

	suite("Kiosk.build : idempotence, aucune fuite d'instances")
	local pI = newParent()
	local loader = function()
		return nil
	end
	local m1 = Kiosk.build(pI, nil, cfg({ loadAsset = loader }))
	local d1, allBefore = descendants(pI), #RT.all
	local m1b = Kiosk.build(pI, nil, cfg({ loadAsset = loader }))
	local d2, allAfter2 = descendants(pI), #RT.all
	local m1c = Kiosk.build(pI, nil, cfg({ loadAsset = loader }))
	local d3, allAfter3 = descendants(pI), #RT.all
	local function isChild(par, o)
		for _, k in ipairs(par:GetChildren()) do
			if k == o then
				return true
			end
		end
		return false
	end
	check("3 appels : un seul Model « Kiosk » dans le parent, les deux premiers sont détruits", #pI:GetChildren() == 1 and not isChild(pI, m1) and not isChild(pI, m1b) and isChild(pI, m1c))
	check("Même nombre d'instances dans le parent après 1, 2 et 3 appels", d1 == d2 and d2 == d3 and d1 > 20)
	check("Chaque reconstruction crée le même nombre d'instances (pas d'accumulation)", (allAfter2 - allBefore) == (allAfter3 - allAfter2))
	local pM = newParent()
	local mod1 = Kiosk.build(pM, nil, cfg({ loadAsset = function()
		return fakeModel()
	end }))
	local dm1 = descendants(pM)
	local mod2 = Kiosk.build(pM, nil, cfg({ loadAsset = function()
		return fakeModel()
	end }))
	check("Idempotent aussi avec le modèle Blender (1 enfant, même taille, ancien détruit)", #pM:GetChildren() == 1 and descendants(pM) == dm1 and not isChild(pM, mod1) and isChild(pM, mod2))
	local other = RT.instance("Part", "Autre")
	other.Parent = pI
	Kiosk.build(pI, nil, cfg({ loadAsset = loader }))
	check("Les autres enfants du parent ne sont pas touchés", other.Parent == pI and #pI:GetChildren() == 2)

	---------------------------------------------------------------- pastille
	suite("Pastille du calendrier : badgeNeeded et setBadge")
	check("badgeNeeded : jour réclamable", Kiosk.badgeNeeded({ canToday = true }) == true)
	check("badgeNeeded : jour manqué rattrapable avec jeton", Kiosk.badgeNeeded({ canToday = false, eligible = true, catch = 1, states = "ccmft" }) == true)
	check("badgeNeeded : jour manqué sans jeton = non", Kiosk.badgeNeeded({ canToday = false, eligible = true, catch = 0, states = "ccmft" }) == false)
	check("badgeNeeded : non éligible = non", Kiosk.badgeNeeded({ canToday = false, eligible = false, catch = 3, states = "m" }) == false)
	check("badgeNeeded : nil, chaîne, nombre = non", Kiosk.badgeNeeded(nil) == false and Kiosk.badgeNeeded("x") == false and Kiosk.badgeNeeded(5) == false and Kiosk.badgeNeeded({}) == false)
	check("badgeNeeded : champs de mauvais type = non", Kiosk.badgeNeeded({ canToday = "yes", eligible = true, catch = "3", states = 5 }) == false)
	Kiosk.setBadge(info, true)
	check("setBadge(true) : pastille visible, texte du prompt", info.badge.Transparency == 0 and info.badge:GetAttribute("Ready") == true and info.ready == true and string.find(prompts.calendar.ObjectText, "récompense prête", 1, true) ~= nil)
	Kiosk.setBadge(info, true)
	Kiosk.setBadge(info, false)
	check("setBadge(false) : pastille cachée, texte d'origine", info.badge.Transparency == 1 and info.badge:GetAttribute("Ready") == false and prompts.calendar.ObjectText == D.panel("calendar").object)
	Kiosk.setBadge(nil, true)
	Kiosk.setBadge({}, true)
	check("setBadge tolère nil et table vide", true)

	---------------------------------------------------------------- validation serveur
	suite("Kiosk.handle : refus (contexte, joueur, action, distance, pause)")
	local player = { Name = "Alice", UserId = 1 }
	local other2 = { Name = "Bob", UserId = 2 }
	local clockNow = 100
	local near_ = true
	local calls = { inRange = 0, view = 0, top = 0 }
	local function ctx(extra)
		local c = {
			Config = Config, data = D,
			inRange = function()
				calls.inRange = calls.inRange + 1
				return near_
			end,
			clock = function()
				return clockNow
			end,
			now = function()
				return 1700000000
			end,
			calView = function()
				calls.view = calls.view + 1
				return { canToday = true, states = "t", idx = 1 }
			end,
			top = function()
				calls.top = calls.top + 1
				return {}
			end,
		}
		for k, v in pairs(extra or {}) do
			c[k] = v
		end
		return c
	end
	local allBeforeHandle = #RT.all
	local r = Kiosk.handle(player, "shop")
	check("Sans contexte : refus « contexte »", r.ok == false and r.reason == "contexte")
	check("Contexte sans inRange : refus", Kiosk.handle(player, "shop", { Config = Config }).reason == "contexte")
	check("Contexte non table : refus", Kiosk.handle(player, "shop", 5).reason == "contexte")
	check("Joueur nil : refus « joueur »", Kiosk.handle(nil, "shop", ctx()).reason == "joueur")
	for _, bad in ipairs({ 5, true, {}, { id = 7 }, { id = {} }, "", "Shop", "SHOP", "shop ", "calendar\0", "__index", "constructor", string.rep("a", 500), "boutique" }) do
		local rr = Kiosk.handle(player, bad, ctx())
		check("Action invalide refusée : " .. tostring(type(bad) == "string" and #bad <= 12 and bad or type(bad)), rr.ok == false and rr.reason == "action")
	end
	check("Action nil refusée", Kiosk.handle(player, nil, ctx()).reason == "action")
	check("Les refus d'action n'appellent ni inRange ni les fournisseurs de données", calls.inRange == 0 and calls.view == 0 and calls.top == 0)
	near_ = false
	check("Hors de portée : refus « distance » pour les 4 actions", Kiosk.handle(player, "shop", ctx()).reason == "distance" and Kiosk.handle(player, "calendar", ctx()).reason == "distance" and Kiosk.handle(player, "odds", ctx()).reason == "distance" and Kiosk.handle(player, "ranking", ctx()).reason == "distance")
	check("Hors de portée : aucune donnée lue (calView / top)", calls.view == 0 and calls.top == 0)
	check("inRange qui lève une erreur : refus « distance »", Kiosk.handle(player, "shop", ctx({ inRange = function()
		error("racine absente")
	end })).reason == "distance")
	check("inRange qui renvoie autre chose que true : refus", Kiosk.handle(player, "shop", ctx({ inRange = function()
		return 1
	end })).reason == "distance" and Kiosk.handle(player, "shop", ctx({ inRange = function()
		return nil
	end })).reason == "distance")
	near_ = true
	check("Horloge invalide : refus « contexte »", Kiosk.handle(player, "shop", ctx({ clock = function()
		return "x"
	end })).reason == "contexte")
	local first = Kiosk.handle(player, "shop", ctx())
	check("Action valide à portée : ok", first.ok == true and first.id == "shop" and first.payload.panel == "shop")
	clockNow = 100.2
	check("Deuxième demande trop tôt (0,2 s) : refus « pause »", Kiosk.handle(player, "shop", ctx()).reason == "pause")
	check("Un autre joueur n'est pas bloqué par la pause du premier", Kiosk.handle(other2, "shop", ctx()).ok == true)
	check("Les refus ne rallongent pas la pause (le compte part de la dernière action acceptée)", (function()
		clockNow = 100 + D.COOLDOWN + 0.01
		return Kiosk.handle(player, "shop", ctx()).ok == true
	end)())
	check("Horloge qui recule : action acceptée sans blocage durable", (function()
		clockNow = 5
		return Kiosk.handle(player, "shop", ctx()).ok == true
	end)())
	Kiosk.forget(player)
	clockNow = 5.01
	check("forget : la pause du joueur est oubliée", Kiosk.handle(player, "shop", ctx()).ok == true)
	check("handle ne crée aucune instance", #RT.all == allBeforeHandle)

	suite("Kiosk.handle : contenu des 4 interactions")
	local t = 1000
	local function fresh()
		t = t + 10
		clockNow = t
		return ctx()
	end
	local rc = Kiosk.handle(player, { id = "calendar" }, fresh())
	check("calendar (action sous forme de table) : vue transmise et ready = true", rc.ok == true and rc.payload.panel == "calendar" and rc.payload.view.idx == 1 and rc.payload.ready == true)
	local rc2 = Kiosk.handle(player, "calendar", (function()
		local c = fresh()
		c.calView = function()
			return "pas une table"
		end
		return c
	end)())
	check("calendar : vue invalide ignorée (nil, ready = false)", rc2.ok == true and rc2.payload.view == nil and rc2.payload.ready == false)
	local rc3 = Kiosk.handle(player, "calendar", (function()
		local c = fresh()
		c.calView = nil
		return c
	end)())
	check("calendar : sans fournisseur de vue, l'action reste valide", rc3.ok == true and rc3.payload.ready == false)
	local rc4 = Kiosk.handle(player, "calendar", (function()
		local c = fresh()
		c.calView = function()
			error("profil non chargé")
		end
		return c
	end)())
	check("calendar : fournisseur qui lève une erreur = refus « erreur », pas de plantage", rc4.ok == false and rc4.reason == "erreur")
	check("Un refus « erreur » ne déclenche pas la pause", Kiosk.handle(player, "shop", ctx()).ok == true)

	local snapPricing = {}
	for k, v in pairs(Config.PRICING) do
		snapPricing[k] = { v.tier, v.coinCost, v.robuxCost }
	end
	local ro = Kiosk.handle(player, "odds", fresh())
	check("odds : ok, 10 lignes de raretés", ro.ok == true and ro.payload.panel == "odds" and #ro.payload.rows == 10)
	local sumN, sumG = 0, 0
	for _, row in ipairs(ro.payload.rows) do
		sumN = sumN + row.normal
		sumG = sumG + row.golden
	end
	check("odds : les pourcentages du tapis normal et doré font 100 %", near(sumN, 100, 1e-6) and near(sumG, 100, 1e-6))
	check("odds : Commun en tête (~50 %), Exclusif hors tapis (0)", ro.payload.rows[1].name == "Commun" and ro.payload.rows[1].normal > 49 and ro.payload.rows[1].normal < 51 and ro.payload.rows[9].normal == 0 and ro.payload.rows[9].golden == 0)
	check("odds : lignes de texte lisibles (virgule décimale, « hors tapis »)", (function()
		local l1, l9 = ro.payload.lines[1], ro.payload.lines[9]
		return string.find(l1, "Commun : 50,0", 1, true) ~= nil and string.find(l1, "%.") == nil and l9 == "Exclusif : hors tapis"
	end)())
	check("odds : prix = les 4 entrées de Config.PRICING, triées par rareté", #ro.payload.prices == 4 and ro.payload.prices[1].tier <= ro.payload.prices[2].tier and ro.payload.prices[2].tier <= ro.payload.prices[3].tier and ro.payload.prices[3].tier <= ro.payload.prices[4].tier)
	check("odds : prix Robux et pièces exacts, Exclusif « jamais en pièces »", (function()
		for _, p in ipairs(ro.payload.prices) do
			local ref = Config.PRICING[p.key]
			if p.robux ~= ref.robuxCost or p.coins ~= ref.coinCost then
				return false
			end
			if ref.coinCost == nil and p.coinsText ~= "jamais en pièces" then
				return false
			end
		end
		return true
	end)())
	check("odds : Config.PRICING et Config.BELT non modifiés", (function()
		for k, v in pairs(Config.PRICING) do
			local s = snapPricing[k]
			if s == nil or s[1] ~= v.tier or s[2] ~= v.coinCost or s[3] ~= v.robuxCost then
				return false
			end
		end
		return true
	end)())
	local od = Kiosk.oddsData({})
	check("oddsData : Config vide = listes vides, sans erreur", #od.rows == 0 and #od.prices == 0 and #od.lines == 0)
	local od2 = Kiosk.oddsData({ TIERS = { { name = "A" }, { name = "B" } }, BELT = { weights = { normal = { 3, "x" }, golden = { 0, 0 } } }, PRICING = { Z = { tier = 2, robuxCost = "?", coinCost = 5 }, Y = "nope" } })
	check("oddsData : poids invalides ignorés (jamais de division par zéro)", od2.rows[1].normal == 100 and od2.rows[2].normal == 0 and od2.rows[1].golden == 0 and #od2.prices == 1 and od2.prices[1].robux == nil)

	local top = {}
	for i = 1, 14 do
		top[#top + 1] = { name = "Joueur" .. i .. string.rep("x", 40), trophies = 1000 - i }
	end
	top[2] = { name = "Neg", trophies = -50 }
	top[3] = { name = 12, trophies = 7.9 }
	top[4] = { name = "Nan", trophies = 0 / 0 }
	top[5] = "pas une table"
	top[6] = { name = "Enorme", trophies = 1e12 }
	local rk = Kiosk.handle(player, "ranking", (function()
		local c = fresh()
		c.top = function(season, n)
			check("ranking : saison et nombre demandés à top", type(season) == "number" and n == D.MAX_ENTRIES)
			return top
		end
		c.mine = function()
			return { trophies = 42 }
		end
		return c
	end)())
	check("ranking : ok, au plus 10 lignes", rk.ok == true and rk.payload.panel == "ranking" and #rk.payload.entries <= 10 and #rk.payload.entries >= 5)
	check("ranking : noms tronqués à 24, trophées entiers entre 0 et 100000, entrées invalides retirées", (function()
		for _, e in ipairs(rk.payload.entries) do
			if type(e.name) ~= "string" or #e.name > 24 or type(e.trophies) ~= "number" or e.trophies ~= math.floor(e.trophies) or e.trophies < 0 or e.trophies > 100000 then
				return false
			end
		end
		return true
	end)())
	check("ranking : saison = Config.pvpSeason(now) et temps restant dans la semaine", rk.payload.season == Config.pvpSeason(1700000000) and rk.payload.secondsLeft > 0 and rk.payload.secondsLeft <= Config.PVP.seasonSeconds and rk.payload.mine.trophies == 42)
	local rk2 = Kiosk.handle(player, "ranking", (function()
		local c = fresh()
		c.top = nil
		c.mine = nil
		return c
	end)())
	check("ranking : sans classement ni profil, liste vide mais action valide", rk2.ok == true and #rk2.payload.entries == 0 and rk2.payload.mine == nil)
	local rk3 = Kiosk.handle(player, "ranking", (function()
		local c = fresh()
		c.top = function()
			error("DataStore indisponible")
		end
		return c
	end)())
	check("ranking : DataStore en panne = refus « erreur » sans plantage", rk3.ok == false and rk3.reason == "erreur")
	local rk4 = Kiosk.handle(player, "ranking", (function()
		local c = fresh()
		c.top = function()
			return "n'importe quoi"
		end
		return c
	end)())
	check("ranking : réponse de mauvais type = liste vide", rk4.ok == true and #rk4.payload.entries == 0)
	local rk5 = Kiosk.handle(player, "ranking", (function()
		local c = fresh()
		c.now = function()
			return "demain"
		end
		return c
	end)())
	check("ranking : heure invalide = saison 0, pas d'erreur", rk5.ok == true and rk5.payload.season == 0 and rk5.payload.secondsLeft >= 0)

	suite("Kiosk.handle : charge (1000 appels) sans fuite")
	local before = #RT.all
	local accepted = 0
	local weakCount = 0
	for i = 1, 1000 do
		local fakePlayer = { Name = "P" .. i, UserId = i }
		clockNow = 5000 + i
		if Kiosk.handle(fakePlayer, D.PANELS[(i % 4) + 1].id, ctx()).ok then
			accepted = accepted + 1
		end
		weakCount = weakCount + 1
	end
	check("1000 joueurs distincts : tous acceptés, aucune instance créée", accepted == 1000 and #RT.all == before and weakCount == 1000)
end
