-- ModuleScript : ReplicatedStorage/Shared/ShopInfo (LOT 16, boutique pure : DONNÉES seulement, aucun service Roblox)
-- Une fiche par achat, clé = clé de Config.PRODUCTS / Config.PASSES. Source : Assets/ACHATS_DEFINITIONS.md (titre <= 28 caractères, définition <= 90).
-- Champs : cat (catégorie, voir Shop.CATEGORIES), icon (clé de Config.ICONS), title, def (définition courte), detail (durée, ce qui est aléatoire ou fixe, prérequis),
--   notDo (« ce que l'achat ne fait PAS »), chance (texte « hasard / fixe »), limit ("achat unique" | "aucune limite" | "achat unique par saison"), also (autres catégories à renvoyer, « voir aussi »).
-- Règles (vérifiées par tests/shop.luau) : aucun champ vide, aucune promesse (de gain, de force, de protection), aucune fausse urgence, aucune limite autre que « achat unique ».
local I = {}

local NO_POWER = "ne donne aucune force en combat et ne protège pas du vol"
local EGG_PLACE = "Il faut une place libre dans ta base ou ton sac : sinon l'achat est refusé AVANT paiement (« fais de la place »). Si une course survient après paiement, l'œuf va dans le coffre de débordement, rien n'est perdu."
local EGG_CHANCE = "oui : l'espèce, la taille et la mutation sont tirées au sort (table affichée avant l'achat) ; la rareté de l'œuf est FIXE et affichée"
local PARTLY = "oui, en partie : le bonus est fixe et affiché ; ce qui sort de chaque éclosion reste aléatoire"

local function egg(tier, name, detailHead, notDoText)
	return {
		cat = "eggs", icon = "egg_r" .. tier, title = "Œuf " .. name,
		def = "Un œuf " .. name .. " posé dans ta base : la rareté est fixe, l'espèce est tirée au sort.",
		detail = detailHead .. " Tailles et mutations tirées au sort (tables du menu Plus). " .. EGG_PLACE,
		notDo = notDoText or "ne donne aucune force en combat et ne protège pas du vol ; un pet vaut pareil, acheté ou trouvé",
		chance = EGG_CHANCE, limit = "aucune limite", also = {},
	}
end

local UP_HEAD = "Contenu et probabilités exacts affichés avant l'achat (les bonus de chance actifs changent la part d'amélioration d'un cran, jamais de rétrogradation)."
local FIXED_HEAD = "Rareté fixe, pas d'amélioration possible : le contenu et les probabilités exacts sont affichés avant l'achat."

---------------------------------------------------------------- Œufs
I.EggR2 = egg(2, "Peu commun", UP_HEAD)
I.EggR3 = egg(3, "Rare", UP_HEAD)
I.EggR4 = egg(4, "Épique", UP_HEAD)
I.EggR5 = egg(5, "Légendaire", UP_HEAD)
I.ExclusiveEgg = egg(6, "Mythique", UP_HEAD .. " Ex-« Œuf exclusif Mythique » : à ne pas confondre avec la rareté Exclusif.")
I.EggR7 = egg(7, "Ultra Rare", FIXED_HEAD)
I.EggSecret = egg(8, "Secret", FIXED_HEAD .. " Masqué tant qu'aucune espèce Secret n'est publiée.")
I.EggExclusive = egg(9, "Exclusif", FIXED_HEAD .. " Les espèces Exclusif sont liées à une fenêtre (fête limitée ou saison du passe de combat) : l'œuf n'est en vente que pendant une fenêtre ouverte et l'espèce est tirée au sort parmi celles de la fenêtre en cours (table affichée), comme la taille et la mutation. Masqué hors fenêtre.", "ne donne aucune force en combat, ne protège pas du vol et rapporte moins qu'un Secret")
I.EggDivine = egg(10, "Divin", FIXED_HEAD .. " Masqué tant qu'aucune espèce Divin n'est publiée.")

---------------------------------------------------------------- Chance & boosts
I.LuckPotionMini = {
	cat = "luck", icon = "r_potion_chance", title = "Potion express",
	def = "+25 points de chance d'avoir un pet de rareté au-dessus, pendant 5 minutes.",
	detail = "Comme la Potion de chance mais seulement 5 minutes, pour un petit prix. La chance d'amélioration d'un cran passe de 5 % à 30 % pendant ce temps (70 % au maximum). Chiffres affichés avant l'achat. Les durées s'ajoutent.",
	notDo = "ne garantit aucun pet rare et ne donne aucune force", chance = PARTLY, limit = "aucune limite", also = {},
}
I.LuckPotion = {
	cat = "luck", icon = "r_potion_chance", title = "Potion de chance",
	def = "+25 points de chance d'avoir un pet de rareté au-dessus, pendant 15 minutes.",
	detail = "Pendant 15 min, la chance d'amélioration d'un cran passe de 5 % à 30 % (sans autre bonus). Jamais de rétrogradation. Les chiffres exacts sont affichés avant l'achat. Les durées s'ajoutent.",
	notDo = "ne garantit aucun pet rare et ne donne aucune force", chance = PARTLY, limit = "aucune limite", also = {},
}
I.GoldenBelt = {
	cat = "luck", icon = "r_mystere", title = "Tapis doré",
	def = "10 min : le tapis du marché donne des œufs plus vite et de meilleure rareté, pour tous.",
	detail = "Pendant 10 min, le tapis livre un œuf plus souvent, avec la table « dorée » (affichée sur le tapis et avant l'achat). Profite à tout le serveur. Durées cumulables.",
	notDo = NO_POWER, chance = "oui : la rareté de chaque œuf du tapis est tirée au sort avec la table dorée, affichée avant l'achat et sur le tapis", limit = "aucune limite", also = { "eggs" },
}
I.ServerLuck = {
	cat = "luck", icon = "r_potion_chance", title = "Pluie de chance pour tous",
	def = "Pendant 10 min, tout le serveur gagne +5 points de chance d'amélioration.",
	detail = "Le bonus profite à tous les joueurs du serveur, pas seulement à toi (ton nom est remercié). Il dure 10 minutes : c'est la durée du bonus, pas une pression pour acheter. Durées cumulables.",
	notDo = "ne garantit aucun pet rare et ne donne aucune force", chance = PARTLY, limit = "aucune limite", also = {},
}
I.DoubleLuck = {
	cat = "luck", icon = "r_potion_chance", title = "Double chance",
	def = "Pendant 30 minutes, tes points de chance d'amélioration comptent double.",
	detail = "Les points de chance (base, Trèfle, passes, potion) sont multipliés par 2 pendant 30 min. Exemple : 5 points deviennent 10, et 15 deviennent 30. Les durées s'ajoutent ; le total ne dépasse jamais 70 points de chance, affichés avant l'achat.",
	notDo = "ne garantit aucun pet rare et ne donne aucune force", chance = PARTLY, limit = "aucune limite", also = {},
}
I.Lucky = {
	cat = "luck", icon = "ui_etoile", title = "Chance +10 %",
	def = "+10 points de chance d'avoir un pet de rareté au-dessus, pour toujours.",
	detail = "La chance d'amélioration d'un cran passe de 5 % à 15 % (70 % au maximum avec tous les bonus). Les chiffres sont affichés avant l'achat. Jamais de rétrogradation.",
	notDo = "ne garantit aucun pet rare et ne donne aucune force", chance = PARTLY, limit = "achat unique", also = {},
}
I.Fast = {
	cat = "luck", icon = "r_boost_vitesse", title = "Éclosion rapide",
	def = "Tes œufs éclosent 25 % plus vite, pour toujours.",
	detail = "Réduit le temps d'éclosion de 25 %, à vie. Ne change ni la rareté ni le contenu des œufs.",
	notDo = "ne donne aucune force en combat et ne change pas ce qui sort des œufs", chance = "non", limit = "achat unique", also = {},
}
I.Speed = {
	cat = "luck", icon = "r_boost_vitesse", title = "Vitesse +20 %",
	def = "Tu cours 20 % plus vite, pour toujours.",
	detail = "Ta vitesse de course est multipliée par 1,2, à vie. Elle ne rend pas le vol automatique : les gardiens et les autres joueurs restent là.",
	notDo = "ne donne pas de force en combat et ne protège pas du vol", chance = "non", limit = "achat unique", also = {},
}
I.PrivateBelt = {
	cat = "luck", icon = "egg_r1", title = "Tapis privé",
	def = "Un petit tapis dans ta base : un œuf gratuit toutes les 2 min quand tu joues.",
	detail = "Un œuf gratuit toutes les 2 min tant que tu joues, 3 en attente au plus. La rareté de chaque œuf est tirée au sort avec la table standard du tapis, affichée avant l'achat.",
	notDo = NO_POWER, chance = "oui : la rareté de chaque œuf gratuit est tirée au sort (table affichée) ; rien n'est promis", limit = "achat unique", also = { "eggs" },
}
I.Lucky2 = {
	cat = "luck", icon = "ui_etoile", title = "Chance +10 % II",
	def = "+10 points de chance d'avoir un pet de rareté au-dessus, en plus de Chance +10 %.",
	detail = "S'ajoute à Chance +10 % : la chance d'amélioration de base passe de 5 % à 25 % avec les deux (70 % au maximum avec tous les bonus). Chiffres affichés avant l'achat.",
	notDo = "ne garantit aucun pet rare et ne donne aucune force", chance = PARTLY, limit = "achat unique", also = {},
}

---------------------------------------------------------------- Pièces
I.CoinPackS = {
	cat = "coins", icon = "r_coins_s", title = "Petit sac de pièces",
	def = "Reçois les revenus de 5 minutes de jeu (au moins 1 000 pièces).",
	detail = "Une somme de pièces égale à 5 min de tes revenus, minimum 1 000. Ce sont des pièces, pas des pets.",
	notDo = "ne donne aucun pet et aucune force", chance = "non", limit = "aucune limite", also = {},
}
I.CoinPack = {
	cat = "coins", icon = "r_coins_m", title = "Sac de pièces",
	def = "Reçois les revenus de 20 minutes de jeu (au moins 5 000 pièces).",
	detail = "Une somme égale à 20 min de tes revenus, minimum 5 000 pièces. Ce sont des pièces, pas des pets.",
	notDo = "ne donne aucun pet et aucune force", chance = "non", limit = "aucune limite", also = {},
}
I.Coins2x = {
	cat = "coins", icon = "r_boost_revenu", title = "Revenus x2",
	def = "Tes pets rapportent deux fois plus de pièces, pour toujours.",
	detail = "Double tous tes revenus de pièces, à vie, une seule fois pour tout le compte.",
	notDo = "ne donne aucune force en combat, ne donne pas de pets et ne protège pas du vol", chance = "non", limit = "achat unique", also = {},
}

---------------------------------------------------------------- Base & confort
I.StreakRestore = {
	cat = "base", icon = "ui_coeur", title = "Sauvetage de série",
	def = "Rétablit ta série de connexion quand elle va se perdre.",
	detail = "Quand un deuxième jour manqué va casser ta série, tu peux la sauver. Il existe un moyen gratuit : finir les 3 quêtes du jour. Proposé seulement quand la série est en danger.",
	notDo = "ne donne aucun œuf supplémentaire et n'avance pas le calendrier", chance = "non", limit = "aucune limite", also = {},
}
I.CalendarCatchup = {
	cat = "base", icon = "r_calendrier", title = "Rattrapage du calendrier",
	def = "Rattrape UN jour manqué du calendrier de 30 jours, au jour de ton choix.",
	detail = "Tu choisis le jour manqué ; la récompense est celle affichée sur la carte. Deux rattrapages gratuits existent (jour de grâce, 3 missions). Aucun tirage payant.",
	notDo = "ne donne rien d'autre que la récompense du jour choisi", chance = "non : la récompense du jour est affichée", limit = "aucune limite", also = {},
}
I.InstantHatch = {
	cat = "base", icon = "r_boost_vitesse", title = "Éclosion instantanée",
	def = "Fait éclore tous tes œufs tout de suite, sans attendre.",
	detail = "Tous les œufs qui incubent éclosent maintenant. Ce qui sort est tiré au sort comme d'habitude : l'achat ne change ni la rareté ni les chances.",
	notDo = "ne change pas les chances et ne donne aucune force", chance = "oui, en partie : ce qui sort des œufs reste aléatoire (tables affichées) ; l'achat ne change pas les chances", limit = "aucune limite", also = { "eggs" },
}
I.EggBagPlus = {
	cat = "base", icon = "r_cadeau", title = "Sac d'œufs +10",
	def = "Ton sac d'œufs passe de 10 à 20 places, pour toujours.",
	detail = "Le sac range les œufs gagnés quand ta base est pleine. Avec ce passe il garde 20 œufs au lieu de 10.",
	notDo = "ne donne aucun œuf et ne protège pas du vol", chance = "non", limit = "achat unique", also = {},
}
I.ExtraSlots = {
	cat = "base", icon = "ui_cadenas", title = "+4 emplacements",
	def = "4 places d'œufs en plus dans ta base, pour toujours (jusqu'à 20).",
	detail = "Ajoute 4 emplacements à ta base, à vie, pour un total de 20 au plus avec toutes les améliorations. Utile quand la base est pleine d'œufs ou de pets.",
	notDo = "ne donne aucun pet, aucune force et ne protège pas du vol", chance = "non", limit = "achat unique", also = {},
}
I.Collector = {
	cat = "base", icon = "ui_etoile", title = "Collectionneur",
	def = "Un pet suiveur de plus (4 au lieu de 3), plus des aides pour ta collection.",
	detail = "Ajoute un pet suiveur (3 passent à 4), des indices de silhouette dans le bestiaire et un cadre doré sur les compteurs de rareté. Rien de tout cela ne change les œufs.",
	notDo = "ne donne aucune force en combat et ne donne aucun pet", chance = "non", limit = "achat unique", also = {},
}
I.VipBase = {
	cat = "base", icon = "ui_bouclier", title = "Base VIP",
	def = "Boucliers d'œufs x2 et bonus quotidien x2, pour toujours.",
	detail = "Les boucliers de tes œufs durent deux fois plus longtemps, et le bonus de pièces de la série quotidienne est doublé. Un bouclier retarde le vol, il ne l'empêche pas indéfiniment.",
	notDo = "n'arrête pas le vol pour toujours et ne donne pas de force en combat", chance = "non", limit = "achat unique", also = {},
}

---------------------------------------------------------------- Combat & vol
I.ArenaTickets = {
	cat = "combat", icon = "r_jeton_combat", title = "Ticket d'arène",
	def = "5 combats de tour de plus aujourd'hui, avec récompenses.",
	detail = "Ajoute 5 combats de tour récompensés pour la journée en cours. Les combats restent équitables : rien ne s'achète qui change les stats des pets.",
	notDo = "ne donne aucune force en combat et ne change pas les adversaires", chance = "non", limit = "aucune limite", also = {},
}
I.Revive = {
	cat = "combat", icon = "ui_coeur", title = "Relance immédiate",
	def = "Au Château : repars tout de suite où tu es tombé, avec tes points de vie.",
	detail = "Points de vie rétablis, 4 s d'invulnérabilité, la défaite n'est pas comptée. Le retour gratuit au début de la salle reste toujours possible. L'offre dure 20 s : c'est la durée réelle de l'écran de défaite.",
	notDo = "ne donne aucune force permanente et ne change pas le Château", chance = "non", limit = "aucune limite", also = {},
}
I.RemoteSteal = {
	cat = "combat", icon = "ui_epee", title = "Corbeau chipeur",
	def = "1 jeton : un corbeau tente de rapporter un œuf d'un joueur du serveur.",
	detail = "Le corbeau vise un œuf en incubation. La victime peut le chasser ; si ça échoue, ton jeton t'est rendu. Règles du vol : 3 vols réussis par jour, protection débutant, bouclier de 5 min après un vol, 20 min de délai par victime, indemnité de 50 % pour la victime. Ton nom de voleur est affiché.",
	notDo = "ne protège de rien (aucun produit de protection n'est vendu) et ne donne aucune force", chance = "oui : la réussite du vol et l'œuf volé dépendent du jeu ; rien n'est promis", limit = "aucune limite", also = {},
}
I.RemoteStealPack = {
	cat = "combat", icon = "ui_epee", title = "3 Corbeaux chipeurs",
	def = "3 jetons de vol à distance.",
	detail = "Trois jetons identiques au Corbeau chipeur, mêmes règles du vol (3 vols réussis par jour, bouclier de 5 min, 20 min de délai par victime, indemnité de 50 %). Un jeton est rendu si la victime chasse le corbeau.",
	notDo = "ne protège de rien (aucun produit de protection n'est vendu) et ne donne aucune force", chance = "oui : la réussite du vol et l'œuf volé dépendent du jeu ; rien n'est promis", limit = "aucune limite", also = {},
}

---------------------------------------------------------------- Passe de combat
I.SeasonPremium = {
	cat = "season", icon = "ui_trophee", title = "Passe de combat premium",
	def = "Débloque la piste premium de la saison en cours : œufs, cosmétiques, un pet exclusif.",
	detail = "Valable pour la saison en cours de 60 jours (thème tournant Feu, Glace, Foudre, Ombre, Nature, Ciel). Les paliers déjà atteints sont crédités une seule fois ; réclamation possible 7 jours après la fin. 30 paliers, XP gagnée en combat et en quêtes. Piste premium : œufs jusqu'à Mythique, une espèce Exclusif FIXE de la saison au palier 30, cosmétiques « Saison N » qui ne reviennent pas. La piste gratuite reste gratuite.",
	notDo = "ne donne aucune force en combat et ne vend pas de niveaux de pets", chance = "non : tout le contenu de chaque palier est affiché ; seuls les pets sortant des œufs gagnés restent tirés au sort", limit = "achat unique par saison", also = { "packs" },
}
I.SeasonUpgradePlus = {
	cat = "season", icon = "ui_trophee", title = "Passe de combat + (suite)",
	def = "Pour qui a déjà le premium : ajoute les 10 paliers immédiats (799 - 399 = 400).",
	detail = "Seulement si tu as DÉJÀ le passe de combat premium cette saison : il ajoute les 10 paliers immédiats sans repayer le premium. Sans le premium, il est caché et refusé.",
	notDo = "ne donne aucune force en combat", chance = "non", limit = "achat unique par saison", also = {},
}
I.SeasonPremiumPlus = {
	cat = "season", icon = "ui_trophee", title = "Passe de combat + 10 paliers",
	def = "Le passe premium plus 10 paliers de saison tout de suite.",
	detail = "Comme le passe premium, avec en plus 10 paliers immédiats (leurs récompenses sont créditées). Pour qui possède déjà le premium, voir « Passe de combat + (suite) ».",
	notDo = "ne donne aucune force en combat", chance = "non : récompenses de paliers affichées", limit = "achat unique par saison", also = { "packs" },
}

---------------------------------------------------------------- Packs
I.StarterPack = {
	cat = "packs", icon = "r_cadeau", title = "Pack de départ",
	def = "Une seule fois : 20 000 pièces, 3 œufs Rares et une potion de chance.",
	detail = "Contient 20 000 pièces, 3 œufs Rares (espèce, taille, mutation tirées au sort, rareté fixe) et une Potion de chance (+25 points, 15 min). Achat unique, à vie.",
	notDo = NO_POWER, chance = "oui : espèces, tailles et mutations des 3 œufs Rares (rareté fixe, affichée)", limit = "achat unique", also = { "eggs" },
}
I.BundleLegend = {
	cat = "packs", icon = "r_coffre", title = "Pack Légende",
	def = "1 œuf Ultra Rare, 3 œufs Légendaires et Double chance 60 minutes.",
	detail = "Contient 1 Œuf Ultra Rare, 3 Œufs Légendaires et 60 min de Double chance (points d'amélioration x2, 70 points au total au plus). Raretés fixes et affichées ; espèces, tailles et mutations tirées au sort. Moins cher que les parties achetées séparément.",
	notDo = NO_POWER, chance = EGG_CHANCE .. " (pour chaque œuf)", limit = "aucune limite", also = { "eggs", "luck" },
}
I.BundleRoyalNoPass = {
	cat = "packs", icon = "r_coffre", title = "Coffre royal sans passe",
	def = "Le Coffre royal pour qui a déjà le passe premium : 2 Ultra Rares, 3 Mythiques.",
	detail = "Complément pour qui possède déjà le passe de combat premium : mêmes œufs que le Coffre royal (2 Œufs Ultra Rares, 3 Œufs Mythiques), sans repayer le passe (1 499 - 399 = 1 100). Caché et refusé sans le passe premium.",
	notDo = NO_POWER, chance = EGG_CHANCE .. " (pour chaque œuf)", limit = "aucune limite", also = { "eggs", "season" },
}
I.BundleRoyal = {
	cat = "packs", icon = "r_coffre", title = "Coffre royal",
	def = "2 œufs Ultra Rares, 3 œufs Mythiques et le passe de combat premium.",
	detail = "Contient 2 Œufs Ultra Rares, 3 Œufs Mythiques et le Passe de combat premium (paliers déjà atteints crédités). Pour qui a déjà le passe premium, ce coffre est remplacé par « Coffre royal sans passe ». Raretés fixes et affichées.",
	notDo = NO_POWER, chance = EGG_CHANCE .. " (pour chaque œuf)", limit = "aucune limite", also = { "eggs", "season" },
}

---------------------------------------------------------------- Cosmétiques
for n = 1, 6 do
	I["EmoteVictory" .. n] = {
		cat = "cosmetics", icon = "r_cosmetique_traine", title = "Pose de victoire " .. n,
		def = "Une animation de victoire pour ton personnage, juste pour le style.",
		detail = "Un geste cosmétique que tu peux jouer après une victoire. Aucun effet sur le jeu. Une fois achetée, elle est à toi pour toujours.",
		notDo = "ne donne aucune force, aucun œuf, aucun bonus", chance = "non", limit = "achat unique", also = {},
	}
end

return I
