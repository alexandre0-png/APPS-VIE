--[[
  Config : toutes les valeurs de réglage du jeu.
  Aucune valeur de timing ou de difficulté n'est écrite en dur dans la logique.
]]
local Config = {}

Config.Debug = {
	SkipActivationDelay = false, -- true : le monstre s'active immédiatement (tests)
	Seed = nil, -- nombre fixe pour rejouer une partie à l'identique
	PlaceRole = nil, -- "hub" ou "game" : rôle forcé en Studio (un fichier de lieu par rôle)
	SkipFlashbacks = false, -- true : pas de flashback lors de la lecture des documents (tests)
}

Config.Round = {
	EndScreenTime = 8, -- durée de l'écran de fin avant le retour au hub
	RestartTimeout = 30, -- secondes d'attente du « Rejouer » avant nouvelle partie automatique
	PhotosRequired = 3, -- photos nécessaires (avec la clé) pour ouvrir la sortie
}

Config.Player = {
	WalkSpeed = 8, -- joueurs un peu plus lents : la maison prend du temps à parcourir
	SprintSpeed = 13,
	QuietSpeed = 3, -- vitesse en mode silencieux (Ctrl maintenu)
	Lives = 3, -- vies par joueur et par partie (une mort en coûte une)
	CrouchSpeed = 2, -- vitesse accroupi (C maintenu) : plus lent, mais silencieux
	CrouchDrop = 1.2, -- hauteur dont le personnage s'abaisse accroupi
	MovingThreshold = 1.5, -- vitesse horizontale (studs/s) au-delà de laquelle on est « en mouvement »
	MaxStamina = 100,
	StaminaDrain = 25, -- par seconde en sprint
	StaminaRegen = 15, -- par seconde hors sprint
	NoiseWalk = 0.5, -- intensité de bruit en marche (0 à 1)
	NoiseSprint = 1,
	NoiseQuietFactor = 0.25, -- multiplicateur de bruit en mode silencieux
	SanityMax = 100,
	SanityLossThreat = 14, -- perte par seconde quand le monstre perçoit le joueur
	SanityRegenSafe = 3,
	SanityRegenHidden = 6,
	SanityLow = 25, -- sous ce seuil : battements de cœur et ralentissement
	SanityLossDark = 2, -- perte par seconde dans une pièce noire sans lampe allumée
	LowSanitySpeedFactor = 0.6,
	SanityScare = 20, -- perte quand le joueur est débusqué d'une cachette
	Tick = 0.1,
}

-- Apparition sûre : aucun personnage n'est chargé avant que la carte et un point d'apparition actif existent
-- (SpawnGate, Respawn.setReady) ; SpawnSafety replace tout personnage tombé sous VoidY.
Config.Spawn = {
	VoidY = -40, -- sous cette hauteur, le personnage est replacé (la maison descend à -12)
	CheckInterval = 0.2, -- secondes entre deux contrôles
	Protect = 3, -- secondes de protection après un replacement
	WatchdogSeconds = 5, -- sans personnage ce nombre de secondes après PlayerAdded : LoadCharacter forcé au point d'apparition
	HoldSeconds = 2.5, -- le personnage reste ancré à l'apparition : le sol a le temps d'arriver chez le client
	FreefallSeconds = 1.5, -- chute libre plus longue que cela pendant EarlyWindow : replacement immédiat
	EarlyWindow = 10, -- secondes après l'apparition pendant lesquelles la chute libre est surveillée
	Debug = true, -- traces [Spawn] dans la console serveur
	ReadyTimeout = 30, -- secondes d'attente du point d'apparition avant d'ouvrir la porte malgré tout
}

Config.Respawn = {
	Delay = 4, -- secondes avant la réapparition après une mort (solo, ou duo sans partenaire vivant)
}

Config.Revive = {
	Window = 40, -- duo : secondes pendant lesquelles l'autre joueur peut réanimer le joueur au sol
	Hold = 3, -- secondes de maintien de l'invite pour réanimer
}

Config.Monster = {
	WalkSpeed = 8,
	ChaseSpeed = 15,
	SightRange = 60,
	FOV = 110, -- angle de vision total en degrés
	HearRange = 40, -- portée d'ouïe à noise = 1
	NoiseMemory = 0.6, -- secondes pendant lesquelles un bruit ponctuel reste « entendu »
	AttackRange = 4,
	AttackCooldown = 2.5,
	AttackDamage = 50,
	AttackRecover = 1.5, -- pause du monstre après une attaque
	SanityHit = 30, -- perte de sanité à chaque attaque
	LoseTargetTime = 5, -- secondes sans voir la cible avant de passer en recherche
	SearchTime = 12,
	SearchRange = 7, -- distance à laquelle le monstre peut débusquer un joueur caché
	DiscoverChancePerSecond = 0.5,
	InvestigateTime = 8,
	PatrolRadius = 60, -- rayon de patrouille si aucun tag Waypoint n'existe
	PatrolPause = 1.5,
	FreezeHold = 0.15, -- durée de gel après un tick de faisceau lumineux
	StepInterval = 0.6, -- secondes entre deux pas audibles du monstre
	SurpriseGap = 8, -- secondes sans attaque avant une attaque surprise
	DarkSightFactor = 0.35, -- portée de vue dans le noir, sans lampe allumée (x SightRange)
	ScreamCooldown = 20, -- secondes minimum entre deux cris de capture
	Tick = 0.1,
	DirectWalkTimeout = 3,
	WaypointTimeout = 3,
}

-- Boutique Robux. Un identifiant à 0 = article désactivé : le jeu reste entièrement jouable gratuitement.
Config.Shop = {
	GamePasses = { LampeRenforcee = 0 }, -- Game Pass : la lampe se vide deux fois moins vite
	Products = { Pile = 0, Cailloux = 0 }, -- produits : une pile, ou des cailloux à lancer
	PileAmount = 45,
	CaillouxAmount = 5,
}

Config.Flashlight = {
	Range = 40,
	Angle = 40, -- angle total du faisceau en degrés
	Brightness = 2,
	Battery = 100,
	DrainPerSecond = 1.6, -- environ une minute de lampe allumée à pleine charge
	PickupAmount = 45, -- charge rendue par une pile ramassée
}

Config.Lights = {
	OnMin = 0.8,
	OnMax = 4,
	OffMin = 0.05,
	OffMax = 0.5,
	BurstMin = 1,
	BurstMax = 4,
	NearMonsterRange = 25, -- en dessous, la lampe reste allumée moins longtemps
	NearMonsterOnFactor = 0.4,
	BlackoutIntervalMin = 90,
	BlackoutIntervalMax = 180,
	BlackoutDuration = 2.5,
}

Config.Game = {
	-- Identifiants des deux lieux Roblox (même expérience, même univers). 0 = un seul lieu (test).
	-- Le lieu hub réserve un serveur privé du lieu de jeu et y téléporte les joueurs ; si Roblox refuse,
	-- repli sur un serveur public du lieu de jeu.
	Places = { hub = 77452764500707, game = 88091909899710 }, -- deux lieux de la même expérience « Sortir Du Grenier » (univers 10776611603) : hub et partie
	HubWait = 30, -- secondes au hub après l'arrivée du premier joueur, puis la partie démarre
	DuoWait = 60, -- zone duo : secondes d'attente d'un second joueur, puis partie en solo
	-- Nombre de joueurs maximum par serveur. Deux joueurs : coopération sans diluer la tension.
	-- Le jeu est conçu pour un joueur (solo) ou un duo. Au-delà, la carte devient trop vite encombrée.
	MaxPlayers = 2,
}

-- Textures tuilables (ID = identifiant de DÉCAL : le serveur charge le décal, lit Decal.Texture et applique cette image).
-- Sans chargement, les matières actuelles restent. StudsPerTile : longueur d'une répétition, réglable par texture.
Config.Textures = {
	StudsPerTile = 8,
	Ids = {
		damier_cuisine = 74886659758502,
		parquet_chevrons = 103808199880931,
		lames_plancher = 137828535744065,
		dalles_cave = 107078290448335,
		marbre_veine = 82505741913633,
		papier_fleuri = 133522614389829,
		papier_enfant = 134002350904585,
		faience_murale = 80018384734004,
	},
	Tile = {}, -- exemple : Tile = { damier_cuisine = 4 }
}

-- Sons synthétiques (ogg) : Enabled = false coupe les nouveaux sons (les anciens restent). Un son dont l'asset ne se
-- charge pas est ignoré sans erreur ; l'ancien son de secours reste alors utilisé.
Config.Audio = {
	Enabled = true,
	PreloadTimeout = 6, -- secondes d'attente maximale du chargement d'un son
	MonsterNear = 40, -- studs : le murmure et le battement de cœur suivent la distance du monstre
}

-- Réglages par mode : en solo, plus de temps pour explorer seul avant la première apparition
Config.Modes = {
	solo = { activationDelay = 60 },
	duo = { activationDelay = 45 },
}

-- Passe 3 : courbe de tension en trois temps (calme, montée, pic). Chaque temps règle la fréquence des
-- événements d'ambiance (events), la portée d'ouïe et la vitesse de poursuite du monstre (hear, chase),
-- le volume (volume) et le délai avant une attaque surprise (gap). Les valeurs entre deux temps sont interpolées.
-- Phases : fin du calme et fin de la montée, en secondes depuis le début de la partie. La progression
-- (0 à 1, photos et étapes) peut avancer la courbe, jamais la reculer. Enabled = false : tout reste à 1.
Config.Tension = {
	Enabled = true,
	Phases = {
		solo = { calm = 240, rise = 720 },
		duo = { calm = 200, rise = 600 },
	},
	ProgressWeight = 1, -- 0 : le temps seul ; 1 : la progression compte à plein
	Levels = {
		calme = { events = 0.5, hear = 0.9, chase = 0.95, volume = 0.8, gap = 1.4 },
		montee = { events = 1.0, hear = 1.0, chase = 1.0, volume = 1.0, gap = 1.0 },
		pic = { events = 1.7, hear = 1.12, chase = 1.07, volume = 1.2, gap = 0.7 },
	},
}

-- Difficulté propre à chaque mode (appliquée au début de la partie, par-dessus le niveau Config.Difficulty) :
-- facteurs sur le monstre, durées de recherche, vies et délai des indices automatiques.
Config.Balance = {
	solo = { chase = 0.93, hear = 0.9, loseTarget = 4, search = 10, surpriseGap = 10, lives = 4, hintDelay = 150 },
	duo = { chase = 1.0, hear = 1.05, loseTarget = 5, search = 12, surpriseGap = 8, lives = 3, hintDelay = 210 },
}

-- Tutoriel discret au premier lancement : trois indices contextuels, jamais bloquants (Tutorial.lua).
Config.Tutorial = {
	Enabled = true,
	Cooldown = 25, -- secondes minimum entre deux indices
	QuietAfter = 40, -- indice 1 : après tant de secondes de jeu sans avoir ralenti ses pas (Ctrl)
	LampBattery = 35, -- indice 3 : lampe sous ce pourcentage
}

-- Progression : rangs et titres affichés au hub (Ranks.lua). Les points s'ajoutent à chaque partie.
Config.Ranks = {
	Enabled = true,
	PointsPerRun = 10, -- pour avoir terminé une partie
	PointsPerEnding = { lose = 5, sealed = 20, truth = 40 },
	PointsPerChallenge = 15,
	DuoBonus = 5,
}

-- Rejouabilité : défis optionnels (Challenges.lua) et graines (Replay.lua).
Config.Replay = {
	Enabled = true,
	AvoidLastSeeds = 5, -- une nouvelle graine évite les cinq dernières jouées
	DailySeed = true, -- le premier défi du jour utilise la graine du jour (identique pour tous)
	StoreProfile = true, -- DataStore : rang, défis, tutoriel (désactiver pour tester sans sauvegarde)
	DataStoreName = "TombeGrenierProfil",
}

Config.Intro = {
	Duration = 8, -- secondes de réveil : le joueur ne peut pas marcher avant la fin
}

Config.Quests = {
	HintDelay = 180, -- secondes sans progrès avant une indication automatique
	HintCooldown = 30, -- secondes entre deux indications demandées (touche H)
}

Config.Throw = {
	Charges = 0, -- lancers au départ : il faut ramasser des cailloux (un caillou = un lancer)
	MaxCarry = 6, -- nombre maximum de lancers gardés sur soi
	Cooldown = 3, -- secondes entre deux jets
	Range = 40, -- portée maximale en studs
}

-- Conception du jeu. ProgressionV2 : une horloge dans le hall, à régler sur la date de la plaque,
-- entre la mélodie et la clé de la malle. false : retour à la progression d'origine.
Config.Design = {
	ProgressionV2 = true,
	Markers = true, -- halo, pastille et nom sur chaque objet interactif (src/shared/Markers.lua)
	ExtraSafe = true, -- énigme optionnelle de la cuisine (compteur) : ne bloque rien, donne une pile
}

Config.Visual = {
	Dust = true, -- poussière en suspension dans les pièces (Atmosphere.lua)
	DustRate = 3, -- particules par seconde et par pièce : faible, pour rester léger
	Vignette = true, -- bords de l'écran assombris, d'autant plus que la sanité baisse (client)
	VignetteMax = 0.6, -- opacité maximale de la vignette (0 à 1)
	CandleFlicker = true, -- la lueur des bougies vacille (Quests.lua)
	RoomLights = true, -- lueurs de pièce : seules les pièces proches du joueur restent allumées (RoomBudget.lua)
	RoomLightQuality = "auto", -- "auto", "bas", "moyen" ou "haut" : nombre de lueurs actives et portée
}

-- Modèles Roblox (décor). Chaque identifiant se charge côté serveur seulement, avec délai maximum.
-- Un modèle absent ou invalide garde les pièces de remplacement actuelles. Enabled = false désactive le chargement.
Config.Assets = {
	Enabled = true,
	Timeout = 8, -- secondes maximum par modèle
	GlobalTimeout = 10, -- secondes maximum pour tous les modèles ensemble : au-delà, plus rien n'est lancé (repli procédural)
	Workers = 8, -- chargements en parallèle
	ChaiseHorreur = 8995653666, -- chaise de la salle à manger (remplace « chaise »)
	ChaiseBois = 13369825696, -- chaise en bois (décor, salle à manger)
	ChaiseAntique = 97314700592382, -- fauteuil du salon (remplace « fauteuil »)
	ChaiseBloquante = 80943579301021, -- chaise devant une porte (décor seulement)
	LampeHorreur = 10780850055, -- lampe avec lueur (décor, dans les pièces)
	TableLongue = 188745055, -- table de la salle à manger et de la cuisine (remplace « table »)
	Plante = 116741237427172, -- plante en pot (décor : hall, couloir)
	-- Catalogue de l'utilisateur (chaque modèle a son repli procédural si le chargement échoue)
	ChaiseModerne = 125943216682367, -- chaise moderne (bureau)
	ChaiseEcole = 8156800485, -- chaise de bureau d'école (chambres, bureau)
	CanapeU = 10551600237, -- canapé moderne en U avec table basse (salon, bureau)
	TableMetal = 12470604445, -- table en métal (îlot de la cuisine)
	TableBois = 839550130, -- table en bois (bureaux, grenier)
	TableManger = 1338860741, -- table à manger (cuisine)
	TableRondeChaise = 1452069624, -- table ronde avec chaise moderne (couloir)
	Billard = 14953074402, -- table de billard (réservé, non placé : aucune pièce assez grande sans bloquer)
	VieuxOrdinateur = 130020507665878, -- vieil ordinateur (posé sur le bureau)
	LampeTable = 5680874848, -- petite lampe de table (chevets, bureau), sans lumière : le budget de lueurs reste
	PlanteMoyenne = 12032209888, -- plante moderne en pot moyenne (bureau)
	PlanteModerne = 16600867704, -- plante moderne (salon)
	PlanteFenetre = 15078054751, -- plante de fenêtre (salle à manger)
	PlanteExterieure = 131378985761907, -- plante extérieure rectangle (jardin)
	PlanteSakura = 101176034116232, -- sakura (jardin)
	-- Modèles Blender low-poly (approuvés) : ils remplacent la clé, le coffret et l'horloge des énigmes, et ornent
	-- la chambre d'enfant (poupée) et le grenier (bougie). Échelle et orientation : src/shared/ModelFit.lua.
	CleOr = 71927105620016, -- clé dorée (anneau, tige, dents), étape « clé »
	CoffretAncien = 135334916682974, -- coffret en bois cerclé de fer, serrure dorée face -Z, étape « coffret »
	HorlogeComtoise = 127086141131615, -- horloge haute, cadran face -Y (Blender), étape « horloge »
	PoupeeAncienne = 137798724739586, -- poupée à robe rouge (chambre d'enfant)
	BougieChandelier = 91265848520746, -- chandelier en laiton avec bougie (grenier)
	-- Face avant réelle d'un modèle dans Roblox si elle diffère de ModelFit.PLANS : Front = { ["horloge comtoise"] = "-Z" }
	-- (valeurs "-Z", "+Z", "-X", "+X"). À régler après avoir regardé le modèle dans Studio.
	-- Bibliothèque Blender (chaque FBX : pièces séparées `Nom__RRGGBB`, couleur lue par ModelColor)
	Armoire = 88627357314275, -- armoire gothique (chambres, grenier), ~2,2 studs de haut
	Commode = 116600254156058, -- commode ancienne, ~1 de haut
	Berceau = 73900289399193, -- berceau (grenier), ~1
	ChevalBascule = 74320735179635, -- cheval à bascule (chambre d'enfant, salle de la tombe), ~1,3
	MiroirAncien = 134489196998276, -- miroir sur pied (grenier), ~2
	Malle = 94690600145377, -- malle (grenier), ~0,9
	Statuette = 107399380407320, -- statues de l'énigme des statues, ~1,2
	CadrePhoto = 86021806351640, -- cadre des photos de l'énigme des photos, ~1
	-- Accessoires Blender de lisibilité des pièces (posés après la carte, sans collision, jamais sur un passage ni une énigme)
	Cheminee = 127626819974178, -- cheminée gothique (6 de large, 1,6 de profondeur, 7 de haut)
	Escalier = 134240189869154, -- escalier de 8 marches, ~4 de large : NON chargé (l'escalier de la carte porte la logique de passage)
	Etagere = 76212522336973, -- étagère à livres colorés, 4,2 de large, 7 de haut
	Gramophone = 99475660293991, -- gramophone (énigme de la mélodie)
	Lustre = 135294864655941, -- lustre suspendu (hall, entrée, couloir, palier)
	MachineCoudre = 124715650479605, -- machine à coudre (chambre d'amis, grenier)
	PorteAncienne = 129943433961170, -- porte ancienne de décor, 4,6 x 8,4 (murs des couloirs)
	TapisRond = 99100525426156, -- tapis rond de 6 de diamètre
	Telephone = 139304662558987, -- téléphone ancien (remplace le téléphone du catalogue quand il est chargé)
	ToileAraignee = 71110850265760, -- toile d'araignée (coins de plafond)
	Valise = 136114731977294, -- valise (grenier, salle de la tombe)
	-- Mobilier Blender (lot 2, approuvé) : devant = -Y Blender ; fit dans la boîte du meuble de la carte
	Chaise = 97926582469965, -- chaise en bois à dossier à barreaux
	TableSalle = 92569428619047, -- longue table rustique
	EtagereMurale = 96130815912348, -- étagère vide à 5 niveaux
	Caisses = 89142087734544, -- pile de caisses
	PiedLit = 129217921305648, -- montant de lit
	PlanteInterieur = 115245941716953, -- plante en pot de terre cuite
	Console = 127180262193443, -- console à deux tiroirs
	Baignoire = 81854062482660, -- baignoire en fonte
	Lavabo = 109380958615258, -- lavabo sur colonne
	WC = 135608112766747, -- WC à réservoir haut
	ArmoireToilette = 128128467516107, -- armoire murale à miroir
	Barrique = 108166293605074, -- tonneau cerclé
	Cuve = 85621038139046, -- cuve métallique de cave
	Canape = 85086079052709, -- canapé trois places défraîchi
	Fauteuil = 84731331370269, -- fauteuil assorti au canapé
	Cuisiniere = 76790495265936, -- cuisinière à gaz ancienne
	Frigo = 77833906083470, -- réfrigérateur arrondi
	Cercueil = 97146110981447, -- cercueil de la salle de la tombe
	CoffreVerrouille = 90844346755064, -- coffre renforcé à cadenas
	CoffreJouets = 118394284398196, -- coffre d'enfant peint
	Vitrine = 82264063741947, -- vitrine de collection
	Portemanteau = 129593495246898, -- portemanteau avec manteau
	Lampadaire = 92735211656049, -- lampadaire à abat-jour jauni
	LitDouble = 135445479170017, -- lit à baldaquin dépouillé
	Etabli = 124510607976600, -- établi d'atelier
	-- Garnitures Blender (lot 3, approuvé) : plinthes, moulures, fenêtres, encadrements, appliques, soupiraux, radiateurs
	Plinthe = 92565174748095, -- plinthe bois
	Moulure = 75784159506222, -- moulure plafond
	FenetreRideaux = 126909624367682, -- fenêtre rideaux
	FenetreRonde = 71510822261833, -- fenêtre ronde
	Balustrade = 75136739107081, -- balustrade d'escalier
	Marche = 101885017410350, -- marche usée
	Encadrement = 125000444415052, -- encadrement de porte
	Applique = 114023857878257, -- applique murale
	Soupirail = 103729918302456, -- soupirail
	Radiateur = 113203803952444, -- radiateur fonte
	OmbreRampante = 101328489566505, -- le monstre : silhouette sombre, masque blanc, yeux rouges, ~2,5
	Front = {},
	HubBibliotheque = 9904549498, -- bibliothèque (décor du hub : étagères) ; même modèle que « bibliothèque » (ModelLoader)
	-- Modèle du monstre : essayés dans l'ordre, le premier valide est utilisé. Sinon, le rig de secours.
	Monstre1 = 14801251042,
	Monstre2 = 126828585469313,
	Monstre3 = 139294979123405,
}

-- Décor du hub (HubDecor.lua, HubLayout.lua) : mobilier, bougies, lampes, toiles, tapis, cadres, panneaux, poussière.
-- Decor = false : le hub garde seulement son sol, ses bornes et son panneau. Music : nappe douce très basse.
Config.Hub = {
	Decor = true,
	Music = true,
	MusicVolume = 0.12,
	CandleFlicker = true, -- la lueur des bougies vacille (comme Config.Visual.CandleFlicker)
}

-- Cinématiques aux moments clés seulement (intro, première apparition, descente, fins) : chacune se coupe seule.
-- Enabled = false coupe toutes les cinématiques. SkipButton : bouton « Passer » à l'écran.
Config.Cinematics = {
	Enabled = true,
	Arrival = true, -- intro courte : arrivée devant la maison, de nuit
	Apparition = true, -- première apparition du monstre (cri, caméra qui se tourne)
	Descent = true, -- le monstre descend au sous-sol
	Sealed = true, -- fin 4, « le piège »
	Truth = true, -- fin 3, « la vérité »
	SkipButton = true,
}

-- Animations : chaque geste peut être coupé seul. Enabled = false coupe tout.
Config.Animations = {
	Enabled = true,
	ChestLid = true, -- la malle s'entrouvre en basculant
	CoffretLid = true, -- le couvercle du coffret se soulève
	PickupRise = true, -- un objet ramassé s'élève puis disparaît
	LampSway = true, -- les lampes de plafond se balancent doucement
	CameraBob = true, -- pas : léger balancement de la caméra en marche
	Breath = true, -- respiration : légère montée et descente de la caméra à l'arrêt
	DocumentRead = true, -- lecture d'un document : la feuille monte à hauteur des yeux
	Drawer = true, -- tiroir : il coulisse hors du meuble
	WakeBlink = true, -- réveil : battements de paupières (fondu en plusieurs temps)
	ScareShake = true, -- débusqué ou apparition : secousse courte de la caméra
	MonsterReaction = true, -- apparition du monstre : secousse et sursaut des bords (pendant et après la cinématique)
	BobAmplitude = 0.08, -- amplitude du balancement de marche (studs)
	BreathAmplitude = 0.04, -- amplitude de la respiration (studs)
	ShakeDuration = 0.6, -- durée de la secousse (secondes)
}

Config.Ambience = {
	CreakIntervalMin = 25, -- secondes entre deux grincements (porte ou chaise)
	CreakIntervalMax = 60,
	ScreamInterval = 90, -- cri lointain : au plus un par intervalle
	ScreamChance = 0.5, -- probabilité de déclenchement à chaque intervalle
}

Config.Falling = {
	IntervalMin = 20,
	IntervalMax = 45,
	NoiseStrength = 1, -- bruit émis à l'impact, attire le monstre
	ItemLifetime = 20, -- secondes avant suppression de l'objet tombé
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
