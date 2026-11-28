# Lot GRAPHISMES (monde) : notes d'intégration

Branche de travail : worktree `agent-ad759c9687d71448f`, partie de `fa4e42b`. **Intégré le 2026-11-28** sur la tête `373ac7c` (après les lots 11 à 14, la refonte du combat et l'audit) par cherry-pick de `c4944d8` et `226f5ca` ; conflits résolus dans `run.luau` (suite du bouton contact gardée), `build_place.py` (`BattleLayout` et `Graphics` gardés), `CHANGELOG.md` et `A_FAIRE_UTILISATEUR.md`. Aucune modification de `Main.server.lua`, `BattleUi.lua`, `BattleLayout*`. Après intégration, mesures identiques (scène 4 254 Parts sans joueur, pic 4 413 avec 5 joueurs, contenus des lots 8B, 11, 12 compris), suite complète 4 431 / 0, `check.py` sans problème.
**Rien n'a été vu dans Roblox Studio** : aucun jugement visuel n'est porté ici. Seules des propriétés mesurables sont testées (nombres d'instances, distances, palettes, densités, zones bloquées, déterminisme).

## Ce qui est fait

1. **Lumière unifiée** : `Config.LIGHTING` (une palette chaude, 5 zones : `hub` = village et place, `plots` = parcelles, `arena` = colisée, `castle` = château, `lobby` = lieu Hub séparé).
   Chaque zone règle ambiance, atmosphère, bloom léger et étalonnage. `Graphics.checkLighting` (pur) valide : toutes les couleurs dans la bande de teinte chaude 20 à 50 degrés,
   écart de teinte entre deux zones <= 8 degrés, de saturation <= 0,08, de valeur <= 0,12, d'heure <= 1,8 h, de densité <= 0,10, de brume <= 0,6, bloom <= 0,40, saturation d'étalonnage <= 0,15.
   - Serveur : `Builder.setupLighting` applique la zone `hub` ; `HubWorld.setupLighting(Config)` applique `lobby` (repli sur les anciennes valeurs sans `Config.LIGHTING`).
   - Client : `Ambience.client.lua` glisse (2,5 s) vers la zone `Config.lightingZoneAt(x, z)` : horloge, ambiances, atmosphère (couleur, décroissance, densité, brume), étalonnage, bloom. La bannière de domaine garde `Config.zoneAt`.
   - `Config.Map.ambience` (violet de Mara, rouge de Zed) n'est plus lu par le client ; la table reste dans `Config` pour un ancien test (clés d'ambiance complètes).
2. **Chemins et herbe** (`Graphics.groundPlan`, posé par `Builder.dressGraphics`, appelé en fin de `dressDeco`, budget séparé de 700 Parts) :
   dalles de variation sur les chemins (couleurs voisines, matières Cobblestone / Slate / Pebble ou Ground / Mud, hauteurs sans face coplanaire), taches d'herbe irrégulières au bord (rayon 0,8 à 2 studs, 4 teintes),
   touffes isolées et grappes de fleurs (1 touffe + 3 à 5 fleurs) seulement près des chemins et de la place, sur sol libre (`MapGeo.blocked` nul, hors arbres et objets posés, y compris décor de village et décor fin).
   Plafonds : 240 dalles, 160 bordures, 110 touffes, 30 grappes ; densité <= 7 pièces par cellule de 20 x 20 studs. Les dalles ne sont pas posées sur un chemin dont les pavés ont été remplacés par des tuiles Blender (`Builder.blenderPaths`).
3. **Arbres** : `Placement.plan` pose désormais les arbres et sapins Blender **par groupes** (4, 3, 5, 2 en rotation, compagnons à 9 à 14 studs). `Placement.treePool` donne les modèles de la zone ;
   `Graphics.assignStyles` choisit pour chaque arbre un style (modèle x 4 classes de taille 0,75 / 0,95 / 1,15 / 1,40) en maximisant la distance au plus proche arbre de même style.
   Forêts procédurales (`Scenery.relief`) : 2 formes x 3 tailles x 3 teintes par palette (prairie / nord), **mêmes 2 Parts par arbre** qu'avant (carte procédurale inchangée : 1 153 Parts).
4. **Performance** : `LightLod.client.lua` (nouveau) allume au plus 4 `PointLight` (les plus proches, à moins de 90 studs, `Graphics.selectLights`) et coupe émetteurs, faisceaux, feux au-delà de 150 studs (rallumés sous 130,
   `Culling.decide`) ; il ne rallume que ce qu'il a lui-même coupé. Tout le contenu nouveau est dans un budget séparé de 700 Parts.

## Mesures (lupa, runtime factice, `python3 roblox/tests/run_graphics.py`)

| Mesure | Valeur | Limite |
|---|---|---|
| Écart de teinte entre zones | 5,8 degrés | 8 |
| Écart de saturation / valeur | 0,078 / 0,043 | 0,08 / 0,12 |
| Écart d'heure | 1,6 h | 1,8 |
| Arbres Blender : styles / modèles / classes de taille | 17 / 5 / 4 sur 28 arbres | >= 6 / 3 / 3 |
| Distance minimale entre arbres Blender de même style | 214,7 studs | 40 |
| Forêts procédurales : styles, distance minimale entre styles identiques | 32 sur 46 arbres, 407 studs | 24 |
| Sol : plan | 503 Parts (182 dalles, 62 bordures, 110 touffes, 30 grappes, 119 fleurs) | 700 |
| Sol : posé dans la scène du test (dalles des chemins Blender omises) | 408 Parts | 700 |
| Densité maximale | 6 pièces par cellule de 20 x 20 | 7 |
| Carte procédurale | 1 153 Parts | 1 200 |
| Parts de la scène sans joueur (avec le lot) | 4 254 (3 846 avant le lot : +408) | 7 000 |
| Pic de Parts avec 5 joueurs, 120 s de charge | 4 413 | 7 000 |
| PointLight dans la scène / allumées avec le LOD (60 caméras) | 67 / 4 au plus | 4 |

Note : le pic de référence « 3 944 » du lot 8B n'est pas reproductible à l'identique ici (la mesure de la base de départ donnait 3 846 sans joueur et 4 006 au pic de 600 s) ; le lot ajoute au plus son budget de 700 Parts, la marge restante jusqu'à 7 000 reste supérieure à 2 000.

## À vérifier visuellement en Studio (rien de ceci n'a été vu)

Voir `A_FAIRE_UTILISATEUR.md` §3octies. En résumé : la perception des transitions de zone (pas de saut de teinte), le bloom et la brume sur mobile, le rendu des dalles de chemin et des bordures d'herbe (hauteurs, z-fighting
éventuel avec les tuiles Blender), les touffes et fleurs (densité perçue, lisibilité), les arbres (tailles, groupes, silhouette des ellipsoïdes de feuillage des forêts procédurales), l'effet du LOD (lumières qui s'éteignent
derrière le joueur, scintillement éventuel), la fréquence d'images sur téléphone.

## Écarts avec la demande

- **Atmosphere + Bloom + ColorCorrection par zone** : faits côté client (par joueur) ; le serveur applique la zone `hub`. Le lieu Hub séparé a sa zone `lobby` (même palette chaude, crépuscule un peu plus tardif).
- **Arbres Blender** : le style joue sur le modèle et l'échelle (on ne recolore pas les modèles Blender : risque sur les textures). Les couleurs varient seulement sur les arbres procéduraux.
- **Décor de carte Blender (`Decor.lua`, lots 15 à 17)** : non inclus dans les obstacles du planificateur de sol ; le décor fin et le village le sont. Un chevauchement mineur d'une touffe avec un modèle de décor reste possible.
- **Tests de rendu** : impossibles ; remplacés par les propriétés mesurées ci-dessus.
- Le LOD de lumières est côté client, donc non exercé par le runtime factice (seuls le sélecteur pur et la présence des garde-fous dans le script sont testés).

## Graphismes 4 : halos d'œufs et bulles de protection (2026-11-28)

**Rien n'a été vu dans Studio.** Côté client uniquement (`StarterPlayerScripts/EggAura.client.lua`), logique pure testée dans `ReplicatedStorage/EggAura.lua` (`tests/eggaura.luau`, `python3 roblox/tests/run_eggaura.py`).
- Le serveur ne fait que publier des attributs : `Builder.egg` pose `Tier` et le tag `EggAura` sur chaque œuf (tapis, porté, posé, nid, vol) ; `refreshPad` pose `ShieldUntil` (bouclier du slot) ; `setNestEgg` pose `Guarded` (territoire avec gardiens : tous sauf l'enclos sauvage).
- Halo : une Part locale néon sphérique par œuf retenu, couleur = `Config.TIERS[t].color`, transparence 0,90 (rareté 1) -> 0,60 (rareté 10), amplitude 0,03 -> 0,16, période 3,6 -> 2,4 s, taille 1,22 -> 1,70 x l'œuf. Bulle : sphère locale en `ForceField` (transparence 0,2), bleutée (bouclier) ou dorée (nid surveillé), 2 x l'œuf.
- Budgets : **aucune PointLight** (le budget LightLod de 4 lumières allumées est inchangé) ; au plus 24 halos et 12 bulles (10 et 6 sur mobile), les plus proches de la caméra à moins de 110 studs ; sélection toutes les 0,25 s (0,5 s sur mobile), pulsation à 30 Hz (10 Hz sur mobile) ; réservoir d'objets réutilisés (au plus 24 en attente), Parts sans collision, toucher, requête ni ombre.
- Mesures (tests) : couleur = rareté pour les 10 raretés, visibilité strictement croissante, amplitude mesurée = amplitude du style, 600 images avec œufs qui apparaissent / disparaissent : jamais plus de 24 / 12 objets vivants, plus aucun objet attaché quand les œufs disparaissent, tout détruit à la désactivation ; bout en bout : attributs posés sur les nids (surveillés et non surveillés) et sur un œuf acheté (bouclier dans le futur).
- Écart : l'œuf garde sa PointLight d'origine (Builder.egg, avant ce lot, gérée par LightLod) ; les halos n'en ajoutent aucune.
