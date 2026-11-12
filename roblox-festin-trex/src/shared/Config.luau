--!strict
-- Configuration centrale du jeu « Festin du T-Rex ».
-- Toutes les valeurs d'équilibrage sont ici : aucune valeur magique dans les services.

local Config: any = {}

Config.Name = "Festin du T-Rex"

Config.DataVersion = 1 -- à incrémenter + ajouter une migration dans DataService.Migrations pour tout changement NON additif

Config.Data = {
	StoreName = "FestinTRex_v1",
	FedBoardName = "FestinTRex_Fed_v1",
	AutosaveSeconds = 90,
	LockSeconds = 150, -- un verrou de session plus vieux que ça est considéré périmé
	LoadRetries = 6,
	LoadRetryDelay = 2,
}

-- Nourritures (ordre = ordre de déblocage). Shape : Ball / Block / Cylinder.
Config.Foods = {
	{ Id = "pomme", Name = "Pomme", Emoji = "🍎", Value = 10, Price = 0, Shape = "Ball", Size = { 1.4, 1.4, 1.4 }, Color = { 220, 40, 40 }, Material = "SmoothPlastic", Weight = 4 },
	{ Id = "burger", Name = "Burger", Emoji = "🍔", Value = 26, Price = 350, Shape = "Block", Size = { 1.7, 1.3, 1.7 }, Color = { 205, 133, 63 }, Material = "SmoothPlastic", Weight = 3 },
	{ Id = "pizza", Name = "Pizza", Emoji = "🍕", Value = 65, Price = 2200, Shape = "Cylinder", Size = { 0.4, 2.2, 2.2 }, Color = { 255, 190, 60 }, Material = "SmoothPlastic", Weight = 3 },
	{ Id = "donut", Name = "Donut", Emoji = "🍩", Value = 150, Price = 11000, Shape = "Cylinder", Size = { 0.8, 2.0, 2.0 }, Color = { 255, 130, 190 }, Material = "SmoothPlastic", Weight = 2 },
	{ Id = "gateau", Name = "Gâteau", Emoji = "🍰", Value = 340, Price = 55000, Shape = "Block", Size = { 2.0, 1.7, 2.0 }, Color = { 250, 240, 225 }, Material = "SmoothPlastic", Weight = 2 },
	{ Id = "dinde", Name = "Dinde dorée", Emoji = "🍗", Value = 900, Price = 280000, Shape = "Ball", Size = { 2.3, 2.3, 2.3 }, Color = { 255, 200, 40 }, Material = "Neon", Weight = 1 },
}

Config.Upgrades = {
	{ Id = "power", Name = "Bras musclé", Icon = "💪", Desc = "+7 studs de portée par niveau", Max = 10, BaseCost = 120, Growth = 1.7 },
	{ Id = "rate", Name = "Cadence", Icon = "⚡", Desc = "Lancers plus rapides", Max = 10, BaseCost = 150, Growth = 1.7 },
	{ Id = "basket", Name = "Grand panier", Icon = "🧺", Desc = "+2 nourritures par niveau", Max = 10, BaseCost = 100, Growth = 1.65 },
	{ Id = "greed", Name = "Gourmandise", Icon = "🪙", Desc = "+10% de pièces par niveau", Max = 15, BaseCost = 300, Growth = 1.75 },
	{ Id = "aim", Name = "Visée", Icon = "🎯", Desc = "Assistance de visée plus large", Max = 8, BaseCost = 200, Growth = 1.7 },
	{ Id = "boots", Name = "Bottes", Icon = "👟", Desc = "Course plus rapide", Max = 8, BaseCost = 180, Growth = 1.6 },
}

Config.Throw = {
	BaseRange = 60,
	RangePerLevel = 7,
	BaseCooldown = 1.0,
	CooldownPerLevel = 0.07,
	MinCooldown = 0.3,
	CooldownTolerance = 0.85, -- tolérance de latence côté serveur
	BaseCapacity = 6,
	CapacityPerLevel = 2,
	BaseAssist = 4,
	AssistPerLevel = 1.5,
	Speed = 70, -- studs/s, sert à déterminer la durée de vol
	MinFlight = 0.35,
	MaxFlight = 1.8,
	TrailTime = 1.0, -- temps de vol supplémentaire simulé après la cible
	StepsPerSecond = 30,
	MaxArenaRadius = 300,
	BaseWalkSpeed = 16,
	WalkPerLevel = 1.2,
}

Config.Combo = {
	Window = 5, -- secondes entre deux touches pour garder le combo
	PerStep = 0.05,
	Max = 30,
}

Config.FavoriteMult = 3
Config.HungryMult = 1.5

Config.RebirthBaseCost = 20000
Config.RebirthCostGrowth = 3
Config.RebirthBonus = 0.5 -- +50% de pièces permanent par renaissance

Config.Dino = {
	DecayPerSecond = 0.003, -- fraction du besoin perdue par seconde
	HungryFraction = 0.12,
	FavoriteEvery = 45,
	Stages = {
		{ Name = "Bébé Rex", Scale = 0.6, Need = 600 },
		{ Name = "Rex Junior", Scale = 0.8, Need = 1500 },
		{ Name = "Rex", Scale = 1.0, Need = 3500 },
		{ Name = "Rex Géant", Scale = 1.25, Need = 8000 },
		{ Name = "Titan Rex", Scale = 1.5, Need = 20000 },
	},
}

Config.Feast = {
	BaseCoins = 400,
	EggChance = 0.25,
	MinShareForEgg = 0.15,
}

-- Événements serveur périodiques.
Config.Events = {
	FirstDelay = 70,
	MinInterval = 150,
	MaxInterval = 230,
	Sauce = { Name = "Marée de sauce tomate", Warning = 9, Duration = 17, Height = 10, Reward = 350, Half = 340 },
	Rain = { Name = "Pluie gourmande", Warning = 5, Duration = 28, DropEvery = 0.45, DropValue = 30, DropLife = 14 },
	Frenzy = { Name = "Frénésie du festin", Warning = 4, Duration = 40, Mult = 2 },
}

-- Compagnons
Config.PetSlots = 3
Config.Rarities = {
	{ Id = "commun", Name = "Commun", Color = { 190, 190, 190 } },
	{ Id = "rare", Name = "Rare", Color = { 80, 160, 255 } },
	{ Id = "epique", Name = "Épique", Color = { 190, 90, 255 } },
	{ Id = "legendaire", Name = "Légendaire", Color = { 255, 190, 40 } },
	{ Id = "mythique", Name = "Mythique", Color = { 255, 80, 120 } },
}

Config.Pets = {
	{ Id = "poussin", Name = "Poussin Rex", Rarity = "commun", Mult = 0.05, Color = { 255, 225, 90 } },
	{ Id = "raptor", Name = "Mini Raptor", Rarity = "commun", Mult = 0.06, Color = { 110, 190, 90 } },
	{ Id = "gluant", Name = "Gluant", Rarity = "commun", Mult = 0.07, Color = { 120, 220, 200 } },
	{ Id = "stego", Name = "Stégo Bonbon", Rarity = "rare", Mult = 0.12, Color = { 255, 130, 170 } },
	{ Id = "tricera", Name = "Tricéra Pizza", Rarity = "rare", Mult = 0.15, Color = { 255, 170, 70 } },
	{ Id = "ptero", Name = "Ptéro Nuage", Rarity = "epique", Mult = 0.30, Color = { 190, 210, 255 } },
	{ Id = "ankylo", Name = "Ankylo Burger", Rarity = "epique", Mult = 0.35, Color = { 190, 120, 60 } },
	{ Id = "rexor", Name = "Rex Doré", Rarity = "legendaire", Mult = 0.70, Color = { 255, 200, 40 } },
	{ Id = "spino", Name = "Spino Glace", Rarity = "legendaire", Mult = 0.80, Color = { 120, 220, 255 } },
	{ Id = "dragon", Name = "Dragon Gourmand", Rarity = "mythique", Mult = 2.00, Color = { 255, 70, 90 } },
	{ Id = "arcenciel", Name = "Rex Arc-en-ciel", Rarity = "mythique", Mult = 2.50, Color = { 255, 120, 255 } },
}

-- Poids de tirage par rareté.
Config.Eggs = {
	classic = {
		Name = "Œuf du T-Rex",
		Emoji = "🥚",
		Price = 4000,
		Odds = { commun = 60, rare = 28, epique = 9, legendaire = 2.6, mythique = 0.4 },
	},
	gold = {
		Name = "Œuf doré",
		Emoji = "🌟",
		Price = 40000,
		Odds = { commun = 20, rare = 40, epique = 28, legendaire = 10, mythique = 2 },
	},
}
Config.DuplicateRefundFraction = 0.25 -- fraction du prix de l'œuf rendue pour un doublon déjà possédé

-- Quêtes quotidiennes : 3 tirées chaque jour parmi ces types.
Config.Quests = {
	{ Kind = "feed", Text = "Nourris le T-Rex %d fois", Targets = { 30, 60, 100 }, BaseCoins = 600, Mode = "add" },
	{ Kind = "combo", Text = "Atteins un combo de %d", Targets = { 8, 12, 18 }, BaseCoins = 700, Mode = "max" },
	{ Kind = "fav", Text = "Donne %d fois sa nourriture préférée", Targets = { 6, 12, 20 }, BaseCoins = 700, Mode = "add" },
	{ Kind = "survive", Text = "Survis à %d marée(s) de sauce", Targets = { 1, 2, 3 }, BaseCoins = 800, Mode = "add" },
	{ Kind = "feast", Text = "Participe à %d festin(s)", Targets = { 1, 2, 3 }, BaseCoins = 900, Mode = "add" },
	{ Kind = "earn", Text = "Gagne %d pièces", Targets = { 3000, 10000, 30000 }, BaseCoins = 600, Mode = "add" },
}
Config.QuestsPerDay = 3

-- Récompenses de connexion quotidienne (série de 7 jours).
Config.Daily = {
	{ Coins = 200, Eggs = 0 },
	{ Coins = 400, Eggs = 0 },
	{ Coins = 800, Eggs = 0 },
	{ Coins = 1500, Eggs = 0 },
	{ Coins = 3000, Eggs = 0 },
	{ Coins = 6000, Eggs = 0 },
	{ Coins = 10000, Eggs = 1 },
}

-- Fourchettes d'or cachées (secrets). La position est définie dans MapBuilder.
Config.SecretCount = 5
Config.SecretReward = { Coins = 1500, Eggs = 1 }
Config.SecretAllBonus = { Coins = 25000, Eggs = 2 }

-- Histoire : un chapitre par stade du T-Rex (affiché à chaque croissance et dans le panneau des quêtes).
Config.Story = {
	"Chapitre 1 — L'œuf tombé du ciel : un tout petit dino, Rex, a éclos sur la place du festin. Il a une faim de loup, et il a choisi TOI pour le nourrir.",
	"Chapitre 2 — Les premières dents : Rex grandit et réclame son plat préféré. Les habitants de l'île Miam découvrent qu'il est capable de rugir très fort.",
	"Chapitre 3 — La grande tablée : Rex est devenu un vrai T-Rex. La tablée entière se rassemble, mais une sauce tomate mystérieuse envahit l'île par vagues…",
	"Chapitre 4 — Le secret des fourchettes d'or : on raconte que cinq fourchettes dorées, cachées sur l'île, ouvrent la cuisine du Chef. Rex les cherche depuis toujours.",
	"Chapitre 5 — Titan Rex : Rex est le plus grand gourmand de l'île. Chaque festin est désormais une légende. Évolue encore pour le rendre inoubliable !",
}

-- Zones à débloquer : un coffre quotidien par zone. Niveau = niveau gourmet, Evolutions = renaissances.
Config.Chests = {
	chef = { Name = "Coffre du Chef", Emoji = "🧰", Zone = "Cuisine du Chef", MinLevel = 10, MinRebirths = 0, Coins = 3000, Eggs = 1, Pos = { 0, 0, -110 }, Color = { 255, 170, 60 } },
	titan = { Name = "Coffre du Titan", Emoji = "👑", Zone = "Terrasse du Titan", MinLevel = 25, MinRebirths = 1, Coins = 25000, Eggs = 2, Pos = { 150, 0, -130 }, Color = { 190, 110, 255 } },
}

-- Énigme du jour : une question par jour (QCM à 4 choix). Les bonnes réponses sont côté serveur (QuestService).
Config.RiddleTries = 3
Config.RiddleReward = { Coins = 1500, Eggs = 1 }
Config.Riddles = {
	{ Q = "Je suis rond, rouge et croquant, Rex m'adore en premier. Qui suis-je ?", Choices = { "Une pomme", "Une pierre", "Un ballon", "Une tomate" } },
	{ Q = "Combien de stades de croissance compte Rex ?", Choices = { "3", "4", "5", "6" } },
	{ Q = "Quelle marée envahit l'île par vagues ?", Choices = { "De sauce tomate", "De chocolat", "D'eau salée", "De lave" } },
	{ Q = "Combien de fourchettes d'or sont cachées sur l'île ?", Choices = { "3", "5", "7", "10" } },
	{ Q = "Que faut-il viser pour nourrir Rex ?", Choices = { "Ses yeux", "Sa queue", "Sa bouche", "Ses pieds" } },
	{ Q = "Où se réfugier pendant la marée de sauce ?", Choices = { "Sous un arbre", "Sur une table", "Près du dino", "Sur la place" } },
	{ Q = "Qu'est-ce qui augmente tes gains quand tu enchaînes les lancers ?", Choices = { "Le combo", "Le sommeil", "La pluie", "Le vent" } },
	{ Q = "Quelle rareté de compagnon est la plus puissante ?", Choices = { "Commun", "Rare", "Épique", "Mythique" } },
	{ Q = "Par combien la nourriture préférée de Rex multiplie-t-elle tes gains ?", Choices = { "x2", "x3", "x5", "x10" } },
	{ Q = "Que se passe-t-il quand la jauge de Rex est pleine ?", Choices = { "Il dort", "Un festin", "La nuit tombe", "Il s'en va" } },
	{ Q = "Comment s'appelle la renaissance dans le jeu ?", Choices = { "Évolution", "Reset", "Retour", "Fusion" } },
	{ Q = "Où se trouve le Coffre du Chef ?", Choices = { "Derrière Rex", "Au point d'arrivée", "Dans une table", "Sous la place" } },
}

-- Sons intégrés au client Roblox (rbxasset://). Remplaçables par vos propres ids.
Config.Sounds = {
	Throw = "rbxasset://sounds/swoosh.wav",
	Munch = "rbxasset://sounds/splat.wav",
	Thud = "rbxasset://sounds/snap.mp3",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Roar = "rbxasset://sounds/impact_explosion_03.mp3",
	Wave = "rbxasset://sounds/impact_water.mp3",
	Success = "rbxasset://sounds/bass.wav",
}

-- Monétisation. Id = 0 : désactivé (affiché « Bientôt »). Renseigner les ids créés sur le Creator Dashboard.
Config.Monetization = {
	Passes = {
		vip = { Id = 0, Name = "VIP Gourmet", Emoji = "👑", Desc = "+50% de pièces, pour toujours", Price = 399 },
		nest = { Id = 0, Name = "Nid agrandi", Emoji = "🪺", Desc = "+1 emplacement de compagnon", Price = 199 },
		aim = { Id = 0, Name = "Super visée", Emoji = "🎯", Desc = "Assistance de visée x2", Price = 149 },
	},
	Products = {
		coins_s = { Id = 0, Name = "Sac de pièces", Emoji = "💰", Desc = "5 000 pièces (x bonus d'évolution)", Price = 49, Coins = 5000 },
		coins_l = { Id = 0, Name = "Coffre de pièces", Emoji = "🧰", Desc = "75 000 pièces (x bonus d'évolution)", Price = 449, Coins = 75000 },
		eggs = { Id = 0, Name = "Pack de 5 œufs", Emoji = "🥚", Desc = "5 œufs du T-Rex", Price = 99, Eggs = 5 },
	},
	MaxReceipts = 200,
}

Config.Defaults = {
	passes = {},
	receipts = {},
	version = 1,
	coins = 0,
	totalFed = 0,
	rebirths = 0,
	upgrades = {},
	foods = { pomme = true },
	selectedFood = "pomme",
	pets = {},
	equipped = {},
	eggs = 1,
	secrets = {},
	chests = {},
	riddle = { day = 0, solved = false, tries = 0 },
	quests = { day = 0, list = {} },
	streak = { last = 0, count = 0 },
	stats = { bestCombo = 0, feasts = 0, survived = 0, hits = 0, riddles = 0 },
}

return Config
