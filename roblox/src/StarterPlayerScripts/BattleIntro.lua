-- ModuleScript : StarterPlayerScripts/BattleIntro   (lot 10, B.4)
-- Intro de combat, 3 s au maximum, passable (tap après 1 s) : deux bandeaux glissent depuis les bords (joueur à gauche, adversaire à droite) avec portrait, nom, ligue,
-- trophées, ratio « 124 V / 37 D (77 %) » et 3 vignettes de pets (type + compteur de rareté) ; « VS » qui frappe (échelle 2 -> 1, secousse 0,3 s, son « fanfare » à 0,5) ;
-- flèche d'avantage de type ; décompte 3-2-1 si demandé. 100 % code. Le plan vient de ReplicatedStorage/IntroPlan (pur). Rien ne s'exécute à l'import, aucun require.
--
-- BRANCHER (client, avant de démarrer l'écran de combat) :
--   local plan = IntroPlan.plan({ mode = "pvp", countdown = true, advantage = 1.5,
--       me = { name = player.Name, userId = player.UserId, wins = 124, losses = 37, league = "Or", trophies = 812, pets = { { type = "Feu", odds = 38494, tier = 5 }, ... } },
--       foe = { ... } }, { fmtOdds = Odds.label })
--   BattleIntro.play(screenGui, plan, {
--       thumbnail = function(userId) return "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150" end, -- optionnel (ou Players:GetUserThumbnailAsync, hors de ce module)
--       sound = function(key, volume) ... end,   -- appelé avec "fanfare", 0.5
--       onDone = function() ... end })           -- UNE fois, à la fin, au passage ou en cas d'erreur
-- Retourne { skip, stop, isDone, created, root } ou nil (onDone est alors appelé quand même). Pas de += ni de continue (lanceur lupa).
local BattleIntro = {}

BattleIntro.MAX_INSTANCES = 120
BattleIntro.WATCHDOG_MARGIN = 0.5

local FONT = Enum.Font.GothamBold
local TYPE_EMOJI = { Feu = "🔥", Eau = "💧", Plante = "🌿", Nature = "🌿", Glace = "❄️", Foudre = "⚡", Terre = "⛰️", Ciel = "☁️", Ombre = "🌑", ["Lumière"] = "✨" }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return v
	end
	return default
end

function BattleIntro.play(parent, plan, opts)
	opts = type(opts) == "table" and opts or {}
	local created, done, alive = 0, false, false
	local root, stage, vs
	local startClock = os.clock()
	local TweenService
	pcall(function()
		TweenService = game:GetService("TweenService")
	end)

	local function make(class, props, par)
		if created >= BattleIntro.MAX_INSTANCES then
			error("plafond d'instances")
		end
		created = created + 1
		local o = Instance.new(class)
		for k, v in pairs(props) do
			o[k] = v
		end
		o.Parent = par
		return o
	end
	local function tween(obj, seconds, goal, style, dir)
		if TweenService == nil then
			return
		end
		pcall(function()
			TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal):Play()
		end)
	end
	local function finish()
		if done then
			return
		end
		done = true
		alive = false
		if root ~= nil then
			pcall(function()
				root:Destroy()
			end)
		end
		if type(opts.onDone) == "function" then
			pcall(opts.onDone)
		end
	end

	local function label(par, props)
		props.BackgroundTransparency = 1
		props.Font = props.Font or FONT
		props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
		props.TextStrokeTransparency = props.TextStrokeTransparency or 0.4
		props.ZIndex = props.ZIndex or 84
		return make("TextLabel", props, par)
	end

	-- bandeau d'un joueur ; right = true : côté droit
	local function buildSide(data, right)
		local x = right and 1 or 0
		local band = make("Frame", {
			AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x + (right and 0.6 or -0.6), 0, 0.32, 0), Size = UDim2.new(0.46, 0, 0, 168), BorderSizePixel = 0, ZIndex = 82,
			BackgroundColor3 = right and Color3.fromRGB(120, 36, 44) or Color3.fromRGB(34, 70, 130),
		}, stage)
		make("UICorner", { CornerRadius = UDim.new(0, 14) }, band)
		make("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.5 }, band)
		local thumb = nil
		if type(opts.thumbnail) == "function" and data.userId ~= 0 then
			local ok, img = pcall(opts.thumbnail, data.userId)
			thumb = ok and type(img) == "string" and img or nil
		end
		local portrait = make("ImageLabel", {
			Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(20, 20, 30), Image = thumb or "", BorderSizePixel = 0, ZIndex = 84,
		}, band)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, portrait)
		label(band, { Position = UDim2.fromOffset(82, 8), Size = UDim2.new(1, -92, 0, 26), Text = data.name, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
		local sub = (data.league ~= "" and (data.league .. " · ") or "") .. "🏆 " .. data.trophies
		label(band, { Position = UDim2.fromOffset(82, 34), Size = UDim2.new(1, -92, 0, 18), Text = sub, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 232, 150) })
		label(band, { Position = UDim2.fromOffset(82, 54), Size = UDim2.new(1, -92, 0, 22), Text = data.record, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
		for i = 1, #data.pets do
			local p = data.pets[i]
			local card = make("Frame", {
				Position = UDim2.new((i - 1) / 3, i == 1 and 8 or 4, 0, 88), Size = UDim2.new(1 / 3, -8, 0, 70), BackgroundColor3 = Color3.fromRGB(16, 16, 28), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 83,
			}, band)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
			label(card, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 34), Text = TYPE_EMOJI[p.type] or "❔", TextSize = 28 })
			label(card, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 22), Text = p.oddsText, TextSize = 12, TextColor3 = Color3.fromRGB(255, 255, 255) })
		end
		return band
	end

	local ok = pcall(function()
		if type(plan) ~= "table" or type(plan.left) ~= "table" or type(plan.right) ~= "table" then
			error("plan invalide")
		end
		local duration = math.max(0.3, math.min(3, num(plan.duration, 2.2)))
		alive = true
		root = make("TextButton", { Name = "BattleIntro", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, ZIndex = 80, BorderSizePixel = 0 }, parent)
		stage = make("Frame", { Name = "Stage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 81, BorderSizePixel = 0 }, root)
		local left, right = buildSide(plan.left, false), buildSide(plan.right, true)
		tween(left, 0.4, { Position = UDim2.new(0, 0, 0.32, 0) }, Enum.EasingStyle.Back)
		tween(right, 0.4, { Position = UDim2.new(1, 0, 0.32, 0) }, Enum.EasingStyle.Back)
		vs = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "VS", TextScaled = true, Font = Enum.Font.GothamBlack,
			TextColor3 = Color3.fromRGB(255, 210, 63), TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(30, 10, 10), Visible = false, ZIndex = 90,
		}, stage)
		task.delay(num(plan.vs and plan.vs.t, 0.5), function()
			if not alive then
				return
			end
			pcall(function()
				vs.Visible = true
				vs.Size = UDim2.fromOffset(200, 120)
				tween(vs, 0.3, { Size = UDim2.fromOffset(100, 60) }, Enum.EasingStyle.Back)
				if type(opts.sound) == "function" then
					pcall(opts.sound, "fanfare", 0.5)
				end
			end)
			-- secousse de 0,3 s
			task.spawn(function()
				local t0 = os.clock()
				while alive and os.clock() - t0 < 0.3 do
					local k = (1 - (os.clock() - t0) / 0.3) * 6
					pcall(function()
						stage.Position = UDim2.fromOffset(math.sin((os.clock() - t0) * 90) * k, 0)
					end)
					task.wait(0.03)
				end
				pcall(function()
					stage.Position = UDim2.fromOffset(0, 0)
				end)
			end)
		end)
		if type(plan.arrow) == "table" then
			task.delay(num(plan.arrow.t, 1), function()
				if not alive then
					return
				end
				pcall(function()
					local good = plan.arrow.good == true
					local a = label(stage, {
						AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.02, 0, 0.32, 100), Size = UDim2.fromOffset(240, 30), Text = (good and "⬆ " or "⬇ ") .. tostring(plan.arrow.text or ""),
						TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = good and Color3.fromRGB(90, 235, 110) or Color3.fromRGB(255, 90, 90), ZIndex = 90,
					})
					a.TextTransparency = 1
					tween(a, 0.25, { TextTransparency = 0 })
				end)
			end)
		end
		if type(plan.count) == "table" then
			for i = 1, #plan.count do
				local c = plan.count[i]
				task.delay(num(c.t, 1.6), function()
					if not alive then
						return
					end
					pcall(function()
						local l = label(stage, {
							AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromOffset(120, 120), Text = tostring(c.text or ""), TextScaled = true,
							Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeTransparency = 0, ZIndex = 90,
						})
						tween(l, 0.38, { Size = UDim2.fromOffset(60, 60), TextTransparency = 1, TextStrokeTransparency = 1 })
					end)
				end)
			end
		end
		local skipAfter = num(plan.skipAfter, 1)
		root.Activated:Connect(function()
			if alive and os.clock() - startClock >= skipAfter then
				finish()
			end
		end)
		task.delay(duration, finish)
		task.delay(duration + BattleIntro.WATCHDOG_MARGIN, finish)
	end)

	if not ok then
		finish()
		return nil
	end
	return {
		root = root,
		skip = function()
			if alive and os.clock() - startClock >= num(plan.skipAfter, 1) then
				finish()
			end
		end,
		stop = finish,
		isDone = function()
			return done
		end,
		created = function()
			return created
		end,
	}
end

return BattleIntro
