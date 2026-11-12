--!nonstrict
-- Garde-fou des animations : commutateur Config.Animations, exécution protégée par pcall.
-- Une animation qui échoue est désactivée pour la session (jamais d'erreur en boucle) et signalée une fois.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AnimLogic = require(Shared.AnimLogic)

local AnimGuard = {}

local broken = {}

function AnimGuard.Enabled(key)
	return not broken[key] and AnimLogic.Enabled(Config.Animations, key)
end

-- Exécute fn(...) si l'animation `key` est active. Renvoie (ok, résultat).
function AnimGuard.Run(key, fn, ...)
	if not AnimGuard.Enabled(key) then
		return false
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		broken[key] = true
		warn(("[Animations] « %s » désactivée après erreur : %s"):format(key, tostring(result)))
		return false
	end
	return true, result
end

function AnimGuard.IsBroken(key)
	return broken[key] == true
end

return AnimGuard
