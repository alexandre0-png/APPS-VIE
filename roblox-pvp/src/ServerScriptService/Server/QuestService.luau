--!nonstrict
-- Quêtes quotidiennes (renouvelées chaque jour UTC) et récompense de connexion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local QuestLogic = require(Shared.QuestLogic)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)

local QuestService = {}

-- Garantit que les quêtes correspondent au jour courant.
function QuestService.Ensure(player)
	local p = DataService.Get(player)
	if not p then
		return nil
	end
	local today = QuestLogic.DayKey(os.time())
	if p.Quests == nil or p.Quests.Day ~= today then
		p.Quests = QuestLogic.NewState(today)
	end
	return p.Quests
end

-- Évènement de jeu : "Kill" | "Headshot" | "Streak" | "Win" | "MatchPlayed" | "Damage"
function QuestService.Notify(player, event, amount, class)
	local state = QuestService.Ensure(player)
	if state and QuestLogic.Apply(state, event, amount, class) then
		PlayerService.Sync(player)
		-- toast quand une quête vient d'être terminée
		for _, entry in ipairs(state.List) do
			local def = QuestLogic.Get(entry.Id)
			if def and def.Event == event and entry.Progress >= def.Target and not entry.Notified then
				entry.Notified = true
				PlayerService.Notify(player, "Quest", ("Quête terminée : %s"):format(def.Title))
			end
		end
	end
end

function QuestService.Claim(player, questId)
	local state = QuestService.Ensure(player)
	if not state or type(questId) ~= "string" then
		return false, "Quête introuvable"
	end
	for _, entry in ipairs(state.List) do
		if entry.Id == questId then
			local def = QuestLogic.Get(entry.Id)
			if not def or entry.Claimed then
				return false, "Déjà récupérée"
			end
			if entry.Progress < def.Target then
				return false, "Quête non terminée"
			end
			entry.Claimed = true
			PlayerService.AddCoins(player, def.Coins)
			PlayerService.AddXP(player, def.XP)
			PlayerService.Notify(player, "Reward", ("+%d pièces  +%d XP"):format(def.Coins, def.XP))
			return true, "Récompense récupérée"
		end
	end
	return false, "Quête introuvable"
end

function QuestService.ClaimDaily(player)
	local p = DataService.Get(player)
	if not p then
		return false, "Profil indisponible"
	end
	local today = QuestLogic.DayKey(os.time())
	if p.LastDaily >= today then
		return false, "Déjà récupérée aujourd'hui"
	end
	if p.LastDaily > 0 and today - p.LastDaily == 1 then
		p.DailyStreak += 1
	else
		p.DailyStreak = 1
	end
	local index = ((p.DailyStreak - 1) % #Config.DailyRewards) + 1
	local coins = Config.DailyRewards[index]
	p.LastDaily = today
	if player:GetAttribute("HasVIP") then
		coins = math.floor(coins * 1.5)
	end
	PlayerService.AddCoins(player, coins, true)
	PlayerService.Notify(player, "Reward", ("Cadeau quotidien : +%d pièces (jour %d)"):format(coins, index))
	PlayerService.Sync(player)
	return true, ("+%d pièces"):format(coins)
end

return QuestService
