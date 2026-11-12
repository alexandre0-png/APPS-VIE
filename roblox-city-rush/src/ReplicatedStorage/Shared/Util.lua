--[[
	Util.lua : petites fonctions pures partagées.
]]

local Util = {}

function Util.formatCash(n)
	n = math.floor(n or 0)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	out = out:gsub("^%s+", "")
	return (n < 0 and "-" or "") .. out .. " $"
end

function Util.formatTime(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Util.flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

function Util.flatDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

function Util.moveToward(current, target, maxDelta)
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + math.sign(target - current) * maxDelta
end

-- Lance une boucle de fond qui redémarre si elle lève une erreur (une erreur ne doit jamais tuer un système)
function Util.supervise(name, fn)
	task.spawn(function()
		while true do
			local ok, err = pcall(fn)
			if ok then
				return
			end
			warn(string.format("[%s] boucle relancée après erreur: %s", name, tostring(err)))
			task.wait(1)
		end
	end)
end

-- Mini signal (pas de dépendance à BindableEvent => pas de copie profonde des arguments)
local Signal = {}
Signal.__index = Signal

function Util.newSignal()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handler = { fn = fn }
	table.insert(self._handlers, handler)
	return {
		Disconnect = function()
			local i = table.find(self._handlers, handler)
			if i then
				table.remove(self._handlers, i)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, h in ipairs(table.clone(self._handlers)) do
		task.spawn(h.fn, ...)
	end
end

-- Choix pondéré dans une liste {{id=..., weight=...}}
function Util.weightedPick(list, rng)
	local total = 0
	for _, e in ipairs(list) do
		total += e.weight
	end
	local r = (rng and rng:NextNumber() or math.random()) * total
	for _, e in ipairs(list) do
		r -= e.weight
		if r <= 0 then
			return e
		end
	end
	return list[#list]
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

-- Complète t avec les valeurs manquantes de defaults (récursif)
function Util.reconcile(t, defaults)
	for k, v in pairs(defaults) do
		if t[k] == nil then
			t[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(t[k]) == "table" then
			Util.reconcile(t[k], v)
		end
	end
	return t
end

return Util
