--[[
  Gestures : petits mouvements côté serveur (malle, coffret, objet ramassé, lampes).
  Chaque geste est désactivable dans Config.Animations et protégé par pcall : un échec ne bloque jamais le jeu.
]]
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Motion = require(Shared.Motion)

local Gestures = {}

local function enabled(flag)
	return Config.Animations.Enabled and Config.Animations[flag] == true
end

-- Couvercle qui s'entrouvre : la pièce bascule autour de son bord arrière, puis reste ouverte
function Gestures.tiltOpen(part, flag)
	if not enabled(flag) or not part or not part:IsA("BasePart") then
		return
	end
	pcall(function()
		local origin = part.CFrame
		local angle = -Motion.lidAngle(1, 22)
		TweenService:Create(part, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = origin * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(angle), 0, 0),
		}):Play()
	end)
end

-- Objet ramassé : il s'élève et s'efface, puis disparaît
function Gestures.riseAndRemove(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	if not enabled("PickupRise") then
		part:Destroy()
		return
	end
	pcall(function()
		part.CanCollide = false
		TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			Position = part.Position + Vector3.new(0, 1.5, 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(part, 0.4)
	end)
	-- Si la tween échoue, l'objet est supprimé quand même
	task.delay(0.5, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

-- Lampes de plafond : quelques-unes se balancent doucement, en boucle, pendant la partie
function Gestures.startLampSway()
	if not enabled("LampSway") then
		return
	end
	local lamps = CollectionService:GetTagged("Lamp")
	local count = math.min(3, #lamps)
	for i = 1, count do
		local lamp = lamps[math.random(1, #lamps)]
		if lamp:IsA("BasePart") then
			task.spawn(function()
				local origin = lamp.CFrame
				local ok = pcall(function()
					while lamp.Parent do
						local a = Motion.swayAngle(os.clock(), 2.5, 6)
						TweenService:Create(lamp, TweenInfo.new(2.5, Enum.EasingStyle.Sine), {
							CFrame = origin * CFrame.Angles(math.rad(a), 0, 0),
						}):Play()
						task.wait(2.5)
					end
				end)
				if not ok then
					return
				end
			end)
		end
	end
end

return Gestures
