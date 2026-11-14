--[[
  Tutorial : trois indices contextuels au premier lancement, jamais bloquants. Chacun s'affiche une
  seule fois, au bon moment, avec un délai minimal entre deux. Logique pure, testée.
  ctx = { elapsed (s de partie), now (s), quietUsed, hidden (s'est déjà caché), chased, battery (0 à 100) }
  state = { shown = { [id] = true }, lastAt = nil }
]]
local Tutorial = {}

Tutorial.HINTS = {
	{ id = "quiet", text = "Astuce : maintiens Ctrl pour avancer sans bruit. Le monstre entend tes pas.",
	  when = function(ctx, cfg) return ctx.elapsed >= cfg.QuietAfter and not ctx.quietUsed end },
	{ id = "hide", text = "Astuce : une armoire ou un lit peut te cacher. Approche-toi, puis interagis.",
	  when = function(ctx, cfg) return ctx.chased and not ctx.hidden end },
	{ id = "lamp", text = "Astuce : ta lampe (F) se vide. Cherche des piles, ou éteins-la quand tu es à l'abri.",
	  when = function(ctx, cfg) return ctx.battery <= cfg.LampBattery end },
}

function Tutorial.newState()
	return { shown = {}, lastAt = nil }
end

-- Prochain indice à montrer (table) ou nil. Marque l'indice comme montré.
function Tutorial.next(cfg, state, ctx)
	if not cfg.Enabled then
		return nil
	end
	if state.lastAt and ctx.now - state.lastAt < cfg.Cooldown then
		return nil
	end
	for _, h in ipairs(Tutorial.HINTS) do
		if not state.shown[h.id] and h.when(ctx, cfg) then
			state.shown[h.id] = true
			state.lastAt = ctx.now
			return h
		end
	end
	return nil
end

function Tutorial.done(state)
	for _, h in ipairs(Tutorial.HINTS) do
		if not state.shown[h.id] then
			return false
		end
	end
	return true
end

return Tutorial
