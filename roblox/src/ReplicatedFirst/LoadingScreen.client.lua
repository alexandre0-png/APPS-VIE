-- LocalScript : ReplicatedFirst/LoadingScreen
-- Écran de chargement : image d'accroche plein écran (Decal 140180423430231) sur fond bleu nuit, barre de progression lissée, « Chargement des œufs… ».
-- Ne bloque jamais le jeu : tout est sous pcall, délai maximal (LoadingPlan.CFG.maxShow), garde-fou indépendant de la boucle. Fondu au premier personnage
-- ET après 2 s au moins, puis Destroy et déconnexions (aucune instance ni connexion restante). Aucune donnée du joueur, aucun remote.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local Plan = require(script.Parent:WaitForChild("LoadingPlan"))
local CFG = Plan.CFG
local bg3 = Color3.fromRGB(CFG.bg[1], CFG.bg[2], CFG.bg[3])
local WHITE = Color3.fromRGB(255, 255, 255)

local player = Players.LocalPlayer
local waited = 0
while not player and waited < 10 do
	waited = waited + task.wait(0.05)
	player = Players.LocalPlayer
end
if not player then
	return
end
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then
	return
end

local gui, conns, closed = nil, {}, false
local state = Plan.new(CFG)
local imageStatus, hasChar = nil, player.Character and true or false

local function close()
	if closed then
		return
	end
	closed = true
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	conns = {}
	if gui then
		pcall(function()
			gui:Destroy()
		end)
		gui = nil
	end
end

local ok = pcall(function()
	gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = bg3
	back.BorderSizePixel = 0
	back.Parent = gui

	local img = Instance.new("ImageLabel")
	img.Name = "Splash"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = CFG.image
	img.ScaleType = Enum.ScaleType.Fit
	img.Visible = false -- affichée seulement si le préchargement réussit (sinon : fond bleu nuit seul)
	img.Parent = back

	-- Bande basse sombre (lisibilité du texte sur n'importe quelle partie de l'image) : texte blanc sur bleu nuit, contraste > 4,5:1 même à 80 % d'opacité
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)
	band.Size = UDim2.new(1, 0, 0, 84)
	band.BackgroundColor3 = bg3
	band.BackgroundTransparency = 0.2
	band.BorderSizePixel = 0
	band.Parent = back

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.new(1, -24, 0, 28)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = WHITE
	label.Text = CFG.text
	label.Parent = band

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 52)
	track.Size = UDim2.new(0.7, 0, 0, 12)
	track.BackgroundColor3 = Color3.fromRGB(60, 70, 110)
	track.BorderSizePixel = 0
	track.Parent = band
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 6)
	tc.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill

	gui.Parent = playerGui

	local function applyScale()
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize
		if size then
			img.ScaleType = Plan.scaleType(size.X, size.Y, CFG) == "Crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
		end
	end
	applyScale()
	local cam = workspace.CurrentCamera
	if cam then
		conns[#conns + 1] = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			pcall(applyScale)
		end)
	end

	conns[#conns + 1] = player.CharacterAdded:Connect(function()
		hasChar = true
	end)

	-- Préchargement de l'image elle-même (hors boucle : un échec ou une lenteur ne bloque rien)
	task.spawn(function()
		local status = "Failure"
		pcall(function()
			ContentProvider:PreloadAsync({ img }, function(_, s)
				status = s
			end)
		end)
		imageStatus = status
	end)

	conns[#conns + 1] = RunService.Heartbeat:Connect(function(dt)
		if closed then
			return
		end
		local good = pcall(function()
			local queue = 0
			pcall(function()
				queue = ContentProvider.RequestQueueSize
			end)
			Plan.update(state, { dt = dt, imageStatus = imageStatus, queue = queue, gameLoaded = game:IsLoaded() == true, character = hasChar })
			img.Visible = state.imageVisible
			fill.Size = UDim2.fromScale(state.shown, 1)
			local a = state.alpha
			back.BackgroundTransparency = a
			img.ImageTransparency = a
			band.BackgroundTransparency = 0.2 + 0.8 * a
			label.TextTransparency = a
			track.BackgroundTransparency = a
			fill.BackgroundTransparency = a
		end)
		if not good or state.done then
			close()
		end
	end)
end)

if not ok then
	close()
	return
end

-- Garde-fou indépendant de la boucle : l'écran disparaît au plus tard à maxShow + 3 s, même si Heartbeat ne tourne plus
task.delay(CFG.maxShow + 3, close)
