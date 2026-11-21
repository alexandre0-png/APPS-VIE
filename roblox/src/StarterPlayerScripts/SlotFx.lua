-- ModuleScript : StarterPlayerScripts/SlotFx
-- Écran de tirage « machine à sous » (rareté / taille / mutation) avant la révélation d'un œuf : 3 colonnes qui défilent comme des rouleaux, ralentissent et
-- s'arrêtent une à une (secousse et étincelles à chaque arrêt), bannière « SECRET ! » sur un tirage secret, phénix lumineux avec cercle runique dès le
-- palier Légendaire. 100 % dessiné par le code ; le plan (positions, arrêts) vient de Reveal.slotPlan et le résultat affiché est TOUJOURS le tirage réel.
-- opts.slotPos = Reveal.slotPos (injecté). Un tap passe l'animation. `onDone` est appelé exactement une fois (fin, passage ou erreur). Aucune erreur ne sort d'ici.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SlotFx = {}

local FONT = Enum.Font.GothamBold
local RUNES = { "ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ" }

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function tween(obj, seconds, goal, style, dir)
	TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal):Play()
end

-- Nombre d'objets créés AVANT le début de l'animation (hors étincelles, bannière et phénix, créés à l'arrêt).
SlotFx.STATIC_COST = 3 + 1 + 3 * 11 -- conteneur + coins + contour, titre, 3 colonnes (cadre, coins, contour, titre, 5 cases, fenêtre, contour)

-- Joue l'écran au centre de `parent` (ScreenGui). opts : secret (bool), onDone (fonction). Retourne le conteneur ou nil.
function SlotFx.play(parent, plan, cell, opts)
	opts = opts or {}
	local finished = false
	local conn, root
	local function finish()
		if finished then
			return
		end
		finished = true
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
		if root then
			pcall(function()
				tween(root, 0.18, { BackgroundTransparency = 1 })
				Debris:AddItem(root, 0.3)
			end)
		end
		if opts.onDone then
			pcall(opts.onDone)
		end
	end
	local ok = pcall(function()
		local CH = cell or 34
		local W = 128
		root = make("TextButton", {
			Name = "SlotFx", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(3 * W + 4 * 12, 3 * CH + 70),
			BackgroundColor3 = Color3.fromRGB(24, 18, 40), BackgroundTransparency = 0.05, Text = "", AutoButtonColor = false, ZIndex = 40,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0, 18) }, root)
		make("UIStroke", { Color = Color3.fromRGB(255, 210, 63), Thickness = 4 }, root)
		make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 26), Text = "🎰 TIRAGE EN COURS… (touche pour passer)", Font = FONT, TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 232, 150), ZIndex = 41,
		}, root)
		local cols = {}
		for k, col in ipairs(plan.columns) do
			local frame = make("Frame", {
				Position = UDim2.fromOffset(12 + (k - 1) * (W + 12), 56), Size = UDim2.fromOffset(W, 3 * CH), BackgroundColor3 = Color3.fromRGB(12, 10, 24), ClipsDescendants = true, ZIndex = 41,
			}, root)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
			make("UIStroke", { Color = Color3.fromRGB(90, 80, 130), Thickness = 2 }, frame)
			make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12 + (k - 1) * (W + 12), 32), Size = UDim2.fromOffset(W, 20), Text = col.title, Font = FONT, TextSize = 14, TextColor3 = Color3.fromRGB(180, 170, 220), ZIndex = 41 }, root)
			local labels = {}
			for j = -2, 2 do
				labels[j] = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, CH), Position = UDim2.new(0.5, 0, 0, CH * 1.5), Text = "", Font = FONT, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), ZIndex = 42 }, frame)
			end
			local win = make("Frame", { Position = UDim2.fromOffset(0, CH), Size = UDim2.new(1, 0, 0, CH), BackgroundTransparency = 1, ZIndex = 43 }, frame)
			make("UIStroke", { Color = Color3.fromRGB(255, 210, 63), Thickness = 2 }, win)
			cols[k] = { col = col, frame = frame, labels = labels, stopped = false, W = W, CH = CH }
		end
		local t0 = os.clock()
		local reduced = opts.reduced == true
		local function burst(k, color)
			local cx = 12 + (k - 1) * (W + 12) + W / 2
			for i = 1, (reduced and 3 or 6) do
				local spark = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, 56 + CH * 1.5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Text = i % 2 == 0 and "✦" or "✨", TextScaled = true, TextColor3 = color, ZIndex = 45 }, root)
				local a = i / 6 * math.pi * 2
				tween(spark, 0.6, { Position = UDim2.fromOffset(cx + math.cos(a) * 60, 56 + CH * 1.5 + math.sin(a) * 50), TextTransparency = 1 })
				Debris:AddItem(spark, 0.7)
			end
			-- secousse du bloc à chaque arrêt
			local base = root.Position
			for s = 1, 4 do
				task.delay(s * 0.04, function()
					pcall(function()
						root.Position = s == 4 and base or UDim2.new(base.X.Scale, base.X.Offset + (s % 2 == 0 and 5 or -5), base.Y.Scale, base.Y.Offset)
					end)
				end)
			end
		end
		local ended = false
		local function ending()
			if ended then
				return
			end
			ended = true
			local tcol = plan.columns[1].symbols[plan.columns[1].final].color or Color3.new(1, 1, 1)
			if opts.secret then
				local ban = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 20), BackgroundTransparency = 1, Text = "SECRET !", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(255, 70, 20), TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(50, 10, 0), ZIndex = 50 }, root)
				tween(ban, 0.45, { Size = UDim2.fromOffset(330, 80) }, Enum.EasingStyle.Back)
			end
			if plan.phoenix then
				local glow = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = tcol, BackgroundTransparency = 0.3, ZIndex = 44 }, root)
				make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, glow)
				make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) }), Rotation = 90 }, glow)
				tween(glow, 0.7, { Size = UDim2.fromOffset(360, 360), BackgroundTransparency = 0.85 }, Enum.EasingStyle.Quint)
				local ring = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(240, 240), BackgroundTransparency = 1, ZIndex = 46 }, root)
				for i, r in ipairs(RUNES) do
					local a = (i - 1) / #RUNES * math.pi * 2
					make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 110, 0.5, math.sin(a) * 110), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = r, Font = FONT, TextScaled = true, TextColor3 = tcol, ZIndex = 46, Rotation = math.deg(a) + 90 }, ring)
				end
				tween(ring, plan.hold + 0.6, { Rotation = 120 }, Enum.EasingStyle.Sine)
				for _, side in ipairs({ -1, 1 }) do
					local wing = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Text = "🪽", TextScaled = true, ZIndex = 47 }, root)
					tween(wing, 0.7, { Position = UDim2.new(0.5, side * 150, 0.5, -20), Size = UDim2.fromOffset(90, 90) }, Enum.EasingStyle.Back)
				end
				local bird = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Text = "🔥", TextScaled = true, ZIndex = 48 }, root)
				tween(bird, 0.6, { Size = UDim2.fromOffset(110, 110) }, Enum.EasingStyle.Elastic)
				Debris:AddItem(glow, plan.hold + 0.7)
				Debris:AddItem(ring, plan.hold + 0.7)
			end
			task.delay(plan.hold, finish)
		end
		conn = RunService.Heartbeat:Connect(function()
			if finished then
				return
			end
			local ok2 = pcall(function()
				local t = os.clock() - t0
				local allStopped = true
				for k, c in ipairs(cols) do
					local col = c.col
					local pos = opts.slotPos(col, t)
					local n = #col.symbols
					local base = math.floor(pos + 0.5)
					local frac = pos - base
					for j = -2, 2 do
						local sym = col.symbols[(base + j - 1) % n + 1]
						local lab = c.labels[j]
						lab.Text = sym.text
						lab.TextColor3 = sym.color or Color3.new(1, 1, 1)
						lab.Position = UDim2.new(0.5, 0, 0, c.CH * (1.5 + j - frac))
						lab.TextTransparency = j == 0 and 0 or 0.45
					end
					if t >= col.stop then
						if not c.stopped then
							c.stopped = true
							burst(k, col.symbols[col.final].color or Color3.new(1, 1, 1))
						end
					else
						allStopped = false
					end
				end
				if allStopped then
					ending()
				end
			end)
			if not ok2 then
				finish()
			end
		end)
		root.Activated:Connect(finish)
		task.delay(plan.duration + 1.5, finish) -- garde-fou : jamais bloqué
	end)
	if not ok then
		finish()
		return nil
	end
	return root
end

return SlotFx
