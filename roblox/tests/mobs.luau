--!nocheck
-- Tests « Fais les mobs » : (1) combat avec les mêmes modèles Blender que le monde (copie légère publiée par le serveur, repli procédural, budget, aucune fuite),
-- (2) gardiens : un repli par animal, (3) chevalier : silhouette de repli, (4) style des replis (blocs arrondis lisses), (5) ids des pets du lot 31.
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs, newRuntime } (tests/run.luau ou tests/run_mobs.py).
-- Style : pas de `+=`, pas de `continue`, pas de math.atan2, pas de LCG > 2^53 (Park-Miller 48271 mod 2^31-1), état partagé dans la table T (limite de 200 variables locales).
return function(env)
	local check, suite, luau, fs, newRuntime = env.check, env.suite, env.luau, env.fs, env.newRuntime
	local T = {}
	local function load(path, name, environment)
		return luau.load(fs.readFile(path), { debugName = name, environment = environment })()
	end
	local L = load("roblox/src/ReplicatedStorage/BattleLayout.lua", "BattleLayout")
	local Config = load("roblox/src/ReplicatedStorage/Config.lua", "Config", { Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end } })
	local Battle = load("roblox/src/ReplicatedStorage/Battle.lua", "Battle")
	local function rng(seed)
		local s = seed
		return function()
			s = (s * 48271) % 2147483647
			return s / 2147483647
		end
	end

	---------------------------------------------------------------- 1. Fonctions pures du modèle de combat
	suite("Mobs 1 : BattleLayout.modelFits / modelHeight / modelScale (purs)")
	check("Réserve du modèle = étiquettes + écran Changer complet + info-bulle + flash (" .. tostring(L.MODEL_RESERVE) .. ")", L.MODEL_RESERVE == L.MAX_POPUPS * L.COST.popup + L.COST.swapPanel + L.MAX_DOTS * L.COST.swapRow + L.COST.tip + L.COST.flash)
	check("modelFits : 41 instances avec 100 utilisées sous 220 -> oui ; 49 (au-dessus de MODEL_MAX_INSTANCES) -> non ; hors budget -> non",
		L.modelFits(41, 100, 220) == true and L.modelFits(L.MODEL_MAX_INSTANCES + 1, 0, 220) == false and L.modelFits(41, 220 - L.MODEL_RESERVE - 40, 220) == false and L.modelFits(41, 220 - L.MODEL_RESERVE - 41, 220) == true)
	check("modelFits : valeurs absurdes (nil, NaN, 0, chaîne) -> non, sans erreur", L.modelFits(nil, 0, 220) == false and L.modelFits(0 / 0, 0, 220) == false and L.modelFits(0, 0, 220) == false and L.modelFits("3", 0, 220) == false and L.modelFits(3, nil, 220) == false)
	T.hOk = true
	for tier = 1, 10 do
		for _, s in ipairs({ 0.5, 0.8, 1, 1.25, 1.6, 2.1 }) do
			local h = L.modelHeight(tier, s, Config.petTargetHeight, Config.TIER_COUNT)
			if type(h) ~= "number" or h < L.MODEL_MIN_H or h > L.MODEL_MAX_H then
				T.hOk = false
			end
			if tier > 1 and h < L.modelHeight(tier - 1, s, Config.petTargetHeight, Config.TIER_COUNT) - 1e-9 then
				T.hOk = false
			end
		end
	end
	check("modelHeight : même règle que le monde (Config.petTargetHeight), non décroissante avec la rareté, bornée [" .. L.MODEL_MIN_H .. ", " .. L.MODEL_MAX_H .. "]", T.hOk)
	check("modelHeight : pet Commun « Normal » = 3 studs (comme la créature procédurale)", math.abs(L.modelHeight(1, 1, Config.petTargetHeight, Config.TIER_COUNT) - 3) < 1e-6)
	check("modelHeight : sans Config.petTargetHeight (Config réduit de BattleUi) -> même valeur par la formule de repli", math.abs(L.modelHeight(1, 1, nil, nil) - 3) < 1e-6 and L.modelHeight(nil, nil, nil, nil) >= L.MODEL_MIN_H)
	check("modelScale : 1 -> 3 = x3 ; mesure absurde (0, NaN, nil) -> nil", L.modelScale(1, 3) == 3 and L.modelScale(0, 3) == nil and L.modelScale(0 / 0, 3) == nil and L.modelScale(nil, 3) == nil and L.modelScale(1, 1e6) == nil)

	---------------------------------------------------------------- 2. BattleScene : modèle cloné, repli, budget, aucune fuite
	local RT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if RT == nil then
		return
	end
	local created = 0
	local env2 = {}
	for k, v in pairs(RT.env) do
		env2[k] = v
	end
	env2.Instance = { new = function(class)
		created = created + 1
		return RT.instance(class)
	end }
	local BattleScene = load("roblox/src/StarterPlayerScripts/BattleScene.lua", "BattleScene", env2)
	local BattleUi = load("roblox/src/StarterPlayerScripts/BattleUi.lua", "BattleUi", env2)
	local function findAll(root, name)
		local out = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d.Name == name then
				out[#out + 1] = d
			end
		end
		return out
	end
	local function partsOf(m)
		local n = 0
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				n = n + 1
			end
		end
		return n
	end
	-- copie publiée factice : `n` Parts (MeshPart), taille brute 1 x 1 x 1 (les pets Blender mesurent ~1)
	local function template(name, n, sizeY)
		local m = RT.instance("Model", name)
		rawset(m, "__fakeSize", RT.vec(1, sizeY or 1, 1))
		for i = 1, n do
			local p = RT.instance("MeshPart", i == 1 and "Corps__A0784A" or ("Piece" .. i))
			p.Size = RT.vec(i == 1 and 2 or 0.5, i == 1 and 2 or 0.5, i == 1 and 2 or 0.5)
			p.Color = { R = 0.6, G = 0.5, B = 0.3 }
			p.Parent = m
		end
		m:SetAttribute("Parts", n)
		return m
	end
	local function newFolder(spec)
		local f = RT.instance("Folder", "PetModels")
		for idx, n in pairs(spec) do
			template(tostring(idx), n).Parent = f
		end
		return f
	end
	local function newGui()
		local g = RT.instance("ScreenGui", "gui")
		g.Enabled = true
		return g
	end
	local function create(gui, st, folder, reduced)
		return BattleScene.create({
			gui = gui, Config = Config, Battle = Battle, Layout = L, player = { DisplayName = "Moi", UserId = 1 }, payload = { floor = 1 }, view = Battle.view(st), foeName = "Rival", floor = 1,
			reduced = reduced == true, specialState = function(u) return BattleUi.specialState(Config, Battle, u) end, fire = function() end, onChosen = function() end, petModels = folder,
		})
	end
	local function team(idxs)
		local t = {}
		for i, p in ipairs(idxs) do
			t[i] = Battle.unit(Config, { p = p, s = 2, m = 1 }, 1)
		end
		return t
	end

	suite("Mobs 1 : BattleScene clone le modèle publié du pet (ReplicatedStorage.PetModels), repli procédural sinon")
	do
		local gui = newGui()
		local folder = newFolder({ [4] = 12, [5] = 8 })
		local st = Battle.new(4242, team({ 4 }), team({ 7 }))
		local sc = create(gui, st, folder)
		local p1, p2 = findAll(gui, "Puppet1")[1], findAll(gui, "Puppet2")[1]
		check("Modèle présent (espèce 4, 12 Parts) : le pet du joueur est la COPIE du modèle (attribut Source = model, 12 Parts)", sc ~= nil and p1 ~= nil and p1:GetAttribute("Source") == "model" and partsOf(p1) == 12)
		check("Modèle absent (espèce 7) : créature procédurale (Body, pas d'attribut Source)", p2 ~= nil and p2:GetAttribute("Source") == nil and p2:FindFirstChild("Body") ~= nil)
		check("Le modèle publié reste intact dans le dossier (cloné, pas déplacé : 12 Parts)", folder:FindFirstChild("4") ~= nil and partsOf(folder:FindFirstChild("4")) == 12 and folder:FindFirstChild("4").Parent == folder)
		check("Mise à l'échelle : hauteur mesurée 1 -> hauteur de combat (" .. tostring(L.modelHeight(Config.PETS[4].tier, 1, Config.petTargetHeight, Config.TIER_COUNT)) .. ")", p1 ~= nil and math.abs(p1:GetScale() - L.modelHeight(Config.PETS[4].tier, 1, Config.petTargetHeight, Config.TIER_COUNT)) < 1e-6)
		local partsOk = true
		for _, d in ipairs(p1 and p1:GetDescendants() or {}) do
			if d:IsA("BasePart") and (d.Anchored ~= true or d.CanCollide ~= false) then
				partsOk = false
			end
		end
		check("Copie : toutes les Parts ancrées, sans collision ; posée sur le socle (pivot à 0,9 + hauteur / 2)", partsOk and p1 ~= nil and math.abs(p1:GetPivot().Y - (0.9 + p1:GetScale() / 2)) < 1e-6)
		T.countWith = sc and sc.count()
		-- remplacement : le pet 5 (modèle) entre, l'ancien part ; compteur cohérent
		local st2 = Battle.new(4243, team({ 4, 5 }), team({ 7 }))
		local v = Battle.view(st2)
		v.sides[1].active = 2
		sc.update(v, nil)
		RT.step(1.5)
		local after = findAll(gui, "Puppet1")
		check("Changement de pet : une seule créature par camp, la nouvelle est le modèle de l'espèce 5 (8 Parts)", #after == 1 and after[1]:GetAttribute("Source") == "model" and partsOf(after[1]) == 8)
		check("Compteur d'instances : 12 -> 8 Parts, le compteur suit exactement (" .. tostring(T.countWith) .. " -> " .. tostring(sc.count()) .. ")", sc.count() == T.countWith - 4)
		sc.destroy()
		check("Destruction : aucune instance restante, compteur à 0, dossier des modèles intact", #gui:GetDescendants() == 0 and sc.count() == 0 and #folder:GetChildren() == 2)
	end

	suite("Mobs 1 : échecs -> repli (trop lourd, mesure absurde, copie impossible, dossier absent)")
	do
		local gui = newGui()
		local folder = RT.instance("Folder", "PetModels")
		template("1", L.MODEL_MAX_INSTANCES + 5).Parent = folder -- trop lourd
		template("2", 6, 0.0001).Parent = folder -- mesure absurde
		local bad = template("3", 6)
		bad.Parent = folder
		rawset(bad, "Clone", function() error("copie impossible") end)
		local before = created
		local sc1 = create(gui, Battle.new(1, team({ 1 }), team({ 2 })), folder)
		local a, b = findAll(gui, "Puppet1")[1], findAll(gui, "Puppet2")[1]
		check("Modèle trop lourd (" .. (L.MODEL_MAX_INSTANCES + 5) .. " Parts) : repli procédural", a ~= nil and a:GetAttribute("Source") == nil and a:FindFirstChild("Body") ~= nil)
		check("Mesure absurde (hauteur 0,0001) : repli procédural, la copie refusée n'est pas restée dans la scène", b ~= nil and b:GetAttribute("Source") == nil and #findAll(gui, "Piece2") == 0)
		sc1.destroy()
		check("Après destruction : écran vide", #gui:GetDescendants() == 0)
		local sc2 = create(gui, Battle.new(2, team({ 1 }), team({ 2 })), nil)
		check("Aucun dossier PetModels (serveur sans modèles, ou client avant publication) : repli procédural, aucune erreur", sc2 ~= nil and findAll(gui, "Puppet1")[1]:GetAttribute("Source") == nil)
		sc2.destroy()
		local broken = { FindFirstChild = function() error("dossier corrompu") end }
		local sc3 = create(gui, Battle.new(3, team({ 1 }), team({ 2 })), broken)
		check("Dossier qui lève une erreur : repli procédural, la scène se construit", sc3 ~= nil and findAll(gui, "Puppet1")[1]:GetAttribute("Source") == nil)
		sc3.destroy()
		local sc4 = create(gui, Battle.new(4, team({ 3 }), team({ 2 })), folder)
		check("Copie impossible (Clone lève une erreur) : repli procédural", sc4 ~= nil and findAll(gui, "Puppet1")[1]:GetAttribute("Source") == nil)
		sc4.destroy()
		check("Aucune instance restante après ces échecs (" .. (created - before) .. " créées)", #gui:GetDescendants() == 0)
	end

	suite("Mobs 1 : budget (220) et aucune fuite sur 20 combats avec des modèles de 40 Parts pour toutes les espèces")
	do
		local spec = {}
		local r = rng(31415)
		for i = 1, #Config.PETS do
			spec[i] = i % 2 == 0 and 40 or (1 + math.floor(r() * 39))
		end
		local folder = newFolder(spec)
		T.peak, T.live, T.leak, T.models, T.procs, T.errs0 = 0, 0, 0, 0, 0, #RT.errors
		for c = 1, 20 do
			local gui = newGui()
			local st = Battle.new(1000 + c * 7919, Battle.towerTeam(Config, 1 + c % 10), Battle.towerTeam(Config, 3 + (c * 3) % 14))
			local sc = create(gui, st, folder, c % 2 == 0)
			if sc == nil then
				T.leak = T.leak + 1
			else
				local turns = 0
				while not st.over and turns < 60 do
					turns = turns + 1
					local ev = Battle.turn(st, Battle.aiAction(st, 1))
					sc.update(Battle.view(st), { delay = sc.cues(ev) })
					RT.step(0.7)
					T.live = math.max(T.live, #gui:GetDescendants())
					T.peak = math.max(T.peak, sc.peak())
					for side = 1, 2 do
						local pz = findAll(gui, "Puppet" .. side)[1]
						if pz and pz:GetAttribute("Source") == "model" then
							T.models = T.models + 1
						elseif pz then
							T.procs = T.procs + 1
						end
					end
				end
				RT.step(2)
				T.live = math.max(T.live, #gui:GetDescendants())
				sc.destroy()
				if #gui:GetDescendants() ~= 0 or sc.count() ~= 0 then
					T.leak = T.leak + 1
				end
			end
		end
		check("20 combats : aucune fuite (écran vide, compteur à 0 après chaque destruction)", T.leak == 0)
		check("Plafond respecté avec les modèles : pic compté " .. T.peak .. " et arbre vivant " .. T.live .. " <= " .. L.MAX_INSTANCES, T.peak <= L.MAX_INSTANCES and T.live <= L.MAX_INSTANCES)
		check("Les modèles sont réellement utilisés en combat (" .. T.models .. " créatures-modèles vues, " .. T.procs .. " replis par budget)", T.models > 0)
		check("Aucune erreur de script pendant les 20 combats", #RT.errors == T.errs0)
		local intact = true
		for i = 1, #Config.PETS do
			local t = folder:FindFirstChild(tostring(i))
			if not t or partsOf(t) ~= spec[i] then
				intact = false
			end
		end
		check("Les " .. #Config.PETS .. " modèles publiés restent intacts après 20 combats (jamais déplacés ni modifiés)", intact)
	end

	---------------------------------------------------------------- 3. Serveur : publication (Builder.exportPets / lightPetCopy) dans le vrai Builder
	suite("Mobs 1 : le serveur publie la copie légère des pets (ReplicatedStorage.PetModels, <= 40 Parts, sans scripts, ancrée)")
	local SRT = newRuntime({ fs = fs, luau = luau, placeId = 0 })
	if SRT == nil then
		return
	end
	local main = SRT.buildTree("roblox/src", false)
	SRT.task.spawn(function()
		SRT.runScript(main)
	end)
	SRT.step(1)
	T.S = {
		cfg = SRT.require(SRT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Config")),
		Builder = SRT.require(SRT.services.ServerScriptService:FindFirstChild("Builder")),
		Assets = SRT.require(SRT.services.ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("Assets")),
	}
	local function srvModel(n, extra)
		local m = SRT.instance("Model", "PetModel")
		for i = 1, n do
			local p = SRT.instance("MeshPart", i == 1 and "Corps__A0784A" or ("Piece" .. i))
			p.Anchored = false
			p.CanCollide = true
			p.Parent = m
		end
		if extra then
			SRT.instance("Script", "Evil").Parent = m:GetChildren()[1]
			SRT.instance("ParticleEmitter", "Sparks").Parent = m:GetChildren()[1]
			SRT.instance("PointLight", "Light").Parent = m
		end
		return m
	end
	T.S.calls = {}
	local fakeAssets = { clonePet = function(idx)
		T.S.calls[#T.S.calls + 1] = idx
		if idx == 1 then
			return srvModel(10, true)
		elseif idx == 2 then
			return srvModel(T.S.cfg.Assets.combatMaxParts + 1, false)
		elseif idx == 3 then
			return srvModel(T.S.cfg.Assets.combatMaxParts, false)
		end
		return nil
	end }
	local boot = SRT.services.ReplicatedStorage:FindFirstChild("PetModels")
	T.S.bootCount = boot and #boot:GetChildren() or 0
	check("Démarrage réel (Main, chargeur factice) : la tâche des Assets publie les pets chargés (" .. T.S.bootCount .. " modèles dans PetModels)", T.S.bootCount > 0)
	if boot then
		boot:Destroy()
	end
	local pub, refused = T.S.Builder.exportPets(fakeAssets)
	local folder = SRT.services.ReplicatedStorage:FindFirstChild("PetModels")
	check("Builder.exportPets : demande le modèle de CHAQUE espèce (" .. #T.S.calls .. " / " .. #T.S.cfg.PETS .. ") par assets.clonePet (même choix que Builder.pet)", #T.S.calls == #T.S.cfg.PETS)
	check("Dossier ReplicatedStorage.PetModels : 2 publiés (10 et " .. T.S.cfg.Assets.combatMaxParts .. " Parts), 1 refusé (" .. (T.S.cfg.Assets.combatMaxParts + 1) .. " Parts)", folder ~= nil and pub == 2 and refused == 1 and folder:FindFirstChild("1") ~= nil and folder:FindFirstChild("3") ~= nil and folder:FindFirstChild("2") == nil)
	local m1 = folder and folder:FindFirstChild("1")
	local clean = m1 ~= nil
	for _, d in ipairs(m1 and m1:GetDescendants() or {}) do
		if not d:IsA("BasePart") then
			clean = false
		elseif d.Anchored ~= true or d.CanCollide ~= false or d.CanQuery ~= false or d.CanTouch ~= false then
			clean = false
		end
	end
	check("Copie légère : seulement des Parts (script, particules, lumière retirés), ancrées, sans collision ni requête", clean and m1:GetAttribute("Parts") == 10 and m1:GetAttribute("Tier") == T.S.cfg.PETS[1].tier)
	check("Plafond combat = 40 Parts (Config.Assets.combatMaxParts, comme petsMaxPartsNew)", T.S.cfg.Assets.combatMaxParts == 40 and T.S.cfg.Assets.combatMaxParts <= T.S.cfg.Assets.petsMaxPartsNew)
	local pub2 = T.S.Builder.exportPets(fakeAssets)
	check("Republication (deuxième appel) : remplace sans doublon", pub2 == 2 and #folder:GetChildren() == 2)
	check("Builder.exportPets sans clonePet (assets réduit) : 0 publié, aucune erreur", T.S.Builder.exportPets({}) == 0)

	-- Id ajouté dans une COPIE de Config.Assets.pets (id factice) : chargé par Assets.loadPets, publié par exportPets, sans autre changement de code
	do
		local cfgCopy = {}
		for k, v in pairs(T.S.cfg) do
			cfgCopy[k] = v
		end
		local assetsCopy = {}
		for k, v in pairs(T.S.cfg.Assets) do
			assetsCopy[k] = v
		end
		assetsCopy.Enabled = true
		assetsCopy.pets = { [6] = 999000111 } -- id FACTICE (jamais écrit dans Config.lua)
		assetsCopy.petsNew = {}
		cfgCopy.Assets = assetsCopy
		local asked = {}
		local A = T.S.Assets.new(cfgCopy, {
			loadAsset = function(id)
				asked[#asked + 1] = id
				local box = SRT.instance("Model", "Box")
				srvModel(7, true).Parent = box
				return box
			end,
			spawn = function(fn) fn() end, wait = function() end, clock = function() return 0 end, warn = function() end,
		})
		local loaded = A.loadPets()
		local pubF = T.S.Builder.exportPets(A)
		local pm = folder:FindFirstChild("6")
		check("Id factice ajouté à une copie de Config.Assets.pets : chargé (1), publié pour le combat (PetModels/6), sans autre changement", loaded == 1 and asked[1] == 999000111 and pubF == 1 and pm ~= nil and partsOf(pm) == 7)
		check("Config.lua ne contient pas l'id factice", string.find(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), "999000111", 1, true) == nil)
	end
	local mainSrc = fs.readFile("roblox/src/ServerScriptService/Main.server.lua")
	local iLoad = string.find(mainSrc, "assets.loadPets()", 1, true)
	local iPub = string.find(mainSrc, "Builder.exportPets(assets)", 1, true)
	check("Main : publication des pets juste après leur chargement (loadPets puis exportPets)", iLoad ~= nil and iPub ~= nil and iPub > iLoad)
	local sceneSrc = fs.readFile("roblox/src/StarterPlayerScripts/BattleScene.lua")
	check("BattleScene : aucun InsertService / LoadAsset côté client (les modèles viennent du dossier publié)", string.find(sceneSrc, "InsertService", 1, true) == nil and string.find(sceneSrc, "LoadAsset", 1, true) == nil and string.find(sceneSrc, "PetModels", 1, true) ~= nil)
	check("Serveur : aucune erreur pendant la publication" .. (#SRT.errors == 0 and "" or (" : " .. tostring(SRT.errors[1]))), #SRT.errors == 0)
	T.SRT = SRT
	env.mobsState = T
end
