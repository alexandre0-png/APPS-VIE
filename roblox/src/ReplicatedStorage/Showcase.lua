-- ModuleScript : ReplicatedStorage/Showcase (idée 3 « Vitrine pet du jour »). Logique PURE, sans service Roblox : le DataStore est injecté.
-- Chaque jour UTC, une espèce de rareté >= minTier (publiée dans Config.PETS) est mise en vitrine, de façon déterministe (même jour = même espèce partout).
-- Le premier joueur qui fait ÉCLORE cette espèce ce jour-là la « possède » : enregistrement DEDIE par jour (UpdateAsync, premier écrit gagne), puis +5 % de
-- revenus pendant 24 h. Garde-fous : un seul bonus actif (jamais cumulé ni prolongé), une vitrine par jour, une par semaine et par joueur, bonus perdu si le
-- propriétaire ne se connecte pas le jour même. Gratuit : aucune monnaie payante, aucun achat. Le nom affiché est assaini ; l'identifiant (userId) reste côté serveur (publicView).
-- Champ de profil : showcase = { last = jour UTC de la dernière vitrine possédée (0 = jamais), ends = fin du bonus en os.time() (0 = aucun) }.
-- Décision utilisateur (2026-11-28) : un œuf ACHETÉ ne peut jamais faire gagner la vitrine. Chaque œuf porte une origine figée à l'octroi (slot.og, voir
-- Showcase.ORIGINS) ; seules les origines listées dans cfg.origins comptent. Origine absente (ancien slot, sac d'œufs, coffre de débordement, boutique payante,
-- offres, packs) = inconnue = exclue. tryClaim refuse toute éclosion dont l'origine n'est pas admise (« notEarned ») AVANT tout appel DataStore.
local Showcase = {}

Showcase.DEFAULTS = {
	minTier = 6, -- rareté minimale d'une espèce de vitrine (Épique)
	bonusPct = 0.05, -- +5 % de revenus
	bonusSeconds = 86400, -- 24 h
	cooldownDays = 7, -- un joueur ne peut être en vitrine qu'une fois par semaine
	nameMax = 20, -- caractères du nom affiché
	retries = 3, -- tentatives DataStore (avec attente croissante)
	storeName = "ChipeOeufs_Showcase_v1",
	fallbackName = "Un dresseur",
	origins = { g = true, c = true }, -- origines admises : g = gagné en jouant (tapis, nids, calendrier, PNJ, quêtes, château, combats), c = boutique en pièces
}

-- Origines d'un œuf (champ slot.og, posé par le serveur au moment de l'octroi, jamais par le client). Absent = inconnu (exclu).
Showcase.ORIGINS = { g = "gagné en jouant", c = "acheté en pièces", r = "payé (argent réel : produit, passe ou rattrapage payant)" }

function Showcase.validOrigin(og)
	return type(og) == "string" and Showcase.ORIGINS[og] ~= nil
end

local function finite(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function num(v, default)
	if finite(v) and v >= 0 then
		return math.floor(v)
	end
	return default
end

function Showcase.new(Config)
	local cfg = {}
	for k, v in pairs(Showcase.DEFAULTS) do
		cfg[k] = v
	end
	if type(Config) == "table" and type(Config.SHOWCASE) == "table" then
		for k, v in pairs(Config.SHOWCASE) do
			cfg[k] = v
		end
	end
	local M = { cfg = cfg, cache = { day = -1, owner = nil, view = nil }, busy = {} }

	-- L'origine d'un œuf permet-elle de gagner la vitrine ? (jamais un œuf payé ni d'origine inconnue)
	function M.originOk(og)
		return og ~= "r" and Showcase.validOrigin(og) and type(cfg.origins) == "table" and cfg.origins[og] == true
	end

	function M.dayOf(t)
		return math.floor(t / 86400)
	end

	-- Espèces éligibles : index dans Config.PETS, rareté >= minTier, ordre croissant (stable).
	-- Intégration (audit A5) : les espèces d'événement / de saison (champ event) sont exclues : hors de leur fenêtre elles ne sortent d'aucun œuf,
	-- la vitrine serait alors impossible à gagner (et le choix du jour ne dépend pas de la date d'un événement : même résultat partout).
	function M.eligible()
		local list = {}
		local pets = type(Config) == "table" and Config.PETS or {}
		for i, p in ipairs(pets) do
			if type(p) == "table" and finite(p.tier) and p.tier >= cfg.minTier and p.event == nil then
				list[#list + 1] = i
			end
		end
		return list
	end

	-- Générateur de Park-Miller sur un entier (produits < 2^53 : même résultat sous Luau et Lua 5.x).
	local function rawIndex(day, n)
		local x = (math.floor(day) % 2147483646) + 1
		for _ = 1, 3 do
			x = (x * 48271) % 2147483647
		end
		return x % n + 1
	end

	-- Espèce du jour (index dans Config.PETS) ou nil s'il n'y en a aucune. Jamais deux jours de suite la même (si >= 2 espèces).
	function M.pick(day)
		local list = M.eligible()
		local n = #list
		if n == 0 or not finite(day) then
			return nil
		end
		local idx = rawIndex(day, n)
		if n > 1 and idx == rawIndex(day - 1, n) then
			idx = idx % n + 1
		end
		return list[idx]
	end

	-- L'espèce p est-elle en vitrine à l'instant now ?
	function M.featured(p, now)
		if not finite(now) then
			return false
		end
		local sp = M.pick(M.dayOf(now))
		return sp ~= nil and p == sp
	end

	-- Nom affichable : caractères de contrôle retirés, espaces réduits, tronqué proprement (UTF-8), sinon nom de secours.
	function M.sanitizeName(name)
		if type(name) ~= "string" then
			return cfg.fallbackName
		end
		local s = string.gsub(name, "[%c]", "")
		s = string.gsub(s, "%s+", " ")
		s = string.match(s, "^%s*(.-)%s*$") or ""
		if not utf8.len(s) then
			s = string.gsub(s, "[\128-\255]", "")
		end
		local len = utf8.len(s)
		if len and len > cfg.nameMax then
			s = string.sub(s, 1, (utf8.offset(s, cfg.nameMax + 1) or (#s + 1)) - 1)
		end
		if s == "" then
			return cfg.fallbackName
		end
		return s
	end

	-- Assainit le champ de profil (idempotent : relire un profil assaini ne change rien). Valeurs neuves si absent ou corrompu ; jamais de réinitialisation d'un champ valide.
	function M.sanitize(saved, now)
		local sc = type(saved) == "table" and saved or {}
		local today = M.dayOf(now)
		return {
			last = math.min(num(sc.last, 0), today),
			ends = math.min(num(sc.ends, 0), math.floor(now) + cfg.bonusSeconds), -- une fin trop lointaine (horloge ou donnée altérée) est ramenée à 24 h
		}
	end

	function M.multiplier(sc, now)
		if type(sc) == "table" and finite(sc.ends) and now < sc.ends and sc.ends - now <= cfg.bonusSeconds then
			return 1 + cfg.bonusPct
		end
		return 1
	end

	-- Le joueur peut-il posséder la vitrine de ce jour ? (ok, raison) ; raisons : active, sameDay, cooldown.
	function M.canOwn(sc, day, now)
		if type(sc) ~= "table" then
			return false, "invalid"
		end
		if finite(sc.ends) and now < sc.ends then
			return false, "active"
		end
		local last = num(sc.last, 0)
		if last == day then
			return false, "sameDay"
		end
		if last > 0 and day - last < cfg.cooldownDays then
			return false, "cooldown"
		end
		return true, nil
	end

	-- Accorde le bonus (24 h à partir de maintenant, jamais prolongé ni cumulé). Retourne true si accordé.
	function M.grant(sc, day, now)
		if not M.canOwn(sc, day, now) then
			return false
		end
		sc.last = day
		sc.ends = math.floor(now) + cfg.bonusSeconds
		return true
	end

	function M.key(day)
		return "Showcase_" .. tostring(math.floor(day))
	end

	-- Fonction de transformation de UpdateAsync : premier écrit gagne. nil = annuler (une vitrine valide existe déjà pour ce jour).
	function M.claimTransform(rec, day, sp, userId, name)
		if type(rec) == "table" and rec.d == day and finite(rec.u) and finite(rec.sp) then
			return nil
		end
		return { v = 1, d = day, sp = sp, u = userId, n = M.sanitizeName(name) }
	end

	-- Vue publique pour l'affichage du hub : espèce et nom SEULEMENT (jamais d'identifiant).
	function M.publicView(rec, day)
		local sp = M.pick(day)
		local view = { day = day, species = sp, claimed = false, name = nil }
		if type(rec) == "table" and rec.d == day and rec.sp == sp and type(rec.n) == "string" then
			view.claimed = true
			view.name = M.sanitizeName(rec.n)
		end
		return view
	end

	local function retry(fn, pause)
		local lastErr = nil
		for attempt = 1, cfg.retries do
			local ok, res = pcall(fn)
			if ok then
				return true, res
			end
			lastErr = res
			if attempt < cfg.retries and pause then
				pause(attempt * 2)
			end
		end
		return false, lastErr
	end

	-- Réclamation à l'éclosion de l'espèce p. store = DataStore (UpdateAsync/GetAsync). player = { userId, name, og } (og = origine figée de l'œuf éclos).
	-- Retourne : "notEarned" (œuf acheté ou d'origine inconnue : aucun appel DataStore) | "notFeatured" | "blocked:<raison>" | "taken" | "busy" | "error" | "won" (le bonus est alors déjà accordé dans sc).
	function M.tryClaim(store, sc, p, player, now, pause)
		if type(player) ~= "table" or not M.originOk(player.og) then
			return "notEarned"
		end
		local day = M.dayOf(now)
		local sp = M.pick(day)
		if sp == nil or p ~= sp then
			return "notFeatured"
		end
		local ok, why = M.canOwn(sc, day, now)
		if not ok then
			return "blocked:" .. tostring(why)
		end
		if M.cache.day == day and M.cache.owner ~= nil and M.cache.owner ~= player.userId then
			return "taken" -- déjà connu sur ce serveur : aucun appel DataStore de plus
		end
		if M.busy[player.userId] then
			return "busy"
		end
		M.busy[player.userId] = true
		local done, res = retry(function()
			return store:UpdateAsync(M.key(day), function(rec)
				return M.claimTransform(rec, day, sp, player.userId, player.name)
			end)
		end, pause)
		M.busy[player.userId] = nil
		if not done then
			return "error" -- aucun bonus sans confirmation du DataStore
		end
		-- UpdateAsync renvoie la valeur finale ; si la transformation a annulé, on relit l'enregistrement gagnant.
		local rec = res
		if rec == nil then
			local got, cur = retry(function()
				return store:GetAsync(M.key(day))
			end, pause)
			rec = got and cur or nil
		end
		if type(rec) ~= "table" or rec.d ~= day then
			return "error"
		end
		M.cache = { day = day, owner = rec.u, view = M.publicView(rec, day) }
		if rec.u ~= player.userId then
			return "taken"
		end
		if not M.grant(sc, day, now) then
			return "blocked:race" -- le profil a changé pendant l'appel (autre bonus accordé entre-temps) : rien n'est accordé
		end
		return "won"
	end

	-- À la connexion : si ce joueur a gagné la vitrine du jour sans que son profil l'ait enregistrée (arrêt serveur), le bonus est accordé UNE fois, ce jour-là seulement.
	function M.onLogin(store, sc, player, now, pause)
		local day = M.dayOf(now)
		local done, rec = retry(function()
			return store:GetAsync(M.key(day))
		end, pause)
		if not done then
			return "error"
		end
		if type(rec) ~= "table" or rec.d ~= day then
			return "none"
		end
		M.cache = { day = day, owner = rec.u, view = M.publicView(rec, day) }
		if rec.u ~= player.userId then
			return "none"
		end
		if M.grant(sc, day, now) then
			return "granted"
		end
		return "none"
	end

	return M
end

return Showcase
