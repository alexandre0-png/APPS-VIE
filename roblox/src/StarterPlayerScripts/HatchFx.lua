-- ModuleScript : StarterPlayerScripts/HatchFx   (lot 10, B.3)
-- Exécute le plan d'éclosion calculé par ReplicatedStorage/HatchPlan (10 animations, une par rareté). 100 % dessiné par le code : Frames, TextLabels, UICorner,
-- UIGradient, UIStroke, TweenService, plus un ColorCorrectionEffect temporaire (teinte / désaturation) et le champ de vision de la caméra (zoom). Aucun asset.
-- Tout est sous pcall ; durée <= 8 s ; l'œuf, la caméra et l'interface sont TOUJOURS restitués (fin normale, passage par un tap, erreur, ou chien de garde à durée + 0,6 s).
-- Rien ne s'exécute à l'import (le module ne fait que définir des fonctions ; aucun require : tout est injecté).
--
-- BRANCHER (client, à la place de CinematicKit.hatchPlan / RevealFx pour l'éclosion) :
--   local plan = HatchPlan.plan(slot.r, slot.o, { reduced = isMobile, firstTime = firstTimeThisTier, still = carryingEgg })
--   local h = HatchFx.play(screenGui, plan, {
--       colors = { main = tier.color, second = tier.color2 },     -- Color3 de la rareté (Config.TIERS)
--       rarityName = "Légendaire", petText = "🐉",                -- bandeau et pet affiché à la révélation (petText = nil : rien, l'appelant dessine sa carte)
--       slot = { rarity = "Légendaire", size = "Grand", mut = "Doré", pools = { rarity = {...}, size = {...}, mut = {...} } }, -- machine à sous de la rareté 4
--       fmtOdds = Odds.label,                                      -- « 1 sur N » (défaut : « 1 sur N » brut)
--       sound = function(key, volume) ... end,                     -- clés : plan.sound.key, "fanfare" (r >= 8), "secret" (N >= 1 000 000), "divine" (r10)
--       onReveal = function() ... end,                             -- appelé UNE fois au moment de la révélation (ou au passage), affichez la carte du pet ici
--       onDone = function() ... end,                               -- appelé UNE fois à la fin, quoi qu'il arrive
--       hide = { otherScreenGui, ... },                            -- interfaces masquées pendant l'animation puis restituées
--   })
--   h.skip() (passer, ignoré avant plan.skipAfter ou si plan.noSkip), h.stop() (arrêt forcé, tout est restitué), h.isDone(), h.created() (instances créées).
-- Retour : poignée { skip, stop, isDone, created, root } ou nil si la construction a échoué (onReveal puis onDone sont alors appelés quand même).
-- Pas de += ni de continue (lanceur lupa).
local HatchFx = {}

HatchFx.MAX_INSTANCES = 220 -- plafond dur d'instances créées par éclosion (échafaudage, décors compris)
HatchFx.WATCHDOG_MARGIN = 0.6

-- Zoom de la caméra partagé entre éclosions qui se chevauchent : la valeur d'origine est mémorisée par le PREMIER zoom actif et restituée quand le dernier se termine
-- (sinon une éclosion lancée pendant une autre figerait le champ de vision zoomé).
local zoomShared = { base = nil, users = 0 }

local FONT = Enum.Font.GothamBold
local RUNES = { "ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ", "ᛁ", "ᛃ", "ᛇ", "ᛉ" }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return v
	end
	return default
end

-- Courbes (0..1 -> 0..1)
local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

-- Paliers du compteur animé (identiques à Odds.countSteps : de 1 à N, ralentissement final, dernier = N).
local function countSteps(target, steps)
	local out = {}
	local prev = 1
	for i = 1, steps do
		local v = 1 + (target - 1) * easeOut(i / steps)
		if target >= 10 then
			v = math.floor(v + 0.5)
		else
			v = math.floor(v * 10 + 0.5) / 10
		end
		if v < prev then
			v = prev
		end
		if i == steps then
			v = target
		end
		out[i] = v
		prev = v
	end
	return out
end

local function defaultOdds(n)
	return "1 sur " .. string.format("%.0f", n)
end

function HatchFx.play(parent, plan, opts)
	opts = type(opts) == "table" and opts or {}
	local done, alive, revealed = false, false, false
	local created = 0
	local root, stage, box, egg, pet, counter, hint, flashF, blackF, cc
	local cam, baseFov, hidden, zoomed = nil, nil, {}, false
	local startClock = os.clock()

	local TweenService, Lighting
	pcall(function()
		TweenService = game:GetService("TweenService")
		Lighting = game:GetService("Lighting")
	end)

	local function make(class, props, par)
		if created >= HatchFx.MAX_INSTANCES then
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
	local function safe(fn, ...)
		if type(fn) == "function" then
			pcall(fn, ...)
		end
	end

	local function restore()
		-- caméra
		if zoomed then
			zoomed = false
			zoomShared.users = math.max(0, zoomShared.users - 1)
			if zoomShared.users == 0 and cam ~= nil and zoomShared.base ~= nil then
				local base = zoomShared.base
				zoomShared.base = nil
				pcall(function()
					cam.FieldOfView = base
				end)
			end
		end
		-- teinte de l'image
		if cc ~= nil then
			pcall(function()
				cc:Destroy()
			end)
			cc = nil
		end
		-- interfaces masquées
		for i = 1, #hidden do
			local h = hidden[i]
			pcall(function()
				h.gui.Enabled = h.was
			end)
		end
		hidden = {}
		if root ~= nil then
			pcall(function()
				root:Destroy()
			end)
		end
	end

	local function reveal()
		if revealed then
			return
		end
		revealed = true
		safe(opts.onReveal)
	end

	local function finish(skipped)
		if done then
			return
		end
		done = true
		alive = false
		if skipped then
			reveal()
		end
		restore()
		reveal() -- garantie : la révélation a toujours lieu avant la fin
		safe(opts.onDone)
	end

	local function colorOf(key, i, n)
		local colors = type(opts.colors) == "table" and opts.colors or {}
		if key == "rainbow" then
			return Color3.fromHSV(((i or 1) - 1) / math.max(n or 1, 1), 0.65, 1)
		elseif key == "second" then
			return colors.second or Color3.fromRGB(184, 134, 11)
		elseif key == "white" then
			return Color3.new(1, 1, 1)
		elseif key == "black" then
			return Color3.fromRGB(16, 16, 20)
		elseif key == "gold" then
			return Color3.fromRGB(255, 205, 60)
		elseif key == "red" then
			return Color3.fromRGB(255, 70, 40)
		end
		return colors.main or Color3.fromRGB(255, 205, 60)
	end

	-- boucle bornée : fn(progression 0..1) tant que l'animation vit
	local function every(dur, fn)
		task.spawn(function()
			local t0 = os.clock()
			while alive do
				local p = (os.clock() - t0) / math.max(dur, 0.05)
				if p >= 1 then
					break
				end
				pcall(fn, p)
				task.wait(0.03)
			end
			if alive then
				pcall(fn, 1)
			end
		end)
	end

	local function cc3()
		if cc == nil and Lighting ~= nil then
			cc = make("ColorCorrectionEffect", { Name = "HatchTint" }, Lighting)
		end
		return cc
	end

	-- ------------------------------------------------------------------ prises
	local K = {}
	function K.shake(b)
		local amp = num(b.amp, 4)
		every(b.d, function(p)
			local a = b.grow and amp * (0.3 + p) or amp
			egg.Rotation = math.sin(p * b.d * 38) * a
		end)
	end
	function K.pop(b)
		tween(egg, math.max(b.d, 0.1), { Size = UDim2.fromOffset(170, 170), TextTransparency = 1 })
		task.delay(math.max(b.d, 0.1), function()
			pcall(function()
				egg.Visible = false
			end)
		end)
	end
	function K.burst(b)
		local dist = num(b.dist, 100)
		for i = 1, b.n do
			local a = (i / b.n) * math.pi * 2
			if b.arc == "crown" then
				a = -math.pi + (i / (b.n + 1)) * math.pi -- éventail vers le haut
			end
			local col = colorOf(b.color, i, b.n)
			local o
			if b.glyph == "cube" or b.glyph == "shard" then
				o = make("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(b.glyph == "cube" and 16 or 8, b.glyph == "cube" and 16 or 24), BackgroundColor3 = col,
					Rotation = (i * 37) % 90, BorderSizePixel = 0, ZIndex = 4,
				}, box)
			else
				o = make("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Text = b.glyph == "petal" and "✿" or "✦", TextScaled = true,
					TextColor3 = col, Font = FONT, ZIndex = 4,
				}, box)
			end
			local dx, dy = math.cos(a) * dist, math.sin(a) * dist
			if b.arc == "fall" then
				dx, dy = math.cos(a) * dist * 0.6, math.abs(math.sin(a)) * dist
			end
			tween(o, b.d, { Position = UDim2.fromOffset(dx, dy), BackgroundTransparency = 1, TextTransparency = 1, Rotation = 120 })
		end
	end
	function K.rays(b)
		local len = num(b.len, 200)
		for i = 1, b.n do
			local ray = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(i % 2 == 0 and 7 or 4, 10), BackgroundColor3 = colorOf(b.color, i, b.n),
				BackgroundTransparency = 0.1, Rotation = (i - 1) * 360 / b.n, BorderSizePixel = 0, ZIndex = 3,
			}, box)
			tween(ray, b.d, { Size = UDim2.fromOffset(i % 2 == 0 and 7 or 4, len * (i % 2 == 0 and 1 or 0.75)), BackgroundTransparency = 1 })
		end
	end
	function K.ring(b)
		for i = 1, b.n do
			local ring = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, ZIndex = 3 }, box)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
			local stroke = make("UIStroke", { Color = colorOf(b.color, i, b.n), Thickness = 5, Transparency = 0.1 }, ring)
			local delay = (i - 1) * 0.18
			task.delay(delay, function()
				if not alive then
					return
				end
				pcall(function()
					if b.mode == "converge" then
						ring.Size = UDim2.fromOffset(300, 300)
						tween(ring, b.d, { Size = UDim2.fromOffset(60, 60) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						tween(stroke, b.d, { Thickness = 9 })
					elseif b.mode == "ground" then
						ring.Position = UDim2.fromOffset(0, 70)
						ring.Size = UDim2.fromOffset(60, 20)
						tween(ring, b.d, { Size = UDim2.fromOffset(300 + i * 40, 90 + i * 12) }, Enum.EasingStyle.Quint)
						tween(stroke, b.d, { Transparency = 1 })
					elseif b.mode == "rise" then
						ring.Position = UDim2.fromOffset(0, 10)
						ring.Size = UDim2.fromOffset(130, 36)
						tween(ring, b.d, { Position = UDim2.fromOffset(0, -150) }, Enum.EasingStyle.Quad)
						tween(stroke, b.d, { Transparency = 0.6 })
					else
						tween(ring, b.d, { Size = UDim2.fromOffset(300 + i * 60, 300 + i * 60) }, Enum.EasingStyle.Quint)
						tween(stroke, b.d, { Transparency = 1, Thickness = 1 })
					end
				end)
			end)
		end
	end
	function K.flash(b)
		flashF.BackgroundColor3 = colorOf(b.color)
		flashF.BackgroundTransparency = 1 - num(b.a, 0.6)
		flashF.Visible = true
		tween(flashF, math.max(b.d, 0.1), { BackgroundTransparency = 1 })
	end
	function K.shakeScreen(b)
		local amp = num(b.amp, 6)
		every(b.d, function(p)
			local k = (1 - p) * amp
			stage.Position = UDim2.fromOffset(math.sin(p * 90) * k, math.cos(p * 70) * k)
		end)
		task.delay(b.d + 0.05, function()
			pcall(function()
				stage.Position = UDim2.fromOffset(0, 0)
			end)
		end)
	end
	function K.text(b)
		local glyph, size, y = b.glyph, 60, -120
		local text = glyph
		if glyph == "crown" then
			text, size = "👑", 70
		elseif glyph == "exceptional" then
			text, size, y = "✨ Tirage exceptionnel ✨", 26, 135
		end
		local lab = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, b.fall and -300 or y), Size = UDim2.fromOffset(glyph == "exceptional" and 340 or 120, size), BackgroundTransparency = 1,
			Text = text, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = colorOf(b.color), TextStrokeTransparency = 0,
			TextStrokeColor3 = b.color == "black" and Color3.new(1, 1, 1) or Color3.fromRGB(30, 20, 40), ZIndex = 8,
		}, box)
		if b.fall then
			tween(lab, 0.9, { Position = UDim2.fromOffset(0, y) }, Enum.EasingStyle.Bounce)
		end
		task.delay(math.max(b.d - 0.3, 0.1), function()
			if alive then
				tween(lab, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
			end
		end)
	end
	function K.banner(b)
		local colors = type(opts.colors) == "table" and opts.colors or {}
		local band = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 150), Size = UDim2.fromOffset(40, 36), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8,
		}, box)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, band)
		make("UIStroke", { Color = Color3.fromRGB(24, 16, 30), Thickness = 4 }, band)
		if b.color == "rainbow" then
			make("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 235, 110)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
				}),
			}, band)
		elseif b.color == "white" then
			make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20)) }), Rotation = 0 }, band)
		else
			make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, colorOf(b.color)), ColorSequenceKeypoint.new(1, colors.second or colorOf(b.color)) }), Rotation = 90 }, band)
		end
		make("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = type(opts.rarityName) == "string" and opts.rarityName:upper() or "", Font = Enum.Font.GothamBlack, TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(24, 16, 30), ZIndex = 9,
		}, band)
		tween(band, 0.5, { Size = UDim2.fromOffset(260, 36) }, Enum.EasingStyle.Back)
	end
	function K.zoom(b)
		if cam == nil or baseFov == nil or plan.camera == false or zoomed or zoomShared.users > 0 then
			return -- pas de caméra, caméra immobile demandée, ou une autre éclosion zoome déjà
		end
		local fov = cam.FieldOfView
		if type(fov) ~= "number" then
			return
		end
		zoomShared.base, zoomShared.users, zoomed = fov, zoomShared.users + 1, true
		local target = fov / math.max(num(b.k, 1.1), 1)
		every(b.d, function(p)
			local k = p < 0.3 and easeOut(p / 0.3) or (p > 0.8 and easeOut((1 - p) / 0.2) or 1)
			cam.FieldOfView = fov + (target - fov) * k
		end)
	end
	function K.tint(b)
		local fx = cc3()
		if fx == nil then
			return
		end
		if b.sat ~= nil then -- désaturation : maintenue jusqu'à la fin
			every(b.d, function(p)
				fx.Saturation = num(b.sat, -1) * p
			end)
		else
			local col = colorOf(b.color)
			fx.TintColor = Color3.new(1, 1, 1):Lerp(col, num(b.a, 0.5))
			task.delay(b.d, function()
				if alive then
					pcall(function()
						fx.TintColor = Color3.new(1, 1, 1)
					end)
				end
			end)
		end
	end
	function K.black(b)
		blackF.BackgroundTransparency = 0
		blackF.Visible = true
		task.delay(b.d, function()
			if alive then
				tween(blackF, 0.3, { BackgroundTransparency = 1 })
			end
		end)
	end
	function K.slot(b)
		local sl = type(opts.slot) == "table" and opts.slot or {}
		local pools = type(sl.pools) == "table" and sl.pools or {}
		local frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 120), Size = UDim2.fromOffset(330, 34), BackgroundColor3 = Color3.fromRGB(24, 18, 40), BorderSizePixel = 0, ZIndex = 7,
		}, box)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
		local labs, finals, pool = {}, { sl.rarity, sl.size, sl.mut }, { pools.rarity, pools.size, pools.mut }
		for i = 1, 3 do
			labs[i] = make("TextLabel", {
				Position = UDim2.new((i - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1, Text = "?", Font = FONT, TextSize = 16,
				TextColor3 = Color3.new(1, 1, 1), ZIndex = 8,
			}, frame)
		end
		every(b.d, function(p)
			for i = 1, 3 do
				local stopAt = 0.4 + 0.25 * (i - 1)
				local final = type(finals[i]) == "string" and finals[i] or "?"
				if p >= stopAt then
					labs[i].Text = final
					labs[i].TextColor3 = colorOf("main")
				else
					local list = type(pool[i]) == "table" and pool[i] or nil
					if list ~= nil and #list > 0 then
						labs[i].Text = tostring(list[(math.floor(p * 40) + i * 3) % #list + 1])
					end
				end
			end
		end)
		task.delay(b.d + 0.4, function()
			if alive then
				tween(frame, 0.3, { BackgroundTransparency = 1 })
			end
		end)
	end
	function K.crystals(b)
		for i = 1, b.n do
			local a = (i / b.n) * math.pi * 2
			local x = b.from == "around" and math.cos(a) * 90 or ((i - (b.n + 1) / 2) * 34)
			local y = b.from == "around" and math.sin(a) * 40 + 40 or 90
			local c = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(14, 4), BackgroundColor3 = colorOf(b.color), BorderSizePixel = 0,
				Rotation = ((i % 3) - 1) * 12, ZIndex = 3,
			}, box)
			make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, c)
			tween(c, b.d, { Size = UDim2.fromOffset(18 + (i % 3) * 6, 70 + (i % 4) * 14) }, Enum.EasingStyle.Back)
		end
	end
	function K.frost(b)
		for i = 1, b.n do
			local f = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((i - 2) * 40, 80), Size = UDim2.fromOffset(20, 8), BackgroundColor3 = colorOf(b.color), BackgroundTransparency = 0.4,
				BorderSizePixel = 0, ZIndex = 2,
			}, box)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
			tween(f, b.d, { Size = UDim2.fromOffset(200 + i * 40, 50 + i * 8), BackgroundTransparency = 0.8 })
		end
	end
	function K.cracks(b)
		for i = 1, b.n do
			local c = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(3, 4), BackgroundColor3 = colorOf(b.color), BorderSizePixel = 0,
				Rotation = (i - 1) * (360 / b.n) + 20, ZIndex = 5,
			}, box)
			tween(c, b.d, { Size = UDim2.fromOffset(4, 90 + (i % 2) * 30) })
		end
	end
	function K.chains(b)
		local links = {}
		for i = 1, b.n do
			local a = (i / b.n) * math.pi * 2
			local link = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.cos(a) * 70, math.sin(a) * 70), Size = UDim2.fromOffset(18, 28), BackgroundTransparency = 1,
				Rotation = math.deg(a), ZIndex = 5,
			}, box)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, link)
			make("UIStroke", { Color = Color3.fromRGB(70, 70, 80), Thickness = 4 }, link)
			links[i] = { obj = link, a = a }
		end
		task.delay(math.max(num(b.breakAt, b.d) - 0.4, 0.1), function()
			if not alive then
				return
			end
			for i = 1, #links do
				tween(links[i].obj, 0.4, { Position = UDim2.fromOffset(math.cos(links[i].a) * 260, math.sin(links[i].a) * 260), Rotation = 400 })
			end
		end)
	end
	function K.runes(b)
		for i = 1, b.n do
			local a = (i / b.n) * math.pi * 2
			local r = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.cos(a) * 130, 80 + math.sin(a) * 34), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1,
				Text = RUNES[(i - 1) % #RUNES + 1], TextScaled = true, Font = FONT, TextColor3 = colorOf(b.color, i, b.n), TextTransparency = 1, ZIndex = 2,
			}, box)
			tween(r, 0.3, { TextTransparency = 0.1 })
			task.delay(math.max(b.d - 0.3, 0.1), function()
				if alive then
					tween(r, 0.3, { TextTransparency = 1 })
				end
			end)
		end
	end
	function K.smoke(b)
		for i = 1, b.n do
			local s = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((i - (b.n + 1) / 2) * 36, 40), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, Text = "☁",
				TextScaled = true, Font = FONT, TextColor3 = Color3.fromRGB(70, 70, 80), TextTransparency = 0.2, ZIndex = 4,
			}, box)
			tween(s, b.d, { Position = UDim2.fromOffset((i - (b.n + 1) / 2) * 60, -120), TextTransparency = 1, Size = UDim2.fromOffset(90, 90) })
		end
	end
	function K.stars(b)
		for i = 1, b.n do
			local a = (i / b.n) * math.pi * 2 + 0.4
			local s = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "★", TextScaled = true, Font = FONT,
				TextColor3 = colorOf(b.color, i, b.n), ZIndex = 4,
			}, box)
			tween(s, b.d, { Position = UDim2.fromOffset(math.cos(a) * (120 + (i % 3) * 40), math.sin(a) * (90 + (i % 3) * 30)), TextTransparency = 1 })
		end
	end
	function K.wings(b)
		for i = 1, 2 do
			local dir = i == 1 and -1 or 1
			local w = make("Frame", {
				AnchorPoint = Vector2.new(dir == -1 and 1 or 0, 0.5), Position = UDim2.fromOffset(dir * 20, -10), Size = UDim2.fromOffset(10, 20), BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.15, Rotation = dir * 5, BorderSizePixel = 0, ZIndex = 3,
			}, box)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, w)
			make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, colorOf(b.color)), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }), Rotation = dir == -1 and 0 or 180 }, w)
			tween(w, b.d, { Size = UDim2.fromOffset(150, 90), Rotation = dir * 28 }, Enum.EasingStyle.Back)
		end
	end
	function K.pillar(b)
		local p = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(60, 10), BackgroundColor3 = colorOf(b.color), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 1,
		}, box)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.8) }), Rotation = 90 }, p)
		tween(p, 1.0, { Size = UDim2.fromOffset(90, 900) })
		task.delay(math.max(b.d - 0.6, 0.2), function()
			if alive then
				tween(p, 0.6, { BackgroundTransparency = 1 })
			end
		end)
	end
	function K.split(b)
		for i = 1, 2 do
			local dir = i == 1 and -1 or 1
			local h = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(dir * 6, 0), Size = UDim2.fromOffset(40, 80), BackgroundColor3 = colorOf(b.color), BackgroundTransparency = 0.2,
				BorderSizePixel = 0, ZIndex = 3,
			}, box)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, h)
			tween(h, b.d, { Position = UDim2.fromOffset(dir * 110, 20), Rotation = dir * 40, BackgroundTransparency = 1 })
		end
	end

	-- compteur « 1 sur N » : monte de 1 à N en 0,8 s (12 paliers), puis rebondit
	local function runCounter(c)
		local to = num(c.to, nil)
		if to == nil or to < 1 or counter == nil then
			return
		end
		local fmt = type(opts.fmtOdds) == "function" and opts.fmtOdds or defaultOdds
		local steps = math.max(1, math.min(60, math.floor(num(c.steps, 12))))
		local list = countSteps(to, steps)
		counter.Visible = true
		if plan.special then
			counter.TextColor3 = Color3.fromRGB(255, 220, 90)
		end
		task.spawn(function()
			for i = 1, #list do
				if not alive then
					return
				end
				local ok, txt = pcall(fmt, list[i])
				counter.Text = ok and type(txt) == "string" and txt or defaultOdds(list[i])
				task.wait(math.max(num(c.d, 0.8) / #list, 0.02))
			end
			if alive then
				tween(counter, 0.15, { TextSize = 34 }, Enum.EasingStyle.Back)
				task.delay(0.15, function()
					if alive then
						tween(counter, 0.2, { TextSize = 26 })
					end
				end)
			end
		end)
	end

	local function doReveal()
		reveal()
		safe(opts.sound, plan.sound.fanfare and "fanfare" or plan.sound.key, 0.8)
		if plan.sound.fanfare then
			safe(opts.sound, plan.sound.key, 0.8)
		end
		if plan.secretSound then
			safe(opts.sound, "secret", 0.9)
		end
		if pet ~= nil then
			pet.Visible = true
			tween(pet, 0.5, { Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(0, -20) }, Enum.EasingStyle.Elastic)
		end
		if type(plan.counter) == "table" then
			runCounter(plan.counter)
		end
	end

	local okSetup = pcall(function()
		if type(plan) ~= "table" or type(plan.beats) ~= "table" or type(plan.sound) ~= "table" then
			error("plan invalide")
		end
		local duration = math.max(0.2, math.min(8, num(plan.duration, 2)))
		alive = true
		root = make("TextButton", {
			Name = "HatchFx", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 50, Active = true, BorderSizePixel = 0,
		}, parent)
		stage = make("Frame", { Name = "Stage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 51 }, root)
		box = make("Frame", { Name = "Center", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 52 }, stage)
		flashF = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0, ZIndex = 60 }, stage)
		blackF = make("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0, ZIndex = 53 }, stage)
		egg = make("TextLabel", {
			Name = "Egg", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1, Text = "🥚", TextScaled = true, Font = FONT, ZIndex = 56,
		}, box)
		counter = make("TextLabel", {
			Name = "Odds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 100), Size = UDim2.fromOffset(300, 34), BackgroundTransparency = 1, Text = "", TextSize = 26, Font = FONT,
			TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(24, 16, 30), Visible = false, ZIndex = 70,
		}, box)
		hint = make("TextLabel", {
			Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(240, 22), BackgroundTransparency = 1, Text = "Touche pour passer",
			TextSize = 14, Font = FONT, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, ZIndex = 71,
		}, stage)
		if type(opts.petText) == "string" and opts.petText ~= "" then
			pet = make("TextLabel", {
				Name = "Pet", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Text = opts.petText, TextScaled = true,
				Font = FONT, Visible = false, ZIndex = 65,
			}, box)
		end
		-- caméra (zoom) : seulement si la valeur d'origine est un nombre
		pcall(function()
			local c = workspace.CurrentCamera
			local fov = c and c.FieldOfView
			if plan.camera ~= false and type(fov) == "number" then
				cam, baseFov = c, fov
			end
		end)
		-- interfaces masquées
		if type(opts.hide) == "table" then
			for i = 1, #opts.hide do
				local g = opts.hide[i]
				pcall(function()
					local was = g.Enabled
					if type(was) == "boolean" then
						hidden[#hidden + 1] = { gui = g, was = was }
						g.Enabled = false
					end
				end)
			end
		end
		-- passage par un tap
		local noSkip = plan.noSkip == true
		local skipAfter = num(plan.skipAfter, 1.5)
		local function trySkip()
			if alive and not noSkip and os.clock() - startClock >= skipAfter then
				finish(true)
			end
		end
		root.Activated:Connect(trySkip)
		if not noSkip then
			task.delay(skipAfter, function()
				if alive then
					tween(hint, 0.3, { TextTransparency = 0.2 })
				end
			end)
		end
		-- sons de départ
		safe(opts.sound, plan.sound.key == "hatchSecret" and "hatchSecret" or "hatch", 0.6)
		if plan.sound.divine then
			safe(opts.sound, "divine", 0.8)
		end
		-- prises
		for i = 1, #plan.beats do
			local b = plan.beats[i]
			if type(b) == "table" and type(b.kind) == "string" and K[b.kind] ~= nil then
				local nb = {}
				for k, v in pairs(b) do
					nb[k] = v
				end
				nb.t, nb.d, nb.n = math.max(0, num(b.t, 0)), math.max(0, num(b.d, 0.3)), math.max(0, math.min(30, math.floor(num(b.n, 0))))
				local function run()
					if alive then
						pcall(K[nb.kind], nb)
					end
				end
				if nb.t <= 0 then
					run()
				else
					task.delay(nb.t, run)
				end
			end
		end
		task.delay(math.max(0, num(plan.revealAt, 0.5)), function()
			if alive then
				pcall(doReveal)
			end
		end)
		task.delay(duration, function()
			finish(false)
		end)
		task.delay(duration + HatchFx.WATCHDOG_MARGIN, function()
			finish(false) -- chien de garde : tout est restitué même si une prise a échoué
		end)
	end)

	if not okSetup then
		finish(true)
		return nil
	end
	return {
		root = root,
		skip = function()
			if alive and plan.noSkip ~= true and os.clock() - startClock >= num(plan.skipAfter, 1.5) then
				finish(true)
			end
		end,
		stop = function()
			finish(true)
		end,
		isDone = function()
			return done
		end,
		created = function()
			return created
		end,
	}
end

return HatchFx
