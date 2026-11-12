--!nonstrict
-- Machine d'état du T-Rex (satiété, contributions, festin). Pure : testable hors Studio.

local Config = require(script.Parent.Config)

local DinoCore = {}
DinoCore.__index = DinoCore

export type Core = typeof(setmetatable(
	{} :: { stage: number, satiety: number, contrib: { [number]: number }, feasts: number },
	DinoCore
))

function DinoCore.new(): Core
	return setmetatable({ stage = 1, satiety = 0, contrib = {}, feasts = 0 }, DinoCore)
end

function DinoCore.need(self: Core): number
	return Config.Dino.Stages[self.stage].Need
end

function DinoCore.isHungry(self: Core): boolean
	return self.satiety < self:need() * Config.Dino.HungryFraction
end

-- Ajoute de la satiété. Retourne true si le seuil du festin est atteint.
function DinoCore.add(self: Core, userId: number, amount: number): boolean
	self.satiety += amount
	self.contrib[userId] = (self.contrib[userId] or 0) + amount
	return self.satiety >= self:need()
end

function DinoCore.decay(self: Core, dt: number)
	local loss = self:need() * Config.Dino.DecayPerSecond * dt
	self.satiety = math.max(0, self.satiety - loss)
end

-- Termine le festin : renvoie (contributions, total, stadeTerminé) et prépare le stade suivant.
function DinoCore.completeFeast(self: Core): ({ [number]: number }, number, number)
	local contrib = self.contrib
	local total = 0
	for _, v in pairs(contrib) do
		total += v
	end
	local finished = self.stage
	self.contrib = {}
	self.satiety = 0
	self.feasts += 1
	self.stage = math.min(self.stage + 1, #Config.Dino.Stages)
	return contrib, total, finished
end

return DinoCore
