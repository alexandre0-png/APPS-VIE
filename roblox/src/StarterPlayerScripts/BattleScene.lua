-- ModuleScript : StarterPlayerScripts/BattleScene   (refonte de la présentation du combat, vue face à face)
-- Construit l'écran de combat : une scène 3D dans un ViewportFrame (fond de ciel, sol de sable ou d'herbe, décor en arc, deux socles circulaires lumineux, une créature
-- procédurale par camp, caméra fixe en léger angle), la carte de l'adversaire (haut à droite : nom, niveau, barre de PV verte, points d'état de l'équipe), la carte du
-- joueur (bas à gauche : nom, niveau, PV chiffrés, points d'état, pastilles de charge), le bandeau de journal (bas) et les boutons d'action (bas à droite : Attaque,
-- Spécial n/5, Changer, Fuir). TOUTE la disposition vient du module pur ReplicatedStorage/BattleLayout (testé) ; ici : uniquement des instances.
-- Le client N'ENVOIE QU'UNE INTENTION (« attack », « skill », « swapN », abandon) : le serveur revalide tout, rien ne change dans le protocole.
-- Plafond : BattleLayout.MAX_INSTANCES (220) instances vivantes pour la scène ; tout est détruit par destroy() (aucune fuite : boucles arrêtées, racine détruite).
-- Sur mobile (`reduced`) : moitié du décor, ni colonne de lumière ni balancement. Aucune erreur ne sort d'ici (create retourne nil si la construction échoue).
-- Pas de += ni de continue (lanceur lupa).
local BattleScene = {}

local FONT = Enum.Font.GothamBold

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- o = { gui, Config, Battle, Layout, player, payload (message « start »), view, foeName, floor, reduced, iconUrl = fn(clé) -> url|nil, specialState = fn(unité) -> état,
--       fire = fn(action, arg), onChosen = fn() (un choix vient d'être envoyé), onFlee = fn(), safe = { l, t, r, b } (optionnel) }
function BattleScene.create(o)
	if type(o) ~= "table" or type(o.view) ~= "table" or type(o.view.sides) ~= "table" or type(o.view.sides[1]) ~= "table" or type(o.view.sides[2]) ~= "table" or type(o.view.sides[1].units) ~= "table" or type(o.view.sides[2].units) ~= "table" then
		return nil, "vue invalide"
	end
	local L, Config, Battle = o.Layout, o.Config, o.Battle
	local S = { alive = true, used = 0, peak = 0, conns = {}, puppets = {}, cur = {}, swapToken = { 0, 0 }, popups = 0, lastView = nil, fleeToken = 0, dimmed = false, speed = 1, skipGen = 0, seen = 0 }
	if type(o.speed) == "number" then
		S.speed = math.max(1, math.min(3, math.floor(o.speed)))
	end
	local cap = L.MAX_INSTANCES
	local TweenService
	pcall(function()
		TweenService = game:GetService("TweenService")
	end)

	local function make(class, props, parent)
		if S.used >= cap then
			error("plafond d'instances")
		end
		S.used = S.used + 1
		if S.used > S.peak then
			S.peak = S.used
		end
		local inst = Instance.new(class)
		for k, v in pairs(props) do
			inst[k] = v
		end
		inst.Parent = parent
		return inst
	end
	local function release(n)
		S.used = math.max(0, S.used - n)
	end
	local function tween(inst, seconds, goal, style, dir)
		if TweenService == nil then
			for k, v in pairs(goal) do
				pcall(function()
					inst[k] = v
				end)
			end
			return nil
		end
		local ok, tw = pcall(function()
			local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
			t:Play()
			return t
		end)
		return ok and tw or nil
	end
	-- appelle step(a) de 0 à 1 puis s'arrête ; durée bornée à 1,2 s et divisée par la vitesse (1x / 2x / 3x) ; « Passer » termine tout de suite ; s'arrête à la destruction
	local function animate(duration, step)
		local dur = math.max(0.02, o.Layout.animSeconds(duration, S.speed))
		local gen = S.skipGen
		task.spawn(function()
			local t0 = os.clock()
			while S.alive do
				if S.skipGen ~= gen then
					pcall(step, 1)
					return
				end
				local a = (os.clock() - t0) / dur
				if a >= 1 then
					pcall(step, 1)
					return
				end
				pcall(step, a)
				task.wait(0.03)
			end
		end)
	end

	local function viewportSize()
		local ok, w, h = pcall(function()
			local a = o.gui.AbsoluteSize
			return a.X, a.Y
		end)
		if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
			return w, h
		end
		ok, w, h = pcall(function()
			local v = workspace.CurrentCamera.ViewportSize
			return v.X, v.Y
		end)
		if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
			return w, h
		end
		return nil, nil
	end

	local st0 = o.payload or {}
	local mode = L.mode(st0)
	local ground = L.ground(mode)
	local pal = L.palette(ground)
	local view0 = o.view
	local nMe = #(view0.sides[1].units or {})
	local nFoe = #(view0.sides[2].units or {})
	local plan = L.plan({ reduced = o.reduced == true, units1 = nMe, units2 = nFoe })
	S.plan, S.mode, S.ground = plan, mode, ground
	local U = L.UI

	local okBuild, err = pcall(function()
		---------------------------------------------------------------- racine, fond, viewport
		local root = make("Frame", { Name = "BattleScene", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(pal.skyTop), BorderSizePixel = 0, Active = true, ZIndex = 1 }, o.gui)
		S.root = root
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(pal.skyTop), rgb(pal.skyBottom)) }, root)
		local vp = make("ViewportFrame", {
			Name = "World", BackgroundTransparency = 1, Position = UDim2.fromOffset(-5, -5), Size = UDim2.new(1, 10, 1, 10), ZIndex = 2,
			Ambient = rgb(pal.ambient), LightColor = rgb(pal.light), LightDirection = Vector3.new(-0.4, -1, -0.6),
		}, root)
		S.vp = vp
		local cam = make("Camera", { FieldOfView = 40 }, vp)
		vp.CurrentCamera = cam
		S.cam = cam
		S.dim = make("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 12, 16), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, root)

		---------------------------------------------------------------- monde : sol, décor, socles
		local function part(props)
			props.Anchored = true
			props.CanCollide = false
			props.TopSurface = Enum.SurfaceType.Smooth
			props.BottomSurface = Enum.SurfaceType.Smooth
			return make("Part", props, vp)
		end
		local function flatCylinder(name, x, y, z, diameter, height, color, material, transparency)
			return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(color), Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
		end
		flatCylinder("Ground", 0, -0.5, -2, 92, 1, pal.ground)
		flatCylinder("Rim", 0, -0.9, -2, 100, 0.8, pal.rim)
		local spots = L.decorSpots(plan.decor)
		for i, sp in ipairs(spots) do
			if ground == "sand" then -- colonnade du colisée
				part({ Name = "Pillar" .. i, Size = Vector3.new(2.4, sp.h * 2, 2.4), CFrame = CFrame.new(sp.x, sp.h, sp.z), Color = rgb(pal.deco), Material = Enum.Material.Sandstone })
			else -- haies et buissons de l'arène
				part({ Name = "Hedge" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(sp.h * 0.5, 4.5, 4.5), CFrame = CFrame.new(sp.x, sp.h * 0.25, sp.z) * CFrame.Angles(0, 0, math.rad(90)), Color = rgb(pal.deco), Material = Enum.Material.Grass })
			end
		end
		S.pedestals = {}
		for side = 1, 2 do
			local u = view0.sides[side].units[view0.sides[side].active]
			local tcol = L.typeColor(u and u.type)
			S.pedestals[side] = { pos = { x = 0, z = 0 }, base = nil, glow = nil, column = nil, color = tcol }
		end

		---------------------------------------------------------------- éléments d'interface (cartes, bandeau, boutons)
		local function label(parent, props)
			props.BackgroundTransparency = 1
			props.Font = props.Font or FONT
			props.TextColor3 = props.TextColor3 or rgb(U.text)
			props.TextSize = props.TextSize or 14
			props.ZIndex = props.ZIndex or 8
			return make("TextLabel", props, parent)
		end
		local function button(name, text, color, textColor)
			local b = make("TextButton", { Name = name, Font = FONT, TextSize = 15, TextWrapped = true, Text = text, AutoButtonColor = true, BackgroundColor3 = rgb(color), TextColor3 = textColor or rgb(U.darkText), ZIndex = 10 }, root)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
			make("UIStroke", { Color = Color3.fromRGB(10, 18, 22), Thickness = 2 }, b)
			return b
		end
		local function place(inst, r)
			inst.Position = UDim2.fromOffset(r.x, r.y)
			inst.Size = UDim2.fromOffset(r.w, r.h)
		end

		local function buildCard(isMe, name)
			local c = { isMe = isMe, dots = {}, pips = {} }
			c.frame = make("Frame", { Name = name, BackgroundColor3 = rgb(U.card), BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 6 }, root)
			make("UICorner", { CornerRadius = UDim.new(0, 12) }, c.frame)
			make("UIStroke", { Color = rgb(U.cardStroke), Thickness = 2 }, c.frame)
			c.accent = make("Frame", { Name = "Accent", BackgroundColor3 = rgb(L.NEUTRAL_COLOR), BorderSizePixel = 0, ZIndex = 7 }, c.frame)
			c.iconText = label(c.frame, { Name = "IconText", TextSize = 18, Text = "" })
			c.iconImage = nil
			c.name = label(c.frame, { Name = "Name", TextSize = 16, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			c.level = label(c.frame, { Name = "Level", TextSize = 13, Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = rgb(U.muted) })
			c.barBg = make("Frame", { Name = "HpBack", BackgroundColor3 = rgb(U.hpBack), BorderSizePixel = 0, ZIndex = 7 }, c.frame)
			make("UICorner", { CornerRadius = UDim.new(0, 6) }, c.barBg)
			c.fill = make("Frame", { Name = "HpFill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(U.hp), BorderSizePixel = 0, ZIndex = 8 }, c.barBg)
			make("UICorner", { CornerRadius = UDim.new(0, 6) }, c.fill)
			if isMe then
				c.hp = label(c.frame, { Name = "HpText", TextSize = 14, Text = "", TextXAlignment = Enum.TextXAlignment.Left })
			else
				c.ctx = label(c.frame, { Name = "Context", TextSize = 12, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(U.muted), TextTruncate = Enum.TextTruncate.AtEnd })
			end
			return c
		end
		S.foeCard = buildCard(false, "FoeCard")
		S.meCard = buildCard(true, "MeCard")
		local function ensureDots(c, n)
			while #c.dots < math.min(n, L.MAX_DOTS) do
				local d = make("Frame", { Name = "TeamDot", Size = UDim2.fromOffset(10, 10), BackgroundColor3 = rgb(U.dotOff), BorderSizePixel = 0, ZIndex = 8 }, c.frame)
				make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
				c.dots[#c.dots + 1] = d
			end
		end
		ensureDots(S.foeCard, nFoe)
		ensureDots(S.meCard, nMe)
		for i = 1, L.CHARGE_MAX do
			local p = make("Frame", { Name = "ChargePip", Size = UDim2.fromOffset(10, 10), BackgroundColor3 = rgb(U.pipOff), BorderSizePixel = 0, ZIndex = 8 }, S.meCard.frame)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
			S.meCard.pips[i] = p
		end

		S.logFrame = make("Frame", { Name = "LogBar", BackgroundColor3 = rgb(U.log), BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 6 }, root)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, S.logFrame)
		make("UIStroke", { Color = rgb(U.cardStroke), Thickness = 1 }, S.logFrame)
		S.status = label(S.logFrame, { Name = "Status", TextSize = 12, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(U.status), TextTruncate = Enum.TextTruncate.AtEnd })
		S.log = label(S.logFrame, { Name = "LogText", TextSize = 13, Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd })

		S.btn = {
			attack = button("Attack", "⚔ Attaque", U.attack),
			special = button("Special", "Spécial", U.special),
			swap = button("Swap", "🔁 Changer", U.swap, rgb(U.swapText)),
			flee = button("Flee", "🏃 Fuir", U.flee, rgb(U.fleeText)),
		}
		-- bouton Spécial : barre de charge DERRIÈRE le bouton (un dégradé sur le bouton teinterait aussi son texte), échelle et voile du flash quand la charge devient pleine
		S.chargeBar = make("Frame", { Name = "ChargeBar", BackgroundColor3 = rgb(U.specialFill), BorderSizePixel = 0, Visible = false, ZIndex = 9 }, root)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, S.chargeBar)
		S.sGrad = make("UIGradient", { Name = "ChargeGradient", Rotation = 0 }, S.chargeBar)
		S.sScale = make("UIScale", { Name = "SpecialScale", Scale = 1 }, S.btn.special)
		S.sVeil = make("Frame", { Name = "SpecialFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 12 }, S.btn.special)
		-- pastilles d'état sous les cartes (3 par camp au plus : étourdi, garde, concentration) : chacune est aussi sa zone tactile (>= 44 px de haut) et ouvre une info-bulle
		S.pills = { {}, {} }
		S.pillCount = { 0, 0 }
		S.pillList = { {}, {} }
		for side = 1, 2 do
			for i = 1, L.MAX_PILLS do
				local b = make("TextButton", { Name = "StatePill", Font = FONT, TextSize = 15, Text = "", AutoButtonColor = true, Visible = false, BackgroundColor3 = rgb(U.card), TextColor3 = rgb(U.text), ZIndex = 9 }, root)
				make("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
				S.pills[side][i] = { btn = b, data = nil }
			end
		end
		S.tip = make("TextLabel", { Name = "StateTip", Font = FONT, TextSize = 13, TextWrapped = true, Text = "", BackgroundColor3 = rgb(U.log), BackgroundTransparency = 0.05, TextColor3 = rgb(U.text), Visible = false, ZIndex = 13 }, root)
		function S.layoutPills() -- place les pastilles d'après la disposition courante (sans superposition, voir BattleLayout.pillLayout) ; appelée à chaque mise en page et à chaque mise à jour
			if not S.rects then
				return
			end
			local lay = L.pillLayout(S.rects, S.pillCount[2], S.pillCount[1])
			S.pillLay = lay
			for side = 1, 2 do
				local chips = L.pillChips(S.pillList[side], lay[side].shown, Battle)
				for i, p in ipairs(S.pills[side]) do
					local c = chips[i]
					p.data = c
					p.btn.Visible = c ~= nil and not S.dimmed
					if c then
						p.btn.Text = c.text
						p.btn.BackgroundColor3 = rgb(c.bg)
						p.btn.TextColor3 = rgb(c.fg)
						place(p.btn, lay[side].rects[i])
					end
				end
			end
		end

		-- vitesse (1x / 2x / 3x), « Passer l'animation » (dès le 2e combat vu) et ordre du tour (3 pastilles sous la carte adverse)
		S.btn.speed = button("Speed", o.Layout.speedLabel(S.speed), { 255, 226, 140 })
		S.btn.skip = button("Skip", "⏭ Passer", { 255, 226, 140 })
		S.btn.skip.TextSize = 13
		S.btn.skip.Visible = o.canSkip == true
		S.queueLabel = label(root, { Name = "QueueLabel", TextSize = 12, Text = "Ordre ▸", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = rgb(U.text), ZIndex = 8 })
		S.queue = {}
		for i = 1, 3 do
			local f = make("Frame", { Name = "QueueChip" .. i, BackgroundColor3 = rgb(U.card), BorderSizePixel = 0, ZIndex = 8 }, root)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
			local e = label(f, { Name = "QueueEmoji", TextSize = 16, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 9 })
			S.queue[i] = { frame = f, emoji = e }
		end

		---------------------------------------------------------------- mise en page (appelée à la création et à chaque changement de taille)
		local function layoutCard(c, r)
			place(c.frame, r)
			local inner = L.cardInner(r.w, c.isMe)
			c.accent.Position = UDim2.fromOffset(3, 8)
			c.accent.Size = UDim2.fromOffset(4, r.h - 16)
			place(c.iconText, inner.icon)
			if c.iconImage then
				place(c.iconImage, inner.icon)
			end
			place(c.name, inner.name)
			place(c.level, inner.level)
			place(c.barBg, inner.bar)
			if c.hp then
				place(c.hp, inner.hp)
			end
			if c.ctx then
				place(c.ctx, inner.ctx)
			end
			local n = #c.dots
			for i, d in ipairs(c.dots) do
				local x = c.isMe and (inner.dots.x + inner.dots.w - n * 14 + (i - 1) * 14) or (inner.dots.x + (i - 1) * 14)
				d.Position = UDim2.fromOffset(x, inner.dots.y)
			end
			for i, p in ipairs(c.pips) do
				p.Position = UDim2.fromOffset(inner.pips.x + (i - 1) * 14, inner.pips.y)
			end
		end
		local function relayout()
			local vw, vh = viewportSize()
			local R = L.rects(vw, vh, o.safe)
			S.rects = R
			layoutCard(S.foeCard, R.foeCard)
			layoutCard(S.meCard, R.meCard)
			place(S.logFrame, R.log)
			place(S.status, { x = 10, y = 3, w = R.log.w - 20, h = 16 })
			place(S.log, { x = 10, y = 19, w = R.log.w - 20, h = R.log.h - 22 })
			for _, k in ipairs({ "attack", "special", "swap", "flee" }) do
				place(S.btn[k], R.actions[k])
			end
			place(S.chargeBar, R.actions.special)
			S.layoutPills()
			if S.closeSwap then -- changement de taille : l'écran « Changer » se referme (il se reconstruit à la bonne taille à la réouverture)
				S.closeSwap()
			end
			place(S.btn.speed, R.speed)
			place(S.btn.skip, R.skip)
			place(S.queueLabel, { x = R.queue.x - 62, y = R.queue.y, w = 58, h = R.queue.h })
			for i, q in ipairs(S.queue) do
				local d = R.queue.h
				q.frame.Position = UDim2.fromOffset(R.queue.x + R.queue.w - 3 * d - 2 * 4 + (i - 1) * (d + 4), R.queue.y)
				q.frame.Size = UDim2.fromOffset(d, d)
			end
			local sc = L.scene(vw, vh, o.safe, ground)
			S.sc = sc
			S.cam.FieldOfView = sc.fov
			S.cam.CFrame = CFrame.lookAt(Vector3.new(sc.eye.x, sc.eye.y, sc.eye.z), Vector3.new(sc.target.x, sc.target.y, sc.target.z))
			-- socles : créés une fois, replacés à chaque mise en page
			for side = 1, 2 do
				local pd = S.pedestals[side]
				local pos = side == 1 and sc.me or sc.foe
				pd.pos = pos
				if pd.base == nil then
					pd.base = flatCylinder("PedestalBase" .. side, pos.x, 0.4, pos.z, sc.pedestal * 2, 0.8, pal.deco)
					pd.glow = flatCylinder("PedestalGlow" .. side, pos.x, 0.86, pos.z, sc.pedestal * 1.75, 0.14, pd.color, Enum.Material.Neon)
					if plan.beams then
						pd.column = flatCylinder("PedestalLight" .. side, pos.x, 3.4, pos.z, sc.pedestal * 1.6, 5.2, pd.color, Enum.Material.Neon, 0.85)
					end
				else
					pd.base.CFrame = CFrame.new(pos.x, 0.4, pos.z) * CFrame.Angles(0, 0, math.rad(90))
					pd.glow.CFrame = CFrame.new(pos.x, 0.86, pos.z) * CFrame.Angles(0, 0, math.rad(90))
					if pd.column then
						pd.column.Position = Vector3.new(pos.x, 3.4, pos.z)
					end
				end
				local pz = S.puppets[side]
				if pz and pz.model then
					pz.base = S.faceCF(side, pz.lift)
					pcall(function()
						pz.model:PivotTo(pz.base)
					end)
				end
			end
		end

		---------------------------------------------------------------- créatures procédurales (corps, yeux, oreilles, queue ou bec : 7 instances)
		function S.faceCF(side, y) -- position du pivot (centre du corps, hauteur y) et regard vers l'autre socle
			local sc = S.sc
			local me, foe = sc.me, sc.foe
			local from, to = me, foe
			if side == 2 then
				from, to = foe, me
			end
			return CFrame.lookAt(Vector3.new(from.x, y, from.z), Vector3.new(to.x, y, to.z))
		end
		local function buildPuppet(side, u)
			local def = Config.PETS[u.p] or { color = Color3.fromRGB(200, 200, 200), ears = "round", extra = "none" }
			local scale = 1
			local sz = Config.SIZES and Config.SIZES[u.s]
			if sz and type(sz.scale) == "number" then
				scale = math.max(0.8, math.min(1.4, sz.scale))
			end
			local R = 1.5 * scale
			local before = S.used
			local model = make("Model", { Name = "Puppet" .. side }, vp)
			local col = def.color
			local function ball(nm, ox, oy, oz, d, c)
				return make("Part", { Name = nm, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Anchored = true, CanCollide = false, Color = c, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(ox, oy, oz) }, model)
			end
			local function block(nm, ox, oy, oz, sx, sy, sz2, c, rotZ)
				return make("Part", { Name = nm, Size = Vector3.new(sx, sy, sz2), Anchored = true, CanCollide = false, Color = c, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(ox, oy, oz) * CFrame.Angles(0, 0, rotZ or 0) }, model)
			end
			local lift = 0.9 + R
			local body = ball("Body", 0, 0, 0, 2 * R, col)
			model.PrimaryPart = body
			local dark = Color3.fromRGB(25, 25, 30)
			ball("EyeL", -0.42 * R, 0.25 * R, -0.86 * R, 0.36 * R, dark)
			ball("EyeR", 0.42 * R, 0.25 * R, -0.86 * R, 0.36 * R, dark)
			local ears = def.ears or "round"
			if ears == "point" then
				block("EarL", -0.55 * R, 1.0 * R, 0, 0.5 * R, 0.9 * R, 0.2 * R, col, math.rad(15))
				block("EarR", 0.55 * R, 1.0 * R, 0, 0.5 * R, 0.9 * R, 0.2 * R, col, math.rad(-15))
			elseif ears == "long" then
				block("EarL", -0.4 * R, 1.35 * R, 0, 0.35 * R, 1.4 * R, 0.2 * R, col, math.rad(8))
				block("EarR", 0.4 * R, 1.35 * R, 0, 0.35 * R, 1.4 * R, 0.2 * R, col, math.rad(-8))
			elseif ears == "floppy" then
				block("EarL", -0.95 * R, 0.55 * R, 0, 0.5 * R, 0.9 * R, 0.2 * R, col, math.rad(40))
				block("EarR", 0.95 * R, 0.55 * R, 0, 0.5 * R, 0.9 * R, 0.2 * R, col, math.rad(-40))
			elseif ears ~= "none" then
				ball("EarL", -0.7 * R, 0.85 * R, 0, 0.5 * R, col)
				ball("EarR", 0.7 * R, 0.85 * R, 0, 0.5 * R, col)
			end
			local extra = def.extra or "none"
			if extra == "beak" then
				block("Beak", 0, -0.05 * R, -1.05 * R, 0.4 * R, 0.25 * R, 0.5 * R, Color3.fromRGB(255, 160, 40), 0)
			elseif extra == "tail" then
				ball("Tail", 0, -0.1 * R, 1.0 * R, 0.5 * R, col)
			end
			local base = S.faceCF(side, lift)
			model:PivotTo(base)
			return { model = model, body = body, base = base, lift = lift, count = S.used - before, busy = 0, color = col }
		end
		local function destroyPuppet(pz)
			if pz and pz.model then
				pcall(function()
					pz.model:Destroy()
				end)
				release(pz.count or 0)
			end
		end
		S.destroyPuppet = destroyPuppet
		function S.setPuppet(side, u, animateIn)
			local old = S.puppets[side]
			local newp = buildPuppet(side, u)
			S.puppets[side] = newp
			destroyPuppet(old)
			if animateIn then
				newp.busy = newp.busy + 1
				animate(0.3, function(a)
					if newp.model then
						newp.model:PivotTo(newp.base * CFrame.new(0, 6 * (1 - a) * (1 - a), 0))
					end
					if a >= 1 then
						newp.busy = math.max(0, newp.busy - 1)
					end
				end)
			end
		end
		S.build = buildPuppet

		relayout()
		S.relayout = relayout
		for side = 1, 2 do
			local sd = view0.sides[side]
			local u = sd.units[sd.active]
			if u then
				S.puppets[side] = nil
				S.setPuppet(side, u, false)
				S.cur[side] = tostring(u.p) .. ":" .. tostring(sd.active)
			end
		end
	end)
	if not okBuild then
		S.alive = false
		if S.root then
			pcall(function()
				S.root:Destroy()
			end)
		end
		return nil, err
	end

	---------------------------------------------------------------- API
	local scene = { root = S.root, viewport = S.vp, shake = S.vp, plan = plan, mode = mode, ground = ground }

	function scene.count()
		return S.used
	end
	function scene.peak()
		return S.peak
	end
	function scene.alive()
		return S.alive
	end

	-- PV : la barre se vide (ou se remplit) en ~0,5 s et le chiffre défile, sans saut ; une nouvelle valeur reprend là où le défilement en est
	local function showHp(c, v, max)
		local frac = max > 0 and math.max(0, math.min(1, v / max)) or 0
		c.fill.Size = UDim2.fromScale(frac, 1)
		c.fill.BackgroundColor3 = rgb(L.hpColor(frac))
		if c.hp then
			c.hp.Text = math.max(0, math.floor(v + 0.0001)) .. "/" .. math.floor(max) .. (c.hpExtra or "")
		end
	end
	local function rollHp(c, u, instant, delay)
		local max = u and type(u.maxHp) == "number" and u.maxHp or 0
		local to = u and type(u.hp) == "number" and math.max(0, math.min(max, u.hp)) or 0
		local from = c.shownHp
		c.rollToken = (c.rollToken or 0) + 1
		local token = c.rollToken
		if instant or from == nil or c.shownMax ~= max then
			c.shownHp, c.shownMax = to, max
			showHp(c, to, max)
			return
		end
		c.shownMax = max
		if from == to then
			showHp(c, to, max)
			return
		end
		local function run()
			if c.rollToken ~= token or not S.alive then
				return
			end
			animate(L.HP_ROLL_SECONDS, function(a)
			if c.rollToken ~= token then
				return
			end
				local v = L.hpRoll(from, to, a)
				c.shownHp = v
				showHp(c, a >= 1 and to or L.hpRollInt(from, to, a), max)
				if a >= 1 then
					c.shownHp = to
				end
			end)
		end
		if type(delay) == "number" and delay > 0 then -- la barre se vide à l'impact du coup, pas avant
			task.delay(delay, run)
		else
			run()
		end
	end
	local function setIcon(c, u)
		local typ = u and u.type
		c.accent.BackgroundColor3 = rgb(L.typeColor(typ))
		local key = Config.TYPE_ICON and Config.TYPE_ICON[typ]
		local url = key and type(o.iconUrl) == "function" and o.iconUrl(key) or nil
		if url and c.iconImage == nil and S.used < cap then
			c.iconImage = make("ImageLabel", { Name = "TypeIcon", BackgroundTransparency = 1, Image = url, ZIndex = 9 }, c.frame)
			local r = S.rects and (c.isMe and S.rects.meCard or S.rects.foeCard)
			if r then
				local inner = L.cardInner(r.w, c.isMe)
				place(c.iconImage, inner.icon)
			end
		elseif url and c.iconImage then
			c.iconImage.Image = url
		end
		c.iconText.Text = c.iconImage and "" or ((Battle.TYPE_EMOJI and Battle.TYPE_EMOJI[typ]) or "")
	end
	local function unitName(u)
		local def = u and Config.PETS[u.p]
		return def and (def.emoji .. " " .. def.name) or "?"
	end
	local function updateCard(c, side, animateIt, hpDelay)
		local u = side.units[side.active]
		c.name.Text = unitName(u)
		c.level.Text = L.levelText(u)
		local key = u and (tostring(u.p) .. ":" .. tostring(side.active)) or nil
		c.hpExtra = (u and u.guard and " 🛡" or "") .. (u and type(u.stun) == "number" and u.stun > 0 and " 💫" or "") .. (u and type(u.focus) == "number" and u.focus > 0 and " ⚡" or "")
		rollHp(c, u, animateIt ~= true or key ~= c.unitKey, hpDelay)
		c.unitKey = key
		setIcon(c, u)
		local dots = L.teamDots(side)
		for i, d in ipairs(c.dots) do
			local info = dots[i]
			d.BackgroundColor3 = rgb(info and info.alive and U.dotOn or U.dotOff)
			d.Size = UDim2.fromOffset(info and info.active and 11 or 10, info and info.active and 11 or 10)
		end
	end

	function scene.setContext(text)
		S.foeCard.ctx.Text = tostring(text or "")
	end
	function scene.setStatus(text)
		S.status.Text = tostring(text or "")
	end
	function scene.setLog(lines)
		S.log.Text = type(lines) == "table" and table.concat(lines, "\n") or tostring(lines or "")
	end

	-- Bouton Spécial : texte, prêt ou non, et animation de charge (la partie chargée du fond est claire, le reste sombre ; coupure nette à charge / max).
	local function setSpecialButton(sb)
		local b = S.btn.special
		b.Text = sb.text
		b.AutoButtonColor = sb.ready
		b.BackgroundColor3 = rgb(U.special)
		b.BackgroundTransparency = sb.ready and 0 or 1 -- pas prêt : le fond est la barre de charge placée derrière
		b.TextColor3 = sb.ready and rgb(U.darkText) or rgb(U.offText)
		local frac = sb.ready and 1 or L.chargeFill(sb.charge, sb.max)
		S.chargeFrac = frac
		S.specialReady = sb.ready == true
		S.chargeBar.Visible = not sb.ready and not S.dimmed
		pcall(function()
			local pts = {}
			for _, p in ipairs(L.chargeStops(frac, 0.55)) do
				pts[#pts + 1] = ColorSequenceKeypoint.new(p.t, Color3.new(p.m, p.m, p.m))
			end
			S.sGrad.Color = ColorSequence.new(pts)
		end)
	end
	-- Flash du spécial (charge pleine pour le MÊME pet) : voile blanc qui s'éteint, bouton qui gonfle de 12 % puis revient, son « special_ready ». Au plus 1,5 s (0,35 s en
	-- effets réduits), divisé par la vitesse ; « Passer » le termine ; un seul flash à la fois ; arrêté à la destruction.
	function S.flashSpecial()
		S.flashToken = (S.flashToken or 0) + 1
		local token = S.flashToken
		local dur = L.flashSeconds(o.reduced == true, S.speed)
		if type(o.sound) == "function" then
			pcall(o.sound, "special_ready")
		end
		S.sVeil.Visible = true
		local gen = S.skipGen
		task.spawn(function()
			local t0 = os.clock()
			while S.alive and S.flashToken == token do
				local a = (os.clock() - t0) / math.max(0.02, dur)
				if S.skipGen ~= gen then
					a = 1
				end
				local f = L.specialFlash(a)
				pcall(function()
					S.sVeil.BackgroundTransparency = f.veilTransparency
					S.sScale.Scale = o.reduced == true and 1 or f.scale
				end)
				if a >= 1 then
					break
				end
				task.wait(0.03)
			end
			if S.alive and S.flashToken == token then
				pcall(function()
					S.sVeil.Visible = false
					S.sVeil.BackgroundTransparency = 1
					S.sScale.Scale = 1
				end)
			end
		end)
	end
	local function setPips(c, mu)
		local info = L.chargePips(mu and mu.charge, mu and mu.chargeMax)
		if c.pulseTween then
			pcall(function()
				c.pulseTween:Cancel()
			end)
			c.pulseTween = nil
		end
		for i, p in ipairs(c.pips) do
			p.BackgroundColor3 = rgb(info.pips[i] and U.pipOn or U.pipOff)
			p.Size = UDim2.fromOffset(10, 10)
		end
		local last = c.pips[#c.pips]
		if info.ready and last and mu and type(mu.charge) == "number" and not o.reduced then
			c.pulseTween = tween(last, 0.45, { Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end
	-- Le bouton « Changer » n'est actif que s'il reste au moins un pet vivant en réserve.
	local function updateSwapButton(sd)
		local any = false
		for _, e in ipairs(L.bench(sd)) do
			if e.alive then
				any = true
			end
		end
		S.swapAny = any
		S.btn.swap.AutoButtonColor = any
		S.btn.swap.BackgroundColor3 = rgb(any and U.swap or U.specialOff)
		S.btn.swap.TextColor3 = rgb(any and U.swapText or U.offText)
	end

	-- Pastilles d'état d'un camp (1 = joueur, 2 = adversaire) : icône + durée, couleur propre à chaque état, rien pour un pet K.O.
	local function setPills(sideIdx, u)
		local list = L.statusPills(u)
		S.pillCount[sideIdx] = #list
		S.pillList[sideIdx] = list
		S.layoutPills()
		if S.tipSide == sideIdx and #list == 0 then
			S.hideTip()
		end
	end
	function S.hideTip()
		S.tipToken = (S.tipToken or 0) + 1
		S.tipSide = nil
		S.tip.Visible = false
	end
	-- Info-bulle d'une pastille : icône, nom et durée (BattleLayout.pillDetail) ; disparaît seule après TIP_SECONDS ou au toucher suivant.
	function S.showTip(sideIdx, i)
		local p = S.pills[sideIdx][i]
		if not (p and p.data and S.alive and not S.dimmed) then
			return
		end
		S.tipToken = (S.tipToken or 0) + 1
		local token = S.tipToken
		local vw, vh = viewportSize()
		vw, vh = L.viewport(vw, vh)
		local r = S.pillLay and S.pillLay[sideIdx].rects[i] or nil
		local lines = 1
		for _ in string.gmatch(p.data.detail, "\n") do
			lines = lines + 1
		end
		local w, h = math.min(300, vw - 16), 20 + 24 * lines
		S.tip.Text = p.data.detail
		S.tip.Size = UDim2.fromOffset(w, h)
		local x = math.max(8, math.min(vw - 8 - w, (r and r.x or 8) - 8))
		local y = sideIdx == 2 and ((r and (r.y + r.h) or 0) + 4) or ((r and r.y or 0) - 4 - h)
		S.tip.Position = UDim2.fromOffset(x, math.max(0, math.min(vh - h, y)))
		S.tip.Visible = true
		S.tipSide = sideIdx
		task.delay(L.TIP_SECONDS, function()
			if S.alive and S.tipToken == token then
				S.hideTip()
			end
		end)
	end

	-- Écran dédié « Changer » : une ligne par pet de l'équipe (nom, niveau, PV chiffrés et barre, charge du spécial, état). Pet K.O. : grisé, non cliquable ; pet au combat :
	-- affiché, non cliquable ; les autres envoient « swapN » (intention seule, le serveur revalide). Construit à l'ouverture, détruit à la fermeture (aucune instance qui traîne).
	function S.closeSwap()
		local ui = S.swapUi
		if not ui then
			return
		end
		S.swapUi = nil
		for _, c in ipairs(ui.conns or {}) do
			pcall(function()
				c:Disconnect()
			end)
		end
		pcall(function()
			ui.frame:Destroy()
		end)
		release(ui.count)
	end
	function S.openSwap()
		if S.swapUi or S.dimmed or not S.alive or not S.lastView or not S.swapAny then
			return
		end
		local rows = L.swapRows(S.lastView.sides[1])
		if #rows == 0 then
			return
		end
		S.hideTip()
		local vw, vh = viewportSize()
		local Rs = L.swapRects(vw, vh, o.safe, #rows)
		local before = S.used
		local okOpen, ui = pcall(function()
			local px, py = Rs.panel.x, Rs.panel.y
			local function rel(r)
				return { x = r.x - px, y = r.y - py, w = r.w, h = r.h }
			end
			local function place(inst, r)
				inst.Position = UDim2.fromOffset(r.x, r.y)
				inst.Size = UDim2.fromOffset(r.w, r.h)
			end
			local function label(parent, props)
				props.BackgroundTransparency = 1
				props.Font = FONT
				props.TextColor3 = props.TextColor3 or rgb(U.text)
				return make("TextLabel", props, parent)
			end
			local frame = make("Frame", { Name = "SwapScreen", BackgroundColor3 = rgb(U.card), BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 14, Active = true }, S.root)
			place(frame, Rs.panel)
			S.swapTmp = frame
			local u = { frame = frame, rows = {}, conns = {} }
			local function conn(sig, fn)
				u.conns[#u.conns + 1] = sig:Connect(fn)
			end
			local title = label(frame, { Name = "SwapTitle", TextSize = 18, Text = "🔁 Changer de pet", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 15 })
			place(title, rel(Rs.title))
			local note = label(frame, { Name = "SwapNote", TextSize = 12, Text = "Changer remplace ton action et passe en premier.", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(U.muted), ZIndex = 15 })
			place(note, rel(Rs.note))
			for i, row in ipairs(rows) do
				local def = Config.PETS[row.p]
				local bg = row.state == "ready" and U.swap or (row.state == "active" and U.rowActive or U.specialOff)
				local fg = row.state == "ready" and U.swapText or (row.state == "active" and U.text or U.offText)
				local b = make("TextButton", { Name = "SwapRow" .. row.index, Font = FONT, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, AutoButtonColor = row.clickable, Active = row.clickable, BackgroundColor3 = rgb(bg), TextColor3 = rgb(fg), ZIndex = 15,
					Text = " " .. (def and (def.emoji .. " " .. def.name) or "?") .. " · " .. row.level .. " · " .. row.tag .. "\n " .. row.hpText .. " PV · " .. row.chargeText .. " " .. row.pipsText }, frame)
				make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
				local rr = rel(Rs.rows[i])
				place(b, rr)
				local barBg = make("Frame", { Name = "SwapHpBack", BackgroundColor3 = rgb(U.hpBack), BorderSizePixel = 0, Position = UDim2.fromOffset(8, rr.h - 9), Size = UDim2.fromOffset(rr.w - 16, 5), ZIndex = 16 }, b)
				make("Frame", { Name = "SwapHpFill", BackgroundColor3 = rgb(L.hpColor(row.frac)), BorderSizePixel = 0, Size = UDim2.fromScale(row.frac, 1), ZIndex = 17 }, barBg)
				u.rows[i] = b
				local index, clickable = row.index, row.clickable
				conn(b.Activated, function()
					if clickable and S.swapUi == u then -- jamais un pet K.O. ni le pet déjà au combat
						S.closeSwap()
						if type(o.sound) == "function" then
							pcall(o.sound, "click")
						end
						o.fire("battleAct", "swap" .. index)
						if type(o.onChosen) == "function" then
							o.onChosen()
						end
					elseif S.swapUi == u and type(o.sound) == "function" then
						pcall(o.sound, "refuse")
					end
				end)
			end
			local back = make("TextButton", { Name = "SwapBack", Font = FONT, TextSize = 15, Text = "↩ Retour", AutoButtonColor = true, BackgroundColor3 = rgb(U.flee), TextColor3 = rgb(U.fleeText), ZIndex = 15 }, frame)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, back)
			place(back, rel(Rs.back))
			conn(back.Activated, function()
				S.closeSwap()
			end)
			return u
		end)
		if okOpen and ui then
			ui.count = S.used - before
			S.swapUi = ui
		else
			pcall(function()
				S.swapTmp:Destroy()
			end)
			release(S.used - before)
		end
		S.swapTmp = nil
	end

	-- Applique la vue du serveur (PV, niveaux, points d'état, charge, créatures). `info.delay` : retard (s) du remplacement d'une créature (laisse jouer les coups).
	function scene.update(view, info)
		if not S.alive or type(view) ~= "table" or type(view.sides) ~= "table" then
			return
		end
		local delay = type(info) == "table" and type(info.delay) == "number" and info.delay or 0
		S.lastView = view
		local me, foe = view.sides[1], view.sides[2]
		if not (me and foe and me.units and foe.units) then
			return
		end
		pcall(function()
			local hit = S.hitAt or {}
			S.hitAt = {}
			updateCard(S.foeCard, foe, true, hit[2])
			updateCard(S.meCard, me, true, hit[1])
			scene.setQueue(L.turnQueue(info and info.events, view, 3), me.units[me.active], foe.units[foe.active])
			local mu = me.units[me.active]
			setPips(S.meCard, mu)
			local ss = o.specialState and mu and o.specialState(mu) or { text = "Spécial", ready = true }
			local sb = L.specialButton(ss)
			setSpecialButton(sb)
			-- flash : seulement quand la charge du MÊME pet devient pleine (jamais au changement de pet ni à la 1re vue)
			local curKey = mu and (tostring(mu.p) .. ":" .. tostring(me.active)) or nil
			local cur = { key = curKey, full = type(mu) == "table" and L.chargePips(mu.charge, mu.chargeMax).ready == true }
			local trans = L.specialTransition(S.specialPrev, cur)
			S.specialPrev = cur
			if trans == "flash" and not view.over then
				if delay > 0 then -- le flash attend la fin des coups du tour
					task.delay(delay, function()
						if S.alive and not S.dimmed then
							S.flashSpecial()
						end
					end)
				else
					S.flashSpecial()
				end
			end
			updateSwapButton(me)
			S.setTray(false)
			setPills(1, mu)
			setPills(2, foe.units[foe.active])
			for side = 1, 2 do
				local sd = view.sides[side]
				local u = sd.units[sd.active]
				local pd = S.pedestals[side]
				if u and pd then
					local tcol = L.typeColor(u.type)
					pd.glow.Color = rgb(tcol)
					if pd.column then
						pd.column.Color = rgb(tcol)
					end
				end
				local key = u and (tostring(u.p) .. ":" .. tostring(sd.active)) or nil
				if u and key ~= S.cur[side] then
					S.cur[side] = key
					S.swapToken[side] = S.swapToken[side] + 1
					local token = S.swapToken[side]
					local old = S.puppets[side]
					local function swapIn()
						if S.alive and S.swapToken[side] == token then
							S.setPuppet(side, u, true)
						end
					end
					if old and old.model and delay > 0 then
						task.delay(delay, function()
							if S.alive and S.swapToken[side] == token then
								old.busy = old.busy + 1
								animate(0.22, function(a)
									if old.model and old.model.Parent then
										old.model:PivotTo(old.base * CFrame.new(0, -3 * a, 0))
									end
									if a >= 1 then
										swapIn()
									end
								end)
							end
						end)
					else
						swapIn()
					end
				end
			end
			if view.over then
				for _, b in pairs(S.btn) do
					b.AutoButtonColor = false
				end
			end
		end)
	end

	-- Position de l'écran (coordonnées de l'interface) au-dessus d'une créature : projection par la caméra de la scène, sinon estimation pure de BattleLayout.
	function scene.anchor(side)
		local sc = S.sc
		local ok, x, y = pcall(function()
			local pos = side == 1 and sc.me or sc.foe
			local v = S.cam:WorldToViewportPoint(Vector3.new(pos.x, 3.2, pos.z))
			return v.X - 5, v.Y - 5
		end)
		if ok and type(x) == "number" and type(y) == "number" and x == x and y == y then
			return x, y
		end
		local vw, vh = viewportSize()
		local a = L.anchor(side, vw, vh, o.safe)
		return a.x, a.y
	end

	-- Étiquette flottante au-dessus d'une créature (nombre de dégâts ou message de type) ; au plus MAX_POPUPS à la fois, détruite après 0,8 s au plus
	local function popup(side, text, color, size, rise, lift)
		if S.popups >= L.MAX_POPUPS or not S.alive then
			return
		end
		S.popups = S.popups + 1
		local x, y = scene.anchor(side)
		local ok, lbl = pcall(function()
			return make("TextLabel", { Name = "Popup", BackgroundTransparency = 1, Font = FONT, TextSize = size or 24, Text = text, TextColor3 = rgb(color), TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.fromRGB(10, 14, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y - (lift or 14)), Size = UDim2.fromOffset(200, 32), ZIndex = 9 }, S.root)
		end)
		if not ok then
			S.popups = S.popups - 1
			return
		end
		local dur = L.animSeconds(0.8, S.speed)
		tween(lbl, dur, { Position = UDim2.fromOffset(x, y - (lift or 14) - (rise or 40)), TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(dur + 0.05, function()
			pcall(function()
				lbl:Destroy()
			end)
			release(1)
			S.popups = math.max(0, S.popups - 1)
		end)
	end

	local function lunge(side)
		local pz = S.puppets[side]
		if not (pz and pz.model) then
			return
		end
		pz.busy = pz.busy + 1
		animate(0.32, function(a)
			if pz.model and pz.model.Parent then
				pz.model:PivotTo(pz.base * CFrame.new(0, 0.6 * math.sin(math.pi * a), -3.2 * math.sin(math.pi * a)))
			end
			if a >= 1 then
				pz.busy = math.max(0, pz.busy - 1)
			end
		end)
	end
	local function recoil(side)
		local pz = S.puppets[side]
		if not (pz and pz.model) then
			return
		end
		pz.busy = pz.busy + 1
		pcall(function()
			pz.body.Color = Color3.fromRGB(255, 255, 255)
		end)
		animate(0.3, function(a)
			if pz.model and pz.model.Parent then
				pz.model:PivotTo(pz.base * CFrame.new(math.sin(a * 28) * 0.4 * (1 - a), 0, 0))
			end
			if a >= 0.35 then
				pcall(function()
					pz.body.Color = pz.color
				end)
			end
			if a >= 1 then
				pz.busy = math.max(0, pz.busy - 1)
			end
		end)
	end
	local function hop(side)
		local pz = S.puppets[side]
		if not (pz and pz.model) then
			return
		end
		pz.busy = pz.busy + 1
		animate(0.35, function(a)
			if pz.model and pz.model.Parent then
				pz.model:PivotTo(pz.base * CFrame.new(0, 1.2 * math.sin(math.pi * a), 0))
			end
			if a >= 1 then
				pz.busy = math.max(0, pz.busy - 1)
			end
		end)
	end

	-- Animations des événements d'un tour, dans l'ordre : élan de l'attaquant, MESSAGE DE TYPE tout de suite (avant le résultat), puis à l'impact (0,16 s) recul de la
	-- cible, nombre de dégâts coloré par efficacité avec icône et début du défilement des PV. Coups décalés (cadence de BattleLayout, divisée par la vitesse). « Passer »
	-- annule ce qui n'a pas démarré. Retourne la durée totale (s) pour différer le remplacement d'une créature. Ne touche JAMAIS au serveur ni au minuteur du tour.
	function scene.cues(events)
		local k = 0
		local gen = S.skipGen
		S.hitAt = {}
		local step = L.animSeconds(0.6, S.speed)
		-- sons du tour (Config.SOUNDS seulement) : attaque = son du type, spécial = special_hit, changement voulu = click ; BattleUi laisse les effets de type jouer les attaques (attackSounds = false)
		for _, sn in ipairs(L.soundPlan(Config, events, { typeOf = function(p) return Battle.SPECIES_TYPE and Battle.SPECIES_TYPE[p] or nil end, speed = S.speed, attackSounds = o.attackSounds ~= false })) do
			task.delay(sn.at, function()
				if S.alive and S.skipGen == gen and type(o.sound) == "function" then
					pcall(o.sound, sn.key)
				end
			end)
		end
		for _, ev in ipairs(events or {}) do
			local cue = L.cue(ev)
			if cue then
				local at = step * k
				local impact = at + L.animSeconds(0.16, S.speed)
				if cue.anim == "attack" and S.hitAt[cue.target] == nil then
					S.hitAt[cue.target] = impact
				end
				task.delay(at, function()
					if not S.alive or S.skipGen ~= gen then
						return
					end
					pcall(function()
						if cue.anim == "attack" then
							lunge(cue.actor)
							if cue.message then
								popup(cue.target, cue.message.icon .. " " .. cue.message.text, cue.message.rgb, 18, 26, 54)
							end
							task.delay(L.animSeconds(0.16, S.speed), function()
								if S.alive and S.skipGen == gen then
									pcall(recoil, cue.target)
									if cue.popup then
										pcall(popup, cue.popup.side, cue.popup.text, cue.popup.rgb, cue.special and 28 or 24, 40, 14)
									end
								end
							end)
						elseif cue.anim == "heal" or cue.anim == "guard" then
							hop(cue.actor)
							if cue.popup then
								popup(cue.popup.side, cue.popup.text, cue.popup.rgb, 22, 36, 14)
							end
						end
					end)
				end)
				if cue.anim == "attack" or cue.anim == "heal" then
					k = k + 1
				end
			end
		end
		return step * k + L.animSeconds(0.2, S.speed)
	end

	-- Ordre du tour : 3 pastilles (emoji du pet qui agit) sous la carte adverse ; la première est mise en avant.
	function scene.setQueue(sides, mu, fu)
		local function emoji(u)
			local def = u and Config.PETS[u.p]
			return def and def.emoji or "?"
		end
		for i, q in ipairs(S.queue) do
			local side = sides[i]
			q.frame.Visible = side ~= nil
			if side then
				q.frame.BackgroundColor3 = rgb(side == 1 and U.meChip or U.foeChip)
				q.emoji.Text = emoji(side == 1 and mu or fu)
				q.frame.BackgroundTransparency = i == 1 and 0 or 0.35
			end
		end
	end

	function scene.setSpeed(v)
		S.speed = math.max(1, math.min(3, math.floor(v or 1)))
		S.btn.speed.Text = L.speedLabel(S.speed)
	end
	function scene.skip() -- termine immédiatement les animations en cours (le jeu et le serveur ne sont pas concernés)
		S.skipGen = S.skipGen + 1
	end
	function scene.setCanSkip(v)
		S.canSkip = v == true
		S.btn.skip.Visible = S.canSkip and not S.dimmed
	end
	S.canSkip = o.canSkip == true

	function scene.setDim(on)
		S.dimmed = on == true
		S.dim.Visible = true
		if on then
			S.dim.BackgroundTransparency = 1
			tween(S.dim, 0.8, { BackgroundTransparency = 0.45 })
		else
			S.dim.BackgroundTransparency = 1
			S.dim.Visible = false
		end
		for _, b in pairs(S.btn) do
			b.Visible = not on
		end
		S.btn.skip.Visible = not on and S.canSkip
		S.logFrame.Visible = not on
		S.closeSwap()
		S.hideTip()
		S.chargeBar.Visible = not on and S.specialReady ~= true
		for side = 1, 2 do
			for _, p in ipairs(S.pills[side]) do
				p.btn.Visible = not on and p.data ~= nil
			end
		end
	end

	function S.setTray(v) -- ouvre (true) ou ferme (false) l'écran « Changer »
		if v == true then
			S.openSwap()
		else
			S.closeSwap()
		end
	end
	local function act(action)
		if not S.alive or S.dimmed then
			return
		end
		if type(o.sound) == "function" then -- un son par action (Config.SOUNDS, coupé si SOUNDS_ENABLED = false : géré par l'appelant)
			pcall(o.sound, "click")
		end
		o.fire("battleAct", action)
		if type(o.onChosen) == "function" then
			o.onChosen()
		end
	end
	local function conn(sig, fn)
		local c = sig:Connect(fn)
		S.conns[#S.conns + 1] = c
	end
	conn(S.btn.attack.Activated, function()
		S.setTray(false)
		act("attack")
	end)
	conn(S.btn.special.Activated, function()
		S.setTray(false)
		local mu = S.lastView and S.lastView.sides[1].units[S.lastView.sides[1].active]
		local ss = mu and o.specialState and o.specialState(mu)
		if ss and ss.ready then -- le serveur revalide (« spécial pas prêt (x/5) ») : ce test n'est que du confort
			act("skill")
		elseif ss then
			if type(o.sound) == "function" then
				pcall(o.sound, "refuse")
			end
			scene.setStatus("Spécial pas prêt (" .. tostring(ss.charge or 0) .. "/" .. tostring(ss.max or L.CHARGE_MAX) .. ") : attaque pour charger !")
		end
	end)
	conn(S.btn.swap.Activated, function()
		if S.dimmed then
			return
		end
		if S.swapUi then
			S.closeSwap()
		elseif S.swapAny then
			if type(o.sound) == "function" then
				pcall(o.sound, "click")
			end
			S.openSwap()
		elseif type(o.sound) == "function" then -- plus aucun pet vivant en réserve : rien à ouvrir
			pcall(o.sound, "refuse")
		end
	end)
	for side = 1, 2 do -- toucher une pastille d'état : info-bulle (icône, nom, durée) ; la même pastille la referme
		for i, p in ipairs(S.pills[side]) do
			conn(p.btn.Activated, function()
				if S.tip.Visible and S.tipSide == side and S.tipIndex == i then
					S.hideTip()
				else
					S.showTip(side, i)
					S.tipIndex = i
				end
			end)
		end
	end
	conn(S.btn.speed.Activated, function() -- 1x -> 2x -> 3x -> 1x ; mémorisé par l'appelant (réglage local)
		local v = L.speedNext(S.speed)
		scene.setSpeed(v)
		if type(o.sound) == "function" then
			pcall(o.sound, "click")
		end
		if type(o.onSpeed) == "function" then
			pcall(o.onSpeed, v)
		end
	end)
	conn(S.btn.skip.Activated, function() -- « Passer l'animation » : les animations en cours se terminent aussitôt
		scene.skip()
		if type(o.onSkip) == "function" then
			pcall(o.onSkip)
		end
	end)
	conn(S.btn.flee.Activated, function() -- deux appuis : un abandon par erreur coûte un forfait (duel, classé)
		if S.dimmed then
			return
		end
		S.setTray(false)
		if S.fleeToken > 0 then
			S.fleeToken = 0
			S.btn.flee.Text = "🏃 Fuir"
			if type(o.onFlee) == "function" then
				o.onFlee()
			else
				o.fire("battleQuit")
			end
			return
		end
		S.fleeToken = S.fleeToken + 1
		local token = S.fleeToken
		S.btn.flee.Text = "Sûr ?"
		task.delay(3, function()
			if S.alive and S.fleeToken == token then
				S.fleeToken = 0
				S.btn.flee.Text = "🏃 Fuir"
			end
		end)
	end)
	pcall(function()
		conn(o.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
			if S.alive then
				pcall(S.relayout)
			end
		end)
	end)

	if plan.bob then -- balancement au repos (une seule boucle, 15 Hz) ; arrêtée à la destruction
		task.spawn(function()
			while S.alive do
				task.wait(0.07)
				local t = os.clock()
				for side = 1, 2 do
					local pz = S.puppets[side]
					if pz and pz.busy == 0 and pz.model and pz.base then
						pcall(function()
							pz.model:PivotTo(pz.base * CFrame.new(0, math.sin(t * 2.2 + side) * 0.12, 0))
						end)
					end
				end
			end
		end)
	end

	-- Destruction complète : boucles arrêtées, connexions coupées, racine (donc tout le monde 3D et l'interface) détruite.
	function scene.destroy()
		if not S.alive then
			return
		end
		pcall(S.closeSwap) -- coupe les connexions de l'écran « Changer » s'il est ouvert
		S.alive = false
		for _, c in ipairs(S.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		S.conns = {}
		pcall(function()
			S.root:Destroy()
		end)
		S.used = 0
		S.puppets = {}
	end

	scene.update(view0, nil)
	return scene
end

return BattleScene
