--!nonstrict
-- Saison : points (éliminations, victoires, parties), palier réclamables une fois, titre de fin de saison.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent
local Config = require(Shared.Config)
local SeasonLogic = require(Shared.SeasonLogic)
local DataService = require(Server.DataService)
local PlayerService = require(Server.PlayerService)

local SeasonService = {}

local function state(player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	if type(profile.Season) ~= "table" then
		profile.Season = { Id = 0, Points = 0, Claimed = {} }
	end
	SeasonLogic.Rollover(profile.Season, Config.Season.Id)
	return profile.Season
end

-- Appelé à l'ouverture de session et à chaque gain.
function SeasonService.Refresh(player)
	local s = state(player)
	if s then
		local top = s.Claimed[tostring(Config.Season.Tiers)] == true
		player:SetAttribute("SeasonChampion", top)
		PlayerService.Sync(player)
	end
end

-- kind : "Kill" | "Assist" | "Match" | "Win"
function SeasonService.Add(player, kind)
	local s = state(player)
	local gain = Config.Season.Points[kind]
	if not s or not gain then
		return
	end
	local before = SeasonLogic.Tier(s.Points, Config.Season.TierPoints, Config.Season.Tiers)
	s.Points += gain
	local after = SeasonLogic.Tier(s.Points, Config.Season.TierPoints, Config.Season.Tiers)
	if after > before then
		PlayerService.Notify(player, "Quest", ("Saison : palier %d atteint !"):format(after))
	end
	PlayerService.Sync(player)
end

function SeasonService.ClaimTier(player, tier)
	local s = state(player)
	if not s or type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or tier > Config.Season.Tiers then
		return false, "Palier inconnu"
	end
	if SeasonLogic.Tier(s.Points, Config.Season.TierPoints, Config.Season.Tiers) < tier then
		return false, "Palier non atteint"
	end
	if s.Claimed[tostring(tier)] then
		return false, "Déjà récupéré"
	end
	s.Claimed[tostring(tier)] = true
	local coins = SeasonLogic.TierCoins(tier, Config.Season.CoinsPerTier)
	PlayerService.AddCoins(player, coins, true)
	PlayerService.Notify(player, "Reward", ("Palier %d : +%d pièces"):format(tier, coins))
	SeasonService.Refresh(player)
	return true, "Récompense récupérée"
end

return SeasonService
