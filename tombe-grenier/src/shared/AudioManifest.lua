--[[
  AudioManifest : clés audio du jeu, avec les IDs Roblox fournis.

  asset  : identifiant « rbxassetid://… ». Chaîne vide = à fournir (warning, pas de crash).
  volume : volume de base (0 à 1).

  Sons non retenus (inutiles à ce jeu) : chariot, telephone, generateur, chaise.
]]
return {
	-- Monstre
	cri_capture = { asset = "rbxassetid://72783633167253", volume = 1 },   -- cri quand le monstre attrape un joueur
	pas         = { asset = "rbxassetid://127992015008072", volume = 0.6 }, -- pas du monstre
	chaines     = { asset = "rbxassetid://97870330505207", volume = 0.7 },  -- poursuite

	-- Ambiance
	cri_loin     = { asset = "rbxassetid://83552831071508", volume = 0.25 }, -- cri lointain, au plus un toutes les 90 s
	porte_grince = { asset = "rbxassetid://9126144505", volume = 0.6 },     -- bruit d'ambiance
	chaise_grince = { asset = "rbxassetid://9113480360", volume = 0.6 },    -- bruit d'ambiance
	ambiance     = { asset = "rbxassetid://9112797020", volume = 0.4, looped = true }, -- nappe continue

	-- Joueur
	battement  = { asset = "rbxassetid://139481207162657", volume = 0.7 },  -- battement de cœur (poursuite, sanité basse)
	respiration = { asset = "rbxassetid://91913825089269", volume = 0.5, looped = true }, -- joueur caché
	lampe      = { asset = "rbxassetid://116266785932124", volume = 0.5 },  -- lampe torche
	cachette   = { asset = "rbxassetid://17122806607", volume = 0.7 },      -- placard qui se ferme

	-- Objets, portes, objectifs
	porte    = { asset = "rbxassetid://82228025681045", volume = 0.9 },     -- porte qui claque (débusquage)
	verre    = { asset = "rbxassetid://138817960173178", volume = 0.8 },    -- objet qui tombe et casse
	tiroir   = { asset = "rbxassetid://1910795334", volume = 0.6 },         -- clé trouvée
	cadenas  = { asset = "rbxassetid://6652808984", volume = 0.8 },         -- sortie déverrouillée

	-- Électricité
	interrupteur = { asset = "rbxassetid://9126027642", volume = 0.7 },     -- début de coupure
	courant      = { asset = "rbxassetid://17864166117", volume = 0.7 },    -- fin de coupure
	lumiere      = { asset = "rbxassetid://136758740736300", volume = 0.4 }, -- lampe qui s'allume par rafale
}
