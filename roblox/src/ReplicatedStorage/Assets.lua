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

-- Lot 9 : met un modèle à l'échelle d'après la hauteur d'UNE pièce (`partName`, nom de base sans suffixe de couleur, ex. « Coque » des œufs) :
-- couronne, auréole ou ailes dépassent sans fausser la taille de l'œuf. Le rapport hauteur de la pièce / hauteur du modèle est mesuré AVANT la mise
-- à l'échelle, puis Assets.fitHeight vise target / rapport (vérifié à ±10 %). Sans cette pièce : repli sur la hauteur du modèle entier.
-- Retourne (true, hauteur du modèle) ou (false, raison).
function Assets.partRatio(model, partName)
	local ok, r = pcall(function()
		local e = model:GetExtentsSize()
		local mh = e and e.Y
		if type(mh) ~= "number" or mh ~= mh or mh <= 0 then
			return nil
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and Assets.baseName(d.Name) == partName then
				local h = d.Size.Y
				if type(h) == "number" and h == h and h > 0 and h <= mh * 1.001 then
					return h / mh
				end
			end
		end
		return nil
	end)
	return ok and r or nil
end
function Assets.fitByPart(model, partName, target)
	local r = Assets.partRatio(model, partName)
	if not r or r < 0.2 then
		return Assets.fitHeight(model, target)
	end
	return Assets.fitHeight(model, target / r)
end

function Assets.new(Config, deps)
	local A = { templates = {}, status = {}, failedIds = {}, requested = {}, placeFailures = {} } -- status[clé] = { ok, reason | parts, removed } ; failedIds[id] = raison
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
		A.requested[key] = id
		-- un identifiant déjà chargé (même modèle sous une autre clé) est réutilisé : un seul LoadAsset par modèle
		if byId[id] then
			A.templates[key] = byId[id].model
			A.status[key] = byId[id].status
			return true
		end
		A.startedAt = A.startedAt or deps.clock()
		local t1 = deps.clock()
		local attempts = 1
		local ok, model = withTimeout(function()
			return deps.loadAsset(id)
		end, cfg.timeout)
		-- un seul nouvel essai (chargement refusé ou trop lent), tant que le plafond global de relance n'est pas atteint : un échec ne bloque jamais la suite
		if not ok and deps.clock() - A.startedAt < (cfg.retryUntil or 25) then
			deps.wait(0.4)
			attempts = 2
			ok, model = withTimeout(function()
				return deps.loadAsset(id)
			end, cfg.timeout)
		end
		if not ok then
			A.status[key] = { ok = false, reason = tostring(model), id = id, attempts = attempts, seconds = deps.clock() - t1 }
			warn("« " .. key .. " » (" .. tostring(id) .. ") : " .. tostring(model) .. " : apparence construite par le code conservée.", id)
			return false
		end
		local sOk, valid, info = pcall(A.sanitize, model, maxParts)
		if not sOk then
			valid, info = false, tostring(valid)
		end
		if not valid then
			A.status[key] = { ok = false, reason = tostring(info), id = id }
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
		A.status[key] = { ok = true, parts = info.parts, removed = info.removed, colored = colored, id = id, attempts = attempts, seconds = deps.clock() - t1 }
		byId[id] = { model = model, status = A.status[key] }
		if deps.store then
			pcall(deps.store, key, model)
		end
		return true
	end

	-- Charge une liste { {key, id, cap} } par LOTS PARALLÈLES (cfg.batchSize, 8 par défaut) : chaque modèle a son délai et son nouvel essai, un échec ou un modèle
	-- lent ne retarde jamais que son lot et n'empêche JAMAIS de lancer les suivants. Les identifiants en double sont chargés une seule fois.
	-- Retourne le nombre de modèles utilisables. Ne lève jamais d'erreur.
	function A.loadMany(entries)
		local first, dups, seen = {}, {}, {}
		for _, e in ipairs(entries) do
			A.requested[e.key] = e.id
			if byId[e.id] or seen[e.id] then
				dups[#dups + 1] = e
			else
				seen[e.id] = true
				first[#first + 1] = e
			end
		end
		local size = cfg.batchSize or 8
		local i = 1
		while i <= #first do
			local running = 0
			for j = i, math.min(i + size - 1, #first) do
				local e = first[j]
				running = running + 1
				deps.spawn(function()
					pcall(A.loadOne, e.key, e.id, e.cap)
					running = running - 1
				end)
			end
			while running > 0 do
				deps.wait(0.05)
			end
			i = i + size
		end
		for _, e in ipairs(dups) do
			pcall(A.loadOne, e.key, e.id, e.cap)
		end
		local loaded = 0
		for _, e in ipairs(entries) do
			if A.status[e.key] and A.status[e.key].ok then
				loaded = loaded + 1
			end
		end
		return loaded
	end

	-- Catégorie d'une clé de statut (pour le rapport) : arbres, chemins, protections d'œufs, base, village, pets, œufs, gardiens, décor...
	local CATEGORY = { trees = "arbres", paths = "chemins", eggguard = "protections d'œufs", base = "base", scenery = "village", guards = "gardiens", traps = "pièges", castle = "château", ground = "sol", deco = "décor", terrain = "relief", vfx = "effets", props = "accessoires", decor = "décor de carte", hub = "kiosque" }
	function A.categoryOf(key)
		local grp = key:match("^m:(%a+)%.")
		if grp then
			return CATEGORY[grp] or grp
		end
		local prefix = key:match("^(%a+):")
		if prefix == "p" then
			return "pets"
		elseif prefix == "r" then
			return "œufs"
		elseif prefix == "d" then
			return "décor catalogue"
		elseif prefix == "x" then
			return "accessoires"
		elseif prefix == "t" then
			return "textures"
		end
		return "œufs"
	end

	-- Rapport par catégorie : { {cat, requested, loaded, fallback, failures = { {key, id, reason} }} } trié par nom ; les statuts sans demande (ID invalide) comptent.
	function A.report()
		local cats, order = {}, {}
		local function bucket(c)
			if not cats[c] then
				cats[c] = { cat = c, requested = 0, loaded = 0, fallback = 0, failures = {} }
				order[#order + 1] = c
			end
			return cats[c]
		end
		local keys, seenKey = {}, {}
		for k in pairs(A.requested) do
			keys[#keys + 1] = k
			seenKey[k] = true
		end
		for k in pairs(A.status) do
			if not seenKey[k] then
				keys[#keys + 1] = k
			end
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local b = bucket(A.categoryOf(k))
			local st = A.status[k]
			b.requested = b.requested + 1
			if st and st.ok then
				b.loaded = b.loaded + 1
			else
				b.fallback = b.fallback + 1
				b.failures[#b.failures + 1] = { key = k, id = A.requested[k] or (st and st.id), reason = st and st.reason or "pas encore chargé" }
			end
		end
		table.sort(order)
		local out = {}
		for _, c in ipairs(order) do
			out[#out + 1] = cats[c]
		end
		return out
	end

	-- Lignes de texte du rapport (une par catégorie, puis une par échec) + totaux { loaded, requested }.
	function A.reportLines()
		local lines, loaded, requested = {}, 0, 0
		local rep = A.report()
		for _, b in ipairs(rep) do
			loaded, requested = loaded + b.loaded, requested + b.requested
			lines[#lines + 1] = ("[Assets] %s : %d/%d chargés, %d en repli"):format(b.cat, b.loaded, b.requested, b.fallback)
		end
		for _, b in ipairs(rep) do
			for _, f in ipairs(b.failures) do
				lines[#lines + 1] = ("[Assets]   ÉCHEC %s (ID %s) : %s"):format(tostring(f.key), tostring(f.id), tostring(f.reason))
			end
		end
		local shown = {}
		for _, f in ipairs(A.placeFailures) do
			if not shown[f] and #shown < 20 then -- un message distinct à la fois, 20 au plus
				shown[f] = true
				shown[#shown + 1] = f
				lines[#lines + 1] = "[Assets]   POSE REFUSÉE " .. f
			end
		end
		return lines, loaded, requested
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
		local entries = {}
		if type(cfg.eggsByRarity) == "table" then -- modèles Blender par rareté (1..6 et « secret ») : prioritaires sur les modèles du catalogue, chargés en premier
			local rk = {}
			for rarity in pairs(cfg.eggsByRarity) do
				rk[#rk + 1] = rarity
			end
			table.sort(rk, function(a, b)
				return tostring(a) < tostring(b)
			end)
			for _, rarity in ipairs(rk) do
				local id = cfg.eggsByRarity[rarity]
				if type(id) == "number" and id > 0 and id % 1 == 0 then
					entries[#entries + 1] = { key = "r:" .. tostring(rarity), id = id, cap = cfg.eggsMaxParts }
				else
					A.status["r:" .. tostring(rarity)] = { ok = false, reason = "ID invalide" }
				end
			end
		end
		for _, key in ipairs(keys) do
			local id = cfg.eggs[key]
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				entries[#entries + 1] = { key = key, id = id, cap = cfg.eggsMaxParts } -- lot 9 : plafond propre des œufs (40)
			else
				A.status[key] = { ok = false, reason = "ID invalide" }
			end
		end
		local loaded = A.loadMany(entries)
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
		local entries = {}
		for _, key in ipairs(keys) do
			local id = cfg.decor[key]
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				entries[#entries + 1] = { key = "d:" .. key, id = id, cap = cfg.decorMaxParts or cfg.maxParts }
			else
				A.status["d:" .. key] = { ok = false, reason = "ID invalide" }
			end
		end
		return A.loadMany(entries)
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
		-- Lot 11 : les 60 nouvelles espèces (cfg.petsNew, plafond de Parts propre cfg.petsMaxPartsNew) ; cfg.pets garde la priorité sur un même indice.
		local newIds = type(cfg.petsNew) == "table" and cfg.petsNew or {}
		for idx in pairs(newIds) do
			if cfg.pets[idx] == nil then
				idxs[#idxs + 1] = idx
			end
		end
		table.sort(idxs, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local entries = {}
		for _, idx in ipairs(idxs) do
			local isNew = cfg.pets[idx] == nil
			local id = cfg.pets[idx] or newIds[idx]
			if type(idx) == "number" and Config.PETS[idx] and type(id) == "number" and id > 0 and id % 1 == 0 then
				entries[#entries + 1] = { key = "p:" .. idx, id = id, cap = isNew and (cfg.petsMaxPartsNew or cfg.petsMaxParts or cfg.maxParts) or (cfg.petsMaxParts or cfg.maxParts) }
			else
				A.status["p:" .. tostring(idx)] = { ok = false, reason = "entrée invalide" }
			end
		end
		loaded = A.loadMany(entries)
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
		local entries = {}
		for _, key in ipairs(keys) do
			local id = cfg.props[key]
			local cap = (cfg.propsMaxParts and cfg.propsMaxParts[key]) or cfg.decorMaxParts or cfg.maxParts
			if type(id) == "number" and id > 0 and id % 1 == 0 then
				entries[#entries + 1] = { key = "x:" .. key, id = id, cap = cap }
			else
				A.status["x:" .. key] = { ok = false, reason = "ID invalide" }
			end
		end
		return A.loadMany(entries)
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
		local entries = {}
		for _, key in ipairs(keys) do
			local id = (not only or only[key]) and g[key] or nil
			local full = group .. "." .. key
			local cap = (cfg.modelsMaxParts and cfg.modelsMaxParts[full]) or (group == "vfx" and cfg.vfxMaxParts) or cfg.decorMaxParts or cfg.maxParts
			if not id then
				-- clé non demandée (filtre `only`)
			elseif type(id) == "number" and id > 0 and id % 1 == 0 then
				entries[#entries + 1] = { key = "m:" .. full, id = id, cap = cap }
			else
				A.status["m:" .. full] = { ok = false, reason = "ID invalide" }
			end
		end
		return A.loadMany(entries)
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
		local mname = "?"
		pcall(function()
			mname = tostring(model.Name)
		end)
		local ok, err = pcall(function()
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
			-- journal : le modèle est refusé (mesure, échelle ±10 %...) et l'apparence procédurale prend le relais
			if #A.placeFailures < 200 then
				A.placeFailures[#A.placeFailures + 1] = ("%s : %s"):format(mname, tostring(err))
			end
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
