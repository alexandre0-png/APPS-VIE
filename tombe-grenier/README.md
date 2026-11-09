# La Tombe du Grenier (Roblox)

Jeu d'horreur coopératif en première personne, 1 à 4 joueurs, écrit en Luau et synchronisé dans Roblox Studio avec Rojo.

## Structure

```
default.project.json          Mapping Rojo -> Roblox
src/shared/                   ReplicatedStorage.Shared (accessible client et serveur)
  Config.lua                  Tous les réglages (timings, difficulté, portées)
  Rng.lua                     Générateur reproductible (scintillement, chutes)
  AudioManifest.lua           Clés audio (asset vide = à fournir)
  Audio.lua                   Lecture par clé, warning si asset manquant
  Remotes.lua                 Canaux réseau client <-> serveur
src/server/                   ServerScriptService.Server
  init.server.lua             Boucle de partie, victoire, défaite, réseau
  PlayerState.lua             Endurance, sanité, bruit, cachettes, lampe
  MonsterAI.lua               IA du monstre (Patrol, Investigate, Chase, Search)
  Lights.lua                  Lampes qui scintillent, coupures
  FallingObjects.lua          Objets qui tombent, jamais deux fois au même point
  Objectives.lua              Photos, clé, sortie
  Hiding.lua                  Armoires
  Noise.lua                   Bruits ponctuels entendus par le monstre
src/client/init.client.lua    StarterPlayerScripts.Client : HUD, effets, entrées
```

## Mise en place

1. Installer Rojo (`aftman` ou `cargo install rojo`) et son plugin dans Roblox Studio.
2. Dans `tombe-grenier/` : `rojo serve`, puis dans Studio : *Connect*.
3. Rien à placer à la main : la carte est construite au lancement par `MapBuilder` à partir de `src/shared/MapData.lua`. Pour modifier la maison, éditer `tools/map/generate_map.py` puis lancer `python3 tools/map/generate_map.py` (voir section Carte).
4. Ajouter dans `ServerStorage` :
   - `Monster` : un modèle avec `Humanoid` et `HumanoidRootPart`, un rig R15 est nécessaire pour que les animations (immobile, marche, course, attaques) s'affichent. Sans modèle, un rig de secours sans animation est utilisé.
   - `FallingItem` (optionnel) : une `BasePart` (barre de fer, bocal…).
5. Les sons sont référencés dans `src/shared/AudioManifest.lua` avec leurs IDs Roblox. Pour un nouveau son, ajouter une entrée `rbxassetid://…`. Une clé avec `asset = ""` logue un warning une seule fois.

## Carte

La maison fait 120 × 90 studs, sur quatre niveaux : sous-sol (y = -12), rez-de-chaussée (0), premier étage (12), grenier (24). Le jardin entoure la maison, clôturé par des murs invisibles.

- Source unique : `tools/map/generate_map.py` (pièces, portes, meubles, escalier, points de tag, murs invisibles, jardin).
- Généré : `src/shared/MapData.lua`. Ne pas l'éditer à la main.
- Construit : `src/server/MapBuilder.lua`, appelé au démarrage du serveur avant les systèmes.
- Tests : `python3 -m unittest discover -s tools/map -p "test_*.py"` depuis `tombe-grenier/`. Ils vérifient l'emprise, les recouvrements, la présence des portes sur un mur, les meubles hors porte et hors escalier, l'accessibilité de toutes les pièces, les tags minimums et les cachettes dans les armoires.

Éléments fixes (toujours aux mêmes endroits) :

| Tag | Où | Rôle |
|---|---|---|
| `Waypoint` | Centre de chaque pièce et porte intérieure | Points de patrouille |
| `Lamp` | Une ampoule par pièce | Source de la pièce, allumée ou non selon la partie |
| `Hiding` | Intérieur de chaque armoire | Cachette |
| `ExitDoor` | Porte d'entrée | Sortie, ouverte si photos + clé |
| `InvisibleWall` | Clôture, portail, grille | Bloque le passage (attribut `Puzzle` pour les énigmes) |

Éléments tirés au sort à chaque partie (`MapBuilder.placeRound`, à partir de la seed de partie) :

| Tag | Tirage | Rôle |
|---|---|---|
| `Photo` | 3 parmi 12 emplacements | Photos (3 requises pour la sortie) |
| `CodeNote` | 1 parmi 5 emplacements | Papier qui donne le code du coffret |
| `CaveKey` / `Decoy` | 1 vraie clé et 2 fausses, parmi 3 emplacements | Clé de la porte de la cave |
| `BathKey` | 1 parmi 3 emplacements | Clé de la salle de bain |
| `Battery` | 3 parmi 5 emplacements | Pile de lampe torche (+45 de charge) |
| `Interactable` | 1 emplacement par objet (journal, bougies, peluche, gramophone, cahier, photo de famille, tasse) | Attribut `Kind`, effet propre à chaque objet |
| `FallSpot` | 4 parmi 6 emplacements | Chute d'objet au-dessus d'une étagère |
| `Key` (sortie) | Fixe : dans la malle du grenier | Clé de la sortie, prenable quand la malle est ouverte |
| `MonsterSpawn` | 1 parmi 3 emplacements | Apparition du monstre |
| `FlickerLight` | Lampes allumées : toutes sauf les pièces sombres | Lampe qui scintille |

Chaque emplacement candidat est vérifié par les tests : il est dans une pièce, jamais à l'intérieur d'un meuble, et posé sur un meuble ou sur le sol.

Pièces sombres : à chaque partie, 4 pièces parmi 14 sont plongées dans le noir (hall, entrée, palier, grenier et tombe restent éclairés). Dans le noir, sans lampe allumée, la sanité baisse et le monstre ne voit qu'à 35 % de sa portée. La lampe torche devient alors l'outil principal de ces pièces.

Le spawn des joueurs est un `SpawnLocation` placé sur le cercueil du grenier.

## État de la maison : ce qui est codé et ce qui manque

Codé (à tester en Play Test) :
- Cachettes : armoires, dessous des lits (sommier sur quatre pieds, espace libre dessous), boîtes en carton (grenier et débarras).
- Énigme du courant : trois interrupteurs (cellier, cave, passage sud) à actionner dans un ordre tiré à chaque partie. Le bon ordre rétablit toutes les lampes pendant une minute, avec une cinématique.
- Monstre : il pousse les portes fermées qu'il touche (bruit, la porte cède) ; une porte fermée bloque sa vue ; un bruit derrière un mur n'est entendu que de près.
- Réveil dans le cercueil : noir, 8 s sans déplacement, photo qui tombe.
- Photo de l'introduction : lue, elle déclenche un flashback silencieux.
- Flashbacks courts (3 à 5 s, sans texte, avec un son existant) à la lecture de chaque document : cahier (chaise qui grince), journal (porte qui grince), plaque (cri lointain), photo de famille (quatre cadres). `Config.Debug.SkipFlashbacks` les coupe pour les tests.
- Quatre documents (journal, cahier, photo de famille, plaque), code, coffret, malle, clé, sortie.
- Première apparition : malle ouverte → coupure de courant, le monstre fixe le joueur 2 s, puis le poursuit.
- Miroir inquiétant (tombe) et miroir fissuré (salle de bain) : sursaut, sanité en baisse.
- Télévision : image granuleuse qui montre la pièce vue de haut.
- Cheval à bascule : il balance seul et attire le monstre.
- Jouet musical (chambre d'enfant) : mélodie, bruit qui porte.
- Tasse de café pleine (cuisine), bougies, peluche, gramophone.
- Silhouette furtive au grenier (une fois sur deux) et pas à l'étage.
- Trois fins, avec teinte propre à chaque fin et bouton « Rejouer » (30 s de repli).
- Cinématiques par mouvements de caméra, sans texte (`src/client/Cinematic.lua`) : réveil dans le cercueil, première apparition (caméra qui tremble face au monstre), fin 1 (sortie et maison vue du jardin), fin 2 (couvercle qui se referme, plaque), fin 3 (lumière qui monte du cercueil). Espace ou Échap passe une cinématique.
- Récit : les quatre documents, le flashback de la photo de famille, l'introduction et les trois fins portent l'histoire. Aucun texte d'explication n'est affiché, comme le demande le design.

Non codé :
- Portes intérieures : elles se ferment seules de temps en temps, et s'ouvrent à la demande (prompt).
- Rideaux : ils bougent alors que les fenêtres sont fermées (il n'y a pas de fenêtres dans la carte).
- Porte métallique de la cave : une des trois clés posées (les deux autres sont fausses) l'ouvre. Elle libère le passage sud, où se trouve un cahier.
- Crise de la cave : à l'ouverture de la porte, le monstre se lance sur celui qui a ouvert, et une personne gémit au fond. « Sauver la personne » (maintien de 3 s près de la porte) sauve la personne ; la partie continue normalement. Une mort dans la cave ramène au jardin.
- Trappes : celle au pied de l'escalier du sous-sol, dans la maison, ne s'ouvre pas (« une porte est peut-être dehors »). Le sous-sol se visite par la porte extérieure, au pied du mur sud. Celle au sommet de l'escalier du grenier reste fermée jusqu'à l'ouverture de la malle.
- Portail du jardin : il se franchit (voir fin 1). Hors de la maison, la clôture resserrée limite les déplacements.
- Voix lointaine « Tu n'aurais jamais dû revenir ici… » : pas d'asset audio dans la banque.
- Cri de corneille de la fin 1 : pas d'asset audio.
- Dessins au mur de la chambre d'enfant : décor à ajouter dans Studio.
- Menu complet (Continuer, Options) : seul « Rejouer » est codé.
- Cinématiques à affiner dans Studio : positions de caméra (réglées sur les coordonnées de la carte, à vérifier dans le moteur), et effet de lumière de la fin 3 (particules non ajoutées).

## Quêtes et fins

Chaîne principale, vers la sortie :
1. Rassembler 3 photos (tirées parmi 12 emplacements).
2. Trouver le papier du code (un des 5 emplacements). Le papier ne donne que les deux premiers chiffres. Les deux derniers sont dans un miroir, écrits à l'envers : il faut les remettre dans le bon sens. Le code change à chaque partie.
3. Ouvrir le coffret à bijoux (table de la salle de la tombe) avec le code complet. Il contient une petite clé.
4. Ouvrir la malle (salle de la tombe) avec la petite clé. Elle contient la clé rouillée de la sortie.
5. Sortir par la porte d'entrée (photos et clé en main) : on arrive dans le jardin, où une cinématique montre le monstre qui cogne à la porte. Deux choix : rester et descendre par la porte du sous-sol (au pied du mur sud, extérieure, avec l'escalier du jardin), où l'on entend les cris ; ou franchir le portail au fond de l'allée.

Chaîne parallèle, vers la fin « vérité » :
- Lire les 4 documents (journal, cahier d'écolier, photo de famille, plaque du cercueil). Chacun a 2 à 3 emplacements.
- Recouper les dates : le journal et la plaque donnent la vraie date (mois/jour), le cahier en donne une fausse en marge.
- Libérer l'enfant au cercueil une fois les 4 documents lus. Un clavier demande la date de la plaque en quatre chiffres (mois puis jour, par exemple `0314`).
- Le gramophone donne une mélodie de trois notes (do, ré, mi, sol), tirée à chaque partie. La boîte à musique se joue note par note : une faute repart de zéro, la mélodie complète ouvre la salle de bain.
- Bibliothèque (autre chemin vers la petite clé, donc vers la malle) : trois livres parmi ceux des bibliothèques portent un marque-page numéroté 1, 2, 3, tirés à chaque partie. Les feuilleter dans l'ordre 1, 2, 3 donne la petite clé. Une faute repart de zéro.
- Statues (une dans le salon, une dans la cuisine, une dans le bureau) : chacune se tourne par quarts de tour. Les trois doivent regarder la même direction, tirée à chaque partie. Résolues, elles ouvrent la cave, sans la vraie clé.
- Tableau (grenier, palier, salon, chambre) : le décrocher fait tomber le cadre et révèle une fente dans le mur, avec une pile. Une fois par partie.
- Mur qui respire (côté salon du hall) : une fois les statues résolues, le toucher donne une pile et fait perdre 15 de sanité. Avant, il ne se passe rien.
- Mannequin (couloir, à l'étage) : buste de couturière construit en primitives, sans modèle. Quand un joueur s'approche à moins de 5 studs, il pivote vers lui une fois par partie, avec un sursaut à l'écran. L'examen donne un détail de décor.

Trois fins, chacune comptée dans « Fins trouvées » pour la session serveur :
- Fin 1, la fuite : franchir le portail. Le monstre disparaît ; il réapparaît quand les joueurs atteignent la cave, et descend l'escalier extérieur vers eux. La partie ne se termine pas sur la fuite.
- Fin 2, la malédiction : déclenchée par un choix au cercueil (une fois la malle ouverte, invite « Refermer le cercueil », maintien de 2 s), ou quand plus personne n'est debout après avoir épuisé ses vies.
- Vies : chaque joueur en a trois par partie (`Config.Player.Lives`). Une mort en coûte une. Avec une vie restante, le joueur réapparaît après `Config.Respawn.Delay` secondes, au dernier point d'avancée (près de la malle ouverte, sinon du coffret ouvert, sinon du cercueil). En duo, si l'autre joueur est vivant, le joueur mort reste au sol et peut être réanimé en maintenant « Réanimer » (`Config.Revive.Hold`) pendant `Config.Revive.Window` secondes. Sans vie, le joueur est hors jeu ; l'autre peut encore le réanimer, et il revient avec une vie.
- Indication : la touche H affiche en bas à gauche l'indication de l'étape courante. Un délai de `Config.Quests.HintCooldown` secondes s'applique entre deux demandes.
- Au réveil, un court rappel des règles s'affiche pendant 12 secondes.
- Vitesse : marche 8, course 13, silencieux 3 (`Config.Player`), pour que la maison prenne du temps.
- Fin 3, la vérité : l'enfant est libéré au cercueil (date de la plaque). Il suit alors les joueurs (il ne peut pas être attrapé). Il faut fuir par le portail : une voiture attend au bout de l'allée, on monte à bord, et le monstre suit de loin ; la partie se termine ensuite.

Indications : après 3 minutes sans progrès (`Config.Quests.HintDelay`), un indice s'affiche, une seule fois par étape.

Éléments qui font varier la partie :
- Papier du code, photos, piles, objets, chutes et apparition du monstre : emplacements tirés.
- Fausses clés : elles ne s'ajustent à rien (même sensation de fausse piste).
- Objets interactifs, une fois par partie :
  - Bougies : une bougie allumée éclaire autour d'elle pendant une minute.
  - Peluche : une pierre lisse cachée dedans, deux jets de bruit en plus.
  - Gramophone : il joue une douzaine de secondes, et le son attire le monstre.
  - Journal, cahier, photo de famille, plaque : documents de l'histoire.
- Pièces sombres : 4 pièces parmi 14 sont tirées dans le noir à chaque partie. Le hall, l'entrée, le palier, le grenier et la tombe restent éclairés.

Pas de sang : les coups se traduisent par un voile sombre, un son et une pause du joueur.

## Hub : salon commun

Tous les joueurs arrivent dans un hub loin de la maison. La borne « Lancer la partie » démarre la partie. Sans borne, elle démarre 30 s après l'arrivée du premier joueur (`Config.Game.HubWait`). Tous les joueurs présents sont téléportés dans le cercueil du grenier.

Le mode suit le nombre de joueurs : un seul joueur = solo (première apparition après 60 s), deux = duo (45 s).

Après une fin, tout le monde est téléporté de nouveau au hub.

### Deux lieux : hub et serveur privé

Le hub peut être un lieu Roblox séparé, qui envoie les joueurs sur un serveur privé du lieu de jeu :
1. Dans Studio, crée deux lieux dans la même expérience : le **lieu de jeu** (ce projet) et un **lieu hub** (un lieu vide avec le même `src/server/Hub.lua` et `src/shared/Config.lua`).
2. Publie les deux lieux, puis renseigne leurs identifiants dans `Config.Game.Places` (`hub` et `game`).
3. Au lancement, le lieu hub réserve un serveur privé du lieu de jeu (`ReserveServer`) et y téléporte tous les joueurs présents (`TeleportToPrivateServer`).
4. Après une fin, le lieu de jeu renvoie les joueurs au lieu hub (`TeleportAsync`).

Tant que les identifiants valent 0, ou en Studio, tout se passe dans un seul lieu. La téléportation ne fonctionne pas en Studio : il faut un test publié.

## Pièces verrouillées

Quatre pièces sont fermées tant que leur énigme n'est pas résolue. Chaque porte qui y donne est verrouillée (pas de contournement) :

Aucun indice ni document indispensable ne se trouve dans une pièce fermée : le générateur écarte ces emplacements (papiers, photos, documents), et `DecorKit` ne marque pas comme livres à lire ceux qui sont dans ces pièces. Vérifié par `tools/map/test_map.py`.

| Pièce | Ouverte par | Où trouver l'énigme |
|---|---|---|
| Chambre d'ami | Lire le cahier d'écolier | Chambre d'enfant, couloir ou passage sud |
| Salle de bain | La clé de la salle de bain | Salon, chambre des parents ou bureau |
| Bureau | Avoir les trois photos | Autres pièces |
| Cellier | Rétablir le courant (interrupteurs) | Interrupteur côté cave |

Le monstre ne pousse pas une porte verrouillée.

## Maison qui réagit

- **Mémoire du monstre** (`src/server/Memory.lua`) : il retient les pièces que tu visites souvent et les cachettes que tu utilises. Il patrouille davantage dans tes pièces habituelles et inspecte tes cachettes en premier. La mémoire dure tant que le serveur tourne.
- **Inspection** : pendant une recherche, le monstre s'arrête devant une cachette proche, la regarde 1,5 s, puis te découvre si tu y es.
- **Lumière qui s'éteint** : en quittant une pièce éclairée, ses lampes peuvent s'éteindre derrière toi pendant 15 s.
- **Journal intime** : il relit tes dernières actions.
- **Télévision** : l'image montre la pièce vue de haut, avec la pièce où se trouve le monstre.
- **Téléphone du salon** : il sonne, avec des consignes qui se contredisent.
- **Événements d'ambiance** : une porte s'ouvre seule, une silhouette traverse le couloir en courant.

## Monstre : état d'animation

Le code charge les animations (immobile, marche, course, attaques) sur `ServerStorage/Monster` si ce modèle existe. Si `ServerStorage/Monster` est absent, le serveur tente de charger un des modèles R15 fournis (`MonsterAI.ensureModel`), en retirant ses scripts. Si le chargement échoue (modèle non autorisé, hors ligne), un bloc de secours sans animation est utilisé. Il est recommandé d'insérer le modèle dans Studio pour ne pas dépendre du chargement à l'exécution.

## Décor à compléter dans Studio

`src/server/DecorKit.lua` pose des livres, bouteilles, boîtes, coussins et casseroles sur les meubles. Pour un décor réaliste, place dans `ServerStorage/Decor` un modèle nommé comme le meuble (par exemple `table`, `bibliothèque`, `lit double`) : il est mis à l'échelle sur l'emplacement du meuble, et sa boîte de collision reste active.

Limite : le mode « Future » ne se règle que dans Studio (Lighting > Technology > Future).

## Tests

Depuis `tombe-grenier/` :
- Carte (géométrie, accessibilité, emplacements, décor, verrous) : `python3 -m unittest discover -s tools/map -p "test_*.py" -v` (49 tests)
- Code Luau (modules, remotes, audio, tags, configuration, champs de la carte, syntaxe Lua 5.4 réelle) : `python3 -m unittest discover -s tools/lua -p "test_*.py" -v` (14 tests ; la syntaxe demande `pip install lupa`)
- Portée des fonctions locales (appel avant déclaration) : `python3 tools/lua/scope_check.py`
- Énigmes exécutées dans un faux environnement Roblox (Lua 5.4 via lupa, `tools/lua/sim/`) : code et miroir, mélodie, bibliothèque, statues, mur, date de la plaque, fin vérité, 60 graines. Lancer : `python3 -m unittest discover -s tools/lua/sim -p "test_*.py" -v`. Ce n'est pas Roblox : les services et les invites sont simulés.

Ces tests ne lancent pas Roblox : ils vérifient la cohérence du code et des données. Le comportement en jeu se valide en Play Test.

## Contrôles

- ZQSD / WASD : déplacement (caméra première personne verrouillée)
- Shift maintenu : sprint (consomme l'endurance, très bruyant)
- Ctrl maintenu : silencieux (lent, quasi silencieux)
- C maintenu : accroupi (plus lent que la marche, s'abaisse, et quasi silencieux, comme Ctrl)
- H : indication de l'étape courante (un délai de 30 s entre deux demandes)
- F : lampe torche (se vide, et fige le monstre quand elle le touche). Une pile la recharge.
- G : lancer de bruit. Un objet lancé attire le monstre au point d'impact. Un lancer = un caillou ramassé au sol (4 cailloux par partie, dans les pièces ouvertes). 3 s de recharge.
- Clic sur le coffret : saisie du code (4 chiffres, Échap pour refermer).
- Téléphone et tablette : deux boutons permanents en bas à droite (Course, Accroupi). Les autres n'apparaissent que quand ils servent : Lampe dans le noir, Lancer avec un caillou, UV près d'une marque, Indice après une minute sans progrès. Le déplacement se fait au joystick tactile intégré à Roblox. Sur clavier et manette, une ligne au bas de l'écran rappelle la touche de chaque action disponible.
- U (manette : R3, tactile : bouton UV) : lampe UV, un mode de la lampe. Les marques écrites à l'encre invisible au sol, devant les deux premières statues, s'affichent avec leur texte : elles indiquent l'orientation cible de la statue. Un clic par bascule.
- Manette : L1 silence, L2 course, B accroupi, Y lampe, R1 lancer, Haut indice. Le bouton d'interaction (X par défaut) est celui des invites.
- Lisibilité : les textes se règlent à la taille de l'écran (bornes 13 à 22) et les largeurs sont relatives à l'écran. L'inventaire est en haut à droite : souvenirs, documents, petite clé, clé de la cave, clé rouillée.
- Difficulté : `Config.Difficulty` (« facile », « normal » ou « difficile ») règle la vitesse de poursuite, l'ouïe et la vue du monstre.
- Musique : l'ambiance baisse pendant une poursuite, et la musique de poursuite joue tant que le monstre chase.
- Événements d'ambiance : la peluche se déplace quand on s'éloigne, une porte ouverte peut se refermer et se verrouiller dix secondes.
- Bouton d'interaction (ProximityPrompt) : ramasser, lire, examiner, se cacher, sortir, ouvrir la sortie

## Réglages de test

Dans `Config.lua` :
- `Config.Debug.SkipActivationDelay = true` : le monstre sort tout de suite.
- `Config.Debug.Seed = 42` : mêmes lampes et mêmes chutes à chaque partie.
- `Config.Round.ActivationDelay`, `Config.Monster.*` : difficulté.

## Vérifications manuelles

1. **Cercueil** : au spawn, le joueur est en première personne, sans menu ni HUD texte, les mains visibles.
2. **Lampes** : les `FlickerLight` s'allument et s'éteignent par rafales. Avec la même seed, les séquences sont identiques.
3. **Chute** : un objet tombe au `FallSpot` sans son (aucun son métallique retenu). Il attire quand même le monstre. Jamais deux fois au même point d'affilée.
4. **Monstre, ouïe** : marcher près du monstre, puis sprinter : il s'approche. Ctrl maintenu : il ne réagit qu'à très courte distance.
5. **Monstre, vue** : se placer dans son cône de vision sans obstacle : passage en Chase. Se cacher derrière un mur : il perd la trace et passe en Search.
6. **Cachette** : entrer dans une armoire, le joueur est immobile. Le monstre peut le débusquer à moins de 7 studs (le joueur est alors éjecté, avec effet de sursaut).
7. **Lampe** : éclairer le monstre : il se fige tant que le faisceau le touche, et reprend quand on tourne le dos.
8. **Objectifs** : 3 photos, code, coffret, petite clé, malle, clé rouillée. Puis sortie ouverte. Sortir par la porte d'entrée : on arrive dans le jardin. Rester (cave) ou franchir le portail (fin 1 par la fuite, voir ci-dessus).
8bis. **Fin 3** : lire les 4 documents, recouper la date (journal et plaque), puis libérer l'enfant au cercueil et saisir la date au clavier. Fuir ensuite par le portail vers la voiture termine la partie.
8ter. **Statues et mur** : tourner les trois statues jusqu'à ce qu'elles regardent toutes dans la même direction ; la cave s'ouvre. Toucher le mur : une pile, une baisse de sanité.
9. **Mort** : trois vies par joueur. Une mort coûte une vie ; réapparition au dernier point d'avancée. En duo, réanimer le joueur au sol (maintien de 3 s, 40 s de fenêtre). Sans vie, hors jeu. Si plus personne n'est debout, fin 2.
9bis. **Indication** : touche H, la première fois puis après le délai. Le texte apparaît en bas à gauche.
10. **Coopération** : deux clients en test serveur (Test > Players = 2). Les photos ramassées par l'un disparaissent pour l'autre, la progression est commune.
11. **Asset manquant** : ne pas renseigner un son. La sortie Output affiche un warning une seule fois, sans erreur.

## Limites connues

- Éclairage : le mode « Future » ne se sélectionne que dans Studio. Le code approxime le rendu (ombres douces, profondeur de champ légère, vignette, ombres portées par les 4 lampes les plus proches des joueurs, recalculées chaque seconde). Le décor de base (livres, bouteilles, coussins) se remplace par des modèles Studio dans `ServerStorage/Decor`, nommés comme le meuble.
- Le rendu 3D et le jeu réel n'ont pas été testés dans Studio : les tests vérifient la géométrie des données, pas le comportement en jeu. Le mode « Future » (ombres et éclairage réalistes) se règle dans Studio : Lighting > Technology > Future.
- Les fins trouvées ne sont pas sauvegardées entre les sessions (remises à zéro au redémarrage du serveur). Une sauvegarde DataStore est à ajouter.
- Les textures ne s'affichent que si les IDs sont des images Roblox.
- Le code n'a pas été exécuté dans Roblox Studio. Il doit être validé en Play Test, en particulier le pathfinding et les `Touched` des objets tombés.
- Les sons sont vides tant que les assets ne sont pas uploadés. Le fichier `.wav` n'est pas lu depuis le dépôt : Roblox ne charge que des assets hébergés.
- Un seul monstre. Le modèle de secours n'a pas d'animations.
- Pas de sauvegarde entre sessions : chaque lancement de serveur repart d'une partie neuve.
