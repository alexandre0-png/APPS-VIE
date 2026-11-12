--!strict
-- Logique pure des animations : activation par clé, état de mouvement, inclinaison, plans (testable hors Roblox).
local AnimLogic = {}

-- Une animation est active si le commutateur général ET sa clé ne sont pas à false.
function AnimLogic.Enabled(cfg: { [string]: any }, key: string): boolean
	if cfg.Enabled == false then
		return false
	end
	return cfg[key] ~= false
end

-- État de pose affiché (priorité : esquive > glissade > garde > saut > course > repos).
function AnimLogic.MoveState(speed: number, grounded: boolean, sliding: boolean, dodging: boolean, guarding: boolean): string
	if dodging then
		return "Dodge"
	elseif sliding then
		return "Slide"
	elseif guarding then
		return "Guard"
	elseif not grounded then
		return "Air"
	elseif speed > 2 then
		return "Run"
	end
	return "Idle"
end

-- Inclinaison avant (radians) proportionnelle à la vitesse, bornée.
function AnimLogic.LeanAngle(speed: number, maxSpeed: number, maxDeg: number): number
	if maxSpeed <= 0 then
		return 0
	end
	return math.rad(math.clamp(speed / maxSpeed, 0, 1) * maxDeg)
end

-- Glissade / esquive autorisées : recharge écoulée, au sol, vitesse minimale (glissade).
function AnimLogic.CanTrigger(now: number, last: number, cooldown: number, grounded: boolean, speed: number, minSpeed: number): boolean
	return grounded and now - last >= cooldown and speed >= minSpeed
end

-- Courbe cloche 0 -> 1 -> 0 pour t dans [0,1] (rechargement, pulsation).
function AnimLogic.Bell(t: number): number
	t = math.clamp(t, 0, 1)
	return math.sin(t * math.pi)
end

-- Délai d'apparition échelonné d'une ligne (classement), plafonné.
function AnimLogic.Stagger(index: number, step: number, maxDelay: number): number
	return math.min(maxDelay, math.max(0, (index - 1) * step))
end

-- Confettis déterministes : { X (0..1), Delay, Duration, Color (1..colors), Size }.
function AnimLogic.ConfettiPlan(count: number, colors: number, seed: number): { { X: number, Delay: number, Duration: number, Color: number, Size: number } }
	local out = {}
	local state = (seed * 7919 + 13) % 2147483647
	local function nextRand(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	for _ = 1, count do
		table.insert(out, {
			X = nextRand(),
			Delay = nextRand() * 0.8,
			Duration = 1.4 + nextRand() * 1.2,
			Color = math.floor(nextRand() * colors) % colors + 1,
			Size = 6 + math.floor(nextRand() * 8),
		})
	end
	return out
end

return AnimLogic
