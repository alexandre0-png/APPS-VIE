-- Hud.luau : interface permanente (monnaies, boutons de menu, objectif, notifications, boutons contextuels).

local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local Ui = require(script.Parent.Ui)
local Store = require(script.Parent.StateStore)

local Hud = {}

Hud.context = { inDigZone = false, nearBooth = false }
Hud.objectiveTarget = nil

local C = Ui.colors
local pills = {}
local menuButtons = {}
local toastHolder, objectiveLabel, eventLabel, boostLabel, digButton, collectButton, warnLabel

----------------------------------------------------------------------
-- Monnaies
----------------------------------------------------------------------
local function makePill(parent, icon, order, color)
	local f = Ui.new(
		"Frame",
		{ Size = UDim2.fromOffset(230, 44), BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, LayoutOrder = order, Parent = parent }
	)
	Ui.corner(f, 22)
	Ui.stroke(f, color, 3)
	Ui.label(f, { text = icon, size = 26, sizeUdim = UDim2.fromOffset(44, 44), name = "Icon" })
	local v = Ui.label(f, {
		text = "0",
		size = 24,
		align = Enum.TextXAlignment.Left,
		pos = UDim2.fromOffset(46, 0),
		sizeUdim = UDim2.new(1, -56, 1, 0),
		stroke = true,
		name = "Value",
	})
	local sc = Ui.new("UIScale", { Parent = v })
	return { frame = f, value = v, scale = sc, last = 0 }
end

local function setPill(p, value, text)
	p.value.Text = text
	if value > p.last + 0.5 then
		p.scale.Scale = 1.18
		TweenService:Create(p.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	p.last = value
end

----------------------------------------------------------------------
-- Notifications
----------------------------------------------------------------------
function Hud.toast(text, kind)
	local color = C.blue
	if kind == "good" then
		color = C.green
	elseif kind == "bad" then
		color = C.red
	end
	local t =
		Ui.new("Frame", { Size = UDim2.fromOffset(380, 42), BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, Parent = toastHolder })
	Ui.corner(t, 14)
	Ui.stroke(t, color, 3)
	local l = Ui.label(t, { text = text, size = 18, wrap = true, stroke = true })
	l.TextTransparency = 1
	t.BackgroundTransparency = 1
	TweenService:Create(t, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(l, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	if kind == "bad" then
		Ui.playSound("error", 0.3)
	end
	task.delay(3.2, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
end

----------------------------------------------------------------------
-- Objectif (tutoriel contextuel)
----------------------------------------------------------------------
local function cheapestEgg()
	return Config.Eggs[Config.EggOrder[1]]
end

local function computeObjective(st)
	local hasDino = next(st.dinos) ~= nil
	local slots = st.eggSlots
	local ready, hatching = nil, false
	for k, info in pairs(slots) do
		if Store.serverNow() >= info.finish then
			ready = tonumber(k)
		else
			hatching = true
		end
	end
	if ready then
		return "Récupère ton œuf prêt dans le laboratoire ! 🥚", { kind = "stand", slot = ready }
	end
	if st.storyTarget and st.storyValue >= st.storyTarget then
		return "📖 Chapitre terminé : récupère ta récompense (bouton Aventure)", nil
	end
	if not hasDino and not hatching then
		if st.fossils < cheapestEgg().cost then
			return string.format("Creuse des fossiles ⛏ (%d/%d)", math.floor(st.fossils), cheapestEgg().cost), { kind = "dig" }
		end
		return "Place un œuf dans l'incubateur du laboratoire 🥚", { kind = "stand", slot = 1 }
	end
	if hatching and not hasDino then
		return "L'œuf éclot… creuse en attendant ⛏", { kind = "dig" }
	end
	if st.pending >= math.max(20, st.income * 20) then
		return "Collecte tes pièces au kiosque 💰", { kind = "booth" }
	end
	-- prochain achat
	local best
	for _, def in ipairs(Config.Buildables) do
		if not st.buildables[def.id] and (def.requires == nil or st.buildables[def.requires]) then
			if best == nil or def.cost < best.cost then
				best = def
			end
		end
	end
	if best then
		if st.cash >= best.cost then
			return "Achète : " .. best.name .. " (" .. Util.formatNumber(best.cost) .. " 💰)", { kind = "pad", id = best.id }
		end
		local freeSlot
		for s = 1, st.incubators do
			if not slots[tostring(s)] then
				freeSlot = s
				break
			end
		end
		if freeSlot and st.fossils >= cheapestEgg().cost then
			return "Fais éclore un œuf pour gagner plus de 💰", { kind = "stand", slot = freeSlot }
		end
		return "Objectif : " .. best.name .. " (" .. Util.formatNumber(best.cost) .. " 💰)", { kind = "pad", id = best.id }
	end
	if st.cash >= st.rebirthCost then
		return "🌟 Renaissance disponible ! (bouton Ère)", nil
	end
	return "Complète ta collection et tes quêtes !", nil
end

----------------------------------------------------------------------
-- Construction
----------------------------------------------------------------------
local function buildMenu(parent)
	local col = Ui.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(84, 500),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = col,
	})
	local defs = {
		{ id = "collection", icon = "🦖", label = "Dinos", panel = "collection", color = C.green },
		{ id = "upgrades", icon = "⛏", label = "Boost", panel = "upgrades", color = C.orange },
		{ id = "quests", icon = "📜", label = "Quêtes", panel = "quests", color = C.blue },
		{ id = "daily", icon = "🎁", label = "Cadeau", panel = "daily", color = C.purple },
		{ id = "rebirth", icon = "🌟", label = "Ère", panel = "rebirth", color = C.gold },
		{ id = "story", icon = "📖", label = "Aventure", panel = "story", color = C.blue },
		{ id = "shop", icon = "🛒", label = "Boutique", panel = "shop", color = C.red },
	}
	for i, d in ipairs(defs) do
		local b = Ui.button(col, {
			name = d.id,
			text = "",
			size = UDim2.fromOffset(74, 62),
			color = d.color,
			radius = 14,
			onClick = function()
				Ui.togglePanel(d.panel)
			end,
		})
		b.LayoutOrder = i
		Ui.label(b, { text = d.icon, size = 28, sizeUdim = UDim2.fromScale(1, 0.62), z = 2, name = "Icon" })
		Ui.label(b, {
			text = d.label,
			size = 14,
			sizeUdim = UDim2.fromScale(1, 0.36),
			pos = UDim2.fromScale(0, 0.62),
			stroke = true,
			z = 2,
			name = "Caption",
		})
		local dot = Ui.new("Frame", {
			Name = "Dot",
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.new(1, -6, 0, 6),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = C.red,
			Visible = false,
			ZIndex = 5,
			Parent = b,
		})
		Ui.corner(dot, 10)
		Ui.stroke(dot, Color3.new(1, 1, 1), 2)
		menuButtons[d.id] = { button = b, dot = dot }
	end
	-- bouton son
	local snd = Ui.button(parent, {
		text = "🔊",
		size = UDim2.fromOffset(44, 44),
		pos = UDim2.new(0, 8, 1, -8),
		anchor = Vector2.new(0, 1),
		color = C.bg,
		textSize = 22,
	})
	snd.Activated:Connect(function()
		Ui.settings.sfx = not Ui.settings.sfx
		snd.Text = Ui.settings.sfx and "🔊" or "🔇"
	end)
end

function Hud.build(root)
	-- monnaies (haut gauche)
	local topLeft = Ui.new("Frame", {
		Name = "Currencies",
		Size = UDim2.fromOffset(230, 210),
		Position = UDim2.fromOffset(8, 8),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = topLeft })
	pills.cash = makePill(topLeft, "💰", 1, C.gold)
	pills.fossils = makePill(topLeft, "🦴", 2, Color3.fromRGB(235, 225, 195))
	pills.income = makePill(topLeft, "⚡", 3, C.green)
	pills.level = makePill(topLeft, "⭐", 4, C.purple)

	-- objectif + événement (haut centre)
	local top = Ui.new("Frame", {
		Name = "Top",
		Size = UDim2.fromOffset(440, 110),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Ui.new("UIListLayout", {
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})
	local obj = Ui.new(
		"Frame",
		{ Size = UDim2.fromOffset(420, 40), BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, LayoutOrder = 1, Parent = top }
	)
	Ui.corner(obj, 20)
	Ui.stroke(obj, C.blue, 3)
	objectiveLabel = Ui.label(obj, { text = "", size = 17, stroke = true, wrap = true })
	local ev = Ui.new("Frame", {
		Name = "Event",
		Size = UDim2.fromOffset(300, 32),
		BackgroundColor3 = Color3.fromRGB(120, 40, 30),
		LayoutOrder = 2,
		Visible = false,
		Parent = top,
	})
	Ui.corner(ev, 16)
	Ui.stroke(ev, C.orange, 3)
	eventLabel = Ui.label(ev, { text = "", size = 16, stroke = true })
	Hud.eventFrame = ev

	-- toasts
	toastHolder = Ui.new("Frame", {
		Name = "Toasts",
		Size = UDim2.fromOffset(400, 200),
		Position = UDim2.new(0.5, 0, 0, 130),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = toastHolder })

	-- boost
	local boost = Ui.new("Frame", {
		Name = "Boost",
		Size = UDim2.fromOffset(200, 36),
		Position = UDim2.new(0, 8, 1, -64),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	})
	Ui.corner(boost, 18)
	Ui.stroke(boost, C.gold, 3)
	boostLabel = Ui.label(boost, { text = "", size = 17, stroke = true })
	Hud.boostFrame = boost

	-- bouton creuser
	digButton = Ui.button(root, {
		name = "Dig",
		text = "⛏ CREUSER (F)",
		size = UDim2.fromOffset(210, 74),
		pos = UDim2.new(0.5, 0, 1, -16),
		anchor = Vector2.new(0.5, 1),
		color = C.orange,
		textSize = 30,
	})
	digButton.Visible = false
	local holding = false
	digButton.MouseButton1Down:Connect(function()
		if holding then
			return
		end
		holding = true
		task.spawn(function()
			while holding do
				Store.act("Dig")
				task.wait(Config.DigCooldown + 0.03)
			end
		end)
	end)
	local function stop()
		holding = false
	end
	digButton.MouseButton1Up:Connect(stop)
	digButton.MouseLeave:Connect(stop)
	digButton.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			stop()
		end
	end)

	-- clavier / manette : F, ou bouton X de la manette, maintenu = creuser (actif uniquement dans la zone de fouille)
	ContextActionService:BindAction("DinoDig", function(_, state)
		if state == Enum.UserInputState.Begin and digButton.Visible then
			holding = true
			task.spawn(function()
				while holding and digButton.Visible do
					Store.act("Dig")
					task.wait(Config.DigCooldown + 0.03)
				end
				holding = false
			end)
		elseif state == Enum.UserInputState.End then
			holding = false
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonX)

	-- bouton collecter
	collectButton = Ui.button(root, {
		name = "Collect",
		text = "💰 COLLECTER",
		size = UDim2.fromOffset(210, 64),
		pos = UDim2.new(0.5, 0, 1, -16),
		anchor = Vector2.new(0.5, 1),
		color = C.green,
		textSize = 26,
		onClick = function()
			Store.act("Collect")
		end,
	})
	collectButton.Visible = false

	-- avertissement données volatiles (Studio)
	warnLabel = Ui.label(root, {
		text = "Mode test : progression non sauvegardée",
		size = 14,
		color = C.red,
		sizeUdim = UDim2.fromOffset(320, 20),
		pos = UDim2.new(0.5, 0, 1, -2),
		anchor = Vector2.new(0.5, 1),
		stroke = true,
	})
	warnLabel.Visible = false

	buildMenu(root)

	Remotes.Notify.OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and type(msg.text) == "string" then
			Hud.toast(msg.text, msg.kind)
		end
	end)

	Store.connect(Hud.onState)

	-- rafraîchissement contextuel (5 Hz) : boutons de zone, événement, boost
	task.spawn(function()
		while true do
			task.wait(0.2)
			Hud.refreshContext()
		end
	end)
end

function Hud.onState(st)
	setPill(pills.cash, st.cash, Util.formatNumber(st.cash))
	setPill(pills.fossils, st.fossils, Util.formatNumber(math.floor(st.fossils)))
	setPill(pills.income, st.income, Util.formatNumber(st.income) .. "/s")
	if st.levelNeed then
		setPill(pills.level, st.level, "Niv. " .. st.level .. "  (" .. st.levelHave .. "/" .. st.levelNeed .. ")")
	else
		setPill(pills.level, st.level, "Niv. " .. st.level .. " MAX")
	end
	menuButtons.story.dot.Visible = st.storyTarget ~= nil and st.storyValue >= st.storyTarget
	warnLabel.Visible = st.volatile == true

	local text, target = computeObjective(st)
	objectiveLabel.Text = text
	Hud.objectiveTarget = target

	-- pastilles de notification
	local claimable = 0
	for _, q in ipairs(st.quests) do
		if not q.claimed and q.progress >= q.target then
			claimable = claimable + 1
		end
	end
	menuButtons.quests.dot.Visible = claimable > 0
	menuButtons.daily.dot.Visible = st.daily.canClaim
	menuButtons.rebirth.dot.Visible = st.cash >= st.rebirthCost
	local anyShop = false
	for _, p in pairs(st.passes) do
		if p.id > 0 then
			anyShop = true
		end
	end
	for _, p in pairs(Config.Products) do
		if p.id > 0 then
			anyShop = true
		end
	end
	menuButtons.shop.button.Visible = anyShop
	Hud.refreshContext()
end

function Hud.refreshContext()
	local st = Store.state
	if not st then
		return
	end
	digButton.Visible = Hud.context.inDigZone and Ui.openName == nil
	collectButton.Visible = (not digButton.Visible) and Hud.context.nearBooth and st.pending >= 1 and Ui.openName == nil
	-- événement serveur
	local name = Workspace:GetAttribute("EventName")
	local endsAt = Workspace:GetAttribute("EventEndsAt")
	if name and endsAt then
		Hud.eventFrame.Visible = true
		eventLabel.Text = name .. " — " .. Util.formatTime(endsAt - Store.serverNow())
	else
		Hud.eventFrame.Visible = false
	end
	-- boost
	local left = st.boostUntil - Store.serverNow()
	if left > 0 then
		Hud.boostFrame.Visible = true
		boostLabel.Text = "⚡ Boost x2 — " .. Util.formatTime(left)
	else
		Hud.boostFrame.Visible = false
	end
end

return Hud
