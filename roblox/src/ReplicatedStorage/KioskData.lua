-- ModuleScript : ReplicatedStorage/Shared/KioskData
-- LOT 8B-kiosque : DONNEES PURES du kiosque central de la place (aucun service Roblox, aucune instance ; testé hors de Roblox). Source unique pour
-- ServerScriptService/Kiosk (construction, prompts, validation serveur) et pour le client (libellés des 4 panneaux).
-- Repères : Nord = -Z, Est = +X. Le « devant » du kiosque (comptoir, PanneauBoutique) regarde la halle (Config.Map2.hall).
local KioskData = {}

KioskData.ASSET_ID = 90238570290603 -- modèle Blender hub_kiosk (clé J.1 : hub.kiosk), 15,4 de large, 12,75 de haut, pieds à 0
KioskData.ASSET_GROUP, KioskData.ASSET_KEY = "hub", "kiosk" -- Config.Assets.models.hub.kiosk (préchargé et nettoyé par le module Assets)
KioskData.WIDTH, KioskData.HEIGHT = 15.4, 12.75
KioskData.RADIUS = 7.7 -- demi-largeur du socle : rayon d'emprise utilisé pour contrôler les obstacles
KioskData.GROUND_Y = 0.52 -- dessus du dallage de la place (Scenery.plaza : disque à y = 0,42, épaisseur 0,2)
KioskData.MODEL_NAME = "Kiosk"
KioskData.MAX_PARTS = 220 -- même plafond que Config.Assets.decorMaxParts ; au-delà le modèle est refusé (repli procédural)
KioskData.SIZE_TOLERANCE = 0.25 -- largeur mesurée du modèle à +-25 % de WIDTH, sinon mise à l'échelle (une fois) puis refus

-- Emplacement proposé (voir KIOSK_INTEGRATION_NOTES.md pour la vérification des obstacles) : sud-est du centre de la place, hors du tapis (z = 0, largeur 8),
-- des chemins B3 / B4, de la fontaine (10, -38) et des étals (z >= 36). Le comptoir regarde la halle (-40, 0).
KioskData.CENTER = { x = 14, z = 22 }
KioskData.FACE = { x = -40, z = 0 }

-- Les 4 interactions. `part` = nom de base de la pièce du modèle Blender (sans suffixe de couleur) ; `rel` = position locale du panneau dans le
-- repère du repli procédural (x = droite, z = vers l'arrière ; le comptoir est à z = -R) ; `ang` = rotation locale (rad) du panneau procédural.
local R = 6.3
KioskData.PANELS = {
	{ id = "shop", part = "PanneauBoutique", rel = { x = 0, z = -R }, ang = 0, action = "Ouvrir la boutique", object = "Boutique Robux", emoji = "💎", title = "BOUTIQUE", sub = "Robux et offres", color = { 255, 190, 60 } },
	{ id = "calendar", part = "PanneauCalendrier", rel = { x = 0, z = R }, ang = 3.14159265, action = "Voir le calendrier", object = "Calendrier des œufs", emoji = "📅", title = "CALENDRIER", sub = "Une récompense par jour", color = { 120, 200, 120 } },
	{ id = "odds", part = "PanneauProba", rel = { x = R, z = 0 }, ang = -1.5707963, action = "Voir les probabilités", object = "Probabilités et prix", emoji = "🎲", title = "PROBABILITÉS", sub = "Tapis et prix", color = { 120, 170, 255 } },
	{ id = "ranking", part = "PanneauClassement", rel = { x = -R, z = 0 }, ang = 1.5707963, action = "Voir le classement", object = "Classement de la saison", emoji = "🏆", title = "CLASSEMENT", sub = "Saison de l'Arène", color = { 255, 150, 90 } },
}
KioskData.LIGHT_PART = "Lueur" -- lanterne centrale du modèle (reçoit une PointLight si le modèle n'en a pas)
KioskData.BADGE_NAME = "PastilleCalendrier" -- pastille rouge posée au-dessus du panneau du calendrier

-- Prompts : distance d'activation côté client, portée de contrôle côté serveur (plus large : latence et marche), pause entre deux demandes d'un joueur.
KioskData.PROMPT = { hold = 0.2, distance = 11, requiresLineOfSight = false }
KioskData.SERVER_RANGE = 20 -- studs au centre du kiosque ; la validation serveur refuse au-delà
KioskData.COOLDOWN = 0.6 -- secondes entre deux actions acceptées d'un même joueur

-- Ambiance : kiosk_ambience (son approuvé fourni par la gestion du projet). Boucle, volume bas, atténuation par distance. Config.SOUNDS.kiosk_ambience, si
-- présent, remplace ces valeurs ; Config.SOUNDS_ENABLED = false : aucun Sound n'est créé.
KioskData.SOUND = { key = "kiosk_ambience", id = "rbxassetid://82723287691994", vol = 0.25, minDist = 14, maxDist = 75 }

KioskData.ACTIONS = { shop = true, calendar = true, odds = true, ranking = true }
KioskData.MAX_ENTRIES = 10 -- lignes du classement renvoyées

function KioskData.panel(id)
	for _, p in ipairs(KioskData.PANELS) do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- Angle (radians, [-pi, pi]) du vecteur (x, z) dans le plan XZ, sans math.atan2 : atan(z / x) corrigé par quadrant.
function KioskData.angle(x, z)
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then
		return 0
	end
	if x == 0 then
		if z > 0 then
			return math.pi / 2
		elseif z < 0 then
			return -math.pi / 2
		end
		return 0
	end
	local a = math.atan(z / x)
	if x < 0 then
		if z >= 0 then
			return a + math.pi
		end
		return a - math.pi
	end
	return a
end

-- Rotation autour de Y (CFrame.Angles(0, theta, 0)) qui amène le vecteur local (lx, lz) sur la direction (ux, uz). Roblox : Y positif tourne (x, z) en
-- (x cos + z sin, -x sin + z cos), l'angle du vecteur DIMINUE de theta. Le repli procédural a son comptoir à (0, -1) (local -Z).
function KioskData.yawFor(lx, lz, ux, uz)
	if type(lx) ~= "number" or type(lz) ~= "number" or lx ~= lx or lz ~= lz or math.sqrt(lx * lx + lz * lz) < 1e-6 then
		lx, lz = 0, -1
	end
	local theta = KioskData.angle(lx, lz) - KioskData.angle(ux, uz)
	while theta > math.pi do
		theta = theta - 2 * math.pi
	end
	while theta < -math.pi do
		theta = theta + 2 * math.pi
	end
	return theta
end

-- Position monde d'un point local (lx, lz) du kiosque de centre (cx, cz) tourné de theta (même convention que yawFor).
function KioskData.toWorld(cx, cz, theta, lx, lz)
	local c, s = math.cos(theta), math.sin(theta)
	return cx + lx * c + lz * s, cz - lx * s + lz * c
end

-- Le disque (cx, cz, r) chevauche-t-il l'un des obstacles de Config.Map2 ? Retourne (false) ou (true, nom). margin = marge libre exigée (studs).
-- Obstacles : halle, fontaine, tapis et bac, étals, piste, portails, arrivée des tapis, bord de la place, chemins (distance au segment).
function KioskData.overlap(Map2, cx, cz, r, margin)
	margin = margin or 0
	local function d(ax, az)
		return math.sqrt((cx - ax) ^ 2 + (cz - az) ^ 2)
	end
	local function segDist(ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = len2 > 0 and math.max(0, math.min(1, ((cx - ax) * dx + (cz - az) * dz) / len2)) or 0
		return math.sqrt((cx - (ax + dx * t)) ^ 2 + (cz - (az + dz * t)) ^ 2)
	end
	local function rect(x0, x1, z0, z1)
		local nx, nz = math.max(x0, math.min(cx, x1)), math.max(z0, math.min(cz, z1))
		return math.sqrt((cx - nx) ^ 2 + (cz - nz) ^ 2)
	end
	local pl = Map2.plaza
	if d(pl.x, pl.z) + r + margin > pl.r then
		return true, "bord de la place"
	end
	if d(Map2.hall.x, Map2.hall.z) < Map2.hall.r + r + margin then
		return true, "halle"
	end
	if d(Map2.fountain.x, Map2.fountain.z) < Map2.fountain.r + r + margin then
		return true, "fontaine"
	end
	local b = Map2.belt
	if rect(b.x0, b.x1, b.z - b.width / 2, b.z + b.width / 2) < r + margin then
		return true, "tapis"
	end
	if d(b.bin.x, b.bin.z) < 6 + r + margin then
		return true, "bac du tapis"
	end
	for _, st in ipairs(Map2.stalls) do
		if rect(st.x - 5.5, st.x + 5.5, st.z - 4.3, st.z + 4.3) < r + margin then
			return true, "étal"
		end
	end
	local tk = Map2.track
	if rect(tk.x - tk.w / 2, tk.x + tk.w / 2, tk.z - tk.d / 2, tk.z + tk.d / 2) < r + margin then
		return true, "piste d'entraînement"
	end
	local ph = Map2.portalHub
	if rect(ph.x0 - 6, ph.x1 + 6, ph.z - 6, ph.z + 6) < r + margin then
		return true, "portails"
	end
	if d(Map2.plazaArrival.x, Map2.plazaArrival.z) < 4 + r + margin then
		return true, "arrivée des tapis"
	end
	for _, p in ipairs(Map2.paths) do
		if p.kind == "paved" and p.pts[1][1] == 0 and p.pts[1][2] == 0 then -- routes qui partent du centre de la place (B1 à B5)
			for k = 1, #p.pts - 1 do
				if segDist(p.pts[k][1], p.pts[k][2], p.pts[k + 1][1], p.pts[k + 1][2]) < Map2.pathHalf + r + margin then
					return true, "chemin " .. tostring(p.name)
				end
			end
		end
	end
	return false
end

return KioskData
