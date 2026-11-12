--!nonstrict
-- Gestion des joueurs : attributs répliqués, leaderstats, XP / pièces / niveaux,
-- plaque de nom, réapparition et synchronisation du profil vers le client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local QuestLogic = require(Shared.QuestLogic)
local Lore = require(Shared.Lore)
local Remotes = require(Shared.Remotes)
local DataService = require(Server.DataService)

local PlayerService = {}

-- Callbacks enregistrés par d'autres services : fn(player, character)
PlayerService.CharacterCallbacks = {}
-- Callbacks exécutés AVANT chaque (ré)apparition : fn(player) -> choisit player.RespawnLocation
PlayerService.PreSpawnCallbacks = {}

local syncQueued = {}

local function hex(h)
	return Color3.fromHex(h)
end

-- (Ré)apparition d'un joueur après sélection du point d'apparition.
function PlayerService.Respawn(player)
	for _, fn in ipairs(PlayerService.PreSpawnCallbacks) do
		fn(player)
	end
	if player.Parent == Players then
		player:LoadCharacter()
	end
end

function PlayerService.Profile(player)
	return DataService.Get(player)
end

function PlayerService.Notify(player, kind, text, extra)
	if player.Parent == nil then
		return
	end
	Remotes.Notify:FireClient(player, { Kind = kind, Text = text, Extra = extra })
end

-- Construit la vue du profil envoyée au client (pas de données internes).
function PlayerService.BuildClientProfile(player)
	local p = DataService.Get(player)
	if not p then
		return nil
	end
	local today = QuestLogic.DayKey(os.time())
	local quests = {}
	if p.Quests then
		for _, q in ipairs(p.Quests.List) do
			table.insert(quests, { Id = q.Id, Progress = q.Progress, Claimed = q.Claimed })
		end
	end
	local nextDay = (p.DailyStreak % #Config.DailyRewards) + 1
	if p.LastDaily > 0 and today - p.LastDaily > 1 then
		nextDay = 1
	end
	return {
		Coins = p.Coins,
		XP = p.XP,
		Level = p.Level,
		XPNeeded = Progression.XpToNext(p.Level),
		Kills = p.Kills,
		Deaths = p.Deaths,
		Wins = p.Wins,
		MatchesPlayed = p.MatchesPlayed,
		BestStreak = p.BestStreak,
		Headshots = p.Headshots,
		DamageDealt = math.floor(p.DamageDealt),
		Owned = p.Owned,
		Loadout = p.Loadout,
		Quests = quests,
		DailyAvailable = p.LastDaily < today,
		DailyNext = nextDay,
		Ephemeral = p.Ephemeral == true,
		Hero = p.Hero,
		Season = p.Season,
		Chapters = p.Chapters,
		Passes = {
			DoubleXP = player:GetAttribute("HasDoubleXP") == true,
			DoubleCoins = player:GetAttribute("HasDoubleCoins") == true,
			VIP = player:GetAttribute("HasVIP") == true,
		},
	}
end

function PlayerService.Sync(player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.delay(0.15, function()
		syncQueued[player] = nil
		if player.Parent == nil then
			return
		end
		local view = PlayerService.BuildClientProfile(player)
		if view then
			Remotes.Sync:FireClient(player, view)
		end
	end)
end

local function refreshAttributes(player)
	local p = DataService.Get(player)
	if not p then
		return
	end
	player:SetAttribute("Coins", p.Coins)
	player:SetAttribute("XP", p.XP)
	player:SetAttribute("XPNeeded", Progression.XpToNext(p.Level))
	player:SetAttribute("Level", p.Level)
	player:SetAttribute("Title", Progression.TitleFor(p.Level, Config.Titles))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Niveau.Value = p.Level
		stats.Kills.Value = p.Kills
	end
	PlayerService.Sync(player)
end
PlayerService.Refresh = refreshAttributes

-- raw = true : montant exact (achats, remboursements) sans multiplicateur de pass.
function PlayerService.AddCoins(player, amount, raw)
	local p = DataService.Get(player)
	if not p or amount == 0 then
		return
	end
	if not raw and amount > 0 and player:GetAttribute("HasDoubleCoins") then
		amount *= 2
	end
	p.Coins = math.max(0, p.Coins + math.floor(amount))
	refreshAttributes(player)
end

function PlayerService.SpendCoins(player, amount)
	local p = DataService.Get(player)
	if not p or amount < 0 or p.Coins < amount then
		return false
	end
	p.Coins -= amount
	refreshAttributes(player)
	return true
end

function PlayerService.AddXP(player, amount)
	local p = DataService.Get(player)
	if not p or amount <= 0 then
		return
	end
	if player:GetAttribute("HasDoubleXP") then
		amount *= 2
	end
	local level, xp, gained = Progression.AddXp(p.Level, p.XP, amount, Config.MaxLevel)
	p.Level, p.XP = level, xp
	if gained > 0 then
		local reward = 0
		for lv = level - gained + 1, level do
			reward += Progression.LevelUpReward(lv)
		end
		p.Coins += reward
		PlayerService.Notify(player, "LevelUp", ("Niveau %d atteint !"):format(level), { Level = level, Coins = reward, Title = Progression.TitleFor(level, Config.Titles) })
	end
	refreshAttributes(player)
end

-- Incrémente un compteur du profil (Kills, Deaths, Wins...).
function PlayerService.Increment(player, field, amount)
	local p = DataService.Get(player)
	if not p then
		return
	end
	p[field] = (p[field] or 0) + amount
	refreshAttributes(player)
end

-- Aura et teinte du héros choisi (purement visuel, aucun effet sur les dégâts).
function PlayerService.ApplyHero(player, character)
	local profile = DataService.Get(player)
	local hero = profile and Lore.Hero(profile.Hero)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not hero or not root then
		return
	end
	local color = hex(hero.Color)
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors then
		colors.TorsoColor3 = color
	end
	local old = root:FindFirstChild("HeroAura")
	if old then
		old:Destroy()
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "HeroAura"
	aura.Color = ColorSequence.new(color)
	aura.LightEmission = 0.8
	aura.Rate = 8
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Speed = NumberRange.new(0.5, 1.5)
	aura.Size = NumberSequence.new(0.35, 0)
	aura.Transparency = NumberSequence.new(0.3, 1)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = root
	player:SetAttribute("Hero", profile.Hero)
	player:SetAttribute("SeasonChampion", false)
end

-- ===== Plaque de nom =====
local function buildNameTag(player, character)
	local head = character:WaitForChild("Head", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(160, 46)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.AlwaysOnTop = false
	gui.Adornee = head

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 18)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 15
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.4
	name.Text = player.DisplayName
	name.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 18)
	sub.Size = UDim2.new(1, 0, 0, 14)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.TextColor3 = Color3.fromRGB(220, 220, 220)
	sub.TextStrokeTransparency = 0.5
	sub.Parent = gui

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.AnchorPoint = Vector2.new(0.5, 0)
	barBg.Position = UDim2.new(0.5, 0, 0, 34)
	barBg.Size = UDim2.fromOffset(90, 7)
	barBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	barBg.BorderSizePixel = 0
	barBg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 110)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local corner2 = corner:Clone()
	corner2.Parent = fill

	local function refresh()
		local team = player:GetAttribute("Team")
		if team and team ~= "" and Config.TeamColors[team] then
			name.TextColor3 = hex(Config.TeamColors[team])
		else
			name.TextColor3 = Color3.new(1, 1, 1)
		end
		local hero = Lore.Hero(tostring(player:GetAttribute("Hero")))
		sub.Text = ("Niv. %d · %s%s%s%s"):format(player:GetAttribute("Level") or 1, player:GetAttribute("Title") or "", hero and (" · " .. hero.Name) or "", player:GetAttribute("HasVIP") and "  ★ VIP" or "", player:GetAttribute("SeasonChampion") and "  🏆" or "")
	end
	local function refreshHealth()
		local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 70, 70):Lerp(Color3.fromRGB(80, 220, 110), ratio)
	end
	refresh()
	refreshHealth()
	-- les connexions sur le joueur survivent au personnage : on les coupe à sa disparition
	local connections = { humanoid.HealthChanged:Connect(refreshHealth) }
	for _, attr in ipairs({ "Team", "Level", "Title", "HasVIP", "Hero", "SeasonChampion" }) do
		table.insert(connections, player:GetAttributeChangedSignal(attr):Connect(refresh))
	end
	gui.Destroying:Connect(function()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
	end)
	gui.Parent = head
end

local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Player.JumpPower
	task.spawn(buildNameTag, player, character)
	PlayerService.ApplyHero(player, character)

	for _, fn in ipairs(PlayerService.CharacterCallbacks) do
		task.spawn(fn, player, character)
	end

	humanoid.Died:Connect(function()
		task.wait(Config.Match.RespawnSeconds)
		if player.Parent == Players and DataService.Get(player) and player.Character == character then
			PlayerService.Respawn(player)
		end
	end)
end

-- Appelé une fois le profil chargé.
function PlayerService.Setup(player, profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, def in ipairs({ { "Niveau", profile.Level }, { "Kills", profile.Kills } }) do
		local v = Instance.new("IntValue")
		v.Name = def[1]
		v.Value = def[2]
		v.Parent = stats
	end
	stats.Parent = player

	player:SetAttribute("InArena", false)
	player:SetAttribute("Team", "")
	player:SetAttribute("Streak", 0)
	player:SetAttribute("BoostUntil", 0)
	player:SetAttribute("HasDoubleXP", false)
	player:SetAttribute("HasDoubleCoins", false)
	player:SetAttribute("HasVIP", false)
	player:SetAttribute("Hero", profile.Hero)
	refreshAttributes(player)

	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if profile.Ephemeral then
		task.delay(6, function()
			PlayerService.Notify(player, "Warn", "Sauvegarde indisponible : votre progression de cette session ne sera pas enregistrée.")
		end)
	end
end

return PlayerService
