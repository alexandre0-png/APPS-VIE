--[[
  Noise : bruits ponctuels (chutes d'objets, etc.) que le monstre peut entendre.
  Les bruits continus des joueurs passent par PlayerState.noise.
]]
local Noise = {}

local MAX_EVENTS = 32
local events = {}

function Noise.emit(position, strength)
	table.insert(events, { pos = position, strength = strength, time = os.clock() })
	if #events > MAX_EVENTS then
		table.remove(events, 1)
	end
end

function Noise.recent(maxAge)
	local now = os.clock()
	local out = {}
	for _, event in ipairs(events) do
		if now - event.time <= maxAge then
			table.insert(out, event)
		end
	end
	return out
end

return Noise
