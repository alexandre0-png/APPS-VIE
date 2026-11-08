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
| `Key` | 1 parmi 5 emplacements | Clé de la sortie |
| `Battery` | 3 parmi 4 emplacements | Pile de lampe torche (+45 de charge) |
| `Interactable` | 1 emplacement par objet (journal, bougies, peluche, gramophone) | Attribut `Kind`, sans logique pour l'instant |
| `FallSpot` | 4 parmi 6 emplacements | Chute d'objet au-dessus d'une étagère |
| `MonsterSpawn` | 1 parmi 3 emplacements | Apparition du monstre |
| `FlickerLight` | Lampes allumées : toutes sauf les pièces sombres | Lampe qui scintille |

Chaque emplacement candidat est vérifié par les tests : il est dans une pièce, jamais à l'intérieur d'un meuble, et posé sur un meuble ou sur le sol.

Pièces sombres : à chaque partie, 4 pièces parmi 10 sont plongées dans le noir (hall, entrée, palier, grenier et tombe restent éclairés). Dans le noir, sans lampe allumée, la sanité baisse et le monstre ne voit qu'à 35 % de sa portée. La lampe torche devient alors l'outil principal de ces pièces.

Le spawn des joueurs est un `SpawnLocation` placé sur le cercueil du grenier.

## État de la maison : ce qui est codé et ce qui manque

Codé (à tester en Play Test) :
- Réveil dans le cercueil : noir, 8 s sans déplacement, photo qui tombe.
- Photo de l'introduction : lue, elle déclenche un flashback silencieux.
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
- Portes qui se ferment seules : la carte n'a pas de portes mobiles.
- Rideaux qui bougent : pas de fenêtres en mouvement dans la carte.
- Porte métallique de la cave : la cave est un passage ouvert.
- Voix lointaine « Tu n'aurais jamais dû revenir ici… » : pas d'asset audio dans la banque.
- Cri de corneille de la fin 1 : pas d'asset audio.
- Dessins au mur de la chambre d'enfant : décor à ajouter dans Studio.
- Menu complet (Continuer, Options) : seul « Rejouer » est codé.
- Cinématiques à affiner dans Studio : positions de caméra (réglées sur les coordonnées de la carte, à vérifier dans le moteur), et effet de lumière de la fin 3 (particules non ajoutées).

## Quêtes et fins

Chaîne principale, vers la sortie :
1. Rassembler 3 photos (tirées parmi 12 emplacements).
2. Trouver le papier du code (un des 5 emplacements). Le code change à chaque partie.
3. Ouvrir le coffret à bijoux (table de la salle de la tombe) avec le code. Il contient une petite clé.
4. Ouvrir la malle (salle de la tombe) avec la petite clé. Elle contient la clé rouillée de la sortie.
5. Sortir par la porte d'entrée, photos et clé en main.

Chaîne parallèle, vers la fin « vérité » :
- Lire les 4 documents (journal, cahier d'écolier, photo de famille, plaque du cercueil). Chacun a 2 à 3 emplacements.
- Libérer l'enfant au cercueil une fois les 4 documents lus.

Trois fins, chacune comptée dans « Fins trouvées » pour la session serveur :
- Fin 1, la fuite : sortie par la porte d'entrée.
- Fin 2, la malédiction : tout le monde meurt. Le cycle suivant commence, avec une date changée sur la plaque.
- Fin 3, la vérité : libération de l'enfant.

Indications : après 3 minutes sans progrès (`Config.Quests.HintDelay`), un indice s'affiche, une seule fois par étape.

Éléments qui font varier la partie :
- Papier du code, photos, piles, objets, chutes et apparition du monstre : emplacements tirés.
- Fausses clés : elles ne s'ajustent à rien (même sensation de fausse piste).
- Objets interactifs, une fois par partie :
  - Bougies : une bougie allumée éclaire autour d'elle pendant une minute.
  - Peluche : une pierre lisse cachée dedans, deux jets de bruit en plus.
  - Gramophone : il joue une douzaine de secondes, et le son attire le monstre.
  - Journal, cahier, photo de famille, plaque : documents de l'histoire.
- Pièces sombres : 4 pièces parmi 10 sont tirées dans le noir à chaque partie. Le hall, l'entrée, le palier, le grenier et la tombe restent éclairés.

Pas de sang : les coups se traduisent par un voile sombre, un son et une pause du joueur.

## Contrôles

- ZQSD / WASD : déplacement (caméra première personne verrouillée)
- Shift maintenu : sprint (consomme l'endurance, très bruyant)
- Ctrl maintenu : silencieux (lent, quasi silencieux)
- F : lampe torche (se vide, et fige le monstre quand elle le touche). Une pile la recharge.
- G : lancer de bruit. Un objet lancé attire le monstre au point d'impact. 3 jets par vie, 3 s de recharge.
- Clic sur le coffret : saisie du code (4 chiffres, Échap pour refermer).
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
8. **Objectifs** : 3 photos, code, coffret, petite clé, malle, clé rouillée. Puis sortie ouverte. Ouvrir la trappe : fin 1, retour au cercueil après `EndScreenTime`.
8bis. **Fin 3** : lire les 4 documents, puis libérer l'enfant au cercueil.
9. **Défaite** : tous les joueurs morts pendant 5 s : message de défaite, nouvelle partie.
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
