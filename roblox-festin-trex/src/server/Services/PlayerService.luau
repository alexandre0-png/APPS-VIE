--!nonstrict
-- Profils joueurs : chargement, état de session, statistiques, monnaie, synchronisation client.
-- Toutes les modifications de données passent par ici (le client ne peut jamais écrire).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Economy = require(Shared:WaitForChild("Economy"))
local QuestLogic = require(Shared:WaitForChild("QuestLogic"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent.DataService)

local PlayerService = {}

local profiles: { [Player]: any } = {} -- player -> data
local sessions: { [Player]: any } = {} -- player -> état volatil
local dirty: { [Player]: boolean } = {}
local loadedHooks: { (Player) -> () } = {}
local characterHooks: { (Player, Model) -> () } = {}
local saveHooks: { (Player, any) -> () } = {}

local StateRemote = nil
local NotifyRemote = nil

function PlayerService.get(player: Player): any?
	return profiles[player]
end

function PlayerService.session(player: Player): any?
	return sessions[player]
end

function PlayerService.getStats(player: Player): any?
	local data = profiles[player]
	if not data then
		return nil
	end
	return Economy.stats(data)
end

function PlayerService.onLoaded(fn: (Player) -> ())
	table.insert(loadedHooks, fn)
end

function PlayerService.onCharacter(fn: (Player, Model) -> ())
	table.insert(characterHooks, fn)
end

function PlayerService.onSave(fn: (Player, any) -> ())
	table.insert(saveHooks, fn)
end

function PlayerService.notify(player: Player, text: string, kind: string?)
	if NotifyRemote and player.Parent then
		NotifyRemote:FireClient(player, text, kind or "info")
	end
end

function PlayerService.markDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

-- ---------------------------------------------------------------- monnaie

function PlayerService.addCoins(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount ~= amount or amount <= 0 then
		return false
	end
	amount = math.floor(amount)
	data.coins = math.min(data.coins + amount, 1e15)
	QuestLogic.progress(data, "earn", amount)
	dirty[player] = true
	return true
end

function PlayerService.trySpend(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or amount ~= amount or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	if data.coins < amount then
		return false
	end
	data.coins -= amount
	dirty[player] = true
	return true
end

function PlayerService.addEggs(player: Player, n: number)
	local data = profiles[player]
	if data then
		data.eggs += math.max(0, math.floor(n))
		dirty[player] = true
	end
end

function PlayerService.addFed(player: Player, n: number)
	local data = profiles[player]
	if data then
		data.totalFed += n
		data.stats.hits += n
		dirty[player] = true
	end
end

-- kind = "feed" | "combo" | "fav" | "survive" | "feast" | "earn"
function PlayerService.record(player: Player, kind: string, amount: number)
	local data = profiles[player]
	if data and QuestLogic.progress(data, kind, amount) then
		dirty[player] = true
	end
end

-- ---------------------------------------------------------------- session

function PlayerService.refillBasket(player: Player, foodId: string?)
	local data, s = profiles[player], sessions[player]
	if not data or not s then
		return
	end
	if foodId then
		data.selectedFood = foodId
	end
	s.ammo = Economy.stats(data).capacity
	dirty[player] = true
end

function PlayerService.applyCharacter(player: Player)
	local data = profiles[player]
	local char = player.Character
	if not data or not char then
		return
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Economy.stats(data).walkSpeed
	end
end

-- ---------------------------------------------------------------- état public

local function snapshot(player: Player): any
	local data, s = profiles[player], sessions[player]
	local stats = Economy.stats(data)
	local level, progress, nextNeed = Economy.level(data.totalFed)
	local canDaily, nextDay = QuestLogic.dailyStatus(data, Util.dayIndex(os.time()))
	return {
		coins = data.coins,
		totalFed = data.totalFed,
		rebirths = data.rebirths,
		level = level,
		levelProgress = progress,
		levelNext = nextNeed,
		upgrades = data.upgrades,
		foods = data.foods,
		selectedFood = data.selectedFood,
		ammo = s.ammo,
		capacity = stats.capacity,
		pets = data.pets,
		equipped = data.equipped,
		eggs = data.eggs,
		passes = data.passes,
		secrets = Util.count(data.secrets),
		quests = data.quests.list,
		canDaily = canDaily,
		nextDay = nextDay,
		streak = data.streak.count,
		stats = stats,
		bestCombo = data.stats.bestCombo,
		feasts = data.stats.feasts,
		survived = data.stats.survived,
		rebirthCost = Economy.rebirthCost(data.rebirths),
		temporary = s.temporary == true,
	}
end

local function syncPublic(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls["Pièces"].Value = data.coins
		ls["Nourri"].Value = data.totalFed
		ls["Renaissances"].Value = data.rebirths
	end
	local level = Economy.level(data.totalFed)
	player:SetAttribute("Level", level)
	player:SetAttribute("Pets", table.concat(data.equipped, ","))
	player:SetAttribute("PetMult", Economy.petBonus(data))
	player:SetAttribute("Vip", data.passes ~= nil and data.passes.vip == true)
end

function PlayerService.pushState(player: Player)
	if profiles[player] and sessions[player] then
		syncPublic(player)
		StateRemote:FireClient(player, snapshot(player))
	end
end

-- ---------------------------------------------------------------- cycle de vie

local function makeLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in ipairs({ "Pièces", "Nourri", "Renaissances" }) do
		local v = Instance.new("NumberValue")
		v.Name = name
		v.Value = 0
		v.Parent = folder
	end
	folder.Parent = player
end

function PlayerService.save(player: Player, release: boolean): boolean
	local data, s = profiles[player], sessions[player]
	if not data or not s or s.temporary then
		return false
	end
	local ok = DataService.save(player.UserId, data, release)
	for _, hook in ipairs(saveHooks) do
		task.spawn(hook, player, data)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	sessions[player] = { loaded = false, ammo = 0, combo = 0, lastHit = 0, lastThrow = 0, temporary = false, rate = {} }

	player.CharacterAdded:Connect(function(char)
		local s = sessions[player]
		if s and s.loaded then
			PlayerService.applyCharacter(player)
			for _, hook in ipairs(characterHooks) do
				task.spawn(hook, player, char)
			end
		end
	end)

	local data, err = DataService.load(player.UserId)
	if not player.Parent or not sessions[player] then
		if data then
			DataService.save(player.UserId, data, true)
		end
		return
	end
	local s = sessions[player]
	if not data then
		if err and string.find(err, "session", 1, true) then
			player:Kick("Ta partie est encore ouverte sur un autre serveur. Réessaie dans quelques secondes.")
			return
		end
		-- DataStore indisponible : on joue avec un profil temporaire non sauvegardé.
		warn("[FestinTRex] Chargement impossible pour " .. player.Name .. " : " .. tostring(err))
		data = Util.deepCopy(Config.Defaults)
		s.temporary = true
	end

	profiles[player] = data
	QuestLogic.ensure(data, Util.dayIndex(os.time()), player.UserId)
	if not data.foods[data.selectedFood] then
		data.selectedFood = "pomme"
	end
	s.ammo = Economy.stats(data).capacity
	makeLeaderstats(player)
	s.loaded = true

	for _, hook in ipairs(loadedHooks) do
		task.spawn(hook, player)
	end
	PlayerService.pushState(player)
	if s.temporary then
		PlayerService.notify(player, "Sauvegarde indisponible : ta progression ne sera pas enregistrée cette session.", "bad")
	end
	if player.Character then
		PlayerService.applyCharacter(player)
		for _, hook in ipairs(characterHooks) do
			task.spawn(hook, player, player.Character)
		end
	end
end

local function onPlayerRemoving(player: Player)
	PlayerService.save(player, true)
	profiles[player] = nil
	sessions[player] = nil
	dirty[player] = nil
end

function PlayerService.init()
	StateRemote = Remotes.get("State")
	NotifyRemote = Remotes.get("Notify")

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end

	-- Envoi groupé de l'état modifié (au plus ~5 fois par seconde et par joueur).
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in pairs(dirty) do
				dirty[player] = nil
				if player.Parent then
					PlayerService.pushState(player)
				end
			end
		end
	end)

	-- Sauvegarde automatique.
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(PlayerService.save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				PlayerService.save(player, true)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			task.wait(0.2)
			waited += 0.2
		end
	end)
end

return PlayerService
