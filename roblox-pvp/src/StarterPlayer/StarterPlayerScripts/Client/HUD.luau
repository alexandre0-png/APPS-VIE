--!nonstrict
-- Interface en jeu : bandeau de manche, carte joueur, vie, barre d'armes,
-- viseur, kill-feed, notifications, écran de mort et de résultats.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons)
local UI = require(Client.UI)
local State = require(Client.State)
local WeaponClient = require(Client.WeaponClient)

local HUD = {}

local C = UI.Colors
local player = Players.LocalPlayer
local gui
local menus
local components = {}

local function hex(h)
	return Color3.fromHex(h)
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function attr(name, default)
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

-- ===================================================================
-- Toasts & grandes annonces
-- ===================================================================
function HUD.Toast(text, color)
	local holder = components.ToastHolder
	if not holder then
		return
	end
	local label = UI.Frame(holder, {
		Size = UDim2.fromOffset(380, 34),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.15,
		Stroke = color or C.Accent,
	})
	UI.Label(label, { Size = UDim2.fromScale(1, 1), Text = text, TextSize = 15, TextColor3 = color or C.Text, TextWrapped = true })
	task.delay(3.2, function()
		UI.Tween(label, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.3)
		label:Destroy()
	end)
end

function HUD.Banner(title, subtitle, color, seconds)
	local b = components.BigBanner
	b.Title.Text = title
	b.Title.TextColor3 = color or C.Gold
	b.Sub.Text = subtitle or ""
	b.Frame.Visible = true
	b.Title.TextTransparency, b.Sub.TextTransparency = 0, 0
	b.Token = (b.Token or 0) + 1
	local token = b.Token
	task.delay(seconds or 2.6, function()
		if b.Token == token then
			UI.Tween(b.Title, 0.4, { TextTransparency = 1 })
			UI.Tween(b.Sub, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			if b.Token == token then
				b.Frame.Visible = false
			end
		end
	end)
end

-- ===================================================================
-- Construction
-- ===================================================================
local function buildMatchBanner()
	local f = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 62),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.2,
		Stroke = C.PanelLight,
	})
	local mode = UI.Label(f, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextColor3 = C.Dim, Text = "" })
	local timer = UI.Label(f, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 26), TextSize = 26, Font = Enum.Font.GothamBlack, Text = "--:--" })
	local score = UI.Label(f, { Position = UDim2.fromOffset(0, 43), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, RichText = true, TextColor3 = C.Dim, Text = "" })
	components.Match = { Mode = mode, Timer = timer, Score = score }
end

local function updateMatchBanner()
	local m = components.Match
	local state = workspace:GetAttribute("MatchState") or "Waiting"
	local currentMode = workspace:GetAttribute("MatchMode") or "FFA"
	local endsAt = workspace:GetAttribute("MatchEndsAt") or 0
	local remaining = endsAt > 0 and (endsAt - workspace:GetServerTimeNow()) or 0
	local inArena = attr("InArena", false)

	if state == "Waiting" then
		m.Mode.Text = "EN ATTENTE DE JOUEURS"
		m.Timer.Text = "--:--"
		m.Score.Text = inArena and "La manche démarre bientôt…" or "Entrez dans l'arène pour lancer une manche"
	elseif state == "Intermission" then
		local nextMode = workspace:GetAttribute("NextMode") or ""
		m.Mode.Text = "PROCHAINE MANCHE : " .. (Config.ModeNames[nextMode] or "?")
		m.Timer.Text = formatTime(remaining)
		m.Score.Text = inArena and "Préparez-vous !" or "Passez le portail pour participer"
	elseif state == "Playing" then
		m.Mode.Text = Config.ModeNames[currentMode] or ""
		m.Timer.Text = formatTime(remaining)
		if currentMode == "TEAM" then
			local team = attr("Team", "")
			local mine = team ~= "" and ("  ·  vous : <font color=\"#%s\">%s</font>"):format(Config.TeamColors[team] or "FFFFFF", Config.TeamNames[team] or "") or ""
			m.Score.Text = ("<font color=\"#%s\">Rouges %d</font>  —  <font color=\"#%s\">%d Bleus</font>%s"):format(
				Config.TeamColors.Red,
				workspace:GetAttribute("RedScore") or 0,
				Config.TeamColors.Blue,
				workspace:GetAttribute("BlueScore") or 0,
				mine
			)
		else
			m.Score.Text = inArena and ("Vos éliminations : %d / %d"):format(attr("MatchKills", 0), Config.Match.FFAScoreLimit) or ("Premier à %d éliminations"):format(Config.Match.FFAScoreLimit)
		end
	else
		m.Mode.Text = "FIN DE MANCHE"
		m.Timer.Text = formatTime(remaining)
		m.Score.Text = ""
	end
end

local function buildPlayerCard()
	local f = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(270, 76),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.2,
		Stroke = C.PanelLight,
	})
	local badge = UI.Frame(f, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.Accent, Radius = 23 })
	local lvl = UI.Label(badge, { Size = UDim2.fromScale(1, 1), TextSize = 22, Font = Enum.Font.GothamBlack, Text = "1" })
	UI.Label(f, { Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -70, 0, 20), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = player.DisplayName })
	local title = UI.Label(f, { Position = UDim2.fromOffset(62, 24), Size = UDim2.new(1, -70, 0, 16), TextSize = 12, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	local xpBg = UI.Frame(f, { Position = UDim2.fromOffset(62, 44), Size = UDim2.new(1, -72, 0, 10), BackgroundColor3 = Color3.fromRGB(16, 18, 26), Radius = 5 })
	local xpFill = UI.Frame(xpBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Radius = 5 })
	local coins = UI.Label(f, { Position = UDim2.fromOffset(62, 55), Size = UDim2.new(1, -70, 0, 18), TextSize = 15, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Text = "🪙 0" })
	local xpText = UI.Label(f, { Position = UDim2.fromOffset(62, 55), Size = UDim2.new(1, -70, 0, 18), TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })

	local function refresh()
		lvl.Text = tostring(attr("Level", 1))
		title.Text = tostring(attr("Title", ""))
		coins.Text = "🪙 " .. UI.FormatNumber(attr("Coins", 0))
		local need = math.max(1, attr("XPNeeded", 1))
		xpFill.Size = UDim2.fromScale(math.clamp(attr("XP", 0) / need, 0, 1), 1)
		xpText.Text = ("%d / %d XP"):format(attr("XP", 0), need)
	end
	for _, a in ipairs({ "Level", "Title", "Coins", "XP", "XPNeeded" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	refresh()

	local streak = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -96),
		Size = UDim2.fromOffset(150, 30),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.25,
		Visible = false,
		Stroke = C.Gold,
	})
	local streakLabel = UI.Label(streak, { Size = UDim2.fromScale(1, 1), TextSize = 15, TextColor3 = C.Gold, Text = "" })
	player:GetAttributeChangedSignal("Streak"):Connect(function()
		local n = attr("Streak", 0)
		streak.Visible = n >= 2
		streakLabel.Text = ("🔥 Série : %d"):format(n)
	end)
end

local function buildHealth()
	local f = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(380, 22),
		BackgroundColor3 = Color3.fromRGB(14, 16, 22),
		Radius = 11,
		Stroke = Color3.new(0, 0, 0),
	})
	local fill = UI.Frame(f, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Good, Radius = 11 })
	local text = UI.Label(f, { Size = UDim2.fromScale(1, 1), TextSize = 14, Text = "100", ZIndex = 3 })
	text.TextStrokeTransparency = 0.5
	local connection
	local function bind(character)
		if connection then
			connection:Disconnect()
		end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		local function update()
			local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
			UI.Tween(fill, 0.12, { Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = C.Bad:Lerp(C.Good, ratio) })
			text.Text = ("%d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
		end
		connection = humanoid.HealthChanged:Connect(update)
		update()
	end
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)
end

-- ===== Barre d'armes =====
local function buildHotbar()
	local f = UI.New("Frame", {
		Parent = gui,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -44),
		Size = UDim2.fromOffset(3 * 96 + 2 * 8, 58),
	})
	local slots = {}
	for i = 1, Config.Loadout.Slots do
		local slot = UI.Button(f, {
			Position = UDim2.fromOffset((i - 1) * 104, 0),
			Size = UDim2.fromOffset(96, 58),
			BackgroundColor3 = C.Bg,
			BackgroundTransparency = 0.15,
			Text = "",
			AutoButtonColor = false,
		})
		local stroke = UI.Stroke(slot, C.PanelLight, 2, 0)
		UI.Label(slot, { Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(16, 14), TextSize = 12, TextColor3 = C.Dim, Text = tostring(i) })
		local name = UI.Label(slot, { Position = UDim2.fromOffset(4, 18), Size = UDim2.new(1, -8, 0, 30), TextSize = 13, TextWrapped = true, Text = "" })
		local accent = UI.Frame(slot, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = C.PanelLight, Radius = false })
		local cd = UI.Frame(slot, { Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Radius = 8, ZIndex = 4 })
		slots[i] = { Button = slot, Stroke = stroke, Name = name, Accent = accent, Cooldown = cd, Tool = nil }
	end
	components.Slots = slots

	local function toggle(i)
		local slot = slots[i]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not slot or not slot.Tool or not humanoid or humanoid.Health <= 0 then
			return
		end
		if slot.Tool.Parent == character then
			humanoid:UnequipTools()
		else
			humanoid:EquipTool(slot.Tool)
		end
	end
	for i, slot in ipairs(slots) do
		slot.Button.Activated:Connect(function()
			toggle(i)
		end)
	end
	-- manette : L1 / R1 pour changer d'arme
	local function cycle(step)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local current = 0
		for i, slot in ipairs(slots) do
			if slot.Tool and slot.Tool.Parent == character then
				current = i
			end
		end
		for k = 1, #slots do
			local idx = ((current - 1 + step * k) % #slots) + 1
			if slots[idx].Tool then
				humanoid:EquipTool(slots[idx].Tool)
				return
			end
		end
	end
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.ButtonL1 then
			cycle(-1)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			cycle(1)
		end
		if processed then
			return
		end
		for i, key in ipairs(keys) do
			if input.KeyCode == key then
				toggle(i)
			end
		end
	end)
end

local function refreshHotbar()
	local slots = components.Slots
	local found = {}
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") then
					table.insert(found, child)
				end
			end
		end
	end
	local order = {}
	local profile = State.Profile
	if profile then
		for i, id in ipairs(profile.Loadout) do
			order[id] = i
		end
	end
	table.sort(found, function(a, b)
		return (order[a:GetAttribute("WeaponId")] or 99) < (order[b:GetAttribute("WeaponId")] or 99)
	end)
	for i, slot in ipairs(slots) do
		local tool = found[i]
		slot.Tool = tool
		local def = tool and Weapons.Get(tool:GetAttribute("WeaponId"))
		slot.Def = def
		slot.Name.Text = def and def.Name or ""
		slot.Accent.BackgroundColor3 = def and hex(def.Accent) or C.PanelLight
	end
end

local function updateHotbarVisuals()
	local character = player.Character
	for _, slot in ipairs(components.Slots) do
		local equipped = slot.Tool ~= nil and slot.Tool.Parent == character
		slot.Stroke.Color = equipped and C.Gold or C.PanelLight
		slot.Button.BackgroundTransparency = equipped and 0 or 0.15
		local left = slot.Def and WeaponClient.CooldownLeft(slot.Def.Id) or 0
		slot.Cooldown.Size = UDim2.fromScale(1, left)
	end
end

-- ===== Viseur / hit markers =====
local function buildCrosshair()
	local ring = UI.New("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Visible = false,
	})
	UI.Corner(ring, 13)
	UI.Stroke(ring, Color3.new(1, 1, 1), 2, 0.1)
	UI.Frame(ring, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.new(1, 1, 1), Radius = 2 })
	local marker = UI.Label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		Text = "✕",
		TextSize = 40,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
	})
	components.Crosshair = ring
	components.Marker = marker
end

function HUD.HitMarker(headshot, killed)
	local m = components.Marker
	m.TextColor3 = killed and C.Bad or (headshot and C.Gold or Color3.new(1, 1, 1))
	m.TextTransparency = 0
	m.TextSize = killed and 56 or 40
	UI.Tween(m, 0.25, { TextTransparency = 1 })
end

function HUD.DamageFlash(amount, from)
	local flash = components.Flash
	flash.BackgroundTransparency = math.clamp(0.75 - amount / 120, 0.4, 0.75)
	UI.Tween(flash, 0.5, { BackgroundTransparency = 1 })
	-- indicateur de direction
	local camera = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if from and camera and root then
		local d = from - root.Position
		local dir = Vector3.new(d.X, 0, d.Z)
		local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
		if dir.Magnitude > 1 and look.Magnitude > 0.01 then
			dir, look = dir.Unit, look.Unit
			local ang = math.atan2(look.X * dir.Z - look.Z * dir.X, look:Dot(dir))
			local arrow = components.Arrow
			arrow.Position = UDim2.new(0.5, math.sin(ang) * 130, 0.5, -math.cos(ang) * 130)
			arrow.Rotation = math.deg(ang)
			arrow.TextTransparency = 0
			components.ArrowToken = (components.ArrowToken or 0) + 1
			local token = components.ArrowToken
			task.delay(0.15, function()
				if components.ArrowToken == token then
					UI.Tween(arrow, 0.6, { TextTransparency = 1 })
				end
			end)
		end
	end
end

-- ===== Kill-feed =====
local function buildFeed()
	components.Feed = UI.New("Frame", {
		Parent = gui,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 130),
		Size = UDim2.fromOffset(340, 120),
	})
	UI.New("UIListLayout", { Parent = components.Feed, Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder })
end

function HUD.OnFeed(data)
	local feed = components.Feed
	local function colored(name, team)
		local color = (team ~= "" and Config.TeamColors[team]) or "FFFFFF"
		return ('<font color="#%s">%s</font>'):format(color, name)
	end
	local text
	if data.Killer then
		text = ("%s  <font color=\"#B8C0CC\">[%s]</font>%s  %s"):format(colored(data.Killer, data.KillerTeam or ""), data.Weapon or "?", data.Headshot and " 🎯" or "", colored(data.Victim, data.VictimTeam or ""))
	else
		text = ("%s  <font color=\"#B8C0CC\">est tombé</font>"):format(colored(data.Victim, data.VictimTeam or ""))
	end
	local mine = data.Killer == player.DisplayName or data.Victim == player.DisplayName
	local row = UI.Frame(feed, {
		Size = UDim2.fromOffset(330, 22),
		BackgroundColor3 = mine and Color3.fromRGB(120, 30, 30) or C.Bg,
		BackgroundTransparency = 0.3,
		LayoutOrder = math.floor(os.clock() * 1000),
		Radius = 5,
	})
	UI.Label(row, { Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), RichText = true, Text = text, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right })
	local rows = {}
	for _, child in ipairs(feed:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #rows > 5 do
		table.remove(rows, 1):Destroy()
	end
	task.delay(6, function()
		if row.Parent then
			UI.Tween(row, 0.4, { BackgroundTransparency = 1 })
			task.wait(0.4)
			row:Destroy()
		end
	end)
end

-- ===== Notifications serveur =====
local function buildBigBanner()
	local f = UI.New("Frame", {
		Parent = gui,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.22, 0),
		Size = UDim2.fromOffset(600, 90),
		Visible = false,
	})
	local title = UI.Label(f, { Size = UDim2.new(1, 0, 0, 52), TextSize = 44, Font = Enum.Font.GothamBlack, Text = "" })
	title.TextStrokeTransparency = 0.3
	local sub = UI.Label(f, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 28), TextSize = 20, Text = "" })
	sub.TextStrokeTransparency = 0.4
	components.BigBanner = { Frame = f, Title = title, Sub = sub, Token = 0 }
end

local function buildKillPopup()
	local f = UI.New("Frame", {
		Parent = gui,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.58, 0),
		Size = UDim2.fromOffset(460, 80),
		Visible = false,
	})
	local title = UI.Label(f, { Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Font = Enum.Font.GothamBlack, TextColor3 = C.Bad, Text = "ÉLIMINATION" })
	title.TextStrokeTransparency = 0.3
	local sub = UI.Label(f, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, RichText = true, Text = "" })
	sub.TextStrokeTransparency = 0.4
	local extra = UI.Label(f, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextColor3 = C.Gold, Text = "" })
	extra.TextStrokeTransparency = 0.4
	components.KillPopup = { Frame = f, Title = title, Sub = sub, Extra = extra, Token = 0 }
end

local function showKill(data)
	local k = components.KillPopup
	local e = data.Extra or {}
	k.Title.Text = e.Headshot and "TIR À LA TÊTE !" or "ÉLIMINATION"
	k.Sub.Text = ("%s  ·  +%d 🪙  +%d XP"):format(data.Text, e.Coins or 0, e.XP or 0)
	local lines = {}
	if e.Label then
		table.insert(lines, e.Label)
	end
	if (e.Bounty or 0) > 0 then
		table.insert(lines, ("Prime récupérée : +%d 🪙"):format(e.Bounty))
	end
	k.Extra.Text = table.concat(lines, "  ·  ")
	k.Frame.Visible = true
	k.Token += 1
	local token = k.Token
	task.delay(2.2, function()
		if k.Token == token then
			k.Frame.Visible = false
		end
	end)
	if e.Label then
		HUD.Banner(e.Label, "", C.Gold, 1.8)
	end
end

local function buildDeathScreen()
	local f = UI.New("Frame", {
		Parent = gui,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
	})
	local title = UI.Label(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(600, 60), TextSize = 46, Font = Enum.Font.GothamBlack, TextColor3 = C.Bad, Text = "ÉLIMINÉ", ZIndex = 6 })
	local who = UI.Label(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 30), TextSize = 22, Text = "", ZIndex = 6 })
	local count = UI.Label(f, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.57), Size = UDim2.fromOffset(600, 30), TextSize = 20, TextColor3 = C.Dim, Text = "", ZIndex = 6 })
	components.Death = { Frame = f, Title = title, Who = who, Count = count, Token = 0 }
	player.CharacterAdded:Connect(function()
		f.Visible = false
		components.Death.Token += 1
	end)
end

local function showDeath(data)
	local d = components.Death
	d.Frame.Visible = true
	d.Title.Text = data.Text ~= "" and "ÉLIMINÉ" or "TU ES TOMBÉ"
	d.Who.Text = data.Text ~= "" and ("par %s  [%s]"):format(data.Text, (data.Extra and data.Extra.Weapon) or "?") or ""
	d.Token += 1
	local token = d.Token
	local seconds = (data.Extra and data.Extra.Seconds) or 3
	task.spawn(function()
		for s = seconds, 1, -1 do
			if d.Token ~= token then
				return
			end
			d.Count.Text = ("Réapparition dans %d…"):format(s)
			task.wait(1)
		end
	end)
end

local function buildResults()
	local f = UI.Frame(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 400),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 8,
		Stroke = C.Gold,
	})
	local head = UI.Label(f, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 36), TextSize = 28, Font = Enum.Font.GothamBlack, TextColor3 = C.Gold, Text = "", ZIndex = 9 })
	local sub = UI.Label(f, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextColor3 = C.Dim, Text = "", ZIndex = 9 })
	local list = UI.New("Frame", { Parent = f, BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 230), ZIndex = 9 })
	UI.New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4) })
	local reward = UI.Label(f, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -20, 0, 50), TextSize = 18, TextColor3 = C.Good, Text = "", ZIndex = 9, TextWrapped = true })
	components.Results = { Frame = f, Head = head, Sub = sub, List = list, Reward = reward, Token = 0 }
end

local function showResults(data)
	local r = components.Results
	r.Head.Text = data.Won and ("🏆 " .. data.Headline) or data.Headline
	r.Head.TextColor3 = data.Won and C.Gold or C.Text
	if data.Mode == "TEAM" then
		r.Sub.Text = ("%s  ·  Rouges %d – %d Bleus"):format(data.ModeName, data.RedScore, data.BlueScore)
	else
		r.Sub.Text = data.ModeName
	end
	for _, child in ipairs(r.List:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, row in ipairs(data.Board) do
		local mine = row.UserId == player.UserId
		local line = UI.Frame(r.List, { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = mine and C.Accent or C.Panel, BackgroundTransparency = mine and 0.3 or 0.2, ZIndex = 9, Radius = 5 })
		local teamColor = (row.Team ~= "" and Config.TeamColors[row.Team]) and hex(Config.TeamColors[row.Team]) or C.Text
		UI.Label(line, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(30, 26), Text = "#" .. i, TextSize = 14, TextColor3 = C.Dim, ZIndex = 10 })
		UI.Label(line, { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -200, 1, 0), Text = row.Name, TextSize = 15, TextColor3 = teamColor, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10 })
		UI.Label(line, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(150, 26), Text = ("%d éliminations  ·  %d morts"):format(row.Kills, row.Deaths), TextSize = 13, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10 })
	end
	r.Reward.Text = ("Récompenses : +%d 🪙  +%d XP%s"):format(data.Coins, data.XP, data.Won and "  (bonus de victoire)" or "")
	r.Frame.Visible = true
	r.Token += 1
	local token = r.Token
	task.delay(Config.Match.ResultsSeconds - 1, function()
		if r.Token == token then
			r.Frame.Visible = false
		end
	end)
end

local function showBoost(data)
	local b = components.Boost
	local duration = data.Extra and data.Extra.Duration or 10
	b.Frame.Visible = true
	b.Fill.Size = UDim2.fromScale(1, 1)
	UI.Tween(b.Fill, duration, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
	b.Token += 1
	local token = b.Token
	task.delay(duration, function()
		if b.Token == token then
			b.Frame.Visible = false
		end
	end)
end

function HUD.OnNotify(data)
	local kind = data.Kind
	if kind == "Kill" then
		showKill(data)
	elseif kind == "Death" then
		showDeath(data)
	elseif kind == "Assist" then
		HUD.Toast(("Assistance : %s  +%d 🪙"):format(data.Text, data.Extra and data.Extra.Coins or 0), C.Accent)
	elseif kind == "LevelUp" then
		HUD.Banner("NIVEAU " .. data.Extra.Level, ("%s  ·  +%d 🪙"):format(data.Extra.Title, data.Extra.Coins), C.Gold, 3)
	elseif kind == "Reward" then
		HUD.Toast(data.Text, C.Good)
	elseif kind == "Quest" then
		HUD.Toast("📜 " .. data.Text, C.Accent)
	elseif kind == "Boost" then
		HUD.Toast(data.Text, C.Bad)
		showBoost(data)
	elseif kind == "Warn" then
		HUD.Toast(data.Text, C.Bad)
	else
		HUD.Toast(data.Text, C.Text)
	end
end

function HUD.OnMatch(data)
	if data.Type == "Results" then
		showResults(data)
	elseif data.Type == "Joined" then
		HUD.Toast("⚔ Vous entrez dans l'arène", C.Good)
	elseif data.Type == "Left" then
		HUD.Toast("🏠 Retour au hub", C.Accent)
	end
end

-- ===== Boutons de menu =====
local function buildMenuButtons()
	local column = UI.New("Frame", {
		Parent = gui,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.64, 0),
		Size = UDim2.fromOffset(150, 6 * 42),
	})
	UI.New("UIListLayout", { Parent = column, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Right })
	local defs = {
		{ Id = "Arena", Text = "⚔  ARÈNE", Color = C.Red },
		{ Id = "Shop", Text = "🛒  BOUTIQUE", Color = C.Accent },
		{ Id = "Loadout", Text = "🎒  ÉQUIPEMENT", Color = C.Accent },
		{ Id = "Quests", Text = "📜  QUÊTES", Color = C.Accent },
		{ Id = "Daily", Text = "🎁  CADEAU", Color = C.Gold },
		{ Id = "Stats", Text = "📊  STATS", Color = C.Accent },
	}
	local buttons = {}
	for i, def in ipairs(defs) do
		local b = UI.Button(column, { Size = UDim2.fromOffset(150, 37), BackgroundColor3 = def.Color, Text = def.Text, TextSize = 15, LayoutOrder = i })
		UI.Stroke(b, Color3.new(0, 0, 0), 1.5, 0.4)
		buttons[def.Id] = b
		b.Activated:Connect(function()
			if def.Id == "Arena" then
				local ok, msg = State.Request(attr("InArena", false) and "Leave" or "Join")
				if not ok then
					HUD.Toast(msg, C.Bad)
				end
			else
				menus.Toggle(def.Id)
			end
		end)
	end
	local dot = UI.Frame(buttons.Daily, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Bad, Radius = 8, Visible = false })
	local questDot = UI.Frame(buttons.Quests, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Good, Radius = 8, Visible = false })

	local function refresh()
		buttons.Arena.Text = attr("InArena", false) and "🏠  QUITTER" or "⚔  ARÈNE"
		buttons.Arena.BackgroundColor3 = attr("InArena", false) and C.PanelLight or C.Red
	end
	player:GetAttributeChangedSignal("InArena"):Connect(refresh)
	refresh()

	local announcedDaily = false
	State.OnChange(function(profile)
		dot.Visible = profile.DailyAvailable
		local claimable = false
		local QuestLogic = require(Shared.QuestLogic)
		for _, q in ipairs(profile.Quests) do
			local def = QuestLogic.Get(q.Id)
			if def and q.Progress >= def.Target and not q.Claimed then
				claimable = true
			end
		end
		questDot.Visible = claimable
		if profile.DailyAvailable and not announcedDaily then
			announcedDaily = true
			HUD.Toast("🎁 Votre cadeau quotidien vous attend !", C.Gold)
		end
		refreshHotbar()
	end)
end

local function buildTouchButton()
	if not UserInputService.TouchEnabled then
		return
	end
	local b = UI.Button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -150, 1, -110),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = C.Red,
		BackgroundTransparency = 0.15,
		Text = "⚔",
		TextSize = 44,
		Radius = 48,
		AutoButtonColor = false,
	})
	UI.Stroke(b, Color3.new(1, 1, 1), 3, 0.3)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponClient.SetTouchHold(true)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponClient.SetTouchHold(false)
		end
	end)
end

function HUD.Init(screenGui, menusModule)
	gui = screenGui
	menus = menusModule

	-- effets plein écran
	components.Flash = UI.New("Frame", { Parent = gui, BackgroundColor3 = Color3.fromRGB(200, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	components.Arrow = UI.Label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Text = "▲", TextSize = 34, TextColor3 = C.Bad, TextTransparency = 1, ZIndex = 3 })
	components.ToastHolder = UI.New("Frame", {
		Parent = gui,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(380, 200),
	})
	UI.New("UIListLayout", { Parent = components.ToastHolder, Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center })

	buildMatchBanner()
	buildPlayerCard()
	buildHealth()
	buildHotbar()
	buildCrosshair()
	buildFeed()
	buildBigBanner()
	buildKillPopup()
	buildDeathScreen()
	buildResults()
	buildMenuButtons()
	buildTouchButton()

	-- barre de rage
	local boost = UI.Frame(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(240, 20), BackgroundColor3 = Color3.fromRGB(40, 10, 10), Visible = false, Stroke = C.Bad })
	local boostFill = UI.Frame(boost, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Bad })
	UI.Label(boost, { Size = UDim2.fromScale(1, 1), Text = "🔥 RAGE  ×" .. tostring(Config.RageOrb.Multiplier), TextSize = 13, ZIndex = 3 })
	components.Boost = { Frame = boost, Fill = boostFill, Token = 0 }

	-- annonces d'état de manche
	local lastState = workspace:GetAttribute("MatchState")
	workspace:GetAttributeChangedSignal("MatchState"):Connect(function()
		local state = workspace:GetAttribute("MatchState")
		if state == lastState then
			return
		end
		lastState = state
		if not attr("InArena", false) then
			return
		end
		if state == "Playing" then
			HUD.Banner("C'EST PARTI !", Config.ModeNames[workspace:GetAttribute("MatchMode")] or "", C.Good, 2.4)
		elseif state == "Intermission" then
			HUD.Banner("PROCHAINE MANCHE", Config.ModeNames[workspace:GetAttribute("NextMode")] or "", C.Accent, 2.4)
		end
	end)

	-- boucles de rafraîchissement
	local timer = 0
	RunService.RenderStepped:Connect(function(dt)
		local def = WeaponClient.GetEquipped()
		local cross = components.Crosshair
		cross.Visible = def ~= nil and def.Class == "Ranged"
		if cross.Visible or components.Marker.TextTransparency < 1 then
			local pos = WeaponClient.AimScreenPos()
			cross.Position = UI.ScreenToOffset(pos)
			components.Marker.Position = cross.Position
		end
		updateHotbarVisuals()
		timer += dt
		if timer >= 0.2 then
			timer = 0
			updateMatchBanner()
		end
	end)

	local function watchTools()
		local backpack = player:WaitForChild("Backpack")
		local function hook(container)
			container.ChildAdded:Connect(refreshHotbar)
			container.ChildRemoved:Connect(refreshHotbar)
		end
		hook(backpack)
		if player.Character then
			hook(player.Character)
		end
		refreshHotbar()
	end
	player.CharacterAdded:Connect(function(character)
		task.spawn(watchTools)
		character.ChildAdded:Connect(refreshHotbar)
	end)
	if player.Character then
		task.spawn(watchTools)
	end
	player:GetAttributeChangedSignal("MatchKills"):Connect(updateMatchBanner)
	updateMatchBanner()
end

return HUD
