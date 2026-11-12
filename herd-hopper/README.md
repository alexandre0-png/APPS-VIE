# Saute-Zoo (dossier `herd-hopper`)

Jeu Roblox de zoo. Tu pars en expédition dans 4 zones au sol mortel, tu sautes d'animal en animal, et tu récupères ceux qui portent un cœur rose : ils rejoignent ton zoo, qui rapporte de l'or. Os pour améliorer les animaux, or pour agrandir le zoo, boss, histoire, quêtes, achats Robux facultatifs.

La version précédente (course de troupeau avec mur de lave) est conservée : tag git local `saute-troupeau-v1` (commit `0347c98`).

- **À faire par toi** : `A_FAIRE_UTILISATEUR.md` (test Studio, achats, identifiants)
- Publication et textes de la page du jeu : `docs/PUBLICATION.md`
- Journal des choix : `CHANGELOG.md`
- Jeu prêt à ouvrir dans Studio : `build/SauteTroupeau.rbxlx` (`python3 tools/build_rbxlx.py` pour le régénérer)
- Images de publication : `marketing/`
- Avec Rojo : `rojo build -o SauteZoo.rbxlx` (fichier `default.project.json`)

## Brief : où c'est dans le code
| Brief | Où |
|---|---|
| Intro animée | `client/Modules/Intro.luau` |
| Sauter d'animal en animal, lasso de saut | `RideService` (serveur), `Controls` (client) |
| Cœur rose, récupérer, lasso de capture avec visée assistée | `RideService` (`markReady`, `HandleCollect`, `HandleLasso`), `CreatureFx` (cœurs, cibles) |
| Mort si saut raté, vies, « Continuer » | `RideService` (`downPlayer`, `die`, `Revive`) |
| Pièces selon le nombre d'animaux, visiteurs | `shared/Zoo.luau`, `ProgressService`, `ZooService`, `client/Modules/Visitors.luau` |
| Améliorations par animal (os) et du zoo (or) | `ProgressService` (`handleZoo`), `Config.ZooUpgrades` |
| Boss et courses spéciales | `RideService` (`trackZones`), `Species` (4 boss), `Config.Run.Boss*` |
| Plusieurs zones | `Config.Zones`, `MapBuilder`, `EventService` |
| Histoire, quêtes | `Config.Story`, `Config.QuestPool`, `ProgressService` |
| Achats Robux | `MonetizationService`, `Config.Monetization` |

## Structure

```
src/shared   Config (tout l'équilibrage), Species, Zoo (formules), Util, Remotes
src/server   init.server + Modules : State, DataService, ProgressService, MonetizationService,
             CreatureService, RideService, ZooService, EventService, MapBuilder, RoundService, Fx, Cosmetics
src/client   init.client + Modules : HUD, Menu, Controls, CameraRig, CreatureFx, Intro, Visitors, Ambience, UI, Sfx, ClientState
tools/sim    simulation serveur + interface hors Roblox (fengari)
tools/marketing  générateur d'images
```

## Vérifications

**Exécutées dans cet environnement** (toutes à zéro erreur) :
- **Lune 0.11.1** : compilation des 30 scripts par le vrai compilateur Luau (`lune run tools/lune/syntax.luau`) et 22 tests de logique pure sur du vrai Luau (`lune run tools/lune/run.luau`) : zones, rosters, animaux et boss, économie du zoo (revenus, coûts d'os, caisse hors ligne, boost, enclos, or d'expédition, déblocage des zones), prix et identifiants uniques ;
- **stylua 2.6** : `stylua --check src tests tools/lune` passe ;
- **selene 0.31** : 0 erreur, 0 avertissement. La bibliothèque standard Roblox ne peut pas être téléchargée ici (réseau refusé) : `herd.yml` déclare les globales Roblox utilisées, moins complet que la vraie (les noms de méthodes Roblox ne sont pas vérifiés) ;
- **rojo 7.7.1** : `rojo build` réussit ;
- **Simulation du serveur et du client hors Roblox** (`cd tools/sim && npm install && node run.js A|B|C|D|CLIENT|UNIT`), avec des doublures de l'API Roblox et 3 joueurs-robots : expéditions complètes, zones, captures par la selle et au lasso, boss capturés, vies, mort et « Continuer » acheté, arrivée, départ d'un joueur, boutique, caisse du zoo, améliorations, histoire, achats et reçus rejoués, sauvegarde avec échecs simulés, interface (menus, HUD, contrôles, intro).

`tools/check.sh` lance tout ce qui est disponible et signale chaque outil manquant.

**Non exécuté, faute de Roblox Studio** : physique réelle (soudure du cavalier sur un animal ancré, propriété réseau), rendu, caméra, ModelScale des animaux du zoo, tactile et manette, sons (fichiers intégrés du client, musiques vides), DataStore et achats réels. Voir `A_FAIRE_UTILISATEUR.md`.
