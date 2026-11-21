--[[
  AudioManifest : sons essentiels à l'ambiance, avec les IDs Roblox fournis.

  asset  : identifiant « rbxassetid://… ». Chaîne vide = à fournir (warning, pas de crash).
  volume : volume de base (0 à 1).

  Retirés : verre (aucun son métallique de chute dans la banque), lampe, tiroir, cadenas
  (retours de confort sans valeur d'ambiance). Non retenus : chariot, telephone, generateur, chaise.
]]
return {
	-- Monstre
	cri_capture = { asset = "rbxassetid://72783633167253", volume = 1 }, -- cri de capture, au plus un toutes les ScreamCooldown
	pas = { asset = "rbxassetid://127992015008072", volume = 0.6 }, -- pas du monstre
	chaines = { asset = "rbxassetid://97870330505207", volume = 0.7 }, -- début de poursuite

	-- Ambiance
	ambiance = { asset = "rbxassetid://9112797020", volume = 0.4, looped = true, prefer = "ambiance_grenier" }, -- nappe continue
	cri_loin = { asset = "rbxassetid://83552831071508", volume = 0.25 }, -- cri lointain, au plus un toutes les 90 s
	porte_grince = { asset = "rbxassetid://9126144505", volume = 0.6, prefer = "grincement_porte" }, -- grincement de porte
	chaise_grince = { asset = "rbxassetid://9113480360", volume = 0.6 }, -- grincement de chaise

	-- Joueur
	battement = { asset = "rbxassetid://139481207162657", volume = 0.7 }, -- battement de cœur (poursuite, sanité basse)
	respiration = { asset = "rbxassetid://91913825089269", volume = 0.5, looped = true }, -- respiration pendant la cachette
	cachette = { asset = "rbxassetid://17122806607", volume = 0.7 }, -- placard qui se ferme

	-- Porte
	porte = { asset = "rbxassetid://82228025681045", volume = 0.9 }, -- débusquage d'un joueur caché

	-- Électricité
	interrupteur = { asset = "rbxassetid://9126027642", volume = 0.7 }, -- début de coupure
	courant = { asset = "rbxassetid://17864166117", volume = 0.7 }, -- fin de coupure
	telephone = { asset = "rbxassetid://138400380236325", volume = 0.8 }, -- téléphone qui sonne
	lumiere = { asset = "rbxassetid://136758740736300", volume = 0.4 }, -- rafale d'une lampe

	-- Lampe, clic (lampe torche ; activation et désactivation, sans boucle)
	clic_lampe = { asset = "rbxassetid://6020984334", volume = 0.5 },

	-- Coups et portes
	coups_mur = { asset = "rbxassetid://92270046821319", volume = 0.7 }, -- trois coups venus du mur au réveil
	grincement_escalier = { asset = "rbxassetid://9126282061", volume = 0.5 }, -- escalier qui grince
	porte_claque = { asset = "rbxassetid://118084341448393", volume = 0.8 }, -- porte qui claque (réservé)
	portail = { asset = "rbxassetid://5930776613", volume = 0.7 }, -- grille du jardin qui s'ouvre

	-- Monstre
	grognement = { asset = "rbxassetid://9125859669", volume = 0.6 }, -- grognement lointain, silhouette
	cri_monstre = { asset = "rbxassetid://527970724", volume = 0.8, prefer = "sting_monstre" }, -- cri du monstre, apparition
	cri_monstre2 = { asset = "rbxassetid://6305809364", volume = 0.8 }, -- autre cri (réservé)
	poursuite = { asset = "rbxassetid://9042664292", volume = 0.5, looped = true }, -- musique de poursuite, tant que le monstre chasse

	-- Ambiance et peur
	ambiance_longue = { asset = "rbxassetid://125578417483849", volume = 0.3, looped = true, prefer = "vent_grenier" }, -- nappe longue de fond, pendant la partie
	ambiance_tension = { asset = "rbxassetid://2893921424", volume = 0.3, looped = true }, -- tension : sanité basse, hors poursuite
	stinger_peur = { asset = "rbxassetid://1835337231", volume = 0.7 }, -- coup de tension au sursaut

	-- Sons fournis (mai 2026) : voix, tableau, jouet, ventilation, téléphone ancien
	voix_enfant = { asset = "rbxassetid://125258912434748", volume = 0.6 }, -- voix d'enfant qui appelle au secours (cave)
	tableau_tombe = { asset = "rbxassetid://125306982616721", volume = 0.8 }, -- tableau qui tombe
	poupee_bouge = { asset = "rbxassetid://76611190936817", volume = 0.5 }, -- jouet qui bouge
	ventilation = { asset = "rbxassetid://11237231494", volume = 0.4 }, -- courant d'air de la trappe

	-- Sons synthétiques (ogg, lot 4) : utilisés seulement quand leur asset se charge (`prefer` sur l'ancien son, ou
	-- directement par les contrôleurs de la boucle de jeu). new = true : préchargés au démarrage, en arrière-plan.
	ambiance_grenier = { asset = "rbxassetid://70845517493066", volume = 0.3, looped = true, new = true },
	vent_grenier = { asset = "rbxassetid://119514716471672", volume = 0.25, looped = true, new = true }, -- 6 s
	murmure = { asset = "rbxassetid://119844783294265", volume = 0.35, looped = true, new = true }, -- 5 s, monstre proche
	chuchotement = { asset = "rbxassetid://97685445181857", volume = 0.5, new = true }, -- 3 s, indices et événements
	sting_monstre = { asset = "rbxassetid://123098158629366", volume = 0.7, new = true }, -- apparition, poursuite
	battement_coeur = { asset = "rbxassetid://134398301938123", volume = 0.7, looped = true, new = true },
	pas_bois = { asset = "rbxassetid://71222524066643", volume = 0.5, new = true },
	pas_courses = { asset = "rbxassetid://130512281096828", volume = 0.6, new = true },
	marche_escalier = { asset = "rbxassetid://80053909075631", volume = 0.5, new = true },
	grincement_porte = { asset = "rbxassetid://72276002070833", volume = 0.6, new = true },
	porte_verrouillee = { asset = "rbxassetid://95280236603158", volume = 0.6, new = true },
	cle_ramassee = { asset = "rbxassetid://94023442831959", volume = 0.6, new = true },
	coffre_ouvre = { asset = "rbxassetid://120351652437677", volume = 0.65, new = true },
	horloge_tic = { asset = "rbxassetid://72367631338816", volume = 0.4, looped = true, new = true },

	-- Statique (télévision, réservé)
	statique_tv = { asset = "rbxassetid://4903742660", volume = 0.5 },
	statique_vhs = { asset = "rbxassetid://81486637394198", volume = 0.5 },
	statique_court = { asset = "rbxassetid://123255788767106", volume = 0.5 },
}
