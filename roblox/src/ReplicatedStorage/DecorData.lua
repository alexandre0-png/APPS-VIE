-- ModuleScript : ReplicatedStorage/Shared/DecorData
-- Lot 8B-décor : DONNÉES PURES des modèles Blender de décor de carte (lots 15, 16 et 17 de Assets-crees). Aucune logique, aucun service Roblox :
-- la logique est dans ServerScriptService/Decor (placement, budgets, repli procédural) et les tests dans tests/decor.luau.
-- Une « famille » = un modèle Blender + sa règle de pose RELATIVE à la carte (zone), sa taille cible, son empreinte, son quota et son repli procédural.
-- Les modèles déjà branchés AILLEURS ne sont PAS repris ici (voir `wired`) : maisons house.l2..l7 (Config.Assets.models.house), arbres lot 11
-- (models.trees), décor de village lot 12 (models.scenery). Les 12 modèles du lot 17 sont de NOUVELLES variétés qui s'ajoutent sans les remplacer.
--
-- Champs d'une famille :
--   id        identifiant InsertService du modèle (entier > 0) ; lot = lot de Assets-crees ; cap = plafond de Parts accepté au chargement
--   zone      règle de pose : "plazaRim" (couronne de la place du marché), "stallSide" (autour des étals), "region" (rectangle de la carte),
--             "pathSide" (le long des chemins pavés), "pathSign" (premier point d'un chemin hors de la place, avec libellé), "lakeShore",
--             "lakeWater", "lakeIsle", et les ANCRES "hall", "bigEgg", "arena", "belt" (superpositions d'un élément procédural existant)
--   count     nombre d'exemplaires voulus ; height | length = taille cible en studs (length = plus grande arête horizontale) ; r = rayon d'empreinte
--   share     part maximale du budget Blender (0..1) que la famille peut consommer ; fb = repli procédural { name, ... } ou nil (ancres : le procédural existe déjà)
--   fbMax     nombre maximal d'exemplaires de repli procédural pour la famille
local DecorData = {}

DecorData.version = 1
DecorData.keyPrefix = "m:decor." -- clé de statut Assets : "m:decor.<famille>" (rapport F3 : catégorie « decor »)

-- Budgets (Parts). `blender` = pire cas réel des modèles posés (coût MESURÉ au chargement, pas le plafond) ; `fallback` = Parts procédurales de repli.
-- Surchargés par Config.Assets.decorBudgetParts / decorFallbackParts. Somme <= 1240 : la carte reste sous Config.Map.totalBudgetParts (7000) (marge mesurée : 7000 - 4990 = 2010 dans le calcul de tests/run.luau).
DecorData.budget = { blender = 1000, fallback = 240 }

-- Kiosque central (autre mission) : disque réservé au centre de la place, rien n'y est posé. Surchargé par Config.Map2.kiosk ou Config.KIOSK ({ x, z, r }).
-- Mesure du modèle hub_kiosk : socle de diamètre 15,4 -> rayon 7,7 ; marge de circulation comprise.
DecorData.kiosk = { x = 0, z = 0, r = 12 }

-- Emprises déjà posées par Builder.dressArena (bancs et lampadaires de la place, positions fixes) : { x, z, r }.
DecorData.existing = {
	{ -20, -28, 3 }, { 20, 24, 3 }, { -18, 26, 3 }, { 48, 18, 3 }, -- props.bench
	{ 30, -22, 2.5 }, { -12, -42, 2.5 }, { -52, 22, 2.5 }, { 54, 8, 2.5 }, -- props.lamp
}

-- Fixtures de la place du marché (rayons d'exclusion, studs) ajoutés à ceux lus dans Config.Map2 (fontaine, halle, étals, tapis, bac, piste, portails, arrivée,
-- enclos de la poule, Grand Œuf, arches des bases, secrets). Marge de circulation autour de chaque élément.
DecorData.plaza = {
	fountainMargin = 4, hallMargin = 4, stallRadius = 8.5, portalPad = 8, arrivalRadius = 7, henRadius = 6, runeRadius = 5, archRadius = 8, secretRadius = 14,
	beltPad = { x0 = 3, x1 = 8, z0 = 14, z1 = 8 }, -- rectangle du tapis : x0 - x0pad .. bin.x + x1pad ; z : -(width/2 + z0) .. width/2 + z1 (panneau du tapis au nord)
	trackPad = 5,
}

-- Modèles déjà branchés ailleurs (NE PAS les poser ici) : clé Config.Assets.models.<groupe>.<clé> pour chaque modèle des lots 15 à 17 concerné.
DecorData.wired = {
	house_lvl2 = "house.l2", house_lvl3 = "house.l3", house_lvl4 = "house.l4", house_lvl5 = "house.l5", house_lvl6 = "house.l6", house_lvl7 = "house.l7",
}

-- Libellés des panneaux (sign_base est livré SANS lettrage : le texte est ajouté par le code), par chemin de Config.Map2.paths.
DecorData.signLabels = {
	B1 = "🏠 Base 1", B2 = "🏠 Base 2", B3 = "🏠 Base 3", B4 = "🏠 Base 4", B5 = "🏠 Base 5",
	Castle = "🏰 Château", Arena = "⚔️ Arène", MillLake = "🎣 Lac du Moulin",
}
DecorData.signPaths = { "B1", "B2", "B3", "B4", "B5", "Castle", "Arena", "MillLake" }

-- Ordre de pose = priorité sur le budget (les ancres d'abord : elles remplacent des éléments déjà là).
DecorData.order = {
	"hub_dome", "grand_oeuf", "arena_colosseum", "conveyor_belt",
	"stall_a", "stall_b", "flag_banner", "lantern_post", "crate_stack", "barrel_pair", "hay_bale", "well_small", "bush_round", "sign_base",
	"island_sakura", "lily_pad", "reeds",
	"bench_park", "flowerbed", "well_roofed", "boulder_cluster",
	"tree_wide", "tree_autumn", "tree_fork", "tree_pine_tier", "tree_dead", "stump_roots", "log_hollow",
}

local function rect(x0, x1, z0, z1)
	return { x0 = x0, x1 = x1, z0 = z0, z1 = z1 }
end

local F = {}
DecorData.families = F

---------------------------------------------------------------- Lot 15 : ancres (superpositions d'éléments procéduraux, repli = l'élément procédural reste)
-- Dôme du hall : 60 x 60 x 24,4 ramené à la largeur du hall (2 r + 2) et posé sur les 8 piliers (haut 15). Masque les gradins procéduraux HallDome / HallDomeTop.
F.hub_dome = { id = 106786001814640, lot = 15, cap = 250, zone = "hall", y0 = 15, spanPad = 2, share = 0.25, hide = { "HallDome", "HallDomeTop" }, dims = { 60, 24.4, 60 } }
-- Grand Œuf : 13,6 x 15,7 ; hauteur du Grand Œuf de la carte (Map2.bigEgg.h), posé sur la marche du monument (y 2,1) ; masque la Part GrandNid (lumière et étincelles restent).
F.grand_oeuf = { id = 140225439366673, lot = 15, cap = 150, zone = "bigEgg", y0 = 2.1, share = 0.15, hide = { "GrandNid" }, dims = { 13.6, 15.7, 13.6 } }
-- Colisée : 70,8 x 21 ramené au diamètre de l'arène (2 r), devant tourné vers l'entrée ; masque ArenaWall et ArenaSteps (les murs procéduraux gardent la collision).
F.arena_colosseum = { id = 105443469311651, lot = 15, cap = 300, zone = "arena", y0 = 0, share = 0.30, hide = { "ArenaWall", "ArenaSteps" }, dims = { 70.8, 21, 70.8 } }
-- Tapis roulant : tuiles de 12 x 4,1 x 1,5 (long axe X) posées en `lanes` rangées sur la longueur du tapis, + conveyor_end à l'extrémité (côté bac). Hauteur du dessus
-- <= topY (sous le centre des œufs : Main.BELT_Y = 3, œuf de 3 de haut -> dessous à 1,5). TOUT OU RIEN : si le coût total dépasse la part, le tapis procédural reste.
-- Masque CentralBelt, BeltRail, BeltMark. Les dimensions de conveyor_end ne sont pas données par la spec : mêmes que la tuile (à vérifier dans Studio).
F.conveyor_belt = { id = 110718997928428, lot = 15, cap = 60, zone = "belt", topY = 1.3, share = 0.25, hide = { "CentralBelt", "BeltRail", "BeltMark" }, dims = { 12, 1.5, 4.1 }, endKey = "conveyor_end" }
F.conveyor_end = { id = 107430030694559, lot = 15, cap = 60, zone = "beltEnd", share = 0, dims = { 12, 1.5, 4.1 } }

---------------------------------------------------------------- Lot 16 : accessoires de marché
-- Étals décoratifs (sans fonction de jeu) en couronne de la place, de face vers le centre ; les 3 étals interactifs procéduraux restent intacts.
F.stall_a = { id = 121243958605530, lot = 16, cap = 90, zone = "plazaRim", ring = { 30, 53 }, count = 1, height = 8, r = 6, gap = 2, share = 0.08, fb = { name = "stall", awning = { 214, 90, 80 } }, fbMax = 2 }
F.stall_b = { id = 94658977878853, lot = 16, cap = 90, zone = "plazaRim", ring = { 30, 53 }, count = 1, height = 8, r = 6, gap = 2, share = 0.08, fb = { name = "stall", awning = { 90, 160, 214 } }, fbMax = 2 }
F.flag_banner = { id = 72351168707999, lot = 16, cap = 40, zone = "plazaRim", ring = { 40, 57 }, count = 6, height = 7, r = 1.6, gap = 6, share = 0.05, fb = { name = "flag" }, fbMax = 6 }
F.lantern_post = { id = 116378599429951, lot = 16, cap = 40, zone = "plazaRim", ring = { 30, 56 }, count = 6, height = 6.5, r = 1.4, gap = 8, share = 0.05, fb = { name = "lantern" }, fbMax = 6 }
-- Accessoires qui s'agglutinent autour des étals (décoratifs et procéduraux) : « satellites ».
F.crate_stack = { id = 72797022625881, lot = 16, cap = 30, zone = "stallSide", offset = { 10.5, 13 }, count = 4, height = 2.6, r = 1.8, gap = 1, share = 0.04, fb = { name = "crates" }, fbMax = 4 }
F.barrel_pair = { id = 102360413338352, lot = 16, cap = 30, zone = "stallSide", offset = { 10.5, 13 }, count = 3, height = 2.4, r = 1.8, gap = 1, share = 0.04, fb = { name = "barrels" }, fbMax = 3 }
F.hay_bale = { id = 99760241706274, lot = 16, cap = 20, zone = "stallSide", offset = { 10.5, 13.5 }, count = 4, height = 2.2, r = 1.6, gap = 1, share = 0.04, fb = { name = "hay" }, fbMax = 4 }
F.well_small = { id = 140033477297106, lot = 16, cap = 60, zone = "plazaRim", ring = { 30, 50 }, count = 1, height = 4.5, r = 2.6, gap = 3, share = 0.04, fb = { name = "well" }, fbMax = 1 }
-- lot 8B (intégration) : 3 buissons (et non 4) : avec le kiosque réel (14, 22, r 12) et le tapis Blender, la couronne n'offre que 3 places libres.
F.bush_round = { id = 72736930746142, lot = 16, cap = 25, zone = "plazaRim", ring = { 28, 57 }, count = 3, height = 2.4, r = 1.8, gap = 3, share = 0.04, fb = { name = "bush" }, fbMax = 4 }
-- Panneaux (livrés sans lettrage) : au premier point de chaque chemin hors de la place ; le libellé vient de `signLabels` (BillboardGui ajouté par le code).
F.sign_base = { id = 121260374584222, lot = 16, cap = 30, zone = "pathSign", signAfter = 66, count = 8, height = 4.5, r = 1.5, gap = 3, share = 0.04, fb = { name = "sign" }, fbMax = 8 }
-- Îlot de sakura au centre de chaque lac, à l'opposé du ponton ; nénuphars sur l'eau, roseaux sur la rive de sable.
F.island_sakura = { id = 77134124755209, lot = 17, cap = 220, zone = "lakeIsle", length = 16, r = 9, gap = 1, count = 2, y0 = 0.3, share = 0.12, fb = { name = "isle" }, fbMax = 2 }
F.lily_pad = { id = 108143670859973, lot = 16, cap = 12, zone = "lakeWater", length = 1.6, r = 1.2, gap = 1.5, count = 14, y0 = 0.94, share = 0.04, fb = { name = "lily" }, fbMax = 14 }
F.reeds = { id = 83409451845816, lot = 16, cap = 20, zone = "lakeShore", height = 4, r = 1.2, gap = 3, count = 14, y0 = 0.3, share = 0.05, fb = { name = "reeds" }, fbMax = 14 }

---------------------------------------------------------------- Lot 17 : décor de carte (nouvelles variétés)
F.bench_park = { id = 71149096082627, lot = 17, cap = 40, zone = "pathSide", pathMinPlaza = 72, step = 46, offset = 4, count = 6, height = 2.5, r = 2.2, gap = 4, share = 0.05, fb = { name = "bench" }, fbMax = 6 }
F.flowerbed = { id = 136250950680925, lot = 17, cap = 40, zone = "pathSide", pathMinPlaza = 70, step = 58, offset = 6, count = 6, height = 1.2, r = 2.6, gap = 3, share = 0.05, fb = { name = "flowerbed" }, fbMax = 6 }
F.well_roofed = { id = 77148661041685, lot = 17, cap = 120, zone = "region", region = rect(-330, 330, -215, 215), minPlaza = 85, count = 2, height = 8, r = 3.5, gap = 6, share = 0.06, fb = { name = "well" }, fbMax = 2 }
F.boulder_cluster = { id = 94606784141362, lot = 17, cap = 40, zone = "region", region = rect(-330, 330, -215, 215), minPlaza = 85, count = 5, length = 9, r = 5, gap = 4, share = 0.06, fb = { name = "rock" }, fbMax = 5 }
F.tree_wide = { id = 86295807080862, lot = 17, cap = 120, zone = "region", region = rect(-330, 330, -215, 215), minPlaza = 95, count = 5, height = 11, r = 5, gap = 4, share = 0.1, fb = { name = "tree", trunk = { 110, 76, 46 }, leaf = { 84, 150, 70 }, shape = "ball" }, fbMax = 5 }
F.tree_autumn = { id = 139640609512190, lot = 17, cap = 120, zone = "region", region = rect(-330, -90, -20, 215), minPlaza = 95, count = 5, height = 10, r = 4, gap = 4, share = 0.1, fb = { name = "tree", trunk = { 100, 70, 44 }, leaf = { 214, 120, 44 }, shape = "ball" }, fbMax = 5 }
F.tree_fork = { id = 134023676934024, lot = 17, cap = 120, zone = "region", region = rect(90, 330, 60, 215), minPlaza = 95, count = 4, height = 10, r = 4, gap = 4, share = 0.08, fb = { name = "tree", trunk = { 96, 68, 44 }, leaf = { 96, 160, 84 }, shape = "ball" }, fbMax = 4 }
F.tree_pine_tier = { id = 89102403219316, lot = 17, cap = 120, zone = "region", region = rect(-330, 200, -250, -215), minPlaza = 95, count = 6, height = 14, r = 3.5, gap = 3, share = 0.1, fb = { name = "tree", trunk = { 92, 64, 40 }, leaf = { 40, 110, 72 }, shape = "cone" }, fbMax = 6 }
F.tree_dead = { id = 110319726621538, lot = 17, cap = 80, zone = "region", region = rect(150, 340, -250, -120), minPlaza = 95, count = 4, height = 9, r = 3, gap = 4, share = 0.06, fb = { name = "tree", trunk = { 84, 70, 60 }, shape = "none" }, fbMax = 4 }
F.stump_roots = { id = 77105687594948, lot = 17, cap = 40, zone = "region", region = rect(-340, 340, -240, 240), minPlaza = 95, count = 6, height = 2.2, r = 2.6, gap = 3, share = 0.04, fb = { name = "stump" }, fbMax = 6 }
F.log_hollow = { id = 92331613804784, lot = 17, cap = 40, zone = "region", region = rect(-340, 340, -240, 240), minPlaza = 95, count = 4, length = 6, r = 3.2, gap = 3, share = 0.04, fb = { name = "log" }, fbMax = 4 }

---------------------------------------------------------------- Modèles inutilisés ici (documentés)
-- lots 18 et 19 (petits objets et gros meubles de maison) : intérieurs de maison, pas du décor de carte (autre mission).
-- scn_ile_sakura (lot 12, déjà dans Config.Assets.models.scenery mais jamais posé par Placement.VILLAGE) : island_sakura le remplace sur les lacs.

return DecorData
