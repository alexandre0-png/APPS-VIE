-- Menus du salon : Boutique (améliorations, chapeaux, cordes), Bestiaire, Quêtes + cadeau du jour.
-- Le client ne fait que demander : le serveur valide chaque achat / récompense.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Species)
local Util = require(Shared.Util)

local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)

local Menu = {}

local player = Players.LocalPlayer
local refs = {}
local openName = nil
local shopTab = "upgrade"
local lastMessage = ""

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function variantColor(base, variantIdx)
	if variantIdx == 2 then
		return base:Lerp(Color3.fromRGB(110, 210, 255), 0.55)
	elseif variantIdx == 3 then
		return base:Lerp(Color3.fromRGB(255, 205, 60), 0.65)
	end
	return base
end

local function setMessage(text, good)
	lastMessage = text
	if refs.message then
		refs.message.Text = text
		refs.message.TextColor3 = good and UI.Colors.Good or UI.Colors.Bad
	end
end

local function invoke(remote, ...)
	local args = table.pack(...)
	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		if ok and type(result) == "table" then
			setMessage(result.msg or "", result.ok)
			Sfx.play(result.ok and "coin" or "down")
		else
			setMessage("Erreur de communication avec le serveur.", false)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Lignes génériques
-- ---------------------------------------------------------------------------

local function listFrame(parent, position, size)
	local scroll = UI.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = position,
		Size = size,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 31,
	}, parent)
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	return scroll
end

local function row(parent, order, title, desc, buttonText, buttonColor, onClick, swatch)
	local frame = UI.frame(parent, { Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = order, ZIndex = 32 })
	UI.corner(frame, 12)
	local left = 10
	if swatch then
		local dot = UI.frame(frame, { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 10, 0.5, -15), BackgroundColor3 = swatch, ZIndex = 33 })
		UI.corner(dot, 15)
		UI.stroke(dot, UI.Colors.Dark, 2)
		left = 50
	end
	UI.text(frame, { Size = UDim2.new(1, -left - 150, 0, 26), Position = UDim2.new(0, left, 0, 6), Text = title, maxSize = 22, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 33 })
	UI.text(frame, { Size = UDim2.new(1, -left - 150, 0, 22), Position = UDim2.new(0, left, 0, 34), Text = desc, maxSize = 15, Font = UI.FontBody, TextColor3 = UI.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Left, outline = false, ZIndex = 33 })
	local button = UI.button(frame, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 132, 0, 42),
		Text = buttonText,
		BackgroundColor3 = buttonColor,
		maxSize = 18,
		ZIndex = 33,
	})
	if onClick then
		button.Activated:Connect(onClick)
	else
		button.AutoButtonColor = false
	end
	return frame
end

-- ---------------------------------------------------------------------------
-- Boutique
-- ---------------------------------------------------------------------------

local function renderShop(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		UI.text(content, { Size = UDim2.new(1, 0, 0, 40), Text = "Chargement de ton profil...", maxSize = 24, ZIndex = 32 })
		return
	end

	local tabs = {
		{ id = "upgrade", label = "AMÉLIORATIONS" },
		{ id = "hat", label = "CHAPEAUX" },
		{ id = "rope", label = "CORDES" },
	}
	for index, tab in ipairs(tabs) do
		local selected = shopTab == tab.id
		local b = UI.button(content, {
			Position = UDim2.new((index - 1) / 3, 2, 0, 0),
			Size = UDim2.new(1 / 3, -4, 0, 40),
			Text = tab.label,
			BackgroundColor3 = selected and UI.Colors.Accent or UI.Colors.PanelLight,
			TextColor3 = selected and UI.Colors.Dark or UI.Colors.Text,
			maxSize = 20,
			ZIndex = 32,
		})
		b.Activated:Connect(function()
			shopTab = tab.id
			Sfx.play("click")
			renderShop(content)
		end)
	end

	local list = listFrame(content, UDim2.new(0, 0, 0, 48), UDim2.new(1, 0, 1, -48 - 26))
	refs.message = UI.text(content, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -24), Text = lastMessage, maxSize = 18, Font = UI.FontBody, ZIndex = 32 })

	if shopTab == "upgrade" then
		for index, def in ipairs(Config.Upgrades) do
			local level = data.upgrades[def.id] or 0
			local maxed = level >= def.max
			local price = def.costs[level + 1]
			row(
				list,
				index,
				("%s  (niv. %d/%d)"):format(def.name, level, def.max),
				def.desc,
				maxed and "MAX" or (Util.formatNumber(price) .. " pièces"),
				maxed and UI.Colors.Muted or (data.coins >= price and UI.Colors.Good or UI.Colors.Warn),
				(not maxed) and function()
					invoke(Remotes.Buy, "upgrade", def.id)
				end or nil
			)
		end
	else
		local isHat = shopTab == "hat"
		local items = isHat and Config.Hats or Config.Ropes
		local owned = isHat and data.owned.hats or data.owned.ropes
		local equippedId = isHat and data.equipped.hat or data.equipped.rope
		for index, def in ipairs(items) do
			local text, color, handler
			if equippedId == def.id then
				text, color = "ÉQUIPÉ", UI.Colors.Muted
			elseif owned[def.id] then
				text, color = "ÉQUIPER", UI.Colors.Info
				handler = function()
					invoke(Remotes.Equip, isHat and "hat" or "rope", def.id)
				end
			elseif def.pass then
				text, color = "PASS " .. def.pass:upper(), UI.Colors.Muted
			else
				text = Util.formatNumber(def.price) .. " pièces"
				color = data.coins >= def.price and UI.Colors.Good or UI.Colors.Warn
				handler = function()
					invoke(Remotes.Buy, isHat and "hat" or "rope", def.id)
				end
			end
			row(list, index, def.name, isHat and "Un look unique pour ton cavalier." or "Change la couleur de ton lasso.", text, color, handler, (not isHat) and def.color or nil)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Bestiaire
-- ---------------------------------------------------------------------------

local function renderBestiary(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		UI.text(content, { Size = UDim2.new(1, 0, 0, 40), Text = "Chargement de ton profil...", maxSize = 24, ZIndex = 32 })
		return
	end

	local found, total = 0, #Species.List * #Config.Variants
	for _, def in ipairs(Species.List) do
		for v = 1, #Config.Variants do
			if (data.tamed[def.id .. "_" .. v] or 0) > 0 then
				found = found + 1
			end
		end
	end
	UI.text(content, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = ("Découvertes : %d / %d   ·   Dompter les 3 variantes d'une espèce rapporte %d pièces !"):format(found, total, Config.Rewards.SpeciesComplete),
		maxSize = 18,
		Font = UI.FontBody,
		ZIndex = 32,
	})

	local grid = UI.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 31,
	}, content)
	UI.make("UIGridLayout", { CellSize = UDim2.new(0, 178, 0, 168), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)

	for index, def in ipairs(Species.List) do
		local card = UI.frame(grid, { BackgroundColor3 = UI.Colors.PanelLight, LayoutOrder = index, ZIndex = 32 })
		UI.corner(card, 12)
		if data.completed[def.id] then
			UI.stroke(card, UI.Colors.Accent, 3)
		end
		UI.text(card, { Size = UDim2.new(1, -12, 0, 24), Position = UDim2.new(0, 6, 0, 4), Text = def.name, maxSize = 20, ZIndex = 33 })
		UI.text(card, { Size = UDim2.new(1, -12, 0, 44), Position = UDim2.new(0, 6, 0, 28), Text = def.desc, maxSize = 13, Font = UI.FontBody, TextColor3 = UI.Colors.Muted, outline = false, ZIndex = 33 })
		for v, variant in ipairs(Config.Variants) do
			local count = data.tamed[def.id .. "_" .. v] or 0
			local swatch = UI.frame(card, {
				Position = UDim2.new(0, 10 + (v - 1) * 54, 0, 78),
				Size = UDim2.new(0, 46, 0, 46),
				BackgroundColor3 = count > 0 and variantColor(def.palette.body, v) or Color3.fromRGB(40, 44, 58),
				ZIndex = 33,
			})
			UI.corner(swatch, 10)
			UI.stroke(swatch, UI.Colors.Dark, 2)
			UI.text(swatch, { Size = UDim2.new(1, 0, 1, 0), Text = count > 0 and "" or "?", maxSize = 26, TextColor3 = UI.Colors.Muted, ZIndex = 34 })
			UI.text(card, {
				Size = UDim2.new(0, 50, 0, 16),
				Position = UDim2.new(0, 8 + (v - 1) * 54, 0, 128),
				Text = count > 0 and ("x" .. count) or variant.name,
				maxSize = 13,
				Font = UI.FontBody,
				TextColor3 = count > 0 and UI.Colors.Good or UI.Colors.Muted,
				outline = false,
				ZIndex = 33,
			})
		end
		if data.completed[def.id] then
			UI.text(card, { Size = UDim2.new(1, -12, 0, 14), Position = UDim2.new(0, 6, 1, -16), Text = "ESPÈCE COMPLÈTE", maxSize = 12, TextColor3 = UI.Colors.Accent, outline = false, ZIndex = 33 })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Quêtes et cadeau du jour
-- ---------------------------------------------------------------------------

local function renderQuests(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		UI.text(content, { Size = UDim2.new(1, 0, 0, 40), Text = "Chargement de ton profil...", maxSize = 24, ZIndex = 32 })
		return
	end

	local list = listFrame(content, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, -26))
	refs.message = UI.text(content, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -24), Text = lastMessage, maxSize = 18, Font = UI.FontBody, ZIndex = 32 })

	local daily = data.daily
	row(
		list,
		1,
		"Cadeau du jour",
		daily.claimable and ("+%d pièces · série actuelle : %d jour(s)"):format(daily.reward, daily.streak) or "Déjà récupéré. Reviens demain pour prolonger ta série !",
		daily.claimable and "RÉCUPÉRER" or "REVIENS DEMAIN",
		daily.claimable and UI.Colors.Good or UI.Colors.Muted,
		daily.claimable and function()
			invoke(Remotes.ClaimDaily)
		end or nil
	)

	for index, quest in ipairs(data.quests) do
		local done = quest.progress >= quest.target
		local text, color, handler
		if quest.claimed then
			text, color = "FAIT", UI.Colors.Muted
		elseif done then
			text, color = ("+%d pièces"):format(quest.reward), UI.Colors.Good
			handler = function()
				invoke(Remotes.ClaimQuest, index)
			end
		else
			text, color = ("%d/%d"):format(quest.progress, quest.target), UI.Colors.PanelLight
		end
		row(list, 1 + index, quest.label, ("Récompense : %d pièces"):format(quest.reward), text, color, handler)
	end

	local stats = UI.frame(list, { Size = UDim2.new(1, -8, 0, 92), BackgroundColor3 = UI.Colors.Panel, LayoutOrder = 10, ZIndex = 32 })
	UI.corner(stats, 12)
	UI.stroke(stats, UI.Colors.PanelLight, 2)
	local lines = {
		("Meilleur score : %s   ·   Victoires : %d   ·   Manches : %d"):format(Util.formatNumber(data.bestScore), data.wins, data.rounds),
		("Bêtes dressées : %d   ·   Lassos : %d   ·   Distance : %s m"):format(data.tamedTotal, data.hooks, Util.formatNumber(data.distance)),
	}
	if data.persistent == false then
		table.insert(lines, "Sauvegarde indisponible : ta progression ne sera pas enregistrée.")
	end
	UI.text(stats, { Size = UDim2.new(1, -16, 1, -12), Position = UDim2.new(0, 8, 0, 6), Text = table.concat(lines, "\n"), maxSize = 18, Font = UI.FontBody, outline = false, ZIndex = 33 })
end

-- ---------------------------------------------------------------------------
-- Boutique Robux
-- ---------------------------------------------------------------------------

local function renderRobux(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		UI.text(content, { Size = UDim2.new(1, 0, 0, 40), Text = "Chargement de ton profil...", maxSize = 24, ZIndex = 32 })
		return
	end
	local list = listFrame(content, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
	local store = data.store or { passes = {}, products = {} }
	local order = 0

	local function header(text)
		order = order + 1
		UI.text(list, { Size = UDim2.new(1, -8, 0, 30), Text = text, maxSize = 22, TextColor3 = UI.Colors.Accent, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 32 })
	end
	local function priceText(entry)
		if not entry.available then
			return "BIENTÔT"
		end
		return entry.price and ("R$ " .. entry.price) or "ACHETER"
	end

	header("PASS PERMANENTS")
	for _, entry in ipairs(store.passes) do
		order = order + 1
		local owned = data.passes and data.passes[entry.key]
		local handler = nil
		if entry.available and not owned then
			handler = function()
				Sfx.play("click")
				Remotes.Prompt:FireServer("pass", entry.key)
			end
		end
		row(list, order, entry.name, entry.desc, owned and "POSSÉDÉ" or priceText(entry), owned and UI.Colors.Muted or (entry.available and UI.Colors.Good or UI.Colors.PanelLight), handler)
	end

	header("PAQUETS DE PIÈCES")
	for _, entry in ipairs(store.products) do
		order = order + 1
		local handler = nil
		if entry.available then
			handler = function()
				Sfx.play("click")
				Remotes.Prompt:FireServer("product", entry.key)
			end
		end
		row(list, order, entry.name, ("+%s pièces, utilisables dans la boutique"):format(Util.formatNumber(entry.coins)), priceText(entry), entry.available and UI.Colors.Good or UI.Colors.PanelLight, handler)
	end
end

-- ---------------------------------------------------------------------------
-- Panneau et boutons
-- ---------------------------------------------------------------------------

local RENDERERS = {
	shop = { title = "BOUTIQUE", fn = renderShop },
	bestiary = { title = "BESTIAIRE", fn = renderBestiary },
	quests = { title = "QUÊTES & CADEAU", fn = renderQuests },
	robux = { title = "BOUTIQUE ROBUX", fn = renderRobux },
}

local function render()
	if openName and RENDERERS[openName] then
		refs.title.Text = RENDERERS[openName].title
		RENDERERS[openName].fn(refs.content)
	end
end

local function open(name)
	openName = name
	refs.panel.Visible = true
	Sfx.play("click")
	render()
end

local function close()
	openName = nil
	refs.panel.Visible = false
	Sfx.play("click")
end

local function questBadge()
	local data = ClientState.Data
	if not data or not data.loaded then
		return false
	end
	if data.daily.claimable then
		return true
	end
	for _, quest in ipairs(data.quests) do
		if not quest.claimed and quest.progress >= quest.target then
			return true
		end
	end
	return false
end

local function refreshChrome()
	local data = ClientState.Data
	if data and data.loaded then
		refs.coins.Text = "Pièces : " .. Util.formatNumber(data.coins)
	else
		refs.coins.Text = "Chargement..."
	end
	refs.badge.Visible = questBadge()
end

local function refreshVisibility()
	local visible = not ClientState.isPlaying()
	refs.buttons.Visible = visible
	refs.coinsBox.Visible = visible
	if not visible and openName then
		close()
	end
end

function Menu.init()
	local gui = UI.make("ScreenGui", {
		Name = "HerdHopperMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- colonne de boutons
	refs.buttons = UI.frame(gui, {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0, 150, 0, 4 * 52),
		BackgroundTransparency = 1,
	})
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.buttons)
	local defs = {
		{ id = "shop", label = "BOUTIQUE", color = UI.Colors.Accent },
		{ id = "bestiary", label = "BESTIAIRE", color = UI.Colors.Info },
		{ id = "quests", label = "QUÊTES", color = UI.Colors.Good },
		{ id = "robux", label = "ROBUX", color = Color3.fromRGB(255, 120, 90) },
	}
	for index, def in ipairs(defs) do
		local b = UI.button(refs.buttons, { Size = UDim2.new(1, 0, 0, 46), Text = def.label, BackgroundColor3 = def.color, LayoutOrder = index, maxSize = 22 })
		b.Activated:Connect(function()
			if openName == def.id then
				close()
			else
				open(def.id)
			end
		end)
		if def.id == "quests" then
			refs.badge = UI.frame(b, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = UI.Colors.Bad, Visible = false, ZIndex = 5 })
			UI.corner(refs.badge, 8)
			UI.stroke(refs.badge, UI.Colors.Dark, 2)
		end
	end

	-- pièces
	refs.coinsBox = UI.frame(gui, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0, 190, 0, 40),
		BackgroundTransparency = 0.15,
	})
	UI.corner(refs.coinsBox, 12)
	UI.stroke(refs.coinsBox, UI.Colors.Dark, 2)
	refs.coins = UI.text(refs.coinsBox, { Size = UDim2.new(1, -12, 1, -8), Position = UDim2.new(0, 6, 0, 4), Text = "Chargement...", maxSize = 22, TextColor3 = UI.Colors.Accent })

	-- panneau modal
	refs.panel = UI.frame(gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.8, 0, 0.84, 0),
		Visible = false,
		ZIndex = 30,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(780, 520), MinSize = Vector2.new(320, 240) }, refs.panel)
	UI.corner(refs.panel, 18)
	UI.stroke(refs.panel, UI.Colors.Accent, 3)
	refs.title = UI.text(refs.panel, { Size = UDim2.new(1, -120, 0, 44), Position = UDim2.new(0, 16, 0, 8), Text = "", maxSize = 32, TextColor3 = UI.Colors.Accent, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31 })
	local closeButton = UI.button(refs.panel, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.new(0, 84, 0, 38),
		Text = "FERMER",
		BackgroundColor3 = UI.Colors.Bad,
		TextColor3 = UI.Colors.Text,
		maxSize = 18,
		ZIndex = 31,
	})
	closeButton.Activated:Connect(close)
	refs.content = UI.frame(refs.panel, {
		Position = UDim2.new(0, 14, 0, 58),
		Size = UDim2.new(1, -28, 1, -70),
		BackgroundTransparency = 1,
		ZIndex = 31,
	})

	ClientState.connect("Data", function()
		refreshChrome()
		if openName then
			render()
		end
	end)
	ClientState.connect("Status", refreshVisibility)
	refreshChrome()
	refreshVisibility()
end

return Menu
