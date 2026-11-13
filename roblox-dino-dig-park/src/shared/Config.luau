-- Config.luau : toutes les données d'équilibrage et de contenu du jeu.
-- Partagé client/serveur. Aucune logique Roblox ici, seulement des données.

local Config = {}

Config.GameName = "Dino Dig Park"
Config.DataStoreName = "DinoDigPark_v1"
Config.LeaderboardStoreName = "DinoDigPark_Lb_v1"
Config.DataVersion = 1

Config.PlotCount = 10
Config.SaveInterval = 60
Config.LockTimeout = 150 -- secondes avant qu'un verrou de session soit considéré périmé

-- Économie générale
Config.BaseSlots = 4 -- emplacements de dinos dans l'enclos 1
Config.SlotsPerPen = 4
Config.GoldenChance = 0.02 -- chance d'un dino doré à l'éclosion
Config.GoldenMultiplier = 3
Config.CollectionBonus = 0.02 -- +2% de revenus par dino découvert
Config.RebirthIncomeBonus = 0.5
Config.RebirthFossilBonus = 0.25
Config.BoothSeconds = 900 -- le kiosque stocke 15 minutes de revenus
Config.OfflineMaxSeconds = 7200
Config.OfflineEfficiency = 0.5
Config.CritMultiplier = 5
Config.DigCooldown = 0.12
Config.StartFossils = 20
Config.StartCash = 0

-- Gamepasses / produits : mettre les vrais IDs Roblox ici (0 = désactivé, caché dans le jeu)
Config.Passes = {
	doubleCash = { id = 0, name = "Revenus x2", desc = "Double tous les revenus du parc, pour toujours.", price = 399 },
	autoDig = { id = 0, name = "Fouille automatique", desc = "Creuse tout seul quand tu es dans la zone de fouille.", price = 249 },
	fastHatch = { id = 0, name = "Éclosion rapide", desc = "Les œufs éclosent 2 fois plus vite.", price = 299 },
	turbo = { id = 0, name = "Mode turbo", desc = "Cours beaucoup plus vite dans ton parc.", price = 199 },
}
Config.TurboWalkSpeed = 26
Config.Products = {
	fossilPack = { id = 0, name = "Pack de fossiles", desc = "Reçois 10 minutes de fouille de pointe.", price = 49 },
	cashPack = { id = 0, name = "Pack de pièces", desc = "Reçois 30 minutes de revenus du parc.", price = 99 },
	boostPack = { id = 0, name = "Boost x2 (10 min)", desc = "Revenus doublés pendant 10 minutes.", price = 79 },
	starterPack = { id = 0, name = "Pack de départ", desc = "600 fossiles et un Œuf Jungle offert pour démarrer vite.", price = 59 },
}

-- Sons : IDs rbxasset natifs du moteur Roblox (remplaçables par des rbxassetid://)
Config.Sounds = {
	click = "rbxasset://sounds/button.wav",
	buy = "rbxasset://sounds/electronicpingshort.wav",
	dig = "rbxasset://sounds/snap.mp3",
	hatch = "rbxasset://sounds/victory.wav",
	error = "rbxasset://sounds/bass.mp3",
}

----------------------------------------------------------------------
-- RARETÉS
----------------------------------------------------------------------
Config.RarityOrder = { "commun", "peucommun", "rare", "epique", "legendaire", "mythique" }
Config.RarityById = {
	commun = { id = "commun", name = "Commun", color = Color3.fromRGB(190, 190, 190), income = 1, order = 1 },
	peucommun = { id = "peucommun", name = "Peu commun", color = Color3.fromRGB(110, 220, 110), income = 2, order = 2 },
	rare = { id = "rare", name = "Rare", color = Color3.fromRGB(80, 160, 255), income = 5, order = 3 },
	epique = { id = "epique", name = "Épique", color = Color3.fromRGB(190, 100, 255), income = 14, order = 4 },
	legendaire = { id = "legendaire", name = "Légendaire", color = Color3.fromRGB(255, 170, 40), income = 60, order = 5 },
	mythique = { id = "mythique", name = "Mythique", color = Color3.fromRGB(255, 80, 120), income = 400, order = 6 },
}

----------------------------------------------------------------------
-- DINOSAURES (18)
----------------------------------------------------------------------
-- archetype : forme de blocs définie dans DinoShapes
Config.Dinos = {
	{
		id = "compy",
		name = "Compy",
		rarity = "commun",
		archetype = "raptor",
		scale = 0.55,
		body = Color3.fromRGB(120, 190, 90),
		accent = Color3.fromRGB(240, 220, 120),
	},
	{
		id = "psitta",
		name = "Psitta",
		rarity = "commun",
		archetype = "tricera",
		scale = 0.5,
		body = Color3.fromRGB(210, 180, 120),
		accent = Color3.fromRGB(150, 110, 70),
	},
	{
		id = "dryo",
		name = "Dryo",
		rarity = "commun",
		archetype = "stego",
		scale = 0.45,
		body = Color3.fromRGB(150, 120, 90),
		accent = Color3.fromRGB(230, 200, 100),
	},

	{
		id = "velo",
		name = "Vélo",
		rarity = "peucommun",
		archetype = "raptor",
		scale = 0.8,
		body = Color3.fromRGB(230, 130, 50),
		accent = Color3.fromRGB(60, 40, 30),
	},
	{
		id = "kentro",
		name = "Kentro",
		rarity = "peucommun",
		archetype = "stego",
		scale = 0.6,
		body = Color3.fromRGB(60, 170, 170),
		accent = Color3.fromRGB(250, 240, 200),
	},
	{
		id = "para",
		name = "Para",
		rarity = "peucommun",
		archetype = "bronto",
		scale = 0.45,
		body = Color3.fromRGB(140, 160, 70),
		accent = Color3.fromRGB(220, 220, 130),
	},

	{
		id = "tricera",
		name = "Tricéra",
		rarity = "rare",
		archetype = "tricera",
		scale = 0.9,
		body = Color3.fromRGB(110, 140, 170),
		accent = Color3.fromRGB(240, 230, 200),
	},
	{
		id = "stego",
		name = "Stégo",
		rarity = "rare",
		archetype = "stego",
		scale = 0.95,
		body = Color3.fromRGB(120, 90, 160),
		accent = Color3.fromRGB(130, 220, 120),
	},
	{
		id = "anky",
		name = "Ankylo",
		rarity = "rare",
		archetype = "ankylo",
		scale = 0.9,
		body = Color3.fromRGB(150, 100, 60),
		accent = Color3.fromRGB(230, 160, 70),
	},

	{
		id = "rex",
		name = "T-Rex",
		rarity = "epique",
		archetype = "trex",
		scale = 1.0,
		body = Color3.fromRGB(70, 130, 70),
		accent = Color3.fromRGB(200, 220, 110),
	},
	{
		id = "brachio",
		name = "Brachio",
		rarity = "epique",
		archetype = "bronto",
		scale = 1.0,
		body = Color3.fromRGB(100, 170, 220),
		accent = Color3.fromRGB(240, 240, 255),
	},
	{
		id = "ptera",
		name = "Ptéra",
		rarity = "epique",
		archetype = "ptero",
		scale = 1.0,
		body = Color3.fromRGB(230, 130, 120),
		accent = Color3.fromRGB(255, 220, 160),
	},

	{
		id = "spino",
		name = "Spino",
		rarity = "legendaire",
		archetype = "spino",
		scale = 0.95,
		body = Color3.fromRGB(40, 150, 150),
		accent = Color3.fromRGB(255, 140, 40),
	},
	{
		id = "dilopho",
		name = "Dilopho",
		rarity = "legendaire",
		archetype = "dilopho",
		scale = 1.0,
		body = Color3.fromRGB(190, 60, 60),
		accent = Color3.fromRGB(255, 200, 60),
	},
	{
		id = "carno",
		name = "Carno",
		rarity = "legendaire",
		archetype = "carno",
		scale = 1.0,
		body = Color3.fromRGB(170, 50, 40),
		accent = Color3.fromRGB(240, 230, 210),
	},

	{
		id = "crystal",
		name = "Rex Cristal",
		rarity = "mythique",
		archetype = "trex",
		scale = 1.1,
		body = Color3.fromRGB(120, 230, 255),
		accent = Color3.fromRGB(255, 255, 255),
		material = "Glass",
		neon = true,
	},
	{
		id = "galaxy",
		name = "Brachio Galaxie",
		rarity = "mythique",
		archetype = "bronto",
		scale = 1.1,
		body = Color3.fromRGB(90, 60, 200),
		accent = Color3.fromRGB(255, 120, 255),
		material = "Neon",
	},
	{
		id = "aurore",
		name = "Aurore",
		rarity = "mythique",
		archetype = "ptero",
		scale = 1.2,
		body = Color3.fromRGB(255, 130, 190),
		accent = Color3.fromRGB(255, 240, 150),
		material = "Neon",
		secret = true,
	},
}
Config.DinoById = {}
Config.DinosByRarity = {}
for _, rid in ipairs(Config.RarityOrder) do
	Config.DinosByRarity[rid] = {}
end
for _, d in ipairs(Config.Dinos) do
	Config.DinoById[d.id] = d
	if not d.secret then
		table.insert(Config.DinosByRarity[d.rarity], d)
	end
end
Config.GoldBoneCount = 5 -- os dorés cachés ; tous trouvés = dino secret
Config.SecretDinoId = "aurore"

----------------------------------------------------------------------
-- ŒUFS
----------------------------------------------------------------------
Config.EggOrder = { "basic", "jungle", "volcano", "cosmic" }
Config.Eggs = {
	basic = {
		id = "basic",
		name = "Œuf Fossile",
		cost = 30,
		time = 10,
		color = Color3.fromRGB(235, 225, 195),
		spot = Color3.fromRGB(160, 130, 90),
		weights = { commun = 75, peucommun = 22, rare = 3 },
	},
	jungle = {
		id = "jungle",
		name = "Œuf Jungle",
		cost = 300,
		time = 90,
		color = Color3.fromRGB(120, 200, 110),
		spot = Color3.fromRGB(40, 110, 50),
		weights = { commun = 20, peucommun = 50, rare = 27, epique = 3 },
	},
	volcano = {
		id = "volcano",
		name = "Œuf Volcan",
		cost = 3000,
		time = 600,
		color = Color3.fromRGB(230, 90, 50),
		spot = Color3.fromRGB(60, 30, 30),
		weights = { peucommun = 15, rare = 55, epique = 28, legendaire = 2 },
	},
	cosmic = {
		id = "cosmic",
		name = "Œuf Cosmique",
		cost = 30000,
		time = 1800,
		color = Color3.fromRGB(110, 70, 230),
		spot = Color3.fromRGB(255, 230, 120),
		weights = { rare = 10, epique = 62, legendaire = 25, mythique = 3 },
	},
}

----------------------------------------------------------------------
-- AMÉLIORATIONS (niveaux répétables)
----------------------------------------------------------------------
Config.UpgradeOrder = { "shovel", "luck", "hatch", "ticket" }
Config.Upgrades = {
	shovel = {
		id = "shovel",
		name = "Pelle en or",
		icon = "⛏",
		currency = "cash",
		base = 50,
		growth = 1.55,
		max = 25,
		desc = "+1 fossile par coup de pelle et fouille auto plus rapide.",
	},
	luck = {
		id = "luck",
		name = "Radar à fossiles",
		icon = "📡",
		currency = "cash",
		base = 200,
		growth = 1.7,
		max = 15,
		desc = "+2% de trouvailles x5 et plus de chance de dinos rares.",
	},
	hatch = {
		id = "hatch",
		name = "Incubateur turbo",
		icon = "🔥",
		currency = "fossils",
		base = 40,
		growth = 1.6,
		max = 15,
		desc = "-4% de temps d'éclosion par niveau (max -60%).",
	},
	ticket = {
		id = "ticket",
		name = "Prix du billet",
		icon = "🎟",
		currency = "fossils",
		base = 60,
		growth = 1.75,
		max = 20,
		desc = "+10% de revenus du parc par niveau.",
	},
}

----------------------------------------------------------------------
-- BÂTIMENTS ACHETABLES (coordonnées locales à la parcelle : -Z = face à l'entrée)
----------------------------------------------------------------------
Config.PlotWidth = 120
Config.PlotDepth = 160

Config.Pens = {
	{ index = 1, center = Vector3.new(-32, 0, -52) },
	{ index = 2, center = Vector3.new(32, 0, -52) },
	{ index = 3, center = Vector3.new(-32, 0, -24) },
	{ index = 4, center = Vector3.new(32, 0, -24) },
	{ index = 5, center = Vector3.new(-32, 0, 4) },
	{ index = 6, center = Vector3.new(32, 0, 4) },
}
Config.PenSize = Vector3.new(36, 0, 26)

Config.GateCenter = Vector3.new(0, 0, -76)
Config.BoothCenter = Vector3.new(0, 0, 32)
Config.BoothPad = Vector3.new(0, 0, 24)
Config.DigCenter = Vector3.new(-32, 0, 60)
Config.DigRadius = 24
Config.LabCenter = Vector3.new(32, 0, 59)
Config.Stands = {
	Vector3.new(21, 0, 60),
	Vector3.new(29, 0, 60),
	Vector3.new(37, 0, 60),
	Vector3.new(45, 0, 60),
}
Config.HelipadCenter = Vector3.new(2, 0, 68)

-- kind : pen | incubator | digger | shop | helipad
Config.Buildables = {
	{ id = "pen2", kind = "pen", name = "Enclos Forêt", cost = 600, pad = Vector3.new(9, 0, -52), index = 2 },
	{ id = "pen3", kind = "pen", name = "Enclos Volcan", cost = 6000, requires = "pen2", pad = Vector3.new(-9, 0, -24), index = 3 },
	{ id = "pen4", kind = "pen", name = "Enclos Lagon", cost = 60000, requires = "pen3", pad = Vector3.new(9, 0, -24), index = 4 },
	{ id = "pen5", kind = "pen", name = "Enclos Glacier", cost = 450000, requires = "pen4", pad = Vector3.new(-9, 0, 4), index = 5 },
	{ id = "pen6", kind = "pen", name = "Enclos Royal", cost = 3000000, requires = "pen5", pad = Vector3.new(9, 0, 4), index = 6 },

	{ id = "incub2", kind = "incubator", name = "Incubateur 2", cost = 1000, pad = Vector3.new(29, 0, 40), index = 2 },
	{
		id = "incub3",
		kind = "incubator",
		name = "Incubateur 3",
		cost = 12000,
		requires = "incub2",
		pad = Vector3.new(37, 0, 40),
		index = 3,
	},
	{
		id = "incub4",
		kind = "incubator",
		name = "Incubateur 4",
		cost = 90000,
		requires = "incub3",
		pad = Vector3.new(45, 0, 40),
		index = 4,
	},

	{ id = "digger1", kind = "digger", name = "Ouvrier 1", cost = 300, pad = Vector3.new(-45, 0, 40), index = 1 },
	{ id = "digger2", kind = "digger", name = "Ouvrier 2", cost = 2500, requires = "digger1", pad = Vector3.new(-37, 0, 40), index = 2 },
	{ id = "digger3", kind = "digger", name = "Ouvrier 3", cost = 20000, requires = "digger2", pad = Vector3.new(-29, 0, 40), index = 3 },
	{ id = "digger4", kind = "digger", name = "Ouvrier 4", cost = 150000, requires = "digger3", pad = Vector3.new(-21, 0, 40), index = 4 },

	{
		id = "cafe",
		kind = "shop",
		name = "Café du parc",
		cost = 2000,
		bonus = 0.20,
		center = Vector3.new(-24, 0, 30),
		pad = Vector3.new(-24, 0, 21.5),
		color = Color3.fromRGB(200, 130, 80),
	},
	{
		id = "gift",
		kind = "shop",
		name = "Boutique cadeaux",
		cost = 10000,
		requires = "cafe",
		bonus = 0.20,
		center = Vector3.new(24, 0, 30),
		pad = Vector3.new(24, 0, 21.5),
		color = Color3.fromRGB(90, 150, 220),
	},
	{
		id = "hotel",
		kind = "shop",
		name = "Hôtel safari",
		cost = 120000,
		requires = "gift",
		bonus = 0.30,
		center = Vector3.new(-46, 0, 30),
		pad = Vector3.new(-46, 0, 21.5),
		color = Color3.fromRGB(230, 200, 120),
	},
	{
		id = "ride",
		kind = "shop",
		name = "Grande roue",
		cost = 900000,
		requires = "hotel",
		bonus = 0.40,
		center = Vector3.new(46, 0, 28),
		pad = Vector3.new(46, 0, 21.5),
		color = Color3.fromRGB(220, 90, 110),
	},

	{ id = "helipad", kind = "helipad", name = "Hélipad (collecte auto)", cost = 50000, requires = "cafe", pad = Vector3.new(2, 0, 58) },
}
Config.BuildableById = {}
Config.BuildableOrder = {}
for i, b in ipairs(Config.Buildables) do
	Config.BuildableById[b.id] = b
	Config.BuildableOrder[b.id] = i
end

----------------------------------------------------------------------
-- RENAISSANCE
----------------------------------------------------------------------
Config.RebirthBaseCost = 60000000
Config.RebirthGrowth = 6
Config.RebirthMax = 50

----------------------------------------------------------------------
-- RÉCOMPENSES QUOTIDIENNES (cycle de 7 jours)
----------------------------------------------------------------------
Config.DailyRewards = {
	{ kind = "fossils", amount = 60, label = "60 🦴" },
	{ kind = "cash", minutes = 10, label = "10 min de revenus" },
	{ kind = "fossils", amount = 200, label = "200 🦴" },
	{ kind = "egg", egg = "jungle", label = "Œuf Jungle" },
	{ kind = "cash", minutes = 30, label = "30 min de revenus" },
	{ kind = "fossils", amount = 800, label = "800 🦴" },
	{ kind = "egg", egg = "volcano", label = "Œuf Volcan" },
}

----------------------------------------------------------------------
-- QUÊTES QUOTIDIENNES
----------------------------------------------------------------------
Config.QuestTypes = {
	{ id = "dig", text = "Creuse %d fois", targets = { 40, 80, 150 }, reward = { fossils = 40 } },
	{ id = "hatch", text = "Fais éclore %d œufs", targets = { 2, 3, 5 }, reward = { minutes = 8 } },
	{ id = "collect", text = "Collecte %d pièces au kiosque", targets = { 1, 1, 1 }, reward = { fossils = 30 }, scaled = true },
	{ id = "buy", text = "Achète %d bâtiments", targets = { 1, 2, 3 }, reward = { minutes = 10 } },
	{ id = "upgrade", text = "Achète %d améliorations", targets = { 1, 2, 3 }, reward = { fossils = 50 } },
}
Config.QuestCount = 3

-- Événement serveur : pluie de météores
Config.Event = {
	interval = 600, -- toutes les 10 minutes
	duration = 60,
	spawnEvery = 2.5,
	maxAlive = 4,
}

----------------------------------------------------------------------
-- NIVEAU DU PARC : portes fermées tant que la collection n'est pas assez grande
----------------------------------------------------------------------
-- nombre de dinos différents découverts pour atteindre le niveau 2, 3, 4...
Config.LevelThresholds = { 3, 6, 9, 12, 15 }
Config.LevelReq = {
	incub3 = 2,
	digger3 = 2,
	pen3 = 2,
	pen4 = 3,
	incub4 = 3,
	digger4 = 3,
	helipad = 3,
	pen5 = 4,
	hotel = 4,
	pen6 = 5,
	ride = 5,
}
Config.EggLevel = { volcano = 3, cosmic = 5 }
for _, b in ipairs(Config.Buildables) do
	b.level = Config.LevelReq[b.id] or 1
end
for id, e in pairs(Config.Eggs) do
	e.level = Config.EggLevel[id] or 1
end
Config.MaxLevel = #Config.LevelThresholds + 1

----------------------------------------------------------------------
-- AVENTURE : l'histoire du Professeur Rex, chapitres à débloquer dans l'ordre
-- cond.type : digs | hatched | collected | buildable | discovered | level | bones | rebirths
----------------------------------------------------------------------
Config.Story = {
	{
		title = "Le terrain du Professeur",
		text = "Le Professeur Rex t'a légué un vieux terrain de fouille. Creuse pour trouver des fossiles !",
		cond = { type = "digs", target = 10 },
		reward = { fossils = 30 },
	},
	{
		title = "L'œuf mystère",
		text = "Au laboratoire, un fossile peut redonner vie à un dinosaure. Fais éclore ton premier œuf.",
		cond = { type = "hatched", target = 1 },
		reward = { egg = "basic" },
	},
	{
		title = "Les portes s'ouvrent",
		text = "Les visiteurs arrivent ! Collecte tes premières pièces au kiosque.",
		cond = { type = "collected", target = 100 },
		reward = { fossils = 60 },
	},
	{
		title = "Un enclos de plus",
		text = "Les dinos ont besoin de place. Ouvre l'enclos Forêt.",
		cond = { type = "buildable", id = "pen2" },
		reward = { cashMinutes = 5 },
	},
	{
		title = "L'équipe de fouille",
		text = "Embauche un premier ouvrier : il creuse même quand tu es ailleurs.",
		cond = { type = "buildable", id = "digger1" },
		reward = { fossils = 150 },
	},
	{
		title = "Le collectionneur",
		text = "Découvre 6 dinos différents pour passer au niveau 3 et ouvrir de nouvelles portes.",
		cond = { type = "discovered", target = 6 },
		reward = { egg = "jungle" },
	},
	{
		title = "Directeur de parc",
		text = "Atteins le niveau 4 : les enclos Glacier et l'hôtel t'attendent.",
		cond = { type = "level", target = 4 },
		reward = { cashMinutes = 20 },
	},
	{
		title = "Le secret du Professeur",
		text = "Cinq os dorés sont cachés autour du lobby. Trouve-les tous !",
		cond = { type = "bones", target = 5 },
		reward = { egg = "volcano" },
	},
	{
		title = "Le premier mystère",
		text = "Le Professeur laisse chaque jour une énigme. Résous-en 3 (bouton Énigme).",
		cond = { type = "riddles", target = 3 },
		reward = { fossils = 200 },
	},
	{
		title = "Une nouvelle ère",
		text = "Prends ta première renaissance : tout recommence, en plus puissant.",
		cond = { type = "rebirths", target = 1 },
		reward = { egg = "cosmic" },
	},
}

----------------------------------------------------------------------
-- ÉNIGMES : une énigme du Professeur par jour (choix multiple, réponse vérifiée côté serveur)
----------------------------------------------------------------------
Config.Riddles = {
	{
		q = "Quel dinosaure a trois cornes sur la face ?",
		options = { "Tricératops", "Stégosaure", "Tyrannosaure" },
		answer = 1,
		hint = "Son nom veut dire « face à trois cornes ».",
	},
	{
		q = "Quel dinosaure porte de grandes plaques osseuses sur le dos ?",
		options = { "Brachiosaure", "Stégosaure", "Vélociraptor" },
		answer = 2,
		hint = "Il a aussi des piques au bout de la queue.",
	},
	{
		q = "Lequel est un très grand carnivore, avec une voile sur le dos ?",
		options = { "Compsognathus", "Parasaurolophus", "Spinosaure" },
		answer = 3,
		hint = "Il pêchait des poissons dans l'eau.",
	},
	{
		q = "Quel reptile volait au temps des dinosaures ?",
		options = { "Ankylosaure", "Ptéranodon", "Diplodocus" },
		answer = 2,
		hint = "Il n'était pas un dinosaure, mais il avait des ailes.",
	},
	{
		q = "Que mange surtout le Brachiosaure ?",
		options = { "De la viande", "Des poissons", "Des plantes" },
		answer = 3,
		hint = "Il attrape les feuilles tout en haut des arbres.",
	},
	{
		q = "Quel dinosaure a une massue au bout de la queue ?",
		options = { "Ankylosaure", "Tricératops", "Allosaure" },
		answer = 1,
		hint = "Il est couvert d'une armure de plaques.",
	},
	{
		q = "Comment s'appelle la science qui étudie les fossiles ?",
		options = { "Astronomie", "Paléontologie", "Météorologie" },
		answer = 2,
		hint = "Le mot commence par « paléo », ancien.",
	},
	{
		q = "Sur combien de pattes marche le Tyrannosaure ?",
		options = { "Deux", "Quatre", "Six" },
		answer = 1,
		hint = "Ses bras sont minuscules.",
	},
	{
		q = "Un dinosaure qui ne mange que des plantes est un…",
		options = { "Carnivore", "Omnivore", "Herbivore" },
		answer = 3,
		hint = "Pense aux « herbes ».",
	},
	{
		q = "Combien d'os dorés faut-il trouver pour débloquer Aurore ?",
		options = { "Trois", "Cinq", "Sept" },
		answer = 2,
		hint = "Regarde la section Aventure.",
	},
	{
		q = "Que faut-il pour ouvrir un enclos fermé dans le parc ?",
		options = { "Des Robux", "Un ami", "Un niveau de parc suffisant" },
		answer = 3,
		hint = "Découvre plus de dinos différents.",
	},
	{
		q = "Quelle période est venue juste avant le Crétacé ?",
		options = { "Le Quaternaire", "Le Jurassique", "Le Néogène" },
		answer = 2,
		hint = "C'est le nom d'un célèbre film de dinosaures.",
	},
}
Config.RiddleReward = { fossilsPerLevel = 100, eggEvery = 3 } -- un œuf Jungle tous les 3 jours de série

----------------------------------------------------------------------
-- ANIMATIONS : chacune peut être désactivée ici (master = false coupe tout)
----------------------------------------------------------------------
Config.Animations = {
	master = true,
	dinoWalk = true, -- promenade des dinos dans leur enclos
	dinoBreath = true, -- respiration au repos
	hatchReaction = true, -- les dinos sautent de joie à l'éclosion
	digSwing = true, -- coup de pelle
	digDust = true, -- poussière de fouille
	fossilReveal = true, -- fossile qui apparaît
	collectionSpin = true, -- dinos qui tournent dans la collection
	coinBurst = true, -- pièces qui jaillissent du kiosque
	arrivalFx = true, -- onde d'arrivée d'un nouveau bâtiment
	doorOpen = true, -- barrières qui s'ouvrent sur un enclos débloqué
	panelFade = true, -- fondu des fenêtres
	staggerIn = true, -- lignes de quêtes qui apparaissent en cascade
	rewardPop = true, -- notifications qui "popent"
	counterTween = true, -- compteurs qui défilent
}

----------------------------------------------------------------------
-- CINÉMATIQUES : seulement aux moments clés, toutes skippables, jamais bloquantes
----------------------------------------------------------------------
Config.Cinematics = {
	enabled = true, -- interrupteur général
	intro = true, -- l'expédition arrive sur le site (environ 22 s)
	tutorial = true, -- mini tutoriel au premier lancement (fouiller, éclore, collecter)
	firstRare = true, -- premier dino rare ou mieux (environ 12 s)
	bigZone = true, -- ouverture d'un grand enclos (environ 12 s)
	bigZonePens = { pen5 = true, pen6 = true },
	minSeconds = 5,
	maxSeconds = 40,
}
-- ids mémorisés dans la sauvegarde : une cinématique ne se rejoue pas
Config.CinematicIds = { intro = true, tutorial = true, firstRare = true, zone_pen5 = true, zone_pen6 = true }

----------------------------------------------------------------------
-- MODÈLES EXTERNES (boîte à outils Roblox) : chargés côté serveur uniquement, nettoyés, avec repli
----------------------------------------------------------------------
-- enabled = false : aucun chargement, les décors et modèles actuels restent en place.
-- Les modèles doivent être publics ou appartenir au créateur de l'expérience (sinon LoadAsset échoue et le repli s'applique).
Config.Assets = {
	enabled = true,
	timeout = 12, -- secondes maximum par modèle
	attempts = 2,
	maxParts = 1500, -- un modèle plus lourd est refusé
	museum = true, -- construit le musée du lobby (avec décors de repli construits par le code)
	digsiteDecor = true, -- plantes sur le site de fouille de chaque parcelle
	museumTrex = { enabled = false, ids = { 10683798442, 71422282686175 } }, -- T-Rex du musée : en option
	ids = {
		pottedPlant = 116741237427172, -- plante en pot d'intérieur
		windowPlant = 15078054751, -- plante de fenêtre
		sakura = 101176034116232, -- arbre Sakura
		diningTable = 1338860741, -- table de la salle d'exposition
	},
	targetHeights = { pottedPlant = 4, windowPlant = 3, sakura = 14, diningTable = 3.2, trex = 14 },
}

return Config
