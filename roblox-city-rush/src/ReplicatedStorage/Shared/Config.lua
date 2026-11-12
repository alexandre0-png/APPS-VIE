--[[
	Config.lua : toutes les données d'équilibrage et de design du jeu CITY RUSH.
	Module partagé serveur + client. Aucune logique de jeu ici, uniquement des données et des helpers purs.
]]

local Config = {}

Config.GameName = "CITY RUSH"
Config.DataStoreName = "CityRush_Data_v1"
Config.CashBoardName = "CityRush_Cash_v1"
Config.SaveInterval = 60

-- ====================================================================
-- Géométrie de la ville (grille 5x5 de blocs séparés par des routes)
-- ====================================================================
Config.Map = {
	Grid = 5,
	Pitch = 200, -- distance centre à centre entre deux blocs
	BlockSize = 160,
	RoadWidth = 40,
	GroundHalf = 700,
	SidewalkHeight = 0.5,
	RoadHeight = 0.3,
}

-- Centre du bloc (i, j) avec i,j dans 1..5
function Config.blockCenter(i, j)
	return Vector3.new((i - 3) * Config.Map.Pitch, 0, (j - 3) * Config.Map.Pitch)
end

-- Intersection (ix, iz) avec ix,iz dans 0..5
function Config.nodePos(ix, iz)
	return Vector3.new(-500 + Config.Map.Pitch * ix, 0, -500 + Config.Map.Pitch * iz)
end

-- Type de bloc selon la position dans la grille
Config.Districts = {
	-- [j][i]
	{ "residential", "industrial", "industrial", "industrial", "harbor" },
	{ "residential", "downtown", "downtown", "downtown", "beach" },
	{ "residential", "downtown", "plaza", "downtown", "stadium" },
	{ "residential", "downtown", "downtown", "downtown", "beach" },
	{ "residential", "payspray", "police", "dealer", "park" },
}

-- ====================================================================
-- Progression
-- ====================================================================
Config.MaxLevel = 50
function Config.xpForNext(level)
	return 120 + 80 * (level - 1)
end

Config.StartCash = 500

-- ====================================================================
-- Véhicules
-- stats : maxSpeed (studs/s), accel (studs/s²), turn (rad/s max)
-- ====================================================================
Config.Vehicles = {
	{
		id = "citadine", name = "Citadine", price = 0, level = 1,
		maxSpeed = 78, accel = 38, turn = 2.1, color = Color3.fromRGB(255, 200, 50),
		w = 6.4, l = 11.5, cabinH = 3.4, style = "hatch",
	},
	{
		id = "berline", name = "Berline Urbaine", price = 2500, level = 2,
		maxSpeed = 92, accel = 42, turn = 2.0, color = Color3.fromRGB(60, 120, 220),
		w = 7, l = 13.5, cabinH = 3.3, style = "sedan",
	},
	{
		id = "pickup", name = "Pickup 4x4", price = 6000, level = 4,
		maxSpeed = 90, accel = 44, turn = 1.85, color = Color3.fromRGB(180, 60, 50),
		w = 7.6, l = 15, cabinH = 3.5, style = "pickup",
	},
	{
		id = "muscle", name = "Muscle Car", price = 15000, level = 8,
		maxSpeed = 118, accel = 56, turn = 1.9, color = Color3.fromRGB(40, 40, 46),
		w = 7.4, l = 14.5, cabinH = 3.0, style = "muscle",
	},
	{
		id = "sport", name = "Sport GT", price = 38000, level = 12,
		maxSpeed = 138, accel = 66, turn = 2.0, color = Color3.fromRGB(230, 60, 60),
		w = 7.6, l = 14, cabinH = 2.2, style = "sport",
	},
	{
		id = "super", name = "Hyper Phantom", price = 95000, level = 18,
		maxSpeed = 165, accel = 80, turn = 2.0, color = Color3.fromRGB(150, 70, 230),
		w = 8, l = 14.5, cabinH = 2.0, style = "super",
	},
	{
		id = "gold", name = "Phantom Doré (VIP)", price = -1, level = 1, gamepass = "VIP",
		maxSpeed = 175, accel = 85, turn = 2.1, color = Color3.fromRGB(255, 190, 40),
		w = 8, l = 14.5, cabinH = 2.0, style = "super",
	},
}

Config.PublicCars = {
	-- véhicules garés dans la rue, utilisables par tous
	{ id = "citadine", weight = 4 },
	{ id = "berline", weight = 3 },
	{ id = "pickup", weight = 2 },
	{ id = "muscle", weight = 1 },
}

Config.Police = {
	id = "police", name = "Voiture de Police", maxSpeed = 112, accel = 52, turn = 2.2,
	color = Color3.fromRGB(240, 240, 245), w = 7.2, l = 14, cabinH = 3.3, style = "sedan", police = true,
}

Config.TaxiVehicleColor = Color3.fromRGB(255, 214, 0)

function Config.getVehicle(id)
	for _, v in ipairs(Config.Vehicles) do
		if v.id == id then
			return v
		end
	end
	if id == "police" then
		return Config.Police
	end
	return nil
end

Config.VehicleColors = {
	Color3.fromRGB(230, 60, 60), Color3.fromRGB(255, 140, 30), Color3.fromRGB(255, 214, 0),
	Color3.fromRGB(70, 190, 90), Color3.fromRGB(60, 120, 220), Color3.fromRGB(150, 70, 230),
	Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 40, 46),
}

Config.VehicleSpawnCooldown = 4
Config.BoostMax = 100
Config.BoostRegenPerSec = 8
Config.BoostDrainPerSec = 30

-- ====================================================================
-- Police / niveau de recherche
-- ====================================================================
Config.Wanted = {
	MaxStars = 5,
	DecayPerSec = 2.5, -- quand aucun policier à proximité
	HeatPerStar = 20,
	LoseDistance = 110,
	HitPedestrianHeat = 12,
	SmashPropHeat = 2,
	HeistHeat = 70,
	BustedCashPercent = 0.10,
	BustedMaxLoss = 2500,
	SprayCostPerStar = 150,
	MaxCopsByStars = { 1, 2, 3, 4, 5 },
	MaxCruisersByStars = { 0, 1, 1, 2, 3 },
}

-- ====================================================================
-- Missions
-- ====================================================================
Config.Missions = {
	delivery = {
		title = "Livraison de pizzas", minLevel = 1, cooldown = 8,
		baseReward = 140, perStud = 0.22, xp = 40, timeBase = 35, studsPerSec = 11,
	},
	taxi = {
		title = "Course de taxi", minLevel = 2, cooldown = 8,
		baseReward = 180, perStud = 0.28, xp = 55, timeBase = 40, studsPerSec = 13,
	},
	race = {
		title = "Course de rue", minLevel = 3, cooldown = 20,
		baseReward = 700, xp = 120, timeLimit = 140, checkpoints = 8,
	},
	heist = {
		title = "Braquage de la banque", minLevel = 6, cooldown = 240,
		baseReward = 2600, xp = 260, crackTime = 7,
	},
}

-- ====================================================================
-- Collectibles / événements / quotidien
-- ====================================================================
Config.Collectibles = { Count = 30, Reward = 400, Milestones = { [10] = 2500, [20] = 6000, [30] = 15000 } }
Config.Airdrop = { MinInterval = 420, MaxInterval = 720, Crates = 8, Reward = 350, Duration = 120 }
Config.DoubleXP = { MinInterval = 1500, MaxInterval = 2400, Duration = 300 }
Config.DayLengthSeconds = 840 -- 14 minutes pour 24 h

Config.Daily = { Base = 200, PerStreak = 100, MaxStreak = 7 }

Config.Achievements = {
	{ id = "first", name = "Premier contrat", desc = "Termine 1 mission", stat = "missions", goal = 1, reward = 300 },
	{ id = "pro", name = "Pro du volant", desc = "Termine 25 missions", stat = "missions", goal = 25, reward = 3000 },
	{ id = "taxi", name = "Taxi parisien", desc = "Termine 10 courses de taxi", stat = "taxis", goal = 10, reward = 2000 },
	{ id = "pizza", name = "Livreur express", desc = "Livre 15 pizzas", stat = "deliveries", goal = 15, reward = 2000 },
	{ id = "racer", name = "Pilote", desc = "Gagne 5 courses de rue", stat = "races", goal = 5, reward = 3500 },
	{ id = "heist", name = "Cerveau du casse", desc = "Réussis un braquage", stat = "heists", goal = 1, reward = 5000 },
	{ id = "wanted", name = "Ennemi public", desc = "Atteins 5 étoiles de recherche", stat = "fiveStars", goal = 1, reward = 2500 },
	{ id = "stars", name = "Chasseur d'étoiles", desc = "Récupère 15 étoiles dorées", stat = "collected", goal = 15, reward = 4000 },
	{ id = "km", name = "Grand voyageur", desc = "Parcours 20 km", stat = "km", goal = 20, reward = 3000 },
	{ id = "busted", name = "Pris la main dans le sac", desc = "Fais-toi arrêter une fois", stat = "busted", goal = 1, reward = 250 },
}

-- ====================================================================
-- Monétisation (les IDs réels sont écrits par tools/publish.py dans MonetizationIds.lua)
-- ====================================================================
Config.Products = {
	{ key = "cash_s", name = "Sac de billets", cash = 5000, robux = 49, desc = "5 000 $ immédiatement" },
	{ key = "cash_m", name = "Mallette", cash = 30000, robux = 249, desc = "30 000 $ immédiatement" },
	{ key = "cash_l", name = "Coffre-fort", cash = 150000, robux = 999, desc = "150 000 $ immédiatement" },
}
Config.GamePasses = {
	{ key = "VIP", name = "VIP CITY RUSH", robux = 399, desc = "Gains x2, Phantom Doré exclusif, badge VIP" },
	{ key = "BOOST", name = "Nitro Infini+", robux = 149, desc = "Nitro 2x plus long et recharge rapide" },
}

-- ====================================================================
-- Interface
-- ====================================================================
Config.Theme = {
	Panel = Color3.fromRGB(28, 30, 38),
	PanelLight = Color3.fromRGB(44, 47, 60),
	Accent = Color3.fromRGB(255, 196, 0),
	Good = Color3.fromRGB(76, 200, 110),
	Bad = Color3.fromRGB(232, 76, 76),
	Info = Color3.fromRGB(70, 150, 240),
	Text = Color3.fromRGB(245, 245, 250),
	Muted = Color3.fromRGB(165, 170, 185),
}

return Config
