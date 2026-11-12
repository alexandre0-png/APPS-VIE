-- Configuration centrale de Saute-Troupeau (Herd Hopper).
-- Toutes les valeurs d'équilibrage sont ici : on peut régler le jeu sans toucher aux systèmes.

local Config = {}

Config.GameName = "Saute-Troupeau"
Config.Gravity = 90

-- Piste : axe +Z = sens de la course. Le sol est à Y = 0.
Config.Track = {
	HalfWidth = 62, -- limite latérale des bêtes (studs)
	WallX = 82, -- murs invisibles
	FinishZ = 3200, -- ligne d'arrivée
	FloorTop = 0,
	StartZ = 0,
}

Config.Lobby = {
	Center = Vector3.new(0, 320, -560),
	Size = Vector3.new(150, 6, 150),
}

Config.Round = {
	Intermission = 18,
	Countdown = 4,
	Duration = 120,
	Results = 11,
	MinPlayers = 1,
}

-- Mur de lave : avance de plus en plus vite et élimine les retardataires.
Config.Wall = {
	StartZ = -70,
	Speed0 = 12,
	Accel = 0.28,
	MaxSpeed = 46,
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
	DownTime = 1.8,
	BuckWarning = 1.2,
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
}

Config.Tame = {
	PerLevel = 0.08, -- réduction du temps de dressage par niveau
	MinTime = 2.5,
}

Config.Rewards = {
	ScoreToCoins = 0.05,
	Place = { 80, 50, 30 },
	Participation = 15,
	TameCoins = 5,
	NewDiscovery = 40,
	SpeciesComplete = 250,
}

Config.Variants = {
	{ id = 1, name = "Normal", mult = 1, weight = 80 },
	{ id = 2, name = "Cristal", mult = 2, weight = 15 },
	{ id = 3, name = "Doré", mult = 4, weight = 5 },
}

Config.Events = {
	FirstDelay = 14,
	MinGap = 11,
	MaxGap = 19,
	GeyserRadius = 15,
	MeteorRadius = 17,
	Telegraph = 2.0,
}

Config.Upgrades = {
	{ id = "range", name = "Corde longue", desc = "Portée du lasso +5 m par niveau.", max = 5, costs = { 150, 300, 550, 900, 1400 } },
	{ id = "taming", name = "Dresseur rapide", desc = "Temps de dressage -8 % par niveau.", max = 5, costs = { 150, 300, 550, 900, 1400 } },
	{ id = "combo", name = "Souffle de combo", desc = "Fenêtre de combo +0,6 s par niveau.", max = 5, costs = { 200, 400, 700, 1100, 1600 } },
}

Config.Hats = {
	{ id = "none", name = "Aucun chapeau", price = 0 },
	{ id = "beanie", name = "Bonnet à pompon", price = 200 },
	{ id = "cowboy", name = "Chapeau de cow-boy", price = 250 },
	{ id = "viking", name = "Casque viking", price = 400 },
	{ id = "wizard", name = "Chapeau de sorcier", price = 500 },
	{ id = "dino", name = "Capuche de dino", price = 650 },
	{ id = "crown", name = "Couronne en or", price = 800 },
	{ id = "vip", name = "Cornes dorées VIP", price = 0, pass = "vip" },
}

-- Achats Robux. Mets ici les identifiants créés sur le Creator Dashboard (voir docs/PUBLICATION.md).
-- Tant qu'un id vaut 0, l'objet s'affiche « Bientôt » et ne peut pas être acheté.
Config.Monetization = {
	GamePasses = {
		{ key = "double", id = 0, name = "Pièces x2", desc = "Double toutes les pièces gagnées en course, pour toujours." },
		{ key = "rope", id = 0, name = "Corde longue +8 m", desc = "Portée du lasso +8 m en permanence." },
		{ key = "vip", id = 0, name = "VIP", desc = "Cornes dorées exclusives pour ton cavalier." },
	},
	Products = {
		{ key = "coins_s", id = 0, coins = 500, name = "Sac de 500 pièces" },
		{ key = "coins_m", id = 0, coins = 1500, name = "Coffre de 1 500 pièces" },
		{ key = "coins_l", id = 0, coins = 5000, name = "Trésor de 5 000 pièces" },
	},
	RopeBonus = 8,
}

Config.Ropes = {
	{ id = "classic", name = "Corde de chanvre", price = 0, color = Color3.fromRGB(210, 170, 100), neon = false },
	{ id = "fire", name = "Corde de feu", price = 300, color = Color3.fromRGB(255, 110, 30), neon = true },
	{ id = "ice", name = "Corde glacée", price = 300, color = Color3.fromRGB(120, 220, 255), neon = true },
	{ id = "toxic", name = "Corde toxique", price = 400, color = Color3.fromRGB(120, 255, 80), neon = true },
	{ id = "royal", name = "Corde royale", price = 600, color = Color3.fromRGB(180, 90, 255), neon = true },
	{ id = "gold", name = "Corde dorée", price = 900, color = Color3.fromRGB(255, 210, 60), neon = true },
}

-- Quêtes quotidiennes : 3 tirées chaque jour. mode "add" = cumul, "max" = meilleure valeur.
Config.QuestPool = {
	{ id = "tame", label = "Dompter %d créatures", target = 4, reward = 60, mode = "add" },
	{ id = "hooks", label = "Réussir %d lassos", target = 25, reward = 60, mode = "add" },
	{ id = "combo", label = "Atteindre un combo de %d", target = 6, reward = 80, mode = "max" },
	{ id = "distance", label = "Parcourir %d m en course", target = 1500, reward = 70, mode = "add" },
	{ id = "rounds", label = "Jouer %d manches", target = 3, reward = 50, mode = "add" },
	{ id = "score", label = "Marquer %d points en une manche", target = 900, reward = 90, mode = "max" },
	{ id = "rare", label = "Dompter %d bête Cristal ou Dorée", target = 1, reward = 100, mode = "add" },
}

Config.DailyReward = { Base = 50, PerStreak = 25, MaxStreak = 7 }

-- Biomes le long de la piste (utilisés par la carte, par l'ambiance côté client et par la boutique).
Config.Biomes = {
	{
		name = "SAVANE DORÉE",
		from = -5000,
		to = 900,
		ground = Color3.fromRGB(124, 168, 74),
		material = "Grass",
		cliff = Color3.fromRGB(158, 124, 88),
		cliffMaterial = "Rock",
		atmosphere = Color3.fromRGB(214, 226, 240),
		tint = Color3.fromRGB(255, 246, 228),
	},
	{
		name = "DÉSERT ROUGE",
		from = 900,
		to = 1700,
		ground = Color3.fromRGB(226, 182, 116),
		material = "Sand",
		cliff = Color3.fromRGB(196, 106, 66),
		cliffMaterial = "Sandstone",
		atmosphere = Color3.fromRGB(246, 214, 176),
		tint = Color3.fromRGB(255, 232, 205),
	},
	{
		name = "FORÊT GÉANTE",
		from = 1700,
		to = 2500,
		ground = Color3.fromRGB(70, 128, 66),
		material = "Grass",
		cliff = Color3.fromRGB(92, 100, 94),
		cliffMaterial = "Slate",
		atmosphere = Color3.fromRGB(176, 214, 196),
		tint = Color3.fromRGB(226, 255, 232),
	},
	{
		name = "VOLCAN",
		from = 2500,
		to = 99999,
		ground = Color3.fromRGB(62, 54, 58),
		material = "Basalt",
		cliff = Color3.fromRGB(42, 36, 40),
		cliffMaterial = "Basalt",
		atmosphere = Color3.fromRGB(255, 168, 128),
		tint = Color3.fromRGB(255, 214, 190),
	},
}

function Config.biomeAt(z)
	for _, biome in ipairs(Config.Biomes) do
		if z < biome.to then
			return biome
		end
	end
	return Config.Biomes[#Config.Biomes]
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
