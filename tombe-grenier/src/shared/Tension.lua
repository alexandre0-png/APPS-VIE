--[[
  Tension : courbe en trois temps (calme, montée, pic) qui pilote l'ambiance, les sons et les apparitions.
  compute() est pure (testée) ; current() l'applique à la partie en cours (horloge serveur).
  Un facteur vaut 1 hors partie ou si Config.Tension.Enabled = false.
  Facteurs : events (fréquence des événements d'ambiance), hear (portée d'ouïe du monstre),
  chase (vitesse de poursuite), volume (volume des sons d'ambiance), gap (délai avant attaque surprise).
]]
local Tension = {}

local FACTORS = { "events", "hear", "chase", "volume", "gap" }
local NEUTRAL = { name = "montee", u = 1, level = 0.5, events = 1, hear = 1, chase = 1, volume = 1, gap = 1 }

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end

-- Position sur la courbe, de 0 (début du calme) à 2 (pic) : max du temps et de la progression (0 à 1)
function Tension.position(cfg, mode, elapsed, progress)
	local ph = cfg.Phases[mode] or cfg.Phases.solo
	local t = math.max(0, elapsed or 0)
	local uTime
	if t < ph.calm then
		uTime = t / ph.calm
	elseif t < ph.rise then
		uTime = 1 + (t - ph.calm) / (ph.rise - ph.calm)
	else
		uTime = 2
	end
	local uProg = clamp(progress or 0, 0, 1) * 2 * (cfg.ProgressWeight or 1)
	return clamp(math.max(uTime, uProg), 0, 2)
end

function Tension.compute(cfg, mode, elapsed, progress)
	if not cfg.Enabled then
		return NEUTRAL
	end
	local u = Tension.position(cfg, mode, elapsed, progress)
	local from, to, t, name
	if u < 1 then
		from, to, t, name = cfg.Levels.calme, cfg.Levels.montee, u, "calme"
	else
		from, to, t = cfg.Levels.montee, cfg.Levels.pic, u - 1
		name = u >= 2 and "pic" or "montee"
	end
	local out = { name = name, u = u, level = u / 2 }
	for _, key in ipairs(FACTORS) do
		out[key] = lerp(from[key], to[key], t)
	end
	return out
end

-- Exécution : horloge et progression de la partie en cours
local startedAt = nil
local runMode = "solo"
local progressFn = nil

function Tension.start(mode, getProgress)
	startedAt = os.clock()
	cached = nil
	runMode = mode or "solo"
	progressFn = getProgress
end

function Tension.stop()
	startedAt = nil
	progressFn = nil
end

local cached, cachedAt = nil, 0

function Tension.current()
	if not startedAt then
		return NEUTRAL
	end
	local now = os.clock()
	if cached and now - cachedAt < 0.5 then
		return cached
	end
	local cfg = require(script.Parent.Config).Tension
	local ok, progress = pcall(progressFn or function()
		return 0
	end)
	cached = Tension.compute(cfg, runMode, now - startedAt, ok and progress or 0)
	cachedAt = now
	return cached
end

-- Raccourci : durée ajustée par la tension (un événement deux fois plus fréquent dure deux fois moins entre deux tirages)
function Tension.scaled(seconds)
	return seconds / math.max(0.2, Tension.current().events)
end

return Tension
