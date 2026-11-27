-- ModuleScript : ReplicatedStorage/Shared/Lot15Data
-- LOT 15 : DONNÉES pures (PNJ, rencontres, dialogues, série de 7 jours, quêtes, rotation, événements). Aucune logique, aucun service Roblox.
-- L'intégrateur copie chaque clé dans Config (Config.NPCS = Lot15Data.NPCS, etc.) ou fusionne la table entière ; Npc.lua et Rewards.lua lisent ces clés dans `Config`.
-- Règle : AUCUN indice de rareté codé en dur ici. Toute rareté est un NOM résolu par Config.TIERS (Npc.tierIdx / Rewards.tierIdx), donc robuste à une renumérotation.
local D = {}

-- Raretés qu'un PNJ, la série de 7 jours, les quêtes ou le sac ne donnent JAMAIS (achat ou événement seulement ; l'Exclusif s'obtient aussi avec 150 plumes).
-- Le calendrier de 30 jours (Calendar.lua, lot 9b) a sa propre table : son tirage du jour 30 peut donner un Secret (décision utilisateur).
D.FORBIDDEN_GIFT_TIERS = { "Secret", "Exclusif", "Divin" }

---------------------------------------------------------------- F.1 Personnages
-- role : trade | fight | champion. types : types d'équipe (TypeFx.TYPES). signature : espèce emblématique (lot 11) ; l'équipe n'utilise que des espèces
-- EXISTANTES de Config.PETS (si la signature n'existe pas encore, elle n'est qu'affichée). model : clé d'asset (repli procédural obligatoire si l'ID est vide).
D.NPCS = {
	pip = { name = "Pip le Colporteur", role = "trade", model = "npc.pip", emoji = "🧺" },
	nora = { name = "Nora la Collectionneuse", role = "trade", model = "npc.nora", emoji = "📒" },
	lina = { name = "Lina la Dresseuse", role = "fight", model = "npc.lina", emoji = "🌿", types = { "Plante", "Eau", "Glace" }, signature = "Koala" },
	bruno = { name = "Bruno le Costaud", role = "fight", model = "npc.bruno", emoji = "🔨", types = { "Terre", "Feu" }, signature = "Ours brun" },
	kai = { name = "Maître Kaï", role = "champion", model = "npc.kai", emoji = "🦊", types = { "Feu", "Eau", "Plante", "Glace", "Foudre", "Terre", "Ciel", "Ombre", "Lumière" }, signature = "Renard à neuf queues" },
}

-- F.2 (valeurs exactes de la spécification).
D.NPC_ENCOUNTER = { firstAfterMinutes = 8, gapMinutes = { 6, 10 }, tradesPerDay = 4, fightsPerDay = 4, weeklyChampion = 1, snoozeMinutes = 10, offerSeconds = 60, approachRange = 25 }

-- F.4 / F.5 : règles chiffrées (noms de raretés, de tailles et de mutations ; jamais d'indices).
D.NPC_RULES = {
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
D.DIALOGUES = {
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
D.TYPE_WEAK = { Feu = "Eau", Eau = "Foudre", Plante = "Feu", Glace = "Feu", Foudre = "Terre", Terre = "Plante", Ciel = "Foudre", Ombre = "Lumière", ["Lumière"] = "Ombre" }

---------------------------------------------------------------- G.1 Série de 7 jours
-- eggs : noms de raretés ; c : minutes de revenu (min coinFloor) ; luck = potion de chance { minutes, points } ; boost = { key, mul, minutes } ; fragments : Fragments du Grand Œuf.
-- Jour 7 : eggsMonth = œufs à la place de `eggs` à chaque 4e semaine complète.
D.STREAK = {
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
D.EGG_BAG = { size = 10 }

---------------------------------------------------------------- G.4 Quêtes bonus et hebdomadaires
D.QUESTS = {
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
	-- Nouveaux types de quêtes du jour (forme libre : l'intégrateur les adapte à Config.QUEST_TYPES).
	newTypes = {
		pve = { text = "Gagne {n} combats PvE", goals = { 2, 3, 5 } }, duel = { text = "Joue {n} duels", goals = { 1, 2, 3 } }, npcTrade = { text = "Fais {n} échange avec un PNJ", goals = { 1, 1, 2 } },
		typeWin = { text = "Gagne {n} combats avec le type {type}", goals = { 1, 2, 3 } }, odds = { text = "Obtiens un pet de 1 sur 1 000 ou plus rare", goals = { 1, 1, 1 } },
	},
}

---------------------------------------------------------------- G.5 Événements
-- Plumes d'événement (monnaie distincte des plumes du calendrier : champ event.p) : plafonds par jour UTC.
D.PLUMES = { perQuest = 10, questCapDay = 40, perPveWin = 2, pveCapDay = 20, login = 5, exclusiveCost = 150, exclusiveName = "Exclusif", maxExclusivePerEvent = 3, balanceCap = 999 }

-- days : jours de la semaine UTC (0 = dimanche) ; le week-end chanceux va de samedi 00:00 à lundi 00:00 (dimanche inclus).
D.EVENTS = {
	weekend = { days = { 6, 0 }, upgradePoints = 5, beltSeconds = 4, beltDefault = 5 },
	goldenHour = { fromHour = 18, toHour = 19, key = "gold" },
}

-- Événements limités (10 jours, 1 par mois au plus) : dates UTC « MM-JJ » (sans année : revient chaque année), species = numéro de l'espèce Exclusif (lot 11).
-- Modifiable sans toucher à la logique.
D.EVENTS_CAL = {
	{ id = "spring", name = "Printemps en fleurs", from = "03-21", to = "03-30", species = 75, decor = "event.springArch" },
	{ id = "summer", name = "Fête de l'été", from = "07-14", to = "07-23", species = 76, decor = "event.summerGate" },
	{ id = "halloween", name = "Nuit des citrouilles", from = "10-22", to = "10-31", species = 72, decor = "event.pumpkin" },
	{ id = "xmas", name = "Noël au Couvoir", from = "12-16", to = "12-25", species = 73, decor = "event.xmasTree" },
}

---------------------------------------------------------------- G.4 Rotation hebdomadaire (cycle de 9 semaines, un type par semaine)
-- featured : espèce vedette (nom de Config.PETS, poids x2 dans son œuf) ; type : type « en forme » (+20 % de dégâts PvE) ; shop : 2 cosmétiques (ids à relier au catalogue).
D.WEEKLY_ROTATION_EPOCH = 0 -- semaine (lundi UTC) servant d'origine du cycle
D.WEEKLY_ROTATION = {
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
D.WEEKLY_ROTATION_MULT = 2 -- poids de l'espèce vedette
D.WEEKLY_ROTATION_DAMAGE = 1.2 -- type en forme, PvE seulement

return D
