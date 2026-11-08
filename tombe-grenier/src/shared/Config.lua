--[[
  Config : toutes les valeurs de réglage du jeu.
  Aucune valeur de timing ou de difficulté n'est écrite en dur dans la logique.
]]
local Config = {}

Config.Debug = {
	SkipActivationDelay = false, -- true : le monstre s'active immédiatement (tests)
	Seed = nil,                  -- nombre fixe pour rejouer une partie à l'identique
	PlaceRole = nil,             -- "hub" ou "game" : rôle forcé en Studio (un fichier de lieu par rôle)
	SkipFlashbacks = false,      -- true : pas de flashback lors de la lecture des documents (tests)
}

Config.Round = {
	EndScreenTime = 8,     -- durée de l'écran de fin avant le retour au hub
	RestartTimeout = 30,   -- secondes d'attente du « Rejouer » avant nouvelle partie automatique
	PhotosRequired = 3,    -- photos nécessaires (avec la clé) pour ouvrir la sortie
}

Config.Player = {
	WalkSpeed = 8,            -- joueurs un peu plus lents : la maison prend du temps à parcourir
	SprintSpeed = 13,
	QuietSpeed = 3,           -- vitesse en mode silencieux (Ctrl maintenu)
	Lives = 3,                -- vies par joueur et par partie (une mort en coûte une)
	CrouchSpeed = 2,         -- vitesse accroupi (C maintenu) : plus lent, mais silencieux
	CrouchDrop = 1.2,        -- hauteur dont le personnage s'abaisse accroupi
	MovingThreshold = 1.5,    -- vitesse horizontale (studs/s) au-delà de laquelle on est « en mouvement »
	MaxStamina = 100,
	StaminaDrain = 25,        -- par seconde en sprint
	StaminaRegen = 15,        -- par seconde hors sprint
	NoiseWalk = 0.5,          -- intensité de bruit en marche (0 à 1)
	NoiseSprint = 1,
	NoiseQuietFactor = 0.25,  -- multiplicateur de bruit en mode silencieux
	SanityMax = 100,
	SanityLossThreat = 14,    -- perte par seconde quand le monstre perçoit le joueur
	SanityRegenSafe = 3,
	SanityRegenHidden = 6,
	SanityLow = 25,           -- sous ce seuil : battements de cœur et ralentissement
	SanityLossDark = 2,       -- perte par seconde dans une pièce noire sans lampe allumée
	LowSanitySpeedFactor = 0.6,
	SanityScare = 20,        -- perte quand le joueur est débusqué d'une cachette
	Tick = 0.1,
}

Config.Respawn = {
	Delay = 4,               -- secondes avant la réapparition après une mort (solo, ou duo sans partenaire vivant)
}

Config.Revive = {
	Window = 40,             -- duo : secondes pendant lesquelles l'autre joueur peut réanimer le joueur au sol
	Hold = 3,                -- secondes de maintien de l'invite pour réanimer
}

Config.Monster = {
	WalkSpeed = 8,
	ChaseSpeed = 15,
	SightRange = 60,
	FOV = 110,                       -- angle de vision total en degrés
	HearRange = 40,                  -- portée d'ouïe à noise = 1
	NoiseMemory = 0.6,               -- secondes pendant lesquelles un bruit ponctuel reste « entendu »
	AttackRange = 4,
	AttackCooldown = 2.5,
	AttackDamage = 50,
	AttackRecover = 1.5,             -- pause du monstre après une attaque
	SanityHit = 30,                  -- perte de sanité à chaque attaque
	LoseTargetTime = 5,              -- secondes sans voir la cible avant de passer en recherche
	SearchTime = 12,
	SearchRange = 7,                 -- distance à laquelle le monstre peut débusquer un joueur caché
	DiscoverChancePerSecond = 0.5,
	InvestigateTime = 8,
	PatrolRadius = 60,               -- rayon de patrouille si aucun tag Waypoint n'existe
	PatrolPause = 1.5,
	FreezeHold = 0.15,               -- durée de gel après un tick de faisceau lumineux
	StepInterval = 0.6,              -- secondes entre deux pas audibles du monstre
	SurpriseGap = 8,                 -- secondes sans attaque avant une attaque surprise
	DarkSightFactor = 0.35,          -- portée de vue dans le noir, sans lampe allumée (x SightRange)
	ScreamCooldown = 20,             -- secondes minimum entre deux cris de capture
	Tick = 0.1,
	DirectWalkTimeout = 3,
	WaypointTimeout = 3,
}

Config.Flashlight = {
	Range = 40,
	Angle = 40,            -- angle total du faisceau en degrés
	Brightness = 2,
	Battery = 100,
	DrainPerSecond = 1.6,    -- environ une minute de lampe allumée à pleine charge
	PickupAmount = 45,       -- charge rendue par une pile ramassée
}

Config.Lights = {
	OnMin = 0.8,
	OnMax = 4,
	OffMin = 0.05,
	OffMax = 0.5,
	BurstMin = 1,
	BurstMax = 4,
	NearMonsterRange = 25,       -- en dessous, la lampe reste allumée moins longtemps
	NearMonsterOnFactor = 0.4,
	BlackoutIntervalMin = 90,
	BlackoutIntervalMax = 180,
	BlackoutDuration = 2.5,
}

Config.Game = {
	-- Identifiants des deux lieux Roblox. 0 = un seul lieu (test). Le lieu hub réserve un serveur
	-- privé du lieu de jeu et y téléporte les joueurs.
	Places = { hub = 0, game = 0 },
	HubWait = 30,            -- secondes au hub après l'arrivée du premier joueur, puis la partie démarre
	-- Nombre de joueurs maximum par serveur. Deux joueurs : coopération sans diluer la tension.
	-- Le jeu est conçu pour un joueur (solo) ou un duo. Au-delà, la carte devient trop vite encombrée.
	MaxPlayers = 2,
}

-- Réglages par mode : en solo, plus de temps pour explorer seul avant la première apparition
Config.Modes = {
	solo = { activationDelay = 60 },
	duo = { activationDelay = 45 },
}

Config.Intro = {
	Duration = 8,            -- secondes de réveil : le joueur ne peut pas marcher avant la fin
}

Config.Quests = {
	HintDelay = 180,         -- secondes sans progrès avant une indication automatique
	HintCooldown = 30,       -- secondes entre deux indications demandées (touche H)
}

Config.Throw = {
	Charges = 0,             -- lancers au départ : il faut ramasser des cailloux (un caillou = un lancer)
	Cooldown = 3,            -- secondes entre deux jets
	Range = 40,              -- portée maximale en studs
}

Config.Ambience = {
	CreakIntervalMin = 25,   -- secondes entre deux grincements (porte ou chaise)
	CreakIntervalMax = 60,
	ScreamInterval = 90,     -- cri lointain : au plus un par intervalle
	ScreamChance = 0.5,      -- probabilité de déclenchement à chaque intervalle
}

Config.Falling = {
	IntervalMin = 20,
	IntervalMax = 45,
	NoiseStrength = 1,       -- bruit émis à l'impact, attire le monstre
	ItemLifetime = 20,       -- secondes avant suppression de l'objet tombé
}

-- Niveaux de difficulté : valeurs du monstre. « normal » garde les réglages ci-dessus.
Config.Difficulty = "normal"
Config.DifficultyPresets = {
	facile = { ChaseSpeed = 13, HearRange = 30, SightRange = 50 },
	normal = { ChaseSpeed = 15, HearRange = 40, SightRange = 60 },
	difficile = { ChaseSpeed = 17, HearRange = 48, SightRange = 70 },
}
for key, value in pairs(Config.DifficultyPresets[Config.Difficulty] or Config.DifficultyPresets.normal) do
	Config.Monster[key] = value
end

return Config
