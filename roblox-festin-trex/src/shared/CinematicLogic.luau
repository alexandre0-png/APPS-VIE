--!nonstrict
-- Logique pure des cinématiques (testable hors Studio) : règles de lancement (réglages, « une seule fois »,
-- délai de repos), état de lecture, durée maximale, reprise après « Passer », choix du plan et interpolation caméra.
-- Aucune dépendance Roblox : le client applique le résultat à la caméra.

local CinematicLogic = {}
CinematicLogic.__index = CinematicLogic

function CinematicLogic.new(cfg: any)
	return setmetatable({ cfg = cfg, playing = nil, startedAt = 0, duration = 0, last = {}, skipped = 0 }, CinematicLogic)
end

-- Durée totale d'une séquence (somme des plans), plafonnée à cfg.MaxSeconds.
function CinematicLogic.totalDuration(seq: any, maxSeconds: number): number
	local total = 0
	for _, shot in ipairs(seq) do
		total += shot.Dur
	end
	return math.min(total, maxSeconds)
end

local function isOnce(cfg: any, id: string): boolean
	for _, v in ipairs(cfg.Once) do
		if v == id then
			return true
		end
	end
	return false
end

-- Peut-on lancer la cinématique `id` ? Retourne (ok, raison).
-- `seen` : table des cinématiques déjà vues (persistée côté serveur).
function CinematicLogic.canPlay(self: any, id: string, now: number, seen: any): (boolean, string?)
	local cfg = self.cfg
	if type(cfg) ~= "table" or cfg.Enabled ~= true then
		return false, "désactivées"
	end
	local flagKey = if string.sub(id, 1, 5) == "zone_" then "Zone" else id
	if cfg.Flags[flagKey] ~= true then
		return false, "désactivée"
	end
	if self.playing then
		return false, "déjà en cours"
	end
	if isOnce(cfg, id) and seen and seen[id] then
		return false, "déjà vue"
	end
	local cooldown = cfg.Cooldowns[id]
	if cooldown and self.last[id] and now - self.last[id] < cooldown then
		return false, "repos"
	end
	return true, nil
end

-- Démarre. `seq` = liste de plans. Retourne (ok, durée).
function CinematicLogic.start(self: any, id: string, now: number, seen: any, seq: any): (boolean, number)
	local ok = CinematicLogic.canPlay(self, id, now, seen)
	if not ok or type(seq) ~= "table" or #seq == 0 then
		return false, 0
	end
	self.playing = id
	self.startedAt = now
	self.duration = CinematicLogic.totalDuration(seq, self.cfg.MaxSeconds)
	self.last[id] = now
	return true, self.duration
end

-- « Passer » : revient immédiatement à l'état libre (le joueur reprend la main), les autres cinématiques restent possibles.
function CinematicLogic.skip(self: any): boolean
	if not self.playing then
		return false
	end
	self.playing = nil
	self.skipped += 1
	return true
end

-- Fin normale ou erreur : même retour à l'état libre.
function CinematicLogic.finish(self: any)
	self.playing = nil
end

-- État à l'instant `now` : ("idle" | "playing" | "done", écoulé). Passe à "done" (et libère) à la fin de la durée.
function CinematicLogic.update(self: any, now: number): (string, number)
	if not self.playing then
		return "idle", 0
	end
	local elapsed = now - self.startedAt
	if elapsed >= self.duration then
		self.playing = nil
		return "done", self.duration
	end
	return "playing", elapsed
end

-- Plan courant : (index, avancement 0..1 dans le plan).
function CinematicLogic.shotAt(seq: any, elapsed: number): (number, number)
	local acc = 0
	for i, shot in ipairs(seq) do
		if elapsed < acc + shot.Dur then
			return i, math.clamp((elapsed - acc) / shot.Dur, 0, 1)
		end
		acc += shot.Dur
	end
	return #seq, 1
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

-- Position caméra et point visé pour un plan à l'avancement t (interpolation douce).
function CinematicLogic.camera(shot: any, t: number): ({ number }, { number })
	local k = smooth(math.clamp(t, 0, 1))
	local from, to = shot.From, shot.To or shot.From
	local lookFrom, lookTo = shot.Look, shot.LookTo or shot.Look
	local pos, look = {}, {}
	for i = 1, 3 do
		pos[i] = from[i] + (to[i] - from[i]) * k
		look[i] = lookFrom[i] + (lookTo[i] - lookFrom[i]) * k
	end
	return pos, look
end

return CinematicLogic
