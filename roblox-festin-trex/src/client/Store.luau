--!nonstrict
-- Magasin d'état côté client : dernier instantané envoyé par le serveur + abonnements.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Store = {}
Store.state = nil :: any
local listeners: { (any) -> () } = {}

function Store.onChange(fn: (any) -> ())
	table.insert(listeners, fn)
	if Store.state then
		task.spawn(fn, Store.state)
	end
end

function Store.init()
	Remotes.get("State").OnClientEvent:Connect(function(snapshot)
		Store.state = snapshot
		for _, fn in ipairs(listeners) do
			task.spawn(fn, snapshot)
		end
	end)
end

-- Requête serveur (achats, quêtes...). Retourne toujours une table { ok, msg, ... }.
function Store.request(action: string, payload: any?): any
	local ok, result = pcall(function()
		return Remotes.get("Request"):InvokeServer(action, payload or {})
	end)
	if not ok or type(result) ~= "table" then
		return { ok = false, msg = "Connexion au serveur impossible" }
	end
	return result
end

return Store
