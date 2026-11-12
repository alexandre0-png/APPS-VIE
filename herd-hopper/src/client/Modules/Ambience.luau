-- Ambiance : la lumière et la brume changent progressivement selon le biome traversé (effet local au client).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sfx = require(script.Parent.Sfx)

local Ambience = {}

local player = Players.LocalPlayer
local currentBiome = nil

function Ambience.init()
	local atmosphere = Lighting:WaitForChild("HHAtmosphere", 20)
	local color = Lighting:WaitForChild("HHColor", 20)
	if not atmosphere or not color then
		return
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		-- le salon (en hauteur) garde l'ambiance de la savane
		local inLobby = hrp.Position.Y > 150
		local z = inLobby and 0 or hrp.Position.Z
		local biome = Config.zoneAt(z)
		if inLobby then
			Sfx.setMusic(workspace:GetAttribute("Phase") == "Results" and "results" or "lobby")
		elseif workspace:GetAttribute("BossActive") == true then
			Sfx.setMusic("boss")
		else
			Sfx.setMusic(biome.key)
		end
		if biome ~= currentBiome then
			currentBiome = biome
			local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
			TweenService:Create(atmosphere, info, { Color = biome.atmosphere }):Play()
			TweenService:Create(color, info, { TintColor = biome.tint }):Play()
		end
	end)
end

return Ambience
