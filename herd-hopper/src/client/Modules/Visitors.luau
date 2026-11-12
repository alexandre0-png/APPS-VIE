-- Visiteurs du zoo : de petits personnages en blocs qui se promènent devant les enclos du joueur.
-- Purement visuels et locaux. Leur nombre grandit avec le zoo (attribut ZooVisitors, 2 à 30).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Visitors = {}

local player = Players.LocalPlayer
local crowd = {}
local folder = nil

local SHIRTS = {
	Color3.fromRGB(230, 90, 90),
	Color3.fromRGB(90, 160, 230),
	Color3.fromRGB(240, 200, 80),
	Color3.fromRGB(120, 200, 120),
	Color3.fromRGB(200, 120, 220),
	Color3.fromRGB(240, 150, 80),
}

local function makePart(parent, size, color)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function newVisitor(center, index)
	local model = Instance.new("Model")
	model.Name = "Visitor"
	local rng = Random.new(index * 97)
	local body = makePart(model, Vector3.new(1.6, 2.2, 1), SHIRTS[rng:NextInteger(1, #SHIRTS)])
	local head = makePart(model, Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(240, 200, 160))
	local legs = makePart(model, Vector3.new(1.4, 1.6, 0.9), Color3.fromRGB(60, 70, 100))
	model.Parent = folder
	local half = Config.Hub.PlotSize / 2 - 6
	local function pick()
		return center + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half + 6, half))
	end
	local visitor = {
		model = model,
		body = body,
		head = head,
		legs = legs,
		pos = pick(),
		target = pick(),
		speed = rng:NextNumber(4, 7),
		phase = rng:NextNumber() * 6,
		pick = pick,
	}
	return visitor
end

local function setCount(n, center)
	while #crowd < n do
		table.insert(crowd, newVisitor(center, #crowd + 1))
	end
	while #crowd > n do
		local v = table.remove(crowd)
		v.model:Destroy()
	end
end

function Visitors.init()
	folder = Instance.new("Folder")
	folder.Name = "HerdHopperVisitors"
	folder.Parent = workspace

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		if accumulator < 0.05 then
			return
		end
		local step = accumulator
		accumulator = 0

		local center = player:GetAttribute("PlotCenter")
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		-- seulement quand le joueur est dans le parc (en hauteur)
		if typeof(center) ~= "Vector3" or not hrp or hrp.Position.Y < 150 then
			setCount(0, Vector3.zero)
			return
		end
		setCount(math.clamp(player:GetAttribute("ZooVisitors") or 2, 0, 30), center + Vector3.new(0, 0.1, 0))

		local t = os.clock()
		for _, v in ipairs(crowd) do
			local delta = v.target - v.pos
			if delta.Magnitude < 1.5 then
				v.target = v.pick()
			else
				v.pos = v.pos + delta.Unit * v.speed * step
			end
			local bob = math.abs(math.sin(t * 6 + v.phase)) * 0.25
			local facing = CFrame.lookAt(v.pos, v.pos + (delta.Magnitude > 0.1 and delta or Vector3.new(0, 0, 1)))
			v.legs.CFrame = facing * CFrame.new(0, 0.8 + bob, 0)
			v.body.CFrame = facing * CFrame.new(0, 2.7 + bob, 0)
			v.head.CFrame = facing * CFrame.new(0, 4.4 + bob, 0)
		end
	end)
end

return Visitors
