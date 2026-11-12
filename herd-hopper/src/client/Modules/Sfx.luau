-- Audio : effets sonores (fichiers fournis avec le client Roblox) et musique par lieu avec fondu enchaîné.
-- Les musiques se règlent dans Config.Audio.Music ; vides par défaut. Deux SoundGroups (Musique / Effets)
-- permettent le réglage du volume et le mode muet.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Sfx = {}

-- Fichiers du client Roblox. Si l'un manque, le son est simplement muet.
local SOUNDS = {
	launch = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.6, pitch = 1.2 },
	land = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5, pitch = 0.9 },
	hook = { id = "rbxasset://sounds/snap.mp3", volume = 0.7, pitch = 1.1 },
	tame = { id = "rbxasset://sounds/victory.wav", volume = 0.6, pitch = 1.3 },
	down = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, pitch = 1 },
	tick = { id = "rbxasset://sounds/button.wav", volume = 0.6, pitch = 1 },
	go = { id = "rbxasset://sounds/switch.wav", volume = 0.8, pitch = 0.9 },
	geyser = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.7, pitch = 1 },
	boom = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.8, pitch = 1 },
	win = { id = "rbxasset://sounds/victory.wav", volume = 0.8, pitch = 1 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.2 },
	heart = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.7 },
	collect = { id = "rbxasset://sounds/victory.wav", volume = 0.7, pitch = 1.1 },
	lasso = { id = "rbxasset://sounds/snap.mp3", volume = 0.7, pitch = 0.8 },
	boss = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.9, pitch = 0.6 },
	click = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitch = 1.4 },
}

local MODES = { "all", "sfx", "mute" }
local MODE_LABELS = { all = "SON : TOUT", sfx = "SON : EFFETS", mute = "SON : MUET" }

local mode = "all"
local musicGroup, sfxGroup = nil, nil
local current = nil -- { key, sound }

local function applyVolumes()
	if not musicGroup then
		return
	end
	musicGroup.Volume = mode == "all" and Config.Audio.MusicVolume or 0
	sfxGroup.Volume = mode == "mute" and 0 or Config.Audio.SfxVolume
end

function Sfx.init()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "HHMusic"
	musicGroup.Parent = SoundService
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "HHSfx"
	sfxGroup.Parent = SoundService
	applyVolumes()
end

function Sfx.play(name)
	local def = SOUNDS[name]
	if not def or mode == "mute" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.pitch
	sound.SoundGroup = sfxGroup
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

-- Joue la musique d'un lieu (clé de Config.Audio.Music) avec un fondu enchaîné. Sans identifiant : silence.
function Sfx.setMusic(key)
	if current and current.key == key then
		return
	end
	local fade = Config.Audio.FadeSeconds
	if current then
		local old = current.sound
		TweenService:Create(old, TweenInfo.new(fade), { Volume = 0 }):Play()
		Debris:AddItem(old, fade + 0.2)
		current = nil
	end
	local id = Config.Audio.Music[key]
	if type(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. key
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(fade), { Volume = 1 }):Play()
	current = { key = key, sound = sound }
end

function Sfx.cycleMode()
	local index = table.find(MODES, mode) or 1
	mode = MODES[index % #MODES + 1]
	applyVolumes()
	return MODE_LABELS[mode]
end

function Sfx.modeLabel()
	return MODE_LABELS[mode]
end

return Sfx
