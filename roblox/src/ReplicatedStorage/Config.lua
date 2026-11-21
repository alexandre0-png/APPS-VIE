-- ModuleScript : ReplicatedStorage/Shared/Config
-- Toutes les données d'équilibrage du jeu. Modifie ici, rien d'autre à toucher.
local Config = {}

Config.PLOT_COUNT = 5 -- nombre de bases (= Config.Game.MaxPlayers : une partie accueille 5 joueurs au plus)

---------------------------------------------------------------- Architecture hub + parties
-- Deux lieux : le HUB (petit lieu léger : zones de lancement 1 à 5 joueurs, parties des amis) et le lieu de JEU (la partie, 5 joueurs max).
-- Le rôle d'un serveur se déduit de game.PlaceId (Config.Game.roleFor). Identifiants = LIEUX (place ids), pas des univers.
-- Les deux lieux appartiennent à la MÊME expérience « Jeu des oeufs » (univers 10776613087) : la réservation de serveur privé
-- (TeleportService) et le registre MemoryStore du hub fonctionnent donc entre eux. Si la réservation échoue malgré tout, le code essaie
-- les replis de `Fallbacks` (serveur public) puis prévient le joueur. Hub = lieu de départ de l'expérience.
Config.Game = {
	Places = { hub = 115261336085924, game = 87012762353093 },
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
	{ name = "Gus", emoji = "🤠", stars = 1, weights = { 60, 35, 5, 0, 0, 0 }, guardSpeed = 13, patrolSpeed = 7, viewDist = 24, viewAngle = 100, hearRadius = 12, damage = 14, color = Color3.fromRGB(111, 191, 115) },
	{ name = "Mara", emoji = "🧛", stars = 2, weights = { 0, 40, 40, 20, 0, 0 }, guardSpeed = 19, patrolSpeed = 10, viewDist = 28, viewAngle = 110, hearRadius = 14, damage = 20, color = Color3.fromRGB(224, 164, 59) },
	{ name = "Zed", emoji = "🤖", stars = 3, weights = { 0, 0, 30, 45, 22, 3 }, guardSpeed = 26, patrolSpeed = 13, viewDist = 32, viewAngle = 120, hearRadius = 16, damage = 28, color = Color3.fromRGB(224, 87, 90) },
}

-- Gardiens : jamais de coup mortel d'un seul coup. Barre de vie, invulnérabilité courte après un coup, recul, régénération ; perception (vue + ouïe)
-- et états (voir Guard.lua). Voler DERRIÈRE un gardien (hors de son cône de vision) sans courir près de lui réussit sans combat.
Config.GUARD = {
	maxHp = 100, iframes = 1.6, regenDelay = 6, regenPerSec = 5, baseRegen = 25, knockback = 28, stun = 0.35, attackRange = 4.5, attackCd = 1.2,
	stillSpeed = 2, sneakSpeed = 12, sneakNoise = 0.4, -- bruit : immobile = 0, lent = 0,4, course = 1
	alertDelay = 0.6, alertMax = 3, loseDelay = 2.5, giveUpDist = 45, pathInterval = 0.8, respawnIframes = 3,
}

-- Mode Château : dégâts non mortels des pièges (mêmes pv et invulnérabilité que les gardiens), animation des pièges à 10 Hz, tableau des temps.
Config.CASTLE = { damage = { spikes = 18, blade = 24, ball = 28, knight = 22 }, step = 0.1, boardSeconds = 120, boardSize = 5 }

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
	Speed = { id = 0, name = "Vitesse +20 %", emoji = "👟", desc = "Cours 20 % plus vite, pour toujours." },
	VipBase = { id = 0, name = "Base VIP", emoji = "👑", desc = "Boucliers d'œufs x2 et bonus quotidien x2." },
}
Config.SPEED_PASS_MUL = 1.2
Config.VIP_SHIELD_MUL = 2
Config.VIP_DAILY_MUL = 2

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

-- Revente d'un œuf (jamais rentable : on récupère 25 % du prix, achat puis revente = perte de 75 %).
Config.EGG_SELL_RATIO = 0.25
function Config.eggSellValue(tier)
	local price = Config.EGG_PRICE[tier]
	return price and math.max(1, math.floor(price * Config.EGG_SELL_RATIO)) or 0
end

-- Doublons à revendre : pour chaque espèce, on garde le pet le plus rentable (revenu, puis indice le plus bas) et on revend les autres.
-- slots[i] = { k = "p", p, s, m } | { k = "e" } | false ; retourne (liste triée d'indices, valeur totale).
function Config.dupesToSell(slots, cap)
	local best = {} -- espèce -> { i, income }
	for i = 1, cap do
		local sl = slots[i]
		if sl and sl.k == "p" then
			local inc = Config.petIncome(sl.p, sl.s, sl.m)
			local b = best[sl.p]
			if not b or inc > b.income then
				best[sl.p] = { i = i, income = inc }
			end
		end
	end
	local out, total = {}, 0
	for i = 1, cap do
		local sl = slots[i]
		if sl and sl.k == "p" and best[sl.p].i ~= i then
			out[#out + 1] = i
			total = total + Config.sellValue(sl.p, sl.s, sl.m)
		end
	end
	return out, total
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
-- Sons synthétiques du jeu (approuvés, rbxassetid://). Effets : volume 0,5 à 0,7 ; ambiances en boucle (loop = true) : 0,25 à 0,4.
Config.SOUNDS = {
	hatch = { id = "rbxassetid://84390525214058", speed = 1.0, vol = 0.55 }, -- éclosion commune (pop)
	rare = { id = "rbxassetid://111600385012831", speed = 1.0, vol = 0.6 },
	epic = { id = "rbxassetid://111875674907537", speed = 1.0, vol = 0.65 },
	legendary = { id = "rbxassetid://90908436660215", speed = 1.0, vol = 0.7 },
	hatchSecret = { id = "rbxassetid://124766540033525", speed = 1.0, vol = 0.7 },
	coin = { id = "rbxassetid://110088134711268", speed = 1.0, vol = 0.5 },
	buy = { id = "rbxassetid://113679524214656", speed = 1.0, vol = 0.55 },
	refuse = { id = "rbxassetid://75136819922416", speed = 1.0, vol = 0.5 },
	growl = { id = "rbxassetid://72413498813091", speed = 1.0, vol = 0.6 }, -- loup / ours : alerte ou poursuite
	bark = { id = "rbxassetid://114298173898782", speed = 1.0, vol = 0.6 }, -- chien
	hurt = { id = "rbxassetid://97370499111519", speed = 1.0, vol = 0.65 },
	spikes = { id = "rbxassetid://115413112102226", speed = 1.0, vol = 0.5 },
	blade = { id = "rbxassetid://84863036780507", speed = 1.0, vol = 0.5, loop = true }, -- près d'une lame
	ball = { id = "rbxassetid://93517357278251", speed = 1.0, vol = 0.5, loop = true }, -- près d'un boulet qui roule
	fanfare = { id = "rbxassetid://126605194205875", speed = 1.0, vol = 0.7 },
	ambCastle = { id = "rbxassetid://123273835786709", speed = 1.0, vol = 0.3, loop = true },
	ambMeadow = { id = "rbxassetid://89353143614427", speed = 1.0, vol = 0.3, loop = true },
	steal = { id = "rbxasset://sounds/action_jump.mp3", speed = 1.5, vol = 0.5 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", speed = 1.0, vol = 0.6 },
	claim = { id = "rbxassetid://110088134711268", speed = 1.15, vol = 0.55 },
	click = { id = "rbxassetid://123764673506668", speed = 1.0, vol = 0.4 },
	event = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.8, vol = 0.7 },
	-- Crochets pour de nouveaux sons : id = "" (silence) tant qu'aucun identifiant vérifié n'est fourni (rbxassetid://NOMBRE). Aucun n'est inventé.
	secret = { id = "", speed = 1.0, vol = 0.7 }, -- fouille d'un secret de la carte
	portal = { id = "", speed = 1.0, vol = 0.6 }, -- entrée dans un portail du hub
	menu = { id = "rbxassetid://123764673506668", speed = 1.0, vol = 0.4 }, -- ouverture d'un menu
}
Config.SOUNDS_ENABLED = true -- false : tout est muet
Config.VOLUME_STEPS = { 1, 0.6, 0.3, 0 } -- réglage du volume général (menu Plus) : 100 %, 60 %, 30 %, muet
function Config.volumeLabel(i)
	local v = Config.VOLUME_STEPS[i] or 1
	return v <= 0 and "Muet" or (math.floor(v * 100 + 0.5) .. " %")
end

-- Clé de son d'éclosion d'après la rareté du pet (1 Commun .. 6 Cosmique) ; secret ou Cosmique = son secret.
function Config.hatchSoundKey(tier, secret)
	if secret or tier >= 6 then
		return "hatchSecret"
	elseif tier >= 4 then
		return "legendary"
	elseif tier == 3 then
		return "epic"
	elseif tier == 2 then
		return "rare"
	end
	return "hatch"
end

-- Volume réel d'un son : volume de la définition x réglage général (0..1) ; 0 si muet, désactivé, inconnu ou sans identifiant.
function Config.soundVolume(key, master)
	local def = Config.SOUNDS[key]
	if not Config.SOUNDS_ENABLED or not def or def.id == "" then
		return 0
	end
	local m = type(master) == "number" and master == master and math.min(math.max(master, 0), 1) or 1
	return def.vol * m
end

-- Son d'alerte d'un gardien (modèle du domaine : chien = aboiement, sinon grognement).
function Config.guardSoundKey(guardKind)
	return guardKind == "dog" and "bark" or "growl"
end

-- Ambiance en boucle : château ou prairie (dehors). Aucune avant que la carte soit prête (ready = false).
function Config.ambienceKey(ready, inCastle)
	if not ready then
		return nil
	end
	return inCastle and "ambCastle" or "ambMeadow"
end

-- Volume d'une boucle localisée (lame, boulet) : plein près de la source, nul au-delà de maxDist (décroissance linéaire).
function Config.loopFade(dist, maxDist)
	if type(dist) ~= "number" or dist ~= dist or dist >= maxDist then
		return 0
	end
	return 1 - math.max(dist, 0) / maxDist
end

-- Produits développeur (achats Robux ponctuels). Crée-les dans Monetization > Developer Products, colle l'ID (0 = désactivé).
Config.PRODUCTS = {
	InstantHatch = { id = 0, name = "Éclosion instantanée", emoji = "⚡", desc = "Fait éclore tous tes œufs tout de suite." },
	LuckPotion = { id = 0, name = "Potion de chance", emoji = "🧪", desc = "+25% de pets supérieurs pendant 15 min." },
	StarterPack = { id = 0, once = true, name = "Pack de départ", emoji = "🎁", desc = "Une seule fois : 20 000 pièces, 3 œufs Rares et une potion de chance." },
	ExclusiveEgg = { id = 0, name = "Œuf exclusif Mythique", emoji = "🥚", desc = "Un œuf Mythique placé directement dans ta base (il faut une place libre)." },
	Revive = { id = 0, name = "Relance immédiate", emoji = "💫", desc = "Au Château : repars aussitôt là où tu es tombé, pv rétablis, sans compter la défaite. Le retour gratuit au début de la salle reste disponible." },
	CoinPack = { id = 0, name = "Sac de pièces", emoji = "👛", desc = "Offre 20 minutes de revenus (minimum 5 000 pièces)." },
}
Config.STARTER_PACK = { coins = 20000, eggTier = 2, eggs = 3 }
Config.EXCLUSIVE_EGG_TIER = 5
Config.REVIVE = { offerSeconds = 20, iframes = 4 } -- offre de relance après une défaite au château (non bloquante), invulnérabilité après la relance
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
	elseif t == "castle" then
		return "Terminer le Château (ouvrir le coffre final)"
	elseif t == "rare" then
		return "Faire éclore " .. n .. " pet(s) Épique ou mieux"
	elseif t == "secret" then
		return "Fouiller " .. n .. " secret(s) de la carte"
	end
	return t
end

-- Bonus de mission au-delà des pièces : { egg = rareté d'œuf, boost = secondes de chance supplémentaire }. Missions de défi (Château, rare, secret) :
-- œuf ou boost ; sinon la 2e mission du jour donne un œuf (rareté selon la progression d'histoire `ch`), la 3e un boost de chance de 10 minutes.
function Config.questBonus(t, index, ch)
	ch = ch or 0
	local tier = 1 + (ch >= 4 and 1 or 0) + (ch >= 8 and 1 or 0)
	if t == "castle" then
		return { egg = math.min(4, 3 + (ch >= 8 and 1 or 0)) }
	elseif t == "rare" then
		return { boost = 900 }
	elseif t == "secret" then
		return { egg = 2 }
	elseif index == 2 then
		return { egg = tier }
	elseif index == 3 then
		return { boost = 600 }
	end
	return {}
end

-- Texte de la récompense d'une mission : « 🪙 1,2K · 🥚 Rare · 🍀 +10 min ».
function Config.questRewardText(q)
	local parts = { "🪙 " .. Config.fmt(q.rew or 0) }
	if (q.re or 0) > 0 and Config.TIERS[q.re] then
		parts[#parts + 1] = "🥚 " .. Config.TIERS[q.re].name
	end
	if (q.rb or 0) > 0 then
		parts[#parts + 1] = "🍀 +" .. math.floor(q.rb / 60 + 0.5) .. " min de chance"
	end
	return table.concat(parts, " · ")
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
	decorMaxParts = 220, -- plafond des modèles de décor du hub (placés une seule fois)
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
	-- Modèles BLENDER de l'utilisateur (approuvés) : convention de couleur `Nom__RRGGBB` lue par Assets.colorize (les couleurs du FBX sont ignorées).
	-- Œufs par rareté de pet (1 Commun .. 5 Mythique, 6 Cosmique = œuf Secret) : prioritaires sur les modèles du catalogue, repli : catalogue puis code.
	eggsByRarity = {
		[1] = 100023720665590, -- OeufCommun
		[2] = 74975545149168, -- OeufRare
		[3] = 86639017295697, -- OeufEpique
		[4] = 137014263068694, -- OeufLegendaire
		[5] = 110535599163330, -- OeufMythique
		[6] = 95190117262171, -- OeufSecret
		secret = 95190117262171,
	},
	-- Accessoires : arbres, rochers, cabanes, pont, fontaine (place du hub), nid d'œufs (sous chaque œuf).
	props = {
		tree = 88144895198576, -- Arbre
		fir = 79188790509321, -- Sapin
		rock = 132852439679625, -- Rocher
		bush = 81559211389899, -- Buisson
		bridge = 72821096584538, -- PontBois (4,4 de long)
		hut = 121389844339916, -- Cabane
		fence = 98207856976488, -- Barriere
		fountain = 87696152276058, -- Fontaine
		nest = 85337440768183, -- NidOeufs
	},
	-- Modèles Blender approuvés (convention `Nom__RRGGBB`, devant = -Y) : IDs enregistrés, pas encore tous câblés (voir BLENDER_REQUESTS.md).
	-- Pièces animées par code (noms de Parts attendus) : Pales/Pales2 (moulin), Herse (porte), Pics, Lame, Boulet, Couvercle (coffre), Flamme (torche).
	models = {
		props = { mill = 108678125939354, castle = 85826335560323, chest = 81643274706684, torch = 89605986322384, flag = 110279682395149, sign = 74276869239897, pen = 117636221218047, lamp = 137473402121117, bench = 123958905099505 },
		guards = { dog = 103939852527807, wolf = 97774277975586, bear = 70929301247964, knight = 79935066561502 },
		castle = { wall = 136500159645250, tower = 120194370584366, door = 81799010490650, floor = 87526275066787 },
		traps = { spikes = 109204482572726, blade = 83758069602274, ball = 97316525004480 },
		ground = { grass = 108336655087221, path = 129255762203803, plaza = 129476241883133 },
		vfx = { cercle_runique = 78887954880607, ailes = 139237669898830, halo = 123922819073158, rayons = 88635068911286, etoile = 73454147532566, cristaux = 84932789634035, onde = 125557026046168, torii = 105301464189354, spirale = 130478050046509, pilier_lumiere = 136359342334671, etincelles = 116678428336273, cone_lumiere = 98452721754905, bouclier = 135593787305812 },
		pets = { Chat = 81991111371408, Chien = 90815266946917, Hamster = 130387777043821, Hibou = 95489512823854, Licorne = 119358850090330, Lion = 73493068085290, Manchot = 73235151647339, TRex = 113312935651236 },
	},
	modelsMaxParts = { ["guards.dog"] = 80, ["guards.wolf"] = 80, ["guards.bear"] = 90, ["guards.knight"] = 100, ["traps.spikes"] = 60, ["traps.blade"] = 40, ["traps.ball"] = 30,
		["castle.wall"] = 30, ["castle.tower"] = 80, ["castle.door"] = 50, ["castle.floor"] = 20, ["props.chest"] = 40, ["props.torch"] = 20, ["props.flag"] = 20, ["props.castle"] = 220, ["props.mill"] = 120, ["props.pen"] = 40, ["props.lamp"] = 25, ["props.bench"] = 30, ["props.sign"] = 20,
		["ground.plaza"] = 30, ["ground.path"] = 30, ["ground.grass"] = 30 },
	-- Textures tuilables (IDs de DÉCALS, lus côté serveur) posées par Texture sur la face visible des grandes surfaces. `tile` = studs par répétition.
	-- Ordre de priorité = ordre de `textureOrder` ; au plus `textureMaxCount` Textures au total (mobile : une face par pièce).
	textures = {
		grass = { id = 122917279401510, tile = 8, targets = { { name = "Ground", faces = { "Top" } } } },
		water = { id = 72897294450066, tile = 10, transparency = 0.2, targets = { { name = "RiverSouth", faces = { "Top" } }, { name = "RiverWest", faces = { "Top" } }, { name = "MoatWater", faces = { "Top" } } } },
		castleFloor = { id = 90865253086689, tile = 8, targets = { { prefix = "CastleFloor", faces = { "Top" } } } },
		castleStone = { id = 87480813124386, tile = 6, targets = { { name = "CastleWall", faces = { "Left", "Right" } } } },
		wood = { id = 136082705365776, tile = 4, targets = { { name = "BridgePlank", faces = { "Top" } } } },
		sand = { id = 83914325296472, tile = 8, targets = { { name = "MoatBank", faces = { "Top" } } } },
		path = { id = 84243738566468, tile = 8, targets = { { name = "PathStone", faces = { "Right" } } } }, -- pavés cylindriques : face plate = Right
	},
	textureOrder = { "grass", "water", "castleFloor", "castleStone", "wood", "sand", "path" },
	textureMaxCount = 220,
	groundBudgetParts = 600, groundMaxTiles = 120, -- dallage : Parts réelles (mesurées) et nombre de tuiles maximum
	arenaBudgetParts = 500, -- pire cas de Parts des modèles Blender de l'arène (place, bancs, lampadaires, moulin, enclos)
	vfxMaxParts = 30, -- plafond de Parts de chaque modèle d'effet (clé modelsMaxParts["vfx.x"] : vfxMaxParts par défaut)
	castleBudgetParts = 1700, -- pire cas de Parts des modèles Blender du château (murs, tours, portes, coffre, torches, drapeaux, fond)
	-- Hauteurs cibles en studs (le joueur mesure ~5). Chaque modèle est mis à l'échelle sur SA HAUTEUR d'après GetExtentsSize puis remesuré (±10 %) ;
	-- mesure impossible = modèle non posé (repli procédural), jamais d'échelle brute.
	targetHeights = { player = 5, petMin = 2, petMax = 4, petHard = 5, eggMin = 3, eggMax = 4.5, lamp = 8, bench = 2.5, fountain = 7, hut = 11, mill = 20, dog = 3, wolf = 4, bear = 6, knight = 5.2, tower = 24, chest = 4, torch = 3, flag = 7 },
	-- Seules ces pièces (nom de base, sans suffixe de couleur) gardent un matériau Metal ; Neon seulement pour les flammes ; tout le reste en plastique lisse.
	metalParts = { Anneau = true, Tige = true, Serrure = true, Poignee = true, Fer = true, Cercles = true, Pics = true, Lame = true, Herse = true },
	neonParts = { Flamme = true },
	guardKinds = { "dog", "wolf", "bear" }, -- gardien de chaque domaine (Config.RIVALS) -> modèle de models.guards
	guardHeights = { dog = 3, wolf = 4, bear = 6, knight = 5.2 }, -- hauteur en studs (= targetHeights)
	propsMaxParts = { tree = 40, fir = 40, rock = 25, bush = 20, hut = 120, fence = 20, bridge = 30, fountain = 150, nest = 12 },
	-- Nombre d'exemplaires posés sur la carte de la partie et hauteur en studs (le pont est mis à l'échelle sur sa longueur).
	propsPlan = { tree = 18, fir = 10, rock = 14, bush = 14, hut = 3, fence = 12, bridge = 4 },
	propsHeight = { tree = 12, fir = 14, rock = 3.5, bush = 2.5, hut = 11, fence = 3, bridge = 1.5, fountain = 7, nest = 1.2 },
	bridgeLength = 18,
	propsBudgetParts = 2600, -- pire cas (exemplaires x plafond de Parts) à ne jamais dépasser ; le placement s'arrête aussi au compte réel
	smallDetail = 0.6, -- pièces dont la plus grande arête est inférieure : CastShadow = false
	-- Décor du hub (modèles catalogue fournis par l'utilisateur) : chargés par Assets.loadDecor, placés selon Config.HubDecor. Le hub est déjà
	-- décoré par du code (bancs, lampadaires, arbres) : si un modèle est refusé, rien ne manque.
	decor = {
		chair = 125943216682367, -- chaise moderne
		sofa = 10551600237, -- canapé moderne en U avec table basse
		metalTable = 12470604445, -- table en métal
		woodTable = 839550130, -- table en bois
		diningTable = 1338860741, -- table à manger
		billiard = 14953074402, -- table de billard
		lamp = 5680874848, -- petite lampe de table
		plantPot = 12032209888, -- plante moderne en pot moyenne
		plantModern = 16600867704, -- plante moderne
		plantWindow = 15078054751, -- plante fenêtre
		plantIndoor = 116741237427172, -- plante en pot intérieur
		plantOutdoor = 131378985761907, -- plante extérieure moderne rectangle
		sakura = 101176034116232, -- plante Sakura
	},
	-- Packs d'animaux fournis (renard, lion, panda, girafe, éléphant, chat, poulet / énorme pack / serpent, biche, léopard) : NON chargés, car
	-- aucun animal ne sert le gameplay (les pets sont construits par le code). Identifiants gardés ici pour un futur PNJ décor.
	animals = { pack1 = 77584505169384, huge = 138337815539618, pack2 = 97050466582003 },
	-- Modèles Blender des pets (à téléverser ensuite) : index d'espèce de Config.PETS -> identifiant du modèle. Vide = pets procéduraux.
	-- Exemple : pets = { [1] = 123456789 }. Un modèle absent, refusé ou invalide garde le pet procédural (repli automatique).
	pets = {
		[1] = 122665615732907, -- PetPoussin (Poussin, Commun)
		[3] = 88649442626593, -- PetLapin (Lapin, Commun)
		[2] = 130387777043821, -- Hamster (Commun)
		[4] = 81991111371408, -- Chat (Rare)
		[5] = 90815266946917, -- Chien (Rare)
		[6] = 125436205733282, -- PetRenard (Renard, Rare)
		[8] = 95489512823854, -- Hibou (Épique)
		[9] = 73235151647339, -- Manchot (Épique)
		[10] = 73493068085290, -- Lion (Légendaire)
		[12] = 119358850090330, -- Licorne (Légendaire)
		[11] = 72370255271127, -- Tigre (Légendaire)
		[15] = 123754319737365, -- Kraken (Mythique)
		[17] = 85626350359383, -- Calmar stellaire (Cosmique)
		[18] = 127368682215579, -- Wyrm astral (Cosmique)
		[14] = 113312935651236, -- T-Rex (Mythique)
		[7] = 113006978203286, -- PetPanda (Panda, Épique)
		[13] = 134284711848469, -- PetDragonnet (Dragon, Mythique)
		[16] = 129116477413499, -- PetFantome (Alien, Cosmique : le « fantôme »)
	},
	petsMaxParts = 120, -- plafond de Parts d'un modèle de pet (cloné pour chaque pet affiché)
	petHeight = 3, -- (les pets Blender mesurent ~1 : mis à l'échelle sur cette hauteur) -- hauteur en studs d'un pet de taille « Normal » (multipliée par l'échelle de taille)
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

-- Étiquettes des portails du hub : une seule (le portail le plus proche) est visible à la fois, à moins de `maxDist` studs. portals = liste de
-- { key, x, z } ; retourne la clé du plus proche ou nil (rien à portée, position invalide).
Config.PORTAL_LABEL = { maxDist = 40, titleSize = { 230, 44 }, statusSize = { 200, 30 } } -- tailles FIXES en pixels (jamais proportionnelles)
function Config.nearestPortal(x, z, portals, maxDist)
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return nil
	end
	local best, bd = nil, (maxDist or Config.PORTAL_LABEL.maxDist) + 1e-9
	for _, p in ipairs(portals) do
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		if d <= bd then
			best, bd = p.key, d
		end
	end
	return best
end

-- Hauteur cible d'un pet : 2 à 4 studs selon la rareté (1..6), multipliée par l'échelle de sa taille, jamais plus de 5 (joueur = 5).
function Config.petTargetHeight(tier, sizeScale)
	local H = Config.Assets.targetHeights
	local t = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), 6)
	local base = H.petMin + (H.petMax - H.petMin) * (t - 1) / 5
	local k = (type(sizeScale) == "number" and sizeScale == sizeScale and sizeScale > 0) and sizeScale or 1
	return math.min(base * k, H.petHard)
end

-- Hauteur cible d'un œuf : 3 à 4,5 studs selon la rareté.
function Config.eggHeight(tier)
	local H = Config.Assets.targetHeights
	local t = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), 6)
	return H.eggMin + (H.eggMax - H.eggMin) * (t - 1) / 5
end

-- Apparence (table de Config.EggFx.looks) de l'œuf de rareté `tier`, ou nil.
function Config.eggLook(tier)
	local key = Config.eggAssetKey(tier)
	return key and Config.EggFx.looks[key] or nil
end

-- Taille maximale d'un œuf posé sur une base : relative à l'emplacement (pad de 8 studs) et au joueur (~5 studs). Quel que soit le modèle
-- (Blender, catalogue, procédural), l'œuf ne dépasse jamais ces bornes : plus de géant à l'éclosion.
Config.EGG_LIMITS = { padSize = 8, playerHeight = 5, widthOfPad = 0.55, heightOfPad = 0.5, heightOfPlayer = 0.75 }

function Config.eggMaxSize(padSize, playerHeight)
	local L = Config.EGG_LIMITS
	padSize, playerHeight = padSize or L.padSize, playerHeight or L.playerHeight
	return { w = padSize * L.widthOfPad, h = math.min(padSize * L.heightOfPad, playerHeight * L.heightOfPlayer) }
end

-- Facteur (<= 1) à appliquer à un modèle d'étendues ext = { X, Y, Z } pour qu'il tienne dans max = { w, h } ; 1 si déjà conforme ou valeurs invalides.
function Config.fitScale(ext, max)
	local f = 1
	local function limit(extent, bound)
		if type(extent) == "number" and extent == extent and extent > 0 and extent > bound then
			f = math.min(f, bound / extent)
		end
	end
	limit(ext.X, max.w)
	limit(ext.Z, max.w)
	limit(ext.Y, max.h)
	return f
end

-- Emplacements du décor du hub : { clé de Config.Assets.decor, x, z, rotation en degrés, hauteur cible en studs }.
-- Zone libre au sud de la place (z > 44), hors fontaine, point d'arrivée, panneaux et portails (vérifié par les tests).
Config.HubDecor = {
	{ "sofa", -40, 58, 90, 4 },
	{ "chair", -28, 66, 200, 3.4 },
	{ "chair", -50, 70, 150, 3.4 },
	{ "metalTable", -38, 76, 0, 3 },
	{ "lamp", -52, 56, 0, 2.4 },
	{ "diningTable", 34, 58, 0, 3.2 },
	{ "chair", 26, 58, 270, 3.4 },
	{ "chair", 42, 58, 90, 3.4 },
	{ "woodTable", 52, 72, 20, 3 },
	{ "billiard", 34, 80, 0, 3.4 },
	{ "plantPot", -14, 50, 0, 4.5 },
	{ "plantModern", 14, 50, 0, 4.5 },
	{ "plantWindow", -22, 46, 0, 3.5 },
	{ "plantIndoor", 22, 46, 0, 3.5 },
	{ "plantOutdoor", -62, 64, 0, 4 },
	{ "plantOutdoor", 64, 64, 0, 4 },
	{ "sakura", 0, 92, 0, 16 },
	{ "sakura", -70, 88, 0, 16 },
	{ "sakura", 72, 90, 0, 16 },
}

-- Pire cas de Parts de tous les accessoires placés sur la carte (exemplaires x plafond par modèle) : doit rester sous propsBudgetParts.
function Config.propsWorstCase()
	local total = 0
	for key, count in pairs(Config.Assets.propsPlan) do
		total = total + count * (Config.Assets.propsMaxParts[key] or Config.Assets.decorMaxParts)
	end
	return total
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

---------------------------------------------------------------- Révélation d'œuf : étoile, anneaux, rayons, « 1 sur N »
-- tiers[t] : style du pet de rareté t (rayons, anneaux, secousse 0-1, flash 0-1, particules). secret : effet distinct (lave et magenta) quand le
-- tirage est plus rare que oneInAtLeast. reducedFactor : option mobile. Tout est dessiné par le client en UI (Frames, UIGradient, UIStroke).
Config.REVEAL = {
	Enabled = true,
	forceReduced = false, -- true : effets réduits partout (sinon : seulement sur appareil tactile sans clavier)
	reducedFactor = 0.5,
	tiers = {
		{ rays = 6, rings = 1, shake = 0, flash = 0, particles = 4 },
		{ rays = 8, rings = 1, shake = 0.1, flash = 0.15, particles = 8 },
		{ rays = 10, rings = 2, shake = 0.25, flash = 0.3, particles = 14 },
		{ rays = 12, rings = 2, shake = 0.5, flash = 0.5, particles = 20 },
		{ rays = 14, rings = 3, shake = 0.8, flash = 0.7, particles = 28 },
		{ rays = 16, rings = 3, shake = 1, flash = 0.85, particles = 36 },
	},
	secret = { oneInAtLeast = 20000, color = Color3.fromRGB(255, 70, 20), rays = 16, rings = 4, shake = 1, flash = 0.95, particles = 30, label = "ŒUF SECRET" },
}

---------------------------------------------------------------- Style d'interface « cartoon glossy » : couleur par fonction
-- vert = jouer / continuer / acheter, bleu = sauver / charger / collection, orange = options / pause, rouge = fermer / retour.
-- Chaque bouton : contour foncé épais (UIStroke), dégradé saturé (UIGradient), coins très arrondis (UICorner), reflet. Aucune icône externe.
Config.UI = {
	glossy = true,
	kinds = {
		play = { base = Color3.fromRGB(91, 227, 125), stroke = Color3.fromRGB(20, 92, 44), text = Color3.fromRGB(10, 40, 20) },
		save = { base = Color3.fromRGB(74, 163, 255), stroke = Color3.fromRGB(18, 58, 120), text = Color3.fromRGB(8, 24, 56) },
		options = { base = Color3.fromRGB(255, 159, 28), stroke = Color3.fromRGB(122, 60, 6), text = Color3.fromRGB(52, 24, 2) },
		close = { base = Color3.fromRGB(255, 99, 99), stroke = Color3.fromRGB(120, 24, 28), text = Color3.fromRGB(56, 8, 10) },
	},
	nav = { shop = "play", dex = "save", quests = "play", bonus = "options", top = "save", more = "options" },
}

function Config.btnStyle(kind)
	return Config.UI.kinds[kind]
end

-- Luminance relative WCAG d'une couleur Color3 (R, G, B dans [0, 1]).
function Config.luminance(c)
	local function lin(v)
		return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end

function Config.contrast(a, b)
	local la, lb = Config.luminance(a), Config.luminance(b)
	local hi, lo = math.max(la, lb), math.min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
end

---------------------------------------------------------------- Paliers visuels de richesse (boutique)
-- 1 pièce, petite pile, grosse pile, coffre : seuils alignés sur les prix des œufs (900, 20 000, 350 000).
Config.WEALTH = {
	{ name = "Une pièce", min = 0, icon = "coin" },
	{ name = "Petite pile", min = 900, icon = "pile" },
	{ name = "Grosse pile", min = 20000, icon = "mound" },
	{ name = "Coffre", min = 350000, icon = "chest" },
}

function Config.wealthTier(coins)
	local c = (type(coins) == "number" and coins == coins) and coins or 0
	local tier = 1
	for i, w in ipairs(Config.WEALTH) do
		if c >= w.min then
			tier = i
		end
	end
	return tier
end

---------------------------------------------------------------- Carrousel d'œufs (boutique)
-- Œuf présélectionné : le plus rare que le joueur peut payer (au moins le Commun).
function Config.carouselDefault(coins)
	local best = 1
	for i, price in ipairs(Config.EGG_PRICE) do
		if coins >= price then
			best = i
		end
	end
	return best
end

-- Déplace la sélection (dir = -1 ou 1) avec retour à l'autre bout.
function Config.carouselStep(sel, dir, n)
	n = n or #Config.TIERS
	return ((sel - 1 + (dir >= 0 and 1 or -1)) % n) + 1
end

---------------------------------------------------------------- Bannière de zone et promesse d'accueil
Config.ZONE_BANNERS = {
	arena = { title = "L'ARÈNE", sub = "Le Grand Nid et le tapis roulant", color = Color3.fromRGB(255, 210, 63) },
	gus = { title = "DOMAINE DE GUS", sub = "La ferme dorée : œufs communs et rares", color = Color3.fromRGB(255, 190, 70) },
	mara = { title = "DOMAINE DE MARA", sub = "Les bois ensorcelés : œufs rares à légendaires", color = Color3.fromRGB(190, 120, 255) },
	zed = { title = "CITADELLE DE ZED", sub = "La lave et l'obsidienne : œufs mythiques et cosmiques", color = Color3.fromRGB(255, 100, 60) },
}
Config.ZONE_BANNER_SECONDS = 2.6

function Config.zoneBanner(key)
	return Config.ZONE_BANNERS[key]
end

-- Promesse affichée dès l'arrivée (non bloquante) : le joueur peut agir tout de suite.
Config.PROMISE = { seconds = 7, button = "▶ Jouer" }

-- Tutoriel des premières minutes : une barre d'objectif unique (« Chipe 2 œufs (0/2) ») qui guide pas à pas ; chaque étape se lit dans les
-- statistiques du joueur (aucune donnée sauvegardée en plus), la barre disparaît d'elle-même quand tout est fait.
Config.TUTORIAL = {
	{ id = "hatch1", stat = "hatched", goal = 1, text = "Touche ton œuf pour le faire éclore" },
	{ id = "steal2", stat = "stolen", goal = 2, text = "Chipe 2 œufs chez un rival" },
	{ id = "hatch3", stat = "hatched", goal = 4, text = "Fais éclore 4 œufs" },
	{ id = "species3", stat = "species", goal = 3, text = "Découvre 3 espèces de pets" },
}
-- st = { hatched, stolen, species } ; retourne { index, total, text, prog, goal } de la première étape non terminée, ou nil (tutoriel fini).
function Config.tutorial(st)
	for i, step in ipairs(Config.TUTORIAL) do
		local v = (st and st[step.stat]) or 0
		if v < step.goal then
			return { index = i, total = #Config.TUTORIAL, text = step.text, prog = v, goal = step.goal }
		end
	end
	return nil
end

-- Ligne de la bannière de zone : nom court et distance à la base du joueur (arrondie à 5 m ; « chez toi » près de la base).
Config.ZONE_NAMES = { arena = "Arène", gus = "Ferme de Gus", mara = "Bois de Mara", zed = "Citadelle de Zed" }
function Config.zoneLine(zone, dist)
	local name = Config.ZONE_NAMES[zone]
	if not name then
		return nil
	end
	if type(dist) ~= "number" or dist ~= dist then
		return name
	end
	if dist < 40 then
		return name .. " · chez toi"
	end
	return name .. " · " .. (math.floor(dist / 5 + 0.5) * 5) .. " m de ta base"
end

-- Titres : un par palier de succès (Éleveur I à IV...), débloqué quand la statistique atteint l'objectif. stats = state.stats.
Config.ROMAN = { "I", "II", "III", "IV" }
function Config.titles(stats)
	local out = {}
	for _, a in ipairs(Config.ACHIEVEMENTS) do
		local v = (stats and stats[a.stat]) or 0
		for i, goal in ipairs(a.goals) do
			out[#out + 1] = { id = a.id .. i, name = a.emoji .. " " .. a.name .. " " .. (Config.ROMAN[i] or tostring(i)), desc = goal .. " " .. a.unit, unlocked = v >= goal }
		end
	end
	return out
end

-- Offre d'achat « au bon moment » : petite carte non bloquante, fermable d'un geste, jamais plus de 3 par session ni plus d'une toutes les 5 minutes,
-- seulement pour un achat disponible (ID renseigné) et pas déjà possédé. ev = "rare" (éclosion rare) ou "milestone" (palier). Retourne { pass, text } ou nil.
Config.OFFERS = { max = 3, gap = 300, graceSeconds = 90 }
function Config.boostOffer(ev, passes, now, lastAt, shown, joinedAt)
	if (shown or 0) >= Config.OFFERS.max or (lastAt and now - lastAt < Config.OFFERS.gap) or now - (joinedAt or 0) < Config.OFFERS.graceSeconds then
		return nil
	end
	local key = ev == "rare" and "Lucky" or (ev == "milestone" and "Coins2x" or nil)
	local def = key and Config.PASSES[key]
	if not def or not Config.purchasable(def) or (passes and passes[key]) then
		return nil
	end
	return { pass = key, text = ev == "rare" and "Plus de pets rares ? Chance +10 %" or "Gagne 2 fois plus de pièces, pour toujours" }
end

-- Prochain geste à proposer pendant les premières minutes : { id, text }. st = { hatched, stolen, speed }.
function Config.nextHint(st)
	if (st.hatched or 0) == 0 then
		return { id = "tap", text = "Touche ton œuf 🥚 pour accélérer l'éclosion !" }
	elseif (st.stolen or 0) == 0 then
		return { id = "steal", text = "Va chez un rival (au nord) et maintiens le bouton pour voler un œuf… évite son gardien 🐕" }
	elseif (st.speed or 0) < 8 then
		return { id = "train", text = "Cours sur le tapis roulant 🏃 au centre pour devenir plus rapide !" }
	end
	return nil
end

-- « 1 sur N » : espaces entre les milliers, une décimale sous 10.
function Config.fmtOdds(n)
	if type(n) ~= "number" or n ~= n or n <= 0 or n == math.huge then
		return ""
	end
	if n < 10 then
		return "1 sur " .. string.format("%.1f", n):gsub("%.", ",")
	end
	local s = string.format("%d", math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return "1 sur " .. out
end

---------------------------------------------------------------- Bandeaux de rareté, aura des raretés élevées, états des pets
-- Bandeaux (couleurs imposées par les inspirations) : commun jaune, rare vert, épique violet, légendaire rouge, mythique cyan, secret arc-en-ciel.
Config.RARITY_BANNERS = {
	{ name = "COMMUN", colors = { Color3.fromRGB(255, 214, 64), Color3.fromRGB(214, 150, 10) } },
	{ name = "RARE", colors = { Color3.fromRGB(110, 235, 110), Color3.fromRGB(30, 150, 50) } },
	{ name = "ÉPIQUE", colors = { Color3.fromRGB(196, 120, 255), Color3.fromRGB(110, 40, 190) } },
	{ name = "LÉGENDAIRE", colors = { Color3.fromRGB(255, 96, 96), Color3.fromRGB(170, 20, 30) } },
	{ name = "MYTHIQUE", colors = { Color3.fromRGB(90, 240, 255), Color3.fromRGB(10, 130, 180) } },
	{ name = "COSMIQUE", colors = { Color3.fromRGB(150, 255, 230), Color3.fromRGB(20, 150, 130) } },
	secret = { name = "SECRET", colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 235, 110), Color3.fromRGB(80, 170, 255), Color3.fromRGB(190, 110, 255) } },
}

function Config.rarityBanner(tier, secret)
	if secret then
		return Config.RARITY_BANNERS.secret
	end
	return Config.RARITY_BANNERS[math.min(math.max(tier, 1), #Config.TIERS)]
end

-- Cercle runique au sol et aura autour du pet obtenu (rareté >= minTier ou secret). Budgets mobiles : maxRate (particules/s) et maxRunes plafonnent.
Config.AURA = {
	Enabled = true,
	minTier = 4,
	seconds = 6,
	maxRate = 40,
	maxRunes = 12,
	maxParts = 24, -- plafond de Parts créées par une aura (vérifié par test)
	highlight = true, -- contour lumineux (Highlight) du pet pendant l'aura
}

-- Style d'aura : { runes, rate, pillar, seconds, color } ou nil si la rareté est trop basse. reduced = option mobile.
function Config.auraStyle(tier, secret, reduced)
	local A = Config.AURA
	if not A.Enabled or (tier < A.minTier and not secret) then
		return nil
	end
	local level = secret and 7 or tier
	local st = { runes = math.min(A.maxRunes, 4 + (level - A.minTier + 1) * 2), rate = math.min(A.maxRate, 8 + (level - A.minTier + 1) * 6), pillar = level >= 5, seconds = A.seconds + (secret and 3 or 0) }
	if reduced then
		st.runes = math.max(4, st.runes // 2)
		st.rate = st.rate // 2
		st.pillar = false
	end
	return st
end

-- États des pets (idle, move, ability) : la capacité des pets de rareté >= abilityMinTier se déclenche toutes les ~abilityInterval s.
Config.PET_STATES = { abilityMinTier = 3, abilityInterval = 9 }

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
	petStates = true, -- états des pets : respiration, bonds en suivant le joueur, capacité (saut en vrille)
	zoneBanner = true, -- bannière au passage d'une zone de la carte
	interactMarkers = true, -- anneaux dorés pulsants sur les éléments interactifs (nids, secrets)
	zoneAmbience = true, -- éclairage et atmosphère propres à chaque domaine
	eggHalo = true, -- halos des œufs : anneau qui tourne, scintillement du glitch
	uiFx = true, -- animations d'interface : compteur qui défile, balayage de brillance sur la rareté, flash de vignette
	pulse = true, -- pulsation légère de ColorCorrection et Bloom à l'éclosion d'un pet rare (désactivable)
	vfx3d = true, -- effets 3D (modèles Blender d'effets) à l'éclosion, à la victoire du château (VfxKit)
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
	hub = true, -- survol d'accueil du hub (fontaine puis portails), première arrivée seulement
	eclosion = true, -- cinématiques d'éclosion (épique court ; légendaire, mythique, cosmique, secret complets)
	chateau = true, -- entrée et victoire du château
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
	pedestals = true, -- piédestal hexagonal sous chaque emplacement
	moat = { radius = 56, width = 6 }, -- douve (rivière) autour de chaque domaine, franchissable (décor) ; un pont en bois la traverse au sud
	ambienceRadius = 62, -- distance du centre d'un domaine à partir de laquelle son ambiance s'applique
	budgetParts = 1200, -- le serveur avertit au démarrage si la carte procédurale dépasse ce nombre de Parts (budget mobile) ; les modèles Blender ont leurs propres budgets
	totalBudgetParts = 7000, -- plafond d'ensemble (carte procédurale + pire cas des accessoires Blender)
	decor = { flowers = 20, trees = 12, patches = 8, hills = 8, moatSegments = 18, fencePosts = 8, bridgePlanks = 5 }, -- quantités de décor (Parts) : réglées pour tenir sous budgetParts
	Streaming = { Enabled = false, MinRadius = 128, TargetRadius = 480 }, -- coupé : un streaming défaillant laisse des joueurs sans sol ; à réactiver seulement après un playtest mobile,
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
-- Effets 3D : qualité imposée (« high », « medium », « low ») ou nil = automatique (Bas sur tactile, Élevé sinon).
Config.VFX = { quality = nil }

Config.HUD = {
	objective = true, -- carte « objectif en cours » (chapitre de l'histoire) sous les compteurs
	shortcuts = true, -- manette (X boutique, Y missions, Select Plus, B fermer) et clavier (B, Q, O) pour les menus
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
