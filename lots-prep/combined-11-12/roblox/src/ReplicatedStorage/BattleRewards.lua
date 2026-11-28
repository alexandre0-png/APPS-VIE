-- ModuleScript : ReplicatedStorage/Shared/BattleRewards   (LOT 12 partie B, D.5)
-- Récompense AU CHOIX après une victoire PvE (tour des Dresseurs, combats de PNJ) : module PUR (aucun service Roblox). Ne remplace pas Rewards.lua (série / calendrier du lot 15).
-- Le SERVEUR tire 3 cartes de 3 catégories DIFFÉRENTES (poids : Pièces 30, Expérience 25, Œuf 15, Vitesse 15, Effet 15 ; aux boss, une des 3 est toujours l'Œuf), les enregistre dans
-- `data.battle.pendingPick = { id, cards, expires, floor, mode }` puis les envoie au client ; le joueur en choisit une en 15 s, sinon la première. Se déconnecter ou relancer ne
-- retire pas la récompense et n'en retire pas de nouvelle : BattleRewards.offer renvoie le tirage existant.
-- Aucune carte ne donne de force payante : pièces, XP de pet (PetXp, jamais vendu), un œuf, de la vitesse de piste GAGNÉE, un boost temporaire gagné en jouant (aucun Robux).
-- Aléa : Park-Miller (48271 mod 2^31-1) en double précision, graine INJECTABLE (le serveur passe une graine issue de Random ; les tests passent une graine fixe).
-- Config attendu (existant) : towerTier, liveEggTier, nextLiveTier, eggCoinValue (optionnel), TIERS, fmt (optionnel). Pas de += ni de continue (lanceur lupa).
local BattleRewards = {}

BattleRewards.PICK_SECONDS = 15
BattleRewards.CARD_COUNT = 3
-- Poids de tirage (D.5), dans l'ordre de tirage stable.
BattleRewards.KINDS = { "coins", "xp", "egg", "speed", "effect" }
BattleRewards.WEIGHTS = { coins = 30, xp = 25, egg = 15, speed = 15, effect = 15 }
-- Multiplicateurs de valeur : première victoire de l'étage x2, victoire répétée x0,5, combat de PNJ x0,6 (D.5).
BattleRewards.MODE_MUL = { first = 2, ["repeat"] = 0.5, npc = 0.6, normal = 1 }
BattleRewards.COINS_MIN = 500
BattleRewards.COINS_SECONDS = 90 -- « revenus de 1,5 min »
BattleRewards.MAX_FLOOR = 45
-- Effets (boosts temporaires) : durée en secondes, non cumulables avec eux-mêmes (prolongent), plafond 30 min. `name` : libellé affiché.
BattleRewards.EFFECTS = {
	income2 = { name = "Revenus ×2", seconds = 300, order = 1 },
	luck10 = { name = "Chance +10 points", seconds = 300, order = 2 },
	xp2 = { name = "XP ×2", seconds = 600, order = 3 },
	speed15 = { name = "Vitesse +15 %", seconds = 300, order = 4 },
}
BattleRewards.EFFECT_KEYS = { "income2", "luck10", "xp2", "speed15" }
BattleRewards.BOOST_CAP_SECONDS = 1800

local COINS_CAP, XP_CAP, SPEED_CAP = 1e15, 100000, 1000

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

---------------------------------------------------------------- Aléa : Park-Miller 48271 mod 2^31-1
local M = 2147483647
local A = 48271 -- état < 2^31, produit < 2^47 : exact en double précision (pas de 1103515245)
BattleRewards.MODULUS, BattleRewards.MULTIPLIER = M, A

-- Générateur à graine injectable. Toute graine (même NaN, négative, énorme) devient un état valide 1..M-1.
function BattleRewards.rng(seed)
	local s = 1
	if isnum(seed) then
		s = math.floor(math.abs(seed)) % (M - 1)
		if s == 0 then
			s = 1
		end
	end
	local r = {}
	function r.next() -- flottant dans ]0 ; 1[
		s = (s * A) % M
		return s / M
	end
	function r.int(lo, hi) -- entier dans [lo ; hi]
		return lo + math.floor(r.next() * (hi - lo + 1))
	end
	function r.state()
		return s
	end
	return r
end

---------------------------------------------------------------- Valeurs des cartes (D.5)
local function modeOf(ctx)
	local m = type(ctx) == "table" and ctx.mode or nil
	if m ~= nil and BattleRewards.MODE_MUL[m] then
		return m
	end
	return "normal"
end

local function scaled(base, mul, lo)
	return math.max(lo, math.floor(base * mul + 1e-9))
end

-- Rareté de l'étage ; l'œuf d'un BOSS est d'un cran au-dessus (règle existante, jamais au-delà de 8 : ni Exclusif ni Divin), toujours une rareté publiée.
function BattleRewards.eggTierFor(Config, floor, boss)
	local rt = Config.towerTier(math.max(1, floor))
	local t = rt
	if boss then
		t = math.min(8, Config.nextLiveTier(rt) or rt)
	end
	return Config.liveEggTier(t)
end

-- ctx = { floor (0 pour un PNJ), income (revenu par seconde), mode ("first" | "repeat" | "npc" | "normal") }. Retourne une carte { kind, ... } sans état caché.
function BattleRewards.makeCard(Config, kind, ctx, rnd)
	local f = int(ctx.floor, 0, BattleRewards.MAX_FLOOR, 0)
	local mul = BattleRewards.MODE_MUL[modeOf(ctx)]
	local boss = f >= 5 and f % 5 == 0 and modeOf(ctx) ~= "npc"
	if kind == "coins" then
		local income = isnum(ctx.income) and math.max(0, ctx.income) or 0
		local base = math.max(BattleRewards.COINS_MIN, income * BattleRewards.COINS_SECONDS * (1 + f / 10))
		return { kind = "coins", amount = math.min(COINS_CAP, scaled(base, mul, 1)) }
	elseif kind == "xp" then
		return { kind = "xp", amount = math.min(XP_CAP, scaled(30 + 10 * f, mul, 1)) }
	elseif kind == "egg" then
		return { kind = "egg", tier = BattleRewards.eggTierFor(Config, f, boss) }
	elseif kind == "speed" then
		return { kind = "speed", amount = math.min(SPEED_CAP, scaled(2 + f // 5, mul, 1)) }
	end
	local key = BattleRewards.EFFECT_KEYS[rnd.int(1, #BattleRewards.EFFECT_KEYS)]
	return { kind = "effect", key = key, seconds = BattleRewards.EFFECTS[key].seconds }
end

---------------------------------------------------------------- Tirage de 3 cartes
-- Tirage pondéré SANS remise sur les catégories : 3 catégories distinctes. `boss` : l'Œuf est d'office l'une des 3. L'ordre final est mélangé (Fisher-Yates).
function BattleRewards.draw(Config, ctx, seed)
	local rnd = BattleRewards.rng(seed)
	local f = int(ctx.floor, 0, BattleRewards.MAX_FLOOR, 0)
	local boss = f >= 5 and f % 5 == 0 and modeOf(ctx) ~= "npc"
	local pool, kinds = {}, {}
	for _, k in ipairs(BattleRewards.KINDS) do
		pool[#pool + 1] = k
	end
	local function take(k)
		for i, v in ipairs(pool) do
			if v == k then
				table.remove(pool, i)
				break
			end
		end
		kinds[#kinds + 1] = k
	end
	if boss then
		take("egg")
	end
	while #kinds < BattleRewards.CARD_COUNT do
		local total = 0
		for _, k in ipairs(pool) do
			total = total + BattleRewards.WEIGHTS[k]
		end
		local roll, pick = rnd.next() * total, pool[#pool]
		for _, k in ipairs(pool) do
			roll = roll - BattleRewards.WEIGHTS[k]
			if roll < 0 then
				pick = k
				break
			end
		end
		take(pick)
	end
	for i = #kinds, 2, -1 do
		local j = rnd.int(1, i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
	local cards = {}
	for _, k in ipairs(kinds) do
		cards[#cards + 1] = BattleRewards.makeCard(Config, k, ctx, rnd)
	end
	return cards
end

---------------------------------------------------------------- pendingPick : enregistrement serveur
-- Crée un tirage enregistrable : { id, cards, expires, floor, mode }. `id` est fourni par le serveur (compteur ou chaîne) ; `now` = os.time().
function BattleRewards.newPick(Config, ctx, seed, now, id)
	return {
		id = id,
		cards = BattleRewards.draw(Config, ctx, seed),
		expires = (isnum(now) and now or 0) + BattleRewards.PICK_SECONDS,
		floor = int(ctx.floor, 0, BattleRewards.MAX_FLOOR, 0),
		mode = modeOf(ctx),
	}
end

-- Point d'entrée serveur après une victoire : s'il existe déjà un pendingPick (assaini), il est RENDU TEL QUEL (pas de nouveau tirage : se reconnecter ou enchaîner
-- ne fait ni perdre ni refaire la récompense). Retourne (pick, estNouveau). Le serveur doit stocker `pick` dans data.battle.pendingPick quand estNouveau.
function BattleRewards.offer(Config, pending, ctx, seed, now, id)
	local clean = BattleRewards.sanitizePending(Config, pending)
	if clean then
		return clean, false
	end
	return BattleRewards.newPick(Config, ctx, seed, now, id), true
end

function BattleRewards.expired(pick, now)
	return type(pick) == "table" and isnum(pick.expires) and isnum(now) and now >= pick.expires
end

-- Choix du joueur : retourne (carte, auto). Index invalide avant expiration -> nil, "bad_index" (le serveur ignore et NE consomme pas) ; après expiration, la première carte
-- est donnée d'office (auto = true), quel que soit l'index. id différent -> nil, "bad_id". Le serveur met data.battle.pendingPick = nil AVANT d'attribuer (pas de double gain).
function BattleRewards.claim(pick, id, index, now)
	if type(pick) ~= "table" or type(pick.cards) ~= "table" or #pick.cards == 0 then
		return nil, "no_pick"
	end
	if id ~= nil and pick.id ~= id then
		return nil, "bad_id"
	end
	if BattleRewards.expired(pick, now) then
		return pick.cards[1], true
	end
	if isnum(index) and index % 1 == 0 and index >= 1 and index <= #pick.cards then
		return pick.cards[index], false
	end
	return nil, "bad_index"
end

-- Secondes restantes (>= 0) pour l'affichage client ; à la reconnexion un tirage échu est résolu par claim (auto), un tirage vivant est renvoyé avec son temps restant.
function BattleRewards.remaining(pick, now)
	if type(pick) ~= "table" or not isnum(pick.expires) or not isnum(now) then
		return 0
	end
	return math.max(0, pick.expires - now)
end

---------------------------------------------------------------- Assainissement (profil)
local function cleanCard(Config, c)
	if type(c) ~= "table" then
		return nil
	end
	local kind = c.kind
	if kind == "coins" and isnum(c.amount) then
		return { kind = "coins", amount = int(c.amount, 1, COINS_CAP, 1) }
	elseif kind == "xp" and isnum(c.amount) then
		return { kind = "xp", amount = int(c.amount, 1, XP_CAP, 1) }
	elseif kind == "speed" and isnum(c.amount) then
		return { kind = "speed", amount = int(c.amount, 1, SPEED_CAP, 1) }
	elseif kind == "egg" and isnum(c.tier) then
		local n = type(Config.TIERS) == "table" and #Config.TIERS or 10
		return { kind = "egg", tier = int(c.tier, 1, n, 1) }
	elseif kind == "effect" and type(c.key) == "string" and BattleRewards.EFFECTS[c.key] then
		return { kind = "effect", key = c.key, seconds = BattleRewards.EFFECTS[c.key].seconds }
	end
	return nil
end

-- Assainit un pendingPick lu dans un profil : table valide (3 cartes de catégories distinctes, expires numérique) ou nil. IDEMPOTENT : sanitize(sanitize(x)) == sanitize(x).
function BattleRewards.sanitizePending(Config, saved)
	if type(saved) ~= "table" or type(saved.cards) ~= "table" or not isnum(saved.expires) then
		return nil
	end
	if not (type(saved.id) == "string" or isnum(saved.id)) then
		return nil
	end
	local cards, seen = {}, {}
	for _, c in ipairs(saved.cards) do
		local cc = cleanCard(Config, c)
		if cc and not seen[cc.kind] and #cards < BattleRewards.CARD_COUNT then
			seen[cc.kind] = true
			cards[#cards + 1] = cc
		end
	end
	if #cards ~= BattleRewards.CARD_COUNT then
		return nil
	end
	local mode = type(saved.mode) == "string" and BattleRewards.MODE_MUL[saved.mode] and saved.mode or "normal"
	return { id = saved.id, cards = cards, expires = int(saved.expires, 0, 4e9, 0), floor = int(saved.floor, 0, BattleRewards.MAX_FLOOR, 0), mode = mode }
end

-- Boosts temporaires : { income2, luck10, xp2, speed15 } = os.time() de fin (entier). Clés inconnues supprimées, valeurs <= 0 supprimées. IDEMPOTENT.
function BattleRewards.sanitizeBoosts(saved)
	local out = {}
	if type(saved) == "table" then
		for _, key in ipairs(BattleRewards.EFFECT_KEYS) do
			local v = saved[key]
			if isnum(v) and v > 0 then
				out[key] = int(v, 1, 4e9, 1)
			end
		end
	end
	return out
end

function BattleRewards.boostActive(boosts, key, now)
	return type(boosts) == "table" and isnum(boosts[key]) and isnum(now) and boosts[key] > now
end

-- Applique (ou prolonge) un boost : jamais cumulé avec lui-même, fin plafonnée à now + 30 min. Retourne la nouvelle fin.
function BattleRewards.applyBoost(boosts, key, seconds, now)
	local def = BattleRewards.EFFECTS[key]
	if type(boosts) ~= "table" or not def or not isnum(now) then
		return nil
	end
	local sec = isnum(seconds) and math.max(0, math.min(BattleRewards.BOOST_CAP_SECONDS, seconds)) or def.seconds
	local cur = isnum(boosts[key]) and boosts[key] or 0
	local ends = math.min(now + BattleRewards.BOOST_CAP_SECONDS, math.max(now, cur) + sec)
	boosts[key] = math.floor(ends)
	return boosts[key]
end

---------------------------------------------------------------- Attribution (serveur)
-- data = profil { coins, speed, boosts, slots, battle = { team } } ; hooks.giveEgg(tier) -> true si l'œuf est placé (base pleine -> false : son prix en pièces).
-- Retourne un résumé { kind, coins?, xp?, speed?, egg?, effect?, converted?, levelUps? } pour l'écran de résultat. N'effleure JAMAIS data.rb ni un champ payant.
function BattleRewards.grant(Config, data, card, hooks, now, PetXp)
	local c = cleanCard(Config, card)
	if not c or type(data) ~= "table" then
		return nil
	end
	local out = { kind = c.kind }
	if c.kind == "coins" then
		data.coins = (isnum(data.coins) and data.coins or 0) + c.amount
		out.coins = c.amount
	elseif c.kind == "xp" then
		out.xp = c.amount
		out.pets = {}
		if PetXp and type(data.battle) == "table" then
			out.pets = PetXp.addToTeam(data.slots, data.battle.team, c.amount)
		end
	elseif c.kind == "speed" then
		data.speed = (isnum(data.speed) and data.speed or 0) + c.amount
		out.speed = c.amount
	elseif c.kind == "egg" then
		local placed = type(hooks) == "table" and type(hooks.giveEgg) == "function" and hooks.giveEgg(c.tier) == true
		if placed then
			out.egg = c.tier
		else
			local price = type(Config.eggCoinValue) == "function" and Config.eggCoinValue(c.tier) or 0
			data.coins = (isnum(data.coins) and data.coins or 0) + price
			out.coins, out.converted, out.egg = price, true, c.tier
		end
	else
		if type(data.boosts) ~= "table" then
			data.boosts = {}
		end
		out.effect = c.key
		out.endsAt = BattleRewards.applyBoost(data.boosts, c.key, c.seconds, now)
	end
	return out
end

---------------------------------------------------------------- Affichage (texte sans état, utilisable par le serveur pour la vue)
function BattleRewards.cardText(Config, card)
	local fmt = type(Config) == "table" and type(Config.fmt) == "function" and Config.fmt or tostring
	local c = type(card) == "table" and card or {}
	if c.kind == "coins" then
		return "🪙", "Pièces", "+" .. fmt(c.amount or 0) .. " 🪙"
	elseif c.kind == "xp" then
		return "⭐", "Expérience", "+" .. tostring(c.amount or 0) .. " XP à chaque pet de l'équipe"
	elseif c.kind == "egg" then
		local t = type(Config) == "table" and type(Config.TIERS) == "table" and Config.TIERS[c.tier or 0] or nil
		return "🥚", "Œuf", "1 œuf " .. (t and t.name or "?")
	elseif c.kind == "speed" then
		return "👟", "Vitesse", "+" .. tostring(c.amount or 0) .. " de vitesse permanente"
	elseif c.kind == "effect" then
		local e = BattleRewards.EFFECTS[c.key or ""]
		return "✨", "Effet", e and (e.name .. " · " .. math.floor(e.seconds / 60) .. " min") or "?"
	end
	return "?", "?", ""
end

-- Vue envoyée au client : AUCUNE donnée de tirage (graine) ; juste de quoi afficher et renvoyer l'index choisi.
function BattleRewards.view(Config, pick, now)
	local cards = {}
	for i, c in ipairs(pick.cards) do
		local icon, title, desc = BattleRewards.cardText(Config, c)
		cards[i] = { kind = c.kind, icon = icon, title = title, desc = desc, boss = c.kind == "egg" and pick.floor % 5 == 0 and pick.floor > 0 and pick.mode ~= "npc" or nil }
	end
	return { id = pick.id, cards = cards, seconds = BattleRewards.remaining(pick, now), floor = pick.floor }
end

return BattleRewards
