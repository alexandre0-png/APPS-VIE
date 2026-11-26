-- ModuleScript : ReplicatedStorage/Shared/HouseDecorData   (lot 8B-meubles, NON INTÉGRÉ : voir roblox/HOUSEDECOR_INTEGRATION_NOTES.md)
-- Données PURES du décor intérieur des maisons (aucun service Roblox, aucun require). Les 24 modèles Blender des lots 18 (petits objets)
-- et 19 (gros meubles) sont répartis sur les 8 niveaux de Config.BASE_LEVELS2 : le niveau N AJOUTE du décor, il n'en retire jamais.
--
-- Conventions (repère de la maison, studs) :
--   pos  = centre du BAS de l'objet : x (droite), y (hauteur au-dessus du sol, 0 = sol ou plan de travail), z (avant) ; origine = centre de la maison au sol.
--   size = taille cible {x, y, z} ; y = hauteur. Pour un Cylinder, size = {diamètre, hauteur, diamètre}.
--   rot  = rotation autour de l'axe Y, en degrés (0 à 359).
--   flat = objet posé à plat (tapis) : exclu du contrôle de chevauchement.
--   parts = BUDGET réservé à l'objet une fois le modèle chargé (estimation, à mesurer dans Studio). Somme par maison <= PARTS_BUDGET.
--   fallback = repli procédural : UNE Part (forme simple), couleur et matière. Utilisé si LoadAsset échoue ou si les modèles sont désactivés.
-- Limite de position : |x| et |z| restent dans REACH (plus petite maison : 52 studs, marge de 8 studs pour les murs).
local HouseDecorData = {}

HouseDecorData.LEVEL_COUNT = 8 -- = #Config.BASE_LEVELS2
HouseDecorData.MAX_NEW_PER_LEVEL = 12 -- au plus ~12 objets nouveaux par niveau
HouseDecorData.PARTS_BUDGET = 150 -- Parts totales par maison (tous niveaux)
HouseDecorData.REACH = 18 -- demi-emprise utile autour du centre de la maison (studs)
HouseDecorData.FALLBACK_PARTS = 1 -- une seule Part par repli procédural

-- LEVELS[n] = objets DÉBLOQUÉS au niveau n (nouveaux à ce niveau). Le décor total d'un niveau = unlocked(n).
HouseDecorData.LEVELS = {
	-- 1 : Enclos de bois
	{
		{ id = "plant_pot_a", name = "Pot de plante A", assetId = 86148706778494, size = { 2.2, 2.4, 2.2 }, pos = { -16, 0, 2 }, rot = 0, parts = 4, fallback = { shape = "Cylinder", color = { 178, 96, 60 }, material = "SmoothPlastic" } },
		{ id = "rug_round", name = "Tapis rond", assetId = 90438557881098, size = { 8, 0.2, 8 }, pos = { 0, 0, 0 }, rot = 0, flat = true, parts = 4, fallback = { shape = "Cylinder", color = { 170, 60, 70 }, material = "Fabric" } },
		{ id = "stool_side", name = "Tabouret", assetId = 134719337565962, size = { 2.2, 2.5, 2.2 }, pos = { 4, 0, 4 }, rot = 0, parts = 4, fallback = { shape = "Cylinder", color = { 140, 95, 60 }, material = "Wood" } },
	},
	-- 2 : Chalet du Couvoir
	{
		{ id = "plant_pot_b", name = "Pot de plante B", assetId = 121510089986414, size = { 2, 2, 2 }, pos = { 17, 0, -10 }, rot = 0, parts = 4, fallback = { shape = "Cylinder", color = { 230, 225, 215 }, material = "SmoothPlastic" } },
		{ id = "books_stack", name = "Pile de livres", assetId = 75235784527086, size = { 3, 2, 2 }, pos = { -16, 0, -7 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 120, 70, 60 }, material = "Wood" } },
		{ id = "coffee_table_round", name = "Table basse ronde", assetId = 112871489043894, size = { 4, 2.5, 4 }, pos = { 0, 0, 0 }, rot = 0, parts = 4, fallback = { shape = "Cylinder", color = { 110, 75, 50 }, material = "Wood" } },
	},
	-- 3 : Maison-Tour (alarme)
	{
		{ id = "wall_lamp", name = "Applique murale", assetId = 73563604591192, size = { 1, 2, 1 }, pos = { -14, 6, -13.5 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 255, 220, 140 }, material = "SmoothPlastic" } },
		{ id = "clock_wall", name = "Horloge murale", assetId = 95777609232622, size = { 2.5, 2.5, 0.5 }, pos = { 0, 8, -13.5 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 245, 240, 225 }, material = "SmoothPlastic" } },
		{ id = "vase_big", name = "Grand vase", assetId = 123819297063677, size = { 2, 4, 2 }, pos = { -4, 0, -6 }, rot = 0, parts = 4, fallback = { shape = "Cylinder", color = { 60, 120, 170 }, material = "SmoothPlastic" } },
	},
	-- 4 : Maison à l'auvent
	{
		{ id = "bed_double", name = "Lit double", assetId = 73424212171108, size = { 6, 3, 8 }, pos = { -8, 0, 6 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 140, 90, 60 }, material = "Wood" } },
		{ id = "speaker_pair", name = "Paire d'enceintes", assetId = 120384220519044, size = { 3, 3, 2 }, pos = { 14, 0, 10 }, rot = 270, parts = 4, fallback = { shape = "Block", color = { 35, 35, 40 }, material = "Metal" } },
		{ id = "branch_chandelier", name = "Lustre en branches", assetId = 81736669133938, size = { 5, 4, 5 }, pos = { 0, 11, 0 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 200, 170, 90 }, material = "Metal" } },
	},
	-- 5 : Maison au garage (chien de garde)
	{
		{ id = "kitchen_run", name = "Plan de cuisine", assetId = 79053277599844, size = { 8, 4, 2.5 }, pos = { -7, 0, -12.5 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 235, 235, 240 }, material = "SmoothPlastic" } },
		{ id = "dining_set", name = "Table à manger", assetId = 104316845432310, size = { 7, 3, 5 }, pos = { 6, 0, 8 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 150, 100, 70 }, material = "Wood" } },
		{ id = "coffee_maker", name = "Cafetière", assetId = 112911908053394, size = { 1.5, 2, 1.5 }, pos = { -9, 4, -12.5 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 60, 60, 65 }, material = "SmoothPlastic" } },
		{ id = "toaster", name = "Grille-pain", assetId = 139790299453025, size = { 1.2, 1.2, 1.5 }, pos = { -5, 4, -12.5 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 200, 40, 40 }, material = "SmoothPlastic" } },
	},
	-- 6 : Villa moderne
	{
		{ id = "sofa_corner", name = "Canapé d'angle", assetId = 107495439971094, size = { 8, 3, 4 }, pos = { 8, 0, -3 }, rot = 180, parts = 8, fallback = { shape = "Block", color = { 90, 110, 150 }, material = "Fabric" } },
		{ id = "tv_unit_stepped", name = "Meuble TV", assetId = 108277232894442, size = { 6, 2, 1.5 }, pos = { -15, 0, 8 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 30, 30, 35 }, material = "SmoothPlastic" } },
		{ id = "kitchen_upper", name = "Meubles hauts de cuisine", assetId = 111169784434252, size = { 8, 3, 1.5 }, pos = { -7, 6.5, -13.5 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 235, 235, 240 }, material = "SmoothPlastic" } },
	},
	-- 7 : Grande villa (Lot de gros meubles de bureau et de rangement)
	{
		{ id = "fridge_big", name = "Grand réfrigérateur", assetId = 131419976234083, size = { 3.5, 6.5, 3 }, pos = { -15, 0, -11 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 230, 235, 240 }, material = "SmoothPlastic" } },
		{ id = "desk_study", name = "Bureau d'étude", assetId = 102305030833988, size = { 5, 3, 2.5 }, pos = { 14, 0, 2 }, rot = 180, parts = 8, fallback = { shape = "Block", color = { 120, 85, 55 }, material = "Wood" } },
		{ id = "shelf_drawers", name = "Étagère à tiroirs", assetId = 139964774272115, size = { 5, 4, 2 }, pos = { 15, 0, -7 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 130, 95, 65 }, material = "Wood" } },
	},
	-- 8 : Château doré
	{
		{ id = "wardrobe_tall", name = "Grande armoire", assetId = 117500900219054, size = { 5, 8, 2.5 }, pos = { 10, 0, -12.5 }, rot = 0, parts = 8, fallback = { shape = "Block", color = { 110, 80, 55 }, material = "Wood" } },
		{ id = "oven_stove", name = "Four et plaque", assetId = 87903538253499, size = { 2.5, 3, 3 }, pos = { -15, 0, -4 }, rot = 0, parts = 4, fallback = { shape = "Block", color = { 50, 50, 55 }, material = "Metal" } },
	},
}

-- Décor TOTAL d'un niveau (cumul des niveaux 1..n), dans l'ordre de déblocage. Niveau hors 1..LEVEL_COUNT : borné ; non-nombre : niveau 1.
function HouseDecorData.unlocked(level)
	local n = 1
	if type(level) == "number" and level == level then
		n = math.floor(level)
	end
	if n < 1 then
		n = 1
	end
	if n > HouseDecorData.LEVEL_COUNT then
		n = HouseDecorData.LEVEL_COUNT
	end
	local out = {}
	for l = 1, n do
		for _, item in ipairs(HouseDecorData.LEVELS[l]) do
			out[#out + 1] = item
		end
	end
	return out
end

-- Budget de Parts (somme de `parts`) du décor cumulé d'un niveau.
function HouseDecorData.budget(level)
	local total = 0
	for _, item in ipairs(HouseDecorData.unlocked(level)) do
		total = total + item.parts
	end
	return total
end

return HouseDecorData
