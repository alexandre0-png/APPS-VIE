--[[
  Audio : lecture d'un son par clé. Fonctionne côté serveur et client.
  Un asset manquant ne fait jamais planter le jeu : un warning est logué une seule fois.
]]
local Debris = game:GetService("Debris")

local Manifest = require(script.Parent.AudioManifest)

local Audio = {}
local warned = {}

function Audio.play(key, parent, options)
	local entry = Manifest[key]
	if not entry then
		warn(("[Audio] clé inconnue : '%s'"):format(tostring(key)))
		return nil
	end

	if entry.asset == "" then
		if not warned[key] then
			warned[key] = true
			warn(("[Audio] asset manquant pour '%s' (fichier attendu : %s)"):format(key, entry.file))
		end
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = entry.asset
	sound.Volume = (options and options.volume) or entry.volume or 1
	sound.RollOffMaxDistance = (options and options.range) or 60
	sound.Parent = parent or workspace
	sound.Looped = entry.looped == true or (options ~= nil and options.looped == true)
	-- Hauteur de lecture légèrement variable : un même son ne sonne pas deux fois pareil
	local speed = (options and options.speed) or 1
	sound.PlaybackSpeed = speed
	-- Réverbération optionnelle (pièces vides, grandes salles)
	if options and options.reverb then
		local rev = Instance.new("ReverbSoundEffect")
		rev.DecayTime = options.reverb
		rev.Mix = 0.35
		rev.Parent = sound
	end
	sound:Play()
	-- Un son en boucle reste en place jusqu'à destruction explicite par l'appelant
	if not sound.Looped then
		Debris:AddItem(sound, (options and options.lifetime) or 15)
	end
	return sound
end

return Audio
