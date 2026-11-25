-- ModuleScript : ReplicatedStorage/Shared/Traps
-- Pièges des territoires (REFONTE lot 4) : fils à clochettes et flaques de boue de Mara, herse, dalles d'alarme et lanternes tournantes de Zed, plus la
-- fraîcheur des œufs de Zed. PUR (aucun service Roblox, positions = nombres x, z) : testé hors de Roblox. Les positions sont DÉRIVÉES de Config.TERR
-- (centre, rayon, entrée) : rien n'est écrit en dur. Le serveur (Main) applique les décisions, le Builder construit les Parts d'après `layout`.
local Traps = {}

local sqrt, cos, sin, rad, deg, acos, pi = math.sqrt, math.cos, math.sin, math.rad, math.deg, math.acos, math.pi

-- Tourne le vecteur unitaire (ux, uz) de `degrees` degrés.
local function rot(ux, uz, degrees)
	local c, s = cos(rad(degrees)), sin(rad(degrees))
	return ux * c - uz * s, ux * s + uz * c
end

-- Plan des pièges d'un territoire (nil si le territoire n'en a pas). `Config` = module Config. Tout est calculé autour de l'entrée du territoire :
--   fils à clochettes : 3 fils tangents sur l'arc à 70 % du rayon, à -30 / 0 / +30 degrés de l'entrée (demi-longueur Config.TRAPS.bellHalfWidth)
--   boue : flaques à 45 % du rayon, étalées de -70 à +70 degrés
--   dalles d'alarme : à 55 % du rayon, tous les 360/n degrés à partir de 45 degrés
--   lanternes : à 55 % du rayon, à +90 et -90 degrés, tournant en sens inverse l'une de l'autre depuis des angles opposés
--   herse : à l'entrée (Config.TERR.zed.traps.gate)
function Traps.layout(Config, key)
	local t = Config.TERR[key]
	local tr = t and t.traps
	if not tr then
		return nil
	end
	local C = Config.TRAPS
	local ex, ez = Config.territoryEntry(key)
	local dx, dz = ex - t.x, ez - t.z
	local d = sqrt(dx * dx + dz * dz)
	local ux, uz = dx / d, dz / d
	local function at(frac, degrees)
		local vx, vz = rot(ux, uz, degrees)
		return t.x + vx * t.r * frac, t.z + vz * t.r * frac, vx, vz
	end
	local L = { key = key, cx = t.x, cz = t.z, r = t.r, bells = {}, mud = {}, plates = {}, lights = {}, gate = nil }
	for k = 1, tr.bells or 0 do
		local x, z, vx, vz = at(0.7, (k - 2) * 30)
		local tx, tz = -vz, vx -- tangente au cercle : le fil barre le passage vers l'intérieur
		L.bells[k] = { x = x, z = z, ax = x - tx * C.bellHalfWidth, az = z - tz * C.bellHalfWidth, bx = x + tx * C.bellHalfWidth, bz = z + tz * C.bellHalfWidth }
	end
	local nm = tr.mud or 0
	for k = 1, nm do
		local x, z = at(0.45, -70 + (k - 1) * 140 / math.max(1, nm - 1))
		L.mud[k] = { x = x, z = z, r = C.mudRadius }
	end
	local np = tr.plates or 0
	for k = 1, np do
		local x, z = at(0.55, 45 + (k - 1) * 360 / np)
		L.plates[k] = { x = x, z = z, r = C.plateRadius }
	end
	for k = 1, tr.searchlights or 0 do
		local x, z = at(0.55, 90 + (k - 1) * 180)
		L.lights[k] = { x = x, z = z, phase = (k - 1) * pi, rev = tr.searchlightRev or 0.5, range = C.lightRange, cone = C.lightCone }
	end
	if tr.gate then
		L.gate = { x = tr.gate.x, z = tr.gate.z, open = tr.gate.open, closed = tr.gate.closed }
	end
	return L
end

-- Nombre de Parts que les pièges d'un plan font construire au Builder (budget : <= 40 pour tous les territoires).
-- fil : 2 poteaux + le fil ; flaque : 1 ; dalle : 1 ; lanterne : poteau + faisceau ; herse : 0 (la Part CourtGate de Scenery est réutilisée).
function Traps.partCount(L)
	if not L then
		return 0
	end
	return #L.bells * 3 + #L.mud + #L.plates + #L.lights * 2
end

---------------------------------------------------------------- géométrie
local function orient(px, pz, qx, qz, rx, rz)
	return (qx - px) * (rz - pz) - (qz - pz) * (rx - px)
end

-- Les segments [a b] et [c d] se croisent-ils strictement ?
function Traps.segCross(ax, az, bx, bz, cx, cz, dx, dz)
	local o1, o2 = orient(ax, az, bx, bz, cx, cz), orient(ax, az, bx, bz, dx, dz)
	local o3, o4 = orient(cx, cz, dx, dz, ax, az), orient(cx, cz, dx, dz, bx, bz)
	return o1 * o2 < 0 and o3 * o4 < 0
end

-- Distance du point (px, pz) au segment [a b].
function Traps.distToSeg(px, pz, ax, az, bx, bz)
	local vx, vz = bx - ax, bz - az
	local l2 = vx * vx + vz * vz
	local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * vx + (pz - az) * vz) / l2)) or 0
	local qx, qz = ax + vx * t, az + vz * t
	return sqrt((px - qx) ^ 2 + (pz - qz) ^ 2)
end

---------------------------------------------------------------- herse (cycle ouverte `open` s / fermée `closed` s, ouverte au temps 0)
function Traps.gateOpen(t, gate)
	local cyc = gate.open + gate.closed
	return (t % cyc) < gate.open
end

-- Hauteur de la herse : 1 = levée (ouverte), 0 = baissée (fermée). Montée ou descente en `window` secondes au début de chaque phase.
function Traps.gateLift(t, gate, window)
	local cyc = gate.open + gate.closed
	local ph = t % cyc
	if ph < gate.open then
		return math.min(1, ph / window)
	end
	return math.max(0, 1 - (ph - gate.open) / window)
end

-- La herse est SOLIDE tant qu'elle est descendue à moitié ou plus (elle ne bloque pas pendant qu'elle monte).
function Traps.gateSolid(t, gate, window)
	return Traps.gateLift(t, gate, window) <= 0.5 and not Traps.gateOpen(t, gate)
end

---------------------------------------------------------------- lanternes tournantes
function Traps.lanternAngle(t, light)
	return light.phase + 2 * pi * light.rev * t
end

-- La lanterne éclaire-t-elle (px, pz) au temps t ? Portée `range`, cône de `cone` degrés (total) centré sur l'angle courant.
function Traps.lanternSees(light, t, px, pz)
	local dx, dz = px - light.x, pz - light.z
	local d = sqrt(dx * dx + dz * dz)
	if d > light.range then
		return false
	end
	if d < 1 then
		return true
	end
	local a = Traps.lanternAngle(t, light)
	local c = (cos(a) * dx + sin(a) * dz) / d
	return deg(acos(math.max(-1, math.min(1, c)))) <= light.cone / 2
end

---------------------------------------------------------------- décision par joueur
function Traps.newPlayerState()
	return { px = nil, pz = nil, mudUntil = 0, cd = {} }
end

-- Un pas de simulation pour un joueur en (x, z) au temps t (le serveur l'appelle ~10 fois par seconde pour les joueurs proches du territoire).
-- Met `ps` à jour (position précédente, délais) et retourne la liste des événements :
--   { kind = "bell", index }  : le joueur a traversé un fil (ou le frôle à moins d'un stud)
--   { kind = "plate", index } : il marche sur une dalle d'alarme
--   { kind = "light", index } : une lanterne l'éclaire
--   { kind = "mud", index }   : il entre dans une flaque (une seule fois par passage ; la vitesse est ralentie tant que t < ps.mudUntil)
-- Chaque alarme a un délai de recharge par joueur (cfg = Config.TRAPS).
function Traps.playerStep(ps, L, cfg, t, x, z)
	local ev = {}
	local qx, qz = ps.px or x, ps.pz or z
	ps.px, ps.pz = x, z
	for i, b in ipairs(L.bells) do
		local key = "b" .. i
		if t >= (ps.cd[key] or 0) and (Traps.segCross(qx, qz, x, z, b.ax, b.az, b.bx, b.bz) or Traps.distToSeg(x, z, b.ax, b.az, b.bx, b.bz) < 1) then
			ps.cd[key] = t + cfg.bellCooldown
			ev[#ev + 1] = { kind = "bell", index = i }
		end
	end
	for i, m in ipairs(L.mud) do
		if (x - m.x) ^ 2 + (z - m.z) ^ 2 <= m.r * m.r then
			if t >= ps.mudUntil then
				ev[#ev + 1] = { kind = "mud", index = i }
			end
			ps.mudUntil = t + cfg.mudSeconds
		end
	end
	for i, p in ipairs(L.plates) do
		local key = "p" .. i
		if t >= (ps.cd[key] or 0) and (x - p.x) ^ 2 + (z - p.z) ^ 2 <= p.r * p.r then
			ps.cd[key] = t + cfg.plateCooldown
			ev[#ev + 1] = { kind = "plate", index = i }
		end
	end
	for i, l in ipairs(L.lights) do
		local key = "l" .. i
		if t >= (ps.cd[key] or 0) and Traps.lanternSees(l, t, x, z) then
			ps.cd[key] = t + cfg.lightCooldown
			ev[#ev + 1] = { kind = "light", index = i }
		end
	end
	return ev
end

-- Multiplicateur de vitesse de la boue (1 hors flaque).
function Traps.mudMul(ps, t, cfg)
	return t < ps.mudUntil and cfg.mudMul or 1
end

---------------------------------------------------------------- fraîcheur des œufs
-- Échéance (temps absolu) d'un œuf de rareté `tier` pris dans le territoire `terr`, ou nil s'il ne se refroidit pas : seuls les œufs de rareté
-- Config.CARRY.beamTier ou plus (Légendaire+) pris dans un territoire qui a une `freshness` (Zed : 75 s).
function Traps.freshDeadline(Config, tier, terr, now)
	local t = terr and Config.TERR[terr]
	if t and t.freshness and tier >= Config.CARRY.beamTier then
		return now + t.freshness
	end
	return nil
end

function Traps.expired(egg, now)
	return egg.fresh ~= nil and now >= egg.fresh
end

return Traps
