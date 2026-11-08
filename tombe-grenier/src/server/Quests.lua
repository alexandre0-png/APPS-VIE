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
    malédiction: choix « Refermer le cercueil » après l'ouverture de la malle

  Le code change à chaque partie (seed). Les indications arrivent seules après un long silence.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Rng = require(Shared.Rng)
local Noise = require(script.Parent.Noise)
local Objectives = require(script.Parent.Objectives)
local PlayerState = require(script.Parent.PlayerState)
local MapBuilder = require(script.Parent.MapBuilder)
local Locks = require(script.Parent.Locks)

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
	["tasse de café"] = "Une tasse de café, pleine, encore tiède. Le liquide n'a pas coulé quand on l'a posée.",
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
	reflet = "Un miroir de la maison garde la fin du code. Le texte y est écrit à l'envers.",
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
local fuseOrder = {} -- ordre des trois interrupteurs pour rétablir le courant
local state = nil
local endFn = nil
local hintGiven = {}
local endingsSeen = {}
local active = false
local openCave -- défini plus bas (porte de la cave)

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
		used = {},
		fuseStep = 0,        -- interrupteurs bien actionnés, dans l'ordre
		fuseDone = false,    -- courant rétabli
		caveKey = false,     -- la vraie clé de la porte de la cave est prise
		caveOpen = false,    -- la porte métallique est ouverte           -- objets interactifs déjà utilisés (une fois par partie)
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
	-- Petite clé obtenue par la bibliothèque : le code et le coffret ne sont plus nécessaires
	if not state.smallKey then
		if not state.note then
			return "note"
		end
		if not state.mirrorRead then
			return "reflet"
		end
		if not state.coffret then
			return "coffret"
		end
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
	reflet = function()
		return "Lis les deux derniers chiffres dans un miroir (le texte est à l'envers)"
	end,
	coffret = function()
		return ("Ouvre le coffret à bijoux (code : %s)"):format(state.note and (code:sub(1, 2) .. "??") or "????")
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
	local name = props.name or "QuestPrompt"
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("ProximityPrompt") and child.Name == name then
			child:Destroy()
		end
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = props.action
	p.ObjectText = props.object
	p.HoldDuration = props.hold or 0.3
	p.MaxActivationDistance = props.distance or 8
	p.RequiresLineOfSight = false
	p.Parent = part
	p.Triggered:Connect(onTriggered)
	return p
end

-- Flashback visuel et sonore lié à un document lu (séquence courte côté client)
local function flashback(player, kind)
	if Config.Debug.SkipFlashbacks then
		return
	end
	Remotes.fire("Flashback", player, { kind = kind })
end

-- Mélodie du gramophone, date de la plaque et notes de la boîte à musique : tirées de la seed
local NOTE_NAMES = { "do", "ré", "mi", "sol" }
local melody = {}
local tombeDate = "0000"

local function melodyFromSeed(seed)
	local rng = Rng.new(seed * 13 + 7)
	local notes = {}
	for i = 1, 3 do
		notes[i] = rng:int(1, #NOTE_NAMES)
	end
	return notes
end

local function melodyText()
	local names = {}
	for i, n in ipairs(melody) do
		names[i] = NOTE_NAMES[n]
	end
	return table.concat(names, ", ")
end

-- Journal et plaque donnent la vraie date ; le cahier en donne une fausse, à recouper
local function writeLore(month, day)
	local shown = ("%02d/%02d"):format(month, day)
	local wrong = ("%02d/%02d"):format(month, day % 28 + 1)
	LORE["journal intime"] = ("Journal intime : « Il y a trente ans, une famille vivait ici. Le %s, notre enfant a disparu. Les voix venaient du grenier. »"):format(shown)
	LORE["cahier d'écolier"] = ("Cahier d'écolier : le même prénom, écrit des dizaines de fois. En marge, une date : %s. Puis un nom de famille, barré."):format(wrong)
	LORE["plaque du cercueil"] = ("Plaque : un prénom délavé, sans nom de famille. Une date gravée dessous : %s."):format(shown)
end

-- Bibliothèque : trois livres portent un marque-page (1, 2, 3), tirés à chaque partie.
-- Les lire dans l'ordre 1, 2, 3 donne la petite clé (autre chemin que le coffret).
local bookReads = {}

local function chooseBookMarks(seed)
	local books = CollectionService:GetTagged("Livre")
	table.sort(books, function(a, b)
		if a.Position.X ~= b.Position.X then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)
	for _, book in ipairs(books) do
		book:SetAttribute("Mark", nil)
	end
	local rng = Rng.new(seed * 19 + 5)
	local chosen = {}
	while #chosen < 3 and #chosen < #books do
		local i = rng:int(1, #books)
		if not table.find(chosen, i) then
			table.insert(chosen, i)
		end
	end
	for mark, i in ipairs(chosen) do
		books[i]:SetAttribute("Mark", mark)
	end
end

local function readBook(player, book)
	if bookReads[book] then
		say(player, "Tu as déjà feuilleté ce livre.")
		return
	end
	bookReads[book] = true
	local mark = book:GetAttribute("Mark")
	if not mark then
		say(player, "Des pages poussiéreuses, sans intérêt.")
		return
	end
	if mark ~= state.nextMark then
		-- Mauvais ordre : tout recommence
		state.nextMark = 1
		bookReads = {}
		say(player, "Les marque-pages se mélangent. Il faut reprendre dans l'ordre, du 1 au 3.")
		return
	end
	state.nextMark += 1
	if state.nextMark > 3 then
		state.smallKey = true
		say(player, "Entre les pages du dernier marque-page, une petite clé.")
	else
		say(player, "Marque-page n°" .. mark .. ". Il en reste d'autres, dans l'ordre.")
	end
	progressed()
end

-- Statues : chacune tourne par quarts de tour. Les trois doivent regarder la même cible (tirée par la seed).
-- Résolue, la cave s'ouvre (la vraie clé est inutile). Le mur qui respire donne alors une pile.
local statueBase = {}     -- [statue] = CFrame de départ, restauré à chaque partie
local statueTargets = {}  -- [statue] = orientation cible (0 à 3)

local function chooseStatues(seed)
	local statues = CollectionService:GetTagged("Statue")
	table.sort(statues, function(a, b)
		if a.Position.X ~= b.Position.X then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)
	local rng = Rng.new(seed * 23 + 11)
	statueTargets = {}
	for _, statue in ipairs(statues) do
		if not statueBase[statue] then
			statueBase[statue] = statue.CFrame
		end
		statue:SetAttribute("Facing", 0)
		statue.CFrame = statueBase[statue]
		statueTargets[statue] = rng:int(0, 3)
	end
end

-- Mannequin : pivote face au joueur qui s'approche, une seule fois par partie
local mannequinBase = {}   -- [part] = CFrame de départ
local mannequinTurned = {} -- [part] = true une fois pivoté pendant la partie en cours

local function resetMannequins()
	mannequinTurned = {}
	for _, part in ipairs(CollectionService:GetTagged("Mannequin")) do
		if part:IsA("BasePart") then
			if not mannequinBase[part] then
				mannequinBase[part] = part.CFrame
			end
			part.CFrame = mannequinBase[part]
		end
	end
end

local function mannequinLoop()
	while true do
		task.wait(0.5)
		if active and state then
			for _, part in ipairs(CollectionService:GetTagged("Mannequin")) do
				if part:IsA("BasePart") and not mannequinTurned[part] then
					mannequinBase[part] = mannequinBase[part] or part.CFrame
					for _, player in ipairs(Players:GetPlayers()) do
						local char = player.Character
						local root = char and char:FindFirstChild("HumanoidRootPart")
						if root and (root.Position - part.Position).Magnitude < 5 then
							mannequinTurned[part] = true
							part.CFrame = mannequinBase[part] * CFrame.Angles(0, math.pi, 0)
							Remotes.fire("Effect", player, { kind = "Scare" })
							break
						end
					end
				end
			end
		end
	end
end

local function turnStatue(player, statue)
	if state.statuesDone then
		say(player, "Les statues sont immobiles, figées dans leur position.")
		return
	end
	local facing = (statue:GetAttribute("Facing") + 1) % 4
	statue:SetAttribute("Facing", facing)
	statue.CFrame = statueBase[statue] * CFrame.Angles(0, facing * math.pi / 2, 0)
	for s, target in pairs(statueTargets) do
		if s:GetAttribute("Facing") ~= target then
			return
		end
	end
	state.statuesDone = true
	state.caveKey = true
	say(player, "Les trois statues se figent, face à la même direction. Un déclic, très loin en bas : la cave est accessible.")
	progressed()
end

-- Boîte à musique : une note jouée. Une faute repart de zéro ; la mélodie complète ouvre la salle de bain.
local function pressNote(player, index)
	if state.boxDone then
		say(player, "La boîte est silencieuse. Sa mélodie est finie.")
		return
	end
	if index == melody[state.melodyIdx + 1] then
		state.melodyIdx += 1
		if state.melodyIdx >= #melody then
			state.boxDone = true
			Locks.open("salle de bain")
			say(player, "La mélodie s'achève. Quelque part dans la maison, une serrure cède.")
		else
			say(player, "Juste. La suite, maintenant.")
		end
		progressed()
	else
		state.melodyIdx = 0
		say(player, "La mélodie se brouille et repart de zéro.")
	end
end

local function wire()
	-- Papier du code : une lecture suffit pour connaître le code
	for _, part in ipairs(CollectionService:GetTagged("CodeNote")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Lire", object = "Papier" }, function(player)
				if state.note then
					say(player, "Au verso, toujours les deux premiers chiffres : " .. code:sub(1, 2) .. ". Les deux autres sont dans la glace.")
					return
				end
				state.note = true
				say(player, "Un papier froissé. Au verso, les deux premiers chiffres : " .. code:sub(1, 2) .. ". Les deux autres sont dans la glace, à l'envers.")
				progressed()
			end)
		end
	end

	-- Miroirs : le texte y est écrit à l'envers. Les deux derniers chiffres du code s'y lisent.
	for _, part in ipairs(CollectionService:GetTagged("Mirror")) do
		if part:IsA("BasePart") then
			prompt(part, { name = "QuestPromptReflet", action = "Lire le reflet", object = "Miroir", distance = 6 }, function(player)
				if state.mirrorRead then
					say(player, "Le reflet ne t'apprend plus rien.")
					return
				end
				state.mirrorRead = true
				say(player, "Dans la glace, un texte écrit à l'envers : « " .. code:sub(3, 4):reverse() .. " ». Remets-le dans le bon sens.")
				progressed()
			end)
		end
	end

	-- Mannequin : examiner (le pivot se fait seul, à l'approche)
	for _, part in ipairs(CollectionService:GetTagged("Mannequin")) do
		if part:IsA("BasePart") then
			prompt(part, { name = "QuestPromptMannequin", action = "Examiner", object = "Mannequin", distance = 6 }, function(player)
				say(player, "Un mannequin de couturière. On lui a mis une petite robe, et une épingle est restée plantée dans le buste.")
			end)
		end
	end

	-- Statues : chaque tour compte, la solution est la même orientation pour les trois
	for _, part in ipairs(CollectionService:GetTagged("Statue")) do
		if part:IsA("BasePart") then
			prompt(part, { name = "QuestPromptStatue", action = "Tourner la statue", object = "Statue ancienne", hold = 0.2, distance = 6 }, function(player)
				turnStatue(player, part)
			end)
		end
	end

	-- Mur qui respire : une fois les statues résolues, il livre une pile
	for _, part in ipairs(CollectionService:GetTagged("Respire")) do
		if part:IsA("BasePart") then
			prompt(part, { name = "QuestPromptRespire", action = "Poser la main sur le mur", object = "Mur", hold = 0.5, distance = 5 }, function(player)
				if not state.statuesDone then
					say(player, "Le mur est froid et immobile. Rien ne se passe.")
					return
				end
				if state.breathed then
					say(player, "Le mur ne respire plus.")
					return
				end
				state.breathed = true
				PlayerState.addBattery(player, Config.Flashlight.PickupAmount)
				PlayerState.addSanity(player, -15)
				say(player, "Le mur respire, lentement. Une chaleur, puis un battement sous le plâtre. Une pile tombe d'une fente.")
			end)
		end
	end

	-- Bibliothèque : feuilleter les livres
	for _, part in ipairs(CollectionService:GetTagged("Livre")) do
		if part:IsA("BasePart") then
			prompt(part, { name = "QuestPromptLivre", action = "Feuilleter", object = "Livre", hold = 0.4, distance = 6 }, function(player)
				readBook(player, part)
			end)
		end
	end

	-- Boîte à musique : rejouer la mélodie du gramophone, note par note
	for _, part in ipairs(CollectionService:GetTagged("MusicBox")) do
		if part:IsA("BasePart") then
			for index, noteName in ipairs(NOTE_NAMES) do
				prompt(part, { name = "QuestPromptNote" .. index, action = "Jouer " .. noteName, object = "Boîte à musique", hold = 0.2, distance = 6 }, function(player)
					pressNote(player, index)
				end)
			end
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
				if Quests.onChestOpened then
					Quests.onChestOpened(player)
				end
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
					if kind == "journal intime" then
						local st = PlayerState.get(player)
						if st and #st.log > 0 then
							local recent = {}
							for i = math.max(1, #st.log - 1), #st.log do
								table.insert(recent, st.log[i])
							end
							say(player, "Une ligne récente, de ta main : « " .. table.concat(recent, " ") .. " »")
						end
					end
					if kind == "cahier d'écolier" then
						Locks.open("cahier") -- lire le cahier ouvre la chambre d'ami
					end
					if kind == "photo de famille" then
						flashback(player, "family")
					elseif kind == "cahier d'écolier" then
						flashback(player, "cahier")
					elseif kind == "journal intime" then
						flashback(player, "journal")
					elseif kind == "plaque du cercueil" then
						flashback(player, "plaque")
					end
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
						say(player, "Le gramophone joue trois notes : " .. melodyText() .. ".")
					end
				end)
			end
		end
	end

	-- Clé de la salle de bain : ouvre la porte verrouillée de la salle de bain
	for _, part in ipairs(CollectionService:GetTagged("BathKey")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Prendre", object = "Clé", hold = 0.3 }, function(player)
				if Locks.isOpen("salle de bain") then
					return
				end
				Locks.open("salle de bain")
				part:Destroy()
				say(player, "Une clé de laiton. Elle doit ouvrir la salle de bain.")
				progressed()
			end)
		end
	end

	-- Disjoncteurs : trois interrupteurs, dans l'ordre tiré pour la partie
	for _, part in ipairs(CollectionService:GetTagged("Switch")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Actionner", object = "Interrupteur", hold = 0.2 }, function(player)
				if state.fuseDone then
					say(player, "Le courant est déjà revenu.")
					return
				end
				if part.Name == fuseOrder[state.fuseStep + 1] then
					state.fuseStep += 1
					if state.fuseStep == #fuseOrder then
						state.fuseDone = true
						MapBuilder.powerOn(60)
						Locks.open("cellier")
						Remotes.fire("Effect", player, { kind = "Cine", name = "courant" })
						say(player, "Un claquement. Le courant revient, dans un grincement.")
					else
						say(player, "Un déclic.")
					end
				else
					state.fuseStep = 0
					say(player, "Rien ne se passe. Une étincelle, puis le noir.")
				end
			end)
		end
	end

	-- Clé de la porte métallique : une des trois clés posées, les autres ne servent à rien
	for _, part in ipairs(CollectionService:GetTagged("CaveKey")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Prendre", object = "Clé", hold = 0.3 }, function(player)
				if state.caveKey then
					return
				end
				state.caveKey = true
				part:Destroy()
				say(player, "Une clé lourde, marquée d'un trait. Elle doit ouvrir la porte de la cave.")
				progressed()
			end)
		end
	end

	-- Porte métallique de la cave : s'ouvre avec la clé, et libère le passage sud
	for _, part in ipairs(CollectionService:GetTagged("CaveDoor")) do
		if part:IsA("BasePart") then
			prompt(part, { action = "Ouvrir", object = "Porte métallique", hold = 1, distance = 6 }, function(player)
				if state.caveOpen then
					say(player, "La porte est ouverte. Le passage sud est libre.")
					return
				end
				if not state.caveKey then
					say(player, "Verrouillée. La clé doit se trouver quelque part dans la maison.")
					return
				end
				state.caveOpen = true
				openCave(part)
				say(player, "Un grincement métallique. La porte cède.")
				-- Le monstre se lance sur celui qui a ouvert : fuir, ou rester sauver la personne
				if Quests.onCaveOpened then
					Quests.onCaveOpened(player)
				end
				say(player, "Quelqu'un gémit au fond de la cave. Tu peux fuir, ou rester et le sauver.")
				progressed()
			end)
			-- Sauver : rester près de la porte pendant trois secondes, une fois la cave ouverte
			prompt(part, { name = "QuestPromptSauver", action = "Sauver la personne", object = "Cave", hold = 3, distance = 6 }, function(player)
				if not state.caveOpen then
					return
				end
				say(player, "Tu la tires vers la lumière. Elle murmure un prénom.")
				if endFn then
					endFn("truth")
				end
			end)
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
				-- La date gravée sur la plaque ouvre la fin : on la saisit au clavier
				state.tombePending = true
				say(player, "La plaque porte une date. Entre-la au clavier, mois puis jour, en quatre chiffres.")
				Remotes.fire("Keypad", player, { length = 4 })
			end)
			-- Choix de la malédiction : refermer le cercueil, une fois la malle ouverte
			prompt(part, { name = "QuestPromptCercueil", action = "Refermer le cercueil", object = "Tombe", hold = 2, distance = 6 }, function()
				if not state or not state.chest then
					return
				end
				if endFn then
					endFn("lose")
				end
			end)
		end
	end
end

-- Date de la plaque, saisie près du cercueil : ouvre la fin « vérité »
local function submitDate(player, text)
	local tomb = CollectionService:GetTagged("Tombe")[1]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not tomb or (root.Position - tomb.Position).Magnitude > 10 then
		return
	end
	if text == tombeDate then
		state.tombePending = false
		if endFn then
			endFn("truth")
		end
	else
		say(player, "Ce n'est pas la date gravée. Recoupe les documents.")
	end
end

-- Saisie du code, envoyée par le client depuis le coffret
function Quests.submitCode(player, text)
	if state and state.tombePending and typeof(text) == "string" then
		submitDate(player, text)
		return
	end
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

local SWITCHES = { "interrupteur cellier", "interrupteur cave", "interrupteur passage sud" }

-- Ordre des interrupteurs, tiré à partir de la seed de partie
local function fuseOrderFromSeed(seed)
	local rng = Rng.new(seed * 5 + 29)
	local list = table.clone(SWITCHES)
	for i = #list, 2, -1 do
		local j = rng:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Porte de la cave : fermée au début de chaque partie
local function resetCave()
	for _, wall in ipairs(CollectionService:GetTagged("InvisibleWall")) do
		if wall:GetAttribute("Puzzle") == "grille" then
			wall.CanCollide = true
		end
	end
	for _, door in ipairs(CollectionService:GetTagged("CaveDoor")) do
		if door:IsA("BasePart") then
			door.Transparency = 0
		end
	end
end

-- Porte de la cave : la grille invisible cesse de bloquer, la porte disparaît
openCave = function(door)
	for _, wall in ipairs(CollectionService:GetTagged("InvisibleWall")) do
		if wall:GetAttribute("Puzzle") == "grille" then
			wall.CanCollide = false
		end
	end
	door.Transparency = 1
	door.CanCollide = false
end

-- Démarre une partie : nouveau code, nouvel état, invites reconstruites
-- Point de réapparition selon l'avancée : après la malle, on revient près de la malle ;
-- après le coffret, près du coffret ; sinon nil (cercueil, point de spawn par défaut).
function Quests.checkpoint()
	-- Dans la cave, en pleine poursuite : toute mort ramène au cercueil de départ
	if not state or state.caveOpen then
		return nil
	end
	local tag = (state.chest and "Chest") or (state.coffret and "Coffret") or nil
	if not tag then
		return nil
	end
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		if part:IsA("BasePart") then
			return part.Position
		end
	end
	return nil
end

function Quests.setup(seed)
	code = codeFromSeed(seed)
	fuseOrder = fuseOrderFromSeed(seed)
	Locks.reset()
	state = freshState()
	state.mirrorRead = false
	state.melodyIdx = 0
	state.boxDone = false
	state.tombePending = false
	state.nextMark = 1
	bookReads = {}
	chooseBookMarks(seed)
	state.statuesDone = false
	state.breathed = false
	chooseStatues(seed)
	resetMannequins()
	melody = melodyFromSeed(seed)
	local dateRng = Rng.new(seed * 17 + 3)
	local month = dateRng:int(1, 12)
	local day = dateRng:int(1, 28)
	tombeDate = ("%02d%02d"):format(month, day)
	writeLore(month, day)
	hintGiven = {}
	active = true
	resetCave()
	wire()
	pushObjective()
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

-- Indication à la demande : l'indication de l'étape courante, au plus une fois toutes les HintCooldown secondes
function Quests.hintFor(player)
	if not active or not state then
		return
	end
	local now = os.clock()
	if state.hintAt and now - state.hintAt < CFG.HintCooldown then
		say(player, "Attends un peu avant une nouvelle indication.")
		return
	end
	state.hintAt = now
	Remotes.fire("Hint", player, { text = HINTS[currentStep()] })
end

function Quests.init(endCallback)
	endFn = endCallback
	task.spawn(hintLoop)
	task.spawn(mannequinLoop)
end

return Quests
