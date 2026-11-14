--[[
  SpawnSafety : filet de sécurité des apparitions (hub et partie).
  - Tant qu'aucun point d'apparition actif n'existe (carte en construction), tout personnage déjà
    chargé est retenu en l'air (ancré, protégé) ; il est posé sur le point dès qu'il existe.
  - Un personnage sous Config.Spawn.VoidY (chute dans le vide) est replacé sur le point d'apparition,
    vitesse remise à zéro, avec une protection brève : la chute ne tue pas.
  getSpawn() renvoie la pièce du point d'apparition actif (SpawnLocation), ou nil si elle n'existe pas encore.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SpawnGate = require(Shared.SpawnGate)

local SpawnSafety = {}

local held = {} -- [player] = true : personnage retenu faute de point d'apparition

local function protect(char)
	local ff = Instance.new("ForceField")
	ff.Name = "ProtectionApparition"
	ff.Visible = false
	ff.Parent = char
	task.delay(Config.Spawn.Protect, function()
		ff:Destroy()
	end)
end

local function place(char, spawn)
	char:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Un passage de contrôle (public pour les tests en Studio)
function SpawnSafety.check(getSpawn)
	local spawn = getSpawn()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			if not spawn then
				if not held[player] then
					held[player] = true
					protect(char)
				end
				root.Anchored = true
			else
				if held[player] then
					held[player] = nil
					root.Anchored = false
					place(char, spawn)
				elseif SpawnGate.belowFloor(root.Position.Y, Config.Spawn.VoidY) then
					protect(char)
					place(char, spawn)
					warn(("[SpawnSafety] %s sous le sol : replacé sur le point d'apparition"):format(player.Name))
				end
			end
		end
	end
end

function SpawnSafety.start(getSpawn)
	task.spawn(function()
		while true do
			pcall(SpawnSafety.check, getSpawn)
			task.wait(Config.Spawn.CheckInterval)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
	end)
end

return SpawnSafety
