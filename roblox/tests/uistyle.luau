--!nocheck
-- Graphismes 6 : style d'interface commun (ReplicatedStorage/UiStyle pur, appliqué par le cadre commun des panneaux de Client.client.lua).
-- Mesuré : constantes cohérentes (rayons, ombre légère, polices, tailles, espacements), contraste WCAG >= 4,5:1 sur tous les couples texte / fond utilisés,
-- une seule famille d'icônes (Config.ICONS, lot 27), application dans Client (cadre, onglets, cartes, notes, boutons) sans toucher aux remotes, et
-- BattleUi / BattleScene / BattleLayout non modifiés par ce lot (aucune référence à UiStyle).
-- Forme : `return function(env) ... end`, env = { check, suite, luau, fs }. Style : pas de `+=`, pas de `continue`.
return function(env)
	local check, suite, luau, fs = env.check, env.suite, env.luau, env.fs
	local T = {}
	local C3 = { Color3 = { fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end } }
	local Config = luau.load(fs.readFile("roblox/src/ReplicatedStorage/Config.lua"), { debugName = "Config", environment = C3 })()
	local U = luau.load(fs.readFile("roblox/src/ReplicatedStorage/UiStyle.lua"), { debugName = "UiStyle" })()
	local function has(s, w)
		return string.find(s, w, 1, true) ~= nil
	end
	local function count(s, w)
		local n, i = 0, 1
		while true do
			local a, b = string.find(s, w, i, true)
			if not a then
				return n
			end
			n, i = n + 1, b + 1
		end
	end

	suite("Graphismes 6 : UiStyle (constantes, contraste >= 4,5:1, icônes du lot 27)")
	check("rayons : panneau > carte > bouton > puce, tous > 0", U.RADIUS.panel > U.RADIUS.card and U.RADIUS.card > U.RADIUS.button and U.RADIUS.button > U.RADIUS.chip and U.RADIUS.chip > 0)
	check("ombre légère : décalage 2 à 8 px, transparence >= 0,6 (discrète), noire", U.SHADOW.offset >= 2 and U.SHADOW.offset <= 8 and U.SHADOW.transparency >= 0.6 and U.SHADOW.transparency < 1 and U.SHADOW.color[1] == 0)
	check("ombre de carte plus petite que l'espacement de la liste (aucun chevauchement de la carte suivante)", U.SHADOW.offset < U.SPACING.sm)
	T.sizes = { U.TEXT.title, U.TEXT.heading, U.TEXT.rowTitle, U.TEXT.tab, U.TEXT.body, U.TEXT.desc, U.TEXT.small }
	T.desc = true
	for i = 2, #T.sizes do
		if T.sizes[i] > T.sizes[i - 1] then
			T.desc = false
		end
	end
	check("tailles de police hiérarchisées (titre 22 >= ... >= petit 11) et lisibles (>= 11 px)", T.desc and U.TEXT.small >= 11 and U.TEXT.title == 22)
	check("espacements croissants xs < sm < md < lg", U.SPACING.xs < U.SPACING.sm and U.SPACING.sm < U.SPACING.md and U.SPACING.md < U.SPACING.lg)
	check("polices : une famille (Gotham) déclinée en titre / texte / description", U.FONTS.title == "GothamBlack" and U.FONTS.body == "GothamBold" and U.FONTS.desc == "Gotham")
	T.bad = U.failingPairs()
	T.worst, T.worstName = math.huge, ""
	for _, p in ipairs(U.PAIRS) do
		local r = U.contrast(U.COLORS[p[1]], U.COLORS[p[2]])
		if r < T.worst then
			T.worst, T.worstName = r, p[1] .. "/" .. p[2]
		end
	end
	check("contraste WCAG >= 4,5:1 pour les " .. #U.PAIRS .. " couples texte / fond (pire : " .. T.worstName .. " " .. string.format("%.2f", T.worst) .. ")", #T.bad == 0 and T.worst >= 4.5)
	check("calcul du contraste conforme WCAG (noir / blanc = 21, même couleur = 1)", math.abs(U.contrast({ 0, 0, 0 }, { 255, 255, 255 }) - 21) < 1e-6 and math.abs(U.contrast({ 50, 90, 70 }, { 50, 90, 70 }) - 1) < 1e-9)
	check("le contrôle détecte un couple illisible (gris sur gris)", U.contrast({ 120, 120, 120 }, { 100, 100, 100 }) < 4.5)
	check("palette convertie par Color3 injecté (même RGB)", (function()
		local P = U.palette(C3.Color3)
		return math.abs(P.text.R - 244 / 255) < 1e-9 and math.abs(P.bg.G - 42 / 255) < 1e-9 and P.disText ~= nil
	end)())
	check("icônes : une seule famille, Config.ICONS (lot 27) ; clé inconnue refusée", U.icon(Config, "egg_r3") == "egg_r3" and U.icon(Config, "inconnue") == nil and U.icon(nil, "egg_r3") == nil)
	check("ombres : bandes bas (+ droite pour le panneau)", #U.shadowStrips("card") == 1 and #U.shadowStrips("panel") == 2)
	check("module pur : aucun service Roblox, pas de += / continue", not has(fs.readFile("roblox/src/ReplicatedStorage/UiStyle.lua"), "GetService") and not has(fs.readFile("roblox/src/ReplicatedStorage/UiStyle.lua"), "+=") and not has(fs.readFile("roblox/src/ReplicatedStorage/UiStyle.lua"), "continue"))

	suite("Graphismes 6 : application dans les panneaux (Client.client.lua), logique et remotes inchangés")
	local cli = fs.readFile("roblox/src/StarterPlayerScripts/Client.client.lua")
	check("Client : UiStyle chargé, palette COL issue de UiStyle", has(cli, 'UiStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiStyle"))') and has(cli, "local COL = L10.UiStyle.palette(Color3)"))
	check("cadre commun des panneaux (boutique, calendrier, bestiaire, bonus, kiosque, menu) : rayon, bordure, ombre de UiStyle", has(cli, "corner(panelFrame, L10.UiStyle.RADIUS.panel)") and has(cli, "L10.shadow(panelFrame, \"panel\")") and has(cli, "Thickness = L10.UiStyle.STROKE.panel"))
	check("titre, onglets, cartes, notes : tailles et polices de UiStyle", has(cli, "TextSize = L10.UiStyle.TEXT.title") and has(cli, "TextSize = L10.UiStyle.TEXT.tab") and has(cli, "TextSize = L10.UiStyle.TEXT.rowTitle") and has(cli, "TextSize = L10.UiStyle.TEXT.desc") and has(cli, "TextSize = L10.UiStyle.TEXT.body"))
	check("cartes : coin, ombre et boutons de UiStyle", has(cli, "corner(f, L10.UiStyle.RADIUS.card)") and has(cli, "L10.shadow(f, \"card\")") and count(cli, "L10.UiStyle.RADIUS.button") >= 2)
	check("bouton désactivé : texte UiStyle disText (contraste >= 4,5)", has(cli, "COL.disText"))
	check("icônes d'image : seulement Config.ICONS (L10.iconUrl filtrée par UiStyle.icon)", has(cli, "if not L10.UiStyle.icon(Config, key) then"))
	check("remotes inchangés : mêmes FireServer d'actions qu'avant (aucun ajouté par le style)", not has(cli, "FireServer(\"uiStyle") and not has(cli, "UiStyle\", "))
	for _, f in ipairs({ "BattleUi.lua", "BattleScene.lua" }) do
		check(f .. " : non modifié par le style commun (aucune référence à UiStyle)", not has(fs.readFile("roblox/src/StarterPlayerScripts/" .. f), "UiStyle"))
	end
	check("BattleLayout.lua : non modifié par le style commun", not has(fs.readFile("roblox/src/ReplicatedStorage/BattleLayout.lua"), "UiStyle"))
end
