-- ModuleScript : ReplicatedStorage/Shared/Raven
-- Règles PURES du vol à distance « Corbeau chipeur » (aucun service Roblox), testées une par une. Le serveur fournit des « contextes » (tables simples) et applique
-- la décision ; le client n'envoie qu'une intention. Jamais d'anonymat, jamais de protection payante : les protections sont gratuites.
local Raven = {}

-- Ancienneté de compte (jours) d'après une valeur d'origine incertaine : tout ce qui n'est pas un nombre fini vaut 0 (donc refusé).
local function days(v)
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return v
end

-- Vérifie le DÉPART d'un corbeau. thief = { userId, tokens, level, playMinutes, freeSlot, dailyDone, flying, newbie, inCastle }
-- (lot 7b : thief et victim portent aussi accountAgeDays ; egg porte rvAt = os.time() du dernier vol par corbeau, nil sinon)
-- victim = { userId, level, playMinutes, newbie, inCastle, graceUntil, shieldUntil, ravenCooldownUntil, friendOfThief, blockFriendRavens }
-- egg = { tier, incubating, eggShieldUntil, endsAt }, now en secondes (os.time). Retourne true ou (false, code).
function Raven.canLaunch(Config, thief, victim, egg, now)
	local R = Config.REMOTE_STEAL
	if not thief or not victim or not egg then
		return false, "invalid"
	end
	if thief.userId == victim.userId then
		return false, "self"
	end
	if (thief.tokens or 0) < 1 then
		return false, "noToken"
	end
	if thief.flying then
		return false, "alreadyFlying"
	end
	if (thief.dailyDone or 0) >= R.dailyMax then
		return false, "dailyLimit"
	end
	if thief.inCastle or victim.inCastle then
		return false, "castle"
	end
	if thief.newbie or victim.newbie then
		return false, "newbie"
	end
	if (thief.playMinutes or 0) < R.minPlayMinutes or (victim.playMinutes or 0) < R.victimMinMinutes then
		return false, "tooYoung"
	end
	if days(thief.accountAgeDays) < R.minAccountAgeDays or days(victim.accountAgeDays) < R.minAccountAgeDays then
		return false, "accountAge"
	end
	if not thief.freeSlot then
		return false, "noSlot"
	end
	if (victim.level or 1) < (thief.level or 1) - R.levelGap then
		return false, "levelGap"
	end
	if now < (victim.shieldUntil or 0) then
		return false, "victimShield"
	end
	if now < (victim.ravenCooldownUntil or 0) then
		return false, "victimCooldown"
	end
	if now < (victim.graceUntil or 0) then
		return false, "grace"
	end
	if victim.friendOfThief and victim.blockFriendRavens then
		return false, "friendBlocked"
	end
	if not egg.incubating then
		return false, "notEgg"
	end
	if type(egg.tier) ~= "number" or egg.tier > R.maxTier or egg.tier < 1 then
		return false, "tier"
	end
	if now < (egg.eggShieldUntil or 0) then
		return false, "eggShield"
	end
	if type(egg.rvAt) == "number" and now - egg.rvAt < R.reStealSeconds then
		return false, "recentlyStolen" -- un œuf volé par corbeau ne se revole pas tout de suite (anti-aller-retour entre comptes complices)
	end
	if (egg.endsAt or 0) - now <= R.minEggSecondsLeft then
		return false, "tooLate"
	end
	return true
end

-- Indemnité de la victime : floor(prix de la boutique x ratio).
function Raven.compensation(Config, tier)
	return math.floor(Config.EGG_PRICE[tier] * Config.REMOTE_STEAL.compensationRatio)
end

-- Indemnité RÉELLEMENT versée (lot 7b) : 0 pour un œuf non indemnisable (`rv` : déjà volé par corbeau, issu du tapis privé ou de l'œuf de bienvenue), sinon
-- l'indemnité normale plafonnée par ce que la victime peut encore recevoir aujourd'hui (plafond = prix d'un œuf de Config.REMOTE_STEAL.compensationCapTier).
function Raven.indemnity(Config, tier, rv, receivedToday)
	if rv == true then
		return 0
	end
	local R = Config.REMOTE_STEAL
	local got = (type(receivedToday) == "number" and receivedToday == receivedToday) and math.max(0, receivedToday) or 0 -- valeur incertaine : nombre fini sinon 0
	local room = Config.EGG_PRICE[R.compensationCapTier] - got
	return math.max(0, math.min(Raven.compensation(Config, tier), room))
end

-- Jour UTC d'un horodatage (clé du plafond quotidien).
function Raven.day(now)
	return math.floor(now / 86400)
end

-- Plafond quotidien : retourne le nouveau compteur (remis à zéro si le jour a changé) sous la forme (jour, compte).
function Raven.rollDaily(day, count, now)
	local today = Raven.day(now)
	if day ~= today then
		return today, 0
	end
	return day, count
end

-- Un achat de `n` jetons est-il possible sans dépasser le plafond ? (sinon le reçu n'est PAS traité : jamais de jeton payé perdu.)
function Raven.canBuy(Config, tokens, n)
	return math.max(0, tokens) + n <= Config.REMOTE_STEAL.tokenMax
end

-- Jetons après un achat de `n` jetons (plafond tokenMax) : retourne (nouveau total, jetons perdus au-delà du plafond).
function Raven.addTokens(Config, tokens, n)
	local cap = Config.REMOTE_STEAL.tokenMax
	local total = math.min(cap, math.max(0, tokens) + n)
	return total, math.max(0, math.max(0, tokens) + n - cap)
end

-- Issue du vol : la victime a-t-elle chassé le corbeau (touche son pad à temps, présente dans sa base) ?
function Raven.resolve(chased)
	return chased and "chased" or "success"
end

-- Jetons offerts par un produit (RemoteSteal 1, RemoteStealPack 3) ; 0 si le produit n'en donne pas.
function Raven.tokensFor(Config, productName)
	local n = Config.REMOTE_STEAL.packs[productName]
	return type(n) == "number" and n or 0
end

-- Jetons « détenus » pour le plafond d'achat : ceux du profil PLUS celui qui est en vol (il sera rendu en cas d'échec : le compter évite de le perdre au-delà du plafond).
function Raven.held(tokens, flying)
	return math.max(0, tokens) + (flying and 1 or 0)
end

-- Cumul d'un bonus serveur (tapis doré, pluie de chance) : `left` secondes restantes, `add` secondes achetées, plafond `max`. Retourne (nouveau restant, accepté).
-- Un achat qui dépasserait le plafond n'est PAS accepté (le reçu reste « pas encore traité » : aucun argent perdu).
function Raven.stack(left, add, max)
	left = math.max(0, left)
	if left + add > max then
		return left, false
	end
	return left + add, true
end

-- Une demande de vol en cours est-elle toujours valable ? Tout est décidé par le serveur ; `w` = { thiefHere, victimHere, eggStill, eggLeft, chased, shielded, thiefFreeSlot, now, endsAt }.
-- Retourne (decision, raison) : "pending" (le corbeau vole encore), "chased" (jeton rendu), "success", ou "aborted" (raison : thiefGone, victimGone, eggGone, shield, noSlot ;
-- jeton rendu partout sauf thiefGone, où le serveur le rend dans le profil du voleur avant sa sauvegarde de départ).
function Raven.settle(w)
	if not w.thiefHere then
		return "aborted", "thiefGone"
	end
	if not w.victimHere then
		return "aborted", "victimGone"
	end
	if not w.eggStill or (type(w.eggLeft) == "number" and w.eggLeft <= 0) then
		return "aborted", "eggGone"
	end
	if w.chased then
		return "chased", "chased"
	end
	if w.now < w.endsAt then
		return "pending", "flying"
	end
	if w.shielded then
		return "aborted", "shield" -- un autre corbeau (ou un vol) vient de protéger la victime : un seul vol à la fois la dépouille
	end
	if not w.thiefFreeSlot then
		return "aborted", "noSlot"
	end
	return "success", "success"
end

-- Journal « Qui m'a volé ? » : insère l'entrée en tête, ne garde que `max` entrées. Retourne la liste (modifiée en place).
function Raven.logPush(list, entry, max)
	table.insert(list, 1, entry)
	while #list > max do
		table.remove(list)
	end
	return list
end

-- Clés du journal serveur RavenLog (une clé par jour UTC) : jour courant, et jour à effacer (plus vieux que `days` jours).
function Raven.dayKey(now)
	return "D" .. Raven.day(now)
end
function Raven.expiredKey(now, days)
	return "D" .. (Raven.day(now) - days - 1)
end

-- Position du corbeau (x, y, z) à l'instant t (0 à 1) d'un vol de `from` vers `to` : montée en arc puis cercle au-dessus de la cible sur la fin.
-- Pure (aucun Vector3) : le serveur en tire un CFrame. `orbit` = fraction du vol passée à tourner (0,3).
function Raven.birdPos(from, to, t, orbit)
	t = math.min(math.max(t, 0), 1)
	local o = orbit or 0.3
	local k = 1 - o
	if t < k then
		local u = t / k
		local e = u * u * (3 - 2 * u)
		return from.x + (to.x - from.x) * e, from.y + (to.y - from.y) * e + math.sin(u * math.pi) * 6, from.z + (to.z - from.z) * e
	end
	local a = (t - k) / o * math.pi * 2
	return to.x + math.cos(a) * 5, to.y, to.z + math.sin(a) * 5
end

return Raven
