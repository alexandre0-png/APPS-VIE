--!nonstrict
-- Chargement SÉCURISÉ de modèles Roblox externes : serveur uniquement, InsertService:LoadAsset dans un pcall avec
-- délai maximum, suppression de tout code / événement, limites de taille, pièces neutralisées (ancrées, sans contact).
-- En cas d'échec, l'appelant garde ses pièces actuelles. Ne lève jamais d'erreur.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local AssetLogic = require(Shared:WaitForChild("AssetLogic"))

local AssetService = {}

local function cfg()
	return Config.Assets
end

-- Retourne un Model nettoyé (non parenté) ou nil. `neutralize` : désactive collisions/contacts (décor animé).
function AssetService.fetch(id: number): Model?
	local c = cfg()
	if c.Enabled ~= true then
		return nil
	end
	if AssetLogic.isExcluded(id, c) then
		warn("[FestinTRex] Modèle " .. tostring(id) .. " exclu (hors sujet).")
		return nil
	end
	local ok, model, err = pcall(function()
		return AssetLogic.load(function(assetId)
			return InsertService:LoadAsset(assetId)
		end, id, { timeout = c.TimeoutSeconds, step = 0.1, spawn = task.spawn, wait = task.wait })
	end)
	if not ok then
		warn("[FestinTRex] Chargement du modèle " .. tostring(id) .. " : " .. tostring(model))
		return nil
	end
	if not model then
		warn("[FestinTRex] Modèle " .. tostring(id) .. " ignoré : " .. tostring(err))
		return nil
	end

	local safe, reason = pcall(function()
		-- 1. Suppression de tout ce qui est interdit (scripts, événements...).
		AssetLogic.sanitize(model:GetDescendants(), function(inst)
			return inst.ClassName
		end, function(inst)
			inst:Destroy()
		end)
		-- 2. Limites.
		local count = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				count += 1
				d.Anchored = true
				d.CanTouch = false
				d.Massless = true
			end
		end
		local _, size = model:GetBoundingBox()
		local fine, why = AssetLogic.checkLimits(count, { size.X, size.Y, size.Z }, c)
		if not fine then
			error(why)
		end
	end)
	if not safe then
		warn("[FestinTRex] Modèle " .. tostring(id) .. " rejeté : " .. tostring(reason))
		pcall(function()
			model:Destroy()
		end)
		return nil
	end
	return model
end

-- Met le modèle à l'échelle (plus grande dimension = targetSize), le pose au sol en (x,z) avec un cap (yaw, degrés).
function AssetService.place(model: Model, x: number, z: number, yawDegrees: number, targetSize: number)
	local _, size = model:GetBoundingBox()
	local scale = AssetLogic.fitScale(math.max(size.X, size.Y, size.Z), targetSize, 0.02, 200)
	model:ScaleTo(scale)
	local cf, newSize = model:GetBoundingBox()
	local rel = cf:ToObjectSpace(model:GetPivot())
	model:PivotTo(CFrame.new(x, newSize.Y / 2 + 0.2, z) * CFrame.Angles(0, math.rad(yawDegrees), 0) * rel)
end

-- Mobilier de festin : chaque pièce est chargée à part ; un échec n'affecte pas les autres.
function AssetService.placeFurniture()
	local c = cfg()
	if c.Enabled ~= true then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor" -- hors de la carte : les lancers traversent le mobilier
	folder.Parent = workspace
	for _, entry in ipairs(c.Furniture) do
		task.spawn(function()
			local model = AssetService.fetch(entry.Id)
			if not model then
				return
			end
			local ok, err = pcall(function()
				model.Name = entry.Name
				-- Le mobilier reste solide (on peut s'asseoir / contourner) mais sans interaction physique.
				AssetService.place(model, entry.Pos[1], entry.Pos[3], entry.Yaw, entry.TargetSize)
				model.Parent = folder
			end)
			if not ok then
				warn("[FestinTRex] Placement de « " .. entry.Name .. " » impossible : " .. tostring(err))
				pcall(function()
					model:Destroy()
				end)
			end
		end)
	end
end

return AssetService
