-- LocalScript : StarterPlayer/StarterPlayerScripts/Animations
-- Animations locales (aucun coût réseau). Chaque animation est activable dans Config.Animations et exécutée par Easing.guard :
-- sous pcall, et désactivée pour la session si elle lève une erreur. Les valeurs (courbes, phases, confettis) viennent du module
-- pur Easing, testé hors de Roblox. Aucune animation n'est nécessaire au gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Easing = require(Shared:WaitForChild("Easing"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local failed = {}
local function run(name, fn)
	return Easing.guard(Config.animEnabled, failed, name, fn, function(n, err)
		warn("[Animations] « " .. n .. " » désactivée pour cette session après une erreur : " .. tostring(err))
	end)
end

local state = nil
Remotes:WaitForChild("State").OnClientEvent:Connect(function(snap)
	state = snap
end)

---------------------------------------------------------------- Œufs : tremblement, blanchissement, rebond, squash & stretch
-- Les œufs à animer (pads, nids) portent le tag EggShake ; l'attribut Ends (heure d'éclosion) n'existe que sur les pads.
local eggData = setmetatable({}, { __mode = "k" })

local function eggInfo(egg)
	local d = eggData[egg]
	if not d then
		d = {
			base = egg.CFrame,
			color = egg.Color,
			mesh = egg:FindFirstChildOfClass("SpecialMesh"),
			phase = (egg.Position.X * 0.37 + egg.Position.Z * 0.51) % 3.2, -- désynchronise les rebonds
		}
		eggData[egg] = d
	end
	return d
end

RunService.RenderStepped:Connect(function()
	if not (Config.animEnabled("eggShake") or Config.animEnabled("eggBounce") or Config.animEnabled("hatchSquash")) then
		return
	end
	local eggs = CollectionService:GetTagged("EggShake")
	if #eggs == 0 then
		return
	end
	local now, t = os.time(), os.clock()
	for _, egg in ipairs(eggs) do
		local d = eggInfo(egg)
		d.y, d.rx, d.rz, d.sx, d.sy, d.whiten = 0, 0, 0, 1, 1, 0
		local ends = egg:GetAttribute("Ends")
		d.left = ends and (ends - now) or 99
	end
	run("eggShake", function() -- tremble les 4 dernières secondes, blanchit dans la dernière seconde et demie
		for _, egg in ipairs(eggs) do
			local d = eggData[egg]
			if d.left < 4 then
				local a = (4 - d.left) / 4
				d.rx = math.sin(t * 29) * 0.08 * a
				d.rz = math.sin(t * 35) * 0.12 * a
				d.whiten = d.left < 1.5 and (1.5 - d.left) / 1.5 * (0.5 + 0.5 * math.sin(t * 22)) or 0
			end
		end
	end)
	run("eggBounce", function() -- petit saut périodique tant que l'éclosion n'est pas imminente
		for _, egg in ipairs(eggs) do
			local d = eggData[egg]
			if d.left >= 4 then
				d.y, d.sx, d.sy = Easing.eggHop(t, d.phase, 0.6)
			end
		end
	end)
	run("hatchSquash", function() -- l'œuf pulse (écrasé puis étiré) dans les 2 dernières secondes : vrai squash & stretch non uniforme
		for _, egg in ipairs(eggs) do
			local d = eggData[egg]
			if d.left < 2 then
				local sx, sy = Easing.squashStretch((t * 1.6) % 1, 0.18 + 0.2 * (2 - d.left) / 2)
				d.sx, d.sy = d.sx * sx, d.sy * sy
			end
		end
	end)
	pcall(function()
		for _, egg in ipairs(eggs) do
			local d = eggData[egg]
			egg.CFrame = d.base * CFrame.new(0, d.y, 0) * CFrame.Angles(d.rx, 0, d.rz)
			if d.mesh then
				d.mesh.Scale = Vector3.new(d.sx, d.sy, d.sx)
			end
			egg.Color = d.color:Lerp(Color3.new(1, 1, 1), d.whiten)
		end
	end)
end)

-- Œufs portés : ils rebondissent pendant la course (modification locale de la soudure).
local carryBase = setmetatable({}, { __mode = "k" })
RunService.RenderStepped:Connect(function()
	run("eggBounce", function()
		local t = os.clock()
		for _, egg in ipairs(CollectionService:GetTagged("CarryEgg")) do
			local weld = egg:FindFirstChildOfClass("Weld")
			if weld then
				local base = carryBase[egg]
				if not base then
					base = weld.C0
					carryBase[egg] = base
				end
				local hum = egg.Parent and egg.Parent:FindFirstChildOfClass("Humanoid")
				local moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1
				weld.C0 = base * CFrame.new(0, Easing.runBounce(t + base.Y * 0.4, moving), 0)
			end
		end
	end)
end)

---------------------------------------------------------------- Pets : apparition (squash & stretch), onde de choc
-- Approximation : les modèles de pets sont faits de plusieurs Parts, on ne peut donc les mettre à l'échelle que de façon uniforme.
-- Le squash & stretch du pet est rendu par une échelle uniforme qui suit la courbe verticale ; celui de l'œuf (avant éclosion) est réel.
CollectionService:GetInstanceAddedSignal("PopIn"):Connect(function(model)
	local born = model:GetAttribute("Born")
	if not born or workspace:GetServerTimeNow() - born > 2 then
		return
	end
	local squash = Config.animEnabled("hatchSquash")
	if not (squash or Config.animEnabled("popIn")) then
		return
	end
	task.spawn(function()
		run(squash and "hatchSquash" or "popIn", function()
			local t0 = os.clock()
			while model.Parent do
				local a = math.min(1, (os.clock() - t0) / 0.7)
				local scale
				if squash then
					local _, sy = Easing.squashStretch(a, 0.45)
					scale = (0.25 + 0.75 * Easing.outQuad(math.min(1, a * 1.8))) * sy
				else
					scale = 0.25 + 0.75 * Easing.outBack(a)
				end
				model:ScaleTo(math.max(0.05, scale))
				if a >= 1 then
					model:ScaleTo(1)
					break
				end
				RunService.RenderStepped:Wait()
			end
		end)
	end)
end)

CollectionService:GetInstanceAddedSignal("Shockwave"):Connect(function(ring)
	run("shockwave", function()
		local big = ring:GetAttribute("Big")
		local d = big and 40 or 22
		TweenService:Create(ring, TweenInfo.new(big and 0.7 or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, d, d), Transparency = 1 }):Play()
	end)
end)

---------------------------------------------------------------- Récolte : l'œuf s'envole en arc vers le joueur
CollectionService:GetInstanceAddedSignal("FlyEgg"):Connect(function(egg)
	local target = Players:GetPlayerByUserId(egg:GetAttribute("Target") or 0)
	local start = egg:GetAttribute("Start")
	if not (target and start) then
		return
	end
	local baseSize = egg.Size
	task.spawn(function()
		run("harvest", function()
			local t0 = os.clock()
			while egg.Parent do
				local a = math.min(1, (os.clock() - t0) / 0.4)
				local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if not root then
					break
				end
				local e = a * a * (3 - 2 * a)
				local pos = start:Lerp(root.Position + Vector3.new(0, 4, 0), e) + Vector3.new(0, math.sin(a * math.pi) * 4, 0)
				egg.CFrame = CFrame.new(pos)
				egg.Size = baseSize * (1 - 0.6 * a)
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if egg.Parent then
				egg.Transparency = 1
			end
		end)
	end)
end)

---------------------------------------------------------------- Visage des pets : clignement, regard, bouche
-- Paupières (LidL/LidR) et bouche (Mouth) sont des Parts du modèle ; les yeux se déplacent légèrement. Seuls les pets proches de la
-- caméra sont animés, au plus MAX_FACES par image (tourniquet), pour rester léger avec beaucoup de joueurs.
local MAX_FACES = 24
local FACE_RANGE = 70
local faceCache = setmetatable({}, { __mode = "k" })
local faceCursor = 0

local function facePart(body, model, name)
	local p = model:FindFirstChild(name)
	if p then
		return { part = p, rel = body.CFrame:ToObjectSpace(p.CFrame) }
	end
	return nil
end

local function faceOf(model)
	local c = faceCache[model]
	if c then
		return c
	end
	local body = model.PrimaryPart
	if not body then
		return nil
	end
	c = {
		body = body,
		R = body.Size.X / 2,
		seed = model:GetAttribute("Seed") or 0,
		eyeL = facePart(body, model, "EyeL"), eyeR = facePart(body, model, "EyeR"),
		shineL = facePart(body, model, "ShineL"), shineR = facePart(body, model, "ShineR"),
		lidL = facePart(body, model, "LidL"), lidR = facePart(body, model, "LidR"),
		mouth = facePart(body, model, "Mouth"),
		lidShown = false, lastMouth = 0,
	}
	if c.mouth then
		c.mouthSize = c.mouth.part.Size
	end
	faceCache[model] = c
	return c
end

RunService.RenderStepped:Connect(function()
	if not (Config.animEnabled("petBlink") or Config.animEnabled("petLook") or Config.animEnabled("petMouth")) then
		return
	end
	local cam = workspace.CurrentCamera
	local models = CollectionService:GetTagged("PetFace")
	if not cam or #models == 0 then
		return
	end
	local camPos, nowServer, t = cam.CFrame.Position, workspace:GetServerTimeNow(), os.clock()
	local near = {}
	for _, m in ipairs(models) do
		local body = m.PrimaryPart
		if body and (body.Position - camPos).Magnitude < FACE_RANGE then
			local born = m:GetAttribute("Born")
			if not born or nowServer - born > 1.2 then -- pas pendant l'apparition (le modèle change d'échelle)
				near[#near + 1] = m
			end
		end
	end
	local list = near
	if #near > MAX_FACES then
		list = {}
		for k = 0, MAX_FACES - 1 do
			list[#list + 1] = near[(faceCursor + k) % #near + 1]
		end
		faceCursor = (faceCursor + MAX_FACES) % #near
	end
	run("petBlink", function()
		for _, m in ipairs(list) do
			local c = faceOf(m)
			if c and c.lidL and c.lidR then
				local closed = Easing.blinkOpenness(t, c.seed) < 0.45
				if closed ~= c.lidShown then
					c.lidShown = closed
					c.lidL.part.Transparency = closed and 0 or 1
					c.lidR.part.Transparency = closed and 0 or 1
				end
			end
		end
	end)
	run("petLook", function()
		for _, m in ipairs(list) do
			local c = faceOf(m)
			if c then
				local dx, dy = Easing.look(t, c.seed)
				local off = CFrame.new(dx * 0.06 * c.R, dy * 0.05 * c.R, 0)
				local base = c.body.CFrame
				for _, key in ipairs({ "eyeL", "eyeR", "shineL", "shineR" }) do
					local e = c[key]
					if e then
						e.part.CFrame = base * e.rel * off
					end
				end
			end
		end
	end)
	run("petMouth", function()
		for _, m in ipairs(list) do
			local c = faceOf(m)
			if c and c.mouth then
				local open = Easing.mouthOpen(t, c.seed)
				if open ~= c.lastMouth then
					c.lastMouth = open
					local sz = c.mouthSize
					c.mouth.part.Size = Vector3.new(sz.X, sz.Y * (1 + open * 2.5), sz.Z)
					c.mouth.part.CFrame = c.body.CFrame * c.mouth.rel * CFrame.new(0, -open * 0.04 * c.R, 0)
				end
			end
		end
	end)
end)

---------------------------------------------------------------- Barrières de zone (portails) : pulsation et dissolution à l'ouverture
local gateState = setmetatable({}, { __mode = "k" })

local function setGateOpen(gate)
	gate.CanCollide = false
	gate.Transparency = 1
	local lbl = gate:FindFirstChild("Label")
	if lbl then
		lbl.Enabled = false
	end
	gateState[gate] = "open"
end

local function openGateAnimated(gate)
	gateState[gate] = "opening"
	gate.CanCollide = false -- on peut passer pendant que la barrière se dissout
	local started = run("zones", function()
		local lbl = gate:FindFirstChild("Label")
		if lbl then
			lbl.Enabled = false
		end
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 120, 140), Color3.fromRGB(255, 255, 255))
		sparks.Rate = 0
		sparks.Lifetime = NumberRange.new(0.8, 1.6)
		sparks.Speed = NumberRange.new(10, 26)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
		sparks.Parent = gate
		sparks:Emit(90)
		Debris:AddItem(sparks, 2.5)
		local tween = TweenService:Create(gate, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = gate.Size * 1.12 })
		tween.Completed:Connect(function()
			pcall(setGateOpen, gate)
		end)
		tween:Play()
	end)
	if not started then
		setGateOpen(gate) -- animation désactivée ou en erreur : ouverture immédiate
	end
end

RunService.RenderStepped:Connect(function()
	if not state then
		return
	end
	local gates = CollectionService:GetTagged("ZoneGate")
	if #gates == 0 then
		return
	end
	local t = os.clock()
	for _, gate in ipairs(gates) do
		local rival = gate:GetAttribute("Rival") or 0
		local gs = gateState[gate]
		if Config.zoneUnlocked(state.story.ch, rival) then
			if gs == nil or not Config.animEnabled("zones") then
				if gs ~= "open" then
					setGateOpen(gate) -- déjà ouverte à l'arrivée (ou animations coupées) : pas de mise en scène
				end
			elseif gs == "closed" then
				openGateAnimated(gate)
			end
		else
			if gs ~= "closed" then
				gate.CanCollide = true
				local lbl = gate:FindFirstChild("Label")
				if lbl then
					lbl.Enabled = true
				end
				gateState[gate] = "closed"
			end
			if not run("zones", function()
				gate.Transparency = 0.5 + 0.2 * Easing.gatePulse(t + rival, 2.2)
			end) then
				gate.Transparency = 0.6
			end
		end
	end
end)

---------------------------------------------------------------- Récompenses : confettis stylisés ; prise d'œuf / capture : secousse du champ de vision
local fx = Instance.new("ScreenGui")
fx.Name = "ChipeFX"
fx.ResetOnSpawn = false
fx.IgnoreGuiInset = true
fx.DisplayOrder = 50
fx.Parent = player:WaitForChild("PlayerGui")

local function uiConfetti(burst)
	for i = 1, burst.count do
		local p = Easing.confettiParticle(i, burst.count, burst)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(p.w, p.h)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.4)
		f.BackgroundColor3 = Color3.fromHSV(p.hue, 0.75, 1)
		f.BorderSizePixel = 0
		f.Rotation = (i * 37) % 360
		f.Parent = fx
		local dx = math.cos(p.angle) * p.speed * burst.life * 0.5
		local dy = math.sin(p.angle) * p.speed * burst.life * 0.5 + 520 * burst.life * burst.life * 0.5 -- + gravité
		TweenService:Create(f, TweenInfo.new(burst.life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, dx, 0.4, dy),
			Rotation = f.Rotation + p.spin * burst.life,
			BackgroundTransparency = 1,
		}):Play()
		Debris:AddItem(f, burst.life + 0.1)
	end
end

local kicking = false
local function fovKick(kind)
	local k = Easing.FOV_KICK[kind]
	local cam = workspace.CurrentCamera
	if not k or not cam or kicking then
		return
	end
	kicking = true
	TweenService:Create(cam, TweenInfo.new(k.time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { FieldOfView = cam.FieldOfView + k.delta }):Play()
	task.delay(k.time * 2 + 0.05, function()
		kicking = false
	end)
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(_msg, sfx)
	local burst = Easing.rewardBurst(sfx)
	if burst then
		run("reward", function()
			uiConfetti(burst)
		end)
	end
	if sfx == "steal" or sfx == "caught" then
		run("characterPop", function()
			fovKick(sfx)
		end)
	end
end)

Remotes:WaitForChild("Hatch").OnClientEvent:Connect(function(info)
	local def = Config.PETS[info.p]
	if def and (def.tier >= 4 or info.m > 1 or info.s >= 4) then
		run("reward", function()
			uiConfetti(Easing.REWARD.rare)
		end)
	end
end)
