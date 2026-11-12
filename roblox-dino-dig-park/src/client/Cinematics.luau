-- Cinematics.luau : courtes séquences caméra aux moments clés. Skippables, réglables (Config.Cinematics),
-- protégées par pcall, et qui ne verrouillent jamais les commandes du joueur.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Remotes = require(Shared.Remotes)
local CinematicLogic = require(Shared.CinematicLogic)

local Ui = require(script.Parent.Ui)
local Store = require(script.Parent.StateStore)
local Reveal = require(script.Parent.Reveal)

local Cinematics = {}
local player = Players.LocalPlayer

local playing = false
local currentState = nil
local localSeen = {}
local queue = {}
local runner = false

function Cinematics.isPlaying()
	return playing
end

function Cinematics.enabled(flag)
	local c = Config.Cinematics
	return c.enabled == true and (flag == nil or c[flag] == true)
end

local function seen(id)
	return localSeen[id] == true or (Store.state ~= nil and Store.state.seen ~= nil and Store.state.seen[id] == true)
end

----------------------------------------------------------------------
-- Plans de caméra (coordonnées locales de la parcelle -> monde)
----------------------------------------------------------------------
local function plotFrame()
	local idx = player:GetAttribute("PlotIndex")
	local plots = Workspace:FindFirstChild("Plots")
	local model = idx and plots and plots:FindFirstChild("Plot" .. idx)
	local static = model and model:FindFirstChild("Static")
	local terrain = static and static:FindFirstChild("Terrain")
	if not terrain then
		return nil, nil
	end
	return terrain.CFrame * CFrame.new(0, -0.05, 0), model
end

local function world(frame, x, y, z)
	local v = frame:PointToWorldSpace(Vector3.new(x, y, z))
	return { v.X, v.Y, v.Z }
end

local function shot(frame, dur, from, to, look0, look1, caption)
	return {
		dur = dur,
		from = world(frame, from[1], from[2], from[3]),
		to = world(frame, to[1], to[2], to[3]),
		look0 = world(frame, look0[1], look0[2], look0[3]),
		look1 = world(frame, look1[1], look1[2], look1[3]),
		caption = caption,
	}
end

function Cinematics.introShots(frame)
	return {
		shot(
			frame,
			5.5,
			{ 0, 70, -170 },
			{ 0, 38, -120 },
			{ 0, 10, -70 },
			{ 0, 8, -40 },
			"L'expédition du Professeur Rex arrive au Dino Dig Park !"
		),
		shot(
			frame,
			6,
			{ 0, 18, -85 },
			{ 0, 10, -20 },
			{ 0, 4, -20 },
			{ -20, 3, 30 },
			"Un vieux terrain, des fossiles cachés… et un rêve fou !"
		),
		shot(
			frame,
			5.5,
			{ -5, 14, 20 },
			{ -18, 8, 40 },
			{ -32, 2, 60 },
			{ -32, 2, 62 },
			"Creuse, fais éclore des œufs et bâtis le plus beau parc de dinos !"
		),
		shot(
			frame,
			5,
			{ 28, 16, 30 },
			{ 18, 10, 40 },
			{ 32, 5, 59 },
			{ 32, 5, 60 },
			"Le laboratoire donnera vie à tes trouvailles. En route !"
		),
	}
end

-- orbite en 3 plans autour d'un point local (x, z)
local function orbitShots(frame, cx, cz, radius, height, caption1, caption2, caption3)
	local function p(angleDeg)
		local a = math.rad(angleDeg)
		return { cx + math.cos(a) * radius, height, cz + math.sin(a) * radius }
	end
	local look = { cx, 3, cz }
	return {
		shot(frame, 4, p(200), p(270), look, look, caption1),
		shot(frame, 4, p(270), p(340), look, look, caption2),
		shot(frame, 4, p(340), p(410), look, look, caption3),
	}
end

function Cinematics.rareShots(frame, cx, cz)
	return orbitShots(
		frame,
		cx,
		cz,
		16,
		7,
		"Un dino RARE ! Le Professeur n'en croit pas ses yeux !",
		"Regarde-le : il rapporte bien plus de pièces.",
		"Ta collection devient légendaire… continue !"
	)
end

function Cinematics.zoneShots(frame, cx, cz, name)
	return orbitShots(
		frame,
		cx,
		cz,
		26,
		14,
		"Un nouvel enclos s'ouvre : " .. name .. " !",
		"Plus de place pour accueillir de nouveaux dinos.",
		"Le parc grandit, les visiteurs adorent !"
	)
end

----------------------------------------------------------------------
-- Lecture
----------------------------------------------------------------------
local function buildOverlay()
	local gui = Ui.new("ScreenGui", {
		Name = "DinoCinematic",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 30,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local topBar =
		Ui.new("Frame", { Size = UDim2.fromScale(1, 0.1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	local bottomBar = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 0.14),
		Position = UDim2.fromScale(0, 0.86),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	local caption = Ui.label(bottomBar, {
		text = "",
		size = 26,
		wrap = true,
		stroke = true,
		color = Color3.fromRGB(255, 232, 150),
		sizeUdim = UDim2.fromScale(0.7, 1),
		pos = UDim2.fromScale(0.03, 0),
		align = Enum.TextXAlignment.Left,
	})
	local skip = Ui.button(bottomBar, {
		text = "Passer ⏭",
		size = UDim2.fromOffset(150, 46),
		pos = UDim2.new(1, -16, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Ui.colors.blue,
		textSize = 20,
		onClick = function()
			Cinematics.skip()
		end,
	})
	return gui, caption, skip, topBar
end

-- oublie une cinématique déjà vue (utilisé par les tests)
function Cinematics.forget(id)
	localSeen[id] = nil
end

function Cinematics.skip()
	if currentState then
		CinematicLogic.skip(currentState)
	end
end

local function restoreCamera(cam, previousType)
	pcall(function()
		cam.CameraType = previousType or Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end)
end

-- Joue un plan. Retourne true si lu jusqu'au bout ou skippé, false si impossible. Ne lève jamais d'erreur.
function Cinematics.play(id, shots)
	if playing or not Cinematics.enabled() then
		return false
	end
	local okShots = CinematicLogic.validate(shots, Config.Cinematics.minSeconds, Config.Cinematics.maxSeconds)
	if not okShots then
		return false
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	playing = true
	localSeen[id] = true
	Remotes.Action:FireServer("CinematicSeen", { id = id })

	local previousType = cam.CameraType
	local gui, caption
	local state = CinematicLogic.new(shots)
	currentState = state
	local ok, err = pcall(function()
		gui, caption = buildOverlay()
		ContextActionService:BindAction("CinematicSkip", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				Cinematics.skip()
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.Return, Enum.KeyCode.ButtonB)
		cam.CameraType = Enum.CameraType.Scriptable
		local startedAt = os.clock()
		local charAtStart = player.Character
		local limit = CinematicLogic.totalDuration(shots) + 5
		while not state.finished do
			local dt = RunService.RenderStepped:Wait()
			local snap = CinematicLogic.step(state, dt)
			if snap.pos then
				cam.CFrame =
					CFrame.lookAt(Vector3.new(snap.pos[1], snap.pos[2], snap.pos[3]), Vector3.new(snap.look[1], snap.look[2], snap.look[3]))
				caption.Text = snap.caption or ""
			end
			-- garde-fous : réapparition du personnage ou durée dépassée => on rend la caméra
			if player.Character ~= charAtStart or os.clock() - startedAt > limit then
				CinematicLogic.skip(state)
			end
		end
	end)
	if not ok then
		warn("[Cinematics] " .. id .. " : " .. tostring(err))
	end
	-- nettoyage systématique
	pcall(function()
		ContextActionService:UnbindAction("CinematicSkip")
	end)
	restoreCamera(cam, previousType)
	if gui then
		pcall(function()
			gui:Destroy()
		end)
	end
	currentState = nil
	playing = false
	return ok
end

----------------------------------------------------------------------
-- Déclencheurs (moments clés uniquement)
----------------------------------------------------------------------
local function enqueue(job)
	table.insert(queue, job)
	if runner then
		return
	end
	runner = true
	task.spawn(function()
		while #queue > 0 do
			local j = table.remove(queue, 1)
			local ok, err = pcall(j)
			if not ok then
				warn("[Cinematics] file : " .. tostring(err))
			end
		end
		runner = false
	end)
end

local function waitUntil(cond, timeout)
	local t0 = os.clock()
	while not cond() and os.clock() - t0 < timeout do
		task.wait(0.2)
	end
	return cond()
end

local function nothingBlocking()
	return not Reveal.isPlaying() and Ui.openName == nil
end

local function findDinoHome(key)
	local _, model = plotFrame()
	local dyn = model and model:FindFirstChild("Dynamic")
	local folder = dyn and dyn:FindFirstChild("Dinos")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("DinoKey") == key then
				return m:GetAttribute("Home")
			end
		end
	end
	return nil
end

local function openTutorial()
	if Cinematics.enabled("tutorial") and not seen("tutorial") then
		localSeen.tutorial = true
		Remotes.Action:FireServer("CinematicSeen", { id = "tutorial" })
		if Ui.openName == nil then
			Ui.openPanel("welcome")
		end
	end
end

-- intro puis mini tutoriel, uniquement pour un tout nouveau joueur
local introChecked = false
local function checkIntro(st)
	if introChecked then
		return
	end
	introChecked = true
	local brandNew = st.stats.digs == 0 and st.stats.hatched == 0 and next(st.dinos) == nil
	if not brandNew then
		return
	end
	enqueue(function()
		if not waitUntil(function()
			return (plotFrame()) ~= nil and player.Character ~= nil
		end, 20) then
			return
		end
		task.wait(1.5)
		if Cinematics.enabled("intro") and not seen("intro") then
			local frame = plotFrame()
			if frame then
				Cinematics.play("intro", Cinematics.introShots(frame))
			end
		end
		openTutorial()
	end)
end

local function onFx(fx)
	if type(fx) ~= "table" then
		return
	end
	if fx.t == "hatch" and Cinematics.enabled("firstRare") and not seen("firstRare") then
		local dino = Config.DinoById[(Economy.parseKey(fx.key))]
		if dino and Config.RarityById[dino.rarity].order >= 3 then
			localSeen.firstRare = nil -- ne sera marqué qu'au moment de la lecture
			enqueue(function()
				if seen("firstRare") then
					return
				end
				waitUntil(nothingBlocking, 40)
				local frame = plotFrame()
				if not frame then
					return
				end
				local home = findDinoHome(fx.key)
				local local_ = home and frame:Inverse():PointToWorldSpace(home)
					or Vector3.new(Config.Pens[1].center.X - 9, 0, Config.Pens[1].center.Z - 6)
				Cinematics.play("firstRare", Cinematics.rareShots(frame, local_.X, local_.Z))
			end)
		end
	elseif fx.t == "buy" and Cinematics.enabled("bigZone") and Config.Cinematics.bigZonePens[fx.id] then
		local cid = "zone_" .. fx.id
		if not seen(cid) then
			enqueue(function()
				if seen(cid) then
					return
				end
				task.wait(1.2) -- laisse l'enclos se construire
				waitUntil(nothingBlocking, 10)
				local frame = plotFrame()
				local def = Config.BuildableById[fx.id]
				if frame and def then
					local c = Config.Pens[def.index].center
					Cinematics.play(cid, Cinematics.zoneShots(frame, c.X, c.Z, def.name))
				end
			end)
		end
	end
end

function Cinematics.start()
	Store.connect(function(st)
		if st.seen then
			checkIntro(st)
		end
	end)
	Remotes.Fx.OnClientEvent:Connect(function(fx)
		local ok, err = pcall(onFx, fx)
		if not ok then
			warn("[Cinematics] fx : " .. tostring(err))
		end
	end)
end

return Cinematics
