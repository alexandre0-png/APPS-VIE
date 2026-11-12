--!nonstrict
-- Fenêtres : boutique, nid (compagnons), quêtes, classement, évolution + animation d'éclosion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))

local Store = require(script.Parent.Store)
local UIKit = require(script.Parent.UIKit)
local HUD = require(script.Parent.HUD)

local C = UIKit.Colors
local Panels = {}

local gui: ScreenGui
local windows: { [string]: any } = {}
local current: string? = nil

local function rarityDef(id: string): any
	for _, r in ipairs(Config.Rarities) do
		if r.Id == id then
			return r
		end
	end
	return Config.Rarities[1]
end

local function rarityColor(id: string): Color3
	local c = rarityDef(id).Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function act(action: string, payload: any?)
	local r = Store.request(action, payload)
	if r.msg and r.msg ~= "" then
		HUD.toast(r.msg, if r.ok then "good" else "bad")
	end
	if r.ok then
		UIKit.sfx("Coin", 0.4)
	end
	return r
end

local function createWindow(name: string, title: string)
	local w = UIKit.frame(gui, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(580, 440),
		Visible = false,
	})
	UIKit.corner(w, 16)
	UIKit.gradient(w, 0.7)
	UIKit.stroke(w, C.accent, 3)
	local scale = Instance.new("UIScale")
	scale.Parent = w
	local function update()
		local cam = workspace.CurrentCamera
		if cam then
			local vp = cam.ViewportSize
			scale.Scale = math.clamp(math.min(vp.X / 660, vp.Y / 500), 0.55, 1.15)
		end
	end
	update()
	task.defer(function()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
	end)

	UIKit.label(w, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(440, 40), Text = title, TextSize = 28, Font = Enum.Font.FredokaOne, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold })
	UIKit.button(w, {
		Position = UDim2.new(1, -52, 0, 8),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.bad,
		Text = "X",
		TextSize = 22,
		Callback = function()
			Panels.close()
		end,
	})
	local content = UIKit.frame(w, { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 1, -68), BackgroundTransparency = 1 })
	local win = { frame = w, content = content, refresh = function(_) end, onOpen = function() end }
	windows[name] = win
	return win
end

function Panels.close()
	if current and windows[current] then
		windows[current].frame.Visible = false
	end
	current = nil
end

function Panels.open(name: string)
	local win = windows[name]
	if not win then
		return
	end
	if current == name then
		Panels.close()
		return
	end
	Panels.close()
	current = name
	win.frame.Visible = true
	if Store.state then
		win.refresh(Store.state)
	end
	win.onOpen()
end

-- ---------------------------------------------------------------- boutique

local function buildShop()
	local win = createWindow("shop", "🛒 Boutique")
	local content = win.content

	local tabs = {}
	local pages = {}
	local function selectTab(id: string)
		for k, p in pairs(pages) do
			p.Visible = (k == id)
			tabs[k].BackgroundColor3 = if k == id then C.accent else C.panel2
		end
	end
	local function makeTab(id: string, text: string, x: number)
		tabs[id] = UIKit.button(content, { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(200, 36), Text = text, BackgroundColor3 = C.panel2, TextSize = 17, Callback = function() selectTab(id) end })
		pages[id] = UIKit.scroll(content, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Visible = false })
		UIKit.list(pages[id], 8)
	end
	makeTab("upgrades", "💪 Améliorations", 0)
	makeTab("foods", "🍔 Nourritures", 150)
	makeTab("robux", "💎 Robux", 300)
	tabs.upgrades.Size = UDim2.fromOffset(142, 36)
	tabs.foods.Size = UDim2.fromOffset(142, 36)
	tabs.robux.Size = UDim2.fromOffset(142, 36)

	local upgradeRows = {}
	for i, def in ipairs(Config.Upgrades) do
		local row = UIKit.frame(pages.upgrades, { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = C.panel2, LayoutOrder = i })
		UIKit.corner(row, 12)
		UIKit.label(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(46, 56), Text = def.Icon, TextSize = 34 })
		local title = UIKit.label(row, { Position = UDim2.fromOffset(62, 6), Size = UDim2.fromOffset(280, 24), Text = def.Name, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne })
		UIKit.label(row, { Position = UDim2.fromOffset(62, 32), Size = UDim2.fromOffset(280, 26), Text = def.Desc, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim })
		local btn = UIKit.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(150, 46),
			Text = "",
			TextSize = 16,
			Callback = function()
				act("buyUpgrade", { id = def.Id })
			end,
		})
		upgradeRows[def.Id] = { title = title, btn = btn, def = def }
	end

	local foodRows = {}
	for i, food in ipairs(Config.Foods) do
		local row = UIKit.frame(pages.foods, { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = C.panel2, LayoutOrder = i })
		UIKit.corner(row, 12)
		UIKit.label(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(46, 56), Text = food.Emoji, TextSize = 34 })
		UIKit.label(row, { Position = UDim2.fromOffset(62, 6), Size = UDim2.fromOffset(280, 24), Text = food.Name, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne })
		UIKit.label(row, { Position = UDim2.fromOffset(62, 32), Size = UDim2.fromOffset(280, 26), Text = string.format("Valeur de base : %d pièces", food.Value), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim })
		local btn = UIKit.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(150, 46),
			Text = "",
			TextSize = 16,
			Callback = function()
				act("buyFood", { id = food.Id })
			end,
		})
		foodRows[food.Id] = { btn = btn, food = food }
	end

	-- Achats Robux : l'invite d'achat est ouverte par Roblox ; le serveur valide et octroie.
	local robuxRows = {}
	local order = 0
	local function robuxRow(kind: string, key: string, def: any)
		order += 1
		local row = UIKit.frame(pages.robux, { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = C.panel2, LayoutOrder = order })
		UIKit.corner(row, 12)
		UIKit.label(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(46, 56), Text = def.Emoji, TextSize = 34 })
		UIKit.label(row, { Position = UDim2.fromOffset(62, 6), Size = UDim2.fromOffset(280, 24), Text = def.Name, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne })
		UIKit.label(row, { Position = UDim2.fromOffset(62, 32), Size = UDim2.fromOffset(280, 26), Text = def.Desc, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim })
		local btn = UIKit.button(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(150, 46),
			Text = "",
			TextSize = 16,
			Callback = function()
				if def.Id == 0 then
					HUD.toast("Bientôt disponible !", "info")
					return
				end
				local player = Players.LocalPlayer
				if kind == "pass" then
					MarketplaceService:PromptGamePassPurchase(player, def.Id)
				else
					MarketplaceService:PromptProductPurchase(player, def.Id)
				end
			end,
		})
		robuxRows[key] = { btn = btn, def = def, kind = kind, key = key }
	end
	for _, key in ipairs({ "vip", "nest", "aim" }) do
		robuxRow("pass", key, Config.Monetization.Passes[key])
	end
	for _, key in ipairs({ "coins_s", "coins_l", "eggs" }) do
		robuxRow("product", key, Config.Monetization.Products[key])
	end

	win.refresh = function(s)
		for _, r in pairs(robuxRows) do
			if r.kind == "pass" and s.passes and s.passes[r.key] then
				r.btn.Text = "✔ Possédé"
				r.btn.BackgroundColor3 = C.panel
			elseif r.def.Id == 0 then
				r.btn.Text = "Bientôt"
				r.btn.BackgroundColor3 = C.panel
			else
				r.btn.Text = "R$ " .. r.def.Price
				r.btn.BackgroundColor3 = C.good
			end
		end
		for id, r in pairs(upgradeRows) do
			local lvl = s.upgrades[id] or 0
			r.title.Text = string.format("%s  (niv. %d/%d)", r.def.Name, lvl, r.def.Max)
			if lvl >= r.def.Max then
				r.btn.Text = "MAX"
				r.btn.BackgroundColor3 = C.panel
			else
				local cost = Economy.upgradeCost(r.def, lvl)
				r.btn.Text = "🪙 " .. Util.formatNumber(cost)
				r.btn.BackgroundColor3 = if s.coins >= cost then C.good else C.bad
			end
		end
		for id, r in pairs(foodRows) do
			if s.foods[id] then
				r.btn.Text = "✔ Débloquée"
				r.btn.BackgroundColor3 = C.panel
			else
				r.btn.Text = "🪙 " .. Util.formatNumber(r.food.Price)
				r.btn.BackgroundColor3 = if s.coins >= r.food.Price then C.good else C.bad
			end
		end
	end
	selectTab("upgrades")
end

-- ---------------------------------------------------------------- compagnons

local function buildPets()
	local win = createWindow("pets", "🥚 Nid des compagnons")
	local content = win.content

	local info = UIKit.label(content, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.dim })
	local freeBtn = UIKit.button(content, { Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(172, 46), Text = "", TextSize = 15, Callback = function() act("openEgg", { kind = "classic", source = "free" }) end })
	local classicBtn = UIKit.button(content, { Position = UDim2.fromOffset(180, 26), Size = UDim2.fromOffset(172, 46), Text = "", TextSize = 15, Callback = function() act("openEgg", { kind = "classic", source = "coins" }) end })
	local goldBtn = UIKit.button(content, { Position = UDim2.fromOffset(360, 26), Size = UDim2.fromOffset(172, 46), Text = "", TextSize = 15, BackgroundColor3 = Color3.fromRGB(190, 140, 20), Callback = function() act("openEgg", { kind = "gold", source = "coins" }) end })

	local grid = UIKit.scroll(content, { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -80) })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(170, 112)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local cards = {}
	for i, pet in ipairs(Config.Pets) do
		local card = UIKit.frame(grid, { BackgroundColor3 = C.panel2, LayoutOrder = i })
		UIKit.corner(card, 12)
		local stroke = UIKit.stroke(card, rarityColor(pet.Rarity), 2)
		local nameL = UIKit.label(card, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 22), Text = pet.Name, TextSize = 15, Font = Enum.Font.FredokaOne, TextColor3 = rarityColor(pet.Rarity) })
		local detail = UIKit.label(card, { Position = UDim2.fromOffset(6, 28), Size = UDim2.new(1, -12, 0, 36), Text = "", TextSize = 13, TextColor3 = C.dim })
		local entry = { name = nameL, detail = detail, pet = pet, equipped = false }
		entry.btn = UIKit.button(card, { Position = UDim2.fromOffset(8, 68), Size = UDim2.new(1, -16, 0, 34), Text = "", TextSize = 15, Callback = function()
			act("equipPet", { id = pet.Id, on = not entry.equipped })
		end })
		cards[pet.Id] = entry
	end

	win.refresh = function(s)
		info.Text = string.format("Équipés : %d/%d   ·   Bonus actuel : +%d%% pièces", #s.equipped, s.stats.petSlots, math.floor(s.stats.petMult * 100 + 0.5))
		freeBtn.Text = string.format("🎁 Œuf gratuit\n(x%d)", s.eggs)
		freeBtn.BackgroundColor3 = if s.eggs > 0 then C.good else C.panel
		classicBtn.Text = string.format("%s 🪙 %s", Config.Eggs.classic.Emoji, Util.formatNumber(Config.Eggs.classic.Price))
		classicBtn.BackgroundColor3 = if s.coins >= Config.Eggs.classic.Price then C.blue else C.panel
		goldBtn.Text = string.format("%s 🪙 %s", Config.Eggs.gold.Emoji, Util.formatNumber(Config.Eggs.gold.Price))
		for id, c in pairs(cards) do
			local count = s.pets[id] or 0
			local equipped = table.find(s.equipped, id) ~= nil
			if count > 0 then
				c.detail.Text = string.format("+%d%% pièces  ·  x%d", math.floor(c.pet.Mult * 100 + 0.5), count)
				c.btn.Text = if equipped then "Déséquiper" else "Équiper"
				c.btn.BackgroundColor3 = if equipped then C.bad else C.good
				c.btn.Visible = true
			else
				c.detail.Text = "???  ·  " .. rarityDef(c.pet.Rarity).Name
				c.btn.Visible = false
			end
			c.equipped = equipped
		end
	end
end

-- ---------------------------------------------------------------- quêtes

local function buildQuests()
	local win = createWindow("quests", "📜 Quêtes du jour")
	local content = win.content

	local daily = UIKit.frame(content, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.panel2 })
	UIKit.corner(daily, 12)
	local dailyText = UIKit.label(daily, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -190, 1, -12), Text = "", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
	local dailyBtn = UIKit.button(daily, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 48), Text = "Réclamer", Callback = function() act("claimDaily") end })

	local rows = {}
	for i = 1, Config.QuestsPerDay do
		local row = UIKit.frame(content, { Position = UDim2.fromOffset(0, 80 + (i - 1) * 78), Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.panel2 })
		UIKit.corner(row, 12)
		local text = UIKit.label(row, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -190, 0, 28), Text = "", TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })
		local bg, fill = UIKit.bar(row, { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -190, 0, 20) }, C.blue)
		local progress = UIKit.label(bg, { Size = UDim2.fromScale(1, 1), Text = "", TextSize = 14, ZIndex = 3 })
		local btn = UIKit.button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 48), Text = "", TextSize = 15, Callback = function() act("claimQuest", { index = i }) end })
		rows[i] = { row = row, text = text, fill = fill, progress = progress, btn = btn }
	end

	local story = UIKit.label(content, { Position = UDim2.fromOffset(0, 80 + Config.QuestsPerDay * 78 + 40), Size = UDim2.new(1, 0, 0, 64), Text = "", TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local secrets = UIKit.label(content, { Position = UDim2.fromOffset(0, 80 + Config.QuestsPerDay * 78), Size = UDim2.new(1, 0, 0, 40), Text = "", TextSize = 15, TextColor3 = C.gold })

	win.refresh = function(s)
		if s.canDaily then
			dailyText.Text = string.format("🎁 Récompense de connexion : jour %d/7 prête !\nSérie actuelle : %d jour(s)", s.nextDay, s.streak)
			dailyBtn.Text = "Réclamer"
			dailyBtn.BackgroundColor3 = C.good
		else
			dailyText.Text = string.format("🎁 Récompense du jour déjà réclamée.\nSérie actuelle : %d jour(s) — reviens demain !", s.streak)
			dailyBtn.Text = "✔"
			dailyBtn.BackgroundColor3 = C.panel
		end
		for i, r in ipairs(rows) do
			local q = s.quests[i]
			r.row.Visible = q ~= nil
			if q then
				local def
				for _, d in ipairs(Config.Quests) do
					if d.Kind == q.kind then
						def = d
					end
				end
				r.text.Text = string.format(def.Text, q.target)
				r.fill.Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0, 1), 1)
				r.progress.Text = string.format("%s / %s", Util.formatNumber(q.progress), Util.formatNumber(q.target))
				if q.claimed then
					r.btn.Text = "✔ Réclamée"
					r.btn.BackgroundColor3 = C.panel
				elseif q.progress >= q.target then
					r.btn.Text = string.format("Réclamer\n🪙 %s%s", Util.formatNumber(q.coins * (1 + s.rebirths * Config.RebirthBonus)), if q.eggs > 0 then " +🥚" else "")
					r.btn.BackgroundColor3 = C.good
				else
					r.btn.Text = string.format("🪙 %s%s", Util.formatNumber(q.coins * (1 + s.rebirths * Config.RebirthBonus)), if q.eggs > 0 then " +🥚" else "")
					r.btn.BackgroundColor3 = C.panel
				end
			end
		end
		local stage = ReplicatedStorage:WaitForChild("GameState"):GetAttribute("Stage") or 1
		story.Text = "📖 " .. (Config.Story[stage] or "")
		secrets.Text = string.format("🍴 Fourchettes d'or cachées trouvées : %d/%d — explore la carte !", s.secrets, Config.SecretCount)
	end
end

-- ---------------------------------------------------------------- classement

local function buildLeaderboard()
	local win = createWindow("leaderboard", "🏆 Plus gros nourrisseurs")
	local rows = {}
	for i = 1, 10 do
		local l = UIKit.label(win.content, { Position = UDim2.fromOffset(10, (i - 1) * 33), Size = UDim2.new(1, -20, 0, 30), Text = string.format("%d. —", i), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left })
		rows[i] = l
	end
	local mine = UIKit.label(win.content, { Position = UDim2.fromOffset(10, 335), Size = UDim2.new(1, -20, 0, 24), Text = "", TextSize = 16, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left })
	win.refresh = function(s)
		mine.Text = string.format("Toi : %s nourritures données  ·  niveau %d", Util.formatNumber(s.totalFed), s.level)
	end
	win.onOpen = function()
		task.spawn(function()
			local r = Store.request("leaderboard")
			for i, l in ipairs(rows) do
				local e = r.top and r.top[i]
				l.Text = if e then string.format("%d. %s — %s", i, e.name, Util.formatNumber(e.value)) else string.format("%d. —", i)
			end
		end)
	end
end

-- ---------------------------------------------------------------- évolution

local function buildRebirth()
	local win = createWindow("rebirth", "✨ Autel d'évolution")
	local text = UIKit.label(win.content, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 210), Text = "", TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local btn = UIKit.button(win.content, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(300, 60), Text = "", TextSize = 20, Callback = function()
		local r = act("rebirth")
		if r.ok then
			UIKit.sfx("Success", 0.7)
		end
	end })
	win.refresh = function(s)
		local nextMult = Economy.rebirthMult(s.rebirths + 1)
		text.Text = string.format(
			"Évolutions : %d  (bonus actuel x%.1f)\n\nÉvoluer remet à zéro tes pièces, améliorations et nourritures débloquées, mais multiplie définitivement tes gains : x%.1f !\n\nTu gardes : compagnons, œufs, quêtes, secrets, classement.\nCoût : 🪙 %s",
			s.rebirths, Economy.rebirthMult(s.rebirths), nextMult, Util.formatNumber(s.rebirthCost)
		)
		btn.Text = "✨ ÉVOLUER"
		btn.BackgroundColor3 = if s.coins >= s.rebirthCost then C.good else C.panel
	end
end

-- ---------------------------------------------------------------- éclosion

function Panels.reveal(petId: string, isDup: boolean, refund: number, eggKind: string)
	local pet = Economy.findPet(petId)
	if not pet then
		return
	end
	local overlay = UIKit.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 20 })
	local card = UIKit.frame(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), ZIndex = 21 })
	UIKit.corner(card, 20)
	UIKit.stroke(card, rarityColor(pet.Rarity), 5)
	local r = rarityDef(pet.Rarity)
	UIKit.label(card, { Position = UDim2.fromOffset(10, 16), Size = UDim2.new(1, -20, 0, 40), Text = "🥚 Éclosion !", TextSize = 30, Font = Enum.Font.FredokaOne, ZIndex = 22 })
	local swatch = UIKit.frame(card, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.fromRGB(pet.Color[1], pet.Color[2], pet.Color[3]), ZIndex = 22 })
	UIKit.corner(swatch, 24)
	UIKit.label(swatch, { Size = UDim2.fromScale(1, 1), Text = "🦖", TextSize = 64, ZIndex = 23 })
	UIKit.label(card, { Position = UDim2.fromOffset(10, 184), Size = UDim2.new(1, -20, 0, 34), Text = pet.Name, TextSize = 28, Font = Enum.Font.FredokaOne, TextColor3 = rarityColor(pet.Rarity), ZIndex = 22 })
	local sub = string.format("%s  ·  +%d%% pièces", r.Name, math.floor(pet.Mult * 100 + 0.5))
	if isDup then
		sub ..= string.format("\nDoublon : +%s 🪙", Util.formatNumber(refund))
	end
	UIKit.label(card, { Position = UDim2.fromOffset(10, 220), Size = UDim2.new(1, -20, 0, 60), Text = sub, TextSize = 18, ZIndex = 22 })
	local ok = UIKit.button(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(180, 44), Text = "Super !", BackgroundColor3 = C.good, ZIndex = 22, Callback = function()
		overlay:Destroy()
	end })
	UIKit.sfx("Success", 0.6, if pet.Rarity == "mythique" or pet.Rarity == "legendaire" then 1.2 else 1)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(340, 330) }):Play()
	task.delay(8, function()
		if overlay.Parent then
			overlay:Destroy()
		end
	end)
end

function Panels.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "FestinPanels"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	buildShop()
	buildPets()
	buildQuests()
	buildLeaderboard()
	buildRebirth()

	Store.onChange(function(s)
		if current and windows[current] then
			windows[current].refresh(s)
		end
	end)
end

return Panels
