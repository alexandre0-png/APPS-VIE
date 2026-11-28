-- ModuleScript : ReplicatedStorage/Odds   (lot 10, B.1 et B.2)
-- Compteur de rareté « 1 sur N » : module PUR (aucun service Roblox, aucun require). Les tables viennent de la table `Config` PASSÉE en paramètre :
--   Config.SIZES[i].weight, Config.MUTS[i].weight, Config.PETS[i].tier (espèces par rareté), Config.ODDS.REF[r] (poids de référence, en %).
-- Le compteur est la rareté de RÉFÉRENCE d'une combinaison (espèce, taille, mutation) : identique pour tous les joueurs, quel que soit l'œuf ou les
-- bonus utilisés. Aucune fonction d'ici ne reçoit de bonus (chance, trèfle, passe, potion, événement) : un achat ne peut donc pas gonfler le chiffre.
--   p_ref = REF[r]/100 × 1/n_r × SIZES[s].weight/ΣSIZES × MUTS[m].weight/ΣMUTS      N = 1/p_ref, arrondi
-- API (toutes les fonctions renvoient nil / "" / false sur entrée invalide, jamais d'erreur) :
--   Odds.value(Config, r, s, m [, nr])    -> N arrondi (nombre) ou nil. nr = nombre d'espèces de la rareté r (défaut : Odds.speciesCount)
--   Odds.forPet(Config, petIndex, s, m [, nr]) -> idem à partir de l'indice d'espèce de Config.PETS
--   Odds.speciesCount(Config, r)          -> nombre d'espèces publiées de rareté r (pet.published == false ou pet.hidden == true : exclu)
--   Odds.pRef(Config, r, s, m [, nr])     -> probabilité de référence (0..1) ou nil
--   Odds.round(n)                         -> arrondi : entier, sauf N < 10 (une décimale)
--   Odds.short(n) / Odds.label(n)         -> « 38 494 » / « 1 sur 38 494 » (milliers séparés par une espace insécable, « 12,5 M », « 8 Md »)
--   Odds.isSpecial(n [, Config])          -> n >= 10 000 (Config.ODDS.specialMin), seuil des effets spéciaux
--   Odds.level(n [, Config])              -> 0 (rien) .. 5 (voir Odds.LEVELS)
--   Odds.fx(n, r [, Config])              -> { special, level, banner, secretSound, announceServer, announceWorld, pillar, billboard }
--   Odds.countSteps(n [, steps])          -> liste croissante de paliers 1 .. n pour le compteur animé (12 paliers par défaut, dernier = n exact)
--   Odds.validate(Config)                 -> ok, liste de problèmes (tables de poids, REF)
-- Pour la brancher : `local Odds = require(ReplicatedStorage.Odds)` ; serveur à l'éclosion : `slot.o = Odds.forPet(Config, petIdx, s, m)` (une seule fois,
-- jamais recalculé) ; client : `Odds.label(slot.o)`. Pas de += ni de continue (le lanceur lupa du dépôt ne les gère pas dans ReplicatedStorage).
local Odds = {}

Odds.SEP = "\u{00A0}" -- espace insécable : rendue par toutes les polices Roblox (l'espace fine U+202F n'est pas garantie)
Odds.MAX = 9007199254740992 -- 2^53, borne du classement OrderedDataStore
Odds.DEFAULT_SPECIAL = 10000
Odds.DEFAULT_BILLBOARD = 1000
-- Seuils des niveaux d'effet : 1 = spécial (>= 10 000), 2 = bandeau « Tirage exceptionnel » (>= 100 000), 3 = son secret (>= 1 000 000),
-- 4 = >= 100 000 000, 5 = >= 1 000 000 000.
Odds.LEVELS = { 10000, 100000, 1000000, 100000000, 1000000000 }
Odds.BANNER_MIN = 100000
Odds.SECRET_SOUND_MIN = 1000000
Odds.SERVER_ANNOUNCE_N, Odds.SERVER_ANNOUNCE_R = 10000, 7
Odds.WORLD_ANNOUNCE_N, Odds.WORLD_ANNOUNCE_R = 1000000, 8

local function isNum(v)
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Somme des poids d'une liste { {weight = x}, ... } ; nil si la liste est inutilisable.
local function sumWeights(list)
	if type(list) ~= "table" then
		return nil
	end
	local total, count = 0, 0
	for i = 1, #list do
		local e = list[i]
		local w = type(e) == "table" and e.weight or nil
		if isNum(w) and w >= 0 then
			total = total + w
		end
		count = count + 1
	end
	if count == 0 or total <= 0 then
		return nil
	end
	return total
end

local function weightAt(list, i)
	if type(list) ~= "table" or not isNum(i) or i ~= math.floor(i) or i < 1 or i > #list then
		return nil
	end
	local e = list[i]
	local w = type(e) == "table" and e.weight or nil
	if isNum(w) and w > 0 then
		return w
	end
	return nil
end

function Odds.speciesCount(Config, r)
	if type(Config) ~= "table" or type(Config.PETS) ~= "table" or not isNum(r) then
		return 0
	end
	local n = 0
	for i = 1, #Config.PETS do
		local p = Config.PETS[i]
		if type(p) == "table" and p.tier == r and p.published ~= false and p.hidden ~= true then
			n = n + 1
		end
	end
	return n
end

function Odds.pRef(Config, r, s, m, nr)
	local ok, res = pcall(function()
		if type(Config) ~= "table" or not isNum(r) or r ~= math.floor(r) or r < 1 then
			return nil
		end
		local odds = Config.ODDS
		local ref = type(odds) == "table" and type(odds.REF) == "table" and odds.REF[r] or nil
		if not isNum(ref) or ref <= 0 then
			return nil
		end
		local count = nr
		if count == nil then
			count = Odds.speciesCount(Config, r)
		end
		if not isNum(count) or count < 1 then
			return nil
		end
		local sw, mw = weightAt(Config.SIZES, s), weightAt(Config.MUTS, m)
		local sTotal, mTotal = sumWeights(Config.SIZES), sumWeights(Config.MUTS)
		if sw == nil or mw == nil or sTotal == nil or mTotal == nil then
			return nil
		end
		local p = (ref / 100) * (1 / count) * (sw / sTotal) * (mw / mTotal)
		if isNum(p) and p > 0 then
			return p
		end
		return nil
	end)
	if ok then
		return res
	end
	return nil
end

-- Arrondi du compteur : entier, sauf N < 10 (une décimale) ; jamais < 1, jamais > 2^53.
function Odds.round(n)
	if not isNum(n) then
		return nil
	end
	if n < 1 then
		return 1
	end
	if n > Odds.MAX then
		return Odds.MAX
	end
	if n < 9.95 then
		return math.floor(n * 10 + 0.5) / 10
	end
	return math.floor(n + 0.5)
end

function Odds.value(Config, r, s, m, nr)
	local p = Odds.pRef(Config, r, s, m, nr)
	if p == nil then
		return nil
	end
	return Odds.round(1 / p)
end

function Odds.forPet(Config, petIndex, s, m, nr)
	if type(Config) ~= "table" or type(Config.PETS) ~= "table" or not isNum(petIndex) then
		return nil
	end
	local pet = Config.PETS[petIndex]
	if type(pet) ~= "table" then
		return nil
	end
	return Odds.value(Config, pet.tier, s, m, nr)
end

-- Groupe les milliers d'une chaîne de chiffres.
local function group(digits)
	local out, n = "", #digits
	for i = 1, n do
		out = out .. digits:sub(i, i)
		local left = n - i
		if left > 0 and left % 3 == 0 then
			out = out .. Odds.SEP
		end
	end
	return out
end

-- 12.5 -> « 12,5 » ; 8 -> « 8 » (une décimale seulement si elle n'est pas nulle).
local function oneDecimal(v)
	local t = math.floor(v * 10 + 0.5) / 10
	if t == math.floor(t) then
		return group(string.format("%.0f", t))
	end
	return (string.format("%.1f", t):gsub("%.", ","))
end

function Odds.short(n)
	if not isNum(n) or n <= 0 then
		return ""
	end
	n = Odds.round(n)
	if n < 10 then
		return (string.format("%.1f", n):gsub("%.", ","))
	end
	if n < 10000000 then
		return group(string.format("%.0f", n))
	end
	if n < 1000000000 then
		local v = n / 1000000
		if math.floor(v * 10 + 0.5) / 10 < 1000 then
			return oneDecimal(v) .. Odds.SEP .. "M"
		end
	end
	local v = n / 1000000000
	if v < 100 then
		return oneDecimal(v) .. Odds.SEP .. "Md"
	end
	return group(string.format("%.0f", math.floor(v + 0.5))) .. Odds.SEP .. "Md"
end

function Odds.label(n)
	local s = Odds.short(n)
	if s == "" then
		return ""
	end
	return "1 sur " .. s
end

function Odds.isSpecial(n, Config)
	if not isNum(n) then
		return false
	end
	local min = Odds.DEFAULT_SPECIAL
	if type(Config) == "table" and type(Config.ODDS) == "table" and isNum(Config.ODDS.specialMin) and Config.ODDS.specialMin > 0 then
		min = Config.ODDS.specialMin
	end
	return n >= min
end

function Odds.level(n, Config)
	if not isNum(n) then
		return 0
	end
	if not Odds.isSpecial(n, Config) then
		return 0
	end
	local lvl = 1
	for i = 2, #Odds.LEVELS do
		if n >= Odds.LEVELS[i] then
			lvl = i
		end
	end
	return lvl
end

-- Effets et annonces liés à un tirage (B.1 et B.2). r = rareté de l'espèce (peut être nil).
function Odds.fx(n, r, Config)
	local num = isNum(n) and n or 0
	local rr = isNum(r) and r or 0
	local billboardMin = Odds.DEFAULT_BILLBOARD
	if type(Config) == "table" and type(Config.ODDS) == "table" and isNum(Config.ODDS.billboardMin) and Config.ODDS.billboardMin > 0 then
		billboardMin = Config.ODDS.billboardMin
	end
	return {
		special = Odds.isSpecial(num, Config),
		level = Odds.level(num, Config),
		banner = num >= Odds.BANNER_MIN,
		secretSound = num >= Odds.SECRET_SOUND_MIN,
		announceServer = num >= Odds.SERVER_ANNOUNCE_N or rr >= Odds.SERVER_ANNOUNCE_R,
		announceWorld = num >= Odds.WORLD_ANNOUNCE_N or rr >= Odds.WORLD_ANNOUNCE_R,
		pillar = rr >= 10,
		billboard = num >= billboardMin,
	}
end

-- Paliers du compteur animé : de 1 à N, ralentissement final (ease out cubique), croissants, le dernier est N exact.
function Odds.countSteps(n, steps)
	local count = 12
	if isNum(steps) then
		count = math.max(1, math.min(60, math.floor(steps)))
	end
	local target = Odds.round(isNum(n) and n or 1) or 1
	local out = {}
	local prev = 1
	for i = 1, count do
		local t = i / count
		local v = 1 + (target - 1) * (1 - (1 - t) ^ 3)
		if target >= 10 then
			v = math.floor(v + 0.5)
		else
			v = math.floor(v * 10 + 0.5) / 10
		end
		if v < prev then
			v = prev
		end
		if i == count then
			v = target
		end
		out[i] = v
		prev = v
	end
	return out
end

-- Vérifie les tables lues dans Config : sommes de poids, REF, espèces par rareté.
function Odds.validate(Config)
	local problems = {}
	if type(Config) ~= "table" then
		return false, { "Config absente" }
	end
	local sTotal, mTotal = sumWeights(Config.SIZES), sumWeights(Config.MUTS)
	if sTotal == nil then
		problems[#problems + 1] = "Config.SIZES inutilisable"
	elseif math.abs(sTotal - 100) > 1e-6 then
		problems[#problems + 1] = "somme des tailles = " .. tostring(sTotal) .. " (attendu 100)"
	end
	if mTotal == nil then
		problems[#problems + 1] = "Config.MUTS inutilisable"
	elseif math.abs(mTotal - 100) > 1e-6 then
		problems[#problems + 1] = "somme des mutations = " .. tostring(mTotal) .. " (attendu 100)"
	end
	local odds = Config.ODDS
	if type(odds) ~= "table" or type(odds.REF) ~= "table" then
		problems[#problems + 1] = "Config.ODDS.REF absente"
	else
		for r = 1, #odds.REF do
			if not isNum(odds.REF[r]) or odds.REF[r] <= 0 then
				problems[#problems + 1] = "REF[" .. r .. "] invalide"
			end
			if Odds.speciesCount(Config, r) < 1 then
				problems[#problems + 1] = "aucune espèce publiée de rareté " .. r
			end
		end
	end
	return #problems == 0, problems
end

return Odds
