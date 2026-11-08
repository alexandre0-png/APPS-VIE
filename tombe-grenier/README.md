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

Limites connues : les textures ne s'affichent que si les IDs sont des images Roblox. Le mode de rendu « Future » (ombres et éclairage réalistes) ne se règle que dans Studio : Lighting > Technology > Future. Les objets interactifs n'ont pas encore de logique. Le rendu 3D et le jeu réel n'ont pas été testés dans Studio : les tests vérifient la géométrie des données, pas le comportement en jeu.

## Contrôles

- ZQSD / WASD : déplacement (caméra première personne verrouillée)
- Shift maintenu : sprint (consomme l'endurance, très bruyant)
- Ctrl maintenu : silencieux (lent, quasi silencieux)
- F : lampe torche (se vide, et fige le monstre quand elle le touche)
- Bouton d'interaction (ProximityPrompt) : ramasser, se cacher, sortir, ouvrir la sortie

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
8. **Objectifs** : 3 photos + clé, puis le HUD affiche « Sortie ouverte ». Ouvrir la trappe : message de victoire, retour au cercueil après `EndScreenTime`.
9. **Défaite** : tous les joueurs morts pendant 5 s : message de défaite, nouvelle partie.
10. **Coopération** : deux clients en test serveur (Test > Players = 2). Les photos ramassées par l'un disparaissent pour l'autre, la progression est commune.
11. **Asset manquant** : ne pas renseigner un son. La sortie Output affiche un warning une seule fois, sans erreur.

## Limites connues

- Le code n'a pas été exécuté dans Roblox Studio. Il doit être validé en Play Test, en particulier le pathfinding et les `Touched` des objets tombés.
- Les sons sont vides tant que les assets ne sont pas uploadés. Le fichier `.wav` n'est pas lu depuis le dépôt : Roblox ne charge que des assets hébergés.
- Un seul monstre. Le modèle de secours n'a pas d'animations.
- Pas de sauvegarde entre sessions : chaque lancement de serveur repart d'une partie neuve.
