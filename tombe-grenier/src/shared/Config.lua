--[[
  Config : toutes les valeurs de réglage du jeu.
  Aucune valeur de timing ou de difficulté n'est écrite en dur dans la logique.
]]
local Config = {}

Config.Debug = {
	SkipActivationDelay = false, -- true : le monstre s'active immédiatement (tests)
	Seed = nil,                  -- nombre fixe pour rejouer une partie à l'identique
}

Config.Round = {
	ActivationDelay = 45,  -- secondes avant que le monstre ne sorte de son point de départ
	EndScreenTime = 8,
	RestartTimeout = 30,   -- secondes d'attente du « Rejouer » avant nouvelle partie automatique     -- durée de l'écran de fin avant le retour au cercueil
	PhotosRequired = 3,    -- photos nécessaires (avec la clé) pour ouvrir la sortie
}

Config.Player = {
	WalkSpeed = 10,
	SprintSpeed = 18,
	QuietSpeed = 4,           -- vitesse en mode silencieux (Ctrl maintenu)
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
	-- Nombre de joueurs maximum par serveur. Deux joueurs : coopération sans diluer la tension.
	-- Le jeu est conçu pour un joueur (solo) ou un duo. Au-delà, la carte devient trop vite encombrée.
	MaxPlayers = 2,
}

Config.Intro = {
	Duration = 8,            -- secondes de réveil : le joueur ne peut pas marcher avant la fin
}

Config.Quests = {
	HintDelay = 180,         -- secondes sans progrès avant une indication automatique
}

Config.Throw = {
	Charges = 3,             -- jets de bruit par vie (un objet lancé fait du bruit au point d'impact)
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

return Config
