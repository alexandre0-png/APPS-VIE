--[[
  Shop : achats Robux (Game Passes et produits développeur).
  Tout est désactivé tant que les identifiants de Config.Shop valent 0 : le jeu reste gratuit et complet.
  - Produits : ProcessReceipt accorde l'effet au moment du paiement confirmé (une seule fois par achat).
  - Game Pass « Lampe renforcée » : le joueur qui le possède voit sa lampe se vider deux fois moins vite.
    Le statut est lu une fois à l'arrivée du joueur, puis posé en attribut « LampPass ».
]]
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PlayerState = require(script.Parent.PlayerState)

local Shop = {}

local function ownsPass(player, passId)
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns == true
end

local function onPlayerAdded(player)
	local lamp = Config.Shop.GamePasses.LampeRenforcee
	player:SetAttribute("LampPass", ownsPass(player, lamp))
end

function Shop.init()
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if Config.Shop.Products.Pile ~= 0 and receipt.ProductId == Config.Shop.Products.Pile then
			PlayerState.addBattery(player, Config.Shop.PileAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif Config.Shop.Products.Cailloux ~= 0 and receipt.ProductId == Config.Shop.Products.Cailloux then
			PlayerState.addThrows(player, Config.Shop.CaillouxAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		warn("[Shop] produit inconnu : " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return Shop
