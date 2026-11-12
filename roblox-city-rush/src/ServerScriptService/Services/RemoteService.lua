--[[
	RemoteService : crée tous les RemoteEvents et fournit une connexion sécurisée
	(limite de fréquence par joueur + validation du type des arguments).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteService = {}

local FOLDER_NAME = "CityRushRemotes"

-- Serveur -> Client
local SERVER_TO_CLIENT = { "State", "Notify", "Wanted", "Mission", "Banner", "OpenPanel", "Busted", "Leaderboard", "Collected" }
-- Client -> Serveur
local CLIENT_TO_SERVER = { "RequestSpawn", "RequestBuy", "RequestColor", "AbandonMission", "ClaimDaily", "RequestState", "SubmitCode" }

local folder
local events = {}
local registrations = 0
local lastCall = {} -- [player][name] = os.clock()

function RemoteService.init()
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in ipairs(SERVER_TO_CLIENT) do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		events[name] = e
	end
	for _, name in ipairs(CLIENT_TO_SERVER) do
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = folder
		events[name] = e
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

function RemoteService.fire(name, player, ...)
	local e = events[name]
	if e and player and player.Parent then
		e:FireClient(player, ...)
	end
end

function RemoteService.notify(player, text, kind)
	RemoteService.fire("Notify", player, text, kind or "info")
end

function RemoteService.fireAll(name, ...)
	local e = events[name]
	if e then
		e:FireAllClients(...)
	end
end

-- handler(player, ...) ; validator(...) -> boolean (optionnel)
function RemoteService.on(name, cooldown, validator, handler)
	local e = events[name]
	assert(e, "Remote inconnu: " .. tostring(name))
	registrations += 1
	local slot = name .. "#" .. registrations
	e.OnServerEvent:Connect(function(player, ...)
		local now = os.clock()
		lastCall[player] = lastCall[player] or {}
		local last = lastCall[player][slot]
		if last and now - last < cooldown then
			return
		end
		lastCall[player][slot] = now
		if validator and not validator(...) then
			return
		end
		handler(player, ...)
	end)
end

return RemoteService
