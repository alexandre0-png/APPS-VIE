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

-- Événements ambiants au grenier : silhouette furtive (une fois sur deux) ou pas à l'étage
local function sceneLoop(rng, gen)
	while generation == gen do
		task.wait(rng:range(35, 60))
		if generation ~= gen then
			return
		end
		if rng:next() < 0.5 then
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
			Debris:AddItem(silhouette, 2.5)
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
	task.spawn(screamLoop, Rng.new(seed + 7717), gen)
end

function Ambience.stop()
	generation += 1
end

return Ambience
