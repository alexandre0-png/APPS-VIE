# Modèles Blender à créer (demandes de Chipe-Œufs)

À relire à chaque lot. Le code les charge déjà par `Config.Assets` (serveur, `InsertService:LoadAsset` sous pcall avec délai, scripts retirés, un seul chargement par modèle puis clonage, plafond de Parts, **repli procédural conservé**). Dès qu'un modèle est téléversé : donner son identifiant, il sera ajouté sous la clé indiquée.

## Convention (obligatoire)
- Une pièce = un objet séparé nommé `Nom__RRGGBB` (hexadécimal, majuscules ou minuscules). Le code lit le suffixe et applique la couleur ; **les couleurs du FBX sont ignorées**. Sans suffixe, la pièce garde son aspect.
- Les petits détails (arête la plus longue < 0,6 stud) ne projettent pas d'ombre automatiquement.
- Unité : 1 unité Blender = 1 stud sauf mention. Orientation : le **devant regarde vers -Z** (Roblox) ; origine au centre du socle. Le code remet le modèle à l'échelle d'après sa hauteur (ou sa longueur pour les ponts) : donner des proportions justes plutôt qu'une taille exacte.
- Budget de pièces (le chargeur refuse un modèle plus lourd) : voir la colonne « Pièces max ». Moins de pièces = mieux sur téléphone.
- Pas de scripts, pas de sons dans les modèles (retirés).

## Déjà intégrés (merci)
Œufs par rareté (Commun, Rare, Épique, Légendaire, Mythique, Secret), pets (Poussin, Lapin, Renard, Panda, Dragonnet, Fantôme), Arbre, Sapin, Rocher, Buisson, PontBois, Cabane, Barrière, Fontaine, NidOeufs.

## À créer
| Clé de config | Modèle | Taille (studs) | Pièces max | Description | Couleurs (suffixes) | Parties séparées nommées |
|---|---|---|---|---|---|---|
| `props.mill` | Moulin à vent | 18 haut, 10 large | 60 | Tour en briques claires, toit pointu rouge, 4 pales en bois (pales = pièce `Pales`, tournent côté code) | tour `E2D2B2`, toit `A04830`, pales `F5EBD7` | `Tour__E2D2B2`, `Toit__A04830`, `Pales__F5EBD7`, `Porte__785028` |
| `guards.dog` | Chien de garde (Gus) | 3 haut, 5 long | 40 | Chien trapu, oreilles tombantes, collier ; pose neutre, pattes séparées (animation par code) | corps `A0784A`, collier `E0574F`, nez `1E1E1E` | `Corps`, `Tete`, `Oreille_G`, `Oreille_D`, `Patte_AvG`, `Patte_AvD`, `Patte_ArG`, `Patte_ArD`, `Queue`, `Collier` |
| `guards.wolf` | Loup (Mara) | 4 haut, 7 long | 50 | Loup gris, museau long, yeux jaunes brillants, queue touffue | corps `8C8C99`, ventre `D6D6DE`, yeux `FFD23F` | mêmes pièces que le chien + `Yeux` |
| `guards.bear` | Ours gardien (Zed) | 6 haut, 6 large | 50 | Ours massif en armure légère, épaulières métalliques | corps `5A3C28`, armure `6E7280`, yeux `FF5050` | `Corps`, `Tete`, `Bras_G`, `Bras_D`, `Jambe_G`, `Jambe_D`, `Armure`, `Yeux` |
| `guards.knight` | Garde du château (mode Château) | 6 haut | 60 | Soldat de pierre avec lance et bouclier | armure `7A7F8C`, plume `D63A3A`, bouclier `C9A227` | `Corps`, `Casque`, `Lance`, `Bouclier`, `Bras_G`, `Bras_D`, `Jambe_G`, `Jambe_D` |
| `props.castle` | Château (extérieur du mode Château) | 60 haut, 80 large | 150 | Enceinte, 4 tours rondes, porte levante, drapeaux | pierre `8E93A0`, toits `7A2A2A`, porte `5A3C28` | `Mur`, `Tour_1..4`, `Toit_1..4`, `Porte`, `Drapeau_1..4` |
| `castle.wall` | Mur de château (module) | 8 long, 8 haut, 2 épais | 12 | Segment de mur crénelé, bords droits (assemblable) | `8E93A0` | `Mur`, `Creneaux` |
| `castle.tower` | Tour de château (module) | 14 haut, 6 large | 25 | Tour ronde crénelée, meurtrières | `8E93A0`, toit `7A2A2A` | `Corps`, `Creneaux`, `Toit` |
| `castle.door` | Porte à timing (piège) | 8 large, 8 haut | 15 | Herse métallique qui monte et descend (pièce `Herse` animée par code) | herse `4A4A52`, cadre `6B5A44` | `Cadre`, `Herse` |
| `castle.floor` | Dalle de salle | 8 x 8, 0,6 épais | 6 | Dalle de pierre usée, joints visibles (assemblable) | `A7ABB5`, joints `6E7280` | `Dalle` |
| `trap.spikes` | Pics (piège) | 6 x 6, 2 haut | 20 | Plaque avec 9 pics métalliques (pièce `Pics` animée vers le haut) | plaque `55555F`, pics `C8CCD6` | `Plaque`, `Pics` |
| `trap.blade` | Lame tournante (piège) | 10 de diamètre, 1 épais | 15 | Scie circulaire sur un bras | lame `D0D4DE`, bras `4A4A52` | `Bras`, `Lame` |
| `trap.ball` | Boulet roulant (piège) | 6 de diamètre | 8 | Boulet de pierre avec bandes de fer | pierre `7A7F8C`, fer `3A3A42` | `Boulet`, `Bandes` |
| `props.chest` | Coffre (récompense du château) | 3 x 2 x 2 | 14 | Coffre en bois cerclé d'or, couvercle séparé (s'ouvre par code) | bois `96622C`, or `E8B923` | `Corps`, `Couvercle`, `Serrure`, `Bandes` |
| `props.torch` | Torche murale | 4 haut | 8 | Support métal + flamme (pièce `Flamme` émissive) | support `4A4A52`, flamme `FF9640` | `Support`, `Flamme` |
| `props.flag` | Drapeau | 8 haut | 8 | Mât + toile rectangulaire | mât `785028`, toile `D63A3A` | `Mat`, `Toile` |
| `props.sign` | Panneau | 5 haut | 8 | Poteau + planche | bois `785028` | `Poteau`, `Planche` |
| `props.pen` | Enclos de base du joueur | 40 x 40, 4 haut | 100 | Clôture de bois autour de la base, entrée au nord, 4 poteaux d'angle | bois `96622C`, liseré `FFD23F` | `Cloture_N/E/S/O`, `Poteau_1..4` |
| `ground.grass` | Tuile d'herbe | 16 x 16, 0,5 épais | 4 | Herbe avec touffes et fleurettes (assemblable, bords raccord) | herbe `5CA052`, fleurs `FFD23F`/`FF7896` | `Herbe`, `Touffes`, `Fleurs` |
| `ground.path` | Tuile de chemin | 8 x 8, 0,3 épais | 4 | Chemin de terre avec cailloux | terre `C4B494`, cailloux `8E93A0` | `Terre`, `Cailloux` |
| `ground.plaza` | Dalle de place (hub) | 12 x 12 | 6 | Pavés ronds clairs | `C4B8A0` | `Paves` |
| `props.lamp` | Lampadaire | 8 haut | 10 | Mât métal, lanterne chaude (pièce `Lanterne`) | mât `32343C`, lanterne `FFEBAA` | `Mat`, `Lanterne` |
| `props.bench` | Banc | 2 haut, 6 long | 8 | Banc en bois | `96622C` | `Assise`, `Dossier`, `Pieds` |
| `pets.*` (suite) | Pets restants (12 espèces) | ~1 de haut | 40 | Hamster, Chat, Chien, Hibou, Manchot, Lion, Tigre, Licorne, T-Rex, Kraken, Calmar stellaire, Wyrm astral | une couleur dominante par espèce | `Corps`, `Tete`, `Yeux`, `Oreilles`, `Queue`, `Pattes` |

Quand les modèles sont téléversés, indique pour chacun : identifiant, clé de la table ci-dessus. Les clés `guards.*`, `castle.*`, `trap.*`, `ground.*` seront branchées avec les mécaniques correspondantes (gardiens, mode Château).

## Demandes de qualité visuelle (retours de test réels) : à créer

Palette limitée à respecter (une couleur par rôle, suffixes `Nom__RRGGBB`) : herbe `5CA052` et `4B8E45`, terre `C4B494`, pierre `8E93A0` et `6E7280`, bois `96622C` et `6E4C2E`, eau `3C96DC`, or `FFCD46`, feuillage `3E8E44` et `5CB256`, accent rouge `C8323C`. Matières : tout en plastique lisse, sauf `Lame`, `Pics`, `Herse`, `Anneau`, `Tige`, `Serrure`, `Poignee`, `Fer`, `Cercles` (métal) ; aucun reflet. Bords arrondis (bevel de 0,1 à 0,2 stud) sur tous les blocs ; au moins deux nuances et un détail (joints, nœuds, mousse, ombre peinte) par pièce.

| Clé de config | Modèle | Taille (studs) | Pièces max | Description | Couleurs (suffixes) | Parties séparées nommées |
|---|---|---|---|---|---|---|
| `deco.flower_a`, `deco.flower_b`, `deco.flower_c` | Fleurs (3 variantes) | 1 haut | 6 | Touffe de 3 fleurs, tiges fines | pétales `FF789A` / `FFD23F` / `FFFFFF`, tige `3E8E44`, cœur `FFB347` | `Petales`, `Tige` |
| `deco.tuft` | Touffe d'herbe | 1,2 haut | 4 | Brins d'herbe en gerbe, deux verts | `5CA052`, `4B8E45` | `Brins` |
| `deco.stone_flat`, `deco.stone_round` | Pierres plates et rondes | 0,6 haut, 2 large | 4 | Pierre arrondie, mousse sur le dessus | `8E93A0`, mousse `5CA052` | `Pierre`, `Mousse` |
| `deco.lantern` | Lanterne posée | 1 haut | 6 | Lanterne de pierre au sol, flamme chaude | pierre `8E93A0`, flamme `FFE9A8` | `Pierre`, `Flamme` |
| `deco.sign_stars` | Panneau de difficulté | 5 haut, 3 large | 10 | Poteau, planche rectangulaire, 5 étoiles creusées (étoiles = pièces `Etoile1` à `Etoile5` recolorées par code) | bois `96622C`, étoiles `FFCD46` | `Poteau`, `Planche`, `Etoile1`..`Etoile5` |
| `terrain.cliff_a`, `terrain.cliff_b` | Falaise en terrasse (module) | 16 long, 8 haut, 6 épais | 14 | Bloc de falaise voxel/low-poly, haut herbeux, flanc de roche stratifiée, bords nets, assemblable | roche `8E93A0` / `6E7280`, herbe `5CA052`, terre `C4B494` | `Roche`, `Herbe` |
| `terrain.cliff_corner` | Angle de falaise | 12 x 12, 8 haut | 14 | Angle extérieur, mêmes teintes | idem | `Roche`, `Herbe` |
| `terrain.stairs` | Escalier de terrasse | 8 large, 8 haut, 12 long | 12 | Marches en pierre et terre entre deux niveaux | `C4B494`, `8E93A0` | `Marches` |
| `terrain.waterfall` | Cascade | 8 large, 10 haut | 10 | Chute d'eau le long d'une falaise, écume (écume = pièce `Ecume`, Neon blanc) | eau `3C96DC`, écume `FFFFFF` | `Eau`, `Ecume` |
| `terrain.islet` | Îlot | 24 de diamètre, 4 haut | 12 | Petite île ronde, un arbre, deux rochers, rive nette | herbe `5CA052`, roche `8E93A0`, tronc `6E4C2E` | `Herbe`, `Roche` |
| `props.bridge_rail` | Pont en bois à rampes | 18 long, 6 large, 2,5 haut | 30 | Planches, deux rampes, poteaux d'extrémité qui s'enfoncent dans les rives | bois `96622C`, poteaux `6E4C2E` | `Planches`, `Rampes` |
| `props.fence_corner`, `props.fence_gate` | Barrière d'angle et portillon | 3 haut | 10 | Angle à 90° et portillon s'ouvrant sur le chemin | bois `96622C` | `Poteaux`, `Lisses` |
| `props.hut_small`, `props.hut_big` | Petite et grande cabane | 7 et 11 haut | 60 / 90 | Toit à deux pans, porte, fenêtre, cheminée ; entrée côté -Y Blender | murs `C9A66B`, toit `B04A3C`, porte `6E4C2E` | `Murs`, `Toit`, `Porte` |
| `base.level1` à `base.level8` (facultatif) | Enclos, cabane, chaumière, maison, manoir, fort, forteresse, château doré | 52 x 52 d'emprise, 4 à 24 haut | 40 à 140 | Les 8 apparences de la base (voir `Config.BASE_LEVELS`) ; entrée côté -Y Blender, arrière +Y, pad de 52 x 52 laissé libre | palette ci-dessus, or `FFCD46` pour le niveau 8 | `Murs`, `Toit`, `Tours` |

## npc.raven (lot 7, optionnel)

Corbeau du vol à distance : modèle `Config.Assets.models.npc.raven` (aucun ID pour l'instant). Repli procédural de 6 Parts déjà en place (`Builder.raven`) ; devant = -Z, moins de 30 Parts, ailes séparées.

## Lot 8B-décor : décor de carte (lots 15, 16, 17 branchés par `Decor.lua`, non intégrés) : réserves et demandes

Les 29 modèles des lots 15 (hors maisons déjà branchées), 16 et 17 sont chargés par `ServerScriptService/Decor.lua` (données : `ReplicatedStorage/DecorData.lua`, clés de statut `m:decor.<famille>`) avec repli procédural par famille. Aucun modèle n'est **manquant** (tous les identifiants sont utilisés), mais le nombre de Parts réel des modèles n'est pas connu (aucune mesure sans Studio) : les plafonds de `DecorData` sont des estimations (arbres 120, colisée 300, dôme 250, tapis 60...). Tout modèle plus lourd est refusé au chargement et son repli procédural prend le relais (rapport F3, catégorie « decor »).

| Clé (famille de DecorData) | Modèle demandé | Taille (studs) | Pièces max | Description | Couleurs (suffixes) | Parties séparées nommées |
|---|---|---|---|---|---|---|
| `conveyor_belt_wide` (nouveau) | Tuile de tapis roulant de la largeur du tapis du marché | 12 long (axe X), 8 large, 1,3 haut | 20 | Remplace `conveyor_belt` (12 x 4,1 x 1,5) : une seule rangée de tuiles, sans les deux rangées côte à côte que le code doit aujourd'hui simuler. Dessus **sous 1,5** (le centre d'un œuf est à y = 3,0, l'œuf mesure ~3 de haut : `Main.BELT_Y`) ; bords latéraux ambrés | acier `343842`, rails `FFC440` | `Tapis`, `Rails` |
| `conveyor_end` (re-livraison) | Bout de tapis (côté bac) | 12 x 1,3 x 8 | 20 | Défaut d'ombrage signalé à la livraison du lot 15 ; dimensions réelles non fournies (le code suppose les mêmes que la tuile) : donner les vraies | idem | `Tapis`, `Rails` |
| `sign_base` (facultatif) | Panneau avec une face plane nommée | 4,5 haut | 30 | Aujourd'hui livré sans lettrage : le texte (« Base 1 », « Château »...) est ajouté par une `BillboardGui` au-dessus du modèle. Une pièce `Planche` plane permettrait un `SurfaceGui` collé au bois (meilleur rendu) | bois `96622C` | `Poteau`, `Planche` |
| `hub_dome` (à confirmer) | Dôme du hall au bon gabarit | 36 x 36 x 15 (socle sur 8 piliers de 15 de haut) | 120 | Le modèle livré mesure 60 x 60 x 24,4 : le code le ramène à 38 de large (hall de 18 de rayon + 2) soit ~15,5 de haut ; si le dôme devait couvrir une zone de 60, dire laquelle | tuiles `B05A46`, bague `FFD678` | `Dome`, `Bague` |
| `arena_colosseum` (à confirmer) | Orientation de l'entrée | 70,8 x 21 | 300 | Le code tourne le **devant (-Z)** vers l'entrée de l'arène (`Config.Map2.arena.entry`) : confirmer que l'ouverture du colisée est bien à l'avant, sinon fournir l'ouverture sur -Z | pierre `D2C1A0` | `Murs`, `Arcs`, `Gradins` |
| `grand_oeuf` (facultatif) | Runes pulsables | 13,6 x 15,7 | 150 | Les pièces `Flamme_Rune*` pourraient pulser par code (comme les pierres runiques) : confirmer qu'elles sont bien des pièces séparées, une par rune | pierre `B0A890`, runes `FF9640` | `Oeuf`, `Flamme_Rune1`.. |
| `house_lvl4`, `house_lvl5` (déjà branchés, lot 5) | Portail de garage (lvl4) ; terrasse de référence (lvl5) | idem | idem | Éléments signalés manquants à la livraison du lot 15 (pas du ressort de `Decor.lua`) | idem | idem |

Non repris par `Decor.lua` : lots 18 et 19 (intérieurs de maison, autre mission). Pas de doublon fonctionnel avec le village du lot 12 : `well_roofed` (2) s'ajoute aux 2 `scn_puits`, `boulder_cluster` aux `scn_rocher_*`, `island_sakura` pose sur les lacs l'îlot que `scn_ile_sakura` n'avait jamais reçu (non placé par `Placement.VILLAGE`).

## Mobs : style unique (inventaire d'après le code et les docs, aucun rendu vu)

Base : lecture de `Builder.lua`, `Scenery.lua`, `Castle.lua`, `BattleScene.lua`, `Client.client.lua`, `Config.lua`, `CHANGELOG.md`, ce fichier. Je n'ai vu aucune image : les contrastes sont déduits des formes, matières et couleurs écrites dans le code, pas jugés à l'œil. Aucun test de « galerie » de mobs n'existe dans `tests/` ni dans les outils (recherche faite) : rien n'est vérifié automatiquement sur la cohérence de style des monstres. Aucun identifiant nouveau, aucun code de jeu modifié.

### État après « Fais les mobs » (2026-11-28, rien vu dans Studio)
- **Créatures de combat** : le combat clone désormais le MÊME modèle Blender que le monde (copie légère publiée par le serveur dans `ReplicatedStorage.PetModels`, au plus 40 Parts, `Builder.exportPets`) ; repli procédural si absent, trop lourd ou hors budget. Le gabarit `combat.puppet` demandé plus bas n'est donc plus nécessaire tant que les modèles de pets tiennent sous 40 Parts.

### Inventaire factuel (comment chaque mob est construit aujourd'hui, au commit e0e97d6 ; voir l'état ci-dessus pour ce qui a changé)

| Mob | Où | Construction aujourd'hui | Repli | Remarques de style |
|---|---|---|---|---|
| Gardiens Gus (domaine 1), Mara (2), Zed (3) | monde, `Builder.guard` ; Blender `guards.dog` / `wolf` / `bear` (ids dans `Config.Assets.models.guards`, branchés par `Builder.dressGuards`) | Blender approuvé (un modèle par gardien), mis à l'échelle sur `Config.Assets.guardHeights` (2,5 / 3 / 5 studs) ; le `Body` procédural reste invisible (repère, étiquette) | Procédural identique pour les 3 : tronc en bloc 3 x 2,4 x 4,4, **tête et yeux en sphères**, museau, oreilles et pattes en blocs, yeux Neon rouges ; seule la couleur change (`Config.RIVALS[i].color`) | Mélange blocs + sphères dans le repli ; trois bêtes différentes (chien, loup, ours en armure) mais le repli donne le même animal trois fois |
| Chevaliers du château (salles 3 à 5) | monde, `Scenery.lua` (pilote), Blender `guards.knight` (`Builder.dressKnights`, hauteur 4,5) | Blender approuvé ; pilote = un seul bloc Metal 3 x 6 x 3 (gris `969CAA`) rendu invisible une fois le modèle posé | **Aucun repli de forme** : sans modèle, le joueur voit un parallélépipède métallique nu (le seul mob sans silhouette) | Pierre/métal brillant quand le reste du donjon est en plastique lisse ; hauteur Config 4,5 contre 6 demandée plus haut dans ce fichier |
| Pièges (pics, lame, boulet) | monde, `Scenery.lua` + `Builder.dressTraps` | Blender si chargé, sinon blocs / cylindre / sphère Metal ou Slate | procédural | Pas des mobs de combat : hors périmètre, cités pour le contraste de matières (Metal brillant, seules pièces métalliques autorisées par la palette) |
| Créatures de combat (joueur et adversaires de la tour, de l'arène, des PNJ, boss de la tour) | client, `BattleScene.buildPuppet` | **Toujours procédural** (le client n'a pas accès aux modèles Blender : noté au CHANGELOG, écart du lot de refonte) : corps **sphère**, yeux, oreilles « round » en sphères ou « point / long / floppy » en blocs, bec en bloc, queue en sphère | aucun (c'est déjà le repli) ; 5 formes d'oreilles et 2 extras seulement (`beak`, `tail`) sur les 78 espèces | Même pet vu au monde en Blender (blocs séparés Corps / Tête / Pattes...) et en combat en boule : contraste de style le plus fort du jeu. Aucun boss n'a de modèle propre : les 9 boss de la tour (`Config.TOWER.bosses`) sont de simples équipes de pets avec un nom |
| Pets en monde (suivants, bases) | `Builder.pet`, Blender `Config.Assets.pets` + `petsNew` (Bestiary, 60 modèles, plafond 40 Parts) | Blender approuvé pour 14 espèces historiques sur 18 + 60 espèces du Bestiaire | Procédural : corps sphère, yeux/joues/pieds en sphères, 16 extras (cornes, ailes, tentacules, segments, cristaux...) | Repli entièrement lisse (sphères) ; Tigre, Kraken, Calmar stellaire, Wyrm astral n'ont pas de Blender |
| PNJ de combat (Lina, Bruno, Maître Kaï) et PNJ d'échange (Pip, Nora) | client, `Client.client.lua` (`L15.buildModel`) ; Blender `npc.*` (ids dans `Config.Assets.models.npc`) | Blender approuvé, remis à 6 studs de haut (`Config.NPC_VIEW.height`) | Corps bloc 2,2 x 3,2 x 1,4 teinté + **tête sphère** (2 Parts) | Humanoïdes : hors du style « bête » ; leur équipe de combat est faite de pets (voir ligne créatures) |
| Corbeau chipeur | monde, `Builder.raven` | Aucun Blender (clé `npc.raven` sans id) | 6 blocs (corps, tête, bec, 2 ailes, queue), sombre `1C1C24` | Tout en blocs, sans sphère |
| Mère Poule | monde, `Builder.hen` | Procédural uniquement, 14 Parts : corps et tête en sphères, crête, ailes, pattes, bec en blocs | aucun | PNJ de décor, pas un mob de combat ; mélange sphères + blocs |

### Mélanges de styles et contrastes repérés

1. **Combat contre monde** (le plus fort) : en monde les pets et gardiens sont des modèles Blender à pièces séparées ; en combat, les mêmes créatures sont des boules à oreilles (`BattleScene.buildPuppet`). Le joueur voit deux « langages » pour le même pet.
2. **Repli procédural des gardiens** : sphère (tête, yeux) posée sur un tronc en bloc, identique pour Gus, Mara et Zed (seule la teinte change) ; les modèles Blender sont trois animaux distincts.
3. **Chevalier** : modèle Blender (pierre, lance, bouclier) mais repli = bloc métallique nu ; métal brillant dans un décor en plastique lisse.
4. **Parts numériques contre demandes** : tailles et budgets réels (`guardHeights` 2,5 / 3 / 5 / 4,5 ; `modelsMaxParts` 80 / 80 / 90 / 100) diffèrent du tableau « À créer » plus haut (3 / 4 / 6 / 6 studs ; 40 / 50 / 50 / 60 Parts) : le code a été calé sur les modèles livrés, pas sur la demande.
5. **Humanoïdes contre bêtes** : PNJ, chevalier et gardien « ours en armure » sont les seuls bipèdes ; tout le reste est quadrupède ou sphérique.
6. **Matières** : seuls les pièges et le pilote du chevalier utilisent Metal / Slate ; tout le reste est SmoothPlastic, conforme à la règle de palette.

### Style cible proposé : UN seul style pour les monstres de combat

**Blocs arrondis en plastique lisse, une pièce par membre, couleurs plates.**

Pourquoi (d'après les docs, pas d'après un rendu) : tous les modèles Blender approuvés des lots documentés suivent cette convention écrite ci-dessus : « tout en plastique lisse », « bords arrondis (bevel de 0,1 à 0,2 stud) sur tous les blocs », une couleur par rôle (suffixe `Nom__RRGGBB`), pièces séparées nommées pour l'animation par code (`Corps`, `Tete`, `Patte_*`...). C'est le cas des gardiens (lot 1 : `Corps`, `Tete`, `Oreille_*`, `Patte_*`, `Queue`), du château (lot 3 : murs, tours, coffre, torches, `Armure`, `Bouclier`), des pets (lots 4 et 11 : `Corps`, `Tete`, `Yeux`, `Oreilles`, `Queue`, `Pattes`, plafond 40 Parts) et des demandes de qualité visuelle du décor (falaises « voxel / low-poly », bords nets). La seule forme franchement lisse est le boulet, un accessoire, pas un mob. Choisir les formes lisses (sphères) obligerait à redemander plus de modèles qu'aujourd'hui ; les blocs arrondis prolongent ce qui existe.

Règles communes à demander pour chaque mob :
- Silhouette lisible de loin : une forme dominante (tronc massif) + 2 ou 3 repères (oreilles, queue, cornes, lance), pas de détail sous 0,3 stud.
- Palette : couleur de rôle de la palette ci-dessus (`corps`, `ventre`, `yeux`, `accent`) ; yeux en pièce séparée `Yeux` (la lueur Neon est ajoutée par le code, pas par le FBX).
- Poses neutres (pas de T-pose), devant vers -Z, origine au centre du socle, pieds sur y = 0.
- Aucun métal sauf pièce d'armure nommée `Armure` / `Fer`.

### À demander à Blender, mob par mob (par ordre d'effet visible)

| Mob à retoucher | Demande | Taille (studs) | Silhouette | Palette (suffixes) | Pièces max | Pièces nommées |
|---|---|---|---|---|---|---|
| **Pets en combat** (puppets de `BattleScene`) : pas un modèle par espèce, mais UN gabarit de bloc commun, `combat.puppet` (clé à créer, aucun id inventé) | Version « combat » à peu de pièces d'un pet : corps en bloc arrondi, tête en bloc, deux yeux, variantes d'oreilles (rondes, pointues, longues, tombantes), queue, bec ; le code recolore par espèce (`Corps__RRGGBB` lu comme couleur de base) et assemble les variantes | 3 de haut (fenêtre de la scène : socle de 3 de rayon) | Trapue, tête = 40 % de la hauteur, devant -Z | corps = couleur de l'espèce (remplacée par le code), yeux `1A1A1E`, ventre = corps éclairci | 14 (budget d'instances client : une scène de 2 créatures doit rester sous 220 instances en tout) | `Corps`, `Tete`, `Yeux`, `Oreille_G`, `Oreille_D`, `Queue`, `Bec`, `Patte_G`, `Patte_D` |
| Chevalier du château (`guards.knight`) | Retoucher en blocs arrondis, armure par pièces séparées, plastique lisse (supprimer l'aspect pierre brillante) ; **fournir aussi un repli** : le code doit pouvoir construire une silhouette sans le modèle (voir `Builder.dressKnights`) | 4,5 de haut (valeur réelle du code ; la demande initiale disait 6, trancher) | Humanoïde carré, casque à plume, lance et bouclier | armure `6E7280`, plume `C8323C`, bouclier `FFCD46`, corps `8E93A0` | 60 | `Corps`, `Casque`, `Lance`, `Bouclier`, `Bras_G`, `Bras_D`, `Jambe_G`, `Jambe_D` |
| Gardien Gus (`guards.dog`) | Vérifier qu'il suit le style (bloc arrondi, oreilles tombantes) ; si le Blender livré est lisse, le refaire en blocs | 2,5 de haut, ~4 de long | Chien trapu | corps `A0784A`, collier `C8323C`, nez `1E1E1E` | 40 | `Corps`, `Tete`, `Oreille_G`, `Oreille_D`, `Patte_AvG`, `Patte_AvD`, `Patte_ArG`, `Patte_ArD`, `Queue`, `Collier` |
| Gardienne Mara (`guards.wolf`) | Idem, silhouette plus longue et plus fine que Gus pour qu'on les distingue de loin | 3 de haut, ~6 de long | Loup, museau long, queue touffue | corps `8C8C99`, ventre `D6D6DE`, yeux `FFCD46` | 50 | mêmes pièces que le chien + `Yeux` |
| Gardien Zed (`guards.bear`) | Idem ; armure en pièces séparées nommées, seule partie métal autorisée | 5 de haut, ~5 de large | Ours massif, épaules larges | corps `6E4C2E`, armure `6E7280`, yeux `C8323C` | 50 | `Corps`, `Tete`, `Bras_G`, `Bras_D`, `Jambe_G`, `Jambe_D`, `Armure`, `Yeux` |
| Boss de la tour (étages 5, 10, ... 45 : 9 boss) | Variante « boss » du gabarit de pet de combat : même style, +30 % de taille, un accessoire propre (couronne, cornes, chaînes, auréole) en pièce séparée recolorable | 4 de haut | Gabarit commun + accessoire dominant | couleur du pet + accent `FFCD46` | 20 | `Corps`, `Tete`, `Yeux`, `Accessoire` |
| Tigre, Kraken, Calmar stellaire, Wyrm astral (pets sans Blender) | Déjà demandés dans « pets.* (suite) » ; ne pas les redemander, seulement les faire dans le même style | ~1 de haut | selon l'espèce | une couleur dominante | 40 | `Corps`, `Tete`, `Yeux`, `Oreilles`, `Queue`, `Pattes` |

À ne pas demander : PNJ humanoïdes (Pip, Nora, Lina, Bruno, Maître Kaï) déjà approuvés, Mère Poule et corbeau (décor et vol, pas des monstres de combat), pièges.

### Points que seul un rendu permet de trancher (à faire par l'utilisateur dans Studio, rien n'a été vu)
- Les modèles Blender des gardiens et du chevalier sont-ils vraiment lisses ou à blocs arrondis ? L'hypothèse « blocs » vient de la convention écrite, pas d'une capture.
- La boule de combat jure-t-elle autant qu'on le suppose avec le pet de la base ? Capture comparée à faire (un pet en monde, le même en combat).
