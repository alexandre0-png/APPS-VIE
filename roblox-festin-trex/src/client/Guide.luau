--!nonstrict
-- Aide à l'orientation : quand le panier est vide, un rayon doré mène au stand débloqué le plus proche.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Store = require(script.Parent.Store)

local Guide = {}

local localPlayer = Players.LocalPlayer
local beam: Beam? = nil
local startAttachment: Attachment? = nil
local endAttachment: Attachment? = nil

local function hide()
	if beam then
		beam.Enabled = false
	end
end

local function ensure(hrp: BasePart)
	if beam and beam.Parent and startAttachment and startAttachment.Parent == hrp then
		return
	end
	if beam then
		beam:Destroy()
	end
	startAttachment = Instance.new("Attachment")
	startAttachment.Name = "GuideStart"
	startAttachment.Parent = hrp
	endAttachment = nil
	beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Attachment0 = startAttachment
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 210, 60))
	beam.Transparency = NumberSequence.new(0.35)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 12
	beam.Enabled = false
	beam.Parent = hrp
end

local function nearestStand(hrp: BasePart, foods: any): BasePart?
	local best, bestDist = nil, math.huge
	for _, prompt in ipairs(CollectionService:GetTagged("FoodStand")) do
		local counter = prompt.Parent
		local foodId = prompt:GetAttribute("FoodId")
		if counter and counter:IsA("BasePart") and foods[foodId] then
			local d = (counter.Position - hrp.Position).Magnitude
			if d < bestDist then
				best, bestDist = counter, d
			end
		end
	end
	return best
end

function Guide.init()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local state = Store.state
			local char = localPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not state or not hrp or state.ammo > 0 then
				hide()
			else
				ensure(hrp)
				local stand = nearestStand(hrp, state.foods)
				-- Pas de rayon quand on est déjà tout près du stand.
				if stand and (stand.Position - hrp.Position).Magnitude > 14 then
					if not endAttachment or endAttachment.Parent ~= stand then
						if endAttachment then
							endAttachment:Destroy()
						end
						endAttachment = Instance.new("Attachment")
						endAttachment.Name = "GuideEnd"
						endAttachment.Position = Vector3.new(0, 3, 0)
						endAttachment.Parent = stand
						beam.Attachment1 = endAttachment
					end
					beam.Enabled = true
				else
					hide()
				end
			end
		end
	end)
end

return Guide
