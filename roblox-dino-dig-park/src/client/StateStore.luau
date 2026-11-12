-- StateStore.luau : copie locale de l'état envoyé par le serveur + signaux de changement.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Store = {}
Store.state = nil
Store.skew = 0
local listeners = {}

function Store.serverNow()
	return os.time() + Store.skew
end

-- fn(state) est appelé à chaque mise à jour (et immédiatement si un état existe déjà)
function Store.connect(fn)
	table.insert(listeners, fn)
	if Store.state then
		fn(Store.state)
	end
end

function Store.act(name, payload)
	Remotes.Action:FireServer(name, payload)
end

Remotes.State.OnClientEvent:Connect(function(state)
	Store.state = state
	Store.skew = state.now - os.time()
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, state)
		if not ok then
			warn("[StateStore] listener:", err)
		end
	end
end)

return Store
