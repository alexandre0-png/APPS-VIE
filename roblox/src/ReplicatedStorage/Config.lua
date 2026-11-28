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

-- LOT 9 (A.1) : 10 raretés. Les anciennes (1 Commun .. 6 Cosmique) sont migrées par Config.TIER_MIGRATE (Cosmique devient « Ultra Rare »).
Config.TIERS = {
	{ name = "Commun", color = Color3.fromRGB(220, 220, 230), color2 = Color3.fromRGB(142, 147, 160) },
	{ name = "Peu commun", color = Color3.fromRGB(60, 220, 60), color2 = Color3.fromRGB(30, 140, 40) },
	{ name = "Rare", color = Color3.fromRGB(46, 139, 255), color2 = Color3.fromRGB(20, 80, 180) },
	{ name = "Épique", color = Color3.fromRGB(155, 77, 255), color2 = Color3.fromRGB(74, 26, 140) },
	{ name = "Légendaire", color = Color3.fromRGB(255, 194, 26), color2 = Color3.fromRGB(184, 134, 11), crown = true },
	{ name = "Mythique", color = Color3.fromRGB(224, 32, 46), color2 = Color3.fromRGB(26, 16, 20), chains = true },
	{ name = "Ultra Rare", color = Color3.fromRGB(111, 214, 255), color2 = Color3.fromRGB(42, 127, 212), facets = true },
	{ name = "Secret", color = Color3.fromRGB(255, 120, 200), color2 = Color3.fromRGB(10, 10, 18), rainbow = true },
	{ name = "Exclusif", color = Color3.fromRGB(242, 242, 242), color2 = Color3.fromRGB(20, 20, 20), crown = true },
	{ name = "Divin", color = Color3.fromRGB(255, 243, 176), color2 = Color3.fromRGB(255, 255, 255), wings = true },
}
Config.TIER_COUNT = 10
-- Ancien indice de rareté (profils v10 et antérieurs, 6 raretés) -> nouvel indice (lot 9).
Config.TIER_MIGRATE = { 1, 3, 4, 5, 6, 7 }
-- Ancien indice (1..6) d'une rareté du lot 9 (inverse de TIER_MIGRATE ; une rareté nouvelle prend l'ancienne inférieure). Sert aux migrations et aux tests.
function Config.oldTier(t)
	local best = 1
	for old, new in ipairs(Config.TIER_MIGRATE) do
		if type(t) == "number" and new <= t then
			best = old
		end
	end
	return best
end
-- Seuils d'effets indexés par rareté (remplacent tous les `tier >= N` codés en dur ; test grep dans tests/run.luau).
-- shine : brillance du bandeau ; announce : annonce serveur, grande révélation ; aura : cercle runique ; pillar : pilier de lumière ;
-- beam : faisceau de portage ; serverBanner / globalBanner : annonces (lot 10) ; rareCine : cinématique « premier rare » ; belt2s : anti-monopole du tapis ;
-- ability : capacité animée des pets ; secret : son et effet « secret » de la rareté ; fullCine : grande cinématique d'éclosion.
Config.TIER_GATE = { shine = 4, announce = 5, aura = 5, pillar = 6, beam = 5, serverBanner = 7, globalBanner = 8, rareCine = 5, belt2s = 5, ability = 4, secret = 7, fullCine = 7 }
function Config.tierAtLeast(tier, gate)
	local g = Config.TIER_GATE[gate]
	return type(tier) == "number" and tier == tier and type(g) == "number" and tier >= g
end
-- Rareté « publiée » : au moins une espèce de Config.PETS (le lot 11 ajoutera les espèces des raretés 2, 8, 9, 10). Une rareté vide n'apparaît
-- jamais : ses poids sont reportés sur la rareté publiée inférieure (A.3), un œuf donné en récompense prend la rareté publiée inférieure.
function Config.tierLive(tier)
	for _, p in ipairs(Config.PETS) do
		if p.tier == tier then
			return true
		end
	end
	return false
end
-- A5 : espèces d'événement et de saison (champ `event` du bestiaire : « halloween », « noel », « saison1 »...). Elles ne font PAS partie du tirage normal :
-- une telle espèce n'est tirable que si son étiquette est dans `open` (ensemble { [étiquette] = true } calculé par le serveur avec
-- Rewards.openSpeciesEvents : événement limité de Config.EVENTS_CAL en cours, saison en cours). open = nil : aucune fenêtre ouverte.
-- tierLive reste statique (rareté publiée) ; tierOpen dit si la rareté a au moins une espèce tirable MAINTENANT (boutique, plumes).
function Config.speciesOpen(p, open)
	local def = type(p) == "number" and Config.PETS[p] or nil
	if type(def) ~= "table" then
		return false
	end
	if def.event == nil then
		return true
	end
	return type(open) == "table" and open[def.event] == true
end
-- Indices des espèces tirables d'une rareté (ordre de Config.PETS).
function Config.speciesPool(tier, open)
	local out = {}
	for i, p in ipairs(Config.PETS) do
		if p.tier == tier and Config.speciesOpen(i, open) then
			out[#out + 1] = i
		end
	end
	return out
end
function Config.tierOpen(tier, open)
	return #Config.speciesPool(tier, open) > 0
end
-- Rareté effective d'un tirage : la rareté elle-même si elle a une espèce tirable, sinon la plus haute rareté inférieure qui en a une
-- (seul cas : œuf Exclusif dont aucune fenêtre n'est ouverte, par exemple éclos après la fin de l'événement).
function Config.poolTier(tier, open)
	local t = math.floor(math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), Config.TIER_COUNT))
	while t > 1 and not Config.tierOpen(t, open) do
		t = t - 1
	end
	return t
end
-- Plus haute rareté publiée <= tier (1 au pire).
function Config.liveEggTier(tier)
	local t = math.floor(math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), Config.TIER_COUNT))
	while t > 1 and not Config.tierLive(t) do
		t = t - 1
	end
	return t
end
-- Rareté publiée immédiatement au-dessus (amélioration d'un cran), ou nil.
function Config.nextLiveTier(tier)
	for t = tier + 1, Config.TIER_COUNT do
		if Config.tierLive(t) then
			return t
		end
	end
	return nil
end
-- Rang d'une rareté parmi les raretés publiées (1..6 tant que seules les 18 espèces historiques existent : même rang que l'ancien indice).
function Config.tierRank(tier)
	local r = 0
	for t = 1, math.min(tier, Config.TIER_COUNT) do
		if Config.tierLive(t) then
			r = r + 1
		end
	end
	return math.max(1, r)
end
-- Poids effectifs d'une table de 10 poids : chaque rareté non publiée reporte son poids sur la rareté publiée inférieure.
function Config.foldWeights(w)
	local out = {}
	for i = 1, Config.TIER_COUNT do
		out[i] = 0
	end
	for i = 1, Config.TIER_COUNT do
		local x = w[i] or 0
		if x > 0 then
			local j = Config.liveEggTier(i)
			out[j] = out[j] + x
		end
	end
	return out
end
-- REGLE DE DESIGN (1) : fourchette de revenu par seconde de chaque rareté (avant taille et mutation). min(r+1) >= 1,8 x max(r) (testé),
-- toute espèce de la rareté est dans sa fourchette (testé). Les espèces du lot 11 devront s'y tenir.
Config.INCOME_RANGE = { { 1, 2 }, { 3.6, 4.1 }, { 7.5, 15 }, { 30, 75 }, { 150, 420 }, { 800, 3000 }, { 6000, 26000 }, { 50000, 120000 }, { 220000, 300000 }, { 550000, 900000 } }
Config.INCOME_GROWTH_MIN = 1.8
-- Prix et durées calibrés avec la simulation tests/Economy.lua (joueur-robot) : ~15 pièces/s après 1 min, œuf Rare vers 2 min,
-- Épique vers 5-8 min, Légendaire vers 15-20 min, Mythique après ~1 h, Cosmique après plusieurs heures ; première renaissance vers 1 h.
Config.START_COINS = 50
Config.FIRST_EGG_SECONDS = 12 -- lot 9 : l'œuf de départ (gratuit) éclot en 12 s (cible : première éclosion entre 10 et 15 s)
Config.EGG_PRICE = { 45, 99, 220, 26000, 7500000, 609975778, 42933105815, 75000000000, 0, 1800000000000 } -- lot 9 : 10 raretés recalibrées (tests/Economy.lua, tools/sim_economy.py) ; Exclusif (9) jamais en pièces ; lot 16 : Mythique et Ultra Rare réajustés (RYTHME_NOTES.md)
-- Lot 8A (B.3) : la boutique vend les raretés 1 à SHOP_MAX_TIER ; Mythique et Cosmique ne s'achètent qu'au tapis du marché (rareté visible, prix x 0,6).
Config.SHOP_MAX_TIER = 6 -- lot 9 : la boutique vend jusqu'au Mythique (sans lui, la maison stagnait entre 1 et 3 jours de jeu) ; Ultra Rare et au-delà : tapis seulement
Config.HATCH = { 18, 20, 30, 106.14, 450, 527, 560, 600, 600, 900 } -- secondes (lot 9 : recalibrées ; l'œuf de départ éclot en Config.FIRST_EGG_SECONDS ; lot 16 : Épique, Mythique, Ultra Rare)

-- tier, emoji (UI), nom, revenu/s, couleur du modèle 3D, oreilles, extra
Config.PETS = {
	{ tier = 1, emoji = "🐥", name = "Poussin", inc = 1, color = Color3.fromRGB(255, 221, 87), ears = "none", extra = "beak" },
	{ tier = 1, emoji = "🐹", name = "Hamster", inc = 1.5, color = Color3.fromRGB(222, 184, 135), ears = "round", extra = "none" },
	{ tier = 1, emoji = "🐰", name = "Lapin", inc = 2, color = Color3.fromRGB(245, 245, 245), ears = "long", extra = "tail" },
	{ tier = 3, emoji = "🐱", name = "Chat", inc = 7.5, color = Color3.fromRGB(150, 150, 160), ears = "point", extra = "tail" },
	{ tier = 3, emoji = "🐶", name = "Chien", inc = 8, color = Color3.fromRGB(160, 110, 70), ears = "floppy", extra = "tail" },
	{ tier = 3, emoji = "🦊", name = "Renard", inc = 11, color = Color3.fromRGB(240, 130, 50), ears = "point", extra = "tail" },
	{ tier = 4, emoji = "🐼", name = "Panda", inc = 33.727, color = Color3.fromRGB(250, 250, 250), ears = "round", extra = "none" },
	{ tier = 4, emoji = "🦉", name = "Hibou", inc = 52.072, color = Color3.fromRGB(130, 95, 60), ears = "point", extra = "beak" },
	{ tier = 4, emoji = "🐧", name = "Manchot", inc = 56.694, color = Color3.fromRGB(40, 50, 80), ears = "none", extra = "beak" },
	{ tier = 5, emoji = "🦁", name = "Lion", inc = 170, color = Color3.fromRGB(230, 180, 80), ears = "round", extra = "mane" },
	{ tier = 5, emoji = "🐯", name = "Tigre", inc = 287, color = Color3.fromRGB(245, 140, 40), ears = "round", extra = "tail" },
	{ tier = 5, emoji = "🦄", name = "Licorne", inc = 330, color = Color3.fromRGB(255, 235, 250), ears = "point", extra = "horn" },
	{ tier = 6, emoji = "🐲", name = "Dragon", inc = 862, color = Color3.fromRGB(210, 50, 50), ears = "none", extra = "wings" },
	{ tier = 6, emoji = "🦖", name = "T-Rex", inc = 1600, color = Color3.fromRGB(80, 170, 80), ears = "none", extra = "tail" },
	{ tier = 6, emoji = "🐙", name = "Kraken", inc = 1803, color = Color3.fromRGB(140, 70, 190), ears = "none", extra = "tentacles" },
	{ tier = 7, emoji = "👽", name = "Alien", inc = 9000, color = Color3.fromRGB(120, 220, 110), ears = "none", extra = "antenna" },
	{ tier = 7, emoji = "🦑", name = "Calmar stellaire", inc = 13000, color = Color3.fromRGB(60, 190, 200), ears = "none", extra = "tentacles" },
	{ tier = 7, emoji = "🐉", name = "Wyrm astral", inc = 20000, color = Color3.fromRGB(80, 160, 255), ears = "none", extra = "wings" },
}

-- LOT 11 : bestiaire de 78 espèces (ReplicatedStorage/Bestiary.lua). Ses 18 premières entrées doivent être identiques à la liste historique ci-dessus (nom, rareté,
-- revenu : indices stables, testé) ; sinon, ou si le module est introuvable (tests purs qui chargent Config seul), la liste de 18 reste en place.
Config.BESTIARY = nil
do
	local okLoad, Bestiary = pcall(function()
		return require(script.Parent:WaitForChild("Bestiary", 10))
	end)
	if okLoad and type(Bestiary) == "table" and type(Bestiary.PETS) == "table" and #Bestiary.PETS >= #Config.PETS then
		local same = true
		for i, d in ipairs(Config.PETS) do
			local b = Bestiary.PETS[i]
			if not b or b.tier ~= d.tier or b.name ~= d.name or b.inc ~= d.inc then
				same = false
				break
			end
		end
		if same then
			Config.PETS = Bestiary.PETS
			Config.BESTIARY = Bestiary
		end
	end
end

Config.SIZES = {
	{ name = "Mini", mult = 0.8, weight = 20, scale = 0.8 },
	{ name = "Normal", mult = 1, weight = 62, scale = 1 },
	{ name = "Grand", mult = 1.5, weight = 14, scale = 1.25 },
	{ name = "Géant", mult = 2.5, weight = 3.5, scale = 1.6 },
	{ name = "Colossal", mult = 5, weight = 0.5, scale = 2.1 },
}

Config.MUTS = {
	{ name = "", mult = 1, weight = 81.9 },
	{ name = "Doré", mult = 2, weight = 9, color = Color3.fromRGB(255, 208, 0) },
	{ name = "Néon", mult = 3, weight = 5, color = Color3.fromRGB(0, 229, 255) },
	{ name = "Arc-en-ciel", mult = 5, weight = 2.6, rainbow = true },
	{ name = "Alien", mult = 10, weight = 1.4, color = Color3.fromRGB(57, 255, 20) },
	{ name = "Céleste", mult = 20, weight = 0.1, color = Color3.fromRGB(255, 243, 176), aura = true }, -- lot 9 (A.6)
}

-- Rivaux PNJ : poids de tirage des œufs (par rareté), vitesses des gardiens en studs/s
-- (le joueur démarre à 16 : il doit s'entraîner sur le tapis pour battre Mara puis Zed)
Config.RIVALS = {
	{ name = "Gus", emoji = "🤠", stars = 1, guards = 1, weights = { 45, 35, 17, 3, 0, 0, 0, 0, 0, 0 }, guardSpeed = 9.5, patrolSpeed = 4.5, viewDist = 16, viewAngle = 80, hearRadius = 7, damage = 10, alertDelay = 1.6, gentle = true, color = Color3.fromRGB(111, 191, 115) },
	{ name = "Mara", emoji = "🧛", stars = 3, guards = 2, weights = { 0, 10, 35, 37, 18, 0, 0, 0, 0, 0 }, guardSpeed = 19, patrolSpeed = 10, viewDist = 28, viewAngle = 110, hearRadius = 14, damage = 20, color = Color3.fromRGB(224, 164, 59) },
	{ name = "Zed", emoji = "🤖", stars = 5, guards = 3, weights = { 0, 0, 0, 30, 45, 22, 2.4, 0.5, 0, 0.1 }, guardSpeed = 26, patrolSpeed = 13, viewDist = 32, viewAngle = 120, hearRadius = 16, damage = 28, color = Color3.fromRGB(224, 87, 90) },
}

-- Gardiens : jamais de coup mortel d'un seul coup. Barre de vie, invulnérabilité courte après un coup, recul, régénération ; perception (vue + ouïe)
-- et états (voir Guard.lua). Voler DERRIÈRE un gardien (hors de son cône de vision) sans courir près de lui réussit sans combat.
Config.GUARD = {
	maxHp = 100, iframes = 1.6, regenDelay = 6, regenPerSec = 5, baseRegen = 25, knockback = 28, stun = 0.35, attackRange = 4.5, attackCd = 1.2,
	stillSpeed = 2, sneakSpeed = 12, sneakNoise = 0.4, -- bruit : immobile = 0, lent = 0,4, course = 1
	alertDelay = 0.6, alertMax = 3, gentleRecover = 6, safeRadius = 16, -- Gus (clément) : 6 s de répit après une prise, aucun gardien ne vise un joueur à moins de 16 studs de l'entrée du plateau ou dans sa base
	 loseDelay = 2.5, giveUpDist = 45, pathInterval = 0.8, respawnIframes = 3,
	stuckSeconds = 4, stuckSpeed = 0.3, territoryMargin = 14, -- gardien immobile alors qu'il devrait bouger plus de 4 s : retour doux à son poste ; jamais hors du plateau (rayon - 14)
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
	Coins2x = { id = 2093291260, name = "Revenus x2", emoji = "💰", desc = "Double tous tes revenus, pour toujours." },
	Lucky = { id = 2093447290, name = "Chance +10%", emoji = "🍀", desc = "+10 points de chance d'amélioration d'un cran à l'éclosion (5 % → 15 %).", random = true },
	Fast = { id = 2097173053, name = "Éclosion rapide", emoji = "⚡", desc = "Les œufs éclosent 25% plus vite." },
	Speed = { id = 2092253306, name = "Vitesse +20 %", emoji = "👟", desc = "Cours 20 % plus vite, pour toujours." },
	VipBase = { id = 2094209172, name = "Base VIP", emoji = "👑", desc = "Boucliers d'œufs x2 et bonus quotidien x2." },
	ExtraSlots = { id = 2098181699, name = "+4 emplacements", emoji = "🧺", desc = "4 emplacements d'œufs en plus dans ta base, pour toujours (jusqu'à 20)." },
	PrivateBelt = { id = 2098265697, name = "Tapis privé", emoji = "🛤️", desc = "Un petit tapis au milieu de ta base : un œuf gratuit toutes les 2 min tant que tu joues (probabilités du tapis standard, affichées).", random = true },
	-- Lot 16 : passes créés par la gestion (2026-11-26)
	EggBagPlus = { id = 2099454839, name = "Sac d'œufs +10", emoji = "🎒", desc = "Ton sac d'œufs passe de 10 à 20 places, pour toujours." },
	Collector = { id = 2099556764, name = "Collectionneur", emoji = "📒", desc = "Un pet suiveur de plus (4 au lieu de 3), des indices de silhouette dans la collection." },
	Lucky2 = { id = 2102045961, name = "Chance +10 % II", emoji = "🌟", desc = "+10 points de chance d'amélioration en plus de Chance +10 % (bonus payants plafonnés à 30 points, 70 au total).", random = true },
}
Config.SPEED_PASS_MUL = 1.2
Config.VIP_SHIELD_MUL = 2
Config.VIP_DAILY_MUL = 2

Config.SHIELD_BASE = 20 -- secondes de protection d'un œuf fraîchement posé (anti-vol)
Config.SHIELD_PER_LEVEL = 10

-- Temps de vol (s) : base du territoire `terr` (Config.TERR[terr].hold : sauvage 0,8 / Gus 1,3 / Mara 2,2 / Zed 3,5) x 0,85 ^ niveau de Doigts agiles.
-- Sans territoire (vol entre joueurs, appels historiques) : 1,3 s de base.
function Config.stealTime(level, terr)
	local base = 1.3
	local t = terr and Config.TERR and Config.TERR[terr]
	if t then
		base = t.hold
	end
	return base * 0.85 ^ level
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
-- Lot 9 : valeur en pièces d'un œuf de rareté `tier` ; l'Exclusif (jamais vendu en pièces, prix 0) vaut le prix du Secret.
function Config.eggCoinValue(tier)
	local price = Config.EGG_PRICE[tier]
	if price == 0 then
		price = Config.EGG_PRICE[tier - 1]
	end
	return price or 0
end
function Config.eggSellValue(tier)
	local price = Config.EGG_PRICE[tier] and Config.eggCoinValue(tier)
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

-- Lot 9 : la revente d'un pet est plafonnée à la moitié de la valeur d'un œuf de sa rareté (SELL_CAP_RATIO) : acheter un œuf Commun puis revendre
-- le pet rapportait jusqu'à 3,6 fois le prix de l'œuf (boucle de gain). Les raretés hautes ne sont pas touchées (45 s de revenu << prix de l'œuf).
Config.SELL_CAP_RATIO = 0.5
function Config.sellValue(p, s, m)
	local v = math.max(1, math.floor(Config.petIncome(p, s, m) * 45 + 0.5))
	local def = Config.PETS[p]
	local capV = def and Config.eggCoinValue(def.tier) * Config.SELL_CAP_RATIO or 0
	if capV > 0 then
		v = math.min(v, math.max(1, math.floor(capV)))
	end
	return v
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
	levelup = { id = "rbxassetid://126605194205875", speed = 1.15, vol = 0.7 }, -- montée de niveau de la maison (même son que la fanfare, sans déclencher la cinématique du château)
	ambCastle = { id = "rbxassetid://123273835786709", speed = 1.0, vol = 0.3, loop = true },
	ambMeadow = { id = "rbxassetid://89353143614427", speed = 1.0, vol = 0.3, loop = true },
	steal = { id = "rbxasset://sounds/action_jump.mp3", speed = 1.5, vol = 0.5 },
	caught = { id = "rbxasset://sounds/uuhhh.mp3", speed = 1.0, vol = 0.6 },
	claim = { id = "rbxassetid://110088134711268", speed = 1.15, vol = 0.55 },
	click = { id = "rbxassetid://123764673506668", speed = 1.0, vol = 0.4 },
	event = { id = "rbxasset://sounds/electronicpingshort.wav", speed = 0.8, vol = 0.7 },
	-- Crochets pour de nouveaux sons : id = "" (silence) tant qu'aucun identifiant vérifié n'est fourni (rbxassetid://NOMBRE). Aucun n'est inventé.
	portal = { id = "", speed = 1.0, vol = 0.6 }, -- entrée dans un portail du hub
	menu = { id = "rbxassetid://123764673506668", speed = 1.0, vol = 0.4 }, -- ouverture d'un menu
	-- Lot 8A : sons approuvés par Roblox, fournis par la gestion du projet (ne pas modifier ces identifiants ; aucun repli).
	-- Berceuse de la Mère Poule : 4 vraies notes, une par pierre (remplacent le son « claim » joué à 4 hauteurs).
	berceuse_note1 = { id = "rbxassetid://85257974839127", speed = 1.0, vol = 0.55 },
	berceuse_note2 = { id = "rbxassetid://101445210941604", speed = 1.0, vol = 0.55 },
	berceuse_note3 = { id = "rbxassetid://139374738574752", speed = 1.0, vol = 0.55 },
	berceuse_note4 = { id = "rbxassetid://82316993375303", speed = 1.0, vol = 0.55 },
	plume_ramassee = { id = "rbxassetid://118620801437766", speed = 1.0, vol = 0.55 }, -- ramassage d'une plume dorée
	poule_glousse = { id = "rbxassetid://125679862476345", speed = 1.0, vol = 0.3 }, -- la Mère Poule parle (chaque page de dialogue), volume bas
	secret_decouvert = { id = "rbxassetid://119606421875553", speed = 1.0, vol = 0.65 }, -- énigme réussie, secret de la carte, plume cachée repérée
	-- Lot 10 : 37 sons approuvés (lot 28 de la gestion ; ne pas modifier ces identifiants). Correspondance : hatch_r1..r10 = éclosion par rareté (HatchFx),	-- atk_<type> = attaque (TypeFx), battle_* = intro et fin de combat, calendar_* = calendrier, belt_* = tapis (boucle atténuée par la distance), kiosk_ambience = kiosque central (lot 8B, Config.Map2.kiosk).
	-- Les anciennes clés restent ; Config.SOUND_ALIAS redirige quelques anciennes clés vers les nouveaux sons (sans changer le nom de la clé jouée).
	atk_ciel = { id = "rbxassetid://111809409022959", speed = 1.0, vol = 0.6 },
	atk_eau = { id = "rbxassetid://126099928196969", speed = 1.0, vol = 0.6 },
	atk_feu = { id = "rbxassetid://81620112328213", speed = 1.0, vol = 0.6 },
	atk_foudre = { id = "rbxassetid://75059811348237", speed = 1.0, vol = 0.6 },
	atk_glace = { id = "rbxassetid://77653528704078", speed = 1.0, vol = 0.6 },
	atk_lumiere = { id = "rbxassetid://108376562226076", speed = 1.0, vol = 0.6 },
	atk_ombre = { id = "rbxassetid://135006463398132", speed = 1.0, vol = 0.6 },
	atk_plante = { id = "rbxassetid://111056707806818", speed = 1.0, vol = 0.6 },
	atk_terre = { id = "rbxassetid://77231920160184", speed = 1.0, vol = 0.6 },
	battle_lose = { id = "rbxassetid://75714072353851", speed = 1.0, vol = 0.6 },
	battle_start = { id = "rbxassetid://133857375212321", speed = 1.0, vol = 0.7 },
	battle_win = { id = "rbxassetid://74841129152048", speed = 1.0, vol = 0.7 },
	belt_buy = { id = "rbxassetid://73924816898255", speed = 1.0, vol = 0.6 },
	belt_loop = { id = "rbxassetid://127299224836728", speed = 1.0, vol = 0.3, loop = true },
	calendar_claim = { id = "rbxassetid://97907407134977", speed = 1.0, vol = 0.6 },
	calendar_milestone = { id = "rbxassetid://134993322632871", speed = 1.0, vol = 0.7 },
	calendar_open = { id = "rbxassetid://119109992802741", speed = 1.0, vol = 0.6 },
	coin_pickup = { id = "rbxassetid://95726825095665", speed = 1.0, vol = 0.6 },
	egg_shake = { id = "rbxassetid://101268169244225", speed = 1.0, vol = 0.6 },
	hatch_r1 = { id = "rbxassetid://120743720926374", speed = 1.0, vol = 0.7 },
	hatch_r10 = { id = "rbxassetid://70399111166131", speed = 1.0, vol = 0.7 },
	hatch_r2 = { id = "rbxassetid://99352802477541", speed = 1.0, vol = 0.7 },
	hatch_r3 = { id = "rbxassetid://130524252980200", speed = 1.0, vol = 0.7 },
	hatch_r4 = { id = "rbxassetid://74396866627910", speed = 1.0, vol = 0.7 },
	hatch_r5 = { id = "rbxassetid://71692383904268", speed = 1.0, vol = 0.7 },
	hatch_r6 = { id = "rbxassetid://98693421307337", speed = 1.0, vol = 0.7 },
	hatch_r7 = { id = "rbxassetid://130739946095614", speed = 1.0, vol = 0.7 },
	hatch_r8 = { id = "rbxassetid://83413707310170", speed = 1.0, vol = 0.7 },
	hatch_r9 = { id = "rbxassetid://127058227889279", speed = 1.0, vol = 0.7 },
	house_levelup = { id = "rbxassetid://110371127961423", speed = 1.0, vol = 0.7 },
	jackpot_rare = { id = "rbxassetid://90004480091860", speed = 1.0, vol = 0.7 },
	kiosk_ambience = { id = "rbxassetid://82723287691994", speed = 1.0, vol = 0.25, loop = true }, -- lot 8B : boucle près du kiosque central (Client, 30 studs de Config.Map2.kiosk)
	npc_ping = { id = "rbxassetid://79333917653019", speed = 1.0, vol = 0.6 },
	special_hit = { id = "rbxassetid://86601967046565", speed = 1.0, vol = 0.6 },
	special_ready = { id = "rbxassetid://131456268494739", speed = 1.0, vol = 0.6 },
	ui_click = { id = "rbxassetid://127134008433069", speed = 1.0, vol = 0.4 },
	ui_error = { id = "rbxassetid://85896764648966", speed = 1.0, vol = 0.4 },
}
Config.SOUNDS_ENABLED = true -- false : tout est muet
-- Lot 10 : anciennes clés jouées avec un son approuvé du lot 28 (le client lit l'identifiant de la cible ; volume de la clé d'origine). Cible sans id = son d'origine.
Config.SOUND_ALIAS = { click = "ui_click", menu = "ui_click", refuse = "ui_error", coin = "coin_pickup", levelup = "house_levelup", event = "npc_ping" }
-- Lot 10 : clé de son d'attaque d'un type (« Lumière » -> atk_lumiere, alias « Nature » -> atk_plante) ; nil si inconnu.
Config.ATK_SOUND = { Feu = "atk_feu", Eau = "atk_eau", Plante = "atk_plante", Nature = "atk_plante", Glace = "atk_glace", Foudre = "atk_foudre", Terre = "atk_terre", Ciel = "atk_ciel", Ombre = "atk_ombre", ["Lumière"] = "atk_lumiere" }
-- Lot 10 : son d'éclosion approuvé d'une rareté (hatch_r1..hatch_r10), ou nil.
function Config.hatchSoundR(r)
	local rr = (type(r) == "number" and r == r) and math.floor(r) or 1
	rr = math.min(Config.TIER_COUNT, math.max(1, rr))
	return "hatch_r" .. rr
end
Config.VOLUME_STEPS = { 1, 0.6, 0.3, 0 } -- réglage du volume général (menu Plus) : 100 %, 60 %, 30 %, muet
function Config.volumeLabel(i)
	local v = Config.VOLUME_STEPS[i] or 1
	return v <= 0 and "Muet" or (math.floor(v * 100 + 0.5) .. " %")
end

-- Clé de son d'éclosion d'après la rareté du pet (1..10, seuils Config.TIER_GATE) ; secret ou Ultra Rare et plus = son secret.
function Config.hatchSoundKey(tier, secret)
	if secret or Config.tierAtLeast(tier, "secret") then
		return "hatchSecret"
	elseif Config.tierAtLeast(tier, "announce") then
		return "legendary"
	elseif Config.tierAtLeast(tier, "shine") then
		return "epic"
	elseif type(tier) == "number" and tier >= 2 then -- Peu commun et Rare : son « rare »
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
-- `robux` = prix (R$) de PUBLICATION.md (Secret / Exclusif / Divin : décision de l'utilisateur), utilisé pour les paliers de mesure et Config.PRICING ; à garder ÉGAL au prix réglé
-- dans le Creator Hub (A_FAIRE_UTILISATEUR.md).
Config.PRODUCTS = {
	InstantHatch = { id = 3734229329, robux = 49, name = "Éclosion instantanée", emoji = "⚡", desc = "Fait éclore tous tes œufs tout de suite." },
	LuckPotion = { id = 3734229337, robux = 99, name = "Potion de chance", emoji = "🧪", desc = "+25 points de chance d'amélioration pendant 15 min.", random = true },
	StarterPack = { id = 3734229313, robux = 99, once = true, name = "Pack de départ", emoji = "🎁", desc = "Une seule fois : 20 000 pièces, 3 œufs Rares et une potion de chance." },
	ExclusiveEgg = { id = 3734229320, robux = 249, name = "Œuf Mythique", emoji = "🥚", eggTier = 6, desc = "Un œuf Mythique (rareté fixe) placé directement dans ta base (il faut une place libre). Espèce, taille et mutation tirées au sort : probabilités affichées.", random = true },
	-- Lot 9 : œufs de rareté FIXE à très haut prix (décision de l'utilisateur). Achat refusé (NotProcessedYet, rien n'est débité) si la base est
	-- pleine, si le compte est restreint (PolicyService) ou tant que la rareté n'a aucune espèce publiée (Config.tierLive) : l'offre reste alors masquée.
	EggSecret = { id = 3736452048, robux = 1499, name = "Œuf Secret", emoji = "🌈", eggTier = 8, desc = "Un œuf Secret (rareté fixe) placé dans ta base (il faut une place libre). Espèce, taille et mutation tirées au sort : probabilités affichées avant l'achat. Aucun bonus de combat.", random = true },
	EggExclusive = { id = 3736452061, robux = 3499, name = "Œuf Exclusif", emoji = "🖤", eggTier = 9, desc = "Un œuf Exclusif (rareté fixe) placé dans ta base (il faut une place libre). Espèce, taille et mutation tirées au sort : probabilités affichées avant l'achat. Aucun bonus de combat.", random = true },
	EggDivine = { id = 3736452072, robux = 6999, name = "Œuf Divin", emoji = "😇", eggTier = 10, desc = "Un œuf Divin (rareté fixe) placé dans ta base (il faut une place libre). Espèce, taille et mutation tirées au sort : probabilités affichées avant l'achat. Aucun bonus de combat.", random = true },
	Revive = { id = 3734229323, robux = 49, name = "Relance immédiate", emoji = "💫", desc = "Au Château : repars aussitôt là où tu es tombé, pv rétablis, sans compter la défaite. Le retour gratuit au début de la salle reste disponible." },
	ServerLuck = { id = 3736121217, robux = 129, name = "Pluie de chance pour tous", emoji = "🌧️", desc = "10 min de +5 points de chance d'amélioration pour tout le serveur. Ton nom est remercié.", random = true },
	GoldenBelt = { id = 3736121227, robux = 99, name = "Tapis doré", emoji = "🌟", desc = "10 min : le tapis du marché livre un œuf toutes les 4 s au lieu de 5, avec la table « doré » (affichée). Pour tout le serveur. Durées cumulables.", random = true },
	RemoteSteal = { id = 3736121232, robux = 79, name = "Corbeau chipeur", emoji = "🐦‍⬛", desc = "1 jeton de vol à distance. Le corbeau tente de rapporter un œuf en incubation d'un joueur du serveur. La victime peut le chasser ; si ça échoue, ton jeton t'est rendu." },
	RemoteStealPack = { id = 3736121238, robux = 199, name = "3 Corbeaux chipeurs", emoji = "🐦‍⬛", desc = "3 jetons de vol à distance." },
	-- Lot 9b : rattrapage d'UN jour manqué du calendrier (29 R$). ID 0 = à créer dans le Creator Hub (A_FAIRE_UTILISATEUR.md) : tant que l'ID vaut 0, l'achat est désactivé
	-- (restent les deux rattrapages gratuits : jour de grâce et 3 missions). Livre un jeton de rattrapage (profil cal.catch), jamais un tirage au sort payant.
	CalendarCatchup = { id = 3736695392, robux = 29, name = "Rattrapage du calendrier", emoji = "📅", desc = "Rattrape UN jour manqué du calendrier de 30 jours : tu en choisis le jour, la récompense est celle affichée sur la carte." },
	CoinPack = { id = 3734229339, robux = 99, name = "Sac de pièces", emoji = "👛", desc = "Offre 20 minutes de revenus (minimum 5 000 pièces)." },
	-- Lot 16 : achats créés par la gestion (2026-11-26). Champs de catalogue (id, robux, cat, random, once, season, eggTier) posés par Config.SHOP (fin du fichier).
	CoinPackS = { name = "Petit sac de pièces", emoji = "🪙", desc = "Les revenus de 5 minutes de jeu (au moins 1 000 pièces)." },
	EggR2 = { name = "Œuf Peu commun", emoji = "🥚", desc = "Un œuf Peu commun (rareté fixe) dans ta base ou ton sac. Espèce, taille et mutation tirées au sort : probabilités affichées." },
	EggR3 = { name = "Œuf Rare", emoji = "🥚", desc = "Un œuf Rare (rareté fixe) dans ta base ou ton sac. Espèce, taille et mutation tirées au sort : probabilités affichées." },
	EggR4 = { name = "Œuf Épique", emoji = "🥚", desc = "Un œuf Épique (rareté fixe) dans ta base ou ton sac. Espèce, taille et mutation tirées au sort : probabilités affichées." },
	EggR5 = { name = "Œuf Légendaire", emoji = "🥚", desc = "Un œuf Légendaire (rareté fixe) dans ta base ou ton sac. Espèce, taille et mutation tirées au sort : probabilités affichées." },
	EggR7 = { name = "Œuf Ultra Rare", emoji = "🥚", desc = "Un œuf Ultra Rare (rareté fixe) dans ta base ou ton sac. Espèce, taille et mutation tirées au sort : probabilités affichées." },
	LuckPotionMini = { name = "Potion express", emoji = "🧪", desc = "+25 points de chance d'amélioration pendant 5 min. Les durées s'ajoutent." },
	DoubleLuck = { name = "Double chance", emoji = "🍀", desc = "30 min : tes points de chance d'amélioration comptent double (70 points au total au plus). Les durées s'ajoutent." },
	ArenaTickets = { name = "Ticket d'arène", emoji = "🎫", desc = "5 combats de tour récompensés en plus, pour la journée UTC en cours. Aucune force n'est vendue." },
	SeasonPremium = { name = "Passe de combat premium", emoji = "🏅", desc = "La piste premium de la saison en cours (paliers déjà atteints crédités une fois)." },
	SeasonPremiumPlus = { name = "Passe de combat + 10 paliers", emoji = "🏅", desc = "Le passe premium de la saison et 10 paliers tout de suite." },
	SeasonUpgradePlus = { name = "Passe de combat + (suite)", emoji = "🏅", desc = "Pour qui a déjà le premium de la saison : 10 paliers tout de suite." },
	BundleLegend = { name = "Pack Légende", emoji = "🧰", desc = "1 œuf Ultra Rare, 3 œufs Légendaires et 60 min de Double chance." },
	BundleRoyal = { name = "Coffre royal", emoji = "👑", desc = "2 œufs Ultra Rares, 3 œufs Mythiques et le passe de combat premium de la saison." },
	BundleRoyalNoPass = { name = "Coffre royal sans passe", emoji = "👑", desc = "Pour qui a déjà le passe premium : 2 œufs Ultra Rares et 3 œufs Mythiques." },
}
for n = 1, 6 do
	Config.PRODUCTS["EmoteVictory" .. n] = { name = "Pose de victoire " .. n, emoji = ({ "🎉", "✌️", "💃", "🏆", "⭐", "🔥" })[n], desc = "Une pose jouée par ton personnage après une victoire. Purement visuelle." }
end
Config.STARTER_PACK = { coins = 20000, eggTier = 3, eggs = 3 }
Config.EXCLUSIVE_EGG_TIER = 6
Config.REVIVE = { offerSeconds = 20, iframes = 4 } -- offre de relance après une défaite au château (non bloquante), invulnérabilité après la relance
Config.COIN_PACK_MINUTES = 20 -- lot 9 : sert aussi de taux de référence du Robux (20 min de revenu pour le prix du Sac de pièces, voir Config.PRICING)
Config.COIN_PACK_MIN = 5000
-- LOT 9, REGLE DE DESIGN (3) : tout ce qui s'achète aux deux est PLUS CHER et PLUS LONG en pièces. `timeRobux` = robuxCost x secondsPerRobux, le taux
-- de référence du jeu lui-même : le Sac de pièces vend COIN_PACK_MINUTES minutes de revenu pour son prix en R$ (20 min pour 99 R$ = 12,1 s de revenu
-- par R$). `timeToAffordCoin` = temps de jeu actif pour GAGNER `coinCost` pièces, mesuré par tests/Economy.lua (médiane de 5 graines, roster projeté du
-- lot 11) pour 3 profils : débutant (profil neuf), milieu (après 10 h de jeu), avancé (après 100 h) ; recalculé par tools/sim_economy.py prix et
-- vérifié par tests/run.luau : pour le débutant, 4 x timeRobux <= timeToAffordCoin <= 12 x timeRobux (chaque graine). L'Exclusif n'a pas de
-- prix en pièces (jamais vendu en pièces) : hors règle, documenté. coinCost : prix boutique si la rareté y est vendue, sinon prix du tapis (x 0,6).
Config.PRICING_REF = { secondsPerRobux = Config.COIN_PACK_MINUTES * 60 / Config.PRODUCTS.CoinPack.robux, minRatio = 4, maxRatio = 12 }
Config.PRICING = {
	ExclusiveEgg = { tier = 6, coinCost = 609975778, robuxCost = 249, where = "boutique", timeToAffordCoin = { beginner = 22750, mid = 6420, advanced = 420 } },
	EggSecret = { tier = 8, coinCost = 45000000000, robuxCost = 1499, where = "tapis", timeToAffordCoin = { beginner = 179220, mid = 146340, advanced = 26220 } },
	EggDivine = { tier = 10, coinCost = 1080000000000, robuxCost = 6999, where = "tapis", timeToAffordCoin = { beginner = 625440, mid = 589620, advanced = 293700 } },
	EggExclusive = { tier = 9, coinCost = nil, robuxCost = 3499, where = "jamais en pièces", timeToAffordCoin = nil },
}
function Config.timeRobux(robux)
	return robux * Config.PRICING_REF.secondsPerRobux
end
-- Un achat n'est proposé que si son ID Roblox a été renseigné (entier > 0). Sinon il reste désactivé, avec un message clair.
function Config.purchasable(def)
	return type(def.id) == "number" and def.id > 0 and def.id % 1 == 0
end
Config.UNAVAILABLE_MESSAGE = "🛒 Cet achat n'est pas encore disponible. Reviens bientôt !"

Config.LUCK_POTION_BONUS = 25
-- Lot 9 : plafond du CUMUL des bonus (tapis doré + tapis privé + potion + pass Chance + pluie de chance). `paidUp` = points d'amélioration payants
-- cumulés au plus (appliqué par le serveur dans Rules.upPoints) ; `gain` = gain de progression maximal mesuré par tests/Economy.lua (testé, +60 %).
Config.BOOST_CAP = { paidUp = 30, gain = 0.6 }
Config.LUCK_POTION_SECONDS = 900

-- Revenu passif : il ne s'accumule que si le joueur est ACTIF (action ou déplacement dans les `seconds` dernières secondes). Au départ du joueur, le revenu hors ligne
-- est plafonné à `offlineMaxSeconds` de gains (x `offlineRate`) ; il est mis de côté (pendingAway) et se récupère d'un clic à la reconnexion.
Config.IDLE = { seconds = 90, offlineMaxSeconds = 1800, offlineRate = 0.4 }

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
	-- A11 : nouveaux types (Config.QUESTS.newTypes, textes « {n} »)
	local nt = Config.QUESTS and Config.QUESTS.newTypes and Config.QUESTS.newTypes[t]
	if type(nt) == "table" and type(nt.text) == "string" then
		return (string.gsub(nt.text, "{n}", tostring(n)))
	end
	return t
end

-- Bonus de mission au-delà des pièces : { egg = rareté d'œuf, boost = secondes de chance supplémentaire }. Missions de défi (Château, rare, secret) :
-- œuf ou boost ; sinon la 2e mission du jour donne un œuf (rareté selon la progression d'histoire `ch`), la 3e un boost de chance de 10 minutes.
function Config.questBonus(t, index, ch)
	ch = ch or 0
	local tier = Config.TIER_MIGRATE[1 + (ch >= 4 and 1 or 0) + (ch >= 8 and 1 or 0)] -- Commun, Rare, Épique (indices du lot 9)
	if t == "castle" then
		return { egg = ch >= 8 and 5 or 4 }
	elseif t == "rare" then
		return { boost = 900 }
	elseif t == "secret" then
		return { egg = 3 }
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
	timeout = 12, -- secondes maximum par tentative (un nouvel essai est fait si la première échoue)
	batchSize = 8, -- modèles chargés EN PARALLÈLE par lot (un échec ne retarde que son lot)
	retryUntil = 25, -- secondes depuis le premier chargement : au-delà, plus de nouvel essai (la suite est toujours lancée)
	maxParts = 60, -- un modèle plus lourd est refusé (il est cloné pour chaque œuf)
	decorMaxParts = 220, -- plafond des modèles de décor du hub (placés une seule fois)
	maxParticleRate = 20, -- plafond des émetteurs de particules du modèle (par seconde)
	targetHeight = 3.4, -- hauteur en studs à laquelle chaque modèle est ramené
	eggs = { -- lot 9 : 10 œufs Blender (un par rareté), repli procédural (Config.EggFx.looks, Builder.egg)
		r1 = 135765683612513,
		r2 = 87965918516208,
		r3 = 96993304097437,
		r4 = 109265198341087,
		r5 = 133048256610873,
		r6 = 102115260137639,
		r7 = 101573584229717,
		r8 = 127835469690102,
		r9 = 98454425446209,
		r10 = 124299527536427,
	},
	eggsMaxParts = 40, -- plafond de Parts d'un œuf Blender (cloné pour chaque œuf)
	eggShellPart = "Coque", -- pièce dont la hauteur fixe l'échelle de l'œuf (couronne, auréole et ailes dépassent)
	-- Lot 9 : les catalogues (red, orange...) et les 6 œufs Blender historiques (eggsByRarity) sont remplacés par les 10 œufs Blender r1..r10
	-- (clés de eggs ci-dessus, Config.Assets.eggByTier) ; pièces nommées Coque, Embleme, Motif, Anneau, Couronne, Chaine, Cristaux, Etoiles, Ailes,
	-- Aureole, Fissure. L'échelle se calcule sur la hauteur de la pièce `Coque` (Assets.fitByPart) ; les effets restent dans le code.
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
		props = { bridge_rail = 112917439859012, fence_corner = 120728100461105, fence_gate = 95541995292351, hut_small = 93190979240574, hut_big = 128414703286969, mill = 108678125939354, castle = 85826335560323, chest = 81643274706684, torch = 89605986322384, flag = 110279682395149, sign = 74276869239897, pen = 117636221218047, lamp = 137473402121117, bench = 123958905099505 },
		guards = { dog = 103939852527807, wolf = 97774277975586, bear = 70929301247964, knight = 79935066561502 },
		castle = { wall = 136500159645250, tower = 120194370584366, door = 81799010490650, floor = 87526275066787 },
		traps = { spikes = 109204482572726, blade = 83758069602274, ball = 97316525004480 },
		ground = { grass = 108336655087221, path = 129255762203803, plaza = 129476241883133 },
		deco = { flower_a = 77356084419297, flower_b = 75380956155225, flower_c = 111315415429762, tuft = 87978041093798, stone_flat = 136754104457535, stone_round = 87559674928022, lantern = 104138982529608, sign_stars = 123744671851193 },
		terrain = { cliff_a = 77185775444063, cliff_b = 121767734121074, cliff_corner = 110100977206117, stairs = 105161635046156, waterfall = 129292144451409, islet = 128405076287969 },
		base = { level1 = 97252816676038, level2 = 81995835244074, level3 = 77426422736227, level4 = 95370892804658, level5 = 75516398880390, level6 = 108065975809605, level7 = 83929759854266, level8 = 100223033827392 },
		house = { l2 = 83993710226197, l3 = 137211706941591, l4 = 131395542579523, l5 = 86282878742281, l6 = 92231252125110, l7 = 79107809937066 }, -- maisons évolutives (niveaux 2 à 7, lot 5) ; niveaux 1 et 8 : base.level1 / base.level8
		vfx = { cercle_runique = 78887954880607, ailes = 139237669898830, halo = 123922819073158, rayons = 88635068911286, etoile = 73454147532566, cristaux = 84932789634035, onde = 125557026046168, torii = 105301464189354, spirale = 130478050046509, pilier_lumiere = 136359342334671, etincelles = 116678428336273, cone_lumiere = 98452721754905, bouclier = 135593787305812 },
		trees = { tree_oak_a = 115675817596242, tree_oak_b = 139178488755477, tree_birch = 86165293471213, tree_pine = 134548154871906, tree_sakura = 136998832791777, tree_round = 128198214830836 },
		paths = { path_straight = 85121318662290, path_curve = 101412637646543, path_stones = 119316046353622 },
		eggguard = { egg_dome = 114304098897950, egg_nest_fence = 101252453233834, egg_cage = 98653120562597, egg_shield = 73837494094507 },
		scenery = { scn_puits = 93457733638103, scn_pin_haut = 103664392312435, scn_pont_pierre = 71167399273394, scn_maison_colombages = 108434085196211, scn_tour_cloche = 117760736577913, scn_rocher_a = 109597978140541, scn_rocher_b = 91218401630144, scn_rocher_c = 126837715911422, scn_ile_sakura = 103275800553270 },
		hub = { kiosk = 90238570290603 }, -- lot 8B : kiosque central de la place (hub_kiosk, clé J.1 hub.kiosk ; Kiosk.lua, repli procédural)
		pets = { Chat = 81991111371408, Chien = 90815266946917, Hamster = 130387777043821, Hibou = 95489512823854, Licorne = 119358850090330, Lion = 73493068085290, Manchot = 73235151647339, TRex = 113312935651236 },
	},
	modelsMaxParts = { ["hub.kiosk"] = 220, ["guards.dog"] = 80, ["guards.wolf"] = 80, ["guards.bear"] = 90, ["guards.knight"] = 100, ["traps.spikes"] = 60, ["traps.blade"] = 40, ["traps.ball"] = 30,
		["castle.wall"] = 30, ["castle.tower"] = 80, ["castle.door"] = 50, ["castle.floor"] = 20, ["props.chest"] = 40, ["props.torch"] = 20, ["props.flag"] = 20, ["props.castle"] = 220, ["props.mill"] = 120, ["props.pen"] = 40, ["props.lamp"] = 25, ["props.bench"] = 30, ["props.sign"] = 20, ["props.bridge_rail"] = 30, ["props.fence_corner"] = 10, ["props.fence_gate"] = 10, ["props.hut_small"] = 60, ["props.hut_big"] = 90,
		["deco.flower_a"] = 6, ["deco.flower_b"] = 6, ["deco.flower_c"] = 6, ["deco.tuft"] = 4, ["deco.stone_flat"] = 4, ["deco.stone_round"] = 4, ["deco.lantern"] = 6, ["deco.sign_stars"] = 14,
		["terrain.cliff_a"] = 14, ["terrain.cliff_b"] = 14, ["terrain.cliff_corner"] = 14, ["terrain.stairs"] = 12, ["terrain.waterfall"] = 10, ["terrain.islet"] = 12,
		["base.level1"] = 80, ["base.level2"] = 80, ["base.level3"] = 80, ["base.level4"] = 80, ["base.level5"] = 80, ["base.level6"] = 80, ["base.level7"] = 80, ["base.level8"] = 80,
		["house.l2"] = 160, ["house.l3"] = 160, ["house.l4"] = 160, ["house.l5"] = 160, ["house.l6"] = 160, ["house.l7"] = 160,
		["trees.tree_oak_a"] = 120, ["trees.tree_oak_b"] = 120, ["trees.tree_birch"] = 120, ["trees.tree_pine"] = 120, ["trees.tree_sakura"] = 120, ["trees.tree_round"] = 120,
		["paths.path_straight"] = 40, ["paths.path_curve"] = 40, ["paths.path_stones"] = 40,
		["eggguard.egg_dome"] = 80, ["eggguard.egg_nest_fence"] = 80, ["eggguard.egg_cage"] = 80, ["eggguard.egg_shield"] = 60,
		["scenery.scn_puits"] = 120, ["scenery.scn_pin_haut"] = 150, ["scenery.scn_pont_pierre"] = 200, ["scenery.scn_maison_colombages"] = 200, ["scenery.scn_tour_cloche"] = 150,
		["scenery.scn_rocher_a"] = 40, ["scenery.scn_rocher_b"] = 40, ["scenery.scn_rocher_c"] = 40, ["scenery.scn_ile_sakura"] = 200,
		["ground.plaza"] = 30, ["ground.path"] = 30, ["ground.grass"] = 30 },
	-- Textures tuilables (IDs de DÉCALS, lus côté serveur) posées par Texture sur la face visible des grandes surfaces. `tile` = studs par répétition.
	-- Ordre de priorité = ordre de `textureOrder` ; au plus `textureMaxCount` Textures au total (mobile : une face par pièce).
	textures = {
		grass = { id = 122917279401510, tile = 8, targets = { { name = "Ground", faces = { "Top" } } } },
		-- REFONTE (lot 2) : cibles renommées (A.6) : RiverNorth, BrookMill, BrookWillow, LakeMill, LakeWillow, Fountain, CastleMoat
		water = { id = 72897294450066, tile = 10, transparency = 0.2, targets = { { name = "RiverNorth", faces = { "Top" } }, { name = "BrookMill", faces = { "Top" } }, { name = "BrookWillow", faces = { "Top" } }, { name = "LakeMill", faces = { "Top" } }, { name = "LakeWillow", faces = { "Top" } }, { name = "CastleMoat", faces = { "Top" } } } },
		castleFloor = { id = 90865253086689, tile = 8, targets = { { prefix = "CastleFloor", faces = { "Top" } } } },
		castleStone = { id = 87480813124386, tile = 6, targets = { { name = "CastleWall", faces = { "Left", "Right" } }, { name = "CourtWall", faces = { "Left", "Right" } } } },
		wood = { id = 136082705365776, tile = 4, targets = { { name = "BridgePlank", faces = { "Top" } } } },
		sand = { id = 83914325296472, tile = 8, targets = { { name = "LakeShore", faces = { "Right" } }, { name = "ArenaSand", faces = { "Right" } } } }, -- disques (cylindres) : face plate = Right
		path = { id = 84243738566468, tile = 8, targets = { { name = "PathStone", faces = { "Top" } } } }, -- dalles des routes pavées (blocs) : face du dessus
	},
	textureOrder = { "grass", "water", "castleFloor", "castleStone", "wood", "sand", "path" },
	textureMaxCount = 220,
	groundBudgetParts = 600, groundMaxTiles = 120, -- dallage : Parts réelles (mesurées) et nombre de tuiles maximum
	arenaBudgetParts = 500, -- pire cas de Parts des modèles Blender de l'arène (place, bancs, lampadaires, moulin, enclos)
	houseBudgetPerBase = 160, -- Parts de la maison évolutive d'UNE base (modèle Blender house.lN ou repli procédural), lot 5
	baseBlenderBudget = 280, -- pire cas de Parts des modèles Blender d'UNE base (cabane 120 + deux tours 80) ; au-delà, versions procédurales
	vfxMaxParts = 30, -- plafond de Parts de chaque modèle d'effet (clé modelsMaxParts["vfx.x"] : vfxMaxParts par défaut)
	castleBudgetParts = 1700,
	decoBudgetParts = 420, -- décor fin (fleurs, touffes, pierres, lanternes) : budget SÉPARÉ des 1200 Parts procédurales, posé après la carte
	decorBudgetParts = 1000, -- lot 8B-décor : Parts Blender du décor de carte (lots 15 à 17, Decor.lua), coût MESURÉ, budget SÉPARÉ posé après la carte
	decorFallbackParts = 240, -- Parts procédurales de repli de ce décor (modèle absent, refusé ou trop lourd)
	decorOff = {}, -- { famille = true } désactive une famille de DecorData (ex. { conveyor_belt = true, hub_dome = true })
	reliefBudgetParts = 700, -- falaises, cascades, îlots Blender : budget séparé, posé après la carte
	-- Arbres Blender (6 variantes) : hauteur cible de chacun (studs) ; variante choisie selon la zone (Placement.treeVariant), échelle ±15 %, rotation libre.
	treeHeights = { tree_oak_a = 10, tree_oak_b = 10, tree_birch = 10, tree_pine = 11, tree_sakura = 10, tree_round = 8 },
	treeScaleJitter = 0.15,
	-- Chemins Blender (tuiles de 8 x 8, droite le long de X, virage à 90°), bordés de pierres : budget de Parts séparé, repli = pavés procéduraux.
	pathTile = 8, pathWind = 5, pathBudgetParts = 900, pathBorderHeight = 0.6,
	-- Protection de l'œuf d'un emplacement selon la rareté (clé de models.eggguard) et largeur cible (studs) ; halo / lumière proportionnels à la rareté.
	eggGuardKeys = { "egg_nest_fence", "egg_nest_fence", "egg_dome", "egg_dome", "egg_cage", "egg_shield", "egg_shield", "egg_shield", "egg_shield", "egg_shield" },
	eggGuardWidth = { egg_nest_fence = 6.5, egg_dome = 4.4, egg_cage = 4.6, egg_shield = 5 },
	eggGuardBudgetPerBase = 500, -- Parts Blender de protection par base (au-delà : nid procédural)
	-- Décor de village (lot scn_*) : `h` = hauteur cible, `len` = plus grande arête cible (studs), `r` = rayon d'empreinte pour la planification.
	sceneryDims = { scn_puits = { h = 8, r = 4 }, scn_pin_haut = { h = 16, r = 4 }, scn_pont_pierre = { len = 40, r = 22 }, scn_maison_colombages = { h = 12, r = 8 }, scn_tour_cloche = { h = 16, r = 5 },
		scn_rocher_a = { len = 8, r = 5 }, scn_rocher_b = { len = 6, r = 4 }, scn_rocher_c = { len = 10, r = 6 }, scn_ile_sakura = { len = 24, r = 13 } },
	scenerySmallRock = 4, -- largeur des rochers en bordure de mare
	sceneryBudgetParts = 1500, -- Parts Blender du décor de village (carte et hub chacun, budget séparé)
	decoHeights = { flower_a = 1, flower_b = 1, flower_c = 1, tuft = 1.2, stone_flat = 0.6, stone_round = 0.9, lantern = 1.2, sign_stars = 5 }, -- hauteurs cibles (studs) du décor fin
	decoFallbackMax = 40, -- Parts procédurales de repli (fleurs) si les modèles Blender manquent -- pire cas de Parts des modèles Blender du château (murs, tours, portes, coffre, torches, drapeaux, fond)
	-- Hauteurs cibles en studs (le joueur mesure ~5). Chaque modèle est mis à l'échelle sur SA HAUTEUR d'après GetExtentsSize puis remesuré (±10 %) ;
	-- mesure impossible = modèle non posé (repli procédural), jamais d'échelle brute.
	targetHeights = { player = 5, petMin = 1.7, petMax = 2.5, petHard = 3.4, eggMin = 1.8, eggMax = 2.9, lamp = 8, bench = 2.5, fountain = 7, hut = 11, mill = 20, dog = 2.5, wolf = 3, bear = 5, knight = 4.5, tower = 24, chest = 4, torch = 3, flag = 7 },
	-- Seules ces pièces (nom de base, sans suffixe de couleur) gardent un matériau Metal ; Neon seulement pour les flammes ; tout le reste en plastique lisse.
	metalParts = { Anneau = true, Tige = true, Serrure = true, Poignee = true, Fer = true, Cercles = true, Pics = true, Lame = true, Herse = true },
	neonParts = { Flamme = true, Aureole = true, Fissure = true },
	guardKinds = { "dog", "wolf", "bear" }, -- gardien de chaque domaine (Config.RIVALS) -> modèle de models.guards
	guardHeights = { dog = 2.5, wolf = 3, bear = 5, knight = 4.5 }, -- hauteur en studs (= targetHeights)
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
	-- Lot 9 : modèles des 60 nouvelles espèces (numéro C.2 -> identifiant), branchés au lot 11 ; plafond de Parts propre.
	petsNew = {},
	petsMaxPartsNew = 40,
	petsMaxParts = 120, -- plafond de Parts d'un modèle de pet (cloné pour chaque pet affiché)
	petHeight = 3, -- (les pets Blender mesurent ~1 : mis à l'échelle sur cette hauteur) -- hauteur en studs d'un pet de taille « Normal » (multipliée par l'échelle de taille)
	eggByTier = { "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10" },
	-- Classes supprimées de tout modèle chargé (code, communication, sons, effets à effet de bord, outils, liaisons parasites).
	blockedClasses = {
		"Script", "LocalScript", "ModuleScript", "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent", "BindableEvent", "BindableFunction",
		"Sound", "Tool", "ForceField", "Explosion", "Weld", "WeldConstraint", "Motor6D", "ManualWeld", "Motor",
	},
}
-- LOT 11 : modèles Blender des 60 nouvelles espèces (lots 22 à 26), indice d'espèce -> identifiant, lus dans Bestiary.ASSET_IDS (source unique). Assets.loadPets les charge avec petsMaxPartsNew.
if Config.BESTIARY then
	for idx, id in pairs(Config.BESTIARY.ASSET_IDS) do
		Config.Assets.petsNew[idx] = id
	end
end

---------------------------------------------------------------- Apparence des œufs construite par le code (repli des modèles, utilisée aussi quand ils sont coupés)
-- Une apparence distincte par modèle de Config.Assets.eggs : couleur, matériau, lumière, particules, halo (sphère ou anneau, qui tourne ou
-- scintille côté client). `Enabled = false` : œufs simples (couleur + sphère), utile pour alléger les téléphones modestes.
-- Lot 9 (A.5) : 10 apparences r1..r10. `details` = pièces construites par le code (Builder.eggDetails, <= 24 Parts, emblème = rune-œuf du jeu,
-- JAMAIS le logo Roblox) ; `orbit` = cubes en orbite (tournés par le client, tag EggHalo) ; `glass` = coque en verre (forcé aussi sur le modèle Blender).
Config.EggFx = {
	Enabled = true,
	maxParts = 24,
	looks = {
		r1 = { name = "Commun", color = Color3.fromRGB(220, 220, 230), material = "SmoothPlastic", light = Color3.fromRGB(220, 220, 230), brightness = 0.6, emblem = Color3.fromRGB(58, 58, 66),
			details = { spots = { n = 3, color = Color3.fromRGB(180, 184, 196) } } },
		r2 = { name = "Peu commun", color = Color3.fromRGB(60, 220, 60), material = "SmoothPlastic", light = Color3.fromRGB(60, 220, 60), emblem = Color3.fromRGB(168, 255, 140),
			details = { pixels = { n = 4, color = Color3.fromRGB(46, 184, 46) } }, orbit = { n = 6, color = Color3.fromRGB(60, 220, 60), rps = 0.3 } },
		r3 = { name = "Rare", color = Color3.fromRGB(46, 139, 255), material = "SmoothPlastic", light = Color3.fromRGB(46, 139, 255), emblem = Color3.fromRGB(140, 200, 255),
			details = { pixels = { n = 4, color = Color3.fromRGB(20, 80, 180) }, ring = { color = Color3.fromRGB(140, 200, 255), tilt = 20 } }, orbit = { n = 4, color = Color3.fromRGB(46, 139, 255), rps = 0.5 } },
		r4 = { name = "Épique", color = Color3.fromRGB(74, 26, 140), material = "SmoothPlastic", light = Color3.fromRGB(155, 77, 255), emblem = Color3.fromRGB(200, 155, 255),
			details = { stripes = { n = 3, color = Color3.fromRGB(155, 77, 255) }, crystals = { n = 4, color = Color3.fromRGB(200, 155, 255) } },
			particles = { color = Color3.fromRGB(181, 124, 255), rate = 4, speed = 2, size = 0.25, life = 1.4 } },
		r5 = { name = "Légendaire", color = Color3.fromRGB(255, 194, 26), material = "SmoothPlastic", light = Color3.fromRGB(255, 210, 74), brightness = 1.5, emblem = Color3.fromRGB(255, 240, 176),
			details = { crown = { color = Color3.fromRGB(255, 210, 74) }, groundRing = { color = Color3.fromRGB(255, 210, 74) } },
			halo = { shape = "ring", color = Color3.fromRGB(255, 230, 140), scale = 1.4, transparency = 0.3, spin = 1.2 },
			particles = { color = Color3.fromRGB(255, 230, 140), rate = 6, speed = 2.5, size = 0.28, life = 1.5 } },
		r6 = { name = "Mythique", color = Color3.fromRGB(26, 16, 20), material = "SmoothPlastic", light = Color3.fromRGB(255, 48, 32), brightness = 1.8, emblem = Color3.fromRGB(255, 96, 64),
			details = { cracks = { n = 3, color = Color3.fromRGB(255, 48, 32) }, chain = { n = 6, color = Color3.fromRGB(58, 58, 66) } },
			particles = { color = Color3.fromRGB(255, 112, 64), rate = 8, speed = 2.5, size = 0.3, life = 1.2 }, pulse = 1 },
		r7 = { name = "Ultra Rare", color = Color3.fromRGB(111, 214, 255), material = "Glass", glass = 0.2, light = Color3.fromRGB(111, 214, 255), brightness = 2, emblem = Color3.fromRGB(255, 255, 255),
			details = { crystals = { n = 6, color = Color3.fromRGB(191, 239, 255) } },
			particles = { color = Color3.fromRGB(255, 255, 255), rate = 6, speed = 1, size = 0.22, life = 2 } },
		r8 = { name = "Secret", color = Color3.fromRGB(10, 10, 18), material = "SmoothPlastic", light = Color3.fromRGB(255, 120, 200), brightness = 2, emblem = Color3.fromRGB(255, 255, 255), rainbow = true,
			details = { ring = { color = Color3.fromRGB(255, 80, 80), tilt = 30 }, ring2 = { color = Color3.fromRGB(80, 170, 255), tilt = -30 }, stars = { n = 3, color = Color3.fromRGB(255, 225, 74) } },
			halo = { shape = "ball", color = Color3.fromRGB(190, 110, 255), scale = 1.25, transparency = 0.7, flicker = true } },
		r9 = { name = "Exclusif", color = Color3.fromRGB(242, 242, 242), material = "SmoothPlastic", light = Color3.fromRGB(255, 255, 255), brightness = 1.2, emblem = Color3.fromRGB(20, 20, 20),
			details = { shards = { n = 3, color = Color3.fromRGB(20, 20, 20) }, crown = { color = Color3.fromRGB(20, 20, 20) }, chain = { n = 4, color = Color3.fromRGB(58, 58, 66) } },
			orbit = { n = 4, color = Color3.fromRGB(20, 20, 20), rps = 0.25 },
			particles = { color = Color3.fromRGB(150, 150, 150), rate = 3, speed = 0.6, size = 0.6, life = 2.5 } },
		r10 = { name = "Divin", color = Color3.fromRGB(255, 243, 176), material = "Glass", glass = 0.15, light = Color3.fromRGB(255, 230, 128), brightness = 2, emblem = Color3.fromRGB(255, 210, 74),
			details = { wings = { color = Color3.fromRGB(255, 255, 255) }, halo = { color = Color3.fromRGB(255, 230, 128) } }, orbit = { n = 4, color = Color3.fromRGB(255, 210, 74), rps = 0.35 },
			particles = { color = Color3.fromRGB(255, 230, 128), rate = 8, speed = 1.5, size = 0.3, life = 1.8 } },
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

-- Progression de la base (REFONTE lot 5) : chaque pet éclos ajoute des points selon sa rareté (Config.BASE_WEIGHTS = BASE_WEIGHTS2 : 1, 4, 15, 50, 180, 700) ;
-- 8 niveaux (Config.BASE_LEVELS = BASE_LEVELS2, définis plus bas), de l'enclos de bois au château doré. Le score est sauvegardé (profil v8, recalculé en v10) ;
-- le niveau s'en déduit, plafonné par la rareté découverte (niveaux 7 et 8) et jamais sous le plancher `baseLevelFloor` des anciens joueurs.
-- Points gagnés par un pet de rareté `tier` (1..6).
function Config.baseGain(tier)
	return Config.BASE_WEIGHTS[math.min(math.max(type(tier) == "number" and tier == tier and math.floor(tier) or 1, 1), #Config.BASE_WEIGHTS)]
end
-- Rareté la plus haute découverte d'après le dex ({ ["indice d'espèce"] = { n = ... } }), 0 si rien.
function Config.dexTopTier(dex)
	local top = 0
	if type(dex) == "table" then
		for k, e in pairs(dex) do
			local def = Config.PETS[tonumber(k) or 0]
			if def and type(e) == "table" and type(e.n) == "number" and e.n > 0 and def.tier > top then
				top = def.tier
			end
		end
	end
	return top
end
-- Niveau d'une base : (niveau 1..8, niveau suivant ou nil, progression 0..1 vers le suivant, points restants, rareté manquante ou nil).
-- `dex` (facultatif) : sans lui, aucune condition de rareté n'est exigée (appels historiques) ; avec lui, le niveau est plafonné tant qu'il manque
-- la rareté `needTier` du niveau suivant. `floor` (facultatif) : plancher sauvegardé, le niveau affiché ne passe jamais dessous.
function Config.baseLevel(score, dex, floor)
	score = (type(score) == "number" and score == score and score > 0) and score or 0
	local levels = Config.BASE_LEVELS
	local top = dex ~= nil and Config.dexTopTier(dex) or nil
	local level = 1
	for i = 2, #levels do
		local lv = levels[i]
		if score < lv.score or (lv.needTier and top ~= nil and top < lv.needTier) then
			break
		end
		level = i
	end
	if type(floor) == "number" and floor == floor then
		level = math.max(level, math.min(#levels, math.max(1, math.floor(floor))))
	end
	local nxt = levels[level + 1]
	if not nxt then
		return level, nil, 1, 0, nil
	end
	local cur = levels[level]
	local progress = math.min(1, math.max(0, (score - cur.score) / (nxt.score - cur.score)))
	local need = (nxt.needTier and top ~= nil and top < nxt.needTier) and nxt.needTier or nil
	return level, nxt, progress, math.max(0, math.ceil(nxt.score - score)), need
end
-- Emplacements bonus du niveau `level` (bonus absolu, non cumulatif : 0 au niveau 1, 4 au niveau 8) et multiplicateur de revenu (1 + income).
function Config.levelSlots(level)
	local lv = Config.BASE_LEVELS[level]
	return lv and lv.slots or 0
end
function Config.levelIncomeMul(level)
	local lv = Config.BASE_LEVELS[level]
	return 1 + (lv and lv.income or 0)
end
-- Position locale (x, z) de l'emplacement `idx` (1..20) : grille 5 colonnes x 4 rangées, pas de 9 studs. Source unique (construction, caméras, interface).
function Config.padLocal(idx)
	local col, row = (idx - 1) % 5, (idx - 1) // 5
	return -18 + col * 9, -4 + row * 9
end
-- Plateforme au niveau `level` : (demi-largeur, z local du bord arrière). Elle grandit vers les côtés (52 -> 72) et vers l'arrière (28 -> 35,7) ;
-- l'avant reste à -26 (spawn, porte et chemins ne bougent pas) et l'arrière reste dans l'emprise réservée par la carte (baseSizeMax / 2 = 36).
function Config.baseExtent(level)
	local n = math.min(math.max(type(level) == "number" and level == level and level or 1, 1), #Config.BASE_LEVELS)
	local lv = Config.BASE_LEVELS[math.floor(n)]
	return ((lv and lv.size) or 52) / 2, 28 + (math.floor(n) - 1) * 1.1
end
-- Un point (repère local de la base : rx, rz, ry) est-il dans la base du niveau `level` (intérieur de la plateforme + 1 stud de marge) ?
function Config.inBase(level, rx, rz, ry)
	local halfX, backZ = Config.baseExtent(level)
	return math.abs(rx) <= halfX + 1 and rz >= -27 and rz <= backZ + 1 and (ry == nil or ry < 30)
end

-- Hauteur cible d'un pet : 1,7 à 2,1 studs selon la rareté (1..6, joueur = 5), multipliée par l'échelle de sa taille, jamais plus de 3 (60 % d'un joueur).
function Config.petTargetHeight(tier, sizeScale)
	local H = Config.Assets.targetHeights
	local t = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), Config.TIER_COUNT)
	local base = H.petMin + (H.petMax - H.petMin) * (t - 1) / (Config.TIER_COUNT - 1)
	local k = (type(sizeScale) == "number" and sizeScale == sizeScale and sizeScale > 0) and sizeScale or 1
	return math.min(base * k, H.petHard)
end

-- Protection de l'œuf de rareté `tier` : Commun = nid à barrière, Rare/Épique = dôme de verre, Légendaire = cage, Mythique/Cosmique = cristaux.
function Config.eggGuardKey(tier)
	local t = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), #Config.Assets.eggGuardKeys)
	return Config.Assets.eggGuardKeys[math.floor(t)]
end

-- Intensité de lumière de la protection (proportionnelle à la rareté : 0,5 à 3) et portée (6 à 11 studs).
function Config.eggGuardGlow(tier)
	local t = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), Config.TIER_COUNT)
	local k = (t - 1) / (Config.TIER_COUNT - 1)
	return { brightness = 0.5 + k * 2.5, range = 6 + k * 5, transparency = Config.tierAtLeast(t, "shine") and 0.7 or 0.8 }
end

-- Hauteur cible d'un œuf : 1,8 à 2,8 studs selon la rareté.
function Config.eggHeight(tier)
	local H = Config.Assets.targetHeights
	local t = math.min(math.max(type(tier) == "number" and tier == tier and tier or 1, 1), Config.TIER_COUNT)
	return H.eggMin + (H.eggMax - H.eggMin) * (t - 1) / (Config.TIER_COUNT - 1)
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

-- Décor de village du HUB (lot scn_*) : { modèle, x, z, rotation (nil = face au centre), largeur forcée (nil = dimension par défaut) }. Placé après le décor
-- procédural ; les arbres et fleurs procéduraux sous l'empreinte sont retirés. Mare procédurale : Config.HubPond.
Config.HubPond = { x = -125, z = 30, w = 36, d = 18 }
Config.HubScenery = {
	{ "scn_ile_sakura", 130, 40 },
	{ "scn_pont_pierre", -125, 30, 0 },
	{ "scn_puits", -100, 75 },
	{ "scn_maison_colombages", -150, -40 }, { "scn_maison_colombages", 155, -45 }, { "scn_maison_colombages", 95, 115 }, { "scn_maison_colombages", -95, 125 },
	{ "scn_tour_cloche", 0, 165 },
	{ "scn_pin_haut", -170, 60 }, { "scn_pin_haut", 170, 70 }, { "scn_pin_haut", -60, 175 }, { "scn_pin_haut", 60, 175 }, { "scn_pin_haut", -145, -105 }, { "scn_pin_haut", 150, -110 },
	{ "scn_rocher_a", -110, 110 }, { "scn_rocher_b", 115, 85 }, { "scn_rocher_c", 160, 10 }, { "scn_rocher_a", -165, -10 }, { "scn_rocher_b", -40, 150 }, { "scn_rocher_c", 45, 150 },
	-- rochers en bordure de la mare
	{ "scn_rocher_b", -146, 18, nil, 4 }, { "scn_rocher_a", -146, 42, nil, 4 }, { "scn_rocher_b", -104, 18, nil, 4 }, { "scn_rocher_a", -104, 42, nil, 4 },
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
		{ rays = 7, rings = 1, shake = 0.05, flash = 0.08, particles = 6 },
		{ rays = 8, rings = 1, shake = 0.1, flash = 0.15, particles = 8 },
		{ rays = 10, rings = 2, shake = 0.25, flash = 0.3, particles = 14 },
		{ rays = 12, rings = 2, shake = 0.5, flash = 0.5, particles = 20 },
		{ rays = 14, rings = 3, shake = 0.8, flash = 0.7, particles = 28 },
		{ rays = 16, rings = 3, shake = 1, flash = 0.85, particles = 36 },
		{ rays = 16, rings = 3, shake = 1, flash = 0.9, particles = 36 },
		{ rays = 16, rings = 3, shake = 1, flash = 0.9, particles = 36 },
		{ rays = 16, rings = 3, shake = 1, flash = 1, particles = 36 }, -- plafond de performance RevealFx (<= 90 objets) : pas plus que l'ancien Cosmique
	},
	-- Écran de tirage « machine à sous » avant la révélation : 3 colonnes (rareté, taille, mutation) qui défilent puis s'arrêtent une à une.
	-- stops = secondes d'arrêt de chaque colonne ; loops = tours complets avant l'arrêt ; fastStops = tirage banal (Commun/Rare, taille et mutation normales) ou mobile.
	slot = { enabled = true, stops = { 1.1, 1.7, 2.3 }, fastStops = { 0.6, 0.95, 1.3 }, loops = { 3, 3, 4 }, hold = 0.55, cell = 34, phoenixFromTier = 5 },
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
Config.WEALTH = { -- lot 9 : seuils = prix des œufs Rare, Épique, Légendaire (suivent l'équilibrage)
	{ name = "Une pièce", min = 0, icon = "coin" },
	{ name = "Petite pile", min = Config.EGG_PRICE[3], icon = "pile" },
	{ name = "Grosse pile", min = Config.EGG_PRICE[4], icon = "mound" },
	{ name = "Coffre", min = Config.EGG_PRICE[5], icon = "chest" },
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
		if i <= Config.SHOP_MAX_TIER and Config.tierLive(i) and coins >= price then
			best = i
		end
	end
	return best
end

-- Lot 9 : raretés vendues en boutique (publiées et <= SHOP_MAX_TIER), et pas suivant (dir = -1 ou 1) avec retour à l'autre bout.
function Config.shopTiers()
	local out = {}
	for t = 1, math.min(Config.SHOP_MAX_TIER, Config.TIER_COUNT) do
		if Config.tierLive(t) then
			out[#out + 1] = t
		end
	end
	return out
end
function Config.shopStep(sel, dir)
	local list = Config.shopTiers()
	local idx = 1
	for i, t in ipairs(list) do
		if t == sel then
			idx = i
		end
	end
	return list[Config.carouselStep(idx, dir, #list)]
end

-- Déplace la sélection (dir = -1 ou 1) avec retour à l'autre bout.
function Config.carouselStep(sel, dir, n)
	n = n or #Config.TIERS
	return ((sel - 1 + (dir >= 0 and 1 or -1)) % n) + 1
end

---------------------------------------------------------------- Bannière de zone et promesse d'accueil
Config.ZONE_BANNERS = {
	arena = { title = "LA PLACE DU MARCHÉ", sub = "Le Grand Œuf, la halle et les portails", color = Color3.fromRGB(255, 210, 63) },
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
-- Onboarding en 4 étapes (Config.ONBOARD2), chacune passable : 1 toucher son œuf (aller vers lui, le toucher, le voir éclore), 2 prendre l'œuf de bienvenue sur le
-- tapis (flèche vers (10, 0)), 3 le poser dans sa base, 4 chiper un œuf dans l'enclos sauvage (flèche vers (75, -105)). `nearEgg` : le joueur est près de sa base ;
-- `remaining` : secondes avant l'éclosion ; `extra` = { stolen, carry, welcome } (état du serveur : welcome = wait / offered / taken / gone / none).
-- Retourne { index, total, text, target } (target : home / belt / wild) ou nil quand tout est fait.
function Config.onboarding(hatched, nearEgg, remaining, extra)
	if type(hatched) ~= "number" then
		return nil
	end
	local T = Config.ONBOARD2
	if hatched < 1 then
		local text = "🐣 Il éclot ! Regarde ce que tu obtiens"
		if not nearEgg then
			text = "🥚 Ton œuf offert t'attend dans ta base : suis la flèche"
		elseif type(remaining) == "number" and remaining > 2 then
			text = T[1]
		end
		return { index = 1, total = #T, text = text, target = "home" }
	end
	if type(extra) ~= "table" or (extra.stolen or 0) >= 1 then
		return nil
	end
	if (extra.carry or 0) > 0 then
		return { index = 3, total = #T, text = T[3], target = "home" }
	end
	if extra.welcome == "wait" or extra.welcome == "offered" then
		return { index = 2, total = #T, text = T[2], target = "belt" }
	end
	return { index = 4, total = #T, text = T[4], target = "wild" }
end

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
		return { id = "train", text = "Cours sur la piste d'entraînement 🏃 près de la place pour devenir plus rapide !" }
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
-- Bandeaux (lot 9) : couleurs des 10 raretés (A.1).
Config.RARITY_BANNERS = {
	{ name = "COMMUN", colors = { Color3.fromRGB(220, 220, 230), Color3.fromRGB(142, 147, 160) } },
	{ name = "PEU COMMUN", colors = { Color3.fromRGB(60, 220, 60), Color3.fromRGB(30, 140, 40) } },
	{ name = "RARE", colors = { Color3.fromRGB(46, 139, 255), Color3.fromRGB(20, 80, 180) } },
	{ name = "ÉPIQUE", colors = { Color3.fromRGB(155, 77, 255), Color3.fromRGB(74, 26, 140) } },
	{ name = "LÉGENDAIRE", colors = { Color3.fromRGB(255, 194, 26), Color3.fromRGB(184, 134, 11) } },
	{ name = "MYTHIQUE", colors = { Color3.fromRGB(224, 32, 46), Color3.fromRGB(26, 16, 20) } },
	{ name = "ULTRA RARE", colors = { Color3.fromRGB(111, 214, 255), Color3.fromRGB(42, 127, 212) } },
	{ name = "SECRET", colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 235, 110), Color3.fromRGB(80, 170, 255), Color3.fromRGB(190, 110, 255) } },
	{ name = "EXCLUSIF", colors = { Color3.fromRGB(242, 242, 242), Color3.fromRGB(20, 20, 20) } },
	{ name = "DIVIN", colors = { Color3.fromRGB(255, 243, 176), Color3.fromRGB(255, 230, 128) } },
	secret = { name = "SECRET", colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 235, 110), Color3.fromRGB(80, 170, 255), Color3.fromRGB(190, 110, 255) } },
}

function Config.rarityBanner(tier, secret)
	if secret then
		return Config.RARITY_BANNERS.secret
	end
	local t = type(tier) == "number" and tier == tier and math.floor(tier) or 1
	return Config.RARITY_BANNERS[math.min(math.max(t, 1), #Config.TIERS)]
end

-- Cercle runique au sol et aura autour du pet obtenu (rareté >= minTier ou secret). Budgets mobiles : maxRate (particules/s) et maxRunes plafonnent.
Config.AURA = {
	Enabled = true,
	minTier = 5,
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
	local level = secret and (Config.TIER_COUNT + 1) or tier
	local st = { runes = math.min(A.maxRunes, 4 + (level - A.minTier + 1) * 2), rate = math.min(A.maxRate, 8 + (level - A.minTier + 1) * 6), pillar = secret or Config.tierAtLeast(level, "pillar"), seconds = A.seconds + (secret and 3 or 0) }
	if reduced then
		st.runes = math.max(4, st.runes // 2)
		st.rate = st.rate // 2
		st.pillar = false
	end
	return st
end

-- États des pets (idle, move, ability) : la capacité des pets de rareté >= abilityMinTier se déclenche toutes les ~abilityInterval s.
Config.PET_STATES = { abilityMinTier = 4, abilityInterval = 9 }

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
	base = true, -- montée de niveau de la base (orbite courte)
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

---------------------------------------------------------------- Univers, histoire et progression
Config.TITLE = "Chipe-Œufs"
Config.TAGLINE = "Chipe, couve, collectionne : deviens Roi des Couvées !"
Config.LORE = "Il y a longtemps, la Grande Couvée donnait vie à tout le royaume. Puis le Grand Nid a volé en éclats, et ses œufs se sont dispersés. "
	.. "Les brigands Gus, Mara et Zed les gardent jalousement. Toi, apprenti Chipeur, tu peux les reprendre, les faire éclore et reconstruire le Nid. "
	.. "Mais méfie-toi : les autres Chipeurs convoitent aussi tes œufs !"

---------------------------------------------------------------- Carte : réglages communs, ambiance par zone, secrets, budget
-- REFONTE (lot 2) : la géométrie vient de Config.Map2 (700 x 500, place du marché au centre) et de Config.TERR (territoires) ; la géométrie
-- dérivée (bases orientées, chemins, eau, murs de rivière, portails, accessibilité) est calculée par le module pur MapGeo. Config.Map ne garde que
-- les réglages qui ne sont pas de la géométrie (budgets, streaming, ambiances) : c'est l'alias conservé pour le code et les tests qui le lisent.
Config.Map = {
	groundSize = 900, -- côté du plus grand axe du sol d'herbe (900 x 700 : zone jouable 700 x 500 + décor de fond)
	ambienceRadius = 62, -- portée maximale d'une ambiance de territoire (rayon du territoire + 12, plafonné ici)
	pedestals = true, -- piédestal hexagonal sous chaque emplacement
	budgetParts = 1200, -- le serveur avertit au démarrage si la carte procédurale dépasse ce nombre de Parts (budget mobile) ; les modèles Blender ont leurs propres budgets
	totalBudgetParts = 7000, -- plafond d'ensemble (carte procédurale + pire cas des accessoires Blender)
	Streaming = { Enabled = false, MinRadius = 128, TargetRadius = 480 }, -- coupé : un streaming défaillant laisse des joueurs sans sol ; à réactiver seulement après un playtest mobile,
	zoneKeys = { "gus", "mara", "zed" }, -- une clé par rival, dans l'ordre de Config.RIVALS
	ambience = {
		arena = { clock = 15.3, ambient = Color3.fromRGB(95, 105, 120), outdoor = Color3.fromRGB(125, 135, 155), tint = Color3.fromRGB(255, 255, 255), atmo = Color3.fromRGB(199, 220, 255), density = 0.28, haze = 1.4 },
		gus = { clock = 16.6, ambient = Color3.fromRGB(125, 110, 90), outdoor = Color3.fromRGB(165, 145, 110), tint = Color3.fromRGB(255, 244, 222), atmo = Color3.fromRGB(255, 226, 170), density = 0.25, haze = 1.2 },
		mara = { clock = 19.0, ambient = Color3.fromRGB(95, 70, 130), outdoor = Color3.fromRGB(105, 85, 150), tint = Color3.fromRGB(226, 214, 255), atmo = Color3.fromRGB(165, 125, 210), density = 0.42, haze = 2.0 },
		zed = { clock = 17.4, ambient = Color3.fromRGB(135, 75, 65), outdoor = Color3.fromRGB(160, 90, 75), tint = Color3.fromRGB(255, 208, 196), atmo = Color3.fromRGB(255, 140, 100), density = 0.40, haze = 2.2 },
	},
}

-- Territoires du rival i (dans l'ordre de Config.TERR_ORDER) : { {key, x, z, r, ...}, ... }. Gus en a deux, Mara et Zed un.
function Config.rivalTerritories(i)
	local out = {}
	for _, key in ipairs(Config.TERR_ORDER) do
		local t = Config.TERR[key]
		if t.rival == i then
			out[#out + 1] = { key = key, x = t.x, z = t.z, r = t.r, data = t }
		end
	end
	return out
end

-- Centre (x, z) du domaine du rival i = son PREMIER territoire (Gus Nord-Ouest, Mara, cour de Zed). Source unique : Builder, Cinematics et les tests.
function Config.rivalCenter(i)
	local t = Config.rivalTerritories(i)[1]
	return t.x, t.z
end

-- Hauteur du sol au centre du domaine i : 0, sauf la cour de Zed, sur le plateau du château (Map2.castle.h).
function Config.rivalHeight(i)
	local x, z = Config.rivalCenter(i)
	local c = Config.Map2.castle
	if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1 then
		return c.h
	end
	return 0
end

-- Poste (x, z) du gardien j sur `count` du rival i : les postes de tous ses territoires, dans l'ordre (Gus : NO puis SO).
function Config.guardTerritory(i, j, count)
	local k = 0
	for _, t in ipairs(Config.rivalTerritories(i)) do
		for _, p in ipairs(t.data.posts or {}) do
			k = k + 1
			if k == j then
				return p[1], p[2]
			end
		end
	end
	return Config.rivalCenter(i)
end

-- Nom du dossier d'un territoire dans World : « Rival_<nom> » pour le premier territoire d'un rival, « Rival_<nom>_<clé> » pour les suivants,
-- « WildPen » pour l'enclos sauvage. Source unique : Builder (construction) et Culling (masquage côté client).
function Config.territoryFolder(key)
	local t = Config.TERR[key]
	if t.rival == 0 then
		return "WildPen"
	end
	local riv = Config.RIVALS[t.rival]
	return "Rival_" .. riv.name .. (Config.rivalTerritories(t.rival)[1].key == key and "" or ("_" .. key))
end

-- Entrée d'un territoire (point du bord tourné vers la place ; la herse pour la cour de Zed) : zone sûre des gardiens (GUARD.safeRadius).
function Config.territoryEntry(key)
	local t = Config.TERR[key]
	if t.traps and t.traps.gate then
		return t.traps.gate.x, t.traps.gate.z
	end
	local d = math.sqrt(t.x * t.x + t.z * t.z)
	return t.x - t.x / d * t.r, t.z - t.z / d * t.r
end

-- Zone d'ambiance d'une position : "arena" (la place et tout le reste) ou la clé du rival (gus / mara / zed) dont un territoire est à portée (rayon + 12).
function Config.zoneAt(x, z)
	local best, bd = "arena", math.huge
	for _, key in ipairs(Config.TERR_ORDER) do
		local t = Config.TERR[key]
		if t.rival > 0 then
			local d = math.sqrt((x - t.x) ^ 2 + (z - t.z) ^ 2)
			if d <= math.min(t.r + 12, Config.Map.ambienceRadius) and d < bd then
				best, bd = Config.Map.zoneKeys[t.rival], d
			end
		end
	end
	return best
end

-- Boussole : zone à rejoindre = la plus avancée débloquée par l'histoire (1 au début).
function Config.frontierZone(chaptersDone)
	local best = 1
	for i = 1, #Config.RIVALS do
		if Config.zoneUnlocked(chaptersDone, i) then
			best = i
		end
	end
	return best
end

-- Flèche de boussole : angle (degrés, 0 = tout droit, positif = à droite) entre le regard (lookX, lookZ) et la direction du joueur (px, pz) vers la cible, et distance.
function Config.compass(px, pz, lookX, lookZ, tx, tz)
	local dx, dz = tx - px, tz - pz
	local dist = math.sqrt(dx * dx + dz * dz)
	local ll = math.sqrt(lookX * lookX + lookZ * lookZ)
	if dist < 1e-6 or ll < 1e-6 then
		return 0, dist
	end
	local cross = (lookX * dz - lookZ * dx) / (ll * dist) -- sin de l'angle orienté (axes X vers la droite, Z vers l'arrière de l'écran)
	local dot = (lookX * dx + lookZ * dz) / (ll * dist)
	local a = math.deg(math.atan(cross / (math.abs(dot) < 1e-9 and 1e-9 or dot)))
	if dot < 0 then
		a = a + (cross >= 0 and 180 or -180)
	end
	return a, dist
end

-- Voyage rapide (Config.TRAVEL2, plan A.4) : quatre portails sur la rose des portails de la place, un tapis de retour (vers la place) posé près de
-- chaque arrivée, et une arche « Retour à la base » par base sur la place. Attribut Dest d'un prompt : k > 0 = portail k ; 0 = retour à la place ;
-- -i = arche de la base i (seul son propriétaire l'utilise). Le serveur valide tout (voir Main.fastTravel).
function Config.portalPad(k)
	local h = Config.Map2.portalHub
	return h.x0 + (k - 1) * h.gap, h.z
end
function Config.homeArch(i)
	return -30 + (i - 1) * 15, 50
end
-- Point d'arrivée d'une destination de voyage : 0 = la place (près de la rose des portails), k = arrivée du portail k.
function Config.travelDest(dest)
	if dest == 0 then
		return Config.Map2.plazaArrival.x, Config.Map2.plazaArrival.z
	end
	local p = Config.TRAVEL2.portals[dest]
	return p.to[1], p.to[2]
end
-- Portail k débloqué au chapitre `chaptersDone` ?
function Config.portalUnlocked(chaptersDone, k)
	local p = Config.TRAVEL2.portals[k]
	return p ~= nil and (chaptersDone or 0) >= (p.chapter or 0)
end
-- Cible de la boussole : 0 = la place ; i = entrée du premier territoire du rival i (compatibilité : ancien nom conservé).
function Config.travelPoint(dest)
	if dest == 0 then
		return Config.travelDest(0)
	end
	return Config.territoryEntry(Config.rivalTerritories(dest)[1].key)
end
-- Secrets : un lieu caché par domaine ; une récompense par jour et par secret (max(minCoins, revenus de `mins` minutes)).
Config.SECRETS = {
	{ id = "verger", name = "L'œuf d'or du verger", emoji = "🥇", x = -330, z = -25, mins = 4, minCoins = 1500, hint = "Au fond du bois de l'Ouest, derrière les champs de Gus, un verger oublié garde un trésor." },
	{ id = "lanterne", name = "La lanterne de Mara", emoji = "🏮", x = 35, z = 125, mins = 6, minCoins = 4000, hint = "Au sud des bois de Mara, une lueur persiste là où personne ne va." },
	{ id = "coeur", name = "Le cœur de lave", emoji = "🔥", x = 335, z = -165, mins = 8, minCoins = 9000, hint = "Sur le plateau du château, à l'est de la cour de Zed, un cœur brûlant attend." },
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
	{ title = "Souffle court", text = "Les chiens de garde courent vite. Entraîne-toi sur la piste d'entraînement de la place : plus tu es rapide, plus tu es libre.", type = "train", goal = 45, coins = 500, mins = 1 },
	{ title = "Le petit cabinet", text = "Un vrai Chipeur collectionne. Découvre 3 espèces différentes : chaque série de 3 augmente tes revenus pour toujours.", type = "species", goal = 3, coins = 800, mins = 2 },
	{ title = "La Dame Mara", text = "Le domaine de Mara s'ouvre à toi. Ses œufs sont épiques, mais son loup est plus rapide que le chien de Gus. Chipe 5 œufs chez elle.", type = "steal", goal = 5, rival = 2, coins = 2000, mins = 5 },
	{ title = "Éclat épique", text = "Fais éclore un pet Épique ou mieux. Les œufs plus rares donnent plus souvent des pets plus rares.", type = "tier", goal = 1, tier = 4, coins = 5000, mins = 8 },
	{ title = "Mutation !", text = "La Citadelle de Zed est ouverte. Mais d'abord, un miracle : fais éclore un pet muté (Doré, Néon, Arc-en-ciel ou Alien).", type = "mut", goal = 1, coins = 10000, mins = 10 },
	{ title = "Le murmure des runes", text = "Les runes du Grand Œuf s'éveillent chaque jour. Lis l'énigme de Mère Poule (Missions > Énigme), tourne les 4 runes autour du Grand Œuf (à l'est de la place), puis touche-le pour valider.", type = "puzzle", goal = 1, coins = 15000, mins = 12 },
	{ title = "Chipeur confirmé", text = "Ta réputation grandit. Chipe 15 œufs au total, chez les rivaux ou chez d'autres Chipeurs.", type = "steal", goal = 15, coins = 25000, mins = 15 },
	{ title = "Le Roi Zed", text = "Zed garde les meilleurs œufs, dont les Cosmiques. Son ours ne rigole pas. Chipe 8 œufs dans sa citadelle.", type = "steal", goal = 8, rival = 3, coins = 60000, mins = 20 },
	{ title = "Légende vivante", text = "Fais éclore un pet Mythique : l'œuf du Dragon n'est plus loin.", type = "tier", goal = 1, tier = 6, coins = 150000, mins = 30 },
	{ title = "Le Grand Nid s'éveille", text = "Le Nid est prêt à renaître. Renais une fois pour le reconstruire, plus fort, et deviens Roi des Couvées !", type = "rebirth", goal = 1, coins = 300000, mins = 45 },
}

Config.COLLECTION_STEP = 3 -- tous les 3 espèces découvertes...
Config.COLLECTION_BONUS = 0.05 -- ...+5% de revenus permanents (max +30% avec les 18 premières espèces)
-- LOT 11 : au-delà des 18 espèces historiques, +5 % par tranche de 6 espèces supplémentaires, plafond +80 % (78 espèces). Identique à l'ancienne formule jusqu'à 18 espèces (jamais en baisse).
Config.COLLECTION_BASE_COUNT = 18
Config.COLLECTION_STEP2 = 6
Config.COLLECTION_MAX = 0.8
-- Arène des pets (PvE) : tour des Dresseurs de 30 étages, combats d'équipes de 3 pets résolus par le serveur (moteur Battle). Tous les 5 étages : un boss.
Config.TOWER = { floors = 45, tiers = { 1, 2, 3, 4, 5, 6, 7, 8, 10 }, teamSize = 3, dailyFights = 20, dailyRepeats = 10, turnSeconds = 10, bosses = { [5] = "Gus", [10] = "Mara", [15] = "Zed", [20] = "Gus l'Ancien", [25] = "Mara la Nuit", [30] = "Zed le Colosse", [35] = "Reine de Cristal", [40] = "Démon enchaîné", [45] = "Séraphin" } } -- lot 9 (D.7) : 45 étages, 5 par rareté de TOWER.tiers
-- PvP asynchrone : l'équipe de DÉFENSE enregistrée d'un autre joueur est simulée par le serveur (aucune latence réseau). Trophées, saisons d'une semaine,
-- récompense de fin de saison selon le palier de trophées atteint ; 10 combats classés par jour. Aucun achat ne touche à la force des pets.
Config.PVP = {
	seasonSeconds = 7 * 86400, dailyFights = 10, winBase = 25, winMin = 10, winMax = 40, loss = 15, start = 0,
	rewards = { { trophies = 100, coins = 5000, eggTier = 3 }, { trophies = 300, coins = 25000, eggTier = 4 }, { trophies = 600, coins = 100000, eggTier = 5, potion = true }, { trophies = 1000, coins = 400000, eggTier = 6, potion = true } },
}
-- Lot 13 (E.2) : duel local amical (même serveur, sable du colisée, aucun trophée). Règles dans ReplicatedStorage/Duel.lua.
Config.DUEL = { range = 30, requestTimeout = 20, sameTargetCooldown = 120, rewardedPerDay = 10, samePairRewardedPerDay = 3, turnSeconds = 10, afkTurnsToForfeit = 2, coinsWinMins = 1, coinsLoseMins = 0.25,
	-- intégration lot 13 : écart des duellistes sur le sable (±10 en X), rayon des spectateurs, délai de l'intro avant le 1er tour, tours minimum pour être payé après un départ / abandon
	sandOffset = 10, spectatorRange = 90, introSeconds = 3, earlyMinTurns = 3 }
-- Lot 13 (E.4) : ligues (trophées min, liste triée) et saison (remise partielle ; récompenses étendues, eggTier = indice de Config.TIERS).
Config.LEAGUES = {
	{ id = "bronze", name = "Bronze", icon = "🥉", min = 0, color = Color3.fromRGB(205, 127, 50) },
	{ id = "argent", name = "Argent", icon = "🥈", min = 300, color = Color3.fromRGB(200, 205, 215) },
	{ id = "or", name = "Or", icon = "🥇", min = 600, color = Color3.fromRGB(255, 205, 60) },
	{ id = "diamant", name = "Diamant", icon = "💎", min = 1000, color = Color3.fromRGB(110, 220, 255) },
	{ id = "champion", name = "Champion", icon = "👑", min = 1500, color = Color3.fromRGB(255, 90, 90) },
}
Config.LEAGUE_SEASON = {
	resetAbove = 300, resetFactor = 0.6,
	rewards = {
		{ trophies = 100, coins = 5000, eggTier = 3 }, { trophies = 300, coins = 25000, eggTier = 4 }, { trophies = 600, coins = 100000, eggTier = 5, potion = true },
		{ trophies = 1000, coins = 400000, eggTier = 6, potion = true }, { trophies = 1500, coins = 0, eggName = "Mythique", potionSeconds = 30 * 60, title = "Champion de la saison" },
	},
	-- Palier 1500 (décision de l'utilisateur, 2026-11-27) : 1 œuf Mythique (rareté retrouvée par son NOM dans Config.TIERS, aucun rang en dur) + potion de chance 30 min,
	-- sans pièces. L'œuf passe par Lot7.L16.storeEgg (place libre -> sac d'œufs -> coffre de débordement : jamais perdu, un seul crédit).
}
-- Indice de Config.TIERS d'après le nom d'une rareté (« Mythique » -> 6 aujourd'hui) ; nil si inconnu.
function Config.tierIndexByName(name)
	for i, t in ipairs(Config.TIERS) do
		if t.name == name then
			return i
		end
	end
	return nil
end
function Config.pvpSeason(now)
	return math.floor(now / Config.PVP.seasonSeconds)
end
-- Trophées gagnés : 25 de base, +1 par 10 trophées d'écart en faveur de l'adversaire, entre 10 et 40.
function Config.pvpGain(mine, theirs)
	return math.min(Config.PVP.winMax, math.max(Config.PVP.winMin, Config.PVP.winBase + math.floor((theirs - mine) / 10)))
end
function Config.pvpSeasonReward(trophies)
	local best
	for _, r in ipairs(Config.PVP.rewards) do
		if trophies >= r.trophies then
			best = r
		end
	end
	return best
end
-- LOT 14 (E.3) : classé EN DIRECT (file MemoryStore, serveur réservé « ranked »). Règles pures : ReplicatedStorage/Shared/Ranked ; transport : PvpLive.
-- `enabled` = interrupteur maître (false tant que le test réel à 2 comptes n'est pas fait) ; même activé, la file reste FERMÉE sous `minCCU` joueurs
-- simultanés dans l'expérience (le bouton propose alors directement le classé asynchrone). Durées en secondes.
Config.PVP_LIVE = {
	enabled = false, minCCU = 60, ccuPublish = 30, ccuTtl = 75,
	queueTtl = 90, refresh = 10, leaderTtl = 10, leaderEvery = 3, pollTicket = 2, ticketTtl = 30, matchTtl = 300, scan = 200,
	waitArena = 25, fallbackAfter = 45, turnSeconds = 10, teleportRetries = 2, teleportRetryDelay = 3,
	dailyFights = 15, dailyTrophyCap = 300, minTurnsForGain = 3, rematchCooldown = 3600, peerWindow = 600, recentMax = 20, peersMax = 20,
	trophyWindow = { base = 100, step = 50, every = 10, max = 400 },
	power = { lo = 0.75, hi = 1.33, wideAfter = 30, wideLo = 0.6, wideHi = 1.67 },
	queueName = "PvpQueue_v1", lockName = "PvpLock_v1", ticketName = "PvpTicket_v1", matchName = "PvpMatch_v1", ccuName = "PvpCcu_v1",
}
-- LOT 14 (E.4) : ligues par trophées : Config.LEAGUES (lot 13, plus haut) partagé par le direct et l'asynchrone (même champ `min`, `name`).

function Config.towerTier(floor) -- rareté des adversaires : 5 étages par rareté de TOWER.tiers (1-5 Commun ... 41-45 Divin)
	local T = Config.TOWER.tiers
	return T[math.min(#T, 1 + (math.max(1, floor) - 1) // 5)]
end
function Config.towerScale(floor) -- 0,85 au premier étage d'une rareté, 0,97 au dernier, boss x1,2
	local pos = (math.max(1, floor) - 1) % 5
	return (0.85 + 0.03 * pos) * (pos == 4 and 1.2 or 1)
end
function Config.towerFoeName(floor)
	return Config.TOWER.bosses[floor] and ("👑 " .. Config.TOWER.bosses[floor]) or ("Dresseur " .. floor)
end
-- Récompenses : première victoire d'un étage = pièces (proportionnelles au revenu), œuf d'un cran au-dessus de la rareté de l'étage aux boss, potion de chance tous les
-- 5 étages (3, 8, 13...). Victoires suivantes : petite récompense en pièces, limitée par jour. JAMAIS d'achat qui renforce un pet.
function Config.towerReward(floor, income, first)
	if not first then
		return { coins = math.floor(math.max(200, income * 60)) }
	end
	local boss = floor % 5 == 0
	return {
		coins = math.floor(math.max(floor * 600, income * floor * 45)),
		eggTier = boss and Config.liveEggTier(math.min(8, Config.nextLiveTier(Config.towerTier(floor)) or Config.towerTier(floor))) or 0, -- jamais Exclusif ni Divin
		potion = floor % 5 == 3,
	}
end

Config.PITY_ENABLED = false -- la pitié (amélioration garantie) est coupée : l'œuf annoncé fixe la rareté, avec UNE seule exception affichée (Config.UPGRADE)
Config.PITY_EVERY = 12 -- (si la pitié est activée) toutes les 12 éclosions sans amélioration, la suivante l'est garantie
-- Amélioration d'un cran de rareté (seule exception à « l'œuf annoncé = la rareté du pet ») : 5 % de base, +1 point par niveau de Trèfle, +10 avec le pass Chance,
-- +5 en événement chance, +25 avec la potion ; signalée « AMÉLIORÉ ! » à la révélation. Plafond : Rules.MAX_UP.
Config.UPGRADE = { base = 5, event = 5, pass = 10, maxEggTier = 6, maxUp = 70, needDiscovered = true } -- lot 9 : amélioration possible seulement depuis un œuf <= Mythique ; plafond 70 (= Rules.MAX_UP)

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
	local n = type(speciesCount) == "number" and speciesCount == speciesCount and math.max(speciesCount, 0) or 0
	local base = math.min(n, Config.COLLECTION_BASE_COUNT)
	local extra = math.max(n - Config.COLLECTION_BASE_COUNT, 0)
	local bonus = Config.COLLECTION_BONUS * (math.floor(base / Config.COLLECTION_STEP) + math.floor(extra / Config.COLLECTION_STEP2))
	return 1 + math.min(bonus, Config.COLLECTION_MAX)
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
		return "Courir " .. c.goal .. " secondes sur la piste d'entraînement"
	elseif c.type == "species" then
		return "Découvrir " .. c.goal .. " espèces différentes"
	elseif c.type == "tier" then
		return "Obtenir un pet " .. Config.TIERS[c.tier].name .. " ou mieux"
	elseif c.type == "mut" then
		return "Obtenir un pet muté"
	elseif c.type == "puzzle" then
		return "Aider la Mère Poule : 4 plumes, 4 runes, la berceuse"
	elseif c.type == "rebirth" then
		return "Renaître " .. c.goal .. " fois"
	end
	return c.type
end

-- Réglages d'interface (chaque ajout se coupe ici).
-- Effets 3D : qualité imposée (« high », « medium », « low ») ou nil = automatique (Bas sur tactile, Élevé sinon).
Config.VFX = { quality = nil }

-- Masquage des zones éloignées (client, sans StreamingEnabled) : masquées au-delà de cullAt studs du bord d'un domaine, réaffichées sous showAt.
Config.Culling = { enabled = true, cullAt = 170, showAt = 140, interval = 1, batch = 150, refresh = 20 }

-- Diagnostic des modèles Blender : petit « Blender N/M » en bas à gauche (hub et partie) et rapport complet par F3. À repasser à false après le test.
-- A9 : forceHatch = rareté (1 à 10) imposée à CHAQUE éclosion, pour voir les 10 animations et les espèces Secret / Exclusif / Divin dans Studio
-- (acceptation du lot 10, test 3 du lot 11). DÉSACTIVÉ par défaut (false) et SANS EFFET en production : le serveur ne le lit qu'avec
-- RunService:IsStudio() (Config.debugForceTier). Avec lui, toutes les fenêtres d'espèces d'événement sont ouvertes (A5) pour tester l'Exclusif.
Config.Debug = { AssetReport = true, forceHatch = false }
-- Rareté imposée par Debug.forceHatch, ou nil : seulement si isStudio == true et si la valeur est une rareté publiée (entier 1..TIER_COUNT).
function Config.debugForceTier(isStudio)
	local f = type(Config.Debug) == "table" and Config.Debug.forceHatch or nil
	if isStudio ~= true or type(f) ~= "number" or f ~= f or f % 1 ~= 0 or f < 1 or f > Config.TIER_COUNT or not Config.tierLive(f) then
		return nil
	end
	return f
end
-- Toutes les étiquettes d'espèces d'événement / de saison du bestiaire ({ [étiquette] = true }) : fenêtres ouvertes de Debug.forceHatch.
function Config.allEventTags()
	local out = {}
	for _, p in ipairs(Config.PETS) do
		if type(p.event) == "string" then
			out[p.event] = true
		end
	end
	return out
end

-- Mini-carte (coin droit) : activable par le bouton 🗺 ; `radius` studs du centre au bord, `size` pixels, `hz` mises à jour par seconde (faible : mobile).
Config.MINIMAP = { enabled = true, radius = 260, size = 112, sizeSmall = 84, hz = 4, guardRange = 90, maxDots = 24 }

Config.HUD = {
	debugStats = false, -- compteur FPS / ping / Parts affiché en haut (F3 l'affiche ou le masque en jeu)
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
Config.PUZZLE_EGG_TIER = 4 -- récompense : un œuf Épique (ou son prix en pièces si la base est pleine)
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

Config.dayRng = dayRng -- partagé avec ReplicatedStorage/Riddle (plumes et berceuse du jour : même générateur, autre sel)

-- Énigme d'un jour (day = os.time() // 86400). Retourne { answer = {symbole du Nord, de l'Est, du Sud, de l'Ouest}, text = énoncé,
-- clues = {indice du Nord, de l'Est, du Sud, de l'Ouest} } : `clues` est lu par les plumes dorées (Riddle.featherLine, lot 6).
function Config.riddleFor(day)
	local r = dayRng(day)
	local order = { 1, 2, 3, 4 }
	for i = 4, 2, -1 do
		local j = r(i)
		order[i], order[j] = order[j], order[i]
	end
	local parts, one = {}, {}
	for dir = 1, 4 do
		local clues = RUNE_CLUES[order[dir]]
		one[dir] = clues[r(#clues)]
		parts[dir] = DIR_PREFIX[dir] .. " : " .. one[dir] .. "."
	end
	return { answer = order, text = table.concat(parts, " "), clues = one }
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
	{ id = "rebirth", name = "Renaissant", emoji = "🌅", stat = "rb", unit = "renaissances", goals = { 1, 2, 4, 8 } },
	{ id = "tower", name = "Dresseur", emoji = "⚔️", stat = "tower", unit = "étages de la tour", goals = { 5, 10, 20, 30 } },
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
-- Probabilités de base par œuf : « Épique : 95 % Épique, 5 % Légendaire ».
function Config.eggOddsText()
	local out = {}
	for i, t in ipairs(Config.TIERS) do
		if Config.tierLive(i) then
			out[#out + 1] = Config.eggContentText(i, Config.UPGRADE.base)
		end
	end
	return table.concat(out, " · ") .. "."
end

-- A.3 : contenu affiché d'un œuf de rareté r avec `upPoints` points d'amélioration (ceux du joueur) : « Épique : 95 % Épique, 5 % Légendaire ».
-- Exactement ce que Rules.tierWeights appliquera (amélioration vers la rareté publiée suivante, seulement si r <= UPGRADE.maxEggTier).
function Config.eggUpShare(r, upPoints)
	if r > Config.UPGRADE.maxEggTier or not Config.nextLiveTier(r) then
		return 0
	end
	local p = type(upPoints) == "number" and upPoints == upPoints and upPoints or 0
	return math.min(math.max(p, 0), Config.UPGRADE.maxUp)
end
-- Lot 9 (décision de rythme) : le PREMIER pet d'une rareté s'obtient toujours avec un œuf de cette rareté. Tant que la rareté visée par
-- l'amélioration d'un cran n'est pas découverte (dex), la part « améliorée » est 0 (affichée telle quelle : eggContentText reçoit ces points).
-- Sans cette règle, la chance de 5 % rendait les premiers Rare / Épique / Légendaire / Mythique imprévisibles (de x0,2 à x3 du temps visé).
-- `topTier` nil = aucune restriction (appels historiques, tests).
function Config.effectiveUp(eggTier, upPoints, topTier)
	if Config.UPGRADE.needDiscovered and type(topTier) == "number" then
		local nxt = Config.nextLiveTier(Config.liveEggTier(eggTier))
		if nxt and nxt > topTier then
			return 0
		end
	end
	return upPoints
end
function Config.eggContentText(r, upPoints)
	local t = Config.TIERS[r]
	if not t then
		return ""
	end
	local up = Config.eggUpShare(r, upPoints)
	local nxt = Config.nextLiveTier(r)
	if up > 0 and nxt then
		return string.format("%s : %s%% %s, %s%% %s", t.name, tostring(100 - up), t.name, tostring(up), Config.TIERS[nxt].name)
	end
	return string.format("%s : 100%% %s", t.name, t.name)
end

-- « Commun 75 % · Rare 14 % ... » pour une table de tapis (« normal » ou « golden ») : poids EFFECTIFS (raretés non publiées reportées).
function Config.beltOddsText(kind)
	local w, out = Config.foldWeights(Config.BELT.weights[kind]), {}
	for i, t in ipairs(Config.TIERS) do
		if w[i] > 0 then
			out[#out + 1] = string.format("%s %s%%", t.name, tostring(math.floor(w[i] * 100 + 0.5) / 100))
		end
	end
	return table.concat(out, " · ") .. "."
end

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
	return "🎲 Probabilités de base. L'œuf annoncé fixe la rareté du pet. Seule exception : " .. Config.UPGRADE.base .. "% de chances d'une amélioration d'un cran, signalée « AMÉLIORÉ ! » (Trèfle, événements, Pass Chance et Potion augmentent cette part, plafonnée à 70%). Jamais de rareté inférieure. Par œuf : " .. Config.eggOddsText() .. " Rareté des œufs du tapis du marché (standard) : " .. Config.beltOddsText("normal") .. " Mutations : "
		.. pct(Config.MUTS, "Aucune") .. " (le Biome Alien multiplie la mutation Alien par 5). Tailles : " .. pct(Config.SIZES, "Normal") .. "."
end

---------------------------------------------------------------- REFONTE (lot 1) : tables de données de la nouvelle carte, du tapis, des territoires, de l'énigme
-- Source : obsidian-studio/Jeux/REFONTE_CHIPE_OEUFS.md. Nord = -Z, Est = +X, marche de référence 16 studs/s. Ces tables sont des DONNÉES : les lots suivants les branchent.

-- A. Nouvelle carte 700 x 500 (remplace Config.Map au lot 2 ; Config.Map reste lu par les tests existants jusque-là).
Config.Map2 = {
	bounds = { x0 = -350, x1 = 350, z0 = -250, z1 = 250 }, backdrop = { w = 900, d = 700 }, pathHalf = 5, dirtHalf = 3,
	plaza = { x = 0, z = 0, r = 60 }, hall = { x = -40, z = 0, r = 18, h = 30 }, fountain = { x = 10, z = -38, r = 7 },
	belt = { x0 = -22, x1 = 38, z = 0, width = 8, height = 2, bin = { x = 42, z = 0 } },
	stalls = { { x = -35, z = 38 }, { x = 5, z = 42 }, { x = 40, z = 36 } },
	kiosk = { x = 14, z = 22, r = 12 }, -- lot 8B : kiosque central (Kiosk.lua, KioskData.CENTER) ; r = rayon d'exclusion du décor (socle 7,7 + circulation), ambiance kiosk_ambience à 30 studs
	track = { x = -60, z = -45, w = 16, d = 40 }, -- ancien Treadmill : « Piste d'entraînement » (clé `train` inchangée)
	portalHub = { x0 = 0, x1 = 40, z = -50, count = 4, gap = 13 },
	bigEgg = { x = 70, z = -20, r = 22, h = 16 }, hen = { x = 52, z = -28 },
	runeStones = { { x = 70, z = -34, dir = "N" }, { x = 84, z = -20, dir = "E" }, { x = 70, z = -6, dir = "S" }, { x = 56, z = -20, dir = "O" } },
	bases = { { x = 0, z = -140 }, { x = -205, z = -45 }, { x = 200, z = -45 }, { x = -30, z = 165 }, { x = 175, z = 135 } },
	wildPen = { x = 75, z = -105, w = 18, d = 14, nests = 3 },
	castle = { keep = { x = 300, z = -205 }, court = { x = 265, z = -170 }, h = 10, x0 = 215, x1 = 345, z0 = -250, z1 = -135, door = { x = 300, z = -185 } },
	arena = { x = -265, z = 165, r = 42, sand = 28, entry = { x = -235, z = 135 } },
	lakes = { { name = "LakeMill", x = -285, z = -105, r = 38, shore = 5 }, { name = "LakeWillow", x = 280, z = 200, r = 32, shore = 5 } },
	rivers = {
		{ name = "RiverNorth", width = 22, pts = { { -350, -205 }, { -200, -212 }, { -60, -208 }, { 60, -198 }, { 150, -160 }, { 215, -118 }, { 285, -105 }, { 350, -110 } } },
		{ name = "BrookMill", width = 8, pts = { { -285, -143 }, { -288, -197 } } },
		{ name = "BrookWillow", width = 6, ford = true, fordSpeed = 0.7, pts = { { 248, 205 }, { 150, 232 }, { 20, 238 }, { -120, 236 } } },
	},
	waterfall = { x = 330, z = -138, h = 10 },
	bridges = { { name = "Castle", x = 215, z = -118, axis = "NS", w = 12, len = 30, stone = true }, { name = "North", x = -20, z = -203, axis = "NS", w = 6, len = 28 }, { name = "Mill", x = -286, z = -170, axis = "EW", w = 6, len = 14 } },
	forests = { { x0 = -350, x1 = -310, z0 = -40, z1 = 120, max = 40 }, { x0 = -350, x1 = 340, z0 = -250, z1 = -222, max = 50 }, { x0 = 312, x1 = 350, z0 = -60, z1 = 150, max = 25 }, { x0 = -200, x1 = 230, z0 = 228, z1 = 250, max = 40 } },
	groves = { { x = -160, z = -150 }, { x = 140, z = -20 }, { x = -200, z = 120 }, { x = 60, z = 190 } }, groveRadius = 12, groveTrees = 6,
	hills = { { x = -300, z = -232, h = 18, r = 40 }, { x = 120, z = -238, h = 14, r = 35 }, { x = -330, z = 235, h = 12, r = 30 }, { x = 330, z = 240, h = 10, r = 30 } },
	baseSizeMax = 72, -- emprise maximale d'une base (niveau 8)
	-- REFONTE (lot 2) : données de construction ajoutées (chemins, arrivée sur la place, pontons, cabane, murs, budgets du décor procédural)
	basePlatform = 52, spawnForward = 20, -- plateforme actuelle d'une base (52 x 52) ; le spawn est 20 studs devant son centre, côté place
	plazaArrival = { x = 28, z = -34 }, -- arrivée des tapis de retour (près de la rose des portails, hors fontaine et chemins)
	bridgeHalfGap = 3, -- demi-largeur minimale du passage laissé dans le mur invisible de la rivière du Nord à un pont (sinon demi-largeur du pont)
	wallHeight = 40, -- murs invisibles (bornes et rivière du Nord) : plus hauts que les collines (on ne les enjambe jamais)
	docks = { { lake = 1, x = -262, z = -90, len = 14, w = 4 }, { lake = 2, x = 255, z = 185, len = 14, w = 4 } }, -- pontons (avancent vers le centre du lac)
	cabin = { x = -300, z = -58, w = 10, d = 8 }, -- cabane du pêcheur (lac du Moulin)
	procTrees = 40, -- arbres procéduraux des forêts (2 Parts chacun ; les bosquets en ajoutent groveTrees chacun) : le reste vient des modèles Blender
	paths = { -- routes pavées (paved, demi-largeur pathHalf) et chemins de terre (dirt, dirtHalf) ; polylignes (x, z) depuis le centre de la place
		{ name = "B1", kind = "paved", pts = { { 0, 0 }, { 0, -140 } } },
		{ name = "B2", kind = "paved", pts = { { 0, 0 }, { -205, -45 } } },
		{ name = "B3", kind = "paved", pts = { { 0, 0 }, { 60, 15 }, { 150, 5 }, { 200, -45 } } }, -- coudes : contourne la place du Grand Œuf et le bosquet est
		{ name = "B4", kind = "paved", pts = { { 0, 0 }, { -30, 165 } } },
		{ name = "B5", kind = "paved", pts = { { 0, 0 }, { 110, 25 }, { 175, 135 } } }, -- coude : contourne le territoire de Mara par le nord
		{ name = "Castle", kind = "paved", pts = { { 40, -40 }, { 140, -75 }, { 215, -103 } } }, -- jusqu'au pied du Pont du Château
		{ name = "Court", kind = "paved", y = 10, pts = { { 215, -137 }, { 232, -137 } } }, -- sur le plateau : du pont vers la herse de la cour (240, -138), hors du territoire
		{ name = "Arena", kind = "paved", pts = { { -20, 110 }, { -150, 145 }, { -235, 135 } } }, -- embranchement en J vers l'arène
		{ name = "MillLake", kind = "dirt", pts = { { -205, -45 }, { -255, -70 } } },
		{ name = "B1B2", kind = "dirt", pts = { { 0, -140 }, { -100, -135 }, { -205, -45 } } }, -- voisins : contourne Gus Nord-Ouest par le nord
		{ name = "B1B3", kind = "dirt", pts = { { 0, -140 }, { 75, -130 }, { 200, -45 } } }, -- voisins : contourne l'enclos sauvage
		{ name = "B3B5", kind = "dirt", pts = { { 200, -45 }, { 175, 135 } } },
		{ name = "B5B4", kind = "dirt", pts = { { 175, 135 }, { -30, 165 } } },
	},
	neighbors = { { 1, 2, "B1B2" }, { 1, 3, "B1B3" }, { 3, 5, "B3B5" }, { 5, 4, "B5B4" } }, -- bases voisines et chemin qui les relie (B2 et B4 : par la place)
}

-- Territoires d'obtention d'œufs (B.4) : poids de rareté à l'apparition (Commun..Cosmique), temps de vol, réapparition (s), pièges.
-- Lot 8A : `nestAlarm` (Mara et Zed ; Gus reste clément, l'enclos sauvage n'a pas de gardien) : chiper un œuf réveille le gardien le plus proche du
-- voleur, qui le CHARGE `delay` s plus tard ; si CE gardien le frappe pendant qu'il porte un œuf du territoire, l'œuf retourne à son nid (B.4 « prise
-- par un gardien »). La vitesse de fuite décide : simulation tests/SimSteal.lua, Zed 23 % sans amélioration, 97 % à vitesse 30 ; Mara 59 à 64 % (vitesses 0 à 30) ; Gus 88 à 100 %.
Config.TERR = {
	wild = { x = 75, z = -105, r = 12, rival = 0, guards = 0, hold = 0.8, respawn = { 12, 12 }, weights = { 100, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, nests = { { 70, -105 }, { 75, -105 }, { 80, -105 } } },
	gusNW = { x = -95, z = -80, r = 40, rival = 1, guards = 1, hold = 1.3, respawn = { 9, 16 }, weights = { 45, 35, 17, 3, 0, 0, 0, 0, 0, 0 }, nests = { { -75, -100 }, { -120, -95 }, { -95, -55 } }, posts = { { -95, -80 } } },
	gusSW = { x = -120, z = 75, r = 40, rival = 1, guards = 1, hold = 1.3, respawn = { 9, 16 }, weights = { 45, 35, 17, 3, 0, 0, 0, 0, 0, 0 }, nests = { { -145, 55 }, { -115, 105 }, { -90, 60 } }, posts = { { -120, 75 } } },
	mara = { x = 85, z = 80, r = 42, rival = 2, guards = 2, hold = 2.2, respawn = { 12, 21 }, weights = { 0, 10, 35, 37, 18, 0, 0, 0, 0, 0 }, nests = { { 65, 70 }, { 105, 65 }, { 90, 110 } }, posts = { { 72, 82 }, { 100, 82 } },
		traps = { bells = 3, mud = 2 }, speed = { chase = 19, patrol = 10 }, view = { 28, 110, 14 }, hit = 25,
		nestAlarm = { delay = 0.9 } }, -- lot 8A : coup du loup 20 -> 25 pv (Mara 61 à 64 % aux vitesses 0 à 30 au lieu de 66 à 70 %)
	zed = { x = 265, z = -170, r = 38, rival = 3, guards = 3, hold = 3.5, respawn = { 18, 32 }, weights = { 0, 0, 0, 30, 45, 22, 2.4, 0.5, 0, 0.1 }, nests = { { 240, -160 }, { 265, -185 }, { 290, -160 } }, posts = { { 240, -165 }, { 265, -180 }, { 290, -165 } },
		traps = { gate = { x = 240, z = -138, open = 3, closed = 3 }, plates = 4, searchlights = 2, searchlightRev = 0.5 }, speed = { chase = 26, patrol = 13 }, view = { 32, 120, 16 }, hit = 28, freshness = 75,
		nestAlarm = { delay = 1.2 } },
}
Config.TERR_ORDER = { "wild", "gusNW", "gusSW", "mara", "zed" }
Config.VIGILANCE = { perSteal = 0.15, max = 0.45, window = 60, decay = 30 } -- +15 % vue et ouïe par vol réussi dans les 60 s, plafond +45 %, retour à la normale 30 s après le dernier vol

-- B.3 Tapis roulant central.
Config.BELT = {
	speed = 3, length = 60, maxEggs = 12, interval = 5, priceRatio = 0.6, buyCooldown = 3, legendaryDelay = 2, legendaryPerMinute = 1,
	weights = { normal = { 50.037, 25, 14, 7, 2.9, 0.85, 0.20875, 0.004, 0, 0.00025 }, golden = { 29.3205, 14.55, 31.5, 15.75, 6.5, 1.9, 0.469925, 0.009, 0, 0.000575 } }, -- lot 9 : doré = x2 à x2,5 du standard sur les raretés >= Rare (mesuré : +15 à +35 % de progression)
	golden = { interval = 4, seconds = 600, maxSeconds = 2592000 }, welcome = { delay = 20, maxHatched = 5 }, -- lot 9 : doré 3 s -> 4 s (trop fort : -34 % de temps au premier Mythique)
	private = { interval = 180, pending = 3, width = 10, depth = 3, z = -13 }, -- tapis privé : au centre-avant de la base (les 20 emplacements occupent le milieu), z local de son centre
}
-- Portage : vitesse selon la rareté de l'œuf porté (produit pour plusieurs œufs, plancher 0,70).
Config.CARRY = { weight = { 1, 1, 1, 0.95, 0.9, 0.85, 0.8, 0.78, 0.78, 0.75 }, floor = 0.7, beamTier = 5, beamRange = 120 }
Config.NEWBIE = { minutes = 15, untilLevel = 3 }
-- Réglages de gardien d'un territoire : le rival (Config.RIVALS) complété par les valeurs propres du territoire (Config.TERR.speed / view / hit), source
-- unique de Main (vitesses, vue, ouïe, coup). Gus (aucune valeur propre) garde celles de son rival : clément, inchangé.
function Config.guardStats(terr)
	local t = Config.TERR[terr]
	local r = Config.RIVALS[t.rival]
	local out = {}
	for k, v in pairs(r) do
		out[k] = v
	end
	if t.speed then
		out.guardSpeed, out.patrolSpeed = t.speed.chase, t.speed.patrol
	end
	if t.view then
		out.viewDist, out.viewAngle, out.hearRadius = t.view[1], t.view[2], t.view[3]
	end
	if t.hit then
		out.damage = t.hit
	end
	return out
end
-- Vitesse de portage : produit des poids Config.CARRY.weight des raretés portées, plancher Config.CARRY.floor (0,70). `tiers` = liste d'indices de rareté.
function Config.carryMul(tiers)
	local m = 1
	for _, t in ipairs(tiers) do
		m = m * (Config.CARRY.weight[t] or 1)
	end
	return math.max(Config.CARRY.floor, m)
end
-- Pièges (lot 4) : constantes communes (le serveur applique, Traps décide).
Config.TRAPS = {
	mudMul = 0.6, mudSeconds = 2, mudRadius = 4, -- flaque : vitesse x0,6 pendant 2 s
	bellCooldown = 4, bellHalfWidth = 5, -- fil à clochettes : demi-longueur du fil, délai avant de pouvoir donner l'alerte de nouveau
	plateRadius = 2.5, plateCooldown = 4, -- dalle d'alarme
	lightRange = 30, lightCone = 36, lightCooldown = 3, -- lanterne tournante : portée, ouverture totale du cône (degrés)
	gateWindow = 0.6, -- durée de la montée ou de la descente de la herse (s) : la herse n'est solide qu'à la fin de la descente
}
-- Porte de base (B.4) : durée = BASE_LEVELS2[niveau].lock (15 s si le niveau n'en a pas), recharge 60 s.
Config.DOOR = { defaultSeconds = 15, cooldown = 60 }
function Config.lockSeconds(level)
	local lv = Config.BASE_LEVELS2[level]
	local sec = lv and lv.lock or 0
	return sec > 0 and sec or Config.DOOR.defaultSeconds
end
-- Protection débutant : actif tant que le temps de jeu cumulé (s) est sous Config.NEWBIE.minutes ET que la maison est sous le niveau untilLevel,
-- sauf fin anticipée (`off`).
function Config.isNewbie(playedSeconds, baseLevel, off)
	if off then
		return false
	end
	return (playedSeconds or 0) < Config.NEWBIE.minutes * 60 and (baseLevel or 1) < Config.NEWBIE.untilLevel
end
-- A.4 Voyage rapide (remplace Config.TRAVEL au lot 2).
Config.TRAVEL2 = {
	cooldown = 4, combatLock = 4, maxDistance = 10, blockWhileCarrying = true,
	portals = { { name = "Arène", to = { -225, 135 }, back = { -215, 128 }, chapter = 0 }, { name = "Pont du Château", to = { 205, -95 }, back = { 195, -90 }, chapter = 6 },
		{ name = "Lac du Moulin", to = { -245, -75 }, back = { -238, -68 }, chapter = 0 }, { name = "Lac des Saules", to = { 240, 175 }, back = { 232, 170 }, chapter = 0 } },
}
-- E.3 Vol à distance « Corbeau chipeur ».
Config.REMOTE_STEAL = { tokenMax = 5, dailyMax = 3, maxTier = 5, flightSeconds = 8, victimCooldown = 1200, postStealShield = 300, compensationRatio = 0.5, levelGap = 1, minEggSecondsLeft = 10, minPlayMinutes = 30, victimMinMinutes = 15, launchCooldown = 10,
	minAccountAgeDays = 3, reStealSeconds = 1200, compensationCapTier = 3, victimFailCooldown = 180, logQueueMax = 60, logBatch = 20, logTries = 3,
	tryGap = 1, logMax = 10, logDays = 30, packs = { RemoteSteal = 1, RemoteStealPack = 3 } } -- lot 7b : minAccountAgeDays = ancienneté de compte exigée du voleur ET de la victime ; reStealSeconds = un œuf volé par corbeau ne se revole pas avant 20 min ; compensationCapTier = indemnité reçue par jour UTC plafonnée au prix d'un œuf de cette rareté (Rare) ; victimFailCooldown = répit de la victime après un vol raté ou chassé (le délai de 20 min n'est posé qu'en cas de succès) ; logQueueMax / logBatch / logTries = file RavenLog bornée, écrite par lots, essais bornés. Lot 7 : tryGap = 1 demande de menu / s ; journal « Qui m'a volé ? » (10 entrées) ; RavenLog gardé 30 jours ; jetons par produit
-- Pluie de chance pour tout le serveur (produit ServerLuck) : +bonus points de chance fixes pendant `seconds`, durées cumulables (lot 16 : sans plafond d'achat),
-- au nom de l'acheteur. Plafond global Rules.MAX_UP (70 points).
Config.SERVER_LUCK = { bonus = 5, seconds = 600, maxSeconds = 2592000 } -- lot 16 : durées cumulables sans limite (maxSeconds = garde technique de 30 jours)
-- Une offre payante est-elle proposée à ce joueur ? Il faut un ID renseigné (0 = offre invisible) ET, pour les offres à hasard (`random = true`),
-- que PolicyService ait confirmé `ArePaidRandomItemsRestricted == false` (restricted nil ou true : masquée, repli prudent).
function Config.offerVisible(def, restricted)
	if type(def) ~= "table" or not Config.purchasable(def) then
		return false
	end
	if type(def.eggTier) == "number" and not Config.tierLive(def.eggTier) then -- lot 9 : jamais vendu tant que la rareté n'a aucune espèce
		return false
	end
	return not (def.random == true and restricted ~= false)
end
Config.INTERCEPT = { enabled = false } -- interception d'un porteur : coupée par défaut (à tester en playtest)

-- D. Maison évolutive : poids par rareté (migration au lot 5) et table des 8 niveaux. `model` = clé de Config.Assets.models.house ; `slots` = emplacements bonus ;
-- `income` = bonus de revenu ; `lock` = durée de la porte de base (s) ; `needTier` = rareté qu'il faut avoir découverte.
Config.BASE_WEIGHTS2 = { 1, 2, 4, 15, 50, 180, 700, 2500, 2500, 9000 } -- lot 9 : anciennes valeurs inchangées pour les raretés migrées
Config.BASE_LEVELS2 = {
	{ score = 0, name = "Enclos de bois", emoji = "🪵", model = "level1", size = 52, slots = 0, income = 0, lock = 0 },
	{ score = 18, name = "Chalet du Couvoir", emoji = "🛖", model = "l2", size = 56, slots = 1, income = 0.05, lock = 20 },
	{ score = 337, name = "Maison-Tour", emoji = "🏡", model = "l3", size = 58, slots = 1, income = 0.10, lock = 25, alarm = true },
	{ score = 1092, name = "Maison à l'auvent", emoji = "🏠", model = "l4", size = 60, slots = 2, income = 0.15, lock = 30 },
	{ score = 1866, name = "Maison au garage", emoji = "🏘️", model = "l5", size = 64, slots = 2, income = 0.20, lock = 35, guardDog = true },
	{ score = 4695, name = "Villa moderne", emoji = "🏢", model = "l6", size = 66, slots = 3, income = 0.30, lock = 40 },
	{ score = 17754, name = "Grande villa", emoji = "🏰", model = "l7", size = 68, slots = 3, income = 0.40, lock = 50, needTier = 5 },
	{ score = 64000, name = "Château doré", emoji = "👑", model = "l8", size = 72, slots = 4, income = 0.50, lock = 60, needTier = 6, shieldBonus = 10 },
}
-- Montée de niveau de la maison (D.4) : durée totale 4,5 s, phases ① échafaudage 0,8 s ② poussière + onde 0,4 s ③ échange ancienne/nouvelle maison 1,5 s ④ fête 1,8 s.
-- `hide` = profondeur (studs) où la nouvelle maison attend sous le sol ; `announceFrom` = niveau à partir duquel tout le serveur est prévenu.
Config.UPGRADE_FX = { seconds = 4.5, scaffold = 0.8, dust = 0.4, swap = 1.5, party = 1.8, hide = 40, announceFrom = 6, confetti = 36 }
-- Texte de la bannière de montée de niveau : « 🏠 Niveau 5 : Maison au garage ! +2 emplacements, revenus +20 % » .
function Config.upgradeBanner(level)
	local lv = Config.BASE_LEVELS[level]
	if not lv then
		return ""
	end
	local gain = Config.levelSlots(level) -- bonus d'emplacements de la maison de ce niveau (comme la table D.2 : « +2 emplacements » au niveau 5)
	local parts = {}
	if gain > 0 then
		parts[#parts + 1] = "+" .. gain .. (gain > 1 and " emplacements" or " emplacement")
	end
	parts[#parts + 1] = "revenus +" .. math.floor((lv.income or 0) * 100 + 0.5) .. " %"
	return "🏠 Niveau " .. level .. " : " .. lv.name .. " ! " .. table.concat(parts, ", ")
end
-- Alarme d'intrusion (niveau 3), chien de garde (niveau 5, intrus ralenti x0,7 pendant 3 s à l'entrée), bouclier d'œuf du niveau 8 (+10 s).
Config.INTRUDER = { alarmCooldown = 12, dogMul = 0.7, dogSeconds = 3, dogCooldown = 20, margin = 1 }
-- Texte du cadenas d'un emplacement non débloqué : le prochain affiche son coût (amélioration en pièces, niveau de maison ou pass).
function Config.slotHint(idx, capacity, upSlots, level, hasPassExtra)
	if idx ~= capacity + 1 then
		return "🔒"
	end
	local u = Config.upgrade("slots")
	if upSlots < u.max then
		return "🔒 " .. Config.fmt(u.cost(upSlots)) .. " 🪙"
	end
	for l = level + 1, #Config.BASE_LEVELS do
		if Config.BASE_LEVELS[l].slots > Config.levelSlots(level) then
			return "🔒 Maison niv. " .. l
		end
	end
	if not hasPassExtra then
		return "🔒 Pass +4"
	end
	return "🔒"
end
Config.SLOTS_MAX = 20 -- 4 + 8 (Doigts agiles... améliorations) + 4 (maison) + 4 (pass)
Config.BASE_WEIGHTS = Config.BASE_WEIGHTS2 -- lot 5 : mêmes tables, lues par baseGain / baseLevel (le plateau des niveaux et ses conditions de rareté)
Config.BASE_LEVELS = Config.BASE_LEVELS2
Config.PASS_EXTRA_SLOTS = 4 -- pass ExtraSlots

-- C. Énigme de la Mère Poule : dialogues exacts et 12 emplacements de plumes (3 par direction ; les 4 du jour = Config.featherSpots(day) au lot 6).
Config.HEN_LINES = {
	first = {
		"Cot ! Enfin un Chipeur au cœur honnête… Approche, petit.",
		"Ce grand œuf de pierre, c'est le cœur de la Couvée. Chaque nuit, il s'endort, et seule ma berceuse peut le réveiller.",
		"Mais le vent a dispersé mes quatre plumes dorées : une au Nord, une à l'Est, une au Sud, une à l'Ouest.",
		"Rapporte-les-moi, règle les runes comme elles te le disent, puis chante avec moi. Le Grand Œuf saura te remercier.",
	},
	buttons = { go = "J'y vais !", again = "Explique encore", later = "Plus tard", hint = "💡 Un coup de bec", replay = "🔁 Réécouter" },
	explain = "Trois étapes. ① Trouve les 4 plumes dorées : la flèche jaune t'y mène. ② Chaque plume parle de la rune de sa direction : tourne cette rune sur le bon symbole, puis touche le Grand Œuf. ③ Les runes s'allument dans un ordre : touche-les dans le même ordre.",
	again = "Le Grand Œuf dort encore. Mes plumes se sont envolées de nouveau… Tu m'aides ?",
	missing = "Il te manque {n} plume(s). Cherche du côté {dirs}.",
	feather = "🪶 Plume {dir} : « {clue} »",
	allFeathers = "Les quatre plumes ! Chacune parle de sa rune. Tourne-les autour du Grand Œuf, puis touche-le.",
	runesWrong = "Hmm… {k} rune(s) sur 4 chantent juste. Relis tes plumes.",
	runesRight = "Les runes vibrent ! Écoute bien la berceuse… et répète-la.",
	lullabyWrong = "Cot-cot, pas tout à fait ! Je te la rechante.",
	success = "Le Grand Œuf s'éveille ! Tiens, ce petit trésor est pour toi. Reviens demain : il se rendort à minuit.",
	done = "Tu as déjà chanté aujourd'hui. Nouvelle berceuse dans {h} h {mm}.",
	locked = "Reviens quand tu auras chipé ton premier œuf, petit. Mes plumes ne se montrent qu'aux vrais Chipeurs.",
	hintFeather = "Un coup de bec ? La plume {dir} se cache {where}.",
	hintRune = "La rune {dir} veut {symbol}.",
	runeWaits = "La rune {dir} attend sa plume.",
	-- lot 6 : indices et refus (le serveur n'envoie que l'identifiant et les paramètres)
	hintLullaby = "Un coup de bec ? La berceuse commence par la pierre {dir}.",
	hintWait = "Cot… laisse-moi réfléchir encore {mm} min {ss} s avant de te souffler quelque chose.",
	hintFails = "Essaie encore : après {n} tentative(s) de plus, je t'aiderai.",
	hintMax = "Je t'ai déjà soufflé mes deux indices du jour, petit.",
	needFeathers = "Il te manque des plumes avant de poser la combinaison. Cherche du côté {dirs}.",
	runesLocked = "Les runes se reposent… patiente quelques secondes.",
	listen = "Écoute… la berceuse commence.",
}
-- REFONTE (lot 2) : trois plumes déplacées pour rester atteignables (E2 était entre la rivière et la falaise, S1 hors du ponton, O1 dans la cabane).
Config.FEATHER_SPOTS = {
	N = { { x = -20, z = -228, where = "au-delà du pont de bois" }, { x = -280, z = -225, where = "sur la colline des vents" }, { x = 120, z = -232, where = "sous les sapins de la colline" } },
	E = { { x = 215, z = -100, where = "au pied du pont de pierre" }, { x = 325, z = -90, where = "face à l'eau qui tombe" }, { x = 330, z = 40, where = "à l'orée du bois de l'Est" } },
	S = { { x = 262, z = 189, where = "sur le ponton des saules", dock = true }, { x = 60, z = 195, where = "entre les arbres du sud" }, { x = -60, z = 215, where = "près du ruisseau du Sud" } },
	O = { { x = -300, z = -47, where = "devant la cabane du lac" }, { x = -265, z = 120, where = "sur les gradins de l'arène" }, { x = -330, z = 40, where = "au fond du bois de l'Ouest" } },
}
Config.HEN = {
	fragmentsForEgg = 7, hintsPerDay = 2, hintAfterSeconds = 300, lullabyLength = 5, lullabyNote = 0.8, lullabyGap = 0.3, tapMinGap = 0.25, collectiveSolves = 3, collectiveSeconds = 300,
	-- lot 6 : distances (studs) et cadences. pickupDistance : le serveur refuse une plume plus loin (11 studs = refusé) ; pickupGap : 1 ramassage / s.
	talkDistance = 14, pickupDistance = 10, pickupGap = 1, singDistance = 16, failsForHint = 3, sparkleDistance = 40, quarterReach = 70, markerRange = 90, bubbleCps = 40, alertRange = 150,
}
-- Textes du HUD (onboarding et chapitres) : tous < 110 octets.
Config.ONBOARD2 = {
	"🥚 Touche ton œuf pour le faire éclore",
	"🛤️ Prends l'œuf de bienvenue sur le tapis",
	"🏠 Pose-le dans ta base",
	"🧺 Chipe un œuf dans l'enclos sauvage",
}
Config.CHAPTER_TEXTS = {
	[8] = { title = "La berceuse du Grand Œuf", text = "Aide la Mère Poule : trouve les 4 plumes, règle les runes, chante la berceuse." },
}
-- Lot 6 : le chapitre 8 devient « La berceuse du Grand Œuf » (son objectif suit la nouvelle énigme, type « puzzle » inchangé : une résolution du jour).
for i, t in pairs(Config.CHAPTER_TEXTS) do
	local c = Config.STORY[i]
	if c then
		c.title, c.text = t.title, t.text
	end
end
-- Titre « Ami de la Mère Poule » : 7 fragments du Grand Œuf cumulés (puzzle.fragments). Config.titles (24 titres de succès) reste INCHANGÉE pour ne pas
-- casser ses tests ; Config.allTitles lui ajoute ce titre (25e), c'est elle que lit l'onglet Titres.
Config.TITLE_HEN = { id = "hen", name = "🐔 Ami de la Mère Poule", desc = "7 fragments du Grand Œuf" }
function Config.allTitles(stats)
	local out = Config.titles(stats)
	local frags = stats and stats.fragments
	out[#out + 1] = { id = Config.TITLE_HEN.id, name = Config.TITLE_HEN.name, desc = Config.TITLE_HEN.desc, unlocked = type(frags) == "number" and frags >= Config.HEN.fragmentsForEgg }
	return out
end

-- LOT 9b : calendrier des œufs sur 30 jours. Le SERVEUR décide du jour (UTC) ; le client ne désigne que la carte qu'il veut réclamer. Un jour = une carte.
--   dayCap = réclamations au plus par jour UTC (le jour en cours + 1 rattrapage) ; monthCap = récompenses au plus par cycle de 30 jours (rattrapages compris).
--   Jour de grâce : 1 jour manqué pardonné (gratuit) toutes les `graceEvery` jours (gagné dès le jour 1, puis aux jours 8, 15, 22, 29). Rattrapage : jour de grâce,
--   `catchupQuests` missions réclamées (compteur cal.qc), ou 1 jeton payant (CalendarCatchup, 29 R$). Éligibilité : compte Roblox de `minAccountAgeDays` jour(s) et
--   `minPlayMinutes` min de jeu cumulées (le cycle démarre alors). Récompense d'une carte : c = minutes de revenu en pièces (au moins coinFloor), egg = rareté de l'œuf
--   (placé dans la base : réclamation refusée si elle est pleine), scrolls (parchemins), plumes, tokens (jetons de combat), cosm (cosmétique), title (titre), draw = tirage J30.
Config.CALENDAR = {
	days = 30, dayCap = 2, monthCap = 30, graceEvery = 7, minAccountAgeDays = 1, minPlayMinutes = 10, catchupQuests = 3, catchupMax = 5, coinFloor = 500,
	legendaryDay = 3, milestones = { 3, 7, 10, 14, 17, 20, 25, 28, 30 },
	caps = { scrolls = 9999, plumes = 9999, tokens = 99 },
	-- Tirage du jour 30 (affiché sur la carte, vérifié sur 1 000 000 tirages à +-0,3 point) : œuf de rareté fixe. Demande utilisateur : 40 % Mythique, 45 % Ultra Rare,
	-- 15 % Secret. Repli : une rareté sans espèce publiée (Secret avant le lot 11) donne un œuf `drawFallback` (Ultra Rare), jamais un œuf vide ; la carte affiche alors
	-- les probabilités réelles (40 % Mythique / 60 % Ultra Rare).
	draw = { { tier = 6, pct = 40 }, { tier = 7, pct = 45 }, { tier = 8, pct = 15 } },
	drawFallback = 7,
	cosmetics = { ribbon = { name = "Ruban doré", emoji = "🎀" }, cape = { name = "Cape du Couvoir", emoji = "🧣" }, aura = { name = "Aura de braise", emoji = "🔥" }, crown = { name = "Couronne de plumes", emoji = "👑" } },
	titles = { cal10 = { name = "📅 Habitué du Couvoir", desc = "Jour 10 du calendrier" }, cal25 = { name = "📅 Fidèle du Couvoir", desc = "Jour 25 du calendrier" }, cal30 = { name = "📅 Maître du Calendrier", desc = "Les 30 jours du calendrier" } },
	rewards = {
		{ egg = 1, scrolls = 1 }, { c = 8, tokens = 1 }, { egg = 5, plumes = 1 }, { c = 10, scrolls = 1 }, { scrolls = 2, plumes = 1 }, { c = 12, tokens = 1 }, { egg = 3, cosm = "ribbon" },
		{ c = 12 }, { scrolls = 2, tokens = 1 }, { c = 25, plumes = 2, title = "cal10" }, { c = 15 }, { scrolls = 2 }, { tokens = 2, c = 15 }, { egg = 4, cosm = "cape" },
		{ c = 20, plumes = 1 }, { scrolls = 3 }, { egg = 4, tokens = 2, plumes = 2 }, { c = 25 }, { scrolls = 3, tokens = 1 }, { egg = 6, cosm = "aura" },
		{ c = 30 }, { plumes = 2, scrolls = 2 }, { c = 35, tokens = 2 }, { scrolls = 3 }, { egg = 5, title = "cal25", plumes = 3 }, { c = 40 }, { tokens = 3, scrolls = 3 },
		{ cosm = "crown", plumes = 3, c = 60 }, { c = 60, scrolls = 4 }, { draw = true, title = "cal30", c = 120, plumes = 5 },
	},
}

-- LOT 10 : compteur « 1 sur N » (module Odds). REF = poids de référence par rareté (en %), alignés sur la table STANDARD du tapis (Config.BELT.weights.normal) pour
-- r1..r8 et r10 (décision : la valeur du brief r8 = 0,04, r10 = 0,01 sous-estimait la rareté réelle du lot 9 d'un facteur 2 à 5) ; r9 Exclusif ne sort jamais du tapis
-- (poids 0, achat seulement) : référence 0,006 (plus rare que Secret 0,008, moins que Divin 0,005), car le compteur exige un poids > 0. N figé dans le slot à l'éclosion
-- (slot.o, slot.ov = version) : changer REF plus tard ne réécrit jamais un ancien chiffre ; un slot sans `o` (pet éclos avant le lot 10) affiche « — ».
Config.ODDS = { version = 1, billboardMin = 1000, REF = { 50.037, 25, 14, 7, 2.9, 0.85, 0.20875, 0.004, 0.001, 0.00025 } }
-- LOT 10 : effets d'éclosion (HatchPlan + HatchFx) et de combat (IntroPlan + BattleIntro, TypeFx). replaceCine : la cinématique 3D d'éclosion (CinematicKit.hatchPlan)
-- n'est plus jouée (HatchFx gère lui-même le zoom). Mobile : reduced (particules / 2), plafonds 220 / 120 / 80 instances (dans les modules), 30 FPS visés.
Config.HATCH_FX = { Enabled = true, replaceCine = true, billboardSeconds = 6 }
Config.BATTLE_FX = { Enabled = true, intro = true, typeFx = true, specialEvery = 5, scene = true } -- scene : combat en vue face à face (BattleScene) ; false = ancien panneau compact
-- Données des effets par type (ReplicatedStorage/TypeFx, partagé) ; absent hors de Roblox (tests purs) : le client relit alors le module directement.
do
	local ok, mod = pcall(function()
		return require(script.Parent:FindFirstChild("TypeFx"))
	end)
	Config.TYPE_FX = (ok and type(mod) == "table") and mod.DATA or nil
end
-- LOT 10 : 42 icônes d'interface (lot 27 de la gestion). Ce sont des IDs de DÉCAL : le serveur les charge (InsertService:LoadAsset, sous pcall), lit Decal.Texture et publie
-- l'URL d'image en attribut du dossier ReplicatedStorage.Icons (clé = nom) ; le client affiche l'image si l'attribut existe, sinon l'emoji de repli (ICON_FALLBACK).
Config.ICONS = {
	egg_r1 = 127934484667125, egg_r2 = 90303465488088, egg_r3 = 133897962711845, egg_r4 = 107492649875193, egg_r5 = 81153824460002,
	egg_r6 = 131736092140777, egg_r7 = 105851181891208, egg_r8 = 79832611035411, egg_r9 = 94571875067666, egg_r10 = 106658286798870,
	r_boost_revenu = 93587101573522, r_boost_vitesse = 76153392233011, r_cadeau = 133203541146640, r_calendrier = 136982022925647, r_coffre = 82453934753407,
	r_coins_l = 89651368486077, r_coins_m = 77804077779876, r_coins_s = 100037045602015, r_cosmetique_traine = 112422956807005, r_jeton_combat = 78770783652851,
	r_mystere = 96381471224410, r_parchemin_xp = 72553197057463, r_plume = 120153496188232, r_potion_chance = 98934700828383, r_titre = 123915288580926,
	type_ciel = 130319463265184, type_eau = 116853247438408, type_feu = 84020103140683, type_foudre = 125216098737198, type_glace = 138517138957698,
	type_lumiere = 136542493297233, type_ombre = 97202454024141, type_plante = 110639649572139, type_terre = 112520404946573,
	ui_bouclier = 136315741394095, ui_cadenas = 71647030149825, ui_coeur = 91429395170558, ui_epee = 116607687889590, ui_etoile = 99988006769146,
	ui_pastille_rouge = 75154857237999, ui_trophee = 117839068590655, ui_victoire_defaite = 84125463363173,
}
Config.ICON_FALLBACK = {
	r_boost_revenu = "💰", r_boost_vitesse = "👟", r_cadeau = "🎁", r_calendrier = "📅", r_coffre = "🧰", r_coins_l = "🪙", r_coins_m = "🪙", r_coins_s = "🪙",
	r_cosmetique_traine = "🎀", r_jeton_combat = "⚔️", r_mystere = "🎲", r_parchemin_xp = "📜", r_plume = "🪶", r_potion_chance = "🧪", r_titre = "🏷️",
	type_ciel = "☁️", type_eau = "💧", type_feu = "🔥", type_foudre = "⚡", type_glace = "❄️", type_lumiere = "✨", type_ombre = "🌑", type_plante = "🌿", type_terre = "⛰️",
	ui_bouclier = "🛡", ui_cadenas = "🔒", ui_coeur = "❤️", ui_epee = "⚔️", ui_etoile = "⭐", ui_pastille_rouge = "🔴", ui_trophee = "🏆", ui_victoire_defaite = "🏆",
}
-- Clé d'icône d'un type de combat (« Lumière » -> type_lumiere, « Nature » -> type_plante) ; nil si inconnu.
Config.TYPE_ICON = { Feu = "type_feu", Eau = "type_eau", Plante = "type_plante", Nature = "type_plante", Glace = "type_glace", Foudre = "type_foudre", Terre = "type_terre", Ciel = "type_ciel", Ombre = "type_ombre", ["Lumière"] = "type_lumiere" }
-- Emoji de repli d'une icône (œufs : 🥚) ; "" si inconnue.
function Config.iconFallback(key)
	if type(key) ~= "string" then
		return ""
	end
	if key:sub(1, 5) == "egg_r" then
		return "🥚"
	end
	return Config.ICON_FALLBACK[key] or ""
end

---------------------------------------------------------------- LOT 15 : PNJ, série de 7 jours, quêtes bonus et hebdomadaires, rotation, événements
-- Données reprises de Lot15Data (modules purs ReplicatedStorage/Npc et Rewards, qui les lisent dans Config). Règle : AUCUN indice de rareté codé en dur ici,
-- toute rareté est un NOM résolu par Config.TIERS. `TIMED_EVENTS` (week-end chanceux, heure dorée) : nom distinct de Config.EVENTS (événements serveur existants).
Config.FORBIDDEN_GIFT_TIERS = { "Secret", "Exclusif", "Divin" }

---------------------------------------------------------------- F.1 Personnages
-- role : trade | fight | champion. types : types d'équipe (TypeFx.TYPES). signature : espèce emblématique (lot 11) ; l'équipe n'utilise que des espèces
-- EXISTANTES de Config.PETS (si la signature n'existe pas encore, elle n'est qu'affichée). model : clé d'asset (repli procédural obligatoire si l'ID est vide).
Config.NPCS = {
	pip = { name = "Pip le Colporteur", role = "trade", model = "npc.pip", emoji = "🧺" },
	nora = { name = "Nora la Collectionneuse", role = "trade", model = "npc.nora", emoji = "📒" },
	lina = { name = "Lina la Dresseuse", role = "fight", model = "npc.lina", emoji = "🌿", types = { "Plante", "Eau", "Glace" }, signature = "Koala" },
	bruno = { name = "Bruno le Costaud", role = "fight", model = "npc.bruno", emoji = "🔨", types = { "Terre", "Feu" }, signature = "Ours brun" },
	kai = { name = "Maître Kaï", role = "champion", model = "npc.kai", emoji = "🦊", types = { "Feu", "Eau", "Plante", "Glace", "Foudre", "Terre", "Ciel", "Ombre", "Lumière" }, signature = "Renard à neuf queues" },
}

-- F.2 (valeurs exactes de la spécification).
Config.NPC_ENCOUNTER = { firstAfterMinutes = 8, gapMinutes = { 6, 10 }, tradesPerDay = 4, fightsPerDay = 4, weeklyChampion = 1, snoozeMinutes = 10, offerSeconds = 60, approachRange = 25 }

-- F.4 / F.5 : règles chiffrées (noms de raretés, de tailles et de mutations ; jamais d'indices).
Config.NPC_RULES = {
	maxRefusals = 3, -- refus de suite : le PNJ ne revient plus ce jour-là
	buyDiscountNum = 8, buyDiscountDen = 10, -- œuf contre pièces = EGG_PRICE x 0,8
	buyMaxTier = "Légendaire", -- r <= 5
	dupesNeeded = 3, dupesMaxTier = "Épique", -- 3 doublons de rareté r (r <= 4) -> 1 œuf r+1
	speciesMaxTier = "Légendaire", speciesFeeNum = 2, speciesFeeDen = 10, speciesSize = "Normal", -- Nora : espèce manquante (r <= 5) contre 1 doublon + EGG_PRICE x 0,2
	giveMaxTier = "Légendaire", -- jamais un pet de rareté >= 6
	forbidMutFrom = "Arc-en-ciel", -- jamais un pet muté Arc-en-ciel ou mieux
	forbidSizeFrom = "Géant", -- jamais un pet Géant ou Colossal
	confirm2FromTier = "Épique", -- 2e confirmation si un pet de rareté >= 4 est donné
	revealQuietTier = "Légendaire", revealQuietSeconds = 60, -- pas de PNJ dans les 60 s après une révélation de rareté >= 5
	fightRewardMul = 0.6, cardPct = 60, champCardPct = 100, champPowerMul = 1.3, powerMin = 0.9, powerMax = 1.1,
	fightEggCap = "Légendaire", champEgg = "Mythique", lossXp = 5, resultSeconds = 900,
}

---------------------------------------------------------------- F.3 Dialogues (textes exacts ; {variables} remplacées par Npc.say)
Config.DIALOGUES = {
	pip = {
		approach = "Psst ! Hé, toi, le Chipeur ! J'ai un œuf qui n'attend que toi… On fait affaire ?",
		offer1 = "Cet œuf {rarity} contre 🪙 {price} : c'est 20 % de moins qu'à la boutique !",
		offer2 = "Tu as des doublons ? Donne-m'en 3 de rareté {r} et je te donne un œuf {r2}. Promis, pas d'arnaque.",
		refuse = "Tant pis ! Je repasse plus tard, garde tes pièces au chaud.",
		buttons = { "Voir l'offre", "Pas maintenant" },
	},
	nora = {
		approach = "Oh ! Il te manque quelque chose dans ton bestiaire…",
		offer = "Oh ! Il te manque le {species} dans ton bestiaire ? J'en ai un. Je te l'échange contre ton {dupe} et 🪙 {fee}.",
		refuse = "Pas de souci, mon carnet est patient.",
		buttons = { "Voir l'offre", "Pas maintenant" },
	},
	lina = {
		approach = "Ton équipe a l'air prometteuse… Un petit combat ? Je ne mords pas. Mon Koala, si.",
		win = "Bien joué ! Choisis ta récompense, tu l'as méritée.",
		lose = "Pas cette fois ! Entraîne-toi à la tour et reviens me voir. Astuce : {tip}",
		refuse = "Une autre fois, alors !",
		buttons = { "Combattre", "Pas maintenant" },
	},
	bruno = {
		approach = "Hé, toi ! Mon Ours brun s'ennuie. Un combat ?",
		win = "Pas mal du tout ! Prends ta récompense.",
		lose = "Haha ! Reviens quand tu auras plus de biceps. Astuce : {tip}",
		refuse = "Une autre fois, alors !",
		gone = "Bon, je vois que t'es occupé. À demain !",
		buttons = { "Combattre", "Pas maintenant" },
	},
	kai = {
		approach = "On m'a parlé de toi. Montre-moi ta meilleure équipe : si tu gagnes, la récompense est à la hauteur.",
		win = "Impressionnant. Cet œuf est à toi, et une récompense de plus.",
		lose = "Tu n'es pas encore prêt. Reviens lundi prochain.",
		refuse = "Je repasserai lundi prochain.",
		buttons = { "Relever le défi", "Pas maintenant" },
	},
}

-- Astuces de défaite : type de l'équipe adverse -> type qui le bat. VALEURS PAR DÉFAUT : l'intégrateur peut les remplacer par une lecture de la matrice D.2 de Battle
-- (Npc.tip accepte une table `weak` en argument).
Config.TYPE_WEAK = { Feu = "Eau", Eau = "Plante", Plante = "Feu", Glace = "Foudre", Foudre = "Terre", Terre = "Glace", Ciel = "Ombre", Ombre = "Lumière", ["Lumière"] = "Ciel" } -- LOT 12A : le type qui BAT chacun (BEATS primaire de Battle.lua, x1,5) ; l'ancienne table contredisait la matrice D.2

---------------------------------------------------------------- G.1 Série de 7 jours
-- eggs : noms de raretés ; c : minutes de revenu (min coinFloor) ; luck = potion de chance { minutes, points } ; boost = { key, mul, minutes } ; fragments : Fragments du Grand Œuf.
-- Jour 7 : eggsMonth = œufs à la place de `eggs` à chaque 4e semaine complète.
Config.STREAK = {
	coinFloor = 500, mythicEveryWeeks = 4, restoreQuests = 3, resetAfterMissed = 3,
	days = {
		{ eggs = { "Peu commun" }, c = 5 },
		{ eggs = { "Rare" } },
		{ luck = { minutes = 10, points = 25 } },
		{ eggs = { "Épique" }, c = 10 },
		{ eggs = { "Rare", "Rare" }, boost = { key = "xp", mul = 2, minutes = 30 } },
		{ eggs = { "Épique", "Épique" } },
		{ eggs = { "Légendaire" }, eggsMonth = { "Mythique" }, c = 30, fragments = 1 },
	},
}

-- Sac d'œufs : 10 places, jamais de perte (réclamation refusée tant que base ET sac sont pleins).
Config.EGG_BAG = { size = 10 }

---------------------------------------------------------------- G.4 Quêtes bonus et hebdomadaires
Config.QUESTS = {
	-- Quête bonus du jour (débloquée par les 3 quêtes du jour) : une option choisie par le numéro du jour.
	bonus = {
		egg = "Épique", eggLate = "Légendaire", lateChapter = 6,
		options = { { kind = "pve", goal = 2, text = "Gagne 2 combats PvE" }, { kind = "hatch", goal = 1, minTier = "Épique", text = "Fais éclore 1 œuf Épique ou mieux" } },
	},
	-- 7 quêtes de la semaine, une par thème. 5/7 -> Légendaire ; 7/7 -> Mythique + 300 XP de saison.
	weekly = {
		themes = {
			{ key = "hatch", goal = 15, text = "Fais éclore 15 œufs" }, { key = "steal", goal = 3, text = "Chipe 3 œufs" }, { key = "pve", goal = 10, text = "Gagne 10 combats PvE" },
			{ key = "pvp", goal = 3, text = "Gagne 3 duels" }, { key = "collect", goal = 5, text = "Découvre 5 espèces" }, { key = "riddle", goal = 3, text = "Résous 3 énigmes" },
			{ key = "npc", goal = 3, text = "Termine 3 rencontres de PNJ" },
		},
		rewards = { { need = 5, egg = "Légendaire" }, { need = 7, egg = "Mythique", seasonXp = 300 } },
	},
	-- Nouveaux types de quêtes du jour (A11 : branchés dans QUEST_TYPES de Main ; progression : Rewards.questKinds).
	newTypes = {
		pve = { text = "Gagne {n} combats PvE", goals = { 2, 3, 5 } }, duel = { text = "Joue {n} duel(s) récompensé(s)", goals = { 1, 2, 3 } }, npcTrade = { text = "Fais {n} échange(s) avec un PNJ", goals = { 1, 1, 2 } },
		typeWin = { text = "Gagne {n} combats PvE avec un pet du type de la semaine", goals = { 1, 2, 3 } }, odds = { text = "Obtiens un pet de 1 sur 1 000 ou plus rare", goals = { 1, 1, 1 } },
	},
}

---------------------------------------------------------------- G.5 Événements
-- Plumes d'événement (monnaie distincte des plumes du calendrier : champ event.p) : plafonds par jour UTC.
Config.PLUMES = { perQuest = 10, questCapDay = 40, perPveWin = 2, pveCapDay = 20, login = 5, exclusiveCost = 150, exclusiveName = "Exclusif", maxExclusivePerEvent = 3, balanceCap = 999 }

-- days : jours de la semaine UTC (0 = dimanche) ; le week-end chanceux va de samedi 00:00 à lundi 00:00 (dimanche inclus).
Config.TIMED_EVENTS = {
	weekend = { days = { 6, 0 }, upgradePoints = 5, beltSeconds = 4, beltDefault = 5 },
	goldenHour = { fromHour = 18, toHour = 19, key = "gold" },
}

-- Événements limités (10 jours, 1 par mois au plus) : dates UTC « MM-JJ » (sans année : revient chaque année), species = numéro de l'espèce Exclusif (lot 11).
-- Modifiable sans toucher à la logique.
Config.EVENTS_CAL = {
	{ id = "spring", name = "Printemps en fleurs", from = "03-21", to = "03-30", species = 75, decor = "event.springArch" },
	{ id = "summer", name = "Fête de l'été", from = "07-14", to = "07-23", species = 76, decor = "event.summerGate" },
	{ id = "halloween", name = "Nuit des citrouilles", from = "10-22", to = "10-31", species = 72, decor = "event.pumpkin" },
	{ id = "xmas", name = "Noël au Couvoir", from = "12-16", to = "12-25", species = 73, decor = "event.xmasTree" },
}

---------------------------------------------------------------- G.4 Rotation hebdomadaire (cycle de 9 semaines, un type par semaine)
-- featured : espèce vedette (nom de Config.PETS, poids x2 dans son œuf) ; type : type « en forme » (+20 % de dégâts PvE) ; shop : 2 cosmétiques (ids à relier au catalogue).
Config.WEEKLY_ROTATION_EPOCH = 0 -- semaine (lundi UTC) servant d'origine du cycle
Config.WEEKLY_ROTATION = {
	{ type = "Feu", featured = "Renard", shop = { "trail_flame", "hat_cinder" } },
	{ type = "Eau", featured = "Manchot", shop = { "trail_bubble", "hat_shell" } },
	{ type = "Plante", featured = "Lapin", shop = { "trail_leaf", "hat_flower" } },
	{ type = "Glace", featured = "Panda", shop = { "trail_snow", "hat_frost" } },
	{ type = "Foudre", featured = "Tigre", shop = { "trail_spark", "hat_bolt" } },
	{ type = "Terre", featured = "Chien", shop = { "trail_dust", "hat_stone" } },
	{ type = "Ciel", featured = "Hibou", shop = { "trail_cloud", "hat_wing" } },
	{ type = "Ombre", featured = "Chat", shop = { "trail_smoke", "hat_moon" } },
	{ type = "Lumière", featured = "Licorne", shop = { "trail_star", "hat_halo" } },
}
Config.WEEKLY_ROTATION_MULT = 2 -- poids de l'espèce vedette
Config.WEEKLY_ROTATION_DAMAGE = 1.2 -- type en forme, PvE seulement
-- Modèles Blender du lot 29 (repli procédural obligatoire si l'ID est vide ou si le chargement échoue). PNJ : chargés par le serveur, publiés dans
-- ReplicatedStorage.NpcTemplates, clonés par le CLIENT (seul le joueur interpellé voit son PNJ). Pip et sa charrette : 9 studs de large.
Config.Assets.models.npc = { pip = 123590742152774, lina = 102038009896523, bruno = 132952760984236, kai = 132880746039280, nora = 81037598191401 }
Config.Assets.models.event = { pumpkin = 73142027959966, xmasTree = 139994644133468, springArch = 100036291919800 }
Config.Assets.models.hub.calendar = 134196650002859 -- calendrier mural de 30 cases (jour 1 en haut à gauche, coffre devant), posé près du kiosque
for _, k in ipairs({ "npc.pip", "npc.lina", "npc.bruno", "npc.kai", "npc.nora", "event.pumpkin", "event.xmasTree", "event.springArch", "hub.calendar" }) do
	Config.Assets.modelsMaxParts[k] = 220
end
-- Affichage des PNJ (client) : hauteur visée, largeur de Pip avec sa charrette, distance d'arrêt devant le joueur, durée de la marche d'approche.
Config.NPC_VIEW = { height = 6, pipWidth = 9, stopAt = 7, walkSeconds = 3.5 }
-- Décor d'un événement limité : clé `decor` de EVENTS_CAL -> modèle du groupe `event` (sans modèle : repli procédural). Calendrier mural : décalage depuis le kiosque.
Config.EVENT_DECOR = { ["event.pumpkin"] = "pumpkin", ["event.xmasTree"] = "xmasTree", ["event.springArch"] = "springArch" }
Config.EVENT_DECOR_SPOT = { x = -14, z = 30, height = 9 }
Config.CALENDAR_BOARD = { dx = -9, dz = -6, height = 7 }
-- Produit de sauvetage de la série (G.2) : 29 R$, id créé par la gestion (lot 16), sans plafond d'achat (seulement quand la série est en danger).
Config.PRODUCTS.StreakRestore = { name = "Sauver ma série", emoji = "🔥", desc = "Sauve ta série de 7 jours quand elle est en danger (2 jours manqués). Le moyen gratuit : les 3 missions du jour. Aucun hasard." }


---------------------------------------------------------------- LOT 16 : boutique en 8 catégories, passe de combat, offres, vendeurs, mesure
-- Catalogue : copie EXACTE de ReplicatedStorage/ShopData.ENTRIES (vérifiée par tests/run.luau : mêmes clés, ids, prix, catégories, drapeaux). Config ne peut pas
-- faire require (il est chargé hors de Roblox par les tests). Décision utilisateur : PLUS AUCUN PLAFOND D'ACHAT ; seuls `once` (achat unique à vie : passes,
-- Pack de départ, chaque pose) et `season` (une fois par saison : season.premium = n) limitent. random = masqué et refusé sans PolicyService « non restreint ».
Config.SHOP = {}
do
	local function P(id, robux, cat, extra)
		local e = { kind = "product", id = id, robux = robux, cat = cat }
		for k, v in pairs(extra or {}) do
			e[k] = v
		end
		return e
	end
	local function G(id, robux, cat, extra)
		local e = P(id, robux, cat, extra)
		e.kind, e.once = "pass", true
		return e
	end
	local S = Config.SHOP
	S.EggR2 = P(3736703563, 15, "eggs", { random = true, eggTier = 2 })
	S.EggR3 = P(3736703571, 25, "eggs", { random = true, eggTier = 3 })
	S.EggR4 = P(3736703588, 49, "eggs", { random = true, eggTier = 4 })
	S.EggR5 = P(3736703667, 99, "eggs", { random = true, eggTier = 5 })
	S.ExclusiveEgg = P(3734229320, 249, "eggs", { random = true, eggTier = 6 })
	S.EggR7 = P(3736703695, 799, "eggs", { random = true, eggTier = 7 })
	S.EggSecret = P(3736452048, 1499, "eggs", { random = true, eggTier = 8 })
	S.EggExclusive = P(3736452061, 3499, "eggs", { random = true, eggTier = 9 })
	S.EggDivine = P(3736452072, 6999, "eggs", { random = true, eggTier = 10 })
	S.LuckPotionMini = P(3736703579, 29, "luck", { random = true })
	S.LuckPotion = P(3734229337, 99, "luck", { random = true })
	S.GoldenBelt = P(3736121227, 99, "luck", { random = true })
	S.ServerLuck = P(3736121217, 129, "luck", { random = true })
	S.DoubleLuck = P(3736703673, 149, "luck", { random = true })
	S.Lucky = G(2093447290, 149, "luck", { random = true })
	S.Fast = G(2097173053, 149, "luck")
	S.Speed = G(2092253306, 149, "luck")
	S.PrivateBelt = G(2098265697, 299, "luck", { random = true })
	S.Lucky2 = G(2102045961, 349, "luck", { random = true })
	S.CoinPackS = P(3736703557, 19, "coins")
	S.CoinPack = P(3734229339, 99, "coins")
	S.Coins2x = G(2093291260, 199, "coins")
	S.StreakRestore = P(3736703610, 29, "base")
	S.CalendarCatchup = P(3736695392, 29, "base")
	S.InstantHatch = P(3734229329, 49, "base")
	S.EggBagPlus = G(2099454839, 149, "base")
	S.ExtraSlots = G(2098181699, 249, "base")
	S.Collector = G(2099556764, 249, "base")
	S.VipBase = G(2094209172, 399, "base")
	S.ArenaTickets = P(3736703606, 19, "combat")
	S.Revive = P(3734229323, 49, "combat")
	S.RemoteSteal = P(3736121232, 79, "combat")
	S.RemoteStealPack = P(3736121238, 199, "combat")
	S.SeasonPremium = P(3736703683, 399, "season", { season = true })
	S.SeasonUpgradePlus = P(3736704000, 400, "season", { season = true })
	S.SeasonPremiumPlus = P(3736703689, 799, "season", { season = true })
	S.StarterPack = P(3734229313, 99, "packs", { random = true, once = true })
	S.BundleLegend = P(3736703706, 999, "packs", { random = true })
	S.BundleRoyalNoPass = P(3736704205, 1100, "packs", { random = true })
	S.BundleRoyal = P(3736703714, 1499, "packs", { random = true })
	for n, id in ipairs({ 3736703619, 3736703629, 3736703634, 3736703641, 3736703649, 3736703657 }) do
		S["EmoteVictory" .. n] = P(id, 39, "cosmetics", { once = true })
	end
	-- pose des champs de catalogue dans PRODUCTS / PASSES (name, emoji, desc existants conservés)
	for key, e in pairs(S) do
		local bag = e.kind == "pass" and Config.PASSES or Config.PRODUCTS
		local def = bag[key] or { name = key, emoji = "🛒", desc = "" }
		bag[key] = def
		for _, f in ipairs({ "id", "robux", "cat", "random", "once", "season", "eggTier" }) do
			def[f] = e[f]
		end
	end
end
-- Les 8 catégories de la boutique, ordre FIXE (= Shop.CATEGORIES, vérifié par les tests). L'onglet « season » est le passe de combat (Season.lua).
Config.SHOP_CATEGORIES = {
	{ key = "eggs", title = "Œufs", icon = "egg_r3" },
	{ key = "luck", title = "Chance & boosts", icon = "r_potion_chance" },
	{ key = "coins", title = "Pièces", icon = "r_coins_m" },
	{ key = "base", title = "Base & confort", icon = "ui_bouclier" },
	{ key = "combat", title = "Combat & vol", icon = "ui_epee" },
	{ key = "season", title = "Passe de combat", icon = "ui_trophee" },
	{ key = "packs", title = "Packs", icon = "r_coffre" },
	{ key = "cosmetics", title = "Cosmétiques", icon = "r_cosmetique_traine" },
}
-- Effets du lot 16 appliqués par le serveur (le moteur reste maître des minuteurs). Double chance : x2 puis 70 points au plus (Shop.DOUBLE_LUCK_CAP).
Config.LOT16 = {
	luckMiniSeconds = 300, doubleSeconds = 1800, legendDoubleSeconds = 3600, doubleCap = 70, arenaTickets = 5,
	coinPackS = { minutes = 5, min = 1000 },
	emotes = { "🎉", "✌️", "💃", "🏆", "⭐", "🔥" }, -- poses de victoire 1 à 6 (effet visuel joué par le client après une victoire)
	overflowTake = 1, -- œufs repris du coffre de débordement par demande
}
-- Sac d'œufs : 20 places avec le passe EggBagPlus (le profil garde jusqu'à sizePlus œufs ; la place réelle dépend du passe). Collectionneur : 4 pets suiveurs.
Config.EGG_BAG.sizePlus = 20
Config.MAX_FOLLOWERS_COLLECTOR = 4
-- Passe de combat : copie de SeasonData.SEASON (vérifiée par les tests) pour l'affichage ; la logique est dans ReplicatedStorage/Season.
Config.SEASON = { name = "Passe de combat", start = 1796083200, days = 60, tiers = 30, graceDays = 7, dailyCap = 400 }
-- Version publiée (étiquette des événements AnalyticsService « version », I.2) : à changer à chaque publication.
Config.BUILD = "1.16.0"
-- Vendeurs PNJ du hub (modèles Blender du lot 30 de la gestion ; repli procédural si le chargement échoue). Écart accepté : 2 vendeurs à 14-22 studs, 6 plus loin.
for key, id in pairs({ vendor_eggs = 138633300069014, vendor_luck = 137414127061497, vendor_coins = 82919202214027, vendor_base = 79064954843258,
	vendor_combat = 105059296701916, vendor_pass = 72959276245033, vendor_packs = 80912619819088, vendor_cosmetics = 82243751363820 }) do
	Config.Assets.models.hub[key] = id
	Config.Assets.modelsMaxParts["hub." .. key] = 80
end

return Config
