--[[
  HubRules : règles de lancement du hub (sans objet Roblox : testées en Python).
  - Solo : lancement dès la borne « Partie solo », avec les joueurs présents.
  - Duo : attend un second joueur, au plus Config.Game.DuoWait secondes, puis lance en solo.
  - Sans borne : aucun lancement tout seul (Config.Game.AutoStart = false) : la partie ne démarre que par une plaque.
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
	return cfg.AutoStart == true and waited >= cfg.HubWait
end

-- File d'attente par borne. players : { { id, joinedAt, queue = "solo" | "duo" | nil, queuedAt } }.
-- Retourne la liste des identifiants du prochain groupe à lancer (au plus cfg.MaxPlayers), ou nil :
--  1. Un joueur en file solo part seul, tout de suite (les autres ne sont pas entraînés avec lui).
--  2. Deux joueurs en file duo partent ensemble ; un seul attend cfg.DuoWait secondes, puis part en solo.
--  3. Sans borne : personne ne part (cfg.AutoStart = false) ; avec AutoStart = true, le plus ancien part après
--     cfg.HubWait secondes, avec le suivant s'il attend aussi (duo).
function HubRules.nextGroup(players, now, cfg)
	local solo, duo, free = {}, {}, {}
	for _, p in ipairs(players) do
		if p.queue == "solo" then
			table.insert(solo, p)
		elseif p.queue == "duo" then
			table.insert(duo, p)
		else
			table.insert(free, p)
		end
	end
	local function order(list, key)
		table.sort(list, function(a, b)
			if a[key] ~= b[key] then
				return a[key] < b[key]
			end
			return a.id < b.id
		end)
	end
	order(solo, "queuedAt")
	order(duo, "queuedAt")
	order(free, "joinedAt")
	local cap = cfg.MaxPlayers or 2
	if #solo > 0 then
		return { solo[1].id }
	end
	if #duo >= 2 and cap >= 2 then
		return { duo[1].id, duo[2].id }
	end
	if #duo == 1 and now - duo[1].queuedAt >= cfg.DuoWait then
		return { duo[1].id }
	end
	if cfg.AutoStart == true and #free > 0 and now - free[1].joinedAt >= cfg.HubWait then
		local group = { free[1].id }
		if free[2] and cap >= 2 then
			table.insert(group, free[2].id)
		end
		return group
	end
	return nil
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
