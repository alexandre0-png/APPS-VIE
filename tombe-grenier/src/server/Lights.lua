--[[
  Lights : lampes qui scintillent par séquences irrégulières, et coupures totales.
  Reproductible : même seed de partie => mêmes séquences.
  Tag : FlickerLight sur une BasePart contenant une PointLight ou SpotLight.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rng = require(Shared.Rng)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local MonsterAI = require(script.Parent.MonsterAI)

local CFG = Config.Lights
local Lights = {}

local generation = 0
local blackoutUntil = 0

local function setPart(part, on)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("PointLight") or child:IsA("SpotLight") or child:IsA("SurfaceLight") then
			child.Enabled = on
		end
	end
	part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
end

local function nearMonster(part)
	local pos = MonsterAI.getRootPosition()
	return pos ~= nil and (pos - part.Position).Magnitude < CFG.NearMonsterRange
end

-- Un cycle de scintillement : allumée, rafales, éteinte
local function flickerCycle(part, rng, gen)
	local onTime = rng:range(CFG.OnMin, CFG.OnMax)
	if nearMonster(part) then
		onTime = onTime * CFG.NearMonsterOnFactor
	end
	setPart(part, true)
	task.wait(onTime)
	if generation ~= gen then
		return
	end

	for _ = 1, rng:int(CFG.BurstMin, CFG.BurstMax) do
		setPart(part, false)
		task.wait(rng:range(CFG.OffMin, CFG.OffMax))
		setPart(part, true)
		if rng:next() < 0.3 then
			Audio.play("lumiere", part, { lifetime = 2 })
		end
		task.wait(rng:range(0.05, 0.25))
		if generation ~= gen then
			return
		end
	end

	setPart(part, false)
	task.wait(rng:range(CFG.OffMin * 2, CFG.OffMax * 2))
end

local function runLight(part, rng, gen)
	while generation == gen and part.Parent do
		if os.clock() < blackoutUntil then
			setPart(part, false)
			task.wait(0.1)
		else
			flickerCycle(part, rng, gen)
		end
	end
end

-- Coupure totale : toutes les lampes éteintes, effet visuel côté client
function Lights.blackout()
	blackoutUntil = os.clock() + CFG.BlackoutDuration
	Audio.play("interrupteur", workspace, { lifetime = 4 })
	task.delay(CFG.BlackoutDuration, function()
		Audio.play("courant", workspace, { lifetime = 4 })
	end)
	for _, part in ipairs(CollectionService:GetTagged("FlickerLight")) do
		setPart(part, false)
	end
	Remotes.fireAll("Effect", { kind = "Blackout", duration = CFG.BlackoutDuration })
end

local function blackoutLoop(rng, gen)
	while generation == gen do
		task.wait(rng:range(CFG.BlackoutIntervalMin, CFG.BlackoutIntervalMax))
		if generation ~= gen then
			return
		end
		Lights.blackout()
	end
end

function Lights.start(seed)
	generation += 1
	local gen = generation
	blackoutUntil = 0

	local lights = CollectionService:GetTagged("FlickerLight")
	if #lights == 0 then
		warn("[Lights] aucun tag FlickerLight dans le monde")
	end
	for i, part in ipairs(lights) do
		if part:IsA("BasePart") then
			task.spawn(runLight, part, Rng.new(seed + i * 7919), gen)
		end
	end
	task.spawn(blackoutLoop, Rng.new(seed + 104729), gen)
end

function Lights.stop()
	generation += 1
end

return Lights
