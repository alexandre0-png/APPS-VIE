--!strict
-- Quêtes quotidiennes : définitions et logique de progression (pure).
local QuestLogic = {}

export type QuestDef = {
	Id: string,
	Title: string,
	Desc: string,
	Event: string, -- Kill | Headshot | Streak | Win | MatchPlayed | Damage
	Class: string?, -- filtre pour Kill : "Melee" | "Ranged"
	Target: number,
	Coins: number,
	XP: number,
	Max: boolean?, -- progression = maximum atteint (série)
}

export type QuestEntry = { Id: string, Progress: number, Claimed: boolean }
export type QuestState = { Day: number, List: { QuestEntry } }

QuestLogic.Pool = {
	{ Id = "kills10", Title = "Chasseur", Desc = "Éliminer 10 joueurs", Event = "Kill", Target = 10, Coins = 100, XP = 80 },
	{ Id = "kills25", Title = "Boucher", Desc = "Éliminer 25 joueurs", Event = "Kill", Target = 25, Coins = 220, XP = 150 },
	{ Id = "melee5", Title = "Fer contre fer", Desc = "5 éliminations au corps à corps", Event = "Kill", Class = "Melee", Target = 5, Coins = 120, XP = 90 },
	{ Id = "ranged5", Title = "Tireur d'élite", Desc = "5 éliminations à distance", Event = "Kill", Class = "Ranged", Target = 5, Coins = 120, XP = 90 },
	{ Id = "head3", Title = "Dans le mille", Desc = "3 tirs à la tête", Event = "Headshot", Target = 3, Coins = 150, XP = 100 },
	{ Id = "streak4", Title = "Implacable", Desc = "Série de 4 éliminations sans mourir", Event = "Streak", Target = 4, Coins = 160, XP = 110, Max = true },
	{ Id = "win1", Title = "Victoire !", Desc = "Gagner une partie", Event = "Win", Target = 1, Coins = 200, XP = 150 },
	{ Id = "play3", Title = "Gladiateur assidu", Desc = "Terminer 3 parties", Event = "MatchPlayed", Target = 3, Coins = 150, XP = 100 },
	{ Id = "dmg1000", Title = "Dévastateur", Desc = "Infliger 1000 dégâts", Event = "Damage", Target = 1000, Coins = 140, XP = 100 },
} :: { QuestDef }

local byId: { [string]: QuestDef } = {}
for _, q in ipairs(QuestLogic.Pool) do
	byId[q.Id] = q
end

function QuestLogic.Get(id: string): QuestDef?
	return byId[id]
end

-- Numéro du jour (UTC) à partir d'un timestamp os.time().
function QuestLogic.DayKey(timestamp: number): number
	return math.floor(timestamp / 86400)
end

-- Sélection déterministe de `count` quêtes distinctes pour un jour donné.
function QuestLogic.Pick(day: number, count: number): { string }
	local ids = {}
	for _, q in ipairs(QuestLogic.Pool) do
		table.insert(ids, q.Id)
	end
	local seed = (day * 1103515245 + 12345) % 2147483647
	local picked = {}
	for _ = 1, math.min(count, #ids) do
		seed = (seed * 48271) % 2147483647
		local index = (seed % #ids) + 1
		table.insert(picked, table.remove(ids, index) :: string)
	end
	return picked
end

function QuestLogic.NewState(day: number): QuestState
	local list: { QuestEntry } = {}
	for _, id in ipairs(QuestLogic.Pick(day, 3)) do
		table.insert(list, { Id = id, Progress = 0, Claimed = false })
	end
	return { Day = day, List = list }
end

-- Applique un évènement. Renvoie vrai si une progression a changé.
function QuestLogic.Apply(state: QuestState, event: string, amount: number, class: string?): boolean
	local changed = false
	for _, entry in ipairs(state.List) do
		local def = byId[entry.Id]
		if def and def.Event == event and not entry.Claimed and entry.Progress < def.Target then
			if def.Class == nil or def.Class == class then
				local before = entry.Progress
				if def.Max then
					entry.Progress = math.min(def.Target, math.max(entry.Progress, amount))
				else
					entry.Progress = math.min(def.Target, entry.Progress + amount)
				end
				if entry.Progress ~= before then
					changed = true
				end
			end
		end
	end
	return changed
end

return QuestLogic
