-- ModuleScript : ServerScriptService/Assets
-- Chargement SÛR des modèles Roblox qui servent d'apparence aux œufs. Rien ici ne touche au gameplay : en cas d'échec quel qu'il soit,
-- cloneEgg retourne nil et l'appelant garde l'apparence par défaut. Les dépendances Roblox sont injectées (Assets.new(Config, deps)) pour
-- tester tous les cas d'échec avec un chargeur factice (tests/run.luau).
--   deps.loadAsset(id) -> modèle   (réel : InsertService:LoadAsset)
--   deps.spawn(fn), deps.wait(secondes), deps.clock() -> secondes   (réels : task.spawn, task.wait, os.clock)
--   deps.warn(message)  (facultatif)   deps.store(clé, modèle)  (facultatif : range le modèle, ex. dans ServerStorage)
local Assets = {}

function Assets.new(Config, deps)
	local A = { templates = {}, status = {}, failedIds = {} } -- status[clé] = { ok, reason | parts, removed } ; failedIds[id] = raison
	local warned = {} -- un seul avertissement par ID
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
	function A.sanitize(model)
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
		if parts > cfg.maxParts then
			return false, "modèle trop lourd (" .. parts .. " parts, maximum " .. cfg.maxParts .. ")"
		end
		return true, { parts = parts, removed = #blocked }
	end

	-- Charge, nettoie et range un modèle. Retourne true si un modèle utilisable est disponible. Ne lève jamais d'erreur.
	function A.loadOne(key, id)
		local ok, model = withTimeout(function()
			return deps.loadAsset(id)
		end, cfg.timeout)
		if not ok then
			A.status[key] = { ok = false, reason = tostring(model) }
			warn("« " .. key .. " » (" .. tostring(id) .. ") : " .. tostring(model) .. " : apparence construite par le code conservée.", id)
			return false
		end
		local sOk, valid, info = pcall(A.sanitize, model)
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
		A.templates[key] = model
		A.status[key] = { ok = true, parts = info.parts, removed = info.removed }
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
		if loaded > 0 and onReady then
			pcall(onReady)
		end
		return loaded
	end

	-- Copie du modèle d'un œuf de rareté `tier`, ou nil (chargement coupé, échoué, pas encore terminé...) : garder l'apparence par défaut.
	function A.cloneEgg(tier)
		if cfg.Enabled ~= true then
			return nil
		end
		local key = Config.eggAssetKey(tier)
		local template = key and A.templates[key]
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

	return A
end

return Assets
