-- ModuleScript : ServerScriptService/Telemetry
-- LOT 9 : 12 métriques de rythme envoyées à AnalyticsService (Creator Hub > Analytics), SANS donnée personnelle (aucun nom, aucun identifiant
-- en champ : AnalyticsService rattache lui-même l'événement au joueur). Tout appel est sous pcall ; service indisponible (Studio, panne) = rien.
-- Débit : au plus 1 événement par seconde et par joueur (file de 16 par joueur, la plus ancienne jetée au-delà), vidée par Telemetry.step.
-- Pur et testable : le service et l'horloge sont injectés (Telemetry.new(service, clock)).
local Telemetry = {}

-- Les 12 métriques du lot 9 + 4 du lot 9b (calendrier) (nom de l'événement -> description). `tier_first_reached`, `hatch_tier` et `house_level_reached` portent la rareté / le niveau
-- dans le nom (« _r5 », « _l3 ») pour être lisibles directement dans le tableau des événements personnalisés.
Telemetry.METRICS = {
	first_hatch_seconds = "temps de jeu cumulé (s) à la première éclosion",
	tier_first_reached = "première fois qu'une rareté de pet est obtenue (_rN), valeur = temps de jeu cumulé (s)",
	house_level_reached = "niveau de maison atteint (_lN), valeur = temps de jeu cumulé (s)",
	session_length = "durée de la session (s), envoyée au départ",
	retention_day1 = "retour le lendemain de la première connexion (jours UTC firstSeen / lastSeen)",
	retention_day7 = "retour 7 jours après la première connexion",
	daily_quest_completed = "mission du jour terminée (récompense réclamée)",
	purchase_tier = "achat Robux, par palier de prix (_p1 < 50 R$, _p2 < 200, _p3 < 500, _p4 < 1500, _p5 au-delà)",
	coins_spent_egg = "pièces dépensées en œufs (événement économique, puits)",
	hatch_tier = "éclosion par rareté (_rN)",
	puzzle_solved = "énigme du jour réussie",
	tower_floor_reached = "nouvel étage record de la tour, valeur = étage",
	-- Lot 9b : calendrier de 30 jours
	calendar_claim_day = "jour du calendrier réclamé (valeur = jour 1 à 30), suffixe _today pour le jour en cours",
	calendar_catchup = "jour manqué rattrapé (valeur = jour), suffixe _grace / _quest / _paid",
	calendar_cycle_complete = "30 jours réclamés dans un cycle (valeur = numéro du cycle)",
	calendar_streak = "série de jours consécutifs réclamés après une réclamation (valeur = série)",
}
-- LOT 16 (I.2) : les 6 TYPES d'événements AnalyticsService, tous sous la même file (<= 1 événement / s / joueur) :
--   custom (LogCustomEvent, métriques ci-dessus), economy (LogEconomyEvent : pièces gagnées / dépensées, source), funnel (LogFunnelStepEvent : entonnoir d'achat
--   vue boutique -> fiche -> invite -> reçu), onboarding (LogOnboardingFunnelStepEvent : étapes de la première session), progression (LogProgressionCompleteEvent :
--   niveau de maison, étage, palier de saison), version (LogCustomEvent « version_<Config.BUILD> », une fois par session).
Telemetry.KINDS = { custom = true, economy = true, funnel = true, onboarding = true, progression = true, version = true }
Telemetry.FUNNEL = { shop_view = 1, card_open = 2, prompt = 3, receipt = 4 }
Telemetry.ONBOARDING = { join = 1, first_hatch = 2, first_battle_win = 3, first_shop_view = 4 }
Telemetry.PROGRESSION = { house = true, tower = true, season = true }
Telemetry.QUEUE_MAX = 16
Telemetry.GAP = 1
-- LOT 14 : métrique SERVEUR (hors des 16 métriques par joueur) : joueurs connectés simultanément, échantillonnés toutes les 60 s, AU PLUS 1 événement par
-- minute et par serveur. Nom « ccu_sample_<mode> » (mode du serveur : arena | castle | ranked), valeur = nombre de joueurs du serveur. AnalyticsService exige un
-- joueur porteur : l'événement entre dans la file d'UN joueur présent (même file, même débit <= 1 événement / s / joueur que le lot 16). Le serveur n'est pas
-- nommé (pas de JobId dans le nom : cardinalité bornée) ; un échantillon par serveur et par minute suffit à sommer la fréquentation. Sert à décider de
-- l'ouverture du classé en direct (seuil Config.PVP_LIVE.minCCU = 60, jamais mesuré en production).
Telemetry.SERVER_METRICS = { ccu_sample = "joueurs connectés sur ce serveur (_arena / _castle / _ranked), 1 échantillon / 60 s / serveur" }
Telemetry.CCU_EVERY = 60
Telemetry.CCU_MODES = { arena = true, castle = true, ranked = true }

function Telemetry.priceTier(robux)
	local r = type(robux) == "number" and robux == robux and robux or 0
	if r < 50 then
		return 1
	elseif r < 200 then
		return 2
	elseif r < 500 then
		return 3
	elseif r < 1500 then
		return 4
	end
	return 5
end

-- Retour du joueur : 1 (lendemain) ou 7 (une semaine) jours UTC après la première connexion, sinon nil. Valeurs incertaines : gardées par type.
function Telemetry.retentionDay(firstSeen, today)
	if type(firstSeen) ~= "number" or type(today) ~= "number" or firstSeen ~= firstSeen or today ~= today or firstSeen <= 0 then
		return nil
	end
	local d = math.floor(today) - math.floor(firstSeen)
	if d == 1 or d == 7 then
		return d
	end
	return nil
end

function Telemetry.new(service, clock)
	local T = { queues = {}, last = {}, sent = 0, dropped = 0, failed = 0, priceTier = Telemetry.priceTier, retentionDay = Telemetry.retentionDay }
	clock = clock or os.clock
	local function send(player, e)
		if not service then
			return
		end
		local ok = pcall(function()
			if e.kind == "economy" then
				service:LogEconomyEvent(player, e.flow, "Coins", e.value, e.balance or 0, e.tx or "Shop", e.sku)
			elseif e.kind == "funnel" then
				service:LogFunnelStepEvent(player, "Shop", e.session, e.step, e.name)
			elseif e.kind == "onboarding" then
				service:LogOnboardingFunnelStepEvent(player, e.step, e.name)
			elseif e.kind == "progression" then
				service:LogProgressionCompleteEvent(player, e.path, e.value, e.name)
			else
				service:LogCustomEvent(player, e.name, e.value)
			end
		end)
		if ok then
			T.sent = T.sent + 1
		else
			T.failed = T.failed + 1
		end
	end
	-- Met un événement en file (nom parmi Telemetry.METRICS, suffixe facultatif « _r5 »...). Nom inconnu : ignoré (évite les fautes de frappe).
	function T.log(player, name, value, suffix)
		if player == nil or Telemetry.METRICS[name] == nil then
			return false
		end
		local q = T.queues[player]
		if not q then
			q = {}
			T.queues[player] = q
		end
		if #q >= Telemetry.QUEUE_MAX then
			table.remove(q, 1)
			T.dropped = T.dropped + 1
		end
		local v = type(value) == "number" and value == value and value or nil
		q[#q + 1] = { name = name .. (suffix or ""), value = v }
		return true
	end
	-- Lot 14 : échantillon de fréquentation. players = liste des joueurs du serveur (le premier présent porte l'événement), mode = mode du serveur.
	-- Retourne true si un échantillon a été mis en file (au plus une fois par CCU_EVERY secondes ; aucun joueur = rien, aucune table créée).
	T.ccuAt = nil
	function T.ccu(players, mode)
		local now = clock()
		if T.ccuAt ~= nil and now - T.ccuAt < Telemetry.CCU_EVERY then
			return false
		end
		if type(players) ~= "table" or players[1] == nil then
			return false
		end
		T.ccuAt = now
		local q = T.queues[players[1]] or {}
		T.queues[players[1]] = q
		if #q >= Telemetry.QUEUE_MAX then
			table.remove(q, 1)
			T.dropped = T.dropped + 1
		end
		q[#q + 1] = { kind = "custom", name = "ccu_sample_" .. (Telemetry.CCU_MODES[mode] and mode or "arena"), value = #players }
		T.ccuSent = (T.ccuSent or 0) + 1
		return true
	end
	function T.economy(player, amount, balance, sku)
		if player == nil or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
			return false
		end
		local q = T.queues[player] or {}
		T.queues[player] = q
		if #q >= Telemetry.QUEUE_MAX then
			table.remove(q, 1)
			T.dropped = T.dropped + 1
		end
		q[#q + 1] = { kind = "economy", name = "coins_spent_egg", flow = "Sink", value = math.floor(amount), balance = type(balance) == "number" and math.floor(balance) or 0, sku = sku }
		return true
	end
	local function push(player, e)
		local q = T.queues[player] or {}
		T.queues[player] = q
		if #q >= Telemetry.QUEUE_MAX then
			table.remove(q, 1)
			T.dropped = T.dropped + 1
		end
		q[#q + 1] = e
		return true
	end
	-- Lot 16 : point d'entrée unique des 6 types (kind, puis arguments propres au type). Type ou nom inconnu : ignoré (false).
	--   custom : (name, value, suffix) ; economy : (flow "Source"|"Sink", amount, balance, tx, sku) ; funnel : (step name, session) ; onboarding : (step name) ;
	--   progression : (path, level) ; version : (build).
	function T.event(player, kind, a, b, c, d, e)
		if player == nil or not Telemetry.KINDS[kind] then
			return false
		end
		if kind == "custom" then
			return T.log(player, a, b, c)
		elseif kind == "economy" then
			if (a ~= "Source" and a ~= "Sink") or type(b) ~= "number" or b ~= b or b <= 0 then
				return false
			end
			return push(player, { kind = "economy", flow = a, value = math.floor(b), balance = type(c) == "number" and c == c and math.floor(c) or 0, tx = type(d) == "string" and d or "Gameplay", sku = type(e) == "string" and e or nil })
		elseif kind == "funnel" then
			local step = Telemetry.FUNNEL[a]
			if not step then
				return false
			end
			return push(player, { kind = "funnel", step = step, name = a, session = type(b) == "string" and b or nil })
		elseif kind == "onboarding" then
			local step = Telemetry.ONBOARDING[a]
			if not step then
				return false
			end
			return push(player, { kind = "onboarding", step = step, name = a })
		elseif kind == "progression" then
			if not Telemetry.PROGRESSION[a] or type(b) ~= "number" or b ~= b then
				return false
			end
			return push(player, { kind = "progression", path = a, value = math.floor(b), name = a .. "_" .. math.floor(b) })
		end
		-- version : étiquette de la version publiée (Config.BUILD), lettres, chiffres, points et tirets seulement
		if type(a) ~= "string" or #a == 0 or #a > 24 or a:find("[^%w%.%-]") then
			return false
		end
		return push(player, { kind = "custom", name = "version_" .. a, value = 1 })
	end
	-- Envoie au plus un événement par joueur et par seconde.
	function T.step()
		local now = clock()
		for player, q in pairs(T.queues) do
			if #q > 0 and now - (T.last[player] or -1e9) >= Telemetry.GAP then
				T.last[player] = now
				send(player, table.remove(q, 1))
			end
		end
	end
	-- Joueur parti : seul le DERNIER événement en file (la durée de session, mise en file juste avant) est envoyé, le reste est compté perdu
	-- (le débit de 1 événement / s est respecté), puis la file est oubliée.
	function T.flush(player)
		local q = T.queues[player]
		T.queues[player] = nil
		T.last[player] = nil
		if q and #q > 0 then
			T.dropped = T.dropped + #q - 1
			send(player, q[#q])
		end
	end
	return T
end

return Telemetry
