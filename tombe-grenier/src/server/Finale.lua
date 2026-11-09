--[[
  Finale : fin « libérer puis fuir ».
  Une fois l'enfant libéré, il suit les joueurs (il ne peut pas être attrapé ; s'il n'y a plus de joueur
  debout, il reste où il est). Les joueurs fuient par le portail : une voiture attend au bout de l'allée,
  une cinématique montre la montée à bord, puis la partie se termine.
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local MonsterAI = require(script.Parent.MonsterAI)

local Finale = {}
local child = nil
local following = false

local function template(name)
	local folder = ServerStorage:FindFirstChild("Decor")
	return folder and folder:FindFirstChild(name) or nil
end

local function nearestAliveRoot(from)
	local best, bestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

-- L'enfant suit le joueur le plus proche, à petits pas. Il ne se fait pas attraper.
local function followLoop()
	while following and child do
		task.wait(0.2)
		local cur = child:GetPivot().Position
		local root = nearestAliveRoot(cur)
		if root then
			local dir = Vector3.new(root.Position.X - cur.X, 0, root.Position.Z - cur.Z)
			if dir.Magnitude > 40 then
				-- Trop loin : il rejoint le joueur, derrière lui
				child:PivotTo(CFrame.new(root.Position - root.CFrame.LookVector * 4))
			elseif dir.Magnitude > 4 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { child }
				-- Essaie la direction du joueur, puis des directions voisines : il contourne les murs
				local len = math.min(dir.Magnitude - 3, 1.2)
				for _, angle in ipairs({ 0, 45, -45, 90, -90 }) do
					local rad = math.rad(angle)
					local d = dir.Unit
					local rotated = Vector3.new(d.X * math.cos(rad) - d.Z * math.sin(rad), 0, d.X * math.sin(rad) + d.Z * math.cos(rad))
					if not Workspace:Raycast(cur + Vector3.new(0, 1, 0), rotated * len, params) then
						child:PivotTo(CFrame.new(cur + rotated * len))
						break
					end
				end
			end
		end
	end
end

-- Libération : l'enfant apparaît au cercueil et commence à suivre les joueurs
function Finale.freed()
	if child then
		return
	end
	local model = template("enfant")
	if not model then
		return
	end
	child = model:Clone()
	for _, d in ipairs(child:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	child:PivotTo(CFrame.new(90, 25.5, 45))
	child.Parent = Workspace
	following = true
	task.spawn(followLoop)
end

-- Fuite : la voiture arrive au bout de l'allée, la cinématique se joue, puis la fin
function Finale.escape(onDone)
	local car = template("voiture")
	if car then
		local vehicle = car:Clone()
		for _, d in ipairs(vehicle:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		vehicle:PivotTo(CFrame.new(60, 0, 175))
		vehicle.Parent = Workspace
		-- La voiture entière roule sur la route, au-delà du portail (on déplace le modèle, pas une seule pièce)
		task.spawn(function()
			local start = vehicle:GetPivot()
			local steps = 50
			for i = 1, steps do
				vehicle:PivotTo(start * CFrame.new(0, 0, 90 * i / steps))
				task.wait(10 / steps)
			end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.fire("Effect", player, { kind = "Cine", name = "voiture" })
	end
	-- Le monstre suit la voiture de loin, sur la route, à mi-parcours
	task.delay(5, function()
		MonsterAI.walkPoints({ Vector3.new(60, 0.5, 150), Vector3.new(60, 0.5, 200), Vector3.new(60, 0.5, 225) }, 7)
	end)
	task.delay(12, function()
		following = false
		onDone()
	end)
end

return Finale
