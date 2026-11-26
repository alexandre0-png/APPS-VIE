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
