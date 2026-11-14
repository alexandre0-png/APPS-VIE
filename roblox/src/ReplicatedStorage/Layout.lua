-- ModuleScript : ReplicatedStorage/Shared/Layout
-- Disposition PURE de l'interface fixe (HUD) : tout est ancré aux bords (compteurs et objectif à gauche, bannière et notifications en haut
-- à droite, conseils en bas à gauche, boutons de menu en colonne en bas à droite) ; la zone centrale reste libre pour voir le personnage.
-- Testée avec une matrice d'appareils (tests/run.luau). Unités : pixels « de conception » ; le HUD est mis à l'échelle par `scale`.
local Layout = {}

Layout.MIN_SCALE = 0.85 -- en dessous, les boutons passent sous 44 px (cible tactile minimale)
Layout.MAX_SCALE = 1.25
Layout.EDGE = 8
Layout.NAV_BUTTON = 52
Layout.NAV_GAP = 4
-- Zone centrale à garder libre (en fraction de l'écran) : le personnage et la caméra.
Layout.CENTER = { x0 = 0.32, x1 = 0.68, y0 = 0.32, y1 = 0.75 }

function Layout.scaleFor(vw, vh)
	local s = math.min(vw / 900, vh / 520)
	if s ~= s then
		s = 1
	end
	return math.max(Layout.MIN_SCALE, math.min(Layout.MAX_SCALE, s))
end

-- Rectangles { x, y, w, h } en pixels de conception pour un écran de vw x vh pixels réels. Retourne (rects, scale, dw, dh).
function Layout.rects(vw, vh, navCount)
	navCount = navCount or 6
	local s = Layout.scaleFor(vw, vh)
	local dw, dh = vw / s, vh / s
	local e = Layout.EDGE
	local navH = navCount * Layout.NAV_BUTTON + (navCount - 1) * Layout.NAV_GAP
	local navW = Layout.NAV_BUTTON
	local rightW = math.min(330, math.max(180, dw - 196 - 3 * e)) -- bannière et notifications : à droite des compteurs
	local nav = { x = dw - e - navW, y = dh - e - navH, w = navW, h = navH }
	-- Notifications : sous la bannière, à droite des compteurs ; décalées à gauche de la colonne de menu si celle-ci monte jusqu'à elles.
	local toastsTop, toastsH = e + 46, 76
	local right = (nav.y < toastsTop + toastsH) and (nav.x - e) or (dw - e)
	local toastsW = math.min(240, right - (e + 196 + e))
	local r = {
		pillCoins = { x = e, y = e, w = 196, h = 52 },
		pillSpeed = { x = e, y = e + 58, w = 196, h = 52 },
		objective = { x = e, y = e + 118, w = 196, h = 62 },
		carry = { x = e, y = e + 188, w = 170, h = 26 },
		banner = { x = dw - e - rightW, y = e, w = rightW, h = 40 },
		toasts = { x = right - toastsW, y = toastsTop, w = toastsW, h = toastsH },
		nav = nav,
		hint = { x = e, y = dh - e - 44, w = math.min(260, dw - navW - 3 * e - 8), h = 44 },
	}
	return r, s, dw, dh
end

local function overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
Layout.overlap = overlap

-- Zone centrale à garder libre, en pixels de conception pour cet écran.
function Layout.centerRect(vw, vh)
	local s = Layout.scaleFor(vw, vh)
	local c = Layout.CENTER
	return { x = c.x0 * vw / s, y = c.y0 * vh / s, w = (c.x1 - c.x0) * vw / s, h = (c.y1 - c.y0) * vh / s }
end

return Layout
