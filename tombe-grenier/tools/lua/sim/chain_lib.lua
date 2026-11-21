-- Bibliothèque de la simulation : joue la chaîne de progression dans l'ordre, et tente chaque étape trop tôt.
-- make(H, Quests, w, alice, find) renvoie { advanceTo, attempts, steps, secrets }.
return function(H, Quests, w, alice, find)
	local Objectives = require({ __path = "STUB:Objectives" })
	local Chain = require({ __path = "src/shared/Chain.lua" })
	local lib = {}

	local function root(p)
		return p.Character:FindFirstChild("HumanoidRootPart")
	end
	local function moveTo(x, y, z)
		root(alice).Position = H.v3(x, y, z)
	end
	local function lastMsgs()
		return H.msgs(alice)
	end

	-- Secrets de la graine, lus par une partie jetable (documents lisibles à tout moment, papier et miroir libres)
	function lib.secrets(seed)
		Quests.setup(seed)
		local s = {}
		H.log = {}
		H.trigger(w.note, "QuestPrompt", alice)
		local prefix = find(lastMsgs(), "chiffres : (%d%d)%.")
		H.log = {}
		H.trigger(w.mirror, "QuestPromptReflet", alice)
		local shown = find(lastMsgs(), "« (%d%d) »")
		s.code = prefix .. string.reverse(shown)
		H.log = {}
		H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
		local mm, dd = string.match(find(lastMsgs(), "gravée dessous : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
		s.date = mm .. dd
		return s
	end

	local function pressMelody()
		H.log = {}
		H.trigger(w.gramophone, "QuestPrompt", alice)
		local text = find(lastMsgs(), "trois notes : ([^%.]+)%.")
		local names = { ["do"] = 1, ["ré"] = 2, ["mi"] = 3, ["sol"] = 4 }
		for n in string.gmatch(text or "", "[^,%s]+") do
			H.trigger(w.box, "QuestPromptNote" .. names[n], alice)
		end
	end

	-- Odomètre : on tourne les trois statues jusqu'à la solution
	local function solveStatues(maxTurns)
		for _ = 1, maxTurns or 70 do
			if Quests.progress().done.statues then
				return true
			end
			H.trigger(w.statues[3], "QuestPromptStatue", alice)
			-- retenue : toutes les quatre rotations de la troisième, on avance la deuxième, etc.
			lib.turns = (lib.turns or 0) + 1
			if lib.turns % 4 == 0 then
				H.trigger(w.statues[2], "QuestPromptStatue", alice)
			end
			if lib.turns % 16 == 0 then
				H.trigger(w.statues[1], "QuestPromptStatue", alice)
			end
		end
		return Quests.progress().done.statues == true
	end

	-- Actions de chaque étape (dans l'ordre de la chaîne). Chacune réussit si la chaîne l'autorise.
	lib.actions = {
		note = function(sec)
			H.trigger(w.note, "QuestPrompt", alice)
		end,
		reflet = function(sec)
			H.trigger(w.mirror, "QuestPromptReflet", alice)
		end,
		coffret = function(sec)
			moveTo(95, 27, 73)
			H.trigger(w.coffret, "QuestPrompt", alice)
			Quests.submitCode(alice, sec.code)
		end,
		chest = function(sec)
			H.trigger(w.chest, "QuestPrompt", alice)
		end,
		key = function(sec)
			if Objectives.canPick and Objectives.canPick("key", alice) then
				H.hasKey = true
			end
		end,
		melodie = function(sec)
			pressMelody()
		end,
		horloge = function(sec)
			H.trigger(w.horloge, "QuestPromptHorloge", alice)
			Quests.submitCode(alice, sec.date)
		end,
		statues = function(sec)
			lib.turns = 0
			solveStatues()
		end,
		photos = function(sec)
			if Objectives.canPick and Objectives.canPick("photo", alice) then
				H.photos = 3
			end
		end,
		sortie = function(sec)
			Quests.onFrontDoor(alice)
		end,
		cave = function(sec)
			moveTo(103, -5, 100)
			H.trigger(w.caveDoor, "QuestPrompt", alice)
		end,
		sous_sol = function(sec)
			moveTo(60, -8, 45)
			Quests.trackOnce()
		end,
		retour = function(sec)
			moveTo(103, -5, 100)
			Quests.trackOnce()
		end,
		enfant = function(sec)
			for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
				H.trigger(w.docs[kind], "QuestPrompt", alice)
			end
			moveTo(55, -9, 80)
			H.trigger(w.tomb, "QuestPrompt", alice)
			Quests.submitCode(alice, sec.date)
		end,
	}

	function lib.reset(seed)
		H.photos = 0
		H.hasKey = false
		H.log = {}
		local sec = lib.secrets(seed)
		Quests.setup(seed) -- la vraie partie, même graine
		H.photos = 0
		H.hasKey = false
		H.log = {}
		lib.sec = sec
		return sec
	end

	-- Avance, en respectant l'ordre, jusqu'à ce que l'étape `id` soit la prochaine à faire
	function lib.advanceTo(id)
		local target = Chain.index(id)
		for i = 1, target - 1 do
			local step = Chain.STEPS[i].id
			if not Quests.progress().done[step] then
				lib.actions[step](lib.sec)
			end
			assert(Quests.progress().done[step], "étape non réalisée : " .. step)
		end
	end

	-- Tentatives trop tôt : pour une étape donnée, on essaie toutes les étapes suivantes et on exige qu'aucune ne passe
	function lib.attemptsBefore(id)
		local before = Quests.progress()
		local function snapshot()
			local p = Quests.progress()
			local n = 0
			for _, step in ipairs(Chain.STEPS) do
				if p.done[step.id] then
					n = n + 1
				end
			end
			return n, p.current
		end
		local n0, cur0 = snapshot()
		local startIdx = Chain.index(id)
		for i = startIdx, #Chain.STEPS do
			local step = Chain.STEPS[i].id
			-- tout sauf l'étape active elle-même
			if step ~= cur0 then
				local saveTurns = lib.turns
				-- sauvegarde des variables simulées : une tentative trop tôt ne doit rien changer
				local photos, key = H.photos, H.hasKey
				lib.actions[step](lib.sec)
				lib.turns = saveTurns
				local n1, cur1 = snapshot()
				if n1 ~= n0 or cur1 ~= cur0 then
					return false, ("étape « %s » réalisée alors que « %s » est active"):format(step, cur0)
				end
				if H.photos ~= photos and not Quests.progress().done.photos then
					return false, "photos données trop tôt"
				end
				if H.hasKey ~= key and not Quests.progress().done.key then
					return false, "clé donnée trop tôt"
				end
			end
		end
		return true
	end

	lib.steps = Chain.STEPS
	lib.Chain = Chain
	return lib
end
