--!nonstrict
-- Point d'entrée client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Store = require(script.Parent:WaitForChild("Store"))
local HUD = require(script.Parent:WaitForChild("HUD"))
local Panels = require(script.Parent:WaitForChild("Panels"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local PetsRenderer = require(script.Parent:WaitForChild("Pets"))
local Input = require(script.Parent:WaitForChild("Input"))
local Guide = require(script.Parent:WaitForChild("Guide"))

Store.init()
HUD.init(function(name)
	Panels.open(name)
end, Input.throwCenter)
Panels.init()
Effects.init()
PetsRenderer.init()
Input.init()
Guide.init()

Remotes.get("Notify").OnClientEvent:Connect(function(text, kind)
	if type(text) == "string" then
		HUD.toast(text, kind)
	end
end)

Remotes.get("OpenPanel").OnClientEvent:Connect(function(name)
	if type(name) == "string" then
		Panels.open(name)
	end
end)

Remotes.get("Reveal").OnClientEvent:Connect(function(petId, isDup, refund, eggKind)
	Panels.reveal(petId, isDup, refund, eggKind)
end)

local welcomed = false
Store.onChange(function()
	if not welcomed then
		welcomed = true
		task.spawn(Effects.welcome)
	end
end)

task.delay(2, function()
	HUD.toast("🦖 Bienvenue au Festin du T-Rex ! Prends de la nourriture au stand 🍎, puis lance-la dans la bouche du dino.", "info")
end)
