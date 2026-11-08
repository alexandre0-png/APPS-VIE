--[[
  Props : objets de scène fixes avec une action (miroirs, télévision, cheval à bascule, photo d'intro).
  Remis à zéro à chaque partie (Props.setup) : chaque effet ne joue qu'une fois par partie.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local Noise = require(script.Parent.Noise)
local PlayerState = require(script.Parent.PlayerState)

local Props = {}

local used = {}          -- [part] = true : effet déjà joué cette partie
local tvRunning = false

local function prompt(part, action, object, onTriggered)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") and child.Name == "PropPrompt" then
			child:Destroy()
		end
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "PropPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.Parent = part
	p.Triggered:Connect(onTriggered)
	return p
end

-- Le reflet : un sursaut, sans sang
local function reflectionScare(player, part, delay, text)
	task.delay(delay, function()
		Remotes.fire("Effect", player, { kind = "Scare" })
		Audio.play("porte", part, { lifetime = 4 })
		Noise.emit(part.Position, 0.5)
		PlayerState.addSanity(player, -15)
	end)
	Remotes.fire("Message", player, { text = text })
end

local function setupMirrors()
	for _, part in ipairs(CollectionService:GetTagged("Mirror")) do
		if part:IsA("BasePart") then
			if part.Name == "miroir fissuré" then
				prompt(part, "Regarder", part.Name, function(player)
					if used[part] then
						return
					end
					used[part] = true
					part.Transparency = 0.2
					part.Color = Color3.fromRGB(120, 130, 140)
					reflectionScare(player, part, 1,
						"Le miroir est fissuré. Ton reflet met une seconde à te suivre.")
				end)
			else
				prompt(part, "Regarder", part.Name, function(player)
					if used[part] then
						return
					end
					used[part] = true
					reflectionScare(player, part, 2,
						"Ton reflet tarde à bouger. Il regarde derrière toi.")
				end)
			end
		end
	end
end

local function setupTV()
	for _, part in ipairs(CollectionService:GetTagged("TV")) do
		if part:IsA("BasePart") then
			prompt(part, "Allumer la télé", "Télévision", function(player)
				if used[part] or tvRunning then
					return
				end
				used[part] = true
				tvRunning = true
				Remotes.fire("Message", player, {
					text = "Une image granuleuse : la pièce vue de haut. Tu y es, au milieu.",
				})
				task.spawn(function()
					for _ = 1, 40 do
						local g = math.random(20, 150)
						part.Color = Color3.fromRGB(g, g, g)
						task.wait(0.25)
					end
					part.Color = Color3.fromRGB(25, 25, 28)
					tvRunning = false
				end)
			end)
		end
	end
end

local function setupRocking()
	for _, part in ipairs(CollectionService:GetTagged("Rocking")) do
		if part:IsA("BasePart") then
			prompt(part, "Faire balancer", "Cheval à bascule", function(player)
				if used[part] then
					return
				end
				used[part] = true
				Remotes.fire("Message", player, { text = "Le cheval se met à balancer, seul." })
				Noise.emit(part.Position, 0.5)
				Audio.play("chaise_grince", part, { lifetime = 4 })
				local origin = part.CFrame
				local tilt = origin * CFrame.Angles(0, 0, math.rad(6))
				task.spawn(function()
					for _ = 1, 3 do
						TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = tilt }):Play()
						task.wait(0.6)
						TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { CFrame = origin }):Play()
						task.wait(0.6)
					end
				end)
			end)
		end
	end
end

-- Photo de l'introduction : tombe depuis le cercueil. Lue, elle déclenche le premier flashback.
local introPart = nil
local introStart = nil -- position de départ de la chute (au-dessus du cercueil)
local function setupIntroPhoto()
	for _, part in ipairs(CollectionService:GetTagged("IntroPhoto")) do
		if part:IsA("BasePart") then
			introPart = part
			introStart = introStart or part.Position
			prompt(part, "Ramasser", "Photo jaunie", function(player)
				if used[part] then
					return
				end
				used[part] = true
				part.Transparency = 1
				Remotes.fire("Flashback", player, { kind = "intro" })
				Remotes.fire("Message", player, {
					text = "Une photo jaunie : une famille, devant cette maison.",
				})
			end)
		end
	end
end

-- Jouet musical : une mélodie se déclenche seule quand on le remonte
local function setupMusicBox()
	for _, part in ipairs(CollectionService:GetTagged("MusicBox")) do
		if part:IsA("BasePart") then
			prompt(part, "Remonter le jouet", "Coffre à jouets", function(player)
				if used[part] then
					return
				end
				used[part] = true
				Remotes.fire("Message", player, { text = "Une mélodie douce se met en route, toute seule." })
				Noise.emit(part.Position, 0.4)
				Audio.play("chaise_grince", part, { lifetime = 3 })
			end)
		end
	end
end

-- Remise à zéro pour une nouvelle partie
function Props.setup()
	used = {}
	tvRunning = false
	setupMirrors()
	setupTV()
	setupRocking()
	setupIntroPhoto()
	setupMusicBox()
	-- La photo tombe du cercueil au début de la partie
	if introPart and introStart then
		introPart.Transparency = 0
		introPart.Anchored = true
		introPart.CFrame = CFrame.new(introStart)
		TweenService:Create(introPart, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(introStart - Vector3.new(0, 3.8, 0)) }):Play()
	end
end

return Props
