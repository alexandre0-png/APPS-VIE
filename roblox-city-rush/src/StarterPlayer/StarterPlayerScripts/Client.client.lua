--[[
	Client.client.lua : point d'entrée client de CITY RUSH.
	Écran de chargement, mise à l'échelle de l'interface (téléphone / tablette / PC / console),
	puis initialisation des contrôleurs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Controllers = script.Parent:WaitForChild("Controllers")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local UI = require(Controllers:WaitForChild("UI"))
local State = require(Controllers:WaitForChild("State"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

-- ScreenGui principal (le HUD est sous la barre Roblox : IgnoreGuiInset = false)
local gui = UI.new("ScreenGui", {
	Name = "CityRushGui", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = false, DisplayOrder = 5, Parent = playerGui,
})
local uiScale = UI.new("UIScale", { Parent = gui })
local function updateScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local base = UserInputService.TouchEnabled and 560 or 900
	uiScale.Scale = math.clamp(vp.Y / base, 0.6, 1.25)
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Écran de chargement
local loading = UI.new("ScreenGui", { Name = "CityRushLoading", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100, Parent = playerGui })
local bg = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 18, 26), BorderSizePixel = 0, Parent = loading })
UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(600, 90), Text = "CITY RUSH", TextSize = 72, Font = Enum.Font.GothamBlack, TextColor3 = UI.Theme.Accent, Parent = bg })
local tip = UI.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(700, 30), Text = "Chargement de la ville...", TextSize = 22, TextColor3 = UI.Theme.Muted, Parent = bg })
local TIPS = {
	"Vole n'importe quelle voiture garée dans la rue !",
	"Shift = nitro. R = remettre la voiture sur ses roues.",
	"Évite de renverser des piétons : la police te surveille.",
	"30 étoiles dorées sont cachées, certaines sont dans les airs.",
	"Le Pay'n'Spray efface ton niveau de recherche contre de l'argent.",
}

local started = false
local function start()
	if started then
		return
	end
	started = true
	State.init()
	require(Controllers:WaitForChild("VehicleController")).init()
	require(Controllers:WaitForChild("Atmosphere")).init()
	require(Controllers:WaitForChild("Hud")).init(gui)
	require(Controllers:WaitForChild("Panels")).init(gui)
end

task.spawn(function()
	local t0 = os.clock()
	local i = 1
	repeat
		tip.Text = TIPS[(i % #TIPS) + 1]
		i += 1
		task.wait(1.2)
	until workspace:GetAttribute("WorldReady") or os.clock() - t0 > 90
	-- contrôleurs prêts dès que le serveur a créé les remotes
	ReplicatedStorage:WaitForChild("CityRushRemotes", 30)
	start()
	-- attendre le personnage
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart", 20)
	task.wait(1)
	for _ = 1, 20 do
		bg.BackgroundTransparency += 0.05
		for _, c in ipairs(bg:GetChildren()) do
			if c:IsA("TextLabel") then
				c.TextTransparency = bg.BackgroundTransparency
			end
		end
		task.wait(0.03)
	end
	loading:Destroy()
end)
