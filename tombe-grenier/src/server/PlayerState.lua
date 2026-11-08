--[[
  PlayerState : état serveur par joueur.
  Endurance, sanité, bruit, cachette, lampe torche.
  Le client ne lit que les attributs Sanity / Stamina / Battery (lecture seule).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Audio = require(Shared.Audio)
local MapBuilder = require(script.Parent.MapBuilder)
local Memory = require(script.Parent.Memory)

local CFG = Config.Player
local FL = Config.Flashlight

local PlayerState = {}
local states = {}

local function newState()
	return {
		quiet = false,
		sprint = false,
		stamina = CFG.MaxStamina,
		sanity = CFG.SanityMax,
		noise = 0,
		hiding = nil,            -- BasePart de la cachette occupée
		savedCFrame = nil,       -- position avant la cachette
		flashlightOn = false,
		battery = FL.Battery,
		threatTime = -math.huge, -- dernier instant où le monstre a perçu ce joueur
		roomDark = false,
		room = nil,              -- pièce où se trouve le joueur
		log = {},                -- ce que le joueur a fait (pour le journal)        -- le joueur est dans une pièce plongée dans le noir
		throws = Config.Throw.Charges,
		frozenUntil = 0,         -- réveil scénarisé : pas de déplacement avant cet instant
		lastThrow = -math.huge,
	}
end

-- Garde les dernières actions du joueur (le journal intime les relit)
local function pushLog(st, text)
	table.insert(st.log, text)
	if #st.log > 12 then
		table.remove(st.log, 1)
	end
end

-- Retourne character, humanoid, root si le joueur est vivant et prêt
local function living(player)
	local char = player.Character
	if not char then
		return nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	return char, hum, root
end

function PlayerState.get(player)
	return states[player]
end

function PlayerState.addSanity(player, delta)
	local st = states[player]
	if st then
		st.sanity = math.clamp(st.sanity + delta, 0, CFG.SanityMax)
	end
end

function PlayerState.markThreat(player)
	local st = states[player]
	if st then
		st.threatTime = os.clock()
	end
end

function PlayerState.setQuiet(player, on)
	local st = states[player]
	if st then
		st.quiet = on
	end
end

function PlayerState.setSprint(player, on)
	local st = states[player]
	if st then
		st.sprint = on
	end
end

function PlayerState.hide(player, spot)
	local st = states[player]
	if not st or st.hiding then
		return false
	end
	local _, _, root = living(player)
	if not root then
		return false
	end
	st.hiding = spot
	st.savedCFrame = root.CFrame
	Memory.spotUsed(spot.name)
	pushLog(st, "Tu t'es caché : " .. tostring(spot:GetAttribute("Kind") or "cachette") .. ".")
	root.CFrame = spot.CFrame
	root.Anchored = true
	player:SetAttribute("Hidden", true)
	Audio.play("cachette", spot, { lifetime = 4 })
	return true
end

function PlayerState.unhide(player, scared)
	local st = states[player]
	if not st or not st.hiding then
		return
	end
	local spot = st.hiding
	st.hiding = nil
	player:SetAttribute("Hidden", false)
	Audio.play("cachette", spot, { lifetime = 4 })
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
		if st.savedCFrame then
			root.CFrame = st.savedCFrame
		end
	end
	if scared then
		st.sanity = math.clamp(st.sanity - CFG.SanityScare, 0, CFG.SanityMax)
		Audio.play("porte", player.Character and player.Character:FindFirstChild("HumanoidRootPart") or workspace, { lifetime = 4 })
		Remotes.fire("Effect", player, { kind = "Scare" })
	end
end

-- Lancer : fait du bruit au point d'impact. Retourne le point d'impact, ou nil si refusé.
function PlayerState.tryThrow(player, direction)
	local st = states[player]
	if not st or st.throws <= 0 or os.clock() - st.lastThrow < Config.Throw.Cooldown then
		return nil
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head or typeof(direction) ~= "Vector3" or math.abs(direction.Magnitude - 1) > 0.05 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(head.Position, direction * Config.Throw.Range, params)
	local impact = hit and hit.Position or (head.Position + direction * Config.Throw.Range)
	st.throws -= 1
	st.lastThrow = os.clock()
	return impact
end

-- Fige tous les joueurs pendant duration secondes (réveil dans le cercueil)
function PlayerState.freezeAll(duration)
	for _, st in pairs(states) do
		st.frozenUntil = os.clock() + duration
	end
end

-- Ajoute des jets de bruit (objet trouvé), plafonné
function PlayerState.addThrows(player, amount)
	local st = states[player]
	if st then
		st.throws = math.min(Config.Throw.Charges + 2, st.throws + amount)
	end
end

-- Recharge la lampe (pile ramassée), sans dépasser le maximum
function PlayerState.addBattery(player, amount)
	local st = states[player]
	if st then
		st.battery = math.min(Config.Flashlight.Battery, st.battery + amount)
	end
end

function PlayerState.setFlashlight(player, on)
	local st = states[player]
	if not st then
		return
	end
	if on and st.battery <= 0 then
		on = false
	end
	st.flashlightOn = on

	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local beam = head:FindFirstChild("FlashlightBeam")
	if on and not beam then
		beam = Instance.new("SpotLight")
		beam.Name = "FlashlightBeam"
		beam.Brightness = FL.Brightness
		beam.Range = FL.Range
		beam.Angle = FL.Angle
		beam.Face = Enum.NormalId.Front
		beam.Parent = head
	end
	if beam then
		beam.Enabled = on
	end
end

local function update(dt)
	for player, st in pairs(states) do
		local char, hum, root = living(player)
		if char then
			-- Mouvement réel (vitesse serveur), pas l'input client
			local v = root.AssemblyLinearVelocity
			local moving = Vector3.new(v.X, 0, v.Z).Magnitude > CFG.MovingThreshold and not st.hiding
			local sprinting = st.sprint and moving and not st.quiet and st.stamina > 0

			-- Endurance
			if sprinting then
				st.stamina = math.max(0, st.stamina - CFG.StaminaDrain * dt)
			else
				st.stamina = math.min(CFG.MaxStamina, st.stamina + CFG.StaminaRegen * dt)
			end

			-- Vitesse de marche
			local speed = CFG.WalkSpeed
			if st.hiding then
				speed = 0
			elseif st.quiet then
				speed = CFG.QuietSpeed
			elseif sprinting then
				speed = CFG.SprintSpeed
			end
			if st.sanity <= CFG.SanityLow and not st.hiding then
				speed *= CFG.LowSanitySpeedFactor
			end
			if os.clock() < st.frozenUntil then
				speed = 0
			end
			hum.WalkSpeed = speed

			-- Bruit émis (lu par le monstre)
			local noise = 0
			if moving then
				noise = sprinting and CFG.NoiseSprint or CFG.NoiseWalk
				if st.quiet then
					noise *= CFG.NoiseQuietFactor
				end
			end
			st.noise = noise

			-- Pièce plongée dans le noir sans lampe allumée : la sanité baisse lentement
			local room = MapBuilder.roomAt(root.Position)
			st.roomDark = MapBuilder.isDark(room)

			-- Changement de pièce : la pièce quittée peut s'éteindre derrière le joueur
			if room and room ~= st.room then
				local left = st.room
				st.room = room
				Memory.visit(room)
				pushLog(st, "Tu es entré dans " .. MapBuilder.roomName(room) .. ".")
				if left and math.random() < 0.3 then
					MapBuilder.lampOff(left, 15)
				end
			end
			if st.roomDark and not st.flashlightOn then
				st.sanity -= CFG.SanityLossDark * dt
			end

			-- Sanité
			if os.clock() - st.threatTime < 0.5 then
				st.sanity -= CFG.SanityLossThreat * dt
			elseif st.hiding then
				st.sanity += CFG.SanityRegenHidden * dt
			else
				st.sanity += CFG.SanityRegenSafe * dt
			end
			st.sanity = math.clamp(st.sanity, 0, CFG.SanityMax)

			-- Lampe torche
			if st.flashlightOn then
				st.battery = math.max(0, st.battery - FL.DrainPerSecond * dt)
				if st.battery <= 0 then
					PlayerState.setFlashlight(player, false)
				end
			end

			player:SetAttribute("Sanity", math.floor(st.sanity))
			player:SetAttribute("Stamina", math.floor(st.stamina))
			player:SetAttribute("Battery", math.floor(st.battery))
		end
	end
end

local function onCharacter(player, char)
	local st = newState()
	states[player] = st
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	hum.WalkSpeed = CFG.WalkSpeed
	player:SetAttribute("Sanity", st.sanity)
	player:SetAttribute("Stamina", st.stamina)
	player:SetAttribute("Battery", st.battery)
end

function PlayerState.init()
	local function bind(player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			onCharacter(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(bind)
	for _, player in ipairs(Players:GetPlayers()) do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(CFG.Tick)
			local now = os.clock()
			update(now - last)
			last = now
		end
	end)
end

return PlayerState
