-- Menus du parc : Expédition (zone + départ), Zoo (caisse, animaux, améliorations), Boutique (équipement,
-- chapeaux, cordes), Quêtes & histoire, Boutique Robux. Le client ne fait que demander : le serveur valide tout.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Species = require(Shared.Species)
local Util = require(Shared.Util)
local Zoo = require(Shared.Zoo)

local ClientState = require(script.Parent.ClientState)
local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)

local Menu = {}

local player = Players.LocalPlayer
local refs = {}
local openName = nil
local shopTab = "upgrade"
local lastMessage = ""
local readyState = false
local PINK = Color3.fromRGB(255, 96, 160)

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
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

local function loading(content)
	UI.text(content, { Size = UDim2.new(1, 0, 0, 40), Text = "Chargement de ton profil...", maxSize = 24, ZIndex = 32 })
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

local function row(parent, order, title, desc, buttonText, buttonColor, onClick, swatch, height)
	local frame = UI.frame(parent, {
		Size = UDim2.new(1, -8, 0, height or 62),
		BackgroundColor3 = UI.Colors.PanelLight,
		LayoutOrder = order,
		ZIndex = 32,
	})
	UI.corner(frame, 12)
	local left = 10
	if swatch then
		local dot = UI.frame(frame, {
			Size = UDim2.new(0, 30, 0, 30),
			Position = UDim2.new(0, 10, 0.5, -15),
			BackgroundColor3 = swatch,
			ZIndex = 33,
		})
		UI.corner(dot, 15)
		UI.stroke(dot, UI.Colors.Dark, 2)
		left = 50
	end
	UI.text(frame, {
		Size = UDim2.new(1, -left - 150, 0, 26),
		Position = UDim2.new(0, left, 0, 6),
		Text = title,
		maxSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
	})
	UI.text(frame, {
		Size = UDim2.new(1, -left - 150, 0, (height or 62) - 38),
		Position = UDim2.new(0, left, 0, 32),
		Text = desc,
		maxSize = 15,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		outline = false,
		ZIndex = 33,
	})
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
	end
	return frame, button
end

local function animalLabel(key)
	local def, variant = Zoo.parseKey(key)
	if not def then
		return key
	end
	if def.boss then
		return def.name
	end
	return variant == 1 and def.name or (def.name .. " " .. Config.Variants[variant].name)
end

-- ---------------------------------------------------------------------------
-- Expédition
-- ---------------------------------------------------------------------------

local function renderExpedition(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		loading(content)
		return
	end

	local lives = Config.Run.BaseLives + ((data.passes.life and Config.Monetization.LifePassBonus) or 0) + data.revives
	local lasso = Config.Run.BaseLasso
		+ data.zooUp.lasso
		+ ((data.passes.lasso and Config.Monetization.LassoPassBonus) or 0)
	UI.text(content, {
		Size = UDim2.new(1, 0, 0, 40),
		Text = ("Tu pars avec %d vie(s) et %d lasso(s) de capture. Le sol est mortel : saute d'animal en animal !"):format(
			lives,
			lasso
		),
		maxSize = 17,
		Font = UI.FontBody,
		ZIndex = 32,
	})

	local list = listFrame(content, UDim2.new(0, 0, 0, 44), UDim2.new(1, 0, 1, -44 - 70))
	for index, zone in ipairs(Config.Zones) do
		local unlocked = data.zones[zone.key]
		local selected = data.zone == zone.key
		local boss = Species.ById[zone.boss]
		local desc = ("Danger : %s · boss : %s"):format(zone.hazard.name, boss and boss.name or "?")
		if not unlocked then
			desc = ("Verrouillée : %d animaux différents requis (tu en as %d)."):format(zone.unlock, data.zoo.owned)
		end
		local text, color, handler
		if not unlocked then
			text, color = "VERROUILLÉE", UI.Colors.Muted
		elseif selected then
			text, color = "CHOISIE", UI.Colors.Good
		else
			text, color = "CHOISIR", UI.Colors.Info
			handler = function()
				invoke(Remotes.ZooAction, "zone", zone.key)
			end
		end
		row(list, index, ("ZONE %d · %s"):format(index, zone.name), desc, text, color, handler, zone.hazard.color)
	end

	local readyCount = workspace:GetAttribute("ReadyCount") or 0
	local go = UI.button(content, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(0.8, 0, 0, 56),
		Text = readyState and ("ANNULER · %d prêt(s)"):format(readyCount) or "PARTIR EN EXPÉDITION",
		BackgroundColor3 = readyState and UI.Colors.Warn or UI.Colors.Good,
		maxSize = 26,
		ZIndex = 33,
	})
	go.Activated:Connect(function()
		readyState = not readyState
		Remotes.Ready:FireServer(data.zone, readyState)
		Sfx.play(readyState and "go" or "click")
		if openName == "expedition" then
			renderExpedition(content)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Zoo
-- ---------------------------------------------------------------------------

local function pendingEstimate(data)
	local zoo = data.zoo
	local elapsed = math.max(0, os.time() - zoo.serverTime)
	local estimate = zoo.pending + zoo.rate / 60 * elapsed
	local cap = math.max(zoo.pending, zoo.rate * zoo.capMinutes)
	return math.floor(math.min(estimate, cap))
end

local function renderZoo(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		loading(content)
		return
	end
	local zoo = data.zoo

	local cash =
		UI.frame(content, { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = UI.Colors.PanelLight, ZIndex = 32 })
	UI.corner(cash, 12)
	refs.cashLabel = UI.text(cash, {
		Size = UDim2.new(1, -170, 0, 30),
		Position = UDim2.new(0, 12, 0, 6),
		Text = "",
		maxSize = 26,
		TextColor3 = UI.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
	})
	refs.cashLabel.Text = ("Caisse : %s or"):format(Util.formatNumber(pendingEstimate(data)))
	local boost = zoo.boostLeft > 0 and (" · BOOST x2 (%d min)"):format(math.ceil(zoo.boostLeft / 60)) or ""
	UI.text(cash, {
		Size = UDim2.new(1, -170, 0, 26),
		Position = UDim2.new(0, 12, 0, 38),
		Text = ("%d animaux · %d enclos · %s or/min%s"):format(
			zoo.owned,
			zoo.slots,
			Util.formatNumber(zoo.rate),
			boost
		),
		maxSize = 15,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		outline = false,
		ZIndex = 33,
	})
	local collect = UI.button(cash, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 140, 0, 46),
		Text = "COLLECTER",
		BackgroundColor3 = UI.Colors.Good,
		maxSize = 20,
		ZIndex = 33,
	})
	collect.Activated:Connect(function()
		invoke(Remotes.ZooAction, "collect")
	end)

	local list = listFrame(content, UDim2.new(0, 0, 0, 78), UDim2.new(1, 0, 1, -78 - 26))
	refs.message = UI.text(content, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -24),
		Text = lastMessage,
		maxSize = 18,
		Font = UI.FontBody,
		ZIndex = 32,
	})
	local order = 0
	local function header(text)
		order = order + 1
		UI.text(list, {
			Size = UDim2.new(1, -8, 0, 28),
			Text = text,
			maxSize = 20,
			TextColor3 = UI.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			ZIndex = 32,
		})
	end

	header("AMÉLIORATIONS DU ZOO (or)")
	for _, def in ipairs(Config.ZooUpgrades) do
		order = order + 1
		local level = data.zooUp[def.id] or 0
		local maxed = level >= def.max
		local price = def.costs[level + 1]
		row(
			list,
			order,
			("%s (niv. %d/%d)"):format(def.name, level, def.max),
			def.desc,
			maxed and "MAX" or (Util.formatNumber(price) .. " or"),
			maxed and UI.Colors.Muted or (data.coins >= price and UI.Colors.Good or UI.Colors.Warn),
			(not maxed) and function()
				invoke(Remotes.ZooAction, "zoo", def.id)
			end or nil
		)
	end

	header("TES ANIMAUX (os : " .. data.bones .. ")")
	local owned = {}
	for key, entry in pairs(data.animals) do
		table.insert(owned, { key = key, entry = entry })
	end
	table.sort(owned, function(a, b)
		if a.entry.income ~= b.entry.income then
			return a.entry.income > b.entry.income
		end
		return a.key < b.key
	end)
	if #owned == 0 then
		order = order + 1
		UI.text(list, {
			Size = UDim2.new(1, -8, 0, 40),
			Text = "Ton zoo est vide. Pars en expédition et récupère un animal à cœur rose !",
			maxSize = 16,
			Font = UI.FontBody,
			LayoutOrder = order,
			ZIndex = 32,
		})
	end
	for _, item in ipairs(owned) do
		order = order + 1
		local e = item.entry
		local maxed = e.cost == nil
		row(
			list,
			order,
			("%s · niv. %d"):format(animalLabel(item.key), e.level),
			("Rapporte %s or/min · %d exemplaire(s)"):format(Util.formatNumber(e.income), e.copies),
			maxed and "MAX" or (e.cost .. " os"),
			maxed and UI.Colors.Muted or (data.bones >= e.cost and UI.Colors.Good or UI.Colors.Warn),
			(not maxed) and function()
				invoke(Remotes.ZooAction, "animal", item.key)
			end or nil
		)
	end
end

-- ---------------------------------------------------------------------------
-- Boutique (équipement, chapeaux, cordes)
-- ---------------------------------------------------------------------------

local function renderShop(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		loading(content)
		return
	end

	local tabs = {
		{ id = "upgrade", label = "ÉQUIPEMENT" },
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
	refs.message = UI.text(content, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -24),
		Text = lastMessage,
		maxSize = 18,
		Font = UI.FontBody,
		ZIndex = 32,
	})

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
				maxed and "MAX" or (Util.formatNumber(price) .. " or"),
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
				text, color = "ZOO PREMIUM", UI.Colors.Muted
			else
				text = Util.formatNumber(def.price) .. " or"
				color = data.coins >= def.price and UI.Colors.Good or UI.Colors.Warn
				handler = function()
					invoke(Remotes.Buy, isHat and "hat" or "rope", def.id)
				end
			end
			row(
				list,
				index,
				def.name,
				isHat and "Un look unique pour ton gardien de zoo." or "Change la couleur de ton lasso.",
				text,
				color,
				handler,
				(not isHat) and def.color or nil
			)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Quêtes et histoire
-- ---------------------------------------------------------------------------

local function renderQuests(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		loading(content)
		return
	end

	local list = listFrame(content, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, -26))
	refs.message = UI.text(content, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 1, -24),
		Text = lastMessage,
		maxSize = 18,
		Font = UI.FontBody,
		ZIndex = 32,
	})

	local order = 0
	local story = data.story
	if story then
		order = order + 1
		local card = UI.frame(list, {
			Size = UDim2.new(1, -8, 0, 122),
			BackgroundColor3 = UI.Colors.PanelLight,
			LayoutOrder = order,
			ZIndex = 32,
		})
		UI.corner(card, 12)
		UI.stroke(card, PINK, 2)
		UI.text(card, {
			Size = UDim2.new(1, -170, 0, 26),
			Position = UDim2.new(0, 12, 0, 6),
			Text = ("HISTOIRE %d/%d · %s"):format(story.index, story.total, story.title),
			maxSize = 20,
			TextColor3 = PINK,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33,
		})
		UI.text(card, {
			Size = UDim2.new(1, -170, 0, 56),
			Position = UDim2.new(0, 12, 0, 34),
			Text = story.text,
			maxSize = 15,
			Font = UI.FontBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			outline = false,
			ZIndex = 33,
		})
		UI.text(card, {
			Size = UDim2.new(1, -170, 0, 22),
			Position = UDim2.new(0, 12, 1, -28),
			Text = ("Objectif : %d/%d · récompense : %d or, %d os"):format(
				story.progress,
				story.target,
				story.gold,
				story.bones
			),
			maxSize = 14,
			Font = UI.FontBody,
			TextColor3 = UI.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			outline = false,
			ZIndex = 33,
		})
		local claim = UI.button(card, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 140, 0, 46),
			Text = story.ready and "RÉCUPÉRER" or "EN COURS",
			BackgroundColor3 = story.ready and UI.Colors.Good or UI.Colors.Panel,
			maxSize = 18,
			ZIndex = 33,
		})
		if story.ready then
			claim.Activated:Connect(function()
				invoke(Remotes.ZooAction, "story")
			end)
		end
	else
		order = order + 1
		UI.text(list, {
			Size = UDim2.new(1, -8, 0, 40),
			Text = "Histoire terminée : tu as le plus beau zoo du monde !",
			maxSize = 18,
			TextColor3 = PINK,
			LayoutOrder = order,
			ZIndex = 32,
		})
	end

	local daily = data.daily
	order = order + 1
	row(
		list,
		order,
		"Cadeau du jour",
		daily.claimable and ("+%d or · série actuelle : %d jour(s)"):format(daily.reward, daily.streak)
			or "Déjà récupéré. Reviens demain pour prolonger ta série !",
		daily.claimable and "RÉCUPÉRER" or "REVIENS DEMAIN",
		daily.claimable and UI.Colors.Good or UI.Colors.Muted,
		daily.claimable and function()
			invoke(Remotes.ClaimDaily)
		end or nil
	)

	for index, quest in ipairs(data.quests) do
		order = order + 1
		local done = quest.progress >= quest.target
		local text, color, handler
		if quest.claimed then
			text, color = "FAIT", UI.Colors.Muted
		elseif done then
			text, color = ("+%d or"):format(quest.reward), UI.Colors.Good
			handler = function()
				invoke(Remotes.ClaimQuest, index)
			end
		else
			text, color = ("%d/%d"):format(quest.progress, quest.target), UI.Colors.PanelLight
		end
		row(list, order, quest.label, ("Récompense : %d or"):format(quest.reward), text, color, handler)
	end

	order = order + 1
	local stats = UI.frame(
		list,
		{ Size = UDim2.new(1, -8, 0, 92), BackgroundColor3 = UI.Colors.Panel, LayoutOrder = order, ZIndex = 32 }
	)
	UI.corner(stats, 12)
	UI.stroke(stats, UI.Colors.PanelLight, 2)
	local lines = {
		("Meilleur score : %s · Victoires : %d · Expéditions : %d"):format(
			Util.formatNumber(data.bestScore),
			data.wins,
			data.rounds
		),
		("Animaux récupérés : %d · Animaux différents : %d · Distance : %s m"):format(
			data.captures,
			data.zoo.owned,
			Util.formatNumber(data.distance)
		),
	}
	if data.persistent == false then
		table.insert(lines, "Sauvegarde indisponible : ta progression ne sera pas enregistrée.")
	end
	UI.text(stats, {
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.new(0, 8, 0, 6),
		Text = table.concat(lines, "\n"),
		maxSize = 17,
		Font = UI.FontBody,
		outline = false,
		ZIndex = 33,
	})
end

-- ---------------------------------------------------------------------------
-- Boutique Robux
-- ---------------------------------------------------------------------------

local PRODUCT_DESC = {
	gold = function(p)
		return ("+%s or, utilisables partout"):format(Util.formatNumber(p.amount))
	end,
	bones = function(p)
		return ("+%d os pour améliorer tes animaux"):format(p.amount)
	end,
	boost = function(p)
		return ("Revenus du zoo x2 pendant %d minutes"):format(p.amount)
	end,
	revive = function()
		return "Une vie de plus en pleine expédition (ou gardée pour la prochaine)"
	end,
}

local function renderRobux(content)
	clear(content)
	local data = ClientState.Data
	if not data or not data.loaded then
		loading(content)
		return
	end
	local list = listFrame(content, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
	local store = data.store or { passes = {}, products = {} }
	local order = 0

	local function header(text)
		order = order + 1
		UI.text(list, {
			Size = UDim2.new(1, -8, 0, 30),
			Text = text,
			maxSize = 22,
			TextColor3 = UI.Colors.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			ZIndex = 32,
		})
	end
	local function priceText(entry)
		if not entry.available then
			return "BIENTÔT"
		end
		return entry.price and ("R$ " .. entry.price) or "ACHETER"
	end

	UI.text(list, {
		Size = UDim2.new(1, -8, 0, 22),
		Text = "La partie de base reste gratuite : ces achats sont facultatifs.",
		maxSize = 15,
		Font = UI.FontBody,
		TextColor3 = UI.Colors.Muted,
		LayoutOrder = 0,
		ZIndex = 32,
	})
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
		row(
			list,
			order,
			entry.name,
			entry.desc,
			owned and "POSSÉDÉ" or priceText(entry),
			owned and UI.Colors.Muted or (entry.available and UI.Colors.Good or UI.Colors.PanelLight),
			handler
		)
	end

	header("OR, OS ET AUTRES")
	for _, entry in ipairs(store.products) do
		order = order + 1
		local handler = nil
		if entry.available then
			handler = function()
				Sfx.play("click")
				Remotes.Prompt:FireServer("product", entry.key)
			end
		end
		local describe = PRODUCT_DESC[entry.kind]
		row(
			list,
			order,
			entry.name,
			describe and describe(entry) or "",
			priceText(entry),
			entry.available and UI.Colors.Good or UI.Colors.PanelLight,
			handler
		)
	end
end

-- ---------------------------------------------------------------------------
-- Panneau et boutons
-- ---------------------------------------------------------------------------

local RENDERERS = {
	expedition = { title = "EXPÉDITION", fn = renderExpedition },
	zoo = { title = "TON ZOO", fn = renderZoo },
	shop = { title = "BOUTIQUE", fn = renderShop },
	quests = { title = "HISTOIRE & QUÊTES", fn = renderQuests },
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
	if data.daily.claimable or (data.story and data.story.ready) then
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
		refs.coins.Text = ("Or : %s · Os : %d"):format(Util.formatNumber(data.coins), data.bones)
	else
		refs.coins.Text = "Chargement..."
	end
	refs.badge.Visible = questBadge()
end

local function refreshVisibility()
	local visible = not ClientState.inRun()
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
		Size = UDim2.new(0, 160, 0, 5 * 52),
		BackgroundTransparency = 1,
	})
	UI.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.buttons)
	local defs = {
		{ id = "expedition", label = "EXPÉDITION", color = UI.Colors.Good },
		{ id = "zoo", label = "MON ZOO", color = PINK },
		{ id = "shop", label = "BOUTIQUE", color = UI.Colors.Accent },
		{ id = "quests", label = "HISTOIRE", color = UI.Colors.Info },
		{ id = "robux", label = "ROBUX", color = Color3.fromRGB(255, 120, 90) },
	}
	for index, def in ipairs(defs) do
		local b = UI.button(refs.buttons, {
			Size = UDim2.new(1, 0, 0, 46),
			Text = def.label,
			BackgroundColor3 = def.color,
			LayoutOrder = index,
			maxSize = 22,
		})
		b.Activated:Connect(function()
			if openName == def.id then
				close()
			else
				open(def.id)
			end
		end)
		if def.id == "quests" then
			refs.badge = UI.frame(b, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 4, 0, -4),
				Size = UDim2.new(0, 16, 0, 16),
				BackgroundColor3 = UI.Colors.Bad,
				Visible = false,
				ZIndex = 5,
			})
			UI.corner(refs.badge, 8)
			UI.stroke(refs.badge, UI.Colors.Dark, 2)
		end
	end

	-- or et os
	refs.coinsBox = UI.frame(gui, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0, 230, 0, 40),
		BackgroundTransparency = 0.15,
	})
	UI.corner(refs.coinsBox, 12)
	UI.stroke(refs.coinsBox, UI.Colors.Dark, 2)
	refs.coins = UI.text(refs.coinsBox, {
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.new(0, 6, 0, 4),
		Text = "Chargement...",
		maxSize = 20,
		TextColor3 = UI.Colors.Accent,
	})

	-- panneau modal
	refs.panel = UI.frame(gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.8, 0, 0.84, 0),
		Visible = false,
		ZIndex = 30,
	})
	UI.make("UISizeConstraint", { MaxSize = Vector2.new(780, 540), MinSize = Vector2.new(320, 240) }, refs.panel)
	UI.corner(refs.panel, 18)
	UI.stroke(refs.panel, UI.Colors.Accent, 3)
	refs.title = UI.text(refs.panel, {
		Size = UDim2.new(1, -120, 0, 44),
		Position = UDim2.new(0, 16, 0, 8),
		Text = "",
		maxSize = 32,
		TextColor3 = UI.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
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

	-- le départ efface l'état « prêt » ; la caisse du zoo s'actualise chaque seconde
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = workspace:GetAttribute("Phase")
		if phase == "Countdown" or phase == "Running" then
			readyState = false
		end
		if openName == "expedition" then
			render()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local data = ClientState.Data
			if openName == "zoo" and refs.cashLabel and refs.cashLabel.Parent and data and data.loaded then
				refs.cashLabel.Text = ("Caisse : %s or"):format(Util.formatNumber(pendingEstimate(data)))
			end
		end
	end)

	refreshChrome()
	refreshVisibility()
end

return Menu
