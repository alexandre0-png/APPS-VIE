--[[
  Ambience : bruits d'ambiance serveur.
  - Grincements de porte ou de chaise, positionnés sur un point Waypoint.
  - Cri lointain, au plus un par intervalle (Config.Ambience.ScreamInterval).
  Reproductible par seed, comme les lampes.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)
local Audio = require(Shared.Audio)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Remotes = require(Shared.Remotes)

local CFG = Config.Ambience
local Ambience = {}

local generation = 0

local function creakLoop(rng, gen)
	while generation == gen do
		task.wait(rng:range(CFG.CreakIntervalMin, CFG.CreakIntervalMax))
		if generation ~= gen then
			return
		end
		local key = rng:int(1, 2) == 1 and "porte_grince" or "chaise_grince"
		local points = CollectionService:GetTagged("Waypoint")
		local parent = #points > 0 and points[rng:int(1, #points)] or Workspace
		Audio.play(key, parent, { range = 30, lifetime = 6 })
	end
end

local function screamLoop(rng, gen)
	while generation == gen do
		task.wait(CFG.ScreamInterval)
		if generation ~= gen then
			return
		end
		if rng:next() < CFG.ScreamChance then
			Audio.play("cri_loin", Workspace, { lifetime = 10 })
		end
	end
end

-- Une porte se ferme seule, puis se rouvre une dizaine de secondes plus tard
local function doorLoop(rng, gen)
	local Props = require(script.Parent.Props)
	while generation == gen do
		task.wait(rng:range(40, 70))
		if generation ~= gen then
			return
		end
		local doors = CollectionService:GetTagged("Door")
		if #doors > 0 and rng:next() < 0.6 then
			local door = doors[rng:int(1, #doors)]
			if door:GetAttribute("Open") then
				Props.setDoor(door, false)
				Audio.play("porte_grince", door, { lifetime = 5 })
				task.delay(10, function()
					if door.Parent and door:GetAttribute("Open") == false then
						Props.setDoor(door, true)
					end
				end)
			end
		end
	end
end

-- Les rideaux bougent alors que les fenêtres sont fermées : un léger balancement
local function curtainLoop(rng, gen)
	local TweenService = game:GetService("TweenService")
	while generation == gen do
		task.wait(rng:range(20, 45))
		if generation ~= gen then
			return
		end
		local curtains = CollectionService:GetTagged("Curtain")
		if #curtains > 0 and rng:next() < 0.7 then
			local c = curtains[rng:int(1, #curtains)]
			if c:IsA("BasePart") then
				local origin = c.CFrame
				local sway = origin * CFrame.Angles(0, math.rad(4), 0)
				TweenService:Create(c, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { CFrame = sway }):Play()
				task.wait(2.5)
				TweenService:Create(c, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { CFrame = origin }):Play()
			end
		end
	end
end

-- Consignes du téléphone : elles se contredisent
local PHONE_LINES = {
	"« Reste dans la pièce. Ne bouge plus. »",
	"« Sors immédiatement. Tu n'as plus le temps. »",
	"« Ne fais confiance à aucune porte. »",
	"« Ce n'est pas toi qui décides. »",
	"« Je sais où tu te caches. »",
}

-- Point invisible où jouer un son, à une position donnée
local function anchorAt(pos)
	local part = Instance.new("Part")
	part.Name = "Ambiance"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = pos
	part.Parent = Workspace
	Debris:AddItem(part, 10)
	return part
end

-- Un grincement dans la cage d'escalier, personne n'y est
local function stairCreak()
	Audio.play("grincement_escalier", anchorAt(Vector3.new(54, 14, 25)), { lifetime = 4 })
end

-- Lumière rouge au bout du couloir de l'étage, quelques secondes
local function redLight()
	local part = anchorAt(Vector3.new(79, 15, 22))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 30, 20)
	light.Range = 16
	light.Brightness = 2
	light.Parent = part
	task.delay(4, function()
		light:Destroy()
	end)
end

-- Voix d'enfant qui appelle depuis la cave (son déjà fourni, sans identifiant nouveau)
local function caveVoice()
	local doors = CollectionService:GetTagged("CaveDoor")
	local source = doors[1] or anchorAt(Vector3.new(80, -6, 45))
	Audio.play("cri_loin", source, { lifetime = 6 })
	Remotes.fireAll("Message", { text = "Une voix d'enfant demande de l'aide, quelque part sous tes pieds." })
end

-- Une armoire tremble quelques secondes quand on approche (une seule à la fois)
local function armoireTremble()
	local spots = {}
	for _, part in ipairs(CollectionService:GetTagged("Hiding")) do
		if part:IsA("BasePart") and part:GetAttribute("Kind") == "armoire" then
			table.insert(spots, part)
		end
	end
	if #spots == 0 then
		return
	end
	local spot = spots[math.random(1, #spots)]
	-- Le marqueur est invisible : on fait trembler le meuble réel le plus proche
	local meubles = Workspace:FindFirstChild("TombeMap") and Workspace.TombeMap:FindFirstChild("Meubles")
	local part, best = nil, math.huge
	for _, f in ipairs(meubles and meubles:GetChildren() or {}) do
		if f:IsA("BasePart") and f.Name == "armoire" then
			local d = (f.Position - spot.Position).Magnitude
			if d < best then
				part, best = f, d
			end
		end
	end
	part = part or spot
	local origin = part.Position
	task.spawn(function()
		for i = 1, 8 do
			part.Position = origin + Vector3.new(i % 2 == 0 and 0.06 or -0.06, 0, 0)
			task.wait(0.08)
		end
		part.Position = origin
	end)
end

-- Événement d'ambiance tiré au hasard, parmi ceux qui n'exigent aucun asset nouveau
local function pickScare(rng)
	local choice = rng:int(1, 4)
	if choice == 1 then
		stairCreak()
	elseif choice == 2 then
		redLight()
	elseif choice == 3 then
		caveVoice()
	else
		armoireTremble()
	end
end

-- Au réveil : trois coups venus du mur, à intervalles irréguliers
function Ambience.knocks()
	local origin = Vector3.new(90, 27.5, 45)
	for i = 1, 3 do
		task.delay(0.9 * i + 0.2 * i, function()
			Audio.play("coups_mur", anchorAt(origin + Vector3.new(-3, 0, 0)), { lifetime = 2 })
		end)
	end
end

-- Téléphone qui sonne, portes qui s'ouvrent seules : des événements à intervalles irréguliers
local function eventLoop(rng, gen)
	local Props = require(script.Parent.Props)
	while generation == gen do
		task.wait(rng:range(25, 45))
		if generation ~= gen then
			return
		end
		local r = rng:next()
		if r < 0.4 then
			local phones = CollectionService:GetTagged("Phone")
			for _, phone in ipairs(phones) do
				if phone:IsA("BasePart") then
					Audio.play("telephone", phone, { lifetime = 10 })
				end
			end
			local line = PHONE_LINES[rng:int(1, #PHONE_LINES)]
			task.delay(6, function()
				if generation == gen then
					Remotes.fireAll("Message", { text = line })
				end
			end)
		elseif r < 0.7 then
			local closed = {}
			for _, door in ipairs(CollectionService:GetTagged("Door")) do
				if door:GetAttribute("Open") == false and door:GetAttribute("Lock") == nil then
					table.insert(closed, door)
				end
			end
			if #closed > 0 then
				local door = closed[rng:int(1, #closed)]
				Props.setDoor(door, true)
				Audio.play("porte_grince", door, { lifetime = 5 })
			end
		else
			pickScare(rng)
		end
	end
end

-- Événements ambiants au grenier : silhouette furtive (une fois sur deux) ou pas à l'étage
local function sceneLoop(rng, gen)
	while generation == gen do
		task.wait(rng:range(35, 60))
		if generation ~= gen then
			return
		end
		local pick = rng:next()
		if pick < 0.3 then
			local silhouette = Instance.new("Part")
			silhouette.Name = "Silhouette"
			silhouette.Anchored = true
			silhouette.CanCollide = false
			silhouette.CanTouch = false
			silhouette.Size = Vector3.new(1.4, 7, 0.8)
			silhouette.CFrame = CFrame.new(112, 27.5, 82)
			silhouette.Color = Color3.fromRGB(8, 8, 10)
			silhouette.Material = Enum.Material.SmoothPlastic
			silhouette.Transparency = 0.15
			silhouette.Parent = Workspace
			Audio.play("grognement", silhouette, { lifetime = 3 })
			Debris:AddItem(silhouette, 2.5)
		elseif pick < 0.6 then
			-- Une silhouette traverse le couloir en courant, du palier vers le couloir
			local runner = Instance.new("Part")
			runner.Name = "Silhouette courante"
			runner.Anchored = true
			runner.CanCollide = false
			runner.CanTouch = false
			runner.Size = Vector3.new(1.2, 5.5, 0.8)
			runner.Color = Color3.fromRGB(10, 10, 12)
			runner.Material = Enum.Material.SmoothPlastic
			runner.Transparency = 0.2
			runner.Position = Vector3.new(60, 14.75, 4)
			runner.Parent = Workspace
			TweenService:Create(runner, TweenInfo.new(3.5, Enum.EasingStyle.Linear),
				{ Position = Vector3.new(60, 14.75, 84) }):Play()
			Debris:AddItem(runner, 4)
		else
			local source = Instance.new("Part")
			source.Name = "Pas à l'étage"
			source.Anchored = true
			source.CanCollide = false
			source.Transparency = 1
			source.Size = Vector3.new(1, 1, 1)
			source.Position = Vector3.new(45, 25, 40)
			source.Parent = Workspace
			Audio.play("pas", source, { lifetime = 6 })
			Debris:AddItem(source, 8)
		end
	end
end

function Ambience.start(seed)
	generation += 1
	local gen = generation
	task.spawn(sceneLoop, Rng.new(seed + 9901), gen)
	task.spawn(creakLoop, Rng.new(seed + 3571), gen)
	task.spawn(doorLoop, Rng.new(seed + 4421), gen)
	task.spawn(curtainLoop, Rng.new(seed + 5519), gen)
	task.spawn(eventLoop, Rng.new(seed + 6607), gen)
	task.spawn(screamLoop, Rng.new(seed + 7717), gen)
end

function Ambience.stop()
	generation += 1
end

return Ambience
