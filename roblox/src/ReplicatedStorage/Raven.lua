-- ModuleScript : ReplicatedStorage/Shared/Raven
-- Règles PURES du vol à distance « Corbeau chipeur » (aucun service Roblox), testées une par une. Le serveur fournit des « contextes » (tables simples) et applique
-- la décision ; le client n'envoie qu'une intention. Jamais d'anonymat, jamais de protection payante : les protections sont gratuites.
local Raven = {}

-- Vérifie le DÉPART d'un corbeau. thief = { userId, tokens, level, playMinutes, freeSlot, dailyDone, flying, newbie, inCastle }
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
	if (egg.endsAt or 0) - now <= R.minEggSecondsLeft then
		return false, "tooLate"
	end
	return true
end

-- Indemnité de la victime : floor(prix de la boutique x ratio).
function Raven.compensation(Config, tier)
	return math.floor(Config.EGG_PRICE[tier] * Config.REMOTE_STEAL.compensationRatio)
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

return Raven
