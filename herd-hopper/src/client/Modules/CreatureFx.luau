-- Côté client : animation des pattes/ailes, bête ciblée (surbrillance dorée), bêtes énervées (rouge).
-- Les animations ne sont jamais répliquées : le serveur ne déplace que la pièce Root.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CreatureFx = {}

local folder = nil
local records = {} -- [model] = { motors = nil | {...}, tries = number, speed = number }
local targetHighlight = nil
local targetModel = nil

local CULL_DISTANCE = 260

local function collectMotors(model)
	local motors = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local name = descendant.Name
			if name:sub(1, 3) == "Leg" then
				table.insert(motors, { motor = descendant, kind = "leg", phase = descendant:GetAttribute("Phase") or 0 })
			elseif name:sub(1, 4) == "Wing" then
				table.insert(motors, { motor = descendant, kind = "wing", side = descendant:GetAttribute("Side") or 1 })
			end
		end
	end
	return motors
end

local function updateAngry(model)
	local angry = model:GetAttribute("Angry") == true
	local existing = model:FindFirstChild("AngryHighlight")
	if angry and not existing then
		local h = Instance.new("Highlight")
		h.Name = "AngryHighlight"
		h.FillColor = Color3.fromRGB(255, 60, 40)
		h.FillTransparency = 0.55
		h.OutlineColor = Color3.fromRGB(255, 220, 200)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = model
	elseif not angry and existing then
		existing:Destroy()
	end
end

local function track(model)
	if not model:IsA("Model") then
		return
	end
	records[model] = { motors = nil, tries = 0, speed = model:GetAttribute("BaseSpeed") or 40 }
	model:GetAttributeChangedSignal("Angry"):Connect(function()
		updateAngry(model)
	end)
end

local function untrack(model)
	records[model] = nil
	if model == targetModel then
		targetModel = nil
	end
end

function CreatureFx.init()
	folder = workspace:WaitForChild("Creatures")
	for _, model in ipairs(folder:GetChildren()) do
		track(model)
	end
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(untrack)

	targetHighlight = Instance.new("Highlight")
	targetHighlight.Name = "TargetHighlight"
	targetHighlight.FillColor = Color3.fromRGB(255, 214, 70)
	targetHighlight.FillTransparency = 0.45
	targetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		local t = os.clock()
		for model, rec in pairs(records) do
			local root = model:FindFirstChild("Root")
			if root and (root.Position - camPos).Magnitude < CULL_DISTANCE then
				if rec.motors == nil then
					local found = collectMotors(model)
					if #found > 0 or rec.tries > 40 then
						rec.motors = found
					else
						rec.tries = rec.tries + 1
					end
				end
				if rec.motors then
					local freq = 4 + rec.speed * 0.11
					for _, m in ipairs(rec.motors) do
						if m.kind == "leg" then
							m.motor.Transform = CFrame.Angles(math.sin(t * freq + m.phase) * 0.7, 0, 0)
						else
							m.motor.Transform = CFrame.Angles(0, 0, m.side * math.sin(t * 8) * 0.55)
						end
					end
				end
			end
		end
	end)
end

-- Meilleure bête à lasso depuis `origin` dans la portée `range`. `minDz` = avance minimale requise
-- sur l'axe de course (en l'air : devant soi ; au sol : on accepte les bêtes qui passent à côté).
function CreatureFx.bestTarget(origin, range, minDz)
	if not folder then
		return nil
	end
	local best, bestScore = nil, math.huge
	for _, model in ipairs(folder:GetChildren()) do
		if model:GetAttribute("Ridden") ~= true and model:GetAttribute("Id") then
			local root = model:FindFirstChild("Root")
			if root then
				local delta = root.Position + Vector3.new(0, 3, 0) - origin
				local dist = delta.Magnitude
				if dist <= range and delta.Z >= (minDz or 5) then
					local score = dist - 0.3 * math.max(delta.Z, 0)
					if score < bestScore then
						best, bestScore = model, score
					end
				end
			end
		end
	end
	return best
end

function CreatureFx.hasTarget()
	return targetModel ~= nil
end

function CreatureFx.setTarget(model)
	if model == targetModel then
		return
	end
	targetModel = model
	if model then
		targetHighlight.Parent = model
	else
		targetHighlight.Parent = nil
	end
end

return CreatureFx
