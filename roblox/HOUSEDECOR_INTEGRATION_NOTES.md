# Lot 8B-meubles : décor intérieur des maisons (NON INTÉGRÉ)

> **INTÉGRÉ (lot 8B, 2026-11-26)** : les lignes ci-dessous ont été appliquées (Config, build_place.py, check.py, Main, Builder, Client, tests). État réel et écarts : `LOT8B_ECARTS.md`. Ce document reste comme référence technique.

Statut : deux modules et leurs tests existent, ils ne sont branchés nulle part. Aucun fichier existant n'a été modifié. Rien n'a été joué dans Studio.

## Fichiers ajoutés

- `src/ReplicatedStorage/HouseDecorData.lua` : données pures. 24 modèles Blender (lots 18 et 19) répartis sur les 8 niveaux, `LEVELS[n]` = objets nouveaux au niveau n, `unlocked(n)` = décor cumulé, `budget(n)` = Parts réservées.
- `src/ServerScriptService/HouseDecor.lua` : `HouseDecor.apply(houseModel, level, config)`, `HouseDecor.clear(houseModel)`.
- `tests/housedecor.luau` et `tests/run_housedecor.py` : 50 assertions (lupa). Lancement : `python3 roblox/tests/run_housedecor.py`.

## Où appeler HouseDecor.apply (montée de niveau côté serveur)

Dans `src/ServerScriptService/Main.server.lua`, fonction `applyBase(s, celebrate, force)` (vers la ligne 868), juste après :

```lua
Builder.baseUpgrade(s.plot, level, rose and { animate = true } or nil)
```

La nouvelle maison est le modèle `s.plot.model:FindFirstChild("BaseUpgrade")` (créé par `Builder.baseUpgrade`, `WorldPivot = plot.cf`). Appel suggéré, hors de la boucle principale car `LoadAsset` cède la main :

```lua
local house = s.plot.model:FindFirstChild("BaseUpgrade")
if house then
	task.spawn(function()
		local ok, err = pcall(HouseDecor.apply, house, level, { offset = HOUSE_DECOR_OFFSET })
		if not ok then warn("HouseDecor : " .. tostring(err)) end
	end)
end
```

Comportement attendu :
- Montée animée : l'ancienne maison est renommée `BaseUpgradeOld` et reste visible pendant l'effet. Le décor va sur la nouvelle maison, `finishUpgrade` la remet à l'échelle et le décor suit.
- Reconstruction (`force`, arrivée des modèles Blender dans `onAssetsLoaded`) : la maison est neuve, `apply` pose tout le cumul. Un second appel sur la même maison ne crée rien (idempotent).
- Démolition : `Builder.clearBase` détruit le modèle, le décor part avec. `HouseDecor.clear` n'est nécessaire que pour un effacement sans reconstruction.
- Le niveau 1 (enclos de bois) reçoit 3 objets. À confirmer : la fiche ne bloque pas ce choix, mais un enclos de bois peut ne pas accepter un tapis.

## Repère à valider dans Studio (écart non résolu)

Les positions de la fiche sont relatives au centre de la maison au sol. Le repère réel dépend du modèle :

- Maison procédurale (`Builder.proceduralHouse`) : le socle et les murs sont centrés en `(0, 1.6, zc)` dans le repère de `plot.cf`, avec `zc = backZ - 1 - depth / 2` (Builder.lua ligne 1072). `zc` dépend du niveau. Il faut donc passer `offset = { 0, 1.6, zc }`, et `Builder` doit exposer `zc` (ou le centre) : c'est la première chose à faire avant d'intégrer.
- Modèles Blender `house.l2` à `l7` (bâtiment à l'arrière, entrée côté -Z) et `base.level1` / `base.level8` (emprise centrée) : leur origine n'est pas connue. Les positions de la fiche supposent un bâtiment centré, entrée en -Z. À vérifier.
- Emprise : `|x|` et `|z|` restent dans 18 studs (`HouseDecorData.REACH`). La plus petite maison fait 52 studs.

## Lignes à ajouter à `tools/build_place.py` (non faites : fichier interdit à ce lot)

Dans la liste `SHARED` (ligne 24 à 26), ajouter :

```python
("HouseDecorData", "HouseDecorData.lua"),
```

Dans la liste `ServerScriptService` (ligne 43 à 51), ajouter :

```python
item("ModuleScript", "HouseDecor", read("ServerScriptService/HouseDecor.lua")),
```

Puis relancer `python3 roblox/tools/build_place.py`. `HouseDecor` charge la fiche par `ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HouseDecorData")` : la ligne `SHARED` est obligatoire. Vérifier aussi que `default.project.json` et `game.project.json` (Rojo) incluent ces deux fichiers (non vérifié).

## Budget et chargement

- Parts : `parts` réservé par objet (4 pour un petit, 8 pour un gros). Niveau 8 : 136 Parts réservées, plafond 150. Repli : une Part par objet, 24 au total. Les `parts` sont des estimations : à mesurer dans Studio (nombre de descendants de chaque modèle chargé) puis à corriger dans la fiche.
- Assets : 24 IDs des lots 18 et 19 (`scratchpad/Assets-crees-fresh.md`). `InsertService:LoadAsset` doit pouvoir les charger depuis le serveur (propriété du compte ou accès public). Sans cela, chaque objet tombe en repli sans erreur.
- Cache : un `LoadAsset` par ID et par session ; un échec est mémorisé pour la session (pas de nouvelle tentative).
- Mise à l'échelle : uniforme, le modèle tient dans la boîte `size` et touche au moins une dimension.

## Limites des tests

- Le faux Roblox ignore la rotation des `CFrame` : les tests vérifient positions, cumul, budget, repli, cache, idempotence, nettoyage et garde contre la course pendant le chargement. Ils ne vérifient pas l'orientation des modèles.
- Les chevauchements sont vérifiés sur les coordonnées de la fiche, pas sur la géométrie réelle des maisons (murs, porte, escalier).
- Garde-fou vérifié : en retirant les deux protections contre les doublons, 9 assertions échouent. En retirant le centrage des modèles chargés, 1 assertion échoue.

## État de `tools/check.py` sur cette branche

- Mes deux modules ne figurent pas encore dans `build/*.rbxlx` : échecs « absent ou périmé » tant que `build_place.py` n'est pas mis à jour (4 lignes, ChipeOeufs et Hub).
- Déjà présents avant ce lot : `Calendar.lua` et `Config.lua` périmés dans les deux `.rbxlx`, et un échec du test Config « Plan : pièces = minutes de revenu (plancher 500) » (lot 9b).
