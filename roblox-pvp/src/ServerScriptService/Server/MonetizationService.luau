--!nonstrict
-- Achats intégrés : Game Passes (XP x2, Pièces x2, VIP) et Developer Products (packs de pièces).
-- Reçus idempotents : chaque PurchaseId n'est crédité qu'une fois, puis le profil est sauvegardé
-- immédiatement avant de répondre PurchaseGranted. Les Id à 0 sont désactivés.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)

local MonetizationService = {}

local function passByKey(key)
	for _, p in ipairs(Config.Monetization.Passes) do
		if p.Key == key then
			return p
		end
	end
	return nil
end

local function setOwned(player, pass)
	player:SetAttribute("Has" .. pass.Key, true)
	PlayerService.Sync(player)
end

-- Vérifie à la connexion les passes déjà possédés.
function MonetizationService.CheckPasses(player)
	for _, pass in ipairs(Config.Monetization.Passes) do
		if pass.Id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				setOwned(player, pass)
			end
		end
	end
end

-- Demande d'achat (le client choisit seulement une clé de la liste blanche).
function MonetizationService.Prompt(player, kind, key)
	if kind == "Pass" then
		local pass = passByKey(key)
		if not pass or pass.Id <= 0 then
			return false, "Bientôt disponible"
		end
		if player:GetAttribute("Has" .. pass.Key) then
			return false, "Déjà possédé"
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return true, ""
	elseif kind == "Product" then
		for _, product in ipairs(Config.Monetization.Products) do
			if product.Key == key then
				if product.Id <= 0 then
					return false, "Bientôt disponible"
				end
				MarketplaceService:PromptProductPurchase(player, product.Id)
				return true, ""
			end
		end
	end
	return false, "Achat inconnu"
end

-- Traitement d'un reçu (testable) : renvoie "Granted" ou "NotYet".
function MonetizationService.HandleReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and DataService.Get(player)
	if not player or not profile or profile.Ephemeral then
		return "NotYet" -- Roblox réessaiera plus tard
	end
	local receiptKey = tostring(info.PurchaseId)
	for _, done in ipairs(profile.Receipts) do
		if done == receiptKey then
			return "Granted" -- déjà crédité
		end
	end
	local product
	for _, p in ipairs(Config.Monetization.Products) do
		if p.Id > 0 and p.Id == info.ProductId then
			product = p
		end
	end
	if not product then
		warn("[Monetization] produit inconnu : " .. tostring(info.ProductId))
		return "NotYet"
	end
	PlayerService.AddCoins(player, product.Coins, true)
	table.insert(profile.Receipts, receiptKey)
	while #profile.Receipts > Config.Monetization.MaxReceipts do
		table.remove(profile.Receipts, 1)
	end
	if not DataService.Save(player) then
		-- sauvegarde impossible : on annule le crédit et Roblox redemandera
		table.remove(profile.Receipts)
		PlayerService.AddCoins(player, -product.Coins, true)
		return "NotYet"
	end
	PlayerService.Notify(player, "Reward", ("Merci ! +%d pièces"):format(product.Coins))
	return "Granted"
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = function(info)
		local ok, result = pcall(MonetizationService.HandleReceipt, info)
		if ok and result == "Granted" then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for _, pass in ipairs(Config.Monetization.Passes) do
				if pass.Id == passId then
					setOwned(player, pass)
					PlayerService.Notify(player, "Reward", "Merci ! " .. pass.Name .. " activé")
				end
			end
		end
	end)
end

return MonetizationService
