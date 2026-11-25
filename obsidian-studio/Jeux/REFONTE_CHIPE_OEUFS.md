# Refonte de Chipe-Œufs (Jeu 2) : cahier des charges chiffré

Destinataire : la session de développement du jeu (`roblox/`, lieu de partie 87012762353093, hub 115261336085924).
Sources : carte-parchemin de l'utilisateur, planche des maisons 1 à 6, diorama du lac, code actuel (Config.lua, Builder.lua, Main.server.lua, Data.lua v9, Rules.lua, Guard.lua, Castle.lua).

## 0. Constats sur le code actuel (à connaître avant de commencer)

| Sujet | État actuel | Conséquence pour la refonte |
|---|---|---|
| Carte | Sol 1200×1200, anneau de 5 bases à 115 studs du Grand Nid (0,0), 3 plateaux en terrasses au nord (Gus h6, Mara h14, Zed h24), rivières droites z=330 et x=-380, lacs à (290,250) et (-480,-150) | Tout `Config.Map` est remplacé par `Config.Map2` (section A). Les plateaux disparaissent, sauf celui du château. |
| « Tapis roulant » | `Treadmill` 16×40 en (0,0.6,38) : un tapis d'**entraînement à la vitesse**, pas un tapis qui livre des œufs | Renommer l'existant « Piste d'entraînement » (clé `train` inchangée) et créer le vrai **tapis roulant central** qui livre des œufs (section B). Sans ce renommage, les joueurs confondent les deux. |
| Énigme | 4 runes autour du Grand Nid, indices sur un panneau et dans Missions > Énigme, Mère Poule est un décor muet (tag `Hen`) | Le joueur ne sait pas qu'elle existe ni quoi faire. Refaite en 3 étapes guidées avec PNJ parlant (section C). `Config.riddleFor` et `RUNE_CLUES` sont réutilisés. |
| Base | 8 niveaux d'apparence (`BASE_LEVELS`, `BASE_WEIGHTS` {1,3,8,20,50,150}, `baseScore`), aucun effet de jeu | Niveaux 2 à 7 = maisons des images 1 à 6, et chaque niveau donne des effets (section D). |
| Emplacements | `SLOT_COUNT = 12` (Data.lua:16), `Rules.capacity = 4 + up.slots` | Passe à 20 (section D/E), migration v9 → v10. |
| Vol PvP | ProximityPrompt sur l'œuf d'autrui, bouclier 20 s + Verrou, `graceUntil` 90 s | Conservé, complété par la porte de base, la protection débutant et le vol à distance payant. |
| Château | Mode de serveur réservé (`serverMode = "castle"`, origine `Castle.ORIGIN` (470,-280)), lancé depuis le hub | Le château devient aussi un repère visible au nord-est ; sa cour abrite le territoire de Zed ; l'entrée du donjon reste le mode existant. |

Conventions de ce document : 1 stud ; **Nord = -Z, Est = +X** (comme `RUNE_DIRECTIONS` et les domaines actuels) ; vitesse de marche de référence 16 studs/s (`Config.walkSpeed(0)`) ; temps à pied = distance / 16.

---

## A. Plan de la carte

### A.1 Cadre

- Zone jouable : **700 × 500 studs**, x ∈ [-350, 350], z ∈ [-250, 250]. Mur invisible au bord (`Config.Map2.bounds`).
- Décor de fond non praticable jusqu'à 900 × 700 (montagnes au nord, collines ailleurs), hors budget de collision (`CanCollide = false`, `CastShadow = false`).
- Sol : herbe (texture `grass` existante). Chemins pavés largeur 10 (`pathHalf = 5`), chemins de terre largeur 6 (`dirtHalf = 3`).

### A.2 Coordonnées de chaque élément

Clé de config proposée entre crochets. Centres (x, z) ; « r » = rayon d'emprise.

| Élément | Centre (x, z) | Emprise | Rôle |
|---|---|---|---|
| Place du marché [`plaza`] | (0, 0) | r 60, dallage pavé | Cœur social, zone sûre (aucun gardien, aucun vol entre joueurs) |
| Halle à dôme [`hall`] | (-40, 0) | r 18, dôme haut 30 | Sortie des œufs du tapis ; à l'intérieur : comptoir de la boutique d'œufs (raretés 1 à 4) |
| Tapis roulant central [`belt`] | de (-22, 0) à (38, 0) | 60 × 8, hauteur 2 | Livre les œufs (section B). Bac de fin en (42, 0) |
| Étals du marché [`stalls`] | (-35, 38), (5, 42), (40, 36) | 10 × 8 chacun | Améliorations, Pets/vente, Boutique Robux |
| Bassin-fontaine [`fountain`] | (10, -38) | r 7 | Point d'eau, décor |
| Piste d'entraînement (ancien Treadmill) [`track`] | (-60, -45) | 16 × 40, axe Z | Gagner de la vitesse (clé `train`) |
| Rose des portails [`portalHub`] | (0, -50) à (40, -50) | 4 arches espacées de 13 | Voyage rapide (A.4) |
| Grand Œuf de l'énigme [`bigEgg`] | (70, -20) | place r 22, œuf haut 16 | Énigme de la Mère Poule (section C) |
| Mère Poule [`hen`] | (52, -28) | PNJ, regarde le joueur | Donneuse de l'énigme |
| 4 pierres runiques [`runeStones`] | (70, -34) N, (84, -20) E, (70, -6) S, (56, -20) O | 2,4 × 5 | Étapes 2 et 3 de l'énigme |
| Base 1 (nord) | (0, -140) | carré 52 → 72 selon niveau | Base joueur, façade vers la place |
| Base 2 (ouest) | (-205, -45) | idem | idem |
| Base 3 (est) | (200, -45) | idem | idem |
| Base 4 (sud) | (-30, 165) | idem | idem |
| Base 5 (sud-est) | (175, 135) | idem | idem |
| Enclos sauvage [`wildPen`] | (75, -105) | 18 × 14, 3 nids | Œufs Communs sans gardien (premières minutes) |
| Territoire Gus Nord-Ouest [`terr.gusNW`] | (-95, -80) | r 40 ; enclos (-75,-100), (-120,-95), (-95,-55) | 1★, 1 chien |
| Territoire Gus Sud-Ouest [`terr.gusSW`] | (-120, 75) | r 40 ; enclos (-145,55), (-115,105), (-90,60) | 1★, 1 chien |
| Territoire Mara (sud-est) [`terr.mara`] | (85, 80) | r 42 ; enclos (65,70), (105,65), (90,110) | 3★, 2 loups |
| Château [`castle`] | donjon (300, -205), cour (265, -170) | plateau h 10 : x 215..345, z -250..-135 | Repère nord-est, territoire de Zed dans la cour, porte du donjon (mode Château) en (300, -185) |
| Territoire Zed (cour du château) [`terr.zed`] | (265, -170) | r 38, enclos (240,-160), (265,-185), (290,-160) | 5★, 3 ours, herse à l'entrée de la cour (240, -138) |
| Arène de combat (colisée) [`arena`] | (-265, 165) | r 42 extérieur, sable r 28, entrée vers le nord-est (-235, 135) | Arène des Pets (tour existante) + gradins |
| Lac du Moulin (diorama) [`lakes[1]`] | (-285, -105) | r 38, rive de sable +5 | Point d'eau, cabane du pêcheur (-300, -58), chemin de terre courbe sur la rive est, buissons ronds rive sud, ponton (-262, -90) |
| Lac des Saules [`lakes[2]`] | (280, 200) | r 32 | Point d'eau sud-est, ponton (255, 185) |
| Rivière du Nord [`rivers[1]`] | polyligne (-350,-205) (-200,-212) (-60,-208) (60,-198) (150,-160) (215,-118) (285,-105) (350,-110) | largeur 22 | Sépare le château du reste ; infranchissable hors ponts |
| Ruisseau du Moulin [`rivers[2]`] | (-285,-143) → (-288,-197) | largeur 8 | Relie le lac à la rivière |
| Ruisseau des Saules [`rivers[3]`] | (248,205) (150,232) (20,238) (-120,236) | largeur 6, gué à pierres plates | Décor sud, franchissable à gué (vitesse x0,7) |
| Cascade [`waterfall`] | (330, -138) | haut 10 | Du plateau du château vers la rivière |
| Pont du Château [`bridges[1]`] | (215, -118), axe N-S | 12 × 30, pierre (`scn_pont_pierre`) | **Seul** accès à la cour de Zed |
| Pont Nord [`bridges[2]`] | (-20, -203), axe N-S | 6 × 28, bois | Accès à la colline nord (plume) |
| Pont du Moulin [`bridges[3]`] | (-286, -170), axe E-O | 6 × 14, bois | Passe le ruisseau du Moulin |
| Forêt Ouest [`forests[1]`] | rectangle x -350..-310, z -40..120 | 40 arbres max | Bord ouest |
| Forêt Nord [`forests[2]`] | x -350..340, z -250..-222 (hors château) | 50 arbres max | Derrière la rivière |
| Forêt Est [`forests[3]`] | x 312..350, z -60..150 | 25 arbres max | Bord est |
| Forêt Sud [`forests[4]`] | x -200..230, z 228..250 | 40 arbres max | Bord sud, le long du ruisseau |
| Bosquets | (-160,-150), (140,-20), (-200,120), (60,190) | r 12, 6 arbres | Ombre, couverture contre les gardiens |
| Collines | NO (-300,-232) h18 r40 ; N (120,-238) h14 r35 ; SO (-330,235) h12 r30 ; SE (330,240) h10 r30 | Terrain ou Parts en dômes aplatis | Relief de fond, non praticables au-delà de h 6 |

Contrôles de distances (bord à bord, à imposer par test) : base ↔ territoire ≥ 16 studs au-delà de la demi-emprise maximale (36) ; base ↔ eau ≥ 12 ; territoire ↔ place ≥ 12 ; aucun chemin pavé ne traverse un territoire.

### A.3 Chemins et temps à pied (16 studs/s)

Routes pavées : place → chaque base (ligne droite ou un coude) ; place (40,-40) → (140,-75) → Pont du Château (215,-118) → porte de la cour (240,-138) ; place → B4 avec embranchement J (-20,110) → (-150,145) → entrée de l'arène (-235,135) ; B2 → lac du Moulin en chemin de terre (-205,-45) → (-255,-70).

| Trajet | Distance | Temps |
|---|---|---|
| Place (0,0) → B1 | 140 | 8,8 s |
| Place → B2 | 210 | 13,1 s |
| Place → B3 | 205 | 12,8 s |
| Place → B4 | 168 | 10,5 s |
| Place → B5 | 221 | 13,8 s |
| B1 ↔ B2 (voisins) | 226 | 14,1 s |
| B1 ↔ B3 (voisins) | 221 | 13,8 s |
| B3 ↔ B5 (voisins) | 182 | 11,4 s |
| B5 ↔ B4 (voisins) | 207 | 12,9 s |
| B2 ↔ B4 | non voisins (l'arène et Gus SO les séparent) : par la place 23,6 s | — |
| Place → enclos sauvage | 128 | 8,0 s |
| Place → centre Gus NO / Gus SO / Mara | 124 / 141 / 117 | 7,8 / 8,8 / 7,3 s |
| Place → cour de Zed par le pont | ≈ 300 | ≈ 19 s (difficulté voulue ; portail une fois débloqué) |
| Place → arène | ≈ 290 | ≈ 18 s (portail dès le début) |

### A.4 Portails de voyage rapide (`Config.TRAVEL2`)

| Portail (rose, place) | Arrivée | Retour posé à | Débloqué |
|---|---|---|---|
| Arène | (-225, 135) | (-215, 128) | dès le départ |
| Pont du Château (rive sud) | (205, -95) | (195, -90) | chapitre 6 (comme `ZONES[3]`) |
| Lac du Moulin | (-245, -75) | (-238, -68) | dès le départ |
| Lac des Saules | (240, 175) | (232, 170) | dès le départ |

Règles serveur conservées (`cooldown = 4`, `combatLock = 4`, distance ≤ 10 au portail) + **nouvelle : `blockWhileCarrying = true`** (on ne téléporte jamais un œuf : le trajet retour fait partie de la difficulté). Chaque base a un tapis « 🏠 Retour à la base » sur la place (une arche par base, en (−30..30, 50)).

### A.5 Gardiens et territoires

| Gardien | Rival | Postes (x, z) | Territoire | Modèle |
|---|---|---|---|---|
| Gus 1★ | 1 chien | (-95, -80) | disque r 40 autour de (-95,-80) | `guards.dog` |
| Gus 1★ | 1 chien | (-120, 75) | disque r 40 autour de (-120,75) | `guards.dog` |
| Mara 3★ | 2 loups | (72, 82), (100, 82) | disque r 42 autour de (85,80) | `guards.wolf` |
| Zed 5★ | 3 ours | (240,-165), (265,-180), (290,-165) | disque r 38 autour de (265,-170), murs de la cour | `guards.bear` |

`Guard.clampToDisc` est réutilisé avec le centre et le rayon du territoire (au lieu du plateau). `Config.GUARD.safeRadius` devient 16 studs autour de l'entrée de chaque territoire et toute la place.

### A.6 Points d'eau (récapitulatif)

Lac du Moulin, Lac des Saules, Rivière du Nord, deux ruisseaux, cascade, bassin-fontaine, douve décorative au pied du plateau du château (largeur 6, côté sud seulement, sous le pont). Eau en Parts `Water` avec texture `water` existante (cibles à renommer `RiverNorth`, `BrookMill`, `BrookWillow`, `LakeMill`, `LakeWillow`, `Fountain`). Nage : vitesse 10 ; murs invisibles sur la rivière du Nord sauf aux ponts (`bridgeHalfGap = 6`, logique existante).

---

## B. Boucle de jeu et difficulté pour récupérer des œufs

### B.1 Sens du jeu (à afficher dans l'intro et sur l'écran de chargement)

« Le Grand Œuf s'est endormi et la Couvée s'est dispersée. Récupère des œufs (au tapis du marché, dans les enclos gardés, ou chez les autres Chipeurs), fais-les éclore, et plus tes pets sont rares, plus ta maison grandit, de l'enclos au château doré. Chaque jour, aide la Mère Poule à réveiller le Grand Œuf. »

Trois buts lisibles en permanence dans le HUD : ① niveau de maison (barre de progression), ② énigme du jour (étape x/3), ③ prochain chapitre d'histoire.

### B.2 Qui apparaît où

| Quoi | Où | Quand |
|---|---|---|
| Joueur | Spawn de sa base (devant la maison, côté place) | Arrivée, mort, retour |
| Œuf de départ | Emplacement 1 de sa base, éclosion 6 s (conservé) | Premier lancement |
| Œufs du tapis | Sortie de la halle (-22, 0), avancent vers +X | Toutes les 5 s (3 s en Tapis doré) |
| Œuf de bienvenue | Sur le tapis, étiqueté au nom du joueur, gratuit | Une fois, 20 s après l'arrivée si `hatched < 5` |
| Œufs d'enclos | Nids des enclos (2 par enclos, 3 dans l'enclos sauvage) | Réapparition après vol : sauvage 12 s, Gus 9-16 s, Mara 12-21 s, Zed 18-32 s |
| Plumes de l'énigme | 1 par direction, parmi 3 emplacements par direction (C.4) | Chaque jour à 00:00 UTC |
| Gardiens | Postes A.5 | Démarrage du serveur |

### B.3 Comment on obtient un œuf

1. **Tapis roulant central (achat en pièces)**. L'œuf affiche sa rareté (couleur, nom, prix) **avant** l'achat : aucune surprise sur la rareté. ProximityPrompt « Acheter 🪙 X » (HoldDuration 0,3 s, distance 10). Le premier joueur validé par le serveur l'emporte ; l'œuf passe dans les bras (`s.carry`) et doit être porté jusqu'à la base.
   - Vitesse du tapis 3 studs/s, longueur 60 : un œuf reste 20 s ; au bout, il tombe dans le bac et disparaît. 12 œufs au plus en même temps.
   - Prix = `Config.EGG_PRICE[tier] × 0,6` (`Config.BELT.priceRatio = 0.6`) : le tapis est moins cher que la boutique (raretés 1 à 4 à prix plein, rareté garantie). Mythique et Cosmique ne s'achètent **qu'au tapis**.
   - Anti-monopole : 1 achat par joueur toutes les 3 s ; un œuf Légendaire ou plus est annoncé (son + lumière) et son prompt ne s'active qu'après 2 s ; 1 œuf Légendaire+ par joueur et par 60 s.
2. **Enclos gardés (vol gratuit)**. Maintenir le prompt sur un nid ; tirage de rareté par territoire (tableau B.5).
3. **Vol entre joueurs**. Œuf en incubation chez un autre joueur, bouclier expiré, porte de base ouverte, voleur et victime hors protection débutant.
4. **Récompenses** : énigme (Épique), missions, tour des Dresseurs, succès (inchangés).

### B.4 Obstacles croissants

| Obstacle | Sauvage | Gus 1★ | Mara 3★ | Zed 5★ |
|---|---|---|---|---|
| Chapitre requis (`ZONES`) | 0 | 0 | 3 | 6 |
| Gardiens | 0 | 1 chien (par territoire) | 2 loups | 3 ours |
| Vitesse poursuite / patrouille | — | 9,5 / 4,5 | 19 / 10 | 26 / 13 |
| Vue (studs / degrés) / ouïe | — | 16 / 80 / 7 | 28 / 110 / 14 | 32 / 120 / 16 |
| Temps de vol de base (`stealHold`) | 0,8 s | 1,3 s | 2,2 s | 3,5 s |
| Pièges | aucun | aucun | 3 fils à clochettes par territoire (alerte les 2 loups), 2 flaques de boue (vitesse x0,6 pendant 2 s) | herse de la cour (ouverte 3 s, fermée 3 s), 4 dalles d'alarme, 2 lanternes tournantes (cône de vue 30 studs, 0,5 tour/s) |
| Chronomètre de fraîcheur | — | — | — | œufs Légendaire+ : 75 s pour atteindre sa base, sinon l'œuf retourne à son nid (message « L'œuf a refroidi et regagne son nid ») |
| Vigilance | — | +15 % vue et ouïe par vol réussi dans les 60 s, max +45 %, retour à la normale 30 s après le dernier vol | idem | idem |
| Coup du gardien | — | 10 pv, 6 s de répit (`gentle`) | 20 pv | 28 pv |
| Prise par un gardien | — | l'œuf retourne au nid | idem | idem |

`stealHold` est multiplié par `0,85 ^ Doigts agiles` (formule `Config.stealTime` généralisée : `Config.stealTime(level, terr) = Config.TERR[terr].hold * 0.85 ^ level`).

**Poids et portée** (`Config.CARRY.weight`) : vitesse en portant un œuf, par rareté : 1,00 / 1,00 / 0,95 / 0,90 / 0,85 / 0,80 ; plusieurs œufs : produit, plancher 0,70. Un porteur d'œuf Légendaire+ émet une colonne de lumière visible à 120 studs (les autres le voient).

**Porte de base** : bouton « 🔒 Fermer la porte » dans sa base ; barrière lumineuse à l'entrée, durée selon le niveau (D.2), recharge 60 s. Serveur : refuse tout vol d'emplacement tant que `lockUntil > now`.

**Protection débutant** (`Config.NEWBIE = { minutes = 15, untilLevel = 3 }`) : tant que le joueur a joué moins de 15 min cumulées ET que sa maison est sous le niveau 3, ses œufs ne peuvent pas être volés (ni physiquement, ni à distance), et il ne peut pas voler d'autres joueurs. Fin anticipée possible (bouton « Je suis prêt pour le PvP »). Badge 🐣 au-dessus de la tête.

### B.5 Tableaux de probabilités (affichés en jeu)

Rareté à l'apparition (en %). Ordre : Commun / Rare / Épique / Légendaire / Mythique / Cosmique.

| Source | C | R | É | L | M | Co | Clé |
|---|---|---|---|---|---|---|---|
| Tapis standard | 62 | 26 | 9 | 2,6 | 0,37 | 0,03 | `Config.BELT.weights.normal` |
| Tapis doré (produit serveur) | 40 | 34 | 18 | 6,5 | 1,35 | 0,15 | `Config.BELT.weights.golden` |
| Enclos sauvage | 100 | 0 | 0 | 0 | 0 | 0 | `Config.TERR.wild.weights` |
| Gus | 60 | 35 | 5 | 0 | 0 | 0 | `RIVALS[1].weights` (inchangé) |
| Mara | 0 | 40 | 40 | 20 | 0 | 0 | `RIVALS[2].weights` (inchangé) |
| Zed | 0 | 0 | 30 | 45 | 22 | 3 | `RIVALS[3].weights` (inchangé) |

Fréquences attendues sur le tapis standard (12 œufs/min, serveur entier) : 1 Légendaire toutes les 3,2 min, 1 Mythique toutes les 22,5 min, 1 Cosmique toutes les 4,6 h. Tapis doré (20/min) : 1 Légendaire / 46 s, 1 Mythique / 3,7 min, 1 Cosmique / 33 min.

À l'éclosion (inchangé, déjà conforme) : l'œuf fixe la rareté du pet ; amélioration d'un cran 5 % + Trèfle (1/niveau) + pass Chance 10 + événement 5 + potion 25, plafond 70 (`Rules.MAX_UP`) ; jamais de rétrogradation ; tailles et mutations selon `Config.SIZES` / `Config.MUTS`. Le panneau du tapis affiche les deux tables de rareté et un lien « 🎲 Probabilités » vers `Config.oddsText()`.

### B.6 Début non frustrant (cibles testées)

| Étape | Cible |
|---|---|
| Première éclosion (œuf de départ 6 s) | < 15 s (actuel conservé), exigence < 60 s |
| Premier œuf récupéré hors base (bienvenue au tapis ou enclos sauvage) | < 60 s |
| Premier vol réussi chez Gus | < 4 min |
| Aucun dégât subi avant 3 min de jeu | 100 % des joueurs-robots |
| Aucun œuf volé par un joueur avant la fin de la protection débutant | testé |

Onboarding (`Config.onboarding`) : 1 « touche ton œuf » (existant) → 2 « prends l'œuf de bienvenue sur le tapis » (flèche vers (10,0)) → 3 « pose-le dans ta base » → 4 « chipe un œuf dans l'enclos sauvage » (flèche vers (75,-105)). Chaque étape passable.

---

## C. Énigme de la Mère Poule

### C.1 Principe

La Mère Poule se tient devant le Grand Œuf (52, -28). Chaque jour, le Grand Œuf « s'endort ». Pour le réveiller : **① trouver 4 plumes dorées** (une par direction) qui portent chacune un indice, **② régler les 4 runes** autour du Grand Œuf selon ces indices, **③ répéter la berceuse** (suite de runes qui s'allument). Même énigme pour tous un jour donné (déterministe, `Config.riddleFor(day)` réutilisée pour les réponses des runes).

Disponible à partir du chapitre 2 réussi (≈ 3 min de jeu). Le chapitre 8 « Le murmure des runes » devient « La berceuse du Grand Œuf » (texte : « Aide la Mère Poule : trouve les 4 plumes, règle les runes, chante la berceuse. »).

### C.2 Comment le joueur comprend immédiatement

- Dès que l'énigme est disponible et non faite : un « ❗ » doré flotte au-dessus de la Mère Poule (visible à 150 studs), une pastille « 1 » sur l'onglet Énigme, et la carte d'objectif du HUD affiche « 🐔 La Mère Poule t'appelle ». Flèche/faisceau jaune existant vers elle.
- Parler = ProximityPrompt « Parler » (distance 12) → bulle de dialogue (UI en bas, portrait, texte qui s'écrit à 40 caractères/s, bouton « Suivant »).
- Après acceptation : carte de quête permanente « 📜 Berceuse du jour : étape 1/3, Plumes 0/4 » ; le faisceau guide vers le **quart** de carte de la plume la plus proche (centre du quart), puis, à moins de 40 studs, la plume scintille (particules + son « secret ») et le faisceau pointe dessus.
- Mini-carte : icône 🪶 sur les plumes non ramassées situées à moins de 90 studs.

### C.3 Dialogues exacts

Premier contact (une fois dans la vie du profil) :
1. « Cot ! Enfin un Chipeur au cœur honnête… Approche, petit. »
2. « Ce grand œuf de pierre, c'est le cœur de la Couvée. Chaque nuit, il s'endort, et seule ma berceuse peut le réveiller. »
3. « Mais le vent a dispersé mes quatre plumes dorées : une au Nord, une à l'Est, une au Sud, une à l'Ouest. »
4. « Rapporte-les-moi, règle les runes comme elles te le disent, puis chante avec moi. Le Grand Œuf saura te remercier. »
Boutons : [« J'y vais ! »] [« Explique encore »].

« Explique encore » : « Trois étapes. ① Trouve les 4 plumes dorées : la flèche jaune t'y mène. ② Chaque plume parle de la rune de sa direction : tourne cette rune sur le bon symbole, puis touche le Grand Œuf. ③ Les runes s'allument dans un ordre : touche-les dans le même ordre. »

Contacts suivants, énigme du jour non commencée : « Le Grand Œuf dort encore. Mes plumes se sont envolées de nouveau… Tu m'aides ? » [« J'y vais ! »] [« Plus tard »].

Pendant l'étape 1 : « Il te manque {4-n} plume(s). Cherche du côté {liste des directions manquantes}. »

Ramassage d'une plume (notification + journal) : « 🪶 Plume du {Nord|de l'Est|du Sud|de l'Ouest} : « {indice} » » — exemple : « 🪶 Plume du Nord : « ce qui coule et berce » ».

Quatre plumes réunies : « Les quatre plumes ! Chacune parle de sa rune. Tourne-les autour du Grand Œuf, puis touche-le. »

Validation des runes ratée : « Hmm… {k} rune(s) sur 4 chantent juste. Relis tes plumes. » (pause `RUNE_LOCK_SECONDS = 6` conservée).

Runes justes : « Les runes vibrent ! Écoute bien la berceuse… et répète-la. »

Berceuse ratée : « Cot-cot, pas tout à fait ! Je te la rechante. »

Réussite : « Le Grand Œuf s'éveille ! Tiens, ce petit trésor est pour toi. Reviens demain : il se rendort à minuit. »

Déjà faite : « Tu as déjà chanté aujourd'hui. Nouvelle berceuse dans {h} h {mm}. »

Pas encore disponible : « Reviens quand tu auras chipé ton premier œuf, petit. Mes plumes ne se montrent qu'aux vrais Chipeurs. »

Indice demandé (étape 1) : « Un coup de bec ? La plume {de la direction} se cache {description du lieu}. » ; (étape 2) : « La rune {de la direction} veut {symbole}. »

### C.4 Étape 1 : les quatre plumes

12 emplacements, 3 par direction ; le jour choisit un emplacement par direction (`Config.featherSpots(day)`, même générateur `dayRng`). Tous hors territoires gardés.

| Direction | Emplacement A | B | C |
|---|---|---|---|
| Nord | colline nord, après le Pont Nord (-20, -228) « au-delà du pont de bois » | colline nord-ouest (-280, -225) « sur la colline des vents » | bosquet nord (120, -232) « sous les sapins de la colline » |
| Est | rive sud du Pont du Château (215, -100) « au pied du pont de pierre » | cascade (325, -120) « près de l'eau qui tombe » | forêt est (330, 40) « à l'orée du bois de l'Est » |
| Sud | Lac des Saules (250, 190) « sur le ponton des saules » | bosquet sud (60, 195) « entre les arbres du sud » | derrière la base 4 (-60, 215) « près du ruisseau du Sud » |
| Ouest | cabane du pêcheur (-300, -58) « devant la cabane du lac » | gradins de l'arène (-265, 120) « sur les gradins de l'arène » | forêt ouest (-330, 40) « au fond du bois de l'Ouest » |

Ramassage : prompt « Ramasser » (HoldDuration 0,5), serveur vérifie distance ≤ 10 et que l'emplacement est celui du jour. Chaque plume est visible de tous mais ramassée **par joueur** (état local `puzzle.feathers` bitmask 4 bits ; la plume disparaît localement chez celui qui l'a prise).

### C.5 Étape 2 : les runes

Pierres runiques aux 4 points cardinaux du Grand Œuf (A.2). Prompt « Tourner la rune » fait défiler 🔥 🌊 🌿 ⭐ (existant). Validation : prompt « Poser la combinaison » sur le Grand Œuf. Retour : nombre de runes justes (pas lesquelles). Réponse = `Config.riddleFor(day).answer`. Indices = `RUNE_CLUES` déjà écrits (« ce qui coule et berce » = 🌊, etc.). Une rune ne se tourne qu'une fois la plume de sa direction ramassée (sinon : « La rune {dir} attend sa plume »).

### C.6 Étape 3 : la berceuse

Les 4 runes s'allument une à une (0,8 s chacune, 0,3 s d'écart) avec une note distincte, suite de **5** symboles tirée du jour (`Config.lullabyFor(day)`, chaque symbole présent au moins une fois). Le joueur touche les pierres dans le même ordre (prompt « Chanter »). Erreur : la suite est rejouée, pas de pause. Bouton « 🔁 Réécouter » illimité. Serveur : garde la position attendue, refuse les touches à < 0,25 s d'intervalle.

### C.7 Récompense, cycle, aide

- Récompense : un œuf Épique (`PUZZLE_EGG_TIER = 3`, ou son prix si base pleine) + `max(2000, 10 min de revenus)` (`PUZZLE_MINS`) + 1 **Fragment du Grand Œuf** (`puzzle.fragments`). 7 fragments (cumulés, pas forcément consécutifs) = 1 œuf Légendaire et le titre « Ami de la Mère Poule ». Succès « Déchiffreur » inchangé.
- Effet collectif : 3 énigmes résolues sur le même serveur le même jour → événement « Pluie de chance » gratuit de 5 min pour tous (clé `luck` existante), une fois par jour et par serveur.
- Cycle : `day = os.time() // 86400` (00:00 UTC = 01:00 heure de Paris en hiver). Le panneau affiche le compte à rebours. Progression intermédiaire sauvegardée (`puzzle.day`, `puzzle.step`, `puzzle.feathers`, `puzzle.hints`) ; changement de jour en cours de route : remise à zéro.
- Aide : bouton « 💡 Un coup de bec » chez la Mère Poule. Indice 1 gratuit après 5 min passées dans l'étape courante ; indice 2 après 3 validations ratées (étape 2). Indices limités à 2 par jour. Aucun indice payant.
- Journal : onglet Missions > Énigme affiche les 3 étapes, les plumes trouvées avec leur texte, les runes réglées, le compte à rebours.

---

## D. Maison évolutive

### D.1 Score pondéré par la rareté

`Config.BASE_WEIGHTS = { 1, 4, 15, 50, 180, 700 }` (Commun → Cosmique ; un pet secret compte comme Cosmique). Le score est cumulatif (chaque pet éclos ajoute ses points ; un pet volé ou vendu ne fait pas redescendre). Les deux derniers niveaux exigent en plus une rareté découverte : c'est la rareté qui fait grimper, pas la quantité de Communs (100 Communs = 100 points ; 1 Mythique = 180).

Migration v9 → v10 : recalcul depuis `dex` avec les nouveaux poids (comme la migration v7 → v8) et `baseLevelFloor = niveau atteint en v9` : le niveau affiché vaut `max(niveau calculé, baseLevelFloor)` (jamais de recul pour un joueur existant).

### D.2 Table des niveaux

| Niv. | Nom | Modèle | Emprise plateforme | Seuil | Condition | Emplacements bonus | Revenu | Porte de base | Autres |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Enclos de bois | `base.level1` (existant) | 52 × 52 | 0 | — | +0 | +0 % | — | — |
| 2 | Chalet du Couvoir | image 1 (toit mansardé, pilotis) `house.l2` | 56 × 56 | 15 | — | +1 | +5 % | 20 s | — |
| 3 | Maison-Tour | image 2 (haute, étroite, balcons) `house.l3` | 58 × 58 | 60 | — | +1 | +10 % | 25 s | alarme d'intrusion (notification quand un autre joueur entre) |
| 4 | Maison à l'auvent | image 3 (auvent, caravane) `house.l4` | 60 × 60 | 200 | — | +2 | +15 % | 30 s | — |
| 5 | Maison au garage | image 4 (garage, terrasse) `house.l5` | 64 × 64 | 600 | — | +2 | +20 % | 35 s | chien de garde de base : un intrus est ralenti x0,7 pendant 3 s à l'entrée |
| 6 | Villa moderne | image 5 (moderne, garage) `house.l6` | 66 × 66 | 1 800 | — | +3 | +30 % | 40 s | — |
| 7 | Grande villa | image 6 (grande moderne) `house.l7` | 68 × 68 | 5 000 | ≥ 1 Légendaire découvert | +3 | +40 % | 50 s | — |
| 8 | Château doré | `house.l8` (nouveau, doré) | 72 × 72 | 14 000 | ≥ 1 Mythique découvert | +4 | +50 % | 60 s | bouclier d'œuf posé +10 s |

Clés : `Config.BASE_LEVELS[i] = { score, name, emoji, model, size, slots, income, lock, needTier }`. Le revenu de niveau s'applique comme multiplicateur dans `Rules.income` (mult). Cibles de rythme (joueur-robot actif, à vérifier par `tests/Economy.lua`) : niveau 2 < 3 min, niveau 4 < 30 min, niveau 6 < 2 h, niveau 8 > 5 h. Si la simulation sort des cibles, ajuster les seuils, jamais les poids.

### D.3 Emplacements

Capacité = 4 + `up.slots` (0..8) + bonus de niveau (0..4) + pass `ExtraSlots` (4) = **20 au maximum**. `SLOT_COUNT = 20`. Grille 5 colonnes × 4 rangées, pas de 9 studs (45 × 36), dans la moitié avant de la plateforme (côté place) ; maison dans la moitié arrière, façade vers la place. `Config.padLocal(idx)` : `col = (idx-1) % 5`, `row = (idx-1) // 5`, `x = -18 + col*9`, `z = -4 + row*9` (repère local, -Z vers la place). Emplacement non débloqué : cadenas + coût affiché.

### D.4 Animation de montée de niveau

Durée totale 4,5 s, non bloquante, skippable (Cinema existant) : ① échafaudage de bois qui monte autour de l'ancienne maison (0,8 s) ; ② nuage de poussière + `VfxKit` « onde » (0,4 s) ; ③ l'ancienne maison descend dans le sol, la nouvelle monte avec squash & stretch (`Easing`) (1,5 s) ; ④ confettis `reward`, fanfare (`fanfare`), bannière « 🏠 Niveau 5 : Maison au garage ! +2 emplacements, revenus +20 % » (1,8 s). Caméra : plan large sur la base pour le propriétaire seulement, si le joueur ne porte pas d'œuf et n'est pas poursuivi. Les autres joueurs voient la transformation sans caméra. Annonce serveur à partir du niveau 6.

---

## E. Monétisation honnête

### E.1 Principes (à respecter dans le code et la fiche)

- Toute rareté d'œuf est **visible avant** l'achat en pièces (tapis) ; aucun produit Robux ne vend un œuf dont la rareté est tirée au sort.
- Les bonus de chance sont des **valeurs fixes affichées** (+10 points, +25 points, +5 points), plafond 70 %.
- Probabilités affichées : panneau du tapis, menu 🎲, fiche de chaque produit qui touche au hasard (`ExclusiveEgg` : taille et mutation ; `PrivateBelt` ; `GoldenBelt`).
- `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` : si vrai, masquer et refuser `ExclusiveEgg`, `PrivateBelt`, `GoldenBelt`, `LuckPotion`, `Lucky`, `ServerLuck` pour ce joueur.
- Rien de payant ne renforce un pet au combat (règle existante de l'Arène).
- Aucun produit de protection contre le vol à distance n'est vendu (pas de racket) : les protections sont gratuites.

### E.2 Catalogue (existants conservés + nouveaux)

| Nom affiché | Type | Clé | Prix suggéré | Description affichée |
|---|---|---|---|---|
| Revenus x2 | Pass | `PASSES.Coins2x` (2093291260) | 199 | inchangé |
| Chance +10 % | Pass | `PASSES.Lucky` (2093447290) | 149 | « +10 points de chance d'amélioration d'un cran à l'éclosion (5 % → 15 %). » |
| Éclosion rapide | Pass | `PASSES.Fast` | 149 | inchangé |
| Vitesse +20 % | Pass | `PASSES.Speed` | 149 | inchangé |
| Base VIP | Pass | `PASSES.VipBase` | 399 | inchangé |
| **+4 emplacements** | Pass (nouveau) | `PASSES.ExtraSlots` | 249 | « 4 emplacements d'œufs en plus dans ta base, pour toujours (jusqu'à 20). » |
| **Tapis privé** | Pass (nouveau) | `PASSES.PrivateBelt` | 299 | « Un petit tapis au milieu de ta base : un œuf gratuit toutes les 2 min tant que tu joues (probabilités du tapis standard, affichées). » |
| Potion de chance | Produit | `PRODUCTS.LuckPotion` | 99 | « +25 points de chance d'amélioration pendant 15 min. » |
| **Pluie de chance pour tous** | Produit (nouveau) | `PRODUCTS.ServerLuck` | 129 | « 10 min de +5 points de chance d'amélioration pour tout le serveur. Ton nom est remercié. » |
| **Tapis doré** | Produit (nouveau) | `PRODUCTS.GoldenBelt` | 99 | « 10 min : le tapis du marché livre un œuf toutes les 3 s au lieu de 5, avec la table « doré » (affichée). Pour tout le serveur. Cumulable jusqu'à 30 min. » |
| **Corbeau chipeur** | Produit (nouveau) | `PRODUCTS.RemoteSteal` | 79 | « 1 jeton de vol à distance. Le corbeau tente de rapporter un œuf en incubation d'un joueur du serveur. La victime peut le chasser ; si ça échoue, ton jeton t'est rendu. » |
| **3 Corbeaux chipeurs** | Produit (nouveau) | `PRODUCTS.RemoteStealPack` | 199 | « 3 jetons de vol à distance. » |
| Pack de départ, Œuf exclusif Mythique, Relance, Éclosion instantanée, Sac de pièces | Produits | existants | inchangés | inchangées |

Tant qu'un `id` vaut 0 : offre masquée (comportement actuel `Config.purchasable`). Les nouveaux produits sont à créer par le propriétaire (ou par l'API, comme le 21 nov) et listés dans `PUBLICATION.md` §3bis.

### E.3 Vol à distance (Corbeau chipeur) : règles exactes

`Config.REMOTE_STEAL = { tokenMax = 5, dailyMax = 3, maxTier = 4, flightSeconds = 8, victimCooldown = 1200, postStealShield = 300, compensationRatio = 0.5, levelGap = 1, minEggSecondsLeft = 10 }`

1. L'achat crédite un **jeton** (`data.tokens.remoteSteal`, plafond 5). ProcessReceipt reste idempotent (`receipts` existant). Le jeton se dépense en jeu, ce qui permet de le rendre en cas d'échec sans remboursement Robux.
2. Menu « 🐦‍⬛ Corbeau » : liste des joueurs **du même serveur** éligibles, puis leurs œufs éligibles (rareté et temps restant visibles).
3. Éligibilité de la cible : pas en protection débutant ; pas sous `victimCooldown` (1 vol à distance reçu par 20 min) ; pas sous bouclier post-vol (5 min après **tout** vol subi, physique ou à distance) ; niveau de maison ≥ niveau du voleur - 1 (on ne vise pas plus petit que soi) ; si la cible est amie du voleur et a coché « Refuser les corbeaux de mes amis » (`settings.blockFriendRavens`, défaut : non coché, réglable dans Plus > Réglages), refus ; pas en mode Château ; pas dans les 90 s de `graceUntil`.
4. Éligibilité de l'œuf : en incubation, rareté ≤ Légendaire (`maxTier = 4`), bouclier d'œuf expiré, plus de 10 s avant éclosion. Jamais un pet éclos.
5. Le voleur doit avoir un emplacement libre (vérifié avant le décollage).
6. Vol : un corbeau part de la place et survole la base cible pendant 8 s. La victime reçoit une bannière + son : « 🐦‍⬛ Le corbeau de {voleur} vise ton œuf {rareté} ! Touche l'œuf pour le chasser (8 s). » Si elle touche le pad dans les 8 s (présente dans sa base), échec : jeton rendu, message au voleur « {victime} a chassé ton corbeau. Jeton rendu. »
7. Réussite : l'œuf (temps restant conservé) va dans la base du voleur avec un bouclier d'œuf normal. Victime : « Le corbeau de {voleur} a emporté ton œuf {rareté}. Tu reçois 🪙 {50 % du prix} et 5 min de bouclier. » Indemnité = `floor(EGG_PRICE[tier] × 0,5)` pièces, créditée par le serveur.
8. Plafonds : 3 vols à distance réussis par voleur et par jour UTC (`dailyMax`) ; 1 corbeau en vol à la fois par voleur.
9. Le nom du voleur est toujours affiché (pas d'anonymat). Journal « Qui m'a volé ? » (10 dernières entrées, physiques et à distance) dans Plus.

### E.4 Tapis premium

- **Tapis doré** (serveur) : `Config.BELT.golden = { interval = 3, seconds = 600, maxSeconds = 1800 }`. Les deux tables sont affichées sur le panneau du tapis, la table active en surbrillance, avec le compte à rebours et « Offert par {nom} ».
- **Tapis privé** (pass) : petit tapis 10 × 3 au centre de la base (entre maison et emplacements), 1 œuf toutes les 120 s **tant que le joueur est actif** (`Config.IDLE.seconds`), 3 œufs en attente au plus, table standard, gratuit à ramasser, posable seulement par le propriétaire (les œufs en attente ne se volent pas, une fois posés oui). Pas de production hors ligne.

### E.5 Anti-abus

- Tout se décide côté serveur : rareté, prix, éligibilité, distances, chronos ; le client n'envoie que des intentions (`RAction` avec `kind` et identifiants).
- Limitation de débit par joueur : achat au tapis 1 / 3 s ; rune 1 / 0,12 s (existant) ; berceuse 1 / 0,25 s ; corbeau 1 lancement / 10 s ; ramassage de plume 1 / 1 s.
- Verrou d'achat au tapis : un œuf a un champ `claimedBy` posé atomiquement par le serveur ; la deuxième demande reçoit « Trop tard ! ».
- Alt-accounts et farm d'amis : le corbeau n'est utilisable qu'après 30 min de jeu cumulé sur le profil voleur et la victime doit avoir 15 min ; le classement ne compte pas les œufs obtenus par corbeau dans `stolen`.
- Journal serveur (`print("[Raven] …")`) + DataStore `RavenLog` (voleur, victime, rareté, résultat, horodatage) gardé 30 jours pour le support.
- Les jetons non dépensés restent dans le profil (aucune perte) ; changement de serveur sans perte.

---

## F. Fonctionnalités utiles et décors (priorisés)

| # | Fonctionnalité | Effort | Risque | Détail |
|---|---|---|---|---|
| 1 | Panneau des probabilités au tapis + menu 🎲 à jour | S | faible | Obligatoire avant tout produit lié au hasard |
| 2 | Carte de quête + faisceau pour l'énigme et l'onboarding | S | faible | Réutilise la boussole `Config.compass` |
| 3 | Journal « Qui m'a volé ? » | S | faible | 10 entrées, nom, rareté, heure |
| 4 | Panneaux directionnels aux carrefours (« ← Arène 12 s ») | S | faible | Calcul `Config.zoneLine` |
| 5 | Arène de combat reliée à l'Arène des Pets | M | moyen | Entrée du colisée = prompt « Combattre » qui ouvre `BattleUi` (tour existante) ; gradins où les spectateurs voient les combats en cours (pets en duel sur le sable, rejoués d'après les événements `RBattle`) ; tableau des meilleurs étages du serveur à l'entrée. Duel PvP entre amis = lot suivant (L) |
| 6 | Entrée du donjon au château (porte (300,-185)) | M | moyen | Sur un serveur « partie » : téléporte vers le donjon existant en solo (origine déplacée hors carte, (600,-200)) ; sur un serveur « castle » : comportement actuel |
| 7 | Pontons et pêche décorative aux lacs | S | faible | Canne au ponton : « pêche » un petit sac de pièces (2 min de revenu) toutes les 5 min, 5 / jour |
| 8 | Canards et poissons animés (lacs, ruisseaux) | S | faible | 6 canards par lac, client seulement |
| 9 | Moulin à eau près du lac du Moulin | S | faible | Modèle `props.mill` existant + roue animée |
| 10 | Cycle jour/nuit 20 min | M | moyen | La nuit (6 min) : vue des gardiens x0,8, lanternes allumées ; à ne faire qu'après playtest mobile |
| 11 | Mini-carte mise à jour (bases, territoires, portails, plumes, eau) | S | faible | `MiniMap.landmarks` |
| 12 | Bouton « J'aime cette base » sur chaque maison | S | faible | Cosmétique, compteur affiché sur la boîte aux lettres |
| 13 | Feux d'artifice au niveau 8 | S | faible | VfxKit |
| 14 | Interception d'un porteur (voler l'œuf porté par un autre joueur hors zone sûre) | M | élevé | `Config.INTERCEPT.enabled = false` par défaut, à tester en playtest |

---

## G. Modèles Blender à créer

Convention existante : une pièce = un objet nommé `Nom__RRGGBB`, devant = -Z, origine au centre du socle, pas de scripts. Clés à ajouter dans `Config.Assets.models` et `modelsMaxParts`.

| Clé | Modèle | Taille (studs, L × l × h) | Pièces nommées (couleurs) | Budget |
|---|---|---|---|---|
| `house.l2` | Chalet du Couvoir (image 1) | 20 × 18 × 22 | `Pilotis__6B4F35`, `Murs__C9A27A`, `Toit__8A3B2E`, `Balcon__E8DCC4`, `Porche__7A5A3C`, `Fenetres__9FD3E6`, `Porte__5A3C28`, `Cheminee__8E8E8E`, `Lanterne__FFD27A` | 120 |
| `house.l3` | Maison-Tour (image 2) | 16 × 16 × 30 | `Murs__B8C4CC`, `Balcons__F0EDE6`, `Auvents__D65A4A`, `Toit__4E5560`, `Fenetres__9FD3E6`, `Hublot__F0EDE6`, `Escalier__8C8C8C`, `Rideau__6E7280`, `Porte__5A3C28`, `Clim__D9D9D9` | 120 |
| `house.l4` | Maison à l'auvent (image 3) | 26 × 18 × 24 | `Murs__E3D5B8`, `Toit__5C6B7A`, `Auvent__A0522D`, `Caravane__F2F2F2`, `Roue__2B2B2B`, `Fenetres__9FD3E6`, `Porte__6B4F35`, `Balcon__FFFFFF`, `Caisses__B88A5A` | 130 |
| `house.l5` | Maison au garage (image 4) | 28 × 22 × 26 | `Murs__D7CFC0`, `Toit__6B4A3A`, `Garage__C0C4CC`, `Terrasse__FFFFFF`, `Hublot__F0EDE6`, `Fenetres__9FD3E6`, `Porte__4A3A2A`, `Cheminee__8E8E8E`, `Tonneau__8B5A2B` | 130 |
| `house.l6` | Villa moderne (image 5) | 30 × 24 × 24 | `Murs__F2F2F2`, `Bardage__B08D6A`, `Toit__3F4650`, `Garage__D0D4DA`, `Balcon__E0E0E0`, `Vitres__A8D8F0`, `Porte__3A3A3A`, `Haie__5E8C4A`, `Applique__FFE6A0` | 140 |
| `house.l7` | Grande villa (image 6) | 34 × 26 × 28 | `Coque__ECE8E1`, `Murs__FFFFFF`, `Bardage__C69C6D`, `Balcon__DADADA`, `Vitres__A8D8F0`, `Escalier__BDBDBD`, `Garde__9E9E9E`, `Arbuste__5E8C4A`, `Spots__FFF2C0` | 150 |
| `house.l8` | Château doré | 44 × 36 × 40 | `Murs__F2D16B`, `Tours__E8C04A`, `Toits__B8860B`, `Porte__7A4E1E`, `Drapeaux__D63A3A`, `Vitraux__7FD4FF`, `Couronne__FFE680` | 160 |
| `hub.hall` | Halle à dôme | 36 × 36 × 30 | `Murs__C9B79C`, `Dome__4F7FA8`, `Nervures__D8C58A`, `Colonnes__E3D8C2`, `Porte__6B4F35`, `Blason__C0392B` | 120 |
| `hub.belt` | Tapis roulant (module 10 de long, assemblable ×6) | 10 × 8 × 2 | `Bande__2E3138`, `Rouleaux__8C8C96`, `Bords__D8B048`, `Pieds__5A5A62` | 20 |
| `hub.beltBin` | Bac de fin de tapis | 8 × 8 × 4 | `Bac__6B4F35`, `Cercles__4A4A52`, `Paille__E8D27A` | 12 |
| `hub.stall` | Étal de marché | 10 × 8 × 8 | `Plateau__8B5A2B`, `Poteaux__6B4F35`, `Toile__D65A4A`, `Caisses__B88A5A`, `Oeufs__F5EBD7` | 40 |
| `hub.bigEgg` | Grand Œuf de l'énigme | 12 × 12 × 16 + socle 22 | `Oeuf__CFC8B8`, `Runes__7FE8FF` (Neon autorisé), `Socle__8E8E8E`, `Fissures__FFF4C0` | 40 |
| `hub.runeStone` | Pierre runique | 2,4 × 1,2 × 5 | `Pierre__6E6860`, `Glyphe__7FE8FF` | 6 |
| `npc.hen` | Mère Poule (remplace la version en Parts, garder les préfixes `Hen` pour picorer) | 4 × 5 × 6 | `Corps__FAF8F0`, `HenHead__FAF8F0`, `HenComb__EB3C3C`, `HenBeak__FFAA28`, `HenWattle__EB3C3C`, `HenEyeL__1E1C20`, `HenEyeR__1E1C20`, `Ailes__EEE8DC`, `Pattes__FFAA28`, `Chale__7A4E9E` | 30 |
| `npc.raven` | Corbeau chipeur | 3 × 4 × 2 | `Corps__1E1E24`, `AileG__2A2A33`, `AileD__2A2A33`, `Bec__D8A030`, `Yeux__FFD23F` | 12 |
| `quest.feather` | Plume dorée | 0,6 × 0,2 × 3 | `Plume__FFD24A`, `Tige__FFF2C0` | 4 |
| `portal.arch` | Arche de portail | 10 × 2 × 12 | `Arche__8E93A0`, `Voile__7FD4FF`, `Cle__FFD24A` | 20 |
| `terr.bells` | Fil à clochettes (Mara) | 12 × 0,3 × 2 | `Piquets__6B4F35`, `Fil__C8C8C8`, `Clochettes__D8B048` | 12 |
| `terr.mud` | Flaque de boue | 10 × 8 × 0,3 | `Boue__5A3E28`, `Bulles__7A5A3C` | 6 |
| `terr.gate` | Herse de la cour (Zed, pièce `Herse` animée) | 14 × 2 × 12 | `Cadre__6B5A44`, `Herse__4A4A52` | 15 |
| `terr.searchlight` | Lanterne tournante (pièce `Tete` tourne) | 2 × 2 × 8 | `Mat__3A3A42`, `Tete__D8B048`, `Lumiere__FFF2C0` | 10 |
| `terr.alarmPlate` | Dalle d'alarme | 6 × 6 × 0,4 | `Dalle__8E93A0`, `Rune__FF5050` | 4 |
| `arena.colosseum` | Colisée (ouvert au centre) | 84 × 84 × 18 | `Murs__D2C1A0`, `Arcs__B8A584`, `Gradins__A89878`, `Sable__E8D7A6`, `Drapeaux__D63A3A`, `Porte__6B4F35` | 200 |
| `water.dock` | Ponton | 12 × 4 × 1,5 | `Planches__8B6A48`, `Poteaux__5A3C28` | 14 |
| `water.reeds` | Touffe de roseaux | 2 × 2 × 3 | `Roseaux__6F8F3A`, `Massette__6B4F35` | 6 |
| `water.lily` | Nénuphars (groupe) | 4 × 4 × 0,2 | `Feuilles__4E8A3A`, `Fleur__F5B8D0` | 6 |
| `water.duck` | Canard | 1,2 × 0,8 × 1 | `Corps__F2F2F2`, `Bec__FFAA28`, `Tete__2E7D32` | 5 |
| `deco.roundBush` | Buisson rond (diorama) | 3 × 3 × 2,5 | `Feuillage__4E8A3A`, `Ombre__3B6E2C` | 4 |
| `deco.dirtPath` | Tuile de chemin de terre courbe (rayon 20, 8 de large) | 20 × 8 × 0,2 | `Terre__9C6B45`, `Bord__6F8F3A` | 6 |
| `deco.signpost` | Panneau directionnel (3 flèches) | 1 × 4 × 6 | `Poteau__6B4F35`, `Fleches__C9A27A` | 8 |
| `deco.fishHut` | Cabane du pêcheur (diorama) | 12 × 10 × 10 | `Murs__8B3A2A`, `Toit__6B2A1E`, `Porte__4A3A2A`, `Fenetre__9FD3E6`, `Filet__D8C58A` | 60 |

Budgets globaux à ajouter : `houseBudgetPerBase = 160` (une seule maison visible par base), `hubBudgetParts = 600`, `territoryBudgetParts = 300`, `waterDecoBudgetParts = 250`, `arena.colosseum` 200. Repli procédural obligatoire pour chaque modèle (comme aujourd'hui).

---

## H. Lots de travail (ordre imposé)

Chaque lot : un commit ou plus dans `roblox/` seulement, tests verts (`lune run roblox/tests/run.luau`, `python3 roblox/tools/check.py`), puis `roblox-qa-tester` et `roblox-security-reviewer` selon CLAUDE.md.

### Lot 1 : Données, textes et tables (modèle conseillé : **haiku**)

- Fichiers : `Config.lua` (nouvelles tables `Config.Map2`, `Config.BELT`, `Config.TERR`, `Config.CARRY`, `Config.NEWBIE`, `Config.TRAVEL2`, `Config.REMOTE_STEAL`, `BASE_WEIGHTS`, `BASE_LEVELS` étendu, `PASSES.ExtraSlots/PrivateBelt`, `PRODUCTS.ServerLuck/GoldenBelt/RemoteSteal/RemoteStealPack` avec `id = 0`, dialogues `Config.HEN_LINES`, `Config.FEATHER_SPOTS`, textes de chapitres 2, 8 et onboarding), `README.md`, `PUBLICATION.md` §3bis.
- Tests : somme des poids de chaque table = 100 ± 0,01 ; aucune clé de produit sans `name/desc/emoji` ; tous les textes du HUD < 110 octets ; `BASE_LEVELS` strictement croissants ; 12 emplacements de plume distincts, tous hors territoires (distance > r + 10).
- Acceptation : 0 test en échec ; aucune modification de logique serveur ; `Config.oddsText()` mentionne le tapis.

### Lot 2 : Refonte de la carte (modèle conseillé : **opus**)

- Fichiers : `Builder.lua` (`build`, `monument` → `bigEgg`, `hen`, bases, chemins, ponts, portails), `Scenery.lua`, `Placement.lua` (planification sur 700 × 500, forêts par rectangles, exclusions eau/chemins/territoires), `MiniMap.lua`, `Spawn.lua`, `Culling` (seuils 170/140 conservés), `Config.Map` remplacé par `Config.Map2` (garder un alias tant que des tests lisent `Config.Map`).
- Tests : distances du tableau A.3 (±5 %) ; base ↔ territoire ≥ 52 du centre au bord ; base ↔ eau ≥ 12 au bord ; aucun chemin dans un territoire ; tous les éléments dans les bornes ; nombre de Parts procédurales ≤ 1200 et total ≤ 7000 ; rivière du Nord infranchissable hors ponts (test de segment) ; plumes atteignables (pas dans l'eau).
- Acceptation : au démarrage la sortie affiche le compte de Parts ≤ budget ; les 5 spawns sont dans leur base ; trajets voisins 7 à 15 s mesurés par le test.

### Lot 3 : Tapis roulant central (modèle conseillé : **sonnet**)

- Fichiers : nouveau module pur `ReplicatedStorage/Belt.lua` (tirage pondéré, positions en fonction du temps, réservation, prix), `Main.server.lua` (boucle 10 Hz, prompts, achat, `carry`), `Client.client.lua` (panneau, surbrillance, annonce Légendaire+), renommage `Treadmill` → piste d'entraînement.
- Tests : 100 000 tirages : écart ≤ 0,3 point par rareté ; 2 achats simultanés → 1 seul gagnant ; limite 1 achat / 3 s ; 12 œufs max ; aucun objet qui fuit après 10 min simulées ; œuf de bienvenue une seule fois.
- Acceptation : un joueur neuf obtient un œuf hors base en < 60 s (test robot) ; probabilités du panneau = table de config.

### Lot 4 : Difficulté des territoires (modèle conseillé : **sonnet**)

- Fichiers : `Guard.lua` (territoires par disque, vigilance), nouveau module pur `ReplicatedStorage/Traps.lua` (clochettes, boue, herse, dalles, lanternes), `Main.server.lua` (hold par territoire, poids, fraîcheur 75 s, colonne de lumière, porte de base, protection débutant), `Config.stealTime`.
- Tests : 10 min simulées, 7 gardiens, 0 sortie de territoire ; vigilance plafonnée à +45 % et retombée après 30 s ; vitesse de portage = produit plancher 0,70 ; fraîcheur : œuf rendu au nid à 75 s ; protection débutant : 0 vol possible ; herse : cycle 3/3 s.
- Acceptation : joueur-robot : premier vol chez Gus < 4 min, 0 dégât avant 3 min ; taux de réussite simulé d'un vol chez Zed sans amélioration de vitesse < 30 %, avec vitesse ≥ 30 > 60 %.

### Lot 5 : Maison évolutive et emplacements (modèle conseillé : **sonnet**)

- Fichiers : `Data.lua` (v10 : `SLOT_COUNT = 20`, `baseLevelFloor`, `tokens`, `settings`, `puzzle.step/feathers/hints/fragments`, migration avec recalcul du score), `Rules.lua` (`capacity`, multiplicateur de niveau), `Builder.baseUpgrade` (modèles `house.l2..l8`, emprise, pads 5 × 4), `Config.padLocal`, animation (`Cinematics`, `Easing`).
- Tests : migration de profils v1 à v9 (fixtures) → v10 sans perte, niveau jamais en baisse ; capacité max 20 ; niveaux 7 et 8 bloqués sans Légendaire / Mythique découvert ; animation : 0 erreur, caméra rendue.
- Acceptation : `tests/Economy.lua` : niveau 2 < 3 min, niveau 4 < 30 min, niveau 6 < 2 h ; changement de niveau visible sans recréer les emplacements occupés.

### Lot 6 : Énigme de la Mère Poule (modèle conseillé : **sonnet**)

- Fichiers : nouveau module pur `ReplicatedStorage/Riddle.lua` (plumes du jour, berceuse, état par étape, indices), `Config.riddleFor` réutilisée, `Builder` (plumes, pierres, Mère Poule avec prompt « Parler »), `Main.server.lua` (étapes, validations, récompense, fragments, effet collectif), UI dialogue et carte de quête dans `Client.client.lua`.
- Tests : déterminisme (même jour = mêmes plumes, runes, berceuse) sur 365 jours ; chaque berceuse contient les 4 symboles ; impossible de passer à l'étape 2 sans 4 plumes ; distance de ramassage refusée à 11 studs ; changement de jour = remise à zéro ; récompense versée une seule fois par jour ; 7 fragments = 1 œuf Légendaire.
- Acceptation : 3 testeurs humains résolvent l'énigme sans aide extérieure en < 10 min (à faire dans Studio par l'utilisateur) ; un robot de test la résout en suivant uniquement le faisceau.

### Lot 7 : Monétisation (modèle conseillé : **sonnet**, revue sécurité obligatoire)

- Fichiers : `Main.server.lua` (ProcessReceipt des nouveaux produits, jetons, corbeau, tapis doré, chance serveur, pass emplacements et tapis privé, PolicyService), nouveau module pur `ReplicatedStorage/Raven.lua` (éligibilité, plafonds, indemnité), UI menu Corbeau, réglage « Refuser les corbeaux de mes amis », journal « Qui m'a volé ? ».
- Tests : chaque règle de E.3 (cible débutant, cooldown 20 min, bouclier 5 min, écart de niveau, ami bloqué, rareté > 4, pas de place libre, plafond 3 / jour, échec = jeton rendu, indemnité exacte) ; reçu rejoué deux fois = 1 seul jeton ; `ArePaidRandomItemsRestricted` masque les 6 offres ; `id = 0` = offre invisible.
- Acceptation : 0 défaut critique ou élevé au `roblox-security-reviewer` ; aucune offre ne contient de rareté tirée au sort sans probabilités affichées.

### Lot 8 : Équilibrage global, décors, arène, intégration Blender (modèle conseillé : **opus**)

- Fichiers : `tests/Economy.lua`, `tools/sim_economy.py` (tapis, niveaux de maison, emplacements 20), décors F.4 à F.13, arène reliée à `BattleUi`, entrée du donjon, câblage des modèles de G dans `Config.Assets.models` (IDs fournis par l'utilisateur), `BLENDER_REQUESTS.md`, `CHANGELOG.md`.
- Tests : cibles de rythme sur 5 graines (éclosion < 60 s, Rare < 4 min, Épique < 12 min, Légendaire < 45 min, Mythique < 3 h sans achat) ; pire cas de Parts ≤ `totalBudgetParts` ; chaque modèle a un repli.
- Acceptation : tous les tests verts ; rapport final au format Exécuté / Analysé / À tester dans Studio.

---

## Les 5 risques principaux et comment les tester

1. **Vol à distance perçu comme payer pour nuire (plaintes, modération Roblox, départs)**. Test : suite unitaire de toutes les règles E.3 ; playtest à 3 comptes (deux amis + un inconnu) avec le réglage « Refuser les corbeaux de mes amis » ; mesurer en playtest le nombre de corbeaux reçus par joueur et par heure (doit rester ≤ 3) ; relire la fiche de questionnaire de maturité (vol d'objets virtuels déjà déclaré).
2. **Économie cassée par le tapis à 0,6 du prix, les bonus de revenu de maison et 20 emplacements**. Test : `sim_economy.py 30 <graine>` sur 5 graines avant / après ; bornes de `tests/run.luau` (lot 8) ; le tapis doré ne doit pas réduire le temps du premier Mythique de plus de 50 %.
3. **Performance mobile (nouvelle carte, eau, 5 maisons jusqu'à 160 Parts, 12 œufs sur le tapis)**. Test : compte de Parts au démarrage ≤ budgets ; test de non-fuite d'objets sur 10 min ; playtest dans l'émulateur téléphone de Studio avec 5 joueurs (Test > Clients and Servers), FPS ≥ 30, mémoire client < 1,2 Go.
4. **Migration des données v9 → v10 (emplacements 12 → 20, score recalculé)**. Test : fixtures de profils v1 à v9 dont un profil v9 au niveau 8 et un aux 12 emplacements pleins ; vérifier aucun pet perdu, niveau jamais en baisse, `receipts` conservés ; essai réel sur un compte de test dans un lieu privé avant publication.
5. **Énigme encore incomprise ou bloquante**. Test : robot qui la résout en suivant le seul faisceau ; 3 testeurs humains < 10 min sans aide ; compteurs serveur `print("[Riddle] step=… t=… hints=…")` relevés au premier playtest public (abandon à l'étape 1 > 40 % = déplacer les plumes plus près).
