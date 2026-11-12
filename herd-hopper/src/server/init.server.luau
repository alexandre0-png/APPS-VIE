-- Point d'entrée serveur de Saute-Troupeau.
-- Ordre : remotes -> services -> construction de la carte -> apparition des joueurs -> boucle de manches.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

-- Les joueurs n'apparaissent qu'une fois la carte construite.
Players.CharacterAutoLoads = false
Players.RespawnTime = 3
Workspace.Gravity = Config.Gravity

local Modules = script:WaitForChild("Modules")
local State = require(Modules.State)
local DataService = require(Modules.DataService)
local ProgressService = require(Modules.ProgressService)
local CreatureService = require(Modules.CreatureService)
local RideService = require(Modules.RideService)
local ZooService = require(Modules.ZooService)
local EventService = require(Modules.EventService)
local MapBuilder = require(Modules.MapBuilder)
local RoundService = require(Modules.RoundService)
local MonetizationService = require(Modules.MonetizationService)

-- Les joueurs ne se bousculent pas (sinon les cavaliers se percutent en l'air).
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
end)

local function setCollisionGroup(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Players"
		end
	end)
end

-- Ramène le joueur devant son zoo (sauf s'il est en expédition).
local function goHome(player, character)
	local home = State.PlotCFrames[player]
	if not home or State.Participants[player] then
		return
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp and character.Parent then
		character:PivotTo(home)
	end
end

local function onCharacterAdded(player, character)
	setCollisionGroup(character)
	task.spawn(function()
		character:WaitForChild("Humanoid", 10)
		character:WaitForChild("Head", 10)
		ProgressService.ApplyCosmetics(player)
		goHome(player, character)
	end)
	Remotes.Status:FireClient(player, "Lobby")
end

local handled = {}

local function onPlayerAdded(player)
	if handled[player] then
		return
	end
	handled[player] = true
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	task.spawn(function()
		DataService.Load(player)
		MonetizationService.LoadPasses(player)
		if not player.Parent then
			DataService.Release(player)
			return
		end
		ProgressService.EnsureDaily(player)
		ProgressService.RefreshAttributes(player)
		ZooService.OnPlayerReady(player)
		if player.Character then
			goHome(player, player.Character)
		end
		Remotes.Data:FireClient(player, ProgressService.Snapshot(player))
		ProgressService.ApplyCosmetics(player)
		if not DataService.IsPersistent(player) then
			Remotes.Feedback:FireClient(player, {
				kind = "warn",
				title = "SAUVEGARDE INDISPONIBLE",
				sub = "Ta progression ne sera pas enregistrée pendant cette session.",
			})
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	handled[player] = nil
	DataService.Release(player)
end)

DataService.Init()
ProgressService.Init()
RideService.Init()
ZooService.Init()
MonetizationService.Init()

-- Carte (peut durer quelques secondes ; les joueurs attendent sans apparaître)
MapBuilder.Build()
State.MapReady = true
Players.CharacterAutoLoads = true

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
	task.spawn(function()
		player:LoadCharacter()
	end)
end

-- Simulation
RunService.Heartbeat:Connect(function(dt)
	if State.Phase ~= "Running" then
		return
	end
	dt = math.min(dt, 0.1)
	State.RunElapsed = State.RunElapsed + dt
	CreatureService.Step(dt)
	RideService.Step(dt)
	EventService.Step(State.RunElapsed)
end)

-- Classement mondial du salon
task.spawn(function()
	task.wait(4)
	while true do
		MapBuilder.RefreshBoard()
		task.wait(90)
	end
end)

task.spawn(RoundService.Run)
