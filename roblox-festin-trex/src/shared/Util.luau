--!strict
-- Utilitaires purs (sans dépendance Roblox) : testables en dehors de Studio.

local Util = {}

function Util.clamp(x: number, a: number, b: number): number
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

function Util.round(x: number): number
	return math.floor(x + 0.5)
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Util.formatNumber(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = ""
	if n < 0 then
		sign = "-"
		n = -n
	end
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local truncated = math.floor(n * 10) / 10
	local text = string.format("%.1f", truncated)
	if string.sub(text, -2) == ".0" then
		text = string.sub(text, 1, -3)
	end
	return sign .. text .. SUFFIXES[i]
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = Util.deepCopy(v)
	end
	return copy
end

-- Complète `target` avec les clés manquantes de `template` (récursif). Ne supprime rien.
function Util.reconcile(target: any, template: any)
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			Util.reconcile(target[k], v)
		end
	end
end

-- items : { {id = string, weight = number} } ; r dans [0,1)
function Util.weightedPick(items: { { id: string, weight: number } }, r: number): string
	local total = 0
	for _, item in ipairs(items) do
		total += item.weight
	end
	local target = r * total
	local acc = 0
	for _, item in ipairs(items) do
		acc += item.weight
		if target < acc then
			return item.id
		end
	end
	return items[#items].id
end

-- Générateur pseudo-aléatoire déterministe (LCG), renvoie des nombres dans [0,1).
function Util.lcg(seed: number): () -> number
	local state = math.floor(math.abs(seed)) % 4294967296
	return function()
		state = (state * 1664525 + 1013904223) % 4294967296
		return state / 4294967296
	end
end

function Util.dayIndex(unixTime: number): number
	return math.floor(unixTime / 86400)
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

return Util
