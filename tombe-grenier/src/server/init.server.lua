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

local round = { seed = 0, ended = false, cycle = 1 }
local restartRequested = false

local function alivePlayers()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			count += 1
		end
	end
	return count
end

local function startRound()
	round.seed = Config.Debug.Seed or math.random(1, 2147483646)
	round.ended = false
	print(("[Round] début, seed=%d"):format(round.seed))

	-- Emplacements, lampes et pièces sombres : tirés à chaque partie
	MapBuilder.placeRound(round.seed)
	Objectives.setup()
	Quests.setup(round.seed, round.cycle)
	Props.setup()

	-- Réveil dans le cercueil : noir, puis le joueur se redresse
	local intro = Config.Intro.Duration
	PlayerState.freezeAll(intro)
	Remotes.fireAll("Effect", { kind = "Intro", duration = intro })
	Remotes.fireAll("Effect", { kind = "Cine", name = "intro" })
	Lights.start(round.seed)
	FallingObjects.start(round.seed)
	Ambience.start(round.seed)

	local delay = Config.Debug.SkipActivationDelay and 0 or Config.Round.ActivationDelay
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

	-- Retour au cercueil pour tous
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
	task.wait(1)
	startRound()
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
MapBuilder.build()
MapBuilder.startShadowLoop()
PlayerState.init()
Hiding.init()
Quests.init(endRound)

-- Première apparition : la malle ouverte fait tout basculer
Quests.onChestOpened = function(player)
	Remotes.fire("Effect", player, { kind = "Cine", name = "apparition" })
	Lights.blackout()
	task.delay(2.5, function()
		MonsterAI.forceChase(player)
	end)
end
Objectives.init(function()
	endRound("win")
end)

startRound()

-- Défaite : tout le monde est mort pendant plusieurs secondes
task.spawn(function()
	local deadTicks = 0
	while true do
		task.wait(1)
		if not round.ended and #Players:GetPlayers() > 0 then
			if alivePlayers() == 0 then
				deadTicks += 1
				if deadTicks >= 5 then
					deadTicks = 0
					round.cycle += 1
					endRound("lose")
				end
			else
				deadTicks = 0
			end
		end
	end
end)
