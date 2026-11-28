-- ModuleScript : ReplicatedStorage/Shared/Spawn
-- Décisions PURES du filet anti-chute et de la garantie de personnage (testées hors Roblox). Le module SpawnGuard les applique.
local Spawn = {}

-- Réglages par rôle. floorY : en dessous, le joueur est tombé hors du monde. half : demi-côté de la zone jouable (au-delà : hors zone).
-- freefallSpeed : vitesse verticale (studs/s, négative) au-delà de laquelle une chute au-dessus du sol est anormale.
Spawn.PRESETS = {
	game = { floorY = -25, half = 590, freefallSpeed = -160, freefallY = 40, noCharTimeout = 10, sky = 400 },
	hub = { floorY = -25, half = 205, freefallSpeed = -160, freefallY = 40, noCharTimeout = 10, sky = 140 },
}

-- st = { hasChar, alive, waited, x, y, z, vy } ; waited = secondes sans personnage. Retourne nil ou une raison :
-- "nochar" (aucun personnage depuis trop longtemps), "void" (sous le sol), "freefall" (chute libre), "outside" (hors de la zone), "sky" (trop haut).
function Spawn.rescueReason(st, cfg)
	if not st.hasChar then
		if (st.waited or 0) >= cfg.noCharTimeout then
			return "nochar"
		end
		return nil
	end
	if st.alive == false or st.y == nil then
		return nil
	end
	if st.y ~= st.y or (st.x or 0) ~= (st.x or 0) or (st.z or 0) ~= (st.z or 0) then
		return "void" -- NaN : position corrompue
	end
	if st.y < cfg.floorY then
		return "void"
	end
	if math.abs(st.x or 0) > cfg.half or math.abs(st.z or 0) > cfg.half then
		return "outside"
	end
	if st.y > cfg.sky then
		return "sky"
	end
	if (st.vy or 0) < cfg.freefallSpeed and st.y < cfg.freefallY then
		return "freefall"
	end
	return nil
end

-- Compteurs de sauvetages : une boucle de sauvetages (> maxPerMinute) est signalée pour ne pas masquer un vrai bug.
function Spawn.newTally()
	local t = { counts = {}, total = 0, times = {} }
	function t.add(kind, now)
		t.counts[kind] = (t.counts[kind] or 0) + 1
		t.total = t.total + 1
		t.times[#t.times + 1] = now
		while #t.times > 0 and now - t.times[1] > 60 do
			table.remove(t.times, 1)
		end
		return #t.times
	end
	return t
end

return Spawn
