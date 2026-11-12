-- État côté client + mini système d'abonnement.

local ClientState = {
	Data = nil, -- profil envoyé par le serveur
	Status = "Lobby", -- Lobby | Riding | Air | Hooking | Down | Out | Finished
	Scores = {}, -- classement en direct
}

local listeners = {}

function ClientState.connect(key, fn)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
	return function()
		local list = listeners[key]
		local index = table.find(list, fn)
		if index then
			table.remove(list, index)
		end
	end
end

local function fire(key, value)
	local list = listeners[key]
	if not list then
		return
	end
	for _, fn in ipairs(table.clone(list)) do
		task.spawn(fn, value)
	end
end

function ClientState.setData(data)
	ClientState.Data = data
	fire("Data", data)
end

function ClientState.setStatus(status)
	if ClientState.Status == status then
		return
	end
	ClientState.Status = status
	fire("Status", status)
end

function ClientState.setScores(scores)
	ClientState.Scores = scores
	fire("Scores", scores)
end

function ClientState.isPlaying()
	local s = ClientState.Status
	return s == "Riding" or s == "Air" or s == "Hooking" or s == "Down"
end

return ClientState
