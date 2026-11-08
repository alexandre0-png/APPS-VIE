--[[
  Quests : enchaînement de l'histoire, par partie.

  Chaîne principale (sortie) :
    1. Rassembler 3 photos (Objectives)
    2. Trouver le papier du code (CodeNote, emplacement tiré à chaque partie)
    3. Ouvrir le coffret à bijoux avec le code (Keypad) : il contient une petite clé
    4. Ouvrir la malle avec la petite clé : elle contient la clé rouillée de la sortie
    5. Sortir par la porte d'entrée (photos + clé)

  Chaîne parallèle (fin « vérité ») :
    Lire les 4 documents (journal, cahier, photo de famille, plaque) puis libérer l'enfant au cercueil.

  Fins :
    fuite      : sortie par la porte d'entrée
    vérité     : libération de l'enfant
    malédiction: tout le monde meurt (cycle suivant)

  Le code change à chaque partie (seed). Les indications arrivent seules après un long silence.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rng = require(Shared.Rng)
local Noise = require(script.Parent.Noise)
local Objectives = require(script.Parent.Objectives)
local PlayerState = require(script.Parent.PlayerState)

local CFG = Config.Quests
local Quests = {}

local LORE_KINDS = { "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }

local LORE = {
	["journal intime"] = "Journal intime : « Il y a trente ans, une famille vivait ici. Un soir, notre enfant a disparu. Les voix venaient du grenier. »",
	["cahier d'écolier"] = "Cahier d'écolier : le même prénom, écrit des dizaines de fois. Puis un nom de famille, barré.",
	["photo de famille"] = "Photo de famille : quatre visages. Celui de l'enfant est effacé, à moitié.",
	["plaque du cercueil"] = "Plaque : un prénom délavé, sans nom de famille. Une date récente est gravée dessous.",
}

local FLAVOUR = {
	["bougies et lampe à pétrole"] = "La flamme vacille, comme si quelqu'un venait de souffler.",
	["peluche ancienne"] = "Une peluche usée. Elle est plus lourde que prévu.",
	["gramophone ancien"] = "Le gramophone grince, puis joue quelques notes. Le son porte très loin.",
}

-- Effets des objets interactifs (une fois par objet et par partie)
local ACTION = {
	["bougies et lampe à pétrole"] = "Allumer",
	["peluche ancienne"] = "Fouiller",
	["gramophone ancien"] = "Mettre en marche",
}

-- Une bougie éclaire un peu autour d'elle, une minute
local function lightCandle(position)
	local folder = Workspace:FindFirstChild("TombeMap") or Workspace
	local candle = Instance.new("Part")
	candle.Name = "Bougie allumée"
	candle.Anchored = true
	candle.CanCollide = false
	candle.Size = Vector3.new(0.4, 0.8, 0.4)
	candle.Position = position + Vector3.new(0, 0.8, 0)
	candle.Material = Enum.Material.Neon
	candle.Color = Color3.fromRGB(255, 190, 110)
	candle.Parent = folder
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 0.9
	light.Color = Color3.fromRGB(255, 180, 100)
	light.Parent = candle
	Debris:AddItem(candle, 60)
end

-- Le gramophone joue une douzaine de secondes : le son porte jusqu'au monstre
local function startGramophone(position)
	task.spawn(function()
		for _ = 1, 6 do
			Noise.emit(position, 0.9)
			task.wait(2)
		end
	end)
end

local HINTS = {
	photos = "Les souvenirs traînent sur les meubles. Une lampe aide à les voir dans le noir.",
	note = "Un papier froissé se cache sur une surface plate, près d'un meuble.",
	coffret = "Le coffret à bijoux est posé sur la table de la salle de la tombe.",
	chest = "La petite clé du coffret ouvre une serrure. Cherche la malle, dans la salle de la tombe.",
	key = "La clé rouillée est au fond de la malle.",
	exit = "Deux chemins : la porte d'entrée, ou la tombe. Lis les documents avant de choisir.",
}

local ENDING_TEXT = {
	win = "Fin 1 : la fuite. Tu sors de la maison.",
	truth = "Fin 3 : la vérité. L'enfant peut enfin partir.",
	lose = "Fin 2 : la malédiction. Le cercueil se referme.",
}
local ENDING_TOTAL = 3

local code = "0000"
local state = nil
local cycle = 1
local endFn = nil
local hintGiven = {}
local endingsSeen = {}
local active = false

local function codeFromSeed(seed)
	local rng = Rng.new(seed * 3 + 17)
	local digits = {}
	for i = 1, 4 do
		digits[i] = tostring(rng:int(0, 9))
	end
	return table.concat(digits)
end

local function freshState()
	return {
		note = false,        -- papier du code trouvé
		coffret = false,     -- coffret ouvert avec le code
		chest = false,       -- malle ouverte avec la petite clé
		smallKey = false,    -- la petite clé est obtenue
		lore = {},           -- documents lus, par type
		wrongCodes = 0,
		lastProgress = os.clock(),
		used = {},           -- objets interactifs déjà utilisés (une fois par partie)
	}
end

local function loreCount()
	local n = 0
	for _, kind in ipairs(LORE_KINDS) do
		if state.lore[kind] then
			n += 1
		end
	end
	return n
end

-- Étape courante de la chaîne principale
local function currentStep()
	local snap = Objectives.snapshot()
	if snap.photos < Config.Round.PhotosRequired then
		return "photos"
	end
	if not state.note then
		return "note"
	end
	if not state.coffret then
		return "coffret"
	end
	if not state.chest then
		return "chest"
	end
	if not snap.hasKey then
		return "key"
	end
	return "exit"
end

local OBJECTIVE = {
	photos = function()
		return ("Rassemble les souvenirs (%d/%d)"):format(Objectives.snapshot().photos, Config.Round.PhotosRequired)
	end,
	note = function()
		return "Trouve le code caché dans la maison"
	end,
	coffret = function()
		return ("Ouvre le coffret à bijoux (code : %s)"):format(state.note and code or "????")
	end,
	chest = function()
		return "Ouvre la malle du grenier"
	end,
	key = function()
		return "Prends la clé rouillée dans la malle"
	end,
	exit = function()
		return ("Sors par la porte d'entrée, ou libère l'enfant (documents lus : %d/%d)")
			:format(loreCount(), #LORE_KINDS)
	end,
}

local function pushObjective()
	if not state then
		return
	end
	Remotes.fireAll("Objective", { text = OBJECTIVE[currentStep()]() })
end

local function sayAll(text)
	Remotes.fireAll("Message", { text = text })
end

local function say(player, text)
	Remotes.fire("Message", player, { text = text })
end

-- Progression : réinitialise le délai avant indication et met à jour l'objectif
local function progressed()
	state.lastProgress = os.clock()
	pushObjective()
end

-- Invite de proximité propre aux quêtes (remplacée à chaque partie)
local function prompt(part, props, onTriggered)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") and child.Name == "QuestPrompt" then
			child:Destroy()
		end
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "QuestPrompt"
	p.ActionText = props.action
	p.ObjectText = props.object
	p.HoldDuration = props.hold or 0.3
	p.MaxActivationDistance = props.distance or 8
	p.RequiresLineOfSight = false
	p.Parent = part
	p.Triggered:Connect(onTriggered)
	return p
end

local function wire()
	-- Papier du code : une lecture suffit pour connaître le code
	for _, part in ipairs(CollectionService:GetTagged("CodeNote")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Lire", object = "Papier" }, function(player)
				if state.note then
					say(player, "Au verso, toujours le même code : " .. code .. ".")
					return
				end
				state.note = true
				say(player, "Un papier froissé. Au verso, quatre chiffres : " .. code .. ".")
				progressed()
			end)
		end
	end

	-- Fausses clés : elles ne correspondent à rien
	for _, part in ipairs(CollectionService:GetTagged("Decoy")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Examiner", object = "Clé" }, function(player)
				say(player, "Une clé. Elle ne s'ajuste à rien ici.")
			end)
		end
	end

	-- Coffret à bijoux : saisie du code sur l'écran de saisie du client
	for _, part in ipairs(CollectionService:GetTagged("Coffret")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Composer le code", object = "Coffret à bijoux", distance = 6 }, function(player)
				if state.coffret then
					say(player, "Le coffret est ouvert. Il est vide, à part une vieille photo.")
					return
				end
				Remotes.fire("Keypad", player, { length = 4 })
			end)
		end
	end

	-- Malle verrouillée : la petite clé du coffret l'ouvre
	for _, part in ipairs(CollectionService:GetTagged("Chest")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Ouvrir la malle", object = "Malle", hold = 0.8, distance = 6 }, function(player)
				if state.chest then
					say(player, "Vide, à part des vieux chiffons.")
					return
				end
				if not state.smallKey then
					say(player, "Verrouillée. Une petite clé doit ouvrir cette serrure.")
					return
				end
				state.chest = true
				Objectives.unlockKey()
				say(player, "Sous les chiffons, une clé rouillée.")
				progressed()
			end)
		end
	end

	-- Objets interactifs : documents et objets de décor
	for _, part in ipairs(CollectionService:GetTagged("Interactable")) do
		if part:IsA("BasePart") then
			local kind = part:GetAttribute("Kind")
			if LORE[kind] then
				prompt(part, { action = "Lire", object = kind, hold = 0.4 }, function(player)
					if not state.lore[kind] then
						state.lore[kind] = true
						progressed()
					end
					say(player, LORE[kind])
				end)
			elseif FLAVOUR[kind] then
				prompt(part, { action = ACTION[kind] or "Examiner", object = kind }, function(player)
					if state.used[part] then
						say(player, "Déjà fait.")
						return
					end
					state.used[part] = true
					say(player, FLAVOUR[kind])
					if kind == "bougies et lampe à pétrole" then
						lightCandle(part.Position)
					elseif kind == "peluche ancienne" then
						PlayerState.addThrows(player, 2) -- une pierre lisse cachée dedans : un jet de bruit en plus
						say(player, "Une pierre lisse, cachée dans la peluche. Tu peux la lancer avec G.")
					elseif kind == "gramophone ancien" then
						startGramophone(part.Position)
					end
				end)
			end
		end
	end

	-- Tombe : libérer l'enfant, possible seulement après avoir lu les documents
	for _, part in ipairs(CollectionService:GetTagged("Tombe")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Libérer l'enfant", object = "Tombe", hold = 2, distance = 6 }, function(player)
				if loreCount() < #LORE_KINDS then
					say(player, "Il te manque des souvenirs. Tu ne sais pas encore qui repose ici.")
					return
				end
				if endFn then
					endFn("truth")
				end
			end)
		end
	end
end

-- Saisie du code, envoyée par le client depuis le coffret
function Quests.submitCode(player, text)
	if not state or state.coffret or typeof(text) ~= "string" then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local coffret = CollectionService:GetTagged("Coffret")[1]
	if not root or not coffret or (root.Position - coffret.Position).Magnitude > 10 then
		return
	end
	if text == code then
		state.coffret = true
		state.smallKey = true
		say(player, "Le couvercle se soulève. Une petite clé est au fond.")
		progressed()
	else
		state.wrongCodes += 1
		say(player, "Ce n'est pas le bon code.")
		if state.wrongCodes == 3 and not state.note then
			say(player, "Le code est écrit quelque part. Cherche un papier.")
		end
	end
end

-- Démarre une partie : nouveau code, nouvel état, invites reconstruites
function Quests.setup(seed, cycleNumber)
	code = codeFromSeed(seed)
	cycle = cycleNumber or 1
	state = freshState()
	hintGiven = {}
	active = true
	wire()
	pushObjective()
	if cycle > 1 then
		sayAll(("Cycle %d. La date gravée sur la plaque a changé."):format(cycle))
	end
end

-- Fin de partie : texte affiché, et fins trouvées pendant la session serveur
function Quests.endingText(reason)
	active = false
	if ENDING_TEXT[reason] then
		endingsSeen[reason] = true
	end
	local count = 0
	for _ in pairs(endingsSeen) do
		count += 1
	end
	return (ENDING_TEXT[reason] or "") .. (" Fins trouvées : %d/%d."):format(count, ENDING_TOTAL)
end

-- Indications automatiques après un long silence, une seule fois par étape
local function hintLoop()
	while true do
		task.wait(5)
		if active and state then
			local step = currentStep()
			if os.clock() - state.lastProgress >= CFG.HintDelay and not hintGiven[step] then
				hintGiven[step] = true
				state.lastProgress = os.clock()
				sayAll(HINTS[step])
			end
		end
	end
end

function Quests.init(endCallback)
	endFn = endCallback
	task.spawn(hintLoop)
end

return Quests
