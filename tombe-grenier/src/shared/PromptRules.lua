--[[
  PromptRules : règles des invites d'interaction (logique pure, testée). Une invite ne s'affiche que dans la partie, près
  de son objet (Config.Prompts.MaxDistance), en vue directe, et seulement si l'étape de son objet est accessible.
]]
local PromptRules = {}

-- Distance d'activation : celle demandée, jamais au-delà de la portée maximale
function PromptRules.distance(requested, max)
	max = max or 8
	if type(requested) ~= "number" or requested ~= requested or requested <= 0 then
		return max
	end
	return math.min(requested, max)
end

-- Une invite est active quand la partie tourne, que l'objet est voulu actif, et que son étape est accessible
-- (étape inconnue ou absente = objet libre : toujours accessible).
function PromptRules.shouldBeEnabled(roundActive, wanted, step, canAct)
	if not roundActive or not wanted then
		return false
	end
	if step == nil or canAct == nil then
		return true
	end
	return canAct(step) == true
end

return PromptRules
