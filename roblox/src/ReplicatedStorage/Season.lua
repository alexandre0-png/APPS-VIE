-- ModuleScript : ReplicatedStorage/Shared/Season
-- LOT 16 (G.5 + addendum B) : logique PURE de la Passe de combat (aucun service Roblox, aucun os.time : le SERVEUR passe `nowUtc` en secondes).
-- Usage : local S = Season.new(Config, SeasonData). Config fournit TIERS (rareté par NOM) et PETS (espèce Exclusif de la saison).
-- Champs de profil (profil.season) : { n, xp, day, dayXp, claimedFree, claimedPrem, premium, plus, prev }
--   n = numéro de saison ; xp = XP de saison ; day/dayXp = jour UTC et XP déjà gagnée ce jour ; claimedFree/claimedPrem = masques de bits (bit t-1 = palier t réclamé) ;
--   premium = numéro de la saison dont la piste premium est achetée (0 = non) ; plus = numéro de la saison où Premium+/complément a été utilisé (une fois par saison) ;
--   prev = saison précédente gardée pendant la période de grâce { n, xp, claimedFree, claimedPrem, premium, seen }.
-- Les fonctions ne font JAMAIS d'octroi : elles renvoient la liste `grants` à appliquer par le serveur (pièces en minutes de revenu, œuf par rareté, jetons, parchemins, cosmétiques, espèce).
-- Style : pas de `+=`, pas de `continue`, valeurs douteuses gardées par type avant toute comparaison.
local Season = {}

local DAY = 86400

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

local function hasBit(mask, t)
	return math.floor(mask / 2 ^ (t - 1)) % 2 == 1
end

local function setBit(mask, t)
	if hasBit(mask, t) then
		return mask
	end
	return mask + 2 ^ (t - 1)
end

function Season.new(Config, SD)
	local S = {}
	local SEASON = SD.SEASON
	local NT = SEASON.tiers
	local MASK_MAX = 2 ^ NT - 1

	-- XP cumulée pour atteindre le palier t : cum[t + 1]
	local cum = { 0 }
	for t = 1, NT do
		cum[t + 1] = cum[t] + SD.TIER_XP[t]
	end
	local MAX_XP = cum[NT + 1]
	S.MAX_XP = MAX_XP
	S.TIERS = NT

	function S.xpForTier(t)
		t = int(t, 0, NT, 0)
		return cum[t + 1]
	end

	function S.tierOf(xp)
		xp = int(xp, 0, MAX_XP, 0)
		local t = 0
		for i = 1, NT do
			if xp >= cum[i + 1] then
				t = i
			end
		end
		return t
	end

	local function tierIdx(name)
		for i, t in ipairs(Config.TIERS) do
			if t.name == name then
				return i
			end
		end
		return nil
	end
	S.tierIdx = tierIdx

	-- L'éclosion d'une rareté (indice Config.TIERS) donne-t-elle de l'XP de saison ?
	function S.hatchQualifies(tier)
		local need = tierIdx(SEASON.hatchMinTier)
		return need ~= nil and type(tier) == "number" and tier >= need
	end

	---------------------------------------------------------------- Saison courante (aucun chevauchement : fin(n) = début(n + 1))
	local function seasonStart(n)
		return SEASON.start + (n - 1) * SEASON.days * DAY
	end
	S.seasonStart = seasonStart

	function S.currentSeason(nowUtc)
		if not isnum(nowUtc) then
			nowUtc = 0
		end
		if nowUtc < SEASON.start then
			return { n = 0, startsAt = SEASON.start, endsAt = SEASON.start, daysLeft = 0, preseason = true }
		end
		local n = math.floor((nowUtc - SEASON.start) / (SEASON.days * DAY)) + 1
		local startsAt = seasonStart(n)
		local endsAt = startsAt + SEASON.days * DAY
		local def = SD.get(n)
		return {
			n = n,
			theme = def.theme,
			name = def.name,
			def = def,
			startsAt = startsAt,
			endsAt = endsAt,
			dayIndex = math.floor((nowUtc - startsAt) / DAY) + 1,
			daysLeft = math.ceil((endsAt - nowUtc) / DAY),
		}
	end

	---------------------------------------------------------------- Profil : création, assainissement, bascule
	local function sanitizeSeason(s)
		s.n = int(s.n, 0, 1000000, 0)
		s.xp = int(s.xp, 0, MAX_XP, 0)
		s.day = int(s.day, 0, 1000000000, 0)
		s.dayXp = int(s.dayXp, 0, SEASON.dailyCap, 0)
		s.claimedFree = int(s.claimedFree, 0, MASK_MAX, 0)
		s.claimedPrem = int(s.claimedPrem, 0, MASK_MAX, 0)
		s.premium = int(s.premium, 0, 1000000, 0)
		s.plus = int(s.plus, 0, 1000000, 0)
		if type(s.prev) == "table" then
			local p = s.prev
			p.n = int(p.n, 1, 1000000, 1)
			p.xp = int(p.xp, 0, MAX_XP, 0)
			p.claimedFree = int(p.claimedFree, 0, MASK_MAX, 0)
			p.claimedPrem = int(p.claimedPrem, 0, MASK_MAX, 0)
			p.premium = int(p.premium, 0, 1000000, 0)
			p.seen = p.seen == true
		else
			s.prev = nil
		end
		return s
	end

	local function freshSeason(n, xp)
		return { n = n, xp = xp or 0, day = 0, dayXp = 0, claimedFree = 0, claimedPrem = 0, premium = 0, plus = 0 }
	end

	-- Garantit profil.season à jour pour l'instant `nowUtc` : migre un profil sans saison (l'ancien profil.seasonXp du lot 15 y est versé puis remis à 0),
	-- bascule de saison (la précédente est gardée en `prev` pendant la grâce). Idempotent. Renvoie (season, cur).
	function S.migrate(profil, nowUtc)
		local cur = S.currentSeason(nowUtc)
		local s = profil.season
		if type(s) ~= "table" then
			local legacy = int(profil.seasonXp, 0, MAX_XP, 0)
			profil.seasonXp = 0
			s = freshSeason(cur.n, legacy)
			profil.season = s
		else
			sanitizeSeason(s)
		end
		if cur.n > 0 and s.n < cur.n then
			if s.n == 0 then
				s.n = cur.n -- XP gagnée avant le début de la toute première saison : conservée
			else
				local keep = nil
				if s.n == cur.n - 1 and (s.xp > 0 or s.premium == s.n) then
					keep = { n = s.n, xp = s.xp, claimedFree = s.claimedFree, claimedPrem = s.claimedPrem, premium = s.premium, seen = false }
				end
				local fresh = freshSeason(cur.n, 0)
				fresh.prev = keep
				profil.season = fresh
				s = fresh
			end
		end
		return s, cur
	end

	local function graceLeftSeconds(prevN, nowUtc)
		return seasonStart(prevN + 1) + SEASON.graceDays * DAY - nowUtc
	end

	---------------------------------------------------------------- Récompenses (résolues)
	local function findSpecies(name)
		local ex = tierIdx(SEASON.exclusiveTier)
		if not name or not ex or type(Config.PETS) ~= "table" then
			return false, ex
		end
		for _, p in ipairs(Config.PETS) do
			if p.name == name and p.tier == ex then
				return true, ex
			end
		end
		return false, ex
	end

	local function resolveEntry(n, e)
		local k = e.k
		if k == "coins" then
			return { kind = "coins", minutes = e.v }
		elseif k == "egg" then
			local idx = tierIdx(e.name)
			if not idx then
				return { kind = "coins", minutes = 30, fallback = true } -- rareté inconnue : jamais une récompense perdue
			end
			return { kind = "egg", tier = idx, name = e.name, n = e.n or 1 }
		elseif k == "token" then
			return { kind = "token", n = e.v }
		elseif k == "scroll" then
			return { kind = "scroll", n = e.v }
		elseif k == "cosmetic" or k == "aura" then
			return { kind = k, id = "s" .. n .. "_" .. e.key, label = SD.cosmeticLabel(n, e.key), season = n }
		elseif k == "species" then
			local def = SD.get(n)
			local name = def and def.species
			local ok, ex = findSpecies(name)
			if ok then
				return { kind = "species", name = name, tier = ex, season = n }
			end
			return { kind = "cosmetic", id = "s" .. n .. "_trophy", label = SD.cosmeticLabel(n, "trophy"), season = n, fallback = true }
		end
		return { kind = "coins", minutes = 15, fallback = true }
	end

	-- Liste de grants du palier t de la piste `track` ("free" | "premium") pour la saison n (nil si aucune récompense).
	function S.rewardFor(n, t, track)
		local tbl = track == "premium" and SD.PREMIUM_TRACK or SD.FREE
		local entries = tbl[t]
		if not entries then
			return nil
		end
		local out = {}
		for _, e in ipairs(entries) do
			out[#out + 1] = resolveEntry(n, e)
		end
		return out
	end

	---------------------------------------------------------------- XP
	-- Ajoute l'XP de la source (pve, pvp, duel, daily, weekly, hatch). Plafond de SEASON.dailyCap par jour UTC pour les sources `capped`.
	-- Renvoie { ok, gained, xp, tier, tiersUp = { paliers atteints }, capped } ou { ok = false, reason }.
	function S.addXp(profil, source, nowUtc)
		if type(source) ~= "string" then
			return { ok = false, reason = "source" }
		end
		local def = SD.XP[source]
		if not def then
			return { ok = false, reason = "source" }
		end
		-- Avant le début de la toute première saison : l'XP est mise de côté (versée au démarrage), toujours plafonnée.
		local s = S.migrate(profil, nowUtc)
		local day = math.floor((isnum(nowUtc) and nowUtc or 0) / DAY)
		if s.day ~= day then
			s.day = day
			s.dayXp = 0
		end
		local want = def.amount
		local capped = false
		if def.capped then
			local room = SEASON.dailyCap - s.dayXp
			if room < want then
				want = math.max(0, room)
				capped = true
			end
		end
		local before = S.tierOf(s.xp)
		local room2 = MAX_XP - s.xp
		if room2 < want then
			want = room2
		end
		s.xp = s.xp + want
		if def.capped then
			s.dayXp = math.min(SEASON.dailyCap, s.dayXp + want)
		end
		local after = S.tierOf(s.xp)
		local up = {}
		for t = before + 1, after do
			up[#up + 1] = t
		end
		return { ok = true, gained = want, xp = s.xp, tier = after, tiersUp = up, capped = capped }
	end

	---------------------------------------------------------------- Réclamation
	-- Réclame le palier `tier` de la piste `track` ("free" | "premium"). `which` = "prev" pour la saison précédente pendant la grâce. Idempotent : une 2e demande = reason "already".
	-- Renvoie { ok, grants, tier, track, season } ou { ok = false, reason } (bad, locked, premium, already, none, expired, noseason).
	function S.claim(profil, tier, track, nowUtc, which)
		if type(tier) ~= "number" or tier ~= tier or tier % 1 ~= 0 or tier < 1 or tier > NT then
			return { ok = false, reason = "bad" }
		end
		if track ~= "free" and track ~= "premium" then
			return { ok = false, reason = "bad" }
		end
		local s, cur = S.migrate(profil, nowUtc)
		local target = s
		if which == "prev" then
			target = s.prev
			if not target then
				return { ok = false, reason = "none" }
			end
			if graceLeftSeconds(target.n, nowUtc) <= 0 then
				return { ok = false, reason = "expired" }
			end
		elseif cur.n == 0 then
			return { ok = false, reason = "noseason" }
		end
		if S.tierOf(target.xp) < tier then
			return { ok = false, reason = "locked" }
		end
		if track == "premium" and target.premium ~= target.n then
			return { ok = false, reason = "premium" }
		end
		local field = track == "premium" and "claimedPrem" or "claimedFree"
		if hasBit(target[field], tier) then
			return { ok = false, reason = "already" }
		end
		local grants = S.rewardFor(target.n, tier, track)
		if not grants then
			return { ok = false, reason = "none" }
		end
		target[field] = setBit(target[field], tier)
		return { ok = true, grants = grants, tier = tier, track = track, season = target.n }
	end

	-- Réclame tout ce qui est réclamable (saison courante, et précédente si which == "prev"). Renvoie la liste cumulée de grants.
	function S.claimAll(profil, nowUtc, which)
		local grants, count = {}, 0
		for t = 1, NT do
			for _, track in ipairs({ "free", "premium" }) do
				local r = S.claim(profil, t, track, nowUtc, which)
				if r.ok then
					count = count + 1
					for _, g in ipairs(r.grants) do
						grants[#grants + 1] = g
					end
				end
			end
		end
		return { ok = true, grants = grants, claimed = count }
	end

	---------------------------------------------------------------- Achat de la piste premium
	-- kind : "premium" (399), "premiumPlus" (799 = premium + 10 paliers, une fois par saison), "upgradePlus" (complément 400, déjà premium : +10 paliers, une fois par saison).
	-- Crédite UNE seule fois les récompenses premium des paliers déjà atteints (le masque claimedPrem les marque), puis les paliers suivants se réclament normalement.
	-- Renvoie { ok, kind, grants, credited, boosted, tier } ou { ok = false, reason } (kind, noseason, owned, plusUsed, needPremium).
	function S.buyPremium(profil, kind, nowUtc)
		if type(kind) ~= "string" or not SD.PREMIUM[kind] then
			return { ok = false, reason = "kind" }
		end
		local s, cur = S.migrate(profil, nowUtc)
		if cur.n == 0 then
			return { ok = false, reason = "noseason" }
		end
		local def = SD.PREMIUM[kind]
		local owned = s.premium == s.n
		if kind == "upgradePlus" then
			if not owned then
				return { ok = false, reason = "needPremium" }
			end
		elseif owned then
			return { ok = false, reason = "owned" }
		end
		if def.plus and s.plus == s.n then
			return { ok = false, reason = "plusUsed" }
		end
		s.premium = s.n
		local boosted = 0
		if def.plus then
			s.plus = s.n
			local t0 = S.tierOf(s.xp)
			local t1 = math.min(NT, t0 + SEASON.plusTiers)
			boosted = t1 - t0
			if cum[t1 + 1] > s.xp then
				s.xp = cum[t1 + 1]
			end
		end
		local grants, credited = {}, 0
		local reached = S.tierOf(s.xp)
		for t = 1, reached do
			if not hasBit(s.claimedPrem, t) then
				local g = S.rewardFor(s.n, t, "premium")
				if g then
					s.claimedPrem = setBit(s.claimedPrem, t)
					credited = credited + 1
					for _, x in ipairs(g) do
						grants[#grants + 1] = x
					end
				end
			end
		end
		return { ok = true, kind = kind, grants = grants, credited = credited, boosted = boosted, tier = reached }
	end

	---------------------------------------------------------------- Fin de saison : récapitulatif et grâce
	local function countUnclaimed(target)
		local reached = S.tierOf(target.xp)
		local free, prem, lost = 0, 0, {}
		for t = 1, reached do
			if SD.FREE[t] and not hasBit(target.claimedFree, t) then
				free = free + 1
				for _, g in ipairs(S.rewardFor(target.n, t, "free")) do
					if g.kind == "cosmetic" or g.kind == "aura" then
						lost[#lost + 1] = g.label
					end
				end
			end
			if target.premium == target.n and SD.PREMIUM_TRACK[t] and not hasBit(target.claimedPrem, t) then
				prem = prem + 1
				for _, g in ipairs(S.rewardFor(target.n, t, "premium")) do
					if g.kind == "cosmetic" or g.kind == "aura" or g.kind == "species" then
						lost[#lost + 1] = g.label or g.name
					end
				end
			end
		end
		return free, prem, lost
	end

	-- Écran récapitulatif de la saison précédente (nil si rien à montrer). `expired` : grâce terminée, ce qui reste est perdu.
	function S.recap(profil, nowUtc)
		local s = S.migrate(profil, nowUtc)
		local p = s.prev
		if not p or p.seen then
			return nil
		end
		local free, prem, lost = countUnclaimed(p)
		local left = graceLeftSeconds(p.n, nowUtc)
		local def = SD.get(p.n)
		return {
			n = p.n,
			theme = def.theme,
			name = def.name,
			tier = S.tierOf(p.xp),
			xp = p.xp,
			premium = p.premium == p.n,
			unclaimedFree = free,
			unclaimedPremium = prem,
			unclaimedCosmetics = lost,
			expired = left <= 0,
			graceDaysLeft = left > 0 and math.ceil(left / DAY) or 0,
		}
	end

	-- Le joueur a vu le récapitulatif : plus de bandeau ; une saison précédente expirée est effacée.
	function S.ackRecap(profil, nowUtc)
		local s = S.migrate(profil, nowUtc)
		local p = s.prev
		if p then
			if graceLeftSeconds(p.n, nowUtc) <= 0 then
				s.prev = nil
			else
				p.seen = true
			end
		end
		return true
	end

	---------------------------------------------------------------- Vue pour le client (aucun octroi)
	function S.view(profil, nowUtc)
		local s, cur = S.migrate(profil, nowUtc)
		local tier = S.tierOf(s.xp)
		local rows = {}
		for t = 1, NT do
			local f = S.rewardFor(s.n, t, "free")
			local p = S.rewardFor(s.n, t, "premium")
			rows[t] = {
				tier = t,
				free = f,
				premium = p,
				reached = t <= tier,
				freeClaimed = hasBit(s.claimedFree, t),
				premiumClaimed = hasBit(s.claimedPrem, t),
			}
		end
		local nextNeed = tier < NT and (cum[tier + 2] - s.xp) or 0
		return {
			season = cur.n,
			theme = cur.theme,
			name = cur.name,
			daysLeft = cur.daysLeft,
			xp = s.xp,
			tier = tier,
			xpToNext = nextNeed,
			dayXp = s.day == math.floor((isnum(nowUtc) and nowUtc or 0) / DAY) and s.dayXp or 0,
			dailyCap = SEASON.dailyCap,
			premium = s.premium == s.n and s.n > 0,
			plusUsed = s.plus == s.n and s.n > 0,
			rows = rows,
			hasPrev = s.prev ~= nil and not s.prev.seen,
		}
	end

	return S
end

return Season
