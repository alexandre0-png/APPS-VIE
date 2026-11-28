-- ModuleScript : StarterPlayerScripts/EvolveUi   (écran « ✨ Évoluer » des pets)
-- Construit l'écran d'évolution : bouton ✨ à droite, panneau avec la liste des pets de la base (prêt / doublons manquants / interdit / forme 2), détail du pet choisi
-- (gains de revenu et de force, les 3 doublons que le SERVEUR sacrifiera), confirmation en DEUX appuis (« Évoluer » puis « Confirmer », la 2e étape expire en 4 s),
-- retour visuel de 1 s au plus. TOUTE la logique (états, textes, disposition) vient du module pur EvolveLayout (testé) ; ici : uniquement des instances.
-- Le client n'envoie que « evoPreview » (indice) et « evolve » ({ i, maxCost = prix vu }) : le serveur décide doublons, coût et interdits (Evolution.plan) et répond sur
-- « Evo » ({ k = "preview", view } ou { k = "done" }). Config.EVOLUTION.enabled = false : l'écran affiche « bientôt », aucun bouton actif, AUCUN message envoyé.
-- Aucune erreur ne sort d'ici (start retourne nil si la construction échoue). Pas de += ni de continue (lanceur lupa).
local EvolveUi = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- ctx = { Config, Evolution, Layout (EvolveLayout), player, gui, FONT, RAction, REvo, playSound, getState = fn() -> état du client, reduced }
function EvolveUi.start(ctx)
	if type(ctx) ~= "table" or type(ctx.Layout) ~= "table" or type(ctx.Evolution) ~= "table" or ctx.gui == nil or ctx.REvo == nil or ctx.RAction == nil then
		return nil
	end
	local Config, E, EL, FONT = ctx.Config, ctx.Evolution, ctx.Layout, ctx.FONT or Enum.Font.GothamBold
	local U = EL.UI
	local S = { alive = true, flow = EL.newFlow(), sig = nil, rowBtns = {}, conns = {}, fxToken = 0, lastPhase = "idle" }

	local function make(class, props, parent)
		local o = Instance.new(class)
		for k, v in pairs(props) do
			o[k] = v
		end
		o.Parent = parent
		return o
	end
	local function snd(key)
		if type(ctx.playSound) == "function" then
			pcall(ctx.playSound, key)
		end
	end
	local function getState()
		local ok, st = pcall(ctx.getState)
		return ok and type(st) == "table" and st or nil
	end
	local function enabled()
		return EL.enabled(Config)
	end
	local function conn(sig, fn)
		S.conns[#S.conns + 1] = sig:Connect(fn)
	end

	local ok, err = pcall(function()
		S.open = make("TextButton", { Name = "EvolveButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0.3, -82), Size = UDim2.fromOffset(34, 34), Text = "✨", Font = FONT, TextSize = 18, BackgroundColor3 = rgb(U.btnOn), TextColor3 = rgb(U.darkText), AutoButtonColor = true }, ctx.gui)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, S.open)
		make("UIStroke", { Color = Color3.fromRGB(20, 80, 40), Thickness = 2 }, S.open)
		S.dot = make("Frame", { Name = "ReadyDot", Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -9, 0, -1), BackgroundColor3 = rgb(U.ok), BorderSizePixel = 0, Visible = false }, S.open) -- pastille « un pet est prêt »
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, S.dot)

		S.root = make("Frame", { Name = "EvolvePanel", BackgroundColor3 = rgb(U.panel), Visible = false, ZIndex = 30, Active = true }, ctx.gui)
		make("UICorner", { CornerRadius = UDim.new(0, 16) }, S.root)
		make("UIStroke", { Color = rgb(U.panelStroke), Thickness = 3 }, S.root)
		S.title = make("TextLabel", { Name = "Title", BackgroundTransparency = 1, Font = FONT, TextSize = 20, Text = "✨ Évolution", TextColor3 = rgb(U.text), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31 }, S.root)
		S.sub = make("TextLabel", { Name = "Subtitle", BackgroundTransparency = 1, Font = FONT, TextSize = 13, Text = "", TextWrapped = true, TextColor3 = rgb(U.muted), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31 }, S.root)
		S.close = make("TextButton", { Name = "Close", Font = FONT, TextSize = 18, Text = "✕", BackgroundColor3 = rgb(U.btnCancel), TextColor3 = rgb(U.cancelText), AutoButtonColor = true, ZIndex = 32 }, S.root)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, S.close)
		S.list = make("ScrollingFrame", { Name = "PetList", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 31 }, S.root)
		make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, S.list)
		S.detail = make("Frame", { Name = "Detail", BackgroundTransparency = 1, ZIndex = 31 }, S.root)
		S.detailText = make("TextLabel", { Name = "DetailText", BackgroundTransparency = 1, Font = FONT, TextSize = 13, Text = "", TextWrapped = true, TextColor3 = rgb(U.text), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.fromScale(1, 1), ZIndex = 32 }, S.detail)
		S.primary = make("TextButton", { Name = "Primary", Font = FONT, TextSize = 15, TextWrapped = true, Text = "", BackgroundColor3 = rgb(U.btnOff), TextColor3 = rgb(U.offText), AutoButtonColor = false, ZIndex = 32 }, S.root)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, S.primary)
		S.cancel = make("TextButton", { Name = "Cancel", Font = FONT, TextSize = 15, Text = "Annuler", BackgroundColor3 = rgb(U.btnCancel), TextColor3 = rgb(U.cancelText), AutoButtonColor = true, Visible = false, ZIndex = 32 }, S.root)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, S.cancel)
		-- retour visuel : halo + pet + « ★2 » (créé à la demande, détruit après 1 s)
		S.fx = make("Frame", { Name = "EvolveFx", BackgroundTransparency = 1, Visible = false, ZIndex = 40, Size = UDim2.fromScale(1, 1) }, S.root)
	end)
	if not ok then
		if S.root then
			pcall(function()
				S.root:Destroy()
			end)
		end
		if S.open then
			pcall(function()
				S.open:Destroy()
			end)
		end
		return nil, err
	end

	local function place(inst, r)
		inst.Position = UDim2.fromOffset(r.x, r.y)
		inst.Size = UDim2.fromOffset(r.w, r.h)
	end
	local function guiSize()
		local okS, w, h = pcall(function()
			local a = ctx.gui.AbsoluteSize
			return a.X, a.Y
		end)
		if okS and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
			return w, h
		end
		return nil, nil
	end
	local function relayout()
		local vw, vh = guiSize()
		local R = EL.rects(vw, vh, nil)
		S.rects = R
		-- le panneau est positionné en absolu dans l'écran : les rectangles des enfants sont relatifs au panneau
		local px, py = R.panel.x, R.panel.y
		local function rel(r)
			return { x = r.x - px, y = r.y - py, w = r.w, h = r.h }
		end
		place(S.root, R.panel)
		place(S.title, rel(R.header))
		place(S.sub, rel(R.subtitle))
		place(S.close, rel(R.close))
		place(S.list, rel(R.list))
		place(S.detail, rel(R.detail))
		place(S.primary, rel(R.primary))
		place(S.cancel, rel(R.cancel))
	end

	local function rowText(r)
		local form = r.form == 2 and " ★2" or ""
		return r.emoji .. " " .. r.name .. form .. "\n" .. r.tierName .. " · " .. r.tag
	end
	local function rowColor(status)
		if status == "ready" then
			return U.ok
		elseif status == "dupes" then
			return U.warn
		elseif status == "locked" then
			return U.bad
		end
		return U.muted
	end

	local function rebuildRows(rows)
		for _, b in ipairs(S.rowBtns) do
			pcall(function()
				b:Destroy()
			end)
		end
		S.rowBtns = {}
		for n, r in ipairs(rows) do
			local selected = S.flow.i == r.i
			local b = make("TextButton", { Name = "Row" .. r.i, LayoutOrder = n, Size = UDim2.new(1, -8, 0, EL.ROW_H), Font = FONT, TextSize = 14, TextWrapped = true, Text = rowText(r), TextColor3 = rgb(rowColor(r.status)), BackgroundColor3 = rgb(selected and U.rowSel or U.row), AutoButtonColor = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }, S.list)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, b)
			make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, b)
			if selected then
				make("UIStroke", { Color = rgb(U.panelStroke), Thickness = 2 }, b)
			end
			local idx = r.i
			conn(b.Activated, function()
				if not S.alive then
					return
				end
				snd("click")
				local _, act = EL.select(S.flow, idx, os.clock(), enabled())
				if act and act.kind == "preview" then
					pcall(function()
						ctx.RAction:FireServer("evoPreview", act.i)
					end)
				end
				S.refresh(true)
			end)
			S.rowBtns[#S.rowBtns + 1] = b
		end
	end

	-- Mise à jour complète de l'écran d'après l'état du joueur et la machine d'états.
	function S.refresh(forceRows)
		if not S.alive then
			return
		end
		pcall(function()
			local st = getState()
			local rows = st and EL.list(Config, E, st) or {}
			local on = enabled()
			S.dot.Visible = on and EL.countReady(rows) > 0
			if not S.root.Visible then
				return
			end
			local head = EL.header(Config, rows)
			S.title.Text = head.title
			S.sub.Text = head.subtitle .. (head.rule ~= "" and ("\nCoût : " .. head.rule .. ".") or "")
			S.sub.TextColor3 = rgb(head.soon and U.soon or U.muted)
			-- le pet choisi doit toujours exister et ne pas être en forme 2 : sinon retour au repos
			if S.flow.i ~= nil then
				local found = false
				for _, r in ipairs(rows) do
					if r.i == S.flow.i and (r.form ~= 2 or S.flow.phase == "done") then
						found = true
					end
				end
				if not found then
					EL.reset(S.flow)
				end
			end
			local parts = { on and "1" or "0", tostring(S.flow.i) }
			for _, r in ipairs(rows) do
				parts[#parts + 1] = r.i .. r.status .. r.form
			end
			local sig = table.concat(parts, ",")
			if forceRows or sig ~= S.sig then
				S.sig = sig
				if head.soon then
					rebuildRows({})
				else
					rebuildRows(rows)
				end
			end
			local btn = EL.button(S.flow, on, E)
			S.primary.Text = btn.text
			S.primary.Active = btn.active
			S.primary.AutoButtonColor = btn.active
			local confirm = btn.kind == "confirm"
			S.primary.BackgroundColor3 = rgb(btn.active and (confirm and U.btnConfirm or U.btnOn) or U.btnOff)
			S.primary.TextColor3 = rgb(btn.active and U.darkText or U.offText)
			S.cancel.Visible = btn.cancel
			local d = st and EL.detail(Config, st, S.flow) or nil
			if on and d then
				local chips = {}
				for _, c in ipairs(d.chips) do
					chips[#chips + 1] = c.emoji .. " #" .. c.i
				end
				local sac = #chips > 0 and ("Sacrifiés : " .. table.concat(chips, "  ")) or ""
				S.detailText.Text = d.emoji .. " " .. d.name .. " → forme 2\n" .. table.concat(d.lines, "\n") .. (sac ~= "" and ("\n" .. sac) or "")
			elseif head.soon then
				S.detailText.Text = "Revenu +" .. EL.pct(Config.EVOLUTION and Config.EVOLUTION.incomeMul) .. " %, force +" .. EL.pct(Config.EVOLUTION and Config.EVOLUTION.powerMul) .. " % : bientôt disponible.\nAucune forme payante : seulement des doublons et des pièces gagnées en jouant."
			else
				S.detailText.Text = "Touche un pet pour voir ce qu'il gagnerait."
			end
			if S.lastPhase ~= S.flow.phase then
				if S.flow.phase == "refused" then
					snd("refuse")
				end
				S.lastPhase = S.flow.phase
			end
		end)
	end

	-- Retour visuel (au plus EL.MAX_FX secondes) : halo qui s'éteint, pet qui rebondit, « ★2 » ; une seule animation à la fois, arrêtée à la destruction.
	function S.playFx(msg)
		S.fxToken = S.fxToken + 1
		local token = S.fxToken
		local def = type(msg) == "table" and Config.PETS and Config.PETS[msg.p] or nil
		pcall(function()
			for _, c in ipairs(S.fx:GetChildren()) do
				c:Destroy()
			end
			local halo = make("Frame", { Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = Color3.fromRGB(255, 236, 140), BorderSizePixel = 0, ZIndex = 41 }, S.fx)
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, halo)
			local pet = make("TextLabel", { Name = "Pet", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(120, 100), BackgroundTransparency = 1, Font = FONT, TextSize = 72, Text = def and tostring(def.emoji) or "✨", ZIndex = 42 }, S.fx)
			local star = make("TextLabel", { Name = "Star", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 40), Size = UDim2.fromOffset(160, 36), BackgroundTransparency = 1, Font = FONT, TextSize = 28, Text = "★2", TextColor3 = Color3.fromRGB(255, 236, 140), TextStrokeTransparency = 0.3, ZIndex = 42 }, S.fx)
			local sc = make("UIScale", { Scale = 1 }, pet)
			S.fx.Visible = true
			local dur = math.min(EL.MAX_FX, EL.fxSeconds(ctx.reduced == true))
			task.spawn(function()
				local t0 = os.clock()
				while S.alive and S.fxToken == token do
					local a = (os.clock() - t0) / dur
					local f = EL.fx(a)
					pcall(function()
						sc.Scale = f.scale
						halo.BackgroundTransparency = f.haloTransparency
						star.TextTransparency = 1 - f.starAlpha
					end)
					if a >= 1 then
						break
					end
					task.wait(0.03)
				end
				if S.fxToken == token then
					pcall(function()
						S.fx.Visible = false
						for _, c in ipairs(S.fx:GetChildren()) do
							c:Destroy()
						end
					end)
				end
			end)
		end)
	end

	conn(S.open.Activated, function()
		snd("click")
		S.root.Visible = not S.root.Visible
		if S.root.Visible then
			pcall(relayout)
			S.sig = nil
			S.refresh(true)
		else
			EL.reset(S.flow)
		end
	end)
	conn(S.close.Activated, function()
		snd("click")
		S.root.Visible = false
		EL.reset(S.flow)
	end)
	conn(S.primary.Activated, function()
		if not S.alive then
			return
		end
		local _, act = EL.press(S.flow, os.clock(), enabled())
		if act and act.kind == "evolve" then
			snd("click")
			pcall(function()
				ctx.RAction:FireServer("evolve", { i = act.i, maxCost = act.maxCost })
			end)
		elseif S.flow.phase == "confirm" then
			snd("click")
		end
		S.refresh(false)
	end)
	conn(S.cancel.Activated, function()
		snd("click")
		EL.cancel(S.flow)
		S.refresh(false)
	end)
	conn(ctx.REvo.OnClientEvent, function(m)
		if not S.alive or type(m) ~= "table" then
			return
		end
		pcall(function()
			if m.k == "preview" and type(m.view) == "table" then
				EL.onPreview(S.flow, m.view, os.clock())
			elseif m.k == "done" then
				EL.onDone(S.flow, m, os.clock())
				if S.flow.phase == "done" then
					snd("levelup")
					S.playFx(m)
				end
			end
			S.refresh(false)
		end)
	end)
	pcall(function()
		conn(ctx.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
			if S.alive then
				pcall(relayout)
			end
		end)
	end)
	pcall(relayout)

	-- Horloge de l'écran : expiration de la 2e étape, délai de l'envoi, fin du retour visuel, aperçu différé ; ne fait rien tant que l'écran est fermé.
	task.spawn(function()
		local n = 0
		while S.alive do
			task.wait(0.25)
			n = n + 1
			pcall(function()
				if not S.root.Visible then
					if n % 8 == 0 then -- écran fermé : seule la pastille « un pet est prêt » est remise à jour (toutes les 2 s)
						S.refresh(false)
					end
					return
				end
				local now = os.clock()
				local _, act = EL.tick(S.flow, now)
				local due = EL.due(S.flow, now)
				local a = act or due
				if a and a.kind == "preview" and enabled() then
					pcall(function()
						ctx.RAction:FireServer("evoPreview", a.i)
					end)
				end
				S.refresh(false)
			end)
		end
	end)

	local self = { gui = S.root, button = S.open }
	function self.state()
		return S.flow.phase
	end
	function self.onState()
		S.refresh(false)
	end
	function self.destroy()
		if not S.alive then
			return
		end
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
		pcall(function()
			S.open:Destroy()
		end)
	end
	S.refresh(false)
	return self
end

return EvolveUi
