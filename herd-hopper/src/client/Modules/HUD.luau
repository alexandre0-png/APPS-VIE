-- Interface d'expédition : minuteur, score, vies, lassos, combo, classement, confiance de l'animal monté,
-- boutons (sauter / lasso, récupérer, lasso de capture), messages, écran « Continuer ? » et résultats.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)
local Controls = require(script.Parent.Controls)
local CameraRig = require(script.Parent.CameraRig)
local CreatureFx = require(script.Parent.CreatureFx)
local Anim = require(script.Parent.Anim)

local HUD = {}

local player = Players.LocalPlayer
local refs = {}
local feedbackToken = 0
local resultsToken = 0
local lastCountdown = -1
local lastWarnTick = 0
local lastCombo = 0
local lastRound = -1
local builtLives = 0
local PINK = Color3.fromRGB(255, 96, 160)

local TIPS = {
	"Ouvre EXPÉDITION pour partir. Le zoo travaille pendant ce temps.",
	"Astuce : un cœur rose au-dessus d'un animal = tu peux le récupérer.",
	"Astuce : monte l'animal quelques secondes, puis appuie sur RÉCUPÉRER.",
	"Astuce : le lasso de capture attrape un animal à cœur à distance.",
	"Astuce : maintiens ESPACE en l'air pour lasser le prochain animal.",
	"Astuce : un doublon rapporte des os pour améliorer tes animaux.",
	"Astuce : le sol est mortel. Ne rate pas ton saut !",
}

local KIND_STYLE = {
	hook = { color = UI.Colors.Accent },
	tame = { color = PINK, sound = "heart" },
	down = { color = UI.Colors.Bad, sound = "down", shake = 1.2 },
	out = { color = UI.Colors.Bad, sound = "down" },
	finish = { color = UI.Colors.Accent, sound = "win" },
	warn = { color = UI.Colors.Warn, sound = "tick" },
	buck = { color = UI.Colors.Warn, sound = "boom", shake = 1.0 },
	geyser = { color = UI.Colors.Info, sound = "geyser", shake = 0.8 },
	event = { color = UI.Colors.Info, sound = "go" },
	danger = { color = UI.Colors.Bad, sound = "boss", shake = 1.5 },
}

local function roundButton(gui, props)
	local b = UI.button(gui, props)
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(1, 0)
	end
	return b
end

local function build(gui)
	local C = UI.Colors
	local panelGradient = ColorSequence.new(Color3.fromRGB(52, 62, 96), Color3.fromRGB(26, 31, 50))

	-- Bandeau du haut (phase / minuteur)
	local banner = UI.frame(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(0, 330, 0, 46),
		BackgroundTransparency = 0.15,
	})
	UI.corner(banner, 14)
	UI.stroke(banner, C.Dark, 2)
	UI.make("UIGradient", { Color = panelGradient, Rotation = 90 }, banner)
	refs.bannerText =
		UI.text(banner, { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.new(0, 8, 0, 4), maxSize = 26 })

	refs.hint = UI.text(gui, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(0, 480, 0, 26),
		maxSize = 18,
		TextColor3 = C.Muted,
		Font = UI.FontBody,
	})

	refs.zone = UI.text(gui, {
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(0, 360, 0, 24),
		maxSize = 20,
		TextColor3 = C.Info,
	})

	-- Score, or, vies et lassos (haut gauche)
	local score = UI.frame(gui, {
		Name = "ScoreBox",
		Position = UDim2.new(0, 12, 0, 10),
		Size = UDim2.new(0, 230, 0, 150),
		BackgroundTransparency = 0.15,
	})
	UI.corner(score, 14)
	UI.stroke(score, C.Dark, 2)
	UI.make("UIGradient", { Color = panelGradient, Rotation = 90 }, score)
	UI.text(score, {
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.new(0, 8, 0, 4),
		Text = "SCORE",
		maxSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.score = UI.text(score, {
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.new(0, 8, 0, 18),
		Text = "0",
		maxSize = 34,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.combo = UI.text(score, {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 8, 0, 56),
		Text = "",
		maxSize = 16,
		TextColor3 = C.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.comboScale = UI.make("UIScale", { Scale = 1 }, refs.combo)
	local comboBar = UI.frame(
		score,
		{ Position = UDim2.new(0, 8, 0, 76), Size = UDim2.new(1, -16, 0, 6), BackgroundColor3 = C.Dark }
	)
	UI.corner(comboBar, 3)
	refs.comboFill = UI.frame(comboBar, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Good })
	UI.corner(refs.comboFill, 3)
	refs.runGold = UI.text(score, {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 8, 0, 86),
		Text = "",
		maxSize = 16,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.livesLabel = UI.text(score, {
		Size = UDim2.new(0, 52, 0, 18),
		Position = UDim2.new(0, 8, 0, 110),
		Text = "VIES",
		maxSize = 14,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.livesRow = UI.frame(
		score,
		{ Position = UDim2.new(0, 62, 0, 104), Size = UDim2.new(1, -70, 0, 28), BackgroundTransparency = 1 }
	)
	UI.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, refs.livesRow)
	refs.lassoText = UI.text(score, {
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.new(0, 8, 1, -20),
		Text = "",
		maxSize = 14,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.scoreBox = score

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
	UI.text(board, {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 8, 0, 2),
		Text = "CLASSEMENT",
		maxSize = 14,
		TextColor3 = C.Muted,
	})
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

	-- Danger : bordure rouge quand on est en l'air près du sol mortel
	refs.danger = UI.frame(gui, {
		Name = "Danger",
		Position = UDim2.new(0, 8, 0, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
	})
	refs.dangerStroke =
		UI.make("UIStroke", { Color = Color3.fromRGB(255, 50, 30), Thickness = 16, Transparency = 1 }, refs.danger)

	-- Animal monté (bas centre) : confiance et cœur
	local ride = UI.frame(gui, {
		Name = "RideBox",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 320, 0, 70),
		BackgroundTransparency = 0.15,
	})
	UI.corner(ride, 14)
	UI.stroke(ride, C.Dark, 2)
	UI.make("UIGradient", { Color = panelGradient, Rotation = 90 }, ride)
	refs.rideName = UI.text(ride, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, 4), maxSize = 22 })
	local tameBar = UI.frame(
		ride,
		{ Position = UDim2.new(0, 10, 0, 38), Size = UDim2.new(1, -20, 0, 20), BackgroundColor3 = C.Dark }
	)
	UI.corner(tameBar, 10)
	refs.tameFill = UI.frame(tameBar, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = PINK })
	UI.corner(refs.tameFill, 10)
	refs.tameText =
		UI.text(tameBar, { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 22, 0, 0), maxSize = 13, Text = "" })
	local barHeart = UI.heart(tameBar, 16, Color3.fromRGB(255, 255, 255))
	barHeart.Position = UDim2.new(0, 3, 0.5, -8)
	refs.tameBar = tameBar
	refs.rideBox = ride

	-- Bouton d'action (bas droite)
	local action = roundButton(gui, {
		Name = "Action",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(0, 124, 0, 124),
		BackgroundColor3 = C.Accent,
		Text = "SAUTER",
		maxSize = 24,
	})
	Controls.bindButton(action)
	refs.action = action

	-- Récupérer (au-dessus de l'action)
	local collect = roundButton(gui, {
		Name = "Collect",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -160),
		Size = UDim2.new(0, 112, 0, 112),
		BackgroundColor3 = PINK,
		Text = "RÉCUPÉRER",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		maxSize = 18,
		Visible = false,
	})
	refs.collectScale = UI.make("UIScale", { Scale = 1 }, collect)
	collect.Activated:Connect(Controls.collect)
	refs.collect = collect

	-- Lasso de capture (à gauche de l'action)
	local lasso = roundButton(gui, {
		Name = "Lasso",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -164, 1, -30),
		Size = UDim2.new(0, 92, 0, 92),
		BackgroundColor3 = C.PanelLight,
		TextColor3 = C.Text,
		Text = "LASSO",
		maxSize = 18,
	})
	lasso.Activated:Connect(Controls.lasso)
	refs.lasso = lasso

	-- Bouton de son
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

	-- Message central
	local toast = UI.frame(gui, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.new(0, 600, 0, 96),
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

	-- Écran « Continuer ? » après une mort
	local revive = UI.frame(gui, {
		Name = "Revive",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 380, 0, 190),
		Visible = false,
		ZIndex = 15,
	})
	UI.corner(revive, 18)
	UI.stroke(revive, C.Bad, 3)
	UI.text(revive, {
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.new(0, 10, 0, 10),
		Text = "TOMBÉ !",
		maxSize = 38,
		TextColor3 = C.Bad,
		ZIndex = 16,
	})
	refs.reviveText = UI.text(revive, {
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 56),
		Text = "",
		maxSize = 20,
		Font = UI.FontBody,
		ZIndex = 16,
	})
	local reviveButton = UI.button(revive, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 280, 0, 54),
		Text = "CONTINUER (Robux)",
		BackgroundColor3 = C.Good,
		maxSize = 22,
		ZIndex = 16,
	})
	reviveButton.Activated:Connect(function()
		Remotes.Prompt:FireServer("product", "revive")
		Sfx.play("click")
	end)
	refs.revive = revive

	-- Résultats
	local results = UI.frame(gui, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.94, 0, 0.84, 0),
		Visible = false,
		ZIndex = 20,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(620, 470) }, results)
	UI.corner(results, 18)
	UI.stroke(results, C.Accent, 3)
	UI.text(results, {
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.new(0, 10, 0, 8),
		Text = "BILAN DE L'EXPÉDITION",
		maxSize = 30,
		TextColor3 = C.Accent,
		ZIndex = 21,
	})
	refs.resultsList = UI.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, 52),
		Size = UDim2.new(1, -20, 1, -150),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 21,
	}, results)
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.resultsList)
	refs.resultsCaptures = UI.text(results, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -58),
		Size = UDim2.new(1, -28, 0, 44),
		Text = "",
		maxSize = 16,
		Font = UI.FontBody,
		TextColor3 = PINK,
		ZIndex = 21,
	})
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

local function rebuildLives(maxLives, lives)
	if builtLives ~= maxLives then
		builtLives = maxLives
		for _, child in ipairs(refs.livesRow:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		refs.hearts = {}
		for i = 1, maxLives do
			local heart = UI.heart(refs.livesRow, 24, PINK)
			heart.LayoutOrder = i
			refs.hearts[i] = heart
		end
	end
	for i, heart in ipairs(refs.hearts or {}) do
		local color = i <= lives and PINK or Color3.fromRGB(70, 74, 90)
		for _, part in ipairs(heart:GetChildren()) do
			if part:IsA("Frame") then
				part.BackgroundColor3 = color
			end
		end
	end
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
	local playing = ClientState.isPlaying() or status == "Dead"
	local running = phase == "Running"
	local ready = workspace:GetAttribute("ReadyCount") or 0

	-- bandeau
	if phase == "Intermission" then
		refs.bannerText.Text = waiting and "Personne n'est parti" or ("Départ dans " .. Util.formatTime(remaining))
	elseif phase == "Countdown" then
		refs.bannerText.Text = "Prépare-toi !"
	elseif phase == "Running" then
		refs.bannerText.Text = "Temps restant : " .. Util.formatTime(remaining)
	else
		refs.bannerText.Text = "Bilan"
	end

	-- compte à rebours géant + nom de la zone
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
		local round = workspace:GetAttribute("Round") or 0
		if round ~= lastRound and ClientState.isPlaying() then
			lastRound = round
			local zone = Config.Zones[workspace:GetAttribute("StartZone") or 1]
			HUD.feedback({
				kind = "event",
				title = zone.name,
				sub = "Danger : " .. zone.hazard.name .. ". Ne touche pas le sol !",
			})
			Anim.zoneIntro()
		end
	else
		refs.countdown.Visible = false
		lastCountdown = -1
	end

	-- indications
	if running and status == "Lobby" then
		refs.hint.Text = "Une expédition est en cours : ton zoo travaille, rejoins la suivante."
	elseif running and (status == "Out" or status == "Finished") then
		refs.hint.Text = status == "Finished" and "Expédition terminée !" or "Tu regardes la suite de l'expédition."
	elseif phase == "Intermission" then
		refs.hint.Text = waiting and "Choisis une zone dans EXPÉDITION et appuie sur PARTIR."
			or ("%d prêt(s). Tu peux encore te préparer."):format(ready)
		if not waiting then
			refs.hint.Text = TIPS[math.floor(os.clock() / 6) % #TIPS + 1]
		end
	else
		refs.hint.Text = ""
	end

	-- blocs de jeu
	local showScore = playing or status == "Out" or status == "Finished"
	refs.scoreBox.Visible = showScore and (running or phase == "Countdown")
	refs.board.Visible = (running or phase == "Countdown") and #ClientState.Scores > 0
	refs.rideBox.Visible = status == "Riding"
	refs.action.Visible = ClientState.isPlaying()
	refs.lasso.Visible = ClientState.isPlaying()
	refs.zone.Visible = playing and running

	if refs.scoreBox.Visible then
		refs.score.Text = Util.formatNumber(player:GetAttribute("RunScore") or 0)
		local combo = player:GetAttribute("Combo") or 0
		if combo ~= lastCombo then
			lastCombo = combo
			if combo >= 2 then
				refs.comboScale.Scale = 1.4
				UI.tween(refs.comboScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		refs.combo.Text = combo >= 2 and ("COMBO x%.1f"):format(player:GetAttribute("ComboMult") or 1) or ""
		UI.tween(refs.comboFill, 0.1, { Size = UDim2.new(player:GetAttribute("ComboLeft") or 0, 0, 1, 0) })
		refs.runGold.Text = ("Or gagné : %s · animaux : %d"):format(
			Util.formatNumber(player:GetAttribute("RunGold") or 0),
			player:GetAttribute("Captures") or 0
		)
		rebuildLives(player:GetAttribute("MaxLives") or 1, player:GetAttribute("Lives") or 1)
		refs.lassoText.Text = ("Lassos de capture : %d  (Q)"):format(player:GetAttribute("Lasso") or 0)
		local zoneIdx = player:GetAttribute("ZoneIdx") or 1
		refs.zone.Text = ("ZONE %d · %s"):format(zoneIdx, Config.Zones[zoneIdx].name)
	end

	-- animal monté
	if refs.rideBox.Visible then
		local name = player:GetAttribute("RideName") or ""
		local hearted = player:GetAttribute("RideHeart") == true
		local boss = player:GetAttribute("RideBoss") == true
		refs.rideName.Text = boss and ("BOSS · " .. name) or name
		refs.tameBar.Visible = hearted
		if hearted then
			local progress = player:GetAttribute("TameProgress") or 0
			UI.tween(refs.tameFill, 0.1, { Size = UDim2.new(progress, 0, 1, 0) })
			refs.tameText.Text = player:GetAttribute("CanCollect") and "RÉCUPÈRE-LE !" or "CONFIANCE"
		else
			refs.rideName.Text = refs.rideName.Text .. " (pas de cœur)"
		end
	end

	-- bouton d'action contextuel
	if refs.action.Visible then
		if status == "Riding" then
			refs.action.Text = "SAUTER"
			refs.action.BackgroundColor3 = UI.Colors.Accent
		elseif status == "Air" or status == "Down" then
			refs.action.Text = "LASSO DE SAUT"
			refs.action.BackgroundColor3 = CreatureFx.hasTarget() and UI.Colors.Accent or UI.Colors.Info
		else
			refs.action.Text = "..."
			refs.action.BackgroundColor3 = UI.Colors.Muted
		end
	end

	-- récupérer / lasso de capture
	local canCollect = player:GetAttribute("CanCollect") == true and status == "Riding"
	refs.collect.Visible = canCollect
	if canCollect then
		refs.collectScale.Scale = 1 + math.sin(os.clock() * 9) * 0.07
	end
	if refs.lasso.Visible then
		local charges = player:GetAttribute("Lasso") or 0
		local aimed = CreatureFx.lassoTarget() ~= nil
		refs.lasso.Text = ("LASSO\nx%d"):format(charges)
		refs.lasso.BackgroundColor3 = (aimed and charges > 0) and PINK or UI.Colors.PanelLight
	end

	-- sol mortel : bordure rouge quand on est bas en l'air
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local low = hrp ~= nil and (status == "Air") and hrp.Position.Y < 11 and hrp.Position.Y < 150
	refs.danger.Visible = low
	if low then
		refs.dangerStroke.Transparency = 0.45 + 0.2 * math.sin(os.clock() * 14)
		if os.clock() - lastWarnTick > 0.35 then
			lastWarnTick = os.clock()
			Sfx.play("tick")
		end
	end

	-- continuer après une mort
	local reviveLeft = player:GetAttribute("ReviveLeft") or 0
	refs.revive.Visible = status == "Dead" and reviveLeft > 0
	if refs.revive.Visible then
		refs.reviveText.Text = ("Continuer avec une vie de plus ? (%d s)"):format(reviveLeft)
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
	if payload.kind == "danger" and tostring(payload.title):sub(1, 4) == "BOSS" then
		Anim.bossPunch()
	end

	task.delay(payload.kind == "tame" and 2.6 or 1.8, function()
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
	local mine = nil
	for index, entry in ipairs(payload.list) do
		local you = entry.id == player.UserId
		if you then
			myRank = entry.rank
			mine = entry
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
		UI.text(row, {
			Size = UDim2.new(0, 44, 1, 0),
			Text = "#" .. entry.rank,
			maxSize = 24,
			TextColor3 = entry.rank == 1 and UI.Colors.Accent or UI.Colors.Text,
			ZIndex = 22,
		})
		UI.text(row, {
			Size = UDim2.new(0.36, 0, 1, -8),
			Position = UDim2.new(0, 48, 0, 4),
			Text = entry.n,
			maxSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		})
		UI.text(row, {
			Size = UDim2.new(0.24, 0, 1, -8),
			Position = UDim2.new(0.42, 0, 0, 4),
			Text = Util.formatNumber(entry.score) .. " pts",
			maxSize = 18,
			TextColor3 = UI.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,
		})
		UI.text(row, {
			Size = UDim2.new(0.3, -8, 1, -8),
			Position = UDim2.new(0.68, 0, 0, 4),
			Text = ("+%s or  ·  %d animaux"):format(Util.formatNumber(entry.gold), entry.captures),
			maxSize = 16,
			TextColor3 = UI.Colors.Good,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,
		})
	end

	if mine and #mine.names > 0 then
		refs.resultsCaptures.Text = ("Nouveaux pensionnaires : %s. Os gagnés : %d."):format(
			table.concat(mine.names, ", "),
			mine.bones
		)
	else
		refs.resultsCaptures.Text = "Aucun animal récupéré cette fois. Cherche les cœurs roses !"
	end

	refs.results.Visible = true
	Sfx.play(myRank == 1 and "win" or "coin")

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
