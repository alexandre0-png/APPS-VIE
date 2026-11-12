-- Côté client : animation des pattes/ailes, cœurs roses sur les animaux récupérables, cibles du saut et du lasso.
-- Les animations ne sont jamais répliquées : le serveur ne déplace que la pièce Root.

local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)

local CreatureFx = {}

local folders = {}
local records = {} -- [model] = { motors = nil | {...}, tries = number, speed = number, heart = nil | { gui, scale } }
local targetHighlight = nil
local targetModel = nil
local lassoHighlight = nil
local lassoModel = nil

local CULL_DISTANCE = 260
local PINK = Color3.fromRGB(255, 96, 160)
local GOLD = Color3.fromRGB(255, 205, 60)

local function collectMotors(model)
	local motors = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local name = descendant.Name
			if name:sub(1, 3) == "Leg" then
				table.insert(
					motors,
					{ motor = descendant, kind = "leg", phase = descendant:GetAttribute("Phase") or 0 }
				)
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

-- Cœur rose au-dessus d'un animal récupérable ; pulse quand la confiance est gagnée ; couronne pour les boss.
local function updateHeart(model)
	local rec = records[model]
	local root = model:FindFirstChild("Root")
	if not rec or not root then
		return
	end
	local wants = model:GetAttribute("Heart") == true
	if wants and not rec.heart then
		local gui = Instance.new("BillboardGui")
		gui.Name = "HeartGui"
		gui.Size = UDim2.new(0, 64, 0, 80)
		gui.StudsOffset = Vector3.new(0, root.Size.Y / 2 + 7, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 190
		gui.Adornee = root
		gui.Parent = root
		local scale = UI.make("UIScale", { Scale = 1 }, gui)
		local holder = UI.make("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(0, 46, 0, 46),
		}, gui)
		UI.heart(holder, 46, PINK)
		if model:GetAttribute("Boss") == true then
			UI.text(gui, {
				Size = UDim2.new(1, 0, 0, 24),
				Text = "BOSS",
				maxSize = 22,
				TextColor3 = GOLD,
			})
		end
		rec.heart = { gui = gui, scale = scale }
	elseif not wants and rec.heart then
		rec.heart.gui:Destroy()
		rec.heart = nil
	end
end

local function track(model)
	if not model:IsA("Model") then
		return
	end
	records[model] = { motors = nil, tries = 0, speed = model:GetAttribute("BaseSpeed") or 40, heart = nil }
	model:GetAttributeChangedSignal("Angry"):Connect(function()
		updateAngry(model)
	end)
	model:GetAttributeChangedSignal("Heart"):Connect(function()
		updateHeart(model)
	end)
	task.defer(updateHeart, model)
end

local function untrack(model)
	records[model] = nil
	if model == targetModel then
		targetModel = nil
	end
	if model == lassoModel then
		lassoModel = nil
	end
end

local function watch(folder)
	table.insert(folders, folder)
	for _, model in ipairs(folder:GetChildren()) do
		track(model)
	end
	folder.ChildAdded:Connect(track)
	folder.ChildRemoved:Connect(untrack)
end

local function makeHighlight(name, fill)
	local h = Instance.new("Highlight")
	h.Name = name
	h.FillColor = fill
	h.FillTransparency = 0.45
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	return h
end

function CreatureFx.init()
	watch(workspace:WaitForChild("Creatures"))
	task.spawn(function()
		watch(workspace:WaitForChild("ZooAnimals"))
	end)

	targetHighlight = makeHighlight("TargetHighlight", GOLD)
	lassoHighlight = makeHighlight("LassoHighlight", PINK)

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
				if rec.heart then
					local ready = model:GetAttribute("Ready") == true
					local pulse = ready and (1.25 + math.sin(t * 9) * 0.25) or (1 + math.sin(t * 3) * 0.08)
					rec.heart.scale.Scale = pulse
				end
			end
		end
	end)
end

-- Meilleure bête à lasso (saut) depuis `origin` dans la portée `range`. `minDz` = avance minimale requise
-- sur l'axe de course (en l'air : devant soi ; au sol : on accepte les bêtes qui passent à côté).
function CreatureFx.bestTarget(origin, range, minDz)
	local best, bestScore = nil, math.huge
	for _, folder in ipairs(folders) do
		if folder.Name == "Creatures" then
			for _, model in ipairs(folder:GetChildren()) do
				if model:GetAttribute("Ridden") ~= true and model:GetAttribute("Id") then
					local root = model:FindFirstChild("Root")
					if root then
						local delta = root.Position + Vector3.new(0, 3, 0) - origin
						local dist = delta.Magnitude
						if dist <= range and delta.Z >= (minDz or 5) then
							local score = dist - 0.3 * math.max(delta.Z, 0)
							if model:GetAttribute("Heart") == true then
								score = score - 12 -- à portée égale, on préfère l'animal au cœur rose
							end
							if score < bestScore then
								best, bestScore = model, score
							end
						end
					end
				end
			end
		end
	end
	return best
end

-- Animal à cœur le plus proche pour le lasso de capture (visée assistée). Les boss ne se lassent pas.
function CreatureFx.bestLassoTarget(origin, range)
	local best, bestScore = nil, math.huge
	for _, folder in ipairs(folders) do
		if folder.Name == "Creatures" then
			for _, model in ipairs(folder:GetChildren()) do
				if
					model:GetAttribute("Heart") == true
					and model:GetAttribute("Boss") ~= true
					and model:GetAttribute("Ridden") ~= true
					and model:GetAttribute("Id")
				then
					local root = model:FindFirstChild("Root")
					if root then
						local delta = root.Position - origin
						local dist = delta.Magnitude
						if dist <= range and delta.Z >= -12 then
							local score = dist - 0.25 * math.max(delta.Z, 0)
							if score < bestScore then
								best, bestScore = model, score
							end
						end
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
	targetHighlight.Parent = model
end

function CreatureFx.setLassoTarget(model)
	if model == lassoModel then
		return
	end
	lassoModel = model
	lassoHighlight.Parent = model
end

function CreatureFx.lassoTarget()
	return lassoModel
end

return CreatureFx
