# Journal des modifications : Chipe-Œufs (Roblox)

Chaque entrée indique les décisions techniques prises. Dates au format AAAA-MM-JJ.

## 2026-11-22 : lots A à D (correctifs Lune, amis, œuf borné, modèles Blender)

- **A (23ae91b)** : les échecs sous Lune venaient de MON test : le générateur du test (`seed * 1103515245`) dépasse 2^53, exact avec les entiers de Lua 5.5 (lupa) mais imprécis avec les doubles de Luau (Lune). Remplacé partout par Park–Miller (`seed * 16807 % 2147483647`, exact en doubles) ; ajout d'un test DÉTERMINISTE sans aléatoire (balayage exact du tirage). L'erreur client « compare table < number » venait du runtime factice (Luau ne tolère pas `proxy < nombre`) : les instances ont maintenant des valeurs numériques réelles par défaut.
- **B (6fa1453)** : toute partie, même lancée seul, reste ouverte aux amis du créateur jusqu'à 5 joueurs (liste blanche serveur inchangée), « Rejoindre l'ami » avec places libres, retrait du registre quand tout le monde est parti, messages clairs.
- **C (8bc3546)** : plafond de taille de l'œuf (`Config.eggMaxSize`, relatif à l'emplacement et au joueur), nid sous chaque œuf, pet qui apparaît plafonné (`Easing.popScale`).
- **D** : modèles Blender intégrés : œufs par rareté (6 + secret, prioritaires sur le catalogue), 6 pets liés aux espèces (Poussin, Lapin, Renard, Panda, Dragonnet = Dragon, Fantôme = Alien), accessoires (arbre, sapin, rocher, buisson, pont, cabane, barrière, fontaine du hub, nid). Convention `Nom__RRGGBB` lue par `Assets.colorize` (couleurs du FBX ignorées, petits détails sans ombre), un seul `LoadAsset` par identifiant puis clonage, plafond de Parts par modèle (`propsMaxParts`) et budget global (`propsBudgetParts`, pire cas testé), repli procédural conservé partout. `BLENDER_REQUESTS.md` liste tous les modèles à créer ensuite.

## 2026-11-22 (suite) : câblage Blender, lot 4 pets supplémentaires

- 8 pets ajoutés à `Config.Assets.pets` : Hamster, Chat, Chien, Hibou, Manchot, Lion, Licorne, T-Rex (14 espèces sur 18 en Blender ; Tigre, Kraken, Calmar stellaire, Wyrm astral restent procéduraux, non créés). Même chargeur, même plafond de Parts (`petsMaxParts`), repli procédural.

## 2026-11-22 (suite) : câblage Blender, lot 3 château (murs, tours, herses, coffre, torches, drapeaux, fond)

- `Builder.dressCastle` : 4 murs Blender par salle (les murs procéduraux restent les colliders, invisibles si les 4 sont posés), 2 tours, une porte par salle dont la pièce `Herse` monte à l'ouverture (`Builder.animDoor`, uniquement au changement d'état), coffre dont le `Couvercle` s'ouvre à la prise du trésor (`Builder.openChest`), torches (la lumière du pilote reste), drapeaux sur le portail, bâtiment `props.castle` en fond. Budget global `castleBudgetParts` (1700, pire cas = plafonds de Parts) ; un modèle sans Herse/Couvercle est ignoré (repli procédural). Groupe `props` entier chargé (moulin, enclos, lampadaire, banc, panneau sont chargés mais pas encore posés). Le sol (`castle.floor`) n'est pas posé : un dallage demande des dizaines de clones, hors budget mobile sans mesures réelles.
- Non testé en Studio : proportions des modèles (échelle par largeur/hauteur), orientation des murs (rotation 90°), sens d'ouverture du couvercle.

## 2026-11-22 (suite) : câblage Blender, lot 2 pièges du château

- `Builder.dressTraps` : pics (`traps.spikes`, pièce animée `Pics`), lames (`traps.blade`, pièce `Lame` qui tourne autour de l'axe vertical du modèle), boulets (`traps.ball`, modèle entier qui suit et roule). Les Parts procédurales restent les pilotes de la logique (dégâts, positions) et deviennent invisibles ; un modèle sans la pièce animée attendue est ignoré (apparence procédurale conservée). Les noms de pièces acceptent le suffixe de couleur (`Pics__C0C0C0`). Mise à jour des modèles seulement quand l'état change (pics) ou à 10 Hz (lames, boulets).
- Tests : le runtime factice clone désormais en profondeur et gère `FindFirstChild(nom, true)`. Non testé en Studio : sens de rotation et position de repos des pièces animées (je suppose les pics dessinés « sortis »).

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
