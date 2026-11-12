--!nonstrict
-- Quêtes quotidiennes, série de connexion et secrets (fourchettes d'or).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local QuestLogic = require(Shared:WaitForChild("QuestLogic"))
local Economy = require(Shared:WaitForChild("Economy"))

local PlayerService = require(script.Parent.PlayerService)

local QuestService = {}

function QuestService.claimQuest(player: Player, index: any): (boolean, string)
	local data = PlayerService.get(player)
	if not data or type(index) ~= "number" or index % 1 ~= 0 then
		return false, "Requête invalide"
	end
	QuestLogic.ensure(data, Util.dayIndex(os.time()), player.UserId)
	local coins, eggs, reason = QuestLogic.claim(data, index)
	if not coins then
		return false, reason or "Impossible"
	end
	PlayerService.addCoins(player, coins)
	PlayerService.addEggs(player, eggs or 0)
	PlayerService.markDirty(player)
	return true, string.format("Quête réussie ! +%s pièces%s", Util.formatNumber(coins), if (eggs or 0) > 0 then " + 1 œuf 🥚" else "")
end

function QuestService.claimDaily(player: Player): (boolean, string)
	local data = PlayerService.get(player)
	if not data then
		return false, "Données non chargées"
	end
	local coins, eggs, day, reason = QuestLogic.claimDaily(data, Util.dayIndex(os.time()))
	if not coins then
		return false, reason or "Impossible"
	end
	PlayerService.addCoins(player, coins)
	PlayerService.addEggs(player, eggs or 0)
	PlayerService.markDirty(player)
	return true, string.format("Jour %d de série ! +%s pièces%s", day, Util.formatNumber(coins), if (eggs or 0) > 0 then " + 1 œuf 🥚" else "")
end

local function onSecret(prompt: ProximityPrompt, player: Player)
	local data = PlayerService.get(player)
	local id = prompt:GetAttribute("SecretId")
	if not data or type(id) ~= "string" then
		return
	end
	if data.secrets[id] then
		PlayerService.notify(player, "Tu as déjà trouvé cette fourchette d'or.", "info")
		return
	end
	data.secrets[id] = true
	local found = Util.count(data.secrets)
	local r = Config.SecretReward
	PlayerService.addCoins(player, r.Coins * (1 + data.rebirths))
	PlayerService.addEggs(player, r.Eggs)
	PlayerService.notify(player, string.format("🍴 Fourchette d'or %d/%d ! +%s pièces + 1 œuf", found, Config.SecretCount, Util.formatNumber(r.Coins * (1 + data.rebirths))), "gold")
	if found >= Config.SecretCount then
		local b = Config.SecretAllBonus
		PlayerService.addCoins(player, b.Coins * (1 + data.rebirths))
		PlayerService.addEggs(player, b.Eggs)
		PlayerService.notify(player, "🏆 Toutes les fourchettes d'or trouvées ! Bonus énorme !", "gold")
	end
	PlayerService.markDirty(player)
end

local function onChest(prompt: ProximityPrompt, player: Player)
	local data = PlayerService.get(player)
	local id = prompt:GetAttribute("ChestId")
	local def = type(id) == "string" and Config.Chests[id]
	if not data or not def then
		return
	end
	local today = Util.dayIndex(os.time())
	local ok, reason = Economy.chestStatus(data, def, id, today)
	if not ok then
		PlayerService.notify(player, "🔒 " .. (reason or "Fermé"), "bad")
		return
	end
	data.chests[id] = today
	local coins = math.floor(def.Coins * Economy.rebirthMult(data.rebirths))
	PlayerService.addCoins(player, coins)
	PlayerService.addEggs(player, def.Eggs)
	PlayerService.notify(player, string.format("%s %s ouvert ! +%s 🪙 + %d œuf(s) 🥚", def.Emoji, def.Name, Util.formatNumber(coins), def.Eggs), "gold")
	PlayerService.markDirty(player)
end

local function bindChest(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		inst.Triggered:Connect(function(player)
			onChest(inst, player)
		end)
	end
end

local function bindSecret(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		inst.Triggered:Connect(function(player)
			onSecret(inst, player)
		end)
	end
end

function QuestService.init()
	-- Régénère les quêtes si la journée change pendant que le joueur est connecté.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local data = PlayerService.get(player)
				if data and QuestLogic.ensure(data, Util.dayIndex(os.time()), player.UserId) then
					PlayerService.markDirty(player)
				end
			end
		end
	end)
	CollectionService:GetInstanceAddedSignal("Chest"):Connect(bindChest)
	for _, inst in ipairs(CollectionService:GetTagged("Chest")) do
		bindChest(inst)
	end
	CollectionService:GetInstanceAddedSignal("Secret"):Connect(bindSecret)
	for _, inst in ipairs(CollectionService:GetTagged("Secret")) do
		bindSecret(inst)
	end
end

return QuestService
