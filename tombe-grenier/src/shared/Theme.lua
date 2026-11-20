--[[
  Theme : style « cartoon glossy » adapté à l'horreur, et code couleur par fonction (données pures, testées).
  Contour foncé épais, dégradé du clair vers le foncé, coins arrondis, reflet discret. Aucune image : tout est dessiné par le code.
    vert   = continuer, jouer           bleu   = sauver, aider
    orange = options, pause, journal    rouge  = fermer, retour, danger
  Le même code couleur sert au hub, au journal, aux boutons tactiles, aux messages et aux bannières.
]]
local Theme = {}

-- top : haut du dégradé ; bottom : bas ; stroke : contour foncé ; text : couleur du texte (assez contrasté)
Theme.ROLES = {
	play = { top = { 120, 205, 95 }, bottom = { 28, 105, 42 }, stroke = { 8, 28, 12 }, text = { 255, 255, 240 } },
	save = { top = { 100, 175, 255 }, bottom = { 22, 70, 170 }, stroke = { 6, 18, 48 }, text = { 255, 255, 250 } },
	option = { top = { 255, 190, 90 }, bottom = { 205, 105, 25 }, stroke = { 48, 24, 6 }, text = { 38, 18, 4 } },
	danger = { top = { 245, 100, 90 }, bottom = { 150, 22, 28 }, stroke = { 46, 8, 8 }, text = { 255, 250, 245 } },
	neutral = { top = { 92, 86, 104 }, bottom = { 40, 36, 50 }, stroke = { 10, 8, 14 }, text = { 238, 232, 220 } },
}

Theme.STROKE = 3 -- épaisseur du contour (px)
Theme.CORNER = 12 -- rayon des coins (px)
Theme.GLOSS = { transparency = 0.88, height = 0.42 } -- reflet discret sur le haut

-- Fonction de chaque action tactile et de chaque bouton : mêmes couleurs partout
Theme.ACTION_ROLES = {
	Course = "play",
	Accroupi = "option",
	Lampe = "play",
	Lancer = "option",
	UV = "option",
	Indice = "save",
	Journal = "option",
}
Theme.BUTTON_ROLES = { Rejouer = "play", Quitter = "danger", Refermer = "danger", Fermer = "danger" }

-- Messages : fonction -> couleur
Theme.MESSAGE_ROLES = { info = "neutral", success = "play", help = "save", option = "option", error = "danger" }

function Theme.role(name)
	return Theme.ROLES[name] or Theme.ROLES.neutral
end

function Theme.roleForAction(name)
	return Theme.ACTION_ROLES[name] or "neutral"
end

function Theme.roleForButton(name)
	return Theme.BUTTON_ROLES[name] or "neutral"
end

-- Luminance relative (WCAG) d'une couleur { r, g, b } en 0..255
function Theme.luminance(c)
	local function lin(v)
		v = v / 255
		if v <= 0.03928 then
			return v / 12.92
		end
		return ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end

function Theme.contrast(a, b)
	local la, lb = Theme.luminance(a), Theme.luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end

-- Couleur moyenne du dégradé : sert à vérifier la lisibilité du texte
function Theme.middle(role)
	local r = Theme.role(role)
	return { (r.top[1] + r.bottom[1]) / 2, (r.top[2] + r.bottom[2]) / 2, (r.top[3] + r.bottom[3]) / 2 }
end

return Theme
