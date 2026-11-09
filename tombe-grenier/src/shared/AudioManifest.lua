--[[
  AudioManifest : sons essentiels à l'ambiance, avec les IDs Roblox fournis.

  asset  : identifiant « rbxassetid://… ». Chaîne vide = à fournir (warning, pas de crash).
  volume : volume de base (0 à 1).

  Retirés : verre (aucun son métallique de chute dans la banque), lampe, tiroir, cadenas
  (retours de confort sans valeur d'ambiance). Non retenus : chariot, telephone, generateur, chaise.
]]
return {
	-- Monstre
	cri_capture = { asset = "rbxassetid://72783633167253", volume = 1 },   -- cri de capture, au plus un toutes les ScreamCooldown
	pas         = { asset = "rbxassetid://127992015008072", volume = 0.6 }, -- pas du monstre
	chaines     = { asset = "rbxassetid://97870330505207", volume = 0.7 },  -- début de poursuite

	-- Ambiance
	ambiance      = { asset = "rbxassetid://9112797020", volume = 0.4, looped = true }, -- nappe continue
	cri_loin      = { asset = "rbxassetid://83552831071508", volume = 0.25 },          -- cri lointain, au plus un toutes les 90 s
	porte_grince  = { asset = "rbxassetid://9126144505", volume = 0.6 },              -- grincement de porte
	chaise_grince = { asset = "rbxassetid://9113480360", volume = 0.6 },              -- grincement de chaise

	-- Joueur
	battement   = { asset = "rbxassetid://139481207162657", volume = 0.7 },                 -- battement de cœur (poursuite, sanité basse)
	respiration = { asset = "rbxassetid://91913825089269", volume = 0.5, looped = true },   -- respiration pendant la cachette
	cachette    = { asset = "rbxassetid://17122806607", volume = 0.7 },                     -- placard qui se ferme

	-- Porte
	porte = { asset = "rbxassetid://82228025681045", volume = 0.9 },                       -- débusquage d'un joueur caché

	-- Électricité
	interrupteur = { asset = "rbxassetid://9126027642", volume = 0.7 },                    -- début de coupure
	courant      = { asset = "rbxassetid://17864166117", volume = 0.7 },                   -- fin de coupure
	telephone    = { asset = "rbxassetid://138400380236325", volume = 0.8 }, -- téléphone qui sonne
	lumiere      = { asset = "rbxassetid://136758740736300", volume = 0.4 },               -- rafale d'une lampe

	-- Lampe, clic (lampe torche ; activation et désactivation, sans boucle)
	clic_lampe = { asset = "rbxassetid://6020984334", volume = 0.5 },

	-- Coups et portes
	coups_mur          = { asset = "rbxassetid://92270046821319", volume = 0.7 },   -- trois coups venus du mur au réveil
	grincement_escalier = { asset = "rbxassetid://9126282061", volume = 0.5 },      -- escalier qui grince
	porte_claque       = { asset = "rbxassetid://118084341448393", volume = 0.8 },  -- porte qui claque (réservé)
	portail            = { asset = "rbxassetid://5930776613", volume = 0.7 },       -- grille du jardin qui s'ouvre

	-- Monstre
	grognement   = { asset = "rbxassetid://9125859669", volume = 0.6 },    -- grognement lointain, silhouette
	cri_monstre  = { asset = "rbxassetid://527970724", volume = 0.8 },     -- cri du monstre, apparition
	cri_monstre2 = { asset = "rbxassetid://6305809364", volume = 0.8 },    -- autre cri (réservé)
	poursuite    = { asset = "rbxassetid://9042664292", volume = 0.5, looped = true }, -- musique de poursuite, tant que le monstre chasse

	-- Ambiance et peur
	ambiance_longue  = { asset = "rbxassetid://125578417483849", volume = 0.3 }, -- nappe longue (réservé)
	ambiance_tension = { asset = "rbxassetid://2893921424", volume = 0.3, looped = true }, -- tension : sanité basse, hors poursuite
	stinger_peur     = { asset = "rbxassetid://1835337231", volume = 0.7 },     -- coup de tension au sursaut

	-- Sons fournis (mai 2026) : voix, tableau, jouet, ventilation, téléphone ancien
	voix_enfant     = { asset = "rbxassetid://125258912434748", volume = 0.6 }, -- voix d'enfant qui appelle au secours (cave)
	tableau_tombe   = { asset = "rbxassetid://125306982616721", volume = 0.8 }, -- tableau qui tombe
	poupee_bouge    = { asset = "rbxassetid://76611190936817", volume = 0.5 },  -- jouet qui bouge
	ventilation     = { asset = "rbxassetid://11237231494", volume = 0.4 },     -- courant d'air de la trappe

	-- Statique (télévision, réservé)
	statique_tv    = { asset = "rbxassetid://4903742660", volume = 0.5 },
	statique_vhs   = { asset = "rbxassetid://81486637394198", volume = 0.5 },
	statique_court = { asset = "rbxassetid://123255788767106", volume = 0.5 },
}
