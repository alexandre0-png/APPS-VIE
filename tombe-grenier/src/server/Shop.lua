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
local Hub = require(script.Parent.Parent.Common.Hub)

local Shop = {}

local function Remotes_say(player, text)
	pcall(function()
		require(Shared.Remotes).fire("Message", player, { text = text })
	end)
end

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
	player:SetAttribute("LampSkin", ownsPass(player, Config.Shop.GamePasses.LanterneDoree) and "or" or nil)
end

-- Article du catalogue par clé, avec son identifiant Roblox ; nil si inconnu ou désactivé (identifiant 0)
function Shop.item(key)
	for _, entry in ipairs(Config.Shop.Catalogue) do
		if entry.key == key then
			local ids = entry.kind == "pass" and Config.Shop.GamePasses or Config.Shop.Products
			local id = ids[key]
			if typeof(id) == "number" and id ~= 0 then
				return entry, id
			end
			return nil
		end
	end
	return nil
end

-- Demande d'achat du client : seulement un article connu et activé ; jamais d'erreur
function Shop.request(player, key)
	if typeof(key) ~= "string" then
		return false
	end
	local entry, id = Shop.item(key)
	if not entry then
		return false
	end
	-- Les produits ont un effet dans la partie : au hub, seuls les Game Passes sont proposés
	if entry.kind == "product" and Hub.role() == "hub" then
		return false
	end
	pcall(function()
		if entry.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	return true
end

function Shop.init()
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	-- Un Game Pass acheté en jeu s'applique tout de suite
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			onPlayerAdded(player)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		-- Au lieu hub, la partie n'existe pas : l'achat n'est pas accordé ici (l'effet serait perdu).
		-- Roblox le repropose quand le joueur est dans le lieu de jeu.
		if not player or Hub.role() == "hub" then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if Config.Shop.Products.Pile ~= 0 and receipt.ProductId == Config.Shop.Products.Pile then
			PlayerState.addBattery(player, Config.Shop.PileAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif Config.Shop.Products.Cailloux ~= 0 and receipt.ProductId == Config.Shop.Products.Cailloux then
			PlayerState.addThrows(player, Config.Shop.CaillouxAmount)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if Config.Shop.Products.Soutien ~= 0 and receipt.ProductId == Config.Shop.Products.Soutien then
			Remotes_say(player, "Merci pour ton soutien.")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		warn("[Shop] produit inconnu : " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return Shop
