--!nonstrict
-- Chargement SÛR de modèles Roblox tiers : serveur uniquement, InsertService:LoadAsset dans un pcall
-- avec délai maximum, puis inspection (sang/gore => écarté), nettoyage (scripts, remotes, effets) et plafond de pièces.
-- Toute défaillance renvoie nil : l'appelant garde alors ses ressources actuelles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLogic = require(Shared.AssetLogic)

local AssetLoader = {}

-- Inspection : renvoie (ok, raison). Appelée AVANT le nettoyage pour repérer le sang/gore.
function AssetLoader.Inspect(model, maxParts)
	local parts = 0
	for _, d in ipairs(model:GetDescendants()) do
		if AssetLogic.IsBloodName(d.Name) then
			return false, "nom suspect : " .. d.Name
		end
		if d:IsA("ParticleEmitter") then
			local seq = d.Color
			local first = seq and seq.Keypoints and seq.Keypoints[1]
			if first and AssetLogic.IsBloodColor(first.Value.R, first.Value.G, first.Value.B) then
				return false, "particules de couleur sang : " .. d.Name
			end
		end
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	if parts > maxParts then
		return false, ("trop de pièces (%d > %d)"):format(parts, maxParts)
	end
	return true, nil
end

-- Nettoyage : supprime code, canaux réseau et effets tiers. Renvoie le nombre d'éléments retirés.
function AssetLoader.Sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if AssetLogic.IsBlockedClass(d.ClassName) or AssetLogic.IsStrippedFx(d.ClassName) then
			d:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Charge l'asset `id`. deps (tests) : InsertService, spawn, wait.
-- Renvoie (modèle | nil, raison). N'attend jamais plus que `timeout` secondes.
function AssetLoader.Load(id, timeout, deps)
	deps = deps or {}
	local insertService = deps.InsertService or game:GetService("InsertService")
	local spawn = deps.spawn or task.spawn
	local wait = deps.wait or task.wait
	local result, finished, errMessage = nil, false, nil
	spawn(function()
		local ok, value = pcall(function()
			return insertService:LoadAsset(id)
		end)
		if ok then
			result = value
		else
			errMessage = tostring(value)
		end
		finished = true
	end)
	local started = os.clock()
	while not finished and os.clock() - started < timeout do
		wait(0.1)
	end
	if not finished then
		return nil, "délai dépassé"
	end
	if not result then
		return nil, errMessage or "chargement échoué"
	end
	return result, nil
end

-- Charge + inspecte + nettoie. Renvoie (modèle | nil, raison).
function AssetLoader.Prepare(id, opts, deps)
	local model, reason = AssetLoader.Load(id, opts.Timeout, deps)
	if not model then
		return nil, reason
	end
	local ok, why = AssetLoader.Inspect(model, opts.MaxParts)
	if not ok then
		model:Destroy()
		return nil, "écarté : " .. tostring(why)
	end
	AssetLoader.Sanitize(model)
	return model, nil
end

return AssetLoader
