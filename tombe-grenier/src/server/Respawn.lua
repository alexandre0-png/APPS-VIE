--[[
  Respawn : vies, réapparition après une mort, et réanimation par l'autre joueur (duo).
  - Chaque joueur a Config.Player.Lives vies par partie. Une mort en partie coûte une vie.
  - Avec une vie restante : réapparition au dernier point d'avancée (Quests.checkpoint),
    après Config.Respawn.Delay secondes ; en duo, si l'autre joueur est vivant, le joueur
    reste au sol et peut être réanimé pendant Config.Revive.Window secondes.
  - Sans vie : hors jeu. En duo, l'autre joueur peut encore le réanimer (il revient avec une vie).
  - Plus personne de vivant en partie : la malédiction (fin 2) se déclenche.
  - Hors partie (hub, lieu de jeu avant le départ) : réapparition au point de spawn courant.
  Le chargement automatique des personnages est désactivé : chaque réapparition passe par ce module.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Respawn = {}
local hooks = nil        -- { isRoundActive, checkpoint, onCurse }
local serial = {}        -- [player] = numéro du dernier arrêt ; invalide les minuteries plus anciennes
local prompts = {}       -- [player] = invite de réanimation en cours
local lives = {}         -- [player] = vies restantes cette partie
local deathCount = 0     -- morts de la partie en cours (tous joueurs)

local function livesOf(player)
	return lives[player] or Config.Player.Lives
end

local function isAlive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function anyAlive()
	for _, player in ipairs(Players:GetPlayers()) do
		if isAlive(player) then
			return true
		end
	end
	return false
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
		-- Un joueur hors jeu revient avec une vie
		if livesOf(player) <= 0 then
			lives[player] = 1
		end
		reload(player, rroot.Position)
	end)
	prompt.Parent = root
	prompts[player] = prompt
end

local function onDeath(player)
	local mine = (serial[player] or 0) + 1
	serial[player] = mine
	clearPrompt(player)

	if not hooks.isRoundActive() then
		task.delay(Config.Respawn.Delay, function()
			if serial[player] ~= mine or isAlive(player) then
				return
			end
			clearPrompt(player)
			reload(player, nil)
		end)
		return
	end

	lives[player] = livesOf(player) - 1
	deathCount += 1
	if not anyAlive() then
		-- Plus personne debout : aucune réanimation possible. Les minuteries en attente et
		-- les invites sont annulées pour que rien ne ressuscite un joueur pendant la fin.
		for _, other in ipairs(Players:GetPlayers()) do
			serial[other] = (serial[other] or 0) + 1
			clearPrompt(other)
		end
		hooks.onCurse()
		return
	end

	local partner = otherAlive(player)
	if livesOf(player) <= 0 then
		-- Hors jeu : seule une réanimation par l'autre joueur le ramène
		if partner then
			addRevivePrompt(player, mine)
		end
		task.delay(Config.Revive.Window, function()
			if serial[player] == mine then
				clearPrompt(player)
			end
		end)
		return
	end

	if partner then
		addRevivePrompt(player, mine)
	end
	local wait = partner and Config.Revive.Window or Config.Respawn.Delay
	task.delay(wait, function()
		if serial[player] ~= mine or isAlive(player) then
			return
		end
		clearPrompt(player)
		reload(player, hooks.checkpoint())
	end)
end

local function bindCharacter(player, char)
	local hum = char:WaitForChild("Humanoid")
	hum.Died:Connect(function()
		onDeath(player)
	end)
end

-- Nouvelle partie : chacun repart avec ses vies
function Respawn.resetRound()
	for player in pairs(prompts) do
		clearPrompt(player)
	end
	for player in pairs(serial) do
		serial[player] = (serial[player] or 0) + 1
	end
	lives = {}
	deathCount = 0
end

-- Nombre de morts depuis le début de la partie (défis, rangs)
function Respawn.deaths()
	return deathCount
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
		lives[player] = nil
	end)
end

return Respawn
