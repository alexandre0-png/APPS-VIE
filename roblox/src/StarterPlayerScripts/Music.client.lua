-- LocalScript : StarterPlayer/StarterPlayerScripts/Music (graphismes 9 : musique par zone). Applique ReplicatedStorage/Music (pur, testé).
-- Une piste par zone (hub, arène, château) d'après Config.lightingZoneAt, volume bas (Config.MUSIC.volume, plafond 0,3), fondus enchaînés, coupée pendant un combat
-- (panneau ArenaPanel de BattleGui visible : lu, jamais modifié), respect de Config.SOUNDS_ENABLED et du volume général du menu Plus (attribut local MasterVolume
-- posé par Client.client.lua ; 0 = muet). Sans aucune piste approuvée (ids vides), le script s'arrête aussitôt : prêt mais muet, aucun Sound créé.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Music = require(Shared:WaitForChild("Music"))

local cfg = Music.cfg(Config)
if not cfg.enabled or not Music.hasTracks(Config) then
	return -- prêt mais muet : aucune piste fournie (voir BLENDER_REQUESTS.md / A_FAIRE_UTILISATEUR.md « pistes à fournir »)
end
local player = Players.LocalPlayer

local sounds = {}
for _, zone in ipairs(Music.ZONES) do
	local id = cfg.tracks[zone]
	if id then
		local s = Instance.new("Sound")
		s.Name = "Music_" .. zone
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		sounds[zone] = s
	end
end

local function inBattle()
	local pg = player:FindFirstChild("PlayerGui")
	local bg = pg and pg:FindFirstChild("BattleGui")
	local panel = bg and bg:FindFirstChild("ArenaPanel")
	return panel ~= nil and panel.Visible == true
end

local function currentZone()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or type(Config.lightingZoneAt) ~= "function" then
		return "hub"
	end
	local ok, z = pcall(Config.lightingZoneAt, root.Position.X, root.Position.Z)
	return Music.zoneOf(ok and z or nil)
end

local last = os.clock()
while true do
	task.wait(cfg.interval)
	local ok, err = pcall(function()
		local now = os.clock()
		local dt = now - last
		last = now
		local master = player:GetAttribute("MasterVolume")
		local ctx = { zone = currentZone(), battle = inBattle(), master = type(master) == "number" and master or 1, soundsEnabled = Config.SOUNDS_ENABLED }
		for zone, s in pairs(sounds) do
			local v = Music.step(s.Volume, Music.target(Config, zone, ctx), dt, cfg.fade)
			s.Volume = v
			if v > 0 and not s.IsPlaying then
				s:Play()
			elseif v <= 0 and s.IsPlaying then
				s:Pause()
			end
		end
	end)
	if not ok then
		warn("[Music] arrêtée : " .. tostring(err))
		for _, s in pairs(sounds) do
			s:Destroy()
		end
		break
	end
end
