--[[
  Objectives : photos, clé, piles, sortie. Progression partagée par l'équipe.
  Les objets sont tirés au sort à chaque partie par MapBuilder.placeRound : on reconstruit
  les invites à chaque partie (setup), pas seulement au démarrage du serveur.
    Photo      : objet ramassable (ProximityPrompt)
    Key        : objet ramassable
    Battery    : pile de lampe torche, recharge la lampe
    ExitDoor   : porte de sortie, ouverte si photos >= PhotosRequired ET clé prise
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PlayerState = require(script.Parent.PlayerState)
local Gestures = require(script.Parent.Gestures)
local Locks = require(script.Parent.Locks)

local Objectives = {}

local team = { photos = 0, hasKey = false }
local exitReady = false
local onWin = nil
local exitPrompts = {}
local keyPrompt = nil -- invite de la clé : activée seulement quand la malle est ouverte

local function makePrompt(part, props)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = props.action
	prompt.ObjectText = props.object
	prompt.HoldDuration = props.hold or 0.3
	prompt.MaxActivationDistance = props.distance or 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = props.enabled ~= false
	prompt.Parent = part
	prompt.Triggered:Connect(props.onTriggered)
	return prompt
end

local function broadcast()
	Remotes.fireAll("HUD", {
		photos = team.photos,
		photosRequired = Config.Round.PhotosRequired,
		hasKey = team.hasKey,
		exitReady = exitReady,
	})
end

local statuesDone = false -- les statues du rez-de-chaussée sont résolues (rend la sortie possible)

local function refreshExit()
	exitReady = team.photos >= Config.Round.PhotosRequired and team.hasKey and statuesDone
	for _, prompt in ipairs(exitPrompts) do
		prompt.Enabled = exitReady
	end
	broadcast()
end

function Objectives.setStatuesDone(done)
	statuesDone = done == true
	refreshExit()
end

-- Invite de ramassage à usage unique ; onPick est appelé une seule fois
local function pickable(part, objectText, onPick)
	local taken = false
	local prompt = makePrompt(part, {
		action = "Ramasser",
		object = objectText,
		hold = 0.3,
		onTriggered = function(player)
			if taken then
				return
			end
			taken = true
			Gestures.riseAndRemove(part)
			onPick(player)
		end,
	})
	return prompt
end

-- Reconstruit toutes les invites de la partie en cours
function Objectives.setup()
	team.photos = 0
	team.hasKey = false
	exitReady = false
	exitPrompts = {}

	for _, part in ipairs(CollectionService:GetTagged("Photo")) do
		if part:IsA("BasePart") then
			pickable(part, "Photo", function()
				team.photos += 1
				if team.photos >= Config.Round.PhotosRequired then
					Locks.open("bureau") -- les trois souvenirs ouvrent le bureau
				end
				refreshExit()
			end)
		end
	end

	keyPrompt = nil
	for _, part in ipairs(CollectionService:GetTagged("Key")) do
		if part:IsA("BasePart") then
			-- La clé est fixe dans la malle : on retire les invites de la partie précédente
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("ProximityPrompt") then
					child:Destroy()
				end
			end
			keyPrompt = pickable(part, "Clé", function()
				team.hasKey = true
				refreshExit()
			end)
			keyPrompt.Enabled = false
		end
	end

	for _, part in ipairs(CollectionService:GetTagged("Battery")) do
		if part:IsA("BasePart") then
			pickable(part, "Pile", function(player)
				PlayerState.addBattery(player, Config.Flashlight.PickupAmount)
			end)
		end
	end

	-- Cailloux : chaque caillou ramassé donne un lancer
	for _, part in ipairs(CollectionService:GetTagged("Throwable")) do
		if part:IsA("BasePart") then
			pickable(part, "Caillou", function(player)
				PlayerState.addThrows(player, 1)
				local st = PlayerState.get(player)
				local count = st and st.throws or 0
				Remotes.fire("Message", player, { text = ("Caillou ramassé (%d lancer(s) en main). Touche G pour lancer."):format(count) })
			end)
		end
	end

	-- La porte de sortie est statique : on retire les invites de la partie précédente
	for _, part in ipairs(CollectionService:GetTagged("ExitDoor")) do
		if part:IsA("BasePart") then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("ProximityPrompt") then
					child:Destroy()
				end
			end
			local prompt = makePrompt(part, {
				action = "Ouvrir la porte",
				object = "Sortie",
				hold = 1.5,
				distance = 6,
				enabled = false,
				onTriggered = function(player)
					if exitReady and onWin then
						onWin(player)
					end
				end,
			})
			table.insert(exitPrompts, prompt)
		end
	end

	broadcast()
end

-- La malle est ouverte : la clé de la sortie devient prenable
function Objectives.unlockKey()
	if keyPrompt then
		keyPrompt.Enabled = true
	end
end

-- État courant de la progression (lecture seule)
function Objectives.snapshot()
	return { photos = team.photos, hasKey = team.hasKey, exitReady = exitReady }
end

-- Enregistre le callback de victoire et prépare la première partie
function Objectives.init(winCallback)
	onWin = winCallback
	Objectives.setup()
end

return Objectives
