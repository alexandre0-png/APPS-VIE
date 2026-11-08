--[[
  MonsterAI : machine à états serveur.

  États :
    Patrol      -> patrouille entre les Waypoint (ou autour du point de départ)
    Investigate -> va vers un bruit (pas de joueur vu)
    Chase       -> poursuit un joueur vu
    Search      -> cherche là où la cible a été vue pour la dernière fois

  Perception : vue en cône + ligne de vue (raycast), ouïe = distance x bruit du joueur,
               débusquage des joueurs cachés à courte distance.
  Lampe torche : un faisceau qui touche le monstre le fige tant qu'il dure.
  Pathfinding : PathfindingService, repli sur MoveTo direct si aucun chemin.
]]
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Audio = require(Shared.Audio)
local Remotes = require(Shared.Remotes)
local Animations = require(Shared.Animations)
local Noise = require(script.Parent.Noise)
local PlayerState = require(script.Parent.PlayerState)
local Memory = require(script.Parent.Memory)
local MapBuilder = require(script.Parent.MapBuilder)
local Props = require(script.Parent.Props)

local CFG = Config.Monster
local PATH_PARAMS = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true }

local MonsterAI = {}
local current = nil
local runId = 0

local function clock()
	return os.clock()
end

-- Ligne de vue libre entre deux points, en ignorant les instances listées
local function clearLine(from, to, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return Workspace:Raycast(from, to - from, params) == nil
end

-- Construit le monstre : modèle ServerStorage.Monster, ou rig de secours
-- Modèles R15 du monstre (identifiants Roblox fournis) : essayés dans l'ordre, à l'initialisation
local REMOTE_MONSTERS = { 126828585469313, 139294979123405 }

-- Charge un modèle R15 dans ServerStorage/Monster si rien n'y est déjà. Les scripts du modèle sont retirés.
function MonsterAI.ensureModel()
	if ServerStorage:FindFirstChild("Monster") then
		return
	end
	local InsertService = game:GetService("InsertService")
	for _, id in ipairs(REMOTE_MONSTERS) do
		local ok, container = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok and container then
			local model = container:FindFirstChildWhichIsA("Model", true)
			if model then
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
						d:Destroy()
					end
				end
				model.Name = "Monster"
				model.Parent = ServerStorage
				container:Destroy()
				return
			end
			container:Destroy()
		end
	end
	warn("[MonsterAI] aucun modèle R15 chargé : rig de secours utilisé")
end

local function buildModel()
	local template = ServerStorage:FindFirstChild("Monster")
	if template then
		local model = template:Clone()
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and model:FindFirstChildOfClass("Humanoid") then
			model.PrimaryPart = root
			return model
		end
		model:Destroy()
		warn("[MonsterAI] ServerStorage.Monster sans HumanoidRootPart ou Humanoid : rig de secours utilisé")
	else
		warn("[MonsterAI] ServerStorage.Monster absent : rig de secours utilisé")
	end

	local model = Instance.new("Model")
	model.Name = "Monster"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true -- sinon le monstre traverse le sol
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = Color3.fromRGB(15, 15, 15)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CFrame = root.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local hum = Instance.new("Humanoid")
	hum.Parent = model

	model.PrimaryPart = root
	return model
end

local function spawnPoint()
	local spawns = CollectionService:GetTagged("MonsterSpawn")
	if #spawns > 0 then
		return spawns[math.random(#spawns)].Position + Vector3.new(0, 3, 0)
	end
	warn("[MonsterAI] aucun tag MonsterSpawn : spawn en (0, 5, 0)")
	return Vector3.new(0, 5, 0)
end

local function pickPatrolPoint(origin)
	local waypoints = CollectionService:GetTagged("Waypoint")
	if #waypoints > 0 then
		-- Le monstre préfère les pièces où le joueur est souvent allé (3 tirages, le plus souvent visité)
		local best, bestWeight = nil, -1
		for _ = 1, 3 do
			local wp = waypoints[math.random(#waypoints)]
			local weight = Memory.roomWeight(MapBuilder.roomAt(wp.Position, true))
			if weight > bestWeight then
				best, bestWeight = wp, weight
			end
		end
		return best.Position
	end
	local angle = math.random() * math.pi * 2
	local dist = math.random(10, CFG.PatrolRadius)
	return origin + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

local function isRunning(m)
	return m.alive and m.runId == runId and m.hum.Health > 0
end

-- Lampe torche : un joueur qui éclaire le monstre le fige
local function beamOnMonster(m)
	local cosHalf = math.cos(math.rad(Config.Flashlight.Angle / 2))
	for _, player in ipairs(Players:GetPlayers()) do
		local st = PlayerState.get(player)
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		if st and st.flashlightOn and head then
			local offset = m.root.Position - head.Position
			local dist = offset.Magnitude
			if dist > 0
				and dist <= Config.Flashlight.Range
				and offset.Unit:Dot(head.CFrame.LookVector) >= cosHalf
				and clearLine(head.Position, m.root.Position, { char, m.model })
			then
				return true
			end
		end
	end
	return false
end

-- Met à jour le gel du monstre ; true si le monstre est figé
local function paused(m)
	if beamOnMonster(m) then
		m.pauseUntil = clock() + CFG.FreezeHold
	end
	return clock() < m.pauseUntil
end

-- Perception : retourne (joueur, "seen"|"heard", position) ou nil
-- Portée de vue réduite quand le joueur est dans le noir sans lampe allumée
local function sightRangeFor(st)
	if st.roomDark and not st.flashlightOn then
		return CFG.SightRange * CFG.DarkSightFactor
	end
	return CFG.SightRange
end

local function perceive(m)
	local cosHalf = math.cos(math.rad(CFG.FOV / 2))
	local searching = m.state ~= "Chase"
	local bestPlayer, bestDist, bestKind, bestPos = nil, math.huge, nil, nil

	for _, player in ipairs(Players:GetPlayers()) do
		local st = PlayerState.get(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if st and root and hum and hum.Health > 0 then
			local offset = root.Position - m.head.Position
			local dist = offset.Magnitude

			if st.hiding then
				-- Joueur caché : débusquage possible à courte distance
				if searching
					and dist <= CFG.SearchRange
					and math.random() < CFG.DiscoverChancePerSecond * CFG.Tick
				then
					PlayerState.unhide(player, true)
					PlayerState.markThreat(player)
					return player, "seen", root.Position
				end
			else
				local kind = nil
				if dist > 0
					and dist <= sightRangeFor(st)
					and offset.Unit:Dot(m.root.CFrame.LookVector) >= cosHalf
					and clearLine(m.head.Position, root.Position, { m.model, char })
				then
					kind = "seen"
				elseif st.noise > 0 and dist <= CFG.HearRange * st.noise and (dist < 12 or clearLine(m.head.Position, root.Position, { m.model, char })) then
					kind = "heard"
				end

				if kind and dist < bestDist then
					bestPlayer, bestDist, bestKind, bestPos = player, dist, kind, root.Position
				end
			end
		end
	end

	if bestPlayer then
		PlayerState.markThreat(bestPlayer)
	end
	return bestPlayer, bestKind, bestPos
end

-- Déplacement vers un point ; interrompu si pause, ou si un joueur est perçu hors chasse
-- Le monstre pousse les portes fermées qu'il touche : un bruit de bois, et la porte cède
local function openNearbyDoor(m)
	if clock() < (m.nextDoorAt or 0) then
		return
	end
	for _, door in ipairs(CollectionService:GetTagged("Door")) do
		if door:IsA("BasePart") and door:GetAttribute("Open") == false and door:GetAttribute("Lock") == nil
			and (door.Position - m.root.Position).Magnitude < 3.5 then
			m.nextDoorAt = clock() + 2
			Props.setDoor(door, true)
			Noise.emit(door.Position, 0.6)
			Audio.play("porte", door, { lifetime = 4 })
			return
		end
	end
end

-- Pas audibles tant que le monstre se déplace
local function footstep(m)
	local v = m.root.AssemblyLinearVelocity
	local horizontal = Vector3.new(v.X, 0, v.Z).Magnitude
	if horizontal > 2 and clock() - m.lastStep >= CFG.StepInterval then
		m.lastStep = clock()
		Audio.play("pas", m.root, { lifetime = 2 })
	end
end

local function moveAndWait(m, goal, speed, timeout)
	local hum = m.hum
	hum.WalkSpeed = speed

	local finished, reached = false, false
	local conn = hum.MoveToFinished:Connect(function(ok)
		finished = true
		reached = ok
	end)
	hum:MoveTo(goal)

	local elapsed = 0
	while not finished and elapsed < timeout and isRunning(m) do
		if paused(m) then
			break
		end
		if m.state ~= "Chase" then
			local _, kind = perceive(m)
			if kind == "seen" then
				break
			end
		end
		task.wait(CFG.Tick)
		elapsed += CFG.Tick
		footstep(m)
	end

	conn:Disconnect()
	if not finished then
		hum:MoveTo(m.root.Position)
	end
	return reached
end

local function walkPath(m, goal, speed)
	local path = PathfindingService:CreatePath(PATH_PARAMS)
	local ok = pcall(function()
		path:ComputeAsync(m.root.Position, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return moveAndWait(m, goal, speed, CFG.DirectWalkTimeout)
	end

	for _, wp in ipairs(path:GetWaypoints()) do
		if not isRunning(m) or paused(m) then
			return false
		end
		if wp.Action == Enum.PathWaypointAction.Jump then
			m.hum.Jump = true
		end
		if not moveAndWait(m, wp.Position, speed, CFG.WaypointTimeout) then
			return false
		end
	end
	return true
end

local function setState(m, state)
	if m.state ~= state then
		m.state = state
		-- Lu par le client pour le battement de cœur pendant la poursuite
		Workspace:SetAttribute("MonsterChasing", state == "Chase")
	end
end

local function tryAttack(m, player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	if (root.Position - m.root.Position).Magnitude > CFG.AttackRange then
		return
	end
	if clock() - m.lastAttack < CFG.AttackCooldown then
		return
	end

	-- Surprise si le monstre n'a pas attaqué depuis un moment
	local surprise = clock() - m.lastAttack > CFG.SurpriseGap
	m.lastAttack = clock()
	Animations.attack(m.anims, surprise)
	-- Cri de capture espacé : au plus un toutes les ScreamCooldown secondes
	if clock() - m.lastScream >= CFG.ScreamCooldown then
		m.lastScream = clock()
		Audio.play("cri_capture", m.root, { lifetime = 6, range = 80 })
	end
	hum:TakeDamage(CFG.AttackDamage)
	PlayerState.addSanity(player, -CFG.SanityHit)
	Remotes.fire("Effect", player, { kind = "Hit" })
	m.pauseUntil = clock() + CFG.AttackRecover
end

local function stepChase(m)
	local target = m.target
	local char = target and target.Character
	local troot = char and char:FindFirstChild("HumanoidRootPart")
	local thum = char and char:FindFirstChildOfClass("Humanoid")
	local st = target and PlayerState.get(target)

	if not troot or not thum or thum.Health <= 0 or (st and st.hiding) then
		setState(m, "Search")
		m.searchPos = m.lastSeenPos
		m.searchUntil = clock() + CFG.SearchTime
		return
	end

	local dist = (troot.Position - m.root.Position).Magnitude
	if dist <= CFG.SightRange * 1.5 and clearLine(m.head.Position, troot.Position, { m.model, char }) then
		m.lastSeenTime = clock()
		m.lastSeenPos = troot.Position
		PlayerState.markThreat(target)
		m.hum.WalkSpeed = CFG.ChaseSpeed
		m.hum:MoveTo(troot.Position)
	else
		walkPath(m, troot.Position, CFG.ChaseSpeed)
	end

	if dist <= CFG.AttackRange then
		tryAttack(m, target)
	end

	if clock() - m.lastSeenTime > CFG.LoseTargetTime then
		setState(m, "Search")
		m.searchPos = m.lastSeenPos
		m.searchUntil = clock() + CFG.SearchTime
	end
end

-- Cachette proche que le monstre n'a pas encore inspectée, la plus utilisée par le joueur d'abord
local function findSpotToInspect(m)
	local best, bestWeight = nil, -1
	for _, spot in ipairs(CollectionService:GetTagged("Hiding")) do
		if spot:IsA("BasePart") and not m.inspected[spot] and (spot.Position - m.root.Position).Magnitude < 9 then
			local weight = Memory.spotWeight(spot.Name)
			if weight > bestWeight then
				best, bestWeight = spot, weight
			end
		end
	end
	return best
end

-- Inspection : le monstre s'arrête devant la cachette, la regarde, puis découvre le joueur s'il y est
local function inspectSpot(m, spot)
	m.inspected[spot] = true
	walkPath(m, spot.Position, CFG.WalkSpeed)
	m.pauseUntil = clock() + 1.5
	task.wait(1.5)
	if not isRunning(m) then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local st = PlayerState.get(player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if st and st.hiding == spot and root then
			PlayerState.unhide(player, true)
			m.target = player
			m.lastSeenTime = clock()
			m.lastSeenPos = root.Position
			setState(m, "Chase")
			return
		end
	end
end

-- Le monstre disparaît et réapparaît à un point de patrouille loin de tout joueur
local function relocate(m)
	local far = {}
	for _, point in ipairs(CollectionService:GetTagged("Waypoint")) do
		if point:IsA("BasePart") then
			local clear = true
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - point.Position).Magnitude < 60 then
					clear = false
				end
			end
			if clear then
				table.insert(far, point)
			end
		end
	end
	if #far == 0 then
		return
	end
	local target = far[math.random(1, #far)].Position + Vector3.new(0, 3, 0)
	if m.model and m.model:IsA("Model") then
		m.model:PivotTo(CFrame.new(target))
	else
		m.root.CFrame = CFrame.new(target)
	end
	m.root.AssemblyLinearVelocity = Vector3.zero
end

local function stepSearch(m)
	local spot = findSpotToInspect(m)
	if spot then
		inspectSpot(m, spot)
		return
	end
	if clock() >= m.searchUntil then
		-- Une fois sur deux, il disparaît et ressurgit ailleurs au lieu de simplement patrouiller
		if math.random() < 0.5 then
			relocate(m)
		end
		setState(m, "Patrol")
		return
	end
	local root = m.root
	if m.searchPos and (m.searchPos - root.Position).Magnitude > 4 then
		walkPath(m, m.searchPos, CFG.WalkSpeed)
	else
		-- Arrivé : tourne autour du dernier point connu
		local angle = math.random() * math.pi * 2
		local dist = math.random(4, 12)
		m.searchPos = root.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		task.wait(1)
	end
end

local function stepInvestigate(m)
	if clock() >= m.investigateUntil then
		setState(m, "Patrol")
		return
	end
	if (m.investigatePos - m.root.Position).Magnitude > 4 then
		walkPath(m, m.investigatePos, CFG.WalkSpeed)
	else
		task.wait(0.5)
	end
end

local function stepPatrol(m)
	walkPath(m, pickPatrolPoint(m.spawnOrigin), CFG.WalkSpeed)
	task.wait(CFG.PatrolPause)
end

-- Bruit ponctuel récent suffisamment proche (chute d'objet, etc.)
local function heardNoise(m)
	for _, event in ipairs(Noise.recent(CFG.NoiseMemory)) do
		if (event.pos - m.root.Position).Magnitude <= CFG.HearRange * event.strength then
			return event.pos
		end
	end
	return nil
end

-- Choisit l'animation de locomotion selon la vitesse réelle et l'état
local function updateLocomotion(m)
	if not m.anims then
		return
	end
	local v = m.root.AssemblyLinearVelocity
	local horizontal = Vector3.new(v.X, 0, v.Z).Magnitude
	local key
	if horizontal < 1 then
		key = "immobile"
	elseif m.state == "Chase" then
		key = "course"
	else
		key = "marche"
	end
	Animations.setLocomotion(m.anims, key)
end

local function run(m)
	while isRunning(m) and clock() < m.activeAt do
		task.wait(0.5)
	end

	while isRunning(m) do
		updateLocomotion(m)
		openNearbyDoor(m)
		Workspace:SetAttribute("MonsterAt", m.root.Position)
		if paused(m) then
			m.hum:MoveTo(m.root.Position)
		else
			local player, kind, pos = perceive(m)

			if player and kind == "seen" then
				if m.state ~= "Chase" then
					setState(m, "Chase")
					Audio.play("chaines", m.root, { lifetime = 8 })
				end
				m.target = player
				m.lastSeenTime = clock()
				m.lastSeenPos = pos
			elseif player and kind == "heard" and m.state ~= "Chase" then
				m.investigatePos = pos
				m.investigateUntil = clock() + CFG.InvestigateTime
				setState(m, "Investigate")
			end

			if m.state == "Patrol" or m.state == "Search" then
				local noisePos = heardNoise(m)
				if noisePos then
					m.investigatePos = noisePos
					m.investigateUntil = clock() + CFG.InvestigateTime
					setState(m, "Investigate")
				end
			end

			if m.state == "Chase" then
				stepChase(m)
			elseif m.state == "Search" then
				stepSearch(m)
			elseif m.state == "Investigate" then
				stepInvestigate(m)
			else
				stepPatrol(m)
			end
		end
		task.wait(CFG.Tick)
	end
end

-- Démarre le monstre (détruit l'instance précédente si elle existe)
function MonsterAI.start(activationDelay)
	MonsterAI.stop()

	local model = buildModel()
	local root = model.PrimaryPart
	local hum = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head") or root

	model:PivotTo(CFrame.new(spawnPoint()))
	model.Parent = Workspace
	pcall(function()
		root:SetNetworkOwner(nil) -- IA contrôlée par le serveur
	end)

	local now = clock()
	local m = {
		model = model,
		root = root,
		hum = hum,
		head = head,
		alive = true,
		runId = runId,
		state = "Patrol",
		pauseUntil = 0,
		lastAttack = -math.huge,
		lastStep = -math.huge,
		anims = Animations.load(hum),
		inspected = {},
		lastScream = -math.huge,
		lastSeenTime = now,
		lastSeenPos = root.Position,
		searchPos = nil,
		searchUntil = 0,
		investigatePos = root.Position,
		investigateUntil = 0,
		target = nil,
		activeAt = now + (activationDelay or 0),
		spawnOrigin = root.Position,
	}
	current = m
	task.spawn(run, m)
end

function MonsterAI.stop()
	runId += 1
	Workspace:SetAttribute("MonsterChasing", false)
	if current then
		current.alive = false
		if current.model then
			current.model:Destroy()
		end
	end
	current = nil
end

-- Séquence scénarisée : le monstre fixe le joueur deux secondes, puis court vers lui
function MonsterAI.forceChase(player)
	if not current or not current.alive then
		return
	end
	local m = current
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	m.target = player
	m.lastSeenTime = clock()
	m.lastSeenPos = root and root.Position or m.root.Position
	m.pauseUntil = clock() + 2
	setState(m, "Chase")
end

function MonsterAI.getRootPosition()
	if current and current.alive and current.root then
		return current.root.Position
	end
	return nil
end

return MonsterAI
