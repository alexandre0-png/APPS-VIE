--!nonstrict
-- Énigme du jour (QCM) : logique pure. Les bonnes réponses ne sont PAS dans le code partagé
-- (elles restent côté serveur, passées en paramètre) pour qu'un client ne puisse pas les lire.

local Config = require(script.Parent.Config)

local RiddleLogic = {}

function RiddleLogic.index(day: number): number
	return (math.floor(day) % #Config.Riddles) + 1
end

-- État du jour sans modifier les données : (index, résolue, essaisRestants)
function RiddleLogic.status(data: any, day: number): (number, boolean, number)
	local r = data.riddle
	if r.day ~= day then
		return RiddleLogic.index(day), false, Config.RiddleTries
	end
	return RiddleLogic.index(day), r.solved == true, math.max(0, Config.RiddleTries - r.tries)
end

-- Tente une réponse. Retourne ("correct" | "wrong" | "error", message).
function RiddleLogic.answer(data: any, day: number, choice: any, answers: { number }): (string, string)
	if type(choice) ~= "number" or choice % 1 ~= 0 or choice < 1 or choice > 4 then
		return "error", "Réponse invalide"
	end
	local r = data.riddle
	if r.day ~= day then
		r.day, r.solved, r.tries = day, false, 0
	end
	if r.solved then
		return "error", "Énigme déjà résolue aujourd'hui. Reviens demain !"
	end
	if r.tries >= Config.RiddleTries then
		return "error", "Plus d'essais aujourd'hui. Reviens demain !"
	end
	local index = RiddleLogic.index(day)
	if answers[index] == choice then
		r.solved = true
		return "correct", "Bonne réponse !"
	end
	r.tries += 1
	return "wrong", string.format("Raté ! Il te reste %d essai(s).", Config.RiddleTries - r.tries)
end

return RiddleLogic
