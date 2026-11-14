--[[
  SpawnGate : porte d'apparition des personnages (logique pure, testée).
  Tant que la carte et un point d'apparition actif n'existent pas, aucun personnage n'est chargé :
  les demandes sont mises en file, puis relâchées dans l'ordre à l'ouverture. Une demande par joueur
  (la dernière position demandée l'emporte). Sert à Respawn.lua.
]]
local SpawnGate = {}
SpawnGate.__index = SpawnGate

function SpawnGate.new()
	return setmetatable({ open = false, queue = {}, order = {} }, SpawnGate)
end

-- Demande un chargement. Renvoie true si on peut charger tout de suite, false si la demande est en file.
function SpawnGate:request(player, pos)
	if self.open then
		return true
	end
	if self.queue[player] == nil then
		table.insert(self.order, player)
	end
	self.queue[player] = { pos = pos }
	return false
end

-- Ouvre la porte. Renvoie les demandes en attente, dans l'ordre : { { player, pos }, ... }
function SpawnGate:release()
	self.open = true
	local out = {}
	for _, player in ipairs(self.order) do
		local entry = self.queue[player]
		if entry then
			table.insert(out, { player = player, pos = entry.pos })
		end
	end
	self.queue = {}
	self.order = {}
	return out
end

-- Un joueur parti n'est plus attendu
function SpawnGate:forget(player)
	self.queue[player] = nil
end

-- Vrai si une hauteur est sous le sol de la carte (le personnage tombe dans le vide)
function SpawnGate.belowFloor(y, voidY)
	return y < voidY
end

-- Faut-il replacer le personnage ? state = { y, age (secondes depuis l'apparition), freefall (secondes de
-- chute libre en cours) }. Oui s'il est sous le sol de la carte, ou en chute libre depuis plus de
-- freefallSeconds pendant les earlyWindow premières secondes. Renvoie (vrai, raison) ou (faux).
function SpawnGate.shouldRescue(state, cfg)
	if SpawnGate.belowFloor(state.y, cfg.VoidY) then
		return true, "sous le sol"
	end
	if state.age <= cfg.EarlyWindow and state.freefall > cfg.FreefallSeconds then
		return true, "chute libre"
	end
	return false
end

return SpawnGate
