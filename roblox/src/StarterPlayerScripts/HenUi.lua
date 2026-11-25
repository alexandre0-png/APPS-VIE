-- ModuleScript : StarterPlayerScripts/HenUi
-- REFONTE lot 6 : interface de l'énigme de la Mère Poule. Tout est local au joueur et sous pcall ; le serveur reste autoritaire (le client n'envoie que
-- des intentions : « henGo », « henExplain », « henHint », « henReplay »).
--  - bulle de dialogue en bas (texte écrit à Config.HEN.bubbleCps caractères/s, « Suivant », boutons selon le contexte, passable) ;
--  - « ❗ » doré au-dessus de la Mère Poule (visible à Config.HEN.alertRange studs) tant que l'énigme est disponible et non faite ;
--  - plumes dorées : cachées localement chez qui les a ramassées, scintillement + son « secret » à moins de 40 studs ;
--  - berceuse : les pierres brillent dans l'ordre (une note par pierre), retour des touches, bouton « 🔁 Réécouter » ;
--  - cible du faisceau jaune (Riddle.guide) et texte de la carte d'objectif.
-- Léger pour mobile : une boucle à 2,5 Hz sur 4 plumes, une seule bulle réutilisée, un seul Highlight par pierre.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local HenUi = {}

local function num(v)
	return type(v) == "number" and v == v
end

function HenUi.start(ctx)
	local Config, Riddle, player, make, corner, COL, FONT = ctx.Config, ctx.Riddle, ctx.player, ctx.make, ctx.corner, ctx.COL, ctx.FONT
	local H = Config.HEN
	local RAction, RHen, playSound = ctx.RAction, ctx.RHen, ctx.playSound
	local self = {}
	local state = nil
	local dlg = nil -- { pages, buttons, i, typing, token }
	local token = 0

	local function henState()
		return state and type(state.hen) == "table" and state.hen or nil
	end
	local function myRoot()
		local char = player.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	---------------------------------------------------------------- Bulle de dialogue
	local frame, nameLbl, textLbl, nextBtn, btnRow, overlay, pill, pillLbl, replayBtn
	local okBuild = pcall(function()
		frame = make("Frame", { Name = "HenBubble", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.new(0.94, 0, 0, 150), BackgroundColor3 = COL.bg, BackgroundTransparency = 0.05, Visible = false, ZIndex = 20 }, ctx.gui)
		corner(frame, 16)
		make("UIStroke", { Color = COL.yellow, Thickness = 2 }, frame)
		make("UISizeConstraint", { MaxSize = Vector2.new(620, 170) }, frame)
		overlay = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 21 }, frame)
		make("TextLabel", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, Text = "🐔", TextSize = 40, Font = FONT, ZIndex = 22 }, frame)
		nameLbl = make("TextLabel", { Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -76, 0, 20), BackgroundTransparency = 1, Text = "Mère Poule", TextSize = 15, Font = FONT, TextColor3 = COL.yellow, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, frame)
		textLbl = make("TextLabel", { Position = UDim2.fromOffset(66, 28), Size = UDim2.new(1, -78, 0, 76), BackgroundTransparency = 1, Text = "", TextSize = 17, Font = Enum.Font.GothamMedium, TextColor3 = COL.text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 22 }, frame)
		nextBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(100, 32), BackgroundColor3 = COL.yellow, Text = "Suivant ▶", TextSize = 15, Font = FONT, TextColor3 = COL.dark, ZIndex = 23 }, frame)
		corner(nextBtn, 16)
		btnRow = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -120, 0, 34), BackgroundTransparency = 1, ZIndex = 23 }, frame)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, btnRow)
		-- pastille de la berceuse (étape 3) : consigne + « 🔁 Réécouter »
		pill = make("Frame", { Name = "HenLullaby", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(330, 40), BackgroundColor3 = COL.bg, BackgroundTransparency = 0.1, Visible = false, ZIndex = 18 }, ctx.gui)
		corner(pill, 20)
		make("UIStroke", { Color = COL.yellow, Thickness = 2 }, pill)
		pillLbl = make("TextLabel", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1, Text = "", TextSize = 13, Font = FONT, TextColor3 = COL.text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 19 }, pill)
		replayBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(112, 30), BackgroundColor3 = COL.yellow, Text = "🔁 Réécouter", TextSize = 13, Font = FONT, TextColor3 = COL.dark, ZIndex = 19 }, pill)
		corner(replayBtn, 15)
	end)

	local function clearButtons()
		if not btnRow then
			return
		end
		for _, c in ipairs(btnRow:GetChildren()) do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
	end

	local function close()
		token = token + 1
		dlg = nil
		if frame then
			frame.Visible = false
		end
	end
	self.close = close

	local function controls()
		if not dlg or not frame then
			return
		end
		local last = dlg.i >= #dlg.pages
		nextBtn.Visible = not last or #dlg.buttons == 0
		nextBtn.Text = last and "OK" or "Suivant ▶"
		btnRow.Visible = last and #dlg.buttons > 0
	end

	local function typePage()
		if not dlg then
			return
		end
		local d = dlg
		local mine = token
		local full = d.pages[d.i] or ""
		textLbl.Text = full
		d.typing = true
		textLbl.MaxVisibleGraphemes = 0
		controls()
		task.spawn(function()
			local t0 = os.clock()
			local total = utf8.len(full) or #full
			while dlg == d and token == mine and d.typing do
				local n = math.floor((os.clock() - t0) * H.bubbleCps)
				if n >= total then
					break
				end
				textLbl.MaxVisibleGraphemes = n
				task.wait(0.05)
			end
			if dlg == d and token == mine then
				d.typing = false
				textLbl.MaxVisibleGraphemes = -1
				controls()
				if #d.buttons == 0 and d.i >= #d.pages then -- réplique sans bouton : se referme seule
					task.delay(7, function()
						if dlg == d and token == mine then
							close()
						end
					end)
				end
			end
		end)
	end

	local function advance()
		if not dlg then
			return
		end
		if dlg.typing then
			dlg.typing = false
			textLbl.MaxVisibleGraphemes = -1
			controls()
		elseif dlg.i < #dlg.pages then
			dlg.i = dlg.i + 1
			typePage()
		elseif #dlg.buttons == 0 then
			close()
		end
	end

	local function onButton(id)
		if id == "go" then
			RAction:FireServer("henGo")
			close()
		elseif id == "again" then
			RAction:FireServer("henExplain")
		elseif id == "later" then
			close()
		elseif id == "hint" then
			RAction:FireServer("henHint")
		elseif id == "replay" then
			RAction:FireServer("henReplay")
			close()
		end
	end

	-- Affiche une réplique (identifiant de Config.HEN_LINES + paramètres envoyés par le serveur).
	local function show(id, params)
		if not okBuild or type(id) ~= "string" then
			return
		end
		local hen = henState()
		local d = Riddle.say(Config, id, type(params) == "table" and params or {}, hen and num(hen.step) and hen.step or 0)
		if #d.pages == 0 then
			return
		end
		token = token + 1
		clearButtons()
		dlg = { pages = d.pages, buttons = d.buttons, i = 1, typing = true }
		for k, b in ipairs(d.buttons) do
			local btn = make("TextButton", { LayoutOrder = k, Size = UDim2.fromOffset(b.id == "go" and 104 or 126, 34), BackgroundColor3 = (b.id == "go" or b.id == "hint") and COL.green or COL.panel, Text = b.text, TextSize = 14, Font = FONT, TextColor3 = (b.id == "go" or b.id == "hint") and COL.dark or COL.text, TextScaled = true, ZIndex = 24 }, btnRow)
			corner(btn, 17)
			make("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9 }, btn)
			btn.Activated:Connect(function()
				onButton(b.id)
			end)
		end
		frame.Visible = true
		typePage()
	end
	self.show = show

	if okBuild then
		overlay.Activated:Connect(advance)
		nextBtn.Activated:Connect(advance)
		replayBtn.Activated:Connect(function()
			RAction:FireServer("henReplay")
		end)
	end

	---------------------------------------------------------------- Pierres : lueur et notes
	local highlights = {}
	local function stonePart(idx)
		for _, st in ipairs(CollectionService:GetTagged("RuneStone")) do
			if st:GetAttribute("Idx") == idx then
				return st
			end
		end
		return nil
	end
	local function glow(idx, seconds, good)
		pcall(function()
			local st = stonePart(idx)
			if not st then
				return
			end
			local h = highlights[idx]
			if not h or not h.Parent then
				h = Instance.new("Highlight")
				h.Name = "HenGlow"
				h.FillTransparency = 0.25
				h.OutlineTransparency = 0
				h.Parent = st
				highlights[idx] = h
			end
			h.Adornee = st
			h.FillColor = good == false and COL.red or Color3.fromRGB(255, 232, 140)
			h.OutlineColor = Color3.fromRGB(255, 255, 255)
			h.Enabled = true
			local mine = os.clock()
			h:SetAttribute("At", mine)
			task.delay(seconds, function()
				if h.Parent and h:GetAttribute("At") == mine then
					h.Enabled = false
				end
			end)
		end)
	end
	local playToken = 0
	local playing = false
	local function playLullaby(seq, note, gap)
		if type(seq) ~= "table" or not num(note) or not num(gap) then
			return
		end
		playToken = playToken + 1
		local mine = playToken
		playing = true
		task.spawn(function()
			for i, stone in ipairs(seq) do
				if playToken ~= mine then
					return
				end
				if type(stone) == "number" then
					glow(stone, note, true)
					playSound("note" .. tostring(stone))
				end
				task.wait(note + gap)
			end
			if playToken == mine then
				playing = false
			end
		end)
	end

	---------------------------------------------------------------- ❗ au-dessus de la Mère Poule
	local alertGui, henBody
	local function ensureAlert(want)
		pcall(function()
			if not henBody or not henBody.Parent then
				local model = CollectionService:GetTagged("Hen")[1]
				henBody = model and (model.PrimaryPart or model:FindFirstChild("Body")) or nil
			end
			if not henBody then
				return
			end
			if not alertGui or not alertGui.Parent then
				alertGui = Instance.new("BillboardGui")
				alertGui.Name = "HenAlert"
				alertGui.Adornee = henBody
				alertGui.Size = UDim2.fromOffset(46, 52)
				alertGui.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
				alertGui.MaxDistance = H.alertRange
				alertGui.AlwaysOnTop = true
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.BackgroundTransparency = 1
				lbl.Text = "❗"
				lbl.TextSize = 44
				lbl.Font = FONT
				lbl.TextColor3 = Color3.fromRGB(255, 205, 40)
				lbl.TextStrokeTransparency = 0.3
				lbl.Parent = alertGui
				alertGui.Parent = player:WaitForChild("PlayerGui")
				TweenService:Create(alertGui, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { StudsOffsetWorldSpace = Vector3.new(0, 9.6, 0) }):Play()
			end
			alertGui.Enabled = want
		end)
	end

	---------------------------------------------------------------- Plumes : visibilité locale, scintillement
	local armed = {}
	local function updateFeathers()
		local hen = henState()
		local root = myRoot()
		local rx, rz = root and root.Position.X or 0, root and root.Position.Z or 0
		for _, f in ipairs(CollectionService:GetTagged("Feather")) do
			pcall(function()
				local dir = f:GetAttribute("Dir")
				local visible = hen ~= nil and hen.avail == true and num(hen.step) and hen.step <= 1 and not Riddle.hasFeather(num(hen.feathers) and hen.feathers or 0, dir)
				f.Transparency = visible and 0 or 1
				local pr = f:FindFirstChildOfClass("ProximityPrompt")
				if pr then
					pr.Enabled = visible
				end
				local em = f:FindFirstChildOfClass("ParticleEmitter")
				local d = math.sqrt((f.Position.X - rx) ^ 2 + (f.Position.Z - rz) ^ 2)
				local close = visible and root ~= nil and d <= H.sparkleDistance
				if em then
					em.Enabled = close
				end
				if close and armed[dir] ~= false then
					armed[dir] = false
					playSound("secret") -- le « son secret » (silencieux tant qu'aucun identifiant vérifié n'est fourni dans Config.SOUNDS.secret)
				elseif not close and d > H.sparkleDistance + 20 then
					armed[dir] = nil
				end
			end)
		end
	end

	---------------------------------------------------------------- Pierres : texte de l'action selon l'étape ; pastille de la berceuse
	local function updateStones()
		local hen = henState()
		local sing = hen ~= nil and hen.step == 3
		for _, st in ipairs(CollectionService:GetTagged("RuneStone")) do
			pcall(function()
				local pr = st:FindFirstChildOfClass("ProximityPrompt")
				if pr then
					pr.ActionText = sing and "Chanter" or "Tourner la rune"
				end
			end)
		end
		if okBuild then
			local show3 = sing and not frame.Visible
			pill.Visible = show3
			if show3 then
				local n = num(hen.lullabyPos) and hen.lullabyPos or 0
				pillLbl.Text = playing and "🎵 Écoute la berceuse…" or ("🎵 Touche les pierres dans le même ordre (" .. n .. "/" .. H.lullabyLength .. ")")
			end
		end
	end

	---------------------------------------------------------------- Cible du faisceau et carte d'objectif
	local marker
	local function getMarker()
		if marker and marker.Parent then
			return marker
		end
		marker = Instance.new("Part")
		marker.Name = "HenGuide"
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Transparency = 1
		marker.Size = Vector3.new(1, 1, 1)
		marker.Parent = workspace
		return marker
	end

	-- Partie sur laquelle le faisceau jaune se pose (ou nil quand l'énigme ne demande rien). root = HumanoidRootPart du joueur.
	function self.guideTarget(root)
		local hen = henState()
		if not hen or not root then
			return nil
		end
		local g = Riddle.guide(Config, hen, root.Position.X, root.Position.Z)
		if not g then
			return nil
		end
		if g.kind == "hen" then
			ensureAlert(hen.alert == true) -- retrouve aussi le corps de la Mère Poule
			if henBody and henBody.Parent then
				return henBody
			end
		elseif g.kind == "feather" then
			for _, f in ipairs(CollectionService:GetTagged("Feather")) do
				if f:GetAttribute("Dir") == g.dir and f.Parent then
					return f
				end
			end
		end
		local m = getMarker()
		m.Position = Vector3.new(g.x, 4, g.z)
		return m
	end

	-- Carte d'objectif : { title, text, frac } ou nil (énigme indisponible ou faite).
	function self.objective(st)
		local hen = type(st) == "table" and type(st.hen) == "table" and st.hen or nil
		if not hen or hen.avail ~= true or not num(hen.step) or hen.step >= 4 then
			return nil
		end
		local step, k = hen.step, num(hen.count) and hen.count or 0
		if step == 0 then
			return { title = "🐔 La Mère Poule t'appelle", text = "Va lui parler près du Grand Œuf : suis la flèche jaune.", frac = 0 }
		elseif step == 1 then
			return { title = "📜 Berceuse du jour", text = "Étape 1/3 · Plumes " .. k .. "/4 — suis la flèche jaune.", frac = k / 12 }
		elseif step == 2 then
			return { title = "📜 Berceuse du jour", text = "Étape 2/3 · Plumes 4/4 — règle les 4 runes.", frac = 1 / 3 + 0.15 }
		end
		local n = num(hen.lullabyPos) and hen.lullabyPos or 0
		return { title = "📜 Berceuse du jour", text = "Étape 3/3 · Plumes 4/4 — répète la berceuse (" .. n .. "/" .. H.lullabyLength .. ").", frac = 2 / 3 + n / H.lullabyLength / 3 }
	end

	function self.onState(st)
		state = st
		local hen = henState()
		ensureAlert(hen ~= nil and hen.alert == true)
		updateStones()
		updateFeathers()
	end

	---------------------------------------------------------------- Événements du serveur
	RHen.OnClientEvent:Connect(function(kind, a, b, c)
		local ok, err = pcall(function()
			if kind == "say" then
				show(a, b)
			elseif kind == "lullaby" then
				playLullaby(a, b, c)
			elseif kind == "tap" then
				if type(a) == "number" then
					glow(a, 0.5, b == true)
					if b == true then
						playSound("note" .. tostring(a))
					else
						playSound("refuse")
					end
				end
			end
		end)
		if not ok then
			warn("[HenUi] " .. tostring(err)) -- jamais bloquant : l'énigme reste jouable avec les notifications
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.4)
			pcall(function()
				updateFeathers()
				updateStones()
				local root = myRoot()
				local hen = henState()
				if dlg and root and frame.Visible then -- la bulle se ferme si on s'éloigne
					local h = Config.Map2.hen
					if math.sqrt((root.Position.X - h.x) ^ 2 + (root.Position.Z - h.z) ^ 2) > 60 then
						close()
					end
				end
				ensureAlert(hen ~= nil and hen.alert == true)
			end)
		end
	end)
	return self
end

return HenUi
