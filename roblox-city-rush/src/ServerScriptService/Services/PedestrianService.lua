--[[
	PedestrianService : piétons qui se promènent sur les trottoirs, rigs R15 classiques Roblox,
	renversements (étourdis, sans violence), billets lâchés ; fabrique aussi les rigs de policiers.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local EconomyService = require(script.Parent.EconomyService)

local Pedestrians = {}

local TARGET_COUNT = 22

-- animations R15 standard de Roblox
local ANIM_IDLE = "rbxassetid://507766666"
local ANIM_WALK = "rbxassetid://507777826"
local ANIM_RUN = "rbxassetid://507767714"

local rng = Random.new()
local folder
local peds = {} -- [model] = data
local drops = {} -- { part, value, expires }

local SKIN = {
	Color3.fromRGB(255, 204, 153), Color3.fromRGB(234, 184, 146), Color3.fromRGB(190, 140, 100),
	Color3.fromRGB(125, 85, 60), Color3.fromRGB(95, 65, 45),
}
local CLOTH = {
	Color3.fromRGB(230, 70, 70), Color3.fromRGB(70, 130, 230), Color3.fromRGB(80, 190, 110),
	Color3.fromRGB(240, 190, 60), Color3.fromRGB(150, 80, 210), Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(60, 60, 70), Color3.fromRGB(240, 130, 60),
}
local PANTS = { Color3.fromRGB(50, 60, 90), Color3.fromRGB(40, 40, 46), Color3.fromRGB(110, 90, 70), Color3.fromRGB(70, 80, 110) }

Pedestrians.Folder = nil

-- Crée un rig R15 coloré. colors = {head, torso, arms, legs}
function Pedestrians.newRig(colors)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = colors.head
	desc.TorsoColor = colors.torso
	desc.LeftArmColor = colors.arms
	desc.RightArmColor = colors.arms
	desc.LeftLegColor = colors.legs
	desc.RightLegColor = colors.legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()
	if not ok or not model then
		warn("[Pedestrians] Création du rig échouée:", model)
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	return model
end

-- Joue idle / marche selon la vitesse (côté serveur, répliqué)
function Pedestrians.setupAnimation(model, runAnim)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local function load(id)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(a)
		end)
		if ok then
			track.Looped = true
			return track
		end
		return nil
	end
	local idle = load(ANIM_IDLE)
	local walk = load(runAnim and ANIM_RUN or ANIM_WALK)
	if idle then
		idle:Play()
	end
	hum.Running:Connect(function(speed)
		if not walk or not idle then
			return
		end
		if speed > 0.8 then
			if idle.IsPlaying then
				idle:Stop(0.2)
			end
			if not walk.IsPlaying then
				walk:Play(0.2)
			end
			walk:AdjustSpeed(math.clamp(speed / 14, 0.5, 1.6))
		else
			if walk.IsPlaying then
				walk:Stop(0.2)
			end
			if not idle.IsPlaying then
				idle:Play(0.2)
			end
		end
	end)
end

local function sidewalkPoint(i, j)
	local c = Config.blockCenter(i, j)
	local side = rng:NextInteger(1, 4)
	local t = rng:NextNumber(-70, 70)
	local r = 73
	if side == 1 then
		return Vector3.new(c.X + t, 3, c.Z - r)
	elseif side == 2 then
		return Vector3.new(c.X + t, 3, c.Z + r)
	elseif side == 3 then
		return Vector3.new(c.X - r, 3, c.Z + t)
	end
	return Vector3.new(c.X + r, 3, c.Z + t)
end

local function randomBlock()
	return rng:NextInteger(1, 5), rng:NextInteger(1, 5)
end

local function spawnOne()
	local colors = {
		head = SKIN[rng:NextInteger(1, #SKIN)],
		torso = CLOTH[rng:NextInteger(1, #CLOTH)],
		arms = CLOTH[rng:NextInteger(1, #CLOTH)],
		legs = PANTS[rng:NextInteger(1, #PANTS)],
	}
	colors.arms = rng:NextNumber() < 0.5 and colors.torso or colors.head
	local model = Pedestrians.newRig(colors)
	if not model then
		return
	end
	model.Name = "Pedestrian"
	model:SetAttribute("Pedestrian", true)
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = rng:NextNumber(7, 12)
	local i, j = randomBlock()
	model:PivotTo(CFrame.new(sidewalkPoint(i, j)))
	model.Parent = folder
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp:SetNetworkOwner(nil)
	end
	Pedestrians.setupAnimation(model, false)
	peds[model] = { model = model, hum = hum, hrp = hrp, target = nil, nextPick = 0, state = "walk", i = i, j = j }
end

function Pedestrians.fromPart(part)
	local m = part:FindFirstAncestorOfClass("Model")
	if m and peds[m] then
		return m
	end
	return nil
end

function Pedestrians.dropCash(pos)
	local part = Instance.new("Part")
	part.Name = "CashDrop"
	part.Size = Vector3.new(2.4, 0.15, 1.2)
	part.Color = Color3.fromRGB(90, 220, 110)
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.Anchored = true
	part.CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	part.Parent = folder
	table.insert(drops, { part = part, value = rng:NextInteger(8, 25), expires = os.clock() + 25 })
end

-- Étourdit un piéton ; retourne false s'il est déjà à terre
function Pedestrians.knockdown(model, velocity)
	local d = peds[model]
	if not d or d.state == "down" or not d.hrp or not d.hrp.Parent then
		return false
	end
	d.state = "down"
	d.hum.PlatformStand = true
	local dir = Vector3.new(velocity.X, 0, velocity.Z)
	dir = dir.Magnitude > 1 and dir.Unit or Vector3.new(0, 0, 1)
	d.hrp.AssemblyLinearVelocity = dir * 38 + Vector3.new(0, 34, 0)
	d.hrp.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
	Pedestrians.dropCash(d.hrp.Position)
	task.delay(3, function()
		if d.hrp and d.hrp.Parent then
			local p = d.hrp.Position
			d.hrp.CFrame = CFrame.new(p.X, p.Y + 2, p.Z)
			d.hrp.AssemblyAngularVelocity = Vector3.zero
			d.hum.PlatformStand = false
			d.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			d.state = "walk"
			d.nextPick = 0
		end
	end)
	return true
end

local function aiStep()
	local now = os.clock()
	for model, d in pairs(peds) do
		if not model.Parent or not d.hrp or not d.hrp.Parent then
			peds[model] = nil
			if model.Parent then
				model:Destroy()
			end
		elseif d.state == "walk" then
			local pos = d.hrp.Position
			if pos.Y < -6 then
				peds[model] = nil
				model:Destroy()
			elseif not d.target or now > d.nextPick or Util.flatDistance(pos, d.target) < 4 then
				local bi = math.clamp(d.i + rng:NextInteger(-1, 1), 1, 5)
				local bj = math.clamp(d.j + rng:NextInteger(-1, 1), 1, 5)
				d.i, d.j = bi, bj
				d.target = sidewalkPoint(bi, bj)
				d.nextPick = now + rng:NextNumber(10, 22)
				d.hum.WalkSpeed = rng:NextNumber(7, 12)
				d.hum:MoveTo(d.target)
			elseif d.hrp.AssemblyLinearVelocity.Magnitude < 0.5 and now > (d.stuckCheck or 0) then
				d.stuckCheck = now + 3
				d.hum.Jump = true
				d.hum:MoveTo(d.target)
			end
		end
	end
end

local function dropsStep()
	local now = os.clock()
	local players = Players:GetPlayers()
	for i = #drops, 1, -1 do
		local dr = drops[i]
		local remove = false
		if not dr.part.Parent or now > dr.expires then
			remove = true
		else
			for _, p in ipairs(players) do
				local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - dr.part.Position).Magnitude < 8 then
					EconomyService.addCash(p, dr.value, "pickup")
					remove = true
					break
				end
			end
		end
		if remove then
			dr.part:Destroy()
			table.remove(drops, i)
		end
	end
end

function Pedestrians.init()
	folder = Instance.new("Folder")
	folder.Name = "Pedestrians"
	folder.Parent = workspace
	Pedestrians.Folder = folder
end

function Pedestrians.start()
	task.spawn(function()
		local n = 0
		while n < TARGET_COUNT do
			pcall(spawnOne)
			n += 1
			task.wait(0.15)
		end
		-- maintien de la population
		while true do
			task.wait(5)
			local count = 0
			for _ in pairs(peds) do
				count += 1
			end
			if count < TARGET_COUNT then
				pcall(spawnOne)
			end
		end
	end)
	Util.supervise("PedestrianService", function()
		while true do
			task.wait(0.5)
			aiStep()
		end
	end)
	Util.supervise("PedestrianService", function()
		while true do
			task.wait(0.25)
			dropsStep()
		end
	end)
end

return Pedestrians
