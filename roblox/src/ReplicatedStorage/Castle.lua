-- ModuleScript : ReplicatedStorage/Shared/Castle
-- Mode « Château » : donjon de salles successives avec pièges à éviter (pics, lames tournantes, boulets, porte à timing) et coffre final.
-- Logique PURE (aucun service Roblox) : géométrie des salles, états des pièges en fonction du temps, détection des touches, difficulté croissante,
-- classement des temps et récompense. Coordonnées d'une salle : lx (travers, -20..20) et lz (profondeur depuis l'entrée, 0..roomLength).
local Castle = {}

Castle.ROOMS = 5
Castle.ROOM_LENGTH = 56
Castle.ROOM_WIDTH = 40
Castle.ORIGIN = { x = 470, z = -280 } -- entrée de la salle 1 dans le monde ; les salles avancent vers -z

-- Difficulté d'une salle r (1..ROOMS) : nombre de pièges et rythme, croissants.
function Castle.room(r)
	r = math.min(math.max(r, 1), Castle.ROOMS)
	return {
		index = r,
		spikes = 3 + r, -- plaques à pics (4 colonnes)
		blades = r >= 4 and 2 or (r >= 2 and 1 or 0),
		balls = r >= 3 and (r - 2) or 0,
		knights = r >= 5 and 2 or (r >= 3 and 1 or 0), -- chevaliers qui patrouillent d'un mur à l'autre (touche non mortelle)
		period = math.max(1.6, 3.4 - 0.3 * r), -- durée d'un cycle des pics (s)
		bladeSpeed = 1.2 + 0.3 * r, -- radians par seconde
		ballTravel = math.max(1.6, 3.2 - 0.25 * r), -- traversée d'un boulet (s)
		doorPeriod = math.max(3, 5 - 0.4 * r), -- cycle de la porte (s)
		doorOpen = math.max(1.4, 2.4 - 0.2 * r), -- durée d'ouverture (s)
	}
end

-- Pics : phase 0..1 du cycle ; avertissement avant le danger (les pics se dressent), danger 0,9 s par cycle.
local DANGER, WARN = 0.9, 0.6
function Castle.spikeState(t, trap, room)
	local period = room.period
	local phase = ((t + trap.offset) % period)
	local dangerStart = period - DANGER
	if phase >= dangerStart then
		return "danger"
	elseif phase >= dangerStart - WARN then
		return "warning"
	end
	return "safe"
end

-- Plaques à pics de la salle : 4 colonnes espacées (couloirs sûrs de 4 studs entre elles), phases décalées.
function Castle.spikes(room)
	local out = {}
	for i = 1, room.spikes do
		local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
		out[i] = { lx = -15 + col * 10, lz = 10 + row * 9, radius = 3, offset = ((col + row) % 4) * (room.period / 4) }
	end
	return out
end

-- Lames tournantes : centre de la salle, deux bras opposés de 14 studs, angle selon le temps.
function Castle.blades(room)
	local out = {}
	for i = 1, room.blades do
		out[i] = { lx = (i - (room.blades + 1) / 2) * 20, lz = 34, arm = 14, phase = (i - 1) * math.pi / 2 }
	end
	return out
end

function Castle.bladeAngle(t, blade, room)
	return blade.phase + t * room.bladeSpeed
end

-- Boulets : couloirs horizontaux (traversée de gauche à droite puis pause avant de recommencer).
function Castle.balls(room)
	local out = {}
	for i = 1, room.balls do
		out[i] = { lz = 18 + (i - 1) * 9, radius = 3, offset = (i - 1) * 0.9 }
	end
	return out
end

-- Position latérale d'un boulet (nil pendant la pause).
function Castle.ballX(t, ball, room)
	local cycle = room.ballTravel + 1.4
	local phase = (t + ball.offset) % cycle
	if phase >= room.ballTravel then
		return nil
	end
	return -22 + 44 * (phase / room.ballTravel)
end

-- Chevaliers : patrouille en aller-retour latéral (onde triangulaire, vitesse constante), décalés pour ne pas être synchrones.
function Castle.knights(room)
	local out = {}
	for i = 1, room.knights do
		out[i] = { lz = 14 + (i - 1) * 24, amp = 15, period = math.max(5, 9 - 0.7 * room.index), offset = (i - 1) * 2.3, radius = 2.6 }
	end
	return out
end

-- Position latérale et sens (+1 vers la droite, -1 vers la gauche) d'un chevalier à l'instant t.
function Castle.knightPos(t, k)
	local phase = ((t + k.offset) % k.period) / k.period -- 0..1
	if phase < 0.5 then
		return -k.amp + 4 * k.amp * phase, 1
	end
	return k.amp - 4 * k.amp * (phase - 0.5), -1
end

-- Porte de fin de salle : ouverte pendant doorOpen secondes par cycle.
function Castle.doorIsOpen(t, room)
	return (t % room.doorPeriod) < room.doorOpen
end

-- Distance d'un point au segment [a, b].
local function distToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local l2 = dx * dx + dz * dz
	local u = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / l2)) or 0
	local cx, cz = ax + u * dx, az + u * dz
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end
Castle.distToSegment = distToSegment

-- Le joueur (px, pz en coordonnées locales de salle) est-il touché par un piège à l'instant t ? Retourne le nom du piège ou nil.
function Castle.hit(t, room, px, pz, playerRadius)
	playerRadius = playerRadius or 1.2
	for _, sp in ipairs(Castle.spikes(room)) do
		if Castle.spikeState(t, sp, room) == "danger" and math.sqrt((px - sp.lx) ^ 2 + (pz - sp.lz) ^ 2) < sp.radius + playerRadius * 0.5 then
			return "spikes"
		end
	end
	for _, bl in ipairs(Castle.blades(room)) do
		local a = Castle.bladeAngle(t, bl, room)
		local cx, cz = math.cos(a) * bl.arm, math.sin(a) * bl.arm
		if distToSegment(px, pz, bl.lx - cx, bl.lz - cz, bl.lx + cx, bl.lz + cz) < 1.6 + playerRadius * 0.5 then
			return "blade"
		end
	end
	for _, ba in ipairs(Castle.balls(room)) do
		local bx = Castle.ballX(t, ba, room)
		if bx and math.sqrt((px - bx) ^ 2 + (pz - ba.lz) ^ 2) < ba.radius + playerRadius * 0.5 then
			return "ball"
		end
	end
	for _, kn in ipairs(Castle.knights(room)) do
		local kx = Castle.knightPos(t, kn)
		if math.sqrt((px - kx) ^ 2 + (pz - kn.lz) ^ 2) < kn.radius + playerRadius * 0.5 then
			return "knight"
		end
	end
	return nil
end

-- Conversion monde <-> salle : la salle r commence à ORIGIN.z - (r - 1) * ROOM_LENGTH et avance vers -z.
function Castle.toLocal(wx, wz)
	local depth = Castle.ORIGIN.z - wz -- profondeur totale depuis l'entrée
	local r = math.floor(depth / Castle.ROOM_LENGTH) + 1
	return r, wx - Castle.ORIGIN.x, depth - (r - 1) * Castle.ROOM_LENGTH
end

function Castle.toWorld(r, lx, lz)
	return Castle.ORIGIN.x + lx, Castle.ORIGIN.z - ((r - 1) * Castle.ROOM_LENGTH + lz)
end

-- Joueur dans le château ? (rectangle des salles). Retourne le numéro de salle ou nil.
function Castle.roomAt(wx, wz)
	local r, lx, lz = Castle.toLocal(wx, wz)
	if r >= 1 and r <= Castle.ROOMS and math.abs(lx) <= Castle.ROOM_WIDTH / 2 and lz >= 0 then
		return r, lx, lz
	end
	return nil
end

-- Classement des temps (secondes, plus petit = meilleur) : insère { name, userId, time }, conserve `max` entrées, un seul meilleur temps par joueur.
-- Retourne (nouvelle liste, rang du joueur ou nil s'il n'entre pas).
function Castle.insertScore(list, entry, max)
	local out, existing = {}, nil
	for _, e in ipairs(list) do
		if e.userId == entry.userId then
			existing = e
		else
			out[#out + 1] = e
		end
	end
	if existing and existing.time <= entry.time then
		local same = {}
		for i, e in ipairs(list) do
			same[i] = e
		end
		return same, nil -- son meilleur temps existant est conservé
	end
	out[#out + 1] = entry
	table.sort(out, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.userId < b.userId
	end)
	local rank = nil
	for i, e in ipairs(out) do
		if e == entry then
			rank = i
		end
	end
	while #out > max do
		table.remove(out)
	end
	if rank and rank > max then
		rank = nil
	end
	return out, rank
end

-- Durée en « m:ss.d » (arrondie au dixième).
function Castle.formatTime(seconds)
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 then
		return "--:--.-"
	end
	local tenths = math.floor(seconds * 10 + 0.5)
	local m = tenths // 600
	local rest = (tenths - m * 600) / 10
	return string.format("%d:%04.1f", m, rest)
end

Castle.REWARD_TIERS = { fast = 5, slow = 4 } -- lot 9 : Légendaire et Épique (indices des 10 raretés)
-- Récompense du coffre final : œuf rare (Épique, Légendaire si temps rapide), pièces proportionnelles aux revenus.
-- fastTime : durée de référence « rapide » (s) pour ce nombre de salles.
function Castle.reward(timeSeconds, income, deaths)
	local fast = 60 * Castle.ROOMS * 0.6 -- 3 min : bon temps
	local tier = (timeSeconds <= fast and (deaths or 0) == 0) and Castle.REWARD_TIERS.fast or Castle.REWARD_TIERS.slow
	local coins = math.floor(math.max(5000, income * 600 * (timeSeconds <= fast and 1.5 or 1)))
	return { eggTier = tier, coins = coins }
end

return Castle
