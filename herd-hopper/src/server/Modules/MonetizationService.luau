-- Achats Robux : pass de jeu (permanents) et produits développeur (paquets de pièces).
-- Aucun achat n'est accordé sans reçu valide ; chaque reçu est enregistré (idempotent) avant d'être validé.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local MonetizationService = {}

local M = Config.Monetization

local function passById(id)
	for _, def in ipairs(M.GamePasses) do
		if def.id ~= 0 and def.id == id then
			return def
		end
	end
	return nil
end

local function productById(id)
	for _, def in ipairs(M.Products) do
		if def.id ~= 0 and def.id == id then
			return def
		end
	end
	return nil
end

local function grantPass(player, def)
	if ProgressService.HasPass(player, def.key) then
		return
	end
	player:SetAttribute("Pass_" .. def.key, true)
	ProgressService.RefreshAttributes(player)
	ProgressService.ApplyCosmetics(player)
	ProgressService.Push(player)
	Remotes.Feedback:FireClient(player, { kind = "tame", title = "MERCI !", sub = def.name .. " activé" })
end

-- Vérifie les pass possédés (appelé à l'arrivée du joueur ; peut patienter sur le réseau).
function MonetizationService.LoadPasses(player)
	for _, def in ipairs(M.GamePasses) do
		if def.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.id)
			end)
			if ok and owns and player.Parent then
				player:SetAttribute("Pass_" .. def.key, true)
			end
		end
	end
	ProgressService.RefreshAttributes(player)
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data or not DataService.IsPersistent(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById(info.ProductId)
	if not product then
		warn("[Achats] Produit inconnu : " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.receipts = data.receipts or {}
	local rid = tostring(info.PurchaseId)
	if data.receipts[rid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	data.coins = data.coins + product.coins
	data.receipts[rid] = os.time()
	-- on ne garde que les 60 reçus les plus récents
	local ids = {}
	for key in pairs(data.receipts) do
		table.insert(ids, key)
	end
	if #ids > 60 then
		table.sort(ids, function(a, b)
			return data.receipts[a] < data.receipts[b]
		end)
		for i = 1, #ids - 60 do
			data.receipts[ids[i]] = nil
		end
	end
	DataService.MarkDirty(player)

	if not DataService.Save(player) then
		-- sauvegarde impossible : on annule et Roblox réessaiera plus tard
		data.coins = data.coins - product.coins
		data.receipts[rid] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	ProgressService.RefreshAttributes(player)
	ProgressService.Push(player)
	Remotes.Feedback:FireClient(
		player,
		{ kind = "tame", title = "MERCI !", sub = ("+%d pièces"):format(product.coins) }
	)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function loadPrices()
	for _, def in ipairs(M.GamePasses) do
		local entry = { key = def.key, name = def.name, desc = def.desc, available = def.id ~= 0 }
		table.insert(ProgressService.Store.passes, entry)
		if def.id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(def.id, Enum.InfoType.GamePass)
				end)
				if ok and info then
					entry.price = info.PriceInRobux
				end
			end)
		end
	end
	for _, def in ipairs(M.Products) do
		local entry = { key = def.key, name = def.name, coins = def.coins, available = def.id ~= 0 }
		table.insert(ProgressService.Store.products, entry)
		if def.id ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(def.id, Enum.InfoType.Product)
				end)
				if ok and info then
					entry.price = info.PriceInRobux
				end
			end)
		end
	end
end

function MonetizationService.Init()
	loadPrices()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		local def = passById(passId)
		if def and wasPurchased then
			grantPass(player, def)
		end
	end)

	Remotes.Prompt.OnServerEvent:Connect(function(player, kind, key)
		if type(kind) ~= "string" or type(key) ~= "string" or not Util.allow(player, "Prompt", 1) then
			return
		end
		if kind == "pass" then
			for _, def in ipairs(M.GamePasses) do
				if def.key == key and def.id ~= 0 and not ProgressService.HasPass(player, key) then
					MarketplaceService:PromptGamePassPurchase(player, def.id)
				end
			end
		elseif kind == "product" then
			for _, def in ipairs(M.Products) do
				if def.key == key and def.id ~= 0 then
					MarketplaceService:PromptProductPurchase(player, def.id)
				end
			end
		end
	end)
end

return MonetizationService
