--[[
  Audio : lecture d'un son par clé. Fonctionne côté serveur et client.
  Un asset manquant ne fait jamais planter le jeu : un warning est logué une seule fois.
]]
local Debris = game:GetService("Debris")

local Manifest = require(script.Parent.AudioManifest)
local Config = require(script.Parent.Config)

local Audio = {}
local warned = {}
local ready = {} -- clé -> true quand l'asset est chargé (sons synthétiques « new »)
local channels = {} -- un Sound réutilisé par clé et par parent

local function enabled()
	return not (Config.Audio and Config.Audio.Enabled == false)
end

-- Le son synthétique est-il chargé ? (faux tant que le préchargement n'est pas fini, ou si l'asset est refusé)
function Audio.isReady(key)
	return ready[key] == true
end

-- Pour les tests : force l'état de chargement d'une clé.
function Audio.markReady(key, value)
	ready[key] = value == true
end

-- Charge un son en arrière-plan ; ready[key] devient vrai seulement si l'asset a une durée. Aucune erreur remontée.
local function check(key, onDone)
	local entry = Manifest[key]
	if not entry or entry.asset == "" then
		onDone()
		return
	end
	local ok = pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = entry.asset
		game:GetService("ContentProvider"):PreloadAsync({ sound })
		ready[key] = sound.TimeLength > 0
		sound:Destroy()
	end)
	if not ok then
		ready[key] = false
	end
	onDone()
end

-- Précharge tous les sons marqués new = true (une seule fois), puis appelle onDone(). Plafond : Config.Audio.PreloadTimeout.
function Audio.preloadNew(onDone)
	if not enabled() then
		if onDone then
			onDone()
		end
		return
	end
	local keys = {}
	for key, entry in pairs(Manifest) do
		if entry.new and ready[key] == nil then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local pending = #keys
	local finished = false
	local function finish()
		if not finished then
			finished = true
			if onDone then
				pcall(onDone)
			end
		end
	end
	if pending == 0 then
		finish()
		return
	end
	for _, key in ipairs(keys) do
		task.spawn(function()
			check(key, function()
				pending -= 1
				if pending == 0 then
					finish()
				end
			end)
		end)
	end
	task.delay((Config.Audio and Config.Audio.PreloadTimeout) or 6, finish)
end

-- Sound réutilisé (une seule instance par clé et par parent) ; nil si le son n'est pas prêt. Ne joue pas.
function Audio.channel(key, parent, volume)
	local entry = Manifest[key]
	if not (enabled() and entry and entry.new and ready[key]) then
		return nil
	end
	parent = parent or workspace
	channels[parent] = channels[parent] or {}
	local sound = channels[parent][key]
	if not sound or not sound.Parent then
		sound = Instance.new("Sound")
		sound.Name = "Canal_" .. key
		sound.SoundId = entry.asset
		sound.Looped = entry.looped == true
		sound.Volume = volume or entry.volume or 0.5
		sound.Parent = parent
		channels[parent][key] = sound
	end
	return sound
end

-- Joue un canal réutilisé depuis le début (effets courts : pas, chuchotement, ramassage).
function Audio.fire(key, parent, volume)
	local sound = Audio.channel(key, parent, volume)
	if not sound then
		return nil
	end
	if volume then
		sound.Volume = volume
	end
	sound.TimePosition = 0
	sound:Play()
	return sound
end

function Audio.play(key, parent, options)
	local entry = Manifest[key]
	if not entry then
		warn(("[Audio] clé inconnue : '%s'"):format(tostring(key)))
		return nil
	end
	-- Son synthétique de remplacement : seulement s'il est chargé ; sinon l'ancien son reste
	if entry.prefer and enabled() and ready[entry.prefer] then
		entry = Manifest[entry.prefer]
	elseif entry.new and not (enabled() and ready[key]) then
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
