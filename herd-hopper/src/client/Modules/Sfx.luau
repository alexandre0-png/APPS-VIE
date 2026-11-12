-- Sons : uniquement les fichiers fournis avec le client Roblox (rbxasset://sounds/...).
-- Si un fichier n'existe pas, le son est simplement muet. Remplace les identifiants par tes propres
-- sons (rbxassetid://...) dans la table ci-dessous pour personnaliser l'ambiance.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sfx = {}

local SOUNDS = {
	launch = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.6, pitch = 1.2 },
	hook = { id = "rbxasset://sounds/snap.mp3", volume = 0.7, pitch = 1.1 },
	tame = { id = "rbxasset://sounds/victory.wav", volume = 0.6, pitch = 1.3 },
	down = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.6, pitch = 1 },
	tick = { id = "rbxasset://sounds/button.wav", volume = 0.6, pitch = 1 },
	go = { id = "rbxasset://sounds/switch.wav", volume = 0.8, pitch = 0.9 },
	geyser = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.7, pitch = 1 },
	boom = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.8, pitch = 1 },
	win = { id = "rbxasset://sounds/victory.wav", volume = 0.8, pitch = 1 },
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.2 },
	click = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitch = 1.4 },
}

function Sfx.play(name)
	local def = SOUNDS[name]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume
	sound.PlaybackSpeed = def.pitch
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 4)
end

return Sfx
