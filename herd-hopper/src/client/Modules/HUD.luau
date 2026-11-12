-- Interface de jeu : minuteur, score, combo, classement, mur de lave, dressage, bouton d'action,
-- messages (lasso, dressage, événements) et tableau des résultats.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)
local Controls = require(script.Parent.Controls)
local CameraRig = require(script.Parent.CameraRig)
local CreatureFx = require(script.Parent.CreatureFx)

local HUD = {}

local player = Players.LocalPlayer
local refs = {}
local feedbackToken = 0
local resultsToken = 0
local lastCountdown = -1
local lastWarnTick = 0
local lastCombo = 0

local KIND_STYLE = {
	hook = { color = UI.Colors.Accent },
	tame = { color = UI.Colors.Good, sound = "tame" },
	down = { color = UI.Colors.Bad, sound = "down", shake = 1.2 },
	out = { color = UI.Colors.Bad, sound = "down" },
	finish = { color = UI.Colors.Accent, sound = "win" },
	warn = { color = UI.Colors.Warn, sound = "tick" },
	buck = { color = UI.Colors.Warn, sound = "boom", shake = 1.0 },
	geyser = { color = UI.Colors.Info, sound = "geyser", shake = 0.8 },
	event = { color = UI.Colors.Info, sound = "go" },
	danger = { color = UI.Colors.Bad, sound = "boom", shake = 1.5 },
}

local function build(gui)
	local C = UI.Colors

	-- Bandeau du haut (phase / minuteur)
	local banner = UI.frame(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 330, 0, 46),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
	})
	UI.corner(banner, 14)
	UI.stroke(banner, C.Dark, 2)
	refs.bannerText =
		UI.text(banner, { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 8, 0, 4), maxSize = 26 })

	refs.hint = UI.text(gui, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(0, 420, 0, 26),
		maxSize = 18,
		TextColor3 = C.Muted,
		Font = UI.FontBody,
	})

	-- Score + combo (haut gauche)
	local score = UI.frame(gui, {
		Name = "ScoreBox",
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(0, 220, 0, 98),
		BackgroundTransparency = 0.15,
	})
	UI.corner(score, 14)
	UI.stroke(score, C.Dark, 2)
	UI.text(
		score,
		{
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.new(0, 8, 0, 4),
			Text = "SCORE",
			maxSize = 14,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}
	)
	refs.score = UI.text(
		score,
		{
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.new(0, 8, 0, 20),
			Text = "0",
			maxSize = 38,
			TextColor3 = C.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		}
	)
	refs.combo = UI.text(
		score,
		{
			Size = UDim2.new(1, -16, 0, 20),
			Position = UDim2.new(0, 8, 0, 62),
			Text = "",
			maxSize = 18,
			TextColor3 = C.Good,
			TextXAlignment = Enum.TextXAlignment.Left,
		}
	)
	local comboBar = UI.frame(
		score,
		{ Position = UDim2.new(0, 8, 1, -12), Size = UDim2.new(1, -16, 0, 6), BackgroundColor3 = C.Dark }
	)
	UI.corner(comboBar, 3)
	refs.comboFill = UI.frame(comboBar, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Good })
	UI.corner(refs.comboFill, 3)
	refs.scoreBox = score
	UI.make(
		"UIGradient",
		{ Color = ColorSequence.new(Color3.fromRGB(52, 62, 96), Color3.fromRGB(26, 31, 50)), Rotation = 90 },
		score
	)
	UI.make(
		"UIGradient",
		{ Color = ColorSequence.new(Color3.fromRGB(52, 62, 96), Color3.fromRGB(26, 31, 50)), Rotation = 90 },
		banner
	)

	-- Classement en direct (haut droite)
	local board = UI.frame(gui, {
		Name = "Board",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.new(0, 200, 0, 20 + 6 * 22),
		BackgroundTransparency = 0.2,
	})
	UI.corner(board, 14)
	UI.stroke(board, C.Dark, 2)
	UI.text(
		board,
		{
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.new(0, 8, 0, 2),
			Text = "CLASSEMENT",
			maxSize = 14,
			TextColor3 = C.Muted,
		}
	)
	refs.rows = {}
	for i = 1, 6 do
		refs.rows[i] = UI.text(board, {
			Size = UDim2.new(1, -16, 0, 20),
			Position = UDim2.new(0, 8, 0, 20 + (i - 1) * 22),
			maxSize = 16,
			Font = UI.FontBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			outline = false,
		})
	end
	refs.board = board

	-- Mur de lave
	local wallBox = UI.frame(gui, {
		Name = "WallBox",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.new(0, 300, 0, 26),
		BackgroundColor3 = C.Dark,
		BackgroundTransparency = 0.2,
	})
	UI.corner(wallBox, 13)
	UI.stroke(wallBox, C.Dark, 2)
	refs.wallFill = UI.frame(wallBox, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = C.Good })
	UI.corner(refs.wallFill, 13)
	refs.wallText =
		UI.text(wallBox, { Size = UDim2.new(1, -10, 1, -4), Position = UDim2.new(0, 5, 0, 2), maxSize = 16 })
	refs.wallBox = wallBox

	-- Danger : bordure rouge pulsante
	refs.danger = UI.frame(
		gui,
		{
			Name = "Danger",
			Position = UDim2.new(0, 8, 0, 8),
			Size = UDim2.new(1, -16, 1, -16),
			BackgroundTransparency = 1,
			Visible = false,
			Active = false,
		}
	)
	refs.dangerStroke =
		UI.make("UIStroke", { Color = Color3.fromRGB(255, 50, 30), Thickness = 16, Transparency = 1 }, refs.danger)

	-- Monture / dressage (bas centre)
	local ride = UI.frame(gui, {
		Name = "RideBox",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 300, 0, 62),
		BackgroundTransparency = 0.15,
	})
	UI.corner(ride, 14)
	UI.stroke(ride, C.Dark, 2)
	refs.rideName = UI.text(ride, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 4), maxSize = 22 })
	local tameBar = UI.frame(
		ride,
		{ Position = UDim2.new(0, 10, 0, 36), Size = UDim2.new(1, -20, 0, 16), BackgroundColor3 = C.Dark }
	)
	UI.corner(tameBar, 8)
	refs.tameFill = UI.frame(tameBar, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Good })
	UI.corner(refs.tameFill, 8)
	refs.tameText = UI.text(tameBar, { Size = UDim2.new(1, 0, 1, 0), maxSize = 12, Text = "DRESSAGE", outline = true })
	refs.rideBox = ride

	-- Bouton d'action (bas droite)
	local action = UI.button(gui, {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(0, 124, 0, 124),
		BackgroundColor3 = C.Accent,
		Text = "SAUTER",
		maxSize = 24,
	})
	local corner = action:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(1, 0)
	end
	Controls.bindButton(action)
	refs.action = action

	-- Bouton de son (tout / effets seuls / muet)
	local soundButton = UI.button(gui, {
		Name = "Sound",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -60),
		Size = UDim2.new(0, 150, 0, 34),
		Text = Sfx.modeLabel(),
		BackgroundColor3 = C.PanelLight,
		TextColor3 = C.Text,
		maxSize = 16,
	})
	soundButton.Activated:Connect(function()
		soundButton.Text = Sfx.cycleMode()
		Sfx.play("click")
	end)

	-- Message central (lasso, dressage...)
	local toast = UI.frame(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.new(0, 560, 0, 96),
		BackgroundTransparency = 1,
		Visible = false,
	})
	refs.toastTitle = UI.text(toast, { Size = UDim2.new(1, 0, 0, 56), maxSize = 52 })
	refs.toastSub = UI.text(
		toast,
		{ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 58), maxSize = 24, Font = UI.FontBody }
	)
	refs.toast = toast

	-- Compte à rebours
	refs.countdown = UI.text(gui, {
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		Size = UDim2.new(0, 240, 0, 160),
		maxSize = 150,
		TextColor3 = C.Accent,
		Visible = false,
	})

	-- Résultats
	local results = UI.frame(gui, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.92, 0, 0.8, 0),
		Visible = false,
		ZIndex = 20,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(560, 440) }, results)
	UI.corner(results, 18)
	UI.stroke(results, C.Accent, 3)
	UI.text(
		results,
		{
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.new(0, 10, 0, 8),
			Text = "RÉSULTATS DE LA MANCHE",
			maxSize = 32,
			TextColor3 = C.Accent,
			ZIndex = 21,
		}
	)
	refs.resultsList = UI.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 58),
		Size = UDim2.new(1, -20, 1, -118),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 21,
	}, results)
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.resultsList)
	local close = UI.button(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0, 160, 0, 40),
		Text = "FERMER",
		maxSize = 22,
		ZIndex = 22,
	})
	close.Activated:Connect(function()
		results.Visible = false
		Sfx.play("click")
	end)
	refs.results = results
end

-- ---------------------------------------------------------------------------
-- Mise à jour périodique
-- ---------------------------------------------------------------------------

local function wallDistance()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local wall = workspace:FindFirstChild("LavaWall")
	local root = wall and wall:FindFirstChild("Root")
	if hrp and root then
		return hrp.Position.Z - (root.Position.Z + 8)
	end
	return nil
end

local function updateScores()
	local list = ClientState.Scores
	for i = 1, 6 do
		local row = refs.rows[i]
		local entry = list[i]
		if entry then
			local you = entry.id == player.UserId
			row.Text = ("%d. %s  %s"):format(i, entry.n, Util.formatNumber(entry.s))
			row.TextColor3 = you and UI.Colors.Accent or UI.Colors.Text
			row.Visible = true
		else
			row.Visible = false
		end
	end
end

local function update()
	local phase = workspace:GetAttribute("Phase") or "Intermission"
	local waiting = workspace:GetAttribute("Waiting")
	local remaining = (workspace:GetAttribute("PhaseEnd") or 0) - workspace:GetServerTimeNow()
	local status = ClientState.Status
	local playing = ClientState.isPlaying()
	local running = phase == "Running"

	-- bandeau
	if phase == "Intermission" then
		refs.bannerText.Text = waiting and "En attente de joueurs..."
			or ("Prochaine manche : " .. Util.formatTime(remaining))
	elseif phase == "Countdown" then
		refs.bannerText.Text = "Prépare-toi !"
	elseif phase == "Running" then
		refs.bannerText.Text = "Temps restant : " .. Util.formatTime(remaining)
	else
		refs.bannerText.Text = "Résultats"
	end

	-- compte à rebours géant
	if phase == "Countdown" then
		local n = math.ceil(remaining)
		refs.countdown.Visible = true
		if n >= 1 then
			refs.countdown.Text = tostring(n)
			if n ~= lastCountdown then
				lastCountdown = n
				Sfx.play("tick")
			end
		else
			refs.countdown.Text = "GO !"
			if lastCountdown ~= 0 then
				lastCountdown = 0
				Sfx.play("go")
			end
		end
	else
		refs.countdown.Visible = false
		lastCountdown = -1
	end

	-- indications
	if running and status == "Lobby" then
		refs.hint.Text = "Manche en cours : tu joues à la prochaine !"
	elseif running and (status == "Out" or status == "Finished") then
		refs.hint.Text = status == "Finished" and "Arrivé ! Tu regardes la fin de la manche."
			or "Éliminé : tu regardes la course."
	elseif phase == "Intermission" then
		refs.hint.Text = "Ouvre la boutique ou le bestiaire en attendant."
	else
		refs.hint.Text = ""
	end

	-- blocs de jeu
	local showScore = playing or status == "Out" or status == "Finished"
	refs.scoreBox.Visible = showScore and (running or phase == "Countdown")
	refs.board.Visible = (running or phase == "Countdown") and #ClientState.Scores > 0
	refs.rideBox.Visible = status == "Riding"
	refs.action.Visible = playing
	refs.wallBox.Visible = playing and running

	if refs.scoreBox.Visible then
		refs.score.Text = Util.formatNumber(player:GetAttribute("RunScore") or 0)
		local combo = player:GetAttribute("Combo") or 0
		if combo ~= lastCombo then
			lastCombo = combo
			if combo >= 2 then
				-- petit "pop" à chaque palier de combo
				refs.combo.TextSize = 30
				UI.tween(refs.combo, 0.25, { TextSize = 20 }, Enum.EasingStyle.Back)
			end
		end
		if combo >= 2 then
			refs.combo.Text = ("COMBO x%.1f"):format(player:GetAttribute("ComboMult") or 1)
		else
			refs.combo.Text = ""
		end
		local left = player:GetAttribute("ComboLeft") or 0
		UI.tween(refs.comboFill, 0.1, { Size = UDim2.new(left, 0, 1, 0) })
	end

	if refs.rideBox.Visible then
		refs.rideName.Text = player:GetAttribute("RideName") or ""
		local progress = player:GetAttribute("TameProgress") or 0
		UI.tween(refs.tameFill, 0.1, { Size = UDim2.new(progress, 0, 1, 0) })
		refs.tameText.Text = progress >= 1 and "DOMPTÉ !" or "DRESSAGE"
	end

	-- bouton d'action contextuel
	if refs.action.Visible then
		if status == "Riding" then
			refs.action.Text = "SAUTER"
			refs.action.BackgroundColor3 = UI.Colors.Accent
		elseif status == "Air" or status == "Down" then
			refs.action.Text = "LASSO"
			-- le bouton brille quand une bête est à portée
			local ready = CreatureFx.hasTarget()
			refs.action.BackgroundColor3 = ready and UI.Colors.Accent or UI.Colors.Info
		else
			refs.action.Text = "..."
			refs.action.BackgroundColor3 = UI.Colors.Muted
		end
	end

	-- mur de lave
	local dist = wallDistance()
	if refs.wallBox.Visible and dist then
		local fraction = math.clamp(dist / 160, 0, 1)
		refs.wallFill.Size = UDim2.new(fraction, 0, 1, 0)
		refs.wallFill.BackgroundColor3 = dist < 35 and UI.Colors.Bad or (dist < 80 and UI.Colors.Warn or UI.Colors.Good)
		refs.wallText.Text = ("MUR DE LAVE : %d m"):format(math.max(0, math.floor(dist)))
		refs.danger.Visible = dist < 45
		if dist < 45 then
			if os.clock() - lastWarnTick > 0.9 - 0.5 * (1 - math.clamp(dist / 45, 0, 1)) then
				lastWarnTick = os.clock()
				Sfx.play("tick")
			end
			local pulse = (math.sin(os.clock() * 8) + 1) / 2
			refs.dangerStroke.Transparency = 1 - (1 - math.clamp(dist / 45, 0, 1)) * (0.35 + 0.35 * pulse)
		end
	else
		refs.danger.Visible = false
	end
end

-- ---------------------------------------------------------------------------
-- Messages et résultats
-- ---------------------------------------------------------------------------

function HUD.feedback(payload)
	if type(payload) ~= "table" then
		return
	end
	local style = KIND_STYLE[payload.kind] or KIND_STYLE.hook
	feedbackToken = feedbackToken + 1
	local token = feedbackToken

	refs.toastTitle.Text = tostring(payload.title or "")
	refs.toastTitle.TextColor3 = style.color
	refs.toastSub.Text = tostring(payload.sub or "")
	refs.toast.Position = UDim2.new(0.5, 0, 0.3, 14)
	refs.toast.Visible = true
	UI.tween(refs.toast, 0.18, { Position = UDim2.new(0.5, 0, 0.3, 0) }, Enum.EasingStyle.Back)

	if style.sound then
		Sfx.play(style.sound)
	end
	if style.shake then
		CameraRig.shake(style.shake, 0.4)
	end

	task.delay(payload.kind == "tame" and 2.4 or 1.6, function()
		if token == feedbackToken then
			refs.toast.Visible = false
		end
	end)
end

function HUD.showResults(payload)
	if type(payload) ~= "table" or type(payload.list) ~= "table" then
		return
	end
	for _, child in ipairs(refs.resultsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local myRank = nil
	for index, entry in ipairs(payload.list) do
		local you = entry.id == player.UserId
		if you then
			myRank = entry.rank
		end
		local row = UI.frame(refs.resultsList, {
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = you and UI.Colors.PanelLight or UI.Colors.Panel,
			LayoutOrder = index,
			ZIndex = 21,
		})
		UI.corner(row, 10)
		if you then
			UI.stroke(row, UI.Colors.Accent, 2)
		end
		UI.text(
			row,
			{
				Size = UDim2.new(0, 44, 1, 0),
				Text = "#" .. entry.rank,
				maxSize = 24,
				TextColor3 = entry.rank == 1 and UI.Colors.Accent or UI.Colors.Text,
				ZIndex = 22,
			}
		)
		UI.text(
			row,
			{
				Size = UDim2.new(0.42, 0, 1, -8),
				Position = UDim2.new(0, 48, 0, 4),
				Text = entry.n,
				maxSize = 20,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 22,
			}
		)
		UI.text(row, {
			Size = UDim2.new(0.3, 0, 1, -8),
			Position = UDim2.new(0.5, 0, 0, 4),
			Text = Util.formatNumber(entry.score) .. " pts",
			maxSize = 20,
			TextColor3 = UI.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,
		})
		UI.text(row, {
			Size = UDim2.new(0.2, -8, 1, -8),
			Position = UDim2.new(0.8, 0, 0, 4),
			Text = "+" .. entry.coins,
			maxSize = 18,
			TextColor3 = UI.Colors.Good,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,
		})
	end

	refs.results.Visible = true
	if myRank == 1 then
		Sfx.play("win")
	else
		Sfx.play("coin")
	end

	resultsToken = resultsToken + 1
	local token = resultsToken
	task.delay(Config.Round.Results + 1, function()
		if token == resultsToken then
			refs.results.Visible = false
		end
	end)
end

function HUD.init()
	local gui = UI.make("ScreenGui", {
		Name = "HerdHopperHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	build(gui)

	ClientState.connect("Scores", updateScores)
	updateScores()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		if accumulator >= 0.1 then
			accumulator = 0
			update()
		end
	end)
end

return HUD
