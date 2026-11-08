--[[
  FallingObjects : objets qui tombent d'une étagère après un délai aléatoire.
  Jamais deux fois au même endroit tant qu'il reste un point libre.
  Tag : FallSpot sur une BasePart (point de départ de la chute, au-dessus de l'étagère).
  Template optionnel : ServerStorage.FallingItem (BasePart). Sinon, bloc de secours.
  L'impact émet un bruit que le monstre peut entendre.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)
local Noise = require(script.Parent.Noise)

local CFG = Config.Falling
local FallingObjects = {}

local generation = 0
local used = {}      -- spot -> true, réinitialisé quand tous les points ont servi
local lastSpot = nil

local function makeItem()
	local template = ServerStorage:FindFirstChild("FallingItem")
	if template and template:IsA("BasePart") then
		return template:Clone()
	end
	if not template then
		warn("[FallingObjects] ServerStorage.FallingItem absent : bloc de secours")
	end
	local part = Instance.new("Part")
	part.Name = "FallingItem"
	part.Size = Vector3.new(0.6, 2.5, 0.6)
	part.Color = Color3.fromRGB(80, 80, 85)
	part.Material = Enum.Material.Metal
	return part
end

local function pickSpot(rng, spots)
	local free = {}
	for _, spot in ipairs(spots) do
		if not used[spot] and spot ~= lastSpot then
			table.insert(free, spot)
		end
	end

	if #free == 0 then
		-- Tous les points ont servi : on repart de zéro, sans reprendre le dernier
		used = {}
		for _, spot in ipairs(spots) do
			if spot ~= lastSpot then
				table.insert(free, spot)
			end
		end
	end
	if #free == 0 then
		return nil
	end

	local spot = free[rng:int(1, #free)]
	used[spot] = true
	lastSpot = spot
	return spot
end

local function drop(spot, rng)
	local item = makeItem()
	item.Anchored = false
	item.CanCollide = true
	item.CFrame = spot.CFrame
	item.AssemblyLinearVelocity = Vector3.new(rng:range(-1, 1), 0, rng:range(-1, 1))
	item.Parent = Workspace
	Debris:AddItem(item, 60) -- sécurité si l'objet ne touche rien

	local landed = false
	item.Touched:Connect(function(hit)
		if landed or hit == spot or hit:IsDescendantOf(item) or hit.CanCollide == false then
			return
		end
		if Players:GetPlayerFromCharacter(hit.Parent) then
			return
		end
		landed = true
		-- Impact silencieux : aucun son métallique retenu. Le bruit ci-dessous attire quand même le monstre.
		Noise.emit(item.Position, CFG.NoiseStrength)
		Debris:AddItem(item, CFG.ItemLifetime)
	end)
end

local function loop(rng, gen)
	while generation == gen do
		task.wait(rng:range(CFG.IntervalMin, CFG.IntervalMax))
		if generation ~= gen then
			return
		end
		local spots = CollectionService:GetTagged("FallSpot")
		local spot = pickSpot(rng, spots)
		if spot and spot:IsA("BasePart") then
			drop(spot, rng)
		elseif not spot then
			warn("[FallingObjects] aucun tag FallSpot dans le monde")
		end
	end
end

function FallingObjects.start(seed)
	generation += 1
	used = {}
	lastSpot = nil
	task.spawn(loop, Rng.new(seed + 1299709), generation)
end

function FallingObjects.stop()
	generation += 1
end

return FallingObjects
