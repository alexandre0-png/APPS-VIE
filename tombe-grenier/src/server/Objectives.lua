--[[
  Objectives : photos, clé, sortie. Progression partagée par l'équipe.
  Tags :
    Photo     : BasePart ramassable (ProximityPrompt)
    Key       : BasePart ramassable (ProximityPrompt)
    ExitDoor  : BasePart de sortie, s'ouvre quand photos >= PhotosRequired ET clé prise
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Objectives = {}

local team = { photos = 0, hasKey = false }
local exitReady = false
local onWin = nil
local originalParent = {} -- part -> parent d'origine (pour la réinitialisation)
local exitPrompts = {}

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

local function refreshExit()
	exitReady = team.photos >= Config.Round.PhotosRequired and team.hasKey
	for _, prompt in ipairs(exitPrompts) do
		prompt.Enabled = exitReady
	end
	broadcast()
end

local function pickable(part, actionText, onPick)
	originalParent[part] = part.Parent
	makePrompt(part, {
		action = "Ramasser",
		object = actionText,
		hold = 0.3,
		onTriggered = function()
			if part.Parent == nil then
				return -- déjà ramassé
			end
			part.Parent = nil -- retiré du monde, restauré au reset
			onPick()
			refreshExit()
		end,
	})
end

function Objectives.init(winCallback)
	onWin = winCallback

	for _, part in ipairs(CollectionService:GetTagged("Photo")) do
		if part:IsA("BasePart") then
			pickable(part, "Photo", function()
				team.photos += 1
			end)
		end
	end

	for _, part in ipairs(CollectionService:GetTagged("Key")) do
		if part:IsA("BasePart") then
			pickable(part, "Clé", function()
				team.hasKey = true
			end)
		end
	end

	for _, part in ipairs(CollectionService:GetTagged("ExitDoor")) do
		if part:IsA("BasePart") then
			local prompt = makePrompt(part, {
				action = "Ouvrir la trappe",
				object = "Sortie",
				hold = 1.5,
				distance = 6,
				enabled = false,
				onTriggered = function()
					if exitReady and onWin then
						onWin()
					end
				end,
			})
			table.insert(exitPrompts, prompt)
		end
	end
end

-- Remet la progression à zéro et réapparaître les objets ramassés
function Objectives.reset()
	team.photos = 0
	team.hasKey = false
	for part, parent in pairs(originalParent) do
		if part.Parent == nil then
			part.Parent = parent
		end
	end
	refreshExit()
end

return Objectives
