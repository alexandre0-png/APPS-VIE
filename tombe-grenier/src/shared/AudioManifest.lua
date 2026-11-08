--[[
  AudioManifest : clés audio du jeu.

  asset : identifiant Roblox « rbxassetid://… » obtenu après upload du fichier
          dans Roblox Studio (Avatar > Audio, ou Asset Manager).
          Chaîne vide = fichier à fournir. Le jeu continue sans crash et logge un warning.

  file  : fichier source de référence (documentation, Roblox ne lit pas ce chemin).
]]
return {
	-- Sons nommés
	mirror_break        = { file = "assets/audio/mirror_break.wav",        asset = "", volume = 1 },
	flashback_door_slam = { file = "assets/audio/flashback_door_slam.wav", asset = "", volume = 1 },
	child_cry_distant   = { file = "assets/audio/child_cry_distant.wav",   asset = "", volume = 0.2 },
	iron_bar_fall       = { file = "assets/audio/iron_bar_fall.wav",       asset = "", volume = 1 },
	crow_outside        = { file = "assets/audio/crow_outside.wav",        asset = "", volume = 0.6 },

	-- Sons à fournir (clés créées vides)
	drip             = { file = "assets/audio/drip.wav",             asset = "", volume = 0.5 },
	floor_creak      = { file = "assets/audio/floor_creak.wav",      asset = "", volume = 0.6 },
	coffin_lid       = { file = "assets/audio/coffin_lid.wav",       asset = "", volume = 0.8 },
	distant_voice    = { file = "assets/audio/distant_voice.wav",    asset = "", volume = 0.3 },
	heartbeat        = { file = "assets/audio/heartbeat.wav",        asset = "", volume = 0.6 },
	monster_chase    = { file = "assets/audio/monster_chase.wav",    asset = "", volume = 0.7 },
	scare            = { file = "assets/audio/scare.wav",            asset = "", volume = 0.9 },
	light_buzz       = { file = "assets/audio/light_buzz.wav",       asset = "", volume = 0.2 },
	flashlight_click = { file = "assets/audio/flashlight_click.wav", asset = "", volume = 0.5 },
}
