-- Cinématiques : intro, mini tutoriel, aperçu d'une nouvelle zone, capture d'un boss. Seulement aux moments clés,
-- jamais pendant l'action. Passables d'un appui, rejouables (menu Histoire), protégées par pcall, jamais bloquantes :
-- la caméra seule est scénarisée, le joueur garde toujours le contrôle, et un départ en expédition l'interrompt.
-- La logique (séquences, durée, passage, reprise, choix de la prochaine) est dans shared/CinematicPlan.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Plan = require(Shared.CinematicPlan)
local Remotes = require(Shared.Remotes)

local CameraRig = require(script.Parent.CameraRig)
local ClientState = require(script.Parent.ClientState)
local Sfx = require(script.Parent.Sfx)
local UI = require(script.Parent.UI)

local Cinematics = {}

local player = Players.LocalPlayer
local PINK = Color3.fromRGB(255, 96, 160)

local current = nil -- { key, state, gui, refs, connection, shotIndex }
local started = 0
Cinematics.failures = 0
Cinematics.lastKey = nil

local function warnOnce(where, err)
	Cinematics.failures = Cinematics.failures + 1
	warn("[Cinématique " .. where .. "] " .. tostring(err))
end

-- ---------------------------------------------------------------- caméra par plan

local function plotCenter()
	local center = player:GetAttribute("PlotCenter")
	if typeof(center) == "Vector3" then
		return center
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or Vector3.new(0, 330, 0)
end

local function bossCenter(key)
	local id = key:match("^boss_(.+)$")
	local folder = workspace:FindFirstChild("ZooAnimals")
	local model = folder and id and folder:FindFirstChild("Zoo_" .. id .. "_1", true)
	local root = model and model:FindFirstChild("Root")
	return root and root.Position or plotCenter()
end

-- Renvoie une fonction t -> CFrame pour toute la séquence (ou nil si aucun plan n'a de caméra).
local function cameraFor(key, shots)
	local cameraShots = false
	for _, shot in ipairs(shots) do
		if shot.cam ~= "none" then
			cameraShots = true
		end
	end
	if not cameraShots then
		return nil
	end
	local total = Plan.total(shots)
	local center = key:match("^boss_") and bossCenter(key) or plotCenter()
	local zoneIndex = tonumber(key:match("^zone_(%d+)$") or "")
	local zone = zoneIndex and Config.Zones[zoneIndex]
	return function(t)
		local overall = math.clamp(t / total, 0, 1)
		if zone then
			-- survol de la zone : de son départ vers le fond, en légère hauteur, regard légèrement devant
			local z = zone.start + overall * 260
			local eye = Vector3.new(30 - overall * 60, 42 - overall * 10, z - 60)
			return CFrame.lookAt(eye, Vector3.new(0, 6, z + 50))
		end
		local boss = key:match("^boss_")
		local angle = t * (boss and 0.5 or 0.3) + 0.6
		local radius = boss and 34 - overall * 8 or 95 - overall * 25
		local height = boss and 16 or 70 - overall * 40
		local eye = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		return CFrame.lookAt(eye, center + Vector3.new(0, 4, 0))
	end
end

-- ---------------------------------------------------------------- affichage

local function buildOverlay(shots)
	local gui = UI.make("ScreenGui", {
		Name = "HerdHopperCinematic",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local refs = {}
	for _, top in ipairs({ true, false }) do
		UI.frame(gui, {
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.new(0, 0, top and 0 or 1, 0),
			Size = UDim2.new(1, 0, 0.11, 0),
			BackgroundColor3 = Color3.fromRGB(10, 12, 20),
			Active = false,
		})
	end
	refs.caption = UI.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.7, 0),
		Size = UDim2.new(0.86, 0, 0.1, 0),
		Text = "",
		maxSize = 56,
		TextColor3 = UI.Colors.Accent,
	})
	refs.sub = UI.text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.79, 0),
		Size = UDim2.new(0.8, 0, 0.07, 0),
		Text = "",
		maxSize = 28,
		Font = UI.FontBody,
	})
	refs.heartHolder = UI.frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 120, 0, 120),
		BackgroundTransparency = 1,
		Visible = false,
	})
	UI.heart(refs.heartHolder, 120, PINK)
	refs.heartScale = UI.make("UIScale", { Scale = 1 }, refs.heartHolder)
	refs.hint = UI.text(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.985, 0),
		Size = UDim2.new(0.6, 0, 0.04, 0),
		Text = "Touche l'écran ou une touche pour passer",
		maxSize = 18,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Muted,
	})
	-- points de progression (un par plan)
	refs.dots = {}
	local row = UI.frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 0),
		Size = UDim2.new(0, #shots * 22, 0, 12),
		BackgroundTransparency = 1,
	})
	UI.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, row)
	for i = 1, #shots do
		local dot = UI.frame(row, { Size = UDim2.new(0, 14, 0, 6), BackgroundColor3 = UI.Colors.Muted })
		UI.corner(dot, 3)
		refs.dots[i] = dot
	end
	return gui, refs
end

local function showShot(refs, shots, index, p)
	local shot = shots[index]
	refs.caption.Text = shot.caption
	refs.sub.Text = shot.sub or ""
	refs.heartHolder.Visible = shot.heart == true
	if shot.heart then
		refs.heartScale.Scale = 1 + math.sin(os.clock() * 6) * 0.1
	end
	for i, dot in ipairs(refs.dots) do
		dot.BackgroundColor3 = i <= index and UI.Colors.Accent or UI.Colors.Muted
	end
	-- fondu d'entrée / sortie du texte
	local alpha = 1 - math.clamp(math.min(p / 0.12, (1 - p) / 0.12), 0, 1)
	refs.caption.TextTransparency = alpha
	refs.sub.TextTransparency = alpha
end

-- ---------------------------------------------------------------- cycle de vie

local function markSeen(key)
	task.spawn(function()
		pcall(function()
			Remotes.ZooAction:InvokeServer("seen", key)
		end)
	end)
end

local function finish(reason)
	local run = current
	if not run then
		return
	end
	current = nil
	local completed = Plan.completed(run.state)
	pcall(function()
		if run.connection then
			run.connection:Disconnect()
		end
		if run.render then
			run.render:Disconnect()
		end
		CameraRig.stopCinematic()
		run.gui:Destroy()
	end)
	if completed and reason ~= "failed" then
		markSeen(run.key)
	end
	Cinematics.lastKey = run.key
	started = os.clock()
end

function Cinematics.isPlaying()
	return current ~= nil
end

-- Passe la cinématique en cours (appui, bouton, ou interruption).
function Cinematics.skip()
	if current then
		Plan.skip(current.state)
		finish("skipped")
	end
end

-- Lance la cinématique `key` si elle existe et est autorisée. Renvoie true si elle démarre.
function Cinematics.play(key, force)
	local cfg = Config.Cinematics
	if current or not cfg.Enabled then
		return false
	end
	local shots = Plan.sequenceFor(key)
	if not shots then
		return false
	end
	local ok, err = pcall(function()
		local state = Plan.newState(shots, cfg.MaxSeconds)
		local gui, refs = buildOverlay(shots)
		local run = { key = key, state = state, gui = gui, refs = refs, t0 = os.clock(), forced = force == true }
		current = run

		local camFn = cameraFor(key, shots)
		if camFn then
			CameraRig.cinematic(camFn, state.total, function()
				-- fin de la caméra : la séquence suit
			end)
		end
		Sfx.play("go")

		-- appui = passer (après un court délai pour ne pas sauter par accident)
		run.connection = UserInputService.InputBegan:Connect(function(input)
			local kind = input.UserInputType
			if current ~= run or os.clock() - run.t0 < cfg.GraceSeconds then
				return
			end
			if
				kind == Enum.UserInputType.Keyboard
				or kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.Touch
				or kind == Enum.UserInputType.Gamepad1
			then
				Cinematics.skip()
			end
		end)

		local last = os.clock()
		run.render = RunService.RenderStepped:Connect(function()
			if current ~= run then
				return
			end
			local now = os.clock()
			local dt = math.min(now - last, 0.1)
			last = now
			local stepOk, stepErr = pcall(function()
				Plan.step(run.state, dt)
				local index, p = Plan.shotAt(shots, run.state.t)
				if index then
					showShot(run.refs, shots, index, p)
				end
			end)
			if not stepOk then
				warnOnce(key, stepErr)
				finish("failed")
				return
			end
			if run.state.done then
				finish("done")
			end
		end)
	end)
	if not ok then
		warnOnce(key, err)
		current = nil
		pcall(function()
			CameraRig.stopCinematic()
		end)
		return false
	end
	return true
end

-- Rejoue une cinématique depuis le menu (intro, tutoriel).
function Cinematics.replay(key)
	if Config.Cinematics.Replayable then
		return Cinematics.play(key, true)
	end
	return false
end

-- ---------------------------------------------------------------- déclenchement automatique

local function calm()
	local phase = workspace:GetAttribute("Phase")
	return ClientState.Status == "Lobby"
		and phase ~= "Countdown"
		and phase ~= "Running"
		and phase ~= "Results"
		and player.Character ~= nil
		and player:GetAttribute("PlotCenter") ~= nil
end

function Cinematics.init()
	-- un départ en expédition interrompt tout : le jeu reprend aussitôt
	ClientState.connect("Status", function(status)
		if status ~= "Lobby" and current then
			finish("interrupted")
		end
	end)
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = workspace:GetAttribute("Phase")
		if current and (phase == "Countdown" or phase == "Running") then
			finish("interrupted")
		end
	end)

	task.spawn(function()
		started = os.clock()
		while true do
			task.wait(0.5)
			local data = ClientState.Data
			if
				not current
				and data
				and data.loaded
				and calm()
				and os.clock() - started > Config.Cinematics.IdleDelay
			then
				local ok, list = pcall(Plan.pending, data, Config.Cinematics)
				if ok and #list > 0 then
					local playedOk = Cinematics.play(list[1])
					if not playedOk then
						-- une cinématique qui ne démarre pas ne doit pas boucler : on la marque vue
						markSeen(list[1])
						started = os.clock()
					end
				end
			end
		end
	end)
end

return Cinematics
