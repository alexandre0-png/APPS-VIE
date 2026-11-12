--!nonstrict
-- Fenêtre de menus : Boutique, Équipement, Quêtes, Cadeau quotidien, Statistiques.
-- Toute action passe par State.Request ; le serveur valide et renvoie le résultat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local QuestLogic = require(Shared.QuestLogic)
local Lore = require(Shared.Lore)
local SeasonLogic = require(Shared.SeasonLogic)
local UI = require(Client.UI)
local State = require(Client.State)

local Menus = {}

local C = UI.Colors
local player = Players.LocalPlayer
local root, content, tabButtons
local currentTab = nil
local selectedSlot = 1
local popScale = Instance.new("UIScale")
local toast = function(_text, _color) end

local TABS = {
	{ Id = "Shop", Text = "🛒 Boutique" },
	{ Id = "Loadout", Text = "🎒 Équipement" },
	{ Id = "Quests", Text = "📜 Quêtes" },
	{ Id = "Daily", Text = "🎁 Cadeau" },
	{ Id = "Stats", Text = "📊 Stats" },
	{ Id = "Hero", Text = "📖 Héros" },
	{ Id = "Season", Text = "🏆 Saison" },
	{ Id = "Robux", Text = "💎 Robux" },
}

local function hex(h)
	return Color3.fromHex(h)
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
end

local function act(action, a, b)
	local ok, msg = State.Request(action, a, b)
	toast(msg ~= "" and msg or (ok and "OK" or "Échec"), ok and C.Good or C.Bad)
	return ok
end

local function statLine(def)
	local parts = { ("Dégâts %d"):format(def.Damage) }
	if def.Pellets then
		parts[1] = ("Dégâts %d×%d"):format(def.Damage, def.Pellets)
	end
	table.insert(parts, ("Cadence %.2fs"):format(def.Cooldown))
	table.insert(parts, (def.Class == "Melee" and "Corps à corps" or "Distance"))
	return table.concat(parts, "  ·  ")
end

-- ===================================================================
-- Boutique
-- ===================================================================
local function weaponCard(parent, def, profile, mode)
	local owned = profile.Owned[def.Id] == true
	local equippedIndex
	for i, id in ipairs(profile.Loadout) do
		if id == def.Id then
			equippedIndex = i
		end
	end
	local rarityColor = hex(Config.Rarities[def.Rarity] or "FFFFFF")
	local card = UI.Frame(parent, { Size = UDim2.fromOffset(222, 168), BackgroundColor3 = C.Panel, Stroke = rarityColor })
	UI.Frame(card, { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarityColor, Radius = false })
	UI.Label(card, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 20), Text = def.Name, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(card, { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 14), Text = def.Rarity, TextSize = 12, TextColor3 = rarityColor, TextXAlignment = Enum.TextXAlignment.Left })
	UI.Label(card, { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 42), Text = def.Description, TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true })
	UI.Label(card, { Position = UDim2.fromOffset(10, 90), Size = UDim2.new(1, -20, 0, 14), Text = statLine(def), TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Left })

	local btn = UI.Button(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 36), TextSize = 15 })
	if mode == "Shop" then
		if owned then
			btn.Text = equippedIndex and "✔ Équipée" or "Possédée"
			btn.BackgroundColor3 = C.PanelLight
			btn.AutoButtonColor = false
		elseif profile.Level < def.LevelReq then
			btn.Text = ("🔒 Niveau %d"):format(def.LevelReq)
			btn.BackgroundColor3 = C.PanelLight
			btn.AutoButtonColor = false
		else
			btn.Text = ("Acheter  🪙 %s"):format(UI.FormatNumber(def.Price))
			btn.BackgroundColor3 = profile.Coins >= def.Price and C.Good or C.Bad
			btn.Activated:Connect(function()
				act("Buy", def.Id)
			end)
		end
	else
		if equippedIndex then
			btn.Text = "Retirer"
			btn.BackgroundColor3 = C.Bad
			btn.Activated:Connect(function()
				act("Unequip", def.Id)
			end)
		else
			btn.Text = ("Équiper (slot %d)"):format(selectedSlot)
			btn.BackgroundColor3 = C.Accent
			btn.Activated:Connect(function()
				act("Equip", def.Id, selectedSlot)
			end)
		end
	end
	return card
end

local function grid(parent)
	local scroll = UI.New("ScrollingFrame", {
		Parent = parent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	})
	UI.New("UIGridLayout", { Parent = scroll, CellSize = UDim2.fromOffset(222, 168), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	UI.New("UIPadding", { Parent = scroll, PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) })
	return scroll
end

local function buildShop(profile)
	local scroll = grid(content)
	for i, def in ipairs(Weapons.List) do
		local card = weaponCard(scroll, def, profile, "Shop")
		card.LayoutOrder = i
	end
end

-- ===================================================================
-- Équipement
-- ===================================================================
local function buildLoadout(profile)
	local header = UI.New("Frame", { Parent = content, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 78) })
	for i = 1, Config.Loadout.Slots do
		local id = profile.Loadout[i]
		local def = id and Weapons.Get(id)
		local slot = UI.Button(header, {
			Position = UDim2.fromOffset((i - 1) * 236, 0),
			Size = UDim2.fromOffset(226, 70),
			BackgroundColor3 = C.Panel,
			Text = "",
			AutoButtonColor = false,
		})
		UI.Stroke(slot, i == selectedSlot and C.Gold or C.PanelLight, 3, 0)
		UI.Label(slot, { Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(100, 16), Text = "SLOT " .. i, TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(slot, { Position = UDim2.fromOffset(8, 22), Size = UDim2.new(1, -16, 0, 26), Text = def and def.Name or "— vide —", TextSize = 18, TextColor3 = def and hex(Config.Rarities[def.Rarity]) or C.Dim, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(slot, { Position = UDim2.fromOffset(8, 48), Size = UDim2.new(1, -16, 0, 16), Text = def and statLine(def) or "Choisissez une arme ci-dessous", TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left })
		slot.Activated:Connect(function()
			selectedSlot = i
			Menus.Refresh()
		end)
	end
	local body = UI.New("Frame", { Parent = content, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84) })
	local scroll = grid(body)
	local n = 0
	for _, def in ipairs(Weapons.List) do
		if profile.Owned[def.Id] then
			n += 1
			weaponCard(scroll, def, profile, "Loadout").LayoutOrder = n
		end
	end
end

-- ===================================================================
-- Quêtes
-- ===================================================================
local function buildQuests(profile)
	UI.Label(content, { Size = UDim2.new(1, 0, 0, 24), Text = "Les quêtes se renouvellent chaque jour (minuit UTC).", TextSize = 14, Font = Enum.Font.Gotham, TextColor3 = C.Dim })
	for i, q in ipairs(profile.Quests) do
		local def = QuestLogic.Get(q.Id)
		if def then
			local done = q.Progress >= def.Target
			local row = UI.Frame(content, { Position = UDim2.fromOffset(0, 32 + (i - 1) * 96), Size = UDim2.new(1, 0, 0, 88), BackgroundColor3 = C.Panel, Stroke = done and C.Good or C.PanelLight })
			UI.Label(row, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 22), Text = def.Title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left })
			UI.Label(row, { Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -200, 0, 18), Text = def.Desc, TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left })
			local bg = UI.Frame(row, { Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -200, 0, 16), BackgroundColor3 = Color3.fromRGB(16, 18, 26), Radius = 8 })
			UI.Frame(bg, { Size = UDim2.fromScale(math.clamp(q.Progress / def.Target, 0, 1), 1), BackgroundColor3 = done and C.Good or C.Accent, Radius = 8 })
			UI.Label(bg, { Size = UDim2.fromScale(1, 1), Text = ("%s / %s"):format(UI.FormatNumber(q.Progress), UI.FormatNumber(def.Target)), TextSize = 11, ZIndex = 3 })
			UI.Label(row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.fromOffset(160, 20), Text = ("+%d 🪙  +%d XP"):format(def.Coins, def.XP), TextSize = 14, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right })
			local btn = UI.Button(row, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -10), Size = UDim2.fromOffset(150, 34), TextSize = 15 })
			if q.Claimed then
				btn.Text = "✔ Récupérée"
				btn.BackgroundColor3 = C.PanelLight
				btn.AutoButtonColor = false
			elseif done then
				btn.Text = "Récupérer"
				btn.BackgroundColor3 = C.Good
				btn.Activated:Connect(function()
					act("ClaimQuest", q.Id)
				end)
			else
				btn.Text = "En cours…"
				btn.BackgroundColor3 = C.PanelLight
				btn.AutoButtonColor = false
			end
		end
	end
end

-- ===================================================================
-- Cadeau quotidien
-- ===================================================================
local function buildDaily(profile)
	UI.Label(content, { Size = UDim2.new(1, 0, 0, 26), Text = "Connectez-vous chaque jour : la série augmente la récompense !", TextSize = 15, Font = Enum.Font.Gotham, TextColor3 = C.Dim })
	local row = UI.New("Frame", { Parent = content, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 150) })
	local width = 96
	for i, coins in ipairs(Config.DailyRewards) do
		local isNext = i == profile.DailyNext
		local tile = UI.Frame(row, {
			Position = UDim2.fromOffset((i - 1) * (width + 6), 0),
			Size = UDim2.fromOffset(width, 140),
			BackgroundColor3 = isNext and C.Gold or C.Panel,
			Stroke = isNext and C.Gold or C.PanelLight,
		})
		UI.Label(tile, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 20), Text = "JOUR " .. i, TextSize = 14, TextColor3 = isNext and Color3.new(0, 0, 0) or C.Dim })
		UI.Label(tile, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 40), Text = i == 7 and "🎁" or "🪙", TextSize = 34 })
		UI.Label(tile, { Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 24), Text = tostring(coins), TextSize = 22, Font = Enum.Font.GothamBlack, TextColor3 = isNext and Color3.new(0, 0, 0) or C.Gold })
	end
	local btn = UI.Button(content, { Position = UDim2.new(0.5, -130, 0, 210), Size = UDim2.fromOffset(260, 46), TextSize = 18 })
	if profile.DailyAvailable then
		btn.Text = "Récupérer mon cadeau"
		btn.BackgroundColor3 = C.Good
		btn.Activated:Connect(function()
			act("ClaimDaily")
		end)
	else
		btn.Text = "Déjà récupéré — à demain !"
		btn.BackgroundColor3 = C.PanelLight
		btn.AutoButtonColor = false
	end
end

-- ===================================================================
-- Statistiques
-- ===================================================================
local function buildStats(profile)
	local kd = profile.Deaths > 0 and profile.Kills / profile.Deaths or profile.Kills
	local lines = {
		{ "Niveau", tostring(profile.Level) },
		{ "Titre", tostring(player:GetAttribute("Title") or "") },
		{ "Expérience", ("%d / %d"):format(profile.XP, profile.XPNeeded) },
		{ "Pièces", UI.FormatNumber(profile.Coins) },
		{ "Éliminations", UI.FormatNumber(profile.Kills) },
		{ "Morts", UI.FormatNumber(profile.Deaths) },
		{ "Ratio K/D", ("%.2f"):format(kd) },
		{ "Victoires", UI.FormatNumber(profile.Wins) },
		{ "Parties jouées", UI.FormatNumber(profile.MatchesPlayed) },
		{ "Meilleure série", tostring(profile.BestStreak) },
		{ "Tirs à la tête", UI.FormatNumber(profile.Headshots) },
		{ "Dégâts infligés", UI.FormatNumber(profile.DamageDealt) },
	}
	for i, line in ipairs(lines) do
		local col = (i - 1) % 2
		local rowIndex = (i - 1) // 2
		local cell = UI.Frame(content, { Position = UDim2.new(col * 0.5, col * 4, 0, rowIndex * 54), Size = UDim2.new(0.5, -4, 0, 48), BackgroundColor3 = C.Panel })
		UI.Label(cell, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = line[1], TextSize = 15, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(cell, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = line[2], TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right })
	end
	if profile.Ephemeral then
		UI.Label(content, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 24), Text = "⚠ Sauvegarde indisponible sur ce serveur", TextSize = 14, TextColor3 = C.Bad })
	end
end

-- ===================================================================
-- Robux : passes et packs (les Id à 0 sont affichés « Bientôt »)
-- ===================================================================
local function buildRobux(profile)
	local M = Config.Monetization
	local scroll = UI.New("ScrollingFrame", { Parent = content, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6 })
	UI.New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local function row(order, title, desc, price, state, onClick)
		local r = UI.Frame(scroll, { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = C.Panel, LayoutOrder = order })
		UI.Label(r, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -200, 0, 22), Text = title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(r, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -200, 0, 22), Text = desc, TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true })
		local b = UI.Button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 36), TextSize = 15 })
		if state == "owned" then
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "✔ Possédé", C.PanelLight, false
		elseif state == "soon" then
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "Bientôt", C.PanelLight, false
		else
			b.Text, b.BackgroundColor3 = ("R$ %d"):format(price), C.Good
			b.Activated:Connect(onClick)
		end
	end
	local order = 0
	for _, pass in ipairs(M.Passes) do
		order += 1
		local state = profile.Passes[pass.Key] and "owned" or (pass.Id <= 0 and "soon" or "buy")
		row(order, pass.Name, pass.Desc, pass.Price, state, function()
			local ok, msg = State.Request("BuyPass", pass.Key)
			if not ok then toast(msg, C.Bad) end
		end)
	end
	for _, product in ipairs(M.Products) do
		order += 1
		row(order, product.Name, "Pièces à dépenser dans la boutique d'armes.", product.Price, product.Id <= 0 and "soon" or "buy", function()
			local ok, msg = State.Request("BuyProduct", product.Key)
			if not ok then toast(msg, C.Bad) end
		end)
	end
end

-- ===================================================================
-- Héros et Chronique
-- ===================================================================
local function buildHero(profile)
	local scroll = UI.New("ScrollingFrame", { Parent = content, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6 })
	UI.New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	UI.Label(scroll, { Size = UDim2.new(1, -10, 0, 22), Text = Lore.Intro.Title, TextSize = 18, TextColor3 = C.Gold, LayoutOrder = 1 })
	UI.Label(scroll, { Size = UDim2.new(1, -10, 0, 34), Text = Lore.Intro.Text, TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextWrapped = true, LayoutOrder = 2 })
	local heroRow = UI.New("Frame", { Parent = scroll, BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 128), LayoutOrder = 3 })
	UI.New("UIListLayout", { Parent = heroRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) })
	for _, hero in ipairs(Lore.Heroes) do
		local unlocked = Lore.IsHeroUnlocked(hero.Key, profile.Chapters)
		local selected = profile.Hero == hero.Key
		local color = Color3.fromHex(hero.Color)
		local card = UI.Frame(heroRow, { Size = UDim2.fromOffset(168, 124), BackgroundColor3 = C.Panel, Stroke = selected and C.Gold or color })
		UI.Frame(card, { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = color, Radius = false })
		UI.Label(card, { Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 20), Text = hero.Name .. " " .. hero.Epithet, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(card, { Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 0, 44), Text = hero.Story, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		local b = UI.Button(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 28), TextSize = 13 })
		if selected then
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "✔ Héros actuel", C.PanelLight, false
		elseif not unlocked then
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "🔒 Via la Chronique", C.PanelLight, false
		else
			b.Text, b.BackgroundColor3 = "Choisir", color
			b.TextColor3 = Color3.new(0, 0, 0)
			b.Activated:Connect(function()
				act("SetHero", hero.Key)
			end)
		end
	end
	UI.Label(scroll, { Size = UDim2.new(1, -10, 0, 22), Text = "CHRONIQUE", TextSize = 16, TextColor3 = C.Gold, LayoutOrder = 4 })
	local stats = { Level = profile.Level, Kills = profile.Kills, Wins = profile.Wins, BestStreak = profile.BestStreak, Headshots = profile.Headshots }
	for i, chapter in ipairs(Lore.Chapters) do
		local progress = Lore.Progress(chapter, stats)
		local done = progress >= chapter.Target
		local claimed = profile.Chapters[chapter.Id] == true
		local row = UI.Frame(scroll, { Size = UDim2.new(1, -10, 0, 74), BackgroundColor3 = C.Panel, LayoutOrder = 4 + i, Stroke = claimed and C.Good or (done and C.Gold or C.PanelLight) })
		UI.Label(row, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -190, 0, 20), Text = ("Chapitre %d · %s"):format(i, chapter.Title), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left })
		UI.Label(row, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -190, 0, 30), Text = chapter.Text, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		local bg = UI.Frame(row, { Position = UDim2.new(0, 12, 1, -14), Size = UDim2.new(1, -190, 0, 8), BackgroundColor3 = Color3.fromRGB(16, 18, 26), Radius = 4 })
		UI.Frame(bg, { Size = UDim2.fromScale(progress / chapter.Target, 1), BackgroundColor3 = done and C.Good or C.Accent, Radius = 4 })
		local b = UI.Button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(160, 34), TextSize = 13 })
		if claimed then
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "✔ Lu", C.PanelLight, false
		elseif done then
			b.Text, b.BackgroundColor3 = ("Lire  +%d 🪙"):format(chapter.Coins), C.Good
			b.Activated:Connect(function()
				act("ClaimChapter", chapter.Id)
			end)
		else
			b.Text, b.BackgroundColor3, b.AutoButtonColor = ("%d / %d"):format(progress, chapter.Target), C.PanelLight, false
		end
	end
end

local function buildSeason(profile)
	local S = Config.Season
	local points = profile.Season.Points
	local tier = SeasonLogic.Tier(points, S.TierPoints, S.Tiers)
	local scroll = UI.New("ScrollingFrame", { Parent = content, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6 })
	UI.New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	UI.Label(scroll, { Size = UDim2.new(1, -10, 0, 26), Text = ("%s · %d points · palier %d / %d"):format(S.Name, points, tier, S.Tiers), TextSize = 16, TextColor3 = C.Gold, LayoutOrder = 0 })
	UI.Label(scroll, { Size = UDim2.new(1, -10, 0, 18), Text = ("Éliminations +%d · Assistances +%d · Partie +%d · Victoire +%d"):format(S.Points.Kill, S.Points.Assist, S.Points.Match, S.Points.Win), TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = C.Dim, LayoutOrder = 1 })
	for i = 1, S.Tiers do
		local reached = tier >= i
		local claimed = profile.Season.Claimed[tostring(i)] == true
		local row = UI.Frame(scroll, { Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = C.Panel, LayoutOrder = 1 + i, Stroke = claimed and C.Good or (reached and C.Gold or C.PanelLight) })
		local reward = ("+%d 🪙"):format(SeasonLogic.TierCoins(i, S.CoinsPerTier)) .. (i == S.Tiers and ("  ·  titre 🏆 " .. S.ChampionTitle) or "")
		UI.Label(row, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -190, 1, 0), Text = ("Palier %d  ·  %d pts  ·  %s"):format(i, i * S.TierPoints, reward), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
		local b = UI.Button(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(150, 28), TextSize = 13 })
		if claimed then
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "✔ Récupéré", C.PanelLight, false
		elseif reached then
			b.Text, b.BackgroundColor3 = "Récupérer", C.Good
			b.Activated:Connect(function()
				act("ClaimTier", i)
			end)
		else
			b.Text, b.BackgroundColor3, b.AutoButtonColor = "🔒", C.PanelLight, false
		end
	end
end

local builders = {
	Season = buildSeason,
	Hero = buildHero,
	Robux = buildRobux,
	Shop = buildShop,
	Loadout = buildLoadout,
	Quests = buildQuests,
	Daily = buildDaily,
	Stats = buildStats,
}

-- ===================================================================
-- Fenêtre
-- ===================================================================
function Menus.Refresh()
	if not root.Visible or not currentTab then
		return
	end
	local profile = State.Profile
	clearContent()
	for id, b in pairs(tabButtons) do
		b.BackgroundColor3 = id == currentTab and C.Accent or C.PanelLight
	end
	if profile then
		builders[currentTab](profile)
	else
		UI.Label(content, { Size = UDim2.fromScale(1, 1), Text = "Chargement du profil…", TextSize = 20, TextColor3 = C.Dim })
	end
end

function Menus.Open(tab)
	currentTab = builders[tab] and tab or "Shop"
	if not root.Visible then
		popScale.Scale = 0.92
		UI.Tween(popScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	root.Visible = true
	Menus.Refresh()
end

function Menus.Close()
	root.Visible = false
end

function Menus.Toggle(tab)
	if root.Visible and currentTab == tab then
		Menus.Close()
	else
		Menus.Open(tab)
	end
end

function Menus.SetToast(fn)
	toast = fn
end

function Menus.Init(gui)
	root = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 450),
		BackgroundColor3 = C.Bg,
		Visible = false,
		ZIndex = 10,
		Stroke = C.PanelLight,
	})
	UI.New("UISizeConstraint", { Parent = root, MaxSize = Vector2.new(900, 520) })
	popScale.Parent = root
	UI.New("UIGradient", { Parent = root, Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 210, 225)) })

	local bar = UI.New("ScrollingFrame", { Parent = root, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -70, 0, 38), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 0 })
	UI.New("UIListLayout", { Parent = bar, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) })
	tabButtons = {}
	for _, tab in ipairs(TABS) do
		local b = UI.Button(bar, { Size = UDim2.fromOffset(112, 36), BackgroundColor3 = C.PanelLight, Text = tab.Text, TextSize = 13 })
		tabButtons[tab.Id] = b
		b.Activated:Connect(function()
			currentTab = tab.Id
			Menus.Refresh()
		end)
	end
	local close = UI.Button(root, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(40, 36), BackgroundColor3 = C.Bad, Text = "✕", TextSize = 18 })
	close.Activated:Connect(Menus.Close)

	local coinLabel = UI.Label(root, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -8), Size = UDim2.fromOffset(240, 20), Text = "", TextSize = 15, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right })
	local function refreshCoins()
		coinLabel.Text = ("🪙 %s   ·   Niveau %d"):format(UI.FormatNumber(player:GetAttribute("Coins") or 0), player:GetAttribute("Level") or 1)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	player:GetAttributeChangedSignal("Level"):Connect(refreshCoins)
	refreshCoins()

	content = UI.New("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 1, -92), ClipsDescendants = true })

	State.OnChange(function()
		Menus.Refresh()
	end)
end

return Menus
