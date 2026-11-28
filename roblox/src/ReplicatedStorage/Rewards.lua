-- ModuleScript : ReplicatedStorage/Shared/Rewards
-- LOT 15 (G) : récompenses PURES (aucun service Roblox) : série de 7 jours (G.1), grâce et sauvetage (G.2), enveloppe du calendrier de 30 jours (Calendar.lua, lot 9b),
-- quêtes bonus et hebdomadaires (G.4), sac d'œufs (10 places, jamais de perte), rotation hebdomadaire de 9 semaines, événements (week-end chanceux, heure dorée, événements limités),
-- plumes d'événement avec plafonds par jour. Le SERVEUR fournit le jour UTC (os.time() // 86400) ; le client ne reçoit que des vues.
-- Config attendu : TIERS, TIER_GATE, EGG_PRICE, PETS, VIP_DAILY_MUL (existants) + STREAK, EGG_BAG, QUESTS, PLUMES, TIMED_EVENTS, EVENTS_CAL, WEEKLY_ROTATION*, FORBIDDEN_GIFT_TIERS (bloc « LOT 15 » de Config.lua).
-- Toute rareté est un NOM résolu par Config.TIERS : jamais d'indice codé en dur. Secret / Exclusif / Divin ne sont jamais donnés par la série ni par les quêtes.
-- États de profil : voir roblox/LOT15_INTEGRATION_NOTES.md (grace, weekly, event, eggBag ; daily / streak existants).
-- Style : pas de `+=`, pas de `continue`, valeurs douteuses gardées par type avant toute comparaison.
local Rewards = {}

local function isnum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function int(v, lo, hi, def)
	if not isnum(v) then
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
Rewards.int = int

---------------------------------------------------------------- Raretés par nom
function Rewards.tierIdx(Config, name)
	for i, t in ipairs(Config.TIERS) do
		if t.name == name then
			return i
		end
	end
	return nil
end

function Rewards.forbiddenTier(Config, t)
	local name = Config.TIERS[t] and Config.TIERS[t].name
	for _, n in ipairs(Config.FORBIDDEN_GIFT_TIERS or {}) do
		if n == name then
			return true
		end
	end
	return false
end

-- Rareté PUBLIÉE la plus proche vers le bas (Config.tierLive du lot 9 si présent) : un œuf n'est jamais d'une rareté sans espèce.
function Rewards.liveTier(Config, t)
	if type(Config.tierLive) ~= "function" then
		return t
	end
	while t > 1 and not Config.tierLive(t) do
		t = t - 1
	end
	return t
end

-- Rareté d'un œuf donné par la série / les quêtes : résolue par nom, jamais interdite (nil sinon), ramenée à une rareté publiée.
local function giftTier(Config, name)
	local t = Rewards.tierIdx(Config, name)
	if not t or Rewards.forbiddenTier(Config, t) then
		return nil
	end
	return Rewards.liveTier(Config, t)
end
Rewards.giftTier = giftTier

---------------------------------------------------------------- Temps UTC (jour = os.time() // 86400)
function Rewards.dow(day)
	return (math.floor(day) + 4) % 7 -- 0 = dimanche
end

function Rewards.weekOf(day)
	return math.floor((math.floor(day) + 3) / 7) -- semaines commençant le lundi
end

-- Date civile (année, mois, jour) d'un numéro de jour UTC (algorithme de H. Hinnant).
function Rewards.civil(day)
	local z = math.floor(day) + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = mp < 10 and mp + 3 or mp - 9
	if m <= 2 then
		y = y + 1
	end
	return y, m, d
end

-- Numéro de jour UTC d'une date civile (inverse de `civil`).
function Rewards.daysFromCivil(y, m, d)
	if m <= 2 then
		y = y - 1
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = m > 2 and m - 3 or m + 9
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

---------------------------------------------------------------- Sac d'œufs et placement (jamais de perte)
local function slotFree(slots, i)
	return slots[i] == nil or slots[i] == false
end

function Rewards.freeSlots(slots, cap)
	local n = 0
	for i = 1, cap do
		if slotFree(slots, i) then
			n = n + 1
		end
	end
	return n
end

-- Assainit un sac lu du profil : liste de rarétés entières valides, au plus `size` entrées.
function Rewards.sanitizeBag(Config, saved)
	local out = {}
	local size = Config.EGG_BAG.size
	if type(saved) == "table" then
		for _, t in ipairs(saved) do
			if #out < size and isnum(t) then
				local v = math.floor(t)
				if v >= 1 and v <= #Config.TIERS then
					out[#out + 1] = v
				end
			end
		end
	end
	return out
end

-- Peut-on ranger `n` œufs ? (base d'abord, puis le sac.)
function Rewards.canStore(Config, slots, cap, bag, n)
	return Rewards.freeSlots(slots, cap) + (Config.EGG_BAG.size - #bag) >= n
end

-- Range des œufs de façon ATOMIQUE : tout ou rien. `mkEgg(tier)` crée l'emplacement d'œuf (le serveur y met `ends`, `shield`) ; défaut { k = "e", t = tier }.
-- Retourne (true, { "slot" | "bag", ... }) ou (false, "bagFull") sans rien modifier.
function Rewards.storeEggs(Config, slots, cap, bag, tiers, mkEgg)
	if not Rewards.canStore(Config, slots, cap, bag, #tiers) then
		return false, "bagFull"
	end
	local where = {}
	local nextSlot = 1
	for _, t in ipairs(tiers) do
		while nextSlot <= cap and not slotFree(slots, nextSlot) do
			nextSlot = nextSlot + 1
		end
		if nextSlot <= cap then
			slots[nextSlot] = mkEgg and mkEgg(t) or { k = "e", t = t }
			where[#where + 1] = "slot"
		else
			bag[#bag + 1] = t
			where[#where + 1] = "bag"
		end
	end
	return true, where
end

-- Pose un œuf du sac dans la base (le plus ancien d'abord). Retourne (true, rareté, emplacement) ou (false, "empty" | "baseFull").
function Rewards.bagTake(slots, cap, bag, mkEgg)
	if #bag == 0 then
		return false, "empty"
	end
	for i = 1, cap do
		if slotFree(slots, i) then
			local t = table.remove(bag, 1)
			slots[i] = mkEgg and mkEgg(t) or { k = "e", t = t }
			return true, t, i
		end
	end
	return false, "baseFull"
end

---------------------------------------------------------------- Récompense (« grant ») : forme commune
local function newGrant()
	return { coins = 0, eggs = {}, fragments = 0, seasonXp = 0, plumes = 0 }
end

local function eggsFromNames(Config, names, grant)
	for _, name in ipairs(names or {}) do
		local t = giftTier(Config, name)
		if t then
			grant.eggs[#grant.eggs + 1] = t
		end
	end
end

-- Un grant ne contient jamais une rareté interdite (sauf `allow`, utilisé seulement pour l'Exclusif contre plumes et le calendrier). Retourne la liste des violations.
function Rewards.grantViolations(Config, grant, allow)
	local bad = {}
	for _, t in ipairs(grant.eggs or {}) do
		if type(t) ~= "number" or Config.TIERS[t] == nil then
			bad[#bad + 1] = "rareté inconnue"
		elseif Rewards.forbiddenTier(Config, t) and not allow then
			bad[#bad + 1] = "rareté interdite : " .. Config.TIERS[t].name
		end
	end
	return bad
end

---------------------------------------------------------------- G.1 Série de 7 jours
-- États de profil : d.daily (dernier jour UTC réclamé), d.streak (jours de suite), d.grace = { week, used, weeks, rweek } :
--   week / used = semaine du dernier jour de grâce consommé ; weeks = semaines de 7 jours terminées (Mythique à la 4e) ; rweek = semaine du dernier sauvetage payant.
function Rewards.sanitizeGrace(saved)
	local g = { week = 0, used = 0, weeks = 0, rweek = 0 }
	if type(saved) == "table" then
		g.week = int(saved.week, 0, 1e6, 0)
		g.used = int(saved.used, 0, 1, 0)
		g.weeks = int(saved.weeks, 0, 1e5, 0)
		g.rweek = int(saved.rweek, 0, 1e6, 0)
	end
	return g
end

local function graceAvailable(g, today)
	return not (g.week == Rewards.weekOf(today) and g.used >= 1)
end

-- Récompense d'un jour de la série (1 à 7). `weeks` = semaines terminées avant celle-ci ; `income` = pièces / s ; `vip` : pièces x VIP_DAILY_MUL (jamais les œufs).
function Rewards.streakReward(Config, day, weeks, income, vip)
	local S = Config.STREAK
	local def = S.days[day]
	local grant = newGrant()
	if not def then
		return grant
	end
	local month = (day == #S.days) and def.eggsMonth and ((weeks + 1) % S.mythicEveryWeeks == 0)
	eggsFromNames(Config, month and def.eggsMonth or def.eggs, grant)
	if def.c then
		local inc = (isnum(income) and income > 0) and income or 0
		local coins = math.floor(math.max(S.coinFloor, inc * 60 * def.c))
		if vip == true then
			coins = coins * (Config.VIP_DAILY_MUL or 1)
		end
		grant.coins = coins
	end
	grant.luck = def.luck and { minutes = def.luck.minutes, points = def.luck.points } or nil
	grant.boost = def.boost and { key = def.boost.key, mul = def.boost.mul, minutes = def.boost.minutes } or nil
	grant.fragments = def.fragments or 0
	grant.mythicWeek = month == true
	return grant
end

-- État de la série pour `today`. g = { daily, streak, grace }. ctx = { questsDone }.
-- state : done (déjà réclamée), ready (la suite normale ou le premier jour), grace (un jour manqué pardonné automatiquement), rescue (sauvetage : quêtes gratuites ou produit),
-- reset (3 jours manqués ou plus : retour au jour 1). day = jour de la série qui serait réclamé.
function Rewards.streakPlan(Config, g, today, ctx)
	local S = Config.STREAK
	local daily = isnum(g.daily) and g.daily or 0
	local streak = int(g.streak, 0, 1e6, 0)
	local plan = { state = "ready", day = 1, missed = 0, streak = streak }
	if daily == today or daily > today then
		plan.state = "done"
		plan.day = (streak % #S.days) + 1
		return plan
	end
	if daily <= 0 then
		return plan
	end
	local missed = today - daily - 1
	plan.missed = missed
	if missed <= 0 then
		plan.day = (streak % #S.days) + 1
	elseif missed == 1 and graceAvailable(g.grace, today) then
		plan.state = "grace"
		plan.day = (streak % #S.days) + 1
	elseif missed < S.resetAfterMissed then
		plan.state = "rescue"
		plan.day = (streak % #S.days) + 1
		local done = (type(ctx) == "table" and isnum(ctx.questsDone)) and ctx.questsDone or 0
		plan.canQuest = done >= S.restoreQuests
		plan.canProduct = true -- lot 16 (décision utilisateur : plus de plafond d'achat) : le sauvetage payant n'est plus limité à 1 par semaine ; rweek reste noté (mesure)
		plan.lost = streak
	else
		plan.state = "reset"
	end
	return plan
end

-- Réclame la série du jour (le serveur appelle ceci, jamais le client). how : nil (suite normale, ou jour de grâce automatique), "quest" (3 quêtes faites aujourd'hui),
-- "product" (produit StreakRestore DÉJÀ vérifié par reçu), "reset" (le joueur accepte de repartir du jour 1 au lieu de sauver sa série).
-- ctx : { income, vip, questsDone, slots, cap, bag, mkEgg }. Atomique : si l'octroi des œufs est impossible (base ET sac pleins) rien n'est modifié ("bagFull").
-- Retourne (true, { day, grant, state, where }) ou (false, code : done, rescue, noQuest, noProduct, bagFull).
function Rewards.streakClaim(Config, g, today, how, ctx)
	local S = Config.STREAK
	local plan = Rewards.streakPlan(Config, g, today, ctx)
	if plan.state == "done" then
		return false, "done"
	end
	local continues = true
	local useGrace, useProduct = false, false
	if plan.state == "grace" then
		useGrace = true
	elseif plan.state == "rescue" then
		if how == "quest" then
			if not plan.canQuest then
				return false, "noQuest"
			end
		elseif how == "product" then
			if not plan.canProduct then
				return false, "noProduct"
			end
			useProduct = true
		elseif how == "reset" then
			continues = false
		else
			return false, "rescue"
		end
	elseif plan.state == "reset" then
		continues = false
	end
	local day = continues and plan.day or 1
	local streakNow = continues and (int(g.streak, 0, 1e6, 0) + 1) or 1
	local weeks = continues and g.grace.weeks or 0
	local grant = Rewards.streakReward(Config, day, weeks, ctx and ctx.income, ctx and ctx.vip)
	local where
	if ctx and ctx.slots then
		local ok, w = Rewards.storeEggs(Config, ctx.slots, ctx.cap, ctx.bag, grant.eggs, ctx.mkEgg)
		if not ok then
			return false, w
		end
		where = w
	end
	g.daily = today
	g.streak = streakNow
	if useGrace then
		g.grace.week = Rewards.weekOf(today)
		g.grace.used = 1
	end
	if useProduct then
		g.grace.rweek = Rewards.weekOf(today)
	end
	if not continues then
		g.grace.weeks = 0
	end
	if day == #S.days then
		g.grace.weeks = g.grace.weeks + 1
	end
	return true, { day = day, grant = grant, state = plan.state, where = where }
end

---------------------------------------------------------------- Calendrier de 30 jours (Calendar.lua, lot 9b) : enveloppe avec sac d'œufs
-- Réutilise Calendar.check / plan / apply (module passé en paramètre) et ajoute le rangement atomique des œufs (base, puis sac). Les raretés du calendrier viennent de
-- Config.CALENDAR (le tirage du jour 30 peut donner un Secret : règle propre au calendrier, hors des interdits de la série et des quêtes).
-- Retourne (true, { plan, streak, where }) ou (false, code) ; codes de Calendar.check, plus bagFull.
function Rewards.calendarClaim(Config, Calendar, cal, today, day, how, eligible, rnd, income, store)
	local ok, why = Calendar.check(Config, cal, today, day, how, eligible)
	if not ok then
		return false, why
	end
	local plan = Calendar.plan(Config, day, rnd, income)
	local where
	if plan and plan.egg and store then
		local ok2, w = Rewards.storeEggs(Config, store.slots, store.cap, store.bag, { plan.egg }, store.mkEgg)
		if not ok2 then
			return false, w
		end
		where = w
	end
	local streak = Calendar.apply(Config, cal, today, day, how)
	return true, { plan = plan, streak = streak, where = where }
end

---------------------------------------------------------------- G.4 Quêtes bonus du jour
-- weekly.bq = { d = jour UTC, prog, claimed } ; l'option du jour est choisie par le numéro du jour (même résultat à chaque appel).
function Rewards.bonusQuest(Config, day, chapter)
	local B = Config.QUESTS.bonus
	local opt = B.options[(math.floor(day) % #B.options) + 1]
	local late = isnum(chapter) and chapter >= B.lateChapter
	local q = { kind = opt.kind, goal = opt.goal, text = opt.text, egg = giftTier(Config, late and B.eggLate or B.egg) }
	if opt.minTier then
		q.minTier = Rewards.tierIdx(Config, opt.minTier)
	end
	return q
end

local function newBonus(day)
	return { d = day, prog = 0, claimed = false }
end

-- Progression de la quête bonus : ev = { kind = "pve" } ou { kind = "hatch", tier }. Compte seulement si les 3 quêtes du jour sont faites (`unlocked`). Retourne (progrès, terminée).
function Rewards.bonusEvent(Config, wk, day, chapter, unlocked, ev)
	if type(wk.bq) ~= "table" or wk.bq.d ~= day then
		wk.bq = newBonus(day)
	end
	local q = Rewards.bonusQuest(Config, day, chapter)
	if unlocked == true and type(ev) == "table" and ev.kind == q.kind and not wk.bq.claimed then
		local ok = true
		if q.kind == "hatch" then
			ok = isnum(ev.tier) and q.minTier ~= nil and ev.tier >= q.minTier
		end
		if ok then
			wk.bq.prog = math.min(q.goal, wk.bq.prog + 1)
		end
	end
	return wk.bq.prog, wk.bq.prog >= q.goal
end

-- Réclame l'Œuf de la quête bonus (une seule fois par jour). store = { slots, cap, bag, mkEgg } facultatif. Retourne (true, grant) ou (false, code : notDone, claimed, bagFull).
function Rewards.bonusClaim(Config, wk, day, chapter, store)
	if type(wk.bq) ~= "table" or wk.bq.d ~= day then
		wk.bq = newBonus(day)
	end
	local q = Rewards.bonusQuest(Config, day, chapter)
	if wk.bq.claimed then
		return false, "claimed"
	end
	if wk.bq.prog < q.goal then
		return false, "notDone"
	end
	local grant = newGrant()
	grant.eggs[1] = q.egg
	if store then
		local ok, w = Rewards.storeEggs(Config, store.slots, store.cap, store.bag, grant.eggs, store.mkEgg)
		if not ok then
			return false, w
		end
		grant.where = w
	end
	wk.bq.claimed = true
	return true, grant
end

---------------------------------------------------------------- G.4 Quêtes de la semaine
-- weekly = { w = semaine UTC, prog = { 7 entiers }, c5, c7 (récompenses réclamées), bq }.
function Rewards.sanitizeWeekly(Config, saved)
	local themes = Config.QUESTS.weekly.themes
	local wk = { w = 0, prog = {}, c5 = false, c7 = false, bq = newBonus(0) }
	for i = 1, #themes do
		wk.prog[i] = 0
	end
	if type(saved) == "table" then
		wk.w = int(saved.w, 0, 1e6, 0)
		for i = 1, #themes do
			wk.prog[i] = int(type(saved.prog) == "table" and saved.prog[i] or 0, 0, themes[i].goal, 0)
		end
		wk.c5 = saved.c5 == true
		wk.c7 = saved.c7 == true
		if type(saved.bq) == "table" then
			wk.bq = { d = int(saved.bq.d, 0, 1e6, 0), prog = int(saved.bq.prog, 0, 99, 0), claimed = saved.bq.claimed == true }
		end
	end
	return wk
end

-- Nouvelle semaine : progression et réclamations remises à zéro.
function Rewards.weeklySync(Config, wk, week)
	if wk.w ~= week then
		local fresh = Rewards.sanitizeWeekly(Config, nil)
		wk.w = week
		wk.prog = fresh.prog
		wk.c5 = false
		wk.c7 = false
	end
end

-- Progression d'un thème (jamais au-delà de l'objectif). Retourne la progression, ou nil si le thème n'existe pas.
function Rewards.weeklyAdd(Config, wk, key, n)
	for i, th in ipairs(Config.QUESTS.weekly.themes) do
		if th.key == key then
			local add = isnum(n) and math.max(0, math.floor(n)) or 0
			wk.prog[i] = math.min(th.goal, wk.prog[i] + add)
			return wk.prog[i]
		end
	end
	return nil
end

function Rewards.weeklyDone(Config, wk)
	local n = 0
	for i, th in ipairs(Config.QUESTS.weekly.themes) do
		if wk.prog[i] >= th.goal then
			n = n + 1
		end
	end
	return n
end

-- Réclame le palier 5/7 (which = 5) ou 7/7 (which = 7) : une fois chacun par semaine. Retourne (true, grant) ou (false, code : notDone, claimed, bagFull, which).
function Rewards.weeklyClaim(Config, wk, which, store)
	local tier
	for _, r in ipairs(Config.QUESTS.weekly.rewards) do
		if r.need == which then
			tier = r
		end
	end
	if not tier then
		return false, "which"
	end
	local flag = which == 5 and "c5" or "c7"
	if wk[flag] then
		return false, "claimed"
	end
	if Rewards.weeklyDone(Config, wk) < tier.need then
		return false, "notDone"
	end
	local grant = newGrant()
	local t = giftTier(Config, tier.egg)
	if t then
		grant.eggs[1] = t
	end
	grant.seasonXp = tier.seasonXp or 0
	if store then
		local ok, w = Rewards.storeEggs(Config, store.slots, store.cap, store.bag, grant.eggs, store.mkEgg)
		if not ok then
			return false, w
		end
		grant.where = w
	end
	wk[flag] = true
	return true, grant
end

---------------------------------------------------------------- Rotation hebdomadaire (cycle de 9 semaines, identique pour tous les joueurs)
function Rewards.rotation(Config, week)
	local list = Config.WEEKLY_ROTATION
	local w = isnum(week) and math.floor(week) or 0
	local epoch = Config.WEEKLY_ROTATION_EPOCH or 0
	return list[((w - epoch) % #list) + 1], ((w - epoch) % #list) + 1
end

-- Poids d'un œuf après l'espèce vedette : x2 pour l'espèce de la semaine (nom de Config.PETS), inchangé sinon.
function Rewards.featuredWeight(Config, rot, petIdx, weight)
	local sp = Config.PETS[petIdx]
	if sp and rot and sp.name == rot.featured then
		return weight * (Config.WEEKLY_ROTATION_MULT or 2)
	end
	return weight
end

-- Espèce vedette appliquée APRÈS un tirage uniforme parmi les n espèces de la rareté obtenue (Rules.rollPet) : bascule vers l'espèce vedette avec la
-- probabilité (M - 1) / (n + M - 1) (M = WEEKLY_ROTATION_MULT ; M = 2 : 1 / (n + 1)). Résultat : P(vedette) = M / (n + M - 1), chaque autre espèce
-- 1 / (n + M - 1), exactement un poids x M. La rareté ne change jamais (la vedette n'est choisie que dans la rareté déjà tirée). Retourne l'indice d'espèce.
function Rewards.featuredPick(Config, rot, petIdx, rnd)
	local sp = Config.PETS[petIdx]
	if not (sp and rot and type(rot.featured) == "string") or sp.name == rot.featured then
		return petIdx
	end
	local featured, n = nil, 0
	for i, p in ipairs(Config.PETS) do
		if p.tier == sp.tier then
			n = n + 1
			if p.name == rot.featured then
				featured = i
			end
		end
	end
	local M = Config.WEEKLY_ROTATION_MULT or 2
	if featured and type(rnd) == "function" and rnd() < (M - 1) / (n + M - 1) then
		return featured
	end
	return petIdx
end

-- A11 : quêtes du jour des lots 12 à 14 (Config.QUESTS.newTypes : pve, typeWin, duel, odds, npcTrade). Les données d'événement viennent du SERVEUR seul.
-- Objectif tiré parmi newTypes[t].goals ; r dans [0, 1). nil si t n'est pas un nouveau type.
function Rewards.newQuestGoal(Config, t, r)
	local nt = Config.QUESTS and Config.QUESTS.newTypes and Config.QUESTS.newTypes[t]
	if type(nt) ~= "table" or type(nt.goals) ~= "table" or #nt.goals == 0 then
		return nil
	end
	local x = isnum(r) and math.min(math.max(r, 0), 0.999999) or 0
	return nt.goals[math.floor(x * #nt.goals) + 1]
end
-- L'équipe (unités de Battle, champ type ; « Nature » = « Plante » de la rotation) contient-elle le type `ty` ?
function Rewards.teamHasType(units, ty)
	if type(units) ~= "table" or type(ty) ~= "string" then
		return false
	end
	for _, u in ipairs(units) do
		local t = type(u) == "table" and u.type or nil
		if t == "Nature" then
			t = "Plante"
		end
		if t == ty then
			return true
		end
	end
	return false
end
-- Progression des quêtes du jour pour un événement serveur : liste { { t, n } } (vide si rien ne compte). Une seule entrée par type et par événement.
--   pveWin   : info = { rewarded, units, weekType } -> pve +1 et typeWin +1 (équipe avec le type de la semaine), seulement si la victoire est RÉCOMPENSÉE
--              (tour : premier passage ou rejouée dans la limite du jour ; PNJ : offre à usage unique) : un rejeu non récompensé ne compte pas ;
--   duelPaid : info = { coins } -> duel +1 seulement si le duel a été payé (Duel.settle : 10 par jour, 3 par paire et par jour, pas d'abandon précoce) ;
--   hatch    : info = { odds } -> odds +1 si le compteur de RÉFÉRENCE (Odds.forPet, aucun bonus) >= Config.ODDS.billboardMin (1 000) ;
--   npcTrade : échange de PNJ conclu (offre retirée du carnet avant l'effet : aucun rejeu) -> npcTrade +1.
function Rewards.questKinds(Config, kind, info)
	local out = {}
	info = type(info) == "table" and info or {}
	if kind == "pveWin" then
		if info.rewarded == true then
			out[#out + 1] = { "pve", 1 }
			if Rewards.teamHasType(info.units, info.weekType) then
				out[#out + 1] = { "typeWin", 1 }
			end
		end
	elseif kind == "duelPaid" then
		if isnum(info.coins) and info.coins > 0 then
			out[#out + 1] = { "duel", 1 }
		end
	elseif kind == "hatch" then
		local min = (Config.ODDS and Config.ODDS.billboardMin) or 1000
		if isnum(info.odds) and info.odds >= min then
			out[#out + 1] = { "odds", 1 }
		end
	elseif kind == "npcTrade" then
		out[#out + 1] = { "npcTrade", 1 }
	end
	return out
end

-- Multiplicateur de dégâts du type « en forme » : PvE seulement.
function Rewards.typeDamage(Config, rot, ty, pve)
	if pve == true and rot and rot.type == ty then
		return Config.WEEKLY_ROTATION_DAMAGE or 1.2
	end
	return 1
end

---------------------------------------------------------------- G.5 Événements
-- Week-end chanceux : samedi 00:00 -> lundi 00:00 UTC. Heure dorée : tous les jours de fromHour à toHour UTC. `now` = secondes UNIX.
function Rewards.isWeekend(Config, now)
	if not isnum(now) then
		return false
	end
	local d = Rewards.dow(math.floor(now / 86400))
	for _, x in ipairs(Config.TIMED_EVENTS.weekend.days) do
		if x == d then
			return true
		end
	end
	return false
end

function Rewards.isGoldenHour(Config, now)
	if not isnum(now) then
		return false
	end
	local h = math.floor((now % 86400) / 3600)
	local G = Config.TIMED_EVENTS.goldenHour
	return h >= G.fromHour and h < G.toHour
end

-- Événement limité actif ce jour-là (Config.EVENTS_CAL, dates « MM-JJ » de l'année en cours) : (entrée, clé « id.année ») ou nil.
function Rewards.limitedEvent(Config, today)
	if not isnum(today) then
		return nil
	end
	local y = Rewards.civil(today)
	for _, e in ipairs(Config.EVENTS_CAL) do
		local fm, fd = string.match(e.from, "^(%d+)%-(%d+)$")
		local tm, td = string.match(e.to, "^(%d+)%-(%d+)$")
		if fm and tm then
			local a = Rewards.daysFromCivil(y, tonumber(fm), tonumber(fd))
			local b = Rewards.daysFromCivil(y, tonumber(tm), tonumber(td))
			if today >= a and today <= b then
				return e, e.id .. "." .. y
			end
		end
	end
	return nil
end

-- A5 : fenêtres ouvertes des espèces d'événement / de saison à l'instant `now` (secondes UNIX) : { [étiquette] = true }. Étiquettes : l'id de l'événement
-- limité en cours (Config.EVENTS_CAL) et l'étiquette `event` de son espèce (halloween -> « halloween », xmas -> espèce 73 « noel ») ; « saison<N> »
-- pendant la saison N en cours (seasonN >= 1, Season.currentSeason). Ensemble vide hors de toute fenêtre. Config.speciesOpen l'interprète.
function Rewards.openSpeciesEvents(Config, now, seasonN)
	local open = {}
	if isnum(now) then
		local limited = Rewards.limitedEvent(Config, math.floor(now / 86400))
		if limited then
			open[limited.id] = true
			local sp = type(limited.species) == "number" and Config.PETS[limited.species] or nil
			if type(sp) == "table" and type(sp.event) == "string" then
				open[sp.event] = true
			end
		end
	end
	if isnum(seasonN) and seasonN >= 1 and seasonN % 1 == 0 then
		open["saison" .. seasonN] = true
	end
	return open
end

-- Ensemble des effets actifs à l'instant `now` (secondes UNIX).
function Rewards.activeEvents(Config, now)
	local today = isnum(now) and math.floor(now / 86400) or 0
	local limited, key = Rewards.limitedEvent(Config, today)
	local W = Config.TIMED_EVENTS.weekend
	local weekend = Rewards.isWeekend(Config, now)
	return {
		weekend = weekend, upgradeBonus = weekend and W.upgradePoints or 0, beltSeconds = weekend and W.beltSeconds or W.beltDefault,
		golden = Rewards.isGoldenHour(Config, now), goldKey = Config.TIMED_EVENTS.goldenHour.key, limited = limited, limitedKey = key,
	}
end

---------------------------------------------------------------- Plumes d'événement
-- event = { k = clé de l'événement en cours (« id.année »), d = jour UTC des compteurs, q / v = plumes de quêtes / de victoires PvE aujourd'hui, l = connexion déjà créditée (0/1),
--           p = solde, x = Œufs Exclusifs obtenus pendant cet événement }.
function Rewards.sanitizeEvent(Config, saved)
	local P = Config.PLUMES
	local e = { k = "", d = 0, q = 0, v = 0, l = 0, p = 0, x = 0 }
	if type(saved) == "table" then
		if type(saved.k) == "string" and #saved.k <= 24 then
			e.k = saved.k
		end
		e.d = int(saved.d, 0, 1e6, 0)
		e.q = int(saved.q, 0, P.questCapDay, 0)
		e.v = int(saved.v, 0, P.pveCapDay, 0)
		e.l = int(saved.l, 0, 1, 0)
		e.p = int(saved.p, 0, P.balanceCap, 0)
		e.x = int(saved.x, 0, 99, 0)
	end
	return e
end

-- Synchronise avec le jour et l'événement actifs (`key` nil = aucun événement). Nouveau jour : compteurs du jour à zéro. Nouvel événement : solde et achats remis à zéro
-- (les plumes d'un événement terminé ne se reportent pas : décision documentée ; à changer en ajoutant un report ici).
function Rewards.plumeSync(Config, ev, today, key)
	if ev.d ~= today then
		ev.d = today
		ev.q = 0
		ev.v = 0
		ev.l = 0
	end
	if key and ev.k ~= key then
		ev.k = key
		ev.p = 0
		ev.x = 0
	end
end

-- Crédite des plumes avec les plafonds du jour. source : "quest" (10 par quête du jour, 40 au plus), "pve" (2 par victoire, 20 au plus), "login" (5, une fois). Retourne la quantité créditée.
-- Sans événement actif (`ev.k == ""` ou `active == false`) : rien.
function Rewards.plumeAdd(Config, ev, source, active)
	local P = Config.PLUMES
	if active ~= true or ev.k == "" then
		return 0
	end
	local add = 0
	if source == "quest" then
		add = math.min(P.perQuest, P.questCapDay - ev.q)
		add = math.max(0, add)
		ev.q = ev.q + add
	elseif source == "pve" then
		add = math.max(0, math.min(P.perPveWin, P.pveCapDay - ev.v))
		ev.v = ev.v + add
	elseif source == "login" then
		if ev.l == 0 then
			ev.l = 1
			add = P.login
		end
	end
	local room = math.max(0, P.balanceCap - ev.p)
	add = math.min(add, room)
	ev.p = ev.p + add
	return add
end

-- Œuf Exclusif contre 150 plumes (jamais plus de `maxExclusivePerEvent` par événement ; refusé tant que la rareté n'a aucune espèce publiée). store = { slots, cap, bag, mkEgg }.
-- Retourne (true, rareté, emplacement) ou (false, code : inactive, plumes, limit, notLive, closed, bagFull).
-- open (A5) : fenêtres ouvertes (Rewards.openSpeciesEvents) ; refus « closed » si aucune espèce Exclusif n'est tirable maintenant (ex. événement sans espèce Exclusif).
function Rewards.plumeBuyExclusive(Config, ev, active, store, open)
	local P = Config.PLUMES
	if active ~= true or ev.k == "" then
		return false, "inactive"
	end
	if ev.x >= P.maxExclusivePerEvent then
		return false, "limit"
	end
	if ev.p < P.exclusiveCost then
		return false, "plumes"
	end
	local t = Rewards.tierIdx(Config, P.exclusiveName)
	if not t or Rewards.liveTier(Config, t) ~= t then
		return false, "notLive"
	end
	if type(Config.tierOpen) == "function" and not Config.tierOpen(t, open) then
		return false, "closed"
	end
	local where
	if store then
		local ok, w = Rewards.storeEggs(Config, store.slots, store.cap, store.bag, { t }, store.mkEgg)
		if not ok then
			return false, w
		end
		where = w[1]
	end
	ev.p = ev.p - P.exclusiveCost
	ev.x = ev.x + 1
	return true, t, where
end

return Rewards
