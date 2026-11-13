--!nonstrict
-- Logique pure du chargement de modèles externes (testable avec un chargeur factice) :
-- liste noire d'éléments dangereux, chargement avec délai maximum, limites, choix du T-Rex alternatif,
-- validation d'un modèle de T-Rex (mâchoire reconnaissable) et mise à l'échelle.

local AssetLogic = {}

-- Classes supprimées de tout modèle chargé : code, communication, audio non maîtrisé, personnages/outils.
AssetLogic.Forbidden = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	Sound = true,
	Tool = true,
	HopperBin = true,
	Humanoid = true,
	VehicleSeat = true,
}

function AssetLogic.isForbidden(className: string): boolean
	return AssetLogic.Forbidden[className] == true
end

-- Supprime les éléments interdits. getClass(inst) -> nom de classe ; destroy(inst). Retourne le nombre supprimé.
function AssetLogic.sanitize(list: { any }, getClass: (any) -> string, destroy: (any) -> ()): number
	local removed = 0
	for _, inst in ipairs(list) do
		if AssetLogic.isForbidden(getClass(inst)) then
			destroy(inst)
			removed += 1
		end
	end
	return removed
end

function AssetLogic.isExcluded(id: number, cfg: any): boolean
	for _, v in ipairs(cfg.Excluded) do
		if v == id then
			return true
		end
	end
	return false
end

-- Charge un modèle avec délai maximum. opts = { timeout, step, spawn, wait }. Retourne (modèle, nil) ou (nil, raison).
-- Ne lève jamais d'erreur : tout échec (erreur du chargeur, résultat vide, délai dépassé) devient (nil, raison).
function AssetLogic.load(loader: (number) -> any, id: number, opts: any): (any?, string?)
	if type(id) ~= "number" or id <= 0 or id % 1 ~= 0 then
		return nil, "identifiant invalide"
	end
	local done, ok, result = false, false, nil
	opts.spawn(function()
		local o, r = pcall(loader, id)
		ok, result, done = o, r, true
	end)
	local waited = 0
	while not done and waited < opts.timeout do
		opts.wait(opts.step)
		waited += opts.step
	end
	if not done then
		return nil, "délai dépassé"
	end
	if not ok then
		return nil, "erreur de chargement : " .. tostring(result)
	end
	if result == nil then
		return nil, "modèle vide"
	end
	return result, nil
end

-- Limites de taille/complexité. size = {x,y,z}.
function AssetLogic.checkLimits(partCount: number, size: { number }, cfg: any): (boolean, string?)
	if partCount < 1 then
		return false, "aucune pièce"
	end
	if partCount > cfg.MaxParts then
		return false, "trop de pièces (" .. partCount .. ")"
	end
	if math.max(size[1], size[2], size[3]) > cfg.MaxDimension then
		return false, "dimensions excessives"
	end
	return true, nil
end

function AssetLogic.fitScale(currentMax: number, targetMax: number, minScale: number, maxScale: number): number
	if currentMax <= 0 then
		return 1
	end
	return math.clamp(targetMax / currentMax, minScale, maxScale)
end

-- Choix du T-Rex : retourne (clé, id) ou nil si le T-Rex intégré doit être conservé.
function AssetLogic.pickDinoSkin(cfg: any): (string?, number?)
	if cfg.Enabled ~= true or cfg.DinoModel == "builtin" then
		return nil, nil
	end
	local id = cfg.DinoIds[cfg.DinoModel]
	if type(id) ~= "number" or AssetLogic.isExcluded(id, cfg) then
		return nil, nil
	end
	return cfg.DinoModel, id
end

-- Cherche la mâchoire inférieure parmi des noms de pièces. Retourne l'index ou nil.
function AssetLogic.findJawIndex(names: { string }): number?
	local best, bestScore = nil, 0
	for i, name in ipairs(names) do
		local n = string.lower(name)
		local isJaw = string.find(n, "jaw", 1, true) or string.find(n, "mandib", 1, true) or string.find(n, "machoire", 1, true) or string.find(n, "mâchoire", 1, true)
		if isJaw then
			local score = 1
			if string.find(n, "lower", 1, true) or string.find(n, "bottom", 1, true) or string.find(n, "inf", 1, true) then
				score = 3
			end
			if string.find(n, "upper", 1, true) or string.find(n, "top", 1, true) or string.find(n, "sup", 1, true) then
				score = 0
			end
			if score > bestScore then
				best, bestScore = i, score
			end
		end
	end
	return best
end

-- Un modèle de T-Rex peut-il remplacer le modèle intégré sans perdre le comportement (mâchoire, rugissement, marche) ?
-- info = { partCount, hasJaw }. Retourne (ok, raison).
function AssetLogic.validateDino(info: any, cfg: any): (boolean, string?)
	if info.partCount < 1 then
		return false, "aucune pièce"
	end
	if cfg.RequireJaw and not info.hasJaw then
		return false, "mâchoire introuvable : le T-Rex intégré est conservé"
	end
	return true, nil
end

return AssetLogic
