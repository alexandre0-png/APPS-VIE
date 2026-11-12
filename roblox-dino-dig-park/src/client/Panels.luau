-- Panels.luau : fenêtres du jeu (améliorations, collection, quêtes, cadeau quotidien, renaissance, boutique, choix d'œuf).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Economy = require(Shared.Economy)

local Ui = require(script.Parent.Ui)
local Store = require(script.Parent.StateStore)

local Panels = {}
local C = Ui.colors

local function row(parent, order, height)
	local r = Ui.new("Frame", { Size = UDim2.new(1, -8, 0, height or 80), BackgroundColor3 = C.row, LayoutOrder = order, Parent = parent })
	Ui.corner(r, 12)
	return r
end

local function listLayout(parent, pad)
	Ui.new("UIListLayout", { Padding = UDim.new(0, pad or 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent })
	Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = parent })
end

local function hex(color)
	return "#" .. color:ToHex()
end

----------------------------------------------------------------------
-- Améliorations
----------------------------------------------------------------------
local function buildUpgrades()
	local p = Ui.createPanel("upgrades", "⛏ Améliorations", UDim2.fromOffset(560, 480), { color = C.orange })
	listLayout(p.body)
	local rows = {}
	for i, id in ipairs(Config.UpgradeOrder) do
		local def = Config.Upgrades[id]
		local r = row(p.body, i, 84)
		Ui.label(r, { text = def.icon, size = 34, sizeUdim = UDim2.fromOffset(56, 84) })
		Ui.label(r, {
			text = def.name,
			size = 22,
			align = Enum.TextXAlignment.Left,
			sizeUdim = UDim2.new(1, -240, 0, 30),
			pos = UDim2.fromOffset(60, 8),
			stroke = true,
			name = "Name",
		})
		Ui.label(r, {
			text = def.desc,
			size = 14,
			color = C.muted,
			align = Enum.TextXAlignment.Left,
			valign = Enum.TextYAlignment.Top,
			wrap = true,
			sizeUdim = UDim2.new(1, -240, 0, 40),
			pos = UDim2.fromOffset(60, 38),
			name = "Desc",
		})
		local btn = Ui.button(r, {
			text = "",
			size = UDim2.fromOffset(150, 60),
			pos = UDim2.new(1, -8, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = C.green,
			onClick = function()
				Store.act("Upgrade", { id = id })
			end,
		})
		local lvl = Ui.label(btn, { text = "", size = 14, sizeUdim = UDim2.fromScale(1, 0.4), name = "Level" })
		local cost = Ui.label(
			btn,
			{ text = "", size = 20, sizeUdim = UDim2.fromScale(1, 0.6), pos = UDim2.fromScale(0, 0.4), stroke = true, name = "Cost" }
		)
		rows[id] = { button = btn, level = lvl, cost = cost }
	end
	local info = Ui.label(p.body, {
		text = "",
		size = 16,
		color = C.muted,
		align = Enum.TextXAlignment.Left,
		valign = Enum.TextYAlignment.Top,
		wrap = true,
		rich = true,
		sizeUdim = UDim2.new(1, -8, 0, 120),
		name = "Info",
	})
	info.LayoutOrder = 10
	Store.connect(function(st)
		for id, rr in pairs(rows) do
			local def = Config.Upgrades[id]
			local lv = st.upgrades[id]
			if lv >= def.max then
				rr.level.Text = "NIV. MAX"
				rr.cost.Text = "✓"
				Ui.setEnabled(rr.button, false)
			else
				local c = Economy.upgradeCost(id, lv)
				local have = st[def.currency]
				rr.level.Text = "Niv. " .. lv .. "/" .. def.max
				rr.cost.Text = (def.currency == "cash" and "💰 " or "🦴 ") .. Util.formatNumber(c)
				Ui.setEnabled(rr.button, have >= c)
			end
		end
		local m = st.mult
		info.Text = string.format(
			"<b>Revenus du parc</b> : %s/s\nBase dinos : %s  ×  collection %.2f  ×  renaissance %.2f  ×  billet %.2f  ×  bâtiments %.2f  ×  pass %.0f  ×  boost %.0f\nPelle : %d 🦴/coup (critique %.0f%% ×%d)  •  ouvriers : %.1f 🦴/s",
			Util.formatNumber(st.income),
			Util.formatNumber(st.baseIncome),
			m.collection,
			m.rebirth,
			m.ticket,
			m.buildings,
			m.pass,
			m.boost,
			st.digAmount,
			st.critChance * 100,
			Config.CritMultiplier,
			st.autoDigRate
		)
	end)
end

----------------------------------------------------------------------
-- Collection
----------------------------------------------------------------------
local function buildCollection()
	local p = Ui.createPanel("collection", "🦖 Collection de dinos", UDim2.fromOffset(700, 520), { color = C.green })
	local header =
		Ui.label(p.body, { text = "", size = 18, color = C.gold, rich = false, sizeUdim = UDim2.new(1, -8, 0, 28), name = "Header" })
	local grid = Ui.new("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = p.body,
	})
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 190),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	local sellBtn = Ui.button(p.frame, {
		text = "",
		size = UDim2.fromOffset(300, 44),
		pos = UDim2.new(0.5, 0, 1, -8),
		anchor = Vector2.new(0.5, 1),
		color = C.red,
		z = 30,
		onClick = function()
			Store.act("SellReserve")
		end,
	})
	p.body.Size = UDim2.new(1, -20, 1, -132)

	local cards = {}
	local ordered = {}
	for _, d in ipairs(Config.Dinos) do
		table.insert(ordered, d)
	end
	table.sort(ordered, function(a, b)
		local sa, sb = a.secret and 1 or 0, b.secret and 1 or 0
		if sa ~= sb then
			return sa < sb
		end
		local ra, rb = Config.RarityById[a.rarity].order, Config.RarityById[b.rarity].order
		if ra ~= rb then
			return ra < rb
		end
		return a.id < b.id
	end)
	for i, d in ipairs(ordered) do
		local rar = Config.RarityById[d.rarity]
		local f = Ui.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, Parent = grid })
		Ui.corner(f, 12)
		Ui.stroke(f, rar.color, 3)
		local vpHolder = Ui.new("Frame", { Name = "VP", Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, Parent = f })
		local name = Ui.label(
			f,
			{ text = "???", size = 18, sizeUdim = UDim2.new(1, -6, 0, 24), pos = UDim2.fromOffset(3, 114), stroke = true, name = "Name" }
		)
		Ui.label(f, {
			text = rar.name,
			size = 14,
			color = rar.color,
			sizeUdim = UDim2.new(1, 0, 0, 18),
			pos = UDim2.fromOffset(0, 136),
			stroke = true,
			name = "Rarity",
		})
		local inc = Ui.label(
			f,
			{ text = "", size = 14, color = C.gold, sizeUdim = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 154), name = "Income" }
		)
		local cnt =
			Ui.label(f, { text = "", size = 15, sizeUdim = UDim2.new(1, -6, 0, 18), pos = UDim2.fromOffset(0, 170), name = "Count" })
		cards[d.id] = { def = d, frame = f, holder = vpHolder, name = name, inc = inc, cnt = cnt, shown = nil }
	end

	local function render(st)
		local discovered = Economy.discoveredCount({ discovered = st.discovered })
		local total = #Config.Dinos
		header.Text = string.format(
			"Découverts : %d/%d   •   bonus de collection : +%d%% revenus",
			discovered,
			total,
			math.floor(discovered * Config.CollectionBonus * 100 + 0.5)
		)
		for id, card in pairs(cards) do
			local known = st.discovered[id] == true
			local normal = st.dinos[id] or 0
			local gold = st.dinos[id .. ":g"] or 0
			if card.shown ~= known then
				card.shown = known
				for _, c in ipairs(card.holder:GetChildren()) do
					c:Destroy()
				end
				if known or not card.def.secret then
					Ui.dinoViewport(card.holder, id, { silhouette = not known })
				else
					Ui.label(card.holder, { text = "🌌", size = 48 })
				end
			end
			if known then
				card.name.Text = card.def.name
				card.inc.Text = "💰 " .. Util.formatNumber(Economy.dinoIncome(id)) .. "/s"
				local t = "x" .. normal
				if gold > 0 then
					t = t .. "  ★" .. gold
				end
				card.cnt.Text = t
			else
				card.name.Text = "???"
				card.inc.Text = card.def.secret and ("Os dorés " .. st.bones .. "/" .. Config.GoldBoneCount) or ""
				card.cnt.Text = ""
			end
		end
		local n = 0
		for _, v in pairs(st.reserve) do
			n = n + v
		end
		sellBtn.Text = n > 0 and ("Vendre la réserve (" .. n .. ") : +" .. Util.formatNumber(st.reserveValue) .. " 💰")
			or "Réserve vide (" .. st.displayedCount .. "/" .. st.slots .. " exposés)"
		Ui.setEnabled(sellBtn, n > 0, C.red)
	end
	-- les viewports ne sont construits qu'à l'ouverture (économie de ressources)
	p.onOpen = function()
		if Store.state then
			render(Store.state)
		end
	end
	Store.connect(function(st)
		if Ui.openName == "collection" then
			render(st)
		end
	end)
end

----------------------------------------------------------------------
-- Quêtes
----------------------------------------------------------------------
local function questText(q)
	for _, t in ipairs(Config.QuestTypes) do
		if t.id == q.id then
			return string.format(t.text, q.target), t
		end
	end
	return q.id
end

local function buildQuests()
	local p = Ui.createPanel("quests", "📜 Quêtes du jour", UDim2.fromOffset(560, 400), { color = C.blue })
	listLayout(p.body)
	local rows = {}
	for i = 1, Config.QuestCount do
		local r = row(p.body, i, 92)
		local text = Ui.label(r, {
			text = "",
			size = 20,
			align = Enum.TextXAlignment.Left,
			sizeUdim = UDim2.new(1, -190, 0, 28),
			pos = UDim2.fromOffset(12, 8),
			stroke = true,
			name = "Text",
		})
		local reward = Ui.label(r, {
			text = "",
			size = 14,
			color = C.gold,
			align = Enum.TextXAlignment.Left,
			sizeUdim = UDim2.new(1, -190, 0, 18),
			pos = UDim2.fromOffset(12, 38),
			name = "Reward",
		})
		local barBg =
			Ui.new("Frame", { Size = UDim2.new(1, -190, 0, 16), Position = UDim2.fromOffset(12, 62), BackgroundColor3 = C.bg, Parent = r })
		Ui.corner(barBg, 8)
		local fill = Ui.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green, Parent = barBg })
		Ui.corner(fill, 8)
		local prog = Ui.label(barBg, { text = "", size = 12, stroke = true, z = 3 })
		local btn = Ui.button(r, {
			text = "Récupérer",
			size = UDim2.fromOffset(150, 52),
			pos = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = C.green,
			onClick = function()
				Store.act("ClaimQuest", { index = i })
			end,
		})
		rows[i] = { row = r, text = text, reward = reward, fill = fill, prog = prog, btn = btn }
	end
	local foot = Ui.label(
		p.body,
		{ text = "Les quêtes se renouvellent chaque jour (minuit UTC).", size = 14, color = C.muted, sizeUdim = UDim2.new(1, -8, 0, 24) }
	)
	foot.LayoutOrder = 10
	Store.connect(function(st)
		for i, rr in ipairs(rows) do
			local q = st.quests[i]
			rr.row.Visible = q ~= nil
			if q then
				local txt, qt = questText(q)
				rr.text.Text = txt
				if qt.reward.fossils then
					local f = math.floor(
						qt.reward.fossils * q.tier * (1 + st.upgrades.shovel * 0.5) * Economy.fossilMultiplier({ rebirths = st.rebirths })
					)
					rr.reward.Text = "Récompense : " .. Util.formatNumber(f) .. " 🦴"
				else
					local c = math.max(300 * q.tier, math.floor(st.income * 60 * qt.reward.minutes * q.tier / 2))
					rr.reward.Text = "Récompense : ≈ " .. Util.formatNumber(c) .. " 💰"
				end
				local ratio = math.clamp(q.progress / q.target, 0, 1)
				rr.fill.Size = UDim2.fromScale(ratio, 1)
				rr.prog.Text = Util.formatNumber(q.progress) .. " / " .. Util.formatNumber(q.target)
				if q.claimed then
					rr.btn.Text = "✓ Terminé"
					Ui.setEnabled(rr.btn, false)
				else
					rr.btn.Text = "Récupérer"
					Ui.setEnabled(rr.btn, q.progress >= q.target, C.green)
				end
			end
		end
	end)
end

----------------------------------------------------------------------
-- Cadeau quotidien
----------------------------------------------------------------------
local function buildDaily()
	local p = Ui.createPanel("daily", "🎁 Cadeau quotidien", UDim2.fromOffset(640, 340), { color = C.purple })
	local grid = Ui.new("Frame", { Size = UDim2.new(1, -8, 0, 150), BackgroundTransparency = 1, Parent = p.body })
	Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(80, 140),
		CellPadding = UDim2.fromOffset(6, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local tiles = {}
	for i, r in ipairs(Config.DailyRewards) do
		local f = Ui.new("Frame", { LayoutOrder = i, BackgroundColor3 = C.row, Parent = grid })
		Ui.corner(f, 12)
		local st = Ui.stroke(f, C.bg, 3)
		Ui.label(f, { text = "Jour " .. i, size = 15, sizeUdim = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 4), stroke = true })
		local icon = r.kind == "egg" and "🥚" or (r.kind == "fossils" and "🦴" or "💰")
		Ui.label(f, { text = icon, size = 36, sizeUdim = UDim2.new(1, 0, 0, 50), pos = UDim2.fromOffset(0, 30) })
		Ui.label(
			f,
			{ text = r.label, size = 13, wrap = true, sizeUdim = UDim2.new(1, -4, 0, 50), pos = UDim2.fromOffset(2, 84), color = C.muted }
		)
		tiles[i] = { frame = f, stroke = st }
	end
	local msg = Ui.label(
		p.body,
		{ text = "", size = 16, color = C.muted, sizeUdim = UDim2.new(1, -8, 0, 24), pos = UDim2.fromOffset(0, 156), name = "Msg" }
	)
	local btn = Ui.button(p.body, {
		text = "Récupérer",
		size = UDim2.fromOffset(260, 50),
		pos = UDim2.new(0.5, 0, 0, 186),
		anchor = Vector2.new(0.5, 0),
		color = C.purple,
		onClick = function()
			Store.act("ClaimDaily")
		end,
	})
	Store.connect(function(st)
		local today = Util.dayNumber(Store.serverNow())
		local nextStreak = st.daily.streak
		if st.daily.canClaim then
			nextStreak = (st.daily.last == today - 1) and (st.daily.streak + 1) or 1
		end
		local idx = ((math.max(nextStreak, 1) - 1) % #Config.DailyRewards) + 1
		for i, t in ipairs(tiles) do
			local done = (not st.daily.canClaim and i <= idx) or (st.daily.canClaim and i < idx)
			t.stroke.Color = (i == idx and st.daily.canClaim) and C.gold or (done and C.green or C.bg)
			t.frame.BackgroundColor3 = done and Color3.fromRGB(50, 90, 70) or C.row
		end
		Ui.setEnabled(btn, st.daily.canClaim, C.purple)
		if st.daily.canClaim then
			msg.Text = "Série en cours : " .. st.daily.streak .. " jour(s). Récupère ton cadeau !"
		else
			local left = (today + 1) * 86400 - Store.serverNow()
			msg.Text = "Prochain cadeau dans " .. Util.formatTime(left) .. " (série : " .. st.daily.streak .. ")"
		end
	end)
	-- compte à rebours vivant
	task.spawn(function()
		while true do
			task.wait(1)
			if Ui.openName == "daily" and Store.state and not Store.state.daily.canClaim then
				local today = Util.dayNumber(Store.serverNow())
				msg.Text = "Prochain cadeau dans "
					.. Util.formatTime((today + 1) * 86400 - Store.serverNow())
					.. " (série : "
					.. Store.state.daily.streak
					.. ")"
			end
		end
	end)
end

----------------------------------------------------------------------
-- Renaissance
----------------------------------------------------------------------
local function buildRebirth()
	local p = Ui.createPanel("rebirth", "🌟 Nouvelle ère", UDim2.fromOffset(560, 420), { color = C.gold })
	local text = Ui.label(p.body, {
		text = "",
		size = 19,
		wrap = true,
		rich = true,
		valign = Enum.TextYAlignment.Top,
		sizeUdim = UDim2.new(1, -16, 0, 230),
		pos = UDim2.fromOffset(8, 4),
		name = "Text",
	})
	local btn = Ui.button(p.body, {
		text = "Renaître",
		size = UDim2.fromOffset(300, 56),
		pos = UDim2.new(0.5, 0, 0, 250),
		anchor = Vector2.new(0.5, 0),
		color = C.gold,
		textSize = 26,
	})
	local armedAt = 0
	btn.Activated:Connect(function()
		if btn:GetAttribute("Disabled") then
			return
		end
		if os.clock() - armedAt < 5 then
			armedAt = 0
			Store.act("Rebirth")
			Ui.closePanels()
		else
			armedAt = os.clock()
			btn.Text = "Confirmer ? (reset du parc)"
			task.delay(5, function()
				if armedAt ~= 0 and os.clock() - armedAt >= 5 then
					armedAt = 0
					if Store.state then
						btn.Text = "Renaître"
					end
				end
			end)
		end
	end)
	Store.connect(function(st)
		local maxed = st.rebirths >= Config.RebirthMax
		local can = st.cash >= st.rebirthCost and not maxed
		text.Text = string.format(
			'<b>Ère actuelle : %d</b>\n\nRenaître remet à zéro tes pièces, fossiles, bâtiments, améliorations et œufs en cours.\n<b>Tu gardes</b> tous tes dinos, ta collection et tes quêtes.\n\n<b>Bonus par ère</b> : +%d%% de revenus et +%d%% de fossiles, définitivement. Tu reçois aussi un <b>Œuf Cosmique</b> gratuit.\n\nCoût : <font color="%s">%s 💰</font> (tu as %s)',
			st.rebirths,
			Config.RebirthIncomeBonus * 100,
			Config.RebirthFossilBonus * 100,
			can and "#6ee87c" or "#ff7a70",
			Util.formatNumber(st.rebirthCost),
			Util.formatNumber(st.cash)
		)
		Ui.setEnabled(btn, can, C.gold)
		if not can then
			btn.Text = maxed and "Ère maximale" or "Pas assez de pièces"
		elseif btn.Text == "Pas assez de pièces" or btn.Text == "Ère maximale" then
			btn.Text = "Renaître"
		end
	end)
end

----------------------------------------------------------------------
-- Boutique Robux (uniquement si des IDs sont configurés)
----------------------------------------------------------------------
local function buildShop()
	local p = Ui.createPanel("shop", "🛒 Boutique", UDim2.fromOffset(560, 440), { color = C.red })
	listLayout(p.body)
	local order = 0
	local rows = {}
	local function add(kind, key, def)
		order = order + 1
		local r = row(p.body, order, 84)
		Ui.label(r, {
			text = def.name,
			size = 22,
			align = Enum.TextXAlignment.Left,
			sizeUdim = UDim2.new(1, -190, 0, 30),
			pos = UDim2.fromOffset(12, 8),
			stroke = true,
		})
		Ui.label(r, {
			text = def.desc,
			size = 14,
			color = C.muted,
			align = Enum.TextXAlignment.Left,
			valign = Enum.TextYAlignment.Top,
			wrap = true,
			sizeUdim = UDim2.new(1, -190, 0, 40),
			pos = UDim2.fromOffset(12, 38),
		})
		local btn = Ui.button(r, {
			text = "R$ " .. def.price,
			size = UDim2.fromOffset(150, 52),
			pos = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = C.green,
			onClick = function()
				Store.act("BuyPass", { kind = kind, key = key })
			end,
		})
		r.Visible = def.id > 0
		rows[#rows + 1] = { kind = kind, key = key, btn = btn, def = def }
	end
	for key, def in pairs(Config.Passes) do
		add("pass", key, def)
	end
	for key, def in pairs(Config.Products) do
		add("product", key, def)
	end
	Store.connect(function(st)
		for _, r in ipairs(rows) do
			if r.kind == "pass" then
				local owned = st.passes[r.key] and st.passes[r.key].owned
				r.btn.Text = owned and "✓ Possédé" or ("R$ " .. r.def.price)
				Ui.setEnabled(r.btn, not owned, C.green)
			end
		end
	end)
end

----------------------------------------------------------------------
-- Choix d'œuf (ouvert depuis un incubateur)
----------------------------------------------------------------------
local eggSlot = 1
local function buildEggs()
	local p = Ui.createPanel("eggs", "🥚 Choisis un œuf", UDim2.fromOffset(620, 470), { color = C.blue })
	listLayout(p.body)
	local rows = {}
	for i, id in ipairs(Config.EggOrder) do
		local def = Config.Eggs[id]
		local r = row(p.body, i, 92)
		local icon = Ui.new(
			"Frame",
			{ Size = UDim2.fromOffset(48, 62), Position = UDim2.fromOffset(12, 15), BackgroundColor3 = def.color, Parent = r }
		)
		Ui.corner(icon, 24)
		Ui.stroke(icon, def.spot, 3)
		Ui.label(r, {
			text = def.name,
			size = 22,
			align = Enum.TextXAlignment.Left,
			sizeUdim = UDim2.new(1, -250, 0, 28),
			pos = UDim2.fromOffset(74, 6),
			stroke = true,
		})
		local chances = {}
		local total = 0
		for _, w in pairs(def.weights) do
			total = total + w
		end
		for _, rid in ipairs(Config.RarityOrder) do
			local w = def.weights[rid]
			if w then
				local rar = Config.RarityById[rid]
				table.insert(
					chances,
					string.format('<font color="%s">%s %d%%</font>', hex(rar.color), rar.name, math.floor(w / total * 100 + 0.5))
				)
			end
		end
		Ui.label(r, {
			text = table.concat(chances, "  "),
			size = 13,
			rich = true,
			align = Enum.TextXAlignment.Left,
			valign = Enum.TextYAlignment.Top,
			wrap = true,
			sizeUdim = UDim2.new(1, -250, 0, 40),
			pos = UDim2.fromOffset(74, 36),
		})
		local timeLbl = Ui.label(r, {
			text = "",
			size = 13,
			color = C.muted,
			align = Enum.TextXAlignment.Left,
			sizeUdim = UDim2.new(1, -250, 0, 16),
			pos = UDim2.fromOffset(74, 72),
		})
		local btn = Ui.button(r, {
			text = "",
			size = UDim2.fromOffset(150, 56),
			pos = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = C.green,
			onClick = function()
				Store.act("StartHatch", { slot = eggSlot, egg = id })
				Ui.closePanels()
			end,
		})
		rows[id] = { btn = btn, time = timeLbl }
	end
	local function render(st)
		for id, rr in pairs(rows) do
			local def = Config.Eggs[id]
			if st.level < def.level then
				rr.btn.Text = "🔒 Niveau " .. def.level
				Ui.setEnabled(rr.btn, false)
			else
				rr.btn.Text = "🦴 " .. Util.formatNumber(def.cost)
				Ui.setEnabled(rr.btn, st.fossils >= def.cost, C.green)
			end
			local t = Economy.hatchTime(id, { upgrades = st.upgrades }, st.flags)
			rr.time.Text = "Éclosion : " .. Util.formatTime(t)
		end
	end
	Store.connect(render)
end

----------------------------------------------------------------------
-- Aventure : l'histoire du Professeur Rex
----------------------------------------------------------------------
local function buildStory()
	local p = Ui.createPanel("story", "📖 L'aventure du Professeur Rex", UDim2.fromOffset(620, 480), { color = C.blue })
	listLayout(p.body)
	local rows = {}
	for i, ch in ipairs(Config.Story) do
		local r = row(p.body, i, 96)
		local title = Ui.label(
			r,
			{
				text = ch.title,
				size = 20,
				align = Enum.TextXAlignment.Left,
				sizeUdim = UDim2.new(1, -190, 0, 26),
				pos = UDim2.fromOffset(12, 6),
				stroke = true,
			}
		)
		local text = Ui.label(
			r,
			{
				text = ch.text,
				size = 14,
				color = C.muted,
				wrap = true,
				align = Enum.TextXAlignment.Left,
				valign = Enum.TextYAlignment.Top,
				sizeUdim = UDim2.new(1, -190, 0, 40),
				pos = UDim2.fromOffset(12, 34),
			}
		)
		local prog = Ui.label(
			r,
			{
				text = "",
				size = 13,
				color = C.gold,
				align = Enum.TextXAlignment.Left,
				sizeUdim = UDim2.new(1, -190, 0, 18),
				pos = UDim2.fromOffset(12, 74),
			}
		)
		local btn = Ui.button(r, {
			text = "Récupérer",
			size = UDim2.fromOffset(150, 52),
			pos = UDim2.new(1, -10, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			color = C.green,
			onClick = function()
				Store.act("ClaimStory")
			end,
		})
		rows[i] = { row = r, title = title, text = text, prog = prog, btn = btn }
	end
	local function rewardText(r)
		if r.fossils then
			return r.fossils .. " 🦴"
		elseif r.cashMinutes then
			return r.cashMinutes .. " min de revenus"
		end
		return "un œuf " .. (Config.Eggs[r.egg] and Config.Eggs[r.egg].name or "")
	end
	Store.connect(function(st)
		for i, rr in ipairs(rows) do
			local ch = Config.Story[i]
			if i <= st.storyClaimed then
				rr.row.BackgroundColor3 = Color3.fromRGB(46, 84, 66)
				rr.prog.Text = "✓ Terminé"
				rr.btn.Text = "✓"
				Ui.setEnabled(rr.btn, false)
			elseif i == st.storyClaimed + 1 then
				rr.row.BackgroundColor3 = C.row
				local target = st.storyTarget or 1
				rr.prog.Text = string.format(
					"%s / %s   •   Récompense : %s",
					Util.formatNumber(math.min(st.storyValue, target)),
					Util.formatNumber(target),
					rewardText(ch.reward)
				)
				rr.btn.Text = "Récupérer"
				Ui.setEnabled(rr.btn, st.storyValue >= target, C.green)
			else
				rr.row.BackgroundColor3 = Color3.fromRGB(44, 50, 68)
				rr.prog.Text = "🔒 Chapitre suivant"
				rr.btn.Text = "…"
				Ui.setEnabled(rr.btn, false)
			end
		end
	end)
end

local function buildWelcome()
	local p = Ui.createPanel("welcome", "🦖 Bienvenue au Dino Dig Park !", UDim2.fromOffset(560, 400), { color = C.green })
	local text = Ui.label(p.body, {
		text = "<b>1.</b> Va dans la zone de fouille et appuie sur ⛏ CREUSER pour trouver des fossiles.\n<b>2.</b> Au laboratoire, place un œuf dans un incubateur (E ou toucher).\n<b>3.</b> Les dinos exposés dans tes enclos rapportent des 💰 : marche sur le pad vert du kiosque pour les collecter.\n<b>4.</b> Marche sur les boutons colorés pour agrandir ton parc.\n\nSuis le rayon jaune : il montre toujours le prochain objectif.",
		size = 19,
		wrap = true,
		rich = true,
		valign = Enum.TextYAlignment.Top,
		align = Enum.TextXAlignment.Left,
		sizeUdim = UDim2.new(1, -16, 0, 240),
		pos = UDim2.fromOffset(8, 4),
	})
	text.Name = "Steps"
	Ui.button(p.body, {
		text = "C'est parti !",
		size = UDim2.fromOffset(260, 54),
		pos = UDim2.new(0.5, 0, 0, 260),
		anchor = Vector2.new(0.5, 0),
		color = C.green,
		textSize = 24,
		onClick = Ui.closePanels,
	})
	local shown = false
	Store.connect(function(st)
		if not shown and st.stats.digs == 0 and st.stats.hatched == 0 and next(st.dinos) == nil then
			shown = true
			task.delay(1.5, function()
				if Ui.openName == nil then
					Ui.openPanel("welcome")
				end
			end)
		else
			shown = true
		end
	end)
end

function Panels.openEggs(slot)
	eggSlot = slot
	Ui.openPanel("eggs")
end

function Panels.build()
	buildUpgrades()
	buildCollection()
	buildQuests()
	buildDaily()
	buildRebirth()
	buildShop()
	buildEggs()
	buildStory()
	buildWelcome()
end

return Panels
