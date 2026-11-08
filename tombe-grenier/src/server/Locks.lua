--[[
  Locks : verrous de pièces, ouverts par une énigme résolue plus tôt dans la partie.
  Une porte porte l'attribut Lock (nom du verrou). Tant que le verrou n'est pas ouvert,
  la porte reste fermée, et le monstre ne la pousse pas.
  Remis à zéro à chaque partie (Quests.setup).
]]
local Locks = {}

-- Message affiché quand on tente d'ouvrir une porte verrouillée
local HINTS = {
	["cahier"] = "Fermée. Un cahier d'écolier doit t'apprendre quelque chose : il traîne quelque part, pas ici.",
	["salle de bain"] = "Fermée à clé. La clé est peut-être dans le bureau, ou dans la chambre des parents.",
	["bureau"] = "Verrouillée. Il faut d'abord rassembler les trois souvenirs.",
	["cellier"] = "Verrouillée électriquement. Le courant doit revenir.",
}

local opened = {}

function Locks.reset()
	opened = {}
end

function Locks.open(name)
	opened[name] = true
end

function Locks.isOpen(name)
	return opened[name] == true
end

function Locks.hint(name)
	return HINTS[name] or "Verrouillée."
end

return Locks
