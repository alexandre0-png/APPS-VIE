-- Configuration centrale de Saute-Troupeau (Herd Hopper).
-- Toutes les valeurs d'équilibrage sont ici : on peut régler le jeu sans toucher aux systèmes.

local Config = {}

Config.Gravity = 90

-- Piste : axe +Z = sens de la course. Le sol est à Y = 0.
Config.Track = {
	HalfWidth = 62, -- limite latérale des bêtes (studs)
	WallX = 82, -- murs invisibles
	FinishZ = 3200, -- ligne d'arrivée
	FloorTop = 0,
	StartZ = 0,
}

-- Le salon est un grand parc : chaque joueur y a une parcelle (son zoo).
Config.Hub = {
	Center = Vector3.new(0, 320, -720),
	PlotSize = 84,
	PlotSpacing = 96,
	Columns = 4,
	Rows = 4,
	SlotColumns = 6,
	SlotSpacing = 12,
}

-- Une expédition dure 4 minutes au maximum. Les joueurs prêts partent ensemble.
Config.Round = {
	Intermission = 20,
	Countdown = 5,
	Duration = 240,
	Results = 12,
	MinPlayers = 1,
}

Config.Ride = {
	LaunchUp = 58, -- vitesse verticale du bond
	LaunchBoost = 18, -- vitesse avant ajoutée à celle de la bête
	AirLateral = 26, -- contrôle latéral en l'air
	AirMax = 2.4, -- durée max d'un vol avant chute forcée (s)
	SteerSpeed = 30, -- vitesse latérale d'une monture pilotée
	HookBaseRange = 58,
	HookRangePerLevel = 5,
	HookCooldown = 0.3,
	HookTolerance = 14, -- marge serveur pour la latence
	ComboWindowBase = 6,
	ComboWindowPerLevel = 0.6,
	ComboStep = 0.2,
	ComboMax = 10,
	DownTime = 1.0,
	BuckWarning = 1.2,
}

-- Vies, cœurs et lasso de capture.
Config.Run = {
	BaseLives = 1,
	ReviveWindow = 12, -- secondes pour acheter « Continuer » après une mort
	CollectWindow = 4, -- secondes pour récupérer un animal dompté avant qu'il ne s'enfuie
	BaseLasso = 3,
	LassoRange = 70,
	LassoCooldown = 2,
	LassoBaseChance = 0.9,
	LassoVariantPenalty = 0.15,
	BossRideTime = 9,
	BossBuckAfter = 3,
}

Config.Score = {
	RidePerSecond = 4,
	HookBonus = 15,
	LongHookDistance = 40,
	LongHookBonus = 25,
	DistanceFactor = 0.1,
	TameBase = 100,
	Finish = { 500, 300, 200 },
	FinishOther = 100,
	CapturePoints = 150,
}

Config.Tame = {
	PerLevel = 0.08, -- réduction du temps de dressage par niveau
	MinTime = 2.5,
}

-- Or gagné en fin d'expédition (le zoo en rapporte en plus, voir Config.Zoo).
Config.Rewards = {
	ScoreToCoins = 0.05,
	Place = { 80, 50, 30 },
	Participation = 15,
	CaptureGold = 20, -- × valeur × variante
	NewDiscovery = 40,
	SpeciesComplete = 250,
}

Config.Variants = {
	{ id = 1, name = "Normal", mult = 1, weight = 80 },
	{ id = 2, name = "Cristal", mult = 2, weight = 15 },
	{ id = 3, name = "Doré", mult = 4, weight = 5 },
}

-- Audio. Les musiques sont volontairement vides : aucun morceau libre de droits n'est fourni avec le jeu.
-- Colle ici des identifiants "rbxassetid://..." de morceaux dont tu as les droits (bibliothèque audio Roblox,
-- Creator Store ou fichiers à toi). Une chaîne vide = pas de musique pour ce lieu.
Config.Audio = {
	MusicVolume = 0.3,
	SfxVolume = 0.8,
	FadeSeconds = 2.5,
	Music = {
		lobby = "",
		savane = "",
		marais = "",
		desert = "",
		volcan = "",
		boss = "",
		results = "",
	},
}

-- Animations : chaque animation se coupe ici (Enabled = interrupteur général). Toutes sont encapsulées en pcall :
-- une animation qui échoue ne peut pas casser le jeu. Ton joyeux, aucun effet violent ni sanglant.
Config.Animations = {
	Enabled = true,
	Walk = true, -- cycle de marche, pattes repliées en saut, ailes
	Jump = true, -- bondissement des animaux joyeux (saut)
	HeartReact = true, -- réaction à l'apparition du cœur (pop, étincelles, petit trot)
	Capture = true, -- l'animal capturé s'envole en tournoyant
	Joy = true, -- joie des animaux qui arrivent au zoo
	Lasso = true, -- lancer, boucle qui se resserre, bras du joueur
	ZoneIntro = true, -- survol de la zone au départ
	ZoneTransition = true, -- balayage de couleur entre deux zones
	Boss = true, -- piétinements, nuage d'arrivée, coup de zoom
	Death = true, -- nuage de fumée, étoiles, estompage, écran grisé
}

Config.Events = {
	FirstDelay = 14,
	MinGap = 11,
	MaxGap = 19,
	GeyserRadius = 15,
	StrikeRadius = 17,
	Telegraph = 2.0,
}

-- Équipement d'expédition (acheté avec de l'or dans la boutique).
Config.Upgrades = {
	{
		id = "range",
		name = "Corde longue",
		desc = "Portée du lasso de saut +5 m par niveau.",
		max = 5,
		costs = { 150, 300, 550, 900, 1400 },
	},
	{
		id = "taming",
		name = "Dresseur rapide",
		desc = "Temps pour gagner la confiance d'un animal -8 % par niveau.",
		max = 5,
		costs = { 150, 300, 550, 900, 1400 },
	},
	{
		id = "combo",
		name = "Souffle de combo",
		desc = "Fenêtre de combo +0,6 s par niveau.",
		max = 5,
		costs = { 200, 400, 700, 1100, 1600 },
	},
}

-- Améliorations du zoo (or).
Config.ZooUpgrades = {
	{
		id = "slots",
		name = "Enclos supplémentaires",
		desc = "+2 enclos par niveau.",
		max = 6,
		costs = { 150, 300, 600, 1100, 1800, 2800 },
	},
	{
		id = "visitors",
		name = "Visiteurs",
		desc = "+10 % de revenu du zoo par niveau.",
		max = 10,
		costs = { 200, 350, 550, 800, 1100, 1500, 2000, 2600, 3400, 4500 },
	},
	{
		id = "storage",
		name = "Caisse du zoo",
		desc = "+10 min de revenus stockés par niveau.",
		max = 5,
		costs = { 150, 300, 600, 1000, 1600 },
	},
	{
		id = "gift",
		name = "Boutique de souvenirs",
		desc = "+10 % d'or par expédition par niveau.",
		max = 5,
		costs = { 250, 500, 900, 1500, 2400 },
	},
	{
		id = "lasso",
		name = "Sac à lassos",
		desc = "+1 lasso de capture par expédition par niveau.",
		max = 3,
		costs = { 300, 800, 1800 },
	},
	{
		id = "hearts",
		name = "Appâts à cœurs",
		desc = "+4 % de chance de voir un cœur sur un animal par niveau.",
		max = 5,
		costs = { 300, 600, 1000, 1600, 2500 },
	},
}

-- Économie du zoo. Revenu par minute d'un animal = IncomePerMinute × valeur × variante × (1 + LevelBonus × (niveau - 1)).
Config.Zoo = {
	BaseSlots = 6,
	SlotsPerLevel = 2,
	PassSlots = 6,
	MaxSlots = 24,
	IncomePerMinute = 6,
	LevelBonus = 0.4,
	VisitorBonus = 0.1,
	PassVisitorFactor = 1.5,
	StorageBaseMinutes = 20,
	StoragePerLevel = 10,
	MaxAnimalLevel = 10,
	BoneCostBase = 3,
	BoneCostGrowth = 1.6,
	BoneCostByVariant = { 1, 1.5, 2.5 },
	DuplicateBones = 4, -- × variante ; les boss rapportent BossBones
	BossBones = 30,
	GiftBonus = 0.1,
	HeartBonus = 0.04,
	BoostMinutes = 30,
	BoostFactor = 2,
	MaxOfflineMinutes = 600,
}

Config.Hats = {
	{ id = "none", name = "Aucun chapeau", price = 0 },
	{ id = "beanie", name = "Bonnet à pompon", price = 200 },
	{ id = "cowboy", name = "Chapeau de cow-boy", price = 250 },
	{ id = "viking", name = "Casque viking", price = 400 },
	{ id = "wizard", name = "Chapeau de sorcier", price = 500 },
	{ id = "dino", name = "Capuche de dino", price = 650 },
	{ id = "crown", name = "Couronne en or", price = 800 },
	{ id = "vip", name = "Cornes dorées VIP", price = 0, pass = "zoo" },
}

Config.Ropes = {
	{ id = "classic", name = "Corde de chanvre", price = 0, color = Color3.fromRGB(210, 170, 100), neon = false },
	{ id = "fire", name = "Corde de feu", price = 300, color = Color3.fromRGB(255, 110, 30), neon = true },
	{ id = "ice", name = "Corde glacée", price = 300, color = Color3.fromRGB(120, 220, 255), neon = true },
	{ id = "toxic", name = "Corde toxique", price = 400, color = Color3.fromRGB(120, 255, 80), neon = true },
	{ id = "royal", name = "Corde royale", price = 600, color = Color3.fromRGB(180, 90, 255), neon = true },
	{ id = "gold", name = "Corde dorée", price = 900, color = Color3.fromRGB(255, 210, 60), neon = true },
}

-- Achats Robux. Mets ici les identifiants créés sur le Creator Dashboard (voir docs/PUBLICATION.md).
-- Tant qu'un id vaut 0, l'objet s'affiche « Bientôt » et ne peut pas être acheté.
-- La partie de base (1 vie, 3 lassos, zoo de 6 enclos) reste entièrement gratuite.
Config.Monetization = {
	GamePasses = {
		{ key = "zoo", id = 0, name = "Zoo Premium", desc = "+6 enclos, visiteurs x1,5 et cornes dorées VIP." },
		{ key = "gold", id = 0, name = "Or x2", desc = "Double l'or gagné à chaque expédition." },
		{ key = "life", id = 0, name = "Vie supplémentaire", desc = "Une vie de plus à chaque expédition." },
		{ key = "lasso", id = 0, name = "Lasso doré", desc = "+2 lassos de capture et une portée plus longue." },
	},
	Products = {
		{ key = "gold_s", id = 0, kind = "gold", amount = 2000, name = "Bourse d'or (2 000)" },
		{ key = "gold_m", id = 0, kind = "gold", amount = 7000, name = "Coffre d'or (7 000)" },
		{ key = "gold_l", id = 0, kind = "gold", amount = 25000, name = "Trésor d'or (25 000)" },
		{ key = "bones_s", id = 0, kind = "bones", amount = 40, name = "Sac d'os (40)" },
		{ key = "bones_m", id = 0, kind = "bones", amount = 150, name = "Caisse d'os (150)" },
		{ key = "boost", id = 0, kind = "boost", amount = 30, name = "Boost de zoo x2 (30 min)" },
		{ key = "revive", id = 0, kind = "revive", amount = 1, name = "Continuer (1 vie)" },
	},
	LassoPassBonus = 2,
	LassoPassRange = 15,
	LifePassBonus = 1,
	GoldPassFactor = 2,
}

-- Quêtes quotidiennes : 3 tirées chaque jour. mode "add" = cumul, "max" = meilleure valeur.
Config.QuestPool = {
	{ id = "capture", label = "Récupérer %d animaux", target = 3, reward = 60, mode = "add" },
	{ id = "hooks", label = "Réussir %d sauts au lasso", target = 25, reward = 60, mode = "add" },
	{ id = "combo", label = "Atteindre un combo de %d", target = 6, reward = 80, mode = "max" },
	{ id = "distance", label = "Parcourir %d m en expédition", target = 1500, reward = 70, mode = "add" },
	{ id = "rounds", label = "Faire %d expéditions", target = 3, reward = 50, mode = "add" },
	{ id = "score", label = "Marquer %d points en une expédition", target = 900, reward = 90, mode = "max" },
	{ id = "rare", label = "Récupérer %d animal Cristal ou Doré", target = 1, reward = 100, mode = "add" },
	{ id = "zone", label = "Atteindre la zone %d", target = 2, reward = 90, mode = "max" },
}

-- Énigme du jour : on devine l'animal, puis on le récupère (n'importe quelle version) pour toucher la récompense.
-- La réponse n'est jamais envoyée au client.
Config.RiddleReward = { gold = 100, bones = 10 }
Config.Riddles = {
	{ answer = "boar", text = "Je fouille la savane avec mes défenses et je ne vais jamais droit. Qui suis-je ?" },
	{
		answer = "zebra",
		text = "Mon pelage est un code-barres vivant, et je cours plus vite que la plupart. Qui suis-je ?",
	},
	{ answer = "ostrich", text = "Mes pattes sont longues, mon cou aussi, et je ne sais pas voler. Qui suis-je ?" },
	{
		answer = "rhino",
		text = "Ma corne vaut de l'or pour les braconniers, et ma charge fait trembler la plaine. Qui suis-je ?",
	},
	{
		answer = "lion",
		text = "Une crinière, une couronne et un rugissement : je règne sur la savane. Qui suis-je ?",
	},
	{
		answer = "hippo",
		text = "Je passe mes journées dans la boue du marais, et ma bouche est immense. Qui suis-je ?",
	},
	{
		answer = "flamingo",
		text = "Je dors sur une patte et je suis rose à force de manger des crevettes. Qui suis-je ?",
	},
	{ answer = "crocodile", text = "Je flotte comme un tronc, puis je referme mes mâchoires. Qui suis-je ?" },
	{ answer = "camel", text = "Ma bosse est une réserve et je traverse le désert sans boire. Qui suis-je ?" },
	{ answer = "ram", text = "Je bondis de rocher en rocher avec mes cornes en spirale. Qui suis-je ?" },
	{ answer = "trike", text = "Trois cornes, une collerette, et je viens d'un temps très ancien. Qui suis-je ?" },
	{ answer = "salamander", text = "Ma peau brille comme la braise et je me baigne dans la lave. Qui suis-je ?" },
	{ answer = "wyvern", text = "Je vole au-dessus du sol mortel, et il faut sauter pour m'attraper. Qui suis-je ?" },
	{
		answer = "mammoth",
		text = "Mon pelage est épais, mes défenses sont longues, et je ne désarçonne jamais. Qui suis-je ?",
	},
}

Config.DailyReward = { Base = 50, PerStreak = 25, MaxStreak = 7 }

-- Histoire : une chaîne de chapitres. Chaque chapitre a un objectif lu dans le profil du joueur.
-- Types : animals (animaux différents), captures (captures totales), zooUpgrades (niveaux d'amélioration du zoo),
-- boss (boss capturés), zone (zone la plus lointaine atteinte), level (niveau max d'un animal).
Config.Story = {
	{
		id = "s1",
		title = "Un zoo tout vide",
		text = "Tu hérites du vieux zoo de ta tante. Il n'y a plus un seul animal. Pars en expédition et trouve un animal avec un cœur rose.",
		goal = { type = "animals", n = 1 },
		reward = { gold = 100, bones = 0 },
	},
	{
		id = "s2",
		title = "Les premiers visiteurs",
		text = "Les visiteurs arrivent en voyant l'enclos occupé. Offre-leur de la compagnie : 3 animaux.",
		goal = { type = "animals", n = 3 },
		reward = { gold = 150, bones = 5 },
	},
	{
		id = "s3",
		title = "Plus de place",
		text = "Ton zoo est trop petit. Achète ta première amélioration du zoo.",
		goal = { type = "zooUpgrades", n = 1 },
		reward = { gold = 100, bones = 5 },
	},
	{
		id = "s4",
		title = "Le roi de la savane",
		text = "Une rumeur parle d'un éléphant géant au bout de la savane. Capture le boss de la Savane.",
		goal = { type = "boss", n = 1 },
		reward = { gold = 400, bones = 20 },
	},
	{
		id = "s5",
		title = "Prends soin d'eux",
		text = "Un animal bien nourri rapporte plus. Monte un animal au niveau 3 avec des os.",
		goal = { type = "level", n = 3 },
		reward = { gold = 200, bones = 10 },
	},
	{
		id = "s6",
		title = "Les brumes du marais",
		text = "Il y a 5 animaux dans ton zoo : le marais s'ouvre. Atteins la zone 2.",
		goal = { type = "zone", n = 2 },
		reward = { gold = 300, bones = 10 },
	},
	{
		id = "s7",
		title = "Collectionneuse ou collectionneur",
		text = "Un vrai zoo, c'est au moins 10 animaux différents.",
		goal = { type = "animals", n = 10 },
		reward = { gold = 500, bones = 20 },
	},
	{
		id = "s8",
		title = "Le désert gronde",
		text = "Au-delà du marais, le désert. Atteins la zone 3 pour y trouver les chameaux.",
		goal = { type = "zone", n = 3 },
		reward = { gold = 600, bones = 25 },
	},
	{
		id = "s9",
		title = "Roi des crocs",
		text = "Deux boss ont déjà rejoint ton zoo ? Capture 2 boss.",
		goal = { type = "boss", n = 2 },
		reward = { gold = 900, bones = 40 },
	},
	{
		id = "s10",
		title = "La montagne de feu",
		text = "Le dernier territoire : le volcan. Atteins la zone 4.",
		goal = { type = "zone", n = 4 },
		reward = { gold = 1200, bones = 50 },
	},
	{
		id = "s11",
		title = "Le plus beau zoo du monde",
		text = "20 animaux différents et un zoo qui fait rêver. Le journal local veut te rencontrer.",
		goal = { type = "animals", n = 20 },
		reward = { gold = 3000, bones = 100 },
	},
}

-- Zones : quatre territoires à la suite sur la piste. Le sol y est mortel (ronces, eau, sables mouvants, lave) :
-- on ne se déplace que d'animal en animal. Chaque zone a ses animaux, son décor, son danger et son ambiance.
-- `unlock` = nombre d'animaux différents requis pour choisir cette zone comme point de départ.
Config.Zones = {
	{
		key = "savane",
		name = "SAVANE DORÉE",
		from = -5000,
		to = 800,
		start = 0,
		ground = Color3.fromRGB(110, 120, 52),
		material = "Grass",
		hazard = { name = "les ronces", color = Color3.fromRGB(150, 70, 50), death = "Les ronces t'ont piqué !" },
		cliff = Color3.fromRGB(158, 124, 88),
		cliffMaterial = "Rock",
		atmosphere = Color3.fromRGB(214, 226, 240),
		tint = Color3.fromRGB(255, 246, 228),
		animals = { "boar", "zebra", "ostrich", "rhino", "lion" },
		boss = "elephant",
		heartChance = 0.22,
		unlock = 0,
		event = { kind = "geyser", name = "TOURBILLONS DE POUSSIÈRE", color = Color3.fromRGB(240, 210, 140) },
	},
	{
		key = "marais",
		name = "MARAIS BRUMEUX",
		from = 800,
		to = 1600,
		start = 800,
		ground = Color3.fromRGB(46, 112, 126),
		material = "Glass",
		hazard = {
			name = "l'eau",
			color = Color3.fromRGB(60, 150, 190),
			death = "Plouf ! Les crocodiles t'attendaient.",
		},
		cliff = Color3.fromRGB(70, 98, 84),
		cliffMaterial = "Slate",
		atmosphere = Color3.fromRGB(176, 214, 204),
		tint = Color3.fromRGB(226, 255, 240),
		animals = { "hippo", "flamingo", "boar", "crocodile" },
		boss = "croc_king",
		heartChance = 0.22,
		unlock = 4,
		event = { kind = "strike", name = "CROCS SURGISSANTS", color = Color3.fromRGB(90, 220, 150) },
	},
	{
		key = "desert",
		name = "DÉSERT ROUGE",
		from = 1600,
		to = 2400,
		start = 1600,
		ground = Color3.fromRGB(214, 168, 102),
		material = "Sand",
		hazard = {
			name = "les sables mouvants",
			color = Color3.fromRGB(150, 110, 60),
			death = "Les sables mouvants t'ont englouti !",
		},
		cliff = Color3.fromRGB(196, 106, 66),
		cliffMaterial = "Sandstone",
		atmosphere = Color3.fromRGB(246, 214, 176),
		tint = Color3.fromRGB(255, 232, 205),
		animals = { "camel", "ram", "ostrich", "rhino" },
		boss = "sphinx",
		heartChance = 0.22,
		unlock = 9,
		event = { kind = "geyser", name = "TOURBILLONS DE SABLE", color = Color3.fromRGB(255, 190, 110) },
	},
	{
		key = "volcan",
		name = "VOLCAN",
		from = 2400,
		to = 99999,
		start = 2400,
		ground = Color3.fromRGB(255, 96, 24),
		material = "Neon",
		hazard = { name = "la lave", color = Color3.fromRGB(255, 120, 40), death = "La lave t'a avalé !" },
		cliff = Color3.fromRGB(42, 36, 40),
		cliffMaterial = "Basalt",
		atmosphere = Color3.fromRGB(255, 168, 128),
		tint = Color3.fromRGB(255, 214, 190),
		animals = { "trike", "salamander", "wyvern", "mammoth" },
		boss = "dragon",
		heartChance = 0.22,
		unlock = 15,
		event = { kind = "strike", name = "PLUIE DE MÉTÉORES", color = Color3.fromRGB(255, 120, 40) },
	},
}

-- Alias conservé : les décors et l'ambiance utilisent « biome » comme « zone ».
Config.Biomes = Config.Zones

function Config.zoneIndex(z)
	for index, zone in ipairs(Config.Zones) do
		if z < zone.to then
			return index
		end
	end
	return #Config.Zones
end

function Config.zoneAt(z)
	return Config.Zones[Config.zoneIndex(z)]
end

Config.biomeAt = Config.zoneAt

function Config.zoneByKey(key)
	for index, zone in ipairs(Config.Zones) do
		if zone.key == key then
			return zone, index
		end
	end
	return nil, nil
end

function Config.findById(list, id)
	for _, item in ipairs(list) do
		if item.id == id then
			return item
		end
	end
	return nil
end

return Config
