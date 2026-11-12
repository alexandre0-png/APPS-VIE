--!nonstrict
-- Cinématiques courtes (intro, tutoriel, saison, Roi de la tour) : caméra scriptée, bandes noires, légendes.
-- Garanties : toujours skippable (bouton « Passer », Entrée, Start), interrompue si le joueur meurt, entre en arène
-- ou si la manche démarre, protégée par pcall, caméra TOUJOURS restaurée. Réglages : Config.Cinematics.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent
local Config = require(Shared.Config)
local Lore = require(Shared.Lore)
local CinematicLogic = require(Shared.CinematicLogic)
local UI = require(Client.UI)
local State = require(Client.State)

local Cinematics = {}

local player = Players.LocalPlayer
local C = UI.Colors
local overlay
local playing = false
local skipRequested = false
local widgets = {}

local function seenKeyOf(name)
	return name == "season" and ("season" .. tostring(Config.Season.Id)) or name
end

local function buildOverlay(gui)
	overlay = UI.New("Frame", { Parent = gui, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60, Visible = false, Active = false })
	widgets.Top = UI.New("Frame", { Parent = overlay, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0.11, 0), ZIndex = 61 })
	widgets.Bottom = UI.New("Frame", { Parent = overlay, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.17, 0), ZIndex = 61 })
	widgets.Caption = UI.Label(overlay, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.9, -34), Size = UDim2.new(0.9, 0, 0, 52), Text = "", TextSize = 40, Font = Enum.Font.GothamBlack, ZIndex = 63, TextWrapped = true })
	widgets.Caption.TextStrokeTransparency = 0.3
	widgets.Sub = UI.Label(overlay, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.9, 0), Size = UDim2.new(0.8, 0, 0, 40), Text = "", TextSize = 18, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(230, 232, 240), ZIndex = 63, TextWrapped = true })
	widgets.Sub.TextStrokeTransparency = 0.5
	widgets.Bar = UI.New("Frame", { Parent = overlay, BackgroundColor3 = C.Gold, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(0, 0, 0, 4), ZIndex = 64 })
	widgets.Skip = UI.Button(overlay, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(130, 38), BackgroundColor3 = Color3.fromRGB(30, 33, 44), Text = "Passer  ›", TextSize = 16, ZIndex = 65 })
	widgets.Skip.Activated:Connect(function()
		skipRequested = true
	end)
	widgets.Fade = UI.New("Frame", { Parent = overlay, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 70 })
	UserInputService.InputBegan:Connect(function(input)
		if playing and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonStart) then
			skipRequested = true
		end
	end)
end

local function applyShot(shot)
	local text = shot.Caption:gsub("{SEASON}", string.upper(Config.Season.Name))
	local hero = shot.Hero and Lore.Hero(shot.Hero)
	widgets.Caption.Text = text
	widgets.Caption.TextColor3 = hero and Color3.fromHex(hero.Color) or C.Gold
	widgets.Sub.Text = shot.Sub
	widgets.Caption.TextTransparency, widgets.Sub.TextTransparency = 1, 1
	UI.Tween(widgets.Caption, 0.35, { TextTransparency = 0 })
	UI.Tween(widgets.Sub, 0.35, { TextTransparency = 0 })
end

local function camera()
	return workspace.CurrentCamera
end

local function interruptReason(name)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return "interrupted"
	end
	local inArena = player:GetAttribute("InArena") == true
	if name == "hill" then
		if workspace:GetAttribute("MatchState") ~= "Intermission" or not inArena then
			return "interrupted"
		end
	elseif inArena then
		return "interrupted" -- le joueur est entré dans l'arène : jamais bloqué par une cinématique
	end
	return nil
end

local function run(name, seq)
	local cam = camera()
	local state = CinematicLogic.New(seq)
	local lastIndex = 0
	skipRequested = false
	overlay.Visible = true
	widgets.Top.Visible, widgets.Bottom.Visible = true, true
	if seq.Camera then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	UI.Tween(widgets.Fade, Config.Cinematics.FadeSeconds, { BackgroundTransparency = 1 })
	while not state.Done do
		local dt = RunService.Heartbeat:Wait()
		local reason = interruptReason(name)
		if reason then
			CinematicLogic.End(state, reason)
		elseif skipRequested then
			CinematicLogic.Skip(state)
		else
			CinematicLogic.Step(state, dt)
		end
		if not state.Done then
			if state.Index ~= lastIndex then
				lastIndex = state.Index
				applyShot(seq.Shots[state.Index])
			end
			local shot = seq.Shots[state.Index]
			if seq.Camera and shot.From then
				local p = CinematicLogic.Lerp(shot.From, shot.To, CinematicLogic.ShotAlpha(state))
				cam.CFrame = CFrame.lookAt(Vector3.new(p[1], p[2], p[3]), Vector3.new(shot.Look[1], shot.Look[2], shot.Look[3]))
			end
			widgets.Bar.Size = UDim2.new(CinematicLogic.Progress(state), 0, 0, 4)
		end
	end
	return state
end

local function cleanup()
	local cam = camera()
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			cam.CameraSubject = humanoid
		end
	end
	if overlay then
		overlay.Visible = false
		widgets.Fade.BackgroundTransparency = 1
	end
	skipRequested = false
	playing = false
end

-- Joue une cinématique (bloque seulement le thread appelant). Renvoie la raison de fin ou nil.
function Cinematics.Play(name)
	if playing or not overlay then
		return nil
	end
	local seq = CinematicLogic.Sequences[name]
	if not seq then
		return nil
	end
	playing = true
	local ok, result = pcall(run, name, seq)
	cleanup() -- caméra et interface toujours restaurées, même après erreur
	if not ok then
		warn("[Cinematics] " .. name .. " : " .. tostring(result))
		return "error"
	end
	local reason = result.Reason
	if CinematicLogic.ShouldMarkSeen(reason) then
		local key = seenKeyOf(name)
		if State.Profile then
			State.Profile.Seen[key] = true
		end
		State.Request("MarkSeen", key)
	end
	return reason
end

function Cinematics.IsPlaying()
	return playing
end

-- Première connexion : intro, tutoriel, début de saison (selon ce qui a déjà été vu).
function Cinematics.Schedule()
	task.spawn(function()
		local waited = 0
		while (not State.Profile or not player.Character) and waited < 40 do
			task.wait(0.5)
			waited += 0.5
		end
		task.wait(1.5)
		for _ = 1, 4 do
			local profile = State.Profile
			if not profile then
				return
			end
			local ctx = { InArena = player:GetAttribute("InArena") == true, SeasonId = Config.Season.Id, NextMode = tostring(workspace:GetAttribute("NextMode")) }
			local nextName = CinematicLogic.NextToPlay(Config.Cinematics, profile.Seen or {}, { "intro", "tutorial", "season" }, ctx)
			if not nextName then
				return
			end
			local reason = Cinematics.Play(nextName)
			if not CinematicLogic.ShouldMarkSeen(reason) then
				return -- interrompue : on ne boucle pas, elle sera reproposée à la prochaine connexion
			end
			task.wait(0.6)
		end
	end)
end

-- Roi de la tour : courte présentation pendant l'intermission qui précède la première manche de ce mode.
local function checkHill()
	local profile = State.Profile
	if playing or not profile or workspace:GetAttribute("MatchState") ~= "Intermission" then
		return
	end
	local ctx = { InArena = player:GetAttribute("InArena") == true, SeasonId = Config.Season.Id, NextMode = tostring(workspace:GetAttribute("NextMode")) }
	if CinematicLogic.NextToPlay(Config.Cinematics, profile.Seen or {}, { "hill" }, ctx) then
		task.spawn(Cinematics.Play, "hill")
	end
end

function Cinematics.Init(gui)
	buildOverlay(gui)
	workspace:GetAttributeChangedSignal("MatchState"):Connect(checkHill)
	workspace:GetAttributeChangedSignal("NextMode"):Connect(checkHill)
	player:GetAttributeChangedSignal("InArena"):Connect(checkHill)
end

return Cinematics
