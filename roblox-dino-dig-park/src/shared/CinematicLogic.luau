-- CinematicLogic.luau : séquencement pur des cinématiques (aucune API Roblox, entièrement testable).
-- Un plan = liste de plans de caméra : { dur, from = {x,y,z}, to = {x,y,z}, look0 = {x,y,z}, look1 = {x,y,z}, caption }
-- La caméra va de `from` à `to` en regardant de `look0` vers `look1` pendant `dur` secondes.

local CinematicLogic = {}

local function lerp3(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

local function ease(t)
	return -(math.cos(math.pi * t) - 1) / 2
end

function CinematicLogic.totalDuration(shots)
	local total = 0
	for _, s in ipairs(shots) do
		total = total + s.dur
	end
	return total
end

-- Valide un plan : retourne true ou false + raison
function CinematicLogic.validate(shots, minSeconds, maxSeconds)
	if type(shots) ~= "table" or #shots == 0 then
		return false, "aucun plan"
	end
	for i, s in ipairs(shots) do
		if type(s.dur) ~= "number" or s.dur <= 0 or s.dur ~= s.dur then
			return false, "durée invalide au plan " .. i
		end
		for _, k in ipairs({ "from", "to", "look0", "look1" }) do
			local v = s[k]
			if type(v) ~= "table" or #v ~= 3 then
				return false, "point " .. k .. " invalide au plan " .. i
			end
		end
	end
	local total = CinematicLogic.totalDuration(shots)
	if minSeconds and total < minSeconds then
		return false, "trop court"
	end
	if maxSeconds and total > maxSeconds then
		return false, "trop long"
	end
	return true
end

-- Échantillon à l'instant t : { idx, alpha, pos, look, caption, finished }
function CinematicLogic.sample(shots, t)
	local total = CinematicLogic.totalDuration(shots)
	if #shots == 0 then
		return { idx = 0, alpha = 1, finished = true }
	end
	if t >= total then
		local last = shots[#shots]
		return { idx = #shots, alpha = 1, pos = last.to, look = last.look1, caption = last.caption, finished = true }
	end
	if t < 0 then
		t = 0
	end
	local acc = 0
	for i, s in ipairs(shots) do
		if t < acc + s.dur then
			local a = ease((t - acc) / s.dur)
			return {
				idx = i,
				alpha = a,
				pos = lerp3(s.from, s.to, a),
				look = lerp3(s.look0, s.look1, a),
				caption = s.caption,
				finished = false,
			}
		end
		acc = acc + s.dur
	end
	return { idx = #shots, alpha = 1, finished = true }
end

-- État de lecture : permet skip et reprise propre
function CinematicLogic.new(shots)
	return { shots = shots, t = 0, finished = #shots == 0, skipped = false }
end

function CinematicLogic.step(state, dt)
	if state.finished then
		return CinematicLogic.sample(state.shots, state.t)
	end
	if type(dt) == "number" and dt > 0 and dt == dt then
		state.t = state.t + math.min(dt, 0.25) -- un gros à-coup d'image ne fait pas sauter de plan
	end
	local snap = CinematicLogic.sample(state.shots, state.t)
	if snap.finished then
		state.finished = true
	end
	return snap
end

function CinematicLogic.skip(state)
	state.skipped = true
	state.finished = true
end

return CinematicLogic
