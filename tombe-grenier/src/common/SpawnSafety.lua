--[[
  SpawnSafety : filet de sécurité des apparitions (hub et partie).
  - Tant qu'aucun point d'apparition actif n'existe (carte en construction), tout personnage déjà
    chargé est retenu en l'air (ancré, protégé) ; il est posé sur le point dès qu'il existe.
  - À chaque apparition : le personnage reste ancré Config.Spawn.HoldSeconds (le sol a le temps d'arriver
    chez le client), et le flux de la zone est demandé (StreamingEnabled). Puis il est libéré.
  - Replacement sur le point d'apparition : dès qu'il passe sous Config.Spawn.VoidY, ou dès qu'il est en
    chute libre depuis plus de Config.Spawn.FreefallSeconds pendant les Config.Spawn.EarlyWindow premières
    secondes. Protection brève, vitesse remise à zéro : la chute ne tue pas.
  - Traces [Spawn] : position, état du personnage et sol sous ses pieds à l'apparition puis toutes les 2 s.
  getSpawn() renvoie la pièce du point d'apparition actif (SpawnLocation), ou nil si elle n'existe pas encore.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SpawnGate = require(Shared.SpawnGate)
local SpawnLog = require(script.Parent.SpawnLog)

local SpawnSafety = {}

local held = {} -- [player] = true : personnage retenu faute de point d'apparition
local born = {} -- [player] = os.clock() de la dernière apparition
local fallingSince = {} -- [player] = os.clock() du début de la chute libre en cours

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

-- Sol sous le personnage vu du serveur : nom de la pièce touchée, ou « AUCUN SOL »
local function floorBelow(root)
	local ok, hit = pcall(function()
		return Workspace:Raycast(root.Position, Vector3.new(0, -60, 0))
	end)
	if ok and hit and hit.Instance then
		return hit.Instance:GetFullName()
	end
	return "AUCUN SOL"
end

-- Apparition d'un personnage : retenue, flux demandé, traces
local function onCharacter(player, char, getSpawn)
	born[player] = os.clock()
	fallingSince[player] = nil
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local spawn = getSpawn()
	SpawnLog.say(
		"%s : personnage apparu en %s ; point d'apparition %s ; StreamingEnabled=%s",
		player.Name,
		SpawnLog.where(char),
		spawn and ("(%.1f, %.1f, %.1f)"):format(spawn.Position.X, spawn.Position.Y, spawn.Position.Z) or "ABSENT",
		tostring(Workspace.StreamingEnabled)
	)
	-- Ancré pendant HoldSeconds : même si le sol n'est pas encore arrivé chez le client, il ne tombe pas
	if spawn and Config.Spawn.HoldSeconds > 0 then
		root.Anchored = true
		if Workspace.StreamingEnabled then
			pcall(function()
				player:RequestStreamAroundAsync(root.Position)
			end)
		end
		task.delay(Config.Spawn.HoldSeconds, function()
			if root.Parent and not held[player] then
				root.Anchored = false
				SpawnLog.say(
					"%s : libéré après %.1f s, en %s, sol : %s",
					player.Name,
					Config.Spawn.HoldSeconds,
					SpawnLog.where(char),
					floorBelow(root)
				)
			end
		end)
	end
	-- Suivi de la première dizaine de secondes
	task.spawn(function()
		for i = 1, 6 do
			task.wait(2)
			if not root.Parent then
				return
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			SpawnLog.say(
				"%s : +%d s en %s, état %s, sol : %s",
				player.Name,
				i * 2,
				SpawnLog.where(char),
				hum and tostring(hum:GetState()) or "?",
				floorBelow(root)
			)
		end
	end)
end

-- Un passage de contrôle
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
					SpawnLog.say("%s : personnage présent sans point d'apparition, retenu", player.Name)
				end
				root.Anchored = true
			else
				if held[player] then
					held[player] = nil
					root.Anchored = false
					place(char, spawn)
					SpawnLog.say("%s : point d'apparition prêt, posé en %s", player.Name, SpawnLog.where(char))
				else
					-- chute libre : durée de la chute en cours
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum and not root.Anchored and hum:GetState() == Enum.HumanoidStateType.Freefall then
						fallingSince[player] = fallingSince[player] or os.clock()
					else
						fallingSince[player] = nil
					end
					local now = os.clock()
					local rescue, why = SpawnGate.shouldRescue({
						y = root.Position.Y,
						age = now - (born[player] or now - 1e6),
						freefall = fallingSince[player] and (now - fallingSince[player]) or 0,
					}, Config.Spawn)
					if rescue then
						SpawnLog.say(
							"%s : %s en %s, replacé sur le point d'apparition",
							player.Name,
							why,
							SpawnLog.where(char)
						)
						fallingSince[player] = nil
						protect(char)
						place(char, spawn)
						warn(("[SpawnSafety] %s : %s, replacé sur le point d'apparition"):format(player.Name, why))
					end
				end
			end
		end
	end
end

function SpawnSafety.start(getSpawn)
	local function bind(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char, getSpawn)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character, getSpawn)
		end
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in ipairs(Players:GetPlayers()) do
		bind(player)
	end
	task.spawn(function()
		while true do
			pcall(SpawnSafety.check, getSpawn)
			task.wait(Config.Spawn.CheckInterval)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
		born[player] = nil
		fallingSince[player] = nil
	end)
end

return SpawnSafety
