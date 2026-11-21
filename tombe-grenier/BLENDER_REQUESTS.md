# Modèles Blender à créer (demande au gestionnaire)

Convention commune : une pièce par couleur, nommée `Nom__RRGGBB` (hex sans #) ; matériau déduit du nom (`Metal`, `Neon`, `Glass`, `Plastic`, sinon bois/tissu). Origine au centre du bas, face avant vers −Z (sauf mention). Moins de 3 000 triangles par objet. Aucune lumière ni script. Les tailles sont en studs (1 stud = 0,28 m) : largeur X × hauteur Y × profondeur Z, c'est la boîte de collision actuelle que le modèle doit remplir (`mode = fit`).

Déjà couverts par la bibliothèque (rien à refaire) : clé or, coffret ancien, horloge comtoise, poupée ancienne, bougie chandelier, armoire gothique, commode ancienne, berceau, cheval à bascule, miroir sur pied, malle, statuette, cadre photo, ombre rampante.

## Priorité 1 : visibles dans toutes les pièces (utilisés 4 fois ou plus)

| Nom du modèle | Taille (X × Y × Z) | Description | Couleurs (suffixes) |
|---|---|---|---|
| chaise ancienne | 2 × 2 × 2 (assise 1,1 de haut, dossier jusqu'à 2) | Chaise en bois à dossier à barreaux, quatre pieds tournés, assise légèrement usée. Silhouette lisible de loin. | `Bois__5A3E28`, `Assise__7A2E2E` |
| table de salle | 10 × 2,5 × 6 | Longue table rustique, plateau épais, pieds carrés, une rayure sur le plateau. | `Plateau__6B4A2F`, `Pieds__4A3220` |
| étagère murale | 8 × 7 × 7 (profondeur réelle 1,5, le reste vide pour la boîte) | Étagère à 5 niveaux, montants épais, planches irrégulières, vide (les livres sont ajoutés par le jeu). | `Bois__5E4630` |
| caisses en bois | 7 × 3 × 6 | Pile de 3 à 4 caisses de transport, lattes avec petits écarts, une caisse entrouverte. | `Lattes__8A6B45`, `Cerclage__3A3A3A` |
| pied de lit | 0,6 × 1,2 × 0,6 | Montant de lit en fer ou bois tourné, boule au sommet. | `Bois__4A3220` |
| plante d'intérieur | 3 × 4 × 3 | Grande plante en pot de terre cuite, feuilles larges, un peu fanées. | `Pot__A5603A`, `Feuilles__3F6B3A` |
| console d'entrée | 10 × 3 × 2 | Console étroite, deux tiroirs, pieds galbés. | `Bois__5A4030`, `Poignees__B8A060` |

## Priorité 2 : salles d'eau, cave, cuisine

| Nom | Taille | Description | Couleurs |
|---|---|---|---|
| baignoire sur pieds | 7 × 2,5 × 6 | Baignoire en fonte à pieds de griffe, bords arrondis, émail écaillé. | `Email__D8D4C8`, `Pieds__3A3A3A` |
| lavabo | 4 × 3 × 4 | Lavabo sur colonne, robinet métallique. | `Email__D8D4C8`, `Robinet__A0A0A0` (Metal) |
| WC | 3 × 2,5 × 3 | WC ancien, réservoir haut avec chaîne. | `Email__D8D4C8`, `Chaine__808080` (Metal) |
| armoire de toilette | 3 × 6 × 6 (profondeur 1) | Petite armoire murale à miroir, cadre en bois, miroir terne. | `Cadre__5A4030`, `Miroir__B0C4CC` (Glass) |
| barrique | 4 × 3 × 4 | Tonneau couché ou debout, cerclages métalliques rouillés. | `Douelles__6B4A2F`, `Cercles__5A4A3A` (Metal) |
| cuve | 8 × 4 × 6 | Cuve métallique de cave, rivets, robinet de vidange. | `Metal__6A6E70` (Metal) |
| canapé | 12 × 3 × 5 | Canapé trois places défraîchi, accoudoirs ronds, coussins affaissés. | `Tissu__6A4A3A`, `Pieds__3A2A20` |
| fauteuil | 4 × 3 × 4 | Fauteuil assorti au canapé. | `Tissu__6A4A3A`, `Pieds__3A2A20` |
| cuisinière | 10 × 3 × 4 | Cuisinière à gaz ancienne, quatre feux, four à poignée. | `Email__3A3A3A`, `Chrome__B0B0B0` (Metal) |
| frigo | 4 × 6 × 4 | Réfrigérateur arrondi années 50, poignée chromée. | `Email__C8C4B0`, `Chrome__B0B0B0` (Metal) |
| cheminée | 8 × 5 × 4 | Cheminée en pierre, foyer sombre, manteau en bois, sans feu. | `Pierre__6A6660`, `Manteau__4A3220` |

## Priorité 3 : pièces à identité forte (histoire)

| Nom | Taille | Description | Couleurs |
|---|---|---|---|
| cercueil | 8 × 2 × 6 (couvercle posé de travers, lisible depuis la porte) | Cercueil ancien, bois sombre, croix gravée, poignées métalliques. | `Bois__3A2418`, `Poignees__8A7A50` (Metal) |
| coffre verrouillé | 8 × 3 × 4 | Coffre renforcé de fer avec gros cadenas sur la face avant. | `Bois__4A3220`, `Fer__4A4A4A` (Metal), `Cadenas__B8A060` (Metal) |
| coffre à jouets | 6 × 2,5 × 6 | Coffre d'enfant peint, motif d'étoiles écaillé. | `Bois__7A5A8A`, `Etoiles__D8C060` |
| vitrine | 4 × 7 × 6 | Vitrine de collection, étagères intérieures, vitres sales. | `Cadre__4A3220`, `Vitre__A8C0C8` (Glass) |
| portemanteau | 2 × 6 × 2 | Portemanteau sur pied avec manteau abandonné. | `Bois__4A3220`, `Manteau__3A3A44` |
| lampadaire | 2 × 5 × 2 | Lampadaire à abat-jour de tissu jauni. | `Pied__4A3A2A`, `Abatjour__C8B070` (Neon, faible) |
| lit double | 12 × 1,8 × 12 | Lit à baldaquin dépouillé, draps jaunis, une traîne au sol. | `Bois__4A3220`, `Draps__C8C0A8` |
| établi | 10 × 3 × 4 | Établi d'atelier avec étau, quelques outils fixes. | `Bois__6B4A2F`, `Etau__5A5A5A` (Metal) |

## Notes pour la pose
- Chaque modèle reçoit son entrée dans `ModelFit.PLANS` (`fit` pour un meuble à boîte, `height` pour un objet à hauteur fixe) et son identifiant dans `Config.Assets` ; le moteur gère l'orientation, l'échelle mesurée et le repli procédural tant que l'asset manque.
- Priorité 1 d'abord : ces sept objets couvrent plus de 50 emplacements.
- Retour attendu : nom exact du modèle (colonne 1) et identifiant d'asset publié, dans `A_FAIRE_UTILISATEUR.md`.

---

# Lot 3 : sols, murs, fenêtres, escalier (demande du regraphisme)

État actuel : chaque pièce a déjà son sol et son mur distincts par matière et couleur (cuisine carreaux blancs, salles d'eau carreaux bleutés, salon et chambre d'enfant parquets, chambres moquettes bordeaux et bleue, bureau moquette verte, hall et entrée marbre, cave pavés, cellier terre battue, grenier plancher chaud, tombe dalles sombres). Il manque le relief et les textures fines.

## Modèles 3D (convention `Nom__RRGGBB`, devant = −Y Blender, tailles en studs X × Y × Z)

| Nom | Taille | Description | Couleurs |
|---|---|---|---|
| plinthe bois | 4 × 0,7 × 0,25 | Module de plinthe, profil à deux marches, bouts droits pour se raccorder. Posé en série le long des murs (hors portes). | `Bois__4A3220` |
| moulure plafond | 4 × 0,5 × 0,5 | Module de corniche en quart de rond, bouts droits. | `Platre__D8D0C0` |
| fenêtre ancienne à rideaux | 3 × 5 × 0,6 | Cadre à six carreaux, volets repliés, rideaux de tissu usé de chaque côté, appui de fenêtre. | `Cadre__5A4030`, `Vitre__A8C0C8` (Glass), `Rideau__7A3A3A` |
| fenêtre grenier ronde | 3 × 3 × 0,6 | Œil-de-bœuf à cadre rouillé, vitre fêlée. | `Cadre__5A4A3A` (Metal), `Vitre__A8C0C8` (Glass) |
| balustrade d'escalier | 4 × 3,5 × 0,4 | Garde-corps de 4 studs : main courante, six barreaux tournés, poteau d'angle. Modules raccordables. | `Bois__4A3220` |
| marche usée | 4 × 0,7 × 1,3 | Une marche de bois, bord avant arrondi par l'usure, un nez en laiton terni. | `Bois__6B4A2F`, `Nez__8A7A50` (Metal) |
| encadrement de porte | 5 × 9 × 0,8 | Chambranle et linteau moulurés autour d'une ouverture de 4 × 8. | `Bois__4A3220` |
| lampe murale applique | 1 × 1,5 × 0,8 | Applique à tulipe de verre, sans lumière. | `Laiton__B8A060` (Metal), `Verre__E8D8A8` (Glass) |
| soupirail | 3 × 1,5 × 0,6 | Soupirail de cave à barreaux et grille de fonte. | `Fonte__2A2A2A` (Metal), `Pierre__6A6660` |
| radiateur fonte | 4 × 2,5 × 0,6 | Radiateur à éléments, peinture écaillée. | `Fonte__6A6A64` (Metal) |

## Textures tuilables (images carrées 512 ou 1024, à téléverser comme décals/textures)
Demande d'images (pas de 3D) : chacune se répète sans couture.

| Nom | Usage | Description |
|---|---|---|
| damier cuisine | sol de la cuisine | Carreaux 1 × 1 stud blanc cassé et noir, joints sales. |
| parquet à chevrons | salon, chambre d'enfant | Lames de chêne en chevrons, usure au centre. |
| lames de plancher larges | grenier, couloir, salle à manger | Lames de 1 stud, nœuds, rayures. |
| dalles de cave | cave, passages | Dalles de pierre irrégulières de 2 × 2 studs, mousse dans les joints. |
| marbre veiné | hall, entrée | Marbre blanc cassé à veines grises. |
| papier peint fleuri | salon, chambre des parents | Motif de fleurs passées sur fond crème, léger déchirement. |
| papier peint enfant | chambre d'enfant | Rayures roses et petites étoiles, coins décollés. |
| faïence murale | cuisine, salles d'eau | Carrelage mural 0,5 × 0,5 stud blanc ou bleuté, joints gris. |

## Notes
- Priorité : plinthe bois, moulure plafond, fenêtre ancienne à rideaux, encadrement de porte, textures damier cuisine et parquet.
- Les plinthes et moulures se posent par modules : la logique de pose (hors portes, plafonnée en nombre de pièces pour le mobile) reste à écrire côté jeu dès que les modèles existent.

---

# Lot 4 : meubles encore procéduraux et cage de l'enfant (retours de test)

Convention : `Nom__RRGGBB`, devant = −Y Blender, tailles en studs (X × Y hauteur × Z), moins de 3 000 triangles. Matière déduite du NOM (métal seulement pour Anneau, Tige, Dent, Serrure, Poignée, Laiton, Fer, Chrome, Pics, Cadre doré ; néon seulement pour Flamme, Yeux, Lanterne) : nomme donc `Barreaux_Fer__4A4A4A` pour du métal et `Bois__5A3E28` pour du bois. Hauteur cible respectée à ±10 % par le jeu.

| Priorité | Nom du modèle | Taille (X × Y × Z) | Description | Pièces et couleurs |
|---|---|---|---|---|
| 1 | cage de l'enfant | 10 × 5 × 8 (porte sur la face −Y) | Cage de fer à barreaux verticaux serrés, toit plat, porte à gros cadenas, plaque de métal vissée sur la face avant (un petit rectangle lisse de 1,2 × 0,6 pour la date), sol de planches nues. C'est l'objet central de la cave. | `Barreaux_Fer__3A3A3A`, `Cadenas_Fer__5A5A5A`, `Plaque_Laiton__8A7A50`, `Sol__5E4630` |
| 1 | matelas de l'enfant | 4 × 0,5 × 4 | Petit matelas taché, couverture roulée, un oreiller. | `Matelas__B8AE98`, `Couverture__6A4A3A` |
| 1 | chaîne de cave | 0,3 × 3 × 0,3 | Chaîne verticale à maillons épais, anneau en haut (module à répéter). | `Chaine_Fer__3A3A3A` |
| 2 | chevet | 2 × 2 × 2 | Table de chevet à un tiroir et pieds fins. | `Bois__5A4030`, `Poignee_Laiton__B8A060` |
| 2 | table basse | 10 × 1,5 × 6 | Table basse rectangulaire, plateau épais, étagère basse. | `Bois__5A3E28` |
| 2 | meuble TV | 10 × 2,5 × 3,5 | Meuble bas à deux portes coulissantes, dessus plat. | `Bois__4A3220`, `Poignee_Laiton__B8A060` |
| 2 | plan de travail de cuisine | 11 × 3 × 1,8 | Plan de travail avec évier encastré, placards dessous. | `Plan__C8C4B0`, `Facade__6A5A48`, `Evier_Chrome__B0B0B0` |
| 2 | penderie | 2 × 7 × 2 | Penderie étroite à une porte, haute. | `Bois__4A3220`, `Poignee_Laiton__B8A060` |
| 3 | guéridon | 4 × 1 × 4 | Petite table ronde à pied central. | `Bois__5A3E28` |
| 3 | banc | 8 × 1,5 × 2 | Banc de bois à dossier bas. | `Bois__6B4A2F` |
| 3 | bidon métallique | 4 × 3 × 4 | Bidon cylindrique cabossé, bouchon. | `Bidon_Fer__5A4A3A`, `Bouchon_Fer__3A3A3A` |
| 3 | coffre de cave | 6 × 3 × 6 | Coffre de fer riveté, couvercle bombé. | `Fer__4A4A4A`, `Rivets_Fer__6A6A6A` |
| 3 | buffet | 5 × 5 × 8 | Buffet haut à quatre portes, moulures. | `Bois__4A3220`, `Poignee_Laiton__B8A060` |

Notes : la cage est l'objet le plus visible de la partie (l'étape « libérer l'enfant » s'y joue) ; tant qu'elle n'existe pas, une boîte de métal procédurale en tient lieu.
