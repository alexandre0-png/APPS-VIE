--[[
  Opening : les dix premières secondes (logique pure, testée). Promesse claire dès le réveil, puis première action
  jouable immédiate : à la fin du réveil, une consigne simple désigne ce qu'il faut faire (l'objet qui brille).
]]
local Opening = {}

Opening.PROMISE = "SORS DU GRENIER AVEC L'ENFANT"
Opening.GAME_NAME = "La Tombe du Grenier"

-- Chronologie : liste d'événements { at, kind, title, text, duration }. wakeDuration : durée du réveil (Config.Intro.Duration).
function Opening.plan(wakeDuration, firstObjective)
	local wake = wakeDuration or 8
	local events = {
		{
			at = 0.4,
			kind = "title",
			title = Opening.PROMISE,
			text = Opening.GAME_NAME,
			duration = math.min(4.2, wake - 1),
		},
		-- à la fin du réveil : la première action, tout de suite
		{
			at = wake,
			kind = "action",
			title = "À TOI DE JOUER",
			text = "Approche-toi de l'objet qui brille et maintiens le bouton d'action.",
			duration = 6,
		},
	}
	if firstObjective and firstObjective ~= "" then
		table.insert(
			events,
			{ at = wake + 0.5, kind = "objective", title = "OBJECTIF", text = firstObjective, duration = 6 }
		)
	end
	return events
end

-- Instant du premier événement jouable (consigne d'action)
function Opening.firstActionAt(events)
	for _, e in ipairs(events) do
		if e.kind == "action" then
			return e.at
		end
	end
	return nil
end

return Opening
