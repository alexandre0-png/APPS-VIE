# Lot 8B-décor : notes d'intégration (fichiers nouveaux, NON intégrés)

> **INTÉGRÉ (lot 8B, 2026-11-26)** : les lignes ci-dessous ont été appliquées (Config, build_place.py, check.py, Main, Builder, Client, tests). État réel et écarts : `LOT8B_ECARTS.md`. Ce document reste comme référence technique.

Branche de worktree `worktree-agent-aaac9677ed96000d0`. Partie « fichiers nouveaux » du branchement des modèles Blender de décor de carte (lots 15, 16, 17 de Assets-crees). **Rien n'a été testé dans Roblox Studio** : placement, budgets, repli et nettoyage sont vérifiés par `tests/run_decor.py` (lupa, Lua 5.x, Roblox simulé) et par l'analyse statique de `check.py`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `src/ReplicatedStorage/DecorData.lua` | Données pures : 29 familles (id, plafond de Parts, zone de pose relative, taille cible, empreinte, quota, part de budget, repli), budgets, kiosque par défaut, emprises existantes |
| `src/ServerScriptService/Decor.lua` | `Decor.plan` (pur), `Decor.build(parent, G, config, deps)`, `Decor.refresh(handle)`, `Decor.clear(handle)`, `Decor.load` |
| `tests/decor.luau` + `tests/run_decor.py` | 93 assertions (calqué sur `run_lot10.py`) : `python3 roblox/tests/run_decor.py` |
| `BLENDER_REQUESTS.md` | Section « Lot 8B-décor » : réserves et nouvelles demandes de modèles |

## Ce qui est déjà branché (NON repris : pas de doublon)

`house_lvl2..7` = `Config.Assets.models.house.l2..l7` (lot 5, `Builder.applyBase`), arbres du lot 11 (`models.trees`, `Builder.dressWorld`), village du lot 12 (`models.scenery`, `Builder.dressScenery`). Les lots 18 et 19 (intérieurs de maison) ne sont pas du décor de carte. Les 12 modèles du lot 17 sont de **nouvelles variétés** : `well_roofed` s'ajoute aux 2 `scn_puits`, `boulder_cluster` aux `scn_rocher_*`, `island_sakura` pose sur les lacs l'îlot que `scn_ile_sakura` n'avait jamais reçu (`Placement.VILLAGE` ne le place pas).

## Lignes exactes à ajouter

### Config.lua, dans `Config.Assets` (après `decoBudgetParts = 420, ...`)

```lua
	decorBudgetParts = 1000, -- lot 8B-décor : Parts Blender du décor de carte (lots 15 à 17, Decor.lua), coût MESURÉ, budget SÉPARÉ posé après la carte
	decorFallbackParts = 240, -- Parts procédurales de repli de ce décor (modèle absent, refusé ou trop lourd)
	decorOff = {}, -- { famille = true } désactive une famille de DecorData (ex. { conveyor_belt = true, hub_dome = true })
```

Dans `Config.Map2` (kiosque central, autre mission) : `kiosk = { x = ?, z = ?, r = 12 },` (rayon d'exclusion = demi-diamètre du modèle 7,7 + circulation ; défaut de `DecorData.kiosk` = centre de la place, r 12). Alternative : `Config.KIOSK = { x, z, r }`.

### tests/run.luau (formule de budget, ligne ~2462)

```lua
check("Budget mobile : avec le décor et les accessoires, la carte reste sous le budget total", 1200 + 600 + Config.propsWorstCase() + 12 * Config.PLOT_COUNT * A.propsMaxParts.nest + A.decorBudgetParts + A.decorFallbackParts <= Config.Map.totalBudgetParts)
```

Marge mesurée : 1200 + 600 + 2470 + 720 = 4990, + 1240 = 6230 <= 7000.

### tools/build_place.py

Dans `SHARED` (fin de liste, avant `]`) : `("DecorData", "DecorData.lua")` ; dans `game_tree`, `ServerScriptService`, après la ligne `Scenery` :

```python
        item("ModuleScript", "Decor", read("ServerScriptService/Decor.lua")),
```

(Les projets Rojo sont par dossier : rien à changer. `check.py` [5/5] signale `Decor.lua` et `DecorData.lua` « absents » de `ChipeOeufs.rbxlx` et `DecorData.lua` de `Hub.rbxlx` tant que `build_place.py` n'est pas modifié et relancé : c'est attendu.)

### ServerScriptService/Assets : catégorie du rapport F3 (facultatif, `Assets.lua` `CATEGORY`)

`decor = "décor de carte"` (sinon la catégorie s'affiche « decor »).

### ServerScriptService/Builder.lua

En tête, avec les autres `require` :

```lua
local DecorMod = require(script.Parent:WaitForChild("Decor")) -- lot 8B-décor : modèles Blender des lots 15 à 17 (repli procédural)
```

Après `Builder.dressDeco` :

```lua
-- Décor de carte des lots 15 à 17 (dôme du hall, Grand Œuf, colisée, tapis, étals, arbres, lacs...) : Decor.lua charge ses modèles par lots parallèles (Assets.loadMany),
-- pose chaque exemplaire en modèle ou en repli procédural, dans World/BlenderDecor. Retourne (exemplaires, Parts Blender, Parts de repli).
local decorHandle = nil
function Builder.dressDecor(assets)
	local n, used, fallback = 0, 0, 0
	pcall(function()
		local world = workspace:FindFirstChild("World")
		local waited = 0
		while not world and waited < 30 do
			task.wait(0.25)
			waited = waited + 0.25
			world = workspace:FindFirstChild("World")
		end
		if not world then
			return
		end
		decorHandle = DecorMod.build(world, MapGeoMod.new(Config), Config, { assets = assets, placement = PlacementMod.new(Config), root = world, warn = warn })
		for _, l in ipairs(decorHandle.lines) do
			print(l)
		end
		n, used, fallback = #decorHandle.items, decorHandle.used, decorHandle.fallbackUsed
	end)
	return n, used, fallback
end

-- Hook onAssetsLoaded (facultatif) : reconstruit avec les modèles arrivés depuis ; un modèle déjà connu n'est jamais redemandé.
function Builder.refreshDecor()
	if decorHandle then
		pcall(function()
			decorHandle = DecorMod.refresh(decorHandle)
		end)
	end
end
```

### ServerScriptService/Main.server.lua

Dans la tâche de chargement des modèles, après la ligne `print("[Assets] château Blender : " ...)` et avant le dernier `onAssetsLoaded` :

```lua
	local dn, du, dfb = Builder.dressDecor(assets)
	print("[Assets] décor de carte (lots 15 à 17) : " .. dn .. " exemplaire(s), " .. du .. " Parts Blender (budget " .. Config.Assets.decorBudgetParts .. "), " .. dfb .. " Parts de repli")
```

`Decor.build` fait le chargement lui-même (`Assets.loadMany`, clés `m:decor.<famille>`) : aucune autre ligne `assets.loadGroup` n'est nécessaire. Si un décor précoce est souhaité (repli visible dès l'entrée), appeler `Builder.dressDecor` plus tôt avec `skipLoad = true`, puis `Builder.refreshDecor()` dans `onAssetsLoaded` après un chargement des modèles.

## Comportement (résumé)

- **Zones relatives** : couronne de la place du marché (étals décoratifs, bannières, lampadaires, puits, buissons), « satellites » autour des étals (caisses, tonneaux, bottes de foin), arbres et rochers sur des rectangles de la carte, bancs et parterres le long des chemins hors place, un panneau par chemin avec libellé (BillboardGui, le modèle est sans lettrage), îlots de sakura au centre de chaque lac à l'opposé du ponton, nénuphars sur l'eau, roseaux sur la rive.
- **Règles de pose** : `MapGeo.blocked` (eau, chemin, place, repère, arène, château, domaine, base, secret, plume, bord) + objets déjà posés (`Placement.plan`, forêt, village, décor fin passés par `deps.placement`) + bancs et lampadaires fixes de `Builder.dressArena` (`DecorData.existing`) + fixtures de la place (fontaine, halle, étals, tapis et bac, piste, pads de portails, arrivée, enclos de la poule, Grand Œuf, arches, secrets, `Config.Decor.reserved` facultatif) + **disque du kiosque central** (`Config.Map2.kiosk`, jamais entamé : testé avec 5 kiosques de position et rayon variés).
- **Ancres** (superposition d'un élément procédural, masqué en `Transparency = 1` **seulement si le modèle est posé**, collision conservée ; clear() rend la transparence) : `hub_dome` sur la halle (largeur 2 r + 2 = 38, y 15, masque `HallDome`/`HallDomeTop`), `grand_oeuf` (hauteur `bigEgg.h`, y 2,1, masque `GrandNid`, lumière et étincelles conservées), `arena_colosseum` (diamètre 2 r, devant vers l'entrée, masque `ArenaWall`/`ArenaSteps`), `conveyor_belt` + `conveyor_end` (tuiles en 2 rangées, dessus 1,3 sous le centre des œufs, masque `CentralBelt`/`BeltRail`/`BeltMark`). **Tout ou rien** : une tuile refusée annule toutes les autres ; coût total > part de budget = le tapis procédural reste. **Le tapis est ignoré si le disque du kiosque touche son rectangle** : avec le kiosque par défaut (centre de la place, r 12) le tapis procédural reste, donner la position réelle dans `Config.Map2.kiosk`.
- **Budgets** : Blender 1000 Parts (coût mesuré par `Assets.status[...].parts`, plafond de chaque famille = `share` x budget), repli 240 Parts et `fbMax` par famille, ancres prioritaires (ordre de `DecorData.order`).
- **Repli** : `LoadAsset` en échec, modèle vide ou trop lourd (refusé par `Assets.sanitize`), `Assets.place` refusé (mesure hors ±10 %) ou budget épuisé = repli procédural de 1 à 5 Parts par exemplaire (arbre, souche, tronc, rochers, banc, parterre, puits, lampadaire, étal, caisses, tonneaux, foin, buisson, panneau, bannière, roseaux, nénuphar, îlot). Ancres : l'élément procédural existant reste.
- **Nettoyage** : un `build` détruit le dossier précédent du même parent et rend les transparences ; `Decor.clear(handle)` détruit le dossier, rend les transparences, vide les listes (testé : 20 reconstructions, 0 fuite).

## Écarts et décisions

1. **Marché** : les 3 étals interactifs procéduraux (ProximityPrompt, panneaux) ne sont PAS remplacés par `stall_a/stall_b` : ces deux modèles servent d'étals décoratifs supplémentaires (1 de chaque).
2. **Tapis** : deux rangées de tuiles (12 x 4,1 x 1,5 ramené à 10,4 x 3,6 x 1,3) car une seule tuile mise à l'échelle sur la largeur (8) monterait à 2,9 de haut et noierait les œufs (centre y 3,0). Un modèle de 8 de large est demandé dans `BLENDER_REQUESTS.md`. Dimensions de `conveyor_end` supposées identiques à la tuile.
3. **Dôme** : le modèle livré (60 x 24,4) est ramené à la halle (38 de large, ~15,5 de haut) et remplace les gradins `HallDome` ; si le dôme devait couvrir 60 de large, à dire.
4. **Plafonds de Parts** (`cap`) estimés : le nombre de Parts réel des modèles est inconnu. Si le rapport F3 (catégorie « decor ») montre des refus « trop lourd », relever `cap` dans `DecorData` ; ajuster `decorBudgetParts` d'après les `parts` mesurés.
5. `Config.Assets.decor` existe déjà (catalogue du hub) : les surcharges portent donc d'autres noms (`decorBudgetParts`, `decorFallbackParts`, `decorOff`).
6. `A_FAIRE_UTILISATEUR.md` non modifié (consigne : fichiers nouveaux seulement) : à fusionner par la coordination, voir « À tester dans Studio ».

## À tester dans Studio (non testé)

- Rendu réel : échelle des 29 modèles (tolérance ±10 % de `Assets.fitHeight`), orientation (devant -Z) des étals, bannières, panneaux, bancs ; colisée orienté vers l'entrée ; dôme bien posé sur les piliers (y 15) sans trou ; Grand Œuf aligné sur la marche du monument.
- Masquage : `GrandNid` invisible mais lumière et étincelles toujours là ; gradins `HallDome` cachés ; murs d'arène solides ; tapis procédural invisible sous les tuiles, œufs bien visibles (dessus à 1,3 contre dessous d'œuf à 1,5).
- Panneaux : libellés BillboardGui lisibles (portée 70), pas masqués par le modèle.
- Nombre de Parts réel (F3), coût de chargement (29 `LoadAsset` en lots de 8, temps avant l'apparition du décor), 5 joueurs sur mobile (>= 30 FPS), StreamingEnabled (le dossier `BlenderDecor` est sous `World`).
- Nénuphars et roseaux : hauteur d'eau 0,94 supposée (`Scenery.lakes`) ; îlot : base à 0,3.
