-- ModuleScript : ReplicatedStorage/Shared/Assets (utilisé côté SERVEUR seulement : jeu et hub)
-- Chargement SÛR des modèles Roblox qui servent d'apparence aux œufs. Rien ici ne touche au gameplay : en cas d'échec quel qu'il soit,
-- cloneEgg retourne nil et l'appelant garde l'apparence par défaut. Les dépendances Roblox sont injectées (Assets.new(Config, deps)) pour
-- tester tous les cas d'échec avec un chargeur factice (tests/run.luau).
--   deps.loadAsset(id) -> modèle   (réel : InsertService:LoadAsset)
--   deps.spawn(fn), deps.wait(secondes), deps.clock() -> secondes   (réels : task.spawn, task.wait, os.clock)
--   deps.warn(message)  (facultatif)   deps.store(clé, modèle)  (facultatif : range le modèle, ex. dans ServerStorage)
local Assets = {}

-- Convention des modèles Blender : chaque pièce se nomme `Nom__RRGGBB` (hexadécimal). Retourne (r, g, b) en 0-255, ou nil si le nom n'a pas de
-- suffixe valide (exactement 6 chiffres hexadécimaux après le DERNIER « __ »). Pur et testé.
function Assets.parseColorSuffix(name)
	if type(name) ~= "string" then
		return nil
	end
	-- un doublon d'import Blender (« Sapin__2E7D4F.001 ») garde la couleur de son suffixe
	local hex = name:match("__(%x%x%x%x%x%x)$") or name:match("__(%x%x%x%x%x%x)%.%d+$")
	if not hex then
		return nil
	end
	return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Clés des modèles d'effets (même liste que VfxKit.MODELS), pour l'export vers les clients.
Assets.vfxKeys = { "cercle_runique", "ailes", "halo", "rayons", "etoile", "cristaux", "onde", "torii", "spirale", "pilier_lumiere", "etincelles", "cone_lumiere", "bouclier" }

-- Nom de base d'une pièce Blender : sans suffixe de couleur ni suffixe de doublon (« Lame__D8DCE8.001 » -> « Lame »).
function Assets.baseName(name)
	if type(name) ~= "string" then
		return ""
	end
	local n = name:gsub("%.%d+$", "")
	n = n:gsub("__%x%x%x%x%x%x$", "")
	return n
end

-- Met un modèle à la hauteur cible (studs) d'après GetExtentsSize, puis REMESURE : la hauteur obtenue doit être à ±10 % de la cible (deux corrections
-- au plus). Retourne (true, hauteur) ou (false, raison) : l'appelant ne pose alors pas le modèle (repli procédural), jamais d'échelle 1 brute.
function Assets.fitHeight(model, target)
	local ok, res = pcall(function()
		if type(target) ~= "number" or target ~= target or target <= 0 or target > 1000 then
			error("hauteur cible invalide")
		end
		local height
		for _ = 1, 3 do
			local e = model:GetExtentsSize()
			height = e and e.Y
			if type(height) ~= "number" or height ~= height or height < 0.05 or height > 1e6 then
				error("mesure impossible")
			end
			if math.abs(height - target) <= 0.1 * target and _ > 1 then
				return height
			end
			model:ScaleTo(model:GetScale() * target / height)
		end
		local e = model:GetExtentsSize()
		height = e and e.Y
		if type(height) ~= "number" or math.abs(height - target) > 0.1 * target then
			error("hauteur hors tolérance")
		end
		return height
	end)
	return ok, res
end

function Assets.new(Config, deps)
	local A = { templates = {}, status = {}, failedIds = {} } -- status[clé] = { ok, reason | parts, removed } ; failedIds[id] = raison
	local warned = {} -- un seul avertissement par ID
	local byId = {} -- identifiant -> { model, status } des modèles déjà chargés
	local cfg = Config.Assets

	local function warn(msg, id)
		if id ~= nil then
			A.failedIds[id] = msg
			if warned[id] then
				return
			end
			warned[id] = true
		end
		if deps.warn then
			deps.warn("[Assets] " .. msg)
		end
	end

	-- Exécute fn avec un délai maximum (le chargeur réel peut ne jamais répondre). Retourne (ok, résultat | message).
	-- Si le résultat arrive après le délai, le modèle est détruit et ignoré.
	local function withTimeout(fn, seconds)
		local state = { done = false, abandoned = false }
		deps.spawn(function()
			local ok, res = pcall(fn)
			state.done, state.ok, state.res = true, ok, res
			if state.abandoned and ok and res ~= nil then
				pcall(function()
					res:Destroy()
				end)
			end
		end)
		local t0 = deps.clock()
		while not state.done and deps.clock() - t0 < seconds do
			deps.wait(0.1)
		end
		if not state.done then
			state.abandoned = true
			return false, "délai dépassé (" .. seconds .. " s)"
		end
		return state.ok, state.res
	end

	local function descendants(model)
		local ok, list = pcall(function()
			return model:GetDescendants()
		end)
		if ok and type(list) == "table" then
			return list
		end
		return nil
	end

	-- Retire tout ce qui est interdit, plafonne les particules, vérifie qu'il reste de la géométrie.
	-- Retourne (true, { parts, removed }) ou (false, raison). Ne lève jamais d'erreur.
	function A.sanitize(model, maxParts)
		maxParts = maxParts or cfg.maxParts
		if model == nil then
			return false, "modèle absent"
		end
		local list = descendants(model)
		if not list then
			return false, "modèle illisible ou corrompu"
		end
		local blocked = {}
		for _, d in ipairs(list) do
			local ok, className = pcall(function()
				return d.ClassName
			end)
			if not ok or type(className) ~= "string" then
				return false, "instance corrompue"
			end
			if Config.isBlockedClass(className) then
				blocked[#blocked + 1] = d
			end
		end
		for _, d in ipairs(blocked) do
			pcall(function()
				d:Destroy()
			end)
		end
		local after = descendants(model)
		if not after then
			return false, "modèle illisible après nettoyage"
		end
		local parts = 0
		for _, d in ipairs(after) do
			local okPart, isPart = pcall(function()
				return d:IsA("BasePart")
			end)
			if okPart and isPart then
				parts = parts + 1
			else
				local okEmitter, isEmitter = pcall(function()
					return d.ClassName == "ParticleEmitter"
				end)
				if okEmitter and isEmitter then
					pcall(function()
						if d.Rate > cfg.maxParticleRate then
							d.Rate = cfg.maxParticleRate
						end
					end)
				end
			end
		end
		if parts == 0 then
			return false, "modèle vide (aucune part)"
		end
		if parts > maxParts then
			return false, "modèle trop lourd (" .. parts .. " parts, maximum " .. maxParts .. ")"
		end
		return true, { parts = parts, removed = #blocked }
	end

	-- Applique la couleur lue dans le suffixe `__RRGGBB` du nom de chaque pièce (les couleurs du FBX ne sont jamais utilisées) ; sans suffixe, rien
	-- ne change. CastShadow = false pour les petits détails (arête la plus longue sous cfg.smallDetail studs). Retourne le nombre de pièces colorées.
	function A.colorize(model, keepMaterial)
		local make = deps.color or (Color3 and Color3.fromRGB)
		if not make then
			return 0
		end
		local list = descendants(model)
		if not list then
			return 0
		end
		local count = 0
		local MAT = deps.material or (Enum and Enum.Material)
		for _, d in ipairs(list) do
			local okName, name = pcall(function()
				return d.Name
			end)
			if MAT and not keepMaterial then
				-- matières : Metal et Neon seulement pour les pièces explicitement métalliques ou lumineuses (Metal sans reflets rend noir),
				-- tout le reste en plastique lisse, jamais de reflets
				pcall(function()
					if d:IsA("BasePart") then
						local base = Assets.baseName(okName and name or "")
						local metals, neons = cfg.metalParts or {}, cfg.neonParts or {}
						if metals[base] then
							d.Material = MAT.Metal
						elseif neons[base] then
							d.Material = MAT.Neon
						elseif d.Material ~= MAT.Plastic and d.Material ~= MAT.SmoothPlastic then
							d.Material = MAT.SmoothPlastic
						end
						d.Reflectance = 0
					end
				end)
			end
			local r, g, b = Assets.parseColorSuffix(okName and name or nil)
			if r then
				local isPart = false
				pcall(function()
					isPart = d:IsA("BasePart")
				end)
				if isPart then
					pcall(function()
						d.Color = make(r, g, b)
						count = count + 1
						pcall(function()
							if d.ClassName == "MeshPart" then
								d.TextureID = "" -- une texture importée teinterait la couleur (rendu sombre)
							end
							for _, c in ipairs(d:GetChildren()) do
								if c.ClassName == "SurfaceAppearance" then
									c:Destroy()
								end
							end
						end)
						local s = d.Size
						if s and math.max(s.X, s.Y, s.Z) < (cfg.smallDetail or 0.6) then
							d.CastShadow = false
						end
					end)
				end
			end
		end
		return count
	end

	-- Charge, nettoie et range un modèle. Retourne true si un modèle utilisable est disponible. Ne lève jamais d'erreur.
	function A.loadOne(key, id, maxParts)
		-- un identifiant déjà chargé (même modèle sous une autre clé) est réutilisé : un seul LoadAsset par modèle
		if byId[id] then
			A.templates[key] = byId[id].model
			A.status[key] = byId[id].status
			return true
		end
		local ok, model = withTimeout(function()
			return deps.loadAsset(id)
		end, cfg.timeout)
		if not ok then
			A.status[key] = { ok = false, reason = tostring(model) }
			warn("« " .. key .. " » (" .. tostring(id) .. ") : " .. tostring(model) .. " : apparence construite par le code conservée.", id)
			return false
		end
		local sOk, valid, info = pcall(A.sanitize, model, maxParts)
		if not sOk then
			valid, info = false, tostring(valid)
		end
		if not valid then
			A.status[key] = { ok = false, reason = tostring(info) }
			pcall(function()
				if model ~= nil then
					model:Destroy()
				end
			end)
			warn("« " .. key .. " » (" .. tostring(id) .. ") : " .. tostring(info) .. " : apparence construite par le code conservée.", id)
			return false
		end
		local colored = 0
		local cOk, cn = pcall(A.colorize, model, key:sub(1, 2) == "v:" or key:sub(1, 6) == "m:vfx.") -- les effets gardent leur matière Neon
		if cOk then
			colored = cn
		end
		A.templates[key] = model
		A.status[key] = { ok = true, parts = info.parts, removed = info.removed, colored = colored }
		byId[id] = { model = model, status = A.status[key] }
		if deps.store then
			pcall(deps.store, key, model)
		end
		return true
	end

	-- Charge tous les modèles d'œufs (un par clé). onReady() est appelé une fois si au moins un modèle est utilisable.
	-- Retourne le nombre de modèles chargés. Ne lève jamais d'erreur ; ne fait rien si Config.Assets.Enabled est faux.
	function A.loadAll(onReady)
		if cfg.Enabled ~= true then
			return 0
		end
		local keys = {}
		for key in pairs(cfg.eggs) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local loaded = 0
		for _, key in ipairs(keys) do
			local id = cfg.eggs[key]
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				if A.loadOne(key, id) then
					loaded = loaded + 1
				end
			else
				A.status[key] = { ok = false, reason = "ID invalide" }
			end
		end
		if type(cfg.eggsByRarity) == "table" then -- modèles Blender par rareté (1..6 et « secret ») : prioritaires sur les modèles du catalogue
			for rarity, id in pairs(cfg.eggsByRarity) do
				if type(id) == "number" and id > 0 and id % 1 == 0 then
					if A.loadOne("r:" .. tostring(rarity), id) then
						loaded = loaded + 1
					end
				else
					A.status["r:" .. tostring(rarity)] = { ok = false, reason = "ID invalide" }
				end
			end
		end
		if loaded > 0 and onReady then
			pcall(onReady)
		end
		return loaded
	end

	-- Charge les modèles de décor du hub (Config.Assets.decor : clé -> ID), plafond de Parts plus large que pour les œufs.
	-- Clés rangées sous « d:<clé> ». Retourne le nombre de modèles chargés. Ne lève jamais d'erreur.
	function A.loadDecor()
		if cfg.Enabled ~= true or type(cfg.decor) ~= "table" then
			return 0
		end
		local keys = {}
		for key in pairs(cfg.decor) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local loaded = 0
		for _, key in ipairs(keys) do
			local id = cfg.decor[key]
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				if A.loadOne("d:" .. key, id, cfg.decorMaxParts or cfg.maxParts) then
					loaded = loaded + 1
				end
			else
				A.status["d:" .. key] = { ok = false, reason = "ID invalide" }
			end
		end
		return loaded
	end

	-- Charge les modèles Blender des pets (Config.Assets.pets : index d'espèce -> ID). Clés « p:<index> ». Retourne le nombre de modèles chargés.
	function A.loadPets()
		if cfg.Enabled ~= true or type(cfg.pets) ~= "table" then
			return 0
		end
		local loaded = 0
		local idxs = {}
		for idx in pairs(cfg.pets) do
			idxs[#idxs + 1] = idx
		end
		table.sort(idxs, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, idx in ipairs(idxs) do
			local id = cfg.pets[idx]
			if type(idx) == "number" and Config.PETS[idx] and type(id) == "number" and id > 0 and id % 1 == 0 then
				if A.loadOne("p:" .. idx, id, cfg.petsMaxParts or cfg.maxParts) then
					loaded = loaded + 1
				end
			else
				A.status["p:" .. tostring(idx)] = { ok = false, reason = "entrée invalide" }
			end
		end
		return loaded
	end

	-- Copie du modèle du pet d'espèce `petIdx`, ou nil (repli : pet procédural).
	function A.clonePet(petIdx)
		if cfg.Enabled ~= true then
			return nil
		end
		local template = A.templates["p:" .. tostring(petIdx)]
		if not template then
			return nil
		end
		local ok, clone = pcall(function()
			return template:Clone()
		end)
		if ok then
			return clone
		end
		return nil
	end

	-- Copie du modèle de décor `key`, ou nil (coupé, échoué, pas encore chargé).
	function A.cloneDecor(key)
		if cfg.Enabled ~= true then
			return nil
		end
		local template = A.templates["d:" .. key]
		if not template then
			return nil
		end
		local ok, clone = pcall(function()
			return template:Clone()
		end)
		if ok then
			return clone
		end
		return nil
	end

	-- Copie du modèle d'un œuf de rareté `tier`, ou nil (chargement coupé, échoué, pas encore terminé...) : garder l'apparence par défaut.
	function A.cloneEgg(tier, secret)
		if cfg.Enabled ~= true then
			return nil
		end
		local template = nil
		if secret then
			template = A.templates["r:secret"]
		end
		template = template or A.templates["r:" .. tostring(tier)]
		if not template then
			local key = Config.eggAssetKey(tier)
			template = key and A.templates[key]
		end
		if not template then
			return nil
		end
		local ok, clone = pcall(function()
			return template:Clone()
		end)
		if ok then
			return clone
		end
		return nil
	end

	-- Accessoires (arbres, rochers, cabanes, pont, fontaine, nid...) : Config.Assets.props clé -> ID, plafond de Parts par clé (propsMaxParts).
	function A.loadProps()
		if cfg.Enabled ~= true or type(cfg.props) ~= "table" then
			return 0
		end
		local keys = {}
		for key in pairs(cfg.props) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local loaded = 0
		for _, key in ipairs(keys) do
			local id = cfg.props[key]
			local cap = (cfg.propsMaxParts and cfg.propsMaxParts[key]) or cfg.decorMaxParts or cfg.maxParts
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				if A.loadOne("x:" .. key, id, cap) then
					loaded = loaded + 1
				end
			else
				A.status["x:" .. key] = { ok = false, reason = "ID invalide" }
			end
		end
		return loaded
	end

	-- Textures tuilables : chaque entrée de Config.Assets.textures est un ID de DÉCAL ; on charge le décal côté serveur, on lit son `Texture` (URL
	-- d'image) et on la met en cache (A.textureUrls[clé]). Un échec laisse la matière actuelle (aucune URL = rien n'est posé). Retourne le nombre chargé.
	A.textureUrls = {}
	function A.loadTextures()
		if cfg.Enabled ~= true or type(cfg.textures) ~= "table" then
			return 0
		end
		local keys = {}
		for key in pairs(cfg.textures) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local loaded = 0
		for _, key in ipairs(keys) do
			local id = cfg.textures[key].id
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				local ok, model = withTimeout(function()
					return deps.loadAsset(id)
				end, cfg.timeout)
				local url = nil
				if ok and model ~= nil then
					pcall(function()
						for _, d in ipairs(model:GetDescendants()) do
							if d:IsA("Decal") and type(d.Texture) == "string" and d.Texture ~= "" then
								url = d.Texture
								break
							end
						end
					end)
					pcall(function()
						model:Destroy()
					end)
				end
				if url then
					A.textureUrls[key] = url
					A.status["t:" .. key] = { ok = true }
					loaded = loaded + 1
				else
					A.status["t:" .. key] = { ok = false, reason = ok and "aucun décal dans le modèle" or tostring(model) }
					warn("texture « " .. key .. " » (" .. tostring(id) .. ") indisponible : matière actuelle conservée.", id)
				end
			else
				A.status["t:" .. key] = { ok = false, reason = "ID invalide" }
			end
		end
		return loaded
	end

	-- Groupes de modèles Blender de Config.Assets.models (guards, castle, traps, ground, props...) : clé "groupe.nom", plafond de Parts par
	-- Config.Assets.modelsMaxParts["groupe.nom"]. Même garanties que loadProps (un seul LoadAsset par ID, jamais d'erreur levée).
	function A.loadGroup(group, only)
		local g = cfg.models and cfg.models[group]
		if cfg.Enabled ~= true or type(g) ~= "table" then
			return 0
		end
		local keys = {}
		for key in pairs(g) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		local loaded = 0
		for _, key in ipairs(keys) do
			local id = (not only or only[key]) and g[key] or nil
			local full = group .. "." .. key
			local cap = (cfg.modelsMaxParts and cfg.modelsMaxParts[full]) or (group == "vfx" and cfg.vfxMaxParts) or cfg.decorMaxParts or cfg.maxParts
			if not id then
				-- clé non demandée (filtre `only`)
			elseif type(id) == "number" and id > 0 and id % 1 == 0 then
				if A.loadOne("m:" .. full, id, cap) then
					loaded = loaded + 1
				end
			else
				A.status["m:" .. full] = { ok = false, reason = "ID invalide" }
			end
		end
		return loaded
	end

	-- Copie d'un modèle d'un groupe (ou nil : repli procédural).
	function A.cloneModel(group, key)
		if cfg.Enabled ~= true then
			return nil
		end
		local template = A.templates["m:" .. tostring(group) .. "." .. tostring(key)]
		if not template then
			return nil
		end
		local ok, clone = pcall(function()
			return template:Clone()
		end)
		return ok and clone or nil
	end

	-- Copie d'un accessoire (clone du modèle chargé une seule fois : jamais de LoadAsset répété), ou nil.
	function A.cloneProp(key)
		if cfg.Enabled ~= true then
			return nil
		end
		local template = A.templates["x:" .. tostring(key)]
		if not template then
			return nil
		end
		local ok, clone = pcall(function()
			return template:Clone()
		end)
		if ok then
			return clone
		end
		return nil
	end

	-- Pose un modèle cloné : mis à l'échelle à `height` studs, posé au sol en (x, z), tourné de rotDeg, ancré, sans collision. Retourne (true, nombre de
	-- Parts) ou (false) ; en cas d'erreur le clone est détruit. Ne lève jamais d'erreur.
	function A.place(model, x, z, rotDeg, height, parent, length, groundY)
		local count = 0
		local ok = pcall(function()
			if not model:IsA("Model") then
				error("pas un Model")
			end
			local _, size = model:GetBoundingBox()
			if size.Y < 0.05 then
				error("hauteur nulle")
			end
			local longest = math.max(size.X, size.Z)
			if length and longest > 0.05 then
				model:ScaleTo(length / longest) -- ponts : échelle d'après la longueur
			else
				local fitted, why = Assets.fitHeight(model, height) -- mesure puis vérification à ±10 % : sinon on ne pose pas
				if not fitted then
					error(why)
				end
			end
			local bbox, size2 = model:GetBoundingBox()
			local target = CFrame.new(x, (groundY or 0) + size2.Y / 2, z) * CFrame.Angles(0, math.rad(rotDeg or 0), 0)
			model:PivotTo(target * bbox:ToObjectSpace(model:GetPivot()))
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					count = count + 1
				end
			end
			model.Parent = parent
		end)
		if not ok then
			pcall(function()
				model:Destroy()
			end)
			return false
		end
		return true, count
	end

	return A
end

return Assets
