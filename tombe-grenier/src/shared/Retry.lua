--[[
  Retry : réessaie une opération qui peut échouer (téléportation, réservation de serveur) avec des pauses croissantes.
  Logique pure : sleep est fourni (task.wait côté Roblox, horloge virtuelle dans les tests).
]]
local Retry = {}

-- fn() réussit si elle ne lève pas d'erreur et ne renvoie pas false. delays = pauses avant chaque nouvel essai.
-- Retourne ok, nombre d'essais, dernière erreur.
function Retry.run(fn, delays, sleep)
	local attempts = 0
	local lastErr = nil
	for i = 0, #delays do
		if i > 0 then
			sleep(delays[i])
		end
		attempts += 1
		local ok, result = pcall(fn, attempts)
		if ok and result ~= false then
			return true, attempts, nil
		end
		lastErr = ok and "refusé" or tostring(result)
	end
	return false, attempts, lastErr
end

return Retry
