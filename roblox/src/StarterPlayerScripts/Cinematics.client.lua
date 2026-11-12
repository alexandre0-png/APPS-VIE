-- LocalScript : StarterPlayer/StarterPlayerScripts/Cinematics
-- Cinématiques courtes, aux moments clés seulement : intro (la ferme, Mère Poule, les œufs, le but) et mini tutoriel au premier lancement,
-- première zone débloquée, premier pet rare. Toutes skippables (bouton, Entrée, manette B), réglables dans Config.Cinematics, exécutées
-- sous pcall (Easing.guard), et JAMAIS bloquantes : le joueur garde le contrôle de son personnage, le jeu continue, la caméra est
-- restituée quoi qu'il arrive (fin, skip, mort, attaque, erreur, délai de sécurité). La logique (séquences, durées, skip, reprise, file)
-- est dans le module pur Cinema, testé hors de Roblox.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Easing = require(Shared:WaitForChild("Easing"))
local Cinema = require(Shared:WaitForChild("Cinema")).new(Easing)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RAction = Remotes:WaitForChild("Action")

local BIND_NAME = "ChipeCine"
local director = Cinema.director()
local plans = {} -- id -> { seq, resolved = { CFrame par plan }, startedAt }
local activeId = nil
local saved = nil -- caméra du joueur avant la cinématique
local bound = false
local state = nil
local lastCh = nil
local failed = {}

---------------------------------------------------------------- Interface : barres de cinéma, légende, bouton Passer
local gui = Instance.new("ScreenGui")
gui.Name = "ChipeCine"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(anchorY, height)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0, anchorY)
	f.Position = UDim2.fromScale(0, anchorY)
	f.Size = UDim2.fromScale(1, height)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.Parent = gui
	return f
end
local topBar, bottomBar = bar(0, 0.09), bar(1, 0.2)

local caption = Instance.new("TextLabel")
caption.BackgroundTransparency = 1
caption.Size = UDim2.new(0.84, 0, 0.8, 0)
caption.AnchorPoint = Vector2.new(0.5, 0.5)
caption.Position = UDim2.fromScale(0.5, 0.5)
caption.Font = Enum.Font.GothamBold
caption.TextColor3 = Color3.fromRGB(255, 244, 220)
caption.TextStrokeTransparency = 0.5
caption.TextWrapped = true
caption.TextScaled = true
caption.Text = ""
caption.Parent = bottomBar
local limit = Instance.new("UITextSizeConstraint")
limit.MaxTextSize = 28
limit.MinTextSize = 12
limit.Parent = caption

local header = Instance.new("TextLabel")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(16, 0)
header.Size = UDim2.new(0.5, 0, 1, 0)
header.Font = Enum.Font.GothamBold
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextColor3 = Color3.fromRGB(255, 214, 120)
header.Text = ""
header.Parent = topBar

local function button(text, xOffset, width)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, xOffset, 0.5, 0)
	b.Size = UDim2.fromOffset(width, 34)
	b.BackgroundColor3 = Color3.fromRGB(255, 210, 63)
	b.TextColor3 = Color3.fromRGB(43, 34, 0)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Text = text
	b.Parent = topBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	return b
end
local skipBtn = button("Passer ▶", -12, 110)
local skipAllBtn = button("Tout passer", -132, 120)
skipAllBtn.BackgroundColor3 = Color3.fromRGB(75, 91, 81)
skipAllBtn.TextColor3 = Color3.fromRGB(244, 255, 246)

local TITLES = { intro = "🎬 Il était une fois…", tutorial = "🎓 Comment jouer", firstZone = "🔓 Nouveau domaine", firstRare = "✨ Pet rare !" }

---------------------------------------------------------------- Caméra : toujours restituée
local function takeCamera()
	local cam = workspace.CurrentCamera
	if cam and not saved then
		saved = { cameraType = cam.CameraType, subject = cam.CameraSubject }
		cam.CameraType = Enum.CameraType.Scriptable
	end
end

local function giveCameraBack()
	local cam = workspace.CurrentCamera
	if cam and saved then
		cam.CameraType = (saved.cameraType == Enum.CameraType.Scriptable) and Enum.CameraType.Custom or saved.cameraType
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraSubject = hum or saved.subject
	end
	saved = nil
end

local function exitCinematic()
	if bound then
		bound = false
		pcall(function()
			RunService:UnbindFromRenderStep(BIND_NAME)
		end)
	end
	pcall(giveCameraBack)
	gui.Enabled = false
	activeId = nil
	plans = {}
end

-- Sortie de secours : quoi qu'il arrive, tout s'arrête et la caméra revient au joueur. Rien n'est considéré comme vu.
local function emergency(reason)
	director.abort()
	exitCinematic()
	if reason then
		warn("[Cinematics] arrêt : " .. tostring(reason))
	end
end

local function markSeen(id)
	pcall(function()
		RAction:FireServer("cineSeen", id)
	end)
end

---------------------------------------------------------------- Ancres de caméra
local function plotCFrame()
	local attr = player:GetAttribute("PlotCF")
	if typeof(attr) == "CFrame" then
		return attr
	end
	local spawn = player.RespawnLocation
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame * CFrame.new(0, -1.2, 20) -- le spawn est à (0, 1.2, -20) dans le repère de la base
	end
	return nil
end

local function rivalCF(i)
	return CFrame.new((i - 2) * 55, 0, -70)
end

local anchors = {
	arena = function()
		return CFrame.new(0, 0, 0)
	end,
	hen = function()
		local m = CollectionService:GetTagged("Hen")[1]
		local body = m and m.PrimaryPart
		return body and CFrame.new(body.Position.X, 0, body.Position.Z) or nil
	end,
	rival1 = function()
		return rivalCF(1)
	end,
	rival2 = function()
		return rivalCF(2)
	end,
	rival3 = function()
		return rivalCF(3)
	end,
	base = plotCFrame,
	pad = function(ctx)
		local pc = plotCFrame()
		if not pc or not ctx or not ctx.slot then
			return nil
		end
		local lx, lz = Config.padLocal(ctx.slot)
		return pc * CFrame.new(lx, 1.4, lz)
	end,
}

local function toWorld(acf, v)
	return acf:PointToWorldSpace(Vector3.new(v[1], v[2], v[3]))
end

---------------------------------------------------------------- Mise en scène
local function sparkleAt(position)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 232, 150), Color3.fromRGB(255, 255, 255))
	e.Rate = 0
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(6, 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = p
	p.Parent = workspace
	e:Emit(50)
	Debris:AddItem(p, 3)
end

local function onShot(id, index)
	local plan = plans[id]
	local shot = plan.seq.shots[index]
	caption.Text = shot.text
	caption.TextTransparency = 1
	TweenService:Create(caption, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	header.Text = (TITLES[id] or "🎬") .. "   " .. index .. "/" .. #plan.seq.shots
	if shot.fx == "sparkle" then
		pcall(sparkleAt, toWorld(plan.resolved[index], shot.look) + Vector3.new(0, 2, 0))
	end
end

local function step()
	local now = os.clock()
	local id, ev = director.update(now)
	if not id then
		exitCinematic()
		return
	end
	if not ev then
		return
	end
	if ev.finished then
		markSeen(id)
		if not director.current then
			exitCinematic()
		end
		return
	end
	local plan = plans[id]
	if not plan then
		return emergency("plan inconnu : " .. tostring(id))
	end
	if activeId ~= id then
		activeId = id
		plan.startedAt = now
	end
	if now - plan.startedAt > plan.seq.total + Config.Cinematics.watchdog then
		return emergency("délai de sécurité dépassé")
	end
	if ev.shotChanged then
		onShot(id, ev.shot)
	end
	local pos, look = Cinema.cameraAt(plan.seq.shots[ev.shot], ev.progress)
	local cam = workspace.CurrentCamera
	local acf = plan.resolved[ev.shot]
	cam.CFrame = CFrame.lookAt(toWorld(acf, pos), toWorld(acf, look))
	skipAllBtn.Visible = #director.queue > 0
end

local function safeStep()
	local ok, err = pcall(step)
	if not ok then
		local id = activeId
		if id then
			failed[id] = true
		end
		emergency(err)
	end
end

local function enter()
	gui.Enabled = true
	skipAllBtn.Visible = false
	takeCamera()
	if not bound then
		bound = true
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, safeStep)
	end
end

---------------------------------------------------------------- Lancer, passer
local function warnOnce(name, err)
	warn("[Cinematics] « " .. name .. " » désactivée pour cette session après une erreur : " .. tostring(err))
	emergency()
end

-- Retourne true si la cinématique a démarré ou été mise en file. Ne lève jamais d'erreur.
local function begin(id, def, ctx, chain)
	if failed[id] or not Config.cineEnabled(id) then
		return false
	end
	local ok, seq = pcall(Cinema.sequence, def)
	if not ok or not seq then
		return false
	end
	local resolved = {}
	for i, shot in ipairs(seq.shots) do
		local f = anchors[shot.anchor]
		local okAnchor, cf = pcall(function()
			return f and f(ctx)
		end)
		if not (okAnchor and cf) then
			return false -- ancre pas encore prête (monde non chargé) : pas de cinématique plutôt qu'un plan cassé
		end
		resolved[i] = cf
	end
	local started = false
	Easing.guard(Config.cineEnabled, failed, id, function()
		local result = director.request(id, seq, os.clock(), chain)
		if result == "refused" then
			return
		end
		plans[id] = { seq = seq, resolved = resolved, startedAt = nil }
		started = true
		if result == "playing" then
			enter()
		end
	end, warnOnce)
	return started
end

local function skipCurrent()
	local id = director.skip(os.clock())
	if id then
		markSeen(id)
	end
	if not director.current then
		exitCinematic()
	end
end

local function skipEverything()
	for _, id in ipairs(director.skipAll()) do
		markSeen(id)
	end
	exitCinematic()
end

skipBtn.Activated:Connect(skipCurrent)
skipAllBtn.Activated:Connect(skipEverything)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not director.isActive() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonB then
		skipCurrent()
	end
end)

---------------------------------------------------------------- Abandon : le joueur est attaqué ou meurt
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(_msg, sfx)
	if sfx == "caught" and director.isActive() then
		emergency() -- un gardien ou un voleur s'en prend à lui : retour immédiat au jeu
	end
end)
local function watchCharacter(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			emergency()
		end)
	end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

---------------------------------------------------------------- Déclencheurs (moments clés uniquement)
-- Premier lancement : intro puis mini tutoriel (le tutoriel est mis en file derrière l'intro). Nouveaux joueurs seulement.
local function onFirstState()
	local t0 = os.clock()
	while os.clock() - t0 < 20 and not (player.Character and player.Character:FindFirstChild("HumanoidRootPart") and plotCFrame()) do
		task.wait(0.25)
	end
	task.wait(1.5) -- laisse le jeu s'afficher
	if not state or state.story.ch ~= 0 or state.hatched ~= 0 then
		return
	end
	local playIntro = Config.cineEnabled("intro") and not state.cine.intro
	local playTutorial = Config.cineEnabled("tutorial") and not state.cine.tutorial
	if playIntro then
		begin("intro", Config.CINE.intro, {}, false)
		if playTutorial then
			begin("tutorial", Config.CINE.tutorial, {}, true)
		end
	elseif playTutorial then
		begin("tutorial", Config.CINE.tutorial, {}, false)
	end
end

Remotes:WaitForChild("State").OnClientEvent:Connect(function(snap)
	local first = state == nil
	state = snap
	if first then
		lastCh = snap.story.ch
		task.spawn(onFirstState)
		return
	end
	-- première zone débloquée : le chapitre vient d'atteindre le seuil d'un domaine
	if snap.story.ch > lastCh and not snap.cine.firstZone and snap.carry == 0 then
		for idx, zone in ipairs(Config.ZONES) do
			if zone.chapter > 0 and zone.chapter == snap.story.ch then
				begin("firstZone", Config.cineFirstZone(idx), {}, false)
			end
		end
	end
	lastCh = snap.story.ch
end)

-- Premier pet rare (même critère que les confettis) ; l'emplacement vient du serveur.
Remotes:WaitForChild("Hatch").OnClientEvent:Connect(function(info)
	if not state or state.cine.firstRare or state.carry > 0 then
		return
	end
	local def = Config.PETS[info.p]
	if not def or not (def.tier >= 4 or info.m > 1 or info.s >= 4) then
		return
	end
	begin("firstRare", Config.cineFirstRare(Config.petName(info.p, info.s, info.m), Config.TIERS[def.tier].name, "+" .. Config.fmt(info.inc) .. "/s."), { slot = info.slot }, false)
end)

-- Revoir (menu Plus) : événement local déclenché par l'interface.
local replay = Instance.new("BindableEvent")
replay.Name = "ReplayCinematic"
replay.Parent = ReplicatedStorage
replay.Event:Connect(function(kind)
	if not Config.Cinematics.replay then
		return
	end
	if kind == "intro" then
		if begin("intro", Config.CINE.intro, {}, false) then
			begin("tutorial", Config.CINE.tutorial, {}, true)
		end
	elseif kind == "tutorial" then
		begin("tutorial", Config.CINE.tutorial, {}, false)
	end
end)
