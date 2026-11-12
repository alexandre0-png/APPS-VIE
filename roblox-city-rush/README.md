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
| `Services/PedestrianService`, `CollectibleService`, `EventService`, `LeaderboardService`, `MonetizationService` | piétons, 30 étoiles, événements, classement, achats |
| `StarterPlayerScripts` | `Client`, `Controllers/{Hud,Panels,MapView,VehicleController,Atmosphere,State,UI}` |

## Sécurité
Aucune récompense, achat, mission ou collecte ne dépend d'une valeur envoyée par le client : les RemoteEvents client->serveur
(`RequestSpawn/Buy/Color`, `AbandonMission`, `ClaimDaily`, `RequestState`) sont validés (types, limites de fréquence, propriété, niveau, argent).
Limite connue : la conduite est simulée par le client du conducteur (standard Roblox), donc la vitesse d'un véhicule est falsifiable ; aucun gain n'en dépend directement.

## Statut des vérifications (voir rapport de session)
- **Exécuté** : `tools/check_luau.py` (blocs/délimiteurs, requires locaux, noms inconnus), construction et validation XML du `.rbxlx`.
- **Analysé seulement** : toute la logique Luau (relecture manuelle), physique des véhicules, IA de police, API Roblox utilisées.
- **À tester dans Studio** : tout le comportement en jeu (cf. `A_FAIRE_UTILISATEUR.md`).
