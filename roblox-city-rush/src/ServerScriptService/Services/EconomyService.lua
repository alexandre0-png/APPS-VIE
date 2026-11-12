--[[
	EconomyService : argent, XP/niveaux, statistiques, succès, récompense quotidienne,
	achat de véhicules, état envoyé au client.
	Toutes les modifications d'état passent par ici (autorité serveur).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local RemoteService = require(script.Parent.RemoteService)

local EconomyService = {}

local passes = {} -- [player] = { VIP = bool, BOOST = bool }
local stateDirty = {}
EconomyService.DoubleXP = false
EconomyService.LevelUp = Util.newSignal() -- (player, newLevel)

local function profileOf(player)
	return DataService.get(player)
end

local function dailyInfo(profile)
	local today = os.time() // 86400
	local available = profile.Daily.day < today
	local streak = profile.Daily.streak
	if available then
		streak = (profile.Daily.day == today - 1) and (streak + 1) or 1
	end
	local capped = math.min(streak, Config.Daily.MaxStreak)
	return available, streak, Config.Daily.Base + Config.Daily.PerStreak * (capped - 1)
end

function EconomyService.hasPass(player, key)
	return passes[player] ~= nil and passes[player][key] == true
end

function EconomyService.setPass(player, key, value)
	passes[player] = passes[player] or {}
	passes[player][key] = value
	stateDirty[player] = true
end

function EconomyService.canUseVehicle(player, id)
	local profile = profileOf(player)
	local spec = Config.getVehicle(id)
	if not profile or not spec then
		return false
	end
	if spec.gamepass then
		return EconomyService.hasPass(player, spec.gamepass)
	end
	return profile.Owned[id] == true
end

local function buildState(player, profile)
	local daily, streak, reward = dailyInfo(profile)
	local owned = {}
	for _, v in ipairs(Config.Vehicles) do
		if EconomyService.canUseVehicle(player, v.id) then
			owned[v.id] = true
		end
	end
	return {
		Cash = profile.Cash,
		Level = profile.Level,
		XP = profile.XP,
		XPNeed = Config.xpForNext(profile.Level),
		Owned = owned,
		Colors = profile.Colors,
		Stats = profile.Stats,
		Achv = profile.Achv,
		Vip = EconomyService.hasPass(player, "VIP"),
		Boost = EconomyService.hasPass(player, "BOOST"),
		DailyAvailable = daily,
		DailyStreak = streak,
		DailyReward = reward,
		DoubleXP = EconomyService.DoubleXP,
		ServerTime = os.time(),
	}
end

local function updateLeaderstats(player, profile)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local cash = ls:FindFirstChild("Argent")
	local lvl = ls:FindFirstChild("Niveau")
	if cash then
		cash.Value = math.floor(profile.Cash)
	end
	if lvl then
		lvl.Value = profile.Level
	end
end

function EconomyService.pushState(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	updateLeaderstats(player, profile)
	RemoteService.fire("State", player, buildState(player, profile))
end

function EconomyService.markState(player)
	stateDirty[player] = true
end

function EconomyService.notify(player, text, kind)
	RemoteService.notify(player, text, kind)
end

-- ====================================================================
-- Argent
-- ====================================================================
function EconomyService.getCash(player)
	local p = profileOf(player)
	return p and p.Cash or 0
end

-- Gain "gagné" : applique le multiplicateur VIP. Retourne le montant réellement crédité.
function EconomyService.addCash(player, amount, reason)
	local profile = profileOf(player)
	if not profile or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	if EconomyService.hasPass(player, "VIP") then
		amount *= 2
	end
	amount = math.floor(amount)
	profile.Cash += amount
	profile.PeakCash = math.max(profile.PeakCash, profile.Cash)
	DataService.markDirty(player)
	stateDirty[player] = true
	return amount
end

-- Crédit brut (achats Robux, remboursements) sans multiplicateur
function EconomyService.grantCashRaw(player, amount)
	local profile = profileOf(player)
	if not profile or amount <= 0 then
		return
	end
	profile.Cash += math.floor(amount)
	profile.PeakCash = math.max(profile.PeakCash, profile.Cash)
	DataService.markDirty(player)
	stateDirty[player] = true
end

function EconomyService.spendCash(player, amount)
	local profile = profileOf(player)
	if not profile or amount < 0 or profile.Cash < amount then
		return false
	end
	profile.Cash -= amount
	DataService.markDirty(player)
	stateDirty[player] = true
	return true
end

-- Retire jusqu'à `amount` (arrestation). Retourne le montant perdu.
function EconomyService.loseCash(player, amount)
	local profile = profileOf(player)
	if not profile then
		return 0
	end
	local lost = math.max(0, math.min(profile.Cash, math.floor(amount)))
	profile.Cash -= lost
	DataService.markDirty(player)
	stateDirty[player] = true
	return lost
end

-- ====================================================================
-- XP / niveau
-- ====================================================================
function EconomyService.addXP(player, amount)
	local profile = profileOf(player)
	if not profile or amount <= 0 then
		return
	end
	if EconomyService.DoubleXP then
		amount *= 2
	end
	profile.XP += math.floor(amount)
	while profile.Level < Config.MaxLevel and profile.XP >= Config.xpForNext(profile.Level) do
		profile.XP -= Config.xpForNext(profile.Level)
		profile.Level += 1
		local bonus = 100 * profile.Level
		profile.Cash += bonus
		RemoteService.notify(player, string.format("NIVEAU %d ! Bonus %s", profile.Level, Util.formatCash(bonus)), "levelup")
		EconomyService.LevelUp:Fire(player, profile.Level)
	end
	if profile.Level >= Config.MaxLevel then
		profile.XP = 0
	end
	DataService.markDirty(player)
	stateDirty[player] = true
end

-- ====================================================================
-- Statistiques & succès
-- ====================================================================
function EconomyService.checkAchievements(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	for _, a in ipairs(Config.Achievements) do
		if not profile.Achv[a.id] and (profile.Stats[a.stat] or 0) >= a.goal then
			profile.Achv[a.id] = true
			local paid = EconomyService.addCash(player, a.reward, "achievement")
			RemoteService.notify(player, string.format("Succès : %s  (+%s)", a.name, Util.formatCash(paid)), "achv")
			DataService.markDirty(player)
		end
	end
end

function EconomyService.addStat(player, stat, n)
	local profile = profileOf(player)
	if not profile then
		return
	end
	profile.Stats[stat] = (profile.Stats[stat] or 0) + (n or 1)
	DataService.markDirty(player)
	stateDirty[player] = true
	EconomyService.checkAchievements(player)
end

function EconomyService.setStatMax(player, stat, value)
	local profile = profileOf(player)
	if profile and value > (profile.Stats[stat] or 0) then
		profile.Stats[stat] = value
		DataService.markDirty(player)
		EconomyService.checkAchievements(player)
	end
end

function EconomyService.addDistance(player, studs)
	local profile = profileOf(player)
	if not profile or studs <= 0 then
		return
	end
	profile.Stats.studs += studs
	local km = profile.Stats.studs * 0.00028
	if math.floor(km) ~= math.floor(profile.Stats.km) then
		profile.Stats.km = km
		EconomyService.checkAchievements(player)
		stateDirty[player] = true
	else
		profile.Stats.km = km
	end
	DataService.markDirty(player)
end

-- ====================================================================
-- Actions client -> serveur
-- ====================================================================
local function onBuy(player, vehicleId)
	local profile = profileOf(player)
	local spec = Config.getVehicle(vehicleId)
	if not profile or not spec or spec.price <= 0 then
		return
	end
	if profile.Owned[vehicleId] then
		RemoteService.notify(player, "Tu possèdes déjà ce véhicule.", "info")
		return
	end
	if profile.Level < spec.level then
		RemoteService.notify(player, string.format("Niveau %d requis.", spec.level), "bad")
		return
	end
	if not EconomyService.spendCash(player, spec.price) then
		RemoteService.notify(player, "Pas assez d'argent !", "bad")
		return
	end
	profile.Owned[vehicleId] = true
	DataService.markDirty(player)
	RemoteService.notify(player, string.format("Achat : %s !", spec.name), "good")
	EconomyService.pushState(player)
end

local function onColor(player, vehicleId, index)
	local profile = profileOf(player)
	if not profile or not EconomyService.canUseVehicle(player, vehicleId) then
		return
	end
	if index ~= math.floor(index) or index < 1 or index > #Config.VehicleColors then
		return
	end
	profile.Colors[vehicleId] = index
	DataService.markDirty(player)
	stateDirty[player] = true
end

local function onClaimDaily(player)
	local profile = profileOf(player)
	if not profile then
		return
	end
	local available, streak, reward = dailyInfo(profile)
	if not available then
		return
	end
	profile.Daily.day = os.time() // 86400
	profile.Daily.streak = streak
	local paid = EconomyService.addCash(player, reward, "daily")
	RemoteService.notify(player, string.format("Récompense quotidienne : %s (série %d)", Util.formatCash(paid), streak), "good")
	DataService.markDirty(player)
	EconomyService.pushState(player)
end

local function setupPlayer(player, profile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Argent"
	cash.Parent = ls
	local lvl = Instance.new("IntValue")
	lvl.Name = "Niveau"
	lvl.Parent = ls
	ls.Parent = player
	updateLeaderstats(player, profile)
	EconomyService.checkAchievements(player)
	EconomyService.pushState(player)
end

function EconomyService.init()
	DataService.Loaded:Connect(setupPlayer)

	RemoteService.on("RequestBuy", 0.5, function(id)
		return type(id) == "string" and #id < 24
	end, onBuy)
	RemoteService.on("RequestColor", 0.3, function(id, i)
		return type(id) == "string" and #id < 24 and type(i) == "number"
	end, onColor)
	RemoteService.on("ClaimDaily", 1, nil, onClaimDaily)
	RemoteService.on("RequestState", 1, nil, function(player)
		EconomyService.pushState(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		passes[player] = nil
		stateDirty[player] = nil
	end)

	Util.supervise("EconomyService", function()
		while true do
			task.wait(0.25)
			for player in pairs(stateDirty) do
				stateDirty[player] = nil
				if player.Parent then
					EconomyService.pushState(player)
				end
			end
		end
	end)
end

return EconomyService
