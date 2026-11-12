-- LocalScript : StarterPlayer/StarterPlayerScripts/Client
-- Interface 100 % générée par code (aucune image à importer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RState, RNotify, RHatch, RAction = Remotes:WaitForChild("State"), Remotes:WaitForChild("Notify"), Remotes:WaitForChild("Hatch"), Remotes:WaitForChild("Action")
local fmt = Config.fmt

local COL = {
	bg = Color3.fromRGB(15, 42, 27),
	panel = Color3.fromRGB(29, 77, 51),
	pill = Color3.fromRGB(10, 30, 20),
	yellow = Color3.fromRGB(255, 210, 63),
	text = Color3.fromRGB(244, 255, 246),
	muted = Color3.fromRGB(159, 199, 173),
	red = Color3.fromRGB(255, 107, 107),
	green = Color3.fromRGB(91, 227, 125),
	dis = Color3.fromRGB(75, 91, 81),
	dark = Color3.fromRGB(43, 34, 0),
}
local FONT = Enum.Font.GothamBold

local state = nil
local panel = nil -- { name, tab, confirm }
local costBtns = {}

---------------------------------------------------------------- Helpers UI
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	make("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o)
end
local function text(parent, props)
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or COL.text
	return make("TextLabel", props, parent)
end

local gui = make("ScreenGui", { Name = "ChipeUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local function pill(y, icon)
	local f = make("Frame", { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(176, 50), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.12 }, gui)
	corner(f, 25)
	text(f, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(36, 50), Text = icon, TextSize = 26 })
	local big = text(f, { Position = UDim2.fromOffset(48, 4), Size = UDim2.new(1, -54, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 20, Text = "0" })
	local small = text(f, { Position = UDim2.fromOffset(48, 28), Size = UDim2.new(1, -54, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, TextColor3 = COL.muted, Text = "" })
	return big, small
end
local coinsBig, coinsSmall = pill(8, "🪙")
local speedBig, speedSmall = pill(64, "⚡")
speedSmall.Text = "VITESSE"

local carryLbl = text(gui, { Position = UDim2.fromOffset(14, 118), Size = UDim2.fromOffset(170, 26), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Text = "", BackgroundTransparency = 0.2, BackgroundColor3 = COL.pill })
corner(carryLbl, 13)
carryLbl.Visible = false

local banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(330, 30), TextSize = 14, TextColor3 = COL.yellow, BackgroundTransparency = 0.12, BackgroundColor3 = COL.pill, Text = "", Visible = false })
corner(banner, 15)
make("UIStroke", { Color = COL.yellow, Thickness = 2 }, banner)

local toasts = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(360, 200), BackgroundTransparency = 1 }, gui)
make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, toasts)

local hint = text(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(340, 40), TextSize = 14, TextColor3 = COL.dark, BackgroundColor3 = COL.yellow, BackgroundTransparency = 0, TextWrapped = true, Text = "", Visible = false })
corner(hint, 12)

local function toast(msg)
	for _, c in ipairs(toasts:GetChildren()) do
		if c:IsA("TextLabel") and #toasts:GetChildren() > 3 then
			c:Destroy()
			break
		end
	end
	local t = text(toasts, { Size = UDim2.fromOffset(340, 30), TextSize = 14, Text = msg, BackgroundColor3 = COL.pill, BackgroundTransparency = 0.1, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y })
	corner(t, 10)
	make("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, t)
	Debris:AddItem(t, 3.2)
end

---------------------------------------------------------------- Pop d'éclosion
local pop = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.fromOffset(300, 200), BackgroundTransparency = 1, Visible = false }, gui)
local popScale = make("UIScale", { Scale = 1 }, pop)
local popEmoji = text(pop, { Size = UDim2.new(1, 0, 0, 110), TextSize = 96, Text = "" })
local popName = text(pop, { Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 34), TextSize = 26, Text = "", TextStrokeTransparency = 0 })
local popInfo = text(pop, { Position = UDim2.fromOffset(0, 148), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, Text = "", TextStrokeTransparency = 0 })
local popToken = 0

local function hatchPop(info)
	local def = Config.PETS[info.p]
	local tier = Config.TIERS[def.tier]
	popToken += 1
	local token = popToken
	popEmoji.Text = def.emoji
	popName.Text = Config.petName(info.p, info.s, info.m)
	popName.TextColor3 = tier.color
	popInfo.Text = tier.name .. "  ·  +" .. fmt(info.inc) .. "/s"
	pop.Visible = true
	popScale.Scale = 0.2
	TweenService:Create(popScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if token == popToken then
			pop.Visible = false
		end
	end)
end

---------------------------------------------------------------- Panneaux
local panelFrame = make("Frame", { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.8), BackgroundColor3 = COL.bg, Visible = false }, gui)
corner(panelFrame, 18)
make("UISizeConstraint", { MaxSize = Vector2.new(560, 470) }, panelFrame)
make("UIStroke", { Color = COL.panel, Thickness = 2 }, panelFrame)
local titleLbl = text(panelFrame, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 22, Text = "" })
local closeBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = COL.panel, Text = "✕", Font = FONT, TextSize = 16, TextColor3 = COL.text }, panelFrame)
corner(closeBtn, 17)
local tabsFrame = make("Frame", { Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1 }, panelFrame)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabsFrame)
local scroll = make("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 1, -96), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panelFrame)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

local function coins()
	return player:GetAttribute("Coins") or 0
end

local function paintCost(btn, cost)
	local ok = coins() >= cost
	btn.BackgroundColor3 = ok and COL.yellow or COL.dis
	btn.TextColor3 = ok and COL.dark or Color3.fromRGB(152, 168, 158)
end

local function addRow(o)
	local f = make("Frame", { Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = COL.panel }, scroll)
	corner(f, 14)
	local ic = text(f, { Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 0.7, BackgroundColor3 = Color3.new(0, 0, 0), Text = o.icon or "", TextSize = 28 })
	corner(ic, 12)
	if o.iconColor then
		make("UIStroke", { Color = o.iconColor, Thickness = 2 }, ic)
	end
	local rightPad = o.btn and 130 or 20
	text(f, { Position = UDim2.fromOffset(62, 5), Size = UDim2.new(1, -62 - rightPad, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, Text = o.title or "", TextColor3 = o.titleColor or COL.text, TextTruncate = Enum.TextTruncate.AtEnd })
	text(f, { Position = UDim2.fromOffset(62, 29), Size = UDim2.new(1, -62 - rightPad, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 12, Text = o.desc or "", TextColor3 = COL.muted, TextWrapped = true, Font = Enum.Font.Gotham })
	if o.btn then
		local b = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(112, 40), Text = o.btn, Font = FONT, TextSize = 14, AutoButtonColor = true, BackgroundColor3 = o.btnColor or COL.yellow, TextColor3 = o.btnText or COL.dark }, f)
		corner(b, 10)
		if o.cost then
			costBtns[b] = o.cost
			paintCost(b, o.cost)
		end
		if o.onClick then
			b.Activated:Connect(o.onClick)
		end
	end
	return f
end

local function addNote(msg)
	local l = text(scroll, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextSize = 13, TextWrapped = true, Text = msg, TextColor3 = COL.muted, Font = Enum.Font.Gotham })
	return l
end

local function avgInc(tier)
	local sum, n = 0, 0
	for _, p in ipairs(Config.PETS) do
		if p.tier == tier then
			sum += p.inc
			n += 1
		end
	end
	return sum / n
end

local tabsDef = {
	shop = { { "eggs", "🥚 Œufs" }, { "up", "⬆️ Améliorations" } },
	dex = { { "col", "📖 Pets" }, { "base", "🏠 Ma base" } },
}
local titles = { shop = "Boutique", dex = "Collection", bonus = "Bonus", more = "Plus" }

local render
local function setTab(t)
	panel.tab = t
	panel.confirm = false
	render()
	scroll.CanvasPosition = Vector2.new(0, 0)
end

function render()
	if not panel or not state then
		return
	end
	local keep = scroll.CanvasPosition
	for _, c in ipairs(scroll:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	for _, c in ipairs(tabsFrame:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	costBtns = {}
	titleLbl.Text = titles[panel.name]

	local tabs = tabsDef[panel.name]
	tabsFrame.Visible = tabs ~= nil
	scroll.Position = tabs and UDim2.fromOffset(10, 86) or UDim2.fromOffset(10, 50)
	scroll.Size = tabs and UDim2.new(1, -20, 1, -96) or UDim2.new(1, -20, 1, -60)
	if tabs then
		for _, t in ipairs(tabs) do
			local on = panel.tab == t[1]
			local b = make("TextButton", { Size = UDim2.new(1 / #tabs, -6, 1, 0), BackgroundColor3 = on and COL.yellow or COL.panel, Text = t[2], Font = FONT, TextSize = 14, TextColor3 = on and COL.dark or COL.muted }, tabsFrame)
			corner(b, 17)
			b.Activated:Connect(function()
				setTab(t[1])
			end)
		end
	end

	if panel.name == "shop" and panel.tab == "eggs" then
		addNote("Achète un œuf : il va directement dans ta base. Voler chez les rivaux est gratuit mais risqué.")
		for i, t in ipairs(Config.TIERS) do
			addRow({
				icon = "🥚", iconColor = t.color, title = "Œuf " .. t.name, titleColor = t.color,
				desc = "Éclot en " .. Config.fmtTime(Config.HATCH[i] * 0.9 ^ state.up.inc) .. " · ~" .. fmt(avgInc(i) * state.mult) .. "/s en moyenne",
				btn = "🪙 " .. fmt(Config.EGG_PRICE[i]), cost = Config.EGG_PRICE[i],
				onClick = function()
					RAction:FireServer("buyEgg", i)
				end,
			})
		end
	elseif panel.name == "shop" then
		for _, u in ipairs(Config.UPGRADES) do
			local l = state.up[u.key] or 0
			local maxed = l >= u.max
			addRow({
				icon = u.emoji, title = u.name .. "  (niv. " .. l .. "/" .. u.max .. ")",
				desc = maxed and "Niveau maximum" or u.desc(l),
				btn = maxed and "MAX" or ("🪙 " .. fmt(u.cost(l))), cost = (not maxed) and u.cost(l) or nil,
				btnColor = maxed and COL.dis or nil,
				onClick = (not maxed) and function()
					RAction:FireServer("buyUp", u.key)
				end or nil,
			})
		end
	elseif panel.name == "dex" and panel.tab == "col" then
		local got = 0
		for k in pairs(state.dex) do
			got += 1
		end
		addNote(got .. "/" .. #Config.PETS .. " espèces découvertes. Tailles et mutations rares multiplient les revenus.")
		for i, p in ipairs(Config.PETS) do
			local d = state.dex[tostring(i)]
			local tier = Config.TIERS[p.tier]
			addRow({
				icon = d and p.emoji or "❓", iconColor = d and tier.color or nil,
				title = d and p.name or "???", titleColor = d and tier.color or COL.muted,
				desc = tier.name .. (d and (" · obtenu x" .. d.n .. " · record x" .. fmt(d.b)) or ""),
			})
		end
	elseif panel.name == "dex" then
		local n = 0
		for i = 1, state.cap do
			local sl = state.slots[i]
			if sl and sl.k == "p" then
				n += 1
				local p = Config.PETS[sl.p]
				addRow({
					icon = p.emoji, iconColor = Config.TIERS[p.tier].color, title = Config.petName(sl.p, sl.s, sl.m),
					desc = "+" .. fmt(Config.petIncome(sl.p, sl.s, sl.m) * state.mult) .. "/s",
					btn = "Vendre " .. fmt(Config.sellValue(sl.p, sl.s, sl.m)), btnColor = COL.red, btnText = COL.text,
					onClick = function()
						RAction:FireServer("sell", i)
					end,
				})
			end
		end
		if n == 0 then
			addNote("Aucun pet pour l'instant. Fais éclore des œufs !")
		end
	elseif panel.name == "bonus" then
		addRow({
			icon = "🎁", title = "Bonus quotidien",
			desc = state.dailyReady and ("Série " .. state.streak .. " jour(s) → 🪙 " .. fmt(state.dailyReward)) or "Reviens demain !",
			btn = state.dailyReady and "Récupérer" or "Pris", btnColor = state.dailyReady and COL.green or COL.dis,
			onClick = state.dailyReady and function()
				RAction:FireServer("daily")
			end or nil,
		})
		local passNames = {}
		for name in pairs(Config.PASSES) do
			passNames[#passNames + 1] = name
		end
		table.sort(passNames)
		for _, name in ipairs(passNames) do
			local def = Config.PASSES[name]
			local owned = state.passes[name]
			addRow({
				icon = def.emoji, title = def.name, desc = def.desc,
				btn = owned and "✅ Actif" or (def.id > 0 and "Acheter" or "Bientôt"),
				btnColor = (owned or def.id == 0) and COL.dis or COL.green,
				onClick = (not owned and def.id > 0) and function()
					MarketplaceService:PromptGamePassPurchase(player, def.id)
				end or nil,
			})
		end
	elseif panel.name == "more" then
		local cost = Config.rebirthCost(state.rb)
		addRow({
			icon = "♻️", title = "Renaissance" .. (state.rb > 0 and (" (x" .. state.rb .. ")") or ""),
			desc = "Remet pièces, pets et améliorations à zéro. Garde vitesse et collection. Revenus +50% définitif.",
			btn = panel.confirm and "Confirmer ?" or ("🪙 " .. fmt(cost)),
			btnColor = panel.confirm and COL.red or nil, btnText = panel.confirm and COL.text or nil, cost = (not panel.confirm) and cost or nil,
			onClick = function()
				if coins() < cost then
					return toast("Il te faut 🪙 " .. fmt(cost) .. " pour renaître.")
				end
				if panel.confirm then
					RAction:FireServer("rebirth")
					panel.confirm = false
					render()
				else
					panel.confirm = true
					render()
				end
			end,
		})
		addNote(string.format("Œufs volés : %d · Œufs éclos : %d · Vitesse : %s", state.stolen, state.hatched, fmt(player:GetAttribute("Speed") or 0)))
		addNote("Comment jouer : maintiens le bouton de vol devant un œuf pour le prendre (évite le gardien 🐕), rapporte-le dans ta base, touche-le pour accélérer l'éclosion. Cours sur le tapis pour gagner en vitesse. Les autres joueurs peuvent voler tes œufs non protégés 🛡 !")
	end
	task.defer(function()
		scroll.CanvasPosition = keep
	end)
end

local function openPanel(name)
	if panel and panel.name == name then
		panel = nil
		panelFrame.Visible = false
		return
	end
	panel = { name = name, tab = tabsDef[name] and tabsDef[name][1][1] or "", confirm = false }
	panelFrame.Visible = true
	render()
end
closeBtn.Activated:Connect(function()
	panel = nil
	panelFrame.Visible = false
end)

---------------------------------------------------------------- Boutons de navigation (colonne gauche)
local navDefs = { { "shop", "🛒", "Boutique" }, { "dex", "📖", "Collection" }, { "bonus", "🎁", "Bonus" }, { "more", "♻️", "Plus" } }
for i, n in ipairs(navDefs) do
	local b = make("TextButton", { Position = UDim2.fromOffset(10, 152 + (i - 1) * 68), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = COL.pill, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = true }, gui)
	corner(b, 16)
	make("UIStroke", { Color = COL.panel, Thickness = 2 }, b)
	text(b, { Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 3), Text = n[2], TextSize = 26 })
	text(b, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 42), Text = n[3], TextSize = 11 })
	b.Activated:Connect(function()
		openPanel(n[1])
	end)
end

---------------------------------------------------------------- Réseau
RState.OnClientEvent:Connect(function(snap)
	state = snap
	if panel then
		render()
	end
end)
RNotify.OnClientEvent:Connect(toast)
RHatch.OnClientEvent:Connect(hatchPop)

local function refreshStats()
	coinsBig.Text = fmt(coins())
	coinsSmall.Text = "+" .. fmt(player:GetAttribute("Income") or 0) .. "/s"
	speedBig.Text = fmt(math.floor(player:GetAttribute("Speed") or 0))
	for b, cost in pairs(costBtns) do
		if b.Parent then
			paintCost(b, cost)
		else
			costBtns[b] = nil
		end
	end
end
for _, a in ipairs({ "Coins", "Income", "Speed" }) do
	player:GetAttributeChangedSignal(a):Connect(refreshStats)
end
refreshStats()

task.spawn(function()
	repeat
		RAction:FireServer("sync")
		task.wait(1.5)
	until state
end)

---------------------------------------------------------------- Bannière d'événement, compteur de sac, conseils
task.spawn(function()
	while true do
		local key = workspace:GetAttribute("EventKey")
		local ends = workspace:GetAttribute("EventEnds")
		banner.Visible = false
		if key and ends then
			for _, e in ipairs(Config.EVENTS) do
				if e.key == key then
					banner.Text = e.emoji .. " " .. e.name .. " · " .. e.desc .. " · " .. math.max(0, ends - os.time()) .. "s"
					banner.Visible = true
				end
			end
		end
		if state then
			carryLbl.Visible = state.carry > 0
			carryLbl.Text = "🥚 " .. state.carry .. "/" .. state.carryCap
			local msg
			if state.hatched == 0 then
				msg = "Touche ton œuf 🥚 pour accélérer l'éclosion !"
			elseif state.stolen == 0 then
				msg = "Va chez un rival (au nord) et maintiens le bouton pour voler un œuf… évite son gardien 🐕"
			elseif (player:GetAttribute("Speed") or 0) < 8 then
				msg = "Cours sur le tapis roulant 🏃 au centre pour devenir plus rapide !"
			end
			hint.Visible = msg ~= nil and not panelFrame.Visible
			hint.Text = msg or ""
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Prompts de vol : durée selon ton niveau, cachés pour ton propre œuf
-- (propriétés modifiées côté client uniquement : elles ne se répliquent pas au serveur)
task.spawn(function()
	while true do
		local lvl = state and state.up.fing or 0
		for _, pr in ipairs(CollectionService:GetTagged("StealPrompt")) do
			pr.HoldDuration = Config.stealTime(lvl)
			pr.Enabled = pr:GetAttribute("Owner") ~= player.UserId
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Pets qui "respirent" (animation locale)
local bobBase = setmetatable({}, { __mode = "k" })
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, m in ipairs(CollectionService:GetTagged("Bob")) do
		local base = bobBase[m]
		if not base and m.PrimaryPart then
			base = m:GetPivot()
			bobBase[m] = base
		end
		if base then
			m:PivotTo(base * CFrame.new(0, math.sin(t * 3 + base.X + base.Z) * 0.25, 0))
		end
	end
end)
