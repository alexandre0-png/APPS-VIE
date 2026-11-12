--!nonstrict
-- État local du joueur (profil reçu du serveur) et appels de requêtes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local State = {}

State.Profile = nil
local listeners = {}

function State.OnChange(fn)
	table.insert(listeners, fn)
end

function State.Set(profile)
	State.Profile = profile
	for _, fn in ipairs(listeners) do
		task.spawn(fn, profile)
	end
end

-- Envoie une action au serveur. Renvoie (ok, message).
function State.Request(action, a, b)
	local ok, res = pcall(function()
		return Remotes.Request:InvokeServer(action, a, b)
	end)
	if not ok or type(res) ~= "table" then
		return false, "Connexion au serveur impossible"
	end
	return res.Ok == true, res.Msg or ""
end

return State
