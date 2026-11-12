--!strict
-- Configuration globale du jeu "Arène des Légendes".
-- Toutes les valeurs d'équilibrage sont centralisées ici.

local Config = {}

Config.GameName = "Arène des Légendes"
Config.MaxLevel = 50

Config.Player = {
	MaxHealth = 100,
	WalkSpeed = 17,
	JumpPower = 52,
}

Config.Match = {
	IntermissionSeconds = 12,
	MatchSeconds = 180,
	ResultsSeconds = 10,
	FFAScoreLimit = 20,
	TeamScoreLimit = 30,
	SpawnProtection = 3,
	RespawnSeconds = 3,
	Modes = { "FFA", "TEAM", "FFA", "TEAM" }, -- rotation
}

Config.ModeNames = {
	FFA = "Mêlée générale",
	TEAM = "Guerre des couleurs",
}

Config.TeamNames = { Red = "Rouges", Blue = "Bleus" }
Config.TeamColors = {
	Red = "E74C3C",
	Blue = "3498DB",
}

Config.Rewards = {
	KillCoins = 15,
	KillXP = 40,
	HeadshotCoins = 5,
	StreakCoinStep = 2,
	StreakCoinCap = 20,
	AssistCoins = 6,
	AssistXP = 15,
	AssistWindow = 10,
	BountyMinStreak = 5,
	BountyPerStreak = 10,
	BountyCap = 200,
	WinCoins = 120,
	WinXP = 150,
	ParticipationCoins = 25,
	ParticipationXP = 40,
	FarmFreeKills = 3, -- éliminations consécutives de la même victime avant réduction
	FarmMultiplier = 0.25,
}

Config.HealthPack = { Heal = 45, Respawn = 15 }
Config.RageOrb = { Duration = 12, Multiplier = 1.5, Respawn = 45 }

-- Achats intégrés. Id = 0 : désactivé (bouton « Bientôt »). Renseigner les Id créés dans le Creator Hub.
-- Aucun achat ne donne de dégâts supplémentaires : seulement du confort et de la progression.
Config.Monetization = {
	Passes = {
		{ Key = "DoubleXP", Id = 0, Name = "XP x2", Desc = "Double l'expérience gagnée, à vie.", Price = 199 },
		{ Key = "DoubleCoins", Id = 0, Name = "Pièces x2", Desc = "Double les pièces gagnées au combat, à vie.", Price = 299 },
		{ Key = "VIP", Id = 0, Name = "VIP", Desc = "Étiquette ★ VIP au-dessus de la tête, +50% au cadeau quotidien.", Price = 399 },
	},
	Products = {
		{ Key = "Coins500", Id = 0, Name = "500 pièces", Coins = 500, Price = 49 },
		{ Key = "Coins1500", Id = 0, Name = "1 500 pièces", Coins = 1500, Price = 129 },
		{ Key = "Coins5000", Id = 0, Name = "5 000 pièces", Coins = 5000, Price = 349 },
	},
	MaxReceipts = 200,
}

Config.DailyRewards = { 50, 75, 100, 150, 200, 300, 500 }

Config.Titles = {
	{ 1, "Recrue" },
	{ 5, "Soldat" },
	{ 10, "Gladiateur" },
	{ 20, "Champion" },
	{ 30, "Légende" },
	{ 45, "Mythe" },
}

Config.Rarities = {
	["Commune"] = "B8C0CC",
	["Rare"] = "4DA3FF",
	["Épique"] = "B05CFF",
	["Légendaire"] = "FFB020",
}

Config.Loadout = { Slots = 3 }

Config.DataStore = {
	Name = "ArenaProfiles_v1",
	LeaderboardName = "ArenaKills_v1",
	AutosaveSeconds = 60,
	LeaderboardRefresh = 90,
}

-- Sons intégrés au client Roblox (rbxasset://). Remplaçables par des IDs uploadés.
Config.Sounds = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Heavy = "rbxasset://sounds/swordlunge.wav",
	Shot = "rbxasset://sounds/electronicpingshort.wav",
	Hit = "rbxasset://sounds/button.wav",
	Kill = "rbxasset://sounds/bass.wav",
	Equip = "rbxasset://sounds/unsheath.wav",
}

return Config
