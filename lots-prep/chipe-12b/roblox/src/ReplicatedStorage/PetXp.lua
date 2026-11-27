-- ModuleScript : ReplicatedStorage/Shared/PetXp   (LOT 12 partie B, D.6)
-- Expérience et niveaux des pets : module PUR (aucun service Roblox, aucun require). L'XP est stockée sur l'emplacement du pet : `slot.x` = XP CUMULÉE (entier, champ déjà
-- créé à 0 par la migration v11 et assaini par Data.merge). Niveau 1 à 20 ; chaque niveau donne +1,5 % de pv et d'attaque (Battle.unit : stat x PetXp.statMul(niveau)).
-- RÈGLE FERME : l'XP de pet ne s'obtient QU'EN JOUANT (combat PvE/PvP/PNJ, carte Expérience D.5). Aucun produit, aucun pass, aucun reçu ne donne d'XP de pet
-- (PetXp.award refuse toute source hors liste blanche). L'effet « XP x2 » (série jour 5 = data.xp2Until, carte Effet = data.boosts.xp2) ne se gagne qu'en jouant.
-- Style : pas de `+=`, pas de `continue`, valeurs douteuses gardées par type avant toute comparaison.
local PetXp = {}

PetXp.MAX_LEVEL = 20
PetXp.PER_LEVEL = 0.015 -- +1,5 % pv / attaque par niveau au-dessus de 1
PetXp.MAX_AWARD = 100000 -- plafond d'un gain unique (anti-valeurs absurdes)
PetXp.TRAINER_MAX_LEVEL = 100
PetXp.TRAINER_MAX_XP = 1e9

local function isnum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- XP à gagner pour passer du niveau L au niveau L+1 (D.6) : floor(40 x L^1,6). nil au niveau max ou pour un niveau invalide.
function PetXp.xpTo(L)
	if not isnum(L) or L < 1 or L >= PetXp.MAX_LEVEL then
		return nil
	end
	L = math.floor(L)
	return math.floor(40 * L ^ 1.6)
end

-- Seuils cumulés : CUM[L] = XP totale nécessaire pour ATTEINDRE le niveau L (CUM[1] = 0).
local CUM = { 0 }
for L = 1, PetXp.MAX_LEVEL - 1 do
	CUM[L + 1] = CUM[L] + PetXp.xpTo(L)
end
PetXp.CUM = CUM
PetXp.MAX_XP = CUM[PetXp.MAX_LEVEL] -- XP cumulée au niveau max : l'XP stockée ne dépasse jamais cette valeur

-- XP stockée saine (entier 0..MAX_XP). Idempotent.
function PetXp.sanitize(x)
	if not isnum(x) or x < 0 then
		return 0
	end
	x = math.floor(x)
	if x > PetXp.MAX_XP then
		return PetXp.MAX_XP
	end
	return x
end

-- (niveau, XP dans le niveau, XP requise pour le suivant | nil au max).
function PetXp.levelOf(x)
	x = PetXp.sanitize(x)
	local lv = 1
	while lv < PetXp.MAX_LEVEL and x >= CUM[lv + 1] do
		lv = lv + 1
	end
	if lv >= PetXp.MAX_LEVEL then
		return lv, 0, nil
	end
	return lv, x - CUM[lv], PetXp.xpTo(lv)
end

function PetXp.level(x)
	local lv = PetXp.levelOf(x)
	return lv
end

-- Multiplicateur de pv / attaque d'un niveau : 1 + 0,015 x (niveau - 1). Niveau invalide -> 1 ; plafonné au niveau max.
function PetXp.statMul(level)
	if not isnum(level) then
		return 1
	end
	level = math.min(PetXp.MAX_LEVEL, math.max(1, math.floor(level)))
	return 1 + PetXp.PER_LEVEL * (level - 1)
end

-- Ajoute `amount` (entier >= 0, plafonné) à l'XP cumulée `x`. Retourne (nouvelle XP, gain réel, niveau avant, niveau après).
function PetXp.add(x, amount)
	x = PetXp.sanitize(x)
	local before = PetXp.level(x)
	local a = 0
	if isnum(amount) and amount > 0 then
		a = math.min(PetXp.MAX_AWARD, math.floor(amount))
	end
	local nx = math.min(PetXp.MAX_XP, x + a)
	return nx, nx - x, before, PetXp.level(nx)
end

-- Vue pour l'interface : { level, into, need, frac, max }.
function PetXp.view(x)
	local lv, into, need = PetXp.levelOf(x)
	return { level = lv, into = into, need = need, frac = need and (into / need) or 1, max = lv >= PetXp.MAX_LEVEL }
end

---------------------------------------------------------------- Sources d'XP (D.6)
-- Liste blanche : on ne gagne de l'XP de pet qu'en jouant. Toute autre source (produit, pass, reçu, cadeau, don) vaut 0.
PetXp.SOURCES = { pve = true, pvp = true, npc = true, card = true }
PetXp.NPC_MUL = 0.6 -- D.5 : combats de PNJ, valeurs x0,6

function PetXp.sourceAllowed(source)
	return type(source) == "string" and PetXp.SOURCES[source] == true
end

-- XP de base par pet pour un combat terminé (D.6) : PvE gagné = 20 + 5 x étage, perdu = 5 ; PvP gagné 15, perdu 5 ; PNJ = formule PvE (étage 0) x 0,6.
function PetXp.combat(kind, win, floor)
	if kind == "pvp" then
		return win and 15 or 5
	end
	if kind == "npc" then
		return win and math.floor(20 * PetXp.NPC_MUL) or math.floor(5 * PetXp.NPC_MUL)
	end
	if kind ~= "pve" then
		return 0
	end
	if not win then
		return 5
	end
	local f = isnum(floor) and math.min(45, math.max(0, math.floor(floor))) or 0
	return 20 + 5 * f
end

-- Multiplicateur d'XP de COMBAT : x2 si l'effet « XP x2 » est actif (série : data.xp2Until ; carte Effet : data.boosts.xp2). Jamais vendu. Les cartes Expérience ne sont pas multipliées.
function PetXp.boostMul(data, now)
	if type(data) ~= "table" or not isnum(now) then
		return 1
	end
	if isnum(data.xp2Until) and data.xp2Until > now then
		return 2
	end
	if type(data.boosts) == "table" and isnum(data.boosts.xp2) and data.boosts.xp2 > now then
		return 2
	end
	return 1
end

-- Montant final d'un gain d'XP pour une source donnée : 0 pour toute source non autorisée (produit, Robux...). `mul` (>= 0) ne s'applique qu'aux combats.
function PetXp.award(source, base, mul)
	if not PetXp.sourceAllowed(source) or not isnum(base) or base <= 0 then
		return 0
	end
	local m = (source ~= "card" and isnum(mul) and mul > 0) and mul or 1
	return math.min(PetXp.MAX_AWARD, math.floor(base * m))
end

-- Donne `amount` d'XP à chacun des emplacements `team` (indices) de `slots` qui contiennent un pet (k == "p"). Retourne la liste { slot, gained, from, to } (niveaux).
function PetXp.addToTeam(slots, team, amount)
	local out = {}
	if type(slots) ~= "table" or type(team) ~= "table" then
		return out
	end
	local seen = {}
	for _, idx in ipairs(team) do
		local sl = isnum(idx) and slots[idx] or nil
		if type(sl) == "table" and sl.k == "p" and not seen[idx] then
			seen[idx] = true
			local nx, gained, from, to = PetXp.add(sl.x, amount)
			sl.x = nx
			out[#out + 1] = { slot = idx, gained = gained, from = from, to = to }
		end
	end
	return out
end

-- Vol / vente : un pet vendu ou volé perd son XP chez le propriétaire d'origine ; le voleur garde l'XP du pet volé (D.6). Retourne l'XP à reporter sur le nouvel emplacement.
function PetXp.carry(slot)
	if type(slot) == "table" and slot.k == "p" then
		return PetXp.sanitize(slot.x)
	end
	return 0
end

---------------------------------------------------------------- Niveau de Dresseur (D.6)
-- trainer = { xp } : total des XP gagnés (tous pets confondus) ; niveau = floor(sqrt(xp / 50)) + 1, max 100. Sert au matchmaking et aux titres : aucun effet sur la force.
function PetXp.sanitizeTrainer(saved)
	local xp = 0
	if type(saved) == "table" and isnum(saved.xp) and saved.xp > 0 then
		xp = math.min(PetXp.TRAINER_MAX_XP, math.floor(saved.xp))
	end
	return { xp = xp }
end

function PetXp.trainerLevel(xp)
	if not isnum(xp) or xp < 0 then
		return 1
	end
	return math.min(PetXp.TRAINER_MAX_LEVEL, math.floor(math.sqrt(xp / 50)) + 1)
end

function PetXp.trainerAdd(trainer, amount)
	local t = PetXp.sanitizeTrainer(trainer)
	if isnum(amount) and amount > 0 then
		t.xp = math.min(PetXp.TRAINER_MAX_XP, t.xp + math.min(PetXp.MAX_AWARD, math.floor(amount)))
	end
	return t
end

return PetXp
