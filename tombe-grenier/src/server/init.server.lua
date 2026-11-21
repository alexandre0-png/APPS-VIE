--[[
  Serveur principal : boucle de partie, branchement des systèmes, événements réseau.
  Autorité serveur : toute décision (dégâts, objectifs, IA, sanité) se prend ici.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Guard = require(Shared.Guard)
-- Les Remotes existent avant tout le reste (et avant tout yield) : le client les attend dès son démarrage.
Remotes.init()

local PlayerState = require(script.PlayerState)
local MonsterAI = require(script.MonsterAI)
local Lights = require(script.Lights)
local FallingObjects = require(script.FallingObjects)
local Ambience = require(script.Ambience)
local Markers = require(script.Markers)
local MapBuilder = require(script.MapBuilder)
local Quests = require(script.Quests)
local Noise = require(script.Noise)
local Audio = require(Shared.Audio)
local Prompts = require(script.Prompts)
local Objectives = require(script.Objectives)
local Hiding = require(script.Hiding)
local Props = require(script.Props)
local Hub = require(script.Parent.Common.Hub)
local ModelLoader = require(script.ModelLoader)
local Finale = require(script.Finale)
local Shop = require(script.Shop)
local Respawn = require(script.Respawn)
local Gestures = require(script.Gestures)
local Tension = require(Shared.Tension)
local Balance = require(Shared.Balance)
local Ranks = require(Shared.Ranks)
local Challenges = require(Shared.Challenges)
local Replay = require(Shared.Replay)
local Tutorial = require(Shared.Tutorial)
local Profile = require(script.Parent.Common.Profile)
local SpawnSafety = require(script.Parent.Common.SpawnSafety)
local SpawnLog = require(script.Parent.Common.SpawnLog)

-- Aucun personnage ne se charge tant que la carte n'existe pas : un joueur téléporté pendant le chargement
-- des modèles ou la construction de la carte tomberait dans le vide. Respawn.setReady rouvre la porte.
-- Dans le lieu hub, ce script n'a pas de carte à attendre (et ne devrait pas tourner : le hub publie hub.project.json) :
-- le moteur garde le chargement automatique, pour qu'une erreur plus bas ne laisse jamais le joueur sans personnage.
if Hub.role() == "hub" then
	warn(
		"[Spawn] ATTENTION : le script de PARTIE tourne dans le lieu HUB. Le fichier publié sur ce lieu est-il game.rbxl au lieu de hub.rbxl ?"
	)
else
	pcall(function()
		Players.CharacterAutoLoads = false
	end)
end

-- Point d'apparition actif : celui du hub (lieu unique ou hub), sinon le cercueil du grenier
local function activeSpawn()
	local hubFolder = workspace:FindFirstChild("Hub")
	local hubSpawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if hubSpawn and hubSpawn.Enabled then
		return hubSpawn
	end
	local root = workspace:FindFirstChild("TombeMap")
	local coffin = root and root:FindFirstChild("CercueilSpawn")
	if coffin and coffin.Enabled then
		return coffin
	end
	return nil
end

-- Filet de sécurité lancé tout de suite, avant les chargements qui attendent : même si la suite du script échoue,
-- un joueur sans personnage 5 s après son arrivée en reçoit un (au point d'apparition actif, ou malgré tout
-- après Config.Spawn.ReadyTimeout), et tout personnage qui tombe sous le sol est replacé.
SpawnSafety.start(activeSpawn, {
	onForced = function(player)
		Respawn.forget(player)
	end,
})

SpawnLog.say(
	"démarrage du serveur : PlaceId=%d, rôle=%s, StreamingEnabled=%s, CharacterAutoLoads=%s, %d joueur(s) déjà là",
	game.PlaceId,
	Hub.role(),
	tostring(workspace.StreamingEnabled),
	tostring(Players.CharacterAutoLoads),
	#Players:GetPlayers()
)

-- Taille du serveur : solo ou duo (voir Config.Game)
pcall(function()
	Players.MaxPlayers = Config.Game.MaxPlayers
end)

local round = { seed = 0, ended = false, active = false, mode = "solo", leaving = false }
local restartRequested = false

-- Graine de la partie : celle du jour pour la première partie de la journée de tous les joueurs,
-- sinon une graine tirée hors des dernières jouées (Replay). Config.Debug.Seed l'emporte.
local function chooseSeed()
	if Config.Debug.Seed then
		return Config.Debug.Seed
	end
	local players = Players:GetPlayers()
	if not Config.Replay.Enabled or #players == 0 then
		return math.random(1, 2147483646)
	end
	local today = Replay.day(os.time())
	local firstToday = Config.Replay.DailySeed
	local history = {}
	for _, p in ipairs(players) do
		local profile = Profile.get(p)
		if profile.lastDay == today then
			firstToday = false
		end
		for _, s in ipairs(profile.seeds) do
			table.insert(history, s)
		end
	end
	local seed
	if firstToday then
		seed = Replay.dailySeed(today)
	else
		seed = Replay.fresh(history, Config.Replay.AvoidLastSeeds * #players, function()
			return math.random(1, 2147483646)
		end)
	end
	for _, p in ipairs(players) do
		local profile = Profile.get(p)
		profile.lastDay = today
		Replay.push(profile.seeds, seed, 20)
	end
	return seed
end

-- Tutoriel discret : trois indices contextuels pour qui n'a pas fini le tutoriel, jamais bloquants
local function startTutorial(gen)
	local startedAt = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Profile.get(player)
		if Config.Tutorial.Enabled and not profile.tutorialDone then
			local state = Tutorial.newState()
			local quietUsed, hidden = false, false
			task.spawn(function()
				while round.gen == gen and not round.ended and player.Parent do
					task.wait(2)
					local st = PlayerState.get(player)
					if st then
						quietUsed = quietUsed or st.quiet or st.crouch
						hidden = hidden or st.hiding ~= nil
						local now = os.clock()
						local hint = Tutorial.next(Config.Tutorial, state, {
							elapsed = now - startedAt,
							now = now,
							quietUsed = quietUsed,
							hidden = hidden,
							chased = workspace:GetAttribute("MonsterChasing") == true,
							battery = st.battery / Config.Flashlight.Battery * 100,
						})
						if hint then
							Remotes.fire("Message", player, { text = hint.text })
						end
						if Tutorial.done(state) then
							profile.tutorialDone = true
							Profile.save(player)
							return
						end
					end
				end
			end)
		end
	end
end

local function startRound()
	round.seed = chooseSeed()
	round.ended = false
	round.gen = (round.gen or 0) + 1
	round.startedAt = os.clock()
	Balance.apply(Config, round.mode)
	Tension.start(round.mode, function()
		return math.min(1, Objectives.snapshot().photos / Config.Round.PhotosRequired)
	end)
	print(("[Round] début, seed=%d, mode=%s"):format(round.seed, round.mode))

	-- Les invites ne s'allument que pendant la partie
	Prompts.setRound(true)
	-- État des joueurs remis à zéro, puis emplacements, lampes et pièces sombres tirés à chaque partie
	PlayerState.newRound()
	Respawn.resetRound()
	MapBuilder.placeRound(round.seed)
	Gestures.startLampSway()
	Objectives.setup()
	Quests.setup(round.seed)
	Props.setup()
	Markers.apply()

	-- Réveil dans le cercueil : noir, puis le joueur se redresse
	local intro = Config.Intro.Duration
	PlayerState.freezeAll(intro)
	Remotes.fireAll("Effect", { kind = "Intro", duration = intro })
	-- Intro courte : arrivée devant la maison (le réveil reste un noir et un battement de paupières)
	Remotes.fireAll("Effect", { kind = "Cine", name = "arrival" })
	Lights.start(round.seed)
	FallingObjects.start(round.seed)
	Ambience.start(round.seed)
	Ambience.knocks()

	local delay = Config.Debug.SkipActivationDelay and 0 or Config.Modes[round.mode].activationDelay
	MonsterAI.start(delay)
	startTutorial(round.gen)
end

-- Fin de partie : défis réussis, points et rang de chaque joueur (sauvegardés), texte propre à chacun
local function awardPlayers(reason)
	local out = {}
	if not Config.Ranks.Enabled then
		return out
	end
	local result = {
		ending = reason,
		mode = round.mode,
		duration = os.clock() - (round.startedAt or os.clock()),
		deaths = Respawn.deaths(),
	}
	for _, player in ipairs(Players:GetPlayers()) do
		local ok, text = pcall(function()
			local profile = Profile.get(player)
			result.challenges = Config.Replay.Enabled and Challenges.evaluate(result, profile.challenges) or {}
			local gain = Ranks.award(Config.Ranks, profile, result, Challenges.titles())
			Profile.save(player)
			local line = (" +%d points · %s"):format(gain.gained, Ranks.label(profile))
			if gain.rankUp then
				line = line .. (" · nouveau rang : %s"):format(gain.rankUp)
			end
			for _, id in ipairs(result.challenges) do
				line = line .. (" · défi réussi : %s"):format(Challenges.get(id).title)
			end
			return line
		end)
		if ok then
			out[player] = text
		else
			warn("[Round] progression non attribuée : " .. tostring(text))
		end
	end
	return out
end

local function endRound(reason)
	if round.ended then
		return
	end
	round.ended = true
	Prompts.setRound(false)
	print(("[Round] fin : %s"):format(reason))

	MonsterAI.stop()
	Lights.stop()
	FallingObjects.stop()
	Ambience.stop()
	Tension.stop()
	local progress = awardPlayers(reason)
	local endText = Quests.endingText(reason)
	Remotes.fireAll("Effect", { kind = "Cine", name = reason })
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.fire(
			"Effect",
			player,
			{ kind = "RoundEnd", reason = reason, text = endText .. (progress[player] or "") }
		)
	end

	task.wait(Config.Round.EndScreenTime)

	-- Menu : on attend « Rejouer » (ou le délai de repli avant une nouvelle partie)
	restartRequested = false
	local waited = 0
	while not restartRequested and waited < Config.Round.RestartTimeout do
		task.wait(0.5)
		waited += 0.5
	end

	-- Retour au hub. Dans le lieu de jeu, les joueurs quittent ce serveur : rien ne redémarre ici.
	round.active = false
	Hub.enter()
	if Hub.role() == "game" then
		round.leaving = true
	end
end

-- Réseau
Remotes.init()

-- Les événements du client sont non fiables : type, plage, longueur et fréquence sont vérifiés ici (Guard)
local limiters = {}
local function guarded(name, rate, burst, check, handler)
	local limiter = Guard.newLimiter(rate, burst, os.clock)
	limiters[name] = limiter
	Remotes.get(name).OnServerEvent:Connect(function(player, ...)
		if typeof(player) ~= "Instance" or not limiter.allow(player.UserId) then
			return
		end
		if check and not check(...) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Remote] %s : %s"):format(name, tostring(err)))
		end
	end)
end
Players.PlayerRemoving:Connect(function(player)
	for _, limiter in pairs(limiters) do
		limiter.forget(player.UserId)
	end
end)

guarded("SetQuiet", 10, 20, Guard.isBoolean, function(player, on)
	PlayerState.setQuiet(player, on)
end)

guarded("SetCrouch", 10, 20, Guard.isBoolean, function(player, on)
	PlayerState.setCrouch(player, on)
end)

guarded("SetSprint", 10, 20, Guard.isBoolean, function(player, on)
	PlayerState.setSprint(player, on)
end)

guarded("ToggleFlashlight", 6, 10, nil, function(player)
	local st = PlayerState.get(player)
	if st then
		PlayerState.setFlashlight(player, not st.flashlightOn)
	end
end)

guarded("Restart", 1, 3, nil, function()
	if round.ended then
		restartRequested = true
	end
end)

-- Quitter après une fin : le joueur sort de la partie avec un message
guarded("Quit", 1, 3, nil, function(player)
	if round.ended then
		player:Kick("Merci d'avoir joué à La Tombe du Grenier.")
	end
end)

-- Saisie du code au coffret : texte court sans caractère de contrôle (le code et la date font quelques chiffres)
guarded("SubmitCode", 3, 6, function(text)
	return Guard.cleanText(text, 16) ~= nil
end, function(player, text)
	Quests.submitCode(player, text)
end)

-- Lancer de bruit : direction unitaire finie, une fois par Config.Throw.Cooldown de toute façon
guarded("Throw", 4, 6, Guard.isUnitVector, function(player, direction)
	local impact = PlayerState.tryThrow(player, direction)
	if impact then
		Noise.emit(impact, 1)
		Audio.play("chaise_grince", workspace, { lifetime = 4 })
		Remotes.fire("Message", player, { text = "Tu lances un objet. Le bruit porte au loin." })
	end
end)

-- Démarrage par étapes isolées : une erreur dans une étape est tracée (« [Boot] nom ERREUR ») et le jeu continue,
-- il ne meurt jamais au milieu du script. Chaque étape réussie laisse « [Boot] nom ok ».
local function boot(name, fn, ...)
	local started = os.clock()
	local ok, err = pcall(fn, ...)
	if ok then
		print(("[Boot] %s ok (%.1f s)"):format(name, os.clock() - started))
	else
		warn(("[Boot] %s ERREUR : %s"):format(name, tostring(err)))
	end
	return ok
end

-- Systèmes
-- La carte doit exister avant les systèmes qui lisent les tags (CollectionService).
-- Le lieu hub n'a pas de maison : il ne construit que l'accueil.
if Hub.role() ~= "hub" then
	boot("carte", function()
		MapBuilder.build()
		MapBuilder.startShadowLoop()
	end)
end
if Hub.role() ~= "game" then
	boot("hub", Hub.build)
end
boot("PlayerState", PlayerState.init)
-- Profils : chargés à l'arrivée, rang et titre affichés au-dessus de chaque joueur
Players.PlayerAdded:Connect(function(player)
	-- Arrivée tardive dans un serveur de jeu qui se vide (partie finie) : retour direct au hub
	if Hub.role() == "game" and round.leaving then
		task.defer(Hub.sendPlayersToHub, { player })
	end
	task.spawn(function()
		Profile.load(player)
		pcall(Profile.attachLabel, player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		Profile.load(player)
		pcall(Profile.attachLabel, player)
	end)
end
boot("Hiding", Hiding.init)
boot("Quests", Quests.init, endRound)

-- Réapparition : au point d'avancée atteint, ou réanimation par l'autre joueur en duo
boot("Respawn", Respawn.init, {
	isRoundActive = function()
		return round.active and not round.ended
	end,
	checkpoint = Quests.checkpoint,
	onCurse = function()
		endRound("lose")
	end,
})

-- La carte est construite : les personnages peuvent se charger. Filet de sécurité pour la suite.
task.spawn(function()
	local waited = 0
	while not activeSpawn() and waited < Config.Spawn.ReadyTimeout do
		task.wait(0.2)
		waited = waited + 0.2
	end
	if not activeSpawn() then
		warn("[Spawn] aucun point d'apparition actif : chargement des personnages malgré tout")
	end
	SpawnLog.say("carte construite après %.1f s d'attente du point d'apparition", waited)
	Respawn.setReady(activeSpawn())
end)

-- Modèles : chargés EN ARRIÈRE-PLAN, après la carte et le point d'apparition ; le jeu n'en attend aucun.
-- Plafond global Config.Assets.GlobalTimeout ; les pièces de remplacement restent partout où un modèle manque.
if Hub.role() ~= "hub" then
	task.spawn(function()
		boot("modèle du monstre (arrière-plan)", MonsterAI.ensureModel)
	end)
	-- Sons synthétiques : préchargés après la carte ; le tic-tac suit l'horloge quand son asset est chargé
	boot("sons (arrière-plan)", Audio.preloadNew, function()
		boot("tic-tac de l'horloge", function()
			if not Audio.isReady("horloge_tic") then
				return
			end
			for _, part in ipairs(CollectionService:GetTagged("Horloge")) do
				if part:IsA("BasePart") and not part:FindFirstChild("Canal_horloge_tic") then
					local tic = Audio.channel("horloge_tic", part)
					if tic then
						tic.RollOffMaxDistance = 22
						tic.RollOffMinDistance = 4
						tic:Play()
					end
				end
			end
		end)
	end)
	boot("textures (arrière-plan)", ModelLoader.loadTextures, function(urls)
		boot("pose des textures", MapBuilder.applyLateTextures, urls)
	end)
	boot("modèles (arrière-plan)", ModelLoader.start, function()
		boot("habillage des modèles", MapBuilder.applyLateModels)
	end)
end

-- Demande d'achat (panneau Boutique) : un article du catalogue, validé par Shop.request ; au plus un clic par seconde
guarded("Buy", 1, 3, Guard.isString, function(player, key)
	Shop.request(player, key)
end)

-- Indication demandée par le joueur (touche H), limitée par Config.Quests.HintCooldown
guarded("AskHint", 2, 4, nil, function(player)
	Quests.hintFor(player)
end)

-- Première apparition : la malle ouverte fait tout basculer
-- Ouverture de la cave : le monstre poursuit celui qui a ouvert la porte
-- Porte d'entrée franchie : le monstre est mis en scène derrière la porte, quelques secondes
Quests.onFrontDoorShown = function()
	MonsterAI.staged(Vector3.new(60, 0.5, 86), 6)
end

boot("Shop", Shop.init)

Quests.onStatuesChanged = function(done)
	Objectives.setStatuesDone(done)
end

Quests.onCaveOpened = function(player)
	Audio.play("cri_monstre2", workspace, { lifetime = 4 })
	MonsterAI.forceChase(player)
end

Quests.onChestOpened = function(player)
	Audio.play("cri_monstre", workspace, { lifetime = 4 })
	Remotes.fire("Effect", player, { kind = "Cine", name = "apparition" })
	Lights.blackout()
	task.delay(2.5, function()
		MonsterAI.forceChase(player)
	end)
end
boot("Objectives", Objectives.init, function(player)
	Quests.onFrontDoor(player)
end)

-- Portail franchi (fuite) : le monstre disparaît. Il réapparaît quand les joueurs atteignent la cave,
-- et descend l'escalier extérieur vers eux.
local monsterReturning = false
-- Enfant libéré : il suit les joueurs ; la fuite par le portail mène à la voiture et à la fin
Quests.onFreed = function(player)
	Finale.freed()
	Remotes.fireAll("Message", { text = "L'enfant est libre. Il vous suit. Rejoignez le portail, la voiture attend." })
end

Quests.onEscape = function()
	Finale.escape(function()
		endRound("truth")
	end)
end

Quests.onGate = function()
	MonsterAI.vanish()
	monsterReturning = true
	task.spawn(function()
		while monsterReturning and round.active and not round.ended do
			task.wait(1)
			for _, p in ipairs(Players:GetPlayers()) do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < -4 then
					monsterReturning = false
					-- Le monstre descend l'escalier extérieur, puis avance dans le sous-sol vers le joueur
					local points = { Vector3.new(103, 0, 110) }
					for k = 0, 11 do
						table.insert(points, Vector3.new(103, -(k + 1) + 0.5, 104 - k - 0.5))
					end
					table.insert(points, Vector3.new(103, -12, 84))
					Remotes.fireAll("Effect", { kind = "Cine", name = "descente" })
					MonsterAI.walkPoints(points, 9, function()
						MonsterAI.resume(p)
					end)
					return
				end
			end
		end
	end)
end

-- Boucle de partie : attend le choix du mode au hub, puis lance la partie
task.spawn(function()
	while true do
		if not round.active and not round.leaving then
			local group = Hub.waitForStart()
			-- Le mode suit le nombre de joueurs : deux joueurs = duo, un seul = solo
			round.mode = (#group >= 2) and "duo" or "solo"
			local launched = Hub.startGame(group)
			if Hub.role() == "hub" then
				-- Le lieu hub ne joue pas : les joueurs partent vers le serveur privé.
				-- Si ça échoue, on attend avant de réessayer.
				round.active = false
				if not launched then
					task.wait(5)
				end
			elseif launched then
				round.active = true
				startRound()
			end
		end
		task.wait(0.5)
	end
end)

-- Mesure de performance serveur : temps moyen d'une frame (ms), publié une fois par seconde pour le compteur F7 des clients.
-- Aucun coût en dehors d'un addition par frame.
do
	local sum, frames = 0, 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		sum += dt
		frames += 1
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if frames > 0 then
				workspace:SetAttribute("ServerFrameMs", math.floor(sum / frames * 10000) / 10)
			end
			sum, frames = 0, 0
		end
	end)
end

if Hub.role() ~= "game" then
	Hub.enter()
end
