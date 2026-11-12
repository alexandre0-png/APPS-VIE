--!nonstrict
-- Routeur unique des requêtes client (RemoteFunction « Request ») + achats.
-- Chaque action est validée : types, existence, propriété, prix, limites, cadence.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerService = require(script.Parent.PlayerService)
local FoodService = require(script.Parent.FoodService)
local PetService = require(script.Parent.PetService)
local QuestService = require(script.Parent.QuestService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local ShopService = {}

local function fail(msg: string)
	return { ok = false, msg = msg }
end

local function ok(msg: string, extra: any?)
	local r = { ok = true, msg = msg }
	if extra then
		for k, v in pairs(extra) do
			r[k] = v
		end
	end
	return r
end

local handlers = {}

function handlers.buyUpgrade(player, data, payload)
	local def = type(payload.id) == "string" and Economy.findUpgrade(payload.id)
	if not def then
		return fail("Amélioration inconnue")
	end
	local level = data.upgrades[def.Id] or 0
	if level >= def.Max then
		return fail("Niveau maximum atteint")
	end
	local cost = Economy.upgradeCost(def, level)
	if not PlayerService.trySpend(player, cost) then
		return fail("Pas assez de pièces")
	end
	data.upgrades[def.Id] = level + 1
	if def.Id == "boots" then
		PlayerService.applyCharacter(player)
	end
	if def.Id == "basket" then
		PlayerService.refillBasket(player)
	end
	PlayerService.markDirty(player)
	return ok(def.Name .. " niveau " .. (level + 1))
end

function handlers.buyFood(player, data, payload)
	local def = type(payload.id) == "string" and Economy.findFood(payload.id)
	if not def then
		return fail("Nourriture inconnue")
	end
	if data.foods[def.Id] then
		return fail("Déjà débloquée")
	end
	if not PlayerService.trySpend(player, def.Price) then
		return fail("Pas assez de pièces")
	end
	data.foods[def.Id] = true
	PlayerService.markDirty(player)
	return ok(def.Emoji .. " " .. def.Name .. " débloqué ! Va au stand correspondant.")
end

function handlers.openEgg(player, data, payload)
	local success, msg = PetService.openEgg(player, payload.kind, payload.source)
	return { ok = success, msg = msg }
end

function handlers.equipPet(player, data, payload)
	local success, msg = PetService.equip(player, payload.id, payload.on)
	return { ok = success, msg = msg }
end

function handlers.claimQuest(player, data, payload)
	local success, msg = QuestService.claimQuest(player, payload.index)
	return { ok = success, msg = msg }
end

function handlers.answerRiddle(player, data, payload)
	local success, msg = QuestService.answerRiddle(player, payload.choice)
	return { ok = success, msg = msg }
end

function handlers.claimDaily(player, data, payload)
	local success, msg = QuestService.claimDaily(player)
	return { ok = success, msg = msg }
end

function handlers.rebirth(player, data, payload)
	local cost = Economy.rebirthCost(data.rebirths)
	if data.coins < cost then
		return fail("Il te faut " .. Util.formatNumber(cost) .. " pièces")
	end
	if not PlayerService.trySpend(player, cost) then
		return fail("Pas assez de pièces")
	end
	data.rebirths += 1
	data.coins = 0
	data.upgrades = {}
	data.foods = { pomme = true }
	data.selectedFood = "pomme"
	PlayerService.refillBasket(player)
	PlayerService.applyCharacter(player)
	FoodService.refreshHeldFood(player)
	PlayerService.markDirty(player)
	return ok(string.format("Évolution %d ! Bonus de pièces x%.1f", data.rebirths, Economy.rebirthMult(data.rebirths)))
end

function handlers.leaderboard(player, data, payload)
	return ok("", { top = LeaderboardService.getTop() })
end

local PANELS = { shop = true, pets = true, quests = true, rebirth = true }

local function bindPanelPrompt(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		inst.Triggered:Connect(function(player)
			local panel = inst:GetAttribute("Panel")
			if type(panel) == "string" and PANELS[panel] then
				Remotes.get("OpenPanel"):FireClient(player, panel)
			end
		end)
	end
end

function ShopService.init()
	CollectionService:GetInstanceAddedSignal("PanelPrompt"):Connect(bindPanelPrompt)
	for _, inst in ipairs(CollectionService:GetTagged("PanelPrompt")) do
		bindPanelPrompt(inst)
	end
	Remotes.get("Request").OnServerInvoke = function(player: Player, action: any, payload: any)
		if type(action) ~= "string" then
			return fail("Requête invalide")
		end
		if type(payload) ~= "table" then
			payload = {}
		end
		if not FoodService.allow(player, "request", 6, 8) then
			return fail("Doucement !")
		end
		local data = PlayerService.get(player)
		if not data then
			return fail("Données non chargées")
		end
		local handler = handlers[action]
		if not handler then
			return fail("Action inconnue")
		end
		local success, result = pcall(handler, player, data, payload)
		if not success then
			warn("[FestinTRex] Erreur action " .. action .. " : " .. tostring(result))
			return fail("Erreur serveur")
		end
		return result
	end
end

return ShopService
