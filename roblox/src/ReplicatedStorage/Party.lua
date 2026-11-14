-- ModuleScript : ReplicatedStorage/Shared/Party
-- Logique PURE du hub : file d'attente des zones de lancement (1 à 5 joueurs), création de partie, registre des parties ouvertes
-- (visibles des amis), rejoindre en cours de partie, repli de téléportation. Toutes les dépendances Roblox sont injectées pour pouvoir
-- tester avec un faux TeleportService (tests/run.luau). Aucune erreur ne sort de ce module : les échecs sont des valeurs de retour.
--   deps.clock() -> secondes
--   deps.reserve(placeId) -> accessCode            (réel : TeleportService:ReserveServer ; peut lever une erreur)
--   deps.teleport(players, placeId, accessCode|nil, data)   (réel : TeleportToPrivateServer / TeleportAsync ; peut lever une erreur)
--   deps.store : { get(key), update(key, fn) , remove(key), list() }   (réel : MemoryStoreService ; peut lever une erreur)
--   deps.log(msg) (facultatif)
local Party = {}

-- Un serveur de jeu accepte-t-il un joueur de plus ? count = joueurs déjà présents.
function Party.admit(count, max)
	return count < max
end

-- Admission d'un joueur dans un serveur de JEU. serverPartyId = identifiant de partie du serveur (celui du premier arrivé, nil si aucun),
-- data = TeleportData reçu à l'arrivée (nil si arrivée directe), count = joueurs déjà présents, role = Config.Game.roleFor(PlaceId).
-- Liste blanche : sur un serveur de partie, seul un joueur envoyé par le hub avec LE MÊME partyId entre. Retourne (true) ou (false, raison).
function Party.admitJoin(serverPartyId, data, count, max, role)
	if not Party.admit(count, max) then
		return false, "full"
	end
	if role ~= "game" then
		return true -- Studio / place non publiée : pas de liste blanche
	end
	local pid = type(data) == "table" and data.partyId or nil
	if serverPartyId ~= nil then
		if pid ~= serverPartyId or data.from ~= "hub" then
			return false, "not_member"
		end
	elseif pid ~= nil and data.from ~= "hub" then
		return false, "not_member"
	end
	return true
end

function Party.new(Config, deps)
	local G = Config.Game
	local P = { queues = {}, where = {} } -- queues[taille] = { members = {userId...}, firstAt, readyAt }

	local function log(msg)
		if deps.log then
			deps.log("[Party] " .. msg)
		end
	end

	for _, size in ipairs(G.Sizes) do
		P.queues[size] = { members = {} }
	end

	---------------------------------------------------------------- zones de lancement (file d'attente)
	function P.enter(userId, size)
		local q = P.queues[size]
		if not q then
			return false, "taille inconnue"
		end
		if P.where[userId] then
			if P.where[userId] == size then
				return true
			end
			P.leave(userId)
		end
		if #q.members >= size then
			return false, "zone pleine"
		end
		q.members[#q.members + 1] = userId
		P.where[userId] = size
		if #q.members == 1 then
			q.firstAt = deps.clock()
		end
		q.readyAt = nil
		return true
	end

	function P.leave(userId)
		local size = P.where[userId]
		if not size then
			return false
		end
		local q = P.queues[size]
		for i, id in ipairs(q.members) do
			if id == userId then
				table.remove(q.members, i)
				break
			end
		end
		P.where[userId] = nil
		q.readyAt = nil
		if #q.members == 0 then
			q.firstAt = nil
		end
		return true
	end

	-- État affiché d'une zone : { size, count, countdown (secondes ou nil), mode = "empty" | "waiting" | "full" }
	function P.status(size)
		local q = P.queues[size]
		local now = deps.clock()
		local count = #q.members
		local out = { size = size, count = count, mode = count == 0 and "empty" or (count >= size and "full" or "waiting") }
		if count > 0 then
			if count >= size then
				q.readyAt = q.readyAt or (now + (size == 1 and G.SoloCountdown or G.CountdownFull))
				out.countdown = math.max(0, q.readyAt - now)
			else
				q.readyAt = nil
				out.countdown = math.max(0, q.firstAt + G.PartialWait - now)
			end
		end
		return out
	end

	-- Groupes prêts à partir : { size, members }. Les membres sont retirés de la file.
	function P.collectLaunches()
		local out = {}
		for _, size in ipairs(G.Sizes) do
			local q = P.queues[size]
			if #q.members > 0 then
				local st = P.status(size)
				if st.countdown ~= nil and st.countdown <= 0 then
					local members = table.clone(q.members)
					for _, id in ipairs(members) do
						P.where[id] = nil
					end
					q.members = {}
					q.firstAt, q.readyAt = nil, nil
					out[#out + 1] = { size = size, members = members }
				end
			end
		end
		return out
	end

	---------------------------------------------------------------- registre des parties
	-- Identifiant imprévisible (GUID injecté : HttpService:GenerateGUID). Jamais dérivé de l'hôte ni de l'heure.
	local function newPartyId()
		if deps.guid then
			return deps.guid()
		end
		local t = {}
		for i = 1, 4 do
			t[i] = string.format("%08x", math.random(0, 0x7fffffff))
		end
		return table.concat(t, "-")
	end

	local function alive(e)
		return type(e) == "table" and deps.clock() - (e.createdAt or 0) < G.PartyTTL
	end

	-- Teleporte un groupe vers le lieu de jeu. Essaie les méthodes de G.Fallbacks dans l'ordre.
	-- group = { size = n, members = {userId...}, players = {Player...}, hostName = "..." }
	-- Retourne { ok = true, mode, partyId? } ou { ok = false, reason, message }.
	function P.launch(group)
		local gamePlace = G.Places.game
		if type(gamePlace) ~= "number" or gamePlace <= 0 then
			return { ok = false, reason = "lieu de jeu non configuré", message = "Le lieu de jeu n'est pas configuré. Préviens le créateur." }
		end
		local size = math.min(math.max(group.size or #group.members, 1), G.MaxPlayers)
		local data = { from = "hub", size = size, late = false }
		local lastErr = "aucune méthode de téléportation"
		for _, mode in ipairs(G.Fallbacks) do
			if mode == "reserved" then
				local okR, code = pcall(deps.reserve, gamePlace)
				if okR and code then
					local partyId = newPartyId()
					data.partyId = partyId
					local okT, errT = pcall(deps.teleport, group.players, gamePlace, code, data)
					if okT then
						local entry = {
							id = partyId, host = group.members[1], hostName = group.hostName or "?", size = size, count = #group.members,
							members = table.clone(group.members), code = code, createdAt = deps.clock(), open = size > 1,
						}
						local okS, errS = pcall(deps.store.update, partyId, function()
							return entry
						end)
						if not okS then
							log("registre indisponible : " .. tostring(errS))
						end
						return { ok = true, mode = "reserved", partyId = partyId, registered = okS }
					end
					lastErr = "téléportation : " .. tostring(errT)
				else
					lastErr = "réservation : " .. tostring(code)
				end
			elseif mode == "public" then
				data.partyId = nil
				local okT, errT = pcall(deps.teleport, group.players, gamePlace, nil, data)
				if okT then
					return { ok = true, mode = "public" }
				end
				lastErr = "téléportation publique : " .. tostring(errT)
			end
		end
		log("lancement impossible : " .. tostring(lastErr))
		return { ok = false, reason = lastErr, message = "Impossible de lancer la partie pour l'instant. Réessaie dans un instant." }
	end

	-- Parties ouvertes visibles par `viewerId` : celles de ses amis (friends[userId] = true) ou celles où il est déjà inscrit.
	-- Retourne une liste triée { id, hostName, count, size }.
	function P.visibleFor(viewerId, friends)
		local okL, list = pcall(deps.store.list)
		if not okL or type(list) ~= "table" then
			return {}, false
		end
		local out = {}
		for _, e in ipairs(list) do
			if alive(e) and e.open and e.count < e.size and e.count < G.MaxPlayers then
				local mine = false
				for _, id in ipairs(e.members or {}) do
					if id == viewerId then
						mine = true
					end
				end
				if not mine and friends and friends[e.host] then
					out[#out + 1] = { id = e.id, hostName = e.hostName, count = e.count, size = e.size }
				end
			end
		end
		table.sort(out, function(a, b)
			return a.id < b.id
		end)
		return out, true
	end

	-- Rejoindre une partie en cours. Retourne { ok = true } ou { ok = false, reason = "full" | "gone" | "registry" | "teleport", message }.
	-- friends = ensemble d'amis du joueur calculé par le SERVEUR (jamais fourni par le client) : seuls les amis de l'hôte (ou un joueur déjà
	-- inscrit) peuvent rejoindre, même s'ils connaissent l'identifiant de la partie.
	function P.join(partyId, player, userId, friends)
		if type(partyId) ~= "string" then
			return { ok = false, reason = "gone", message = "Cette partie n'existe plus." }
		end
		local okG, e = pcall(deps.store.get, partyId)
		if not okG then
			return { ok = false, reason = "registry", message = "Liste des parties indisponible." }
		end
		if not alive(e) or not e.open then
			return { ok = false, reason = "gone", message = "Cette partie n'existe plus." }
		end
		local isMember = false
		for _, id in ipairs(e.members or {}) do
			if id == userId then
				isMember = true
			end
		end
		if not isMember and not (type(friends) == "table" and friends[e.host]) then
			log("refus : " .. tostring(userId) .. " n'est pas ami de l'hôte")
			return { ok = false, reason = "gone", message = "Cette partie n'existe plus." } -- même message : ne révèle pas son existence
		end
		-- réservation atomique de la place (compte + membre) ; refus si plein
		local reserved = false
		local okU, errU = pcall(deps.store.update, partyId, function(old)
			if type(old) ~= "table" or old.count >= old.size or old.count >= G.MaxPlayers then
				return nil
			end
			for _, id in ipairs(old.members) do
				if id == userId then
					return nil
				end
			end
			old.count = old.count + 1
			old.members[#old.members + 1] = userId
			reserved = true
			return old
		end)
		if not okU then
			return { ok = false, reason = "registry", message = "Liste des parties indisponible." }
		end
		if not reserved then
			return { ok = false, reason = "full", message = "Cette partie est pleine." }
		end
		local okT, errT = pcall(deps.teleport, { player }, G.Places.game, e.code, { from = "hub", partyId = partyId, size = e.size, late = true })
		if not okT then
			P.leaveParty(partyId, userId) -- annule la place prise
			log("rejoindre : " .. tostring(errT))
			return { ok = false, reason = "teleport", message = "Impossible de rejoindre la partie pour l'instant." }
		end
		return { ok = true }
	end

	-- Libère la place d'un joueur (retour au hub, échec de téléportation). Supprime la partie quand elle est vide.
	function P.leaveParty(partyId, userId)
		pcall(deps.store.update, partyId, function(old)
			if type(old) ~= "table" then
				return nil
			end
			for i, id in ipairs(old.members) do
				if id == userId then
					table.remove(old.members, i)
					old.count = math.max(0, old.count - 1)
					break
				end
			end
			return old
		end)
	end

	return P
end

return Party
