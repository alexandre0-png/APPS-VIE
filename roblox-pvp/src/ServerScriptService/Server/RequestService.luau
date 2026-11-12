--!nonstrict
-- Point d'entrée unique des actions du client (RemoteFunction "Request").
-- Chaque action est limitée en débit, ses arguments sont validés et son résultat
-- est décidé par le serveur : le client ne peut rien acheter, équiper ou réclamer de force.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Weapons = require(Shared.Weapons)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)
local QuestService = require(Server.QuestService)
local MatchService = require(Server.MatchService)
local WeaponService = require(Server.WeaponService)
local RateLimiter = require(Server.RateLimiter)

local RequestService = {}

local function reply(ok, msg)
	return { Ok = ok, Msg = msg }
end

local function reloadLoadout(player)
	PlayerService.Sync(player)
	WeaponService.GiveLoadout(player)
end

local handlers = {}

function handlers.Sync(player)
	PlayerService.Sync(player)
	return true, ""
end

function handlers.Join(player)
	return MatchService.Join(player)
end

function handlers.Leave(player)
	return MatchService.Leave(player)
end

function handlers.Buy(player, id)
	local profile = DataService.Get(player)
	local def = Weapons.IsValid(id) and Weapons.Get(id)
	if not profile or not def then
		return false, "Arme inconnue"
	end
	if profile.Owned[id] then
		return false, "Déjà possédée"
	end
	if profile.Level < def.LevelReq then
		return false, ("Niveau %d requis"):format(def.LevelReq)
	end
	if not PlayerService.SpendCoins(player, def.Price) then
		return false, "Pas assez de pièces"
	end
	profile.Owned[id] = true
	if #profile.Loadout < Config.Loadout.Slots then
		table.insert(profile.Loadout, id)
		reloadLoadout(player)
	else
		PlayerService.Sync(player)
	end
	return true, ("%s achetée !"):format(def.Name)
end

function handlers.Equip(player, id, slot)
	local profile = DataService.Get(player)
	if not profile or not Weapons.IsValid(id) or not profile.Owned[id] then
		return false, "Arme non possédée"
	end
	if type(slot) ~= "number" or slot ~= slot then
		slot = #profile.Loadout + 1
	end
	slot = math.clamp(math.floor(slot), 1, Config.Loadout.Slots)
	local slots = {}
	for i = 1, Config.Loadout.Slots do
		local current = profile.Loadout[i]
		if current ~= id then
			slots[i] = current
		end
	end
	slots[slot] = id
	local list = {}
	for i = 1, Config.Loadout.Slots do
		if slots[i] then
			table.insert(list, slots[i])
		end
	end
	profile.Loadout = list
	reloadLoadout(player)
	return true, "Équipée"
end

function handlers.Unequip(player, id)
	local profile = DataService.Get(player)
	if not profile or type(id) ~= "string" then
		return false, "Arme inconnue"
	end
	if #profile.Loadout <= 1 then
		return false, "Gardez au moins une arme"
	end
	for i, v in ipairs(profile.Loadout) do
		if v == id then
			table.remove(profile.Loadout, i)
			reloadLoadout(player)
			return true, "Retirée"
		end
	end
	return false, "Non équipée"
end

function handlers.ClaimQuest(player, questId)
	return QuestService.Claim(player, questId)
end

function handlers.ClaimDaily(player)
	return QuestService.ClaimDaily(player)
end

function RequestService.Init()
	Remotes.Request.OnServerInvoke = function(player, action, a, b)
		if type(action) ~= "string" or not RateLimiter.Check(player, "Request", 4, 8) then
			return reply(false, "Trop de requêtes")
		end
		local handler = handlers[action]
		if not handler then
			return reply(false, "Action inconnue")
		end
		local ok, success, msg = pcall(handler, player, a, b)
		if not ok then
			warn("[RequestService] " .. action .. " : " .. tostring(success))
			return reply(false, "Erreur serveur")
		end
		return reply(success == true, msg or "")
	end
end

return RequestService
