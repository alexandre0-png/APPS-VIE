-- ModuleScript : ReplicatedStorage/Shared/Config
-- Toutes les données d'équilibrage du jeu. Modifie ici, rien d'autre à toucher.
local Config = {}

Config.PLOT_COUNT = 5 -- nombre de bases (= Config.Game.MaxPlayers : une partie accueille 5 joueurs au plus)

---------------------------------------------------------------- Architecture hub + parties
-- Deux lieux : le HUB (petit lieu léger : zones de lancement 1 à 5 joueurs, parties des amis) et le lieu de JEU (la partie, 5 joueurs max).
-- Le rôle d'un serveur se déduit de game.PlaceId (Config.Game.roleFor). Identifiants = LIEUX (place ids), pas des univers.
-- ATTENTION : TeleportService:ReserveServer et MemoryStoreService sont limités à UNE expérience (univers). Si le hub et le jeu sont deux
-- expériences distinctes, la réservation vers l'autre expérience peut être refusée : le code essaie alors les replis de `Fallbacks`
-- puis prévient le joueur. Le plus sûr : faire du hub un second lieu de l'expérience du jeu (Creator Hub > Lieux > Ajouter) et changer
-- seulement Places.hub ci-dessous.
Config.Game = {
	Places = { hub = 106358102689021, game = 115261336085924 },
	MaxPlayers = 5, -- plafond absolu d'un serveur de jeu (réglage Creator Dashboard : Max Players = 5 aussi)
	Sizes = { 1, 2, 3, 4, 5 }, -- tailles de partie proposées par les zones du hub
	CountdownFull = 5, -- secondes avant le départ d'un groupe complet
	PartialWait = 25, -- secondes après le premier arrivé avant de lancer un groupe incomplet (la partie reste ouverte aux amis)
	SoloCountdown = 3,
	PartyTTL = 7200, -- une partie du registre plus vieille que ça n'est plus proposée
	Fallbacks = { "reserved", "public" }, -- ordre des méthodes de téléportation essayées
	LateJoinGrace = 90, -- secondes de protection des œufs d'un joueur qui arrive dans une partie déjà commencée
	RegistryName = "ChipeParties",
}

function Config.Game.roleFor(placeId)
	if placeId == Config.Game.Places.hub then
		return "hub"
	elseif placeId == Config.Game.Places.game then
		return "game"
	end
	return "unknown" -- place non publiée (Studio) : chaque projet lance son propre code
end

Config.TIERS = {
	{ name = "Commun", color = Color3.fromRGB(170, 180, 191) },
	{ name = "Rare", color = Color3.fromRGB(74, 163, 255) },
	{ name = "Épique", color = Color3.fromRGB(184, 120, 255) },
	{ name = "Légendaire", color = Color3.fromRGB(255, 176, 32) },
	{ name = "Mythique", color = Color3.fromRGB(255, 77, 109) },
	{ name = "Cosmique", color = Color3.fromRGB(61, 255, 208) },
}
-- Prix et durées calibrés avec la simulation tests/Economy.lua (joueur-robot) : ~15 pièces/s après 1 min, œuf Rare vers 2 min,
-- Épique vers 5-8 min, Légendaire vers 15-20 min, Mythique après ~1 h, Cosmique après plusieurs heures ; première renaissance vers 1 h.
Config.START_COINS = 50
Config.EGG_PRICE = { 25, 900, 20000, 350000, 6000000, 130000000 }
Config.HATCH = { 8, 20, 45, 90, 180, 300 } -- secondes

-- tier, emoji (UI), nom, revenu/s, couleur du modèle 3D, oreilles, extra
Config.PETS = {
	{ tier = 1, emoji = "🐥", name = "Poussin", inc = 1, color = Color3.fromRGB(255, 221, 87), ears = "none", extra = "beak" },
	{ tier = 1, emoji = "🐹", name = "Hamster", inc = 1.5, color = Color3.fromRGB(222, 184, 135), ears = "round", extra = "none" },
	{ tier = 1, emoji = "🐰", name = "Lapin", inc = 2, color = Color3.fromRGB(245, 245, 245), ears = "long", extra = "tail" },
	{ tier = 2, emoji = "🐱", name = "Chat", inc = 6, color = Color3.fromRGB(150, 150, 160), ears = "point", extra = "tail" },
	{ tier = 2, emoji = "🐶", name = "Chien", inc = 8, color = Color3.fromRGB(160, 110, 70), ears = "floppy", extra = "tail" },
	{ tier = 2, emoji = "🦊", name = "Renard", inc = 11, color = Color3.fromRGB(240, 130, 50), ears = "point", extra = "tail" },
	{ tier = 3, emoji = "🐼", name = "Panda", inc = 32, color = Color3.fromRGB(250, 250, 250), ears = "round", extra = "none" },
	{ tier = 3, emoji = "🦉", name = "Hibou", inc = 45, color = Color3.fromRGB(130, 95, 60), ears = "point", extra = "beak" },
	{ tier = 3, emoji = "🐧", name = "Manchot", inc = 60, color = Color3.fromRGB(40, 50, 80), ears = "none", extra = "beak" },
	{ tier = 4, emoji = "🦁", name = "Lion", inc = 170, color = Color3.fromRGB(230, 180, 80), ears = "round", extra = "mane" },
	{ tier = 4, emoji = "🐯", name = "Tigre", inc = 230, color = Color3.fromRGB(245, 140, 40), ears = "round", extra = "tail" },
	{ tier = 4, emoji = "🦄", name = "Licorne", inc = 330, color = Color3.fromRGB(255, 235, 250), ears = "point", extra = "horn" },
	{ tier = 5, emoji = "🐲", name = "Dragon", inc = 1100, color = Color3.fromRGB(210, 50, 50), ears = "none", extra = "wings" },
	{ tier = 5, emoji = "🦖", name = "T-Rex", inc = 1600, color = Color3.fromRGB(80, 170, 80), ears = "none", extra = "tail" },
	{ tier = 5, emoji = "🐙", name = "Kraken", inc = 2300, color = Color3.fromRGB(140, 70, 190), ears = "none", extra = "tentacles" },
	{ tier = 6, emoji = "👽", name = "Alien", inc = 9000, color = Color3.fromRGB(120, 220, 110), ears = "none", extra = "antenna" },
	{ tier = 6, emoji = "🦑", name = "Calmar stellaire", inc = 13000, color = Color3.fromRGB(60, 190, 200), ears = "none", extra = "tentacles" },
	{ tier = 6, emoji = "🐉", name = "Wyrm astral", inc = 20000, color = Color3.fromRGB(80, 160, 255), ears = "none", extra = "wings" },
}

Config.SIZES = {
	{ name = "Mini", mult = 0.8, weight = 20, scale = 0.8 },
	{ name = "Normal", mult = 1, weight = 62, scale = 1 },
	{ name = "Grand", mult = 1.5, weight = 14, scale = 1.25 },
	{ name = "Géant", mult = 2.5, weight = 3.5, scale = 1.6 },
	{ name = "Colossal", mult = 5, weight = 0.5, scale = 2.1 },
}

Config.MUTS = {
	{ name = "", mult = 1, weight = 82 },
	{ name = "Doré", mult = 2, weight = 9, color = Color3.fromRGB(255, 208, 0) },
	{ name = "Néon", mult = 3, weight = 5, color = Color3.fromRGB(0, 229, 255) },
	{ name = "Arc-en-ciel", mult = 5, weight = 2.6, rainbow = true },
	{ name = "Alien", mult = 10, weight = 1.4, color = Color3.fromRGB(57, 255, 20) },
}

-- Rivaux PNJ : poids de tirage des œufs (par rareté), vitesses des gardiens en studs/s
-- (le joueur démarre à 16 : il doit s'entraîner sur le tapis pour battre Mara puis Zed)
Config.RIVALS = {
	{ name = "Gus", emoji = "🤠", stars = 1, weights = { 60, 35, 5, 0, 0, 0 }, guardSpeed = 13, patrolSpeed = 7, color = Color3.fromRGB(111, 191, 115) },
	{ name = "Mara", emoji = "🧛", stars = 2, weights = { 0, 40, 40, 20, 0, 0 }, guardSpeed = 19, patrolSpeed = 10, color = Color3.fromRGB(224, 164, 59) },
	{ name = "Zed", emoji = "🤖", stars = 3, weights = { 0, 0, 30, 45, 22, 3 }, guardSpeed = 26, patrolSpeed = 13, color = Color3.fromRGB(224, 87, 90) },
}

-- Événements serveur (tous les joueurs en profitent)
Config.EVENTS = {
	{ key = "alien", name = "Biome Alien", emoji = "👽", desc = "Mutation Alien x5", tint = Color3.fromRGB(205, 160, 255) },
	{ key = "gold", name = "Ruée vers l'or", emoji = "💰", desc = "Revenus x2", tint = Color3.fromRGB(255, 232, 160) },
	{ key = "luck", name = "Pluie de chance", emoji = "🍀", desc = "Pets supérieurs +10%", tint = Color3.fromRGB(175, 255, 195) },
	{ key = "run", name = "Marathon", emoji = "🏃", desc = "Entraînement x3", tint = Color3.fromRGB(175, 215, 255) },
}
Config.EVENT_DURATION = 60
Config.EVENT_GAP = { 120, 200 } -- délai aléatoire entre deux événements

-- Game Passes : crée-les sur create.roblox.com puis colle les ID ici (0 = désactivé)
Config.PASSES = {
	Coins2x = { id = 0, name = "Revenus x2", emoji = "💰", desc = "Double tous tes revenus, pour toujours." },
	Lucky = { id = 0, name = "Chance +10%", emoji = "🍀", desc = "Plus de pets supérieurs à l'éclosion." },
	Fast = { id = 0, name = "Éclosion rapide", emoji = "⚡", desc = "Les œufs éclosent 25% plus vite." },
}

Config.SHIELD_BASE = 20 -- secondes de protection d'un œuf fraîchement posé (anti-vol)
Config.SHIELD_PER_LEVEL = 10

function Config.stealTime(level)
	return 1.3 * 0.85 ^ level
end

function Config.walkSpeed(speedStat)
	return 16 + 44 * (1 - math.exp(-speedStat / 150))
end

function Config.rebirthCost(rb)
	return 5e7 * 7 ^ rb
end

Config.UPGRADES = {
	{ key = "slots", name = "Emplacements", emoji = "🏠", max = 8, cost = function(l) return 500 * 6 ^ l end,
		desc = function(l) return (4 + l) .. " → " .. (5 + l) .. " emplacements" end },
	{ key = "tm", name = "Tapis puissant", emoji = "🏃", max = 15, cost = function(l) return 100 * 2.4 ^ l end,
		desc = function(l) return string.format("Entraînement x%.2f → x%.2f", 1 + 0.35 * l, 1 + 0.35 * (l + 1)) end },
	{ key = "fing", name = "Doigts agiles", emoji = "🧤", max = 8, cost = function(l) return 200 * 3 ^ l end,
		desc = function(l) return string.format("Vol en %.2fs → %.2fs", Config.stealTime(l), Config.stealTime(l + 1)) end },
	{ key = "bag", name = "Grand sac", emoji = "🎒", max = 3, cost = function(l) return 1500 * 8 ^ l end,
		desc = function(l) return "Porter " .. (1 + l) .. " → " .. (2 + l) .. " œufs" end },
	{ key = "inc", name = "Incubateur", emoji = "🔥", max = 10, cost = function(l) return 200 * 3.8 ^ l end,
		desc = function(l) return string.format("Éclosion -%d%% → -%d%%", math.floor((1 - 0.9 ^ l) * 100 + 0.5), math.floor((1 - 0.9 ^ (l + 1)) * 100 + 0.5)) end },
	{ key = "luck", name = "Trèfle", emoji = "🍀", max = 10, cost = function(l) return 600 * 4 ^ l end,
		desc = function(l) return "Pet supérieur " .. (3 * l) .. "% → " .. (3 * (l + 1)) .. "%" end },
	{ key = "food", name = "Festin", emoji = "🍖", max = 20, cost = function(l) return 300 * 2.8 ^ l end,
		desc = function(l) return "Revenus +" .. (20 * l) .. "% → +" .. (20 * (l + 1)) .. "%" end },
	{ key = "lock", name = "Verrou", emoji = "🔒", max = 6, cost = function(l) return 300 * 3.5 ^ l end,
		desc = function(l) return "Œufs protégés " .. (Config.SHIELD_BASE + Config.SHIELD_PER_LEVEL * l) .. "s → " .. (Config.SHIELD_BASE + Config.SHIELD_PER_LEVEL * (l + 1)) .. "s" end },
}

function Config.upgrade(key)
	for _, u in ipairs(Config.UPGRADES) do
		if u.key == key then
			return u
		end
	end
	return nil
end

function Config.fmt(n)
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	if n < 1000 then
		if n < 10 and n % 1 ~= 0 then
			return string.format("%.1f", n)
		end
		return tostring(math.floor(n))
	end
	local u = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }
	local i = 0
	while n >= 1000 and i < #u do
		n = n / 1000
		i += 1
	end
	if n < 10 then
		return string.format("%.2f%s", n, u[i])
	elseif n < 100 then
		return string.format("%.1f%s", n, u[i])
	end
	return string.format("%d%s", math.floor(n), u[i])
end

function Config.fmtTime(s)
	s = math.max(0, math.ceil(s))
	if s < 60 then
		return s .. "s"
	end
	return string.format("%dm%02d", s // 60, s % 60)
end

function Config.petIncome(p, s, m)
	return Config.PETS[p].inc * Config.SIZES[s].mult * Config.MUTS[m].mult
end

function Config.sellValue(p, s, m)
	return math.max(1, math.floor(Config.petIncome(p, s, m) * 45 + 0.5))
end

function Config.petName(p, s, m)
	local n = Config.PETS[p].name
	if m > 1 then
		n = n .. " " .. Config.MUTS[m].name
	end
	if s ~= 2 then
		n = n .. " " .. Config.SIZES[s].name
	end
	return n
end

-- Sons : par défaut, sons intégrés au client Roblox (non vérifiés ici : si l'un manque, il reste simplement silencieux).
-- Remplace "id" par un ID du Creator Store ("rbxassetid://123456") pour de vrais sons ; id = "" désactive le son. speed = hauteur, vol = volume.
Config.SOUNDS = {
	hatch = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.0, vol = 0.5 },
	rare = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.6, vol = 0.8 },
	steal = { id = "rbxasset://sounds/action_jump.mp3", speed = 1.5, vol = 0.5 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", speed = 1.0, vol = 0.6 },
	claim = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 1.3, vol = 0.6 },
	click = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 2.0, vol = 0.25 },
	event = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.8, vol = 0.7 },
}

-- Produits développeur (achats Robux ponctuels). Crée-les dans Monetization > Developer Products, colle l'ID (0 = désactivé).
Config.PRODUCTS = {
	InstantHatch = { id = 0, name = "Éclosion instantanée", emoji = "⚡", desc = "Fait éclore tous tes œufs tout de suite." },
	LuckPotion = { id = 0, name = "Potion de chance", emoji = "🧪", desc = "+25% de pets supérieurs pendant 15 min." },
	CoinPack = { id = 0, name = "Sac de pièces", emoji = "👛", desc = "Offre 20 minutes de revenus (minimum 5 000 pièces)." },
}
Config.COIN_PACK_MINUTES = 20
Config.COIN_PACK_MIN = 5000
-- Un achat n'est proposé que si son ID Roblox a été renseigné (entier > 0). Sinon il reste désactivé, avec un message clair.
function Config.purchasable(def)
	return type(def.id) == "number" and def.id > 0 and def.id % 1 == 0
end
Config.UNAVAILABLE_MESSAGE = "🛒 Cet achat n'est pas encore disponible. Reviens bientôt !"

Config.LUCK_POTION_BONUS = 25
Config.LUCK_POTION_SECONDS = 900

Config.MAX_FOLLOWERS = 3 -- pets qui suivent le joueur
Config.SCORE_UNIT = 100000 -- classement : score = renaissances * SCORE_UNIT + œufs éclos

function Config.questText(t, n)
	if t == "steal" then
		return "Voler " .. n .. " œufs aux rivaux"
	elseif t == "hatch" then
		return "Faire éclore " .. n .. " œufs"
	elseif t == "earn" then
		return "Gagner " .. Config.fmt(n) .. " pièces"
	elseif t == "train" then
		return "Courir " .. n .. "s sur le tapis"
	elseif t == "pvp" then
		return "Voler " .. n .. " œuf(s) à d'autres joueurs"
	elseif t == "discover" then
		return "Découvrir " .. n .. " nouvelle(s) espèce(s)"
	elseif t == "sell" then
		return "Vendre " .. n .. " pet(s)"
	end
	return t
end

---------------------------------------------------------------- Modèles Roblox pour l'apparence des œufs
-- Seule l'APPARENCE change : éclosion, raretés, probabilités et animations ne dépendent pas de ces modèles. Chargement côté serveur
-- uniquement (InsertService:LoadAsset), sous pcall, avec délai maximum, une seule fois au démarrage (puis clonage). Tout Script,
-- LocalScript, ModuleScript, RemoteEvent, BindableEvent... est supprimé du modèle. Si le chargement échoue (modèle absent, vide, corrompu,
-- trop lourd, trop lent, non autorisé), l'apparence actuelle est gardée. `Enabled = false` : aucun chargement.
Config.Assets = {
	Enabled = true, -- interrupteur général (false : aucun chargement, apparence construite par le code)
	timeout = 8, -- secondes maximum par modèle
	maxParts = 60, -- un modèle plus lourd est refusé (il est cloné pour chaque œuf)
	maxParticleRate = 20, -- plafond des émetteurs de particules du modèle (par seconde)
	targetHeight = 3.4, -- hauteur en studs à laquelle chaque modèle est ramené
	eggs = {
		red = 151044983, -- œuf rouge
		orange = 147144059, -- œuf orange
		purple = 112478990, -- œuf à aura violette
		legendary = 2937230482, -- œuf légendaire
		glitch = 2937218888, -- œuf glitch
	},
	-- Rareté de l'œuf (1 = Commun ... 6 = Cosmique) -> modèle.
	eggByTier = { "red", "orange", "purple", "legendary", "legendary", "glitch" },
	-- Classes supprimées de tout modèle chargé (code, communication, sons, effets à effet de bord, outils, liaisons parasites).
	blockedClasses = {
		"Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction",
		"Sound", "Tool", "ForceField", "Explosion", "Weld", "WeldConstraint", "Motor6D", "ManualWeld", "Motor",
	},
}

---------------------------------------------------------------- Apparence des œufs construite par le code (repli des modèles, utilisée aussi quand ils sont coupés)
-- Une apparence distincte par modèle de Config.Assets.eggs : couleur, matériau, lumière, particules, halo (sphère ou anneau, qui tourne ou
-- scintille côté client). `Enabled = false` : œufs simples (couleur + sphère), utile pour alléger les téléphones modestes.
Config.EggFx = {
	Enabled = true,
	looks = {
		red = { name = "Rouge", color = Color3.fromRGB(222, 56, 56), material = "SmoothPlastic", light = Color3.fromRGB(255, 96, 96) },
		orange = {
			name = "Orange",
			color = Color3.fromRGB(255, 150, 40),
			material = "Plastic",
			light = Color3.fromRGB(255, 170, 70),
			particles = { color = Color3.fromRGB(255, 190, 90), rate = 3, speed = 1.5, size = 0.25, life = 1.2 },
		},
		purple = {
			name = "Aura violette",
			color = Color3.fromRGB(150, 80, 235),
			material = "Neon",
			light = Color3.fromRGB(180, 110, 255),
			halo = { shape = "ball", color = Color3.fromRGB(205, 150, 255), scale = 1.4, transparency = 0.78 },
			particles = { color = Color3.fromRGB(215, 170, 255), rate = 8, speed = 2, size = 0.3, life = 1.6 },
		},
		legendary = {
			name = "Légendaire",
			color = Color3.fromRGB(255, 205, 60),
			material = "Metal",
			light = Color3.fromRGB(255, 220, 110),
			brightness = 2,
			halo = { shape = "ring", color = Color3.fromRGB(255, 235, 140), scale = 1.55, transparency = 0.25, spin = 1.6 },
			particles = { color = Color3.fromRGB(255, 230, 120), rate = 10, speed = 2.5, size = 0.3, life = 1.5 },
		},
		glitch = {
			name = "Glitch",
			color = Color3.fromRGB(40, 255, 230),
			material = "Neon",
			light = Color3.fromRGB(255, 60, 210),
			brightness = 2,
			halo = { shape = "ball", color = Color3.fromRGB(255, 40, 200), scale = 1.22, transparency = 0.55, flicker = true },
			particles = { color = Color3.fromRGB(255, 70, 215), rate = 14, speed = 5, size = 0.22, life = 0.6 },
		},
	},
}

-- Apparence (table de Config.EggFx.looks) de l'œuf de rareté `tier`, ou nil.
function Config.eggLook(tier)
	local key = Config.eggAssetKey(tier)
	return key and Config.EggFx.looks[key] or nil
end

function Config.isBlockedClass(className)
	for _, c in ipairs(Config.Assets.blockedClasses) do
		if c == className then
			return true
		end
	end
	return false
end

-- Clé de modèle d'un œuf de rareté `tier` (nil si inconnue).
function Config.eggAssetKey(tier)
	return Config.Assets.eggByTier[tier]
end

-- ID du modèle d'un œuf de rareté `tier`, ou nil : chargement coupé, rareté inconnue ou ID invalide (entier > 0 exigé).
function Config.eggAssetId(tier)
	if Config.Assets.Enabled ~= true then
		return nil
	end
	local key = Config.eggAssetKey(tier)
	local id = key and Config.Assets.eggs[key]
	if type(id) == "number" and id > 0 and id % 1 == 0 then
		return id
	end
	return nil
end

---------------------------------------------------------------- Animations (client)
-- Chaque animation est activable séparément. `enabled = false` coupe tout. Une animation qui lève une erreur est désactivée
-- automatiquement pour la session (voir Easing.guard). Aucune n'est nécessaire au gameplay.
Config.Animations = {
	enabled = true, -- interrupteur général
	eggShake = true, -- l'œuf tremble puis blanchit juste avant d'éclore
	eggBounce = true, -- les œufs (nids, bases, portés) rebondissent légèrement
	hatchSquash = true, -- squash & stretch de l'œuf avant l'éclosion et du pet à son apparition
	popIn = true, -- le pet apparaît en grossissant
	shockwave = true, -- anneau lumineux à l'éclosion
	harvest = true, -- l'œuf s'envole vers le joueur à la récolte
	petBlink = true, -- clignement des yeux des pets
	petLook = true, -- les yeux des pets regardent autour
	petMouth = true, -- la bouche des pets s'anime
	menuTransitions = true, -- ouverture et fermeture animées des menus
	reward = true, -- confettis lors d'une récompense (chapitre, succès, énigme, rare)
	zones = true, -- barrières de zone pulsantes et dissolution à l'ouverture
	characterPop = true, -- petite secousse de caméra quand on prend un œuf ou qu'on est attrapé
	hen = true, -- Mère Poule picore
	zoneAmbience = true, -- éclairage et atmosphère propres à chaque domaine
	eggHalo = true, -- halos des œufs : anneau qui tourne, scintillement du glitch
}

function Config.animEnabled(name)
	return Config.Animations.enabled == true and Config.Animations[name] == true
end

---------------------------------------------------------------- Cinématiques (aux moments clés seulement)
-- Toujours skippables (bouton « Passer », Entrée, manette B), jamais bloquantes (le joueur garde le contrôle de son personnage,
-- la caméra est restituée quoi qu'il arrive), exécutées sous pcall. `enabled = false` coupe tout ; chaque clé coupe une cinématique.
Config.Cinematics = {
	enabled = true, -- interrupteur général
	intro = true, -- courte intro : la ferme, Mère Poule, les œufs, le but (premier lancement)
	tutorial = true, -- mini tutoriel : récolte, éclosion, zones (enchaîné à l'intro au premier lancement)
	firstZone = true, -- la première zone débloquée
	firstRare = true, -- le premier pet rare
	replay = true, -- boutons « Revoir l'intro / le tutoriel » dans le menu Plus
	watchdog = 4, -- sécurité : au-delà de la durée + ce délai (secondes), la caméra est rendue de force
}
Config.CINE_IDS = { "intro", "tutorial", "firstZone", "firstRare" } -- identifiants mémorisés dans la sauvegarde une fois vus

function Config.cineEnabled(name)
	return Config.Cinematics.enabled == true and Config.Cinematics[name] == true
end

-- Ancres de caméra : arena (le Grand Nid), hen (Mère Poule), rival1..3 (domaines), base (ta base), pad (un emplacement de ta base).
-- Les positions d'un plan sont { x, y, z } dans le repère de l'ancre ; `toPos` / `toLook` (facultatifs) animent le plan ; `fx = "sparkle"` (facultatif) lance des étincelles au point visé.
Config.CINE_ANCHORS = { arena = true, hen = true, rival1 = true, rival2 = true, rival3 = true, base = true, pad = true }

Config.CINE = {
	intro = { id = "intro", shots = {
		{ anchor = "arena", pos = { 0, 70, 100 }, look = { 0, 6, 0 }, toPos = { 0, 44, 72 }, dur = 4.5, text = "Il était une fois une ferme où la Grande Couvée donnait vie à tout le royaume…" },
		{ anchor = "hen", pos = { 6, 4, -9 }, look = { 0, 3, 0 }, toPos = { 4, 4, -6 }, dur = 4, fx = "sparkle", text = "Mère Poule veillait sur le Grand Nid, gardienne de tous les œufs." },
		{ anchor = "rival1", pos = { 0, 20, 28 }, look = { 0, 2, -3 }, toPos = { 0, 15, 22 }, dur = 4, fx = "sparkle", text = "Mais le Nid s'est brisé et ses œufs se sont dispersés. Les brigands les gardent !" },
		{ anchor = "base", pos = { 0, 16, 36 }, look = { 0, 3, 0 }, toPos = { 0, 12, 28 }, dur = 4, text = "À toi, apprenti Chipeur : chipe les œufs, fais-les éclore et reconstruis le Grand Nid !" },
	} },
	tutorial = { id = "tutorial", shots = {
		{ anchor = "rival1", pos = { 0, 12, 22 }, look = { 0, 3, -3 }, toPos = { 0, 9, 17 }, dur = 4, text = "① RÉCOLTE : maintiens le bouton devant un œuf pour le chiper. Attention au chien de garde !" },
		{ anchor = "base", pos = { 0, 10, -22 }, look = { 0, 1, 6 }, toPos = { 0, 7, -14 }, dur = 4, text = "② ÉCLOSION : rapporte l'œuf ici. Touche-le pour l'aider à éclore !" },
		{ anchor = "rival2", pos = { 0, 22, 48 }, look = { 0, 6, -2 }, toPos = { 0, 16, 36 }, dur = 4, text = "③ ZONES : réussis les chapitres de l'histoire pour ouvrir de nouveaux domaines." },
	} },
}

-- Cinématique de la première zone débloquée (zoneIdx = 2 ou 3).
function Config.cineFirstZone(zoneIdx)
	local zone, rival = Config.ZONES[zoneIdx], Config.RIVALS[zoneIdx]
	return { id = "firstZone", shots = {
		{ anchor = "rival" .. zoneIdx, pos = { 0, 18, 46 }, look = { 0, 5, -2 }, toPos = { 0, 12, 34 }, dur = 3, text = "🔓 " .. zone.name .. " est ouvert !" },
		{ anchor = "rival" .. zoneIdx, pos = { 18, 8, 24 }, look = { 0, 3, -3 }, toPos = { 10, 7, 18 }, dur = 3, text = "Ses œufs sont plus rares… et " .. rival.name .. " a un gardien plus rapide !" },
	} }
end

-- Cinématique du premier pet rare ; ancre « pad » = l'emplacement où il vient d'éclore.
function Config.cineFirstRare(petName, tierName, incText)
	return { id = "firstRare", shots = {
		{ anchor = "pad", pos = { 0, 4.5, -13 }, look = { 0, 2.5, 0 }, toPos = { 0, 3.5, -8 }, dur = 3.5, text = "✨ Un pet " .. tierName .. " : " .. petName .. " !" },
		{ anchor = "pad", pos = { 6, 4, -8 }, look = { 0, 2.5, 0 }, toPos = { -6, 4, -8 }, dur = 2.5, text = incText .. " Les raretés supérieures rapportent bien plus." },
	} }
end

-- Position locale (x, z) de l'emplacement `idx` (1..12) dans une base : source unique pour la construction et les caméras.
function Config.padLocal(idx)
	local col, row = (idx - 1) % 4, (idx - 1) // 4
	return -15 + col * 10, -6 + row * 11
end

---------------------------------------------------------------- Univers, histoire et progression
Config.TITLE = "Chipe-Œufs"
Config.TAGLINE = "Chipe, couve, collectionne : deviens Roi des Couvées !"
Config.LORE = "Il y a longtemps, la Grande Couvée donnait vie à tout le royaume. Puis le Grand Nid a volé en éclats, et ses œufs se sont dispersés. "
	.. "Les brigands Gus, Mara et Zed les gardent jalousement. Toi, apprenti Chipeur, tu peux les reprendre, les faire éclore et reconstruire le Nid. "
	.. "Mais méfie-toi : les autres Chipeurs convoitent aussi tes œufs !"

---------------------------------------------------------------- Carte : dimensions, domaines, ambiance par zone, secrets, budget
-- Le sol fait 1200 x 1200 studs (la carte précédente : 620). Les bases forment un anneau de rayon 215 autour de l'arène centrale, les
-- trois domaines (Gus, Mara, Zed) sont au nord, chacun dans son propre biome, et des repères et secrets sont répartis plus loin.
Config.Map = {
	groundSize = 1200,
	plotRadius = 215,
	rivalSpacing = 90,
	rivalZ = -95,
	domainRadius = 38,
	ambienceRadius = 62, -- distance du centre d'un domaine à partir de laquelle son ambiance s'applique
	budgetParts = 7000, -- le serveur avertit au démarrage si la carte dépasse ce nombre de Parts (budget mobile)
	Streaming = { Enabled = true, MinRadius = 128, TargetRadius = 480 },
	zoneKeys = { "gus", "mara", "zed" }, -- une clé par rival, dans l'ordre de Config.RIVALS
	ambience = {
		arena = { clock = 15.3, ambient = Color3.fromRGB(95, 105, 120), outdoor = Color3.fromRGB(125, 135, 155), tint = Color3.fromRGB(255, 255, 255), atmo = Color3.fromRGB(199, 220, 255), density = 0.28, haze = 1.4 },
		gus = { clock = 16.6, ambient = Color3.fromRGB(125, 110, 90), outdoor = Color3.fromRGB(165, 145, 110), tint = Color3.fromRGB(255, 244, 222), atmo = Color3.fromRGB(255, 226, 170), density = 0.25, haze = 1.2 },
		mara = { clock = 19.0, ambient = Color3.fromRGB(95, 70, 130), outdoor = Color3.fromRGB(105, 85, 150), tint = Color3.fromRGB(226, 214, 255), atmo = Color3.fromRGB(165, 125, 210), density = 0.42, haze = 2.0 },
		zed = { clock = 17.4, ambient = Color3.fromRGB(135, 75, 65), outdoor = Color3.fromRGB(160, 90, 75), tint = Color3.fromRGB(255, 208, 196), atmo = Color3.fromRGB(255, 140, 100), density = 0.40, haze = 2.2 },
	},
}

-- Centre (x, z) du domaine du rival i. Source unique : Builder, Cinematics et les tests.
function Config.rivalCenter(i)
	return (i - 2) * Config.Map.rivalSpacing, Config.Map.rivalZ
end

-- Zone d'ambiance d'une position : "arena" ou la clé du domaine (gus / mara / zed) le plus proche, s'il est à portée.
function Config.zoneAt(x, z)
	local best, bd = "arena", Config.Map.ambienceRadius
	for i, key in ipairs(Config.Map.zoneKeys) do
		local cx, cz = Config.rivalCenter(i)
		local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
		if d <= bd then
			best, bd = key, d
		end
	end
	return best
end

-- Secrets : un lieu caché par domaine ; une récompense par jour et par secret (max(minCoins, revenus de `mins` minutes)).
Config.SECRETS = {
	{ id = "verger", name = "L'œuf d'or du verger", emoji = "🥇", x = -340, z = -330, mins = 4, minCoins = 1500, hint = "Au bout du sentier de la ferme, derrière les champs, un verger oublié garde un trésor." },
	{ id = "lanterne", name = "La lanterne de Mara", emoji = "🏮", x = 0, z = -450, mins = 6, minCoins = 4000, hint = "Dans les bois de Mara, une lueur persiste là où personne ne va." },
	{ id = "coeur", name = "Le cœur de lave", emoji = "🔥", x = 340, z = -330, mins = 8, minCoins = 9000, hint = "La citadelle de Zed cache un cœur brûlant sur son flanc est." },
}

function Config.secret(id)
	for _, sct in ipairs(Config.SECRETS) do
		if sct.id == id then
			return sct
		end
	end
	return nil
end

function Config.secretReward(sct, income)
	return math.floor(math.max(sct.minCoins, income * sct.mins * 60))
end

-- Domaines des rivaux : verrouillés tant que le chapitre `chapter` de l'histoire n'est pas réussi.
Config.ZONES = {
	{ name = "Domaine de Gus", chapter = 0 },
	{ name = "Domaine de Mara", chapter = 3 },
	{ name = "Citadelle de Zed", chapter = 6 },
}

-- Rangs selon le nombre de chapitres réussis.
Config.RANKS = {
	{ chapter = 0, name = "Apprenti", emoji = "🥚" },
	{ chapter = 3, name = "Chipeur", emoji = "🧤" },
	{ chapter = 6, name = "Maître Chipeur", emoji = "🥷" },
	{ chapter = 9, name = "Seigneur des Couvées", emoji = "👑" },
	{ chapter = 12, name = "Roi des Couvées", emoji = "🐉" },
}

-- Histoire : suite de chapitres. type = hatch | steal | train (secondes) | species (espèces découvertes) | tier (pet de rareté >= `tier` obtenu)
-- | mut (pet muté obtenu) | puzzle (énigme du jour résolue) | rebirth. `rival` : ne compte que les vols chez ce rival. Récompense = max(coins, revenus de `mins` minutes).
Config.STORY = {
	{ title = "L'œuf d'argent", text = "Le Grand Nid s'est brisé, mais un dernier œuf dort dans ta base. Fais-le éclore : touche-le pour l'aider !", type = "hatch", goal = 1, coins = 100, mins = 0 },
	{ title = "Premier larcin", text = "Les brigands de Gus gardent des œufs au nord. Maintiens le bouton devant un nid pour en chiper un, puis rapporte-le chez toi.", type = "steal", goal = 1, coins = 250, mins = 0 },
	{ title = "Souffle court", text = "Les chiens de garde courent vite. Entraîne-toi sur le tapis roulant du centre : plus tu es rapide, plus tu es libre.", type = "train", goal = 45, coins = 500, mins = 1 },
	{ title = "Le petit cabinet", text = "Un vrai Chipeur collectionne. Découvre 3 espèces différentes : chaque série de 3 augmente tes revenus pour toujours.", type = "species", goal = 3, coins = 800, mins = 2 },
	{ title = "La Dame Mara", text = "Le domaine de Mara s'ouvre à toi. Ses œufs sont épiques, mais son loup est plus rapide que le chien de Gus. Chipe 5 œufs chez elle.", type = "steal", goal = 5, rival = 2, coins = 2000, mins = 5 },
	{ title = "Éclat épique", text = "Fais éclore un pet Épique ou mieux. Les œufs plus rares donnent plus souvent des pets plus rares.", type = "tier", goal = 1, tier = 3, coins = 5000, mins = 8 },
	{ title = "Mutation !", text = "La Citadelle de Zed est ouverte. Mais d'abord, un miracle : fais éclore un pet muté (Doré, Néon, Arc-en-ciel ou Alien).", type = "mut", goal = 1, coins = 10000, mins = 10 },
	{ title = "Le murmure des runes", text = "Les runes du Grand Nid s'éveillent chaque jour. Lis l'énigme de Mère Poule (Missions > Énigme), tourne les 4 runes autour du Nid, puis touche le Nid pour valider.", type = "puzzle", goal = 1, coins = 15000, mins = 12 },
	{ title = "Chipeur confirmé", text = "Ta réputation grandit. Chipe 15 œufs au total, chez les rivaux ou chez d'autres Chipeurs.", type = "steal", goal = 15, coins = 25000, mins = 15 },
	{ title = "Le Roi Zed", text = "Zed garde les meilleurs œufs, dont les Cosmiques. Son ours ne rigole pas. Chipe 8 œufs dans sa citadelle.", type = "steal", goal = 8, rival = 3, coins = 60000, mins = 20 },
	{ title = "Légende vivante", text = "Fais éclore un pet Mythique : l'œuf du Dragon n'est plus loin.", type = "tier", goal = 1, tier = 5, coins = 150000, mins = 30 },
	{ title = "Le Grand Nid s'éveille", text = "Le Nid est prêt à renaître. Renais une fois pour le reconstruire, plus fort, et deviens Roi des Couvées !", type = "rebirth", goal = 1, coins = 300000, mins = 45 },
}

Config.COLLECTION_STEP = 3 -- tous les 3 espèces découvertes...
Config.COLLECTION_BONUS = 0.05 -- ...+5% de revenus permanents (max +30% avec les 18 espèces)
Config.PITY_EVERY = 12 -- tous les 12 éclosions sans pet de rareté supérieure, la suivante l'est garantie

function Config.rankFor(chaptersDone)
	local best = Config.RANKS[1]
	for _, r in ipairs(Config.RANKS) do
		if chaptersDone >= r.chapter then
			best = r
		end
	end
	return best
end

function Config.collectionBonus(speciesCount)
	return 1 + Config.COLLECTION_BONUS * math.floor(speciesCount / Config.COLLECTION_STEP)
end

function Config.zoneUnlocked(chaptersDone, rival)
	local z = Config.ZONES[rival]
	return z ~= nil and chaptersDone >= z.chapter
end

-- Texte de l'objectif d'un chapitre.
function Config.storyGoalText(c)
	local rival = c.rival and (" chez " .. Config.RIVALS[c.rival].name) or ""
	if c.type == "hatch" then
		return "Faire éclore " .. c.goal .. " œuf(s)"
	elseif c.type == "steal" then
		return "Chiper " .. c.goal .. " œuf(s)" .. rival
	elseif c.type == "train" then
		return "Courir " .. c.goal .. " secondes sur le tapis roulant"
	elseif c.type == "species" then
		return "Découvrir " .. c.goal .. " espèces différentes"
	elseif c.type == "tier" then
		return "Obtenir un pet " .. Config.TIERS[c.tier].name .. " ou mieux"
	elseif c.type == "mut" then
		return "Obtenir un pet muté"
	elseif c.type == "puzzle" then
		return "Résoudre l'énigme des runes"
	elseif c.type == "rebirth" then
		return "Renaître " .. c.goal .. " fois"
	end
	return c.type
end

-- Réglages d'interface (chaque ajout se coupe ici).
Config.HUD = {
	objective = true, -- carte « objectif en cours » (chapitre de l'histoire) sous les compteurs
}

-- Objectif affiché en permanence : chapitre en cours de l'histoire (nil si l'histoire est terminée).
-- st = { ch = chapitres réussis, prog = progression du chapitre en cours }.
function Config.objective(st)
	local c = Config.STORY[(st.ch or 0) + 1]
	if not c then
		return nil
	end
	local prog = math.min(math.max(st.prog or 0, 0), c.goal)
	return { index = (st.ch or 0) + 1, total = #Config.STORY, title = c.title, text = Config.storyGoalText(c), prog = prog, goal = c.goal, done = prog >= c.goal }
end

-- Récompense de pièces d'un chapitre pour un revenu donné (par seconde).
function Config.storyReward(chapter, income)
	return math.floor(math.max(chapter.coins, income * chapter.mins * 60))
end

---------------------------------------------------------------- Énigmes des runes (Grand Nid)
-- Quatre runes autour du monument (Nord, Est, Sud, Ouest). Chaque jour, Mère Poule énonce un indice par direction ; le joueur doit
-- régler chaque rune sur le bon symbole puis valider en touchant le Grand Nid. L'énigme est la même pour tous les joueurs un jour donné.
Config.RUNES = { "🔥", "🌊", "🌿", "⭐" }
Config.RUNE_DIRECTIONS = { "Nord", "Est", "Sud", "Ouest" }
Config.RUNE_LOCK_SECONDS = 6 -- pause après une mauvaise combinaison (empêche d'essayer au hasard en boucle)
Config.PUZZLE_EGG_TIER = 3 -- récompense : un œuf Épique (ou son prix en pièces si la base est pleine)
Config.PUZZLE_MINS = 10 -- + pièces : max(2000, 10 minutes de revenus)

local RUNE_CLUES = {
	{ "ce qui danse et brûle", "la flamme qui crépite", "ce qui réchauffe et consume" },
	{ "ce qui coule et berce", "la vague qui murmure", "ce qui désaltère les rivières" },
	{ "ce qui pousse vers la lumière", "la feuille qui respire", "ce qui plonge ses racines" },
	{ "ce qui brille quand tout dort", "la lumière lointaine", "ce qui guide les voyageurs" },
}
local DIR_PREFIX = { "Au Nord", "À l'Est", "Au Sud", "À l'Ouest" }

-- Générateur pseudo-aléatoire déterministe (Park-Miller : les produits restent exacts en double précision).
local function dayRng(seed)
	local x = (seed * 7919 + 104729) % 2147483646 + 1
	local function raw()
		x = (x * 16807) % 2147483647
		return x
	end
	raw()
	raw()
	raw()
	return function(n)
		return raw() % n + 1
	end
end

-- Énigme d'un jour (day = os.time() // 86400). Retourne { answer = {symbole du Nord, de l'Est, du Sud, de l'Ouest}, text = énoncé }.
function Config.riddleFor(day)
	local r = dayRng(day)
	local order = { 1, 2, 3, 4 }
	for i = 4, 2, -1 do
		local j = r(i)
		order[i], order[j] = order[j], order[i]
	end
	local parts = {}
	for dir = 1, 4 do
		local clues = RUNE_CLUES[order[dir]]
		parts[dir] = DIR_PREFIX[dir] .. " : " .. clues[r(#clues)] .. "."
	end
	return { answer = order, text = table.concat(parts, " ") }
end

function Config.puzzleCoins(income)
	return math.floor(math.max(2000, income * Config.PUZZLE_MINS * 60))
end

---------------------------------------------------------------- Succès à paliers (récompenses permanentes de progression)
-- stat : hatched | stolen | species | rb | puzzles. goals : seuils des paliers successifs.
Config.ACHIEVEMENTS = {
	{ id = "hatched", name = "Éleveur", emoji = "🐣", stat = "hatched", unit = "œufs éclos", goals = { 10, 50, 250, 1000 } },
	{ id = "stolen", name = "Chipeur", emoji = "🧤", stat = "stolen", unit = "œufs chipés", goals = { 10, 50, 200, 800 } },
	{ id = "species", name = "Collectionneur", emoji = "📚", stat = "species", unit = "espèces découvertes", goals = { 3, 6, 12, 18 } },
	{ id = "rebirth", name = "Renaissant", emoji = "♻️", stat = "rb", unit = "renaissances", goals = { 1, 2, 4, 8 } },
	{ id = "puzzle", name = "Déchiffreur", emoji = "🔮", stat = "puzzles", unit = "énigmes résolues", goals = { 1, 5, 15, 40 } },
}
Config.ACH_REWARD = { coins = { 500, 5000, 50000, 500000 }, mins = { 1, 5, 20, 60 } }

function Config.achievement(id)
	for _, a in ipairs(Config.ACHIEVEMENTS) do
		if a.id == id then
			return a
		end
	end
	return nil
end

-- Récompense du palier `tier` (1..4) : max(pièces fixes, revenus de `mins` minutes).
function Config.achReward(tier, income)
	return math.floor(math.max(Config.ACH_REWARD.coins[tier], income * Config.ACH_REWARD.mins[tier] * 60))
end

-- Probabilités affichées dans le jeu (transparence sur les tirages aléatoires, exigée par Roblox pour les achats Robux liés au hasard)
function Config.oddsText()
	local function pct(list, none)
		local total = 0
		for _, x in ipairs(list) do
			total += x.weight
		end
		local out = {}
		for _, x in ipairs(list) do
			out[#out + 1] = string.format("%s %.1f%%", x.name == "" and none or x.name, x.weight / total * 100)
		end
		return table.concat(out, " · ")
	end
	return "🎲 Probabilités de base. Rareté du pet : 12% une rareté au-dessus de l'œuf, 22% en dessous, le reste de la même rareté (Trèfle, événements, Pass Chance et Potion augmentent la part « au-dessus », plafonnée à 70%). Mutations : "
		.. pct(Config.MUTS, "Aucune") .. " (le Biome Alien multiplie la mutation Alien par 5). Tailles : " .. pct(Config.SIZES, "Normal") .. "."
end

return Config
