--!nonstrict
-- Achats Robux : Game Passes (propriété vérifiée par Roblox) et produits développeur
-- (ProcessReceipt idempotent : un reçu n'est jamais accordé deux fois, annulation si la sauvegarde échoue).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))

local PlayerService = require(script.Parent.PlayerService)

local MonetizationService = {}

local M = Config.Monetization

local function passKeyForId(passId: number): string?
	for key, def in pairs(M.Passes) do
		if def.Id ~= 0 and def.Id == passId then
			return key
		end
	end
	return nil
end

local function grantPass(player: Player, key: string)
	local data = PlayerService.get(player)
	if data and not data.passes[key] then
		data.passes[key] = true
		PlayerService.applyCharacter(player)
		PlayerService.markDirty(player)
		PlayerService.notify(player, "✔ " .. M.Passes[key].Emoji .. " " .. M.Passes[key].Name .. " activé !", "gold")
	end
end

-- Vérifie la propriété des passes à l'arrivée (couvre les achats faits hors du jeu).
local function syncOwnership(player: Player)
	for key, def in pairs(M.Passes) do
		if def.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
			end)
			if ok and owns then
				grantPass(player, key)
			end
		end
	end
end

local function productForId(productId: number): (string?, any?)
	for key, def in pairs(M.Products) do
		if def.Id ~= 0 and def.Id == productId then
			return key, def
		end
	end
	return nil, nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = PlayerService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptKey = tostring(info.PurchaseId)
	if data.receipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local _, def = productForId(info.ProductId)
	if not def then
		warn("[FestinTRex] Produit inconnu : " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Octroi (mémorisé pour pouvoir annuler si la sauvegarde échoue).
	local coins = if def.Coins then math.floor(def.Coins * Economy.rebirthMult(data.rebirths)) else 0
	local eggs = def.Eggs or 0
	local coinsBefore, eggsBefore = data.coins, data.eggs
	if coins > 0 then
		PlayerService.addCoins(player, coins)
	end
	if eggs > 0 then
		PlayerService.addEggs(player, eggs)
	end
	data.receipts[receiptKey] = os.time()

	local saved = PlayerService.save(player, false)
	if not saved then
		data.receipts[receiptKey] = nil
		data.coins, data.eggs = coinsBefore, eggsBefore
		PlayerService.markDirty(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Purge des plus anciens reçus.
	local list = {}
	for k, t in pairs(data.receipts) do
		table.insert(list, { k = k, t = t })
	end
	if #list > M.MaxReceipts then
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
		for i = 1, #list - M.MaxReceipts do
			data.receipts[list[i].k] = nil
		end
	end

	PlayerService.markDirty(player)
	PlayerService.notify(player, string.format("Merci ! %s %s reçu%s", def.Emoji, def.Name, if coins > 0 then (" : +" .. Util.formatNumber(coins) .. " 🪙") else ""), "gold")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local key = passKeyForId(passId)
			if key then
				grantPass(player, key)
				PlayerService.save(player, false)
			end
		end
	end)

	PlayerService.onLoaded(function(player)
		task.spawn(syncOwnership, player)
	end)
end

return MonetizationService
