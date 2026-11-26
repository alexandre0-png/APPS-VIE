-- ModuleScript : ReplicatedStorage/Shared/Calendar
-- LOT 9b : règles PURES du calendrier des œufs sur 30 jours (aucun service Roblox, testées une par une). Le serveur fournit le jour UTC et décide ; le client ne reçoit
-- que `Calendar.view` (affichage). Style : pas de `+=`, pas de `continue`, valeurs d'origine incertaine gardées par type avant toute comparaison numérique.
-- État d'un profil (`cal`) : start = jour UTC du jour 1 du cycle (0 = pas démarré), cycle = numéro du cycle, days = 30 caractères « 0 » / « 1 » (jour réclamé),
-- grace = jours de grâce utilisés ce cycle, catch = jetons de rattrapage payants, qc = missions réclamées comptées pour un rattrapage,
-- dayD / dayN = jour UTC et nombre de réclamations déjà faites ce jour-là (plafond Config.CALENDAR.dayCap).
local Calendar = {}

local function int(v, lo, hi, def)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return def
	end
	v = math.floor(v)
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end
Calendar.int = int

local function zeros(Config)
	return string.rep("0", Config.CALENDAR.days)
end

function Calendar.newState(Config)
	return { start = 0, cycle = 0, days = zeros(Config), grace = 0, catch = 0, qc = 0, dayD = 0, dayN = 0 }
end

-- Assainit un `cal` lu du profil (champ facultatif : absent, corrompu ou d'une autre forme = état neuf). Ne garde que des entiers bornés.
function Calendar.sanitize(Config, saved)
	local C = Config.CALENDAR
	local cal = Calendar.newState(Config)
	if type(saved) ~= "table" then
		return cal
	end
	cal.start = int(saved.start, 0, 1e6, 0)
	cal.cycle = int(saved.cycle, 0, 1e4, 0)
	if cal.start > 0 and cal.cycle < 1 then
		cal.cycle = 1
	end
	if type(saved.days) == "string" and #saved.days == C.days and not string.find(saved.days, "[^01]") then
		cal.days = saved.days
	end
	cal.grace = int(saved.grace, 0, C.days, 0)
	cal.catch = int(saved.catch, 0, C.catchupMax, 0)
	cal.qc = int(saved.qc, 0, C.catchupQuests * 2, 0)
	cal.dayD = int(saved.dayD, 0, 1e6, 0)
	cal.dayN = int(saved.dayN, 0, C.dayCap, 0)
	return cal
end

function Calendar.claimedCount(cal)
	local _, n = string.gsub(cal.days, "1", "")
	return n
end

-- Jour du cycle (1 à 30 pendant le cycle ; 0 = pas démarré ; > 30 = cycle terminé, à renouveler). today = jour UTC (os.time() // 86400).
function Calendar.dayIndex(cal, today)
	if type(today) ~= "number" or today ~= today or cal.start <= 0 then
		return 0
	end
	return math.floor(today) - cal.start + 1
end

-- Cycle terminé (30 jours écoulés) : nouveau cycle commençant aujourd'hui, jours remis à zéro (les jours non réclamés sont perdus ; jetons et missions comptées restent).
-- Retourne vrai si le cycle a été renouvelé.
function Calendar.normalize(Config, cal, today)
	if type(today) ~= "number" or today ~= today or cal.start <= 0 then
		return false
	end
	if math.floor(today) - cal.start >= Config.CALENDAR.days then
		cal.cycle = cal.cycle + 1
		cal.start = math.floor(today)
		cal.days = zeros(Config)
		cal.grace = 0
		cal.dayD = 0
		cal.dayN = 0
		return true
	end
	return false
end

-- Démarre le cycle 1 aujourd'hui s'il ne l'est pas (appelé seulement pour un joueur éligible). Retourne vrai si démarré maintenant.
function Calendar.begin(Config, cal, today)
	if cal.start > 0 or type(today) ~= "number" or today ~= today then
		return false
	end
	cal.start = math.floor(today)
	cal.cycle = math.max(1, cal.cycle + 1)
	cal.days = zeros(Config)
	cal.grace = 0
	cal.dayD = 0
	cal.dayN = 0
	return true
end

-- Éligibilité : ancienneté du compte (jours) et temps de jeu cumulé (secondes). Valeurs incertaines : tout ce qui n'est pas un nombre fini vaut 0 (refusé).
function Calendar.eligible(Config, ageDays, playedSeconds)
	local C = Config.CALENDAR
	local a = (type(ageDays) == "number" and ageDays == ageDays) and ageDays or 0
	local p = (type(playedSeconds) == "number" and playedSeconds == playedSeconds) and playedSeconds or 0
	if a < C.minAccountAgeDays then
		return false, "age"
	end
	if p < C.minPlayMinutes * 60 then
		return false, "played"
	end
	return true
end

-- Jours de grâce gagnés au jour `idx` (1 dès le jour 1, +1 tous les `graceEvery` jours) moins ceux déjà utilisés.
function Calendar.graceEarned(Config, idx)
	if type(idx) ~= "number" or idx ~= idx or idx < 1 then
		return 0
	end
	return math.floor((math.min(idx, Config.CALENDAR.days) - 1) / Config.CALENDAR.graceEvery) + 1
end

function Calendar.graceAvail(Config, cal, idx)
	return math.max(0, Calendar.graceEarned(Config, idx) - cal.grace)
end

-- Réclamations déjà faites aujourd'hui (UTC).
function Calendar.todayCount(cal, today)
	return cal.dayD == today and cal.dayN or 0
end

-- Une réclamation est-elle permise ? `day` = carte demandée, `how` = "today" (le jour en cours) ou, pour un jour manqué, "grace" / "quest" / "paid".
-- Retourne true ou (false, code) : ineligible, day, notStarted, future, claimed, monthCap, dayCap, how, noResource.
function Calendar.check(Config, cal, today, day, how, eligible)
	local C = Config.CALENDAR
	if eligible ~= true then
		return false, "ineligible"
	end
	if type(day) ~= "number" or day ~= day or day % 1 ~= 0 or day < 1 or day > C.days then
		return false, "day"
	end
	local idx = Calendar.dayIndex(cal, today)
	if idx < 1 then
		return false, "notStarted"
	end
	if day > idx then
		return false, "future"
	end
	if string.sub(cal.days, day, day) == "1" then
		return false, "claimed"
	end
	if Calendar.claimedCount(cal) >= C.monthCap then
		return false, "monthCap"
	end
	if Calendar.todayCount(cal, today) >= C.dayCap then
		return false, "dayCap"
	end
	if day == idx then
		return true
	end
	local have
	if how == "grace" then
		have = Calendar.graceAvail(Config, cal, idx) > 0
	elseif how == "quest" then
		have = cal.qc >= C.catchupQuests
	elseif how == "paid" then
		have = cal.catch >= 1
	else
		return false, "how"
	end
	if not have then
		return false, "noResource"
	end
	return true
end

-- Série : jours consécutifs réclamés qui se terminent au dernier jour réclamé du cycle.
function Calendar.streak(days)
	local last = 0
	for i = #days, 1, -1 do
		if string.sub(days, i, i) == "1" then
			last = i
			break
		end
	end
	local n = 0
	for i = last, 1, -1 do
		if string.sub(days, i, i) == "1" then
			n = n + 1
		else
			break
		end
	end
	return n
end

-- Applique une réclamation DÉJÀ validée par `check` : jour marqué, ressource consommée, compteur du jour. Retourne la série.
function Calendar.apply(Config, cal, today, day, how)
	local idx = Calendar.dayIndex(cal, today)
	cal.days = string.sub(cal.days, 1, day - 1) .. "1" .. string.sub(cal.days, day + 1)
	if cal.dayD ~= today then
		cal.dayD = today
		cal.dayN = 0
	end
	cal.dayN = cal.dayN + 1
	if day < idx then
		if how == "grace" then
			cal.grace = cal.grace + 1
		elseif how == "quest" then
			cal.qc = math.max(0, cal.qc - Config.CALENDAR.catchupQuests)
		elseif how == "paid" then
			cal.catch = math.max(0, cal.catch - 1)
		end
	end
	return Calendar.streak(cal.days)
end

-- Une mission réclamée compte pour le rattrapage « 3 missions » (plafonné à 2 rattrapages d'avance).
function Calendar.addQuest(Config, cal)
	cal.qc = math.min(Config.CALENDAR.catchupQuests * 2, cal.qc + 1)
end

-- Un jeton de rattrapage payant de plus ; faux si le plafond est atteint (l'achat n'est alors pas traité : rien n'est perdu).
function Calendar.addCatch(Config, cal)
	if cal.catch >= Config.CALENDAR.catchupMax then
		return false
	end
	cal.catch = cal.catch + 1
	return true
end

-- Tirage du jour 30 : r dans [0, 1) -> rareté de l'œuf (table Config.CALENDAR.draw, pourcentages affichés).
function Calendar.draw(Config, r)
	local d = Config.CALENDAR.draw
	local v = (type(r) == "number" and r == r) and r or 0
	local acc = 0
	for _, e in ipairs(d) do
		acc = acc + e.pct / 100
		if v < acc then
			return e.tier
		end
	end
	return d[#d].tier
end

-- Un jour dont la récompense est aléatoire (donc soumis à PolicyService quand il est obtenu par un rattrapage PAYANT).
function Calendar.isRandom(Config, day)
	local r = Config.CALENDAR.rewards[day]
	return r ~= nil and r.draw == true
end

-- Récompense concrète d'un jour : { coins, egg, scrolls, plumes, tokens, cosm, title, drew }. `rnd` = tirage [0,1) (serveur), `income` = pièces / s du joueur.
function Calendar.plan(Config, day, rnd, income)
	local C = Config.CALENDAR
	local r = C.rewards[day]
	if not r then
		return nil
	end
	local inc = (type(income) == "number" and income == income and income > 0) and income or 0
	local coins = 0
	if r.c then
		coins = math.floor(math.max(C.coinFloor, inc * 60 * r.c))
	end
	local egg = r.egg
	local drew = false
	if r.draw then
		egg = Calendar.draw(Config, rnd)
		drew = true
	end
	return { coins = coins, egg = egg, scrolls = r.scrolls or 0, plumes = r.plumes or 0, tokens = r.tokens or 0, cosm = r.cosm, title = r.title, drew = drew }
end

-- Texte court de la récompense affichée sur une carte.
function Calendar.rewardText(Config, day)
	local C = Config.CALENDAR
	local r = C.rewards[day]
	if not r then
		return ""
	end
	local parts = {}
	if r.draw then
		local t = {}
		for _, e in ipairs(C.draw) do
			t[#t + 1] = e.pct .. " % " .. Config.TIERS[e.tier].name
		end
		parts[#parts + 1] = "🎲 Œuf : " .. table.concat(t, " / ")
	elseif r.egg then
		parts[#parts + 1] = "🥚 Œuf " .. Config.TIERS[r.egg].name
	end
	if r.c then
		parts[#parts + 1] = "🪙 " .. r.c .. " min de revenu"
	end
	if r.scrolls then
		parts[#parts + 1] = "📜 " .. r.scrolls
	end
	if r.plumes then
		parts[#parts + 1] = "🪶 " .. r.plumes
	end
	if r.tokens then
		parts[#parts + 1] = "⚔️ " .. r.tokens
	end
	if r.cosm and C.cosmetics[r.cosm] then
		parts[#parts + 1] = C.cosmetics[r.cosm].emoji .. " " .. C.cosmetics[r.cosm].name
	end
	if r.title and C.titles[r.title] then
		parts[#parts + 1] = "🏷 " .. C.titles[r.title].name
	end
	return table.concat(parts, " · ")
end

-- Compte à rebours du Légendaire (jour 3), visible dès le jour 1. idx = jour du cycle (0 avant le démarrage = jour 1), got = œuf déjà réclamé.
function Calendar.legendaryText(Config, idx, got)
	if got then
		return "🌟 Légendaire du jour " .. Config.CALENDAR.legendaryDay .. " : obtenu !"
	end
	local i = (type(idx) == "number" and idx == idx and idx >= 1) and idx or 1
	local left = Config.CALENDAR.legendaryDay - i
	if left > 1 then
		return "🌟 Œuf Légendaire : plus que " .. left .. " jours !"
	elseif left == 1 then
		return "🌟 Œuf Légendaire : plus que 1 jour !"
	elseif left == 0 then
		return "🌟 Œuf Légendaire : c'est aujourd'hui !"
	end
	return "🌟 Œuf Légendaire manqué : rattrape le jour " .. Config.CALENDAR.legendaryDay .. " !"
end

-- Vue envoyée au client (toute décision reste au serveur). states : 30 caractères, « c » réclamé, « t » à réclamer aujourd'hui, « m » manqué (rattrapable),
-- « f » à venir. Un jour qui n'est plus rattrapable n'existe pas : tout jour manqué du cycle reste rattrapable jusqu'à la fin du cycle.
function Calendar.view(Config, cal, today, eligible, reason)
	local C = Config.CALENDAR
	local idx = Calendar.dayIndex(cal, today)
	local started = idx >= 1 and idx <= C.days
	local out = {}
	for d = 1, C.days do
		local claimed = string.sub(cal.days, d, d) == "1"
		local st = "f"
		if claimed then
			st = "c"
		elseif started and d == idx then
			st = "t"
		elseif started and d < idx then
			st = "m"
		end
		out[#out + 1] = st
	end
	local shownIdx = started and idx or 1
	local left = math.max(0, C.dayCap - Calendar.todayCount(cal, today))
	local canToday = eligible == true and started and string.sub(cal.days, idx, idx) == "0" and left > 0 and Calendar.claimedCount(cal) < C.monthCap
	return {
		states = table.concat(out), idx = shownIdx, started = started, cycle = cal.cycle, claimed = Calendar.claimedCount(cal), streak = Calendar.streak(cal.days),
		grace = started and Calendar.graceAvail(Config, cal, idx) or 0, catch = cal.catch, qc = cal.qc, left = left, eligible = eligible == true, reason = reason,
		canToday = canToday == true, legendary = Calendar.legendaryText(Config, shownIdx, string.sub(cal.days, C.legendaryDay, C.legendaryDay) == "1"),
	}
end

return Calendar
