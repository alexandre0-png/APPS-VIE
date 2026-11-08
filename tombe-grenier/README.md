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
3. Construire la carte (voir tags ci-dessous). Sans carte, le jeu tourne mais sans objectifs.
4. Ajouter dans `ServerStorage` :
   - `Monster` : un modèle avec `Humanoid` et `HumanoidRootPart`, idéalement un rig R15. Sans lui, un rig de secours est utilisé.
   - `FallingItem` (optionnel) : une `BasePart` (barre de fer, bocal…).
5. Uploader les sons (Avatar > Audio, ou Asset Manager) et coller `rbxassetid://…` dans `AudioManifest.lua`, champ `asset`.

## Tags CollectionService à poser sur la carte

| Tag | Sur quoi | Rôle |
|---|---|---|
| `MonsterSpawn` | BasePart | Point d'apparition du monstre |
| `Waypoint` | BasePart | Points de patrouille (sinon patrouille aléatoire) |
| `FallSpot` | BasePart | Point de départ de chute, au-dessus d'une étagère |
| `FlickerLight` | BasePart avec PointLight/SpotLight enfant | Lampe qui scintille |
| `Photo` | BasePart | Photo ramassable (3 requises) |
| `Key` | BasePart | Clé ramassable |
| `ExitDoor` | BasePart | Sortie, ouverte si photos + clé |
| `Hiding` | BasePart à l'intérieur d'une armoire | Cachette |

Le spawn des joueurs est le `SpawnLocation` de la carte : c'est là que se trouve le cercueil.

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
3. **Chute** : un objet tombe au `FallSpot` avec le son `iron_bar_fall` (si l'asset est renseigné). Jamais deux fois au même point d'affilée.
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
