-- AssetService.luau : place les modèles externes (plantes, table, T-Rex du musée) APRÈS la construction du monde.
-- Aucun chargement si Config.Assets.enabled = false. Un échec laisse les modèles actuels en place.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local AssetLoader = require(script.Parent.AssetLoader)
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlotService = require(script.Parent.PlotService)

local AssetService = {}
AssetService.report = { loaded = {}, failed = {}, disabled = false, done = false }

local function run()
	local cfg = Config.Assets
	local report = AssetService.report
	local templates = {}

	-- charge (une seule fois par nom) et met à l'échelle ; retourne le modèle gabarit ou nil
	local function template(name, id, height)
		if templates[name] ~= nil then
			return templates[name] or nil
		end
		local model, info = AssetLoader.load(id, { timeout = cfg.timeout, attempts = cfg.attempts, maxParts = cfg.maxParts })
		if model and not AssetLoader.fit(model, height) then
			model:Destroy()
			model, info = nil, "taille invalide"
		end
		if not model then
			templates[name] = false
			report.failed[name] = tostring(info)
			warn("[AssetService] " .. name .. " (" .. tostring(id) .. ") non chargé, modèle actuel conservé : " .. tostring(info))
			return nil
		end
		templates[name] = model
		report.loaded[name] = info
		return model
	end

	local function place(name, parent, groundPos, yaw)
		local tpl = templates[name]
		if not tpl then
			return nil
		end
		local ok, clone = pcall(function()
			local c = tpl:Clone()
			c.Parent = parent
			AssetLoader.placeOnGround(c, groundPos, yaw)
			return c
		end)
		if not ok then
			warn("[AssetService] pose de " .. name .. " impossible : " .. tostring(clone))
			return nil
		end
		return clone
	end

	local H = cfg.targetHeights
	local ids = cfg.ids

	-- musée
	local museum = WorldBuilder.museum
	if museum then
		if template("diningTable", ids.diningTable, H.diningTable) then
			if place("diningTable", museum.folder, museum.spots.table, 0) then
				museum.fallbackTable:Destroy()
			end
		end
		local plantNames = { "pottedPlant", "windowPlant", "sakura", "pottedPlant" }
		local plantHeights = { H.pottedPlant, H.windowPlant, H.sakura * 0.45, H.pottedPlant }
		for i, spot in ipairs(museum.spots.plants) do
			local name = plantNames[i]
			if template(name, ids[name], name == "sakura" and plantHeights[i] or H[name]) then
				if place(name, museum.folder, spot, math.rad(i * 70)) then
					museum.fallbackPlants[i]:Destroy()
				end
			end
		end
		if cfg.museumTrex.enabled then
			local first = true
			for i, id in ipairs(cfg.museumTrex.ids) do
				local name = "trex" .. i
				if template(name, id, H.trex) and place(name, museum.folder, museum.spots.trex[i], math.rad(150 - 60 * (i - 1))) then
					if first and museum.fallbackTrex then
						museum.fallbackTrex:Destroy()
						first = false
					end
				end
			end
		end
	end

	-- décor du site de fouille et du laboratoire de chaque parcelle
	if cfg.digsiteDecor then
		local spots = {
			{ "sakura", Vector3.new(-57, 0.3, 50), 0.6 },
			{ "sakura", Vector3.new(57, 0.3, 62), 2.4 },
			{ "pottedPlant", Vector3.new(14, 0.3, 44), 0 },
			{ "pottedPlant", Vector3.new(50, 0.3, 42), 1 },
			{ "windowPlant", Vector3.new(13, 0.3, 66), 1.6 },
		}
		for _, plot in ipairs(PlotService.getPlots()) do
			local decor = Instance.new("Folder")
			decor.Name = "DecorAssets"
			decor.Parent = plot.model
			for _, s in ipairs(spots) do
				local name = s[1]
				local height = name == "sakura" and H.sakura or H[name]
				if template(name, ids[name], height) then
					place(name, decor, WorldBuilder.toWorld(plot, s[2]), s[3])
				end
			end
		end
	end
	report.done = true
end

function AssetService.init()
	if not Config.Assets.enabled then
		AssetService.report.disabled = true
		AssetService.report.done = true
		return
	end
	task.spawn(function()
		local ok, err = pcall(run)
		if not ok then
			warn("[AssetService] erreur : " .. tostring(err))
		end
		AssetService.report.done = true
	end)
end

return AssetService
