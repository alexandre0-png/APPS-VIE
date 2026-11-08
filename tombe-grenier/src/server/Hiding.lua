--[[
  Hiding : cachettes (armoires). Tag : Hiding sur une BasePart placée à l'intérieur.
  Un ProximityPrompt fait entrer ou sortir le joueur.
]]
local CollectionService = game:GetService("CollectionService")
local PlayerState = require(script.Parent.PlayerState)

local Hiding = {}

function Hiding.init()
	for _, spot in ipairs(CollectionService:GetTagged("Hiding")) do
		if spot:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Se cacher / sortir"
			prompt.ObjectText = "Armoire"
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 6
			prompt.RequiresLineOfSight = false
			prompt.Parent = spot

			prompt.Triggered:Connect(function(player)
				local st = PlayerState.get(player)
				if st and st.hiding == spot then
					PlayerState.unhide(player, false)
				else
					PlayerState.hide(player, spot)
				end
			end)
		end
	end
end

return Hiding
