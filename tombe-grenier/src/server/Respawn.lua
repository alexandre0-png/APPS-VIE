--[[
  Respawn : réapparition après une mort, et réanimation par l'autre joueur (duo).
  - Partie en cours : réapparition au dernier point d'avancée (Quests.checkpoint), ou au cercueil.
  - Duo : si l'autre joueur est vivant, le joueur mort reste au sol et peut être réanimé
    pendant Config.Revive.Window. Sans réanimation, il réapparaît au point d'avancée.
  - Hors partie (hub, lieu de jeu avant le départ) : réapparition au point de spawn courant.
  Le chargement automatique est désactivé : chaque réapparition passe par ce module.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Respawn = {}
local hooks = nil        -- { isRoundActive = fn() -> bool, checkpoint = fn() -> Vector3|nil }
local serial = {}        -- [player] = numéro du dernier arrêt ; invalide les minuteries plus anciennes
local prompts = {}       -- [player] = invite de réanimation en cours
local deaths = 0         -- décès de l'équipe pendant la partie en cours

function Respawn.resetRound()
	deaths = 0
end

local function isAlive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function otherAlive(player)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and isAlive(other) then
			return other
		end
	end
	return nil
end

local function clearPrompt(player)
	local prompt = prompts[player]
	if prompt then
		prompt:Destroy()
		prompts[player] = nil
	end
end

-- Recharge le personnage ; s'il y a une position, le joueur y est posé
local function reload(player, pos)
	task.spawn(function()
		local ok = pcall(function()
			player:LoadCharacter()
		end)
		if not ok then
			return
		end
		local char = player.Character
		if char and pos then
			char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
		end
	end)
end

-- Invite au sol : l'autre joueur la maintient pour réanimer
local function addRevivePrompt(player, mine)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Réanimer"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Config.Revive.Hold
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(reviver)
		if serial[player] ~= mine or reviver == player or not isAlive(reviver) then
			return
		end
		local rchar = reviver.Character
		local rroot = rchar and rchar:FindFirstChild("HumanoidRootPart")
		if not rroot then
			return
		end
		-- Annule la réapparition automatique prévue
		serial[player] += 1
		clearPrompt(player)
		reload(player, rroot.Position)
	end)
	prompt.Parent = root
	prompts[player] = prompt
end

local function onDeath(player)
	local mine = (serial[player] or 0) + 1
	serial[player] = mine
	clearPrompt(player)

	local inRound = hooks.isRoundActive()
	if inRound then
		deaths += 1
		if deaths >= Config.Respawn.MaxDeaths then
			-- Trop de morts pour l'équipe : la malédiction ferme la partie, sans réapparition
			clearPrompt(player)
			hooks.onCurse()
			return
		end
	end
	local partner = inRound and otherAlive(player) or nil
	if partner then
		addRevivePrompt(player, mine)
	end

	local wait = partner and Config.Revive.Window or Config.Respawn.Delay
	task.delay(wait, function()
		if serial[player] ~= mine or isAlive(player) then
			return
		end
		clearPrompt(player)
		reload(player, inRound and hooks.checkpoint() or nil)
	end)
end

local function bindCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		onDeath(player)
	end)
end

function Respawn.init(h)
	hooks = h
	pcall(function()
		Players.CharacterAutoLoads = false
	end)

	local function bind(player)
		player.CharacterAdded:Connect(function(char)
			bindCharacter(player, char)
		end)
		if player.Character then
			bindCharacter(player, player.Character)
		else
			reload(player, nil)
		end
	end

	Players.PlayerAdded:Connect(bind)
	for _, player in ipairs(Players:GetPlayers()) do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		serial[player] = nil
		prompts[player] = nil
	end)
end

return Respawn
