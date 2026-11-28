-- ModuleScript : ReplicatedStorage/Music (graphismes 9 : musique par zone). Logique PURE, sans service Roblox.
-- Une piste par zone (hub = village et parcelles, arène, château), volume bas, coupée pendant un combat (interface de combat ouverte), fondus enchaînés,
-- respect de Config.SOUNDS_ENABLED et du volume général du menu Plus (0 = muet). Les identifiants de Config.MUSIC sont VIDES tant qu'aucune piste approuvée
-- n'existe : le système est prêt mais muet (aucun Sound créé). On n'invente aucun identifiant : une piste doit être de la forme « rbxassetid://<chiffres> ».
-- Style : compatible lupa (affectations composées et saut de boucle évités), gardes de type avant comparaison.
local Music = {}

Music.ZONES = { "hub", "arena", "castle" }
-- Zone d'éclairage (Config.lightingZoneAt) -> zone musicale.
Music.FROM_LIGHTING = { hub = "hub", plots = "hub", lobby = "hub", arena = "arena", castle = "castle" }
Music.MAX_VOLUME = 0.3 -- plafond dur : la musique reste en fond

local function finite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Identifiant de piste valide (rbxassetid://<chiffres>, pas 0) ou nil.
function Music.trackId(id)
	if type(id) ~= "string" then
		return nil
	end
	local digits = string.match(id, "^rbxassetid://(%d+)$")
	if digits and digits ~= "0" and not string.match(digits, "^0+$") then
		return id
	end
	return nil
end

-- Réglages assainis : { enabled, fade, volume, tracks = { zone = id|nil }, interval }.
function Music.cfg(Config)
	local m = type(Config) == "table" and type(Config.MUSIC) == "table" and Config.MUSIC or {}
	local tracks = {}
	local src = type(m.tracks) == "table" and m.tracks or {}
	for _, z in ipairs(Music.ZONES) do
		tracks[z] = Music.trackId(src[z])
	end
	local vol = finite(m.volume) and m.volume or 0.15
	return {
		enabled = m.enabled ~= false,
		fade = finite(m.fade) and m.fade > 0 and m.fade or 2.5,
		volume = math.min(Music.MAX_VOLUME, math.max(0, vol)),
		interval = finite(m.interval) and m.interval > 0 and m.interval or 0.5,
		tracks = tracks,
	}
end

-- Zone musicale d'une zone d'éclairage (repli hub).
function Music.zoneOf(lightingZone)
	return Music.FROM_LIGHTING[lightingZone] or "hub"
end

-- Le système a-t-il au moins une piste ? (sinon : prêt mais muet, aucun Sound créé)
function Music.hasTracks(Config)
	local c = Music.cfg(Config)
	for _, z in ipairs(Music.ZONES) do
		if c.tracks[z] then
			return true
		end
	end
	return false
end

-- Volume cible de la piste `zone` : ctx = { zone (zone courante), battle (bool), master (0..1), soundsEnabled (bool) }.
function Music.target(Config, zone, ctx)
	local c = Music.cfg(Config)
	if not c.enabled or type(ctx) ~= "table" or ctx.soundsEnabled == false or ctx.battle == true then
		return 0
	end
	if zone ~= ctx.zone or not c.tracks[zone] then
		return 0
	end
	local master = finite(ctx.master) and math.min(1, math.max(0, ctx.master)) or 1
	return c.volume * master
end

-- Un pas de fondu : rapproche `current` de `target` d'au plus (plafond / fade) x dt. Jamais de dépassement, valeurs bornées à [0, MAX_VOLUME].
function Music.step(current, target, dt, fade)
	local cur = finite(current) and current or 0
	local tg = finite(target) and math.min(Music.MAX_VOLUME, math.max(0, target)) or 0
	local d = finite(dt) and dt > 0 and dt or 0
	local f = finite(fade) and fade > 0 and fade or 2.5
	local maxStep = Music.MAX_VOLUME / f * d
	if cur < tg then
		return math.min(tg, cur + maxStep)
	end
	return math.max(tg, cur - maxStep)
end

return Music
