-- ModuleScript : StarterPlayerScripts/TypeFx   (lot 10, B.6)
-- Effets d'attaque par type (Feu, Eau, Plante, Glace, Foudre, Terre, Ciel, Ombre, Lumière) pour l'écran de combat : attaque de base (0,5 s) et spécial (1,2 s, cercle runique sous
-- l'attaquant + secousse 0,4 s), plus le texte d'efficacité flottant. 100 % dessiné par le code (Frames, TextLabels, UICorner, UIGradient, UIStroke, TweenService), aucun asset.
-- Les DONNÉES viennent de ReplicatedStorage/TypeFx (table DATA, exposée plus tard comme Config.TYPE_FX) et sont PASSÉES en paramètre : ce module n'a aucun require et
-- ne fait rien à l'import. Chaque couche d'une donnée crée exactement `n` objets : coût d'un effet = 1 + somme des n (ReplicatedStorage/TypeFx.cost), plafond dur 80 instances.
--
-- BRANCHER (dans l'écran de combat, à chaque événement d'attaque rejoué) :
--   local def = Config.TYPE_FX[attackerType]            -- ou TypeFxData.get(type) ; nil -> aucun effet
--   local h = TypeFx.play(battleGui, def, isSpecial, {
--       from = Vector2.new(x1, y1), to = Vector2.new(x2, y2),   -- positions en pixels dans `battleGui` (attaquant, cible) ; défaut : 25 % / 75 % de la largeur
--       reduced = isMobile,                                      -- moitié des objets
--       shakeFrame = battlePanel,                                -- (optionnel) cadre secoué par le spécial
--       sound = function(key) ... end, onDone = function() ... end })
--   TypeFx.floatText(battleGui, "Super efficace !", rgb, x, y)  -- texte d'efficacité (TypeFxData.efficacy(mult) donne texte et couleur RGB)
-- Retour de play : { stop, isDone, created, root } ou nil (def invalide). Tout est détruit tout seul (durée + persistance au sol + marge). Pas de += ni de continue.
local TypeFx = {}

TypeFx.MAX_INSTANCES = 80
TypeFx.MARGIN = 0.4

local FONT = Enum.Font.GothamBold
local RUNES = { "ᚠ", "ᚢ", "ᚦ", "ᚨ", "ᚱ", "ᚲ", "ᚷ", "ᚹ" }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return v
	end
	return default
end

local function pt(v, dx, dy)
	if type(v) == "table" then
		local x, y = v.X, v.Y
		if type(x) == "number" and type(y) == "number" then
			return x, y
		end
	end
	return dx, dy
end

function TypeFx.play(parent, def, special, opts)
	opts = type(opts) == "table" and opts or {}
	if type(def) ~= "table" or type(def.rgb) ~= "table" then
		return nil
	end
	local fx = special and def.special or def.basic
	if type(fx) ~= "table" or type(fx.layers) ~= "table" then
		return nil
	end
	local created, done, alive = 0, false, true
	local root
	local TweenService
	pcall(function()
		TweenService = game:GetService("TweenService")
	end)
	local main = Color3.fromRGB(num(def.rgb[1], 255), num(def.rgb[2], 255), num(def.rgb[3], 255))
	local function colorOf(key)
		if key == "dark" then
			return Color3.fromRGB(30, 22, 24)
		elseif key == "white" then
			return Color3.new(1, 1, 1)
		end
		return main
	end
	local function tween(obj, seconds, goal, style, dir)
		if TweenService == nil then
			return
		end
		pcall(function()
			TweenService:Create(obj, TweenInfo.new(math.max(seconds, 0.05), style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal):Play()
		end)
	end
	-- objet compté (1 par n) ; décorations non comptées
	local function ob(class, props)
		if created >= TypeFx.MAX_INSTANCES then
			error("plafond d'instances")
		end
		created = created + 1
		local o = Instance.new(class)
		for k, v in pairs(props) do
			o[k] = v
		end
		o.Parent = root
		return o
	end
	local function deco(class, props, par)
		local o = Instance.new(class)
		for k, v in pairs(props) do
			o[k] = v
		end
		o.Parent = par
		return o
	end
	local function glyph(g, size, x, y, extra)
		local props = {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Text = g, TextScaled = true,
			Font = FONT, TextColor3 = main, ZIndex = 95,
		}
		if extra then
			for k, v in pairs(extra) do
				props[k] = v
			end
		end
		return ob("TextLabel", props)
	end

	local W, H = 800, 450
	pcall(function()
		local s = parent.AbsoluteSize
		if type(s.X) == "number" and type(s.Y) == "number" and s.X > 0 and s.Y > 0 then
			W, H = s.X, s.Y
		end
	end)
	local x1, y1 = pt(opts.from, W * 0.25, H * 0.5)
	local x2, y2 = pt(opts.to, W * 0.75, H * 0.5)
	local dx, dy = x2 - x1, y2 - y1
	local reduced = opts.reduced == true

	local P = {} -- primitives : chacune crée exactement L.n objets
	function P.shoot(L, n)
		for i = 1, n do
			local o = glyph(L.glyph or "●", num(L.size, 24), x1, y1, { Rotation = 0 })
			local spread = (i - (n + 1) / 2) * 14
			task.delay((i - 1) * 0.05, function()
				if alive then
					tween(o, math.max(L.d - (i - 1) * 0.05, 0.1), { Position = UDim2.fromOffset(x2, y2 + spread), Rotation = L.spin and 360 or 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.delay(math.max(L.d - (i - 1) * 0.05, 0.1), function()
						if alive then
							tween(o, 0.1, { TextTransparency = 1 })
						end
					end)
				end
			end)
		end
	end
	function P.burst(L, n)
		for i = 1, n do
			local a = (i / n) * math.pi * 2 + 0.5
			local o = glyph(L.glyph or "✦", 18, x2, y2)
			tween(o, L.d, { Position = UDim2.fromOffset(x2 + math.cos(a) * num(L.dist, 50), y2 + math.sin(a) * num(L.dist, 50)), TextTransparency = 1, Rotation = 90 })
		end
	end
	function P.cone(L, n)
		for i = 1, n do
			local spreadAngle = (i - (n + 1) / 2) * 0.09
			local len = math.sqrt(dx * dx + dy * dy)
			local base = math.atan(dy / (dx == 0 and 1e-6 or dx)) + (dx < 0 and math.pi or 0)
			local a = base + spreadAngle
			local o = glyph(L.glyph or "●", num(L.size, 24), x1, y1, { TextTransparency = 0.1 })
			task.delay((i - 1) * 0.04, function()
				if alive then
					tween(o, math.max(L.d - (i - 1) * 0.04, 0.1), { Position = UDim2.fromOffset(x1 + math.cos(a) * len * 0.9, y1 + math.sin(a) * len * 0.9), TextTransparency = 1, Size = UDim2.fromOffset(46, 46) })
				end
			end)
		end
	end
	function P.bolt(L, n)
		local px, py = x1, y1
		for i = 1, n do
			local k = i / n
			local nx = x1 + dx * k
			local ny = y1 + dy * k + (i == n and 0 or ((i % 2 == 0) and 1 or -1) * (14 + (i * 7) % 12))
			local sdx, sdy = nx - px, ny - py
			local len = math.sqrt(sdx * sdx + sdy * sdy)
			local seg = ob("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((px + nx) / 2, (py + ny) / 2), Size = UDim2.fromOffset(len + 2, 4), BackgroundColor3 = L.color == "dark" and colorOf("dark") or main,
				Rotation = math.deg(math.atan(sdy / (sdx == 0 and 1e-6 or sdx))), BorderSizePixel = 0, ZIndex = 95, BackgroundTransparency = 1,
			})
			task.delay((i - 1) * (L.d / n) * 0.6, function()
				if alive then
					seg.BackgroundTransparency = 0
					tween(seg, math.max(L.d * 0.5, 0.1), { BackgroundTransparency = 1 })
				end
			end)
			px, py = nx, ny
		end
	end
	function P.column(L, n)
		for i = 1, n do
			local x = x2 + (i - (n + 1) / 2) * (n == 1 and 0 or 26)
			local width = num(L.size, 20)
			local height, color = 90, main
			if L.glyph == "pillar" then
				height, color = 260, Color3.fromRGB(255, 240, 170)
			elseif L.glyph == "rock" then
				height, color = 40 + (i % 2) * 14, Color3.fromRGB(130, 96, 66)
			elseif L.glyph == "vine" then
				width, height = 8, 80 + (i % 3) * 14
			end
			local c = ob("Frame", {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(x, y2 + 40), Size = UDim2.fromOffset(width, 6), BackgroundColor3 = color, BorderSizePixel = 0,
				Rotation = L.glyph == "rock" and 0 or ((i % 3) - 1) * 8, ZIndex = 94,
			})
			deco("UICorner", { CornerRadius = UDim.new(L.glyph == "spike" and 0.1 or 0.4, 0) }, c)
			tween(c, L.d * 0.5, { Size = UDim2.fromOffset(width, height) }, Enum.EasingStyle.Back)
			task.delay(L.d, function()
				if alive then
					tween(c, 0.25, { BackgroundTransparency = 1 })
				end
			end)
		end
	end
	function P.ring(L, n)
		for i = 1, n do
			local r = ob("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x2, y2 + 30), Size = UDim2.fromOffset(30, 10), BackgroundTransparency = 1, ZIndex = 93 })
			deco("UICorner", { CornerRadius = UDim.new(0.5, 0) }, r)
			local stroke = deco("UIStroke", { Color = main, Thickness = 5, Transparency = 0.1 }, r)
			task.delay((i - 1) * 0.22, function()
				if alive then
					tween(r, math.max(L.d - (i - 1) * 0.22, 0.2), { Size = UDim2.fromOffset(280 + i * 50, 90 + i * 16) }, Enum.EasingStyle.Quint)
					tween(stroke, math.max(L.d - (i - 1) * 0.22, 0.2), { Transparency = 1 })
				end
			end)
		end
	end
	function P.flash(L, n)
		local f = ob("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = main:Lerp(Color3.new(1, 1, 1), 0.5), BackgroundTransparency = 1 - num(L.alpha, 0.4), BorderSizePixel = 0, ZIndex = 99 })
		tween(f, math.max(L.d, 0.1), { BackgroundTransparency = 1 })
	end
	function P.runes(L, n)
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local r = glyph(RUNES[(i - 1) % #RUNES + 1], 22, x1 + math.cos(a) * 70, y1 + 36 + math.sin(a) * 22, { TextTransparency = 1, ZIndex = 90 })
			tween(r, 0.25, { TextTransparency = 0.05 })
			task.delay(math.max(L.d - 0.25, 0.1), function()
				if alive then
					tween(r, 0.25, { TextTransparency = 1 })
				end
			end)
		end
	end
	function P.decal(L, n)
		local d = ob("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x2, y2 + 40), Size = UDim2.fromOffset(20, 8), BackgroundColor3 = colorOf(L.color), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 88,
		})
		deco("UICorner", { CornerRadius = UDim.new(0.5, 0) }, d)
		tween(d, L.d, { Size = UDim2.fromOffset(160, 50), BackgroundTransparency = 0.5 })
		task.delay(num(fx.linger, 0) + L.d, function()
			if alive then
				tween(d, 0.3, { BackgroundTransparency = 1 })
			end
		end)
	end
	function P.spiral(L, n)
		for i = 1, n do
			local k = i / n
			local o = glyph(L.glyph or "☁", num(L.size, 24), x2, y2 + 40, { TextTransparency = 0.2 })
			local a = k * math.pi * 4
			tween(o, L.d, { Position = UDim2.fromOffset(x2 + math.cos(a) * 55, y2 + 40 - k * 120), Rotation = 360, TextTransparency = 0.8 })
		end
	end
	function P.chainring(L, n)
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local link = ob("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x2 + math.cos(a) * 120, y2 + math.sin(a) * 70), Size = UDim2.fromOffset(16, 26), BackgroundTransparency = 1,
				Rotation = math.deg(a), ZIndex = 94,
			})
			deco("UICorner", { CornerRadius = UDim.new(0.5, 0) }, link)
			deco("UIStroke", { Color = main, Thickness = 4 }, link)
			tween(link, L.d * 0.7, { Position = UDim2.fromOffset(x2 + math.cos(a) * 30, y2 + math.sin(a) * 20) }, Enum.EasingStyle.Back)
			task.delay(L.d, function()
				if alive then
					tween(link, 0.25, { Rotation = 300 })
				end
			end)
		end
	end
	function P.beam(L, n)
		local len = math.sqrt(dx * dx + dy * dy)
		local b = ob("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2), Size = UDim2.fromOffset(len, 4), BackgroundColor3 = Color3.fromRGB(255, 240, 170),
			Rotation = math.deg(math.atan(dy / (dx == 0 and 1e-6 or dx))), BorderSizePixel = 0, ZIndex = 95,
		})
		deco("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, b)
		tween(b, L.d, { Size = UDim2.fromOffset(len, 22), BackgroundTransparency = 1 })
	end

	local total = num(fx.d, 0.5) + num(fx.linger, 0)
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

	local ok = pcall(function()
		root = Instance.new("Frame")
		created = created + 1
		root.Name = "TypeFx"
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.BorderSizePixel = 0
		root.Active = false
		root.ZIndex = 90
		root.Parent = parent
		for i = 1, #fx.layers do
			local L = fx.layers[i]
			local run = type(L) == "table" and P[L.prim] or nil
			if run ~= nil then
				local n = math.max(1, math.min(30, math.floor(num(L.n, 1))))
				if reduced then
					n = math.max(1, math.floor(n / 2))
				end
				local layer = { glyph = L.glyph, size = L.size, dist = L.dist, color = L.color, spin = L.spin, alpha = L.alpha, d = math.max(0.1, num(L.d, 0.3)) }
				local t = math.max(0, num(L.t, 0))
				local function go()
					if alive then
						pcall(run, layer, n)
					end
				end
				if t <= 0 then
					go()
				else
					task.delay(t, go)
				end
			end
		end
		-- secousse du cadre de combat pendant le spécial
		local shakeT = num(fx.shake, 0)
		if shakeT > 0 and opts.shakeFrame ~= nil then
			local f = opts.shakeFrame
			local okPos, orig = pcall(function()
				return f.Position
			end)
			task.spawn(function()
				local t0 = os.clock()
				while alive and os.clock() - t0 < shakeT do
					local k = (1 - (os.clock() - t0) / shakeT) * 5
					pcall(function()
						f.Position = orig + UDim2.fromOffset(math.sin((os.clock() - t0) * 80) * k, math.cos((os.clock() - t0) * 60) * k)
					end)
					task.wait(0.03)
				end
				if okPos then
					pcall(function()
						f.Position = orig
					end)
				end
			end)
		end
		if type(opts.sound) == "function" then
			pcall(opts.sound, special and "special" or "attack")
		end
		task.delay(total + TypeFx.MARGIN, finish)
	end)
	if not ok then
		finish()
		return nil
	end
	return {
		root = root,
		stop = finish,
		isDone = function()
			return done
		end,
		created = function()
			return created
		end,
	}
end

-- Texte d'efficacité flottant (« Super efficace ! ») : monte de 40 px en 0,9 s puis disparaît ; rgb = { r, g, b }. Retourne le TextLabel ou nil.
function TypeFx.floatText(parent, text, rgb, x, y)
	local ok, lab = pcall(function()
		local c = type(rgb) == "table" and Color3.fromRGB(num(rgb[1], 255), num(rgb[2], 255), num(rgb[3], 255)) or Color3.new(1, 1, 1)
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromOffset(num(x, 400), num(y, 200))
		l.Size = UDim2.fromOffset(260, 30)
		l.BackgroundTransparency = 1
		l.Text = tostring(text)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = 24
		l.TextColor3 = c
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = Color3.fromRGB(20, 14, 24)
		l.ZIndex = 100
		l.Parent = parent
		local ts = game:GetService("TweenService")
		ts:Create(l, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(num(x, 400), num(y, 200) - 40), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		game:GetService("Debris"):AddItem(l, 1.1)
		return l
	end)
	if ok then
		return lab
	end
	return nil
end

return TypeFx
