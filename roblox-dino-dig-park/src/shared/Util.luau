-- Util.luau : fonctions utilitaires pures (partagées).

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Util.clamp(x, lo, hi)
	if x < lo then
		return lo
	elseif x > hi then
		return hi
	end
	return x
end

function Util.isFinite(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- 1234 -> "1.23K"
function Util.formatNumber(n)
	if not Util.isFinite(n) then
		return "0"
	end
	if n < 0 then
		return "-" .. Util.formatNumber(-n)
	end
	if n < 1000 then
		if n < 10 and n ~= math.floor(n) then
			return string.format("%.1f", n)
		end
		return tostring(math.floor(n))
	end
	local idx = 1
	while n >= 1000 and idx < #SUFFIXES do
		n = n / 1000
		idx = idx + 1
	end
	local s
	if n >= 100 then
		s = string.format("%.0f", n)
	elseif n >= 10 then
		s = string.format("%.1f", n)
	else
		s = string.format("%.2f", n)
	end
	-- retire les zéros inutiles
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s .. SUFFIXES[idx]
end

-- 125 -> "2:05", 3700 -> "1h 01m"
function Util.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	if seconds >= 3600 then
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		return string.format("%dh %02dm", h, m)
	end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

-- weights : { clef = poids }. rng : fonction () -> [0,1)
function Util.weightedPick(weights, rng)
	local total = 0
	local keys = {}
	for k, w in pairs(weights) do
		if w > 0 then
			table.insert(keys, k)
			total = total + w
		end
	end
	table.sort(keys) -- ordre déterministe
	if total <= 0 then
		return nil
	end
	local r = rng() * total
	local acc = 0
	for _, k in ipairs(keys) do
		acc = acc + weights[k]
		if r < acc then
			return k
		end
	end
	return keys[#keys]
end

function Util.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = Util.deepCopy(v)
	end
	return c
end

-- Complète `data` avec les champs manquants de `template` (récursif, sans écraser).
function Util.reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" then
			Util.reconcile(data[k], v)
		end
	end
end

function Util.dayNumber(t)
	return math.floor(t / 86400)
end

function Util.count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

return Util
