--[[
  HubRules : règles de lancement du hub (sans objet Roblox : testées en Python).
  - Solo : lancement dès la borne « Partie solo », avec les joueurs présents.
  - Duo : attend un second joueur, au plus Config.Game.DuoWait secondes, puis lance en solo.
  - Sans borne : lancement après Config.Game.HubWait secondes à partir de l'arrivée du premier joueur.
]]
local HubRules = {}

-- Mode demandé par une borne : "solo", "duo", ou nil (aucune borne pressée)
function HubRules.shouldLaunch(mode, present, waited, cfg)
	if present <= 0 then
		return false
	end
	if mode == "solo" then
		return true
	end
	if mode == "duo" then
		return present >= 2 or waited >= cfg.DuoWait
	end
	return waited >= cfg.HubWait
end

-- Mode de la partie lancée : duo si deux joueurs ou plus, sinon solo
function HubRules.groupMode(count)
	return count >= 2 and "duo" or "solo"
end

-- Texte de file d'attente affiché au-dessus d'une borne
function HubRules.queueText(label, count, needed)
	return ("%s : %d/%d en attente"):format(label, count, needed)
end

return HubRules
