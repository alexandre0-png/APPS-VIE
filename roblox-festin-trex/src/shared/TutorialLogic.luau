--!nonstrict
-- Mini tutoriel du premier lancement (logique pure) : 3 étapes déduites de l'état du jeu, sans écran bloquant.
--   1. LANCER   : la munition du panier diminue (un lancer a eu lieu)
--   2. VISER    : la nourriture donnée augmente (le T-Rex a été touché dans la bouche)
--   3. RÉCOLTER : la munition augmente (le panier a été rechargé à un stand)
-- Étape 4 = terminé.

local TutorialLogic = {}
TutorialLogic.__index = TutorialLogic

TutorialLogic.DONE = 4

function TutorialLogic.new()
	return setmetatable({ step = 1, lastAmmo = nil, lastFed = nil }, TutorialLogic)
end

-- snap = { ammo = number, totalFed = number }. Retourne l'étape courante (1..4).
function TutorialLogic.update(self: any, snap: any): number
	if type(snap) ~= "table" or type(snap.ammo) ~= "number" or type(snap.totalFed) ~= "number" then
		return self.step
	end
	if self.lastAmmo == nil then
		self.lastAmmo, self.lastFed = snap.ammo, snap.totalFed
		return self.step
	end
	if self.step == 1 and snap.ammo < self.lastAmmo then
		self.step = 2
	end
	if self.step == 2 and snap.totalFed > self.lastFed then
		self.step = 3
	end
	if self.step == 3 and snap.ammo > self.lastAmmo then
		self.step = TutorialLogic.DONE
	end
	self.lastAmmo, self.lastFed = snap.ammo, snap.totalFed
	return self.step
end

function TutorialLogic.isDone(self: any): boolean
	return self.step >= TutorialLogic.DONE
end

-- Abandon (« Passer le tutoriel »).
function TutorialLogic.skip(self: any)
	self.step = TutorialLogic.DONE
end

return TutorialLogic
