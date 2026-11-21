# Journal des modifications : Chipe-Œufs (Roblox)

Chaque entrée indique les décisions techniques prises. Dates au format AAAA-MM-JJ.

## 2026-11-22 : lots A à D (correctifs Lune, amis, œuf borné, modèles Blender)

- **A (23ae91b)** : les échecs sous Lune venaient de MON test : le générateur du test (`seed * 1103515245`) dépasse 2^53, exact avec les entiers de Lua 5.5 (lupa) mais imprécis avec les doubles de Luau (Lune). Remplacé partout par Park–Miller (`seed * 16807 % 2147483647`, exact en doubles) ; ajout d'un test DÉTERMINISTE sans aléatoire (balayage exact du tirage). L'erreur client « compare table < number » venait du runtime factice (Luau ne tolère pas `proxy < nombre`) : les instances ont maintenant des valeurs numériques réelles par défaut.
- **B (6fa1453)** : toute partie, même lancée seul, reste ouverte aux amis du créateur jusqu'à 5 joueurs (liste blanche serveur inchangée), « Rejoindre l'ami » avec places libres, retrait du registre quand tout le monde est parti, messages clairs.
- **C (8bc3546)** : plafond de taille de l'œuf (`Config.eggMaxSize`, relatif à l'emplacement et au joueur), nid sous chaque œuf, pet qui apparaît plafonné (`Easing.popScale`).
- **D** : modèles Blender intégrés : œufs par rareté (6 + secret, prioritaires sur le catalogue), 6 pets liés aux espèces (Poussin, Lapin, Renard, Panda, Dragonnet = Dragon, Fantôme = Alien), accessoires (arbre, sapin, rocher, buisson, pont, cabane, barrière, fontaine du hub, nid). Convention `Nom__RRGGBB` lue par `Assets.colorize` (couleurs du FBX ignorées, petits détails sans ombre), un seul `LoadAsset` par identifiant puis clonage, plafond de Parts par modèle (`propsMaxParts`) et budget global (`propsBudgetParts`, pire cas testé), repli procédural conservé partout. `BLENDER_REQUESTS.md` liste tous les modèles à créer ensuite.

## 2026-11-22 (suite) : câblage Blender, lot 5 arène (sol, moulin, enclos, bancs, lampadaires)

- `Builder.dressArena` : place `ground.plaza` sous le monument, 4 bancs (tournés vers le monument) et 4 lampadaires autour, moulin (`props.mill`) avec ses `Pales` / `Pales2` qui tournent en sens contraires (10 Hz, `Builder.animProps`) et enclos (`props.pen`) dans le domaine 1. Budget `arenaBudgetParts` (500, pire cas). Chargé après les gardiens et les pièges, avant le château.
- Pas posés : `ground.grass` et `ground.path` (le sol et les chemins procéduraux de `Scenery.paths` restent : dallage = trop de clones sans mesure réelle sur téléphone) ; le hub n'a pas de lampadaires/bancs Blender (ses bancs et lampadaires sont déjà construits par `HubWorld`, à remplacer dans un lot dédié si tu le veux). Non testé en Studio : axe de rotation des pales, orientation des bancs, taille de la place.

## 2026-11-22 (suite) : câblage Blender, lot 4 pets supplémentaires

- 8 pets ajoutés à `Config.Assets.pets` : Hamster, Chat, Chien, Hibou, Manchot, Lion, Licorne, T-Rex (14 espèces sur 18 en Blender ; Tigre, Kraken, Calmar stellaire, Wyrm astral restent procéduraux, non créés). Même chargeur, même plafond de Parts (`petsMaxParts`), repli procédural.

## 2026-11-22 (suite) : câblage Blender, lot 3 château (murs, tours, herses, coffre, torches, drapeaux, fond)

- `Builder.dressCastle` : 4 murs Blender par salle (les murs procéduraux restent les colliders, invisibles si les 4 sont posés), 2 tours, une porte par salle dont la pièce `Herse` monte à l'ouverture (`Builder.animDoor`, uniquement au changement d'état), coffre dont le `Couvercle` s'ouvre à la prise du trésor (`Builder.openChest`), torches (la lumière du pilote reste), drapeaux sur le portail, bâtiment `props.castle` en fond. Budget global `castleBudgetParts` (1700, pire cas = plafonds de Parts) ; un modèle sans Herse/Couvercle est ignoré (repli procédural). Groupe `props` entier chargé (moulin, enclos, lampadaire, banc, panneau sont chargés mais pas encore posés). Le sol (`castle.floor`) n'est pas posé : un dallage demande des dizaines de clones, hors budget mobile sans mesures réelles.
- Non testé en Studio : proportions des modèles (échelle par largeur/hauteur), orientation des murs (rotation 90°), sens d'ouverture du couvercle.

## 2026-11-22 (suite) : câblage Blender, lot 2 pièges du château

- `Builder.dressTraps` : pics (`traps.spikes`, pièce animée `Pics`), lames (`traps.blade`, pièce `Lame` qui tourne autour de l'axe vertical du modèle), boulets (`traps.ball`, modèle entier qui suit et roule). Les Parts procédurales restent les pilotes de la logique (dégâts, positions) et deviennent invisibles ; un modèle sans la pièce animée attendue est ignoré (apparence procédurale conservée). Les noms de pièces acceptent le suffixe de couleur (`Pics__C0C0C0`). Mise à jour des modèles seulement quand l'état change (pics) ou à 10 Hz (lames, boulets).
- Tests : le runtime factice clone désormais en profondeur et gère `FindFirstChild(nom, true)`. Non testé en Studio : sens de rotation et position de repos des pièces animées (je suppose les pics dessinés « sortis »).

## 2026-11-22 (suite) : retours de test réels, lot 2 : échelles réduites

- Hauteurs cibles (joueur = 5) : pet normal 1,7 (Commun) à 2,1 (Cosmique), jamais plus de 3 = 60 % d'un joueur même Géant ou Colossal (`petHard`) ; œufs 1,8 à 2,8 ; gardiens chien 2,5, loup 3, ours 5, chevalier 4,5. Pet procédural réduit dans les mêmes proportions (rayon 0,9). Tests : pets (le plus grand <= 3), œufs affichés (<= 2,8 +10 %), gardiens (±10 %), lampadaires, moulin ; un modèle qui dépasse sa cible de plus de 10 % fait échouer la suite.

## 2026-11-22 (suite) : retours de test réels, lot 3 : pictogrammes

- Le pictogramme de recyclage ♻ (rendu comme un « + » selon les polices) est retiré partout : échange des doublons = ⭐ « Échanger » (bouton « Échanger 1,2K », titre, message « ⭐ N doublon(s) échangé(s) »), renaissance = 🌅 (menu, succès, classement, message), menu Plus = ⚙️. Choix justifié : ⭐ dit « valeur » et reste lisible à 16 px ; 🌅 = recommencer plus fort ; aucune icône « 🔄 ». Test : plus aucun ♻ ni 🔄 dans les scripts.

## 2026-11-22 (suite) : retours de test réels, lot 4 : la base grandit avec les œufs

- **Score de base** : chaque pet éclos ajoute des points selon sa rareté (Commun 1, Rare 3, Épique 8, Légendaire 20, Mythique 50, Cosmique/secret 150, `Config.BASE_WEIGHTS`) ; **8 niveaux** (`Config.BASE_LEVELS`) : Enclos de bois (0), Cabane (12), Chaumière (40), Maison (110), Manoir (260), Fort (600), Forteresse (1400), Château doré (3200).
- **Apparence** (`Builder.baseUpgrade`, cumulative, 130 Parts au plus par base) : enclos de bois sur trois côtés, cabane au fond (modèle Blender `props.hut` si le budget le permet), lanternes lumineuses et dallage, muret de pierre, tours d'angle (modèle Blender `castle.tower`), créneaux et bannières, arche et torches, et au niveau 8 toit, tours, linteau et lueur en or. Repli procédural partout ; budget Blender des bases `baseBlenderBudget` (280 Parts par base).
- **Montée de niveau** : message serveur, effet 3D (pilier, aura, onde de choc, `VfxKit`) et plan de caméra court en orbite (`base_niveau`, `CinematicKit`, jamais en danger). Interface : ligne « Ma base : niveau N » avec progression et prochain palier dans le menu Plus et note en tête de l'onglet Œufs.
- **Sauvegarde** : profil **version 8** (`baseScore`), migration de l'ancien profil (score reconstitué d'après la collection : nombre de pets par espèce x poids de la rareté).
- **Bug trouvé au passage** : la renaissance ne conservait pas `starter` (le pack de départ à achat unique pouvait être racheté après une renaissance) ; elle garde maintenant `starter` et `baseScore`.
- Non testé en Studio : proportions des apparences, position des éléments sur la plateforme (l'entrée est supposée côté -Z, l'arrière +Z).

## 2026-11-22 (suite) : retours de test réels, lot 5 : pose planifiée du décor, domaines espacés

- **Cause du désordre** : les trois domaines étaient à 90 studs l'un de l'autre alors que leurs douves ont 56 de rayon : les anneaux d'eau se recouvraient, et les accessoires (posés au hasard) finissaient dans l'eau ou sur les chemins. Corrigé : domaines espacés de 125 (`Config.Map.rivalSpacing`, 13 studs entre deux douves), reculés (`rivalZ = -110`) et anneau des bases agrandi (`plotRadius = 262`) pour ne rien recouvrir.
- **`Placement` (module pur, 14 tests)** remplace la pose aléatoire de `Builder.dressWorld` : grille de cellules parcourue dans un ordre déterministe, empreinte circulaire par objet, refus si l'empreinte touche l'eau (rivières, douves), un chemin, l'arène, un domaine, une base, un secret ou le bord, distance minimale de 2 studs entre objets, cabanes tournées face au centre de leur domaine, barrières alignées sur une même ligne (côté nord, jamais sur le chemin d'arrivée), ponts centrés sur leur rivière et plus longs qu'elle (18 pour 14) donc posés sur les deux rives. Géométrie de référence dans `Config.Map.geo`. Moulin et enclos de l'arène déplacés dans le domaine, hors douve.
- Tests : aucune collision d'empreintes, aucun objet dans l'eau ni sur un chemin ni dans l'arène (vérification indépendante du planificateur), ponts reliant les rives, plan déterministe. Décor procédural réduit pour rester sous 1200 Parts.
- Non fait ici (voir le rapport) : relief en terrasses avec Terrain et falaises, cascades.

## 2026-11-22 (suite) : retours de test réels, lot 1 : sol qui scintille

- **Détecteur de z-fighting** (test sur le hub et la partie construits) : deux dessus horizontaux à moins de 0,05 stud qui se recouvrent sur plus de 1 stud carré sont refusés ; il a trouvé (hub) la bague de la place au même niveau que la place, les pavés des chemins sous l'anneau des portails et superposés entre eux (le chemin du portail « château » doublait celui de l'arène) ; (partie) les taches d'herbe qui se recouvraient, l'arène sous l'eau des douves, les segments de douve entre eux, les deux rivières à leur croisement, la paille du nid, l'étang de Mara, les tuiles Blender de chemin sur celles de pelouse.
- Corrections : hauteurs distinctes (≥ 0,05), taches d'herbe sans recouvrement et hors de l'arène, douves à deux niveaux alternés, rivières décalées, arène et bague abaissées, chemins du hub à trois niveaux et arrêtés avant les anneaux (le chemin « château » part du portail de l'arène), tuiles de chemin 0,06 au-dessus des pelouses.
- **Plus de Neon plein sol** (test : aucun disque ou dalle Neon de plus de 300 studs carrés à moins de 1,2 de haut) : anneaux des portails du hub, anneau lumineux des domaines et étang de Mara en matières lisses ou verre ; le néon reste sur les petits éléments et les linteaux.

## 2026-11-22 (suite) : pack animations, survol du hub, animations d'interface, ANIMATIONS.md

- **Survol d'accueil du hub** (HubClient, CinematicKit) : fontaine puis portails, 5 s, première arrivée seulement (`ReturnVisit` posé par le hub au retour d'une partie), bandes noires, carton, bouton Passer, tap/clic/Entrée, sécurité à 10 s, caméra et champ de vision restitués. Testé avec le vrai client du hub (démarre, se termine, aucun survol au retour).
- **Animations d'interface** (`Config.Animations.uiFx`, `pulse`) : compteur de pièces qui défile (`Easing.rollTo`), balayage de brillance (`Easing.shineX`) sur le bandeau de rareté dès Épique, flash de vignette coloré dès Légendaire, pulsation légère de ColorCorrection et Bloom (`Easing.pulse`). Testé en pur et à l'éclosion d'un Dragon synthétique.
- **`roblox/ANIMATIONS.md`** : catalogue des préréglages, qualités, plans avec durées, événements déclencheurs, réglages.

## 2026-11-22 (suite) : pack animations, CinematicKit (caméras)

- Module partagé `CinematicKit` (logique pure, 52 tests) : plans = listes de prises (position, cible, champ de vision, durée, courbe Back/Elastic/Quint/Quad/Sine, trajectoire : travelling, orbite, plongée, zoom dolly), tremblement décroissant, ralenti par zone de prise (durée réelle allongée, temps virtuel monotone), durée réelle plafonnée à 8 s (`build` réduit proportionnellement), refus d'un plan invalide, `canPlay` (jamais en danger : moins de 50 % de pv, coup depuis moins de 4 s, poursuite par un gardien, salle à pièges, mort), `canAlert` pour l'alerte des gardiens (aucune caméra, 40 % de pv, 90 s de recharge, 3 par session), `runner` (une seule cinématique à la fois, passage immédiat, caméra restituée UNE fois quoi qu'il arrive : fin, passage, erreur d'affichage, caméra indisponible, abandon).
- Plans : survol du hub, éclosion par rareté (commun et rare : aucune cinématique, effets 3D seuls ; épique court ; légendaire à cosmique : orbite lente, zoom avec ralenti à la « fissure », secousse ; secret : plongée, orbite, zoom et carton), entrée du château (panoramique puis herse), victoire du château (zoom au ralenti sur le coffre, orbite, carton « Victoire »).
- `Cinematics.client` : utilise le kit (FOV restauré avec la caméra, secousse, ralenti par temps virtuel, carton de titre au centre, passage d'un tap dans le monde pour les éclosions sans bloquer l'inventaire, abandon si le joueur est touché), déclencheurs : éclosion (au plus une par 20 s), entrée et victoire du château ; alerte « ❗ » des gardiens (à-coup de champ de vision, tremblement léger, sans caméra). Le runtime factice gère maintenant `BindToRenderStep` et `RenderPriority.X.Value`.
- Non testé en Studio : sensation des plans, tailles de caméra, position des ancres du château.

## 2026-11-22 (suite) : pack animations, VfxKit (effets 3D)

- Module partagé `VfxKit` : 8 préréglages (aura runique, aura d'ailes, onde de choc, pilier de révélation, bouclier, étincelles, spirale montante, portail torii) = séquences de pièces des 13 modèles Blender d'effets (IDs approuvés, `Config.Assets.models.vfx`), particules, faisceau (Beam), surbrillance (Highlight) ; données pures et planification testées (`plan`, `hatchPlans`, `hatchEffects`, courbes Back/Elastic/Quint/Quad/Sine, transparence et échelle par progression) ; exécution client `VfxKit.play` (clone depuis `ReplicatedStorage.VfxTemplates`, recoloration par code par rareté, ancré, sans collision, TweenService, Debris, tout sous pcall).
- Qualité : Élevé (8 effets simultanés, 120 particules, faisceau), Moyen (5, 70, pas de faisceau), Bas = tactile (3 effets simultanés, 40 particules par émetteur, pas de faisceau, une seule pièce par effet) ; automatique par appareil, forçable (`Config.VFX.quality`), coupable (`Config.Animations.vfx3d`).
- Le serveur charge le groupe `vfx` (plafond 30 Parts par modèle, matière Neon conservée) et le publie dans `ReplicatedStorage.VfxTemplates` (un client ne peut pas charger d'assets). L'éclosion joue les effets 3D EN PLUS de la révélation en interface : ampleur croissante (commun : étincelles seules ; rare : + onde ; épique : aura runique ; légendaire : pilier, aura, ailes ; mythique : + spirale ; cosmique et secret : tout, avec torii) ; la victoire du château joue étincelles et onde autour du joueur.
- Non testé en Studio : orientation, taille et lisibilité des effets (tailles Blender supposées naturelles), coût réel sur téléphone.

## 2026-11-22 (suite) : produit « Relance immédiate » (château)

- `Config.PRODUCTS.Revive` (ID à 0 = désactivé, aucune offre). Après une défaite au château, le retour gratuit au début de la salle reste inchangé ; si le produit est disponible, le serveur ouvre une offre de 20 s (`ReviveUntil`, position de chute mémorisée) et le client affiche une carte non bloquante « 💫 Relancer maintenant » (à la place du conseil, ✕ pour fermer, disparaît seule). `ProcessReceipt` : relance sur place (pv pleins, 4 s d'invulnérabilité, défaite décomptée en moins) ; offre expirée ou joueur sorti du château : potion de chance offerte à la place (l'achat n'est jamais perdu) ; reçus rejoués, sauvegarde et dédoublonnage via le mécanisme commun. Tests de bout en bout (aucune offre à ID 0, relance à l'endroit de la chute, expiré, rejoué) ; mutation vérifiée.

## 2026-11-22 (suite) : étiquettes des portails du hub

- Les étiquettes « CHÂTEAU SOLO / 1 JOUEURS · Libre » se superposaient : 20 BillboardGui visibles de 140 studs. Maintenant : tailles FIXES en pixels (titre 230 x 44, statut 200 x 30, château +40 de large), `MaxDistance` 40, décalages verticaux alternés d'un portail à l'autre, et UNE SEULE paire visible à la fois : celle du portail le plus proche (`Config.nearestPortal`, HubClient, 4 fois par seconde), les autres sont désactivées. Tags `PortalLabel` avec `PortalKey` (« 1 » à « 5 » ; « c1 » à « c5 »). Testé : 10 portails, un titre et un statut chacun, aucun doublon, distance 40, choix du plus proche, positions invalides.

## 2026-11-22 (suite) : retour réel de Studio, échelle et matières des modèles Blender

- **Pets énormes (cause trouvée)** : l'animation d'apparition du client (`Animations.client`) appelait `model:ScaleTo(1)` et `ScaleTo(popScale)` en échelle ABSOLUE : elle écrasait l'échelle posée par le serveur et rendait le modèle à sa taille Blender brute (~20 studs). Elle est maintenant relative (`base = model:GetScale()`), avec un test qui interdit `ScaleTo(1)`.
- **Échelle par hauteur cible** : `Assets.fitHeight` mesure `GetExtentsSize`, met à l'échelle sur la HAUTEUR, remesure et exige ±10 % (deux corrections au plus) ; mesure impossible (nulle, NaN, absente) ou hauteur hors tolérance : le modèle n'est pas posé (repli procédural), jamais d'échelle brute. Appliqué aux pets, œufs, gardiens, accessoires, château, bancs, lampadaires, moulin. Table `Config.Assets.targetHeights` : pet 2 à 4 selon la rareté (`Config.petTargetHeight`, maximum 5 même Colossal), œuf 3 à 4,5, lampadaire 8, banc 2,5, fontaine 7, cabane 11, moulin 20, arbre 12, sapin 14, chien 3, loup 4, ours 6.
- **Couleurs et matières** : `Metal` seulement pour les pièces explicitement métalliques (`metalParts` : Anneau, Tige, Serrure, Poignee, Fer, Cercles, Pics, Lame, Herse), `Neon` seulement pour `Flamme`, tout le reste en `SmoothPlastic`, `Reflectance = 0` partout ; sur une pièce colorée, `TextureID` et `SurfaceAppearance` retirés (une texture importée teinte la couleur) ; le suffixe `.001` d'un doublon d'import garde sa couleur (`Sapin__2E7D4F.001` = vert) ; sans suffixe la couleur du FBX n'est jamais modifiée. Les modèles d'effets gardent leur Neon.
- Runtime factice : géométrie à état (taille brute, `ScaleTo` absolu).

## 2026-11-22 (suite) : chasse aux bugs

Nouvelle suite de tests de bout en bout sur les vrais scripts (runtime factice) : départs en plein jeu (éclosion, téléportation, combat de gardien, château, achat), courses (vol simultané du même œuf, double vente, achat et revente rapprochés, 6e joueur), DataStore (panne au départ, retour pendant la sauvegarde, retour avec sauvegarde en attente, arrivée pendant la panne, `BindToClose`), achats (ID à 0, reçu rejoué, sauvegarde en échec), 80 éclosions enchaînées sans fuite d'objets, 10 000 tirages d'éclosion valides, gardiens (sans chemin, zone verrouillée, plusieurs joueurs, AFK, perte de cible), classement du château (valeurs invalides, ex aequo), chargements en échec à 100 %.

Bugs trouvés et corrigés :
1. **Profil écrasé à la reconnexion rapide** : un joueur qui repart puis revient pendant que sa sauvegarde de départ réessaie rechargeait un profil périmé, puis l'écrasait à sa prochaine sauvegarde (perte de l'œuf acheté). Correctif : la reconnexion attend la fin de la sauvegarde de départ (`leavingSave`).
2. **Progression perdue si la sauvegarde de départ échoue** : après 3 essais le profil était abandonné. Correctif : reprise en arrière-plan (`saveLater`, délais croissants, 10 essais), reprise du profil en attente si le joueur revient avant, vidage à `BindToClose`.
3. **Classement du château** : une valeur invalide (texte, négative, nulle, NaN) apparaissait comme un temps de 0:00. Correctif : ignorées dans `Data.castleTop`.
4. **Budget de Parts** : la carte procédurale faisait 1622 Parts. Ramenée à 1194 (budget 1200 : fleurs, arbres, taches d'herbe, collines, douves, palissades, planches de pont réduits, piédestal en disque de marbre au lieu de 3 dalles) ; l'ancien budget de 7000 devient `Config.Map.totalBudgetParts` (carte + pire cas des modèles Blender).
Le runtime factice clone désormais en profondeur, trie les magasins ordonnés et expose `RT.Enum`.
Non couvert par des tests de bout en bout : vrai téléphone, vraie latence DataStore, deux amis qui rejoignent exactement au même instant (la logique d'admission est sérialisée et testée en séquence).

## 2026-11-22 (suite) : textures tuilables

- `Assets.loadTextures` : les 7 IDs approuvés sont des DÉCALS ; chargés côté serveur par `LoadAsset`, le `Decal.Texture` est lu et l'URL mise en cache (`textureUrls`), le modèle détruit. Échec, délai ou décal absent : la matière actuelle reste (warn).
- `Builder.dressTextures` : une `Texture` par face visible (`StudsPerTileU/V` = `tile`) sur le sol de la carte (herbe 8), rivières et douves (eau 10, transparence 0,2), sol (dalles 8) et murs (pierre 6, faces intérieures) du château, planches de ponts (bois 4), berges (sable 8), pavés des chemins (terre 8, face plate des cylindres). Priorité `textureOrder`, plafond `textureMaxCount` (220). Chargé après les accessoires et avant le sol Blender.
- Non testé en Studio : alignement des faces sur les cylindres des pavés, rendu des textures sur le verre des rivières (la matière Glass reste), cohérence visuelle avec les tuiles Blender du sol (`ground.grass` se pose au-dessus de la texture).

## 2026-11-22 (suite) : sons

- 18 sons synthétiques approuvés (rbxassetid://) branchés dans `Config.SOUNDS` : éclosion par rareté (`Config.hatchSoundKey` : commun pop, rare, épique, légendaire pour 4-5, secret ou Cosmique = son secret), pièce (récompenses), achat, refus (pas assez de pièces), grognement (loup, ours) et aboiement (chien) à l'alerte ou à la poursuite d'un gardien pour les joueurs à moins de 60 studs, coup reçu (gardiens, pièges, chevaliers), pics qui sortent (par salle, au plus 1 fois / 0,8 s), lame et boulet en boucle selon la distance (tags `CastleBlade`, `CastleBall`, `Config.loopFade`), fanfare à la fin du château, ambiances prairie (dehors) et château (dedans).
- Client : un seul `Sound` réutilisé par type, volume = définition x réglage général, aucun son (hors clics et menus) avant la première réception de l'état, tout sous `pcall` (un asset qui échoue ne casse rien), boucles coupées en quittant la zone. Menu Plus : « Son » (100 %, 60 %, 30 %, muet), réglage non sauvegardé (remis à 100 % à chaque connexion). Les messages vides du serveur ne produisent que le son.
- Non testé : le rendu réel des sons (je n'entends rien ici), les ambiances dans le hub (le client du hub n'a pas de sons ambiants), la sensation des volumes.

## 2026-11-22 (suite) : hub Blender, sol mesuré, chevaliers du château

- **Hub** (a86b6b1) : 6 bancs et 16 lampadaires Blender remplacent les procéduraux (la lumière des lampadaires est conservée, boule invisible). `Assets.loadGroup(groupe, seulement)` charge un sous-ensemble. Banc de l'arène : orientation corrigée (face au monument).
- **Sol** (de9e882) : `Builder.dressGround` : chemins (`ground.path`, du Grand Nid vers les domaines) puis pelouses 3 x 3 devant chaque base (`ground.grass`). Coût d'une tuile MESURÉ à l'exécution (Parts réelles du modèle chargé) ; arrêt à `groundBudgetParts` (600) ou `groundMaxTiles` (120). Je ne peux pas mesurer les vrais modèles ici : le plafond protège le mobile, le nombre de tuiles réellement posées s'affiche dans la sortie (`[Assets] sol Blender`).
- **Chevaliers** : 1 en salles 3 et 4, 2 en salle 5 (`Castle.knights`, `Castle.knightPos`, patrouille latérale en onde triangulaire), touche non mortelle (22 pv, mêmes pv et invulnérabilité que les pièges), pilote procédural remplacé par `guards.knight` orienté dans le sens de la marche.

## 2026-11-22 (suite) : étape 2, tutoriel, inventaire à onglets, bannière avec distance, offres au bon moment

- **Tutoriel** (`Config.TUTORIAL`, `Config.tutorial(stats)`) : la carte d'objectif sous les compteurs affiche « 🎯 Objectif n/4 : Chipe 2 œufs chez un rival (0/2) » avec barre de progression, étape lue dans les statistiques (rien de sauvegardé en plus), puis laisse la place à l'objectif de l'histoire ; le conseil du bas est masqué pendant le tutoriel (un seul guidage).
- **Inventaire à onglets** : 🥚 Œufs (revente), 🐾 Pets (doublons, suivre, vendre), ⚡ Boosts (multiplicateur, collection, potion, passes actifs), 🏷 Titres (`Config.titles` : 20 titres = 5 succès x 4 paliers, verrouillés « ??? »), 📖 Index (compteur x/18, espèces non obtenues grisées ❓), 🏅 Succès.
- **Bannière de zone** : « Ferme de Gus · 120 m de ta base » (`Config.zoneLine`, distance arrondie à 5 m, « chez toi » près de la base) ; la base est publiée en attributs du joueur (`BaseX`, `BaseZ`).
- **Offres d'achat au bon moment** (`Config.boostOffer`) : après une éclosion rare (Chance +10 %) ou un palier de 25 éclosions (Revenus x2), carte non bloquante à la place du conseil, ✕ pour fermer, disparaît seule en 12 s, jamais dans les 90 premières secondes, 1 toutes les 5 minutes, 3 par session, jamais si déjà possédé ni si l'ID du pass est à 0. Testé en pur ; l'affichage de la carte n'est pas testé de bout en bout.

## 2026-11-22 (suite) : câblage Blender, lot 1 gardiens

- `Assets.loadGroup(groupe)` / `cloneModel(groupe, clé)` : chargement générique des groupes de `Config.Assets.models` (un LoadAsset par ID, plafond de Parts par `modelsMaxParts`, repli procédural). Chargé APRÈS la carte et les accessoires.
- `Builder.dressGuards` : chien (domaine 1), loup (2), ours (3) remplacent l'apparence procédurale (Body invisible conservé comme repère et support de l'étiquette, mise à l'échelle par `guardHeights`, posé au sol, ancré). Le déplacement (`PivotTo`) et la logique (perception, états, dégâts) sont inchangés. Le chevalier est chargé pour le château (lot suivant). Non testé en Studio : orientation du modèle (devant attendu = -Z) et hauteur.

## 2026-11-22 (suite) : lots G et H, économie et boutique payante

- **G (fa55b6d)** : revente d'un œuf (`Config.eggSellValue`, 25 % du prix : acheter puis revendre est toujours une perte) et « Revendre les doublons » (`Config.dupesToSell` garde le meilleur pet de chaque espèce) ; actions serveur `sellEgg` / `sellDupes` validées (emplacement, type, pets retirés de ceux qui suivent), boutons dans l'onglet base. Améliorations (emplacements, vitesse, chance, sac, incubateurs...) et prix croissants existaient déjà, avec test de simulation.
- **H** : 2 Game Passes (`Speed` : +20 % de vitesse, appliqué aussi à la tolérance anti-triche ; `VipBase` : boucliers d'œufs x2, bonus quotidien x2) et 2 produits (`StarterPack` à achat unique, `ExclusiveEgg` : œuf Mythique), IDs à 0 (désactivés avec message clair). `ProcessReceipt` corrigé : la livraison en mémoire n'est faite qu'une fois, `PurchaseGranted` n'est renvoyé qu'APRÈS une sauvegarde réussie (sinon `NotProcessedYet`, et la nouvelle tentative ne fait que sauvegarder, sans relivrer) ; base pleine : l'œuf exclusif n'est pas livré (`NotProcessedYet`) ; pack de départ déjà acheté : rien n'est livré. Donnée `starter` : sauvegarde v7 avec migration. Aucune monnaie n'est créditée côté client (le client ne fait que demander l'invite d'achat).
- **Vérifié** : lupa 1651 assertions, 0 échec (dont reçus avec DataStore en panne, relivraison, reçu déjà traité, base pleine, contrôle direct du contenu du DataStore) ; mutation vérifiée. Non testé : achats réels (IDs à 0).

## 2026-11-22 (suite) : lot F, missions et mode Château

- **Missions** : 3 nouveaux types (Château, pet Épique ou mieux, secret) ; récompenses au-delà des pièces : la 2e mission du jour donne un **œuf** (rareté selon l'histoire), la 3e un **boost de chance** de 10 minutes, les missions de défi un œuf ou un boost (`Config.questBonus`) ; texte de récompense (`Config.questRewardText`) ; données de quêtes étendues (`re`, `rb`, bornées à la lecture).
- **Mode Château** (`Castle`, pur, 41 assertions) : 5 salles successives de 40 x 56 studs, difficulté croissante (pics 4 à 8 plaques, lames 0 à 2, boulets 0 à 3, rythmes plus rapides, porte à timing de plus en plus brève). Pics : sûr -> avertissement 0,6 s -> danger 0,9 s (couloirs sûrs entre colonnes, vérifiés dans les 5 salles) ; lames tournantes (distance point-segment) ; boulets qui traversent puis font une pause ; porte qui s'ouvre par intervalles. Touches NON mortelles (18 / 24 / 28 pv, mêmes pv et invulnérabilité que les gardiens) ; à 0 pv : retour au début de la salle, pv rétablis, aucun œuf perdu. Chrono dès la première salle, **coffre final** (pièces + œuf Épique, Légendaire si rapide et sans défaite), **classement des temps** (OrderedDataStore `ChipeOeufs_Castle_v1`, un meilleur temps par joueur, tableau mis à jour toutes les 2 minutes à l'entrée).
- **Lancement** : 5 portails « 🏰 CHÂTEAU » (1 à 5 joueurs) dans le hub, files séparées de l'arène (`Party` gère `mode`), `TeleportData.mode = "castle"` : le premier joueur fixe le mode du serveur réservé, les amis qui rejoignent reçoivent le même mode ; le donjon est aussi accessible à pied depuis l'arène (entrée au nord-est). Tests de bout en bout : entrée par le prompt, chrono, coup de pics non mortel, traversée, coffre, temps au classement, coffre à usage unique.
- **Non fait** : modèles Blender du château, des pièges et des gardes (clés `castle.*`, `trap.*`, `guards.knight` dans `BLENDER_REQUESTS.md`) ; le donjon est procédural (Parts) ; pas de difficulté « infinie » au-delà de 5 salles.

## 2026-11-22 (suite) : lot E, gardiens qui « calculent » et ne tuent plus d'un coup

Module pur `Guard` (testé, 38 assertions) : **vue** (cône de `viewAngle` degrés et distance `viewDist`, propres à chaque gardien : Gus 100° / 24, Mara 110° / 28, Zed 120° / 32), **ouïe** (bruit selon la vitesse : immobile 0, marche lente 0,4, course 1 ; rayon `hearRadius` x bruit), **états** Patrouille → Alerte (intrigué, ❓) → Poursuite (❗) → Perte de cible (continue vers la dernière position 2,5 s) → Retour, abandon au-delà de 45 studs. **Voler DERRIÈRE un gardien** (hors cône, hors rayon d'ouïe) réussit sans combat ; passer devant le déclenche. **Dégâts** : barre de vie (100 pv), un coup retire 14 / 20 / 28 pv selon le gardien (jamais 40 % : au moins 3 coups pour l'ours), invulnérabilité de 1,6 s après un coup, recul, étourdissement 0,35 s, régénération (5 pv/s après 6 s sans coup, 25 pv/s dans la base) ; à 0 pv : œufs rendus à leur nid, retour à la base avec tous les pv et 3 s d'invulnérabilité. Chemin : `PathfindingService` en tâche de fond avec repli en ligne droite. HUD : barre de vie rouge glossy en bas à gauche (visible seulement si les pv sont entamés). Tests : mutations « dégâts x10 » et « états figés » détectées ; scénario de bout en bout (joueur loin = aucun dégât, joueur sur la ligne de patrouille : premier coup = 14 pv, jamais de mort en un coup, défaite = retour à la base). Non fait : modèles Blender des gardiens (clés `guards.*` dans `BLENDER_REQUESTS.md`).

## 2026-11-21 : inspirations (révélation, carrousel, style glossy, richesse, bannières)

Source : note `obsidian-studio/Inspirations/Videos-et-styles.md` (branche `claude/jolly-cannon-w2wx5h`), vidéos et images fournies par l'utilisateur. Tout est dessiné par le code (Frames, UIGradient, UIStroke, UICorner, TweenService) : aucun asset ni identifiant.

- **Révélation d'œuf par rareté** : étoile « ★ » colorée selon la rareté (gris commun, bleu rare, violet épique, orange légendaire, rouge mythique, cyan cosmique), halo, rayons qui tournent, anneaux, étincelles, flash et secousse de caméra proportionnels, texte **« 1 sur N »** sous le nom ; **œuf secret** (lave, plus d'anneaux, libellé) au-delà de `Config.REVEAL.secret.oneInAtLeast` (1 sur 20 000). Option mobile (`reducedFactor`, appareil tactile sans clavier ou `forceReduced`). `Reveal.probability` calcule la probabilité exacte (rareté, espèce, taille, mutation, tirage de pitié inclus) ; **test : les fréquences de 600 000 vrais tirages `Rules.rollPet` (4 configurations) collent à la probabilité annoncée (< 5 sigma)** et les probabilités somment à 1. Le serveur envoie `oneIn` avec chaque éclosion.
- **Carrousel d'œufs** (boutique) : l'œuf choisi est grand avec contour coloré, les voisins plus petits ; flèches ◀ ▶ (orange), clic sur un voisin, défilement circulaire, bouton vert « Acheter » ; œuf présélectionné = le plus rare payable. Les œufs sont dessinés (ovale dégradé, reflet) aux couleurs de `Config.EggFx`.
- **Style glossy** (`Config.UI`) : contour sombre épais, dégradé, coins arrondis, reflet ; vert = jouer / acheter, bleu = sauver / collection / classement, orange = options / flèches, rouge = fermer ; texte vérifié lisible (contraste >= 4,5) par test ; appliqué aux boutons de navigation, à la fermeture, aux boutons de ligne et au carrousel.
- **Richesse** : 1 pièce, petite pile, grosse pile, coffre (`Config.WEALTH`, seuils = prix des œufs 900, 20 000, 350 000), icônes dessinées (`CoinIcon`) dans l'en-tête de la boutique.
- **Bannière de zone** au passage d'un domaine ou retour à l'arène (`Config.ZONE_BANNERS`, `Config.Animations.zoneBanner`).
- **Premières 10 secondes** : carte de promesse (titre, accroche, bouton vert Jouer) non bloquante dès l'arrivée, premier geste proposé immédiatement (`Config.nextHint` : toucher l'œuf, qui éclot en quelques secondes).
- **Test de bout en bout** (client + serveur dans le runtime factice, remotes réellement reliés) : démarrage des 4 scripts client, promesse, objectif, boutique avec carrousel et icône de richesse, achat côté serveur par le bouton Acheter, éclosion avec « 1 sur N » et RevealFx, bannière « DOMAINE DE MARA ». Mutation « le bouton n'achète plus » détectée. Outil : `run_tests.py` gère maintenant les commentaires de fin de ligne après `+=`.
- **Non fait / limites** : pas de Beam ni de ParticleEmitter 3D (la révélation est en UI 2D, plus sûre sur mobile) ; icônes : dessinées ou emojis, aucun identifiant ; rendu réel non vu (Studio indispensable) ; l'inspection de vidéos n'a pas été refaite (note lue seulement).

## 2026-11-20 (correctif) : blocage de `lune run roblox/tests/run.luau` à d90cf58

**Cause probable (non reproduite : Lune n'est pas exécutable dans ma session)** : `fs.readFile` est asynchrone sous Lune et rend la main à l'ordonnanceur de Lune. `FakeRuntime.runScript` l'appelait depuis des coroutines créées par le runtime factice (démarrage de `Main` / `Hub`) : Lune ne reprenait jamais ce thread, d'où un processus à 0 % CPU sans sortie, alors que sous lupa `fs.readFile` est synchrone (c'est pourquoi mes 1431 tests passaient). **Corrections** : tous les fichiers sont lus dans `buildTree` (thread principal) et `runScript` n'appelle plus `fs`. **Garde-fous** (indépendants du moteur) : nom de chaque suite affiché (`▶ ...`), délai global de 90 s sous Lune (`task.delay` réel, message « bloqué dans la suite X », `process.exit(2)`), délai de 120 s sous lupa, sortie explicite en fin de run (aucune tâche de fond ne retient le processus), runtime factice avec plafond de reprises de coroutines, de temps réel et de durée virtuelle, auto-vérification que `luau.load` applique bien l'environnement fourni (sinon les suites de démarrage sont sautées avec un échec explicite plutôt que de lancer de vraies tâches), contrôle `check.py` [4c] (aucun `fs.*` dans une coroutine du runtime, watchdog présent).

## 2026-11-20 : audit de robustesse, retour au hub, manette

**Tests de démarrage RÉEL** (`tests/FakeRuntime.lua`) : le vrai `Hub.server.lua` et le vrai `Main.server.lua` (avec Builder, Data, Rules, Assets, Scenery...) s'exécutent dans un runtime factice permissif : DataStore et MemoryStore en mémoire, TeleportService enregistré avec échecs injectables, Players, Heartbeat, ordonnanceur à temps virtuel, `require` des vrais modules, garde d'instructions contre les boucles sans `wait`. Vérifié : démarrage sans erreur, « serveur prêt » atteint (les Remotes existent), carte construite à 1117 Parts (budget 7000), deux joueurs avec personnage et verrou de session, **600 actions aléatoires aux arguments invalides** (types, NaN, infini, tables, chaînes de 5000 caractères) sans erreur interne, sauvegarde au départ (verrou libéré, données saines), `BindToClose`, DataStore en panne sans erreur non gérée, scénario d'achat (2 œufs payés, œuf à 20 000 refusé) et du côté hub : portail 2 + compte à rebours + téléportation, registre, liste des amis, fuzz du Remote. Mutations détectées : require cassé, boucle infinie, achat sans paiement. Limite : proxies universels et physique absente (le `fastTick` du tapis lève des erreurs de type sous le faux monde, sans valeur pour Roblox) ; ce n'est pas un playtest.

**Boucles et fuites** : `check.py` impose un `task.wait` dans chaque `while true do` (0 violation). Les tables par joueur du hub sont nettoyées au départ (`lastReq`, `friendCache`, `launching`, file des portails).

**Fin de partie** : action serveur `toHub` + ligne « Retour au hub » dans Plus (lieu de jeu seulement) : sauvegarde, `Party.returnToHub` (testé : succès, échec avec message clair, hub non configuré), le joueur reste en jeu si la téléportation échoue, nouvel essai possible après 15 s ; `Hub.server` libère sa place dans la partie à son retour.

**Accessibilité** : manette X = boutique, Y = missions, Select = Plus, B = fermer ; clavier B / Q / O ; premier bouton du menu sélectionné à la manette (`Config.HUD.shortcuts`).

**Sons** : les sons existants sont des chemins intégrés `rbxasset://sounds/...` (non vérifiés dans Studio). Ajout de crochets muets `secret`, `portal`, `menu` (`id = ""`) et de `Config.SOUNDS_ENABLED` ; aucun identifiant inventé.

**Non fait** : « équilibrage des manches » (le jeu n'a pas de manches : économie par simulation, déjà traitée) ; progression/tutoriel inchangés (rangs, histoire, objectif à l'écran et indices existent déjà).

## 2026-11-19 (suite) : identifiants catalogue de l'utilisateur

**Œufs** : les 5 identifiants de la liste sont déjà dans `Config.Assets.eggs` (rouge 151044983, orange 147144059, aura violette 112478990, légendaire 2937230482, glitch 2937218888) ; l'aura violette n'avait jamais été vue refusée, les trois autres l'ont été (repli par le code conservé). **Décor du hub** : 13 modèles (chaise, canapé en U, tables, billard, lampe, 6 plantes dont Sakura) dans `Config.Assets.decor`, placés selon `Config.HubDecor` (zone libre au sud de la place ; emplacements vérifiés par test : hors fontaine, point d'arrivée, portails, panneaux). `Assets` passe dans `Shared` (utilisé aussi par le hub), avec `loadDecor` / `cloneDecor` et un plafond de Parts propre au décor (220, œufs : 60). Chargement serveur seulement, `InsertService:LoadAsset` sous pcall avec délai, scripts et objets de communication retirés, refus de permission = rien n'est placé (le hub est déjà décoré par le code). **Animaux** : les 3 packs sont gardés dans `Config.Assets.animals` mais NON chargés : aucun animal ne sert le gameplay (les pets sont construits par le code). **Sons** : aucun fourni, aucun inventé. Non vérifié : le chargement réel, l'échelle et l'orientation des modèles.

## 2026-11-19 : robustesse du démarrage, hub étoffé, éléments interactifs

**Cause racine à vérifier (retour du Jeu 2 : un `require` mal résolu plante tout le script serveur avant les Remotes)** : `check.py` simule Rojo (arbre construit depuis `default/game/hub.project.json`) et résout chaque `require(...)` (parenthèses équilibrées) et chaque chaîne `WaitForChild` / `:GetService` / `.Parent` de modules statiques. Résultat sur les 3 projets : 0 chemin faux (39, 39 et 11 chemins vérifiés). Testé par mutation (noms de module faussés : détectés). Non exécuté : `rojo build` réel (blocage d'autorisation de la session).

**Personnage garanti et filet anti-chute** : modules `Spawn` (décisions pures, 24 tests : aucun personnage, sous le sol, NaN, hors zone, trop haut, chute libre, joueur mort...) et `SpawnGuard` (application Roblox, sous pcall) dans le jeu ET le hub : chargement forcé après 10 s sans personnage (couvre `CharacterAutoLoads = false` de la partie), replacement au point de départ, alerte si plus de 6 sauvetages en une minute, traces `[Spawn]` en console serveur. `StreamingEnabled = false` écrit dans les 3 projets Rojo et dans les 2 places (vérifié par `check.py`) ; `Config.Map.Streaming.Enabled` reste le réglage de référence.

**Hub** : murs et plafond invisibles (4 murs + plafond à 130 studs), 3 panneaux d'explication lisibles (Comment jouer, Lancer une partie, Rejoindre des amis, valeurs lues dans `Config.Game`), bancs, chemins en pas japonais vers chaque portail, lucioles ; décor exécuté avec un Roblox factice (`tests/FakeRoblox.lua`) : aucune erreur, entre 200 et 600 Parts, 5 zones, 4 murs et un plafond, 3 panneaux.

**Partie** : les éléments interactifs (nids à chiper, secrets) portent un anneau doré pulsant et une icône (tag `Interactive`, `Config.Animations.interactMarkers`) ; aucun décor n'utilise ce doré.

**Non fait** : sons (aucun identifiant vérifié, je n'en invente pas), nouveaux modèles du catalogue (aucun identifiant reçu dans cette demande ; `Config.Assets` et `Assets` restent le point d'entrée). stylua : non exécuté, le signalement du bug `//` n'a donc pas pu être vérifié.

## 2026-11-14 (suite) : interface ancrée, hub et parties, grande carte

**Interface** : le HUD était posé au centre sur les captures d'écran de l'utilisateur. Nouveau module pur `Layout` : tout est ancré aux bords (compteurs et objectif à gauche, bannière et notifications en haut à droite, conseils en bas à gauche, boutons de menu en colonne en bas à droite), dans un conteneur `UIScale` (0,85 à 1,25 selon l'écran) et `ScreenInsets = DeviceSafeInsets`. Tests : 10 appareils (téléphones portrait et paysage, tablettes, PC, ultra-large, fenêtre Studio) : tout dans l'écran, rien dans la zone centrale (32-68 % x 32-75 %), aucun chevauchement, boutons >= 44 px réels. Les tests ont d'abord échoué sur 4 cas réels (chevauchement des notifications et de la colonne de menu en paysage), corrigés. Non vérifié dans Studio : la cause exacte du placement central observé n'a pas pu être reproduite sans Studio.

**Hub et parties** : `Config.Game` (lieux hub 115261336085924 et jeu 87012762353093, même expérience (univers 10776613087), 5 joueurs max, tailles 1 à 5, délais, replis), rôle d'un serveur déduit de `game.PlaceId`. Module pur `Party` (zones de lancement et file d'attente, lancement avec replis `reserved` puis `public`, registre des parties ouvertes visibles des amis, rejoindre en cours, départ, TTL) testé avec un faux TeleportService (création 1 à 5, zone pleine, groupe incomplet, rejoindre, plafond 5, départ, serveur indisponible, téléportation refusée, registre indisponible ; 3 mutations détectées). `Hub.server` + `HubWorld` (place pavée, fontaine, 5 portails néon en arc avec file d'attente visible, panneau des amis) + `HubClient` (bouton Amis, liste, Rejoindre). Côté jeu : plafond de 5 joueurs (renvoi au hub), arrivée en cours de partie = protection des œufs 90 s (`LateJoinGrace`), `PLOT_COUNT` = 5. Deux projets Rojo (`hub.project.json`, `game.project.json`) et deux fichiers de place (`build/Hub.rbxlx`, `build/ChipeOeufs.rbxlx`), le code commun est dans `src/ReplicatedStorage`.

**Réservation de serveur** : les deux lieux sont dans la même expérience, donc `ReserveServerAsync` et le registre MemoryStore du hub s'appliquent (la première version de cette entrée supposait deux expériences et prévoyait un repli ; le repli public avec message reste en place). Le serveur de jeu ne relit pas le registre du hub : sa liste blanche vérifie la cohérence des données de téléportation (`Party.admitJoin`). Les API de réservation sont marquées dépréciées dans le dump de l'API (sans remplaçant dans le même dump) : exception documentée dans `check.py`. Correctif de sécurité conservé (`2dd3d67`).

**Carte** : sol 1200 x 1200 (620 avant), bases en anneau de rayon 215 (5 bases), domaines espacés de 90 studs, `Config.rivalCenter` comme source unique (Cinématiques incluses). Décor identitaire par domaine (`Scenery`) : ferme dorée de Gus (grange, moulin, blé, foin, épouvantail), bois ensorcelés de Mara (arbres morts, champignons lumineux, cimetière, mare violette, lanterne-lune), citadelle de lave de Zed (aiguilles d'obsidienne, lacs de lave, tour aux anneaux cyan, passerelle) ; chemins en pas japonais ; quatre repères lointains (Grand Arbre, tour de guet avec balise, arche de pierre, obélisque doré) ; 34 monticules et une forêt périphérique ; trois secrets (un par domaine, fouillables une fois par jour, récompense serveur, données v6 `secrets`). Ambiance par zone : script client `Ambience` (éclairage, atmosphère, teinte, glissement de 2,5 s ; `Config.Animations.zoneAmbience`). `StreamingEnabled` (rayon min 128, cible 480) écrit dans le fichier de place depuis `Config.Map.Streaming` ; Mère Poule en `Persistent`. Budget mobile : `Config.Map.budgetParts` (7000), compte et avertissement au démarrage ; le décor ajouté fait 406 Parts (compte vérifié par test avec un Roblox factice qui exécute réellement chaque fonction du décor).

**Non testé** : tout le rendu et le réseau (Studio indispensable) ; l'effet de StreamingEnabled sur les scripts clients (garde-fous nil en place, mais non éprouvés) ; la téléportation réelle ; l'équilibrage des distances après l'agrandissement (les gardiens, le tapis et les bases sont inchangés, les domaines sont plus éloignés de l'arène).

## 2026-11-14 : retour du premier lancement dans Studio (v4 publiée) et passe d'amélioration

**Constats du journal de sortie** : (1) `StudioAccessToApisNotAllowed` : « Enable Studio Access to API Services » n'était pas activé, le chargement de données était réessayé 8 fois avec de faux échecs ; (2) trois modèles d'œufs refusés (`Requester does not have permission for Asset` : legendary, orange, glitch) : le repli par défaut a fonctionné mais l'apparence de secours était trop pauvre.

**Corrigé / ajouté**
- **Studio sans accès API** : module pur `Diag` (reconnaît l'erreur), `Data` passe en mode mémoire dès la première erreur précise avec UN seul avertissement (plus de 8 tentatives, plus de faux « Chargement échoué »), classement idem. Les vraies erreurs (réseau, quota, verrou de session) gardent leur comportement et leurs tentatives. Un serveur en ligne n'est pas concerné.
- **Apparences d'œufs sans modèle** : `Config.EggFx` donne à chacun des 5 œufs une apparence distincte construite par le code (rouge simple, orange avec étincelles, violet néon avec sphère d'aura, légendaire doré métallique avec anneau lumineux qui tourne, glitch néon cyan avec coque magenta qui scintille). Rotation et scintillement sont locaux au client (`Config.Animations.eggHalo`). `Config.EggFx.Enabled = false` revient aux œufs simples (téléphones modestes).
- **Modèles** : `Config.Assets.Enabled` (renommé depuis `enabled`), un seul avertissement par ID, échecs mémorisés dans `failedIds`. Un modèle refusé ne se réessaie pas.
- **Économie rééquilibrée** (mesurée par simulation, pas au jugé) : la simulation d'un joueur-robot de 30 minutes (règles réelles) montrait 2 250 pièces/s à 5 min, 300 000/s à 30 min, tous les œufs achetés en 20 min et la renaissance à 4 min. Nouveaux prix : œufs 25 / 900 / 20 000 / 350 000 / 6 M / 130 M ; coûts des améliorations (emplacements, Festin, Incubateur, Trèfle) relevés ; renaissance 5×10⁷ × 7^n. Résultat (5 graines) : 10 pièces/s en ~1 min, œuf Rare vers 1,5 min, Épique vers 4-8 min, Légendaire vers 13-20 min, Mythique après ~40 min, premier Cosmique après plusieurs heures, 4 500 à 28 000 pièces/s à 30 min. `tests/Economy.lua` + `tools/sim_economy.py` ; 11 garde-fous dans `tests/run.luau` (la mutation « anciens prix » est détectée).
- **HUD** : carte d'objectif permanente (chapitre, avancement, réclamation en un appui) sous les compteurs, `Config.HUD.objective`.
- **Anti-exploit** : audit des actions client (type, plage, existence, une seule réclamation, délai entre actions) : aucun défaut nouveau trouvé ; cadre inchangé.

**Limites** : la simulation ignore le vol, les quêtes, l'histoire, les événements et la renaissance (le bot ne renaît pas). Les récompenses d'histoire (minutes de revenus) accélèrent un peu le rythme réel. Aucun playtest.

## 2026-11-13 : apparence des œufs par modèles Roblox

**Ajouté** : `Config.Assets` (5 IDs : rouge 151044983, orange 147144059, aura violette 112478990, légendaire 2937230482, glitch 2937218888 ; `enabled`, `timeout` 8 s, `maxParts` 60, plafond de particules, hauteur cible, liste de classes interdites), module serveur `Assets` (dépendances injectées), `Builder.setAssets` / `dressEgg`, chargement lancé en arrière-plan par `Main`.

**Choix techniques**
- **Correspondance** (`Config.Assets.eggByTier`) : Commun = rouge, Rare = orange, Épique = aura violette, Légendaire et Mythique = légendaire, Cosmique = glitch. Le « glitch » est placé sur la rareté la plus haute faute d'événement d'éclosion dédié dans le jeu ; à changer en une ligne.
- **Apparence seulement** : l'éclosion, les raretés, les probabilités, les tags et les animations ne lisent jamais ces modèles. La Part « Egg » reste la racine (invisible), le modèle y est soudé par des `Weld` portés par ses propres parts (l'animation de course cherche le `Weld` direct du joueur). Limite : l'écrasement/étirement (Size) et le blanchiment (Color) de l'animation d'éclosion ne touchent que la racine invisible ; le saut et le tremblement (CFrame) suivent.
- **Sécurité** : `InsertService:LoadAsset` côté serveur seulement, sous `pcall`, délai maximum, un chargement par modèle au démarrage puis clonage. Supprimés : Script, LocalScript, ModuleScript, RemoteEvent, RemoteFunction, BindableEvent/Function, Sound, Tool, ForceField, Explosion et soudures d'origine ; particules plafonnées ; refus d'un modèle vide, sans part, corrompu ou de plus de `maxParts` parts. Tout échec garde l'apparence par défaut (Part + sphère).
- **Tests** (chargeur factice) : modèle sain, vide, code seul, corrompu, instance corrompue, erreur de LoadAsset, retour nil, trop lourd, délai dépassé (et réponse tardive ignorée), `enabled = false`, ID invalide, éclosion identique dans tous les cas. 1126 assertions ; mutation (nettoyage désactivé) détectée.

## 2026-11-12 : correction de documentation

Deux fois de suite (README des animations, puis documentation des cinématiques), un script de mise à jour de la documentation a échoué sur sa première substitution alors que la commande suivante a poursuivi (commit et push). Conséquences : le rapport de la passe animations annonçait à tort une section « Animations » du README, et le commit `7afb887` (cinématiques) annonce « documentation » sans la contenir. Rattrapé ici : sections Animations et Cinématiques du README, entrées de ce CHANGELOG, VERIFICATION, fiche de publication, `A_FAIRE_UTILISATEUR.md`. Désormais les scripts de documentation s'arrêtent à la première erreur (`sys.exit(1)`) et le commit n'est lancé que si tous les contrôles passent (chaîne `&&`).

## 2026-11-12 : cinématiques aux moments clés (v6)

**Ajouté** : `Config.Cinematics` (réglages) et `Config.CINE` (plans), module pur `Cinema` (séquences, lecteur, directeur), script client `Cinematics`, **Mère Poule** (modèle en Parts, gardienne du Grand Nid et guide de l'histoire, elle picore : drapeau `hen`), mémorisation des cinématiques vues (`cine`, données en version 5), boutons « Revoir » dans le menu Plus, `Config.padLocal` (source unique des positions d'emplacements). Les textes de l'énigme parlent désormais de Mère Poule.

**Choix techniques**
- **Peu de cinématiques** : la consigne la plus récente (moments clés seulement) remplace la précédente (une séquence par événement, 20 à 40 s). Quatre cinématiques de 6 à 16,5 s au total, au lieu de séquences longues qui casseraient le rythme d'un jeu de récolte.
- **Jamais bloquant** : caméra Scriptable seulement pendant la lecture, personnage toujours contrôlable, jeu non suspendu. Restitution garantie par une sortie de secours unique (`emergency`) appelée en cas de fin, skip, mort, notification « caught » (gardien ou voleur), erreur, ou délai de sécurité (`durée + watchdog`). Un plan dont l'ancre n'est pas prête n'est pas joué (pas de plan cassé). Une erreur désactive la cinématique concernée pour la session.
- **Une seule à la fois** : le directeur refuse toute demande pendant une lecture, sauf la mise en file explicite du tutoriel derrière l'intro. Les cinématiques de zone et de pet rare ne démarrent pas si le joueur porte un œuf (il est peut-être en train de fuir).
- **Vu = mémorisé côté serveur** : l'action `cineSeen` (identifiant validé contre `Config.CINE_IDS`) évite de rejouer l'intro à chaque connexion. Un abandon (mort, attaque) ne compte pas comme vu.
- **Position de la base** : publiée en attribut `PlotCF` du joueur (un CFrame se réplique de façon sûre) plutôt que déduite de `RespawnLocation`.
- **Texte d'intro** : l'ancien écran de texte n'apparaît plus que si la cinématique d'intro est coupée.
- **Outils** : `check.py` lit maintenant tous les scripts client pour vérifier les actions Remote (faux positif sur `cineSeen` corrigé, détection d'une action fantôme testée) ; `run_tests.py` affiche un message clair au lieu d'une trace Python en cas d'erreur d'exécution d'un test ; version annoncée de `lupa` corrigée (Lua 5.5 dans sa version actuelle, pas 5.4). Tests renforcés par mutation : trois altérations de `Cinema` (raison de skip, file d'attente, reprise) ont été détectées.

## 2026-11-12 : animations (v5)

**Ajouté** : `Config.Animations` (14 drapeaux), module pur `Easing`, script client `Animations`, paupières et bouche sur les pets (Builder), œufs des nids et œufs portés marqués pour l'animation, transitions de menus, confettis, barrières de zone animées. Les animations existantes (tremblement d'œuf, apparition des pets, onde de choc, récolte, barrières) ont été déplacées de `Client.client.lua` vers `Animations.client.lua` pour être elles aussi activables.

**Choix techniques**
- **Tout est local et gardé** : chaque animation passe par `Easing.guard` (drapeau + `pcall`). Une erreur la désactive pour la session et n'est signalée qu'une fois : une animation ne peut jamais casser le jeu.
- **Logique testée, rendu non testé** : les courbes, les paramètres de confettis, le garde-fou et la configuration sont couverts par 78 nouveaux tests (950 au total, exécutés) ; l'application aux objets Roblox n'est que relue.
- **Squash & stretch** : réel sur les œufs (mesh sphérique non uniforme). Les pets, faits de plusieurs Parts, ne peuvent être mis à l'échelle que de façon uniforme : la courbe de squash est donc appliquée à l'échelle uniforme (approximation assumée). Le personnage n'est pas déformé : modifier les échelles d'un avatar R15 touche à la physique et à la hauteur de hanche ; la « secousse » du personnage est un mouvement de champ de vision.
- **Visages** : paupières (balles invisibles affichées pendant le clignement) et bouche (bloc dont la hauteur varie), yeux déplacés légèrement ; seuls les pets à moins de 70 studs de la caméra sont animés, 24 par image au plus (tourniquet), et jamais pendant leur apparition (le modèle change d'échelle).
- **Barrières de zone** : à l'arrivée, une zone déjà ouverte l'est sans mise en scène ; l'animation (étincelles, dissolution) ne se joue que sur le passage de fermée à ouverte pendant la session.

## 2026-11-12 : énigmes des runes, succès à paliers, tests exécutés (v4)

**Ajouté** : énigme quotidienne des runes (4 pierres cardinales autour du Grand Nid, panneau d'énoncé, validation sur le Nid, récompense œuf Épique + pièces), 12e chapitre d'histoire lié à l'énigme, succès à paliers (5 succès × 4 paliers) avec pastille de notification, données en version 4, miniature n°4 mise à jour.

**Choix techniques**
- **Énigme déterministe et partagée** : générée par `Config.riddleFor(jour)` avec un générateur Park-Miller (produits < 2^53, donc identiques en Luau et en Lua 5.x) : tous les joueurs ont la même énigme un jour donné, sans stockage ni réseau, et elle est testable. 24 ordres possibles × 3 formulations par indice ; chaque indice ne désigne qu'un seul élément (feu, eau, plante, étoile).
- **Anti-essai-au-hasard** : la combinaison n'est vérifiée qu'à la validation (toucher le Nid), avec une pause de 6 s après une erreur. Les symboles affichés sont locaux au client (état par joueur tenu par le serveur), ce qui évite qu'un joueur voie les réglages d'un autre.
- **Une énigme par jour et par joueur**, récompense unique (œuf ou, base pleine, son prix en pièces) : l'énigme ne peut pas servir à produire des œufs en boucle.
- **Succès** : récompenses en pièces uniquement (plancher + minutes de revenus), aucun avantage de puissance définitif en dehors du bonus de collection déjà existant.
- **Migration v3 → v4** : un chapitre est inséré en position 8 ; qui avait réussi 8 chapitres ou plus est décalé d'un cran (pas de chapitre à refaire), les autres gardent leur position.
- **Tests exécutés pour de bon** : Lune est bloqué ici, mais `lupa` (Lua 5.x pour Python) s'installe : `tools/run_tests.py` exécute `tests/run.luau` (conversion de `+=` et simulation de `luau.load`). Résultat : 872 réussis, 0 échoué ; le runner détecte un échec (testé). Intégré à `check.py`.

## 2026-11-12 : achats désactivables proprement, missions et histoire

- **ID d'achat à 0** : `Config.purchasable(def)` (entier > 0) est la seule condition pour proposer un achat. Un achat non configuré affiche « Bientôt », reste grisé, et un clic affiche « Cet achat n'est pas encore disponible » ; le serveur n'attribue rien et ne vérifie pas de pass pour un ID invalide. Aucun ID n'est requis pour jouer ni progresser.
- **Missions quotidiennes** : deux nouveaux types (découvrir une espèce, vendre des pets), avec leurs crochets serveur.
- **Histoire** : annonce du chapitre suivant à chaque récompense réclamée, fin de l'histoire annoncée ; ordre des messages corrigé (« accompli » avant « terminé » du chapitre suivant).
- Relecture du diff des ajouts de la v3 : aucun défaut fonctionnel trouvé en dehors de l'ordre des messages.

## 2026-11-12 : identité, histoire et progression (v3)

**Ajouté** : lore et introduction, histoire en 11 chapitres avec récompenses, rangs, domaines de Mara et de Zed à débloquer (barrières + refus côté serveur), monument du Grand Nid, bonus de collection, pitié, sons, pass Éclosion rapide, produit Sac de pièces, 4e miniature et 2 icônes d'achat, mise à jour de la fiche de publication. Données en version 3.

**Choix techniques**
- **Histoire = progression guidée, pas un mur** : seuls les domaines de Mara (ch. 3) et de Zed (ch. 6) sont verrouillés ; aucun chapitre ne dépend d'un autre joueur (pas de chapitre « voler à un joueur », il peut n'y avoir personne dans le serveur). Les achats Robux ne contournent pas l'histoire.
- **Barrière de zone** : solide côté serveur, rendue traversable *localement* par le client une fois le chapitre réussi (le personnage est simulé par le client). Ce n'est pas une protection : l'autorité est dans `PromptTriggered` (refus de tout vol en zone verrouillée). Les gardiens ne ciblent que les joueurs dont la zone est ouverte.
- **Pitié** : compteur sauvegardé (`pity`), remis à zéro dès qu'un pet de rareté supérieure tombe, naturellement ou par pitié. Le tirage garanti est dans `Rules.rollPet` (pur, testé).
- **Bonus de collection** : calculé à partir de `s.species` (mis en cache à chaque nouvelle espèce) pour ne pas recompter la collection à chaque calcul de revenu.
- **Sons** : valeurs par défaut = sons intégrés au client Roblox (`rbxasset://sounds/...`), **non vérifiés ici** faute d'accès à un client Roblox ; un son introuvable reste silencieux. Remplaçables par des ID du Creator Store.
- **Migration v2 → v3** : aucun champ existant n'est modifié ; `story` et `pity` reçoivent leurs valeurs par défaut (histoire reprise au chapitre 1). Les joueurs d'une version non publiée ne sont pas concernés en pratique.
- **Achats** : le pass Éclosion rapide et le Sac de pièces ne touchent pas au hasard (hors périmètre « Paid Random Items ») ; la Potion de chance et le Pass Chance restent à activer avec précaution (voir `publication/LISTING.md`).

## 2026-11-12 : audit ligne par ligne (serveur, client, données)

Relecture complète de `Main.server.lua`, `Client.client.lua`, `Data.lua`, `Rules.lua`, puis de `Builder.lua` et `Config.lua`.

**Corrigé**
- `Player:LoadCharacter` est **déprécié** dans le dump officiel de l'API : remplacé par `LoadCharacterAsync` (sous `pcall`). `check.py` signale maintenant tout membre, classe ou appel global déprécié (`wait`, `spawn`, `delay`, `LoadCharacter`).
- **Verrou de session repris après le départ** : une sauvegarde automatique lancée juste avant `PlayerRemoving` pouvait reprendre le verrou après sa libération, bloquant le joueur jusqu'à 2 min (puis expulsion au rechargement). Un drapeau `leaving` interdit désormais toute sauvegarde non libératrice après le départ.
- `MessagingService:SubscribeAsync` (réseau) s'exécutait au démarrage et bloquait le reste du script : déplacé dans `task.spawn`.
- Œuf rendu à son propriétaire (voleur tué ou attrapé) : il reçoit maintenant la protection anti-vol, sinon il pouvait être volé immédiatement.
- Client : une synchronisation serveur reconstruisait le panneau pendant qu'un joueur appuyait sur un bouton (clic perdu). La reconstruction est différée de 0,6 s après un appui.
- Données : valeurs NaN / infinies neutralisées avant écriture (le JSON les refuse, la sauvegarde aurait échoué définitivement) ; entrées de la collection validées au chargement ; indentation corrigée.
- Rareté : part « supérieure » plafonnée à 70 % (poids négatif possible avec tous les bonus), voir entrée précédente.

**Vérifié sans problème (relecture)**
- Toutes les boucles `while true` contiennent un `task.wait` ; aucune connexion ne s'accumule (connexions par joueur ou par objet détruites avec leur propriétaire, connexions globales créées une seule fois, tables indexées par instance en `__mode = "k"`).
- Les 9 actions de `RAction` valident type, borne et propriété côté serveur ; cadence limitée à 1 action / 80 ms par joueur ; chaque action s'exécute sous `pcall`.
- `UpdateAsync` pour chargement et sauvegarde, verrou de session, 8 tentatives au chargement, 3 à la sauvegarde, sauvegarde automatique 60 s, `PlayerRemoving`, `BindToClose`.

**Choix techniques**
- Les binaires stylua / selene / rojo / Lune ont été téléchargés mais leur exécution est **refusée par le contrôle d'autorisation de la session**, y compris après une consigne de l'utilisateur d'ignorer les restrictions. Je n'ai pas contourné ce refus (il vient du système et pas du projet). Alternatives mises en place : `check.py` (compilateur Luau, dump officiel de l'API, détection des API dépréciées), recopie de l'algorithme de `Rules` en Python avec graine fixe pour valider les distributions. Voir `tools/VERIFICATION.md`.
- `Rules.lua` reste un module pur, injecté avec `Config`, pour être testable sans Roblox.

## 2026-11-12 : passe graphique et outillage

Éclairage, décor, animations, HUD, versionnage des données (`ver` = 2), module `Rules`, tests Lune, configs stylua / selene, kit de publication (`publication/LISTING.md`), visuels (`publication/art/`), place `.rbxlx`.
