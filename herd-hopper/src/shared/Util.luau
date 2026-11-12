-- Petits utilitaires partagés (serveur + client).

local Util = {}

function Util.create(className, props, parent)
	local inst = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			inst[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Anti-spam des RemoteEvents : renvoie false si l'appel est trop rapproché.
local lastCall = {}

function Util.allow(player, key, interval)
	local now = os.clock()
	local bucket = lastCall[player]
	if not bucket then
		bucket = {}
		lastCall[player] = bucket
	end
	local last = bucket[key]
	if last and now - last < interval then
		return false
	end
	bucket[key] = now
	return true
end

function Util.forget(player)
	lastCall[player] = nil
end

function Util.pickWeighted(list, rng)
	local total = 0
	for _, item in ipairs(list) do
		total = total + item.weight
	end
	local roll = rng:NextNumber() * total
	for _, item in ipairs(list) do
		roll = roll - item.weight
		if roll <= 0 then
			return item
		end
	end
	return list[#list]
end

function Util.formatNumber(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^%s+", ""))
end

function Util.formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Util.isFiniteNumber(v)
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

return Util
