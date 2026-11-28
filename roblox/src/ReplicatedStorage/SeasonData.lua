-- ModuleScript : ReplicatedStorage/Shared/SeasonData
-- LOT 16 (G.5 + addendum B) : DONNÉES de la Passe de combat (aucune logique, aucun service Roblox). Les raretés sont des NOMS résolus par Config.TIERS (jamais de rang en dur).
-- Modifiable sans toucher Season.lua : durée, date de début, XP par source, plafond/jour, XP par palier, récompenses des deux pistes, thèmes et espèces de saison.
local D = {}

-- Début de la saison 1 : date UTC FIXE (2026-12-01 00:00:00 UTC). Les saisons s'enchaînent toutes les `days` jours sans trou ni chevauchement.
D.SEASON = {
	start = 1796083200,
	days = 60,
	tiers = 30,
	graceDays = 7, -- jours après la fin pendant lesquels les récompenses déjà gagnées restent réclamables (puis perdues)
	dailyCap = 400, -- XP de saison maximale par jour UTC (sources plafonnées)
	hatchMinTier = "Épique", -- éclosion donnant de l'XP : cette rareté ou mieux (nom, résolu par Config.TIERS)
	freeEggMax = "Épique", -- plus haute rareté d'œuf de la piste gratuite (hors palier 30)
	premiumEggMax = "Mythique", -- plus haute rareté d'œuf de la piste premium
	freeFinalEgg = "Légendaire", -- œuf du palier 30 gratuit
	exclusiveTier = "Exclusif", -- rareté de l'espèce de saison (garantie par la piste premium au palier 30 ; A5 : aussi tirable d'un œuf Exclusif pendant la saison, jamais hors saison)
	plusTiers = 10, -- paliers offerts par Premium+ et par le complément
}

-- XP par source. `capped = false` : la source n'entre pas dans le plafond/jour (la quête de la semaine ne tombe qu'une fois par semaine).
D.XP = {
	pve = { amount = 20, capped = true }, -- victoire PvE
	pvp = { amount = 30, capped = true }, -- victoire PvP
	duel = { amount = 30, capped = true }, -- victoire en duel
	daily = { amount = 100, capped = true }, -- quête du jour
	weekly = { amount = 300, capped = false }, -- quêtes de la semaine (7/7)
	hatch = { amount = 50, capped = true }, -- éclosion Épique ou mieux
}

-- Produits (Robux). Les ids de produit restent dans Config.PRODUCTS (créés par la gestion) : ici seulement le prix et l'effet.
D.PREMIUM = {
	premium = { robux = 399, plus = false },
	premiumPlus = { robux = 799, plus = true }, -- premium + 10 paliers, une fois par saison
	upgradePlus = { robux = 400, plus = true }, -- complément (déjà premium) : 10 paliers, une fois par saison
}

-- XP nécessaire pour passer de chaque palier au suivant (palier 1 = 0 -> 1). Total 16 500 XP.
D.TIER_XP = {
	490, 490, 490, 490, 490, 490, 490, 490, 490, 490,
	550, 550, 550, 550, 550, 550, 550, 550, 550, 550,
	610, 610, 610, 610, 610, 610, 610, 610, 610, 610,
}

-- Thèmes en rotation (Feu, Glace, Foudre, Ombre, Nature, Ciel) : décor, bannière, aura et espèce changent à chaque saison.
D.THEMES = {
	{ name = "Feu", of = "de Feu", color = { 255, 110, 40 }, decor = "braises" },
	{ name = "Glace", of = "de Glace", color = { 140, 215, 255 }, decor = "givre" },
	{ name = "Foudre", of = "de Foudre", color = { 255, 230, 70 }, decor = "éclairs" },
	{ name = "Ombre", of = "d'Ombre", color = { 120, 80, 190 }, decor = "brume" },
	{ name = "Nature", of = "de Nature", color = { 90, 200, 90 }, decor = "feuilles" },
	{ name = "Ciel", of = "du Ciel", color = { 120, 180, 255 }, decor = "nuages" },
}

-- Espèce Exclusif FIXE de chaque saison (par NOM d'espèce : pas de hasard). Tant que l'espèce n'existe pas dans Config.PETS (rareté Exclusif), Season donne un cosmétique à la place.
-- Au-delà de la saison 6 : à renseigner (nil = cosmétique de repli).
-- Lot 11 : la saison 1 donne « Corbeau couronné », l'espèce Exclusif du bestiaire marquée event = "saison1" ; les saisons 2 à 6 gardent leur nom prévu
-- (espèces pas encore créées : trophée de repli, aucune récompense perdue). Halloween / Noël (Loup-garou citrouille, Renne étoilé) relèvent des événements.
-- A5 : une espèce marquée event n'est tirée d'un œuf Exclusif que pendant sa fenêtre (« saison1 » = saison 1 en cours, Rewards.openSpeciesEvents) ;
-- hors fenêtre, jamais (ni œuf, ni tapis). La récompense du palier 30 reste donnée par nom, hors tirage.
D.SPECIES = { "Corbeau couronné", "Yéti d'Aurore", "Loup d'Orage", "Chat d'Éclipse", "Cerf des Bois", "Griffon des Nuages" }

-- Libellés des cosmétiques (clé -> début du libellé). L'identifiant final est "s<n>_<clé>" : propre à la saison, jamais réutilisé.
D.COSMETICS = {
	pose = "Pose",
	banner = "Bannière",
	trail = "Traînée",
	title = "Titre",
	aura = "Aura",
	aura2 = "Grande aura",
	trophy = "Trophée Exclusif",
}

-- Définition d'une saison : D.SEASONS[n] (1..6 écrites ici, au-delà générées par la rotation).
D.SEASONS = {}
function D.get(n)
	if type(n) ~= "number" or n ~= n or n < 1 then
		return nil
	end
	n = math.floor(n)
	local cached = D.SEASONS[n]
	if cached then
		return cached
	end
	local theme = D.THEMES[(n - 1) % #D.THEMES + 1]
	local def = {
		n = n,
		theme = theme.name,
		of = theme.of,
		color = theme.color,
		decor = theme.decor,
		name = "Passe de combat : " .. theme.name .. " (Saison " .. n .. ")",
		species = D.SPECIES[n],
	}
	D.SEASONS[n] = def
	return def
end
for n = 1, #D.THEMES do
	D.get(n)
end

function D.cosmeticLabel(n, key)
	local def = D.get(n)
	local base = D.COSMETICS[key] or key
	if key == "trophy" then
		return base .. " : " .. (def and def.species or "?") .. " (Saison " .. n .. ")"
	end
	return base .. " " .. (def and def.of or "") .. " (Saison " .. n .. ")"
end

-- Récompenses : entrées de forme { k = genre, ... }, résolues par Season (rareté par nom, cosmétique par saison). Une récompense de palier = liste d'entrées.
--   coins = minutes de revenu (le serveur applique son plancher), egg = nom de rareté, token = jetons de combat, scroll = parchemins d'XP de pet,
--   cosmetic/aura = clé de D.COSMETICS, species = espèce Exclusif de la saison.
local function C(m) return { k = "coins", v = m } end
local function E(name, n) return { k = "egg", name = name, n = n or 1 } end
local function T(n) return { k = "token", v = n } end
local function S(n) return { k = "scroll", v = n } end
local function COS(key) return { k = "cosmetic", key = key } end
local function AURA(key) return { k = "aura", key = key } end
local function SPECIES() return { k = "species" } end

-- Piste gratuite : un cadeau à chaque palier jusqu'au 20, puis 25 et 30 (Légendaire). Aucune rareté Secret / Exclusif / Divin.
D.FREE = {
	[1] = { C(15) }, [2] = { E("Peu commun") }, [3] = { T(1) }, [4] = { C(20) }, [5] = { E("Rare") },
	[6] = { S(1) }, [7] = { C(25) }, [8] = { E("Rare") }, [9] = { T(1) }, [10] = { COS("pose") },
	[11] = { C(30) }, [12] = { E("Rare") }, [13] = { S(1) }, [14] = { C(35) }, [15] = { E("Épique") },
	[16] = { T(2) }, [17] = { C(40) }, [18] = { S(2) }, [19] = { C(45) }, [20] = { E("Épique"), AURA("aura") },
	[25] = { C(60), T(2) }, [30] = { E("Légendaire"), COS("banner") },
}

-- Piste premium : un cadeau à chaque palier, œufs jusqu'à Mythique, espèce Exclusif de la saison au palier 30.
D.PREMIUM_TRACK = {
	[1] = { E("Rare") }, [2] = { C(30) }, [3] = { T(2) }, [4] = { E("Rare") }, [5] = { COS("banner") },
	[6] = { E("Épique") }, [7] = { S(2) }, [8] = { C(50) }, [9] = { E("Épique") }, [10] = { COS("pose") },
	[11] = { T(3) }, [12] = { E("Épique") }, [13] = { C(70) }, [14] = { S(3) }, [15] = { AURA("aura2") },
	[16] = { E("Légendaire") }, [17] = { C(90) }, [18] = { T(3) }, [19] = { E("Épique") }, [20] = { COS("trail") },
	[21] = { C(110) }, [22] = { E("Légendaire") }, [23] = { S(4) }, [24] = { T(4) }, [25] = { COS("title") },
	[26] = { E("Légendaire") }, [27] = { C(150) }, [28] = { E("Mythique") }, [29] = { T(5) }, [30] = { SPECIES(), E("Mythique") },
}

return D
