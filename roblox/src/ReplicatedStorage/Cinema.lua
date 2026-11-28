-- ModuleScript : ReplicatedStorage/Shared/Cinema
-- Logique PURE des cinématiques (aucun service Roblox, aucune Instance) : séquences de plans, lecteur à états (lecture, skip, abandon,
-- reprise), interpolation de caméra, directeur qui enchaîne une file. Easing est injecté : require(Cinema).new(Easing).
-- Le client (Cinematics.client.lua) ne fait qu'appliquer ces valeurs à la caméra.
local Cinema = {}

function Cinema.new(Easing)
	local C = {}

	-- Construit une séquence à partir de { id, shots = { { dur = secondes, ... }, ... } }.
	-- Retourne nil et un message si la définition est invalide (aucun plan, durée <= 0).
	function C.sequence(def)
		if type(def) ~= "table" or type(def.shots) ~= "table" or #def.shots == 0 then
			return nil, "aucun plan"
		end
		local starts, t = {}, 0
		for i, shot in ipairs(def.shots) do
			if type(shot.dur) ~= "number" or shot.dur <= 0 then
				return nil, "durée invalide (plan " .. i .. ")"
			end
			starts[i] = t
			t = t + shot.dur
		end
		return { id = def.id, shots = def.shots, starts = starts, total = t }
	end

	-- Plan actif à l'instant t (secondes depuis le début) : (index, progression dans [0, 1[), ou nil si la séquence est terminée.
	-- Un temps négatif est ramené à 0.
	function C.shotAt(seq, t)
		if t < 0 then
			t = 0
		end
		if t >= seq.total then
			return nil
		end
		for i = #seq.shots, 1, -1 do
			if t >= seq.starts[i] then
				return i, (t - seq.starts[i]) / seq.shots[i].dur
			end
		end
		return 1, 0
	end

	local function lerp3(a, b, e)
		return { a[1] + (b[1] - a[1]) * e, a[2] + (b[2] - a[2]) * e, a[3] + (b[3] - a[3]) * e }
	end

	-- Position et point visé de la caméra pour la progression p du plan (repère de l'ancre), avec adoucissement.
	function C.cameraAt(shot, p)
		local e = Easing.inOutSine(Easing.clamp01(p))
		return lerp3(shot.pos, shot.toPos or shot.pos, e), lerp3(shot.look, shot.toLook or shot.look, e)
	end

	-- Lecteur d'une séquence. États : idle -> playing -> done (raison : completed | skipped | aborted). play() redémarre à zéro (reprise).
	function C.player(seq)
		local P = { state = "idle", reason = nil, startedAt = 0, lastShot = 0 }
		function P.play(now)
			P.state, P.reason, P.startedAt, P.lastShot = "playing", nil, now, 0
		end
		function P.isPlaying()
			return P.state == "playing"
		end
		-- À appeler à chaque image. nil si rien ne joue ; sinon { shot, progress, shotChanged, finished, reason }.
		-- L'événement `finished` n'est renvoyé qu'une seule fois.
		function P.update(now)
			if P.state ~= "playing" then
				return nil
			end
			local i, p = C.shotAt(seq, now - P.startedAt)
			if not i then
				P.state, P.reason = "done", "completed"
				return { finished = true, reason = "completed" }
			end
			local changed = i ~= P.lastShot
			P.lastShot = i
			return { shot = i, progress = p, shotChanged = changed, finished = false }
		end
		function P.skip()
			if P.state == "playing" then
				P.state, P.reason = "done", "skipped"
				return true
			end
			return false
		end
		function P.abort()
			if P.state == "playing" then
				P.state, P.reason = "done", "aborted"
				return true
			end
			return false
		end
		return P
	end

	-- Directeur : une seule cinématique à la fois. Une demande « chain » pendant une lecture est mise en file (intro puis tutoriel) ;
	-- une autre demande est refusée (jamais de cinématique superposée). Une cinématique ne démarre jamais seule en plein jeu.
	function C.director()
		local D = { current = nil, queue = {} }

		local function startNext(now)
			local nxt = table.remove(D.queue, 1)
			if nxt then
				D.current = { id = nxt.id, seq = nxt.seq, player = C.player(nxt.seq) }
				D.current.player.play(now)
			end
		end

		-- Retourne "playing", "queued" ou "refused".
		function D.request(id, seq, now, chain)
			if D.current and D.current.player.isPlaying() then
				if chain then
					D.queue[#D.queue + 1] = { id = id, seq = seq }
					return "queued"
				end
				return "refused"
			end
			D.current = { id = id, seq = seq, player = C.player(seq) }
			D.current.player.play(now)
			return "playing"
		end

		-- Retourne (id, événement). À la fin d'une séquence, la suivante de la file démarre ; l'événement `finished` est renvoyé une fois.
		function D.update(now)
			local cur = D.current
			if not cur then
				return nil
			end
			local ev = cur.player.update(now)
			if ev and ev.finished then
				D.current = nil
				startNext(now)
			end
			return cur.id, ev
		end

		-- Passe la séquence en cours (la file continue). Retourne l'id passé, ou nil si rien ne jouait.
		function D.skip(now)
			local cur = D.current
			if cur and cur.player.skip() then
				D.current = nil
				startNext(now)
				return cur.id
			end
			return nil
		end

		-- Passe tout : la séquence en cours et la file. Retourne la liste des identifiants passés.
		function D.skipAll()
			local ids = {}
			local cur = D.current
			if cur and cur.player.skip() then
				ids[#ids + 1] = cur.id
			end
			for _, q in ipairs(D.queue) do
				ids[#ids + 1] = q.id
			end
			D.current, D.queue = nil, {}
			return ids
		end

		-- Abandon (mort, attaque, erreur) : tout s'arrête, la file est vidée, rien n'est considéré comme vu.
		function D.abort()
			local cur = D.current
			if cur then
				cur.player.abort()
			end
			D.current, D.queue = nil, {}
		end

		function D.isActive()
			return D.current ~= nil
		end

		return D
	end

	return C
end

return Cinema
