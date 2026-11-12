--[[
	SoundController : sons du véhicule piloté. Chaque son est désactivé proprement tant que
	Config.Sounds.<nom> est vide (voir A_FAIRE_UTILISATEUR.md pour brancher des audios).
	- moteur : boucle dont la hauteur suit la vitesse
	- klaxon : touche H (ou bouton R3 manette)
]]

local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local VehicleController = require(script.Parent.VehicleController)

local SoundController = {}

local engine

local function make(id, looped, volume)
	if not Config.Sounds.Enabled or type(id) ~= "string" or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.Parent = SoundService
	return s
end

function SoundController.init()
	engine = make(Config.Sounds.engine, true, 0.35)
	local horn = make(Config.Sounds.horn, false, 0.8)

	VehicleController.Updated:Connect(function(speed, _, driving)
		if not engine then
			return
		end
		if driving then
			if not engine.IsPlaying then
				engine:Play()
			end
			engine.PlaybackSpeed = 0.7 + math.clamp(speed / 120, 0, 1.4)
		elseif engine.IsPlaying then
			engine:Stop()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not horn then
			return
		end
		if input.KeyCode == Enum.KeyCode.H and VehicleController.Driving then
			horn:Play()
		end
	end)
end

return SoundController
