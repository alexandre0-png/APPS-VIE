--[[
	VehicleBuilder : construit les modèles de voitures (blocs Roblox) et leur physique "arcade".

	Physique : 1 LinearVelocity en mode Plan (vitesse avant + adhérence latérale nulle)
	           + 1 AngularVelocity (rotation de lacet), pilotés par le client du conducteur
	           (VehicleController) ou par le serveur pour les voitures de police (IA).
	Repère : l'avant du véhicule est -Z (LookVector), le conducteur est sur le siège gauche.
]]

local CollectionService = game:GetService("CollectionService")

local VehicleBuilder = {}

local DARK = Color3.fromRGB(30, 30, 34)
local GLASS = Color3.fromRGB(70, 110, 150)
local CHROME = Color3.fromRGB(190, 195, 205)

local function darker(c, f)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- Construit le modèle. opts.static = true : décor (ancré, sans siège ni physique).
function VehicleBuilder.build(spec, color, opts)
	opts = opts or {}
	local W, L = spec.w, spec.l
	local style = spec.style
	local convertible = (style == "sport" or style == "super")

	local model = Instance.new("Model")
	model.Name = spec.name

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(W, 1.6, L)
	chassis.CFrame = CFrame.new(0, 0, 0)
	chassis.Color = color
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 1, 1)
	chassis.Anchored = opts.static == true
	chassis.Parent = model
	model.PrimaryPart = chassis

	local function add(name, size, offset, col, mat, extra)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Color = col
		p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = opts.static == true
		if extra then
			for k, v in pairs(extra) do
				p[k] = v
			end
		end
		p.Parent = model
		if not opts.static then
			local w = Instance.new("WeldConstraint")
			w.Part0 = chassis
			w.Part1 = p
			w.Parent = p
		end
		return p
	end

	-- Géométrie de l'habitacle selon le style
	local cabinLen, cabinZ
	if style == "hatch" then
		cabinLen, cabinZ = 0.62 * L, 0.06 * L
	elseif style == "sedan" then
		cabinLen, cabinZ = 0.46 * L, 0.06 * L
	elseif style == "pickup" then
		cabinLen, cabinZ = 0.36 * L, -0.12 * L
	elseif style == "muscle" then
		cabinLen, cabinZ = 0.40 * L, 0.08 * L
	elseif style == "sport" then
		cabinLen, cabinZ = 0.30 * L, 0.02 * L
	else -- super
		cabinLen, cabinZ = 0.28 * L, 0.06 * L
	end
	local cabinH = spec.cabinH
	local topY = 0.8

	if convertible then
		-- Pare-brise + arceau, pas de toit
		add("Windshield", Vector3.new(W - 1.2, cabinH * 0.7, 0.3), Vector3.new(0, topY + cabinH * 0.35, cabinZ - cabinLen / 2), GLASS, Enum.Material.Glass, { Transparency = 0.4 })
		add("Dash", Vector3.new(W - 1.2, 0.8, 1.2), Vector3.new(0, topY + 0.4, cabinZ - cabinLen / 2 + 0.4), darker(color, 0.5))
		add("RollBar", Vector3.new(W - 2, 0.5, 0.6), Vector3.new(0, topY + cabinH * 0.9, cabinZ + cabinLen / 2), darker(color, 0.7))
	else
		add("Cabin", Vector3.new(W - 1.1, cabinH, cabinLen), Vector3.new(0, topY + cabinH / 2, cabinZ), GLASS, Enum.Material.Glass, { Transparency = 0.35 })
		add("Roof", Vector3.new(W - 0.9, 0.4, cabinLen + 0.3), Vector3.new(0, topY + cabinH + 0.2, cabinZ), color)
	end

	-- Pare-chocs, feux
	add("BumperF", Vector3.new(W + 0.2, 0.8, 0.7), Vector3.new(0, -0.35, -L / 2 - 0.2), DARK)
	add("BumperR", Vector3.new(W + 0.2, 0.8, 0.7), Vector3.new(0, -0.35, L / 2 + 0.2), DARK)
	local hx = W / 2 - 1.2
	for _, sx in ipairs({ -1, 1 }) do
		local hl = add("Headlight", Vector3.new(1.5, 0.8, 0.3), Vector3.new(sx * hx, 0.15, -L / 2 - 0.05), Color3.fromRGB(255, 244, 200), Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 70
		light.Angle = 70
		light.Brightness = 2.5
		light.Enabled = false
		light.Parent = hl
		CollectionService:AddTag(hl, "Headlight")
		add("Taillight", Vector3.new(1.5, 0.7, 0.3), Vector3.new(sx * hx, 0.2, L / 2 + 0.05), Color3.fromRGB(230, 30, 30), Enum.Material.Neon)
	end

	-- Détails par style
	if style == "pickup" then
		local bedZ = L * 0.27
		local bedLen = L * 0.42
		add("BedFloor", Vector3.new(W - 0.6, 0.4, bedLen), Vector3.new(0, 0.95, bedZ), darker(color, 0.6))
		add("BedL", Vector3.new(0.4, 1.4, bedLen), Vector3.new(-(W / 2 - 0.5), 1.5, bedZ), color)
		add("BedR", Vector3.new(0.4, 1.4, bedLen), Vector3.new(W / 2 - 0.5, 1.5, bedZ), color)
		add("BedBack", Vector3.new(W - 0.6, 1.4, 0.4), Vector3.new(0, 1.5, bedZ + bedLen / 2), color)
		add("BedFront", Vector3.new(W - 0.6, 1.4, 0.4), Vector3.new(0, 1.5, bedZ - bedLen / 2), color)
	elseif style == "muscle" then
		add("StripeHood", Vector3.new(1.6, 0.12, L * 0.34), Vector3.new(0, 0.86, -L * 0.28), Color3.fromRGB(245, 245, 245))
		add("StripeTrunk", Vector3.new(1.6, 0.12, L * 0.2), Vector3.new(0, 0.86, L * 0.4), Color3.fromRGB(245, 245, 245))
		add("HoodScoop", Vector3.new(2, 0.5, 2.4), Vector3.new(0, 1.05, -L * 0.25), DARK)
	elseif style == "sport" or style == "super" then
		local wz = L / 2 - 0.8
		add("WingPostL", Vector3.new(0.4, 1.6, 0.6), Vector3.new(-(W / 2 - 1.4), 1.6, wz), DARK)
		add("WingPostR", Vector3.new(0.4, 1.6, 0.6), Vector3.new(W / 2 - 1.4, 1.6, wz), DARK)
		add("Wing", Vector3.new(W + 0.2, 0.3, 2.2), Vector3.new(0, 2.5, wz), darker(color, 0.55))
		add("IntakeL", Vector3.new(0.3, 0.8, 2.4), Vector3.new(-(W / 2 + 0.05), 0.2, 0.5), DARK)
		add("IntakeR", Vector3.new(0.3, 0.8, 2.4), Vector3.new(W / 2 + 0.05, 0.2, 0.5), DARK)
		if style == "super" then
			add("Underglow", Vector3.new(W - 1.2, 0.2, L - 3), Vector3.new(0, -0.82, 0), Color3.fromRGB(120, 80, 255), Enum.Material.Neon)
		end
	elseif style == "hatch" or style == "sedan" then
		add("Grille", Vector3.new(W - 3, 0.6, 0.2), Vector3.new(0, -0.1, -L / 2 - 0.3), CHROME, Enum.Material.Metal)
	end

	if spec.taxi then
		local sign = add("TaxiSign", Vector3.new(2.6, 0.9, 1.2), Vector3.new(0, topY + cabinH + 0.85, cabinZ), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = sign
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = "TAXI"
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBlack
		tl.TextColor3 = Color3.new(0, 0, 0)
		tl.Parent = gui
	end

	if spec.police then
		local barY = topY + cabinH + 0.65
		local red = add("SirenRed", Vector3.new(1.8, 0.7, 1.2), Vector3.new(-1.1, barY, cabinZ), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		local blue = add("SirenBlue", Vector3.new(1.8, 0.7, 1.2), Vector3.new(1.1, barY, cabinZ), Color3.fromRGB(40, 80, 255), Enum.Material.Neon)
		CollectionService:AddTag(red, "SirenA")
		CollectionService:AddTag(blue, "SirenB")
		add("PoliceStripe", Vector3.new(W + 0.1, 0.9, L * 0.4), Vector3.new(0, 0.1, 0), Color3.fromRGB(25, 40, 90))
	end

	-- Roues (visuel) + colliders sphériques sans friction (physique)
	local wx = W / 2 - 0.1
	local wz = L / 2 - 2.8
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			add("Wheel", Vector3.new(1.3, 3, 3), Vector3.new(sx * wx, -0.6, sz * wz), Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
			add("Hub", Vector3.new(1.4, 1.5, 1.5), Vector3.new(sx * (wx + 0.05), -0.6, sz * wz), CHROME, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			if not opts.static then
				add("Collider", Vector3.new(3, 3, 3), Vector3.new(sx * (wx - 0.4), -0.6, sz * wz), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, {
					Shape = Enum.PartType.Ball,
					Transparency = 1,
					CanCollide = true,
					CustomPhysicalProperties = PhysicalProperties.new(0.3, 0, 0, 100, 100),
				})
			end
		end
	end

	if not opts.static then
		local seatZ = cabinZ
		local driver = Instance.new("VehicleSeat")
		driver.Name = "DriverSeat"
		driver.Size = Vector3.new(2, 1, 2)
		driver.CFrame = CFrame.new(-1.6, 0.35, seatZ)
		driver.Transparency = 1
		driver.Massless = true
		driver.TopSurface = Enum.SurfaceType.Smooth
		driver.BottomSurface = Enum.SurfaceType.Smooth
		driver.HeadsUpDisplay = false
		driver.MaxSpeed = 0
		driver.Torque = 0
		driver.Parent = model
		local w1 = Instance.new("WeldConstraint")
		w1.Part0 = chassis
		w1.Part1 = driver
		w1.Parent = driver
		driver:SetAttribute("CRVehicle", true)

		local pass = Instance.new("Seat")
		pass.Name = "PassengerSeat"
		pass.Size = Vector3.new(2, 1, 2)
		pass.CFrame = CFrame.new(1.6, 0.35, seatZ)
		pass.Transparency = 1
		pass.Massless = true
		pass.TopSurface = Enum.SurfaceType.Smooth
		pass.BottomSurface = Enum.SurfaceType.Smooth
		pass.Parent = model
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = chassis
		w2.Part1 = pass
		w2.Parent = pass

		-- Contraintes de conduite
		local mass = W * 1.6 * L * 1
		local att = Instance.new("Attachment")
		att.Name = "DriveAttachment"
		att.Parent = chassis

		local lv = Instance.new("LinearVelocity")
		lv.Name = "DriveVelocity"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		lv.PlaneVelocity = Vector2.new(0, 0)
		lv.MaxForce = mass * 250
		lv.Parent = chassis

		local av = Instance.new("AngularVelocity")
		av.Name = "TurnVelocity"
		av.Attachment0 = att
		av.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		av.AngularVelocity = Vector3.new(0, 0, 0)
		av.MaxTorque = mass * 900
		av.ReactionTorqueEnabled = false
		av.Parent = chassis

		model:SetAttribute("CRVehicle", true)
		model:SetAttribute("VehicleId", spec.id)
		model:SetAttribute("MaxSpeed", spec.maxSpeed)
		model:SetAttribute("Accel", spec.accel)
		model:SetAttribute("Turn", spec.turn)
		model:SetAttribute("Mass", mass)
		if spec.police then
			model:SetAttribute("Police", true)
		end
	end

	return model
end

-- Hauteur du centre du châssis au dessus du sol
VehicleBuilder.RideHeight = 2.2

return VehicleBuilder
