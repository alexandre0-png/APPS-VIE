--[[
	MonetizationService : achats intégrés (Developer Products) et Game Passes.
	- ProcessReceipt idempotent (reçus déjà traités mémorisés dans le profil)
	- Les IDs sont dans MonetizationIds (remplis par tools/publish.py)
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Ids = require(Shared:WaitForChild("MonetizationIds"))

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RemoteService = require(script.Parent.RemoteService)

local MonetizationService = {}

local function productByRealId(productId)
	for _, p in ipairs(Config.Products) do
		if Ids.Products[p.key] and Ids.Products[p.key] ~= 0 and Ids.Products[p.key] == productId then
			return p
		end
	end
	return nil
end

local function passKeyById(passId)
	for key, id in pairs(Ids.GamePasses) do
		if id ~= 0 and id == passId then
			return key
		end
	end
	return nil
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Receipts = profile.Receipts or {}
	local rid = tostring(info.PurchaseId)
	if profile.Receipts[rid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productByRealId(info.ProductId)
	if not product then
		warn("[Monetization] Produit inconnu", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	EconomyService.grantCashRaw(player, product.cash)
	profile.Receipts[rid] = os.time()
	-- on ne garde que les 60 derniers reçus
	local count = 0
	for _ in pairs(profile.Receipts) do
		count += 1
	end
	if count > 60 then
		local oldestKey, oldest = nil, math.huge
		for k, t in pairs(profile.Receipts) do
			if t < oldest then
				oldest, oldestKey = t, k
			end
		end
		profile.Receipts[oldestKey] = nil
	end
	DataService.markDirty(player)
	RemoteService.notify(player, string.format("Merci ! +%s", Util.formatCash(product.cash)), "good")
	task.spawn(DataService.saveNow, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function checkPasses(player)
	for key, id in pairs(Ids.GamePasses) do
		if id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and owns then
				EconomyService.setPass(player, key, true)
			end
		end
	end
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			local key = passKeyById(passId)
			if key then
				EconomyService.setPass(player, key, true)
				RemoteService.notify(player, "Pass activé, merci !", "good")
			end
		end
	end)

	DataService.Loaded:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
end

return MonetizationService
