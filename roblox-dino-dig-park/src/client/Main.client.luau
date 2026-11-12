-- Main.client.luau : point d'entrée client de Dino Dig Park.

local StarterGui = game:GetService("StarterGui")

local Ui = require(script.Parent.Ui)
local Store = require(script.Parent.StateStore)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Reveal = require(script.Parent.Reveal)
local World = require(script.Parent.World)
local Cinematics = require(script.Parent.Cinematics)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local root = Ui.createRoot()
Hud.build(root)
Panels.build()
Reveal.build()
World.start()
Cinematics.start()

-- l'état initial a pu être envoyé avant que ce script ne soit prêt : on le redemande
Store.act("RequestState")
