--!nonstrict
-- Cinématiques : séquences de caméra courtes, skippables, jamais bloquantes.
-- Sécurités : pcall autour de chaque lecture, durée maximale, bouton « Passer », arrêt si le joueur se déplace,
-- et restauration systématique de la caméra (même en cas d'erreur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CinematicLogic = require(Shared:WaitForChild("CinematicLogic"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)

local Cinematics = {}

local logic = CinematicLogic.new(Config.Cinematics)
local localSeen: { [string]: boolean } = {}
local gui: ScreenGui? = nil
local cleanup: (() -> ())? = nil

local function restoreCamera()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
end

local function buildUi(onSkip: () -> ()): (Frame, TextLabel)
	gui = Instance.new("ScreenGui")
	gui.Name = "FestinCinematic"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = UIKit.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local top = UIKit.frame(root, { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0) })
	local bottom = UIKit.frame(root, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0) })
	-- Bandes noires « cinéma ».
	TweenService:Create(top, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
	TweenService:Create(bottom, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()

	local caption = UIKit.label(root, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.88, -10),
		Size = UDim2.new(0.8, 0, 0, 60),
		Text = "",
		TextSize = 26,
		Font = Enum.Font.FredokaOne,
		TextStrokeTransparency = 0,
		ZIndex = 5,
	})
	local skip = UIKit.button(root, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -14),
		Size = UDim2.fromOffset(150, 46),
		Text = "Passer ⏭",
		TextSize = 18,
		BackgroundColor3 = Color3.fromRGB(60, 60, 75),
		ZIndex = 6,
		Callback = onSkip,
	})
	skip.Active = true
	return root, caption
end

local function markSeen(id: string)
	localSeen[id] = true
	-- Seules les cinématiques « une fois » sont mémorisées (le serveur valide aussi l'identifiant).
	if table.find(Config.Cinematics.Once, id) then
		task.spawn(function()
			Store.request("cinematicSeen", { id = id })
		end)
	end
end

-- Lance la cinématique `id` (séquence optionnelle fournie pour les plans dynamiques). Retourne true si lancée.
function Cinematics.play(id: string, sequence: any?): boolean
	local seq = sequence or Config.Cinematics.Sequences[id]
	if not seq then
		return false
	end
	local seen = {}
	if Store.state and Store.state.seen then
		for k, v in pairs(Store.state.seen) do
			seen[k] = v
		end
	end
	for k in pairs(localSeen) do
		seen[k] = true
	end
	local ok, duration = logic:start(id, os.clock(), seen, seq)
	if not ok then
		return false
	end
	markSeen(id)

	local started = pcall(function()
		local cam = workspace.CurrentCamera
		local stopped = false
		local conn: RBXScriptConnection? = nil
		local lastShot = 0

		local function stop()
			if stopped then
				return
			end
			stopped = true
			if conn then
				conn:Disconnect()
			end
			if gui then
				gui:Destroy()
				gui = nil
			end
			restoreCamera()
			logic:finish()
			cleanup = nil
		end
		cleanup = stop

		local _, caption = buildUi(function()
			logic:skip()
			stop()
		end)
		cam.CameraType = Enum.CameraType.Scriptable

		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		conn = RunService.RenderStepped:Connect(function()
			local okFrame = pcall(function()
				local state, elapsed = logic:update(os.clock())
				if state ~= "playing" then
					stop()
					return
				end
				-- Bouger le personnage coupe la cinématique : le joueur n'est jamais bloqué.
				if Config.Cinematics.SkipOnMove and hum and elapsed > Config.Cinematics.SkipGrace and hum.MoveDirection.Magnitude > 0.1 then
					logic:skip()
					stop()
					return
				end
				local index, t = CinematicLogic.shotAt(seq, elapsed)
				local shot = seq[index]
				local pos, look = CinematicLogic.camera(shot, t)
				cam.CFrame = CFrame.lookAt(Vector3.new(pos[1], pos[2], pos[3]), Vector3.new(look[1], look[2], look[3]))
				cam.FieldOfView = shot.Fov or 60
				if index ~= lastShot then
					lastShot = index
					caption.Text = shot.Text or ""
					if shot.Sfx then
						UIKit.sfx(shot.Sfx, 0.7)
					end
				end
			end)
			if not okFrame then
				logic:finish()
				stop()
			end
		end)
		-- Filet de sécurité : fin forcée même si l'image ne se met plus à jour.
		task.delay(duration + 1, stop)
	end)
	if not started then
		logic:finish()
		if cleanup then
			cleanup()
		end
		restoreCamera()
		return false
	end
	return true
end

function Cinematics.skip()
	if logic:skip() and cleanup then
		cleanup()
	end
end

-- ---------------------------------------------------------------- déclencheurs

local function dynamicSequence(id: string, replacements: { [string]: string }): any
	local base = Config.Cinematics.Sequences[id]
	local seq = {}
	for i, shot in ipairs(base) do
		local copy = table.clone(shot)
		local text = copy.Text or ""
		for key, value in pairs(replacements) do
			text = string.gsub(text, "{" .. key .. "}", function()
				return value
			end)
		end
		copy.Text = text
		seq[i] = copy
	end
	return seq
end

local function zoneSequence(def: any): any
	local P = def.Pos
	local seq = dynamicSequence("zone", { zone = def.Zone })
	local shifts = {
		{ from = { 0, 60, 60 }, to = { 0, 35, 40 }, look = { 0, 4, 0 } },
		{ from = { 30, 20, 30 }, to = { -30, 20, 30 }, look = { 0, 4, 0 } },
		{ from = { 0, 10, 40 }, to = { 0, 6, 18 }, look = { 0, 3, 0 } },
	}
	for i, shot in ipairs(seq) do
		local s = shifts[i]
		shot.From = { P[1] + s.from[1], P[2] + s.from[2], P[3] + s.from[3] }
		shot.To = { P[1] + s.to[1], P[2] + s.to[2], P[3] + s.to[3] }
		shot.Look = { P[1] + s.look[1], P[2] + s.look[2], P[3] + s.look[3] }
	end
	return seq
end

function Cinematics.init()
	local state = ReplicatedStorage:WaitForChild("GameState")
	local lastStage = state:GetAttribute("Stage") or 1
	local stages = Config.Dino.Stages

	-- Introduction (première visite) et zones débloquées.
	local introScheduled = false
	Store.onChange(function(s)
		if not introScheduled then
			introScheduled = true
			task.delay(4, function()
				pcall(Cinematics.play, "intro")
			end)
		end
		local Economy = require(Shared:WaitForChild("Economy"))
		local level = Economy.level(s.totalFed)
		for id, def in pairs(Config.Cinematics.Flags.Zone and Config.Chests or {}) do
			if level >= def.MinLevel and s.rebirths >= def.MinRebirths and not (s.seen and s.seen["zone_" .. id]) and not localSeen["zone_" .. id] then
				pcall(function()
					Cinematics.play("zone_" .. id, zoneSequence(def))
				end)
			end
		end
	end)

	-- Nouveau stade du T-Rex.
	state:GetAttributeChangedSignal("Stage"):Connect(function()
		local stage = state:GetAttribute("Stage") or 1
		if stage > lastStage then
			lastStage = stage
			if stage < Config.Cinematics.StageUpFrom then
				return
			end
			pcall(function()
				Cinematics.play("stageUp", dynamicSequence("stageUp", { story = Config.Story[stage] or "" }))
			end)
		end
	end)

	-- Première marée de sauce.
	state:GetAttributeChangedSignal("EventPhase"):Connect(function()
		if state:GetAttribute("EventId") == "sauce" and state:GetAttribute("EventPhase") == "warning" then
			pcall(Cinematics.play, "sauce")
		end
	end)

	-- Fin du festin : conclusion de l'histoire au festin du dernier stade, sinon victoire (avec repos).
	Remotes.get("FeastFx").OnClientEvent:Connect(function(finishedStageName)
		task.delay(0.6, function()
			local finalName = stages[#stages].Name
			if finishedStageName == finalName then
				if not pcall(Cinematics.play, "ending") then
					return
				end
				if not logic.playing then
					pcall(Cinematics.play, "victory")
				end
			else
				pcall(Cinematics.play, "victory")
			end
		end)
	end)
end

return Cinematics
