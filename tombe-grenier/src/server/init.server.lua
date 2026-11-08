--[[
  Serveur principal : boucle de partie, branchement des systèmes, événements réseau.
  Autorité serveur : toute décision (dégâts, objectifs, IA, sanité) se prend ici.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local PlayerState = require(script.PlayerState)
local MonsterAI = require(script.MonsterAI)
local Lights = require(script.Lights)
local FallingObjects = require(script.FallingObjects)
local Ambience = require(script.Ambience)
local MapBuilder = require(script.MapBuilder)
local Quests = require(script.Quests)
local Noise = require(script.Noise)
local Audio = require(Shared.Audio)
local Objectives = require(script.Objectives)
local Hiding = require(script.Hiding)
local Props = require(script.Props)
local Hub = require(script.Hub)
local Respawn = require(script.Respawn)

-- Taille du serveur : solo ou duo (voir Config.Game)
pcall(function()
	Players.MaxPlayers = Config.Game.MaxPlayers
end)

local round = { seed = 0, ended = false, active = false, mode = "solo", leaving = false }
local restartRequested = false

local function startRound()
	round.seed = Config.Debug.Seed or math.random(1, 2147483646)
	round.ended = false
	print(("[Round] début, seed=%d"):format(round.seed))

	-- État des joueurs remis à zéro, puis emplacements, lampes et pièces sombres tirés à chaque partie
	PlayerState.newRound()
	Respawn.resetRound()
	MapBuilder.placeRound(round.seed)
	Objectives.setup()
	Quests.setup(round.seed)
	Props.setup()

	-- Réveil dans le cercueil : noir, puis le joueur se redresse
	local intro = Config.Intro.Duration
	PlayerState.freezeAll(intro)
	Remotes.fireAll("Effect", { kind = "Intro", duration = intro })
	Remotes.fireAll("Effect", { kind = "Cine", name = "intro" })
	Lights.start(round.seed)
	FallingObjects.start(round.seed)
	Ambience.start(round.seed)
	Ambience.knocks()

	local delay = Config.Debug.SkipActivationDelay and 0 or Config.Modes[round.mode].activationDelay
	MonsterAI.start(delay)
end

local function endRound(reason)
	if round.ended then
		return
	end
	round.ended = true
	print(("[Round] fin : %s"):format(reason))

	MonsterAI.stop()
	Lights.stop()
	FallingObjects.stop()
	Ambience.stop()
	Remotes.fireAll("Effect", { kind = "Cine", name = reason })
	Remotes.fireAll("Effect", { kind = "RoundEnd", reason = reason, text = Quests.endingText(reason) })

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

Remotes.get("SetQuiet").OnServerEvent:Connect(function(player, on)
	if typeof(on) == "boolean" then
		PlayerState.setQuiet(player, on)
	end
end)

Remotes.get("SetSprint").OnServerEvent:Connect(function(player, on)
	if typeof(on) == "boolean" then
		PlayerState.setSprint(player, on)
	end
end)

Remotes.get("ToggleFlashlight").OnServerEvent:Connect(function(player)
	local st = PlayerState.get(player)
	if st then
		PlayerState.setFlashlight(player, not st.flashlightOn)
	end
end)

Remotes.get("Restart").OnServerEvent:Connect(function()
	if round.ended then
		restartRequested = true
	end
end)

-- Saisie du code au coffret, et lancer de bruit
Remotes.get("SubmitCode").OnServerEvent:Connect(function(player, text)
	Quests.submitCode(player, text)
end)

Remotes.get("Throw").OnServerEvent:Connect(function(player, direction)
	local impact = PlayerState.tryThrow(player, direction)
	if impact then
		Noise.emit(impact, 1)
		Audio.play("chaise_grince", workspace, { lifetime = 4 })
		Remotes.fire("Message", player, { text = "Tu lances un objet. Le bruit porte au loin." })
	end
end)

-- Systèmes
-- La carte doit exister avant les systèmes qui lisent les tags (CollectionService)
-- Le lieu hub n'a pas de maison : il ne construit que l'accueil
if Hub.role() ~= "hub" then
	MapBuilder.build()
	MapBuilder.startShadowLoop()
end
if Hub.role() ~= "game" then
	Hub.build()
end
PlayerState.init()
Hiding.init()
Quests.init(endRound)

-- Réapparition : au point d'avancée atteint, ou réanimation par l'autre joueur en duo
Respawn.init({
	isRoundActive = function()
		return round.active and not round.ended
	end,
	checkpoint = Quests.checkpoint,
	onCurse = function()
		endRound("lose")
	end,
})

-- Indication demandée par le joueur (touche H), limitée par Config.Quests.HintCooldown
Remotes.get("AskHint").OnServerEvent:Connect(function(player)
	Quests.hintFor(player)
end)

-- Première apparition : la malle ouverte fait tout basculer
-- Ouverture de la cave : le monstre poursuit celui qui a ouvert la porte
Quests.onCaveOpened = function(player)
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
Objectives.init(function(player)
	Quests.onFrontDoor(player)
end)

-- Portail franchi : la poursuite commence, et ce qui est rattrapé retourne au cercueil
Quests.onGate = function(player)
	for _, p in ipairs(Players:GetPlayers()) do
		MonsterAI.forceChase(p)
	end
	task.delay(Config.Exit.CatchDelay, function()
		for _, p in ipairs(Players:GetPlayers()) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = 0
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

if Hub.role() ~= "game" then
	Hub.enter()
end

