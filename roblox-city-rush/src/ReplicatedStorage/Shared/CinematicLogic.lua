--[[
	CinematicLogic : logique pure des cinématiques (testable sans Roblox).
	- validation des séquences (durées 20 à 40 s)
	- lecteur : temps, plan courant, légende, skip, reprise (finished/skipped, une seule fois)
	- pose caméra d'un plan (position + point visé) sous forme de tables {x,y,z}
]]

local CinematicLogic = {}

CinematicLogic.MIN_DURATION = 20
CinematicLogic.MAX_DURATION = 40

local function smooth(t)
	t = math.max(0, math.min(1, t))
	return t * t * (3 - 2 * t)
end

function CinematicLogic.totalDuration(seq)
	local d = 0
	for _, shot in ipairs(seq.shots) do
		d += shot.dur
	end
	return d
end

-- Retourne (ok, message)
function CinematicLogic.validate(seq)
	if type(seq) ~= "table" or type(seq.shots) ~= "table" or #seq.shots == 0 then
		return false, "séquence vide"
	end
	for i, shot in ipairs(seq.shots) do
		if type(shot.dur) ~= "number" or shot.dur <= 0 then
			return false, "durée invalide du plan " .. i
		end
		if shot.kind ~= "orbit" and shot.kind ~= "fly" then
			return false, "type de plan inconnu " .. tostring(shot.kind)
		end
		if shot.kind == "orbit" and (type(shot.radius) ~= "number" or shot.radius <= 0) then
			return false, "rayon invalide du plan " .. i
		end
		if shot.kind == "fly" and (type(shot.from) ~= "table" or type(shot.to) ~= "table") then
			return false, "from/to manquants du plan " .. i
		end
		if type(shot.caption) ~= "string" or shot.caption == "" then
			return false, "légende manquante du plan " .. i
		end
	end
	local total = CinematicLogic.totalDuration(seq)
	if total < CinematicLogic.MIN_DURATION or total > CinematicLogic.MAX_DURATION then
		return false, string.format("durée totale %ds hors de 20-40 s", total)
	end
	return true, "ok"
end

-- Lecteur ------------------------------------------------------------
local Player = {}
Player.__index = Player

function CinematicLogic.newPlayer(seq)
	return setmetatable({ seq = seq, time = 0, finished = false, skipped = false, total = CinematicLogic.totalDuration(seq) }, Player)
end

function Player:step(dt)
	if self.finished then
		return
	end
	self.time += math.max(0, dt)
	if self.time >= self.total then
		self.time = self.total
		self.finished = true
	end
end

function Player:skip()
	if self.finished then
		return false
	end
	self.skipped = true
	self.finished = true
	return true
end

-- Retourne (plan, avancement 0..1 dans ce plan, index)
function Player:current()
	local t = self.time
	for i, shot in ipairs(self.seq.shots) do
		if t < shot.dur or i == #self.seq.shots then
			return shot, math.min(1, t / shot.dur), i
		end
		t -= shot.dur
	end
end

function Player:caption()
	local shot = self:current()
	return shot and shot.caption or ""
end

-- Pose caméra : center = {x,y,z} (monde). Retourne pos, look (tables)
function CinematicLogic.pose(shot, progress, center)
	local p = smooth(progress)
	local cx, cy, cz = center[1], center[2], center[3]
	local lookY = shot.lookY or 0
	if shot.kind == "orbit" then
		local a = shot.a0 + (shot.a1 - shot.a0) * p
		return { x = cx + math.cos(a) * shot.radius, y = cy + (shot.height or 20), z = cz + math.sin(a) * shot.radius },
			{ x = cx, y = cy + lookY, z = cz }
	end
	local f, t = shot.from, shot.to
	local ox, oy, oz = 0, 0, 0
	if shot.relative then
		ox, oy, oz = cx, cy, cz
	end
	return {
		x = ox + f[1] + (t[1] - f[1]) * p,
		y = oy + f[2] + (t[2] - f[2]) * p,
		z = oz + f[3] + (t[3] - f[3]) * p,
	}, { x = cx, y = cy + lookY, z = cz }
end

-- File d'attente : évite les doublons et borne la taille. Retourne true si ajouté.
function CinematicLogic.enqueue(queue, id, maxSize)
	if #queue >= maxSize then
		return false
	end
	for _, q in ipairs(queue) do
		if q == id then
			return false
		end
	end
	table.insert(queue, id)
	return true
end

return CinematicLogic
