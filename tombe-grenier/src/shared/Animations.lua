--[[
  Animations : animations du monstre, chargées sur son Animator.
  Locomotion : immobile / marche / course (une seule active à la fois).
  Attaques : attaque, attaque rapide, attaque surprise (surprise après une période calme).

  Les animations ne s'affichent que sur un rig R15 (ou un modèle dont les joints correspondent).
]]
local Animations = {}

local IDS = {
	immobile = "rbxassetid://616158929",
	marche = "rbxassetid://616168032",
	course = "rbxassetid://616163682",
	attaque = "rbxassetid://708553116",
	attaque_rapide = "rbxassetid://674871189",
	attaque_surprise = "rbxassetid://717879555",
}

local LOOPED = { immobile = true, marche = true, course = true }
local PRIORITY = {
	immobile = Enum.AnimationPriority.Idle,
	marche = Enum.AnimationPriority.Movement,
	course = Enum.AnimationPriority.Movement,
	attaque = Enum.AnimationPriority.Action,
	attaque_rapide = Enum.AnimationPriority.Action,
	attaque_surprise = Enum.AnimationPriority.Action,
}

-- Charge toutes les animations sur l'Animator du Humanoid
function Animations.load(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local tracks = {}
	for key, id in pairs(IDS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = LOOPED[key] == true
			track.Priority = PRIORITY[key]
			tracks[key] = track
		else
			warn(("[Animations] impossible de charger '%s' (%s)"):format(key, id))
		end
	end
	return { tracks = tracks, current = nil }
end

-- Joue la locomotion demandée si elle diffère de la courante
function Animations.setLocomotion(set, key)
	if set.current == key then
		return
	end
	if set.current and set.tracks[set.current] then
		set.tracks[set.current]:Stop(0.2)
	end
	local track = set.tracks[key]
	if track then
		track:Play(0.2)
	end
	set.current = key
end

-- Joue une attaque : surprise si elle arrive après une période calme
function Animations.attack(set, surprise)
	local key
	if surprise then
		key = "attaque_surprise"
	else
		key = math.random() < 0.5 and "attaque" or "attaque_rapide"
	end
	local track = set.tracks[key]
	if track then
		track:Play(0.05)
	end
end

return Animations
