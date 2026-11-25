-- ModuleScript : ReplicatedStorage/Shared/Belt
-- Tapis roulant central du marché : logique PURE (aucun service Roblox), testée. Le serveur appelle step() à 10 Hz et tryBuy() à chaque demande d'achat ;
-- le client ne fait qu'afficher. La rareté d'un œuf est tirée à son apparition et reste VISIBLE avant l'achat. Un œuf n'a qu'un acheteur (réservation atomique).
local Belt = {}

local function nextRnd(state)
	state = (state * 16807) % 2147483647
	return state / 2147483647, state
end

-- Tire une rareté (1..#weights) d'après des poids ; r dans [0, 1).
function Belt.pick(weights, r)
	local total = 0
	for _, w in ipairs(weights) do
		total = total + math.max(w, 0)
	end
	local x = r * total
	for i, w in ipairs(weights) do
		if w > 0 then
			x = x - w
			if x < 0 then
				return i
			end
		end
	end
	return #weights
end

-- Prix en pièces d'un œuf de rareté `tier` au tapis : `priceRatio` du prix de la boutique (arrondi inférieur).
function Belt.price(Config, tier)
	return math.floor(Config.EGG_PRICE[tier] * Config.BELT.priceRatio)
end

function Belt.new(seed, startAt)
	return { eggs = {}, nextId = 1, rnd = (math.floor(seed) % 2147483646) + 1, nextSpawn = startAt or 0, lastBuy = {}, legendaryAt = {}, goldenUntil = 0, sold = 0, welcomed = {} }
end

-- Le tapis doré est-il actif à l'instant `now` ? Retourne les secondes restantes (0 si inactif).
function Belt.goldenLeft(st, now)
	return math.max(0, st.goldenUntil - now)
end

-- Ajoute `seconds` de tapis doré (cumulable, plafonné à `maxSeconds` restantes). `by` (optionnel) : nom du donateur, affiché sur le panneau.
function Belt.addGolden(Config, st, now, seconds, by)
	local G = Config.BELT.golden
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return Belt.goldenLeft(st, now)
	end
	local left = Belt.goldenLeft(st, now)
	st.goldenUntil = now + math.min(G.maxSeconds, left + seconds)
	if by then
		st.goldenBy = by
	end
	return Belt.goldenLeft(st, now)
end

-- « 9:05 » pour 545 secondes.
function Belt.clock(seconds)
	local n = math.max(0, math.floor((seconds or 0) + 0.999))
	return string.format("%d:%02d", n // 60, n % 60)
end

-- Contenu du panneau du tapis : les deux tables de rareté (textes de Config.beltOddsText, donc identiques à la config), celle en vigueur, le compte à rebours du tapis doré.
function Belt.panel(Config, st, now)
	local left = Belt.goldenLeft(st, now)
	local golden = left > 0
	local status = "Tapis standard : un œuf toutes les " .. Config.BELT.interval .. " s"
	if golden then
		status = "✨ TAPIS DORÉ : " .. Belt.clock(left) .. (st.goldenBy and (" · Offert par " .. st.goldenBy) or "")
	end
	return { normal = Config.beltOddsText("normal"), golden = Config.beltOddsText("golden"), active = golden and "golden" or "normal", left = left, status = status }
end

-- Abscisse de l'œuf sur le tapis (de belt.x0 vers belt.x1 à `speed` studs/s) ; nil s'il est tombé dans le bac.
function Belt.positionX(Config, egg, now)
	local B = Config.Map2.belt
	local x = B.x0 + Config.BELT.speed * (now - egg.born)
	if x > B.x1 then
		return nil
	end
	return x
end

-- Fait vivre le tapis : retire les œufs arrivés au bac, en fait apparaître un nouveau toutes les `interval` secondes (3 en doré) tant qu'il y en a moins de maxEggs.
-- `welcome` : si non nil, { userId = n } -> un œuf de bienvenue Commun gratuit est posé en tête (une fois par joueur, voir Belt.welcome). Retourne (apparus, retirés).
function Belt.step(Config, st, now)
	local C = Config.BELT
	local removed, spawned = {}, {}
	local keep = {}
	for _, e in ipairs(st.eggs) do
		if Belt.positionX(Config, e, now) then
			keep[#keep + 1] = e
		else
			removed[#removed + 1] = e
		end
	end
	st.eggs = keep
	local golden = Belt.goldenLeft(st, now) > 0
	local interval = golden and C.golden.interval or C.interval
	local weights = golden and C.weights.golden or C.weights.normal
	local guard = 0
	while now >= st.nextSpawn and guard < 50 do
		guard = guard + 1
		if #st.eggs < C.maxEggs then
			local r
			r, st.rnd = nextRnd(st.rnd)
			local egg = { id = st.nextId, tier = Belt.pick(weights, r), born = st.nextSpawn, claimedBy = nil, price = nil }
			egg.price = Belt.price(Config, egg.tier)
			st.nextId = st.nextId + 1
			st.eggs[#st.eggs + 1] = egg
			spawned[#spawned + 1] = egg
		end
		st.nextSpawn = st.nextSpawn + interval
	end
	if now - st.nextSpawn > 60 then
		st.nextSpawn = now -- serveur en pause : pas de rattrapage massif
	end
	return spawned, removed
end

-- Œuf de bienvenue : gratuit, posé sur le tapis au nom du joueur, une seule fois par joueur (et seulement si hatched < welcome.maxHatched). Retourne l'œuf ou nil.
function Belt.welcome(Config, st, userId, hatched, now)
	local W = Config.BELT.welcome
	if st.welcomed[userId] or hatched >= W.maxHatched or #st.eggs >= Config.BELT.maxEggs then
		return nil
	end
	st.welcomed[userId] = true
	local egg = { id = st.nextId, tier = 1, born = now, claimedBy = nil, price = 0, forUser = userId }
	st.nextId = st.nextId + 1
	st.eggs[#st.eggs + 1] = egg
	return egg
end

-- Tente l'achat de l'œuf `eggId` par `userId` ; `coins` = pièces du joueur. Retourne (true, œuf) ou (false, raison).
-- Règles : 1 achat par joueur toutes les `buyCooldown` s ; œuf Légendaire+ : prompt actif seulement `legendaryDelay` s après son apparition et 1 par joueur
-- et par minute ; œuf de bienvenue réservé à son destinataire ; réservation atomique (le premier valide l'emporte).
function Belt.tryBuy(Config, st, userId, eggId, coins, now)
	local C = Config.BELT
	local egg
	for _, e in ipairs(st.eggs) do
		if e.id == eggId then
			egg = e
		end
	end
	if not egg or not Belt.positionX(Config, egg, now) then
		return false, "gone"
	end
	if egg.claimedBy then
		return false, "late" -- « Trop tard ! »
	end
	if egg.forUser and egg.forUser ~= userId then
		return false, "reserved"
	end
	if not egg.forUser and now - (st.lastBuy[userId] or -1e9) < C.buyCooldown then
		return false, "cooldown"
	end
	if egg.tier >= 4 then
		if now - egg.born < C.legendaryDelay then
			return false, "wait"
		end
		if now - (st.legendaryAt[userId] or -1e9) < 60 / C.legendaryPerMinute then
			return false, "legendaryLimit"
		end
	end
	if type(coins) ~= "number" or coins ~= coins or coins < egg.price then
		return false, "poor"
	end
	egg.claimedBy = userId -- atomique : la deuxième demande reçoit « late »
	if not egg.forUser then
		st.lastBuy[userId] = now
	end
	if egg.tier >= 4 then
		st.legendaryAt[userId] = now
	end
	st.sold = st.sold + 1
	-- l'œuf quitte le tapis
	local keep = {}
	for _, e in ipairs(st.eggs) do
		if e ~= egg then
			keep[#keep + 1] = e
		end
	end
	st.eggs = keep
	return true, egg
end

return Belt
