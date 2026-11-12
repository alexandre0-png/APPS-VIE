--[[
	CinematicService : décide quand une cinématique est jouée (une seule fois par joueur) et prévient le client.
	Le client ne peut pas déclencher de cinématique ; il peut seulement la passer.
	Aucun effet sur le gameplay : une cinématique n'attribue rien et ne bloque rien.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local DataService = require(script.Parent.DataService)
local RemoteService = require(script.Parent.RemoteService)

local CinematicService = {}

-- Retourne true si la cinématique a été envoyée
function CinematicService.play(player, id)
	local cfg = Config.Cinematics
	if not cfg.Enabled then
		return false
	end
	local seq = cfg.Sequences[id]
	if not seq or not seq.enabled then
		return false
	end
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	profile.Seen = profile.Seen or {}
	if cfg.PlayOnce and profile.Seen[id] then
		return false
	end
	profile.Seen[id] = true
	DataService.markDirty(player)
	RemoteService.fire("Cinematic", player, id)
	return true
end

return CinematicService
