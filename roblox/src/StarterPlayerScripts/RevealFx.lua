-- ModuleScript : StarterPlayerScripts/RevealFx
-- Effet de révélation d'un œuf, 100 % dessiné par le code (Frames, UIGradient, UIStroke, UICorner, TweenService) : étoile lumineuse centrale
-- colorée selon la rareté, halo, rayons qui tournent, anneaux qui s'étendent, étincelles, libellé « ŒUF SECRET ». Aucun asset externe.
-- Le style (nombre de rayons, d'anneaux, de particules) vient de Reveal.style : l'option mobile le réduit. Aucune erreur ne sort d'ici.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RevealFx = {}

local DURATION = 2.6

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

-- Nombre d'objets créés pour un style (plafond de performance, vérifié par les tests).
function RevealFx.cost(style)
	-- conteneur 1 + halo 3 (Frame, UICorner, UIGradient) + rayons 1 + 2 par rayon + 3 par anneau + étoile 1 + 1 par étincelle + libellé secret
	return 6 + 2 * style.rays + 3 * style.rings + style.particles + ((style.secret and style.label) and 1 or 0)
end

-- Joue l'effet au centre (position `center`, UDim2) de `parent` (ScreenGui). Retourne le conteneur (détruit tout seul), ou nil en cas d'erreur.
function RevealFx.play(parent, style, center)
	local ok, root = pcall(function()
		local color = style.color
		local box = make("Frame", {
			Name = "RevealFx", AnchorPoint = Vector2.new(0.5, 0.5), Position = center or UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1, ZIndex = 1, Active = false,
		}, parent)
		-- halo : disque dégradé (opaque au centre, transparent au bord)
		local glow = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60), BackgroundColor3 = color, BackgroundTransparency = 0.1, ZIndex = 1 }, box)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, glow)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.85) }), Rotation = 90 }, glow)
		tween(glow, 0.5, { Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 0.7 }, Enum.EasingStyle.Back)
		tween(glow, DURATION, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		-- rayons : conteneur tournant
		local spin = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, ZIndex = 2 }, box)
		for i = 1, style.rays do
			local ray = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(i % 2 == 0 and 7 or 4, i % 2 == 0 and 250 or 190),
				BackgroundColor3 = color, BackgroundTransparency = 0.15, Rotation = (i - 1) * 360 / style.rays, ZIndex = 2,
			}, spin)
			make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Rotation = 90 }, ray)
		end
		spin.Rotation = -20
		tween(spin, DURATION, { Rotation = 70 }, Enum.EasingStyle.Sine)
		-- anneaux
		for i = 1, style.rings do
			local ring = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, ZIndex = 3 }, box)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
			local stroke = make("UIStroke", { Color = color, Thickness = 5, Transparency = 0.1 }, ring)
			task.delay((i - 1) * 0.18, function()
				pcall(function()
					tween(ring, 0.9, { Size = UDim2.fromOffset(240 + i * 70, 240 + i * 70) }, Enum.EasingStyle.Quint)
					tween(stroke, 0.9, { Transparency = 1, Thickness = 1 })
				end)
			end)
		end
		-- étoile centrale : « ★ » avec contour sombre épais et reflet
		local star = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Text = "★", TextScaled = true, Font = Enum.Font.GothamBold,
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45), TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(30, 20, 40), ZIndex = 5, Rotation = -30,
		}, box)
		tween(star, 0.55, { Size = UDim2.fromOffset(150, 150), Rotation = 0 }, Enum.EasingStyle.Elastic)
		task.delay(DURATION - 0.7, function()
			pcall(function()
				tween(star, 0.7, { Size = UDim2.fromOffset(40, 40), TextTransparency = 1, TextStrokeTransparency = 1 })
			end)
		end)
		-- étincelles lancées dans toutes les directions
		for i = 1, style.particles do
			local a = (i / style.particles) * math.pi * 2 + (i % 3) * 0.3
			local dist = 150 + (i % 5) * 38
			local spark = make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Text = i % 2 == 0 and "✦" or "✨",
				TextScaled = true, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3), Font = Enum.Font.GothamBold, ZIndex = 4,
			}, box)
			tween(spark, 0.9 + (i % 4) * 0.15, { Position = UDim2.fromOffset(math.cos(a) * dist, math.sin(a) * dist), TextTransparency = 1 })
		end
		if style.secret and style.label then
			make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, -150), Size = UDim2.fromOffset(360, 36), BackgroundTransparency = 1, Text = style.label,
				TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = color, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(50, 10, 0), ZIndex = 6,
			}, box)
		end
		Debris:AddItem(box, DURATION + 0.6)
		return box
	end)
	return ok and root or nil
end

return RevealFx
