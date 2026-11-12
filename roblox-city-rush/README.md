# CITY RUSH - mini GTA pour Roblox (Jeu 8)

Monde ouvert 100 % généré par script (Parts natives, style blocs Roblox, aucun asset externe) :
ville 5x5 blocs, voitures volables, missions, niveau de recherche policier, économie, progression.

## Démarrage
- Studio : ouvrir `build/CityRush.rbxlx` (régénérer avec `python3 tools/build_rbxlx.py`).
- Rojo : `rojo serve default.project.json`.
- Vérifs statiques : `python3 tools/check_luau.py`.
- Publication : voir `A_FAIRE_UTILISATEUR.md` et `tools/publish.py`.

## Architecture
| Dossier | Rôle |
|---|---|
| `src/ReplicatedStorage/Shared` | `Config` (équilibrage), `Util`, `MonetizationIds` |
| `src/ServerScriptService/Main.server.lua` | démarrage ordonné des services |
| `Services/WorldService` | ville, routes, quartiers, jour/nuit, props destructibles |
| `Services/VehicleBuilder` + `VehicleService` | voitures (blocs + physique arcade), voitures publiques, verrouillage |
| `Services/WantedService` | recherche 0-5 étoiles, policiers à pied, voitures de patrouille IA, arrestation, Pay'n'Spray |
| `Services/MissionService` | livraison, taxi, course, braquage (tout validé serveur) |
| `Services/EconomyService`, `DataService` | argent/XP/succès/quotidien, DataStore avec verrou de session |
| `Services/StoryService` | histoire "L'Affaire du Coffre" : 4 énigmes géographiques, 4 chiffres, code final validé serveur |
| `Services/CinematicService` | décide quand jouer une cinématique (une fois par joueur) ; le client ne peut que la passer |
| `Services/PedestrianService`, `CollectibleService`, `EventService`, `LeaderboardService`, `MonetizationService` | piétons, 30 étoiles, événements, classement, achats |
| `StarterPlayerScripts` | `Client`, `Controllers/{Hud,Panels,MapView,VehicleController,Atmosphere,VisualFX,Animations,Cinematics,SoundController,State,UI}` (effets dans `Config.Visual`, animations dans `Config.Animations`, maths pures dans `Shared/AnimMath`, cinématiques dans `Config.Cinematics` + `Shared/CinematicLogic`) |

## Sécurité
Aucune récompense, achat, mission ou collecte ne dépend d'une valeur envoyée par le client : les RemoteEvents client->serveur
(`RequestSpawn/Buy/Color`, `AbandonMission`, `ClaimDaily`, `RequestState`) sont validés (types, limites de fréquence, propriété, niveau, argent).
Limite connue : la conduite est simulée par le client du conducteur (standard Roblox), donc la vitesse d'un véhicule est falsifiable ; aucun gain n'en dépend directement.

## Tests
`pip install lupa && python3 tests/run.py` : 63 tests exécutés sous Lua 5.5 dans un faux environnement Roblox (`tests/harness.lua` : Instance, signaux, scheduler de tâches, DataStore avec pannes injectables).
Couvrent : économie (gains, plafonds, valeurs aberrantes), achats, succès, quotidien, sauvegarde (chargement raté, verrou de session, Studio, sortie du joueur), reçus Robux idempotents,
niveaux de recherche et arrestations, missions (progression validée serveur, ordre des points, annulation, braquage), étoiles, voitures, piétons, événements, génération complète de la ville et démarrage de `Main`,
validateurs de chaque Remote (nil, mauvais types, NaN, très grands, chaînes longues, spam).
`ONLY="mot|autre" python3 tests/run.py` filtre par nom.

## Statut des vérifications
- **Exécuté** : les 63 tests ci-dessus (Lua 5.5, pas Luau), `tools/check_luau.py`, construction + validation XML du `.rbxlx`.
- **Analysé seulement** : physique des véhicules (contraintes), IA des voitures de patrouille (déplacement réel), rendu, UI (le faux environnement ne simule ni GUI ni physique), compatibilité exacte Luau (types/APIs).
- **À tester dans Studio** : tout ce qui touche au rendu, à la physique et à l'interface (cf. `A_FAIRE_UTILISATEUR.md`).
