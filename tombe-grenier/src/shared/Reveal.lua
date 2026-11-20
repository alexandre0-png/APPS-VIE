--[[
  Reveal : texte et durée de la révélation affichée quand une étape de la chaîne se termine (pure, testée).
]]
local Reveal = {}

function Reveal.title(n, total)
	if n >= total then
		return ("ÉTAPE %d SUR %d : DERNIÈRE LIGNE DROITE"):format(n, total)
	end
	return ("ÉTAPE %d SUR %d"):format(n, total)
end

-- Durée d'affichage : brève, plus longue pour la dernière étape
function Reveal.duration(n, total)
	return n >= total and 3.2 or 2.2
end

-- Couleur de la bannière : vert à chaque étape, bleu à la dernière (sauver l'enfant)
function Reveal.role(n, total)
	return n >= total - 1 and "save" or "play"
end

return Reveal
