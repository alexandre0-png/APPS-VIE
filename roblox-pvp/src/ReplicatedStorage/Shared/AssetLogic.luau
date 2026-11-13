--!strict
-- Règles pures de sécurité et de choix pour les modèles Roblox importés (testables hors Roblox).
local AssetLogic = {}

-- Classes supprimées de tout modèle importé : aucun code ni canal réseau venant d'un tiers.
local BLOCKED: { [string]: boolean } = {
	Script = true, LocalScript = true, ModuleScript = true,
	RemoteEvent = true, RemoteFunction = true, BindableEvent = true, BindableFunction = true,
}

-- Effets cosmétiques tiers supprimés (le jeu a ses propres effets sans sang).
local STRIPPED_FX: { [string]: boolean } = {
	ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Smoke = true, Sparkles = true, Sound = true,
	Explosion = true, ForceField = true,
}

local BLOOD_WORDS = { "blood", "gore", "sang", "gib", "splat", "wound", "viscer", "entrail", "guts", "dismember" }

function AssetLogic.IsBlockedClass(className: string): boolean
	return BLOCKED[className] == true
end

function AssetLogic.IsStrippedFx(className: string): boolean
	return STRIPPED_FX[className] == true
end

-- Nom évoquant du sang / du gore.
function AssetLogic.IsBloodName(name: string): boolean
	local lower = string.lower(name)
	for _, word in ipairs(BLOOD_WORDS) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- Couleur (0..1) typiquement « sang » : rouge dominant, vert et bleu très bas.
function AssetLogic.IsBloodColor(r: number, g: number, b: number): boolean
	return r >= 0.45 and g <= 0.2 and b <= 0.2 and r > (g + b) * 2.5
end

-- Index du nom correspondant le mieux aux mots-clés (mot entier > sous-chaîne), ou nil.
function AssetLogic.PickByKeywords(names: { string }, keywords: { string }): number?
	local bestIndex, bestScore = nil, 0
	for i, name in ipairs(names) do
		local lower = string.lower(name)
		local tokens: { [string]: boolean } = {}
		for token in string.gmatch(lower, "[%w]+") do
			tokens[token] = true
		end
		for k, keyword in ipairs(keywords) do
			local kw = string.lower(keyword)
			local score = 0
			if tokens[kw] then
				score = 100 - k
			elseif string.find(lower, kw, 1, true) then
				score = 50 - k
			end
			if score > bestScore then
				bestIndex, bestScore = i, score
			end
		end
	end
	return bestIndex
end

-- Facteur d'échelle pour ramener la plus grande dimension à `target`.
function AssetLogic.ScaleFor(longest: number, target: number): number
	if longest <= 0.001 then
		return 1
	end
	return math.clamp(target / longest, 0.01, 100)
end

-- Axe le plus long (1=X, 2=Y, 3=Z) d'une boîte englobante.
function AssetLogic.LongestAxis(x: number, y: number, z: number): number
	if x >= y and x >= z then
		return 1
	elseif y >= z then
		return 2
	end
	return 3
end

return AssetLogic
