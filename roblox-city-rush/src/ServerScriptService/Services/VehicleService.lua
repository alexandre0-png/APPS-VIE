--[[
	VehicleService : apparition / suppression des véhicules, voitures publiques garées dans la rue,
	verrouillage du siège conducteur, détection des collisions avec piétons et mobilier,
	distance parcourue.
	La conduite des voitures de joueurs est simulée par le client du conducteur (VehicleController).
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local VehicleBuilder = require(script.Parent.VehicleBuilder)
local RemoteService = require(script.Parent.RemoteService)
local EconomyService = require(script.Parent.EconomyService)
local DataService = require(script.Parent.DataService)

local VehicleService = {}

local World
local Pedestrians -- injecté (peut être nil)
local Wanted -- injecté (peut être nil)

local vehiclesFolder
local playerVehicle = {} -- [player] = model
local lastSpawn = {} -- [player] = os.clock()
local publicCars = {} -- liste de {model, home, emptySince}
local rng = Random.new()
local hitParams = OverlapParams.new()
hitParams.FilterType = Enum.RaycastFilterType.Include

function VehicleService.setDependencies(world, pedestrians, wanted)
	World = world
	Pedestrians = pedestrians
	Wanted = wanted
	hitParams.FilterDescendantsInstances = { world.BreakFolder, pedestrians and pedestrians.Folder or world.BreakFolder }
end

local function groundHeight(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local r = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return r and r.Position.Y or nil
end

local function applyColor(model, color)
	local chassis = model.PrimaryPart
	chassis.Color = color
	for _, name in ipairs({ "Roof", "BedL", "BedR", "BedBack", "BedFront" }) do
		local p = model:FindFirstChild(name)
		if p then
			p.Color = color
		end
	end
end

-- Crée un véhicule (non parenté au monde tant que l'appelant ne le décide pas)
local function create(spec, color, cf)
	local model = VehicleBuilder.build(spec, color)
	model:PivotTo(cf)
	model.Parent = vehiclesFolder
	return model
end

local function driverSeat(model)
	return model:FindFirstChild("DriverSeat")
end

function VehicleService.getDriver(model)
	local seat = driverSeat(model)
	if seat and seat.Occupant then
		return Players:GetPlayerFromCharacter(seat.Occupant.Parent)
	end
	return nil
end

-- Véhicule dans lequel se trouve le joueur (conducteur ou passager)
function VehicleService.getOccupiedVehicle(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat.Parent and seat.Parent:GetAttribute("CRVehicle") then
		return seat.Parent
	end
	return nil
end

local function hookSeats(model)
	local seat = driverSeat(model)
	if not seat then
		return
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = seat.Occupant
		if not occ then
			return
		end
		local player = Players:GetPlayerFromCharacter(occ.Parent)
		if not player then
			return
		end
		local ownerId = model:GetAttribute("OwnerUserId")
		if ownerId and ownerId ~= player.UserId then
			-- voiture personnelle verrouillée pour le conducteur
			task.defer(function()
				occ.Sit = false
				occ.Jump = true
			end)
			RemoteService.notify(player, "Cette voiture est verrouillée (propriétaire uniquement).", "bad")
			return
		end
		if model:GetAttribute("Police") then
			return
		end
		-- vol d'une voiture publique près de la police => chaleur
		if not ownerId and Wanted and Wanted.copNear then
			if Wanted.copNear(player, 70) then
				Wanted.addHeat(player, 15, "Vol de voiture")
			end
		end
		model:SetAttribute("LastDriver", player.UserId)
	end)
end

-- ====================================================================
-- Voitures de joueurs
-- ====================================================================
function VehicleService.despawnFor(player)
	local m = playerVehicle[player]
	if m then
		m:Destroy()
		playerVehicle[player] = nil
	end
end

function VehicleService.spawnFor(player, vehicleId)
	local profile = DataService.get(player)
	local spec = Config.getVehicle(vehicleId)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not profile or not spec or not hrp or not hum or hum.Health <= 0 then
		return
	end
	if not EconomyService.canUseVehicle(player, vehicleId) then
		RemoteService.notify(player, "Tu ne possèdes pas ce véhicule.", "bad")
		return
	end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < Config.VehicleSpawnCooldown then
		RemoteService.notify(player, "Patiente un instant avant de rappeler un véhicule.", "info")
		return
	end
	lastSpawn[player] = now

	VehicleService.despawnFor(player)

	local look = hrp.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.1 then
		flatLook = Vector3.new(0, 0, -1)
	end
	flatLook = flatLook.Unit
	local pos = hrp.Position + flatLook * (spec.l / 2 + 6)
	local gy = groundHeight(pos, { char, vehiclesFolder }) or (hrp.Position.Y - 3)
	local colorIndex = profile.Colors[vehicleId]
	local color = colorIndex and Config.VehicleColors[colorIndex] or spec.color
	local cf = CFrame.lookAt(Vector3.new(pos.X, gy + VehicleBuilder.RideHeight + 0.3, pos.Z), Vector3.new(pos.X, gy + VehicleBuilder.RideHeight + 0.3, pos.Z) + flatLook)
	local model = create(spec, color, cf)
	model:SetAttribute("OwnerUserId", player.UserId)
	playerVehicle[player] = model
	hookSeats(model)
	local seat = driverSeat(model)
	task.defer(function()
		if seat and seat.Parent and hum.Parent and hum.Health > 0 then
			seat:Sit(hum)
		end
	end)
end

-- ====================================================================
-- Voitures publiques (garées)
-- ====================================================================
local function spawnPublicAt(entry)
	local pick = Util.weightedPick(Config.PublicCars, rng)
	local spec = Config.getVehicle(pick.id)
	local color = Config.VehicleColors[rng:NextInteger(1, #Config.VehicleColors)]
	local gy = entry.home.Position.Y
	local cf = entry.home + Vector3.new(0, VehicleBuilder.RideHeight + 0.2 - 0.3 + (gy - entry.home.Position.Y), 0)
	local model = create(spec, color, cf)
	model:SetAttribute("Public", true)
	hookSeats(model)
	entry.model = model
	entry.emptySince = nil
end

local function playersNear(pos, radius)
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude < radius then
			return true
		end
	end
	return false
end

local function publicLoop()
	while true do
		task.wait(5)
		for _, e in ipairs(publicCars) do
			local m = e.model
			if not m or not m.Parent then
				spawnPublicAt(e)
			else
				local chassis = m.PrimaryPart
				local occupied = false
				for _, s in ipairs({ m:FindFirstChild("DriverSeat"), m:FindFirstChild("PassengerSeat") }) do
					if s and s.Occupant then
						occupied = true
					end
				end
				if occupied then
					e.emptySince = nil
				else
					e.emptySince = e.emptySince or os.clock()
					if chassis and os.clock() - e.emptySince > 90 and (chassis.Position - e.home.Position).Magnitude > 8 and not playersNear(chassis.Position, 80) then
						m:Destroy()
						spawnPublicAt(e)
					end
				end
				if chassis and chassis.Position.Y < -8 then
					m:Destroy()
					spawnPublicAt(e)
				end
			end
		end
	end
end

-- ====================================================================
-- Voitures de police (IA pilotée par WantedService)
-- ====================================================================
function VehicleService.spawnCruiser(cf)
	local model = create(Config.Police, Config.Police.color, cf)
	model:SetAttribute("Police", true)
	for _, seatName in ipairs({ "DriverSeat", "PassengerSeat" }) do
		local seat = model:FindFirstChild(seatName)
		if seat then
			seat.Disabled = true -- les voitures de police ne sont pas volables
		end
	end
	model.PrimaryPart:SetNetworkOwner(nil)
	return model
end

-- ====================================================================
-- Collisions & statistiques (boucle 10 Hz sur les véhicules conduits par un joueur)
-- ====================================================================
local lastPos = {} -- [player] = Vector3
local distAcc = {} -- [player] = studs cumulés

local function hitLoop()
	local acc = 0
	while true do
		task.wait(0.1)
		acc += 0.1
		for _, player in ipairs(Players:GetPlayers()) do
			local model = VehicleService.getOccupiedVehicle(player)
			local seat = model and driverSeat(model)
			if model and seat and seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent) == player and not model:GetAttribute("Police") then
				local chassis = model.PrimaryPart
				local speed = chassis.AssemblyLinearVelocity.Magnitude
				-- distance (plafonnée pour ignorer les téléportations)
				local lp = lastPos[player]
				if lp then
					local d = (chassis.Position - lp).Magnitude
					if d < 40 then
						distAcc[player] = (distAcc[player] or 0) + d
					end
				end
				lastPos[player] = chassis.Position
				if acc >= 1 and (distAcc[player] or 0) > 0 then
					EconomyService.addDistance(player, distAcc[player])
					distAcc[player] = 0
				end
				if speed > 22 then
					local size = chassis.Size
					local cf = chassis.CFrame * CFrame.new(0, 1, -size.Z / 2 - 1)
					local parts = workspace:GetPartBoundsInBox(cf, Vector3.new(size.X + 2, 4, 5), hitParams)
					for _, part in ipairs(parts) do
						if part.Parent == World.BreakFolder then
							if World.breakProp(part) and Wanted then
								Wanted.addHeat(player, Config.Wanted.SmashPropHeat, "Vandalisme")
							end
						elseif Pedestrians then
							local ped = Pedestrians.fromPart(part)
							if ped and Pedestrians.knockdown(ped, chassis.AssemblyLinearVelocity) and Wanted then
								Wanted.addHeat(player, Config.Wanted.HitPedestrianHeat, "Piéton renversé")
								EconomyService.addStat(player, "hits", 1)
							end
						end
					end
				end
			else
				lastPos[player] = nil
			end
		end
		if acc >= 1 then
			acc = 0
		end
	end
end

local function fallLoop()
	while true do
		task.wait(2)
		for player, m in pairs(playerVehicle) do
			if m.Parent and m.PrimaryPart and m.PrimaryPart.Position.Y < -8 then
				m:Destroy()
				playerVehicle[player] = nil
				RemoteService.notify(player, "Ton véhicule a coulé ! Rappelle-le depuis ton garage (G).", "bad")
			elseif not m.Parent then
				playerVehicle[player] = nil
			end
		end
	end
end

function VehicleService.init()
	vehiclesFolder = Instance.new("Folder")
	vehiclesFolder.Name = "Vehicles"
	vehiclesFolder.Parent = workspace

	RemoteService.on("RequestSpawn", 0.5, function(id)
		return type(id) == "string" and #id < 24
	end, function(player, id)
		VehicleService.spawnFor(player, id)
	end)

	Players.PlayerRemoving:Connect(function(player)
		VehicleService.despawnFor(player)
		lastSpawn[player] = nil
		lastPos[player] = nil
		distAcc[player] = nil
	end)
end

function VehicleService.start()
	for _, cf in ipairs(World.ParkingSpots) do
		local entry = { home = cf }
		table.insert(publicCars, entry)
		spawnPublicAt(entry)
	end
	task.spawn(publicLoop)
	task.spawn(hitLoop)
	task.spawn(fallLoop)
end

return VehicleService
