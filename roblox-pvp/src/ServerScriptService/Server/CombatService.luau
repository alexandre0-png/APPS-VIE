--!nonstrict
-- Cœur du combat : application des dégâts (autorité serveur), journal pour les
-- éliminations/assistances, récompenses, séries, primes et kill-feed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local Combat = require(Shared.Combat)
local MatchLogic = require(Shared.MatchLogic)
local Remotes = require(Shared.Remotes)
local PlayerService = require(Server.PlayerService)
local QuestService = require(Server.QuestService)
local DataService = require(Server.DataService)

local CombatService = {}

local killCallbacks = {}
local repeatKills = {} -- [killerUserId] = { Victim = userId, Count = n }
local logs = {} -- [Humanoid] = { Entries = {[userId] = {Player, Time}}, Last = {...} }
local tracked = setmetatable({}, { __mode = "k" })

function CombatService.OnKill(fn)
	table.insert(killCallbacks, fn)
end

-- Vrai si `attacker` peut blesser `victim` (deux joueurs) selon l'état de la partie.
function CombatService.CanDamagePlayers(attacker, victim)
	if attacker == victim then
		return false
	end
	if workspace:GetAttribute("MatchState") ~= "Playing" then
		return false
	end
	if not attacker:GetAttribute("InArena") or not victim:GetAttribute("InArena") then
		return false
	end
	if workspace:GetAttribute("MatchMode") == "TEAM" then
		local ta, tv = attacker:GetAttribute("Team"), victim:GetAttribute("Team")
		if ta ~= "" and ta == tv then
			return false
		end
	end
	return true
end

local function boostMultiplier(player)
	local untilT = player:GetAttribute("BoostUntil") or 0
	if untilT > workspace:GetServerTimeNow() then
		return Config.RageOrb.Multiplier
	end
	return nil
end

-- Coup d'un bot sur un joueur (même règles : manche en cours, joueur dans l'arène, pas de ForceField).
function CombatService.BotDamage(botModel, victimPlayer, amount)
	local character = victimPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or workspace:GetAttribute("MatchState") ~= "Playing" then
		return 0
	end
	if not victimPlayer:GetAttribute("InArena") or character:FindFirstChildOfClass("ForceField") then
		return 0
	end
	CombatService.Track(humanoid)
	local entry = logs[humanoid]
	if not entry then
		entry = { Entries = {} }
		logs[humanoid] = entry
	end
	entry.Last = { BotName = botModel:GetAttribute("BotName") or "Bot", Time = os.clock() }
	local dealt = math.min(amount, humanoid.Health)
	humanoid:TakeDamage(amount)
	local root = botModel:FindFirstChild("HumanoidRootPart")
	Remotes.Hit:FireClient(victimPlayer, { Kind = "Taken", Amount = dealt, From = root and root.Position or nil })
	return dealt
end

function CombatService.Heal(humanoid, amount)
	if humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
end

-- Applique des dégâts à un modèle. Renvoie (dégâts infligés, éliminé ?).
-- opts : Weapon (WeaponDef), Headshot, Backstab, Falloff, Origin (Vector3)
function CombatService.DealDamage(attacker, targetModel, baseDamage, opts)
	opts = opts or {}
	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return 0, false
	end
	local victimPlayer = Players:GetPlayerFromCharacter(targetModel)
	if victimPlayer then
		if not CombatService.CanDamagePlayers(attacker, victimPlayer) then
			return 0, false
		end
	elseif not targetModel:GetAttribute("Dummy") then
		return 0, false
	elseif targetModel:GetAttribute("Bot") and workspace:GetAttribute("MatchState") ~= "Playing" then
		return 0, false -- les bots ne sont blessables que pendant une manche
	end
	if targetModel:FindFirstChildOfClass("ForceField") then
		return 0, false
	end

	local weapon = opts.Weapon
	local damage = Combat.ComputeDamage(baseDamage, {
		Headshot = opts.Headshot,
		HeadshotMult = weapon and weapon.HeadshotMult,
		Backstab = opts.Backstab,
		BackstabMult = weapon and weapon.BackstabMult,
		Boost = boostMultiplier(attacker),
		Falloff = opts.Falloff,
	})

	CombatService.Track(humanoid)
	local entry = logs[humanoid]
	if not entry then
		entry = { Entries = {} }
		logs[humanoid] = entry
	end
	local now = os.clock()
	entry.Entries[attacker.UserId] = { Player = attacker, Time = now }
	entry.Last = { Player = attacker, Time = now, Weapon = weapon, Headshot = opts.Headshot == true }

	local before = humanoid.Health
	humanoid:TakeDamage(damage)
	local dealt = math.min(damage, before)
	local killed = humanoid.Health <= 0

	-- retours visuels
	local root = targetModel:FindFirstChild("HumanoidRootPart")
	local pos = root and root.Position or Vector3.zero
	Remotes.Hit:FireClient(attacker, { Kind = "Dealt", Amount = dealt, Headshot = opts.Headshot == true, Killed = killed, Pos = pos + Vector3.new(0, 3, 0) })
	if victimPlayer then
		Remotes.Hit:FireClient(victimPlayer, { Kind = "Taken", Amount = dealt, From = opts.Origin })
		local profile = DataService.Get(attacker)
		if profile then
			profile.DamageDealt += dealt
		end
		QuestService.Notify(attacker, "Damage", dealt)
	end
	if weapon and weapon.LifeSteal and attacker.Character then
		local ah = attacker.Character:FindFirstChildOfClass("Humanoid")
		if ah then
			CombatService.Heal(ah, dealt * weapon.LifeSteal)
		end
	end
	return dealt, killed
end

-- Mort instantanée environnementale (lave...). Le dernier agresseur récent reste crédité.
function CombatService.EnvironmentKill(humanoid)
	if humanoid.Health > 0 then
		CombatService.Track(humanoid)
		humanoid.Health = 0
	end
end

local function teamOf(player)
	if player and workspace:GetAttribute("MatchMode") == "TEAM" then
		return player:GetAttribute("Team")
	end
	return ""
end

-- Un joueur élimine un bot : petite récompense, pas de série ni de quête (anti-farm).
local function onBotDied(entry, model)
	local last = entry and entry.Last
	local killer = last and last.Player
	if not killer or killer.Parent ~= Players or os.clock() - last.Time > Config.Rewards.AssistWindow or not killer:GetAttribute("InArena") then
		return
	end
	local B = Config.Bots
	PlayerService.AddCoins(killer, B.RewardCoins)
	PlayerService.AddXP(killer, B.RewardXP)
	PlayerService.Notify(killer, "Kill", model:GetAttribute("BotName") or "Bot", { Coins = B.RewardCoins, XP = B.RewardXP })
	Remotes.Feed:FireAllClients({
		Killer = killer.DisplayName,
		Victim = model:GetAttribute("BotName") or "Bot",
		Weapon = last.Weapon and last.Weapon.Name or nil,
		Headshot = last.Headshot,
		KillerTeam = teamOf(killer),
		VictimTeam = "",
	})
end

local function onDied(humanoid)
	local model = humanoid.Parent
	local victim = model and Players:GetPlayerFromCharacter(model)
	local entry = logs[humanoid]
	logs[humanoid] = nil
	if not victim then
		if model and model:GetAttribute("Bot") then
			onBotDied(entry, model)
		end
		return
	end

	local window = Config.Rewards.AssistWindow
	local now = os.clock()
	local killer, last
	local botName
	if entry and entry.Last and now - entry.Last.Time <= window then
		if entry.Last.BotName then
			botName = entry.Last.BotName
		elseif entry.Last.Player.Parent == Players then
			killer, last = entry.Last.Player, entry.Last
		end
	end
	if killer == victim then
		killer = nil
	end

	local victimStreak = victim:GetAttribute("Streak") or 0
	victim:SetAttribute("Streak", 0)
	PlayerService.Increment(victim, "Deaths", 1)

	local weaponName = last and last.Weapon and last.Weapon.Name or (botName and "Griffes" or nil)
	PlayerService.Notify(victim, "Death", killer and killer.DisplayName or botName or "", {
		Weapon = weaponName,
		Seconds = Config.Match.RespawnSeconds,
		Headshot = last and last.Headshot or false,
	})

	Remotes.Feed:FireAllClients({
		Killer = killer and killer.DisplayName or botName,
		Victim = victim.DisplayName,
		Weapon = weaponName,
		Headshot = last and last.Headshot or false,
		KillerTeam = teamOf(killer),
		VictimTeam = teamOf(victim),
	})

	if not killer or not killer:GetAttribute("InArena") then
		return
	end

	-- récompenses de l'éliminateur
	local R = Config.Rewards
	local streak = (killer:GetAttribute("Streak") or 0) + 1
	killer:SetAttribute("Streak", streak)
	local coins = R.KillCoins + math.min(R.StreakCoinCap, (streak - 1) * R.StreakCoinStep)
	local xp = R.KillXP
	-- anti-farm : à partir de la 4e élimination consécutive de la même victime, gains réduits
	local rk = repeatKills[killer.UserId]
	if rk and rk.Victim == victim.UserId then
		rk.Count += 1
	else
		rk = { Victim = victim.UserId, Count = 1 }
		repeatKills[killer.UserId] = rk
	end
	local farmed = rk.Count > R.FarmFreeKills
	if farmed then
		coins = math.floor(coins * R.FarmMultiplier)
		xp = math.floor(xp * R.FarmMultiplier)
	end
	local headshot = last.Headshot
	local profile = DataService.Get(killer)
	if headshot then
		coins += R.HeadshotCoins
		if profile then
			profile.Headshots += 1
		end
		QuestService.Notify(killer, "Headshot", 1)
	end
	local bounty = farmed and 0 or MatchLogic.Bounty(victimStreak, R.BountyMinStreak, R.BountyPerStreak, R.BountyCap)
	coins += bounty

	PlayerService.Increment(killer, "Kills", 1)
	if profile and streak > profile.BestStreak then
		profile.BestStreak = streak
	end
	PlayerService.AddCoins(killer, coins)
	PlayerService.AddXP(killer, xp)
	QuestService.Notify(killer, "Kill", 1, last.Weapon and last.Weapon.Class or nil)
	QuestService.Notify(killer, "Streak", streak)

	PlayerService.Notify(killer, "Kill", victim.DisplayName, {
		Coins = coins,
		XP = xp,
		Streak = streak,
		Headshot = headshot,
		Bounty = bounty,
		Label = MatchLogic.StreakLabel(streak),
	})

	-- assistances
	if entry then
		for userId, a in pairs(entry.Entries) do
			if a.Player ~= killer and a.Player ~= victim and a.Player.Parent == Players and now - a.Time <= window then
				PlayerService.AddCoins(a.Player, R.AssistCoins)
				PlayerService.AddXP(a.Player, R.AssistXP)
				PlayerService.Notify(a.Player, "Assist", victim.DisplayName, { Coins = R.AssistCoins })
			end
		end
	end

	for _, fn in ipairs(killCallbacks) do
		task.spawn(fn, killer, victim, { Weapon = last.Weapon, Headshot = headshot })
	end
end

-- Surveille la mort d'un Humanoid (idempotent).
function CombatService.Track(humanoid)
	if tracked[humanoid] then
		return
	end
	tracked[humanoid] = true
	humanoid.Died:Connect(function()
		onDied(humanoid)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	repeatKills[player.UserId] = nil
end)

function CombatService.Init()
	PlayerService.CharacterCallbacks[#PlayerService.CharacterCallbacks + 1] = function(_player, character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			CombatService.Track(humanoid)
		end
	end
end

return CombatService
