-- World.luau : animations locales (dinos qui se promènent, visiteurs, ouvriers, œufs), effets et rayon-guide.
-- Tout est cosmétique et exécuté uniquement chez le joueur : aucun coût serveur.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local HumanFactory = require(Shared.HumanFactory)

local Ui = require(script.Parent.Ui)
local Store = require(script.Parent.StateStore)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local Reveal = require(script.Parent.Reveal)

local World = {}
local player = Players.LocalPlayer
local rng = Random.new()

local plotModel, plotCF = nil, nil
local dinoState = setmetatable({}, { __mode = "k" })
local eggBase = setmetatable({}, { __mode = "k" })
local visitors = {}
local visitorFolder

----------------------------------------------------------------------
-- Localisation de la parcelle
----------------------------------------------------------------------
local function refreshPlot()
	local idx = player:GetAttribute("PlotIndex")
	if not idx then
		return false
	end
	local plots = Workspace:FindFirstChild("Plots")
	local m = plots and plots:FindFirstChild("Plot" .. idx)
	if not m then
		return false
	end
	if m ~= plotModel then
		plotModel = m
		local static = m:WaitForChild("Static")
		local terrain = static:WaitForChild("Terrain")
		plotCF = terrain.CFrame * CFrame.new(0, -0.05, 0)
	end
	return true
end

local function rootPart()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

----------------------------------------------------------------------
-- Effets
----------------------------------------------------------------------
local digEmitter
local function ensureEmitter(hrp)
	if digEmitter and digEmitter.Parent then
		return digEmitter
	end
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -2.5, -1)
	att.Parent = hrp
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(150, 105, 65))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(6, 12)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Rate = 0
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Parent = att
	digEmitter = pe
	return pe
end

function World.floatText(text, color, big)
	local hrp = rootPart()
	if not hrp then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = hrp
	bb.Size = UDim2.fromOffset(big and 260 or 180, big and 54 or 40)
	bb.StudsOffset = Vector3.new(rng:NextNumber(-1.5, 1.5), 3.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = player:WaitForChild("PlayerGui")
	local l = Ui.label(bb, { text = text, size = big and 30 or 22, color = color or Color3.new(1, 1, 1), stroke = true })
	TweenService:Create(
		bb,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = bb.StudsOffset + Vector3.new(0, 4, 0) }
	):Play()
	local tw = TweenService:Create(l, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 })
	tw:Play()
	tw.Completed:Connect(function()
		bb:Destroy()
	end)
end

local burst
local function emitBurst(color, count)
	local hrp = rootPart()
	if not hrp then
		return
	end
	if not burst or not burst.Parent then
		local att = Instance.new("Attachment")
		att.Name = "BurstAtt"
		att.Position = Vector3.new(0, 1, 0)
		att.Parent = hrp
		burst = Instance.new("ParticleEmitter")
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.Lifetime = NumberRange.new(0.6, 1.1)
		burst.Speed = NumberRange.new(10, 20)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		burst.LightEmission = 1
		burst.Rate = 0
		burst.Parent = att
	end
	burst.Color = ColorSequence.new(color)
	burst:Emit(count)
end

local function onFx(fx)
	if type(fx) ~= "table" then
		return
	end
	local t = fx.t
	if t == "dig" then
		local text = "+" .. Util.formatNumber(fx.amount) .. " 🦴"
		if fx.crit then
			World.floatText("TROUVAILLE ! " .. text, Ui.colors.gold, true)
		else
			World.floatText(text, Color3.fromRGB(250, 240, 210), false)
		end
		Ui.playSound("dig", fx.crit and 0.7 or 0.4)
		local hrp = rootPart()
		if hrp then
			ensureEmitter(hrp):Emit(fx.crit and 14 or 6)
		end
	elseif t == "collect" then
		World.floatText("+" .. Util.formatNumber(fx.amount) .. " 💰", Ui.colors.green, true)
		Ui.playSound("buy", 0.5)
		emitBurst(Color3.fromRGB(255, 225, 90), 10)
	elseif t == "buy" or t == "upgrade" then
		Ui.playSound("buy", 0.6)
		emitBurst(t == "buy" and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 170, 60), 18)
	elseif t == "hatch" then
		Reveal.show(fx.key, fx.new, fx.egg)
	elseif t == "openEggs" then
		Panels.openEggs(fx.slot)
	elseif t == "meteor" then
		World.floatText("☄ +" .. Util.formatNumber(fx.amount) .. " 🦴", Ui.colors.orange, true)
		Ui.playSound("buy", 0.6)
	elseif t == "levelup" then
		World.floatText("⭐ NIVEAU " .. fx.level .. " !", Ui.colors.gold, true)
		Ui.playSound("hatch", 0.8, 1.2)
		emitBurst(Color3.fromRGB(255, 220, 90), 40)
	elseif t == "story" then
		Ui.playSound("buy", 0.7, 1.3)
		emitBurst(Color3.fromRGB(120, 180, 255), 24)
	elseif t == "rebirth" then
		Ui.playSound("hatch", 0.7)
	end
end

----------------------------------------------------------------------
-- Animations : dinos, ouvriers, œufs
----------------------------------------------------------------------
local function updateDinos(dt, t, camPos)
	local dyn = plotModel:FindFirstChild("Dynamic")
	local folder = dyn and dyn:FindFirstChild("Dinos")
	if not folder then
		return
	end
	for _, m in ipairs(folder:GetChildren()) do
		local home = m:GetAttribute("Home")
		if home then
			local st = dinoState[m]
			if not st then
				st = {
					pos = home,
					yaw = rng:NextNumber(0, 6.28),
					target = home,
					wait = rng:NextNumber(0, 3),
					phase = rng:NextNumber(0, 6.28),
				}
				dinoState[m] = st
			end
			if (home - camPos).Magnitude < 220 then
				local moving = false
				if st.wait > 0 then
					st.wait = st.wait - dt
				else
					local delta = Vector3.new(st.target.X - st.pos.X, 0, st.target.Z - st.pos.Z)
					local dist = delta.Magnitude
					if dist < 0.3 then
						st.target = home + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2, 2))
						st.wait = rng:NextNumber(1, 4)
					else
						moving = true
						local dir = delta / dist
						st.pos = st.pos + dir * math.min(dist, 2.6 * dt)
						local want = math.atan2(-dir.X, -dir.Z)
						local diff = math.atan2(math.sin(want - st.yaw), math.cos(want - st.yaw))
						st.yaw = st.yaw + math.clamp(diff, -3 * dt, 3 * dt)
					end
				end
				local bob = moving and math.abs(math.sin(t * 7 + st.phase)) * 0.22 or math.sin(t * 1.5 + st.phase) * 0.05
				m:PivotTo(CFrame.new(st.pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, st.yaw, 0))
			end
		end
	end
end

local function updateWorkers(t)
	local dyn = plotModel:FindFirstChild("Dynamic")
	if not dyn then
		return
	end
	for _, folder in ipairs(dyn:GetChildren()) do
		if string.sub(folder.Name, 1, 7) == "Ouvrier" then
			local model = folder:FindFirstChild("Ouvrier")
			local base = model and model:GetAttribute("BaseCF")
			if base then
				local phase = tonumber(string.sub(folder.Name, 8)) or 0
				local lift = 0.5 + math.sin(t * 5 + phase * 1.7) * 0.9
				HumanFactory.pose(model, base, 0, lift)
			end
		end
	end
end

-- boutons d'achat : pulsation douce (cosmétique)
local function updatePads(t)
	local pads = plotModel:FindFirstChild("Pads")
	if not pads then
		return
	end
	for _, pad in ipairs(pads:GetChildren()) do
		pad.Transparency = 0.15 + (math.sin(t * 3 + pad.Position.X) + 1) * 0.12
	end
	local booth = plotModel.Static:FindFirstChild("PadCollecte")
	if booth then
		booth.Transparency = 0.1 + (math.sin(t * 4) + 1) * 0.1
	end
end

-- grande roue : rotation des rayons et des nacelles (les nacelles restent à l'endroit)
local wheelState = setmetatable({}, { __mode = "k" })
local function updateWheel(t)
	local dyn = plotModel:FindFirstChild("Dynamic")
	local ride = dyn and dyn:FindFirstChild("ride")
	local axle = ride and ride:FindFirstChild("Axe")
	if not axle then
		return
	end
	local inv = plotCF:Inverse()
	local hub = (inv * axle.CFrame).Position
	local angle = t * 0.25
	local rot = CFrame.new(hub) * CFrame.Angles(angle, 0, 0) * CFrame.new(-hub.X, -hub.Y, -hub.Z)
	for _, part in ipairs(ride:GetChildren()) do
		local isSpoke = string.sub(part.Name, 1, 5) == "Rayon"
		local isGondola = string.sub(part.Name, 1, 7) == "Nacelle"
		if isSpoke or isGondola then
			local base = wheelState[part]
			if not base then
				base = inv * part.CFrame
				wheelState[part] = base
			end
			local moved = rot * base
			if isGondola then
				part.CFrame = plotCF * CFrame.new(moved.Position)
			else
				part.CFrame = plotCF * moved
			end
		end
	end
end

local function updateEggs(t)
	local dyn = plotModel:FindFirstChild("Dynamic")
	if not dyn then
		return
	end
	for _, folder in ipairs(dyn:GetChildren()) do
		if string.sub(folder.Name, 1, 5) == "Stand" then
			local egg = folder:FindFirstChild("Oeuf")
			if egg then
				local base = eggBase[egg]
				if not base then
					base = egg.CFrame
					eggBase[egg] = base
				end
				local state = egg:GetAttribute("State")
				if state == "ready" then
					egg.CFrame = base * CFrame.Angles(0, 0, math.sin(t * 20) * 0.14)
				elseif state == "hatching" then
					egg.CFrame = base * CFrame.new(0, math.sin(t * 2.2) * 0.25, 0) * CFrame.Angles(0, t * 0.8, 0)
				else
					egg.CFrame = base
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Visiteurs (cosmétiques, uniquement dans ta parcelle)
----------------------------------------------------------------------
local function buildRoute(st)
	local route = {}
	local function add(x, z, wait, face)
		table.insert(route, { pos = Vector3.new(x, 0, z), wait = wait, face = face })
	end
	add(rng:NextNumber(-3, 3), -105)
	add(0, -84)
	-- arrêts : enclos possédés
	local stops = {}
	for i, pen in ipairs(Config.Pens) do
		if i == 1 or st.buildables["pen" .. i] then
			local side = pen.center.X < 0 and -1 or 1
			table.insert(stops, { x = side * 8.5, z = pen.center.Z, face = Vector3.new(side, 0, 0) })
		end
	end
	for _, def in ipairs(Config.Buildables) do
		if def.kind == "shop" and st.buildables[def.id] then
			table.insert(stops, { x = def.center.X, z = def.center.Z - 10, face = Vector3.new(0, 0, 1) })
		end
	end
	-- 1 à 3 arrêts, triés du plus proche de l'entrée au plus loin
	local chosen = {}
	local n = rng:NextInteger(1, math.min(3, #stops))
	for _ = 1, n do
		local idx = rng:NextInteger(1, #stops)
		table.insert(chosen, table.remove(stops, idx))
		if #stops == 0 then
			break
		end
	end
	table.sort(chosen, function(a, b)
		return a.z < b.z
	end)
	for _, s in ipairs(chosen) do
		if math.abs(s.x) > 9 then
			add(0, s.z, 0)
		end
		add(s.x, s.z, rng:NextNumber(3, 6), s.face)
		if math.abs(s.x) > 9 then
			add(0, s.z, 0)
		end
	end
	add(0, 18, rng:NextNumber(1, 2), Vector3.new(0, 0, 1))
	add(0, -84, 0)
	add(0, -105, 0)
	return route
end

local function spawnVisitor(st)
	local model = HumanFactory.build({ name = "Visiteur" })
	model.Parent = visitorFolder
	local route = buildRoute(st)
	table.insert(visitors, {
		model = model,
		route = route,
		idx = 2,
		pos = route[1].pos,
		yaw = math.pi,
		wait = 0,
		speed = rng:NextNumber(8, 11),
		phase = rng:NextNumber(0, 6),
	})
end

local function updateVisitors(dt, t, st)
	local target = math.clamp(math.floor(st.displayedCount * 0.9) + 1, 1, 14)
	if #visitors < target and rng:NextNumber() < dt * 0.6 then
		spawnVisitor(st)
	end
	for i = #visitors, 1, -1 do
		local v = visitors[i]
		local swing = 0
		if v.wait > 0 then
			v.wait = v.wait - dt
			if v.face then
				local want = math.atan2(-v.face.X, -v.face.Z)
				local diff = math.atan2(math.sin(want - v.yaw), math.cos(want - v.yaw))
				v.yaw = v.yaw + math.clamp(diff, -6 * dt, 6 * dt)
			end
		else
			local wp = v.route[v.idx]
			if not wp then
				v.model:Destroy()
				table.remove(visitors, i)
				v = nil
			else
				local delta = Vector3.new(wp.pos.X - v.pos.X, 0, wp.pos.Z - v.pos.Z)
				local dist = delta.Magnitude
				if dist < 0.6 then
					v.idx = v.idx + 1
					v.wait = wp.wait or 0
					v.face = wp.face
				else
					local dir = delta / dist
					v.pos = v.pos + dir * math.min(dist, v.speed * dt)
					local want = math.atan2(-dir.X, -dir.Z)
					local diff = math.atan2(math.sin(want - v.yaw), math.cos(want - v.yaw))
					v.yaw = v.yaw + math.clamp(diff, -8 * dt, 8 * dt)
					swing = math.sin(t * 11 + v.phase) * 0.7
				end
			end
		end
		if v then
			local cf = plotCF * CFrame.new(v.pos) * CFrame.Angles(0, v.yaw, 0)
			HumanFactory.pose(v.model, cf, swing, 0)
		end
	end
end

----------------------------------------------------------------------
-- Rayon guide vers l'objectif
----------------------------------------------------------------------
local beam, beamAtt0
local currentGuideTarget

local function resolveTarget(t)
	if not t or not plotModel then
		return nil
	end
	local static = plotModel:FindFirstChild("Static")
	local dyn = plotModel:FindFirstChild("Dynamic")
	if t.kind == "dig" then
		return static and static:FindFirstChild("RepereFouille")
	elseif t.kind == "booth" then
		return static and static:FindFirstChild("PadCollecte")
	elseif t.kind == "stand" then
		local s = dyn and dyn:FindFirstChild("Stand" .. t.slot)
		return s and s:FindFirstChild("Socle")
	elseif t.kind == "pad" then
		local pads = plotModel:FindFirstChild("Pads")
		return pads and pads:FindFirstChild("Pad_" .. t.id)
	end
	return nil
end

local function updateGuide()
	local hrp = rootPart()
	if not hrp then
		return
	end
	-- après une réapparition, l'ancien personnage (et le rayon) est détruit : on recrée tout
	if not beam or not beam.Parent or not beamAtt0 or not beamAtt0.Parent or beamAtt0.Parent ~= hrp then
		if beam then
			beam:Destroy()
		end
		if beamAtt0 then
			beamAtt0:Destroy()
		end
		beamAtt0 = Instance.new("Attachment")
		beamAtt0.Name = "GuideStart"
		beamAtt0.Parent = hrp
		beam = Instance.new("Beam")
		beam.Name = "Guide"
		beam.Width0 = 0.7
		beam.Width1 = 0.7
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.35)
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90))
		beam.Segments = 1
		beam.Attachment0 = beamAtt0
		beam.Parent = hrp
		currentGuideTarget = nil
	end
	local part = resolveTarget(Hud.objectiveTarget)
	if part and (part.Position - hrp.Position).Magnitude > 16 and Ui.openName == nil then
		if currentGuideTarget ~= part or not beam.Attachment1 or not beam.Attachment1.Parent then
			local att = part:FindFirstChild("GuideEnd")
			if not att then
				att = Instance.new("Attachment")
				att.Name = "GuideEnd"
				att.Position = Vector3.new(0, 1, 0)
				att.Parent = part
			end
			beam.Attachment1 = att
			currentGuideTarget = part
		end
		beam.Enabled = true
	else
		beam.Enabled = false
	end
end

----------------------------------------------------------------------
-- Démarrage
----------------------------------------------------------------------
function World.start()
	visitorFolder = Instance.new("Folder")
	visitorFolder.Name = "LocalVisitors"
	visitorFolder.Parent = Workspace

	Remotes.Fx.OnClientEvent:Connect(onFx)

	-- contexte (zone de fouille / kiosque) + guide, 4 Hz
	task.spawn(function()
		while true do
			task.wait(0.25)
			if refreshPlot() then
				local hrp = rootPart()
				if hrp then
					local dig = plotModel.Static:FindFirstChild("RepereFouille")
					local pad = plotModel.Static:FindFirstChild("PadCollecte")
					if dig then
						local d = Vector3.new(hrp.Position.X - dig.Position.X, 0, hrp.Position.Z - dig.Position.Z).Magnitude
						Hud.context.inDigZone = d <= Config.DigRadius
					end
					if pad then
						Hud.context.nearBooth = (pad.Position - hrp.Position).Magnitude <= 20
					end
					pcall(updateGuide)
				end
			end
		end
	end)

	-- animations
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not plotModel or not plotModel.Parent then
			return
		end
		acc = acc + dt
		if acc < 1 / 30 then
			return
		end
		local step = acc
		acc = 0
		local t = os.clock()
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		updateDinos(step, t, camPos)
		updateWorkers(t)
		updateEggs(t)
		updatePads(t)
		updateWheel(t)
		if Store.state and plotCF then
			updateVisitors(step, t, Store.state)
		end
	end)
end

return World
