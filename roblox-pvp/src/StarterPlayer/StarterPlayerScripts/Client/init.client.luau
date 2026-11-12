--!nonstrict
-- Point d'entrée client de "Arène des Légendes".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script

local Remotes = require(Shared.Remotes)
local UI = require(Client.UI)
local State = require(Client.State)
local Effects = require(Client.Effects)
local WeaponClient = require(Client.WeaponClient)
local HUD = require(Client.HUD)
local Menus = require(Client.Menus)
local World = require(Client.World)

-- Interface Roblox par défaut remplacée par la nôtre (barre d'armes et vie).
for _ = 1, 10 do
	local ok = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	if ok then
		break
	end
	task.wait(0.5)
end

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
UI.AttachScale(gui, 1100, 620)
gui.Parent = player:WaitForChild("PlayerGui")

Effects.Init()
Effects.SetHUD(HUD)
WeaponClient.Init()
Menus.Init(gui)
HUD.Init(gui, Menus)
Menus.SetToast(HUD.Toast)
World.Init()

Remotes.Sync.OnClientEvent:Connect(State.Set)
Remotes.Notify.OnClientEvent:Connect(HUD.OnNotify)
Remotes.Feed.OnClientEvent:Connect(HUD.OnFeed)
Remotes.Match.OnClientEvent:Connect(HUD.OnMatch)
Remotes.Hit.OnClientEvent:Connect(Effects.OnHit)
Remotes.Fx.OnClientEvent:Connect(Effects.OnFx)

-- Astuces d'accueil (une fois par session) adaptées à l'appareil.
task.delay(4, function()
	local UIS = game:GetService("UserInputService")
	local touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	local tips = touch
		and { "Touche le portail violet pour entrer dans l'arène", "Maintiens le bouton ⚔ pour attaquer", "Touche une arme en bas pour l'équiper", "Ramasse les soins rouges et l'orbe de rage au centre" }
		or { "Traverse le portail violet pour entrer dans l'arène", "Clic gauche : attaquer  ·  1 2 3 : changer d'arme", "Teste tes armes sur les cibles du hub", "Évite la lave et prends l'orbe de rage sur la tour" }
	for _, tip in ipairs(tips) do
		HUD.Toast("💡 " .. tip, UI.Colors.Accent)
		task.wait(3.6)
	end
end)

-- Le serveur a pu envoyer le profil avant la connexion des handlers : on le redemande.
task.spawn(State.Request, "Sync")

-- Interactions du décor (ProximityPrompts créés par le serveur)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local menu = prompt:GetAttribute("OpenMenu")
	if menu then
		Menus.Open(menu)
	elseif prompt:GetAttribute("JoinArena") then
		local ok, msg = State.Request("Join")
		if not ok then
			HUD.Toast(msg, UI.Colors.Bad)
		end
	end
end)
