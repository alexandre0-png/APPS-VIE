-- LocalScript : StarterPlayerScripts/Ambience
-- Ambiance propre à chaque zone : en entrant dans un domaine (ou en revenant à l'arène), l'éclairage, l'atmosphère et la teinte de l'image
-- glissent doucement vers les réglages de Config.Map.ambience (modification locale : n'affecte que ce joueur). Coupable avec
-- Config.Animations.zoneAmbience. Une erreur désactive l'ambiance pour la session sans gêner le jeu.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer

local current = nil
local failed = false
local TWEEN = TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local function apply(zone)
	local a = Config.Map.ambience[zone]
	if not a then
		return
	end
	TweenService:Create(Lighting, TWEEN, { ClockTime = a.clock, Ambient = a.ambient, OutdoorAmbient = a.outdoor }):Play()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		TweenService:Create(atmo, TWEEN, { Color = a.atmo, Density = a.density, Haze = a.haze }):Play()
	end
	local grade = Lighting:FindFirstChild("ChipeGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		TweenService:Create(grade, TWEEN, { TintColor = a.tint }):Play()
	end
end

task.spawn(function()
	while not failed do
		local ok = pcall(function()
			if Config.animEnabled("zoneAmbience") then
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local zone = Config.zoneAt(root.Position.X, root.Position.Z)
					if zone ~= current then
						current = zone
						apply(zone)
					end
				end
			end
		end)
		if not ok then
			failed = true
			warn("[Ambience] désactivée pour cette session après une erreur")
		end
		task.wait(0.5)
	end
end)
