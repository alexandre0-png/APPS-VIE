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
Telemetry.QUEUE_MAX = 16
Telemetry.GAP = 1

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
