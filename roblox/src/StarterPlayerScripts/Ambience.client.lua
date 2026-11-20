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
local TweenService2 = TweenService

-- Bannière de zone : glisse depuis le haut au passage d'un domaine (ou du retour à l'arène), puis disparaît. Pas au tout premier placement.
local bannerGui = Instance.new("ScreenGui")
bannerGui.Name = "ZoneBanner"
bannerGui.ResetOnSpawn = false
bannerGui.IgnoreGuiInset = false
bannerGui.DisplayOrder = 5
local bannerFrame = Instance.new("Frame")
bannerFrame.AnchorPoint = Vector2.new(0.5, 0)
bannerFrame.Position = UDim2.new(0.5, 0, 0, -120)
bannerFrame.Size = UDim2.fromOffset(340, 74)
bannerFrame.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
bannerFrame.Active = false
bannerFrame.Parent = bannerGui
local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(0, 18)
bCorner.Parent = bannerFrame
local bStroke = Instance.new("UIStroke")
bStroke.Thickness = 4
bStroke.Color = Color3.fromRGB(255, 210, 63)
bStroke.Parent = bannerFrame
local bGrad = Instance.new("UIGradient")
bGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(130, 130, 130))
bGrad.Rotation = 90
bGrad.Parent = bannerFrame
local bTitle = Instance.new("TextLabel")
bTitle.BackgroundTransparency = 1
bTitle.Position = UDim2.fromOffset(10, 6)
bTitle.Size = UDim2.new(1, -20, 0, 36)
bTitle.Font = Enum.Font.GothamBlack
bTitle.TextScaled = true
bTitle.TextStrokeTransparency = 0.2
bTitle.Parent = bannerFrame
local bSub = Instance.new("TextLabel")
bSub.BackgroundTransparency = 1
bSub.Position = UDim2.fromOffset(10, 44)
bSub.Size = UDim2.new(1, -20, 0, 24)
bSub.Font = Enum.Font.GothamBold
bSub.TextSize = 13
bSub.TextWrapped = true
bSub.TextColor3 = Color3.fromRGB(225, 240, 230)
bSub.Parent = bannerFrame
bannerGui.Parent = player:WaitForChild("PlayerGui")
local bannerToken = 0

local function showBanner(zone)
	local b = Config.zoneBanner(zone)
	if not b then
		return
	end
	bannerToken += 1
	local token = bannerToken
	bTitle.Text = b.title
	bTitle.TextColor3 = b.color
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local bx, bz = player:GetAttribute("BaseX"), player:GetAttribute("BaseZ")
	local dist = (root and type(bx) == "number" and type(bz) == "number") and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(bx, 0, bz)).Magnitude or nil
	bSub.Text = (dist and Config.zoneLine(zone, dist)) or b.sub
	bStroke.Color = b.color
	TweenService2:Create(bannerFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	task.delay(Config.ZONE_BANNER_SECONDS, function()
		if token == bannerToken then
			TweenService2:Create(bannerFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
		end
	end)
end
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
						local first = current == nil
						current = zone
						apply(zone)
						if not first and Config.Animations.zoneBanner then
							showBanner(zone)
						end
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
