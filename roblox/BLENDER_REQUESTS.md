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
