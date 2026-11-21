--[[
  Guard : validation des données reçues du client et limiteur de fréquence (logique pure, testée hors Roblox).
  Tout ce qui arrive par un RemoteEvent est du texte non fiable : type, plage, longueur et fréquence se vérifient côté serveur.
]]
local Guard = {}

-- Nombre fini (ni NaN, ni infini)
function Guard.isFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Guard.isString(v)
	return typeof(v) == "string" and #v <= 40
end

function Guard.isBoolean(v)
	return type(v) == "boolean"
end

-- Vecteur (champs X, Y, Z finis) de norme 1 à tolérance près
function Guard.isUnitVector(v, tolerance)
	if v == nil then
		return false
	end
	local ok, x, y, z = pcall(function()
		return v.X, v.Y, v.Z
	end)
	if not ok or not (Guard.isFinite(x) and Guard.isFinite(y) and Guard.isFinite(z)) then
		return false
	end
	return math.abs(math.sqrt(x * x + y * y + z * z) - 1) <= (tolerance or 0.05)
end

-- Texte court sans caractère de contrôle ; nil si le type ou la longueur est mauvais
function Guard.cleanText(s, maxLen)
	if type(s) ~= "string" or #s > maxLen then
		return nil
	end
	if s:find("%c") then
		return nil
	end
	return s
end

-- Limiteur à jetons : rate jetons par seconde, burst jetons au plus. allow(clé) consomme un jeton.
-- clock() donne le temps en secondes (os.clock côté Roblox, horloge virtuelle dans les tests).
function Guard.newLimiter(rate, burst, clock)
	local buckets = {}
	local limiter = {}
	function limiter.allow(key)
		local now = clock()
		local b = buckets[key]
		if not b then
			b = { tokens = burst, at = now }
			buckets[key] = b
		end
		b.tokens = math.min(burst, b.tokens + (now - b.at) * rate)
		b.at = now
		if b.tokens >= 1 then
			b.tokens -= 1
			return true
		end
		return false
	end
	function limiter.forget(key)
		buckets[key] = nil
	end
	function limiter.size()
		local n = 0
		for _ in pairs(buckets) do
			n += 1
		end
		return n
	end
	return limiter
end

return Guard
