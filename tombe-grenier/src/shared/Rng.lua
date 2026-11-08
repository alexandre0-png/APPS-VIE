--[[
  Rng : générateur pseudo-aléatoire reproductible (Park-Miller).
  Même seed => même séquence : sert au scintillement des lampes et aux chutes d'objets.
]]
local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 48271

function Rng.new(seed)
	local s = math.floor(math.abs(seed or 1)) % MODULUS
	if s == 0 then
		s = 1
	end
	return setmetatable({ state = s }, Rng)
end

-- Valeur dans [0, 1[
function Rng:next()
	self.state = (self.state * MULTIPLIER) % MODULUS
	return self.state / MODULUS
end

-- Réel dans [a, b[
function Rng:range(a, b)
	return a + (b - a) * self:next()
end

-- Entier dans [a, b] inclus
function Rng:int(a, b)
	return a + math.floor(self:next() * (b - a + 1))
end

return Rng
