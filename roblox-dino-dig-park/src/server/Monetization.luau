-- Monetization.luau : gamepasses et produits développeur (inactifs tant que les IDs valent 0 dans Config).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Economy = require(Shared.Economy)

local DataService = require(script.Parent.DataService)

local Monetization = {}
local GameService = nil

function Monetization.loadPasses(player, passes)
	for key, p in pairs(Config.Passes) do
		if p.id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end)
			passes[key] = ok and owns == true
		else
			passes[key] = false
		end
	end
end

function Monetization.prompt(player, kind, key)
	if type(key) ~= "string" then
		return
	end
	if kind == "pass" then
		local def = Config.Passes[key]
		if def and def.id > 0 then
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, def.id)
			end)
		end
	elseif kind == "product" then
		local def = Config.Products[key]
		if def and def.id > 0 then
			pcall(function()
				MarketplaceService:PromptProductPurchase(player, def.id)
			end)
		end
	end
end

local function grantProduct(player, key)
	local s = GameService.getSession(player)
	if not s then
		return false
	end
	if key == "fossilPack" then
		local amount = math.max(500, math.floor(Economy.autoDigRate(s.data) * 600 + Economy.digAmount(s.data) * 150))
		GameService.addFossils(player, amount)
		GameService.notify(player, "+" .. Util.formatNumber(amount) .. " 🦴 — merci !", "good")
	elseif key == "cashPack" then
		local amount = math.max(5000, math.floor(GameService.computeIncome(player) * 1800))
		GameService.grantCash(player, amount)
		GameService.notify(player, "+" .. Util.formatNumber(amount) .. " 💰 — merci !", "good")
	else
		return false
	end
	return true
end

function Monetization.init(gameService)
	GameService = gameService

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, def in pairs(Config.Passes) do
			if def.id == passId then
				GameService.setPass(player, key, true)
				GameService.notify(player, def.name .. " activé !", "good")
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = DataService.get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local pid = tostring(info.PurchaseId)
		for _, r in ipairs(data.receipts) do
			if r == pid then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		local granted = false
		for key, def in pairs(Config.Products) do
			if def.id == info.ProductId then
				granted = grantProduct(player, key)
			end
		end
		if not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(data.receipts, pid)
		while #data.receipts > 100 do
			table.remove(data.receipts, 1)
		end
		DataService.save(player, false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Monetization
