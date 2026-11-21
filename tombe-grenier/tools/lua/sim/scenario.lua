local function check(cond, label)
	if not cond then
		error("ÉCHEC : " .. label, 2)
	end
	print("ok  " .. label)
end
local function find(list, pat)
	for _, t in ipairs(list) do
		local a, b = string.match(t, pat)
		if a then
			return a, b or true
		end
	end
	return nil
end

local Quests = require({ __path = "src/server/Quests.lua" })
local Locks = require({ __path = "src/server/Locks.lua" })

-- Monde : une seule maison simulée avec les points nécessaires
local function build()
	H.tagged = {}
	for k in pairs(H.tagged) do
		H.tagged[k] = nil
	end
end
local function world()
	local tagged = {}
	local parts = {}
	local function add(tag, x, y, z, name, attrs)
		local p = H.part(tag, x, y, z, name)
		for k, v in pairs(attrs or {}) do
			p:SetAttribute(k, v)
		end
		parts[#parts + 1] = p
		return p
	end
	local w = {}
	w.note = add("CodeNote", 10, 0, 10, "papier")
	w.coffret = add("Coffret", 95, 27, 73, "coffret")
	w.chest = add("Chest", 70, 27, 60, "malle")
	w.tomb = add("Tombe", 55, -9, 84, "cage de l'enfant")
	w.caveDoor = add("CaveDoor", 80, -6, 45, "porte métallique")
	w.mirror = add("Mirror", 119, 31, 30, "miroir")
	w.box = add("MusicBox", 20, 0, 20, "boîte")
	w.books = {}
	for i = 1, 6 do
		w.books[i] = add("Livre", 40 + i, 1, 5, "livre " .. i)
	end
	w.statues = {}
	for i = 1, 3 do
		w.statues[i] = add("Statue", 2 + 30 * i, 1, 2, "statue " .. i)
	end
	w.docs = {}
	for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
		w.docs[kind] = add("Interactable", 30, 1, 30, kind, { Kind = kind })
	end
	w.gramophone = add("Interactable", 25, 1, 25, "gramophone", { Kind = "gramophone ancien" })
	w.respire = add("Respire", 38, 1, 36, "mur")
	w.mannequin = add("Mannequin", 42, 13, 46, "mannequin")
	w.horloge = add("Horloge", 60, 4.5, 1.1, "horloge du hall")
	w.etiquette = add("Interactable", 118, 3, 14, "étiquette de la réserve", { Kind = "étiquette de la réserve" })
	w.compteur = add("Compteur", 118, 3, 30, "compteur de la cuisine")
	return w
end
local w = world()
local alice = H.player("Alice", 95, 27, 73)
H.players = { alice }

local function root(p)
	return p.Character:FindFirstChild("HumanoidRootPart")
end
local function moveTo(p, x, y, z)
	root(p).Position = H.v3(x, y, z)
end

-- 1. Installation de la partie : aucune erreur d'exécution
Quests.setup(12345)
Quests.init(function(reason)
	H.endReason = reason
end)
check(true, "setup + init s'exécutent")
local Objectives = require({ __path = "STUB:Objectives" })
local chain = __runfile("tools/lua/sim/chain_lib.lua")(H, Quests, w, alice, find)

-- 2. Papier, miroir et coffret : le code se reconstitue et ouvre le coffret
H.log = {}
H.trigger(w.note, "QuestPrompt", alice)
local prefix = find(H.msgs(alice), "chiffres : (%d%d)%.")
check(prefix ~= nil, "le papier donne deux chiffres")
H.log = {}
H.trigger(w.mirror, "QuestPromptReflet", alice)
local shown = find(H.msgs(alice), "« (%d%d) »")
check(shown ~= nil, "le miroir montre deux chiffres à l'envers")
local last2 = string.reverse(shown)
local code = prefix .. last2
H.log = {}
local wrong = (code == "0000") and "1111" or "0000"
Quests.submitCode(alice, wrong)
check(find(H.msgs(alice), "(Ce n'est pas le bon code)") ~= nil, "mauvais code refusé")
H.log = {}
Quests.submitCode(alice, code)
check(find(H.msgs(alice), "(Le couvercle se soulève)") ~= nil, "le bon code ouvre le coffret")
H.trigger(w.chest, "QuestPrompt", alice)
check(Quests.progress().done.chest == true, "la petite clé ouvre la malle")
check(Objectives.canPick("key", alice) == true, "la clé rouillée est prenable une fois la malle ouverte")
H.hasKey = true

-- 3. Gramophone puis boîte à musique : la mélodie se rejoue
H.log = {}
H.trigger(w.gramophone, "QuestPrompt", alice)
local melodyText = find(H.msgs(alice), "trois notes : ([^%.]+)%.")
check(melodyText ~= nil, "le gramophone donne sa mélodie")
local names = { ["do"] = 1, ["ré"] = 2, ["mi"] = 3, ["sol"] = 4 }
local notes = {}
for n in string.gmatch(melodyText, "[^,%s]+") do
	notes[#notes + 1] = names[n]
end
check(#notes == 3, "trois notes lues")
for _, idx in ipairs(notes) do
	H.trigger(w.box, "QuestPromptNote" .. idx, alice)
end
check(Locks.isOpen("salle de bain"), "la mélodie complète ouvre la salle de bain")

-- 4. Bibliothèque : marque-pages dans l'ordre, puis mauvais ordre
Quests.setup(777)
local marked = {}
for _, b in ipairs(w.books) do
	local m = b:GetAttribute("Mark")
	if m then
		marked[m] = b
	end
end
check(marked[1] and marked[2] and marked[3], "trois marque-pages posés")
H.log = {}
H.trigger(marked[2], "QuestPromptLivre", alice)
check(find(H.msgs(alice), "(se mélangent)") ~= nil, "mauvais ordre réinitialise")
for i = 1, 3 do
	H.trigger(marked[i], "QuestPromptLivre", alice)
end
check((H.battery or 0) > 0, "dernier marque-page : une pile (plus de raccourci vers la petite clé)")
check(Quests.progress().done.coffret ~= true, "la bibliothèque ne donne plus la petite clé")

-- 5. Statues : une orientation par statue, tirée par la seed (on retrouve une solution, dans l'ordre de la chaîne)
chain.reset(999)
chain.advanceTo("statues")
chain.turns = 0
chain.actions.statues(chain.sec)
check(Quests.progress().done.statues == true, "les statues ont une solution")

-- 6. Mur qui respire : refusé avant les statues, pile après
chain.reset(999)
H.log = {}
H.trigger(w.respire, "QuestPromptRespire", alice)
check(find(H.msgs(alice), "(Rien ne se passe)") ~= nil, "mur muet avant les statues")

-- 7. Documents, date de la plaque et fin vérité (l'enfant n'est sauvable qu'après le sous-sol)
chain.reset(12345)
chain.advanceTo("enfant")
H.endReason = nil
for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
	H.trigger(w.docs[kind], "QuestPrompt", alice)
end
local plaqueDate = nil
H.log = {}
H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
plaqueDate = find(H.msgs(alice), "gravée dessous : (%d%d/%d%d)")
check(plaqueDate ~= nil, "la plaque donne une date")
moveTo(alice, 55, -9, 80)
H.log = {}
H.trigger(w.tomb, "QuestPrompt", alice)
check(find(H.msgs(alice), "(Entre%-la au clavier)") ~= nil, "le cercueil demande la date")
H.log = {}
Quests.submitCode(alice, "1111")
check(find(H.msgs(alice), "(Ce n'est pas la date gravée)") ~= nil, "mauvaise date refusée")
Quests.onFreed = function()
	H.freed = true
end
local mm, dd = string.match(plaqueDate, "(%d%d)/(%d%d)")
Quests.submitCode(alice, mm .. dd)
check(H.freed == true and H.endReason == nil, "bonne date : enfant libéré, la partie continue")

-- 7sexies. Fin 4 (piège) : la date du cahier, fausse, scelle le cercueil
chain.reset(12345)
chain.advanceTo("enfant")
H.endReason = nil
for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
	H.trigger(w.docs[kind], "QuestPrompt", alice)
end
H.log = {}
H.trigger(w.docs["cahier d'écolier"], "QuestPrompt", alice)
local wrongMM, wrongDD = string.match(find(H.msgs(alice), "En marge, une date : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
H.log = {}
H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
local plaqueMM, plaqueDD = string.match(find(H.msgs(alice), "gravée dessous : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
check(
	plaqueMM ~= nil and (plaqueMM .. plaqueDD) ~= (wrongMM or "") .. (wrongDD or ""),
	"la plaque donne la date juste, lisible avant le cercueil"
)
check(wrongMM ~= nil, "le cahier donne une date fausse")
moveTo(alice, 55, -9, 80)
H.trigger(w.tomb, "QuestPrompt", alice)
Quests.submitCode(alice, wrongMM .. wrongDD)
check(H.endReason == nil, "une seule saisie de la date du cahier ne scelle pas (avertissement)")
check(
	find(H.msgs(alice), "(Tu ne pourras pas revenir en arrière)") ~= nil,
	"avertissement affiché avant confirmation"
)
Quests.submitCode(alice, "1111")
Quests.submitCode(alice, wrongMM .. wrongDD)
check(H.endReason == nil, "une saisie différente entre-temps annule l'armement")
Quests.submitCode(alice, wrongMM .. wrongDD)
check(H.endReason == "sealed", "la date du cahier confirmée scelle le cercueil (fin 4)")
check(string.find(Quests.endingText("sealed"), "/4%.") ~= nil, "le total des fins compte 4")

-- 7bis. Indication à la demande : une fois, puis limitée par le délai
Quests.setup(12345)
H.log = {}
Quests.hintFor(alice)
local hintSent = false
for _, e in ipairs(H.log) do
	if e.name == "Hint" and e.payload.text then
		hintSent = true
	end
end
check(hintSent, "la touche H envoie une indication")
H.log = {}
Quests.hintFor(alice)
local hintAgain = false
for _, e in ipairs(H.log) do
	if e.name == "Hint" then
		hintAgain = true
	end
end
check(not hintAgain and find(H.msgs(alice), "(Attends)") ~= nil, "indication limitée par le délai")

-- 7ter. Progression V2 : l'horloge du hall se règle avec la date de la plaque, pour chaque graine
local function solveHorloge(seed)
	chain.reset(seed)
	chain.advanceTo("horloge")
	H.log = {}
	H.trigger(w.docs["plaque du cercueil"], "QuestPrompt", alice)
	local mm, dd = string.match(find(H.msgs(alice), "gravée dessous : (%d%d/%d%d)") or "", "(%d%d)/(%d%d)")
	if not mm then
		return false, "plaque illisible"
	end
	H.log = {}
	H.trigger(w.horloge, "QuestPromptHorloge", alice)
	if find(H.msgs(alice), "(Entre la date de la plaque)") == nil then
		return false, "horloge muette"
	end
	H.log = {}
	Quests.submitCode(alice, "1111")
	if find(H.msgs(alice), "(ne bougent pas)") == nil then
		return false, "mauvaise date acceptée"
	end
	H.log = {}
	Quests.submitCode(alice, mm .. dd)
	if find(H.msgs(alice), "(se remet en marche)") == nil then
		return false, "bonne date refusée"
	end
	if H.lastObjective() == "Règle l'horloge du hall sur la date gravée sur la plaque du cercueil" then
		return false, "objectif non avancé"
	end
	return true
end
local okH, whyH = solveHorloge(12345)
check(okH, "horloge résolue avec la date de la plaque" .. (whyH and (" (" .. whyH .. ")") or ""))
for seed = 1, 60 do
	local ok, why = solveHorloge(seed)
	check(ok, ("horloge solvable, graine %d%s"):format(seed, why and (" : " .. why) or ""))
end

-- 7quater. Progression d'origine (ProgressionV2 = false) : l'horloge n'existe pas dans l'enchaînement
local Config = require({ __path = "src/shared/Config.lua" })
Config.Design.ProgressionV2 = false
for seed = 1, 60 do
	Quests.setup(seed)
	H.log = {}
	H.trigger(w.horloge, "QuestPromptHorloge", alice)
	check(find(H.msgs(alice), "(Entre la date de la plaque)") == nil, ("V1 : horloge inerte, graine %d"):format(seed))
	check(
		H.lastObjective() ~= "Règle l'horloge du hall sur la date gravée sur la plaque du cercueil",
		("V1 : pas d'objectif horloge, graine %d"):format(seed)
	)
	H.log = {}
	Quests.submitCode(alice, "0000")
	check(find(H.msgs(alice), "(ne bougent pas)") == nil, ("V1 : pas de saisie d'horloge, graine %d"):format(seed))
end
Config.Design.ProgressionV2 = true

-- 7quinquies. Énigme optionnelle de la cuisine : l'étiquette donne le code, le compteur l'accepte, une pile à la clé
local function solveCompteur(seed)
	Quests.setup(seed)
	H.log = {}
	H.trigger(w.etiquette, "QuestPromptEtiquette", alice)
	local digits = string.match(find(H.msgs(alice), "Réserve — (%d%d%d)") or "", "(%d%d%d)")
	if not digits then
		return false, "étiquette illisible"
	end
	H.log = {}
	H.trigger(w.compteur, "QuestPromptCompteur", alice)
	if find(H.msgs(alice), "(Trois chiffres)") == nil then
		return false, "compteur muet"
	end
	H.log = {}
	Quests.submitCode(alice, "9999" == digits and "1234" or "9999")
	if find(H.msgs(alice), "(pile neuve)") ~= nil then
		return false, "mauvais code accepté"
	end
	H.log = {}
	Quests.submitCode(alice, digits)
	if find(H.msgs(alice), "(pile neuve)") == nil then
		return false, "bon code refusé"
	end
	return true
end
local okC, whyC = solveCompteur(12345)
check(okC, "compteur de la cuisine résolu" .. (whyC and (" (" .. whyC .. ")") or ""))
for seed = 1, 60 do
	local ok, why = solveCompteur(seed)
	check(ok, ("compteur solvable, graine %d%s"):format(seed, why and (" : " .. why) or ""))
end

-- 7octies. Chaîne strictement séquentielle : à chaque pas, toute étape suivante tentée trop tôt est refusée
local function playChain(seed)
	chain.reset(seed)
	local n = #chain.steps
	for i = 1, n do
		local id = chain.steps[i].id
		local skip = id == "horloge" and not require({ __path = "src/shared/Config.lua" }).Design.ProgressionV2
		if not skip then
			local p = Quests.progress()
			if p.current ~= id then
				return false, ("étape active « %s », attendue « %s »"):format(tostring(p.current), id)
			end
			local ok, why = chain.attemptsBefore(id)
			if not ok then
				return false, why
			end
			chain.turns = 0
			chain.actions[id](chain.sec)
			if not Quests.progress().done[id] then
				return false, ("étape « %s » non réalisable dans l'ordre"):format(id)
			end
		end
	end
	return Quests.progress().done.enfant == true, "enfant non libéré"
end
H.endReason = nil
for seed = 1, 60 do
	local ok, why = playChain(seed)
	check(ok, ("chaîne complète dans l'ordre, graine %d%s"):format(seed, why and (" : " .. tostring(why)) or ""))
end
check(H.endReason == nil, "la chaîne n'a terminé la partie à aucun moment")
-- Répétition : refaire toutes les actions ne change rien
local function doneCount()
	local k = 0
	for _, v in pairs(Quests.progress().done) do
		if v then
			k = k + 1
		end
	end
	return k
end
local before = doneCount()
for _, step in ipairs(chain.steps) do
	chain.turns = 0
	chain.actions[step.id](chain.sec)
end
check(doneCount() == before, "répéter les actions ne change rien")
-- Sans l'horloge (ProgressionV2 = false) la chaîne reste séquentielle
do
	local Cfg = require({ __path = "src/shared/Config.lua" })
	Cfg.Design.ProgressionV2 = false
	for seed = 1, 20 do
		local ok, why = playChain(seed)
		check(ok, ("V1 : chaîne dans l'ordre, graine %d%s"):format(seed, why and (" : " .. tostring(why)) or ""))
	end
	Cfg.Design.ProgressionV2 = true
end
-- L'enfant (dans la cage de la cave) n'est jamais sauvable avant d'être entré dans la cave, même avec tous les documents et la date
chain.reset(4242)
chain.advanceTo("sortie")
Quests.onFrontDoor(alice)
for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
	H.trigger(w.docs[kind], "QuestPrompt", alice)
end
moveTo(alice, 55, -9, 80)
H.log = {}
H.trigger(w.tomb, "QuestPrompt", alice)
check(#H.msgs(alice) > 0, "message clair : l'étape n'est pas accessible")
Quests.submitCode(alice, chain.sec.date)
check(Quests.progress().done.enfant ~= true, "date saisie avant la cave : l'enfant reste prisonnier")
check(Quests.canAct("enfant") == false, "l'étape enfant est verrouillée côté serveur")
-- Une fois dans la cave, l'enfant se libère ; la sortie par le sous-sol ne compte qu'ensuite
chain.reset(4243)
chain.advanceTo("enfant")
for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
	H.trigger(w.docs[kind], "QuestPrompt", alice)
end
moveTo(alice, 103, -5, 100)
Quests.trackOnce()
check(Quests.progress().done.retour ~= true, "sortir avant d'avoir libéré l'enfant ne compte pas")
moveTo(alice, 55, -9, 80)
chain.actions.enfant(chain.sec)
check(Quests.progress().done.enfant == true, "l'enfant est libéré dans la cave")
moveTo(alice, 103, -5, 100)
Quests.trackOnce()
check(Quests.progress().done.retour == true, "puis la sortie par le sous-sol compte")

-- 7nonies. Journal de quêtes et indice automatique après 90 s sans progrès
do
	chain.reset(777)
	local lines = Quests.journal()
	check(find({ lines[1] }, "^Étape active") ~= nil, "le journal commence par l'étape active")
	check(lines[#lines]:find("à découvrir") ~= nil, "le journal annonce les étapes restantes sans les dévoiler")
	chain.advanceTo("coffret")
	lines = Quests.journal()
	check(lines[2] == "Ce que je sais :", "le journal a une rubrique « Ce que je sais »")
	check(
		lines[3] ~= nil and lines[3]:sub(1, 3) == "✓",
		"le journal liste d'abord les étapes faites, la plus récente en tête"
	)
	-- Indice automatique : rien avant 3 minutes, un indice ensuite, un seul par étape
	chain.reset(778)
	local cfgQ = require({ __path = "src/shared/Config.lua" }).Quests
	local t0 = os.clock()
	H.log = {}
	check(Quests.hintTick(t0 + cfgQ.HintDelay - 5) == false, "pas d'indice automatique avant 90 s")
	check(Quests.hintTick(t0 + cfgQ.HintDelay + 5) == true, "indice automatique après 90 s sans progrès")
	local sentHint = false
	for _, e in ipairs(H.log) do
		if e.name == "Message" and e.payload.text:find("^Indice") then
			sentHint = true
		end
	end
	check(sentHint, "l'indice automatique est un message de la partie")
	check(Quests.hintTick(t0 + 10 * cfgQ.HintDelay) == false, "un seul indice automatique par étape")
	chain.advanceTo("coffret")
	check(Quests.hintTick(os.clock() + cfgQ.HintDelay + 10) == true, "l'étape suivante a son propre indice")
end

-- 9. Mort et réapparition à chaque étape : le point de réapparition existe sans erreur et la chaîne continue ensuite
do
	chain.reset(777)
	local n = #chain.steps
	for i = 1, n do
		local id = chain.steps[i].id
		local skip = id == "horloge" and not require({ __path = "src/shared/Config.lua" }).Design.ProgressionV2
		if not skip then
			local before = Quests.progress()
			local okp, point = pcall(Quests.checkpoint)
			check(okp, ("point de réapparition lisible avant « %s »"):format(id))
			check(point == nil or point.X ~= nil, ("point de réapparition valide avant « %s »"):format(id))
			chain.turns = 0
			chain.actions[id](chain.sec)
			local after = Quests.progress()
			check(after.done[id] == true, ("étape « %s » faisable après une réapparition"):format(id))
			-- une mort ne retire aucune étape accomplie
			for _, step in ipairs(chain.steps) do
				if before.done[step.id] then
					check(after.done[step.id] == true, ("étape « %s » conservée après la mort"):format(step.id))
				end
			end
		end
	end
end

-- 10. Deux joueurs agissent en même temps sur le même objet : un seul effet, aucune erreur
do
	local bob = H.player("Bob", 95, 27, 73)
	H.players = { alice, bob }
	chain.reset(4242)
	chain.advanceTo("coffret")
	local sec = chain.sec
	-- même code au même instant
	moveTo(alice, 95, 27, 73)
	moveTo(bob, 95, 27, 73)
	H.trigger(w.coffret, "QuestPrompt", alice)
	H.trigger(w.coffret, "QuestPrompt", bob)
	Quests.submitCode(alice, sec.code)
	Quests.submitCode(bob, sec.code)
	check(Quests.progress().done.coffret == true, "coffret ouvert une fois par les deux joueurs")
	local keys = 0
	for _, e in ipairs(H.log) do
		if e.name == "Message" and string.find(e.payload.text or "", "petite clé est au fond", 1, true) then
			keys = keys + 1
		end
	end
	check(keys == 1, "la petite clé est donnée une seule fois (" .. keys .. ")")
	-- la malle ouverte par les deux
	chain.advanceTo("key")
	H.trigger(w.chest, "QuestPrompt", alice)
	H.trigger(w.chest, "QuestPrompt", bob)
	check(Quests.progress().done.chest == true, "malle ouverte une fois")
	-- les statues tournées en même temps
	chain.advanceTo("statues")
	for _ = 1, 5 do
		H.trigger(w.statues[3], "QuestPromptStatue", alice)
		H.trigger(w.statues[3], "QuestPromptStatue", bob)
	end
	check(true, "statues tournées à deux sans erreur")
	-- la porte de la cave et les documents lus à deux
	for _, kind in ipairs({ "journal intime", "cahier d'écolier", "photo de famille", "plaque du cercueil" }) do
		H.trigger(w.docs[kind], "QuestPrompt", alice)
		H.trigger(w.docs[kind], "QuestPrompt", bob)
	end
	check(true, "documents lus à deux sans erreur")
	H.players = { alice }
end

-- 11. Spam : mille soumissions de code fausses ou répétées ne cassent rien et ne font rien avancer
do
	chain.reset(99)
	chain.advanceTo("coffret")
	local before = Quests.progress()
	for i = 1, 1000 do
		Quests.submitCode(alice, tostring(i % 10000))
	end
	local after = Quests.progress()
	check(after.current == before.current, "le spam de codes faux ne fait pas avancer la chaîne")
	for i = 1, 200 do
		H.trigger(w.tomb, "QuestPrompt", alice)
		H.trigger(w.compteur, "QuestPrompt", alice)
		Quests.onFrontDoor(alice)
	end
	check(Quests.progress().current == before.current, "le spam d'actions hors ordre est refusé")
end

-- 8. Robustesse : toutes les graines de la partie tiennent sans erreur
for seed = 1, 60 do
	Quests.setup(seed)
end
check(true, "60 graines sans erreur")
print("TOUT PASSE")
