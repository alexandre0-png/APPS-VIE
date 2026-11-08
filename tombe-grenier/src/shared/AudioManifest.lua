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
}
