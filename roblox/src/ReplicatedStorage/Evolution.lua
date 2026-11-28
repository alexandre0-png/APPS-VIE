-- ModuleScript : ReplicatedStorage/Shared/Evolution
-- IDÉE 2 (coffre IDEES_CHIPE_OEUFS) : évolution d'un pet en « forme 2 ». Logique PURE : aucune API Roblox, aucun yield, aucune erreur levée sur une
-- entrée invalide (valeurs de retour). Testé par tests/evolution.luau (Lune ou lupa). Le serveur (Main) n'appelle que plan / stage / stillValid / apply.
--
-- Règles (Config.EVOLUTION, valeurs uniques) :
--   * coût : `sacrifices` (3) DOUBLONS de la même rareté que le pet visé + `costSeconds` (300 s = 5 min) du revenu ACTUEL du joueur, en pièces.
--     Aucune forme payante : rien ici ne lit un produit, un pass ou des Robux ; le coût en pièces est calculé par le serveur (le client n'envoie que
--     l'emplacement et le prix maximal qu'il accepte, `maxCost`, pour ne jamais payer plus que ce qu'il a vu) ;
--   * doublon : pet dont l'espèce garde au moins UN exemplaire dans la base après l'évolution (le pet visé compte). On ne sacrifie jamais le dernier
--     exemplaire d'une espèce. Choix AUTOMATIQUE par le serveur : les doublons qui rapportent le moins d'abord (puis l'indice le plus bas) ;
--   * forme 2 : même espèce (sl.p inchangé), `sl.f = 2`, revenu x incomeMul (1,15), pv et attaque x powerMul (1,10) en combat (Battle.unit, échelle),
--     silhouette x visualScale et halo (Builder) ;
--   * interdits : pet visé ou sacrifié qui suit le joueur (equip), qui est dans l'équipe de combat (battle.team) ou dont la copie (p, s, m) est dans la
--     défense PvP enregistrée ; taille Géant / Colossal ; mutation Arc-en-ciel et au-delà (Alien, Céleste) ; pet déjà en forme 2 ; combat en cours ;
--   * force : la forme 2 d'une rareté r reste STRICTEMENT sous la forme 1 de la rareté r + 1 (mêmes taille, mutation, niveau) : vérifié par les tests
--     sur les 10 raretés (Battle.STATS) et sur chaque espèce du bestiaire ;
--   * profil : `evo = { ["indice d'espèce"] = nombre d'évolutions }` (compteur par espèce), assaini, jamais remis à zéro (migration v13 -> v14 idempotente).
-- Atomicité (même schéma que le calendrier et les cartes : sauvegarde PUIS octroi) : `stage` construit une COPIE du profil après l'évolution, le
-- serveur la sauvegarde ; seulement si la sauvegarde réussit, `stillValid` puis `apply` modifient le profil vivant. Échec = profil vivant intact.
local Evolution = {}

Evolution.FORM2 = 2

local function num(v, default)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return v
end

local function isInt(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge and v % 1 == 0
end

local function cfgOf(Config)
	return type(Config) == "table" and type(Config.EVOLUTION) == "table" and Config.EVOLUTION or nil
end

-- Forme d'un emplacement : 2 si `f == 2`, sinon 1 (pets plus anciens, œufs, vides).
function Evolution.form(sl)
	if type(sl) == "table" and sl.k == "p" and sl.f == Evolution.FORM2 then
		return 2
	end
	return 1
end

-- Assainit le champ facultatif `f` d'un pet (merge) : 2 ou absent. Idempotent.
function Evolution.sanitizeForm(sl)
	if type(sl) == "table" then
		if sl.k == "p" and sl.f == Evolution.FORM2 then
			sl.f = Evolution.FORM2
		else
			sl.f = nil
		end
	end
	return sl
end

-- Multiplicateur de revenu d'une forme (Config.petIncome) : 1 ou cfg.incomeMul.
function Evolution.incomeMulOf(Config, f)
	local cfg = cfgOf(Config)
	if f == Evolution.FORM2 and cfg then
		return num(cfg.incomeMul, 1)
	end
	return 1
end

-- Échelle de combat d'un pet (3e argument de Battle.unit) : nil pour la forme 1 (aucun changement), cfg.powerMul pour la forme 2.
function Evolution.powerScale(Config, sl)
	local cfg = cfgOf(Config)
	if cfg and Evolution.form(sl) == 2 then
		return num(cfg.powerMul, 1)
	end
	return nil
end

-- Échelle visuelle (Builder) : 1 ou cfg.visualScale.
function Evolution.visualScale(Config, f)
	local cfg = cfgOf(Config)
	if cfg and f == Evolution.FORM2 then
		return num(cfg.visualScale, 1)
	end
	return 1
end

-- Compteur d'évolutions par espèce : clés = tostring(indice d'espèce existante), valeurs entières 1..1e6. Absent ou corrompu = {}.
-- Idempotent : relire un compteur déjà assaini le rend identique.
function Evolution.sanitizeCounts(Config, v)
	local out = {}
	if type(v) ~= "table" or type(Config) ~= "table" or type(Config.PETS) ~= "table" then
		return out
	end
	for k, n in pairs(v) do
		local idx = tonumber(k)
		if idx and isInt(idx) and Config.PETS[idx] ~= nil and type(n) == "number" and n == n and n >= 1 then
			out[tostring(idx)] = math.min(1e6, math.floor(n))
		end
	end
	return out
end

-- Migration v13 -> v14 : pose `evo = {}` si absent ou d'un autre type ; un compteur existant n'est JAMAIS remis à zéro (assaini ensuite par merge).
function Evolution.migrate(saved)
	if type(saved) == "table" and type(saved.evo) ~= "table" then
		saved.evo = {}
	end
	return saved
end

local function blocked(cfg, sl)
	return (cfg.blockedSizes and cfg.blockedSizes[sl.s]) or (cfg.blockedMuts and cfg.blockedMuts[sl.m])
end

local function inList(list, v)
	if type(list) == "table" then
		for _, x in ipairs(list) do
			if x == v then
				return true
			end
		end
	end
	return false
end

-- Raison pour laquelle l'emplacement `i` est protégé (suiveur, équipe, défense PvP), ou nil.
function Evolution.protected(d, i)
	if type(d) ~= "table" or type(d.slots) ~= "table" then
		return "slot"
	end
	if inList(d.equip, i) then
		return "follower"
	end
	local b = type(d.battle) == "table" and d.battle or {}
	if inList(b.team, i) then
		return "team"
	end
	local sl = d.slots[i]
	local pv = type(b.pvp) == "table" and b.pvp or {}
	if type(sl) == "table" and type(pv.defense) == "table" then
		for _, e in ipairs(pv.defense) do
			if type(e) == "table" and e.p == sl.p and e.s == sl.s and e.m == sl.m and e.f ~= Evolution.FORM2 then
				return "defense"
			end
		end
	end
	return nil
end

-- Le pet de l'emplacement `i` peut-il être visé ? Retourne (true) ou (false, code). Ne regarde ni le coût ni les doublons.
function Evolution.targetCheck(Config, d, i, capacity)
	local cfg = cfgOf(Config)
	if not cfg or cfg.enabled ~= true then
		return false, "disabled"
	end
	if type(d) ~= "table" or type(d.slots) ~= "table" or not isInt(i) or i < 1 or i > (capacity or 0) then
		return false, "slot"
	end
	local sl = d.slots[i]
	if type(sl) ~= "table" or sl.k ~= "p" or type(Config.PETS) ~= "table" or Config.PETS[sl.p] == nil then
		return false, "slot"
	end
	if Evolution.form(sl) >= (cfg.maxForm or 2) then
		return false, "already"
	end
	if blocked(cfg, sl) then
		return false, "special"
	end
	local why = Evolution.protected(d, i)
	if why then
		return false, why
	end
	return true
end

-- Doublons sacrifiables pour le pet visé `i` : `cfg.sacrifices` emplacements, ou (nil, nombre trouvé). Ordre : revenu croissant, puis indice.
function Evolution.pickSacrifices(Config, d, i, capacity)
	local cfg = cfgOf(Config)
	local target = d.slots[i]
	local tier = Config.PETS[target.p].tier
	local counts = {}
	for j = 1, capacity do
		local sl = d.slots[j]
		if type(sl) == "table" and sl.k == "p" and Config.PETS[sl.p] then
			counts[sl.p] = (counts[sl.p] or 0) + 1
		end
	end
	local cands = {}
	for j = 1, capacity do
		local sl = d.slots[j]
		if
			j ~= i
			and type(sl) == "table"
			and sl.k == "p"
			and Config.PETS[sl.p]
			and Config.PETS[sl.p].tier == tier
			and Evolution.form(sl) == 1
			and not blocked(cfg, sl)
			and Evolution.protected(d, j) == nil
		then
			cands[#cands + 1] = { j = j, p = sl.p, inc = Config.petIncome(sl.p, sl.s, sl.m) }
		end
	end
	table.sort(cands, function(a, b)
		if a.inc ~= b.inc then
			return a.inc < b.inc
		end
		return a.j < b.j
	end)
	local need = cfg.sacrifices or 3
	local out = {}
	for _, c in ipairs(cands) do
		if #out < need and counts[c.p] > 1 then -- jamais le dernier exemplaire d'une espèce (le pet visé compte comme exemplaire restant)
			out[#out + 1] = c.j
			counts[c.p] = counts[c.p] - 1
		end
	end
	if #out < need then
		return nil, #out
	end
	table.sort(out)
	return out
end

-- Coût en pièces : cfg.costSeconds x revenu actuel par seconde (arrondi au supérieur, >= 0).
function Evolution.cost(Config, incomePerSec)
	local cfg = cfgOf(Config)
	local inc = math.max(0, num(incomePerSec, 0))
	return math.max(0, math.ceil((cfg and cfg.costSeconds or 300) * inc - 1e-9))
end

-- Plan d'évolution complet. ctx (calculé par le SERVEUR) = { capacity, income, coins?, busy?, maxCost? }.
-- Retourne (plan) ou (nil, code, détail). plan = { i, p, tier, sac = { j, ... }, pets = { [j] = table du pet }, target = table du pet, cost }.
-- `pets` et `target` gardent les RÉFÉRENCES des tables du profil : stillValid vérifie que ce sont toujours les mêmes pets.
function Evolution.plan(Config, d, i, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	if ctx.busy then
		return nil, "busy"
	end
	local capacity = isInt(ctx.capacity) and ctx.capacity or 0
	local ok, code = Evolution.targetCheck(Config, d, i, capacity)
	if not ok then
		return nil, code
	end
	local sac, found = Evolution.pickSacrifices(Config, d, i, capacity)
	if not sac then
		return nil, "dupes", found
	end
	local cost = Evolution.cost(Config, ctx.income)
	if ctx.maxCost ~= nil and (type(ctx.maxCost) ~= "number" or ctx.maxCost ~= ctx.maxCost or cost > ctx.maxCost) then
		return nil, "price", cost
	end
	if num(d.coins, 0) < cost then
		return nil, "coins", cost
	end
	local target = d.slots[i]
	local pets = {}
	for _, j in ipairs(sac) do
		pets[j] = d.slots[j]
	end
	return { i = i, p = target.p, tier = Config.PETS[target.p].tier, sac = sac, pets = pets, target = target, cost = cost }
end

-- Aperçu pour le client : { ok, code, sac, cost, need, found } (aucune référence de table du profil).
function Evolution.view(Config, d, i, ctx)
	local plan, code, extra = Evolution.plan(Config, d, i, ctx)
	local cfg = cfgOf(Config)
	if plan then
		return { ok = true, i = i, sac = plan.sac, cost = plan.cost, need = cfg.sacrifices }
	end
	return { ok = false, i = i, code = code, cost = (code == "coins" or code == "price") and extra or nil, found = code == "dupes" and extra or nil, need = cfg and cfg.sacrifices or nil }
end

local function bump(evo, p)
	local k = tostring(p)
	evo[k] = math.min(1e6, (evo[k] or 0) + 1)
end

-- Copie du profil APRÈS l'évolution, à sauvegarder (le profil vivant n'est pas touché) : copie superficielle, avec de nouvelles tables pour
-- slots, evo et le pet visé ; les autres champs sont partagés (lecture seule pendant la sauvegarde).
function Evolution.stage(d, plan)
	local post = table.clone(d)
	local slots = table.clone(d.slots)
	local pet = table.clone(plan.target)
	pet.f = Evolution.FORM2
	slots[plan.i] = pet
	for _, j in ipairs(plan.sac) do
		slots[j] = false
	end
	local evo = table.clone(type(d.evo) == "table" and d.evo or {})
	bump(evo, plan.p)
	post.slots, post.evo = slots, evo
	post.coins = num(d.coins, 0) - plan.cost
	return post
end

-- Le plan s'applique-t-il encore au profil vivant (mêmes tables de pets aux mêmes emplacements, forme 1, pièces suffisantes) ?
function Evolution.stillValid(d, plan)
	if type(d) ~= "table" or type(d.slots) ~= "table" or type(plan) ~= "table" then
		return false
	end
	if d.slots[plan.i] ~= plan.target or Evolution.form(plan.target) ~= 1 then
		return false
	end
	for _, j in ipairs(plan.sac) do
		if d.slots[j] ~= plan.pets[j] then
			return false
		end
	end
	return num(d.coins, 0) >= plan.cost
end

-- Applique le plan au profil vivant (après une sauvegarde réussie de `stage`) : pièces débitées (delta : le revenu gagné pendant la sauvegarde reste),
-- doublons retirés, forme 2, compteur de l'espèce +1. Retourne true, ou false sans rien toucher si le plan ne s'applique plus.
function Evolution.apply(d, plan)
	if not Evolution.stillValid(d, plan) then
		return false
	end
	d.coins = num(d.coins, 0) - plan.cost
	for _, j in ipairs(plan.sac) do
		d.slots[j] = false
	end
	plan.target.f = Evolution.FORM2
	if type(d.evo) ~= "table" then
		d.evo = {}
	end
	bump(d.evo, plan.p)
	return true
end

-- Retire les indices sacrifiés d'une liste d'emplacements (equip) : sécurité, ils ne peuvent pas y être (protégés).
function Evolution.dropIndices(list, sac)
	if type(list) ~= "table" then
		return list
	end
	for n = #list, 1, -1 do
		if inList(sac, list[n]) then
			table.remove(list, n)
		end
	end
	return list
end

-- Messages des refus (client) : codes de plan / targetCheck.
Evolution.REFUSE = {
	disabled = "L'évolution n'est pas encore disponible.",
	slot = "Choisis un pet de ta base.",
	already = "Ce pet est déjà en forme 2.",
	special = "Les pets Géants, Colossaux, Arc-en-ciel, Alien et Célestes n'évoluent pas.",
	follower = "Ce pet te suit : retire-le de tes suiveurs avant de le faire évoluer.",
	team = "Ce pet est dans ton équipe de combat : retire-le de l'équipe avant de le faire évoluer.",
	defense = "Ce pet est dans ta défense PvP : enregistre une autre défense avant de le faire évoluer.",
	busy = "Termine d'abord ton combat.",
	dupes = "Il faut 3 doublons de la même rareté (jamais le dernier exemplaire d'une espèce).",
	coins = "Pas assez de pièces (5 min de revenus).",
	price = "Le prix a changé : regarde le nouveau prix et réessaie.",
	save = "Sauvegarde impossible pour l'instant : réessaie dans un moment (rien n'a été perdu).",
	changed = "Ta base a changé pendant l'évolution : rien n'a été fait.",
}

return Evolution
