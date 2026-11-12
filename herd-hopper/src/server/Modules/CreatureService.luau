-- Troupeau : construction des bêtes, déplacement, apparition / disparition.
-- Chaque bête = un Model dont seule la pièce "Root" est ancrée ; les autres pièces sont soudées.
-- Déplacer Root (CFrame) déplace tout le monde et ne réplique qu'une pièce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Species = require(Shared.Species)
local Util = require(Shared.Util)

local AnimMath = require(Shared.AnimMath)

local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)

local CreatureService = {}

local rng = Random.new()

local function variantColor(color, variantIdx)
	if variantIdx == 2 then
		return color:Lerp(Color3.fromRGB(110, 210, 255), 0.55)
	elseif variantIdx == 3 then
		return color:Lerp(Color3.fromRGB(255, 205, 60), 0.65)
	end
	return color
end

local function variantMaterial(variantIdx, override)
	if variantIdx == 2 then
		return Enum.Material.Ice
	elseif variantIdx == 3 then
		return Enum.Material.Metal
	end
	return override or Enum.Material.Plastic
end

local function newPart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	return part
end

-- Construit le modèle d'une bête (sans le parenter). Renvoie model, root.
function CreatureService.BuildModel(def, variantIdx)
	local palette = def.palette
	local model = Instance.new("Model")
	model.Name = "Beast"

	local function color(key)
		if key == "eye" then
			return palette.eye
		end
		return variantColor(palette[key], variantIdx)
	end

	local root = newPart("Root", def.body.s, color(def.body.c), variantMaterial(variantIdx))
	root.Anchored = true
	root.CFrame = CFrame.new(0, 0, 0)
	root.CastShadow = true
	root.Parent = model
	model.PrimaryPart = root

	for _, spec in ipairs(def.parts) do
		local part = newPart(
			spec.n,
			spec.s,
			color(spec.c),
			spec.c == "eye" and Enum.Material.SmoothPlastic or variantMaterial(variantIdx)
		)
		local rot = spec.rot or Vector3.new(0, 0, 0)
		part.CFrame = root.CFrame
			* CFrame.new(spec.o)
			* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		part.CastShadow = spec.s.Magnitude > 3
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	for _, spec in ipairs(def.legs) do
		local pivot = Vector3.new(0, spec.s.Y / 2, 0)
		local part = newPart(spec.n, spec.s, color(spec.c), variantMaterial(variantIdx))
		part.CFrame = root.CFrame * CFrame.new(spec.hip) * CFrame.new(-pivot)
		part.CastShadow = false
		local motor = Instance.new("Motor6D")
		motor.Name = spec.n
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = CFrame.new(spec.hip)
		motor.C1 = CFrame.new(pivot)
		motor:SetAttribute("Phase", spec.phase)
		motor.Parent = part
		part.Parent = model
	end

	for _, spec in ipairs(def.wings) do
		local pivot = Vector3.new(-spec.side * spec.s.X / 2, 0, 0)
		local part = newPart(spec.n, spec.s, color(spec.c), variantMaterial(variantIdx))
		part.CFrame = root.CFrame * CFrame.new(spec.hip) * CFrame.new(-pivot)
		part.CastShadow = false
		local motor = Instance.new("Motor6D")
		motor.Name = spec.n
		motor.Part0 = root
		motor.Part1 = part
		motor.C0 = CFrame.new(spec.hip)
		motor.C1 = CFrame.new(pivot)
		motor:SetAttribute("Side", spec.side)
		motor.Parent = part
		part.Parent = model
	end

	return model, root
end

local function addEmitters(def, variantIdx, root)
	-- Poussière : activée uniquement quand la bête est montée.
	local dustAttachment = Instance.new("Attachment")
	dustAttachment.Name = "DustAttachment"
	if def.flying then
		dustAttachment.Position = Vector3.new(0, 0, 3)
	else
		dustAttachment.Position = Vector3.new(0, -def.rootY + 0.5, 2)
	end
	dustAttachment.Parent = root

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Enabled = false
	dust.Rate = 26
	dust.Lifetime = NumberRange.new(0.5, 1.0)
	dust.Speed = NumberRange.new(4, 9)
	dust.SpreadAngle = Vector2.new(25, 25)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.8), NumberSequenceKeypoint.new(1, 0.2) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(def.flying and Color3.fromRGB(200, 170, 255) or Color3.fromRGB(214, 190, 150))
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Parent = dustAttachment

	if variantIdx > 1 then
		local spark = Instance.new("ParticleEmitter")
		spark.Name = "Sparkle"
		spark.Rate = 5
		spark.Lifetime = NumberRange.new(0.8, 1.4)
		spark.Speed = NumberRange.new(1, 3)
		spark.SpreadAngle = Vector2.new(180, 180)
		spark.LightEmission = 1
		spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
		spark.Color =
			ColorSequence.new(variantIdx == 3 and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(150, 230, 255))
		spark.Parent = root
	end
end

-- Animal tiré dans la liste de la zone où se trouve `z`.
local function pickSpecies(z)
	local zone = Config.zoneAt(z or 0)
	local list = {}
	for _, id in ipairs(zone.animals) do
		table.insert(list, Species.ById[id])
	end
	return Util.pickWeighted(list, rng)
end

local function pickVariant()
	return Util.pickWeighted(Config.Variants, rng).id
end

-- Crée une bête et l'ajoute au monde. Renvoie le record `creature`.
-- Un animal peut porter un cœur rose (récupérable) ; un boss en porte toujours un.
function CreatureService.Spawn(x, z, speciesId, variantIdx, speedFactor)
	local def = speciesId and Species.ById[speciesId] or pickSpecies(z)
	if def.boss then
		variantIdx = 1
	else
		variantIdx = variantIdx or pickVariant()
	end
	local variant = Config.Variants[variantIdx]
	local zone = Config.zoneAt(z)
	local hearted = def.boss == true or rng:NextNumber() < zone.heartChance + State.HeartBonus

	local id = State.NextCreatureId
	State.NextCreatureId = id + 1

	local model, root = CreatureService.BuildModel(def, variantIdx)
	model.Name = "Beast" .. id
	model:SetAttribute("Id", id)
	model:SetAttribute("Species", def.id)
	model:SetAttribute("Variant", variantIdx)
	model:SetAttribute("BaseSpeed", def.speed)
	model:SetAttribute("BaseY", def.rootY)
	model:SetAttribute("Ridden", false)
	model:SetAttribute("Angry", false)
	model:SetAttribute("Heart", hearted)
	model:SetAttribute("Ready", false)
	model:SetAttribute("Boss", def.boss == true)
	addEmitters(def, variantIdx, root)

	local baseSpeed = def.speed * (0.9 + rng:NextNumber() * 0.2) * (speedFactor or 1)
	if variantIdx == 3 then
		baseSpeed = baseSpeed * 1.1
	end

	local creature = {
		id = id,
		def = def,
		variantIdx = variantIdx,
		variant = variant,
		model = model,
		root = root,
		x = x,
		z = z,
		baseSpeed = baseSpeed,
		speed = baseSpeed,
		phase = rng:NextNumber() * 10,
		age = 0,
		steer = 0,
		vx = 0,
		rider = nil,
		hearted = hearted,
		boss = def.boss == true,
		progress = {}, -- [Player] = secondes passées en selle (boss)
		tamed = false,
		tamedBy = nil,
		collectUntil = 0,
		angry = false,
		removed = false,
		seat = CFrame.new(def.seat),
	}

	local y = def.rootY
	root.CFrame = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z + 1))
	model.Parent = State.CreaturesFolder
	State.Creatures[id] = creature
	return creature
end

function CreatureService.Remove(creature)
	if creature.removed then
		return
	end
	creature.removed = true
	State.Creatures[creature.id] = nil
	creature.model:Destroy()
end

function CreatureService.Clear()
	for _, creature in pairs(State.Creatures) do
		creature.removed = true
		creature.model:Destroy()
	end
	State.Creatures = {}
end

function CreatureService.SeatWorldCFrame(creature)
	return creature.root.CFrame * creature.seat
end

-- Bête libre la plus proche (pour remonter un joueur tombé). Renvoie nil si aucune.
function CreatureService.FindRescue(x, z)
	local best, bestScore = nil, math.huge
	for _, creature in pairs(State.Creatures) do
		if not creature.rider and not creature.removed and not creature.capture then
			local dz = creature.z - z
			if dz > -25 and dz < 150 then
				local score = math.abs(dz - 20) + math.abs(creature.x - x) * 0.5
				if score < bestScore then
					best, bestScore = creature, score
				end
			end
		end
	end
	return best
end

local function activeBounds()
	local minZ, maxZ = math.huge, -math.huge
	local positions = {}
	for _, run in pairs(State.Participants) do
		local s = run.status
		if s == "Riding" or s == "Air" or s == "Hooking" or s == "Down" then
			local z = run.z or 0
			minZ = math.min(minZ, z)
			maxZ = math.max(maxZ, z)
			table.insert(positions, z)
		end
	end
	if #positions == 0 then
		return nil, nil, positions
	end
	return minZ, maxZ, positions
end

local function tooClose(x, z)
	for _, creature in pairs(State.Creatures) do
		if math.abs(creature.z - z) < 9 and math.abs(creature.x - x) < 9 then
			return true
		end
	end
	return false
end

local function trySpawnNear(z0, ahead)
	for _ = 1, 6 do
		local x = (rng:NextNumber() * 2 - 1) * (Config.Track.HalfWidth - 8)
		local z = z0 + ahead[1] + rng:NextNumber() * (ahead[2] - ahead[1])
		if z < Config.Track.FinishZ - 40 and not tooClose(x, z) then
			-- Les bêtes de devant sont un peu plus lentes pour rester rattrapables.
			return CreatureService.Spawn(x, z, nil, nil, 0.85 + rng:NextNumber() * 0.15)
		end
	end
	return nil
end

-- Remplit la zone de départ au début de l'expédition (autour de `startZ`).
function CreatureService.FillInitial(startZ)
	for _ = 1, 40 do
		local x = (rng:NextNumber() * 2 - 1) * (Config.Track.HalfWidth - 8)
		local z = startZ + 40 + rng:NextNumber() * 260
		if not tooClose(x, z) then
			CreatureService.Spawn(x, z)
		end
	end
end

-- Capture animée : l'animal s'envole en tournoyant puis disparaît (joyeux, sans violence).
local function stepCapture(creature)
	local c = creature.capture
	local p = (os.clock() - c.t0) / c.duration
	if p >= 1 then
		CreatureService.Remove(creature)
		return
	end
	local rise, spin, hop = AnimMath.capture(p)
	creature.root.CFrame = CFrame.new(c.x, c.y + rise + hop, c.z) * CFrame.Angles(0, c.yaw + spin, 0)
end

function CreatureService.BeginCapture(creature)
	if creature.removed or creature.capture then
		return
	end
	creature.hearted = false
	creature.tamed = false
	creature.model:SetAttribute("Heart", false)
	creature.model:SetAttribute("Ready", false)
	creature.model:SetAttribute("Captured", true)
	local cfg = Config.Animations
	if not (cfg.Enabled and cfg.Capture) then
		CreatureService.Remove(creature)
		return
	end
	creature.capture = {
		t0 = os.clock(),
		duration = 0.8,
		x = creature.x,
		y = creature.y or creature.def.rootY,
		z = creature.z,
		yaw = math.pi,
	}
	Fx.confetti(creature.root.Position + Vector3.new(0, 4, 0), creature.boss and 30 or 14)
end

function CreatureService.Step(dt)
	if State.Frozen then
		return
	end

	local half = Config.Track.HalfWidth
	local finishZ = Config.Track.FinishZ

	local bossStomp = Config.Animations.Enabled and Config.Animations.Boss
	for _, creature in pairs(State.Creatures) do
		if creature.capture then
			stepCapture(creature)
		else
			local def = creature.def
			creature.age = creature.age + dt

			local target = creature.baseSpeed
			if def.trait == "charge" then
				if (creature.age + creature.phase) % 6 < 1.2 then
					target = target * 1.5
				end
			end
			creature.speed = creature.speed + (target - creature.speed) * math.min(1, dt * 4)

			local vx
			if creature.rider then
				vx = creature.steer * Config.Ride.SteerSpeed
			else
				vx = math.sin(creature.age * def.weaveFreq + creature.phase) * def.weaveAmp
			end
			creature.vx = vx
			creature.x = math.clamp(creature.x + vx * dt, -half, half)
			creature.z = creature.z + creature.speed * dt

			local y = def.rootY
			if def.trait == "hop" then
				y = y + math.abs(math.sin((creature.age + creature.phase) * 3.2)) * 2.2
			elseif def.flying then
				y = y + math.sin((creature.age + creature.phase) * 2) * 1.2
			elseif def.boss and bossStomp and not creature.rider then
				y = y + AnimMath.bossStomp(creature.age)
			end
			creature.y = y

			local pos = Vector3.new(creature.x, y, creature.z)
			creature.root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(vx * 0.12, 0, 1))
				* CFrame.Angles(0, 0, -vx * 0.004)
		end
	end

	-- Disparition : trop loin derrière / devant les joueurs actifs, ou après l'arrivée.
	local minZ, maxZ, positions = activeBounds()
	local toRemove = nil
	for _, creature in pairs(State.Creatures) do
		local gone = creature.z > finishZ + 30
		if minZ and not creature.rider then
			if creature.z < minZ - 90 or creature.z > maxZ + 320 then
				gone = true
			end
		end
		if gone and not creature.rider then
			toRemove = toRemove or {}
			table.insert(toRemove, creature)
		end
	end
	if toRemove then
		for _, creature in ipairs(toRemove) do
			CreatureService.Remove(creature)
		end
	end

	-- Apparition : garantir de la densité devant chaque joueur actif.
	if not minZ then
		return
	end
	local total = 0
	for _ in pairs(State.Creatures) do
		total = total + 1
	end
	local desired = math.clamp(10 + 9 * #positions, 28, 64)
	local spawned = 0
	for _, pz in ipairs(positions) do
		if total >= 80 or spawned >= 3 then
			break
		end
		local ahead = 0
		for _, creature in pairs(State.Creatures) do
			if creature.z > pz and creature.z < pz + 170 then
				ahead = ahead + 1
			end
		end
		if ahead < 7 then
			if trySpawnNear(pz, { 60, 170 }) then
				spawned = spawned + 1
				total = total + 1
			end
		end
	end
	if total < desired and spawned < 3 then
		local pz = positions[rng:NextInteger(1, #positions)]
		if trySpawnNear(pz, { 40, 190 }) then
			total = total + 1
		end
	end
end

return CreatureService
