--[[
  Prompts (serveur) : registre des invites d'interaction de la partie. Toute invite passe ici :
  - portée limitée (Config.Prompts.MaxDistance, 8 studs) et vue directe exigée (RequiresLineOfSight) ;
  - désactivée hors partie (hub, attente, écran de fin) : aucune invite ne reste affichée sans raison ;
  - désactivée tant que l'étape de son objet n'est pas accessible (Chain.canAct), sans masquer les étapes déjà faites.
  Les plaques du hub ne passent pas ici : elles servent justement à lancer la partie.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PromptRules = require(Shared.PromptRules)

local Prompts = {}

local entries = {} -- { prompt, wanted, step }
local roundActive = false
local gate = nil -- function(step) -> boolean

local function apply(entry)
	pcall(function()
		entry.prompt.Enabled = PromptRules.shouldBeEnabled(roundActive, entry.wanted, entry.step, gate)
	end)
end

-- Enregistre une invite : portée et vue directe imposées, état initial selon la partie. opts : { step, enabled, noLineOfSight }
function Prompts.register(prompt, opts)
	opts = opts or {}
	local cfg = Config.Prompts or {}
	pcall(function()
		prompt.MaxActivationDistance = PromptRules.distance(prompt.MaxActivationDistance, cfg.MaxDistance or 8)
		prompt.RequiresLineOfSight = cfg.LineOfSight ~= false and opts.noLineOfSight ~= true
	end)
	local entry = { prompt = prompt, wanted = opts.enabled ~= false, step = opts.step }
	table.insert(entries, entry)
	apply(entry)
	return prompt
end

-- Un objet décide lui-même d'être actif ou non (la clé après la malle, la sortie une fois prête)
function Prompts.set(prompt, value)
	for _, entry in ipairs(entries) do
		if entry.prompt == prompt then
			entry.wanted = value == true
			apply(entry)
			return
		end
	end
	pcall(function()
		prompt.Enabled = value == true
	end)
end

local function sweep()
	local alive = {}
	for _, entry in ipairs(entries) do
		local ok, parent = pcall(function()
			return entry.prompt.Parent
		end)
		if ok and parent then
			table.insert(alive, entry)
		end
	end
	entries = alive
end

function Prompts.setRound(active)
	roundActive = active == true
	sweep()
	for _, entry in ipairs(entries) do
		apply(entry)
	end
end

-- Fonction qui dit si une étape est accessible ; rappelée à chaque progression
function Prompts.setGate(fn)
	gate = fn
	Prompts.refresh()
end

function Prompts.refresh()
	sweep()
	for _, entry in ipairs(entries) do
		apply(entry)
	end
end

function Prompts.count()
	sweep()
	return #entries
end

return Prompts
