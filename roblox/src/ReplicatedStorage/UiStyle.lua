-- ModuleScript : ReplicatedStorage/UiStyle (graphismes 6 : style d'interface commun). Données et calculs PURS, sans service Roblox ni Color3 :
-- rayons des coins, ombre légère, polices, tailles de texte, espacements, palette (triplets RGB 0-255) et couples texte / fond dont le contraste WCAG
-- doit rester >= 4,5:1 (vérifié par les tests). Les panneaux (boutique, calendrier, bestiaire, bonus, kiosque, menu : tous dans le même cadre de
-- Client.client.lua) lisent ces constantes ; leur logique et leurs remotes ne changent pas. Icônes : une seule famille, celle du lot 27 (Config.ICONS).
-- Style : compatible lupa (affectations composées et saut de boucle évités), gardes de type avant comparaison.
local UiStyle = {}

-- Coins arrondis (px).
UiStyle.RADIUS = { panel = 18, card = 14, button = 10, icon = 12, chip = 8, pill = 26 }

-- Ombre légère portée sous les cartes et le cadre des panneaux : bandes décalées (bas et droite), noires, très transparentes.
UiStyle.SHADOW = { offset = 4, transparency = 0.72, color = { 0, 0, 0 } }

-- Polices (noms d'Enum.Font) : titres, texte courant, descriptions.
UiStyle.FONTS = { title = "GothamBlack", body = "GothamBold", desc = "Gotham" }

-- Tailles de texte (px), du plus grand au plus petit.
UiStyle.TEXT = { title = 22, heading = 18, tab = 14, rowTitle = 15, button = 14, body = 13, desc = 12, small = 11 }

-- Espacements (px).
UiStyle.SPACING = { xs = 4, sm = 6, md = 10, lg = 16 }

-- Bordures.
UiStyle.STROKE = { panel = 2, button = 2, glossy = 3 }

-- Palette commune (RGB 0-255). Les valeurs historiques de Client.client.lua sont gardées ; seul le texte des boutons désactivés est éclairci (contraste).
UiStyle.COLORS = {
	bg = { 15, 42, 27 },
	panel = { 29, 77, 51 },
	pill = { 10, 30, 20 },
	yellow = { 255, 210, 63 },
	text = { 244, 255, 246 },
	muted = { 159, 199, 173 },
	red = { 255, 107, 107 },
	green = { 91, 227, 125 },
	dis = { 75, 91, 81 },
	dark = { 43, 34, 0 },
	disText = { 205, 218, 210 },
}

-- Couples (texte, fond) réellement utilisés par les panneaux : contraste >= MIN_CONTRAST exigé.
UiStyle.MIN_CONTRAST = 4.5
UiStyle.PAIRS = {
	{ "text", "bg" }, { "text", "panel" }, { "text", "pill" }, { "text", "dis" },
	{ "muted", "bg" }, { "muted", "panel" }, { "muted", "pill" },
	{ "yellow", "bg" }, { "yellow", "panel" }, { "yellow", "pill" },
	{ "green", "bg" }, { "green", "panel" }, { "green", "pill" },
	{ "dark", "yellow" }, { "dark", "green" }, { "dark", "red" },
	{ "disText", "dis" },
}

local function isRgb(c)
	return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number"
end

-- Luminance relative WCAG d'un triplet RGB 0-255.
function UiStyle.luminance(c)
	if not isRgb(c) then
		return 0
	end
	local function lin(v)
		local x = math.min(255, math.max(0, v)) / 255
		if x <= 0.03928 then
			return x / 12.92
		end
		return ((x + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end

-- Rapport de contraste WCAG (1 à 21) entre deux triplets.
function UiStyle.contrast(a, b)
	local la, lb = UiStyle.luminance(a), UiStyle.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Couples sous le seuil : liste { fg, bg, ratio } (vide = conforme).
function UiStyle.failingPairs()
	local bad = {}
	for _, p in ipairs(UiStyle.PAIRS) do
		local fg, bg = UiStyle.COLORS[p[1]], UiStyle.COLORS[p[2]]
		local r = (isRgb(fg) and isRgb(bg)) and UiStyle.contrast(fg, bg) or 0
		if r < UiStyle.MIN_CONTRAST then
			bad[#bad + 1] = { p[1], p[2], r }
		end
	end
	return bad
end

-- Palette convertie (Color3 injecté : Color3.fromRGB). Retourne { nom = Color3 }.
function UiStyle.palette(Color3)
	local out = {}
	for k, c in pairs(UiStyle.COLORS) do
		out[k] = Color3.fromRGB(c[1], c[2], c[3])
	end
	return out
end

-- Police d'un rôle (Enum injecté) : Enum.Font[nom], repli GothamBold.
function UiStyle.font(Enum, role)
	local name = UiStyle.FONTS[role] or UiStyle.FONTS.body
	local ok, f = pcall(function()
		return Enum.Font[name]
	end)
	if ok and f then
		return f
	end
	return Enum.Font.GothamBold
end

-- Famille d'icônes unique : une clé n'est acceptée que si elle appartient à Config.ICONS (lot 27). Retourne la clé ou nil (l'appelant garde son emoji).
function UiStyle.icon(Config, key)
	if type(key) == "string" and type(Config) == "table" and type(Config.ICONS) == "table" and Config.ICONS[key] ~= nil then
		return key
	end
	return nil
end

-- Description de l'ombre d'un cadre (bandes à poser comme enfants, hors de la surface du cadre) : liste { position = {sx, ox, sy, oy}, size = {sx, ox, sy, oy} }.
-- kind = "panel" (bas et droite) ou "card" (bas seulement : la liste verticale laisse SPACING.sm entre deux cartes).
function UiStyle.shadowStrips(kind)
	local o = UiStyle.SHADOW.offset
	local strips = { { position = { 0, o, 1, 0 }, size = { 1, -o, 0, o } } }
	if kind == "panel" then
		strips[2] = { position = { 1, 0, 0, o }, size = { 0, o, 1, 0 } }
	end
	return strips
end

return UiStyle
