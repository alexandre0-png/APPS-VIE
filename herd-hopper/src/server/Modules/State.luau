-- État partagé côté serveur (une seule source de vérité pour la manche en cours).

local State = {
	Phase = "Intermission", -- Intermission | Countdown | Running | Results
	RoundId = 0,
	Frozen = true, -- bêtes immobiles (compte à rebours)
	RunElapsed = 0,
	StartZone = 1,
	HeartBonus = 0,
	BossesSpawned = {}, -- [index de zone] = true
	FinishCount = 0,
	Participants = {}, -- [Player] = run
	Creatures = {}, -- [id] = creature
	NextCreatureId = 1,
	CreaturesFolder = nil,
	FxFolder = nil,
	LobbyCFrame = CFrame.new(0, 330, -720),
	PlotCFrames = {}, -- [Player] = point d'arrivée devant le zoo du joueur
	Ready = {}, -- [Player] = true : le joueur part à la prochaine expédition
	FinishCFrame = CFrame.new(0, 6, 3300),
	MapReady = false,
}

function State.SetPhase(phase, duration)
	State.Phase = phase
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEnd", workspace:GetServerTimeNow() + (duration or 0))
	workspace:SetAttribute("Round", State.RoundId)
end

function State.CountActive()
	local n = 0
	for _, run in pairs(State.Participants) do
		local s = run.status
		if s == "Riding" or s == "Air" or s == "Hooking" or s == "Down" or s == "Dead" then
			n = n + 1
		end
	end
	return n
end

return State
